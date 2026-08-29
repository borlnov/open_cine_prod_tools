// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_provision.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the budget mode's quote: the `budget_postes` catalogue and the `budget_lines` inside
/// each one.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Seeds the ten CNC postes on the first read of an empty `budget_postes` table**
/// ([loadPostes]), not at project creation, so an existing project gets them too — the labels are
/// resolved by the caller (`OcptBudgetPosteSeed`, already localized), since no service ever sees a
/// `Tr`.
///
/// **`budget_postes` is ordered flat by `sortKey`**, like `OcptElementsService`'s own catalogue —
/// see that service's doc comment for why one flat order beats one order per department.
/// **`budget_lines` is ordered by `sortKey` within its own `posteId`**, like
/// `OcptShotListService`'s shots within a scene: a line only ever competes for a position against
/// the other lines of the very poste it prices.
class OcptBudgetQuoteService {
  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter].
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptBudgetQuoteService({required this.deviceId});

  /// Loads every live poste of [database], in `sortKey` order, each joined with its own live
  /// `budget_lines` rows (themselves in their own `sortKey` order) — seeding [seed] first if the
  /// table holds no row at all, tombstones included.
  Future<List<OcptBudgetPoste>> loadPostes({
    required OcptProjectDatabase database,
    required List<OcptBudgetPosteSeed> seed,
  }) async {
    await _seedIfEmpty(database: database, seed: seed);

    final posteRows = await _livePosteRows(database);
    final lineRows = await _liveLineRows(database);

    final linesByPosteId = <String, List<OcptBudgetLine>>{};
    for (final row in lineRows) {
      linesByPosteId.putIfAbsent(row.posteId, () => []).add(OcptBudgetLine.fromRow(row));
    }

    return [
      for (final row in posteRows)
        OcptBudgetPoste.fromRow(row: row, lines: linesByPosteId[row.id] ?? const []),
    ];
  }

  /// Seeds [database]'s `budget_postes` table with [seed], **once**: only when the table holds
  /// **no row at all, tombstones included**. A user who deleted every poste has not asked for them
  /// back, and a table already holding rows — seeded earlier, or built up by hand on a project that
  /// predates this seed list — is left exactly as it is.
  ///
  /// Guarded like every other write: a preview connection never gains a seeded row it would then
  /// show as if the user had asked for it.
  Future<void> _seedIfEmpty({
    required OcptProjectDatabase database,
    required List<OcptBudgetPosteSeed> seed,
  }) async {
    if (database.refusesUserWrite("seedBudgetPostes") || seed.isEmpty) {
      return;
    }

    await database.transaction(() async {
      final anyRow = await (database.select(
        database.ocptBudgetPostesTable,
      )..limit(1)).getSingleOrNull();
      if (anyRow != null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final keys = ocptFractionalKeySequence(seed.length);
      for (var i = 0; i < seed.length; i++) {
        final posteSeed = seed[i];
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptBudgetPostesTable,
          rowId: posteSeed.id,
          current: null,
          next: OcptBudgetPosteRow(
            id: posteSeed.id,
            sortKey: keys[i],
            isDeleted: false,
            code: posteSeed.code,
            label: posteSeed.label,
            simpleLabel: posteSeed.simpleLabel,
          ),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Creates a new poste named [label], appended at the end of the catalogue, and returns its
  /// freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createPoste({
    required OcptProjectDatabase database,
    required String label,
  }) async {
    if (database.refusesUserWrite("createPoste")) {
      return null;
    }

    final existing = await _livePosteRows(database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetPostesTable,
        rowId: id,
        current: null,
        next: OcptBudgetPosteRow(
          id: id,
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
          code: '',
          label: label,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of poste [posteId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderPoste] and [deletePoste].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updatePoste({
    required OcptProjectDatabase database,
    required String posteId,
    Value<String> code = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<String?> simpleLabel = const Value.absent(),
    Value<int?> estimateToCompleteCents = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updatePoste")) {
      return;
    }

    final companion = OcptBudgetPostesTableCompanion(
      code: code,
      label: label,
      simpleLabel: simpleLabel,
      estimateToCompleteCents: estimateToCompleteCents,
    );

    await database.transaction(() async {
      final current = await _livePosteRowOrNull(database: database, posteId: posteId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetPostesTable,
        rowId: posteId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves poste [posteId] to [newPosition] (0-based) within the catalogue's flat `sortKey` order,
  /// by giving it a `sortKey` sitting between the two postes it lands between. Writes **exactly one
  /// row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderPoste({
    required OcptProjectDatabase database,
    required String posteId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderPoste")) {
      return;
    }

    await database.transaction(() async {
      final current = await _livePosteRowOrNull(database: database, posteId: posteId);
      if (current == null) {
        return;
      }

      final others = (await _livePosteRows(database))..removeWhere((row) => row.id == posteId);

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
        table: database.ocptBudgetPostesTable,
        rowId: posteId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones poste [posteId] in [database] and every live `budget_lines` row it holds, in the
  /// same transaction.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deletePoste({
    required OcptProjectDatabase database,
    required String posteId,
  }) async {
    if (database.refusesUserWrite("deletePoste")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final lineRows = await _liveLineRowsOfPoste(database, posteId: posteId);
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

      final poste = await _livePosteRowOrNull(database: database, posteId: posteId);
      if (poste != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptBudgetPostesTable,
          rowId: posteId,
          current: poste,
          next: poste.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Creates a new line named [label] inside poste [posteId], appended at the end of that poste's
  /// own lines, and returns its freshly generated id.
  ///
  /// [provisionKey], [provisionDigest] and [quantityMilli] are what the régie view's own
  /// `Provision into the quote` gesture fills in, through [applyProvision] — see
  /// `OcptBudgetLinesTable.provisionKey`. Every other caller leaves all three at [Value.absent],
  /// and the line then reads as one somebody typed, which is what it is.
  ///
  /// [elementId] and [unitAmountCents] are what `OcptBudgetFiche`'s own `From breakdown`
  /// gesture fills in — a line minted from a breakdown element, its own unit price seeded from
  /// `OcptElement.cost` — and what the ordinary `+ Add` footer leaves at [Value.absent], the plain
  /// `+ Add` line reading exactly as it always has. **A null `elements.cost` is passed on as
  /// [Value.absent] too, never as `Value(0)`**: the line this call mints is then left at
  /// `budget_lines.unitAmountCents`'s own ordinary default — a fresh, unpriced line the ordinary
  /// `+ Add` footer already produces — rather than writing a figure that would read as a price typed
  /// on purpose, which nobody has typed.
  ///
  /// [unit] is what a line born already filled — the entry wizard's own `addQuoteLine` gesture —
  /// fills in alongside [label], [quantityMilli] and [unitAmountCents]; every other caller leaves
  /// it at [Value.absent], reading `budget_lines.unit`'s own ordinary default exactly as before this
  /// parameter existed.
  ///
  /// [isTaxInclusive] and [vatRateBasisPoints] are what the fiche's own `Add to the quote` banner
  /// action fills in — a line promoted from an off-line journal entry, its own tax basis mirrored
  /// exactly rather than left to the ordinary line default — and what every other caller leaves at
  /// [Value.absent], reading `budget_lines`' own ordinary defaults exactly as before these two
  /// parameters existed.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createLine({
    required OcptProjectDatabase database,
    required String posteId,
    required String label,
    Value<String?> elementId = const Value.absent(),
    Value<int> quantityMilli = const Value.absent(),
    Value<String> unit = const Value.absent(),
    Value<int> unitAmountCents = const Value.absent(),
    Value<bool> isTaxInclusive = const Value.absent(),
    Value<int?> vatRateBasisPoints = const Value.absent(),
    Value<String?> provisionKey = const Value.absent(),
    Value<String?> provisionDigest = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("createLine")) {
      return null;
    }

    final existing = await _liveLineRowsOfPoste(database, posteId: posteId);
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
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
          posteId: posteId,
          label: label,
          quantityMilli: quantityMilli.present ? quantityMilli.value : 1000,
          unit: unit.present ? unit.value : '',
          unitAmountCents: unitAmountCents.present ? unitAmountCents.value : 0,
          isTaxInclusive: !isTaxInclusive.present || isTaxInclusive.value,
          vatRateBasisPoints: vatRateBasisPoints.present ? vatRateBasisPoints.value : null,
          elementId: elementId.present ? elementId.value : null,
          provisionKey: provisionKey.present ? provisionKey.value : null,
          provisionDigest: provisionDigest.present ? provisionDigest.value : null,
          notes: '',
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of line [lineId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey`, `isDeleted` or `posteId`: those only change through
  /// [reorderLine] and [deleteLine] — this table carries no "move to another poste" of its own,
  /// which would need its own `sortKey` recomputed against a different group entirely.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateLine({
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
  }) async {
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
  }

  /// Moves line [lineId] to [newPosition] (0-based) within its own poste's `sortKey` order, by
  /// giving it a `sortKey` sitting between the two lines it lands between. Writes **exactly one
  /// row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderLine({
    required OcptProjectDatabase database,
    required String lineId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderLine")) {
      return;
    }

    await database.transaction(() async {
      final line = await (database.select(
        database.ocptBudgetLinesTable,
      )..where((table) => table.id.equals(lineId))).getSingle();

      final others =
          (await _liveLineRowsOfPoste(database, posteId: line.posteId))
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
  }

  /// Tombstones line [lineId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteLine({required OcptProjectDatabase database, required String lineId}) async {
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
  }

  /// Writes [entries] onto poste [posteId], one quote line per nature — the régie view's own
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
  Future<void> applyProvision({
    required OcptProjectDatabase database,
    required String posteId,
    required List<OcptBudgetProvisionEntry> entries,
  }) async {
    if (database.refusesUserWrite("applyProvision")) {
      return;
    }

    await database.transaction(() async {
      for (final entry in entries) {
        switch (entry.outcome) {
          case OcptBudgetProvisionOutcome.created:
            await createLine(
              database: database,
              posteId: posteId,
              label: entry.label,
              quantityMilli: Value(entry.quantityMilli),
              unitAmountCents: Value(entry.unitAmountCents),
              provisionKey: Value(entry.kind.name),
              provisionDigest: Value(entry.digest),
            );
          case OcptBudgetProvisionOutcome.updated:
            await updateLine(
              database: database,
              lineId: entry.lineId!,
              label: Value(entry.label),
              quantityMilli: Value(entry.quantityMilli),
              unitAmountCents: Value(entry.unitAmountCents),
              provisionDigest: Value(entry.digest),
            );
          case OcptBudgetProvisionOutcome.unchanged:
          case OcptBudgetProvisionOutcome.skippedEdited:
            break;
        }
      }
    });
  }

  /// Every live poste row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetPosteRow>> _livePosteRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetPostesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The live poste row [posteId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetPosteRow?> _livePosteRowOrNull({
    required OcptProjectDatabase database,
    required String posteId,
  }) => (database.select(database.ocptBudgetPostesTable)
        ..where((table) => table.id.equals(posteId) & table.isDeleted.not()))
      .getSingleOrNull();

  /// Every live line row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetLineRow>> _liveLineRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetLinesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Every live line row of poste [posteId], ordered by `sortKey`.
  Future<List<OcptBudgetLineRow>> _liveLineRowsOfPoste(
    OcptProjectDatabase database, {
    required String posteId,
  }) =>
      (database.select(database.ocptBudgetLinesTable)
            ..where((table) => table.posteId.equals(posteId) & table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The live line row [lineId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetLineRow?> _liveLineRowOrNull({
    required OcptProjectDatabase database,
    required String lineId,
  }) => (database.select(database.ocptBudgetLinesTable)
        ..where((table) => table.id.equals(lineId) & table.isDeleted.not()))
      .getSingleOrNull();
}
