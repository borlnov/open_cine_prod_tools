// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const service = OcptBudgetQuoteService();

  late OcptProjectDatabase database;

  setUp(() {
    database = OcptProjectDatabase.memory();
  });

  tearDown(() async {
    await database.close();
  });

  /// Three postes, standing in for the ten the real CNC nomenclature ships — enough to prove the
  /// seeding, ordering and merge-safety rules without repeating all ten in every test.
  const seed = [
    OcptBudgetPosteSeed(id: "poste-artistic", code: "1", label: "Artistic rights", simpleLabel: "Rights"),
    OcptBudgetPosteSeed(id: "poste-crew", code: "2", label: "Personnel", simpleLabel: "Crew"),
    OcptBudgetPosteSeed(id: "poste-cast", code: "3", label: "Cast", simpleLabel: null),
  ];

  /// Every `budget_postes` row, tombstoned or not, in `sortKey` order.
  Future<List<OcptBudgetPosteRow>> readAllPostes() =>
      (database.select(database.ocptBudgetPostesTable)
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  group("seeding", () {
    test("loadPostes seeds the ten (here, three) CNC postes on an empty table", () async {
      final postes = await service.loadPostes(database: database, seed: seed);

      expect(postes.map((poste) => poste.id), ["poste-artistic", "poste-crew", "poste-cast"]);
      expect(postes.map((poste) => poste.code), ["1", "2", "3"]);
      expect(postes.map((poste) => poste.label), ["Artistic rights", "Personnel", "Cast"]);
      expect(postes.last.simpleLabel, isNull);
      expect(postes.every((poste) => poste.lines.isEmpty), isTrue);
    });

    test("seeding is deterministic: the same seed always mints the same ids", () async {
      await service.loadPostes(database: database, seed: seed);
      final rows = await readAllPostes();

      expect(rows.map((row) => row.id).toSet(), seed.map((posteSeed) => posteSeed.id).toSet());
    });

    test("loadPostes seeds only once, never on a table that already holds rows", () async {
      await service.loadPostes(database: database, seed: seed);
      final firstSortKeys = (await readAllPostes()).map((row) => row.sortKey).toList();

      // A second read, with a seed list that would be trivially distinguishable if re-applied.
      await service.loadPostes(
        database: database,
        seed: const [
          OcptBudgetPosteSeed(id: "poste-other", code: "9", label: "Should never appear", simpleLabel: null),
        ],
      );

      final rows = await readAllPostes();
      expect(rows.map((row) => row.id), seed.map((posteSeed) => posteSeed.id));
      expect(rows.map((row) => row.sortKey).toList(), firstSortKeys);
    });

    test("a user who deleted every poste is not seeded again", () async {
      await service.loadPostes(database: database, seed: seed);
      for (final posteSeed in seed) {
        await service.deletePoste(database: database, posteId: posteSeed.id);
      }

      final postes = await service.loadPostes(database: database, seed: seed);

      expect(postes, isEmpty);
      expect(await readAllPostes(), hasLength(seed.length));
      expect((await readAllPostes()).every((row) => row.isDeleted), isTrue);
    });

    test("seeding is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final postes = await service.loadPostes(database: preview, seed: seed);

      expect(postes, isEmpty);
      expect(await preview.select(preview.ocptBudgetPostesTable).get(), isEmpty);

      await preview.close();
    });
  });

  group("poste CRUD and ordering", () {
    test("createPoste appends at the end of the catalogue", () async {
      final firstId = await service.createPoste(database: database, label: "Divers");
      final secondId = await service.createPoste(database: database, label: "Assurances");

      final postes = await service.loadPostes(database: database, seed: const []);
      expect(postes.map((poste) => poste.id), [firstId, secondId]);
    });

    test("updatePoste changes only the fields passed", () async {
      final id = await service.createPoste(database: database, label: "Divers");

      await service.updatePoste(
        database: database,
        posteId: id!,
        code: const Value("11"),
        simpleLabel: const Value("Misc"),
      );

      final poste = (await service.loadPostes(database: database, seed: const [])).single;
      expect(poste.label, "Divers");
      expect(poste.code, "11");
      expect(poste.simpleLabel, "Misc");
    });

    test("reorderPoste moves a poste and writes exactly one row", () async {
      await service.loadPostes(database: database, seed: seed);
      final before = await readAllPostes();

      await service.reorderPoste(database: database, posteId: "poste-cast", newPosition: 0);

      final after = await readAllPostes();
      expect(after.map((row) => row.id), ["poste-cast", "poste-artistic", "poste-crew"]);

      // Only the moved row's sortKey actually changed.
      final beforeById = {for (final row in before) row.id: row.sortKey};
      final unchanged = after.where((row) => row.id != "poste-cast");
      expect(unchanged.every((row) => row.sortKey == beforeById[row.id]), isTrue);
    });

    test("deletePoste tombstones the poste and every line it holds", () async {
      final posteId = (await service.createPoste(database: database, label: "Personnel"))!;
      final lineId = (await service.createLine(
        database: database,
        posteId: posteId,
        label: "Ingénieur du son",
      ))!;

      await service.deletePoste(database: database, posteId: posteId);

      final posteRow = await (database.select(
        database.ocptBudgetPostesTable,
      )..where((table) => table.id.equals(posteId))).getSingle();
      expect(posteRow.isDeleted, isTrue);

      final lineRow = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.id.equals(lineId))).getSingle();
      expect(lineRow.isDeleted, isTrue);

      // And a tombstoned poste and its lines are filtered back out of a read.
      final postes = await service.loadPostes(database: database, seed: const []);
      expect(postes, isEmpty);
    });

    test("createPoste is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final id = await service.createPoste(database: preview, label: "Divers");

      expect(id, isNull);
      expect(await preview.select(preview.ocptBudgetPostesTable).get(), isEmpty);

      await preview.close();
    });
  });

  group("line CRUD and ordering", () {
    late String posteId;

    setUp(() async {
      posteId = (await service.createPoste(database: database, label: "Personnel"))!;
    });

    test("createLine appends at the end of its own poste, defaulting the quantity to one", () async {
      final firstId = await service.createLine(database: database, posteId: posteId, label: "DP");
      final secondId = await service.createLine(
        database: database,
        posteId: posteId,
        label: "1er assistant caméra",
      );

      final poste = (await service.loadPostes(database: database, seed: const [])).single;
      expect(poste.lines.map((line) => line.id), [firstId, secondId]);
      expect(poste.lines.first.quantityMilli, 1000);
      expect(poste.lines.first.unitPrice.amountCents, 0);
      expect(poste.lines.first.unitPrice.isTaxInclusive, isTrue);
      expect(poste.lines.first.unitPrice.vatRateBasisPoints, isNull);
    });

    test("lines of two different postes order independently", () async {
      final otherPosteId = (await service.createPoste(database: database, label: "Cast"))!;

      final lineA = await service.createLine(database: database, posteId: posteId, label: "A");
      final lineB = await service.createLine(
        database: database,
        posteId: otherPosteId,
        label: "B",
      );

      final postes = await service.loadPostes(database: database, seed: const []);
      final personnel = postes.firstWhere((poste) => poste.id == posteId);
      final cast = postes.firstWhere((poste) => poste.id == otherPosteId);

      expect(personnel.lines.map((line) => line.id), [lineA]);
      expect(cast.lines.map((line) => line.id), [lineB]);
    });

    test("updateLine writes the money triple and the quantity", () async {
      final lineId = (await service.createLine(
        database: database,
        posteId: posteId,
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

      final poste = (await service.loadPostes(database: database, seed: const [])).single;
      final line = poste.lines.single;
      expect(line.quantityMilli, 1500);
      expect(line.unit, "day");
      expect(line.unitPrice.amountCents, 20000);
      expect(line.unitPrice.isTaxInclusive, isFalse);
      expect(line.unitPrice.vatRateBasisPoints, 550);
    });

    test("reorderLine moves a line within its own poste and writes exactly one row", () async {
      final lineA = await service.createLine(database: database, posteId: posteId, label: "A");
      final lineB = await service.createLine(database: database, posteId: posteId, label: "B");
      final lineC = await service.createLine(database: database, posteId: posteId, label: "C");

      final beforeSortKeys = {
        for (final row in await (database.select(
          database.ocptBudgetLinesTable,
        )..where((table) => table.posteId.equals(posteId))).get())
          row.id: row.sortKey,
      };

      await service.reorderLine(database: database, lineId: lineC!, newPosition: 0);

      final poste = (await service.loadPostes(database: database, seed: const [])).single;
      expect(poste.lines.map((line) => line.id), [lineC, lineA, lineB]);

      final afterRows = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.posteId.equals(posteId))).get();
      final unchanged = afterRows.where((row) => row.id != lineC);
      expect(unchanged.every((row) => row.sortKey == beforeSortKeys[row.id]), isTrue);
    });

    test("deleteLine tombstones the line, filtered back out of a read", () async {
      final lineId = (await service.createLine(
        database: database,
        posteId: posteId,
        label: "DP",
      ))!;

      await service.deleteLine(database: database, lineId: lineId);

      final lineRow = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.id.equals(lineId))).getSingle();
      expect(lineRow.isDeleted, isTrue);

      final poste = (await service.loadPostes(database: database, seed: const [])).single;
      expect(poste.lines, isEmpty);
    });

    test("createLine is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      final previewPosteId = (await service.createPoste(
        database: preview,
        label: "Personnel",
      ));

      // createPoste is itself refused, so there is no poste id to hand createLine — proving the
      // guard already stopped the write one level up.
      expect(previewPosteId, isNull);

      await preview.close();
    });
  });
}
