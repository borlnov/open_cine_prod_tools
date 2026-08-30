// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_allowances_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final service = OcptBudgetAllowancesService(deviceId: testDeviceId);

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

  /// Every `budget_allowances` row, tombstoned or not, in `sortKey` order.
  Future<List<OcptBudgetAllowanceRow>> readAll() =>
      (database.select(database.ocptBudgetAllowancesTable)
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Seeds one person, so a defrayal naming them satisfies the foreign key the table declares.
  Future<void> seedPerson(String id) => database
      .into(database.ocptPeopleTable)
      .insert(OcptPeopleTableCompanion.insert(id: id, firstName: const Value("Léa"), lastName: const Value("Petit")));

  /// Creates one defrayal with everything but what a test varies neutral.
  Future<String?> create({
    String? personId,
    OcptBudgetAllowanceKind kind = OcptBudgetAllowanceKind.travel,
    String label = "Défraiement",
    DateTime? date,
    DateTime? endDate,
    int quantityMilli = 168000,
    int unitAmountMilliCents = 52900,
    String notes = "",
  }) => service.createAllowance(
    database: database,
    personId: personId,
    kind: kind,
    label: label,
    date: date,
    endDate: endDate,
    quantityMilli: quantityMilli,
    unitAmountMilliCents: unitAmountMilliCents,
    notes: notes,
  );

  test("a project that has defrayed nobody reads empty, nothing seeded", () async {
    // Unlike the CNC postes, and for the reason the mileage scales are not seeded either: what a
    // production pays back is entirely its own business.
    expect(await service.loadAllowances(database: database), isEmpty);
  });

  test("creating writes every field it was handed, appended at the end", () async {
    await seedPerson("p1");
    final firstId = await create(personId: "p1", label: "Aller");
    final secondId = await create(
      kind: OcptBudgetAllowanceKind.accommodation,
      label: "Hôtel du port",
      date: DateTime.utc(2026, 3, 2),
      endDate: DateTime.utc(2026, 3, 15),
      quantityMilli: 13000,
      unitAmountMilliCents: 6000000,
    );

    final allowances = await service.loadAllowances(database: database);
    expect(allowances.map((row) => row.id), [firstId, secondId]);

    final first = allowances.first;
    expect(first.personId, "p1");
    expect(first.kind, OcptBudgetAllowanceKind.travel);
    expect(first.quantityMilli, 168000);
    expect(first.unitAmountMilliCents, 52900);
    // A journey happens on one day, so it carries no end date at all — a real absence rather than
    // a repeat of its own start.
    expect(first.endDate, isNull);

    final second = allowances.last;
    expect(second.personId, isNull);
    expect(second.kind, OcptBudgetAllowanceKind.accommodation);
    expect(second.date, DateTime.utc(2026, 3, 2));
    expect(second.endDate, DateTime.utc(2026, 3, 15));
  });

  test("updating touches only what it was passed", () async {
    await seedPerson("p1");
    final id = await create(personId: "p1", notes: "Péage inclus");

    await service.updateAllowance(
      database: database,
      allowanceId: id!,
      quantityMilli: const Value(84000),
    );

    final allowance = (await service.loadAllowances(database: database)).single;
    expect(allowance.quantityMilli, 84000);
    expect(allowance.unitAmountMilliCents, 52900);
    expect(allowance.personId, "p1");
    expect(allowance.notes, "Péage inclus");
  });

  test("a defrayal can be handed back to nobody, and a date taken back off", () async {
    await seedPerson("p1");
    final id = await create(personId: "p1", date: DateTime.utc(2026, 3, 2));

    await service.updateAllowance(
      database: database,
      allowanceId: id!,
      personId: const Value(null),
      date: const Value(null),
    );

    final allowance = (await service.loadAllowances(database: database)).single;
    expect(allowance.personId, isNull);
    expect(allowance.date, isNull);
  });

  test("deleting tombstones rather than removing, and the read filters it out", () async {
    final id = await create();
    await service.deleteAllowance(database: database, allowanceId: id!);

    expect(await service.loadAllowances(database: database), isEmpty);
    // The row itself is still there: no service of this app ever deletes a synchronised row.
    final rows = await readAll();
    expect(rows.single.id, id);
    expect(rows.single.isDeleted, isTrue);
  });

  test("reordering writes exactly one row", () async {
    final firstId = await create(label: "Aller");
    final secondId = await create(label: "Retour");
    final thirdId = await create(label: "Taxi");

    final before = {for (final row in await readAll()) row.id: row.sortKey};

    await service.reorderAllowance(database: database, allowanceId: thirdId!, newPosition: 0);

    final after = await service.loadAllowances(database: database);
    expect(after.map((row) => row.id), [thirdId, firstId, secondId]);

    // The two rows it moved past kept the very keys they had.
    final keys = {for (final row in await readAll()) row.id: row.sortKey};
    expect(keys[firstId], before[firstId]);
    expect(keys[secondId], before[secondId]);
    expect(keys[thirdId], isNot(before[thirdId]));
  });

  test("a tombstoned defrayal takes no place in the order it is reordered against", () async {
    final firstId = await create(label: "Aller");
    final secondId = await create(label: "Retour");
    final thirdId = await create(label: "Taxi");
    await service.deleteAllowance(database: database, allowanceId: secondId!);

    await service.reorderAllowance(database: database, allowanceId: thirdId!, newPosition: 0);

    expect(
      (await service.loadAllowances(database: database)).map((row) => row.id),
      [thirdId, firstId],
    );
  });

  test("every write is refused on a previewed version", () async {
    final id = await create();
    await database.close();

    database = OcptProjectDatabase.memory(isPreview: true);
    expect(await service.createAllowance(
      database: database,
      personId: null,
      kind: OcptBudgetAllowanceKind.travel,
      label: "Aller",
      date: null,
      endDate: null,
      quantityMilli: 1000,
      unitAmountMilliCents: 1000,
      notes: "",
    ), isNull);
    await service.updateAllowance(
      database: database,
      allowanceId: id!,
      label: const Value("Changé"),
    );
    await service.deleteAllowance(database: database, allowanceId: id);
    await service.reorderAllowance(database: database, allowanceId: id, newPosition: 0);

    expect(await readAll(), isEmpty);
  });

  group("stamping", () {
    test("createAllowance stamps every column of the new row", () async {
      final id = (await create())!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptBudgetAllowancesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("budget_allowances/$id/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["budget_allowances/$id/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("updateAllowance stamps only the columns that actually changed", () async {
      final id = (await create(notes: "Péage inclus"))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.updateAllowance(
        database: database,
        allowanceId: id,
        quantityMilli: const Value(84000),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("budget_allowances/$id/")).toSet();
      expect(ownKeys, {"budget_allowances/$id/quantityMilli"});
    });

    test("deleteAllowance stamps isDeleted on the defrayal", () async {
      final id = (await create())!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.deleteAllowance(database: database, allowanceId: id);

      final stamps = await readStamps();
      expect(stamps["budget_allowances/$id/isDeleted"]!.version, 1);
    });
  });
}
