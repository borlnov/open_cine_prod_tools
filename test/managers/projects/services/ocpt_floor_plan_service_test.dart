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
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// The fixed device id every stamp this file's writes carry.
const _deviceId = "device-1";

Future<String> _testDeviceId() async => _deviceId;

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const assetsService = OcptAssetsService(deviceId: _testDeviceId);
  const floorPlanService = OcptFloorPlanService(
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
    storyboardService: OcptStoryboardService(assetsService: assetsService, deviceId: _testDeviceId),
    floorPlanService: floorPlanService,
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

  /// Saves a one-scene screenplay and returns its scene id.
  Future<String> seedScene() async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. KITCHEN - DAY

Action.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );
    final scene = await (database.select(
      database.ocptScenesTable,
    )..where((row) => row.isDeleted.equals(false))).getSingle();
    return scene.id;
  }

  /// Saves a scene and creates a shot on it, returning the shot id.
  Future<String> seedShot() async {
    final sceneId = await seedScene();
    return (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: sceneId,
    ))!;
  }

  Future<List<OcptFloorPlanCaseRow>> readCases() => (database.select(
    database.ocptFloorPlanCasesTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptFloorPlanSymbolRow>> readSymbols() => (database.select(
    database.ocptFloorPlanSymbolsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptFloorPlanArrowRow>> readArrows() => (database.select(
    database.ocptFloorPlanArrowsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  group("loadFloorPlans", () {
    test("returns an empty snapshot for a screenplay with no cases", () async {
      final snapshot = await floorPlanService.loadFloorPlans(
        database: database,
        screenplayId: screenplayId,
      );

      expect(snapshot.casesById, isEmpty);
    });

    test("groups live cases by scene, each carrying its own live symbols and arrows", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: null,
        layer: OcptFloorPlanLayer.decor,
        xM: 1,
        yM: 1,
      ))!;

      final snapshot = await floorPlanService.loadFloorPlans(
        database: database,
        screenplayId: screenplayId,
      );

      final cases = snapshot.casesOfScene(sceneId);
      expect(cases, hasLength(1));
      expect(cases.single.id, caseId);
      expect(cases.single.symbols.single.id, symbolId);
      expect(snapshot.casesById[caseId], isNotNull);
    });

    test("names a fresh case after the scene heading's place", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      final row = (await readCases()).single;
      expect(row.id, caseId);
      expect(row.name, "KITCHEN");
    });
  });

  group("case CRUD", () {
    test("addCase appends after the scene's current cases", () async {
      final sceneId = await seedScene();
      final firstId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;
      final secondId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      final cases = await (database.select(database.ocptFloorPlanCasesTable)
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();
      expect(cases.map((row) => row.id), [firstId, secondId]);
    });

    test("renameCase changes only the name", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      await floorPlanService.renameCase(database: database, caseId: caseId, name: "Hallway");

      expect((await readCases()).single.name, "Hallway");
    });

    test("reorderCase moves a case by writing exactly one row", () async {
      final sceneId = await seedScene();
      final firstId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;
      final secondId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      final before = {for (final row in await readCases()) row.id: row.sortKey};
      await floorPlanService.reorderCase(database: database, caseId: secondId, newPosition: 0);
      final after = {for (final row in await readCases()) row.id: row.sortKey};

      expect(after[firstId], before[firstId]);
      expect(after[secondId], isNot(before[secondId]));
    });

    test("deleteCase tombstones the case, its symbols and its arrows", () async {
      final sceneId = await seedScene();
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;
      final symbol1 = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: null,
        layer: OcptFloorPlanLayer.decor,
        xM: 0,
        yM: 0,
      ))!;
      final symbol2 = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      ))!;
      await floorPlanService.addArrow(
        database: database,
        caseId: caseId,
        shotId: shotId!,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: symbol1,
        toSymbolId: symbol2,
      );

      await floorPlanService.deleteCase(database: database, caseId: caseId);

      expect(await readCases(), isEmpty);
      expect(await readSymbols(), isEmpty);
      expect(await readArrows(), isEmpty);
    });

    test("setCaseUnderlay mints an asset and frames it, clearCaseUnderlay tombstones it", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      await floorPlanService.setCaseUnderlay(
        database: database,
        caseId: caseId,
        path: "/tmp/plan.jpg",
        xM: 1,
        yM: 2,
        widthM: 5,
        heightM: 4,
      );

      final withUnderlay = (await readCases()).single;
      expect(withUnderlay.underlayAssetId, isNotNull);
      expect(withUnderlay.underlayWidthM, 5);

      final assetId = withUnderlay.underlayAssetId!;

      await floorPlanService.clearCaseUnderlay(database: database, caseId: caseId);

      final cleared = (await readCases()).single;
      expect(cleared.underlayAssetId, isNull);
      expect(cleared.underlayWidthM, isNull);

      final asset = await (database.select(
        database.ocptAssetsTable,
      )..where((row) => row.id.equals(assetId))).getSingle();
      expect(asset.isDeleted, isTrue);
    });

    test(
      "updateUnderlayFrame re-frames the underlay without touching any asset row",
      () async {
        final sceneId = await seedScene();
        final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;
        await floorPlanService.setCaseUnderlay(
          database: database,
          caseId: caseId,
          path: "/tmp/plan.jpg",
          xM: 0,
          yM: 0,
          widthM: 4,
          heightM: 3,
        );
        final imported = (await readCases()).single;
        final assetId = imported.underlayAssetId!;
        final assetsBefore = await database.select(database.ocptAssetsTable).get();

        await floorPlanService.updateUnderlayFrame(
          database: database,
          caseId: caseId,
          xM: const Value(2),
          yM: const Value(-1),
          widthM: const Value(6),
          heightM: const Value(5),
        );

        final reframed = (await readCases()).single;
        expect(reframed.underlayAssetId, assetId);
        expect(reframed.underlayXM, 2);
        expect(reframed.underlayYM, -1);
        expect(reframed.underlayWidthM, 6);
        expect(reframed.underlayHeightM, 5);

        // No `assets` row was minted or tombstoned by this write: the very defect this method
        // exists to avoid (dragging the underlay must never churn the `assets` table).
        final assetsAfter = await database.select(database.ocptAssetsTable).get();
        expect(assetsAfter, hasLength(assetsBefore.length));
        expect(assetsAfter.single.id, assetsBefore.single.id);
        expect(assetsAfter.single.isDeleted, isFalse);
      },
    );

    test("updateUnderlayFrame is a no-op while the case carries no underlay", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      await floorPlanService.updateUnderlayFrame(
        database: database,
        caseId: caseId,
        xM: const Value(2),
        yM: const Value(2),
      );

      final row = (await readCases()).single;
      expect(row.underlayAssetId, isNull);
      expect(row.underlayXM, isNull);
      expect(await database.select(database.ocptAssetsTable).get(), isEmpty);
    });
  });

  group("placeSymbol — the scope invariant", () {
    test("accepts a sequence layer with no shotId", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      final symbolId = await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: null,
        layer: OcptFloorPlanLayer.furniture,
        xM: 0,
        yM: 0,
      );

      expect(symbolId, isNotNull);
    });

    test("accepts a shot layer with a shotId", () async {
      final sceneId = await seedScene();
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      final symbolId = await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.characters,
        xM: 0,
        yM: 0,
      );

      expect(symbolId, isNotNull);
    });

    test("rejects a sequence layer given a shotId", () async {
      final sceneId = await seedScene();
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          caseId: caseId,
          shotId: shotId,
          layer: OcptFloorPlanLayer.decor,
          xM: 0,
          yM: 0,
        ),
        throwsArgumentError,
      );
    });

    test("rejects a shot layer given no shotId", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          caseId: caseId,
          shotId: null,
          layer: OcptFloorPlanLayer.cameras,
          xM: 0,
          yM: 0,
        ),
        throwsArgumentError,
      );
    });

    test("a rejected write leaves nothing behind", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;

      await expectLater(
        () => floorPlanService.placeSymbol(
          database: database,
          caseId: caseId,
          shotId: null,
          layer: OcptFloorPlanLayer.lights,
          xM: 0,
          yM: 0,
        ),
        throwsArgumentError,
      );

      expect(await readSymbols(), isEmpty);
    });
  });

  group("updateSymbol", () {
    test("moves, rotates, resizes, sets fov and label without touching layer/shotId/caseId", () async {
      final sceneId = await seedScene();
      final caseId = (await floorPlanService.addCase(database: database, sceneId: sceneId))!;
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: null,
        layer: OcptFloorPlanLayer.furniture,
        xM: 0,
        yM: 0,
      ))!;

      await floorPlanService.updateSymbol(
        database: database,
        symbolId: symbolId,
        xM: const Value(2.5),
        yM: const Value(3.5),
        rotationDeg: const Value(90),
        widthM: const Value(1.1),
        heightM: const Value(0.6),
        label: const Value("sofa"),
      );

      final symbol = (await readSymbols()).single;
      expect(symbol.xM, 2.5);
      expect(symbol.yM, 3.5);
      expect(symbol.rotationDeg, 90);
      expect(symbol.widthM, 1.1);
      expect(symbol.heightM, 0.6);
      expect(symbol.label, "sofa");
      expect(symbol.caseId, caseId);
      expect(symbol.layer, OcptFloorPlanLayer.furniture);
      expect(symbol.shotId, isNull);
    });
  });

  group("deleteSymbol — the arrow cascade", () {
    test("tombstones every arrow whose fromSymbolId or toSymbolId names the removed symbol", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final caseId = (await floorPlanService.addCase(
        database: database,
        sceneId: sceneRow.sceneId!,
      ))!;

      final camera = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;
      final character = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.characters,
        xM: 1,
        yM: 1,
      ))!;
      final untouchedA = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.lights,
        xM: 2,
        yM: 2,
      ))!;
      final untouchedB = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.handProps,
        xM: 3,
        yM: 3,
      ))!;

      final arrowFrom = (await floorPlanService.addArrow(
        database: database,
        caseId: caseId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: character,
        toSymbolId: camera,
      ))!;
      final arrowTo = (await floorPlanService.addArrow(
        database: database,
        caseId: caseId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.cameraMove,
        fromSymbolId: camera,
        toSymbolId: character,
      ))!;
      final untouchedArrow = (await floorPlanService.addArrow(
        database: database,
        caseId: caseId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: untouchedA,
        toSymbolId: untouchedB,
      ))!;

      await floorPlanService.deleteSymbol(database: database, symbolId: camera);

      final liveArrowIds = (await readArrows()).map((row) => row.id).toSet();
      expect(liveArrowIds.contains(arrowFrom), isFalse);
      expect(liveArrowIds.contains(arrowTo), isFalse);
      expect(liveArrowIds.contains(untouchedArrow), isTrue);

      final liveSymbolIds = (await readSymbols()).map((row) => row.id).toSet();
      expect(liveSymbolIds.contains(camera), isFalse);
      expect(liveSymbolIds.contains(character), isTrue);
    });
  });

  group("arrow CRUD", () {
    test("setArrowLabel updates only the label, deleteArrow tombstones it", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final caseId = (await floorPlanService.addCase(
        database: database,
        sceneId: sceneRow.sceneId!,
      ))!;
      final a = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;
      final b = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.characters,
        xM: 1,
        yM: 1,
      ))!;
      final arrowId = (await floorPlanService.addArrow(
        database: database,
        caseId: caseId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: a,
        toSymbolId: b,
      ))!;

      await floorPlanService.setArrowLabel(database: database, arrowId: arrowId, label: "walks to");
      expect((await readArrows()).single.label, "walks to");

      await floorPlanService.deleteArrow(database: database, arrowId: arrowId);
      expect(await readArrows(), isEmpty);
    });
  });

  group("tombstoneFloorPlanRowsOfShot", () {
    test("tombstones the shot's own shot-layer symbols and arrows, leaving sequence layers alone", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final caseId = (await floorPlanService.addCase(
        database: database,
        sceneId: sceneRow.sceneId!,
      ))!;

      final decor = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: null,
        layer: OcptFloorPlanLayer.decor,
        xM: 0,
        yM: 0,
      ))!;
      final camera = (await floorPlanService.placeSymbol(
        database: database,
        caseId: caseId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      ))!;
      await floorPlanService.addArrow(
        database: database,
        caseId: caseId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.cameraMove,
        fromSymbolId: camera,
        toSymbolId: decor,
      );

      await database.transaction(() async {
        final stamps = await OcptRowStampService.seed(database: database, deviceId: _deviceId);
        await floorPlanService.tombstoneFloorPlanRowsOfShot(
          database: database,
          shotId: shotId,
          stamps: stamps,
        );
        await stamps.flush(database);
      });

      final liveSymbolIds = (await readSymbols()).map((row) => row.id).toSet();
      expect(liveSymbolIds.contains(camera), isFalse);
      expect(liveSymbolIds.contains(decor), isTrue);
      expect(await readArrows(), isEmpty);
    });
  });
}
