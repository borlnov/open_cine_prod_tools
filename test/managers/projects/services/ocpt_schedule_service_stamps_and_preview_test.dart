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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of the schedule service stamps and preview.
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

  /// Every candidate row of block [blockId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingBlockCandidateRow>> readAllBlockCandidates(String blockId) =>
      (database.select(database.ocptShootingBlockCandidatesTable)
            ..where((row) => row.blockId.equals(blockId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Inserts a candidacy — somebody seen for a part — satisfying the foreign keys
  /// `shooting_block_candidates` needs, without going through
  /// `OcptRoleCandidatesService`, whose own retained rule this service has no business exercising.
  Future<String> createCandidacy(
    String id, {
    required String roleId,
    required String personId,
  }) async {
    await database
        .into(database.ocptRoleCandidatesTable)
        .insert(
          OcptRoleCandidatesTableCompanion.insert(id: id, roleId: roleId, personId: personId),
        );
    return id;
  }

  /// Every event row of day [dayId], tombstoned or not, in `sortKey` order.
  Future<List<OcptShootingDayEventRow>> readAllEvents(String dayId) =>
      (database.select(database.ocptShootingDayEventsTable)
            ..where((row) => row.shootingDayId.equals(dayId))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptBreakdownService`'s own stamping tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

  group("row-field-version stamps", () {
    setUp(insertScreenplay);

    test("createDay stamps every column of the new day", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);

      final stamps = await readStamps();
      final day = await readDay(dayId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shooting_days/$dayId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(day.toJson().length));
      for (final column in day.toJson().keys) {
        final stamp = ownStamps["shooting_days/$dayId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("deleteDay stamps isDeleted on the day", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService.deleteDay(database: database, dayId: dayId).okOrFail;

      final stamps = await readStamps();
      expect(stamps["shooting_days/$dayId/isDeleted"]!.version, 1);
    });

    test("createSlot stamps every column of the new row", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final slotId = (await scheduleService
          .createSlot(database: database, shootingDayId: dayId, anchorMinute: 600)
          .valueOrFail);

      final stamps = await readStamps();
      final slot = (await readAllSlots(dayId)).firstWhere((row) => row.id == slotId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shooting_slots/$slotId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(slot.toJson().length));
      for (final column in slot.toJson().keys) {
        expect(
          ownStamps["shooting_slots/$slotId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("updateSlot stamps only the columns that actually changed", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService
          .updateSlot(database: database, slotId: slotId, label: const Value("Matin"))
          .okOrFail;

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("shooting_slots/$slotId/")).toSet();
      expect(ownKeys, {"shooting_slots/$slotId/label"});
    });

    test("addSlotCrewMember stamps every column of the new row", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final crewId = (await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .valueOrFail);

      final stamps = await readStamps();
      final crew = (await readAllCrew(slotId)).firstWhere((row) => row.id == crewId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shooting_slot_crew/$crewId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(crew.toJson().length));
      for (final column in crew.toJson().keys) {
        expect(
          ownStamps["shooting_slot_crew/$crewId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("removeSlotCrewMember stamps isDeleted", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      final crewId = (await scheduleService
          .addSlotCrewMember(database: database, slotId: slotId, personId: personId)
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService.removeSlotCrewMember(database: database, crewMemberId: crewId).okOrFail;

      final stamps = await readStamps();
      expect(stamps.keys.where((key) => key.startsWith("shooting_slot_crew/$crewId/")).toSet(), {
        "shooting_slot_crew/$crewId/isDeleted",
      });
    });

    test("addSlotCastRole stamps every column of the new row", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final roleId = await createRole("role-1");
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final castId = (await scheduleService
          .addSlotCastRole(database: database, slotId: slotId, roleId: roleId)
          .valueOrFail);

      final stamps = await readStamps();
      final cast = (await readAllCast(slotId)).firstWhere((row) => row.id == castId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shooting_slot_cast/$castId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(cast.toJson().length));
      for (final column in cast.toJson().keys) {
        expect(
          ownStamps["shooting_slot_cast/$castId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("removeSlotCastRole stamps isDeleted", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final roleId = await createRole("role-1");
      final castId = (await scheduleService
          .addSlotCastRole(database: database, slotId: slotId, roleId: roleId)
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService.removeSlotCastRole(database: database, castRoleId: castId).okOrFail;

      final stamps = await readStamps();
      expect(stamps.keys.where((key) => key.startsWith("shooting_slot_cast/$castId/")).toSet(), {
        "shooting_slot_cast/$castId/isDeleted",
      });
    });

    test("addSlotGuest stamps every column of the new row", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final guestId = (await scheduleService
          .addSlotGuest(database: database, slotId: slotId, freeName: "Le maire")
          .valueOrFail);

      final stamps = await readStamps();
      final guest = (await readAllGuests(slotId)).firstWhere((row) => row.id == guestId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shooting_slot_guests/$guestId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(guest.toJson().length));
      for (final column in guest.toJson().keys) {
        expect(
          ownStamps["shooting_slot_guests/$guestId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("deleteSlotGuest stamps isDeleted", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final guestId = (await scheduleService
          .addSlotGuest(database: database, slotId: slotId, freeName: "Le maire")
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService.deleteSlotGuest(database: database, guestId: guestId).okOrFail;

      final stamps = await readStamps();
      expect(stamps.keys.where((key) => key.startsWith("shooting_slot_guests/$guestId/")).toSet(), {
        "shooting_slot_guests/$guestId/isDeleted",
      });
    });

    test("placeShot stamps every column of the new block", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final shotId = await createShot("shot-1");
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final blockId = (await scheduleService
          .placeShot(database: database, slotId: slotId, shotId: shotId)
          .valueOrFail);

      final stamps = await readStamps();
      final block = await readBlock(blockId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shooting_day_blocks/$blockId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(block.toJson().length));
      for (final column in block.toJson().keys) {
        expect(
          ownStamps["shooting_day_blocks/$blockId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("updateBlock stamps only the columns that actually changed", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.meal)
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService
          .updateBlock(
            database: database,
            blockId: blockId,
            crewNote: const Value("The generator arrives during this move"),
          )
          .okOrFail;

      final stamps = await readStamps();
      final ownKeys = stamps.keys
          .where((key) => key.startsWith("shooting_day_blocks/$blockId/"))
          .toSet();
      expect(ownKeys, {"shooting_day_blocks/$blockId/crewNote"});
    });

    test("deleteBlock stamps isDeleted", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.meal)
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService.deleteBlock(database: database, blockId: blockId).okOrFail;

      final stamps = await readStamps();
      expect(stamps["shooting_day_blocks/$blockId/isDeleted"]!.version, 1);
    });

    test("createDayEvent stamps every column of the new row", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final eventId = (await scheduleService
          .createDayEvent(
            database: database,
            dayId: dayId,
            minute: 1020,
            label: "Feu d'artifice du village",
          )
          .valueOrFail);

      final stamps = await readStamps();
      final event = (await readAllEvents(dayId)).firstWhere((row) => row.id == eventId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shooting_day_events/$eventId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(event.toJson().length));
      for (final column in event.toJson().keys) {
        expect(
          ownStamps["shooting_day_events/$eventId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("deleteDayEvent stamps isDeleted", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final eventId = (await scheduleService
          .createDayEvent(database: database, dayId: dayId, minute: 1020)
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService.deleteDayEvent(database: database, eventId: eventId).okOrFail;

      final stamps = await readStamps();
      expect(stamps["shooting_day_events/$eventId/isDeleted"]!.version, 1);
    });

    test("addBlockCandidate stamps every column of the new row", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final roleId = await createRole("role-1");
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      final candidacyId = await createCandidacy("candidacy-1", roleId: roleId, personId: personId);
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final convocationId = (await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .valueOrFail);

      final stamps = await readStamps();
      final candidate = (await readAllBlockCandidates(
        blockId,
      )).firstWhere((row) => row.id == convocationId);
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shooting_block_candidates/$convocationId/"))
            entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(candidate.toJson().length));
      for (final column in candidate.toJson().keys) {
        expect(
          ownStamps["shooting_block_candidates/$convocationId/$column"],
          isNotNull,
          reason: "$column should be stamped",
        );
      }
    });

    test("removeBlockCandidate stamps isDeleted", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final roleId = await createRole("role-1");
      final personId = (await peopleService.createPerson(database: database).valueOrFail);
      final candidacyId = await createCandidacy("candidacy-1", roleId: roleId, personId: personId);
      final blockId = (await scheduleService
          .createBlock(database: database, slotId: slotId, kind: OcptShootingBlockKind.audition)
          .valueOrFail);
      final convocationId = (await scheduleService
          .addBlockCandidate(database: database, blockId: blockId, roleCandidateId: candidacyId)
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await scheduleService
          .removeBlockCandidate(database: database, blockCandidateId: convocationId)
          .okOrFail;

      final stamps = await readStamps();
      expect(
        stamps.keys
            .where((key) => key.startsWith("shooting_block_candidates/$convocationId/"))
            .toSet(),
        {"shooting_block_candidates/$convocationId/isDeleted"},
      );
    });

    test("tombstoneShotBlocks stamps isDeleted on shooting_day_blocks", () async {
      final dayId = (await scheduleService
          .createDay(database: database, date: DateTime(2026, 8, 10))
          .valueOrFail);
      final slotId = (await readLiveSlots(dayId)).single.id;
      final shotId = await createShot("shot-1");
      final blockId = (await scheduleService
          .placeShot(database: database, slotId: slotId, shotId: shotId)
          .valueOrFail);
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final stamps = await OcptRowStampService.seed(database: database, deviceId: "device-x");
      await scheduleService.tombstoneShotBlocks(
        database: database,
        shotIds: [shotId],
        stamps: stamps,
      );
      await stamps.flush(database);

      final readBackStamps = await readStamps();
      expect(readBackStamps["shooting_day_blocks/$blockId/isDeleted"]!.version, 1);
      expect(readBackStamps["shooting_day_blocks/$blockId/isDeleted"]!.deviceId, "device-x");
    });
  });

  group("read-only preview", () {
    test("every write is refused on a preview database", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      addTearDown(preview.close);

      expect(
        await scheduleService
            .createDay(database: preview, date: DateTime(2026, 8, 10))
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService.updateDay(database: preview, dayId: "missing-day").okOrFail;
      await scheduleService.deleteDay(database: preview, dayId: "missing-day").okOrFail;
      expect(
        await scheduleService
            .duplicateDay(
              database: preview,
              sourceDayId: "missing-day",
              date: DateTime(2026, 8, 20),
            )
            .maybeValueOrFail,
        isNull,
      );

      expect(
        await scheduleService
            .createSlot(database: preview, shootingDayId: "missing-day", anchorMinute: 480)
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService.updateSlot(database: preview, slotId: "missing-slot").okOrFail;
      expect(
        await scheduleService
            .setSlotAnchor(
              database: preview,
              slotId: "missing-slot",
              edge: OcptShootingSlotAnchorEdge.start,
              minute: 480,
            )
            .valueOrFail,
        isFalse,
      );
      await scheduleService
          .reorderSlot(database: preview, slotId: "missing-slot", newPosition: 0)
          .okOrFail;
      await scheduleService.deleteSlot(database: preview, slotId: "missing-slot").okOrFail;

      expect(
        await scheduleService
            .addSlotCrewMember(
              database: preview,
              slotId: "missing-slot",
              personId: "missing-person",
            )
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService
          .updateSlotCrewMember(database: preview, crewMemberId: "missing-crew")
          .okOrFail;
      await scheduleService
          .removeSlotCrewMember(database: preview, crewMemberId: "missing-crew")
          .okOrFail;

      expect(
        await scheduleService
            .addSlotCastRole(database: preview, slotId: "missing-slot", roleId: "missing-role")
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService
          .updateSlotCastRole(database: preview, castRoleId: "missing-cast")
          .okOrFail;
      await scheduleService
          .removeSlotCastRole(database: preview, castRoleId: "missing-cast")
          .okOrFail;

      expect(
        await scheduleService
            .placeShot(database: preview, slotId: "missing-slot", shotId: "missing-shot")
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService.deleteBlock(database: preview, blockId: "missing-block").okOrFail;
      expect(
        await scheduleService
            .createBlock(
              database: preview,
              slotId: "missing-slot",
              kind: OcptShootingBlockKind.meal,
            )
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService.updateBlock(database: preview, blockId: "missing-block").okOrFail;
      await scheduleService
          .reorderBlock(database: preview, blockId: "missing-block", newPosition: 0)
          .okOrFail;
      await scheduleService
          .moveBlockToSlot(
            database: preview,
            blockId: "missing-block",
            targetSlotId: "missing-slot",
            newPosition: 0,
          )
          .okOrFail;

      expect(
        await scheduleService
            .addSlotGuest(database: preview, slotId: "missing-slot", freeName: "Le maire")
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService.updateSlotGuest(database: preview, guestId: "missing-guest").okOrFail;
      await scheduleService.deleteSlotGuest(database: preview, guestId: "missing-guest").okOrFail;

      expect(
        await scheduleService
            .createDayEvent(database: preview, dayId: "missing-day", minute: 1020)
            .maybeValueOrFail,
        isNull,
      );
      await scheduleService.updateDayEvent(database: preview, eventId: "missing-event").okOrFail;
      await scheduleService.deleteDayEvent(database: preview, eventId: "missing-event").okOrFail;

      final snapshot = await scheduleService.loadSchedule(database: preview).valueOrFail;
      expect(snapshot.days, isEmpty);
    });
  });
}
