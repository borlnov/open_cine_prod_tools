// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_allowances_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import '../../../ocpt_result_expectations.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({String first, String second});

/// Run the tests of what [OcptBudgetAllowancesService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptBudgetAllowancesService(logger: const SilentLogger(), deviceId: testDeviceId);

  const tables = ["budget_allowances"];

  late OcptProjectDatabase database;
  late _Fixture rows;

  /// Create a defrayal of [database] through the service.
  Future<String> create(String label) => service
      .createAllowance(
        database: database,
        personId: null,
        kind: OcptBudgetAllowanceKind.travel,
        label: label,
        date: null,
        endDate: null,
        quantityMilli: 1000,
        unitAmountMilliCents: 1000,
        notes: "",
      )
      .valueOrFail;

  /// Insert two defrayals.
  Future<_Fixture> seed() async => (first: await create("Aller"), second: await create("Retour"));

  setUp(() async {
    database = OcptProjectDatabase.memory();
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "createAllowance": (r) async => (await service.createAllowance(
      database: database,
      personId: null,
      kind: OcptBudgetAllowanceKind.accommodation,
      label: "Hôtel",
      date: null,
      endDate: null,
      quantityMilli: 1000,
      unitAmountMilliCents: 1000,
      notes: "",
    )).status,
    "updateAllowance": (r) async => (await service.updateAllowance(
      database: database,
      allowanceId: r.first,
      label: const Value("Changé"),
    )).status,
    "reorderAllowance": (r) async => (await service.reorderAllowance(
      database: database,
      allowanceId: r.second,
      newPosition: 0,
    )).status,
    "deleteAllowance": (r) async =>
        (await service.deleteAllowance(database: database, allowanceId: r.first)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadAllowances": (r) async => (await service.loadAllowances(database: database)).status,
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
      final created = await service
          .createAllowance(
            database: preview,
            personId: null,
            kind: OcptBudgetAllowanceKind.travel,
            label: "Aller",
            date: null,
            endDate: null,
            quantityMilli: 1000,
            unitAmountMilliCents: 1000,
            notes: "",
          )
          .maybeValueOrFail;

      expect(created, isNull);
    });

    test("a read is not refused", () async {
      expect(await service.loadAllowances(database: preview).valueOrFail, isEmpty);
    });
  });
}
