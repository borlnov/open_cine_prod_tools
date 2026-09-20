// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_case.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_set_suggestion.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a screenplay's floor plans: each sequence's cases, the symbols placed on them (the
/// décor's sequence layers and each shot's own shot layers) and the arrows drawn between symbols
/// (`docs/plans/storyboard.md`, §1, §2).
///
/// [assetsService] is the one place a case's underlay `assets` row is minted or tombstoned
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
  /// The service used to mint and tombstone a case's underlay `assets` row.
  final OcptAssetsService assetsService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [tombstoneFloorPlanRowsOfShot] never calls it: it writes inside a
  /// caller's own transaction, and takes that caller's own [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptFloorPlanService({required this.assetsService, required this.deviceId});

  /// Loads every live case of screenplay [screenplayId]'s sequences, each carrying its resolved
  /// underlay path and its live symbols and arrows, keyed by scene id.
  ///
  /// Runs one query per table (`floor_plan_cases`, `floor_plan_symbols`, `floor_plan_arrows`,
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
      return OcptFloorPlanSnapshot.build(screenplayId: screenplayId, casesBySceneId: const {});
    }

    final caseRows =
        await (database.select(database.ocptFloorPlanCasesTable)
              ..where((table) => table.sceneId.isIn(sceneIds) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();

    final caseIds = caseRows.map((row) => row.id).toList(growable: false);

    final symbolRows = caseIds.isEmpty
        ? const <OcptFloorPlanSymbolRow>[]
        : await (database.select(
                database.ocptFloorPlanSymbolsTable,
              )..where((table) => table.caseId.isIn(caseIds) & table.isDeleted.not()))
              .get();

    final arrowRows = caseIds.isEmpty
        ? const <OcptFloorPlanArrowRow>[]
        : await (database.select(
                database.ocptFloorPlanArrowsTable,
              )..where((table) => table.caseId.isIn(caseIds) & table.isDeleted.not()))
              .get();

    final symbolsByCaseId = <String, List<OcptFloorPlanSymbol>>{};
    for (final row in symbolRows) {
      symbolsByCaseId.putIfAbsent(row.caseId, () => []).add(OcptFloorPlanSymbol.fromRow(row));
    }

    final arrowsByCaseId = <String, List<OcptFloorPlanArrow>>{};
    for (final row in arrowRows) {
      arrowsByCaseId.putIfAbsent(row.caseId, () => []).add(OcptFloorPlanArrow.fromRow(row));
    }

    final underlayAssetIds = {
      for (final row in caseRows)
        if (row.underlayAssetId != null) row.underlayAssetId!,
    };
    final pathByAssetId = await _liveAssetPathsById(
      database: database,
      assetIds: underlayAssetIds,
    );

    final casesBySceneId = <String, List<OcptFloorPlanCase>>{};
    for (final row in caseRows) {
      casesBySceneId
          .putIfAbsent(row.sceneId, () => [])
          .add(
            OcptFloorPlanCase.fromRow(
              row: row,
              underlayPath: row.underlayAssetId == null ? null : pathByAssetId[row.underlayAssetId],
              symbols: symbolsByCaseId[row.id] ?? const [],
              arrows: arrowsByCaseId[row.id] ?? const [],
            ),
          );
    }

    return OcptFloorPlanSnapshot.build(screenplayId: screenplayId, casesBySceneId: casesBySceneId);
  }

  /// Creates a new case on scene [sceneId], named from its heading's place
  /// (`ocptSceneHeadingPlaceOf`, the breakdown's own rule), appended after the scene's current
  /// cases, and returns its freshly generated id. Does nothing (returns null) if [sceneId] doesn't
  /// name a live scene.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addCase({
    required OcptProjectDatabase database,
    required String sceneId,
  }) async {
    if (database.refusesUserWrite("addCase")) {
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

      final existing = await _caseRowsOfScene(database: database, sceneId: sceneId);

      final row = OcptFloorPlanCaseRow(
        id: id,
        sceneId: sceneId,
        name: ocptSceneHeadingPlaceOf(scene.heading),
        sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
        isDeleted: false,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanCasesTable,
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

  /// Renames case [caseId] to [name] — a user editing the tab in place.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> renameCase({
    required OcptProjectDatabase database,
    required String caseId,
    required String name,
  }) async {
    if (database.refusesUserWrite("renameCase")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveCaseRowOrNull(database: database, caseId: caseId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanCasesTable,
        rowId: caseId,
        current: current,
        next: current.copyWith(name: name),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves case [caseId] to [newPosition] (0-based) among its own scene's cases (its tab order), by
  /// giving it a `sortKey` sitting between the two cases it lands between. Writes **exactly one
  /// row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderCase({
    required OcptProjectDatabase database,
    required String caseId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderCase")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveCaseRowOrNull(database: database, caseId: caseId);
      if (current == null) {
        return;
      }

      final others = (await _caseRowsOfScene(database: database, sceneId: current.sceneId))
        ..removeWhere((row) => row.id == caseId);

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
        table: database.ocptFloorPlanCasesTable,
        rowId: caseId,
        current: current,
        next: current.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones case [caseId], its symbols and its arrows, in one transaction. **Not** cascaded to
  /// its underlay's `assets` row on purpose — an underlay is cleared explicitly through
  /// [clearCaseUnderlay] and otherwise left referenced, the same "no orphan handling" choice the
  /// case-of-a-vanished-scene state already makes (`docs/plans/storyboard.md`, §2, §8): nothing
  /// currently reads a tombstoned case's own asset back, so leaving the reference in place costs
  /// nothing and keeps this cascade mirroring exactly what [tombstoneFloorPlanRowsOfShot] tombstones
  /// for a shot — symbols and arrows, never an asset row it doesn't own the minting of.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteCase({required OcptProjectDatabase database, required String caseId}) async {
    if (database.refusesUserWrite("deleteCase")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      final arrowRows = await _arrowRowsOfCase(database: database, caseId: caseId);
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

      final symbolRows = await _symbolRowsOfCase(database: database, caseId: caseId);
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

      final current = await _liveCaseRowOrNull(database: database, caseId: caseId);
      if (current != null) {
        await OcptRowStampService.writeAndStamp(
          database: database,
          table: database.ocptFloorPlanCasesTable,
          rowId: caseId,
          current: current,
          next: current.copyWith(isDeleted: true),
          stamps: stamps,
        );
      }

      await stamps.flush(database);
    });
  }

  /// Sets case [caseId]'s underlay to the file at [path], framed at
  /// `(xM, yM, widthM, heightM, rotationDeg)`: tombstones its previous underlay `assets` row (if
  /// any) and mints a fresh one.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> setCaseUnderlay({
    required OcptProjectDatabase database,
    required String caseId,
    required String path,
    required double xM,
    required double yM,
    required double widthM,
    required double heightM,
    double rotationDeg = 0,
  }) async {
    if (database.refusesUserWrite("setCaseUnderlay")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveCaseRowOrNull(database: database, caseId: caseId);
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
        table: database.ocptFloorPlanCasesTable,
        rowId: caseId,
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

  /// Clears case [caseId]'s underlay: tombstones its `assets` row (if any) and blanks its frame.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> clearCaseUnderlay({
    required OcptProjectDatabase database,
    required String caseId,
  }) async {
    if (database.refusesUserWrite("clearCaseUnderlay")) {
      return;
    }

    await database.transaction(() async {
      final current = await _liveCaseRowOrNull(database: database, caseId: caseId);
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
        table: database.ocptFloorPlanCasesTable,
        rowId: caseId,
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

  /// Updates case [caseId]'s underlay **frame** — its centre, size and/or rotation, whichever is
  /// passed as something other than [Value.absent] — through a single guarded write that touches
  /// no `assets` row at all.
  ///
  /// This is the write a drag moving or resizing the underlay on the canvas ends on. The frame
  /// lives entirely on this table's own `underlay*M`/`underlayRotationDeg` columns, so re-framing
  /// it must never go through [setCaseUnderlay]: that method unconditionally tombstones the
  /// current `assets` row and mints a fresh one, which is the right cost for actually importing or
  /// replacing the underlay's image, but is a permanent (ADR 0010) churn of dead `assets` rows for
  /// a gesture as frequent as dragging the underlay against the reference silhouette. A no-op
  /// while the case carries no underlay at all (`underlayAssetId == null`): there is nothing to
  /// re-frame.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateUnderlayFrame({
    required OcptProjectDatabase database,
    required String caseId,
    Value<double> xM = const Value.absent(),
    Value<double> yM = const Value.absent(),
    Value<double> widthM = const Value.absent(),
    Value<double> heightM = const Value.absent(),
    Value<double> rotationDeg = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateUnderlayFrame")) {
      return;
    }

    final companion = OcptFloorPlanCasesTableCompanion(
      underlayXM: xM,
      underlayYM: yM,
      underlayWidthM: widthM,
      underlayHeightM: heightM,
      underlayRotationDeg: rotationDeg,
    );

    await database.transaction(() async {
      final current = await _liveCaseRowOrNull(database: database, caseId: caseId);
      if (current == null || current.underlayAssetId == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptFloorPlanCasesTable,
        rowId: caseId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Places a new symbol of [layer] on case [caseId], appended after the case's current last symbol
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
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> placeSymbol({
    required OcptProjectDatabase database,
    required String caseId,
    required String? shotId,
    required OcptFloorPlanLayer layer,
    required double xM,
    required double yM,
    double rotationDeg = 0,
    double? widthM,
    double? heightM,
    double? fovDeg,
    String label = '',
    OcptFloorPlanSetElementShape? setElementShape,
  }) async {
    if (database.refusesUserWrite("placeSymbol")) {
      return null;
    }

    _checkScopeInvariant(shotId: shotId, layer: layer);

    final id = const Uuid().v4();

    await database.transaction(() async {
      final existing = await _symbolRowsOfCaseAndLayer(
        database: database,
        caseId: caseId,
        layer: layer,
      );

      final row = OcptFloorPlanSymbolRow(
        id: id,
        caseId: caseId,
        shotId: shotId,
        layer: layer,
        sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
        xM: xM,
        yM: yM,
        rotationDeg: rotationDeg,
        widthM: widthM,
        heightM: heightM,
        fovDeg: fovDeg,
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

  /// Updates symbol [symbolId]'s position, rotation, footprint, field of view, label and/or
  /// set-element shape, whichever is passed as something other than [Value.absent] — a move writes
  /// `xM`/`yM`, a rotate writes `rotationDeg`, a resize writes `widthM`/`heightM`,
  /// [setElementShape] switches a décor primitive's own type (a wall turned into a door, say), and
  /// so on, all through this one guarded write. Never touches `caseId`, `shotId` or `layer`: those
  /// are fixed at [placeSymbol] and nothing here can put the scope invariant out of step.
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

  /// Adds a new [kind] arrow on case [caseId], belonging to shot [shotId] (always set — an arrow is
  /// always one shot's own movement, `OcptFloorPlanArrowsTable`'s own doc comment), from
  /// [fromSymbolId] to [toSymbolId], and returns its freshly generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addArrow({
    required OcptProjectDatabase database,
    required String caseId,
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
        caseId: caseId,
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

  /// Every live case row of scene [sceneId], ordered by `sortKey`.
  Future<List<OcptFloorPlanCaseRow>> _caseRowsOfScene({
    required OcptProjectDatabase database,
    required String sceneId,
  }) => (database.select(database.ocptFloorPlanCasesTable)
        ..where((table) => table.sceneId.equals(sceneId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Reads back the live case row [caseId], or null if it doesn't exist or has been tombstoned.
  Future<OcptFloorPlanCaseRow?> _liveCaseRowOrNull({
    required OcptProjectDatabase database,
    required String caseId,
  }) => (database.select(database.ocptFloorPlanCasesTable)
        ..where((table) => table.id.equals(caseId) & table.isDeleted.not()))
      .getSingleOrNull();

  /// Every live symbol row of case [caseId].
  Future<List<OcptFloorPlanSymbolRow>> _symbolRowsOfCase({
    required OcptProjectDatabase database,
    required String caseId,
  }) => (database.select(
        database.ocptFloorPlanSymbolsTable,
      )..where((table) => table.caseId.equals(caseId) & table.isDeleted.not()))
      .get();

  /// Every live symbol row of case [caseId] on layer [layer], ordered by `sortKey` — what a new
  /// symbol of that layer is appended after.
  Future<List<OcptFloorPlanSymbolRow>> _symbolRowsOfCaseAndLayer({
    required OcptProjectDatabase database,
    required String caseId,
    required OcptFloorPlanLayer layer,
  }) => (database.select(database.ocptFloorPlanSymbolsTable)
        ..where(
          (table) =>
              table.caseId.equals(caseId) &
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

  /// Every live arrow row of case [caseId].
  Future<List<OcptFloorPlanArrowRow>> _arrowRowsOfCase({
    required OcptProjectDatabase database,
    required String caseId,
  }) => (database.select(
        database.ocptFloorPlanArrowsTable,
      )..where((table) => table.caseId.equals(caseId) & table.isDeleted.not()))
      .get();

  /// Reads back the live arrow row [arrowId], or null if it doesn't exist or has been tombstoned.
  Future<OcptFloorPlanArrowRow?> _liveArrowRowOrNull({
    required OcptProjectDatabase database,
    required String arrowId,
  }) => (database.select(database.ocptFloorPlanArrowsTable)
        ..where((table) => table.id.equals(arrowId) & table.isDeleted.not()))
      .getSingleOrNull();
}
