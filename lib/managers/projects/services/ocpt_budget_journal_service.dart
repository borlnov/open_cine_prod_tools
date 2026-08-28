// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the budget mode's cash journal: the `budget_entries` movements and the
/// `budget_commitments` still owed against a poste.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **`budget_entries` is ordered chronologically** ([loadEntries]: `date` ascending, then `sortKey`
/// ascending) — a journal is read day by day, and `sortKey` is only there to settle two entries
/// recorded on the same day, exactly the role it plays as a tie-breaker rather than the primary
/// order. **`budget_commitments` is ordered by `dueDate` ascending with the undated ones last**
/// ([loadCommitments]), then `sortKey`: a commitment nobody has dated yet is not due sooner than
/// every dated one, which is what SQLite's own default (nulls first) would otherwise claim.
///
/// Both tables still carry a flat `sortKey` of their own, read exactly as `OcptBudgetPostesTable`'s
/// own catalogue is: [createEntry]/[createCommitment] append to it and [reorderEntry]/
/// [reorderCommitment] move a single row within it, independently of the chronological or
/// due-date order [loadEntries]/[loadCommitments] actually display rows in.
class OcptBudgetJournalService {
  /// The prefix every voucher number [createEntry] mints starts with: `J-001`, `J-002`, …, growing
  /// past three digits rather than wrapping once a project needs a fourth.
  ///
  /// **Deliberately not localized.** A voucher number is an accounting reference stored in the data
  /// and printed on the voucher itself — a stapled receipt, an invoice — so it has to read the same
  /// whatever language the UI happens to be shown in that day; that is also why this service and
  /// every other one under `lib/managers/` stays free of `Tr` (`AGENTS.md`).
  static const _voucherNumberPrefix = 'J-';

  /// The shape [_nextVoucherNumber] recognises a voucher number by: [_voucherNumberPrefix] followed
  /// by one or more digits, captured. A `budget_entries.voucherNumber` that doesn't match this — the
  /// user typed their own reference instead of keeping the minted one — is simply ignored by the
  /// scan rather than corrected.
  static final RegExp _voucherNumberPattern = RegExp(
    '^${RegExp.escape(_voucherNumberPrefix)}(\\d+)\$',
  );

  /// The service used to mint and tombstone the `assets` rows referencing a voucher file.
  final OcptAssetsService _assetsService;

  /// Class constructor
  const OcptBudgetJournalService({OcptAssetsService assetsService = const OcptAssetsService()})
    : _assetsService = assetsService;

  /// Loads every live entry of [database], in `date` order, `sortKey` breaking a tie between two
  /// entries recorded on the same day.
  Future<List<OcptBudgetEntry>> loadEntries({required OcptProjectDatabase database}) async {
    final rows =
        await (database.select(database.ocptBudgetEntriesTable)
              ..where((table) => table.isDeleted.not())
              ..orderBy([
                (table) => OrderingTerm.asc(table.date),
                (table) => OrderingTerm.asc(table.sortKey),
              ]))
            .get();

    return [for (final row in rows) OcptBudgetEntry.fromRow(row)];
  }

  /// Loads every live commitment of [database], in `dueDate` order with the undated ones **last**,
  /// `sortKey` breaking a tie between two commitments sharing a due date (or sharing no due date at
  /// all).
  ///
  /// SQLite sorts `NULL` before every other value by default, which would put every commitment
  /// nobody has dated yet at the very top — the opposite of what "still owed, but nobody has said
  /// when" should read as. Ordering by `dueDate.isNull()` first (`false` sorts before `true`) is
  /// what puts every dated commitment ahead of the undated ones, in their own date order, before
  /// `dueDate` itself is asked to order anything.
  Future<List<OcptBudgetCommitment>> loadCommitments({required OcptProjectDatabase database}) async {
    final rows =
        await (database.select(database.ocptBudgetCommitmentsTable)
              ..where((table) => table.isDeleted.not())
              ..orderBy([
                (table) => OrderingTerm.asc(table.dueDate.isNull()),
                (table) => OrderingTerm.asc(table.dueDate),
                (table) => OrderingTerm.asc(table.sortKey),
              ]))
            .get();

    return [for (final row in rows) OcptBudgetCommitment.fromRow(row)];
  }

  /// Loads every live voucher of [database] — `OcptAssetKind.receipt`, `assets.budgetEntryId`
  /// naming the journal entry it evidences — keyed by that entry's own id.
  ///
  /// **At most one per entry**, mirroring `OcptLocationsService.loadLocations`' own
  /// `permitDocument` join but reading `assets` directly rather than through a stored owning
  /// column: `budget_entries` carries no `receiptAssetId` of its own, `assets.budgetEntryId` being
  /// the only place the link is recorded (`setEntryReceipt`'s own doc comment argues why a second,
  /// redundant column on the entry itself would only be one more copy of the same fact to keep in
  /// step).
  Future<Map<String, OcptAssetRef>> loadReceipts({required OcptProjectDatabase database}) async {
    final rows =
        await (database.select(database.ocptAssetsTable)..where(
              (table) => table.kind.equalsValue(OcptAssetKind.receipt) & table.isDeleted.not(),
            ))
            .get();

    return {
      for (final row in rows)
        if (row.budgetEntryId case final entryId?) entryId: OcptAssetRef.fromRow(row),
    };
  }

  /// Creates a new journal entry dated [date], appended at the end of the journal's own flat
  /// `sortKey` order, and returns its freshly generated id.
  ///
  /// Mints `OcptBudgetEntriesTable.voucherNumber` itself, through [_nextVoucherNumber]: the caller
  /// never types one in for a fresh entry, only [updateEntry] can change it afterwards.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createEntry({
    required OcptProjectDatabase database,
    required DateTime date,
    required String label,
    String? posteId,
    String? resourceId,
    String? revenueId,
    String? shareId,
    String? commitmentId,
    String? personId,
    int debitCents = 0,
    int creditCents = 0,
    bool isTaxInclusive = true,
    int? vatRateBasisPoints,
  }) async {
    if (database.refusesUserWrite("createEntry")) {
      return null;
    }

    return database.transaction(() async {
      final existing = await _liveEntryRows(database);
      final id = const Uuid().v4();
      final voucherNumber = await _nextVoucherNumber(database);

      await database
          .into(database.ocptBudgetEntriesTable)
          .insert(
            OcptBudgetEntriesTableCompanion.insert(
              id: id,
              date: date,
              label: label,
              posteId: Value(posteId),
              resourceId: Value(resourceId),
              revenueId: Value(revenueId),
              shareId: Value(shareId),
              commitmentId: Value(commitmentId),
              personId: Value(personId),
              debitCents: Value(debitCents),
              creditCents: Value(creditCents),
              isTaxInclusive: Value(isTaxInclusive),
              vatRateBasisPoints: Value(vatRateBasisPoints),
              voucherNumber: Value(voucherNumber),
              sortKey: Value(
                ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
              ),
            ),
          );

      return id;
    });
  }

  /// Updates the fields of entry [entryId] in [database] that are passed as something other than
  /// [Value.absent], [voucherNumber] included: unlike `OcptBudgetLinesTable`'s `posteId`, a
  /// voucher number is exactly the kind of field a user is expected to retype once the number
  /// [createEntry] minted doesn't match the paper trail (a supplier's own reference, say). Never
  /// touches `sortKey` or `isDeleted`: those only change through [reorderEntry] and [deleteEntry].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateEntry({
    required OcptProjectDatabase database,
    required String entryId,
    Value<DateTime> date = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<String?> posteId = const Value.absent(),
    Value<String?> resourceId = const Value.absent(),
    Value<String?> revenueId = const Value.absent(),
    Value<String?> shareId = const Value.absent(),
    Value<String?> commitmentId = const Value.absent(),
    Value<String?> personId = const Value.absent(),
    Value<int> debitCents = const Value.absent(),
    Value<int> creditCents = const Value.absent(),
    Value<bool> isTaxInclusive = const Value.absent(),
    Value<int?> vatRateBasisPoints = const Value.absent(),
    Value<String> voucherNumber = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateEntry")) {
      return;
    }

    await (database.update(
      database.ocptBudgetEntriesTable,
    )..where((table) => table.id.equals(entryId) & table.isDeleted.not())).write(
      OcptBudgetEntriesTableCompanion(
        date: date,
        label: label,
        posteId: posteId,
        resourceId: resourceId,
        revenueId: revenueId,
        shareId: shareId,
        commitmentId: commitmentId,
        personId: personId,
        debitCents: debitCents,
        creditCents: creditCents,
        isTaxInclusive: isTaxInclusive,
        vatRateBasisPoints: vatRateBasisPoints,
        voucherNumber: voucherNumber,
      ),
    );
  }

  /// Moves entry [entryId] to [newPosition] (0-based) within the journal's own flat `sortKey`
  /// order, by giving it a `sortKey` sitting between the two entries it lands between. Writes
  /// **exactly one row**.
  ///
  /// This is independent of the chronological order [loadEntries] displays rows in: two entries
  /// recorded on the same day still need a `sortKey` to settle between them, and this is what
  /// moves it.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderEntry({
    required OcptProjectDatabase database,
    required String entryId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderEntry")) {
      return;
    }

    await database.transaction(() async {
      final others = (await _liveEntryRows(database))..removeWhere((row) => row.id == entryId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals(entryId))).write(
        OcptBudgetEntriesTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Tombstones entry [entryId] and, in the same transaction, tombstones every live `assets` row
  /// naming it as its `OcptAssetKind.receipt` ([_tombstoneEntryReceipt]): the voucher goes with the
  /// entry it stood for, exactly as `OcptElementsService` tombstones an element's photo alongside
  /// the element.
  ///
  /// **No commitment needs correcting here any more.** A settled commitment used to name its own
  /// settling entry (`settledEntryId`), so deleting that entry had to clear the link back to null or
  /// leave a commitment pointing at a row that no longer existed. Settlement is read off
  /// `budget_entries.commitmentId` now: tombstoning this entry is enough on its own, since every
  /// read already filters tombstones out (`{@macro open_cine_prod_tools.tombstones}`) — a
  /// commitment this entry used to pay simply stops seeing it summed against it.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteEntry({required OcptProjectDatabase database, required String entryId}) async {
    if (database.refusesUserWrite("deleteEntry")) {
      return;
    }

    await database.transaction(() async {
      await _tombstoneEntryReceipt(database: database, entryId: entryId);

      await (database.update(
        database.ocptBudgetEntriesTable,
      )..where((table) => table.id.equals(entryId))).write(
        const OcptBudgetEntriesTableCompanion(isDeleted: Value(true)),
      );
    });
  }

  /// References the file at [path] as journal entry [entryId]'s own voucher, replacing whichever
  /// receipt it referenced before — tombstoned in the same transaction, since an entry has at most
  /// one voucher and a row nothing points at any more is not history worth keeping, it is an
  /// orphan. Mirrors `OcptLocationsService.setPermitDocument`; see that method's own doc comment
  /// (and `docs/adr/0013-binary-assets-referenced-by-path.md`) for why no byte of the file is ever
  /// touched.
  ///
  /// **No `receiptAssetId` column exists on `budget_entries` to write back**: `assets
  /// .budgetEntryId` is the only place this link is recorded — a second, redundant column on the
  /// entry itself would only be one more copy of the same fact to keep in step, which is exactly
  /// the argument `OcptBudgetPostesTable`'s own doc comment already makes against a stored
  /// `quotedAmount`.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> setEntryReceipt({
    required OcptProjectDatabase database,
    required String entryId,
    required String path,
  }) async {
    if (database.refusesUserWrite("setEntryReceipt")) {
      return null;
    }

    return database.transaction(() async {
      await _tombstoneEntryReceipt(database: database, entryId: entryId);

      return _assetsService.insertAsset(
        database: database,
        kind: OcptAssetKind.receipt,
        budgetEntryId: entryId,
        path: path,
      );
    });
  }

  /// Drops journal entry [entryId]'s own reference to its voucher: the `assets` row is tombstoned.
  /// The file itself is never touched.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> clearEntryReceipt({
    required OcptProjectDatabase database,
    required String entryId,
  }) async {
    if (database.refusesUserWrite("clearEntryReceipt")) {
      return;
    }

    await _tombstoneEntryReceipt(database: database, entryId: entryId);
  }

  /// Tombstones every live `assets` row naming [entryId] as its `OcptAssetKind.receipt` voucher —
  /// shared by [deleteEntry]'s own cascade, [setEntryReceipt] (replacing one) and
  /// [clearEntryReceipt] (dropping one outright). Unguarded, like `OcptLocationsService
  /// ._tombstonePermitDocument`: every caller has already refused the write on a previewed
  /// database itself, or is running inside [deleteEntry]'s own transaction.
  Future<void> _tombstoneEntryReceipt({
    required OcptProjectDatabase database,
    required String entryId,
  }) async {
    final vouchers =
        await (database.select(database.ocptAssetsTable)..where(
              (table) => table.budgetEntryId.equals(entryId) & table.isDeleted.not(),
            ))
            .get();
    for (final voucher in vouchers) {
      await _assetsService.tombstoneAsset(database: database, assetId: voucher.id);
    }
  }

  /// Creates a new commitment against [posteId], appended at the end of the commitment list's own
  /// flat `sortKey` order, and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createCommitment({
    required OcptProjectDatabase database,
    required String posteId,
    required String label,
    DateTime? dueDate,
    int amountCents = 0,
    bool isTaxInclusive = true,
    int? vatRateBasisPoints,
    OcptBudgetCommitmentStatus status = OcptBudgetCommitmentStatus.quoteAccepted,
    String? lineId,
  }) async {
    if (database.refusesUserWrite("createCommitment")) {
      return null;
    }

    final existing = await _liveCommitmentRows(database);
    final id = const Uuid().v4();

    await database
        .into(database.ocptBudgetCommitmentsTable)
        .insert(
          OcptBudgetCommitmentsTableCompanion.insert(
            id: id,
            posteId: posteId,
            label: label,
            dueDate: Value(dueDate),
            amountCents: Value(amountCents),
            isTaxInclusive: Value(isTaxInclusive),
            vatRateBasisPoints: Value(vatRateBasisPoints),
            status: Value(status),
            lineId: Value(lineId),
            sortKey: Value(
              ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
            ),
          ),
        );

    return id;
  }

  /// Updates the fields of commitment [commitmentId] in [database] that are passed as something
  /// other than [Value.absent]. **Settlement is never written here any more** — it is read off
  /// `budget_entries.commitmentId`, not stored on this row at all: writing a payment is
  /// [OcptBudgetJournalService.createEntry] naming this commitment, and undoing one is clearing that
  /// link back to null on the entry that named it ([updateEntry]). Never touches `sortKey` or
  /// `isDeleted`: those only change through [reorderCommitment] and [deleteCommitment].
  ///
  /// **[posteId] *is* updatable here, unlike `OcptBudgetQuoteService.updateLine`'s own.** That
  /// method withholds it because a line's `sortKey` is fractional **within its own `posteId`**, so
  /// moving a line to another poste would need its position recomputed against a different group
  /// entirely — a real second operation wearing the name of a field write. This table's `sortKey`
  /// is flat, so no such thing is true of a commitment, and a commitment's poste is exactly the
  /// field somebody gets wrong: it is an attribution typed once against a ten-poste nomenclature,
  /// not the parent that gives the row its place. Refusing it would leave a mistyped commitment
  /// correctable only by deleting it — and a delete here is a tombstone kept forever (ADR 0010),
  /// which is a heavy price for a slip of the mouse.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateCommitment({
    required OcptProjectDatabase database,
    required String commitmentId,
    Value<DateTime?> dueDate = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<String> posteId = const Value.absent(),
    Value<int> amountCents = const Value.absent(),
    Value<bool> isTaxInclusive = const Value.absent(),
    Value<int?> vatRateBasisPoints = const Value.absent(),
    Value<OcptBudgetCommitmentStatus> status = const Value.absent(),
    Value<String?> lineId = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateCommitment")) {
      return;
    }

    await (database.update(
      database.ocptBudgetCommitmentsTable,
    )..where((table) => table.id.equals(commitmentId) & table.isDeleted.not())).write(
      OcptBudgetCommitmentsTableCompanion(
        dueDate: dueDate,
        label: label,
        posteId: posteId,
        amountCents: amountCents,
        isTaxInclusive: isTaxInclusive,
        vatRateBasisPoints: vatRateBasisPoints,
        status: status,
        lineId: lineId,
      ),
    );
  }

  /// Moves commitment [commitmentId] to [newPosition] (0-based) within the commitment list's own
  /// flat `sortKey` order, by giving it a `sortKey` sitting between the two commitments it lands
  /// between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderCommitment({
    required OcptProjectDatabase database,
    required String commitmentId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderCommitment")) {
      return;
    }

    await database.transaction(() async {
      final others =
          (await _liveCommitmentRows(database))..removeWhere((row) => row.id == commitmentId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      await (database.update(
        database.ocptBudgetCommitmentsTable,
      )..where((table) => table.id.equals(commitmentId))).write(
        OcptBudgetCommitmentsTableCompanion(sortKey: Value(sortKey)),
      );
    });
  }

  /// Tombstones commitment [commitmentId]. Nothing else in the schema ever names a commitment, so
  /// unlike [deleteEntry] there is no dangling reference to clear.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteCommitment({
    required OcptProjectDatabase database,
    required String commitmentId,
  }) async {
    if (database.refusesUserWrite("deleteCommitment")) {
      return;
    }

    await (database.update(
      database.ocptBudgetCommitmentsTable,
    )..where((table) => table.id.equals(commitmentId))).write(
      const OcptBudgetCommitmentsTableCompanion(isDeleted: Value(true)),
    );
  }

  /// The next voucher number [createEntry] mints: one above the highest number parsed off any
  /// `budget_entries.voucherNumber` matching [_voucherNumberPattern] in [database], **tombstones
  /// included** — a number is never reused once handed out, even once the entry it named has since
  /// been deleted, so a fresh voucher never collides with one a paper trail elsewhere still names.
  /// A row whose voucher number doesn't match the pattern at all (the user typed their own instead
  /// of keeping the minted one) is simply ignored by the scan.
  Future<String> _nextVoucherNumber(OcptProjectDatabase database) async {
    final rows = await database.select(database.ocptBudgetEntriesTable).get();

    var highest = 0;
    for (final row in rows) {
      final match = _voucherNumberPattern.firstMatch(row.voucherNumber);
      if (match == null) {
        continue;
      }

      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > highest) {
        highest = parsed;
      }
    }

    return _voucherNumberOf(highest + 1);
  }

  /// [number], formatted as [_voucherNumberPrefix] followed by three digits at least — `J-001`,
  /// `J-002`, …, growing past three digits (`J-1000`) rather than wrapping once a project needs a
  /// fourth.
  static String _voucherNumberOf(int number) =>
      '$_voucherNumberPrefix${number.toString().padLeft(3, '0')}';

  /// Every live entry row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetEntryRow>> _liveEntryRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetEntriesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Every live commitment row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetCommitmentRow>> _liveCommitmentRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetCommitmentsTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();
}
