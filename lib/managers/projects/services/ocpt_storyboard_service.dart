// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_fractional_key.dart';
import 'package:uuid/uuid.dart';

/// CRUD over a screenplay's storyboard: its shots' panels and each panel's light annotation layer
/// (`docs/plans/storyboard.md`, §1, §2).
///
/// [assetsService] is the one place a panel's image `assets` row is minted or tombstoned
/// (`OcptAssetKind.storyboardPanelImage`) — this service never reads or writes `assets.path`
/// itself, exactly as `OcptShotListService` never touches an element's or a location's own asset
/// columns.
///
/// {@macro open_cine_prod_tools.tombstones}
///
/// **Order is `sortKey`, never `position`** — neither `storyboard_panels` nor
/// `storyboard_annotations` carries a `position` column at all: both are new in a schema version
/// that never needed one (`docs/plans/storyboard.md`, §2).
class OcptStoryboardService {
  /// The service used to mint and tombstone a panel's image `assets` row.
  final OcptAssetsService assetsService;

  /// Resolves the device id every stamp this service's own writes carry — see
  /// [OcptDeviceIdGetter]. [tombstonePanelsOfShot] never calls it: it writes inside a caller's own
  /// transaction, and takes that caller's own [OcptRowStampService] instead.
  final OcptDeviceIdGetter deviceId;

  /// Class constructor
  const OcptStoryboardService({required this.assetsService, required this.deviceId});

  /// Loads every live panel of screenplay [screenplayId]'s shots, each carrying its resolved image
  /// path and its live annotations, keyed by shot id.
  ///
  /// Runs one query per table (`storyboard_panels`, `storyboard_annotations`, `assets`), joined in
  /// memory against the screenplay's own live shot ids — the same shape `OcptShotListService
  /// .loadShotList` keeps its own reads to, for the same reason: a storyboard is hundreds of rows,
  /// not millions.
  Future<OcptStoryboardSnapshot> loadStoryboard({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final shotIds = await _liveShotIdsOfScreenplay(database: database, screenplayId: screenplayId);
    if (shotIds.isEmpty) {
      return OcptStoryboardSnapshot(screenplayId: screenplayId, panelsByShotId: const {});
    }

    final panelRows =
        await (database.select(database.ocptStoryboardPanelsTable)
              ..where((table) => table.shotId.isIn(shotIds) & table.isDeleted.not())
              ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
            .get();

    final panelIds = panelRows.map((row) => row.id).toList(growable: false);

    final annotationRows = panelIds.isEmpty
        ? const <OcptStoryboardAnnotationRow>[]
        : await (database.select(database.ocptStoryboardAnnotationsTable)
                ..where((table) => table.panelId.isIn(panelIds) & table.isDeleted.not())
                ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
              .get();

    final annotationsByPanelId = <String, List<OcptStoryboardAnnotation>>{};
    for (final row in annotationRows) {
      annotationsByPanelId
          .putIfAbsent(row.panelId, () => [])
          .add(OcptStoryboardAnnotation.fromRow(row));
    }

    final imageAssetIds = {
      for (final row in panelRows)
        if (row.imageAssetId != null) row.imageAssetId!,
    };
    final pathByAssetId = await _liveAssetPathsById(database: database, assetIds: imageAssetIds);

    final panelsByShotId = <String, List<OcptStoryboardPanel>>{};
    for (final row in panelRows) {
      panelsByShotId
          .putIfAbsent(row.shotId, () => [])
          .add(
            OcptStoryboardPanel.fromRow(
              row: row,
              imagePath: row.imageAssetId == null ? null : pathByAssetId[row.imageAssetId],
              annotations: annotationsByPanelId[row.id] ?? const [],
            ),
          );
    }

    return OcptStoryboardSnapshot(screenplayId: screenplayId, panelsByShotId: panelsByShotId);
  }

  /// Creates a new panel on shot [shotId] in [database], appended after its current last panel, and
  /// returns its freshly generated id. No image yet — [replacePanelImage] is what imports one.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addPanel({required OcptProjectDatabase database, required String shotId}) async {
    if (database.refusesUserWrite("addPanel")) {
      return null;
    }

    final id = const Uuid().v4();

    await database.transaction(() async {
      final existing = await _panelRowsOfShot(database: database, shotId: shotId);

      final row = OcptStoryboardPanelRow(
        id: id,
        shotId: shotId,
        sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
        comment: '',
        isDeleted: false,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptStoryboardPanelsTable,
        rowId: id,
        current: null,
        next: row,
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Replaces panel [panelId]'s image with the file at [path]: tombstones its previous image
  /// `assets` row (if it had one) and mints a fresh one, re-pointing `imageAssetId` — the panel's
  /// own [panelId] never changes, so its annotations and its stamps stay attached to it.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> replacePanelImage({
    required OcptProjectDatabase database,
    required String panelId,
    required String path,
  }) async {
    if (database.refusesUserWrite("replacePanelImage")) {
      return;
    }

    await database.transaction(() async {
      final current = await _livePanelRowOrNull(database: database, panelId: panelId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());

      if (current.imageAssetId != null) {
        await assetsService.tombstoneAsset(
          database: database,
          assetId: current.imageAssetId!,
          stamps: stamps,
        );
      }

      final newAssetId = await assetsService.insertAsset(
        database: database,
        kind: OcptAssetKind.storyboardPanelImage,
        path: path,
        stamps: stamps,
      );

      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptStoryboardPanelsTable,
        rowId: panelId,
        current: current,
        next: current.copyWith(imageAssetId: Value(newAssetId)),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Moves panel [panelId] to [newPosition] (0-based) within its own shot's panels, by giving it a
  /// `sortKey` sitting between the two panels it lands between. Writes **exactly one row**.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> reorderPanel({
    required OcptProjectDatabase database,
    required String panelId,
    required int newPosition,
  }) async {
    if (database.refusesUserWrite("reorderPanel")) {
      return;
    }

    await database.transaction(() async {
      final panel = await _livePanelRowOrNull(database: database, panelId: panelId);
      if (panel == null) {
        return;
      }

      final others = (await _panelRowsOfShot(database: database, shotId: panel.shotId))
        ..removeWhere((row) => row.id == panelId);

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
        table: database.ocptStoryboardPanelsTable,
        rowId: panelId,
        current: panel,
        next: panel.copyWith(sortKey: sortKey),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Updates panel [panelId]'s free comment.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updatePanelComment({
    required OcptProjectDatabase database,
    required String panelId,
    required String comment,
  }) async {
    if (database.refusesUserWrite("updatePanelComment")) {
      return;
    }

    await database.transaction(() async {
      final current = await _livePanelRowOrNull(database: database, panelId: panelId);
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptStoryboardPanelsTable,
        rowId: panelId,
        current: current,
        next: current.copyWith(comment: comment),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones panel [panelId], its annotations and its image `assets` row (if it had one), in one
  /// transaction.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deletePanel({
    required OcptProjectDatabase database,
    required String panelId,
  }) async {
    if (database.refusesUserWrite("deletePanel")) {
      return;
    }

    await database.transaction(() async {
      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await _tombstonePanel(database: database, panelId: panelId, stamps: stamps);
      await stamps.flush(database);
    });
  }

  /// Adds a mark of [kind] to panel [panelId] at the normalised point/segment
  /// `(x1, y1)`-`(x2, y2)`, appended after the panel's current last mark, and returns its freshly
  /// generated id.
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<String?> addAnnotation({
    required OcptProjectDatabase database,
    required String panelId,
    required OcptStoryboardAnnotationKind kind,
    required double x1,
    required double y1,
    double x2 = 0,
    double y2 = 0,
    String text = '',
  }) async {
    if (database.refusesUserWrite("addAnnotation")) {
      return null;
    }

    final id = const Uuid().v4();

    await database.transaction(() async {
      final existing = await _annotationRowsOfPanel(database: database, panelId: panelId);

      final row = OcptStoryboardAnnotationRow(
        id: id,
        panelId: panelId,
        kind: kind,
        sortKey: ocptFractionalKeyBetween(before: existing.isEmpty ? null : existing.last.sortKey),
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        labelText: text,
        isDeleted: false,
      );

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptStoryboardAnnotationsTable,
        rowId: id,
        current: null,
        next: row,
        stamps: stamps,
      );
      await stamps.flush(database);
    });

    return id;
  }

  /// Updates annotation [annotationId]'s geometry and/or text, whichever is passed as something
  /// other than [Value.absent].
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> updateAnnotation({
    required OcptProjectDatabase database,
    required String annotationId,
    Value<double> x1 = const Value.absent(),
    Value<double> y1 = const Value.absent(),
    Value<double> x2 = const Value.absent(),
    Value<double> y2 = const Value.absent(),
    Value<String> text = const Value.absent(),
  }) async {
    if (database.refusesUserWrite("updateAnnotation")) {
      return;
    }

    final companion = OcptStoryboardAnnotationsTableCompanion(
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      labelText: text,
    );

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptStoryboardAnnotationsTable,
      )..where((table) => table.id.equals(annotationId) & table.isDeleted.not())).getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptStoryboardAnnotationsTable,
        rowId: annotationId,
        current: current,
        next: current.copyWithCompanion(companion),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones annotation [annotationId].
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  ///
  /// {@macro open_cine_prod_tools.OcptProjectDatabase.previewGuard}
  Future<void> deleteAnnotation({
    required OcptProjectDatabase database,
    required String annotationId,
  }) async {
    if (database.refusesUserWrite("deleteAnnotation")) {
      return;
    }

    await database.transaction(() async {
      final current = await (database.select(
        database.ocptStoryboardAnnotationsTable,
      )..where((table) => table.id.equals(annotationId) & table.isDeleted.not())).getSingleOrNull();
      if (current == null) {
        return;
      }

      final stamps = await OcptRowStampService.seed(database: database, deviceId: await deviceId());
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptStoryboardAnnotationsTable,
        rowId: annotationId,
        current: current,
        next: current.copyWith(isDeleted: true),
        stamps: stamps,
      );
      await stamps.flush(database);
    });
  }

  /// Tombstones every panel of shot [shotId] — its annotations and its image `assets` row along
  /// with each one — for `OcptShotListService.deleteShot`'s and `.tombstoneShotsOfScreenplay`'s own
  /// cascade.
  ///
  /// **Unguarded**, exactly as `OcptShotListService.tombstoneShotsOfScreenplay` is: its only caller
  /// has already refused the write on a preview connection and is already inside the transaction
  /// removing the shot, so a second guard here would only be able to disagree with the first — and
  /// stamps through [stamps], that caller's own instance, for the same reason.
  ///
  /// {@macro open_cine_prod_tools.tombstones}
  Future<void> tombstonePanelsOfShot({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptRowStampService? stamps,
  }) async {
    final panelRows = await _panelRowsOfShot(database: database, shotId: shotId);
    for (final panel in panelRows) {
      await _tombstonePanel(database: database, panelId: panel.id, stamps: stamps, panel: panel);
    }
  }

  /// Tombstones panel [panelId]'s annotations, then the panel itself and its image `assets` row (if
  /// any) — the write body [deletePanel] and [tombstonePanelsOfShot] share, taking [stamps] as
  /// given by whichever transaction is already open around it. [panel] may be passed to skip the
  /// lookup when the caller already has the row (as [tombstonePanelsOfShot] does).
  Future<void> _tombstonePanel({
    required OcptProjectDatabase database,
    required String panelId,
    required OcptRowStampService? stamps,
    OcptStoryboardPanelRow? panel,
  }) async {
    final annotationRows = await _annotationRowsOfPanel(database: database, panelId: panelId);
    for (final row in annotationRows) {
      await OcptRowStampService.writeAndStamp(
        database: database,
        table: database.ocptStoryboardAnnotationsTable,
        rowId: row.id,
        current: row,
        next: row.copyWith(isDeleted: true),
        stamps: stamps,
      );
    }

    final current = panel ?? await _livePanelRowOrNull(database: database, panelId: panelId);
    if (current == null) {
      return;
    }

    if (current.imageAssetId != null) {
      await assetsService.tombstoneAsset(
        database: database,
        assetId: current.imageAssetId!,
        stamps: stamps,
      );
    }

    await OcptRowStampService.writeAndStamp(
      database: database,
      table: database.ocptStoryboardPanelsTable,
      rowId: panelId,
      current: current,
      next: current.copyWith(isDeleted: true),
      stamps: stamps,
    );
  }

  /// Every live shot id of screenplay [screenplayId].
  Future<List<String>> _liveShotIdsOfScreenplay({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final rows =
        await (database.select(database.ocptShotsTable)..where(
              (table) => table.screenplayId.equals(screenplayId) & table.isDeleted.not(),
            ))
            .get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  /// The resolved absolute path of every live `assets` row of [assetIds], keyed by id — a row
  /// [assetIds] names but that no longer exists, or is tombstoned, is simply absent from the map,
  /// which is how a caller reads "file reference gone" the same way an unresolved path already
  /// reads (ADR 0013).
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

  /// Every live panel row of shot [shotId], ordered by `sortKey`.
  Future<List<OcptStoryboardPanelRow>> _panelRowsOfShot({
    required OcptProjectDatabase database,
    required String shotId,
  }) => (database.select(database.ocptStoryboardPanelsTable)
        ..where((table) => table.shotId.equals(shotId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();

  /// Reads back the live panel row [panelId], or null if it doesn't exist or has been tombstoned.
  Future<OcptStoryboardPanelRow?> _livePanelRowOrNull({
    required OcptProjectDatabase database,
    required String panelId,
  }) => (database.select(database.ocptStoryboardPanelsTable)
        ..where((table) => table.id.equals(panelId) & table.isDeleted.not()))
      .getSingleOrNull();

  /// Every live annotation row of panel [panelId], ordered by `sortKey`.
  Future<List<OcptStoryboardAnnotationRow>> _annotationRowsOfPanel({
    required OcptProjectDatabase database,
    required String panelId,
  }) => (database.select(database.ocptStoryboardAnnotationsTable)
        ..where((table) => table.panelId.equals(panelId) & table.isDeleted.not())
        ..orderBy([(table) => OrderingTerm.asc(table.sortKey)]))
      .get();
}
