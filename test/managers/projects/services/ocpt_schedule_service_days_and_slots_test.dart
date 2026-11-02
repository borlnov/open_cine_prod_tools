// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of the schedule service days and slots.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";

  final scheduleService = OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId);

  final peopleService = OcptPeopleService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
    assetsService: OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId),
    roleCandidatesService: OcptRoleCandidatesService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
  );

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
  /// `OcptRoleIndexService`'s reconciliation, exactly as
  /// `ocpt_breakdown_service_reconcile_and_stamps_test.dart` does.
  Future<String> createRole(String id, {String name = "LÉA"}) async {
    await database
        .into(database.ocptRolesTable)
        .insert(OcptRolesTableCompanion.insert(id: id, name: name, kind: OcptRoleKind.silent));
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

  /// Every guest row of slot [slotId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingSlotGuestRow>> readAllGuests(String slotId) =>
      (database.select(database.ocptShootingSlotGuestsTable)
            ..where((row) => row.slotId.equals(slotId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every event row of day [dayId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingDayEventRow>> readAllEvents(String dayId) =>
      (database.select(database.ocptShootingDayEventsTable)
            ..where((row) => row.shootingDayId.equals(dayId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  group("days", () {
    setUp(insertScreenplay);

    test("createDay mints exactly one slot anchored by its start at the default minute", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);

      final slots = await readLiveSlots(dayId);
      expect(slots, hasLength(1));
      expect(slots.single.label, "");
      expect(slots.single.anchorEdge, OcptShootingSlotAnchorEdge.start);
      expect(slots.single.anchorMinute, 480);
      expect(slots.single.anchorSlotId, isNull);
    });

    test("loadSchedule ranks days chronologically, and renumbers when a date moves", () async {
      // Created out of chronological order: the 12th first, then the 10th, then the 11th.
      final laterId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 12))
          .valueOrFail);
      final earliestId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final middleId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 11))
          .valueOrFail);

      var snapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      expect(snapshot.days.map((day) => day.id), [earliestId, middleId, laterId]);
      expect(snapshot.days.map((day) => day.dayNumber), [1, 2, 3]);

      // Moving the middle day's date before the earliest one renumbers all three — J1/J2/J3 are a
      // label read off the dates, not the days' own creation order.
      await scheduleService
          .updateDay(database: database, dayId: middleId, date: Value(DateTime(2026, 8, 9)))
          .okOrFail;

      snapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      expect(snapshot.days.map((day) => day.id), [middleId, earliestId, laterId]);
      expect(snapshot.days.map((day) => day.dayNumber), [1, 2, 3]);
    });

    test("deleteDay tombstones the day and everything hanging off it", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slots = await readLiveSlots(dayId);
      final slotId = slots.single.id;

      final personId = (await peopleService.createPerson(database: database))!;
      final roleId = await createRole("role-1");
      final shotId = await createShot("shot-1");

      await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .maybeValueOrFail;
      await scheduleService
          .addSlotCastRole(database: database, slotId: slotId, roleId: roleId)
          .maybeValueOrFail;
      await scheduleService
          .placeShot(database: database, slotId: slotId, shotId: shotId)
          .maybeValueOrFail;
      await scheduleService
          .addSlotGuest(database: database, slotId: slotId, freeName: "Le maire")
          .maybeValueOrFail;
      await scheduleService
          .createDayEvent(
            database: database,
            dayId: dayId,
            minute: 1020,
            label: "Feu d'artifice du village",
          )
          .maybeValueOrFail;

      await scheduleService.deleteDay(database: database, dayId: dayId).okOrFail;

      expect((await readDay(dayId)).isDeleted, isTrue);
      final allSlots = await readAllSlots(dayId);
      expect(allSlots, hasLength(1));
      expect(allSlots.single.isDeleted, isTrue);
      expect((await readAllCrew(slotId)).every((row) => row.isDeleted), isTrue);
      expect((await readAllCast(slotId)).every((row) => row.isDeleted), isTrue);
      expect((await readAllBlocks(dayId)).every((row) => row.isDeleted), isTrue);
      expect((await readAllGuests(slotId)).every((row) => row.isDeleted), isTrue);
      expect((await readAllEvents(dayId)).every((row) => row.isDeleted), isTrue);

      final snapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      expect(snapshot.days, isEmpty);
    });

    test("duplicateDay copies the slots, crew, cast and guests with fresh ids, and neither the "
        "shots, the crew note, nor the source day's events", () async {
      final sourceDayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;

      await scheduleService
          .updateSlot(database: database, slotId: sourceSlotId, label: const Value("Matin"))
          .okOrFail;
      await scheduleService
          .setSlotAnchor(
            database: database,
            slotId: sourceSlotId,
            edge: OcptShootingSlotAnchorEdge.start,
            minute: 420,
          )
          .maybeValueOrFail;
      await scheduleService
          .updateDay(
            database: database,
            dayId: sourceDayId,
            crewNote: const Value("Apporter les parapluies"),
          )
          .okOrFail;

      final personId = (await peopleService.createPerson(database: database))!;
      final roleId = await createRole("role-1");
      final shotId = await createShot("shot-1");

      final sourceCrewId = (await scheduleService
          .addSlotCrewMember(
            database: database,
            slotId: sourceSlotId,
            personId: personId,
            positionId: "director",
          )
          .valueOrFail);

      final sourceCastId = (await scheduleService
          .addSlotCastRole(database: database, slotId: sourceSlotId, roleId: roleId)
          .valueOrFail);

      final sourceGuestId = (await scheduleService
          .addSlotGuest(
            database: database,
            slotId: sourceSlotId,
            freeName: "Le maire",
            reason: "Prête la place",
          )
          .valueOrFail);

      await scheduleService
          .placeShot(database: database, slotId: sourceSlotId, shotId: shotId)
          .maybeValueOrFail;
      await scheduleService
          .createDayEvent(
            database: database,
            dayId: sourceDayId,
            minute: 1020,
            label: "Feu d'artifice du village",
          )
          .maybeValueOrFail;

      final newDayId = (await scheduleService
          .duplicateDay(database: database, sourceDayId: sourceDayId, date: DateTime(2026, 8, 20))
          .valueOrFail);

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

      final newGuests = await readAllGuests(newSlot.id);
      expect(newGuests, hasLength(1));
      expect(newGuests.single.id, isNot(sourceGuestId));
      expect(newGuests.single.freeName, "Le maire");
      expect(newGuests.single.reason, "Prête la place");

      // Neither the placed shot, its block, nor the source day's own event travelled to the new
      // day.
      expect(await readAllBlocks(newDayId), isEmpty);
      expect(await readAllEvents(newDayId), isEmpty);
    });

    test("duplicateDay mints the default slot when the source day has no live slot left", () async {
      final sourceDayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;
      await scheduleService.deleteSlot(database: database, slotId: sourceSlotId).okOrFail;

      final newDayId = (await scheduleService
          .duplicateDay(database: database, sourceDayId: sourceDayId, date: DateTime(2026, 8, 20))
          .valueOrFail);

      final newSlots = await readLiveSlots(newDayId);
      expect(newSlots, hasLength(1));
      expect(newSlots.single.anchorMinute, 480);
    });
  });

  group("slots", () {
    setUp(insertScreenplay);

    test(
      "setSlotAnchor pins an edge to a typed hour, and to another slot's opposite one",
      () async {
        final dayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 10))
            .valueOrFail);
        final slotA = (await readLiveSlots(dayId)).single.id;
        final slotB = (await scheduleService
            .createSlot(database: database, shootingDayId: dayId, anchorMinute: 1080)
            .valueOrFail);

        expect(
          await scheduleService
              .setSlotAnchor(
                database: database,
                slotId: slotB,
                edge: OcptShootingSlotAnchorEdge.end,
                minute: 1320,
              )
              .valueOrFail,
          isTrue,
        );
        var slots = {for (final row in await readLiveSlots(dayId)) row.id: row};
        expect(slots[slotB]!.anchorEdge, OcptShootingSlotAnchorEdge.end);
        expect(slots[slotB]!.anchorMinute, 1320);
        expect(slots[slotB]!.anchorSlotId, isNull);

        expect(
          await scheduleService
              .setSlotAnchor(
                database: database,
                slotId: slotB,
                edge: OcptShootingSlotAnchorEdge.start,
                sourceSlotId: slotA,
              )
              .valueOrFail,
          isTrue,
        );
        slots = {for (final row in await readLiveSlots(dayId)) row.id: row};
        expect(slots[slotB]!.anchorEdge, OcptShootingSlotAnchorEdge.start);
        // The two halves of the discriminator are exclusive: the typed hour goes when a link lands.
        expect(slots[slotB]!.anchorMinute, isNull);
        expect(slots[slotB]!.anchorSlotId, slotA);
      },
    );

    test(
      "setSlotAnchor refuses everything that isn't exactly one half of the discriminator",
      () async {
        final dayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 10))
            .valueOrFail);
        final slotA = (await readLiveSlots(dayId)).single.id;
        final slotB = (await scheduleService
            .createSlot(database: database, shootingDayId: dayId, anchorMinute: 1080)
            .valueOrFail);

        // Neither half, then both.
        expect(
          await scheduleService
              .setSlotAnchor(
                database: database,
                slotId: slotB,
                edge: OcptShootingSlotAnchorEdge.start,
              )
              .valueOrFail,
          isFalse,
        );
        expect(
          await scheduleService
              .setSlotAnchor(
                database: database,
                slotId: slotB,
                edge: OcptShootingSlotAnchorEdge.start,
                minute: 600,
                sourceSlotId: slotA,
              )
              .valueOrFail,
          isFalse,
        );

        final slot = {for (final row in await readLiveSlots(dayId)) row.id: row}[slotB]!;
        expect(slot.anchorMinute, 1080);
        expect(slot.anchorSlotId, isNull);
      },
    );

    test(
      "setSlotAnchor refuses a link to itself, to another day's slot, and to a circle",
      () async {
        final dayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 10))
            .valueOrFail);
        final otherDayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 11))
            .valueOrFail);
        final slotA = (await readLiveSlots(dayId)).single.id;
        final slotB = (await scheduleService
            .createSlot(database: database, shootingDayId: dayId, anchorMinute: 1080)
            .valueOrFail);
        final foreignSlot = (await readLiveSlots(otherDayId)).single.id;

        expect(
          await scheduleService
              .setSlotAnchor(
                database: database,
                slotId: slotB,
                edge: OcptShootingSlotAnchorEdge.start,
                sourceSlotId: slotB,
              )
              .valueOrFail,
          isFalse,
        );
        expect(
          await scheduleService
              .setSlotAnchor(
                database: database,
                slotId: slotB,
                edge: OcptShootingSlotAnchorEdge.start,
                sourceSlotId: foreignSlot,
              )
              .valueOrFail,
          isFalse,
        );

        // B now reads A; A reading B back would close the circle the pure function only defends
        // against, and this is what keeps that defence unreachable.
        await scheduleService
            .setSlotAnchor(
              database: database,
              slotId: slotB,
              edge: OcptShootingSlotAnchorEdge.start,
              sourceSlotId: slotA,
            )
            .maybeValueOrFail;
        expect(
          await scheduleService
              .setSlotAnchor(
                database: database,
                slotId: slotA,
                edge: OcptShootingSlotAnchorEdge.start,
                sourceSlotId: slotB,
              )
              .valueOrFail,
          isFalse,
        );

        final slots = {for (final row in await readLiveSlots(dayId)) row.id: row};
        expect(slots[slotA]!.anchorSlotId, isNull);
        expect(slots[slotA]!.anchorMinute, 480);
      },
    );

    test("deleteSlot freezes the hour each of its dependents was reading", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final source = (await readLiveSlots(dayId)).single.id; // 08:00
      final follower = (await scheduleService
          .createSlot(database: database, shootingDayId: dayId, anchorMinute: 1080)
          .valueOrFail);
      final before = (await scheduleService
          .createSlot(database: database, shootingDayId: dayId, anchorMinute: 1080)
          .valueOrFail);

      // The source runs 08:00 -> 09:00, so its follower starts at 09:00 and the slot pinned to end
      // when it begins ends at 08:00.
      await scheduleService
          .createBlock(
            database: database,
            slotId: source,
            kind: OcptShootingBlockKind.preparation,
            durationMinutes: 60,
          )
          .maybeValueOrFail;
      await scheduleService
          .setSlotAnchor(
            database: database,
            slotId: follower,
            edge: OcptShootingSlotAnchorEdge.start,
            sourceSlotId: source,
          )
          .maybeValueOrFail;
      await scheduleService
          .setSlotAnchor(
            database: database,
            slotId: before,
            edge: OcptShootingSlotAnchorEdge.end,
            sourceSlotId: source,
          )
          .maybeValueOrFail;

      await scheduleService.deleteSlot(database: database, slotId: source).okOrFail;

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
      final sourceDayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final first = (await readLiveSlots(sourceDayId)).single.id;
      final second = (await scheduleService
          .createSlot(
            database: database,
            shootingDayId: sourceDayId,
            anchorMinute: 1080,
            label: "Soir",
          )
          .valueOrFail);
      await scheduleService
          .setSlotAnchor(
            database: database,
            slotId: second,
            edge: OcptShootingSlotAnchorEdge.start,
            sourceSlotId: first,
          )
          .maybeValueOrFail;

      final newDayId = (await scheduleService
          .duplicateDay(database: database, sourceDayId: sourceDayId, date: DateTime(2026, 8, 20))
          .valueOrFail);

      final newSlots = await readLiveSlots(newDayId);
      expect(newSlots, hasLength(2));
      final newFirst = newSlots.firstWhere((row) => row.label.isEmpty);
      final newSecond = newSlots.firstWhere((row) => row.label == "Soir");
      expect(newSecond.anchorSlotId, newFirst.id);
      expect(newSecond.anchorSlotId, isNot(first));
      expect(newSecond.anchorMinute, isNull);
    });

    test("deleteSlot moves its live blocks, in order, to the end of the day's first other live "
        "slot", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotA = (await readLiveSlots(dayId)).single.id;
      final slotB = (await scheduleService
          .createSlot(database: database, shootingDayId: dayId, anchorMinute: 1080, label: "Soir")
          .valueOrFail);

      final x1 = (await scheduleService
          .createBlock(database: database, slotId: slotB, kind: OcptShootingBlockKind.preparation)
          .valueOrFail);
      final x2 = (await scheduleService
          .createBlock(database: database, slotId: slotB, kind: OcptShootingBlockKind.hairMakeUp)
          .valueOrFail);
      final y1 = (await scheduleService
          .createBlock(database: database, slotId: slotA, kind: OcptShootingBlockKind.meal)
          .valueOrFail);
      final y2 = (await scheduleService
          .createBlock(database: database, slotId: slotA, kind: OcptShootingBlockKind.wrap)
          .valueOrFail);

      await scheduleService.deleteSlot(database: database, slotId: slotA).okOrFail;

      expect((await readAllSlots(dayId)).firstWhere((row) => row.id == slotA).isDeleted, isTrue);

      final blocks = await readAllBlocks(dayId);
      expect(blocks.every((row) => !row.isDeleted), isTrue);
      expect(blocks.every((row) => row.slotId == slotB), isTrue);
      expect(blocks.map((row) => row.id), [x1, x2, y1, y2]);
    });

    test("deleteSlot tombstones its own blocks too when it is the day's last live slot", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;

      final y1 = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.meal)
          .valueOrFail);
      final y2 = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.wrap)
          .valueOrFail);

      await scheduleService.deleteSlot(database: database, slotId: slotId).okOrFail;

      expect((await readAllSlots(dayId)).single.isDeleted, isTrue);
      final blocks = await readAllBlocks(dayId);
      expect(blocks.map((row) => row.id).toSet(), {y1, y2});
      expect(blocks.every((row) => row.isDeleted), isTrue);
    });

    test("deleteSlot tombstones its own guests, a guest being convoked by the slot", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final guestId = (await scheduleService
          .addSlotGuest(database: database, slotId: slotId, freeName: "Le maire")
          .valueOrFail);

      await scheduleService.deleteSlot(database: database, slotId: slotId).okOrFail;

      final guest = (await readAllGuests(slotId)).firstWhere((row) => row.id == guestId);
      expect(guest.isDeleted, isTrue);
    });

    test("addSlotCastRole refuses convoking the same role twice in one slot", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final roleId = await createRole("role-1");

      final firstId = await scheduleService
          .addSlotCastRole(database: database, slotId: slotId, roleId: roleId)
          .maybeValueOrFail;
      final secondId = await scheduleService
          .addSlotCastRole(database: database, slotId: slotId, roleId: roleId)
          .maybeValueOrFail;

      expect(secondId, firstId);
      expect(await readAllCast(slotId), hasLength(1));
    });
  });
}
