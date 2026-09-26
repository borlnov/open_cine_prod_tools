// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a Resources set's floor plan — the symbols placed on it (its own set/scene layers and
/// each shot's own shot layers) and the arrows drawn between symbols (`docs/plans/storyboard.md`,
/// §10).
///
/// **The plan belongs to the Resources set, not to a sequence** — `floor_plan_sets.id` **is**
/// `sets.id` (see `OcptFloorPlanSetsTable`'s own doc comment), created lazily on the first write
/// ([_ensurePlan]) rather than eagerly for every Resources set the project holds. A sequence's
/// floor-plan tabs are its live `scene_sets` links, which this service reads but never writes —
/// that link is `OcptLocationsService`'s (`assignSceneToSet`/`removeSceneFromSet`), and this
/// service has no reference to it at all: `OcptLocationsService` depends on this one instead (for
/// its own delete cascade, [tombstoneFloorPlanRowsOfSet]), and dependencies never reference their
/// dependents. [duplicateSet] is accordingly narrower than "duplicate this set" end to end — see
/// its own doc comment for how the two services' halves are put together by the caller.
///
/// [assetsService] is the one place a set's underlay `assets` row is minted or tombstoned
/// (`OcptAssetKind.floorPlanUnderlay`) — this service never reads or writes `assets.path` itself.
///
/// **The scope invariant.** A symbol's scope ([OcptFloorPlanScope], derived from its own
/// `sceneId`/`shotId` by `ocptFloorPlanScopeOf`) must be one [_allowedScopesOf] lists for its own
/// [OcptFloorPlanLayer] — this service is what enforces it, at [placeSymbol], the only write that
/// can set `sceneId`, `shotId`, `layer` or `overridesSymbolId`: an update never touches any of the
/// four, so nothing else can put the invariant out of step once a symbol exists.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — none of the three tables this service owns carries a
/// `position` column: all three are new in a schema version that never needed one.
class OcptFloorPlanService {
  /// The service used to mint and tombstone a set's underlay `assets` row.
  final OcptAssetsService assetsService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [tombstoneFloorPlanRowsOfShot] and [tombstoneFloorPlanRowsOfSet] never
  /// call it: they write inside a caller's own transaction, and take that caller's own
  /// [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptFloorPlanService({required this.assetsService, required this.deviceId});

  /// Loads every live Resources set linked (`scene_sets`) to a live scene of screenplay
  /// [screenplayId], each carrying its resolved underlay path and its live symbols and arrows,
  /// keyed by scene id — a sequence's floor-plan tabs are exactly its own live links, in the
  /// Resources mode's own display order (`sets.sortKey`), and the very same [OcptFloorPlanSet] is
  /// handed back under every scene it is linked to (`OcptFloorPlanSnapshot`'s own doc comment).
  ///
  /// A linked set with no `floor_plan_sets` row yet (nothing has been drawn on it) reads as an
  /// empty plan rather than being skipped — [_ensurePlan] is what a first write mints the row
  /// through, this read never does.
  Future<OcptFloorPlanSnapshot> loadFloorPlans({
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

    final sceneSetRows =
        await (database.select(
              database.ocptSceneSetsTable,
            )..where((table) => table.sceneId.isIn(sceneIds) & table.isDeleted.not()))
            .get();
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

    final planRows =
        await (database.select(
              database.ocptFloorPlanSetsTable,
            )..where((table) => table.id.isIn(liveSetIds) & table.isDeleted.not()))
            .get();
    final planRowById = {for (final row in planRows) row.id: row};

    final symbolRows = liveSetIds.isEmpty
        ? const <OcptFloorPlanSymbolRow>[]
        : await (database.select(
                database.ocptFloorPlanSymbolsTable,
              )..where((table) => table.setId.isIn(liveSetIds) & table.isDeleted.not()))
              .get();

    final arrowRows = liveSetIds.isEmpty
        ? const <OcptFloorPlanArrowRow>[]
        : await (database.select(
                database.ocptFloorPlanArrowsTable,
              )..where((table) => table.setId.isIn(liveSetIds) & table.isDeleted.not()))
              .get();

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
    final pathByAssetId = await _liveAssetPathsById(
      database: database,
      assetIds: underlayAssetIds,
    );

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

  /// Sets Resources set [setId]'s underlay to the file at [path], framed at
  /// `(xM, yM, widthM, heightM, rotationDeg)`: creates the plan row if it doesn't exist yet
  /// ([_ensurePlan]), tombstones its previous underlay `assets` row (if any) and mints a fresh one.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> setSetUnderlay({
    required OcptProjectDatabase database,
    required String setId,
    required String path,
    required double xM,
    required double yM,
    required double widthM,
    required double heightM,
    double rotationDeg = 0,
  }) async {
    if (database.refusesUserWrite("setSetUnderlay")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await _ensurePlan(database: database, setId: setId, stamps: stamps);

      final current = await _livePlanRowOrNull(database: database, setId: setId);
      if (current == null) {
        return;
      }

      if (current.underlayAssetId != null) {
        await assetsService.tombstoneAsset(
          database: database,
          assetId: current.underlayAssetId!,
          stamps: stamps,
        );
      }

      final newAssetId = await assetsService.insertAsset(
        database: database,
        kind: OcptAssetKind.floorPlanUnderlay,
        path: path,
        stamps: stamps,
      );

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(
          underlayAssetId: Value(newAssetId),
          underlayXM: Value(xM),
          underlayYM: Value(yM),
          underlayWidthM: Value(widthM),
          underlayHeightM: Value(heightM),
          underlayRotationDeg: Value(rotationDeg),
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Clears set [setId]'s underlay: tombstones its `assets` row (if any) and blanks its frame. A
  /// no-op while the plan doesn't exist yet or already carries no underlay.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> clearSetUnderlay({
    required OcptProjectDatabase database,
    required String setId,
  }) async {
    if (database.refusesUserWrite("clearSetUnderlay")) {
      return;
    }

    await database.transaction(() async {
      final current = await _livePlanRowOrNull(database: database, setId: setId);
      if (current == null || current.underlayAssetId == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      await assetsService.tombstoneAsset(
        database: database,
        assetId: current.underlayAssetId!,
        stamps: stamps,
      );

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(
          underlayAssetId: const Value(null),
          underlayXM: const Value(null),
          underlayYM: const Value(null),
          underlayWidthM: const Value(null),
          underlayHeightM: const Value(null),
          underlayRotationDeg: const Value(null),
        ),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Updates set [setId]'s underlay **frame** — its centre, size and/or rotation, whichever is
  /// passed as something other than [Value.absent] — through a single guarded write that touches
  /// no `assets` row at all. A no-op while the plan doesn't exist yet or carries no underlay
  /// (`underlayAssetId == null`): there is nothing to re-frame.
  ///
  /// This is the write a drag moving or resizing the underlay on the canvas ends on. The frame
  /// lives entirely on this table's own `underlay*M`/`underlayRotationDeg` columns, so re-framing
  /// it must never go through [setSetUnderlay]: that method unconditionally tombstones the
  /// current `assets` row and mints a fresh one, which is the right cost for actually importing or
  /// replacing the underlay's image, but is a permanent (ADR 0010) churn of dead `assets` rows for
  /// a gesture as frequent as dragging the underlay against the reference silhouette.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateUnderlayFrame({
    required OcptProjectDatabase database,
    required String setId,
    Value<double> xM = const Value.absent(),
    Value<double> yM = const Value.absent(),
    Value<double> widthM = const Value.absent(),
    Value<double> heightM = const Value.absent(),
    Value<double> rotationDeg = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateUnderlayFrame")) {
      return;
    }

    final companion = OcptFloorPlanSetsTableCompanion(
      underlayXM: xM,
      underlayYM: yM,
      underlayWidthM: widthM,
      underlayHeightM: heightM,
      underlayRotationDeg: rotationDeg,
    );

    await database.transaction(() async {
      final current = await _livePlanRowOrNull(database: database, setId: setId);
      if (current == null || current.underlayAssetId == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Places a new symbol of [layer] on Resources set [setId] — creating its plan row if it doesn't
  /// exist yet ([_ensurePlan]) — appended after the set's current last symbol of that layer, and
  /// returns its freshly generated id.
  ///
  /// **Enforces the scope invariant**: the scope [sceneId]/[shotId] derive
  /// (`ocptFloorPlanScopeOf`) must be one [_allowedScopesOf] allows for [layer], or this throws an
  /// [ArgumentError] rather than writing a row the rest of this service could never make sense of
  /// again. [overridesSymbolId], when given, must name a **live** symbol on this very [setId], of
  /// the very same [layer], itself set-scope (`sceneId` and `shotId` both null) — the "every
  /// sequence / only this one" move (`docs/plans/storyboard.md`, §10): passing it on anything but a
  /// scene-scope symbol, or naming a symbol that doesn't meet all three conditions, throws too.
  ///
  /// [setElementShape] records a set-element symbol's visual primitive (a wall, a door, a piece of
  /// furniture, a free-hand shape). Passed null for a camera, character or light symbol — every
  /// caller placing one of those simply omits it — and, ordinarily, for whichever of the two this
  /// call isn't (a set element never carries a field of view, a camera never carries a shape).
  ///
  /// [fovReachM] records a camera symbol's own field-of-view wedge reach, in metres — its own axial
  /// height/depth, from the lens to the wedge's own far chord — null meaning the drawing's own
  /// default (`ocptFloorPlanCameraFovWedgeLengthM`). Null for every other symbol, the same as
  /// [fovDeg].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> placeSymbol({
    required OcptProjectDatabase database,
    required String setId,
    required String? sceneId,
    required String? shotId,
    required OcptFloorPlanLayer layer,
    required double xM,
    required double yM,
    double rotationDeg = 0,
    double? widthM,
    double? heightM,
    double? fovDeg,
    double? fovReachM,
    String label = '',
    OcptFloorPlanSetElementShape? setElementShape,
    String? overridesSymbolId,
  }) async {
    if (database.refusesUserWrite("placeSymbol")) {
      return null;
    }

    _checkScopeInvariant(sceneId: sceneId, shotId: shotId, layer: layer);
    if (overridesSymbolId != null &&
        ocptFloorPlanScopeOf(sceneId: sceneId, shotId: shotId) != OcptFloorPlanScope.scene) {
      throw ArgumentError(
        "overridesSymbolId is only ever set on a scene-scope symbol, but this one has "
        "sceneId: $sceneId, shotId: $shotId",
      );
    }

    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await _ensurePlan(database: database, setId: setId, stamps: stamps);

      if (overridesSymbolId != null) {
        final target = await _liveSymbolRowOrNull(database: database, symbolId: overridesSymbolId);
        final targetScope = target == null
            ? null
            : ocptFloorPlanScopeOf(sceneId: target.sceneId, shotId: target.shotId);
        if (target == null ||
            target.setId != setId ||
            target.layer != layer ||
            targetScope != OcptFloorPlanScope.set) {
          throw ArgumentError(
            "overridesSymbolId $overridesSymbolId must name a live set-scope symbol of the same "
            "set and layer",
          );
        }
      }

      final existing = await _symbolRowsOfSetAndLayer(
        database: database,
        setId: setId,
        layer: layer,
      );

      final row = OcptFloorPlanSymbolRow(
        id: id,
        setId: setId,
        sceneId: sceneId,
        shotId: shotId,
        layer: layer,
        sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
        xM: xM,
        yM: yM,
        rotationDeg: rotationDeg,
        widthM: widthM,
        heightM: heightM,
        fovDeg: fovDeg,
        fovReachM: fovReachM,
        label: label,
        setElementShape: setElementShape,
        overridesSymbolId: overridesSymbolId,
        isDeleted: false,
      );

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSymbolsTable,
        rowId: id,
        current: null,
        next: row,
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates symbol [symbolId]'s position, rotation, footprint, field of view (angle and reach),
  /// label and/or set-element shape, whichever is passed as something other than [Value.absent] —
  /// a move writes `xM`/`yM`, a rotate writes `rotationDeg`, a resize writes `widthM`/`heightM`,
  /// [fovReachM] writes a camera's own wedge reach (its tip handle), [setElementShape] switches a
  /// décor primitive's own type (a wall turned into a door, say), and so on, all through this one
  /// guarded write. Never touches `setId`, `sceneId`, `shotId`, `layer` or `overridesSymbolId`:
  /// those are fixed at [placeSymbol] and nothing here can put the scope invariant out of step.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateSymbol({
    required OcptProjectDatabase database,
    required String symbolId,
    Value<double> xM = const Value.absent(),
    Value<double> yM = const Value.absent(),
    Value<double> rotationDeg = const Value.absent(),
    Value<double?> widthM = const Value.absent(),
    Value<double?> heightM = const Value.absent(),
    Value<double?> fovDeg = const Value.absent(),
    Value<double?> fovReachM = const Value.absent(),
    Value<String> label = const Value.absent(),
    Value<OcptFloorPlanSetElementShape?> setElementShape = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateSymbol")) {
      return;
    }

    final companion = OcptFloorPlanSymbolsTableCompanion(
      xM: xM,
      yM: yM,
      rotationDeg: rotationDeg,
      widthM: widthM,
      heightM: heightM,
      fovDeg: fovDeg,
      fovReachM: fovReachM,
      label: label,
      setElementShape: setElementShape,
    );

    await database.transaction(() async {
      final current = await _liveSymbolRowOrNull(database: database, symbolId: symbolId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSymbolsTable,
        rowId: symbolId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones symbol [symbolId] and every arrow touching it — whose [OcptFloorPlanArrow
  /// .fromSymbolId] or [OcptFloorPlanArrow.toSymbolId] names it — in one transaction.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteSymbol({
    required OcptProjectDatabase database,
    required String symbolId,
  }) async {
    if (database.refusesUserWrite("deleteSymbol")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await _tombstoneArrowsTouchingSymbol(database: database, symbolId: symbolId, stamps: stamps);

      final current = await _liveSymbolRowOrNull(database: database, symbolId: symbolId);
      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanSymbolsTable,
          rowId: symbolId,
          current: current,
          next: current.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Adds a new [kind] arrow on set [setId] — creating its plan row if it doesn't exist yet
  /// ([_ensurePlan]) — belonging to shot [shotId] (always set — an arrow is always one shot's own
  /// movement, `OcptFloorPlanArrowsTable`'s own doc comment), from [fromSymbolId] to [toSymbolId],
  /// and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addArrow({
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
      await _ensurePlan(database: database, setId: setId, stamps: stamps);

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
  Future<void> setArrowLabel({
    required OcptProjectDatabase database,
    required String arrowId,
    required String label,
  }) async {
    if (database.refusesUserWrite("setArrowLabel")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveArrowRowOrNull(database: database, arrowId: arrowId);
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
  Future<void> updateArrowCurve({
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
      final current = await _liveArrowRowOrNull(database: database, arrowId: arrowId);
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
  Future<void> deleteArrow({
    required OcptProjectDatabase database,
    required String arrowId,
  }) async {
    if (database.refusesUserWrite("deleteArrow")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveArrowRowOrNull(database: database, arrowId: arrowId);
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

  /// Copies Resources set [sourceSetId]'s own live **set-scope** symbols (`sceneId` and `shotId`
  /// both null — the set's own décor, never a scene's re-dressing nor a shot's blocking) onto set
  /// [destinationSetId]'s plan, as independent copies (fresh ids, never links), creating that
  /// destination plan if it doesn't exist yet ([_ensurePlan]).
  ///
  /// **This is only the copying half of "duplicate this set"** (`docs/plans/storyboard.md`, §10):
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
  Future<void> duplicateSet({
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String destinationSetId,
  }) async {
    if (database.refusesUserWrite("duplicateSet")) {
      return;
    }

    await database.transaction(() async {
      final setScopeSymbols =
          (await _symbolRowsOfSet(database: database, setId: sourceSetId)).where(
            (row) =>
                ocptFloorPlanScopeOf(sceneId: row.sceneId, shotId: row.shotId) ==
                OcptFloorPlanScope.set,
          ).toList()
            ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

      if (setScopeSymbols.isEmpty) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await _ensurePlan(database: database, setId: destinationSetId, stamps: stamps);

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

  /// Copies shot [sourceShotId]'s own live shot-layer symbols (cameras, characters, lights, props)
  /// and the arrows drawn between two of them, from set [sourceSetId] onto shot [destinationShotId]
  /// of set [destinationSetId] — the same set for a same-set copy, a different one for a copy across
  /// sets — as **independent copies**, appended after [destinationShotId]'s own current symbols of
  /// each layer. Creates [destinationSetId]'s plan if it doesn't exist yet ([_ensurePlan]).
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
  Future<void> copyShotBlocking({
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
      await _ensurePlan(database: database, setId: destinationSetId, stamps: stamps);

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
        final existingOfLayer = await _symbolRowsOfSetAndLayer(
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

  /// Tombstones shot [shotId]'s own shot-layer symbols and every arrow it carries — every arrow
  /// whose own `shotId` names it, and, defensively, every arrow touching one of the symbols being
  /// removed — for `OcptShotListService.deleteShot`'s and `.tombstoneShotsOfScreenplay`'s own
  /// cascade.
  ///
  /// **Never touches a set-scope/scene-scope symbol or another shot's rows**: shot [shotId] can
  /// only ever own symbols whose own `shotId` equals it (the scope invariant), so this is exactly
  /// the shot's own placements, nothing of the décor it was drawn against.
  ///
  /// **Unguarded**, exactly as `OcptStoryboardService.tombstonePanelsOfShot` is: its only caller has
  /// already refused the write on a preview connection and is already inside the transaction
  /// removing the shot. Stamps through [stamps], that caller's own instance.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneFloorPlanRowsOfShot({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptRowStampService? stamps,
  }) async {
    final ownArrows =
        await (database.select(
              database.ocptFloorPlanArrowsTable,
            )..where((table) => table.shotId.equals(shotId) & table.isDeleted.not()))
            .get();
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

    final symbolRows =
        await (database.select(
              database.ocptFloorPlanSymbolsTable,
            )..where((table) => table.shotId.equals(shotId) & table.isDeleted.not()))
            .get();
    for (final row in symbolRows) {
      await _tombstoneArrowsTouchingSymbol(database: database, symbolId: row.id, stamps: stamps);
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

  /// Tombstones Resources set [setId]'s own plan row (if any — a set nothing has ever been drawn
  /// on has none to tombstone), its symbols and its arrows, in one pass —
  /// `OcptLocationsService.deleteSet`'s and `.deleteLocation`'s own cascade (`docs/plans/
  /// storyboard.md`, §10). Removing a set's **link** to a scene (`OcptLocationsService
  /// .removeSceneFromSet`) never calls this: unlinking keeps the plan, so placements come back if
  /// the set is relinked.
  ///
  /// **Unguarded**, exactly as [tombstoneFloorPlanRowsOfShot] is: the caller has already refused
  /// the write on a preview connection and is already inside the transaction removing the
  /// Resources set. Stamps through [stamps], that caller's own instance.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstoneFloorPlanRowsOfSet({
    required OcptProjectDatabase database,
    required String setId,
    required OcptRowStampService? stamps,
  }) async {
    final arrowRows = await _arrowRowsOfSet(database: database, setId: setId);
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

    final symbolRows = await _symbolRowsOfSet(database: database, setId: setId);
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

    final current = await _livePlanRowOrNull(database: database, setId: setId);
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

  /// Creates the plan row of Resources set [setId] if none exists yet, from inside the caller's
  /// own transaction and stamping through its own [stamps] — **idempotent**, and safe under
  /// concurrent replicas: the plan's own row id **is** [setId] (`OcptFloorPlanSetsTable`'s own doc
  /// comment), so two devices that each place the first symbol on the same set while offline
  /// converge on one row through the sync merge rather than each minting their own.
  Future<void> _ensurePlan({
    required OcptProjectDatabase database,
    required String setId,
    required OcptRowStampService stamps,
  }) async {
    final existing =
        await (database.select(
              database.ocptFloorPlanSetsTable,
            )..where((table) => table.id.equals(setId)))
            .getSingleOrNull();
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

  /// The scopes [layer] may land in — the scope matrix `OcptFloorPlanSymbolsTable`'s own doc
  /// comment describes. A `switch` with no `default`: a sixth layer must be placed on one side or
  /// another here rather than silently landing in whichever branch happens to be listed last.
  static Set<OcptFloorPlanScope> _allowedScopesOf(OcptFloorPlanLayer layer) => switch (layer) {
    OcptFloorPlanLayer.set => const {OcptFloorPlanScope.set, OcptFloorPlanScope.scene},
    OcptFloorPlanLayer.cameras ||
    OcptFloorPlanLayer.characters ||
    OcptFloorPlanLayer.lights => const {OcptFloorPlanScope.shot},
    OcptFloorPlanLayer.props => const {OcptFloorPlanScope.scene, OcptFloorPlanScope.shot},
  };

  /// Throws an [ArgumentError] unless the scope [sceneId]/[shotId] derive is one [_allowedScopesOf]
  /// allows for [layer]. See this class's own doc comment for why this is the one place the scope
  /// invariant is checked.
  void _checkScopeInvariant({
    required String? sceneId,
    required String? shotId,
    required OcptFloorPlanLayer layer,
  }) {
    final scope = ocptFloorPlanScopeOf(sceneId: sceneId, shotId: shotId);
    final allowed = _allowedScopesOf(layer);
    if (!allowed.contains(scope)) {
      throw ArgumentError(
        "A floor plan symbol's scope must be one of $allowed for layer $layer, but got $scope "
        "(sceneId: $sceneId, shotId: $shotId)",
      );
    }
  }

  /// Tombstones every live arrow whose [OcptFloorPlanArrow.fromSymbolId] or
  /// [OcptFloorPlanArrow.toSymbolId] equals [symbolId] — the write body [deleteSymbol] and
  /// [tombstoneFloorPlanRowsOfShot] share.
  Future<void> _tombstoneArrowsTouchingSymbol({
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

  /// Every live scene id of screenplay [screenplayId].
  Future<List<String>> _liveSceneIdsOfScreenplay({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final rows =
        await (database.select(database.ocptScenesTable)..where(
              (table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not(),
            ))
            .get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  /// The resolved absolute path of every live `assets` row of [assetIds], keyed by id. See
  /// `OcptStoryboardService._liveAssetPathsById`'s own doc comment for why a missing entry is a
  /// normal state.
  Future<Map<String, String>> _liveAssetPathsById({
    required OcptProjectDatabase database,
    required Set<String> assetIds,
  }) async {
    if (assetIds.isEmpty) {
      return const {};
    }

    final rows =
        await (database.select(
              database.ocptAssetsTable,
            )..where((table) => table.id.isIn(assetIds) & table.isDeleted.not()))
            .get();
    return {for (final row in rows) row.id: row.path};
  }

  /// Reads back the live plan row of Resources set [setId], or null if it doesn't exist yet or has
  /// been tombstoned.
  Future<OcptFloorPlanSetRow?> _livePlanRowOrNull({
    required OcptProjectDatabase database,
    required String setId,
  }) => (database.select(database.ocptFloorPlanSetsTable)
        ..where((table) => table.id.equals(setId) & table.isDeleted.not()))
      .getSingleOrNull();

  /// Every live symbol row of set [setId].
  Future<List<OcptFloorPlanSymbolRow>> _symbolRowsOfSet({
    required OcptProjectDatabase database,
    required String setId,
  }) => (database.select(
        database.ocptFloorPlanSymbolsTable,
      )..where((table) => table.setId.equals(setId) & table.isDeleted.not()))
      .get();

  /// Every live symbol row of set [setId] on layer [layer], ordered by `sortKey` — what a new
  /// symbol of that layer is appended after.
  Future<List<OcptFloorPlanSymbolRow>> _symbolRowsOfSetAndLayer({
    required OcptProjectDatabase database,
    required String setId,
    required OcptFloorPlanLayer layer,
  }) => (database.select(database.ocptFloorPlanSymbolsTable)
        ..where(
          (table) =>
              table.setId.equals(setId) &
              table.layer.equalsValue(layer) &
              table.isDeleted.not(),
        )
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Reads back the live symbol row [symbolId], or null if it doesn't exist or has been tombstoned.
  Future<OcptFloorPlanSymbolRow?> _liveSymbolRowOrNull({
    required OcptProjectDatabase database,
    required String symbolId,
  }) => (database.select(database.ocptFloorPlanSymbolsTable)
        ..where((table) => table.id.equals(symbolId) & table.isDeleted.not()))
      .getSingleOrNull();

  /// Every live arrow row of set [setId].
  Future<List<OcptFloorPlanArrowRow>> _arrowRowsOfSet({
    required OcptProjectDatabase database,
    required String setId,
  }) => (database.select(
        database.ocptFloorPlanArrowsTable,
      )..where((table) => table.setId.equals(setId) & table.isDeleted.not()))
      .get();

  /// Reads back the live arrow row [arrowId], or null if it doesn't exist or has been tombstoned.
  Future<OcptFloorPlanArrowRow?> _liveArrowRowOrNull({
    required OcptProjectDatabase database,
    required String arrowId,
  }) => (database.select(database.ocptFloorPlanArrowsTable)
        ..where((table) => table.id.equals(arrowId) & table.isDeleted.not()))
      .getSingleOrNull();
}
