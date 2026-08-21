// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_journal_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_budget_quote_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const service = OcptBudgetJournalService();
  const assetsService = OcptAssetsService();
  const quoteService = OcptBudgetQuoteService();

  late OcptProjectDatabase database;
  late String posteId;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    posteId = (await quoteService.createPoste(database: database, label: "Personnel"))!;
  });

  tearDown(() async {
    await database.close();
  });

  group("entry CRUD", () {
    test("createEntry mints a sequential voucher number and appends at the end", () async {
      final firstId = await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 2, 20),
        label: "Location camion",
        posteId: posteId,
        debitCents: 15000,
      );
      final secondId = await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 2),
        label: "Acompte subvention",
        creditCents: 200000,
      );

      final entries = await service.loadEntries(database: database);
      expect(entries.map((entry) => entry.id), [firstId, secondId]);
      expect(entries.first.voucherNumber, "J-001");
      expect(entries.last.voucherNumber, "J-002");
      expect(entries.first.posteId, posteId);
      expect(entries.first.debitCents, 15000);
      expect(entries.first.isTaxInclusive, isTrue);
      expect(entries.first.vatRateBasisPoints, isNull);
      // Money coming in with no poste is a real fact, not an omission.
      expect(entries.last.posteId, isNull);
      expect(entries.last.creditCents, 200000);
    });

    test("createEntry never reuses a voucher number once handed out, even after a deletion", () async {
      final firstId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "A",
      ))!;
      await service.createEntry(database: database, date: DateTime.utc(2026, 3, 2), label: "B");

      await service.deleteEntry(database: database, entryId: firstId);

      final thirdId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 3),
        label: "C",
      ))!;

      final thirdRow = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals(thirdId))).getSingle();
      expect(thirdRow.voucherNumber, "J-003");
    });

    test("createEntry ignores a hand-typed voucher number when computing the next one", () async {
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "hand-typed",
              date: DateTime.utc(2026, 1, 6),
              label: "Typed by hand",
              voucherNumber: const Value("FACTURE-2026-42"),
            ),
          );

      final id = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Fresh one",
      ))!;

      final row = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.voucherNumber, "J-001");
    });

    test("createEntry grows the voucher number past three digits", () async {
      // A hand-planted row standing in for 999 prior entries, so the scan has to grow past three
      // digits rather than wrap.
      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "many",
              date: DateTime.utc(2026, 1, 6),
              label: "Nine hundred ninety nine",
              voucherNumber: const Value("J-999"),
            ),
          );

      final id = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "One thousand",
      ))!;

      final row = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.voucherNumber, "J-1000");
    });

    test("updateEntry writes every field passed, voucherNumber included", () async {
      final id = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "A",
      ))!;

      await service.updateEntry(
        database: database,
        entryId: id,
        date: Value(DateTime.utc(2026, 3, 5)),
        label: const Value("Renamed"),
        posteId: Value(posteId),
        debitCents: const Value(5000),
        isTaxInclusive: const Value(false),
        vatRateBasisPoints: const Value(550),
        voucherNumber: const Value("J-custom"),
      );

      final row = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.date, DateTime.utc(2026, 3, 5));
      expect(row.label, "Renamed");
      expect(row.posteId, posteId);
      expect(row.debitCents, 5000);
      expect(row.isTaxInclusive, isFalse);
      expect(row.vatRateBasisPoints, 550);
      expect(row.voucherNumber, "J-custom");
    });

    test("reorderEntry moves an entry and writes exactly one row", () async {
      final firstId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "A",
      ))!;
      final secondId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "B",
      ))!;
      final thirdId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "C",
      ))!;

      final before = {
        for (final row in await database.select(database.ocptBudgetEntriesTable).get())
          row.id: row.sortKey,
      };

      await service.reorderEntry(database: database, entryId: thirdId, newPosition: 0);

      final rows = await database.select(database.ocptBudgetEntriesTable).get();
      final byId = {for (final row in rows) row.id: row};
      expect(
        (rows..sort((a, b) => a.sortKey.compareTo(b.sortKey))).map((row) => row.id),
        [thirdId, firstId, secondId],
      );

      final unchanged = rows.where((row) => row.id != thirdId);
      expect(unchanged.every((row) => row.sortKey == before[row.id]), isTrue);
      expect(byId[thirdId]!.sortKey, isNot(before[thirdId]));
    });

    test("deleteEntry tombstones the entry, filtered back out of loadEntries", () async {
      final id = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "A",
      ))!;

      await service.deleteEntry(database: database, entryId: id);

      final row = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(await service.loadEntries(database: database), isEmpty);
    });

    test("deleteEntry clears settledEntryId on any commitment naming it", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Paiement assurance",
        posteId: posteId,
        debitCents: 30000,
      ))!;
      final commitmentId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Assurance tournage",
        amountCents: 30000,
      ))!;
      await service.updateCommitment(
        database: database,
        commitmentId: commitmentId,
        settledEntryId: Value(entryId),
      );

      final settled = (await service.loadCommitments(database: database)).single;
      expect(settled.isSettled, isTrue);

      await service.deleteEntry(database: database, entryId: entryId);

      final commitment = (await service.loadCommitments(database: database)).single;
      expect(commitment.settledEntryId, isNull);
      expect(commitment.isSettled, isFalse);
    });

    test("deleteEntry tombstones every live receipt asset naming the entry", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Essence",
        debitCents: 6000,
      ))!;
      final assetId = await assetsService.insertAsset(
        database: database,
        kind: OcptAssetKind.receipt,
        path: "/tmp/receipt.pdf",
        budgetEntryId: entryId,
      );

      await service.deleteEntry(database: database, entryId: entryId);

      final assetRow = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(assetId))).getSingle();
      expect(assetRow.isDeleted, isTrue);
    });

    test("createEntry is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);

      final id = await service.createEntry(
        database: preview,
        date: DateTime.utc(2026, 3, 6),
        label: "A",
      );

      expect(id, isNull);
      expect(await preview.select(preview.ocptBudgetEntriesTable).get(), isEmpty);

      await preview.close();
    });

    test("updateEntry, reorderEntry and deleteEntry are all refused on a preview", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview
          .into(preview.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: "entry1",
              date: DateTime.utc(2026, 3, 6),
              label: "A",
            ),
          );

      await service.updateEntry(
        database: preview,
        entryId: "entry1",
        label: const Value("Renamed"),
      );
      await service.reorderEntry(database: preview, entryId: "entry1", newPosition: 0);
      await service.deleteEntry(database: preview, entryId: "entry1");

      final row = await preview.select(preview.ocptBudgetEntriesTable).getSingle();
      expect(row.label, "A");
      expect(row.isDeleted, isFalse);

      await preview.close();
    });

    test("loadEntries orders by date, then by sortKey within the same day", () async {
      final sameDayFirst = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 5),
        label: "Recorded first",
      ))!;
      final earlierDay = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 2, 20),
        label: "Earlier day",
      ))!;
      final sameDaySecond = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 5),
        label: "Recorded second",
      ))!;

      final entries = await service.loadEntries(database: database);
      expect(entries.map((entry) => entry.id), [earlierDay, sameDayFirst, sameDaySecond]);
    });
  });

  group("commitment CRUD", () {
    test("createCommitment appends at the end and defaults to quoteAccepted", () async {
      final firstId = await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Assurance",
        amountCents: 20000,
      );
      final secondId = await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Location véhicule",
      );

      final commitments = await service.loadCommitments(database: database);
      expect(commitments.map((c) => c.id), [firstId, secondId]);
      expect(commitments.first.status, OcptBudgetCommitmentStatus.quoteAccepted);
      expect(commitments.first.amount.amountCents, 20000);
      expect(commitments.first.isSettled, isFalse);
    });

    test("updateCommitment writes every field passed", () async {
      final id = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Assurance",
      ))!;

      await service.updateCommitment(
        database: database,
        commitmentId: id,
        dueDate: Value(DateTime.utc(2026, 4, 6)),
        label: const Value("Assurance tournage"),
        amountCents: const Value(45000),
        isTaxInclusive: const Value(false),
        vatRateBasisPoints: const Value(2000),
        status: const Value(OcptBudgetCommitmentStatus.contractSigned),
      );

      final commitment = (await service.loadCommitments(database: database)).single;
      expect(commitment.dueDate, DateTime.utc(2026, 4, 6));
      expect(commitment.label, "Assurance tournage");
      expect(commitment.amount.amountCents, 45000);
      expect(commitment.amount.isTaxInclusive, isFalse);
      expect(commitment.amount.vatRateBasisPoints, 2000);
      expect(commitment.status, OcptBudgetCommitmentStatus.contractSigned);
    });

    test("updateCommitment can set and then clear settledEntryId", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Paiement",
        debitCents: 10000,
      ))!;
      final commitmentId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Assurance",
        amountCents: 10000,
      ))!;

      await service.updateCommitment(
        database: database,
        commitmentId: commitmentId,
        settledEntryId: Value(entryId),
      );
      expect((await service.loadCommitments(database: database)).single.isSettled, isTrue);

      await service.updateCommitment(
        database: database,
        commitmentId: commitmentId,
        settledEntryId: const Value(null),
      );
      expect((await service.loadCommitments(database: database)).single.isSettled, isFalse);
    });

    test("reorderCommitment moves a commitment and writes exactly one row", () async {
      final firstId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "A",
      ))!;
      final secondId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "B",
      ))!;
      final thirdId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "C",
      ))!;

      final before = {
        for (final row in await database.select(database.ocptBudgetCommitmentsTable).get())
          row.id: row.sortKey,
      };

      await service.reorderCommitment(database: database, commitmentId: firstId, newPosition: 2);

      final rows = await database.select(database.ocptBudgetCommitmentsTable).get();
      final byId = {for (final row in rows) row.id: row};
      expect(
        (rows..sort((a, b) => a.sortKey.compareTo(b.sortKey))).map((row) => row.id),
        [secondId, thirdId, firstId],
      );
      final unchanged = rows.where((row) => row.id != firstId);
      expect(unchanged.every((row) => row.sortKey == before[row.id]), isTrue);
      expect(byId[firstId]!.sortKey, isNot(before[firstId]));
    });

    test("deleteCommitment tombstones it, filtered back out of loadCommitments", () async {
      final id = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "A",
      ))!;

      await service.deleteCommitment(database: database, commitmentId: id);

      final row = await (database.select(
        database.ocptBudgetCommitmentsTable,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(await service.loadCommitments(database: database), isEmpty);
    });

    test("createCommitment is refused on the database of a version being previewed", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview
          .into(preview.ocptBudgetPostesTable)
          .insert(
            OcptBudgetPostesTableCompanion.insert(id: "poste1", label: "Personnel"),
          );

      final id = await service.createCommitment(
        database: preview,
        posteId: "poste1",
        label: "A",
      );

      expect(id, isNull);
      expect(await preview.select(preview.ocptBudgetCommitmentsTable).get(), isEmpty);

      await preview.close();
    });

    test("loadCommitments orders by dueDate ascending, with the undated ones last", () async {
      final undated = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Undated",
      ))!;
      final later = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Later",
        dueDate: DateTime.utc(2026, 5, 6),
      ))!;
      final sooner = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Sooner",
        dueDate: DateTime.utc(2026, 4, 6),
      ))!;

      final commitments = await service.loadCommitments(database: database);
      expect(commitments.map((c) => c.id), [sooner, later, undated]);
    });
  });
}
