// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:uuid/uuid.dart';

/// The arrows drawn between the symbols of a floor plan.
///
/// What `OcptFloorPlanService` forwards to; see `OcptFloorPlanReadOps`.
abstract final class OcptFloorPlanArrowOps {
  /// Adds a new [kind] arrow on set [setId] — creating its plan row if it doesn't exist yet
  /// ([OcptFloorPlanRows.ensurePlan]) — belonging to shot [shotId] (always set — an arrow is always one shot's own
  /// movement, `OcptFloorPlanArrowsTable`'s own doc comment), from [fromSymbolId] to [toSymbolId],
  /// and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<String?> addArrow({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String setId,
    required String shotId,
    required OcptFloorPlanArrowKind kind,
    required String fromSymbolId,
    required String toSymbolId,
    String label = '',
  }) async {
    if (database.refusesUserWrite("addArrow")) {
      return null;
    }

    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptFloorPlanRows.ensurePlan(database: database, setId: setId, stamps: stamps);

      final row = OcptFloorPlanArrowRow(
        id: id,
        setId: setId,
        shotId: shotId,
        kind: kind,
        fromSymbolId: fromSymbolId,
        toSymbolId: toSymbolId,
        label: label,
        isDeleted: false,
      );

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanArrowsTable,
        rowId: id,
        current: null,
        next: row,
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates arrow [arrowId]'s label.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> setArrowLabel({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String arrowId,
    required String label,
  }) async {
    if (database.refusesUserWrite("setArrowLabel")) {
      return;
    }

    await database.transaction(() async {
      final current = await OcptFloorPlanRows.liveArrowRowOrNull(
        database: database,
        arrowId: arrowId,
      );
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanArrowsTable,
        rowId: arrowId,
        current: current,
        next: current.copyWith(label: label),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Updates arrow [arrowId]'s bezier control point — `(ctrlXM, ctrlYM)`, in metres — bending it
  /// into a curve, or straightening it back out by writing both `const Value(null)`. Writes only
  /// these two columns.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> updateArrowCurve({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String arrowId,
    required Value<double?> ctrlXM,
    required Value<double?> ctrlYM,
  }) async {
    if (database.refusesUserWrite("updateArrowCurve")) {
      return;
    }

    final companion = OcptFloorPlanArrowsTableCompanion(ctrlXM: ctrlXM, ctrlYM: ctrlYM);

    await database.transaction(() async {
      final current = await OcptFloorPlanRows.liveArrowRowOrNull(
        database: database,
        arrowId: arrowId,
      );
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanArrowsTable,
        rowId: arrowId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones arrow [arrowId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> deleteArrow({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String arrowId,
  }) async {
    if (database.refusesUserWrite("deleteArrow")) {
      return;
    }

    await database.transaction(() async {
      final current = await OcptFloorPlanRows.liveArrowRowOrNull(
        database: database,
        arrowId: arrowId,
      );
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanArrowsTable,
        rowId: arrowId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }
}
