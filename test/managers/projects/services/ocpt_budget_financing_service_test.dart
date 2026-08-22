// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const service = OcptBudgetFinancingService();

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every `budget_resources` row, tombstoned or not, in `sortKey` order.
  Future<List<OcptBudgetResourceRow>> readAllResources() =>
      (database.select(database.ocptBudgetResourcesTable)
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Every `budget_mileage_rates` row, tombstoned or not, in `sortKey` order.
  Future<List<OcptBudgetMileageRateRow>> readAllMileageRates() =>
      (database.select(database.ocptBudgetMileageRatesTable)
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  group("financing resources", () {
    test("a fresh project names no resource of its own", () async {
      expect(await service.loadResources(database: database), isEmpty);
    });

    test("createResource appends at the end of the plan", () async {
      final firstId = await service.createResource(database: database, label: "CNC — aide");
      final secondId = await service.createResource(database: database, label: "Région IDF");

      final resources = await service.loadResources(database: database);
      expect(resources.map((resource) => resource.id), [firstId, secondId]);
      expect(resources.first.groupKind, OcptBudgetResourceGroupKind.subsidy);
      expect(resources.first.status, OcptBudgetResourceStatus.applied);
      expect(resources.first.amountCents, 0);
      expect(resources.first.isReimbursable, isFalse);
    });

    test("updateResource changes only the fields passed", () async {
      final id = (await service.createResource(database: database, label: "CNC — aide"))!;

      await service.updateResource(
        database: database,
        resourceId: id,
        groupKind: const Value(OcptBudgetResourceGroupKind.inKind),
        amountCents: const Value(150000),
        status: const Value(OcptBudgetResourceStatus.secured),
        isReimbursable: const Value(true),
        notes: const Value("Caméra prêtée par le loueur"),
      );

      final resource = (await service.loadResources(database: database)).single;
      expect(resource.label, "CNC — aide");
      expect(resource.groupKind, OcptBudgetResourceGroupKind.inKind);
      expect(resource.amountCents, 150000);
      expect(resource.status, OcptBudgetResourceStatus.secured);
      expect(resource.isReimbursable, isTrue);
      expect(resource.notes, "Caméra prêtée par le loueur");
    });

    test("reorderResource moves a resource and writes exactly one row", () async {
      final firstId = (await service.createResource(database: database, label: "A"))!;
      final secondId = (await service.createResource(database: database, label: "B"))!;
      final thirdId = (await service.createResource(database: database, label: "C"))!;
      final before = await readAllResources();

      await service.reorderResource(database: database, resourceId: thirdId, newPosition: 0);

      final after = await readAllResources();
      expect(after.map((row) => row.id), [thirdId, firstId, secondId]);

      final beforeById = {for (final row in before) row.id: row.sortKey};
      final unchanged = after.where((row) => row.id != thirdId);
      expect(unchanged.every((row) => row.sortKey == beforeById[row.id]), isTrue);
    });

    test("deleteResource tombstones the resource, filtered back out of a read", () async {
      final id = (await service.createResource(database: database, label: "CNC — aide"))!;

      await service.deleteResource(database: database, resourceId: id);

      final row = await (database.select(
        database.ocptBudgetResourcesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(await service.loadResources(database: database), isEmpty);
    });

    test("createResource is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final id = await service.createResource(database: preview, label: "CNC — aide");

      expect(id, isNull);
      expect(await preview.select(preview.ocptBudgetResourcesTable).get(), isEmpty);

      await preview.close();
    });

    test("updateResource, reorderResource and deleteResource are all refused on a preview", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview
          .into(preview.ocptBudgetResourcesTable)
          .insert(OcptBudgetResourcesTableCompanion.insert(id: "resource-1", label: "CNC"));

      await service.updateResource(
        database: preview,
        resourceId: "resource-1",
        label: const Value("Renamed"),
      );
      await service.reorderResource(database: preview, resourceId: "resource-1", newPosition: 0);
      await service.deleteResource(database: preview, resourceId: "resource-1");

      final row = await preview.select(preview.ocptBudgetResourcesTable).getSingle();
      expect(row.label, "CNC");
      expect(row.isDeleted, isFalse);

      await preview.close();
    });
  });

  group("mileage rates", () {
    test("a fresh project names no rate of its own", () async {
      expect(await service.loadMileageRates(database: database), isEmpty);
    });

    test("createMileageRate appends at the end of the list, defaulting the rate to zero", () async {
      final firstId = await service.createMileageRate(
        database: database,
        label: "Voiture personnelle",
      );
      final secondId = await service.createMileageRate(database: database, label: "Camion");

      final rates = await service.loadMileageRates(database: database);
      expect(rates.map((rate) => rate.id), [firstId, secondId]);
      expect(rates.first.ratePerKmMilliCents, 0);
    });

    test("updateMileageRate writes the rate exactly as typed, to three decimals", () async {
      final id = (await service.createMileageRate(
        database: database,
        label: "Voiture personnelle",
      ))!;

      // 0.529 €/km, in thousandths of a cent.
      await service.updateMileageRate(
        database: database,
        rateId: id,
        ratePerKmMilliCents: const Value(52900),
      );

      final rate = (await service.loadMileageRates(database: database)).single;
      expect(rate.ratePerKmMilliCents, 52900);
    });

    test("reorderMileageRate moves a rate and writes exactly one row", () async {
      final firstId = (await service.createMileageRate(database: database, label: "A"))!;
      final secondId = (await service.createMileageRate(database: database, label: "B"))!;
      final thirdId = (await service.createMileageRate(database: database, label: "C"))!;
      final before = await readAllMileageRates();

      await service.reorderMileageRate(database: database, rateId: thirdId, newPosition: 0);

      final after = await readAllMileageRates();
      expect(after.map((row) => row.id), [thirdId, firstId, secondId]);

      final beforeById = {for (final row in before) row.id: row.sortKey};
      final unchanged = after.where((row) => row.id != thirdId);
      expect(unchanged.every((row) => row.sortKey == beforeById[row.id]), isTrue);
    });

    test("deleteMileageRate tombstones the rate, filtered back out of a read", () async {
      final id = (await service.createMileageRate(
        database: database,
        label: "Voiture personnelle",
      ))!;

      await service.deleteMileageRate(database: database, rateId: id);

      final row = await (database.select(
        database.ocptBudgetMileageRatesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(await service.loadMileageRates(database: database), isEmpty);
    });

    test("createMileageRate is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final id = await service.createMileageRate(database: preview, label: "Voiture");

      expect(id, isNull);
      expect(await preview.select(preview.ocptBudgetMileageRatesTable).get(), isEmpty);

      await preview.close();
    });

    test(
      "updateMileageRate, reorderMileageRate and deleteMileageRate are all refused on a preview",
      () async {
        final preview = OcptProjectDatabase.memory(isPreview: true);
        await preview
            .into(preview.ocptBudgetMileageRatesTable)
            .insert(OcptBudgetMileageRatesTableCompanion.insert(id: "rate-1", label: "Voiture"));

        await service.updateMileageRate(
          database: preview,
          rateId: "rate-1",
          label: const Value("Renamed"),
        );
        await service.reorderMileageRate(database: preview, rateId: "rate-1", newPosition: 0);
        await service.deleteMileageRate(database: preview, rateId: "rate-1");

        final row = await preview.select(preview.ocptBudgetMileageRatesTable).getSingle();
        expect(row.label, "Voiture");
        expect(row.isDeleted, isFalse);

        await preview.close();
      },
    );
  });
}
