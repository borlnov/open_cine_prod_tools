// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:uuid/uuid.dart';

/// What a set or a shot owes its floor plan beyond a single symbol: the plan copied along with a
/// duplicated set, a shot's blocking copied to another, and the rows tombstoned with a shot or a
/// set.
///
/// What `OcptFloorPlanService` forwards to; see `OcptFloorPlanReadOps`.
abstract final class OcptFloorPlanCascadeOps {
  /// Copy Resources set [sourceSetId]'s own live **set-scope** symbols (`sceneId` and `shotId`
  /// both null — the set's own décor, never a scene's re-dressing nor a shot's blocking) onto set
  /// [destinationSetId]'s plan, as independent copies (fresh ids, never links), creating that
  /// destination plan if it doesn't exist yet ([OcptFloorPlanRows.ensurePlan]).
  ///
  /// **This is only the copying half of "duplicate this set"**:
  /// minting [destinationSetId] as a fresh Resources set in the same location
  /// (`OcptLocationsService.createSiblingSet`) and linking it to the calling scene
  /// (`OcptLocationsService.assignSceneToSet`) are the other two steps, and this service
  /// deliberately does not take them on. `OcptLocationsService` already depends on this one (for
  /// its own delete cascade, [tombstoneFloorPlanRowsOfSet]), and dependencies never reference their
  /// dependents, so this service cannot depend back on `OcptLocationsService` to mint the set
  /// itself — `OcptShotListBloc`, which already holds both services, is what calls all three in
  /// order and reports the new set id back to its own state.
  ///
  /// A no-op while [sourceSetId] carries no plan or no set-scope symbol at all.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> duplicateSet({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String destinationSetId,
  }) async {
    if (database.refusesUserWrite("duplicateSet")) {
      return;
    }

    await database.transaction(() async {
      final setScopeSymbols =
          (await OcptFloorPlanRows.symbolRowsOfSet(database: database, setId: sourceSetId))
              .where(
                (row) =>
                    ocptFloorPlanScopeOf(sceneId: row.sceneId, shotId: row.shotId) ==
                    OcptFloorPlanScope.set,
              )
              .toList()
            ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

      if (setScopeSymbols.isEmpty) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptFloorPlanRows.ensurePlan(
        database: database,
        setId: destinationSetId,
        stamps: stamps,
      );

      for (final row in setScopeSymbols) {
        final newId = const Uuid().v4();
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanSymbolsTable,
          rowId: newId,
          current: null,
          next: row.copyWith(id: newId, setId: destinationSetId),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Copy shot [sourceShotId]'s own live shot-layer symbols (cameras, characters, lights — never
  /// props any more, now that the scope matrix confines a prop to scene scope) and the arrows drawn
  /// between two of them, from set [sourceSetId] onto shot [destinationShotId] of set
  /// [destinationSetId] — the same set for a same-set copy, a different one for a copy across sets
  /// — as **independent copies**, appended after [destinationShotId]'s own current symbols of each
  /// layer. Creates [destinationSetId]'s plan if it doesn't exist yet ([OcptFloorPlanRows.ensurePlan]).
  ///
  /// An arrow whose either end is a set-scope or scene-scope symbol (a set element the source
  /// shot's own blocking points at or from) is **not copied**: that symbol belongs to
  /// [sourceSetId]'s own décor and has no copied counterpart on [destinationSetId] in general (nor,
  /// for a same-set copy, any reason to point the copy back at the very same décor symbol the
  /// source shot already points at) — only a movement whose both ends are themselves being copied
  /// travels with it.
  ///
  /// A no-op while [sourceShotId] carries nothing on [sourceSetId].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  static Future<void> copyShotBlocking({
    required OcptDeviceIdGetter deviceId,
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String sourceShotId,
    required String destinationSetId,
    required String destinationShotId,
  }) async {
    if (database.refusesUserWrite("copyShotBlocking")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptFloorPlanRows.ensurePlan(
        database: database,
        setId: destinationSetId,
        stamps: stamps,
      );

      final symbolRows =
          (await (database.select(database.ocptFloorPlanSymbolsTable)..where(
                  (table) =>
                      table.setId.equals(sourceSetId) &
                      table.shotId.equals(sourceShotId) &
                      table.isDeleted.not(),
                ))
                .get())
            ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

      final newSymbolIdBySourceId = <String, String>{};
      for (final row in symbolRows) {
        final existingOfLayer = await OcptFloorPlanRows.symbolRowsOfSetAndLayer(
          database: database,
          setId: destinationSetId,
          layer: row.layer,
        );
        final newSymbolId = const Uuid().v4();
        newSymbolIdBySourceId[row.id] = newSymbolId;
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanSymbolsTable,
          rowId: newSymbolId,
          current: null,
          next: row.copyWith(
            id: newSymbolId,
            setId: destinationSetId,
            shotId: Value(destinationShotId),
            sortKey: ocptFractionalKeyBetween(
              before: existingOfLayer.isEmpty ? null : existingOfLayer.last.sortKey,
            ),
          ),
          stamps: stamps,
        );
      }

      final arrowRows =
          await (database.select(database.ocptFloorPlanArrowsTable)..where(
                (table) =>
                    table.setId.equals(sourceSetId) &
                    table.shotId.equals(sourceShotId) &
                    table.isDeleted.not(),
              ))
              .get();
      for (final row in arrowRows) {
        final newFromSymbolId = newSymbolIdBySourceId[row.fromSymbolId];
        final newToSymbolId = newSymbolIdBySourceId[row.toSymbolId];
        if (newFromSymbolId == null || newToSymbolId == null) {
          continue;
        }
        final newArrowId = const Uuid().v4();
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanArrowsTable,
          rowId: newArrowId,
          current: null,
          next: row.copyWith(
            id: newArrowId,
            setId: destinationSetId,
            shotId: destinationShotId,
            fromSymbolId: newFromSymbolId,
            toSymbolId: newToSymbolId,
          ),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Tombstone shot [shotId]'s own shot-layer symbols and every arrow it carries — every arrow
  /// whose own `shotId` names it, and, defensively, every arrow touching one of the symbols being
  /// removed — for `OcptShotListService.deleteShot`'s and `.tombstoneShotsOfScreenplay`'s own
  /// cascade.
  ///
  /// **Never touches a set-scope/scene-scope symbol or another shot's rows**: shot [shotId] can
  /// only ever own symbols whose own `shotId` equals it (the scope invariant), so this is exactly
  /// the shot's own placements, nothing of the décor it was drawn against.
  ///
  /// **Unguarded**, exactly as `OcptStoryboardService.tombstonePanelsOfShot` is: its only caller
  /// has already refused the write on a preview connection and is already inside the transaction
  /// removing the shot. Stamps through [stamps], that caller's own instance.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  static Future<void> tombstoneFloorPlanRowsOfShot({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptRowStampService? stamps,
  }) async {
    final ownArrows = await (database.select(
      database.ocptFloorPlanArrowsTable,
    )..where((table) => table.shotId.equals(shotId) & table.isDeleted.not())).get();
    for (final row in ownArrows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanArrowsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    final symbolRows = await (database.select(
      database.ocptFloorPlanSymbolsTable,
    )..where((table) => table.shotId.equals(shotId) & table.isDeleted.not())).get();
    for (final row in symbolRows) {
      await OcptFloorPlanRows.tombstoneArrowsTouchingSymbol(
        database: database,
        symbolId: row.id,
        stamps: stamps,
      );
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSymbolsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }

  /// Tombstone Resources set [setId]'s own plan row (if any — a set nothing has ever been drawn
  /// on has none to tombstone), its symbols and its arrows, in one pass —
  /// `OcptLocationsService.deleteSet`'s and `.deleteLocation`'s own cascade. Removing a set's
  /// **link** to a scene (`OcptLocationsService
  /// .removeSceneFromSet`) never calls this: unlinking keeps the plan, so placements come back if
  /// the set is relinked.
  ///
  /// **Unguarded**, exactly as [tombstoneFloorPlanRowsOfShot] is: the caller has already refused
  /// the write on a preview connection and is already inside the transaction removing the
  /// Resources set. Stamps through [stamps], that caller's own instance.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  static Future<void> tombstoneFloorPlanRowsOfSet({
    required OcptProjectDatabase database,
    required String setId,
    required OcptRowStampService? stamps,
  }) async {
    final arrowRows = await OcptFloorPlanRows.arrowRowsOfSet(database: database, setId: setId);
    for (final row in arrowRows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanArrowsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    final symbolRows = await OcptFloorPlanRows.symbolRowsOfSet(database: database, setId: setId);
    for (final row in symbolRows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSymbolsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    final current = await OcptFloorPlanRows.livePlanRowOrNull(database: database, setId: setId);
    if (current != null) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }
  }
}
