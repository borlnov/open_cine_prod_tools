// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over the budget mode's revenue sharing: the `budget_revenues` takings and the
/// `budget_shares` splitting what they bring in.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **No seeding of any kind, unlike `OcptBudgetQuoteService`'s own ten CNC postes.** This app names
/// no taking and no participant of its own — a revenue and a sharing plan are entirely the
/// production's own business — so both tables come out of [loadRevenues]/[loadShares] exactly as
/// empty as the project that has never been read from before them.
///
/// **Both tables order flat by their own `sortKey`**, like `OcptBudgetFinancingService`'s own two
/// tables: neither a revenue nor a share belongs inside another row the way a quote line belongs
/// inside its poste.
class OcptBudgetSharingService {
  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter].
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptBudgetSharingService({required this.deviceId});

  /// Loads every live revenue of [database], in `sortKey` order.
  Future<List<OcptBudgetRevenue>> loadRevenues({required OcptProjectDatabase database}) async {
    final rows = await _liveRevenueRows(database);
    return [for (final row in rows) OcptBudgetRevenue.fromRow(row)];
  }

  /// Creates a new revenue named [label], appended at the end of the sharing view's own list, and
  /// returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createRevenue({
    required OcptProjectDatabase database,
    required DateTime date,
    required String label,
  }) async {
    if (database.refusesUserWrite("createRevenue")) {
      return null;
    }

    final existing = await _liveRevenueRows(database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetRevenuesTable,
        rowId: id,
        current: null,
        next: OcptBudgetRevenueRow(
          id: id,
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
          date: date,
          label: label,
          amountCents: 0,
          status: OcptBudgetRevenueStatus.expected,
          notes: '',
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of revenue [revenueId] in [database] that are passed as something other
  /// than [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderRevenue] and [deleteRevenue].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateRevenue({
    required OcptProjectDatabase database,
    required String revenueId,
    Value<DateTime> date = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<int> amountCents = const Value.absent(),
    Value<OcptBudgetRevenueStatus> status = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateRevenue")) {
      return;
    }

    final companion = OcptBudgetRevenuesTableCompanion(
      date: date,
      label: label,
      amountCents: amountCents,
      status: status,
      notes: notes,
    );

    await database.transaction(() async {
      final current = await _liveRevenueRowOrNull(database: database, revenueId: revenueId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetRevenuesTable,
        rowId: revenueId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves revenue [revenueId] to [newPosition] (0-based) within the sharing view's own flat
  /// `sortKey` order, by giving it a `sortKey` sitting between the two revenues it lands between.
  /// Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderRevenue({
    required OcptProjectDatabase database,
    required String revenueId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderRevenue")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveRevenueRowOrNull(database: database, revenueId: revenueId);
      if (current == null) {
        return;
      }

      final others = (await _liveRevenueRows(database))..removeWhere((row) => row.id == revenueId);

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
        table: database.ocptBudgetRevenuesTable,
        rowId: revenueId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones revenue [revenueId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteRevenue({
    required OcptProjectDatabase database,
    required String revenueId,
  }) async {
    if (database.refusesUserWrite("deleteRevenue")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveRevenueRowOrNull(database: database, revenueId: revenueId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetRevenuesTable,
        rowId: revenueId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Loads every live share of [database], in `sortKey` order.
  Future<List<OcptBudgetShare>> loadShares({required OcptProjectDatabase database}) async {
    final rows = await _liveShareRows(database);
    return [for (final row in rows) OcptBudgetShare.fromRow(row)];
  }

  /// Creates a new share named [label], appended at the end of the sharing view's own list, and
  /// returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> createShare({
    required OcptProjectDatabase database,
    required String label,
  }) async {
    if (database.refusesUserWrite("createShare")) {
      return null;
    }

    final existing = await _liveShareRows(database);
    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetSharesTable,
        rowId: id,
        current: null,
        next: OcptBudgetShareRow(
          id: id,
          sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
          isDeleted: false,
          label: label,
          sharePermille: 0,
          reinvestPermille: 0,
          notes: '',
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates the fields of share [shareId] in [database] that are passed as something other than
  /// [Value.absent]. Never touches `sortKey` or `isDeleted`: those only change through
  /// [reorderShare] and [deleteShare].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateShare({
    required OcptProjectDatabase database,
    required String shareId,
    Value<String?> personId = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<int> sharePermille = const Value.absent(),
    Value<int> reinvestPermille = const Value.absent(),
    Value<String> notes = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateShare")) {
      return;
    }

    final companion = OcptBudgetSharesTableCompanion(
      personId: personId,
      label: label,
      sharePermille: sharePermille,
      reinvestPermille: reinvestPermille,
      notes: notes,
    );

    await database.transaction(() async {
      final current = await _liveShareRowOrNull(database: database, shareId: shareId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetSharesTable,
        rowId: shareId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves share [shareId] to [newPosition] (0-based) within the sharing view's own flat `sortKey`
  /// order, by giving it a `sortKey` sitting between the two shares it lands between. Writes
  /// **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderShare({
    required OcptProjectDatabase database,
    required String shareId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderShare")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveShareRowOrNull(database: database, shareId: shareId);
      if (current == null) {
        return;
      }

      final others = (await _liveShareRows(database))..removeWhere((row) => row.id == shareId);

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
        table: database.ocptBudgetSharesTable,
        rowId: shareId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones share [shareId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteShare({required OcptProjectDatabase database, required String shareId}) async {
    if (database.refusesUserWrite("deleteShare")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveShareRowOrNull(database: database, shareId: shareId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptBudgetSharesTable,
        rowId: shareId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Every live revenue row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetRevenueRow>> _liveRevenueRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetRevenuesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The live revenue row [revenueId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetRevenueRow?> _liveRevenueRowOrNull({
    required OcptProjectDatabase database,
    required String revenueId,
  }) => (database.select(database.ocptBudgetRevenuesTable)
        ..where((table) => table.id.equals(revenueId) & table.isDeleted.not()))
      .getSingleOrNull();

  /// Every live share row of [database], ordered by `sortKey`.
  Future<List<OcptBudgetShareRow>> _liveShareRows(OcptProjectDatabase database) =>
      (database.select(database.ocptBudgetSharesTable)
            ..where((table) => table.isDeleted.not())
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// The live share row [shareId], or null if it doesn't exist or has been tombstoned.
  Future<OcptBudgetShareRow?> _liveShareRowOrNull({
    required OcptProjectDatabase database,
    required String shareId,
  }) => (database.select(database.ocptBudgetSharesTable)
        ..where((table) => table.id.equals(shareId) & table.isDeleted.not()))
      .getSingleOrNull();
}
