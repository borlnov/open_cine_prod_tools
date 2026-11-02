// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_provision_outcome.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the budget mode's quote: the `budget_postes` catalogue and the `budget_lines` inside
/// each one.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Seeds the ten CNC accounts on the first read of an empty `budget_postes` table**
/// ([loadAccounts]), not at project creation, so an existing project gets them too — the labels are
/// resolved by the caller (`OcptBudgetAccountSeed`, already localized), since no service ever sees
/// a `Tr`.
///
/// **`budget_postes` is ordered flat by `sortKey`**, like `OcptElementsService`'s own catalogue —
/// see that service's doc comment for why one flat order beats one order per department.
/// **`budget_lines` is ordered by `sortKey` within its own `accountId`**, like
/// `OcptShotListService`'s shots within a scene: a line only ever competes for a position against
/// the other lines of the very account it prices.
class OcptBudgetQuoteService extends AbsOcptService {
  /// {@macro open_cine_prod_tools.serviceDeviceIdGetter}
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptBudgetQuoteService({required super.logger, required this.deviceId});

  /// Load every live account of [database], in `sortKey` order, each joined with its own live
  /// `budget_lines` rows (themselves in their own `sortKey` order) — seeding [seed] first if the
  /// table holds no row at all, tombstone included.
  @useResult
  Future<OcptDatabaseResult<List<OcptBudgetAccount>>> loadAccounts({
    required OcptProjectDatabase database,
    required List<OcptBudgetAccountSeed> seed,
  }) => guardResult("loadAccounts", () async {
    await _seedIfEmpty(database: database, seed: seed);

    final accountRows = await _liveAccountRows(database);
    final lineRows = await _liveLineRows(database);

    final linesByAccountId = <String, List<OcptBudgetLine>>{};
    for (final row in lineRows) {
      linesByAccountId.putIfAbsent(row.accountId, () => []).add(OcptBudgetLine.fromRow(row));
    }

    return [
      for (final row in accountRows)
        OcptBudgetAccount.fromRow(row: row, lines: linesByAccountId[row.id] ?? const []),
    ];
  });

  /// Create a new account named [label], appended at the end of the catalogue, and return its
  /// freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseResult<String>> createAccount({
    required OcptProjectDatabase database,
    required String label,
  }) => guardResult("createAccount", () async {
    if (database.refusesUserWrite("createAccount")) {
      return null;
    }

    final existing = await _liveAccountRows(database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetAccountsTable,
        rowId: id,
        current: null,
        next: OcptBudgetAccountRow(
          id: id,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          isDeleted: false,
          code: '',
          label: label,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  });

  /// Update the fields of account [accountId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderAccount] and [deleteAccount].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> updateAccount({
    required OcptProjectDatabase database,
    required String accountId,
    Value<String> code = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<String?> simpleLabel = const Value.absent(),
    Value<int?> estimateToCompleteCents = const Value.absent(),
  }) => guardOutcome("updateAccount", () async {
    if (database.refusesUserWrite("updateAccount")) {
      return;
    }

    final companion = OcptBudgetAccountsTableCompanion(
      code: code,
      label: label,
      simpleLabel: simpleLabel,
      estimateToCompleteCents: estimateToCompleteCents,
    );

    await database.transaction(() async {
      final current = await _liveAccountRowOrNull(database: database, accountId: accountId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetAccountsTable,
        rowId: accountId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Move account [accountId] to [newPosition] (0-based) within the catalogue's flat `sortKey`
  /// order, by giving it a `sortKey` sitting between the two accounts it lands between. Writes
  /// **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> reorderAccount({
    required OcptProjectDatabase database,
    required String accountId,
    required int newPosition,
  }) => guardOutcome("reorderAccount", () async {
    if (database.refusesUserWrite("reorderAccount")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveAccountRowOrNull(database: database, accountId: accountId);
      if (current == null) {
        return;
      }

      final others = (await _liveAccountRows(database))..removeWhere((row) => row.id == accountId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetAccountsTable,
        rowId: accountId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Tombstone account [accountId] in [database] and every live `budget_lines` row it holds, in the
  /// same transaction.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> deleteAccount({
    required OcptProjectDatabase database,
    required String accountId,
  }) => guardOutcome("deleteAccount", () async {
    if (database.refusesUserWrite("deleteAccount")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final lineRows = await _liveLineRowsOfAccount(database, accountId: accountId);
      for (final row in lineRows) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptBudgetLinesTable,
          rowId: row.id,
          current: row,
          next: row.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      final account = await _liveAccountRowOrNull(database: database, accountId: accountId);
      if (account != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptBudgetAccountsTable,
          rowId: accountId,
          current: account,
          next: account.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  });

  /// Create a new line named [label] inside account [accountId], appended at the end of that
  /// account's own lines, and return its freshly generated id.
  ///
  /// [provisionKey], [provisionDigest] and [quantityMilli] are what the logistics view's own
  /// `Provision into the quote` gesture fills in, through [applyProvision] — see
  /// `OcptBudgetLinesTable.provisionKey`. Every other caller leaves all three at [Value.absent],
  /// and the line then reads as one somebody typed, which is what it is.
  ///
  /// [elementId] and [unitAmountCents] are what `OcptBudgetDetail`'s own `From breakdown` gesture
  /// fills in — a line minted from a breakdown element, its own unit price seeded from
  /// `OcptElement.cost` — and what the ordinary `+ Add` footer leaves at [Value.absent], the plain
  /// `+ Add` line reading exactly as it always has. **A null `elements.cost` is passed on as
  /// [Value.absent] too, never as `Value(0)`**: the line this call mints is then left at
  /// `budget_lines.unitAmountCents`'s own ordinary default — a fresh, unpriced line the ordinary
  /// `+ Add` footer already produces — rather than writing a figure that would read as a price
  /// typed on purpose, which nobody has typed.
  ///
  /// [unit] is what a line born already filled — the entry wizard's own `addQuoteLine` gesture —
  /// fills in alongside [label], [quantityMilli] and [unitAmountCents]; every other caller leaves
  /// it at [Value.absent], reading `budget_lines.unit`'s own ordinary default exactly as before
  /// this parameter existed.
  ///
  /// [isTaxInclusive] and [vatRateBasisPoints] are what the detail panel's own `Add to the quote`
  /// banner action fills in — a line promoted from an off-line journal entry, its own tax basis
  /// mirrored exactly rather than left to the ordinary line default — and what every other caller
  /// leaves at [Value.absent], reading `budget_lines`' own ordinary defaults exactly as before
  /// these two parameters existed.
  ///
  /// [inKindResourceId] is what the budget bloc's own in-kind reconciliation fills in when this
  /// line is the counterpart minted for an in-kind contribution — see
  /// `OcptBudgetLinesTable.inKindResourceId`. Every other caller leaves it at [Value.absent], null
  /// being the ordinary case for a line nobody's contribution counterbalances.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseResult<String>> createLine({
    required OcptProjectDatabase database,
    required String accountId,
    required String label,
    Value<String?> elementId = const Value.absent(),
    Value<int> quantityMilli = const Value.absent(),
    Value<String> unit = const Value.absent(),
    Value<int> unitAmountCents = const Value.absent(),
    Value<bool> isTaxInclusive = const Value.absent(),
    Value<int?> vatRateBasisPoints = const Value.absent(),
    Value<String?> provisionKey = const Value.absent(),
    Value<String?> provisionDigest = const Value.absent(),
    Value<String?> inKindResourceId = const Value.absent(),
  }) => guardResult("createLine", () async {
    if (database.refusesUserWrite("createLine")) {
      return null;
    }

    final existing = await _liveLineRowsOfAccount(database, accountId: accountId);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetLinesTable,
        rowId: id,
        current: null,
        next: OcptBudgetLineRow(
          id: id,
          sortKey: ocptFractionalKeyBetween(
            before: existing.isEmpty ? null : existing.last.sortKey,
          ),
          isDeleted: false,
          accountId: accountId,
          label: label,
          quantityMilli: quantityMilli.present ? quantityMilli.value : 1000,
          unit: unit.present ? unit.value : '',
          unitAmountCents: unitAmountCents.present ? unitAmountCents.value : 0,
          isTaxInclusive: !isTaxInclusive.present || isTaxInclusive.value,
          vatRateBasisPoints: vatRateBasisPoints.present ? vatRateBasisPoints.value : null,
          elementId: elementId.present ? elementId.value : null,
          inKindResourceId: inKindResourceId.present ? inKindResourceId.value : null,
          provisionKey: provisionKey.present ? provisionKey.value : null,
          provisionDigest: provisionDigest.present ? provisionDigest.value : null,
          notes: '',
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  });

  /// Update the fields of line [lineId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey`, `isDeleted` or `accountId`: those only change through
  /// [reorderLine] and [deleteLine] — this table carries no "move to another poste" of its own,
  /// which would need its own `sortKey` recomputed against a different group entirely.
  ///
  /// [inKindResourceId] is what the budget bloc's own in-kind reconciliation fills in while
  /// revaluing or renaming an in-kind contribution's counterpart line — every other caller leaves
  /// it at [Value.absent], the link a line already carries left untouched.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> updateLine({
    required OcptProjectDatabase database,
    required String lineId,
    Value<String> label = const Value.absent(),
    Value<int> quantityMilli = const Value.absent(),
    Value<String> unit = const Value.absent(),
    Value<int> unitAmountCents = const Value.absent(),
    Value<bool> isTaxInclusive = const Value.absent(),
    Value<int?> vatRateBasisPoints = const Value.absent(),
    Value<String?> elementId = const Value.absent(),
    Value<String?> provisionKey = const Value.absent(),
    Value<String?> provisionDigest = const Value.absent(),
    Value<String> notes = const Value.absent(),
    Value<String?> inKindResourceId = const Value.absent(),
  }) => guardOutcome("updateLine", () async {
    if (database.refusesUserWrite("updateLine")) {
      return;
    }

    final companion = OcptBudgetLinesTableCompanion(
      label: label,
      quantityMilli: quantityMilli,
      unit: unit,
      unitAmountCents: unitAmountCents,
      isTaxInclusive: isTaxInclusive,
      vatRateBasisPoints: vatRateBasisPoints,
      inKindResourceId: inKindResourceId,
      elementId: elementId,
      provisionKey: provisionKey,
      provisionDigest: provisionDigest,
      notes: notes,
    );

    await database.transaction(() async {
      final current = await _liveLineRowOrNull(database: database, lineId: lineId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetLinesTable,
        rowId: lineId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Move line [lineId] to [newPosition] (0-based) within its own account's `sortKey` order, by
  /// giving it a `sortKey` sitting between the two lines it lands between. Writes **exactly one
  /// row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> reorderLine({
    required OcptProjectDatabase database,
    required String lineId,
    required int newPosition,
  }) => guardOutcome("reorderLine", () async {
    if (database.refusesUserWrite("reorderLine")) {
      return;
    }

    await database.transaction(() async {
      final line = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.id.equals(lineId))).getSingle();

      final others = (await _liveLineRowsOfAccount(database, accountId: line.accountId))
        ..removeWhere((row) => row.id == lineId);

      final clampedPosition = newPosition < 0
          ? 0
          : (newPosition > others.length ? others.length : newPosition);

      final sortKey = ocptFractionalKeyBetween(
        before: clampedPosition > 0 ? others[clampedPosition - 1].sortKey : null,
        after: clampedPosition < others.length ? others[clampedPosition].sortKey : null,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetLinesTable,
        rowId: lineId,
        current: line,
        next: line.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Tombstone line [lineId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> deleteLine({
    required OcptProjectDatabase database,
    required String lineId,
  }) => guardOutcome("deleteLine", () async {
    if (database.refusesUserWrite("deleteLine")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveLineRowOrNull(database: database, lineId: lineId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetLinesTable,
        rowId: lineId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  });

  /// Write [entries] onto account [accountId], one quote line per nature — the logistics view's own
  /// `Provision into the quote` gesture.
  ///
  /// **Takes a plan rather than computing one**: `ocptBudgetProvisionPlanOf` decides what would
  /// happen, whole, before anything is written, so the mode can put those counts in front of the
  /// user and let them say no. This method carries the plan out and nothing else.
  ///
  /// - [OcptBudgetProvisionOutcome.created] mints a line stamped with its nature's own key;
  /// - [OcptBudgetProvisionOutcome.updated] rewrites the wording, the quantity and the unit price
  ///   of a line the provisioning itself last wrote, and re-stamps it;
  /// - [OcptBudgetProvisionOutcome.unchanged] and [OcptBudgetProvisionOutcome.skippedEdited] write
  ///   **nothing at all** — the first has nothing to say, and the second is a line somebody has
  ///   retouched by hand, which this app does not silently correct.
  ///
  /// Every write happens in one transaction: a provisioning that fails halfway would leave a quote
  /// stating a total nobody could account for. [createLine] and [updateLine] each seed and flush
  /// their own [OcptRowStampService] inside this outer transaction, one per entry, exactly as they
  /// do for any other caller.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  @useResult
  Future<OcptDatabaseOutcome> applyProvision({
    required OcptProjectDatabase database,
    required String accountId,
    required List<OcptBudgetProvisionEntry> entries,
  }) => guardOutcome("applyProvision", () async {
    if (database.refusesUserWrite("applyProvision")) {
      return;
    }

    await database.transaction(() async {
      for (final entry in entries) {
        switch (entry.outcome) {
          case OcptBudgetProvisionOutcome.created:
            await createLine(
              database: database,
              accountId: accountId,
              label: entry.label,
              quantityMilli: Value(entry.quantityMilli),
              unitAmountCents: Value(entry.unitAmountCents),
              provisionKey: Value(entry.kind.name),
              provisionDigest: Value(entry.digest),
            ).valueOrAbort();
          case OcptBudgetProvisionOutcome.updated:
            await updateLine(
              database: database,
              lineId: entry.lineId!,
              label: Value(entry.label),
              quantityMilli: Value(entry.quantityMilli),
              unitAmountCents: Value(entry.unitAmountCents),
              provisionDigest: Value(entry.digest),
            ).okOrAbort();
          case OcptBudgetProvisionOutcome.unchanged:
          case OcptBudgetProvisionOutcome.skippedEdited:
            break;
        }
      }
    });
  });

  /// Seed [database]'s `budget_postes` table with [seed], **once**: only when the table holds
  /// **no row at all, tombstones included**. A user who deleted every account has not asked for
  /// them back, and a table already holding rows — seeded earlier, or built up by hand on a project
  /// that predates this seed list — is left exactly as it is.
  ///
  /// Guarded like every other write: a preview connection never gains a seeded row it would then
  /// show as if the user had asked for it.
  Future<void> _seedIfEmpty({
    required OcptProjectDatabase database,
    required List<OcptBudgetAccountSeed> seed,
  }) async {
    if (database.refusesUserWrite("seedBudgetAccounts") || seed.isEmpty) {
      return;
    }

    await database.transaction(() async {
      final anyRow = await (database.select(
        database.ocptBudgetAccountsTable,
      )..limit(1)).getSingleOrNull();
      if (anyRow != null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final keys = ocptFractionalKeySequence(seed.length);
      for (var i = 0; i < seed.length; i++) {
        final accountSeed = seed[i];
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptBudgetAccountsTable,
          rowId: accountSeed.id,
          current: null,
          next: OcptBudgetAccountRow(
            id: accountSeed.id,
            sortKey: keys[i],
            isDeleted: false,
            code: accountSeed.code,
            label: accountSeed.label,
            simpleLabel: accountSeed.simpleLabel,
          ),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Get every live account row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetAccountRow>> _liveAccountRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetAccountsTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get the live account row [accountId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetAccountRow?> _liveAccountRowOrNull({
    required OcptProjectDatabase database,
    required String accountId,
  }) => (database.select(
    database.ocptBudgetAccountsTable,
  )..where((table) => table.id.equals(accountId) & table.isDeleted.not())).getSingleOrNull();

  /// Get every live line row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetLineRow>> _liveLineRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetLinesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get every live line row of account [accountId], ordered by `sortKey`.
  Future<List<OcptBudgetLineRow>> _liveLineRowsOfAccount(
    OcptProjectDatabase database, {
    required String accountId,
  }) =>
      (database.select(database.ocptBudgetLinesTable)
            ..where((table) => table.accountId.equals(accountId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Get the live line row [lineId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetLineRow?> _liveLineRowOrNull({
    required OcptProjectDatabase database,
    required String lineId,
  }) => (database.select(
    database.ocptBudgetLinesTable,
  )..where((table) => table.id.equals(lineId) & table.isDeleted.not())).getSingleOrNull();
}
