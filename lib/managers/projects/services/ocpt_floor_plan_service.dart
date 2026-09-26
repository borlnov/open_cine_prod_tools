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
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_set_suggestion.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a screenplay's floor plans: each sequence's sets, the symbols placed on them (the
/// décor's sequence layers and each shot's own shot layers) and the arrows drawn between symbols
/// (`docs/plans/storyboard.md`, §1, §2).
///
/// [assetsService] is the one place a set's underlay `assets` row is minted or tombstoned
/// (`OcptAssetKind.floorPlanUnderlay`) — this service never reads or writes `assets.path` itself.
///
/// **The scope invariant.** `floor_plan_symbols.shotId` is null exactly when the symbol's
/// [OcptFloorPlanLayer] is sequence-scoped (`OcptFloorPlanLayerScope.isSequenceScoped`) — this
/// service is what enforces it, at [placeSymbol], the only write that can set either: an update
/// never touches `shotId` or `layer`, so nothing else can put the invariant out of step once a
/// symbol exists.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — none of the three tables this service owns carries a
/// `position` column: all three are new in a schema version that never needed one.
class OcptFloorPlanService {
  /// The service used to mint and tombstone a set's underlay `assets` row.
  final OcptAssetsService assetsService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [tombstoneFloorPlanRowsOfShot] never calls it: it writes inside a
  /// caller's own transaction, and takes that caller's own [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptFloorPlanService({required this.assetsService, required this.deviceId});

  /// Loads every live set of screenplay [screenplayId]'s sequences, each carrying its resolved
  /// underlay path and its live symbols and arrows, keyed by scene id.
  ///
  /// Runs one query per table (`floor_plan_sets`, `floor_plan_symbols`, `floor_plan_arrows`,
  /// `assets`, plus the screenplay's own live `scenes`), joined in memory — the same shape
  /// `OcptShotListService.loadShotList` keeps its own reads to.
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

    final setRows =
        await (database.select(database.ocptFloorPlanSetsTable)
              ..where((table) => table.sceneId.isIn(sceneIds) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();

    final setIds = setRows.map((row) => row.id).toList(growable: false);

    final symbolRows = setIds.isEmpty
        ? const <OcptFloorPlanSymbolRow>[]
        : await (database.select(
                database.ocptFloorPlanSymbolsTable,
              )..where((table) => table.setId.isIn(setIds) & table.isDeleted.not()))
              .get();

    final arrowRows = setIds.isEmpty
        ? const <OcptFloorPlanArrowRow>[]
        : await (database.select(
                database.ocptFloorPlanArrowsTable,
              )..where((table) => table.setId.isIn(setIds) & table.isDeleted.not()))
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
      for (final row in setRows)
        if (row.underlayAssetId != null) row.underlayAssetId!,
    };
    final pathByAssetId = await _liveAssetPathsById(
      database: database,
      assetIds: underlayAssetIds,
    );

    final setsBySceneId = <String, List<OcptFloorPlanSet>>{};
    for (final row in setRows) {
      setsBySceneId
          .putIfAbsent(row.sceneId, () => [])
          .add(
            OcptFloorPlanSet.fromRow(
              row: row,
              underlayPath: row.underlayAssetId == null ? null : pathByAssetId[row.underlayAssetId],
              symbols: symbolsBySetId[row.id] ?? const [],
              arrows: arrowsBySetId[row.id] ?? const [],
            ),
          );
    }

    return OcptFloorPlanSnapshot.build(screenplayId: screenplayId, setsBySceneId: setsBySceneId);
  }

  /// Creates a new set on scene [sceneId], named from its heading's place
  /// (`ocptSceneHeadingPlaceOf`, the breakdown's own rule), appended after the scene's current
  /// sets, and returns its freshly generated id. Does nothing (returns null) if [sceneId] doesn't
  /// name a live scene.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addSet({
    required OcptProjectDatabase database,
    required String sceneId,
  }) async {
    if (database.refusesUserWrite("addSet")) {
      return null;
    }

    final id = const Uuid().v4();
    var created = false;

    await database.transaction(() async {
      final scene = await (database.select(
        database.ocptScenesTable,
      )..where((table) => table.id.equals(sceneId) & table.isDeleted.not())).getSingleOrNull();
      if (scene == null) {
        return;
      }

      final existing = await _setRowsOfScene(database: database, sceneId: sceneId);

      final row = OcptFloorPlanSetRow(
        id: id,
        sceneId: sceneId,
        name: ocptSceneHeadingPlaceOf(scene.heading),
        sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
        isDeleted: false,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSetsTable,
        rowId: id,
        current: null,
        next: row,
        stamps: stamps,
      );
      await stamps.flush(database);
      created = true;
    });

    return created ? id : null;
  }

  /// Renames set [setId] to [name] — a user editing the tab in place.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> renameSet({
    required OcptProjectDatabase database,
    required String setId,
    required String name,
  }) async {
    if (database.refusesUserWrite("renameSet")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveSetRowOrNull(database: database, setId: setId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(name: name),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves set [setId] to [newPosition] (0-based) among its own scene's sets (its tab order), by
  /// giving it a `sortKey` sitting between the two sets it lands between. Writes **exactly one
  /// row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderSet({
    required OcptProjectDatabase database,
    required String setId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderSet")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveSetRowOrNull(database: database, setId: setId);
      if (current == null) {
        return;
      }

      final others = (await _setRowsOfScene(database: database, sceneId: current.sceneId))
        ..removeWhere((row) => row.id == setId);

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
        table: database.ocptFloorPlanSetsTable,
        rowId: setId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones set [setId], its symbols and its arrows, in one transaction. **Not** cascaded to
  /// its underlay's `assets` row on purpose — an underlay is cleared explicitly through
  /// [clearSetUnderlay] and otherwise left referenced, the same "no orphan handling" choice the
  /// set-of-a-vanished-scene state already makes (`docs/plans/storyboard.md`, §2, §8): nothing
  /// currently reads a tombstoned set's own asset back, so leaving the reference in place costs
  /// nothing and keeps this cascade mirroring exactly what [tombstoneFloorPlanRowsOfShot] tombstones
  /// for a shot — symbols and arrows, never an asset row it doesn't own the minting of.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteSet({required OcptProjectDatabase database, required String setId}) async {
    if (database.refusesUserWrite("deleteSet")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

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

      final current = await _liveSetRowOrNull(database: database, setId: setId);
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

      await stamps.flush(database);
    });
  }

  /// Sets set [setId]'s underlay to the file at [path], framed at
  /// `(xM, yM, widthM, heightM, rotationDeg)`: tombstones its previous underlay `assets` row (if
  /// any) and mints a fresh one.
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
      final current = await _liveSetRowOrNull(database: database, setId: setId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

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

  /// Clears set [setId]'s underlay: tombstones its `assets` row (if any) and blanks its frame.
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
      final current = await _liveSetRowOrNull(database: database, setId: setId);
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
  /// no `assets` row at all.
  ///
  /// This is the write a drag moving or resizing the underlay on the canvas ends on. The frame
  /// lives entirely on this table's own `underlay*M`/`underlayRotationDeg` columns, so re-framing
  /// it must never go through [setSetUnderlay]: that method unconditionally tombstones the
  /// current `assets` row and mints a fresh one, which is the right cost for actually importing or
  /// replacing the underlay's image, but is a permanent (ADR 0010) churn of dead `assets` rows for
  /// a gesture as frequent as dragging the underlay against the reference silhouette. A no-op
  /// while the set carries no underlay at all (`underlayAssetId == null`): there is nothing to
  /// re-frame.
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
      final current = await _liveSetRowOrNull(database: database, setId: setId);
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

  /// Places a new symbol of [layer] on set [setId], appended after the set's current last symbol
  /// of that layer, and returns its freshly generated id.
  ///
  /// **Enforces the scope invariant**: [shotId] must be non-null exactly when [layer] is a shot
  /// layer (`!layer.isSequenceScoped`), and null exactly when it is a sequence layer — a call that
  /// violates it throws an [ArgumentError] rather than writing a row the rest of this service could
  /// never make sense of again.
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
  }) async {
    if (database.refusesUserWrite("placeSymbol")) {
      return null;
    }

    _checkScopeInvariant(shotId: shotId, layer: layer);

    final id = const Uuid().v4();

    await database.transaction(() async {
      final existing = await _symbolRowsOfSetAndLayer(
        database: database,
        setId: setId,
        layer: layer,
      );

      final row = OcptFloorPlanSymbolRow(
        id: id,
        setId: setId,
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
        isDeleted: false,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
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
  /// guarded write. Never touches `setId`, `shotId` or `layer`: those are fixed at [placeSymbol]
  /// and nothing here can put the scope invariant out of step.
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

  /// Adds a new [kind] arrow on set [setId], belonging to shot [shotId] (always set — an arrow is
  /// always one shot's own movement, `OcptFloorPlanArrowsTable`'s own doc comment), from
  /// [fromSymbolId] to [toSymbolId], and returns its freshly generated id.
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

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
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

  /// Deep-copies set [setId] within its own scene: a new set row, appended after the scene's
  /// current tabs, plus **independent copies** of every live symbol and arrow it carries — never
  /// links (`docs/plans/storyboard.md`, §9.2) — and returns the new set's freshly generated id.
  /// Does nothing (returns null) if [setId] doesn't name a live set.
  ///
  /// The copy starts with **no underlay**: an underlay is a specific photo of a specific room, and
  /// duplicating a set is for a second room laid out the same way, not a second copy of the first
  /// room's own photo — the same posture [deleteSet] already takes towards an underlay it doesn't
  /// own the minting of. Every symbol and arrow gets a fresh id and a fresh `sortKey` run of its
  /// own (appended in the source's own draw order), so mutating the copy — moving a symbol,
  /// deleting an arrow — never touches the source's own rows.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> duplicateSet({required OcptProjectDatabase database, required String setId}) async {
    if (database.refusesUserWrite("duplicateSet")) {
      return null;
    }

    final newSetId = const Uuid().v4();
    var created = false;

    await database.transaction(() async {
      final source = await _liveSetRowOrNull(database: database, setId: setId);
      if (source == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final existingSets = await _setRowsOfScene(database: database, sceneId: source.sceneId);
      final newSetRow = OcptFloorPlanSetRow(
        id: newSetId,
        sceneId: source.sceneId,
        name: source.name,
        sortKey: ocptFractionalKeyBetween(
          before: existingSets.isEmpty ? null : existingSets.last.sortKey,
        ),
        isDeleted: false,
      );
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanSetsTable,
        rowId: newSetId,
        current: null,
        next: newSetRow,
        stamps: stamps,
      );

      final symbolRows = (await _symbolRowsOfSet(database: database, setId: setId))
        ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
      final newSymbolIdBySourceId = <String, String>{};
      for (final row in symbolRows) {
        final newSymbolId = const Uuid().v4();
        newSymbolIdBySourceId[row.id] = newSymbolId;
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanSymbolsTable,
          rowId: newSymbolId,
          current: null,
          next: row.copyWith(id: newSymbolId, setId: newSetId),
          stamps: stamps,
        );
      }

      final arrowRows = await _arrowRowsOfSet(database: database, setId: setId);
      for (final row in arrowRows) {
        final newFromSymbolId = newSymbolIdBySourceId[row.fromSymbolId];
        final newToSymbolId = newSymbolIdBySourceId[row.toSymbolId];
        // Defensive only: every arrow's own endpoints are read from this very set's own live
        // symbols above, so both are always found.
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
            setId: newSetId,
            fromSymbolId: newFromSymbolId,
            toSymbolId: newToSymbolId,
          ),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
      created = true;
    });

    return created ? newSetId : null;
  }

  /// Copies shot [sourceShotId]'s own live shot-layer symbols (cameras, characters, lights, props)
  /// and the arrows drawn between two of them, from set [sourceSetId] onto shot [destinationShotId]
  /// of set [destinationSetId] — the same set for a same-set copy, a different one for a copy across
  /// sets — as **independent copies**, appended after [destinationShotId]'s own current symbols of
  /// each layer.
  ///
  /// An arrow whose either end is a *sequence*-scoped symbol (a set element the source shot's own
  /// blocking points at or from) is **not copied**: that symbol belongs to [sourceSetId]'s own décor
  /// and has no copied counterpart on [destinationSetId] in general (nor, for a same-set copy, any
  /// reason to point the copy back at the very same décor symbol the source shot already points at)
  /// — only a movement whose both ends are themselves being copied travels with it.
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
  /// **Never touches a sequence layer or another shot's rows**: shot [shotId] can only ever own
  /// symbols whose own `shotId` equals it (the scope invariant), so this is exactly the shot's own
  /// placements, nothing of the décor it was drawn against.
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

  /// Throws an [ArgumentError] unless [shotId] is non-null exactly when [layer] is shot-scoped. See
  /// this class's own doc comment for why this is the one place the scope invariant is checked.
  void _checkScopeInvariant({required String? shotId, required OcptFloorPlanLayer layer}) {
    final isShotScoped = !layer.isSequenceScoped;
    final hasShotId = shotId != null;
    if (isShotScoped != hasShotId) {
      throw ArgumentError(
        "A floor plan symbol's shotId must be set exactly when its layer is shot-scoped, but "
        "layer $layer (isSequenceScoped: ${layer.isSequenceScoped}) was given shotId: $shotId",
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

  /// Every live set row of scene [sceneId], ordered by `sortKey`.
  Future<List<OcptFloorPlanSetRow>> _setRowsOfScene({
    required OcptProjectDatabase database,
    required String sceneId,
  }) => (database.select(database.ocptFloorPlanSetsTable)
        ..where((table) => table.sceneId.equals(sceneId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Reads back the live set row [setId], or null if it doesn't exist or has been tombstoned.
  Future<OcptFloorPlanSetRow?> _liveSetRowOrNull({
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
