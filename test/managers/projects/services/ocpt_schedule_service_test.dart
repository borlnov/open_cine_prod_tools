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
        OcptScreenplaysTableCompanion.insert(id: screenplayId, title: "Draft", updatedAt: DateTime.now()),
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

    test("createDay mints exactly one slot with the default crew band", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;

      final slots = await readLiveSlots(dayId);
      expect(slots, hasLength(1));
      expect(slots.single.label, "");
      expect(slots.single.crewCallMinute, 480);
      expect(slots.single.crewWrapMinute, 1080);
      expect(slots.single.castCallMinute, isNull);
    });

    test("loadSchedule ranks days by sortKey and updates after a reorder", () async {
      final firstId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final secondId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final thirdId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 12),
      ))!;

      var snapshot = await scheduleService.loadSchedule(
        database: database,
        screenplayId: screenplayId,
      );
      expect(snapshot.days.map((day) => day.id), [firstId, secondId, thirdId]);
      expect(snapshot.days.map((day) => day.dayNumber), [1, 2, 3]);

      await scheduleService.reorderDay(database: database, dayId: thirdId, newPosition: 0);

      snapshot = await scheduleService.loadSchedule(database: database, screenplayId: screenplayId);
      expect(snapshot.days.map((day) => day.id), [thirdId, firstId, secondId]);
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
      await scheduleService.placeShot(database: database, dayId: dayId, shotId: shotId);

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
          crewCallMinute: const Value(420),
          crewWrapMinute: const Value(1000),
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
          callMinute: 400,
        ))!;
        final sourceCastId = (await scheduleService.addSlotCastRole(
          database: database,
          slotId: sourceSlotId,
          roleId: roleId,
          arrivalMinute: 415,
        ))!;
        await scheduleService.placeShot(database: database, dayId: sourceDayId, shotId: shotId);

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
        expect(newSlot.crewCallMinute, 420);
        expect(newSlot.crewWrapMinute, 1000);

        final newCrew = await readAllCrew(newSlot.id);
        expect(newCrew, hasLength(1));
        expect(newCrew.single.id, isNot(sourceCrewId));
        expect(newCrew.single.personId, personId);
        expect(newCrew.single.positionId, "director");
        expect(newCrew.single.callMinute, 400);

        final newCast = await readAllCast(newSlot.id);
        expect(newCast, hasLength(1));
        expect(newCast.single.id, isNot(sourceCastId));
        expect(newCast.single.roleId, roleId);
        expect(newCast.single.arrivalMinute, 415);

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
      expect(newSlots.single.crewCallMinute, 480);
      expect(newSlots.single.crewWrapMinute, 1080);
    });
  });

  group("slots", () {
    setUp(insertScreenplay);

    test("deleteSlot tombstones its crew and cast but leaves its blocks in place, unslotted", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final slotId = (await readLiveSlots(dayId)).single.id;

      final personId = (await peopleService.createPerson(database: database))!;
      final crewId = (await scheduleService.addSlotCrewMember(
        database: database,
        slotId: slotId,
        personId: personId,
      ))!;
      final roleId = await createRole("role-1");
      final castId = (await scheduleService.addSlotCastRole(
        database: database,
        slotId: slotId,
        roleId: roleId,
      ))!;
      final shotId = await createShot("shot-1");
      final blockId = (await scheduleService.placeShot(
        database: database,
        dayId: dayId,
        shotId: shotId,
        slotId: slotId,
      ))!;

      await scheduleService.deleteSlot(database: database, slotId: slotId);

      final crewRow = (await readAllCrew(slotId)).firstWhere((row) => row.id == crewId);
      expect(crewRow.isDeleted, isTrue);
      final castRow = (await readAllCast(slotId)).firstWhere((row) => row.id == castId);
      expect(castRow.isDeleted, isTrue);

      final block = await readBlock(blockId);
      expect(block.isDeleted, isFalse);
      expect(block.shootingDayId, dayId);
      expect(block.slotId, isNull);
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

    test("placeShot on an already-placed shot moves its block instead of duplicating it", () async {
      final firstDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final secondDayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 11),
      ))!;
      final shotId = await createShot("shot-1");

      final firstBlockId = (await scheduleService.placeShot(
        database: database,
        dayId: firstDayId,
        shotId: shotId,
      ))!;
      final secondBlockId = (await scheduleService.placeShot(
        database: database,
        dayId: secondDayId,
        shotId: shotId,
      ))!;

      expect(secondBlockId, firstBlockId);

      final firstDayBlocks = (await readAllBlocks(firstDayId)).where((row) => !row.isDeleted);
      expect(firstDayBlocks, isEmpty);

      final secondDayBlocks = await readAllBlocks(secondDayId);
      expect(secondDayBlocks.where((row) => !row.isDeleted), hasLength(1));
      expect(secondDayBlocks.single.shotId, shotId);
      expect(secondDayBlocks.single.kind, OcptShootingBlockKind.shot);
    });

    test("unplaceShot tombstones the shot's block and drops it from loadShotPlacements", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;
      final shotId = await createShot("shot-1");

      await scheduleService.placeShot(database: database, dayId: dayId, shotId: shotId);
      var placements = await scheduleService.loadShotPlacements(
        database: database,
        screenplayId: screenplayId,
      );
      expect(placements[shotId]!.dayId, dayId);
      expect(placements[shotId]!.dayNumber, 1);

      await scheduleService.unplaceShot(database: database, shotId: shotId);

      placements = await scheduleService.loadShotPlacements(
        database: database,
        screenplayId: screenplayId,
      );
      expect(placements.containsKey(shotId), isFalse);

      final blocks = await readAllBlocks(dayId);
      expect(blocks.single.isDeleted, isTrue);
    });

    test("moveBlockToDay moves a block across days and clears its slot", () async {
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

      final blockId = (await scheduleService.createBlock(
        database: database,
        dayId: sourceDayId,
        kind: OcptShootingBlockKind.meal,
        slotId: sourceSlotId,
        label: "Repas",
      ))!;

      await scheduleService.moveBlockToDay(
        database: database,
        blockId: blockId,
        targetDayId: targetDayId,
        newPosition: 0,
      );

      final moved = await readBlock(blockId);
      expect(moved.shootingDayId, targetDayId);
      expect(moved.slotId, isNull);
      expect(moved.kind, OcptShootingBlockKind.meal);
      expect(moved.label, "Repas");
    });

    test("createBlock refuses kind shot, which only placeShot may write", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;

      final blockId = await scheduleService.createBlock(
        database: database,
        dayId: dayId,
        kind: OcptShootingBlockKind.shot,
      );

      expect(blockId, isNull);
      expect(await readAllBlocks(dayId), isEmpty);
    });

    test("reorderBlock writes exactly one row within a day's timetable", () async {
      final dayId = (await scheduleService.createDay(
        database: database,
        screenplayId: screenplayId,
        date: DateTime(2026, 8, 10),
      ))!;

      final firstId = (await scheduleService.createBlock(
        database: database,
        dayId: dayId,
        kind: OcptShootingBlockKind.preparation,
      ))!;
      final secondId = (await scheduleService.createBlock(
        database: database,
        dayId: dayId,
        kind: OcptShootingBlockKind.meal,
      ))!;

      await scheduleService.reorderBlock(
        database: database,
        dayId: dayId,
        blockId: secondId,
        newPosition: 0,
      );

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
      await scheduleService.reorderDay(database: preview, dayId: "missing-day", newPosition: 0);
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
          crewCallMinute: 480,
          crewWrapMinute: 1080,
        ),
        isNull,
      );
      await scheduleService.updateSlot(database: preview, slotId: "missing-slot");
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
          dayId: "missing-day",
          shotId: "missing-shot",
        ),
        isNull,
      );
      await scheduleService.unplaceShot(database: preview, shotId: "missing-shot");
      await scheduleService.deleteBlock(database: preview, blockId: "missing-block");
      expect(
        await scheduleService.createBlock(
          database: preview,
          dayId: "missing-day",
          kind: OcptShootingBlockKind.meal,
        ),
        isNull,
      );
      await scheduleService.updateBlock(database: preview, blockId: "missing-block");
      await scheduleService.reorderBlock(
        database: preview,
        dayId: "missing-day",
        blockId: "missing-block",
        newPosition: 0,
      );
      await scheduleService.moveBlockToDay(
        database: preview,
        blockId: "missing-block",
        targetDayId: "missing-day",
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
