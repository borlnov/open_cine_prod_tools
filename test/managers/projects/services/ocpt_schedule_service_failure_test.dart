// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import '../../../ocpt_result_expectations.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String dayId,
  String slotA,
  String slotB,
  String mealBlock,
  String secondMealBlock,
  String auditionBlock,
  String crewMember,
  String castRole,
  String guest,
  String firstCandidate,
  String secondCandidate,
  String candidacy,
  String event,
  String shotId,
  String roleId,
  String personId,
});

/// One public method of the service, called with the rows of a [_Fixture].
typedef _Call = Future<MixinResultStatus> Function(_Fixture rows);

/// The tables the schedule service writes.
const _scheduleTables = [
  "shooting_days",
  "shooting_slots",
  "shooting_slot_crew",
  "shooting_slot_cast",
  "shooting_slot_guests",
  "shooting_block_candidates",
  "shooting_day_blocks",
  "shooting_day_events",
];

/// Run the tests of what [OcptScheduleService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptScheduleService(logger: const SilentLogger(), deviceId: testDeviceId);
  final peopleService = OcptPeopleService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
    assetsService: OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId),
    roleCandidatesService: OcptRoleCandidatesService(
      logger: const SilentLogger(),
      deviceId: testDeviceId,
    ),
  );

  late OcptProjectDatabase database;
  late _Fixture rows;

  /// Insert the rows every case works on, through the service.
  Future<_Fixture> seed() async {
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: "screenplay-1",
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
    await database
        .into(database.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(id: "shot-1", screenplayId: "screenplay-1", position: 0),
        );
    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(id: "role-1", name: "LÉA", kind: OcptRoleKind.silent),
        );
    final personId = (await peopleService.createPerson(database: database))!;
    await database
        .into(database.ocptRoleCandidatesTable)
        .insert(
          OcptRoleCandidatesTableCompanion.insert(
            id: "candidacy-1",
            roleId: "role-1",
            personId: personId,
          ),
        );

    final dayId = await service
        .createDay(database: database, date: DateTime(2026, 8, 10))
        .valueOrFail;
    final slotA =
        (await service.loadSchedule(database: database).valueOrFail).slotsByDayId[dayId]!.single.id;
    final slotB = await service
        .createSlot(database: database, shootingDayId: dayId, anchorMinute: 720)
        .valueOrFail;
    final mealBlock = await service
        .createBlock(database: database, slotId: slotA, kind: OcptShootingBlockKind.meal)
        .valueOrFail;
    final secondMealBlock = await service
        .createBlock(database: database, slotId: slotA, kind: OcptShootingBlockKind.meal)
        .valueOrFail;
    final auditionBlock = await service
        .createBlock(database: database, slotId: slotA, kind: OcptShootingBlockKind.audition)
        .valueOrFail;
    final crewMember = await service
        .addSlotCrewMember(database: database, slotId: slotA, personId: personId)
        .valueOrFail;
    final castRole = await service
        .addSlotCastRole(database: database, slotId: slotA, roleId: "role-1")
        .valueOrFail;
    final guest = await service
        .addSlotGuest(database: database, slotId: slotA, freeName: "Guest")
        .valueOrFail;
    final firstCandidate = await service
        .addBlockCandidate(
          database: database,
          blockId: auditionBlock,
          roleCandidateId: "candidacy-1",
        )
        .valueOrFail;
    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(id: "role-2", name: "MAX", kind: OcptRoleKind.silent),
        );
    await database
        .into(database.ocptRoleCandidatesTable)
        .insert(
          OcptRoleCandidatesTableCompanion.insert(
            id: "candidacy-2",
            roleId: "role-2",
            personId: personId,
          ),
        );
    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(id: "role-3", name: "ZOÉ", kind: OcptRoleKind.silent),
        );
    await database
        .into(database.ocptRoleCandidatesTable)
        .insert(
          OcptRoleCandidatesTableCompanion.insert(
            id: "candidacy-3",
            roleId: "role-3",
            personId: personId,
          ),
        );
    final secondCandidate = await service
        .addBlockCandidate(
          database: database,
          blockId: auditionBlock,
          roleCandidateId: "candidacy-2",
        )
        .valueOrFail;
    final event = await service
        .createDayEvent(database: database, dayId: dayId, minute: 600)
        .valueOrFail;

    return (
      dayId: dayId,
      slotA: slotA,
      slotB: slotB,
      mealBlock: mealBlock,
      secondMealBlock: secondMealBlock,
      auditionBlock: auditionBlock,
      crewMember: crewMember,
      castRole: castRole,
      guest: guest,
      firstCandidate: firstCandidate,
      secondCandidate: secondCandidate,
      candidacy: "candidacy-3",
      event: event,
      shotId: "shot-1",
      roleId: "role-2",
      personId: personId,
    );
  }

  setUp(() async {
    database = OcptProjectDatabase.memory();
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every write of the service, with an input that changes a row.
  final writes = <String, _Call>{
    "createDay": (r) async =>
        (await service.createDay(database: database, date: DateTime(2026, 9, 3))).status,
    "updateDay": (r) async => (await service.updateDay(
      database: database,
      dayId: r.dayId,
      notes: const Value("x"),
    )).status,
    "duplicateDay": (r) async => (await service.duplicateDay(
      database: database,
      sourceDayId: r.dayId,
      date: DateTime(2026, 9, 2),
    )).status,
    "deleteDay": (r) async => (await service.deleteDay(database: database, dayId: r.dayId)).status,
    "createSlot": (r) async => (await service.createSlot(
      database: database,
      shootingDayId: r.dayId,
      anchorMinute: 900,
    )).status,
    "updateSlot": (r) async => (await service.updateSlot(
      database: database,
      slotId: r.slotA,
      label: const Value("x"),
    )).status,
    "setSlotAnchor": (r) async => (await service.setSlotAnchor(
      database: database,
      slotId: r.slotB,
      edge: OcptShootingSlotAnchorEdge.start,
      minute: 800,
    )).status,
    "reorderSlot": (r) async =>
        (await service.reorderSlot(database: database, slotId: r.slotB, newPosition: 0)).status,
    "deleteSlot": (r) async =>
        (await service.deleteSlot(database: database, slotId: r.slotA)).status,
    "addSlotCrewMember": (r) async => (await service.addSlotCrewMember(
      database: database,
      slotId: r.slotB,
      personId: r.personId,
    )).status,
    "updateSlotCrewMember": (r) async => (await service.updateSlotCrewMember(
      database: database,
      crewMemberId: r.crewMember,
      notes: const Value("x"),
    )).status,
    "removeSlotCrewMember": (r) async =>
        (await service.removeSlotCrewMember(database: database, crewMemberId: r.crewMember)).status,
    "addSlotCastRole": (r) async => (await service.addSlotCastRole(
      database: database,
      slotId: r.slotB,
      roleId: r.roleId,
    )).status,
    "updateSlotCastRole": (r) async => (await service.updateSlotCastRole(
      database: database,
      castRoleId: r.castRole,
      notes: const Value("x"),
    )).status,
    "removeSlotCastRole": (r) async =>
        (await service.removeSlotCastRole(database: database, castRoleId: r.castRole)).status,
    "addSlotGuest": (r) async =>
        (await service.addSlotGuest(database: database, slotId: r.slotB, freeName: "Other")).status,
    "updateSlotGuest": (r) async => (await service.updateSlotGuest(
      database: database,
      guestId: r.guest,
      notes: const Value("x"),
    )).status,
    "deleteSlotGuest": (r) async =>
        (await service.deleteSlotGuest(database: database, guestId: r.guest)).status,
    "addBlockCandidate": (r) async => (await service.addBlockCandidate(
      database: database,
      blockId: r.auditionBlock,
      roleCandidateId: r.candidacy,
    )).status,
    "updateBlockCandidate": (r) async => (await service.updateBlockCandidate(
      database: database,
      blockCandidateId: r.firstCandidate,
      notes: const Value("x"),
    )).status,
    "reorderBlockCandidate": (r) async => (await service.reorderBlockCandidate(
      database: database,
      blockCandidateId: r.secondCandidate,
      newPosition: 0,
    )).status,
    "removeBlockCandidate": (r) async => (await service.removeBlockCandidate(
      database: database,
      blockCandidateId: r.firstCandidate,
    )).status,
    "createDayEvent": (r) async =>
        (await service.createDayEvent(database: database, dayId: r.dayId, minute: 700)).status,
    "updateDayEvent": (r) async => (await service.updateDayEvent(
      database: database,
      eventId: r.event,
      label: const Value("x"),
    )).status,
    "deleteDayEvent": (r) async =>
        (await service.deleteDayEvent(database: database, eventId: r.event)).status,
    "placeShot": (r) async =>
        (await service.placeShot(database: database, slotId: r.slotB, shotId: r.shotId)).status,
    "deleteBlock": (r) async =>
        (await service.deleteBlock(database: database, blockId: r.mealBlock)).status,
    "createBlock": (r) async => (await service.createBlock(
      database: database,
      slotId: r.slotB,
      kind: OcptShootingBlockKind.pause,
    )).status,
    "updateBlock": (r) async => (await service.updateBlock(
      database: database,
      blockId: r.mealBlock,
      label: const Value("x"),
    )).status,
    "reorderBlock": (r) async => (await service.reorderBlock(
      database: database,
      blockId: r.secondMealBlock,
      newPosition: 0,
    )).status,
    "moveBlockToSlot": (r) async => (await service.moveBlockToSlot(
      database: database,
      blockId: r.mealBlock,
      targetSlotId: r.slotB,
      newPosition: 0,
    )).status,
  };

  /// Every read of the service.
  final reads = <String, _Call>{
    "loadSchedule": (r) async => (await service.loadSchedule(database: database)).status,
    "loadShotPlacements": (r) async =>
        (await service.loadShotPlacements(database: database)).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [..._scheduleTables, "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  group("every write answers a database error when the database refuses it", () {
    for (final entry in writes.entries) {
      test("${entry.key} writes nothing", () async {
        // The call must change something when nothing is wrong, or the refusal proves nothing.
        final before = await snapshot();
        expect(await entry.value(rows), OcptDatabaseStatus.ok);
        expect(await snapshot(), isNot(before), reason: "the input changes no row");
        await database.close();
        database = OcptProjectDatabase.memory();
        rows = await seed();

        final untouched = await snapshot();
        for (final table in _scheduleTables) {
          for (final verb in ["INSERT", "UPDATE"]) {
            await database.customStatement(
              "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
              "BEGIN SELECT RAISE(ABORT, 'refused'); END",
            );
          }
        }

        final status = await entry.value(rows);

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every method answers a database error when its tables are gone", () {
    for (final entry in {...writes, ...reads}.entries) {
      test("${entry.key} answers a database error", () async {
        for (final table in _scheduleTables) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(rows), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("on the database of a version being previewed", () {
    late OcptProjectDatabase preview;

    setUp(() => preview = OcptProjectDatabase.memory(isPreview: true));

    tearDown(() => preview.close());

    test("every write is refused as a call that went well, and writes nothing", () async {
      final previous = database;
      database = preview;

      for (final entry in writes.entries) {
        expect(await entry.value(rows), OcptDatabaseStatus.ok, reason: entry.key);
      }

      database = previous;
      for (final table in _scheduleTables) {
        expect(await preview.customSelect("SELECT * FROM $table").get(), isEmpty, reason: table);
      }
    });

    test("a write that answers an id answers none", () async {
      expect(
        await service.createDay(database: preview, date: DateTime(2026, 8, 10)).maybeValueOrFail,
        isNull,
      );
      expect(
        await service
            .createSlot(database: preview, shootingDayId: rows.dayId, anchorMinute: 480)
            .maybeValueOrFail,
        isNull,
      );
    });

    test("setSlotAnchor answers that it did not anchor", () async {
      expect(
        await service
            .setSlotAnchor(
              database: preview,
              slotId: rows.slotA,
              edge: OcptShootingSlotAnchorEdge.start,
              minute: 480,
            )
            .valueOrFail,
        isFalse,
      );
    });

    test("a read is not refused", () async {
      expect(await service.loadSchedule(database: preview).valueOrFail, isNotNull);
      expect(await service.loadShotPlacements(database: preview).valueOrFail, isEmpty);
    });
  });
}
