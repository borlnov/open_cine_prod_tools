// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const scheduleService = OcptScheduleService();
  const peopleService = OcptPeopleService();
  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Inserts the screenplay every day/slot/shot in these tests hangs off.
  Future<void> insertScreenplay() => database
      .into(database.ocptScreenplaysTable)
      .insert(
        OcptScreenplaysTableCompanion.insert(
          id: screenplayId,
          title: "Draft",
          updatedAt: DateTime.now(),
        ),
      );

  /// Inserts a role, satisfying `shooting_slot_cast.roleId`'s foreign key without going through
  /// `OcptRoleIndexService`'s reconciliation, exactly as `ocpt_breakdown_service_test.dart` does.
  Future<String> createRole(String id, {String name = "LÉA"}) async {
    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(
            id: id,
            screenplayId: screenplayId,
            name: name,
            kind: OcptRoleKind.silent,
          ),
        );
    return id;
  }

  /// Inserts a scene, satisfying `shooting_day_blocks.sceneId`'s foreign key without going through
  /// `OcptSceneIndexService`'s reconciliation, which this service has no business exercising.
  Future<String> createScene(String id) async {
    await database
        .into(database.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: id,
            screenplayId: screenplayId,
            position: 0,
            heading: "INT. CUISINE - JOUR",
            charStart: 0,
            charEnd: 1,
          ),
        );
    return id;
  }

  /// Inserts an orphaned shot (no scene), satisfying `shooting_day_blocks.shotId`'s foreign key
  /// without the shot list's own scene machinery, which this service has no business exercising.
  Future<String> createShot(String id) async {
    await database
        .into(database.ocptShotsTable)
        .insert(OcptShotsTableCompanion.insert(id: id, screenplayId: screenplayId, position: 0));
    return id;
  }

  /// The day row [id], tombstoned or not.
  Future<OcptShootingDayRow> readDay(String id) => (database.select(
    database.ocptShootingDaysTable,
  )..where((row) => row.id.equals(id))).getSingle();

  /// Every slot row of day [dayId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingSlotRow>> readAllSlots(String dayId) =>
      (database.select(database.ocptShootingSlotsTable)
            ..where((row) => row.shootingDayId.equals(dayId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every live slot row of day [dayId], in `sortKey` order.
  Future<List<OcptShootingSlotRow>> readLiveSlots(String dayId) async =>
      (await readAllSlots(dayId)).where((row) => !row.isDeleted).toList();

  /// Every crew row of slot [slotId], tombstoned or not.
  Future<List<OcptShootingSlotCrewRow>> readAllCrew(String slotId) =>
      (database.select(database.ocptShootingSlotCrewTable)
            ..where((row) => row.slotId.equals(slotId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every cast row of slot [slotId], tombstoned or not.
  Future<List<OcptShootingSlotCastRow>> readAllCast(String slotId) =>
      (database.select(database.ocptShootingSlotCastTable)
            ..where((row) => row.slotId.equals(slotId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every block row of day [dayId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingDayBlockRow>> readAllBlocks(String dayId) =>
      (database.select(database.ocptShootingDayBlocksTable)
            ..where((row) => row.shootingDayId.equals(dayId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// The block row [id], tombstoned or not.
  Future<OcptShootingDayBlockRow> readBlock(String id) => (database.select(
    database.ocptShootingDayBlocksTable,
  )..where((row) => row.id.equals(id))).getSingle();

  group("days", () {
    setUp(insertScreenplay);

    test("createDay mints exactly one slot anchored by its start at the default minute", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;

      final slots = await readLiveSlots(dayId);
      expect(slots, hasLength(1));
      expect(slots.single.label, "");
      expect(slots.single.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slots.single.anchorMinute, 480);
      expect(slots.single.anchorSlotId, isNull);
    });

    test("loadSchedule ranks days chronologically, and renumbers when a date moves", () async {
      // Created out of chronological order: the 12th first, then the 10th, then the 11th.
      final laterId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 12),
      ))!;
      final earliestId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final middleId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;

      var snapshot = await scheduleService.loadSchedule(
        database: database,
        screenplayId: screenplayId,
      );
      expect(snapshot.days.map((day) => day.id), [earliestId, middleId, laterId]);
      expect(snapshot.days.map((day) => day.dayNumber), [1, 2, 3]);

      // Moving the middle day's date before the earliest one renumbers all three — J1/J2/J3 are a
      // label read off the dates, not the days' own creation order.
      await scheduleService.updateDay(
        database: database,
        dayId: middleId,
        date: Value(DateTime(2026, 8, 9)),
      );

      snapshot = await scheduleService.loadSchedule(database: database, screenplayId: screenplayId);
      expect(snapshot.days.map((day) => day.id), [middleId, earliestId, laterId]);
      expect(snapshot.days.map((day) => day.dayNumber), [1, 2, 3]);
    });

    test("deleteDay tombstones the day and everything hanging off it", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slots = await readLiveSlots(dayId);
      final slotId = slots.single.id;

      final personId = (await peopleService.createPerson(database: database))!;
      final roleId = await createRole("role-1");
      final shotId = await createShot("shot-1");

      await scheduleService.addSlotCrewMember(database: database, slotId: slotId, personId: personId);
      await scheduleService.addSlotCastRole(database: database, slotId: slotId, roleId: roleId);
      await scheduleService.placeShot(database: database, slotId: slotId, shotId: shotId);

      await scheduleService.deleteDay(database: database, dayId: dayId);

      expect((await readDay(dayId)).isDeleted, isTrue);
      final allSlots = await readAllSlots(dayId);
      expect(allSlots, hasLength(1));
      expect(allSlots.single.isDeleted, isTrue);
      expect((await readAllCrew(slotId)).every((row) => row.isDeleted), isTrue);
      expect((await readAllCast(slotId)).every((row) => row.isDeleted), isTrue);
      expect((await readAllBlocks(dayId)).every((row) => row.isDeleted), isTrue);

      final snapshot = await scheduleService.loadSchedule(
        database: database,
        screenplayId: screenplayId,
      );
      expect(snapshot.days, isEmpty);
    });

    test(
      "duplicateDay copies the slots, crew and cast with fresh ids, and neither the shots nor "
      "the crew note",
      () async {
        final sourceDayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;
        final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;

        await scheduleService.updateSlot(
          database: database,
          slotId: sourceSlotId,
          label: const Value("Matin"),
        );
        await scheduleService.setSlotAnchor(
          database: database,
          slotId: sourceSlotId,
          edge: OcptShootingSlotAnchorEdge.start,
          minute: 420,
        );
        await scheduleService.updateDay(
          database: database,
          dayId: sourceDayId,
          crewNote: const Value("Apporter les parapluies"),
        );

        final personId = (await peopleService.createPerson(database: database))!;
        final roleId = await createRole("role-1");
        final shotId = await createShot("shot-1");

        final sourceCrewId = (await scheduleService.addSlotCrewMember(
          database: database,
          slotId: sourceSlotId,
          personId: personId,
          positionId: "director",
        ))!;

        final sourceCastId = (await scheduleService.addSlotCastRole(
          database: database,
          slotId: sourceSlotId,
          roleId: roleId,
        ))!;

        await scheduleService.placeShot(database: database, slotId: sourceSlotId, shotId: shotId);

        final newDayId = (await scheduleService.duplicateDay(
          database: database,
          sourceDayId: sourceDayId,
          date: DateTime(2026, 8, 20),
        ))!;

        expect(newDayId, isNot(sourceDayId));
        final newDay = await readDay(newDayId);
        expect(newDay.crewNote, "");
        expect(newDay.status, OcptShootingDayStatus.planned);

        final newSlots = await readLiveSlots(newDayId);
        expect(newSlots, hasLength(1));
        final newSlot = newSlots.single;
        expect(newSlot.id, isNot(sourceSlotId));
        expect(newSlot.label, "Matin");
        expect(newSlot.anchorEdge, OcptShootingSlotAnchorEdge.start);
        expect(newSlot.anchorMinute, 420);

        final newCrew = await readAllCrew(newSlot.id);
        expect(newCrew, hasLength(1));
        expect(newCrew.single.id, isNot(sourceCrewId));
        expect(newCrew.single.personId, personId);
        expect(newCrew.single.positionId, "director");

        final newCast = await readAllCast(newSlot.id);
        expect(newCast, hasLength(1));
        expect(newCast.single.id, isNot(sourceCastId));
        expect(newCast.single.roleId, roleId);

        // Neither the placed shot nor its block travelled to the new day.
        expect(await readAllBlocks(newDayId), isEmpty);
      },
    );

    test("duplicateDay mints the default slot when the source day has no live slot left", () async {
      final sourceDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;
      await scheduleService.deleteSlot(database: database, slotId: sourceSlotId);

      final newDayId = (await scheduleService.duplicateDay(
        database: database,
        sourceDayId: sourceDayId,
        date: DateTime(2026, 8, 20),
      ))!;

      final newSlots = await readLiveSlots(newDayId);
      expect(newSlots, hasLength(1));
      expect(newSlots.single.anchorMinute, 480);
    });
  });

  group("slots", () {
    setUp(insertScreenplay);

    test("setSlotAnchor pins an edge to a typed hour, and to another slot's opposite one", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotA = (await readLiveSlots(dayId)).single.id;
      final slotB = (await scheduleService.createSlot(
        database: database,
        shootingDayId: dayId,
        anchorMinute: 1080,
      ))!;

      expect(
        await scheduleService.setSlotAnchor(
          database: database,
          slotId: slotB,
          edge: OcptShootingSlotAnchorEdge.end,
          minute: 1320,
        ),
        isTrue,
      );
      var slots = {for (final row in await readLiveSlots(dayId)) row.id: row};
      expect(slots[slotB]!.anchorEdge, OcptShootingSlotAnchorEdge.end);
      expect(slots[slotB]!.anchorMinute, 1320);
      expect(slots[slotB]!.anchorSlotId, isNull);

      expect(
        await scheduleService.setSlotAnchor(
          database: database,
          slotId: slotB,
          edge: OcptShootingSlotAnchorEdge.start,
          sourceSlotId: slotA,
        ),
        isTrue,
      );
      slots = {for (final row in await readLiveSlots(dayId)) row.id: row};
      expect(slots[slotB]!.anchorEdge, OcptShootingSlotAnchorEdge.start);
      // The two halves of the discriminator are exclusive: the typed hour goes when a link lands.
      expect(slots[slotB]!.anchorMinute, isNull);
      expect(slots[slotB]!.anchorSlotId, slotA);
    });

    test("setSlotAnchor refuses everything that isn't exactly one half of the discriminator", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotA = (await readLiveSlots(dayId)).single.id;
      final slotB = (await scheduleService.createSlot(
        database: database,
        shootingDayId: dayId,
        anchorMinute: 1080,
      ))!;

      // Neither half, then both.
      expect(
        await scheduleService.setSlotAnchor(
          database: database,
          slotId: slotB,
          edge: OcptShootingSlotAnchorEdge.start,
        ),
        isFalse,
      );
      expect(
        await scheduleService.setSlotAnchor(
          database: database,
          slotId: slotB,
          edge: OcptShootingSlotAnchorEdge.start,
          minute: 600,
          sourceSlotId: slotA,
        ),
        isFalse,
      );

      final slot = {for (final row in await readLiveSlots(dayId)) row.id: row}[slotB]!;
      expect(slot.anchorMinute, 1080);
      expect(slot.anchorSlotId, isNull);
    });

    test("setSlotAnchor refuses a link to itself, to another day's slot, and to a circle", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final otherDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final slotA = (await readLiveSlots(dayId)).single.id;
      final slotB = (await scheduleService.createSlot(
        database: database,
        shootingDayId: dayId,
        anchorMinute: 1080,
      ))!;
      final foreignSlot = (await readLiveSlots(otherDayId)).single.id;

      expect(
        await scheduleService.setSlotAnchor(
          database: database,
          slotId: slotB,
          edge: OcptShootingSlotAnchorEdge.start,
          sourceSlotId: slotB,
        ),
        isFalse,
      );
      expect(
        await scheduleService.setSlotAnchor(
          database: database,
          slotId: slotB,
          edge: OcptShootingSlotAnchorEdge.start,
          sourceSlotId: foreignSlot,
        ),
        isFalse,
      );

      // B now reads A; A reading B back would close the circle the pure function only defends
      // against, and this is what keeps that defence unreachable.
      await scheduleService.setSlotAnchor(
        database: database,
        slotId: slotB,
        edge: OcptShootingSlotAnchorEdge.start,
        sourceSlotId: slotA,
      );
      expect(
        await scheduleService.setSlotAnchor(
          database: database,
          slotId: slotA,
          edge: OcptShootingSlotAnchorEdge.start,
          sourceSlotId: slotB,
        ),
        isFalse,
      );

      final slots = {for (final row in await readLiveSlots(dayId)) row.id: row};
      expect(slots[slotA]!.anchorSlotId, isNull);
      expect(slots[slotA]!.anchorMinute, 480);
    });

    test("deleteSlot freezes the hour each of its dependents was reading", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final source = (await readLiveSlots(dayId)).single.id; // 08:00
      final follower = (await scheduleService.createSlot(
        database: database,
        shootingDayId: dayId,
        anchorMinute: 1080,
      ))!;
      final before = (await scheduleService.createSlot(
        database: database,
        shootingDayId: dayId,
        anchorMinute: 1080,
      ))!;

      // The source runs 08:00 -> 09:00, so its follower starts at 09:00 and the slot pinned to end
      // when it begins ends at 08:00.
      await scheduleService.createBlock(
        database: database,
        slotId: source,
        kind: OcptShootingBlockKind.preparation,
        durationMinutes: 60,
      );
      await scheduleService.setSlotAnchor(
        database: database,
        slotId: follower,
        edge: OcptShootingSlotAnchorEdge.start,
        sourceSlotId: source,
      );
      await scheduleService.setSlotAnchor(
        database: database,
        slotId: before,
        edge: OcptShootingSlotAnchorEdge.end,
        sourceSlotId: source,
      );

      await scheduleService.deleteSlot(database: database, slotId: source);

      final slots = {for (final row in await readLiveSlots(dayId)) row.id: row};
      expect(slots.keys, unorderedEquals([follower, before]));
      // Each keeps the hour it was reading, as a typed anchor on its own edge: a deletion never
      // silently moves a day.
      expect(slots[follower]!.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slots[follower]!.anchorMinute, 540);
      expect(slots[follower]!.anchorSlotId, isNull);
      expect(slots[before]!.anchorEdge, OcptShootingSlotAnchorEdge.end);
      expect(slots[before]!.anchorMinute, 480);
      expect(slots[before]!.anchorSlotId, isNull);
    });

    test("duplicateDay remaps a link onto the copy, never back across the two days", () async {
      final sourceDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final first = (await readLiveSlots(sourceDayId)).single.id;
      final second = (await scheduleService.createSlot(
        database: database,
        shootingDayId: sourceDayId,
        anchorMinute: 1080,
        label: "Soir",
      ))!;
      await scheduleService.setSlotAnchor(
        database: database,
        slotId: second,
        edge: OcptShootingSlotAnchorEdge.start,
        sourceSlotId: first,
      );

      final newDayId = (await scheduleService.duplicateDay(
        database: database,
        sourceDayId: sourceDayId,
        date: DateTime(2026, 8, 20),
      ))!;

      final newSlots = await readLiveSlots(newDayId);
      expect(newSlots, hasLength(2));
      final newFirst = newSlots.firstWhere((row) => row.label.isEmpty);
      final newSecond = newSlots.firstWhere((row) => row.label == "Soir");
      expect(newSecond.anchorSlotId, newFirst.id);
      expect(newSecond.anchorSlotId, isNot(first));
      expect(newSecond.anchorMinute, isNull);
    });

    test(
      "deleteSlot moves its live blocks, in order, to the end of the day's first other live "
      "slot",
      () async {
        final dayId = (await scheduleService.createDay(
          database: database,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ))!;
        final slotA = (await readLiveSlots(dayId)).single.id;
        final slotB = (await scheduleService.createSlot(
          database: database,
          shootingDayId: dayId,
          anchorMinute: 1080,
          label: "Soir",
        ))!;

        final x1 = (await scheduleService.createBlock(
          database: database,
          slotId: slotB,
          kind: OcptShootingBlockKind.preparation,
        ))!;
        final x2 = (await scheduleService.createBlock(
          database: database,
          slotId: slotB,
          kind: OcptShootingBlockKind.hairMakeUp,
        ))!;
        final y1 = (await scheduleService.createBlock(
          database: database,
          slotId: slotA,
          kind: OcptShootingBlockKind.meal,
        ))!;
        final y2 = (await scheduleService.createBlock(
          database: database,
          slotId: slotA,
          kind: OcptShootingBlockKind.wrap,
        ))!;

        await scheduleService.deleteSlot(database: database, slotId: slotA);

        expect((await readAllSlots(dayId)).firstWhere((row) => row.id == slotA).isDeleted, isTrue);

        final blocks = await readAllBlocks(dayId);
        expect(blocks.every((row) => !row.isDeleted), isTrue);
        expect(blocks.every((row) => row.slotId == slotB), isTrue);
        expect(blocks.map((row) => row.id), [x1, x2, y1, y2]);
      },
    );

    test("deleteSlot tombstones its own blocks too when it is the day's last live slot", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;

      final y1 = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.meal,
      ))!;
      final y2 = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.wrap,
      ))!;

      await scheduleService.deleteSlot(database: database, slotId: slotId);

      expect((await readAllSlots(dayId)).single.isDeleted, isTrue);
      final blocks = await readAllBlocks(dayId);
      expect(blocks.map((row) => row.id).toSet(), {y1, y2});
      expect(blocks.every((row) => row.isDeleted), isTrue);
    });

    test("addSlotCastRole refuses convoking the same role twice in one slot", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;
      final roleId = await createRole("role-1");

      final firstId = await scheduleService.addSlotCastRole(
        database: database,
        slotId: slotId,
        roleId: roleId,
      );
      final secondId = await scheduleService.addSlotCastRole(
        database: database,
        slotId: slotId,
        roleId: roleId,
      );

      expect(secondId, firstId);
      expect(await readAllCast(slotId), hasLength(1));
    });
  });

  group("the timetable", () {
    setUp(insertScreenplay);

    test("placeShot on an already-placed shot creates a second block rather than moving the first",
        () async {
      final firstDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
      final secondDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final secondSlotId = (await readLiveSlots(secondDayId)).single.id;
      final shotId = await createShot("shot-1");

      final firstBlockId = (await scheduleService.placeShot(
        database: database,
        slotId: firstSlotId,
        shotId: shotId,
      ))!;
      final secondBlockId = (await scheduleService.placeShot(
        database: database,
        slotId: secondSlotId,
        shotId: shotId,
      ))!;

      expect(secondBlockId, isNot(firstBlockId));

      final firstDayBlocks = (await readAllBlocks(firstDayId)).where((row) => !row.isDeleted);
      expect(firstDayBlocks, hasLength(1));
      expect(firstDayBlocks.single.id, firstBlockId);
      expect(firstDayBlocks.single.slotId, firstSlotId);

      final secondDayBlocks = await readAllBlocks(secondDayId);
      expect(secondDayBlocks.where((row) => !row.isDeleted), hasLength(1));
      expect(secondDayBlocks.single.id, secondBlockId);
      expect(secondDayBlocks.single.slotId, secondSlotId);
      expect(secondDayBlocks.single.shotId, shotId);
      expect(secondDayBlocks.single.kind, OcptShootingBlockKind.shot);
    });

    test("placing the same shot twice in one slot yields two live blocks and two placements",
        () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;
      final shotId = await createShot("shot-1");

      // A shot interrupted by the meal break and resumed after it: two blocks, same slot, same day.
      final firstBlockId = (await scheduleService.placeShot(
        database: database,
        slotId: slotId,
        shotId: shotId,
      ))!;
      final secondBlockId = (await scheduleService.placeShot(
        database: database,
        slotId: slotId,
        shotId: shotId,
      ))!;

      expect(secondBlockId, isNot(firstBlockId));

      final liveBlocks = (await readAllBlocks(dayId)).where((row) => !row.isDeleted);
      expect(liveBlocks, hasLength(2));

      final placements = await scheduleService.loadShotPlacements(
        database: database,
        screenplayId: screenplayId,
      );
      expect(placements[shotId], hasLength(2));
      expect(placements[shotId]!.every((placement) => placement.dayId == dayId), isTrue);
    });

    test("placing the same shot on two different days yields two placements, day-number ordered",
        () async {
      final firstDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
      final secondDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final secondSlotId = (await readLiveSlots(secondDayId)).single.id;
      final shotId = await createShot("shot-1");

      // Placed on the later day first, to prove the result is ordered by dayNumber rather than by
      // the order placeShot was called in.
      await scheduleService.placeShot(database: database, slotId: secondSlotId, shotId: shotId);
      await scheduleService.placeShot(database: database, slotId: firstSlotId, shotId: shotId);

      final placements = await scheduleService.loadShotPlacements(
        database: database,
        screenplayId: screenplayId,
      );

      expect(placements[shotId], hasLength(2));
      expect(placements[shotId]![0].dayId, firstDayId);
      expect(placements[shotId]![0].dayNumber, 1);
      expect(placements[shotId]![1].dayId, secondDayId);
      expect(placements[shotId]![1].dayNumber, 2);
    });

    test("moveBlockToSlot moves a block to another slot, and to that slot's day with it", () async {
      final sourceDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final targetDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;
      final targetSlotId = (await readLiveSlots(targetDayId)).single.id;

      final blockId = (await scheduleService.createBlock(
        database: database,
        slotId: sourceSlotId,
        kind: OcptShootingBlockKind.meal,
        label: "Repas",
      ))!;

      await scheduleService.moveBlockToSlot(
        database: database,
        blockId: blockId,
        targetSlotId: targetSlotId,
        newPosition: 0,
      );

      final moved = await readBlock(blockId);
      expect(moved.shootingDayId, targetDayId);
      expect(moved.slotId, targetSlotId);
      expect(moved.kind, OcptShootingBlockKind.meal);
      expect(moved.label, "Repas");
    });

    test("createBlock refuses kind shot, which only placeShot may write", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;

      final blockId = await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.shot,
      );

      expect(blockId, isNull);
      expect(await readAllBlocks(dayId), isEmpty);
    });

    test("createBlock keeps a scene on a hold and drops it on any other kind", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;
      final sceneId = await createScene("scene-1");

      final holdId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.hold,
        sceneId: sceneId,
      ))!;
      final mealId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.meal,
        sceneId: sceneId,
      ))!;

      expect((await readBlock(holdId)).sceneId, sceneId);
      expect((await readBlock(mealId)).sceneId, isNull);
    });

    test("updateBlock drops a hold's scene when it stops being a hold", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;
      final sceneId = await createScene("scene-1");

      final blockId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.hold,
        sceneId: sceneId,
      ))!;

      await scheduleService.updateBlock(
        database: database,
        blockId: blockId,
        kind: const Value(OcptShootingBlockKind.preparation),
      );

      expect((await readBlock(blockId)).sceneId, isNull);
    });

    test("updateBlock refuses to name a scene on a block that isn't a hold", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;
      final sceneId = await createScene("scene-1");

      final blockId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.meal,
      ))!;

      await scheduleService.updateBlock(
        database: database,
        blockId: blockId,
        sceneId: Value(sceneId),
      );

      expect((await readBlock(blockId)).sceneId, isNull);
    });

    test("reorderBlock writes exactly one row within a slot's own timetable", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;

      final firstId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.preparation,
      ))!;
      final secondId = (await scheduleService.createBlock(
        database: database,
        slotId: slotId,
        kind: OcptShootingBlockKind.meal,
      ))!;

      await scheduleService.reorderBlock(database: database, blockId: secondId, newPosition: 0);

      final blocks = await readAllBlocks(dayId);
      expect(blocks.map((row) => row.id), [secondId, firstId]);
    });
  });

  group("read-only preview", () {
    test("every write is refused on a preview database", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      expect(
        await scheduleService.createDay(
          database: preview,
          screenplayId: screenplayId,
          date: DateTime(2026, 8, 10),
        ),
        isNull,
      );
      await scheduleService.updateDay(database: preview, dayId: "missing-day");
      await scheduleService.deleteDay(database: preview, dayId: "missing-day");
      expect(
        await scheduleService.duplicateDay(
          database: preview,
          sourceDayId: "missing-day",
          date: DateTime(2026, 8, 20),
        ),
        isNull,
      );

      expect(
        await scheduleService.createSlot(
          database: preview,
          shootingDayId: "missing-day",
          anchorMinute: 480,
        ),
        isNull,
      );
      await scheduleService.updateSlot(database: preview, slotId: "missing-slot");
      expect(
        await scheduleService.setSlotAnchor(
          database: preview,
          slotId: "missing-slot",
          edge: OcptShootingSlotAnchorEdge.start,
          minute: 480,
        ),
        isFalse,
      );
      await scheduleService.reorderSlot(database: preview, slotId: "missing-slot", newPosition: 0);
      await scheduleService.deleteSlot(database: preview, slotId: "missing-slot");

      expect(
        await scheduleService.addSlotCrewMember(
          database: preview,
          slotId: "missing-slot",
          personId: "missing-person",
        ),
        isNull,
      );
      await scheduleService.updateSlotCrewMember(database: preview, crewMemberId: "missing-crew");
      await scheduleService.removeSlotCrewMember(database: preview, crewMemberId: "missing-crew");

      expect(
        await scheduleService.addSlotCastRole(
          database: preview,
          slotId: "missing-slot",
          roleId: "missing-role",
        ),
        isNull,
      );
      await scheduleService.updateSlotCastRole(database: preview, castRoleId: "missing-cast");
      await scheduleService.removeSlotCastRole(database: preview, castRoleId: "missing-cast");

      expect(
        await scheduleService.placeShot(
          database: preview,
          slotId: "missing-slot",
          shotId: "missing-shot",
        ),
        isNull,
      );
      await scheduleService.deleteBlock(database: preview, blockId: "missing-block");
      expect(
        await scheduleService.createBlock(
          database: preview,
          slotId: "missing-slot",
          kind: OcptShootingBlockKind.meal,
        ),
        isNull,
      );
      await scheduleService.updateBlock(database: preview, blockId: "missing-block");
      await scheduleService.reorderBlock(
        database: preview,
        blockId: "missing-block",
        newPosition: 0,
      );
      await scheduleService.moveBlockToSlot(
        database: preview,
        blockId: "missing-block",
        targetSlotId: "missing-slot",
        newPosition: 0,
      );

      final snapshot = await scheduleService.loadSchedule(
        database: preview,
        screenplayId: screenplayId,
      );
      expect(snapshot.days, isEmpty);
    });
  });
}
