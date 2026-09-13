// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_sharing_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptBudgetSharingService(deviceId: testDeviceId);

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptShotListService`'s own stamping tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

  /// Every `budget_revenues` row, tombstoned or not, in `sortKey` order.
  Future<List<OcptBudgetRevenueRow>> readAllRevenues() =>
      (database.select(database.ocptBudgetRevenuesTable)
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Every `budget_shares` row, tombstoned or not, in `sortKey` order.
  Future<List<OcptBudgetShareRow>> readAllShares() =>
      (database.select(database.ocptBudgetSharesTable)
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  group("revenues", () {
    test("a fresh project names no taking of its own", () async {
      expect(await service.loadRevenues(database: database), isEmpty);
    });

    test("createRevenue appends at the end of the list", () async {
      final date = DateTime.utc(2026, 5, 15);
      final firstId = await service.createRevenue(database: database, date: date, label: "VOD");
      final secondId = await service.createRevenue(
        database: database,
        date: date,
        label: "Broadcast",
      );

      final revenues = await service.loadRevenues(database: database);
      expect(revenues.map((revenue) => revenue.id), [firstId, secondId]);
      expect(revenues.first.status, OcptBudgetRevenueStatus.expected);
      expect(revenues.first.amountCents, 0);
      expect(revenues.first.notes, "");
    });

    test("updateRevenue changes only the fields passed", () async {
      final id = (await service.createRevenue(
        database: database,
        date: DateTime.utc(2026, 5, 15),
        label: "VOD",
      ))!;

      await service.updateRevenue(
        database: database,
        revenueId: id,
        amountCents: const Value(80000),
        status: const Value(OcptBudgetRevenueStatus.confirmed),
        notes: const Value("Contrat signé"),
      );

      final revenue = (await service.loadRevenues(database: database)).single;
      expect(revenue.label, "VOD");
      expect(revenue.amountCents, 80000);
      expect(revenue.status, OcptBudgetRevenueStatus.confirmed);
      expect(revenue.notes, "Contrat signé");
    });

    test("reorderRevenue moves a revenue and writes exactly one row", () async {
      final date = DateTime.utc(2026, 5, 15);
      final firstId = (await service.createRevenue(database: database, date: date, label: "A"))!;
      final secondId = (await service.createRevenue(database: database, date: date, label: "B"))!;
      final thirdId = (await service.createRevenue(database: database, date: date, label: "C"))!;
      final before = await readAllRevenues();

      await service.reorderRevenue(database: database, revenueId: thirdId, newPosition: 0);

      final after = await readAllRevenues();
      expect(after.map((row) => row.id), [thirdId, firstId, secondId]);

      final beforeById = {for (final row in before) row.id: row.sortKey};
      final unchanged = after.where((row) => row.id != thirdId);
      expect(unchanged.every((row) => row.sortKey == beforeById[row.id]), isTrue);
    });

    test("deleteRevenue tombstones the revenue, filtered back out of a read", () async {
      final id = (await service.createRevenue(
        database: database,
        date: DateTime.utc(2026, 5, 15),
        label: "VOD",
      ))!;

      await service.deleteRevenue(database: database, revenueId: id);

      final row = await (database.select(
        database.ocptBudgetRevenuesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(await service.loadRevenues(database: database), isEmpty);
    });

    test("createRevenue is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final id = await service.createRevenue(
        database: preview,
        date: DateTime.utc(2026, 5, 15),
        label: "VOD",
      );

      expect(id, isNull);
      expect(await preview.select(preview.ocptBudgetRevenuesTable).get(), isEmpty);

      await preview.close();
    });

    test("updateRevenue, reorderRevenue and deleteRevenue are all refused on a preview", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview
          .into(preview.ocptBudgetRevenuesTable)
          .insert(
            OcptBudgetRevenuesTableCompanion.insert(
              id: "revenue-1",
              date: DateTime.utc(2026, 5, 15),
              label: "VOD",
            ),
          );

      await service.updateRevenue(
        database: preview,
        revenueId: "revenue-1",
        label: const Value("Renamed"),
      );
      await service.reorderRevenue(database: preview, revenueId: "revenue-1", newPosition: 0);
      await service.deleteRevenue(database: preview, revenueId: "revenue-1");

      final row = await preview.select(preview.ocptBudgetRevenuesTable).getSingle();
      expect(row.label, "VOD");
      expect(row.isDeleted, isFalse);

      await preview.close();
    });
  });

  group("shares", () {
    test("a fresh project names no participant of its own", () async {
      expect(await service.loadShares(database: database), isEmpty);
    });

    test("createShare appends at the end of the list", () async {
      final firstId = await service.createShare(database: database, label: "Réalisatrice");
      final secondId = await service.createShare(database: database, label: "Production");

      final shares = await service.loadShares(database: database);
      expect(shares.map((share) => share.id), [firstId, secondId]);
      expect(shares.first.personId, isNull);
      expect(shares.first.sharePermille, 0);
      expect(shares.first.reinvestPermille, 0);
    });

    test("updateShare changes only the fields passed", () async {
      final id = (await service.createShare(database: database, label: "Réalisatrice"))!;

      await service.updateShare(
        database: database,
        shareId: id,
        personId: const Value("person-1"),
        sharePermille: const Value(300),
        reinvestPermille: const Value(100),
        notes: const Value("Réinvestit un tiers"),
      );

      final share = (await service.loadShares(database: database)).single;
      expect(share.label, "Réalisatrice");
      expect(share.personId, "person-1");
      expect(share.sharePermille, 300);
      expect(share.reinvestPermille, 100);
      expect(share.notes, "Réinvestit un tiers");
    });

    test("updateShare can put a share back to naming nobody", () async {
      final id = (await service.createShare(database: database, label: "Production"))!;
      await service.updateShare(database: database, shareId: id, personId: const Value("person-1"));

      await service.updateShare(database: database, shareId: id, personId: const Value(null));

      final share = (await service.loadShares(database: database)).single;
      expect(share.personId, isNull);
    });

    test("reorderShare moves a share and writes exactly one row", () async {
      final firstId = (await service.createShare(database: database, label: "A"))!;
      final secondId = (await service.createShare(database: database, label: "B"))!;
      final thirdId = (await service.createShare(database: database, label: "C"))!;
      final before = await readAllShares();

      await service.reorderShare(database: database, shareId: thirdId, newPosition: 0);

      final after = await readAllShares();
      expect(after.map((row) => row.id), [thirdId, firstId, secondId]);

      final beforeById = {for (final row in before) row.id: row.sortKey};
      final unchanged = after.where((row) => row.id != thirdId);
      expect(unchanged.every((row) => row.sortKey == beforeById[row.id]), isTrue);
    });

    test("deleteShare tombstones the share, filtered back out of a read", () async {
      final id = (await service.createShare(database: database, label: "Réalisatrice"))!;

      await service.deleteShare(database: database, shareId: id);

      final row = await (database.select(
        database.ocptBudgetSharesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(await service.loadShares(database: database), isEmpty);
    });

    test("createShare is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final id = await service.createShare(database: preview, label: "Réalisatrice");

      expect(id, isNull);
      expect(await preview.select(preview.ocptBudgetSharesTable).get(), isEmpty);

      await preview.close();
    });

    test("updateShare, reorderShare and deleteShare are all refused on a preview", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview
          .into(preview.ocptBudgetSharesTable)
          .insert(OcptBudgetSharesTableCompanion.insert(id: "share-1", label: "Réalisatrice"));

      await service.updateShare(
        database: preview,
        shareId: "share-1",
        label: const Value("Renamed"),
      );
      await service.reorderShare(database: preview, shareId: "share-1", newPosition: 0);
      await service.deleteShare(database: preview, shareId: "share-1");

      final row = await preview.select(preview.ocptBudgetSharesTable).getSingle();
      expect(row.label, "Réalisatrice");
      expect(row.isDeleted, isFalse);

      await preview.close();
    });
  });

  group("stamping", () {
    test("createRevenue stamps every column of the new row", () async {
      final id = (await service.createRevenue(
        database: database,
        date: DateTime.utc(2026, 5, 15),
        label: "VOD",
      ))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptBudgetRevenuesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("budget_revenues/$id/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["budget_revenues/$id/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("updateRevenue stamps only the columns that actually changed", () async {
      final id = (await service.createRevenue(
        database: database,
        date: DateTime.utc(2026, 5, 15),
        label: "VOD",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.updateRevenue(
        database: database,
        revenueId: id,
        amountCents: const Value(80000),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("budget_revenues/$id/")).toSet();
      expect(ownKeys, {"budget_revenues/$id/amountCents"});
    });

    test("deleteRevenue stamps isDeleted on the revenue", () async {
      final id = (await service.createRevenue(
        database: database,
        date: DateTime.utc(2026, 5, 15),
        label: "VOD",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.deleteRevenue(database: database, revenueId: id);

      final stamps = await readStamps();
      expect(stamps["budget_revenues/$id/isDeleted"]!.version, 1);
    });

    test("createShare stamps every column of the new row", () async {
      final id = (await service.createShare(database: database, label: "Réalisatrice"))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptBudgetSharesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("budget_shares/$id/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["budget_shares/$id/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("updateShare stamps only the columns that actually changed", () async {
      final id = (await service.createShare(database: database, label: "Réalisatrice"))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.updateShare(
        database: database,
        shareId: id,
        sharePermille: const Value(300),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("budget_shares/$id/")).toSet();
      expect(ownKeys, {"budget_shares/$id/sharePermille"});
    });

    test("deleteShare stamps isDeleted on the share", () async {
      final id = (await service.createShare(database: database, label: "Réalisatrice"))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.deleteShare(database: database, shareId: id);

      final stamps = await readStamps();
      expect(stamps["budget_shares/$id/isDeleted"]!.version, 1);
    });
  });
}
