// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import '../../../ocpt_result_expectations.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String firstRevenue,
  String secondRevenue,
  String firstShare,
  String secondShare,
});

/// Run the tests of what [OcptBudgetSharingService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptBudgetSharingService(logger: const SilentLogger(), deviceId: testDeviceId);

  const tables = ["budget_revenues", "budget_shares"];

  late OcptProjectDatabase database;
  late _Fixture rows;

  /// Insert two takings and two shares through the service.
  Future<_Fixture> seed() async => (
    firstRevenue: await service
        .createRevenue(database: database, date: DateTime.utc(2026, 3), label: "Box office")
        .valueOrFail,
    secondRevenue: await service
        .createRevenue(database: database, date: DateTime.utc(2026, 4), label: "Sales agent")
        .valueOrFail,
    firstShare: await service.createShare(database: database, label: "Producer").valueOrFail,
    secondShare: await service.createShare(database: database, label: "Director").valueOrFail,
  );

  setUp(() async {
    database = OcptProjectDatabase.memory();
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  final revenueFields = OcptBudgetRevenueFormFields(
    date: DateTime.utc(2026, 6),
    label: "Broadcast",
    amountCents: 250000,
    status: OcptBudgetRevenueStatus.confirmed,
    notes: "",
  );
  const shareFields = OcptBudgetShareFormFields(
    personId: null,
    label: "Producer",
    sharePermille: 500,
    reinvestPermille: 0,
    notes: "",
  );

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "createRevenue": (r) async => (await service.createRevenue(
      database: database,
      date: DateTime.utc(2026, 5),
      label: "Streaming",
    )).status,
    "createRevenueWithFields": (r) async =>
        (await service.createRevenueWithFields(database: database, fields: revenueFields)).status,
    "createShareWithFields": (r) async =>
        (await service.createShareWithFields(database: database, fields: shareFields)).status,
    "updateRevenue": (r) async => (await service.updateRevenue(
      database: database,
      revenueId: r.firstRevenue,
      label: const Value("Changed"),
    )).status,
    "reorderRevenue": (r) async => (await service.reorderRevenue(
      database: database,
      revenueId: r.secondRevenue,
      newPosition: 0,
    )).status,
    "deleteRevenue": (r) async =>
        (await service.deleteRevenue(database: database, revenueId: r.firstRevenue)).status,
    "createShare": (r) async =>
        (await service.createShare(database: database, label: "Investor")).status,
    "updateShare": (r) async => (await service.updateShare(
      database: database,
      shareId: r.firstShare,
      label: const Value("Changed"),
    )).status,
    "reorderShare": (r) async => (await service.reorderShare(
      database: database,
      shareId: r.secondShare,
      newPosition: 0,
    )).status,
    "deleteShare": (r) async =>
        (await service.deleteShare(database: database, shareId: r.firstShare)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadRevenues": (r) async => (await service.loadRevenues(database: database)).status,
    "loadShares": (r) async => (await service.loadShares(database: database)).status,
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

  group("a row created with its fields is one transaction", () {
    for (final table in tables) {
      test("a $table row whose fields cannot be written is not created", () async {
        final untouched = await snapshot();
        await database.customStatement(
          "CREATE TRIGGER refuse_update BEFORE UPDATE ON $table "
          "BEGIN SELECT RAISE(ABORT, 'refused'); END",
        );

        final status = table == "budget_revenues"
            ? (await service.createRevenueWithFields(
                database: database,
                fields: revenueFields,
              )).status
            : (await service.createShareWithFields(database: database, fields: shareFields)).status;

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched);
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
      final revenue = await service
          .createRevenue(database: preview, date: DateTime.utc(2026, 5), label: "Streaming")
          .maybeValueOrFail;
      final share = await service
          .createShare(database: preview, label: "Investor")
          .maybeValueOrFail;

      expect(revenue, isNull);
      expect(share, isNull);
    });

    test("a read is not refused", () async {
      expect(await service.loadRevenues(database: preview).valueOrFail, isEmpty);
      expect(await service.loadShares(database: preview).valueOrFail, isEmpty);
    });
  });
}
