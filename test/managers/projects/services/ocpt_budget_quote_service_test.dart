// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_financing_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import '../../../ocpt_result_expectations.dart';

/// Run the tests of [OcptBudgetQuoteService].
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptBudgetQuoteService(logger: const SilentLogger(), deviceId: testDeviceId);
  final elementsService = OcptElementsService(
    logger: const SilentLogger(),
    assetsService: OcptAssetsService(logger: const SilentLogger(), deviceId: testDeviceId),
    deviceId: testDeviceId,
  );
  final financingService = OcptBudgetFinancingService(
    logger: const SilentLogger(),
    deviceId: testDeviceId,
  );

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

  /// Three accounts, standing in for the ten the real CNC nomenclature ships — enough to prove the
  /// seeding, ordering and merge-safety rules without repeating all ten in every test.
  const seed = [
    OcptBudgetAccountSeed(
      id: "poste-artistic",
      code: "1",
      label: "Artistic rights",
      simpleLabel: "Rights",
    ),
    OcptBudgetAccountSeed(id: "poste-crew", code: "2", label: "Personnel", simpleLabel: "Crew"),
    OcptBudgetAccountSeed(id: "poste-cast", code: "3", label: "Cast", simpleLabel: null),
  ];

  /// Every `budget_postes` row, tombstoned or not, in `sortKey` order.
  Future<List<OcptBudgetAccountRow>> readAllAccounts() => (database.select(
    database.ocptBudgetAccountsTable,
  )..orderBy([(table) => OrderingTerm.asc(table.sortKey)])).get();

  group("seeding", () {
    test("loadAccounts seeds the ten (here, three) CNC accounts on an empty table", () async {
      final accounts = await service.loadAccounts(database: database, seed: seed);

      expect(accounts.map((account) => account.id), ["poste-artistic", "poste-crew", "poste-cast"]);
      expect(accounts.map((account) => account.code), ["1", "2", "3"]);
      expect(accounts.map((account) => account.label), ["Artistic rights", "Personnel", "Cast"]);
      expect(accounts.last.simpleLabel, isNull);
      expect(accounts.every((account) => account.lines.isEmpty), isTrue);
    });

    test("seeding is deterministic: the same seed always mints the same ids", () async {
      await service.loadAccounts(database: database, seed: seed);
      final rows = await readAllAccounts();

      expect(rows.map((row) => row.id).toSet(), seed.map((accountSeed) => accountSeed.id).toSet());
    });

    test("loadAccounts seeds only once, never on a table that already holds rows", () async {
      await service.loadAccounts(database: database, seed: seed);
      final firstSortKeys = (await readAllAccounts()).map((row) => row.sortKey).toList();

      // A second read, with a seed list that would be trivially distinguishable if re-applied.
      await service.loadAccounts(
        database: database,
        seed: const [
          OcptBudgetAccountSeed(
            id: "poste-other",
            code: "9",
            label: "Should never appear",
            simpleLabel: null,
          ),
        ],
      );

      final rows = await readAllAccounts();
      expect(rows.map((row) => row.id), seed.map((accountSeed) => accountSeed.id));
      expect(rows.map((row) => row.sortKey).toList(), firstSortKeys);
    });

    test("a user who deleted every poste is not seeded again", () async {
      await service.loadAccounts(database: database, seed: seed);
      for (final accountSeed in seed) {
        await service.deleteAccount(database: database, accountId: accountSeed.id);
      }

      final accounts = await service.loadAccounts(database: database, seed: seed);

      expect(accounts, isEmpty);
      expect(await readAllAccounts(), hasLength(seed.length));
      expect((await readAllAccounts()).every((row) => row.isDeleted), isTrue);
    });

    test("seeding is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final accounts = await service.loadAccounts(database: preview, seed: seed);

      expect(accounts, isEmpty);
      expect(await preview.select(preview.ocptBudgetAccountsTable).get(), isEmpty);

      await preview.close();
    });
  });

  group("poste CRUD and ordering", () {
    test("createAccount appends at the end of the catalogue", () async {
      final firstId = await service.createAccount(database: database, label: "Divers");
      final secondId = await service.createAccount(database: database, label: "Assurances");

      final accounts = await service.loadAccounts(database: database, seed: const []);
      expect(accounts.map((account) => account.id), [firstId, secondId]);
    });

    test("updateAccount changes only the fields passed", () async {
      final id = await service.createAccount(database: database, label: "Divers");

      await service.updateAccount(
        database: database,
        accountId: id!,
        code: const Value("11"),
        simpleLabel: const Value("Misc"),
      );

      final account = (await service.loadAccounts(database: database, seed: const [])).single;
      expect(account.label, "Divers");
      expect(account.code, "11");
      expect(account.simpleLabel, "Misc");
    });

    test("reorderAccount moves an account and writes exactly one row", () async {
      await service.loadAccounts(database: database, seed: seed);
      final before = await readAllAccounts();

      await service.reorderAccount(database: database, accountId: "poste-cast", newPosition: 0);

      final after = await readAllAccounts();
      expect(after.map((row) => row.id), ["poste-cast", "poste-artistic", "poste-crew"]);

      // Only the moved row's sortKey actually changed.
      final beforeById = {for (final row in before) row.id: row.sortKey};
      final unchanged = after.where((row) => row.id != "poste-cast");
      expect(unchanged.every((row) => row.sortKey == beforeById[row.id]), isTrue);
    });

    test("deleteAccount tombstones the account and every line it holds", () async {
      final accountId = (await service.createAccount(database: database, label: "Personnel"))!;
      final lineId = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "Ingénieur du son",
      ))!;

      await service.deleteAccount(database: database, accountId: accountId);

      final accountRow = await (database.select(
        database.ocptBudgetAccountsTable,
      )..where((table) => table.id.equals(accountId))).getSingle();
      expect(accountRow.isDeleted, isTrue);

      final lineRow = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.id.equals(lineId))).getSingle();
      expect(lineRow.isDeleted, isTrue);

      // And a tombstoned account and its lines are filtered back out of a read.
      final accounts = await service.loadAccounts(database: database, seed: const []);
      expect(accounts, isEmpty);
    });

    test("createAccount is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final id = await service.createAccount(database: preview, label: "Divers");

      expect(id, isNull);
      expect(await preview.select(preview.ocptBudgetAccountsTable).get(), isEmpty);

      await preview.close();
    });
  });

  group("line CRUD and ordering", () {
    late String accountId;

    setUp(() async {
      accountId = (await service.createAccount(database: database, label: "Personnel"))!;
    });

    test(
      "createLine appends at the end of its own account, defaulting the quantity to one",
      () async {
        final firstId = await service.createLine(
          database: database,
          accountId: accountId,
          label: "DP",
        );
        final secondId = await service.createLine(
          database: database,
          accountId: accountId,
          label: "1er assistant caméra",
        );

        final account = (await service.loadAccounts(database: database, seed: const [])).single;
        expect(account.lines.map((line) => line.id), [firstId, secondId]);
        expect(account.lines.first.quantityMilli, 1000);
        expect(account.lines.first.unitPrice.amountCents, 0);
        expect(account.lines.first.unitPrice.isTaxInclusive, isTrue);
        expect(account.lines.first.unitPrice.vatRateBasisPoints, isNull);
      },
    );

    test(
      "createLine can be minted from an element, carrying its own elementId and unit price",
      () async {
        final elementId = await elementsService.createElement(
          database: database,
          name: "Camera body",
          category: OcptElementCategory.camera,
          sourceKind: OcptElementSourceKind.owned,
        );
        expect(elementId, isNotNull);

        final lineId = await service.createLine(
          database: database,
          accountId: accountId,
          label: "Camera body",
          elementId: Value(elementId),
          unitAmountCents: const Value(2500),
        );

        final account = (await service.loadAccounts(database: database, seed: const [])).single;
        final line = account.lines.single;

        expect(line.id, lineId);
        expect(line.elementId, elementId);
        expect(line.unitPrice.amountCents, 2500);
      },
    );

    test(
      "createLine given no unit price at all defaults exactly as an ordinary line does",
      () async {
        final elementId = await elementsService.createElement(
          database: database,
          name: "Dolly",
          category: OcptElementCategory.specialEquipment,
          sourceKind: OcptElementSourceKind.toBuy,
        );
        expect(elementId, isNotNull);

        // Mirrors an element whose own `cost` is null: the caller passes no `unitAmountCents` at
        // all, and the fresh line is left at the table's own ordinary default — the very same
        // reading an unpriced `+ Add` line already gets, never a price of zero typed on purpose.
        await service.createLine(
          database: database,
          accountId: accountId,
          label: "Dolly",
          elementId: Value(elementId),
        );

        final account = (await service.loadAccounts(database: database, seed: const [])).single;
        final line = account.lines.single;

        expect(line.elementId, elementId);
        expect(line.unitPrice.amountCents, 0);
      },
    );

    test("lines of two different postes order independently", () async {
      final otherAccountId = (await service.createAccount(database: database, label: "Cast"))!;

      final lineA = await service.createLine(database: database, accountId: accountId, label: "A");
      final lineB = await service.createLine(
        database: database,
        accountId: otherAccountId,
        label: "B",
      );

      final accounts = await service.loadAccounts(database: database, seed: const []);
      final personnel = accounts.firstWhere((account) => account.id == accountId);
      final cast = accounts.firstWhere((account) => account.id == otherAccountId);

      expect(personnel.lines.map((line) => line.id), [lineA]);
      expect(cast.lines.map((line) => line.id), [lineB]);
    });

    test("createLine can be minted linked to an in-kind contribution", () async {
      final resourceId = await financingService
          .createResource(database: database, label: "Camera loan")
          .maybeValueOrFail;
      expect(resourceId, isNotNull);

      final lineId = await service.createLine(
        database: database,
        accountId: accountId,
        label: "Camera loan",
        quantityMilli: const Value(1000),
        unitAmountCents: const Value(250000),
        isTaxInclusive: const Value(true),
        vatRateBasisPoints: const Value(0),
        inKindResourceId: Value(resourceId),
      );

      final account = (await service.loadAccounts(database: database, seed: const [])).single;
      final line = account.lines.single;
      expect(line.id, lineId);
      expect(line.inKindResourceId, resourceId);
    });

    test("updateLine writes the money triple and the quantity", () async {
      final lineId = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "DP",
      ))!;

      await service.updateLine(
        database: database,
        lineId: lineId,
        quantityMilli: const Value(1500),
        unit: const Value("day"),
        unitAmountCents: const Value(20000),
        isTaxInclusive: const Value(false),
        vatRateBasisPoints: const Value(550),
      );

      final account = (await service.loadAccounts(database: database, seed: const [])).single;
      final line = account.lines.single;
      expect(line.quantityMilli, 1500);
      expect(line.unit, "day");
      expect(line.unitPrice.amountCents, 20000);
      expect(line.unitPrice.isTaxInclusive, isFalse);
      expect(line.unitPrice.vatRateBasisPoints, 550);
    });

    test("updateLine writes inKindResourceId", () async {
      final resourceId = await financingService
          .createResource(database: database, label: "Camera loan")
          .maybeValueOrFail;
      expect(resourceId, isNotNull);

      final lineId = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "Camera loan",
      ))!;

      await service.updateLine(
        database: database,
        lineId: lineId,
        inKindResourceId: Value(resourceId),
      );

      final account = (await service.loadAccounts(database: database, seed: const [])).single;
      final line = account.lines.single;
      expect(line.inKindResourceId, resourceId);
    });

    test("reorderLine moves a line within its own account and writes exactly one row", () async {
      final lineA = await service.createLine(database: database, accountId: accountId, label: "A");
      final lineB = await service.createLine(database: database, accountId: accountId, label: "B");
      final lineC = await service.createLine(database: database, accountId: accountId, label: "C");

      final beforeSortKeys = {
        for (final row in await (database.select(
          database.ocptBudgetLinesTable,
        )..where((table) => table.accountId.equals(accountId))).get())
          row.id: row.sortKey,
      };

      await service.reorderLine(database: database, lineId: lineC!, newPosition: 0);

      final account = (await service.loadAccounts(database: database, seed: const [])).single;
      expect(account.lines.map((line) => line.id), [lineC, lineA, lineB]);

      final afterRows = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.accountId.equals(accountId))).get();
      final unchanged = afterRows.where((row) => row.id != lineC);
      expect(unchanged.every((row) => row.sortKey == beforeSortKeys[row.id]), isTrue);
    });

    test("deleteLine tombstones the line, filtered back out of a read", () async {
      final lineId = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "DP",
      ))!;

      await service.deleteLine(database: database, lineId: lineId);

      final lineRow = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.id.equals(lineId))).getSingle();
      expect(lineRow.isDeleted, isTrue);

      final account = (await service.loadAccounts(database: database, seed: const [])).single;
      expect(account.lines, isEmpty);
    });

    test("createLine is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      final previewAccountId = (await service.createAccount(database: preview, label: "Personnel"));

      // createAccount is itself refused, so there is no account id to hand createLine — proving the
      // guard already stopped the write one level up.
      expect(previewAccountId, isNull);

      await preview.close();
    });
  });

  group("stamping", () {
    test("createAccount stamps every column of the new row", () async {
      final accountId = (await service.createAccount(database: database, label: "Divers"))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptBudgetAccountsTable,
      )..where((table) => table.id.equals(accountId))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("budget_postes/$accountId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["budget_postes/$accountId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("_seedIfEmpty stamps every column of every seeded account", () async {
      await service.loadAccounts(database: database, seed: seed);

      final stamps = await readStamps();
      for (final accountSeed in seed) {
        final ownKeys = stamps.keys.where(
          (key) => key.startsWith("budget_postes/${accountSeed.id}/"),
        );
        expect(ownKeys, isNotEmpty);
      }
    });

    test("updateAccount stamps only the columns that actually changed", () async {
      final accountId = (await service.createAccount(database: database, label: "Divers"))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.updateAccount(
        database: database,
        accountId: accountId,
        code: const Value("11"),
        simpleLabel: const Value("Misc"),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys
          .where((key) => key.startsWith("budget_postes/$accountId/"))
          .toSet();
      expect(ownKeys, {"budget_postes/$accountId/code", "budget_postes/$accountId/simpleLabel"});
    });

    test("deleteAccount stamps isDeleted on the account and every line it holds", () async {
      final accountId = (await service.createAccount(database: database, label: "Personnel"))!;
      final lineId = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "Ingénieur du son",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.deleteAccount(database: database, accountId: accountId);

      final stamps = await readStamps();
      expect(stamps["budget_postes/$accountId/isDeleted"]!.version, 1);
      expect(stamps["budget_lines/$lineId/isDeleted"]!.version, 1);
    });

    test("createLine stamps every column of the new row", () async {
      final accountId = (await service.createAccount(database: database, label: "Personnel"))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final lineId = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "DP",
      ))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.id.equals(lineId))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("budget_lines/$lineId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["budget_lines/$lineId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("updateLine stamps only the columns that actually changed", () async {
      final accountId = (await service.createAccount(database: database, label: "Personnel"))!;
      final lineId = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "DP",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.updateLine(
        database: database,
        lineId: lineId,
        quantityMilli: const Value(1500),
        unit: const Value("day"),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("budget_lines/$lineId/")).toSet();
      expect(ownKeys, {"budget_lines/$lineId/quantityMilli", "budget_lines/$lineId/unit"});
    });

    test("reorderLine stamps only the moved line's sortKey", () async {
      final accountId = (await service.createAccount(database: database, label: "Personnel"))!;
      final lineA = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "A",
      ))!;
      final lineB = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "B",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.reorderLine(database: database, lineId: lineB, newPosition: 0);

      final stamps = await readStamps();
      expect(stamps.keys, {"budget_lines/$lineB/sortKey"});
      expect(stamps.keys.any((key) => key.startsWith("budget_lines/$lineA/")), isFalse);
    });

    test("deleteLine stamps isDeleted on the line", () async {
      final accountId = (await service.createAccount(database: database, label: "Personnel"))!;
      final lineId = (await service.createLine(
        database: database,
        accountId: accountId,
        label: "DP",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.deleteLine(database: database, lineId: lineId);

      final stamps = await readStamps();
      expect(stamps["budget_lines/$lineId/isDeleted"]!.version, 1);
    });
  });
}
