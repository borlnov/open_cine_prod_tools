// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import '../../../ocpt_result_expectations.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({String first, String second});

/// Run the tests of what [OcptRoleCandidatesService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptRoleCandidatesService(logger: const SilentLogger(), deviceId: testDeviceId);

  const tables = ["role_candidates", "roles"];

  late OcptProjectDatabase database;
  late _Fixture rows;

  /// Insert a role, three people and two candidacies of that role, through the service.
  Future<_Fixture> seed() async {
    await database
        .into(database.ocptRolesTable)
        .insert(
          OcptRolesTableCompanion.insert(id: "role-1", name: "CLARA", kind: OcptRoleKind.speaking),
        );
    for (final id in ["person-1", "person-2", "person-3"]) {
      await database.into(database.ocptPeopleTable).insert(OcptPeopleTableCompanion.insert(id: id));
    }
    final first = await service
        .addCandidate(database: database, roleId: "role-1", personId: "person-1")
        .valueOrFail;
    final second = await service
        .addCandidate(database: database, roleId: "role-1", personId: "person-2")
        .valueOrFail;

    return (first: first, second: second);
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
    "addCandidate": (r) async => (await service.addCandidate(
      database: database,
      roleId: "role-1",
      personId: "person-3",
    )).status,
    "updateCandidate": (r) async => (await service.updateCandidate(
      database: database,
      candidateId: r.first,
      notes: const Value("Very good"),
    )).status,
    "reorderCandidate": (r) async => (await service.reorderCandidate(
      database: database,
      roleId: "role-1",
      candidateId: r.second,
      newPosition: 0,
    )).status,
    "setStatus": (r) async => (await service.setStatus(
      database: database,
      candidateId: r.first,
      status: OcptRoleCandidateStatus.shortlisted,
    )).status,
    "retainCandidate": (r) async =>
        (await service.retainCandidate(database: database, candidateId: r.first)).status,
    "removeCandidate": (r) async =>
        (await service.removeCandidate(database: database, candidateId: r.first)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadCandidatesByRoleId": (r) async =>
        (await service.loadCandidatesByRoleId(database: database, people: const [])).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [...tables, "row_field_versions"]) {
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
        for (final table in tables) {
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
        for (final table in tables) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(rows), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("retaining a candidacy writes two tables", () {
    test("a cast column that cannot be written undoes the turn-down of the others", () async {
      await service
          .setStatus(
            database: database,
            candidateId: rows.second,
            status: OcptRoleCandidateStatus.shortlisted,
          )
          .okOrFail;
      final untouched = await snapshot();
      await database.customStatement(
        "CREATE TRIGGER refuse_update_roles BEFORE UPDATE ON roles "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      final retained = await service.retainCandidate(database: database, candidateId: rows.first);

      expect(retained.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "neither the status nor the turn-down stayed");
    });

    test("unretaining a candidacy clears the cast column with it", () async {
      await service.retainCandidate(database: database, candidateId: rows.first).okOrFail;

      await service.unretainCandidate(database: database, candidateId: rows.first).okOrFail;

      final role = await database.customSelect("SELECT person_id FROM roles").getSingle();
      expect(role.data["person_id"], isNull);
    });

    test("a failed unretaining leaves the candidacy retained", () async {
      await service.retainCandidate(database: database, candidateId: rows.first).okOrFail;
      final untouched = await snapshot();
      await database.customStatement(
        "CREATE TRIGGER refuse_update_roles BEFORE UPDATE ON roles "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );

      final unretained = await service.unretainCandidate(
        database: database,
        candidateId: rows.first,
      );

      expect(unretained.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    });
  });

  group("on the database of a version being previewed", () {
    late OcptProjectDatabase preview;

    setUp(() => preview = OcptProjectDatabase.memory(isPreview: true));

    tearDown(() => preview.close());

    test("every write is refused as a call that went well, and writes nothing", () async {
      await preview.customStatement("PRAGMA foreign_keys = OFF");
      await preview
          .into(preview.ocptRolesTable)
          .insert(
            OcptRolesTableCompanion.insert(
              id: "role-1",
              name: "CLARA",
              kind: OcptRoleKind.speaking,
            ),
          );
      for (final (id, personId) in [(rows.first, "person-1"), (rows.second, "person-2")]) {
        await preview
            .into(preview.ocptRoleCandidatesTable)
            .insert(
              OcptRoleCandidatesTableCompanion.insert(id: id, roleId: "role-1", personId: personId),
            );
      }
      final previous = database;
      database = preview;
      final untouched = await snapshot();

      for (final entry in writes.entries) {
        expect(await entry.value(rows), OcptDatabaseStatus.ok, reason: entry.key);
      }
      await service.unretainCandidate(database: preview, candidateId: rows.first).okOrFail;

      expect(await snapshot(), untouched);
      database = previous;
    });

    test("a write that answers an id answers none", () async {
      expect(
        await service
            .addCandidate(database: preview, roleId: "role-1", personId: "person-3")
            .maybeValueOrFail,
        isNull,
      );
    });

    test("a read is not refused", () async {
      expect(
        await service.loadCandidatesByRoleId(database: preview, people: const []).valueOrFail,
        isEmpty,
      );
    });
  });
}
