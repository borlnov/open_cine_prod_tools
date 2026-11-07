// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import '../../../ocpt_result_expectations.dart';

/// The fixed device id every stamp this file's writes carry.
const _deviceId = "device-1";

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String personA,
  String personB,
  String positionA,
  String positionB,
  String skillA,
  String skillB,
  String unavailability,
});

/// Answer with the fixed device id.
Future<String> _testDeviceId() async => _deviceId;

/// Run the tests of what [OcptPeopleService] answers when the database fails or refuses.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const assetsService = OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId);
  const roleCandidatesService = OcptRoleCandidatesService(
    logger: SilentLogger(),
    deviceId: _testDeviceId,
  );
  const roleIndexService = OcptRoleIndexService(
    logger: SilentLogger(),
    elementsService: OcptElementsService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: _testDeviceId,
    ),
    roleCandidatesService: roleCandidatesService,
    deviceId: _testDeviceId,
  );
  const peopleService = OcptPeopleService(
    logger: SilentLogger(),
    deviceId: _testDeviceId,
    assetsService: assetsService,
    roleCandidatesService: roleCandidatesService,
  );

  late OcptProjectDatabase database;
  late _Fixture rows;

  const tables = [
    "people",
    "person_positions",
    "person_skills",
    "person_unavailabilities",
    "assets",
    "role_candidates",
    "local_erasures",
  ];

  /// Two people, the first with two positions, two skills, one unavailability, a photo, an image
  /// rights document and a candidacy for a role.
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
    final a = await peopleService.createPerson(database: database).valueOrFail;
    final b = await peopleService.createPerson(database: database).valueOrFail;
    final positionA = await peopleService
        .addPosition(database: database, personId: a, positionId: "sound", customLabel: "")
        .valueOrFail;
    final positionB = await peopleService
        .addPosition(database: database, personId: a, positionId: "light", customLabel: "")
        .valueOrFail;
    final skillA = await peopleService
        .addSkill(database: database, personId: a, label: "Driving licence")
        .valueOrFail;
    final skillB = await peopleService
        .addSkill(database: database, personId: a, label: "French")
        .valueOrFail;
    final unavailability = await peopleService
        .addUnavailability(
          database: database,
          personId: a,
          startDate: DateTime(2026, 5),
          endDate: DateTime(2026, 5, 2),
          slot: OcptDayPartSlot.fullDay,
          reason: "Holiday",
        )
        .valueOrFail;
    await peopleService
        .setPersonPhoto(database: database, personId: a, path: "/photos/a.jpg")
        .valueOrFail;
    await peopleService
        .setImageRightsDocument(database: database, personId: a, path: "/docs/release.pdf")
        .valueOrFail;
    final roleId = await roleIndexService
        .addRole(
          database: database,
          screenplayId: "screenplay-1",
          name: "DRIVER",
          kind: OcptRoleKind.silent,
        )
        .valueOrFail;
    await roleCandidatesService
        .addCandidate(database: database, roleId: roleId, personId: a)
        .valueOrFail;

    return (
      personA: a,
      personB: b,
      positionA: positionA,
      positionB: positionB,
      skillA: skillA,
      skillB: skillB,
      unavailability: unavailability,
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
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "createPerson": (r) async => (await peopleService.createPerson(database: database)).status,
    "updatePerson": (r) async => (await peopleService.updatePerson(
      database: database,
      personId: r.personB,
      firstName: const Value("Clara"),
    )).status,
    "deletePerson": (r) async =>
        (await peopleService.deletePerson(database: database, personId: r.personA)).status,
    "setPersonPhoto": (r) async => (await peopleService.setPersonPhoto(
      database: database,
      personId: r.personA,
      path: "/photos/other.jpg",
    )).status,
    "clearPersonPhoto": (r) async =>
        (await peopleService.clearPersonPhoto(database: database, personId: r.personA)).status,
    "setImageRightsDocument": (r) async => (await peopleService.setImageRightsDocument(
      database: database,
      personId: r.personA,
      path: "/docs/other.pdf",
    )).status,
    "clearImageRightsDocument": (r) async => (await peopleService.clearImageRightsDocument(
      database: database,
      personId: r.personA,
    )).status,
    "reorderPerson": (r) async => (await peopleService.reorderPerson(
      database: database,
      personId: r.personB,
      newPosition: 0,
    )).status,
    "addPosition": (r) async => (await peopleService.addPosition(
      database: database,
      personId: r.personB,
      positionId: "camera",
      customLabel: "",
    )).status,
    "updatePosition": (r) async => (await peopleService.updatePosition(
      database: database,
      id: r.positionA,
      customLabel: const Value("Boom"),
    )).status,
    "removePosition": (r) async =>
        (await peopleService.removePosition(database: database, id: r.positionA)).status,
    "reorderPositions": (r) async => (await peopleService.reorderPositions(
      database: database,
      personId: r.personA,
      orderedIds: [r.positionB, r.positionA],
    )).status,
    "addSkill": (r) async => (await peopleService.addSkill(
      database: database,
      personId: r.personB,
      label: "Sailing",
    )).status,
    "updateSkill": (r) async => (await peopleService.updateSkill(
      database: database,
      id: r.skillA,
      label: "Driving licence B",
    )).status,
    "removeSkill": (r) async =>
        (await peopleService.removeSkill(database: database, id: r.skillA)).status,
    "reorderSkills": (r) async => (await peopleService.reorderSkills(
      database: database,
      personId: r.personA,
      orderedIds: [r.skillB, r.skillA],
    )).status,
    "addUnavailability": (r) async => (await peopleService.addUnavailability(
      database: database,
      personId: r.personB,
      startDate: DateTime(2026, 6),
      endDate: DateTime(2026, 6, 2),
      slot: OcptDayPartSlot.morning,
      reason: "Exam",
    )).status,
    "updateUnavailability": (r) async => (await peopleService.updateUnavailability(
      database: database,
      id: r.unavailability,
      reason: const Value("Illness"),
    )).status,
    "removeUnavailability": (r) async =>
        (await peopleService.removeUnavailability(database: database, id: r.unavailability)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadPeople": (r) async => (await peopleService.loadPeople(database: database)).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [...tables, "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Refuse the [verbs] on [table], on the rows [when] selects when it is given.
  Future<void> refuse(String table, List<String> verbs, {String? when}) async {
    for (final verb in verbs) {
      await database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "${when == null ? '' : 'WHEN $when '}BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
    }
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
        for (final table in tables) {
          await refuse(table, ["INSERT", "UPDATE"]);
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
        for (final table in tables) {
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
      final untouched = await snapshot();

      for (final entry in writes.entries) {
        expect(await entry.value(rows), OcptDatabaseStatus.ok, reason: entry.key);
      }

      expect(await snapshot(), untouched);
      database = previous;
    });

    test("a write that answers an id answers none", () async {
      final created = <String?>[
        await peopleService.createPerson(database: preview).maybeValueOrFail,
        await peopleService
            .setPersonPhoto(database: preview, personId: rows.personA, path: "/p.jpg")
            .maybeValueOrFail,
        await peopleService
            .setImageRightsDocument(database: preview, personId: rows.personA, path: "/p.pdf")
            .maybeValueOrFail,
        await peopleService
            .addPosition(
              database: preview,
              personId: rows.personA,
              positionId: "sound",
              customLabel: "",
            )
            .maybeValueOrFail,
        await peopleService
            .addSkill(database: preview, personId: rows.personA, label: "French")
            .maybeValueOrFail,
        await peopleService
            .addUnavailability(
              database: preview,
              personId: rows.personA,
              startDate: DateTime(2026, 6),
              endDate: DateTime(2026, 6, 2),
              slot: OcptDayPartSlot.fullDay,
              reason: "",
            )
            .maybeValueOrFail,
      ];

      expect(created, everyElement(isNull));
    });

    test("a read is not refused", () async {
      expect(await peopleService.loadPeople(database: preview).valueOrFail, isEmpty);
    });
  });

  group("a write that touches several rows is one transaction", () {
    /// Refuse the [verbs] on [table], then expect [call] to answer a database error with every
    /// table as it was.
    Future<void> expectNothingKept(
      String table,
      List<String> verbs,
      Future<MixinResultStatus> Function() call, {
      String? when,
    }) async {
      final untouched = await snapshot();
      await refuse(table, verbs, when: when);

      final status = await call();

      expect(status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    }

    for (final (table, verbs) in [
      ("people", ["UPDATE"]),
      ("person_positions", ["UPDATE"]),
      ("person_skills", ["UPDATE"]),
      ("person_unavailabilities", ["UPDATE"]),
      ("assets", ["UPDATE"]),
      ("role_candidates", ["UPDATE"]),
      ("local_erasures", ["INSERT", "UPDATE"]),
    ]) {
      test("an erasure keeps the person whole when $table cannot be written", () async {
        await expectNothingKept(table, verbs, () => writes["deletePerson"]!(rows));
      });
    }

    test("an erasure keeps everything when the second skill cannot be tombstoned", () async {
      await expectNothingKept(
        "person_skills",
        ["UPDATE"],
        () => writes["deletePerson"]!(rows),
        when: "NEW.id = '${rows.skillB}'",
      );
    });

    test("a new photo keeps the old one when the person cannot point at it", () async {
      await expectNothingKept("people", ["UPDATE"], () => writes["setPersonPhoto"]!(rows));
    });

    test("a new photo is not kept when the old one cannot be dropped", () async {
      await expectNothingKept("assets", ["UPDATE"], () => writes["setPersonPhoto"]!(rows));
    });

    test("a cleared photo keeps its asset when the person cannot be written", () async {
      await expectNothingKept("people", ["UPDATE"], () => writes["clearPersonPhoto"]!(rows));
    });

    test("a new release keeps the old one when the person cannot point at it", () async {
      await expectNothingKept("people", ["UPDATE"], () => writes["setImageRightsDocument"]!(rows));
    });
  });
}
