// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_arrow_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_cascade_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_read_ops.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_rows.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_scope_decision.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a Resources set's floor plan — the symbols placed on it (its own set/scene layers and
/// each shot's own shot layers) and the arrows drawn between symbols.
///
/// **The plan belongs to the Resources set, not to a sequence** — `floor_plan_sets.id` **is**
/// `sets.id` (see `OcptFloorPlanSetsTable`'s own doc comment), created lazily on the first write
/// ([OcptFloorPlanRows.ensurePlan]) rather than eagerly for every Resources set the project holds. A sequence's
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
class OcptFloorPlanService extends AbsOcptService {
  /// The service used to mint and tombstone a set's underlay `assets` row.
  final OcptAssetsService assetsService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [tombstoneFloorPlanRowsOfShot] and [tombstoneFloorPlanRowsOfSet] never
  /// call it: they write inside a caller's own transaction, and take that caller's own
  /// [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptFloorPlanService({
    required super.logger,
    required this.assetsService,
    required this.deviceId,
  });

  /// {@macro act_life_cycle.MixinWithLifeCycle.initLifeCycle}
  ///
  /// Initialises the services this one owns, in the order they are listed in its constructor.
  @override
  Future<void> initLifeCycle() async {
    await super.initLifeCycle();
    await assetsService.initLifeCycle();
  }

  /// Forward to [OcptFloorPlanReadOps.loadFloorPlans].
  Future<OcptFloorPlanSnapshot> loadFloorPlans({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) => OcptFloorPlanReadOps.loadFloorPlans(database: database, screenplayId: screenplayId);

  /// Forward to [OcptFloorPlanReadOps.loadSetScopeSymbolsByProjectSetId].
  Future<Map<String, List<OcptFloorPlanSymbol>>> loadSetScopeSymbolsByProjectSetId({
    required OcptProjectDatabase database,
  }) => OcptFloorPlanReadOps.loadSetScopeSymbolsByProjectSetId(database: database);

  /// Forward to [OcptFloorPlanReadOps.liveSetIdsWithPlan].
  Future<Set<String>> liveSetIdsWithPlan({
    required OcptProjectDatabase database,
    required Iterable<String> setIds,
  }) => OcptFloorPlanReadOps.liveSetIdsWithPlan(database: database, setIds: setIds);

  /// Set Resources set [setId]'s underlay to the file at [path], framed at
  /// `(xM, yM, widthM, heightM, rotationDeg)`: creates the plan row if it doesn't exist yet
  /// ([OcptFloorPlanRows.ensurePlan]), tombstones its previous underlay `assets` row (if any) and mints a fresh one.
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
      await OcptFloorPlanRows.ensurePlan(database: database, setId: setId, stamps: stamps);

      final current = await OcptFloorPlanRows.livePlanRowOrNull(database: database, setId: setId);
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

  /// Clear set [setId]'s underlay: tombstones its `assets` row (if any) and blanks its frame. A
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
      final current = await OcptFloorPlanRows.livePlanRowOrNull(database: database, setId: setId);
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

  /// Update set [setId]'s underlay **frame** — its centre, size and/or rotation, whichever is
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
      final current = await OcptFloorPlanRows.livePlanRowOrNull(database: database, setId: setId);
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

  /// Place a new symbol of [layer] on Resources set [setId] — creating its plan row if it doesn't
  /// exist yet ([OcptFloorPlanRows.ensurePlan]) — appended after the set's current last symbol of
  /// that layer, and return its freshly generated id.
  ///
  /// **Enforces the scope invariant**: the scope [sceneId]/[shotId] derive
  /// (`ocptFloorPlanScopeOf`) must be one [_allowedScopesOf] allows for [layer], or this throws an
  /// [ArgumentError] rather than writing a row the rest of this service could never make sense of
  /// again. [overridesSymbolId] is how a `set`/`props`-layer symbol is written as an **override**
  /// two levels deep:
  /// - A **scene-scope** override (`sceneId` set, `shotId` null) must name a live **set-scope**
  ///   symbol of this very [setId] and [layer] — the "every sequence / only this one" move.
  /// - A **shot-scope** override (`shotId` set, `sceneId` null — the only way a `set`/`props`
  ///   symbol may ever be shot-scope at all) must name a live **scene-scope** symbol of this
  ///   very [setId] and [layer], and [shotId] must belong to that scene-scope symbol's own
  ///   sequence — the "the whole sequence / only this shot" move.
  ///
  /// Passing [overridesSymbolId] on a set-scope symbol, or naming a target that doesn't meet every
  /// condition above, throws an [ArgumentError] too — and so does a shot-scope `set`/`props`
  /// symbol with **no** [overridesSymbolId] at all: unlike a camera, character or light, that
  /// layer is never natively shot-scope, only ever an override of a sequence's own symbol.
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
  /// [isHidden] creates the override already masking its own [overridesSymbolId] for this sequence
  /// ("remove from sequence n" with no override placed yet) — it is only ever true alongside a
  /// non-null [overridesSymbolId], or this throws an [ArgumentError] too.
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
    bool isHidden = false,
  }) async {
    if (database.refusesUserWrite("placeSymbol")) {
      return null;
    }

    _checkScopeInvariant(
      sceneId: sceneId,
      shotId: shotId,
      layer: layer,
      hasOverride: overridesSymbolId != null,
    );
    final scope = ocptFloorPlanScopeOf(sceneId: sceneId, shotId: shotId);
    if (overridesSymbolId != null && scope == OcptFloorPlanScope.set) {
      throw ArgumentError(
        "overridesSymbolId is only ever set on a scene- or shot-scope symbol, but this one has "
        "sceneId: $sceneId, shotId: $shotId",
      );
    }
    if (isHidden && overridesSymbolId == null) {
      throw ArgumentError("isHidden is only ever set on a scene- or shot-scope override");
    }

    final id = const Uuid().v4();

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptFloorPlanRows.ensurePlan(database: database, setId: setId, stamps: stamps);

      if (overridesSymbolId != null) {
        // A scene-scope override targets a set-scope original; a shot-scope override targets a
        // scene-scope one — one level down each time.
        final expectedTargetScope = scope == OcptFloorPlanScope.shot
            ? OcptFloorPlanScope.scene
            : OcptFloorPlanScope.set;
        final target = await OcptFloorPlanRows.liveSymbolRowOrNull(
          database: database,
          symbolId: overridesSymbolId,
        );
        final targetScope = target == null
            ? null
            : ocptFloorPlanScopeOf(sceneId: target.sceneId, shotId: target.shotId);
        if (target == null ||
            target.setId != setId ||
            target.layer != layer ||
            targetScope != expectedTargetScope) {
          throw ArgumentError(
            "overridesSymbolId $overridesSymbolId must name a live "
            "${expectedTargetScope.name}-scope symbol of the same set and layer",
          );
        }

        if (scope == OcptFloorPlanScope.shot) {
          final shotRow = await OcptFloorPlanRows.liveShotRowOrNull(
            database: database,
            shotId: shotId!,
          );
          if (shotRow == null || shotRow.sceneId != target.sceneId) {
            throw ArgumentError(
              "shot $shotId must belong to the same sequence as the scene-scope symbol "
              "$overridesSymbolId it overrides",
            );
          }
        }
      }

      final existing = await OcptFloorPlanRows.symbolRowsOfSetAndLayer(
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
        isHidden: isHidden,
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

  /// Update symbol [symbolId]'s position, rotation, footprint, field of view (angle and reach),
  /// label and/or set-element shape, whichever is passed as something other than [Value.absent] —
  /// a move writes `xM`/`yM`, a rotate writes `rotationDeg`, a resize writes `widthM`/`heightM`,
  /// [fovReachM] writes a camera's own wedge reach (its tip handle), [setElementShape] switches a
  /// décor primitive's own type (a wall turned into a door, say), [isHidden] masks or unmasks an
  /// already-placed override for its own sequence ("remove from sequence n" on an override that
  /// already exists, or undoing that), and so on, all through this one guarded write. Never touches
  /// `setId`, `sceneId`, `shotId`, `layer` or `overridesSymbolId`: those are fixed at [placeSymbol]
  /// and nothing here can put the scope invariant out of step.
  ///
  /// Setting [isHidden] on a symbol that isn't a scene-scope override (`overridesSymbolId` null)
  /// throws an [ArgumentError], the same as [placeSymbol]'s own check.
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
    Value<bool> isHidden = const Value.absent(),
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
      isHidden: isHidden,
    );

    await database.transaction(() async {
      final current = await OcptFloorPlanRows.liveSymbolRowOrNull(
        database: database,
        symbolId: symbolId,
      );
      if (current == null) {
        return;
      }
      if (isHidden.present && current.overridesSymbolId == null) {
        throw ArgumentError("isHidden is only ever set on a scene-scope override");
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

  /// Tombstone symbol [symbolId], every live scene-scope override of it, and every arrow touching
  /// any of them — whose [OcptFloorPlanArrow.fromSymbolId] or [OcptFloorPlanArrow.toSymbolId] names
  /// it — in one transaction.
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

      // A set-scope original may still carry overrides from a sequence no longer linked to its set
      // (unlinking keeps every placement): left live, one would come back on relinking with no
      // original to stand for.
      final overrides = await (database.select(
        database.ocptFloorPlanSymbolsTable,
      )..where((table) => table.overridesSymbolId.equals(symbolId) & table.isDeleted.not())).get();
      for (final override in overrides) {
        await OcptFloorPlanRows.tombstoneArrowsTouchingSymbol(
          database: database,
          symbolId: override.id,
          stamps: stamps,
        );
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanSymbolsTable,
          rowId: override.id,
          current: override,
          next: override.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await OcptFloorPlanRows.tombstoneArrowsTouchingSymbol(
        database: database,
        symbolId: symbolId,
        stamps: stamps,
      );

      final current = await OcptFloorPlanRows.liveSymbolRowOrNull(
        database: database,
        symbolId: symbolId,
      );
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

  /// Tombstone a set-scope symbol **everywhere**: [symbolId] itself (or, when [symbolId] names a
  /// scene-scope override instead, the set-scope original it overrides — resolved through its own
  /// `overridesSymbolId`) and every live scene-scope override of it, in every sequence, plus every
  /// arrow touching any of them — the "Delete everywhere" branch of the extended delete
  /// confirmation for a set element used by two or more sequences: the original and every one of
  /// its own re-dressings for a particular sequence are, semantically, one piece of furniture, and
  /// "everywhere" removes all of it at once rather than leaving an override dangling with no
  /// original left to fall back to.
  ///
  /// A no-op while [symbolId] (or the original it resolves to) is already gone.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteSymbolEverywhere({
    required OcptProjectDatabase database,
    required String symbolId,
  }) async {
    if (database.refusesUserWrite("deleteSymbolEverywhere")) {
      return;
    }

    await database.transaction(() async {
      final selected = await OcptFloorPlanRows.liveSymbolRowOrNull(
        database: database,
        symbolId: symbolId,
      );
      if (selected == null) {
        return;
      }
      final originalId = selected.overridesSymbolId ?? symbolId;

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final overrides =
          await (database.select(database.ocptFloorPlanSymbolsTable)..where(
                (table) => table.overridesSymbolId.equals(originalId) & table.isDeleted.not(),
              ))
              .get();
      for (final override in overrides) {
        await OcptFloorPlanRows.tombstoneArrowsTouchingSymbol(
          database: database,
          symbolId: override.id,
          stamps: stamps,
        );
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanSymbolsTable,
          rowId: override.id,
          current: override,
          next: override.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await OcptFloorPlanRows.tombstoneArrowsTouchingSymbol(
        database: database,
        symbolId: originalId,
        stamps: stamps,
      );
      final original = await OcptFloorPlanRows.liveSymbolRowOrNull(
        database: database,
        symbolId: originalId,
      );
      if (original != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanSymbolsTable,
          rowId: originalId,
          current: original,
          next: original.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Forward to [OcptFloorPlanArrowOps.addArrow].
  Future<String?> addArrow({
    required OcptProjectDatabase database,
    required String setId,
    required String shotId,
    required OcptFloorPlanArrowKind kind,
    required String fromSymbolId,
    required String toSymbolId,
    String label = '',
  }) => OcptFloorPlanArrowOps.addArrow(
    database: database,
    setId: setId,
    shotId: shotId,
    kind: kind,
    fromSymbolId: fromSymbolId,
    toSymbolId: toSymbolId,
    label: label,
    deviceId: deviceId,
  );

  /// Forward to [OcptFloorPlanArrowOps.setArrowLabel].
  Future<void> setArrowLabel({
    required OcptProjectDatabase database,
    required String arrowId,
    required String label,
  }) => OcptFloorPlanArrowOps.setArrowLabel(
    database: database,
    arrowId: arrowId,
    label: label,
    deviceId: deviceId,
  );

  /// Forward to [OcptFloorPlanArrowOps.updateArrowCurve].
  Future<void> updateArrowCurve({
    required OcptProjectDatabase database,
    required String arrowId,
    required Value<double?> ctrlXM,
    required Value<double?> ctrlYM,
  }) => OcptFloorPlanArrowOps.updateArrowCurve(
    database: database,
    arrowId: arrowId,
    ctrlXM: ctrlXM,
    ctrlYM: ctrlYM,
    deviceId: deviceId,
  );

  /// Forward to [OcptFloorPlanArrowOps.deleteArrow].
  Future<void> deleteArrow({required OcptProjectDatabase database, required String arrowId}) =>
      OcptFloorPlanArrowOps.deleteArrow(database: database, arrowId: arrowId, deviceId: deviceId);

  /// Forward to [OcptFloorPlanCascadeOps.duplicateSet].
  Future<void> duplicateSet({
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String destinationSetId,
  }) => OcptFloorPlanCascadeOps.duplicateSet(
    database: database,
    sourceSetId: sourceSetId,
    destinationSetId: destinationSetId,
    deviceId: deviceId,
  );

  /// Forward to [OcptFloorPlanCascadeOps.copyShotBlocking].
  Future<void> copyShotBlocking({
    required OcptProjectDatabase database,
    required String sourceSetId,
    required String sourceShotId,
    required String destinationSetId,
    required String destinationShotId,
  }) => OcptFloorPlanCascadeOps.copyShotBlocking(
    database: database,
    sourceSetId: sourceSetId,
    sourceShotId: sourceShotId,
    destinationSetId: destinationSetId,
    destinationShotId: destinationShotId,
    deviceId: deviceId,
  );

  /// Forward to [OcptFloorPlanCascadeOps.tombstoneFloorPlanRowsOfShot].
  Future<void> tombstoneFloorPlanRowsOfShot({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptRowStampService? stamps,
  }) => OcptFloorPlanCascadeOps.tombstoneFloorPlanRowsOfShot(
    database: database,
    shotId: shotId,
    stamps: stamps,
  );

  /// Forward to [OcptFloorPlanCascadeOps.tombstoneFloorPlanRowsOfSet].
  Future<void> tombstoneFloorPlanRowsOfSet({
    required OcptProjectDatabase database,
    required String setId,
    required OcptRowStampService? stamps,
  }) => OcptFloorPlanCascadeOps.tombstoneFloorPlanRowsOfSet(
    database: database,
    setId: setId,
    stamps: stamps,
  );

  /// Mask [original] for one sequence ([sceneId]) or one shot ([shotId]) alone — exactly one of
  /// the two is non-null — a hidden override: sets `isHidden` on [existingOverride] when one
  /// already exists, or places one copied from [original]'s own geometry otherwise. What the
  /// extended delete confirmation's alternative branch ("Remove from sequence n"/"Remove from
  /// shot n") writes.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> hideSymbolForScope({
    required OcptProjectDatabase database,
    required OcptFloorPlanSymbol original,
    required OcptFloorPlanSymbol? existingOverride,
    required String? sceneId,
    required String? shotId,
  }) async {
    if (existingOverride != null) {
      await updateSymbol(
        database: database,
        symbolId: existingOverride.id,
        isHidden: const Value(true),
      );
      return;
    }

    await placeSymbol(
      database: database,
      setId: original.setId,
      sceneId: sceneId,
      shotId: shotId,
      layer: original.layer,
      xM: original.xM,
      yM: original.yM,
      rotationDeg: original.rotationDeg,
      widthM: original.widthM,
      heightM: original.heightM,
      label: original.label,
      setElementShape: original.setElementShape,
      overridesSymbolId: original.id,
      isHidden: true,
    );
  }

  /// Write [decision]'s geometry (every field it carries, the others left as they are) onto the
  /// original symbol it names when [onEveryScope] is true, or onto an override of it for
  /// [targetSceneId] / [targetShotId] otherwise: [existingOverride] updated when there is one, a
  /// new override copied from [original] and moved by the decision when not.
  ///
  /// Returns false, having written nothing, when an override has to be created but [original] is
  /// null (the original is no longer in the snapshot the caller read), true otherwise.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<bool> applyScopeDecision({
    required OcptProjectDatabase database,
    required OcptFloorPlanScopeDecision decision,
    required bool onEveryScope,
    required OcptFloorPlanSymbol? original,
    required OcptFloorPlanSymbol? existingOverride,
    required String? targetSceneId,
    required String? targetShotId,
  }) async {
    if (onEveryScope || existingOverride != null) {
      await updateSymbol(
        database: database,
        symbolId: onEveryScope ? decision.symbolId : existingOverride!.id,
        xM: decision.xM == null ? const Value.absent() : Value(decision.xM!),
        yM: decision.yM == null ? const Value.absent() : Value(decision.yM!),
        rotationDeg: decision.rotationDeg == null
            ? const Value.absent()
            : Value(decision.rotationDeg!),
        widthM: decision.widthM == null ? const Value.absent() : Value(decision.widthM),
        heightM: decision.heightM == null ? const Value.absent() : Value(decision.heightM),
      );
      return true;
    }

    if (original == null) {
      return false;
    }
    await placeSymbol(
      database: database,
      setId: decision.setId,
      sceneId: targetSceneId,
      shotId: targetShotId,
      layer: original.layer,
      xM: decision.xM ?? original.xM,
      yM: decision.yM ?? original.yM,
      rotationDeg: decision.rotationDeg ?? original.rotationDeg,
      widthM: decision.widthM ?? original.widthM,
      heightM: decision.heightM ?? original.heightM,
      label: original.label,
      setElementShape: original.setElementShape,
      overridesSymbolId: decision.symbolId,
    );
    return true;
  }

  /// Throw an [ArgumentError] unless the scope [sceneId]/[shotId] derive is one [_allowedScopesOf]
  /// allows for [layer] — and, for a `set`/`props` symbol at shot scope specifically, unless
  /// [hasOverride] is true: that layer is never natively shot-scope, only ever a shot override of
  /// a scene-scope symbol. See this class's own doc comment for why this is the one place the
  /// scope invariant is checked.
  void _checkScopeInvariant({
    required String? sceneId,
    required String? shotId,
    required OcptFloorPlanLayer layer,
    required bool hasOverride,
  }) {
    final scope = ocptFloorPlanScopeOf(sceneId: sceneId, shotId: shotId);
    final allowed = _allowedScopesOf(layer);
    if (!allowed.contains(scope)) {
      throw ArgumentError(
        "A floor plan symbol's scope must be one of $allowed for layer $layer, but got $scope "
        "(sceneId: $sceneId, shotId: $shotId)",
      );
    }

    final isShotScopedSetOrProps =
        scope == OcptFloorPlanScope.shot &&
        (layer == OcptFloorPlanLayer.set || layer == OcptFloorPlanLayer.props);
    if (isShotScopedSetOrProps && !hasOverride) {
      throw ArgumentError(
        "A shot-scope symbol of layer $layer must be a shot override (overridesSymbolId) of a "
        "scene-scope symbol — it is never natively shot-scope",
      );
    }
  }

  /// Get the scopes [layer] may land in — the scope matrix `OcptFloorPlanSymbolsTable`'s own doc
  /// comment describes. A `switch` with no `default`: a sixth layer must be placed on one side or
  /// another here rather than silently landing in whichever branch happens to be listed last.
  ///
  /// **Shot scope for `set`/`props` is allowed here only as an override** —
  /// [_checkScopeInvariant] is what turns that back into "a
  /// *non*-override shot-scope `set`/`props` symbol still throws", since this set alone cannot
  /// express "allowed, but only conditionally".
  static Set<OcptFloorPlanScope> _allowedScopesOf(OcptFloorPlanLayer layer) => switch (layer) {
    OcptFloorPlanLayer.set => const {
      OcptFloorPlanScope.set,
      OcptFloorPlanScope.scene,
      OcptFloorPlanScope.shot,
    },
    OcptFloorPlanLayer.cameras ||
    OcptFloorPlanLayer.characters ||
    OcptFloorPlanLayer.lights => const {OcptFloorPlanScope.shot},
    // A breakdown prop is placed for one sequence's own coverage and may be re-dressed for one
    // shot alone through a shot-scope override —
    // set scope stays out of reach, a prop is never shared by the whole Resources set.
    OcptFloorPlanLayer.props => const {OcptFloorPlanScope.scene, OcptFloorPlanScope.shot},
  };

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Disposes the services this one owns, in the reverse order they were initialised.
  @override
  Future<void> disposeLifeCycle() async {
    await assetsService.disposeLifeCycle();

    return super.disposeLifeCycle();
  }
}
