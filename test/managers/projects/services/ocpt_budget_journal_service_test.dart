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
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  Future<String> testDeviceId() async => "test-device";
  final assetsService = OcptAssetsService(deviceId: testDeviceId);
  final service = OcptBudgetJournalService(assetsService: assetsService, deviceId: testDeviceId);
  final quoteService = OcptBudgetQuoteService(deviceId: testDeviceId);

  late OcptProjectDatabase database;
  late String posteId;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    posteId = (await quoteService.createPoste(database: database, label: "Personnel"))!;
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

    test("deleteEntry tombstones the entry, so the commitment it named reads unsettled again", () async {
      final commitmentId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Assurance tournage",
        amountCents: 30000,
      ))!;
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Paiement assurance",
        posteId: posteId,
        commitmentId: commitmentId,
        debitCents: 30000,
      ))!;

      final settled = (await service.loadCommitments(database: database)).single;
      expect(
        ocptBudgetCommitmentIsSettledOf(
          settled,
          await service.loadEntries(database: database),
          projectVatRateBasisPoints: null,
        ),
        isTrue,
      );

      await service.deleteEntry(database: database, entryId: entryId);

      final commitment = (await service.loadCommitments(database: database)).single;
      expect(
        ocptBudgetCommitmentIsSettledOf(
          commitment,
          await service.loadEntries(database: database),
          projectVatRateBasisPoints: null,
        ),
        isFalse,
      );
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
        stamps: null,
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

  group("vouchers", () {
    test("setEntryReceipt references a fresh voucher and loadReceipts reads it back", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Essence",
        debitCents: 6000,
      ))!;

      final assetId = await service.setEntryReceipt(
        database: database,
        entryId: entryId,
        path: "/tmp/receipt.pdf",
      );
      expect(assetId, isNotNull);

      final receipts = await service.loadReceipts(database: database);
      expect(receipts, hasLength(1));
      expect(receipts[entryId]?.id, assetId);
      expect(receipts[entryId]?.path, "/tmp/receipt.pdf");
      expect(receipts[entryId]?.kind, OcptAssetKind.receipt);
    });

    test("setEntryReceipt replaces whatever the entry already referenced, tombstoning it", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Essence",
        debitCents: 6000,
      ))!;

      final firstAssetId = await service.setEntryReceipt(
        database: database,
        entryId: entryId,
        path: "/tmp/first.pdf",
      );
      final secondAssetId = await service.setEntryReceipt(
        database: database,
        entryId: entryId,
        path: "/tmp/second.pdf",
      );

      final receipts = await service.loadReceipts(database: database);
      expect(receipts, hasLength(1));
      expect(receipts[entryId]?.id, secondAssetId);
      expect(receipts[entryId]?.path, "/tmp/second.pdf");

      final firstRow = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(firstAssetId!))).getSingle();
      expect(firstRow.isDeleted, isTrue);
    });

    test("clearEntryReceipt drops the reference, the file untouched", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Essence",
        debitCents: 6000,
      ))!;
      final assetId = await service.setEntryReceipt(
        database: database,
        entryId: entryId,
        path: "/tmp/receipt.pdf",
      );

      await service.clearEntryReceipt(database: database, entryId: entryId);

      final receipts = await service.loadReceipts(database: database);
      expect(receipts, isEmpty);
      final row = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(assetId!))).getSingle();
      expect(row.isDeleted, isTrue);
      // The path itself is untouched — only the reference is dropped.
      expect(row.path, "/tmp/receipt.pdf");
    });

    test("setEntryReceipt and clearEntryReceipt are both refused on a preview", () async {
      final preview = OcptProjectDatabase.memory(isPreview: true);
      await preview
          .into(preview.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(id: "entry1", date: DateTime.utc(2026, 3, 6), label: "A"),
          );

      final assetId = await service.setEntryReceipt(
        database: preview,
        entryId: "entry1",
        path: "/tmp/receipt.pdf",
      );
      expect(assetId, isNull);
      expect(await preview.select(preview.ocptAssetsTable).get(), isEmpty);

      await service.clearEntryReceipt(database: preview, entryId: "entry1");
      // Nothing to clear, and nothing thrown either.

      await preview.close();
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
      expect(
        ocptBudgetCommitmentIsSettledOf(commitments.first, const [], projectVatRateBasisPoints: null),
        isFalse,
      );
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

    test("updateCommitment moves a commitment to another poste", () async {
      final otherPosteId = (await quoteService.createPoste(
        database: database,
        label: "Moyens techniques",
      ))!;
      final id = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Location optiques",
      ))!;

      await service.updateCommitment(
        database: database,
        commitmentId: id,
        posteId: Value(otherPosteId),
      );

      final commitment = (await service.loadCommitments(database: database)).single;
      expect(commitment.posteId, otherPosteId);
    });

    test("an entry naming a commitment settles it, and clearing that link unsettles it", () async {
      final commitmentId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Assurance",
        amountCents: 10000,
      ))!;
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Paiement",
        commitmentId: commitmentId,
        debitCents: 10000,
      ))!;

      expect(
        ocptBudgetCommitmentIsSettledOf(
          (await service.loadCommitments(database: database)).single,
          await service.loadEntries(database: database),
          projectVatRateBasisPoints: null,
        ),
        isTrue,
      );

      await service.updateEntry(database: database, entryId: entryId, commitmentId: const Value(null));
      expect(
        ocptBudgetCommitmentIsSettledOf(
          (await service.loadCommitments(database: database)).single,
          await service.loadEntries(database: database),
          projectVatRateBasisPoints: null,
        ),
        isFalse,
      );
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

  group("stamping", () {
    test("createEntry stamps every column of the new row", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Essence",
        posteId: posteId,
        debitCents: 6000,
      ))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals(entryId))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("budget_entries/$entryId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["budget_entries/$entryId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        // The device clock already ticked once creating `posteId` in setUp, so this entry's own
        // transaction reserves the next tick, not the first one.
        expect(stamp!.version, 2);
      }
    });

    test("updateEntry stamps only the columns that actually changed", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "A",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.updateEntry(
        database: database,
        entryId: entryId,
        label: const Value("Renamed"),
        debitCents: const Value(5000),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("budget_entries/$entryId/")).toSet();
      expect(ownKeys, {"budget_entries/$entryId/label", "budget_entries/$entryId/debitCents"});
    });

    test("deleteEntry stamps isDeleted on the entry", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "A",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.deleteEntry(database: database, entryId: entryId);

      final stamps = await readStamps();
      expect(stamps["budget_entries/$entryId/isDeleted"]!.version, 1);
    });

    test("createCommitment stamps every column of the new row", () async {
      final commitmentId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Assurance",
        amountCents: 20000,
      ))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptBudgetCommitmentsTable,
      )..where((table) => table.id.equals(commitmentId))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("budget_commitments/$commitmentId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["budget_commitments/$commitmentId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        // The device clock already ticked once creating `posteId` in setUp, so this commitment's
        // own transaction reserves the next tick, not the first one.
        expect(stamp!.version, 2);
      }
    });

    test("updateCommitment stamps only the columns that actually changed", () async {
      final commitmentId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "Assurance",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.updateCommitment(
        database: database,
        commitmentId: commitmentId,
        label: const Value("Assurance tournage"),
        amountCents: const Value(45000),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys
          .where((key) => key.startsWith("budget_commitments/$commitmentId/"))
          .toSet();
      expect(ownKeys, {
        "budget_commitments/$commitmentId/label",
        "budget_commitments/$commitmentId/amountCents",
      });
    });

    test("deleteCommitment stamps isDeleted on the commitment", () async {
      final commitmentId = (await service.createCommitment(
        database: database,
        posteId: posteId,
        label: "A",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.deleteCommitment(database: database, commitmentId: commitmentId);

      final stamps = await readStamps();
      expect(stamps["budget_commitments/$commitmentId/isDeleted"]!.version, 1);
    });

    test("setEntryReceipt stamps the receipt asset it mints — previously left unstamped", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Essence",
        debitCents: 6000,
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      final assetId = (await service.setEntryReceipt(
        database: database,
        entryId: entryId,
        path: "/tmp/receipt.pdf",
      ))!;

      final stamps = await readStamps();
      final row = await (database.select(
        database.ocptAssetsTable,
      )..where((table) => table.id.equals(assetId))).getSingle();
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("assets/$assetId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(row.toJson().length));
      for (final column in row.toJson().keys) {
        final stamp = ownStamps["assets/$assetId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
      }
    });

    test(
      "setEntryReceipt stamps isDeleted on the receipt it replaces — previously left unstamped",
      () async {
        final entryId = (await service.createEntry(
          database: database,
          date: DateTime.utc(2026, 3, 6),
          label: "Essence",
          debitCents: 6000,
        ))!;
        final firstAssetId = (await service.setEntryReceipt(
          database: database,
          entryId: entryId,
          path: "/tmp/first.pdf",
        ))!;
        await database.delete(database.ocptRowFieldVersionsTable).go();

        await service.setEntryReceipt(
          database: database,
          entryId: entryId,
          path: "/tmp/second.pdf",
        );

        final stamps = await readStamps();
        expect(stamps["assets/$firstAssetId/isDeleted"]!.version, 1);
      },
    );

    test(
      "clearEntryReceipt stamps isDeleted on the receipt — previously left unstamped",
      () async {
        final entryId = (await service.createEntry(
          database: database,
          date: DateTime.utc(2026, 3, 6),
          label: "Essence",
          debitCents: 6000,
        ))!;
        final assetId = (await service.setEntryReceipt(
          database: database,
          entryId: entryId,
          path: "/tmp/receipt.pdf",
        ))!;
        await database.delete(database.ocptRowFieldVersionsTable).go();

        await service.clearEntryReceipt(database: database, entryId: entryId);

        final stamps = await readStamps();
        expect(stamps["assets/$assetId/isDeleted"]!.version, 1);
      },
    );

    test("deleteEntry stamps isDeleted on its own live receipt asset too", () async {
      final entryId = (await service.createEntry(
        database: database,
        date: DateTime.utc(2026, 3, 6),
        label: "Essence",
        debitCents: 6000,
      ))!;
      final assetId = (await service.setEntryReceipt(
        database: database,
        entryId: entryId,
        path: "/tmp/receipt.pdf",
      ))!;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await service.deleteEntry(database: database, entryId: entryId);

      final stamps = await readStamps();
      expect(stamps["assets/$assetId/isDeleted"]!.version, 1);
      expect(stamps["budget_entries/$entryId/isDeleted"]!.version, 1);
    });
  });
}
