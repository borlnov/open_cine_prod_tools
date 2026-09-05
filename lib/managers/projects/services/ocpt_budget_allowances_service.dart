// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the budget mode's defrayals: the `budget_allowances` a production types for itself.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Nothing here reads the schedule, and nothing seeds a row**, unlike the catering half of the
/// régie view sitting above these rows on screen: a defrayal is not derivable from a presence — see
/// `OcptBudgetAllowancesTable`'s own doc comment — so the only rows this service ever returns are
/// the ones somebody wrote.
///
/// **Orders flat by `sortKey`**, like the financing plan's own two catalogues: a defrayal belongs
/// inside no other row.
class OcptBudgetAllowancesService {
  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter].
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptBudgetAllowancesService({required this.deviceId});

  /// Loads every live defrayal of [database], in `sortKey` order.
  Future<List<OcptBudgetAllowance>> loadAllowances({required OcptProjectDatabase database}) async {
    final rows = await _liveAllowanceRows(database);
    return [for (final row in rows) OcptBudgetAllowance.fromRow(row)];
  }

  /// Creates a new defrayal, appended at the end of the list, and returns its freshly generated id.
  ///
  /// Every field but the ordering is taken as passed rather than left to a default: this row is
  /// only ever minted from a dialog the user has already filled in, unlike a resource, which is
  /// created empty and named afterwards.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createAllowance({
    required OcptProjectDatabase database,
    required String? personId,
    required OcptBudgetAllowanceKind kind,
    required String label,
    required DateTime? date,
    required DateTime? endDate,
    required int quantityMilli,
    required int unitAmountMilliCents,
    required String notes,
  }) async {
    if (database.refusesUserWrite("createAllowance")) {
      return null;
    }

    final existing = await _liveAllowanceRows(database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetAllowancesTable,
        rowId: id,
        current: null,
        next: OcptBudgetAllowanceRow(
          id: id,
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
          personId: personId,
          kind: kind,
          label: label,
          date: date,
          endDate: endDate,
          quantityMilli: quantityMilli,
          unitAmountMilliCents: unitAmountMilliCents,
          notes: notes,
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of defrayal [allowanceId] in [database] that are passed as something other
  /// than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderAllowance] and [deleteAllowance].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateAllowance({
    required OcptProjectDatabase database,
    required String allowanceId,
    Value<String?> personId = const Value.absent(),
    Value<OcptBudgetAllowanceKind> kind = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<DateTime?> date = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    Value<int> quantityMilli = const Value.absent(),
    Value<int> unitAmountMilliCents = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateAllowance")) {
      return;
    }

    final companion = OcptBudgetAllowancesTableCompanion(
      personId: personId,
      kind: kind,
      label: label,
      date: date,
      endDate: endDate,
      quantityMilli: quantityMilli,
      unitAmountMilliCents: unitAmountMilliCents,
      notes: notes,
    );

    await database.transaction(() async {
      // This lookup deliberately does not filter `isDeleted`, matching the plain `where` update
      // this method wrote before stamping existed: a defrayal's own tombstone was never guarded
      // against here, unlike every other table's own `updateX`.
      final current = await (database.select(
        database.ocptBudgetAllowancesTable,
      )..where((table) => table.id.equals(allowanceId))).getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetAllowancesTable,
        rowId: allowanceId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves defrayal [allowanceId] to [newPosition] (0-based) within the list's own flat `sortKey`
  /// order, by giving it a `sortKey` sitting between the two rows it lands between. Writes
  /// **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderAllowance({
    required OcptProjectDatabase database,
    required String allowanceId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderAllowance")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveAllowanceRowOrNull(database: database, allowanceId: allowanceId);
      if (current == null) {
        return;
      }

      final others = (await _liveAllowanceRows(database))
        ..removeWhere((row) => row.id == allowanceId);

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
        table: database.ocptBudgetAllowancesTable,
        rowId: allowanceId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones defrayal [allowanceId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteAllowance({
    required OcptProjectDatabase database,
    required String allowanceId,
  }) async {
    if (database.refusesUserWrite("deleteAllowance")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveAllowanceRowOrNull(database: database, allowanceId: allowanceId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetAllowancesTable,
        rowId: allowanceId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Every live defrayal row of [database], in `sortKey` order.
  Future<List<OcptBudgetAllowanceRow>> _liveAllowanceRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetAllowancesTable)
            ..where((table) => table.isDeleted.equals(false))
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The live defrayal row [allowanceId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetAllowanceRow?> _liveAllowanceRowOrNull({
    required OcptProjectDatabase database,
    required String allowanceId,
  }) => (database.select(database.ocptBudgetAllowancesTable)
        ..where((table) => table.id.equals(allowanceId) & table.isDeleted.not()))
      .getSingleOrNull();
}
