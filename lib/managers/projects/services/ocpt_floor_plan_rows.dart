// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

/// The reads and cascades every floor plan operation shares: the plan row (created lazily), the
/// symbol, shot and arrow rows looked up by id or under a set, and the tombstoning of the arrows
/// touching a symbol.
///
/// Stateless, so a call takes the database it works on, the same shape every service's own private
/// query helpers have.
abstract final class OcptFloorPlanRows {
  /// Create the plan row of Resources set [setId] if none exists yet, from inside the caller's
  /// own transaction and stamping through its own [stamps] — **idempotent**, and safe under
  /// concurrent replicas: the plan's own row id **is** [setId] (`OcptFloorPlanSetsTable`'s own doc
  /// comment), so two devices that each place the first symbol on the same set while offline
  /// converge on one row through the sync merge rather than each minting their own.
  static Future<void> ensurePlan({
    required OcptProjectDatabase database,
    required String setId,
    required OcptRowStampService stamps,
  }) async {
    final existing = await (database.select(
      database.ocptFloorPlanSetsTable,
    )..where((table) => table.id.equals(setId))).getSingleOrNull();
    if (existing != null) {
      return;
    }

    await OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptFloorPlanSetsTable,
      rowId: setId,
      current: null,
      next: OcptFloorPlanSetRow(id: setId, isDeleted: false),
      stamps: stamps,
    );
  }

  /// Read back the live plan row of Resources set [setId], or null if it doesn't exist yet or have
  /// been tombstoned.
  static Future<OcptFloorPlanSetRow?> livePlanRowOrNull({
    required OcptProjectDatabase database,
    required String setId,
  }) => (database.select(
    database.ocptFloorPlanSetsTable,
  )..where((table) => table.id.equals(setId) & table.isDeleted.not())).getSingleOrNull();

  /// Get every live symbol row of set [setId].
  static Future<List<OcptFloorPlanSymbolRow>> symbolRowsOfSet({
    required OcptProjectDatabase database,
    required String setId,
  }) => (database.select(
    database.ocptFloorPlanSymbolsTable,
  )..where((table) => table.setId.equals(setId) & table.isDeleted.not())).get();

  /// Get every live symbol row of set [setId] on layer [layer], ordered by `sortKey` — what a new
  /// symbol of that layer is appended after.
  static Future<List<OcptFloorPlanSymbolRow>> symbolRowsOfSetAndLayer({
    required OcptProjectDatabase database,
    required String setId,
    required OcptFloorPlanLayer layer,
  }) =>
      (database.select(database.ocptFloorPlanSymbolsTable)
            ..where(
              (table) =>
                  table.setId.equals(setId) &
                  table.layer.equalsValue(layer) &
                  table.isDeleted.not(),
            )
            ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
          .get();

  /// Read back the live symbol row [symbolId], or null if it doesn't exist or have been tombstoned.
  static Future<OcptFloorPlanSymbolRow?> liveSymbolRowOrNull({
    required OcptProjectDatabase database,
    required String symbolId,
  }) => (database.select(
    database.ocptFloorPlanSymbolsTable,
  )..where((table) => table.id.equals(symbolId) & table.isDeleted.not())).getSingleOrNull();

  /// Read back the live shot row [shotId], or null if it doesn't exist or have been tombstoned —
  /// `placeSymbol`'s own way of checking a shot-scope override's own shot belongs to the sequence
  /// its target scene-scope symbol does.
  static Future<OcptShotRow?> liveShotRowOrNull({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(
    database.ocptShotsTable,
  )..where((table) => table.id.equals(shotId) & table.isDeleted.not())).getSingleOrNull();

  /// Get every live arrow row of set [setId].
  static Future<List<OcptFloorPlanArrowRow>> arrowRowsOfSet({
    required OcptProjectDatabase database,
    required String setId,
  }) => (database.select(
    database.ocptFloorPlanArrowsTable,
  )..where((table) => table.setId.equals(setId) & table.isDeleted.not())).get();

  /// Read back the live arrow row [arrowId], or null if it doesn't exist or have been tombstoned.
  static Future<OcptFloorPlanArrowRow?> liveArrowRowOrNull({
    required OcptProjectDatabase database,
    required String arrowId,
  }) => (database.select(
    database.ocptFloorPlanArrowsTable,
  )..where((table) => table.id.equals(arrowId) & table.isDeleted.not())).getSingleOrNull();

  /// Tombstone every live arrow whose [OcptFloorPlanArrow.fromSymbolId] or
  /// [OcptFloorPlanArrow.toSymbolId] equals [symbolId] — the write body `deleteSymbol` and
  /// `tombstoneFloorPlanRowsOfShot` share.
  static Future<void> tombstoneArrowsTouchingSymbol({
    required OcptProjectDatabase database,
    required String symbolId,
    required OcptRowStampService? stamps,
  }) async {
    final rows =
        await (database.select(database.ocptFloorPlanArrowsTable)..where(
              (table) =>
                  (table.fromSymbolId.equals(symbolId) | table.toSymbolId.equals(symbolId)) &
                  table.isDeleted.not(),
            ))
            .get();

    for (final row in rows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanArrowsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }
}
