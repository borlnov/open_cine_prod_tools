// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';

/// The reads of the floor plans: every plan of a screenplay with its symbols and arrows, the
/// symbols of a set at a given scope and the sets which hold a plan.
///
/// What `OcptFloorPlanService` forwards to; that service documents the floor plan model whole.
abstract final class OcptFloorPlanReadOps {
  /// Loads every live Resources set linked (`scene_sets`) to a live scene of screenplay
  /// [screenplayId], each carrying its resolved underlay path and its live symbols and arrows,
  /// keyed by scene id — a sequence's floor-plan tabs are exactly its own live links, in the
  /// Resources mode's own display order (`sets.sortKey`), and the very same [OcptFloorPlanSet] is
  /// handed back under every scene it is linked to (`OcptFloorPlanSnapshot`'s own doc comment).
  ///
  /// A linked set with no `floor_plan_sets` row yet (nothing has been drawn on it) reads as an
  /// empty plan rather than being skipped — `ensurePlan` is what a first write mints the row
  /// through, this read never does.
  static Future<OcptFloorPlanSnapshot> loadFloorPlans({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final sceneIds = await _liveSceneIdsOfScreenplay(
      database: database,
      screenplayId: screenplayId,
    );
    if (sceneIds.isEmpty) {
      return OcptFloorPlanSnapshot.build(screenplayId: screenplayId, setsBySceneId: const {});
    }

    final sceneSetRows = await (database.select(
      database.ocptSceneSetsTable,
    )..where((table) => table.sceneId.isIn(sceneIds) & table.isDeleted.not())).get();
    if (sceneSetRows.isEmpty) {
      return OcptFloorPlanSnapshot.build(screenplayId: screenplayId, setsBySceneId: const {});
    }

    final linkedSetIds = {for (final row in sceneSetRows) row.setId};

    final resourceSetRows =
        await (database.select(database.ocptSetsTable)
              ..where((table) => table.id.isIn(linkedSetIds) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();
    final liveSetIds = resourceSetRows.map((row) => row.id).toSet();

    final planRows = await (database.select(
      database.ocptFloorPlanSetsTable,
    )..where((table) => table.id.isIn(liveSetIds) & table.isDeleted.not())).get();
    final planRowById = {for (final row in planRows) row.id: row};

    final symbolRows = liveSetIds.isEmpty
        ? const <OcptFloorPlanSymbolRow>[]
        : await (database.select(
            database.ocptFloorPlanSymbolsTable,
          )..where((table) => table.setId.isIn(liveSetIds) & table.isDeleted.not())).get();

    final arrowRows = liveSetIds.isEmpty
        ? const <OcptFloorPlanArrowRow>[]
        : await (database.select(
            database.ocptFloorPlanArrowsTable,
          )..where((table) => table.setId.isIn(liveSetIds) & table.isDeleted.not())).get();

    final symbolsBySetId = <String, List<OcptFloorPlanSymbol>>{};
    for (final row in symbolRows) {
      symbolsBySetId.putIfAbsent(row.setId, () => []).add(OcptFloorPlanSymbol.fromRow(row));
    }

    final arrowsBySetId = <String, List<OcptFloorPlanArrow>>{};
    for (final row in arrowRows) {
      arrowsBySetId.putIfAbsent(row.setId, () => []).add(OcptFloorPlanArrow.fromRow(row));
    }

    final underlayAssetIds = {
      for (final row in planRows)
        if (row.underlayAssetId != null) row.underlayAssetId!,
    };
    final pathByAssetId = await _liveAssetPathsById(database: database, assetIds: underlayAssetIds);

    final floorPlanSetById = <String, OcptFloorPlanSet>{
      for (final resourceRow in resourceSetRows)
        resourceRow.id: OcptFloorPlanSet.fromRows(
          setRow: resourceRow,
          planRow: planRowById[resourceRow.id],
          underlayPath: switch (planRowById[resourceRow.id]?.underlayAssetId) {
            final assetId? => pathByAssetId[assetId],
            null => null,
          },
          symbols: symbolsBySetId[resourceRow.id] ?? const [],
          arrows: arrowsBySetId[resourceRow.id] ?? const [],
        ),
    };

    final linkedSetIdsBySceneId = <String, Set<String>>{};
    for (final row in sceneSetRows) {
      linkedSetIdsBySceneId.putIfAbsent(row.sceneId, () => {}).add(row.setId);
    }

    final setsBySceneId = <String, List<OcptFloorPlanSet>>{};
    for (final sceneId in sceneIds) {
      final linked = linkedSetIdsBySceneId[sceneId];
      if (linked == null || linked.isEmpty) {
        continue;
      }

      final tabs = [
        for (final resourceRow in resourceSetRows)
          if (linked.contains(resourceRow.id)) floorPlanSetById[resourceRow.id]!,
      ];
      if (tabs.isNotEmpty) {
        setsBySceneId[sceneId] = tabs;
      }
    }

    return OcptFloorPlanSnapshot.build(screenplayId: screenplayId, setsBySceneId: setsBySceneId);
  }

  /// The **set-scope** symbols (`sceneId` and `shotId` both null) of every live Resources set of
  /// [database], keyed by set id — a project-wide read, unlike [loadFloorPlans]'s own
  /// per-screenplay one, used only to draw a lightweight thumbnail of a set's own décor, for the
  /// empty-state gallery: no scene/shot-scope symbol, no
  /// arrow, no underlay — a thumbnail draws the room's own shape, never what a sequence or a shot
  /// staged on it.
  static Future<Map<String, List<OcptFloorPlanSymbol>>> loadSetScopeSymbolsByProjectSetId({
    required OcptProjectDatabase database,
  }) async {
    final rows =
        await (database.select(database.ocptFloorPlanSymbolsTable)..where(
              (table) => table.sceneId.isNull() & table.shotId.isNull() & table.isDeleted.not(),
            ))
            .get();

    final bySetId = <String, List<OcptFloorPlanSymbol>>{};
    for (final row in rows) {
      bySetId.putIfAbsent(row.setId, () => []).add(OcptFloorPlanSymbol.fromRow(row));
    }
    return bySetId;
  }

  /// The ids of [setIds] that hold a live `floor_plan_sets` row — a plan that "exists" in the sense
  /// the Resources location sheet's own set line reads: a
  /// light read of ids alone, never a whole plan's worth of symbols and arrows, since the sheet
  /// only ever needs to know whether one is there at all.
  static Future<Set<String>> liveSetIdsWithPlan({
    required OcptProjectDatabase database,
    required Iterable<String> setIds,
  }) async {
    final ids = setIds.toSet();
    if (ids.isEmpty) {
      return const {};
    }

    final query = database.selectOnly(database.ocptFloorPlanSetsTable)
      ..addColumns([database.ocptFloorPlanSetsTable.id])
      ..where(
        database.ocptFloorPlanSetsTable.id.isIn(ids) &
            database.ocptFloorPlanSetsTable.isDeleted.not(),
      );
    final rows = await query.get();

    return {
      for (final row in rows)
        if (row.read(database.ocptFloorPlanSetsTable.id) case final id?) id,
    };
  }

  /// Every live scene id of screenplay [screenplayId].
  static Future<List<String>> _liveSceneIdsOfScreenplay({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final rows = await (database.select(
      database.ocptScenesTable,
    )..where((table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not())).get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  /// The resolved absolute path of every live `assets` row of [assetIds], keyed by id. See
  /// `OcptStoryboardService._liveAssetPathsById`'s own doc comment for why a missing entry is a
  /// normal state.
  static Future<Map<String, String>> _liveAssetPathsById({
    required OcptProjectDatabase database,
    required Set<String> assetIds,
  }) async {
    if (assetIds.isEmpty) {
      return const {};
    }

    final rows = await (database.select(
      database.ocptAssetsTable,
    )..where((table) => table.id.isIn(assetIds) & table.isDeleted.not())).get();
    return {for (final row in rows) row.id: row.path};
  }
}
