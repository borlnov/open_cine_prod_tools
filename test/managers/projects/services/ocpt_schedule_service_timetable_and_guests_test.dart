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
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of the schedule service timetable and guests.
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

  group("addSlotCrewMember pre-fills the position", () {
    setUp(insertScreenplay);

    test("a person with two declared positions convoked twice lands on both, in order", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      await peopleService
          .addPosition(
            database: database,
            personId: personId,
            positionId: "director",
            customLabel: "",
          )
          .maybeValueOrFail;
      await peopleService
          .addPosition(
            database: database,
            personId: personId,
            positionId: "soundEngineer",
            customLabel: "",
          )
          .maybeValueOrFail;

      final firstId = (await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .valueOrFail);
      final secondId = (await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .valueOrFail);

      final crew = {for (final row in await readAllCrew(slotId)) row.id: row};
      expect(crew[firstId]!.positionId, "director");
      expect(crew[secondId]!.positionId, "soundEngineer");
    });

    test("a third convocation of the same person pre-fills nothing", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      await peopleService
          .addPosition(
            database: database,
            personId: personId,
            positionId: "director",
            customLabel: "",
          )
          .maybeValueOrFail;

      await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .maybeValueOrFail;
      final thirdId = (await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .valueOrFail);

      final crew = {for (final row in await readAllCrew(slotId)) row.id: row};
      expect(crew[thirdId]!.positionId, "");
      expect(crew[thirdId]!.customLabel, "");
    });

    test("a person with a free-label declared position pre-fills that label", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      await peopleService
          .addPosition(
            database: database,
            personId: personId,
            positionId: "",
            customLabel: "Rigger",
          )
          .maybeValueOrFail;

      final crewId = (await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .valueOrFail);

      final crew = {for (final row in await readAllCrew(slotId)) row.id: row};
      expect(crew[crewId]!.positionId, "");
      expect(crew[crewId]!.customLabel, "Rigger");
    });

    test("an explicit positionId passed by the caller wins over the pre-fill", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      await peopleService
          .addPosition(
            database: database,
            personId: personId,
            positionId: "director",
            customLabel: "",
          )
          .maybeValueOrFail;

      final crewId = (await scheduleService
          .addSlotCrewMember(
            database: database,
            slotId: slotId,
            personId: personId,
            positionId: "boomOperator",
          )
          .valueOrFail);

      final crew = {for (final row in await readAllCrew(slotId)) row.id: row};
      expect(crew[crewId]!.positionId, "boomOperator");
    });

    test("a person with nothing declared gets an empty position, as before", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);

      final crewId = (await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .valueOrFail);

      final crew = {for (final row in await readAllCrew(slotId)) row.id: row};
      expect(crew[crewId]!.positionId, "");
      expect(crew[crewId]!.customLabel, "");
    });
  });

  group("the timetable", () {
    setUp(insertScreenplay);

    test(
      "placeShot on an already-placed shot creates a second block rather than moving the first",
      () async {
        final firstDayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 10))
            .valueOrFail);
        final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
        final secondDayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 11))
            .valueOrFail);
        final secondSlotId = (await readLiveSlots(secondDayId)).single.id;
        final shotId = await createShot("shot-1");

        final firstBlockId = (await scheduleService
            .placeShot(database: database, slotId: firstSlotId, shotId: shotId)
            .valueOrFail);
        final secondBlockId = (await scheduleService
            .placeShot(database: database, slotId: secondSlotId, shotId: shotId)
            .valueOrFail);

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
      },
    );

    test(
      "placing the same shot twice in one slot yields two live blocks and two placements",
      () async {
        final dayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 10))
            .valueOrFail);
        final slotId = (await readLiveSlots(dayId)).single.id;
        final shotId = await createShot("shot-1");

        // A shot interrupted by the meal break and resumed after it: two blocks, same slot, same
        // day.
        final firstBlockId = (await scheduleService
            .placeShot(database: database, slotId: slotId, shotId: shotId)
            .valueOrFail);
        final secondBlockId = (await scheduleService
            .placeShot(database: database, slotId: slotId, shotId: shotId)
            .valueOrFail);

        expect(secondBlockId, isNot(firstBlockId));

        final liveBlocks = (await readAllBlocks(dayId)).where((row) => !row.isDeleted);
        expect(liveBlocks, hasLength(2));

        final placements = await scheduleService.loadShotPlacements(database: database).valueOrFail;
        expect(placements[shotId], hasLength(2));
        expect(placements[shotId]!.every((placement) => placement.dayId == dayId), isTrue);
      },
    );

    test(
      "placing the same shot on two different days yields two placements, day-number ordered",
      () async {
        final firstDayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 10))
            .valueOrFail);
        final firstSlotId = (await readLiveSlots(firstDayId)).single.id;
        final secondDayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 11))
            .valueOrFail);
        final secondSlotId = (await readLiveSlots(secondDayId)).single.id;
        final shotId = await createShot("shot-1");

        // Placed on the later day first, to prove the result is ordered by dayNumber rather than by
        // the order placeShot was called in.
        await scheduleService
            .placeShot(database: database, slotId: secondSlotId, shotId: shotId)
            .maybeValueOrFail;
        await scheduleService
            .placeShot(database: database, slotId: firstSlotId, shotId: shotId)
            .maybeValueOrFail;

        final placements = await scheduleService.loadShotPlacements(database: database).valueOrFail;

        expect(placements[shotId], hasLength(2));
        expect(placements[shotId]![0].dayId, firstDayId);
        expect(placements[shotId]![0].dayNumber, 1);
        expect(placements[shotId]![1].dayId, secondDayId);
        expect(placements[shotId]![1].dayNumber, 2);
      },
    );

    test("moveBlockToSlot moves a block to another slot, and to that slot's day with it", () async {
      final sourceDayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final targetDayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 11))
          .valueOrFail);
      final sourceSlotId = (await readLiveSlots(sourceDayId)).single.id;
      final targetSlotId = (await readLiveSlots(targetDayId)).single.id;

      final blockId = (await scheduleService
          .createBlock(
            database: database,
            slotId: sourceSlotId,
            kind: OcptShootingBlockKind.meal,
            label: "Repas",
          )
          .valueOrFail);

      await scheduleService
          .moveBlockToSlot(
            database: database,
            blockId: blockId,
            targetSlotId: targetSlotId,
            newPosition: 0,
          )
          .okOrFail;

      final moved = await readBlock(blockId);
      expect(moved.shootingDayId, targetDayId);
      expect(moved.slotId, targetSlotId);
      expect(moved.kind, OcptShootingBlockKind.meal);
      expect(moved.label, "Repas");
    });

    test("createBlock refuses kind shot, which only placeShot may write", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;

      final blockId = await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.shot)
          .maybeValueOrFail;

      expect(blockId, isNull);
      expect(await readAllBlocks(dayId), isEmpty);
    });

    test("createBlock keeps a scene on a hold and drops it on any other kind", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final sceneId = await createScene("scene-1");

      final holdId = (await scheduleService
          .createBlock(
            database: database,
            slotId: slotId,
            kind: OcptShootingBlockKind.hold,
            sceneId: sceneId,
          )
          .valueOrFail);
      final mealId = (await scheduleService
          .createBlock(
            database: database,
            slotId: slotId,
            kind: OcptShootingBlockKind.meal,
            sceneId: sceneId,
          )
          .valueOrFail);

      expect((await readBlock(holdId)).sceneId, sceneId);
      expect((await readBlock(mealId)).sceneId, isNull);
    });

    test("updateBlock drops a hold's scene when it stops being a hold", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final sceneId = await createScene("scene-1");

      final blockId = (await scheduleService
          .createBlock(
            database: database,
            slotId: slotId,
            kind: OcptShootingBlockKind.hold,
            sceneId: sceneId,
          )
          .valueOrFail);

      await scheduleService
          .updateBlock(
            database: database,
            blockId: blockId,
            kind: const Value(OcptShootingBlockKind.preparation),
          )
          .okOrFail;

      expect((await readBlock(blockId)).sceneId, isNull);
    });

    test("updateBlock refuses to name a scene on a block that isn't a hold", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final sceneId = await createScene("scene-1");

      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.meal)
          .valueOrFail);

      await scheduleService
          .updateBlock(database: database, blockId: blockId, sceneId: Value(sceneId))
          .okOrFail;

      expect((await readBlock(blockId)).sceneId, isNull);
    });

    test("updateBlock writes the crew note, independently of the private notes", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;

      final blockId = (await scheduleService
          .createBlock(
            database: database,
            slotId: slotId,
            kind: OcptShootingBlockKind.meal,
            notes: "Not for the crew's eyes",
          )
          .valueOrFail);

      await scheduleService
          .updateBlock(
            database: database,
            blockId: blockId,
            crewNote: const Value("The generator arrives during this move"),
          )
          .okOrFail;

      final block = await readBlock(blockId);
      expect(block.crewNote, "The generator arrives during this move");
      expect(block.notes, "Not for the crew's eyes");
    });

    test("reorderBlock writes exactly one row within a slot's own timetable", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;

      final firstId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.preparation)
          .valueOrFail);
      final secondId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.meal)
          .valueOrFail);

      await scheduleService
          .reorderBlock(database: database, blockId: secondId, newPosition: 0)
          .okOrFail;

      final blocks = await readAllBlocks(dayId);
      expect(blocks.map((row) => row.id), [secondId, firstId]);
    });
  });

  group("guests and events", () {
    setUp(insertScreenplay);

    test("addSlotGuest mints a row naming a person, reloaded by loadSchedule", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);

      final guestId = await scheduleService
          .addSlotGuest(
            database: database,
            slotId: slotId,
            personId: personId,
            reason: "Ancien propriétaire",
          )
          .maybeValueOrFail;

      expect(guestId, isNotNull);
      final snapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      final guest = snapshot.slotsByDayId[dayId]!.single.guests.single;
      expect(guest.id, guestId);
      expect(guest.personId, personId);
      expect(guest.freeName, "");
      expect(guest.reason, "Ancien propriétaire");
    });

    test("addSlotGuest mints a row naming a free-text name", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;

      final guestId = await scheduleService
          .addSlotGuest(database: database, slotId: slotId, freeName: "Une journaliste")
          .maybeValueOrFail;

      final guests = await readAllGuests(slotId);
      expect(guests.single.id, guestId);
      expect(guests.single.personId, isNull);
      expect(guests.single.freeName, "Une journaliste");
    });

    test("addSlotGuest refuses naming both a person and a free name", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);

      final guestId = await scheduleService
          .addSlotGuest(
            database: database,
            slotId: slotId,
            personId: personId,
            freeName: "Une journaliste",
          )
          .maybeValueOrFail;

      expect(guestId, isNull);
      expect(await readAllGuests(slotId), isEmpty);
    });

    test("addSlotGuest refuses naming neither a person nor a free name", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;

      final guestId = await scheduleService
          .addSlotGuest(database: database, slotId: slotId)
          .maybeValueOrFail;

      expect(guestId, isNull);
      expect(await readAllGuests(slotId), isEmpty);
    });

    test("updateSlotGuest may move a guest from a person to a free name, and back", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      final guestId = (await scheduleService
          .addSlotGuest(database: database, slotId: slotId, personId: personId)
          .valueOrFail);

      await scheduleService
          .updateSlotGuest(
            database: database,
            guestId: guestId,
            personId: const Value(null),
            freeName: const Value("Une journaliste"),
          )
          .okOrFail;
      var guest = (await readAllGuests(slotId)).single;
      expect(guest.personId, isNull);
      expect(guest.freeName, "Une journaliste");

      await scheduleService
          .updateSlotGuest(
            database: database,
            guestId: guestId,
            personId: Value(personId),
            freeName: const Value(""),
          )
          .okOrFail;
      guest = (await readAllGuests(slotId)).single;
      expect(guest.personId, personId);
      expect(guest.freeName, "");
    });

    test(
      "updateSlotGuest refuses a write that would leave both halves of the discriminator set",
      () async {
        final dayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 10))
            .valueOrFail);
        final slotId = (await readLiveSlots(dayId)).single.id;
        final personId = (await peopleService.createPerson(database: database).valueOrFail);
        final guestId = (await scheduleService
            .addSlotGuest(database: database, slotId: slotId, personId: personId)
            .valueOrFail);

        await scheduleService
            .updateSlotGuest(
              database: database,
              guestId: guestId,
              freeName: const Value("Une journaliste"),
            )
            .okOrFail;

        final guest = (await readAllGuests(slotId)).single;
        expect(guest.personId, personId);
        expect(guest.freeName, "");
      },
    );

    test(
      "updateSlotGuest refuses a write that would leave both halves of the discriminator empty",
      () async {
        final dayId = (await scheduleService
            .createDay(database: database, date: DateTime(2026, 8, 10))
            .valueOrFail);
        final slotId = (await readLiveSlots(dayId)).single.id;
        final guestId = (await scheduleService
            .addSlotGuest(database: database, slotId: slotId, freeName: "Une journaliste")
            .valueOrFail);

        await scheduleService
            .updateSlotGuest(database: database, guestId: guestId, freeName: const Value(""))
            .okOrFail;

        final guest = (await readAllGuests(slotId)).single;
        expect(guest.freeName, "Une journaliste");
      },
    );

    test("deleteSlotGuest tombstones the row", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final guestId = (await scheduleService
          .addSlotGuest(database: database, slotId: slotId, freeName: "Le maire")
          .valueOrFail);

      await scheduleService.deleteSlotGuest(database: database, guestId: guestId).okOrFail;

      expect((await readAllGuests(slotId)).single.isDeleted, isTrue);
    });

    test("createDayEvent mints a row, reloaded by loadSchedule ordered by minute", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);

      await scheduleService
          .createDayEvent(
            database: database,
            dayId: dayId,
            minute: 1020,
            label: "Feu d'artifice du village",
          )
          .maybeValueOrFail;
      await scheduleService
          .createDayEvent(
            database: database,
            dayId: dayId,
            minute: 300,
            label: "Passage du cortège",
          )
          .maybeValueOrFail;

      final snapshot = await scheduleService.loadSchedule(database: database).valueOrFail;
      expect(snapshot.eventsByDayId[dayId]!.map((event) => event.label), [
        "Passage du cortège",
        "Feu d'artifice du village",
      ]);
    });

    test("updateDayEvent updates the fields passed, leaving the rest alone", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final eventId = (await scheduleService
          .createDayEvent(
            database: database,
            dayId: dayId,
            minute: 1020,
            label: "Feu d'artifice du village",
          )
          .valueOrFail);

      await scheduleService
          .updateDayEvent(database: database, eventId: eventId, minute: const Value(1080))
          .okOrFail;

      final event = (await readAllEvents(dayId)).single;
      expect(event.minute, 1080);
      expect(event.label, "Feu d'artifice du village");
    });

    test("deleteDayEvent tombstones the row", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final eventId = (await scheduleService
          .createDayEvent(database: database, dayId: dayId, minute: 1020)
          .valueOrFail);

      await scheduleService.deleteDayEvent(database: database, eventId: eventId).okOrFail;

      expect((await readAllEvents(dayId)).single.isDeleted, isTrue);
    });
  });
}
