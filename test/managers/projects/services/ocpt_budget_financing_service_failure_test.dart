// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import '../../../ocpt_result_expectations.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String firstResource,
  String secondResource,
  String firstRate,
  String secondRate,
});

/// Run the tests of what [OcptBudgetFinancingService] answers when the database fails or refuses.
void main() {
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptBudgetFinancingService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
    quoteService: OcptBudgetQuoteService(logger: const SilentLogger(), deviceId: testDeviceId),
  );

  const tables = ["budget_resources", "budget_mileage_rates"];

  late OcptProjectDatabase database;
  late _Fixture rows;

  /// Insert two resources and two mileage rates through the service.
  Future<_Fixture> seed() async => (
    firstResource: await service.createResource(database: database, label: "Lab").valueOrFail,
    secondResource: await service.createResource(database: database, label: "Region").valueOrFail,
    firstRate: await service.createMileageRate(database: database, label: "Car").valueOrFail,
    secondRate: await service.createMileageRate(database: database, label: "Van").valueOrFail,
  );

  setUp(() async {
    database = OcptProjectDatabase.memory();
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  /// The fields of a resource of [groupKind] worth 1 000, offsetting [accountId] when in kind.
  OcptBudgetResourceFormFields fieldsOf(
    OcptBudgetResourceGroupKind groupKind, {
    String? accountId,
    String label = "Loan",
  }) => OcptBudgetResourceFormFields(
    groupKind: groupKind,
    personId: null,
    label: label,
    amountCents: 100000,
    status: OcptBudgetResourceStatus.pending,
    isReimbursable: false,
    notes: "",
    accountId: accountId,
  );

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "createResource": (r) async =>
        (await service.createResource(database: database, label: "Grant")).status,
    "createResourceWithFields": (r) async => (await service.createResourceWithFields(
      database: database,
      fields: fieldsOf(OcptBudgetResourceGroupKind.subsidy),
    )).status,
    "writeResourceFields": (r) async => (await service.writeResourceFields(
      database: database,
      resourceId: r.firstResource,
      fields: fieldsOf(OcptBudgetResourceGroupKind.subsidy, label: "Changed"),
    )).status,
    "updateResource": (r) async => (await service.updateResource(
      database: database,
      resourceId: r.firstResource,
      label: const Value("Changed"),
    )).status,
    "reorderResource": (r) async => (await service.reorderResource(
      database: database,
      resourceId: r.secondResource,
      newPosition: 0,
    )).status,
    "deleteResource": (r) async =>
        (await service.deleteResource(database: database, resourceId: r.firstResource)).status,
    "createMileageRate": (r) async =>
        (await service.createMileageRate(database: database, label: "Bike")).status,
    "updateMileageRate": (r) async => (await service.updateMileageRate(
      database: database,
      rateId: r.firstRate,
      label: const Value("Changed"),
    )).status,
    "reorderMileageRate": (r) async => (await service.reorderMileageRate(
      database: database,
      rateId: r.secondRate,
      newPosition: 0,
    )).status,
    "deleteMileageRate": (r) async =>
        (await service.deleteMileageRate(database: database, rateId: r.firstRate)).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadResources": (r) async => (await service.loadResources(database: database)).status,
    "loadMileageRates": (r) async => (await service.loadMileageRates(database: database)).status,
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

  group("a resource and its counterpart line are one transaction", () {
    final quote = OcptBudgetQuoteService(logger: const SilentLogger(), deviceId: testDeviceId);

    /// Every resource and line row, stamps included, as a comparable text.
    Future<String> state() async {
      final buffer = StringBuffer();
      for (final table in ["budget_resources", "budget_lines", "row_field_versions"]) {
        final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
        buffer.writeln("$table: ${[for (final row in result) row.data]}");
      }

      return buffer.toString();
    }

    Future<void> refuseLines(List<String> verbs) async {
      for (final verb in verbs) {
        await database.customStatement(
          "CREATE TRIGGER refuse_${verb.toLowerCase()}_lines BEFORE $verb ON budget_lines "
          "BEGIN SELECT RAISE(ABORT, 'refused'); END",
        );
      }
    }

    test("an in-kind resource whose line cannot be minted is not created", () async {
      final account = await quote.createAccount(database: database, label: "Crew").valueOrFail;
      final untouched = await state();
      await refuseLines(["INSERT"]);

      final created = await service.createResourceWithFields(
        database: database,
        fields: fieldsOf(OcptBudgetResourceGroupKind.inKind, accountId: account),
      );

      expect(created.status, OcptDatabaseStatus.databaseError);
      expect(await state(), untouched);
    });

    test("an in-kind resource is created with its line when nothing fails", () async {
      final account = await quote.createAccount(database: database, label: "Crew").valueOrFail;

      final created = await service
          .createResourceWithFields(
            database: database,
            fields: fieldsOf(OcptBudgetResourceGroupKind.inKind, accountId: account),
          )
          .valueOrFail;

      final lines = await database
          .customSelect("SELECT in_kind_resource_id FROM budget_lines")
          .get();
      expect([for (final line in lines) line.data["in_kind_resource_id"]], [created]);
    });

    test("an edit whose line cannot follow leaves the resource as it was", () async {
      final account = await quote.createAccount(database: database, label: "Crew").valueOrFail;
      final resourceId = await service
          .createResourceWithFields(
            database: database,
            fields: fieldsOf(OcptBudgetResourceGroupKind.inKind, accountId: account),
          )
          .valueOrFail;
      final untouched = await state();
      await refuseLines(["UPDATE"]);

      final written = await service.writeResourceFields(
        database: database,
        resourceId: resourceId,
        fields: fieldsOf(OcptBudgetResourceGroupKind.inKind, accountId: account, label: "Renamed"),
      );

      expect(written.status, OcptDatabaseStatus.databaseError);
      expect(await state(), untouched);
    });

    test("a reclassification whose line cannot be dropped leaves the resource in kind", () async {
      final account = await quote.createAccount(database: database, label: "Crew").valueOrFail;
      final resourceId = await service
          .createResourceWithFields(
            database: database,
            fields: fieldsOf(OcptBudgetResourceGroupKind.inKind, accountId: account),
          )
          .valueOrFail;
      final untouched = await state();
      await refuseLines(["UPDATE"]);

      final written = await service.writeResourceFields(
        database: database,
        resourceId: resourceId,
        fields: fieldsOf(OcptBudgetResourceGroupKind.subsidy),
      );

      expect(written.status, OcptDatabaseStatus.databaseError);
      expect(await state(), untouched);
    });
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
      final resource = await service
          .createResource(database: preview, label: "Grant")
          .maybeValueOrFail;
      final rate = await service
          .createMileageRate(database: preview, label: "Bike")
          .maybeValueOrFail;

      expect(resource, isNull);
      expect(rate, isNull);
    });

    test("a read is not refused", () async {
      expect(await service.loadResources(database: preview).valueOrFail, isEmpty);
      expect(await service.loadMileageRates(database: preview).valueOrFail, isEmpty);
    });
  });
}
