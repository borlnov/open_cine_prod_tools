// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';

/// The fixed device id every stamp this file's writes carry.
const _deviceId = "device-1";

Future<String> _testDeviceId() async => _deviceId;

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const assetsService = OcptAssetsService(deviceId: _testDeviceId);
  const storyboardService = OcptStoryboardService(
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const elementsService = OcptElementsService(assetsService: assetsService, deviceId: _testDeviceId);
  const locationsService = OcptLocationsService(
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const roleIndexService = OcptRoleIndexService(
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(deviceId: _testDeviceId),
    deviceId: _testDeviceId,
  );
  const shotListService = OcptShotListService(
    roleIndexService: roleIndexService,
    storyboardService: storyboardService,
    floorPlanService: OcptFloorPlanService(assetsService: assetsService, deviceId: _testDeviceId),
    deviceId: _testDeviceId,
  );
  const screenplayService = OcptScreenplayService(
    sceneIndexService: OcptSceneIndexService(),
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(deviceId: _testDeviceId),
    roleIndexService: roleIndexService,
    breakdownService: OcptBreakdownService(
      elementsService: elementsService,
      locationsService: locationsService,
      deviceId: _testDeviceId,
    ),
    scheduleService: OcptScheduleService(deviceId: _testDeviceId),
    deviceId: _testDeviceId,
  );
  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;

  setUp(() async {
    database = OcptProjectDatabase.memory();
    await database
        .into(database.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  /// Saves a one-scene screenplay and returns the fresh shot id created inside it, ready for a
  /// panel to be attached to.
  Future<String> seedShot() async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );
    final scene = await (database.select(
      database.ocptScenesTable,
    )..where((row) => row.isDeleted.equals(false))).getSingle();

    return (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: scene.id,
    ))!;
  }

  Future<List<OcptStoryboardPanelRow>> readPanels() => (database.select(
    database.ocptStoryboardPanelsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptStoryboardPanelRow>> readPanelsIncludingTombstones() =>
      database.select(database.ocptStoryboardPanelsTable).get();

  Future<List<OcptStoryboardAnnotationRow>> readAnnotations() => (database.select(
    database.ocptStoryboardAnnotationsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptAssetRow>> readLiveAssets() =>
      (database.select(database.ocptAssetsTable)..where((row) => row.isDeleted.equals(false))).get();

  group("loadStoryboard", () {
    test("returns an empty snapshot for a screenplay with no shots", () async {
      final snapshot = await storyboardService.loadStoryboard(
        database: database,
        screenplayId: screenplayId,
      );

      expect(snapshot.panelsByShotId, isEmpty);
    });

    test("groups live panels by shot, in sortKey order, with their annotations attached", () async {
      final shotId = await seedShot();
      final firstId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      final secondId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      await storyboardService.addAnnotation(
        database: database,
        panelId: firstId,
        kind: OcptStoryboardAnnotationKind.label,
        x1: 0.5,
        y1: 0.5,
        text: "note",
      );

      final snapshot = await storyboardService.loadStoryboard(
        database: database,
        screenplayId: screenplayId,
      );

      final panels = snapshot.panelsOfShot(shotId);
      expect(panels.map((panel) => panel.id), [firstId, secondId]);
      expect(panels.first.annotations, hasLength(1));
      expect(panels.first.annotations.single.text, "note");
      expect(panels.last.annotations, isEmpty);
    });

    test("resolves a panel's image path off its asset row, null while it has none", () async {
      final shotId = await seedShot();
      final panelId = (await storyboardService.addPanel(database: database, shotId: shotId))!;

      final beforeImport = await storyboardService.loadStoryboard(
        database: database,
        screenplayId: screenplayId,
      );
      expect(beforeImport.panelsOfShot(shotId).single.imagePath, isNull);

      await storyboardService.replacePanelImage(
        database: database,
        panelId: panelId,
        path: "/tmp/frame.jpg",
      );

      final afterImport = await storyboardService.loadStoryboard(
        database: database,
        screenplayId: screenplayId,
      );
      expect(afterImport.panelsOfShot(shotId).single.imagePath, "/tmp/frame.jpg");
    });
  });

  group("addPanel", () {
    test("appends a panel after the shot's current last one", () async {
      final shotId = await seedShot();
      final firstId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      final secondId = (await storyboardService.addPanel(database: database, shotId: shotId))!;

      final panels = await (database.select(database.ocptStoryboardPanelsTable)
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();
      expect(panels.map((row) => row.id), [firstId, secondId]);
      expect(panels.every((row) => row.imageAssetId == null), isTrue);
    });
  });

  group("replacePanelImage", () {
    test("mints a fresh asset on first import and re-points imageAssetId", () async {
      final shotId = await seedShot();
      final panelId = (await storyboardService.addPanel(database: database, shotId: shotId))!;

      await storyboardService.replacePanelImage(
        database: database,
        panelId: panelId,
        path: "/tmp/frame-1.jpg",
      );

      final panel = (await readPanels()).single;
      expect(panel.imageAssetId, isNotNull);

      final assets = await readLiveAssets();
      expect(assets, hasLength(1));
      expect(assets.single.id, panel.imageAssetId);
      expect(assets.single.path, "/tmp/frame-1.jpg");
      expect(assets.single.kind, OcptAssetKind.storyboardPanelImage);
    });

    test("tombstones the previous image asset and mints a new one, keeping the panel's own id", () async {
      final shotId = await seedShot();
      final panelId = (await storyboardService.addPanel(database: database, shotId: shotId))!;

      await storyboardService.replacePanelImage(
        database: database,
        panelId: panelId,
        path: "/tmp/frame-1.jpg",
      );
      final firstAssetId = (await readPanels()).single.imageAssetId!;

      await storyboardService.replacePanelImage(
        database: database,
        panelId: panelId,
        path: "/tmp/frame-2.jpg",
      );

      final panel = (await readPanels()).single;
      expect(panel.id, panelId);
      expect(panel.imageAssetId, isNot(firstAssetId));

      final liveAssets = await readLiveAssets();
      expect(liveAssets, hasLength(1));
      expect(liveAssets.single.path, "/tmp/frame-2.jpg");

      final allAssets = await database.select(database.ocptAssetsTable).get();
      final tombstoned = allAssets.singleWhere((row) => row.id == firstAssetId);
      expect(tombstoned.isDeleted, isTrue);
    });
  });

  group("reorderPanel", () {
    test("moves a panel by writing exactly one row", () async {
      final shotId = await seedShot();
      final firstId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      final secondId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      final thirdId = (await storyboardService.addPanel(database: database, shotId: shotId))!;

      final sortKeysBefore = {
        for (final row in await readPanels()) row.id: row.sortKey,
      };

      await storyboardService.reorderPanel(database: database, panelId: thirdId, newPosition: 0);

      final panels = await readPanels();
      final sortKeysAfter = {for (final row in panels) row.id: row.sortKey};

      expect(sortKeysAfter[firstId], sortKeysBefore[firstId]);
      expect(sortKeysAfter[secondId], sortKeysBefore[secondId]);
      expect(sortKeysAfter[thirdId], isNot(sortKeysBefore[thirdId]));

      final orderedIds = (panels..sort((a, b) => a.sortKey.compareTo(b.sortKey)))
          .map((row) => row.id);
      expect(orderedIds, [thirdId, firstId, secondId]);
    });
  });

  group("updatePanelComment", () {
    test("updates only the comment", () async {
      final shotId = await seedShot();
      final panelId = (await storyboardService.addPanel(database: database, shotId: shotId))!;

      await storyboardService.updatePanelComment(
        database: database,
        panelId: panelId,
        comment: "dolly in slowly",
      );

      final panel = (await readPanels()).single;
      expect(panel.comment, "dolly in slowly");
    });
  });

  group("deletePanel", () {
    test("tombstones the panel, its annotations and its image asset in one go", () async {
      final shotId = await seedShot();
      final panelId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      await storyboardService.replacePanelImage(
        database: database,
        panelId: panelId,
        path: "/tmp/frame.jpg",
      );
      final assetId = (await readPanels()).single.imageAssetId!;
      await storyboardService.addAnnotation(
        database: database,
        panelId: panelId,
        kind: OcptStoryboardAnnotationKind.label,
        x1: 0.2,
        y1: 0.2,
        text: "note",
      );

      await storyboardService.deletePanel(database: database, panelId: panelId);

      expect(await readPanels(), isEmpty);
      expect(await readAnnotations(), isEmpty);

      final tombstonedPanel = (await readPanelsIncludingTombstones()).single;
      expect(tombstonedPanel.isDeleted, isTrue);

      final asset = await (database.select(
        database.ocptAssetsTable,
      )..where((row) => row.id.equals(assetId))).getSingle();
      expect(asset.isDeleted, isTrue);
    });
  });

  group("annotations", () {
    test("addAnnotation appends and updateAnnotation changes geometry/text", () async {
      final shotId = await seedShot();
      final panelId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      final annotationId = (await storyboardService.addAnnotation(
        database: database,
        panelId: panelId,
        kind: OcptStoryboardAnnotationKind.movementArrow,
        x1: 0.1,
        y1: 0.1,
        x2: 0.4,
        y2: 0.4,
      ))!;

      await storyboardService.updateAnnotation(
        database: database,
        annotationId: annotationId,
        x2: const Value(0.9),
        text: const Value("dolly in"),
      );

      final annotation = (await readAnnotations()).single;
      expect(annotation.x1, 0.1);
      expect(annotation.x2, 0.9);
      expect(annotation.labelText, "dolly in");
    });

    test("deleteAnnotation tombstones it", () async {
      final shotId = await seedShot();
      final panelId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      final annotationId = (await storyboardService.addAnnotation(
        database: database,
        panelId: panelId,
        kind: OcptStoryboardAnnotationKind.label,
        x1: 0.5,
        y1: 0.5,
        text: "note",
      ))!;

      await storyboardService.deleteAnnotation(database: database, annotationId: annotationId);

      expect(await readAnnotations(), isEmpty);
    });
  });

  group("tombstonePanelsOfShot", () {
    test("tombstones every panel of the shot, its annotations and its image asset", () async {
      final shotId = await seedShot();
      final panelId = (await storyboardService.addPanel(database: database, shotId: shotId))!;
      await storyboardService.replacePanelImage(
        database: database,
        panelId: panelId,
        path: "/tmp/frame.jpg",
      );
      final assetId = (await readPanels()).single.imageAssetId!;
      await storyboardService.addAnnotation(
        database: database,
        panelId: panelId,
        kind: OcptStoryboardAnnotationKind.label,
        x1: 0.5,
        y1: 0.5,
        text: "note",
      );

      await database.transaction(() async {
        final stamps = await OcptRowStampService.seed(database: database, deviceId: _deviceId);
        await storyboardService.tombstonePanelsOfShot(
          database: database,
          shotId: shotId,
          stamps: stamps,
        );
        await stamps.flush(database);
      });

      expect(await readPanels(), isEmpty);
      expect(await readAnnotations(), isEmpty);
      final asset = await (database.select(
        database.ocptAssetsTable,
      )..where((row) => row.id.equals(assetId))).getSingle();
      expect(asset.isDeleted, isTrue);
    });
  });
}
