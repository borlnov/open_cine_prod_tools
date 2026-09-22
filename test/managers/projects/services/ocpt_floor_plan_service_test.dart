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
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
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

  Future<List<OcptFloorPlanSetRow>> readCases() => (database.select(
    database.ocptFloorPlanSetsTable,
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

      expect(snapshot.setsById, isEmpty);
    });

    test("groups live cases by scene, each carrying its own live symbols and arrows", () async {
      final sceneId = await seedScene();
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 1,
        yM: 1,
      ))!;

      final snapshot = await floorPlanService.loadFloorPlans(
        database: database,
        screenplayId: screenplayId,
      );

      final cases = snapshot.setsOfScene(sceneId);
      expect(cases, hasLength(1));
      expect(cases.single.id, setId);
      expect(cases.single.symbols.single.id, symbolId);
      expect(snapshot.setsById[setId], isNotNull);
    });

    test("names a fresh case after the scene heading's place", () async {
      final sceneId = await seedScene();
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      final row = (await readCases()).single;
      expect(row.id, setId);
      expect(row.name, "KITCHEN");
    });
  });

  group("case CRUD", () {
    test("addSet appends after the scene's current sets", () async {
      final sceneId = await seedScene();
      final firstId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final secondId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      final cases = await (database.select(database.ocptFloorPlanSetsTable)
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();
      expect(cases.map((row) => row.id), [firstId, secondId]);
    });

    test("renameSet changes only the name", () async {
      final sceneId = await seedScene();
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      await floorPlanService.renameSet(database: database, setId: setId, name: "Hallway");

      expect((await readCases()).single.name, "Hallway");
    });

    test("reorderSet moves a set by writing exactly one row", () async {
      final sceneId = await seedScene();
      final firstId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final secondId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      final before = {for (final row in await readCases()) row.id: row.sortKey};
      await floorPlanService.reorderSet(database: database, setId: secondId, newPosition: 0);
      final after = {for (final row in await readCases()) row.id: row.sortKey};

      expect(after[firstId], before[firstId]);
      expect(after[secondId], isNot(before[secondId]));
    });

    test("deleteSet tombstones the set, its symbols and its arrows", () async {
      final sceneId = await seedScene();
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final symbol1 = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;
      final symbol2 = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      ))!;
      await floorPlanService.addArrow(
        database: database,
        setId: setId,
        shotId: shotId!,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: symbol1,
        toSymbolId: symbol2,
      );

      await floorPlanService.deleteSet(database: database, setId: setId);

      expect(await readCases(), isEmpty);
      expect(await readSymbols(), isEmpty);
      expect(await readArrows(), isEmpty);
    });

    test("setSetUnderlay mints an asset and frames it, clearSetUnderlay tombstones it", () async {
      final sceneId = await seedScene();
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      await floorPlanService.setSetUnderlay(
        database: database,
        setId: setId,
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

      await floorPlanService.clearSetUnderlay(database: database, setId: setId);

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
        final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
        await floorPlanService.setSetUnderlay(
          database: database,
          setId: setId,
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
          setId: setId,
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
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      await floorPlanService.updateUnderlayFrame(
        database: database,
        setId: setId,
        xM: const Value(2),
        yM: const Value(2),
      );

      final row = (await readCases()).single;
      expect(row.underlayAssetId, isNull);
      expect(row.underlayXM, isNull);
      expect(await database.select(database.ocptAssetsTable).get(), isEmpty);
    });
  });

  group("duplicateSet", () {
    test("copies the set's own symbols and arrows as independent rows", () async {
      final sceneId = await seedScene();
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      final sourceSetId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final decor = (await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
        label: "Table",
      ))!;
      final camera = (await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      ))!;
      final arrowId = (await floorPlanService.addArrow(
        database: database,
        setId: sourceSetId,
        shotId: shotId!,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: decor,
        toSymbolId: camera,
      ))!;

      final newSetId = await floorPlanService.duplicateSet(database: database, setId: sourceSetId);

      expect(newSetId, isNotNull);
      expect(newSetId, isNot(sourceSetId));

      final newSetRow = (await readCases()).firstWhere((row) => row.id == newSetId);
      expect(newSetRow.sceneId, sceneId);
      expect(newSetRow.name, (await readCases()).firstWhere((row) => row.id == sourceSetId).name);
      expect(newSetRow.underlayAssetId, isNull);

      final newSymbols = (await readSymbols()).where((row) => row.setId == newSetId).toList();
      expect(newSymbols, hasLength(2));
      // Fresh ids, never the source's own.
      expect(newSymbols.map((row) => row.id), isNot(containsAll([decor, camera])));
      final newDecor = newSymbols.singleWhere((row) => row.layer == OcptFloorPlanLayer.set);
      final newCamera = newSymbols.singleWhere((row) => row.layer == OcptFloorPlanLayer.cameras);
      expect(newDecor.label, "Table");
      expect(newDecor.shotId, isNull);
      expect(newCamera.shotId, shotId);

      final newArrows = (await readArrows()).where((row) => row.setId == newSetId).toList();
      expect(newArrows, hasLength(1));
      expect(newArrows.single.id, isNot(arrowId));
      expect(newArrows.single.fromSymbolId, newDecor.id);
      expect(newArrows.single.toSymbolId, newCamera.id);

      // The source set is untouched: same count of symbols/arrows, same ids.
      final sourceSymbols = (await readSymbols()).where((row) => row.setId == sourceSetId);
      expect(sourceSymbols.map((row) => row.id).toSet(), {decor, camera});
      final sourceArrows = (await readArrows()).where((row) => row.setId == sourceSetId);
      expect(sourceArrows.single.id, arrowId);
    });

    test("mutating the copy never touches the source (independent copies, not links)", () async {
      final sceneId = await seedScene();
      final sourceSetId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final sourceSymbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;

      final newSetId = (await floorPlanService.duplicateSet(
        database: database,
        setId: sourceSetId,
      ))!;
      final copiedSymbolId = (await readSymbols())
          .firstWhere((row) => row.setId == newSetId)
          .id;

      await floorPlanService.updateSymbol(
        database: database,
        symbolId: copiedSymbolId,
        xM: const Value(9),
        yM: const Value(9),
      );
      await floorPlanService.deleteSet(database: database, setId: newSetId);

      final sourceSymbol = (await readSymbols()).singleWhere((row) => row.id == sourceSymbolId);
      expect(sourceSymbol.xM, 0);
      expect(sourceSymbol.yM, 0);
      final sourceSetRow = (await readCases()).singleWhere((row) => row.id == sourceSetId);
      expect(sourceSetRow.isDeleted, isFalse);
    });

    test("tombstones (symbols and arrows) of the source are not copied", () async {
      final sceneId = await seedScene();
      final sourceSetId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final liveId = (await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;
      final removedId = (await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 1,
        yM: 1,
      ))!;
      await floorPlanService.deleteSymbol(database: database, symbolId: removedId);

      final newSetId = await floorPlanService.duplicateSet(database: database, setId: sourceSetId);

      final newSymbols = (await readSymbols()).where((row) => row.setId == newSetId).toList();
      expect(newSymbols, hasLength(1));
      expect(newSymbols.single.xM, 0);
      expect(liveId, isNotEmpty); // sanity: the surviving source symbol id is still meaningful
    });

    test("returns null for a set that doesn't exist", () async {
      final result = await floorPlanService.duplicateSet(database: database, setId: "nope");
      expect(result, isNull);
    });
  });

  group("copyShotBlocking", () {
    test(
      "copies shot-scoped symbols and same-shot arrows onto the destination shot, as independent "
      "copies",
      () async {
        final sceneId = await seedScene();
        final sourceShotId = (await shotListService.createShot(
          database: database,
          screenplayId: screenplayId,
          sceneId: sceneId,
        ))!;
        final destinationShotId = (await shotListService.createShot(
          database: database,
          screenplayId: screenplayId,
          sceneId: sceneId,
        ))!;
        final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
        final sourceCamera = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: sourceShotId,
          layer: OcptFloorPlanLayer.cameras,
          xM: 0,
          yM: 0,
          label: "wide",
        ))!;
        final sourceCharacter = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: sourceShotId,
          layer: OcptFloorPlanLayer.characters,
          xM: 2,
          yM: 2,
          label: "SAM",
        ))!;
        final sourceArrowId = (await floorPlanService.addArrow(
          database: database,
          setId: setId,
          shotId: sourceShotId,
          kind: OcptFloorPlanArrowKind.movement,
          fromSymbolId: sourceCharacter,
          toSymbolId: sourceCamera,
        ))!;
        // A camera already on the destination shot, so the copy is proven to append after it
        // rather than colliding with (or replacing) it.
        final existingDestinationCamera = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: destinationShotId,
          layer: OcptFloorPlanLayer.cameras,
          xM: 5,
          yM: 5,
        ))!;

        await floorPlanService.copyShotBlocking(
          database: database,
          sourceSetId: setId,
          sourceShotId: sourceShotId,
          destinationSetId: setId,
          destinationShotId: destinationShotId,
        );

        final destinationSymbols = (await readSymbols())
            .where((row) => row.shotId == destinationShotId)
            .toList();
        // The pre-existing camera plus the two freshly copied symbols.
        expect(destinationSymbols, hasLength(3));
        final copiedCamera = destinationSymbols.singleWhere(
          (row) => row.layer == OcptFloorPlanLayer.cameras && row.id != existingDestinationCamera,
        );
        expect(copiedCamera.label, "wide");
        expect(copiedCamera.id, isNot(sourceCamera));
        final copiedCharacter = (await readSymbols()).singleWhere(
          (row) => row.shotId == destinationShotId && row.layer == OcptFloorPlanLayer.characters,
        );
        expect(copiedCharacter.label, "SAM");
        expect(copiedCharacter.id, isNot(sourceCharacter));
        // Distinct sortKeys: the copied camera is appended after the destination's own existing
        // one, not colliding with it.
        final existingRow = (await readSymbols()).singleWhere(
          (row) => row.id == existingDestinationCamera,
        );
        expect(copiedCamera.sortKey, isNot(existingRow.sortKey));

        final destinationArrows = (await readArrows())
            .where((row) => row.shotId == destinationShotId)
            .toList();
        expect(destinationArrows, hasLength(1));
        expect(destinationArrows.single.id, isNot(sourceArrowId));
        expect(destinationArrows.single.fromSymbolId, copiedCharacter.id);
        expect(destinationArrows.single.toSymbolId, copiedCamera.id);

        // The source shot's own rows are untouched.
        final sourceSymbolsAfter = (await readSymbols())
            .where((row) => row.shotId == sourceShotId)
            .toList();
        expect(sourceSymbolsAfter.map((row) => row.id).toSet(), {sourceCamera, sourceCharacter});
        final sourceArrowsAfter = (await readArrows())
            .where((row) => row.shotId == sourceShotId)
            .toList();
        expect(sourceArrowsAfter.single.id, sourceArrowId);
      },
    );

    test("mutating a copied symbol never touches the source symbol", () async {
      final sceneId = await seedScene();
      final sourceShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final destinationShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final sourceLightId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: sourceShotId,
        layer: OcptFloorPlanLayer.lights,
        xM: 0,
        yM: 0,
      ))!;

      await floorPlanService.copyShotBlocking(
        database: database,
        sourceSetId: setId,
        sourceShotId: sourceShotId,
        destinationSetId: setId,
        destinationShotId: destinationShotId,
      );
      final copiedLightId = (await readSymbols())
          .singleWhere((row) => row.shotId == destinationShotId)
          .id;

      await floorPlanService.updateSymbol(
        database: database,
        symbolId: copiedLightId,
        xM: const Value(7),
      );
      await floorPlanService.deleteSymbol(database: database, symbolId: copiedLightId);

      final sourceLight = (await readSymbols()).singleWhere((row) => row.id == sourceLightId);
      expect(sourceLight.xM, 0);
      expect(sourceLight.isDeleted, isFalse);
    });

    test(
      "an arrow touching a sequence-scoped (set) symbol is not copied",
      () async {
        final sceneId = await seedScene();
        final sourceShotId = (await shotListService.createShot(
          database: database,
          screenplayId: screenplayId,
          sceneId: sceneId,
        ))!;
        final destinationShotId = (await shotListService.createShot(
          database: database,
          screenplayId: screenplayId,
          sceneId: sceneId,
        ))!;
        final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
        final decor = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 0,
          yM: 0,
        ))!;
        final character = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: sourceShotId,
          layer: OcptFloorPlanLayer.characters,
          xM: 1,
          yM: 1,
        ))!;
        await floorPlanService.addArrow(
          database: database,
          setId: setId,
          shotId: sourceShotId,
          kind: OcptFloorPlanArrowKind.movement,
          fromSymbolId: character,
          toSymbolId: decor,
        );

        await floorPlanService.copyShotBlocking(
          database: database,
          sourceSetId: setId,
          sourceShotId: sourceShotId,
          destinationSetId: setId,
          destinationShotId: destinationShotId,
        );

        expect((await readArrows()).where((row) => row.shotId == destinationShotId), isEmpty);
        // The character symbol was still copied on its own.
        expect(
          (await readSymbols()).where(
            (row) => row.shotId == destinationShotId && row.layer == OcptFloorPlanLayer.characters,
          ),
          hasLength(1),
        );
      },
    );

    test("is a no-op while the source shot carries nothing on the set", () async {
      final sceneId = await seedScene();
      final sourceShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final destinationShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      await floorPlanService.copyShotBlocking(
        database: database,
        sourceSetId: setId,
        sourceShotId: sourceShotId,
        destinationSetId: setId,
        destinationShotId: destinationShotId,
      );

      expect(await readSymbols(), isEmpty);
      expect(await readArrows(), isEmpty);
    });
  });

  group("placeSymbol — the scope invariant", () {
    test("accepts a sequence layer with no shotId", () async {
      final sceneId = await seedScene();
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      final symbolId = await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
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
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      final symbolId = await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
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
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: shotId,
          layer: OcptFloorPlanLayer.set,
          xM: 0,
          yM: 0,
        ),
        throwsArgumentError,
      );
    });

    test("rejects a shot layer given no shotId", () async {
      final sceneId = await seedScene();
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
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
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

      await expectLater(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: null,
          layer: OcptFloorPlanLayer.lights,
          xM: 0,
          yM: 0,
        ),
        throwsArgumentError,
      );

      expect(await readSymbols(), isEmpty);
    });

    test(
      "records a set element's shape; a camera symbol placed alongside it stays null",
      () async {
        final sceneId = await seedScene();
        final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;

        final wallId = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 0,
          yM: 0,
          setElementShape: OcptFloorPlanSetElementShape.wall,
        ))!;

        final shotId = (await shotListService.createShot(
          database: database,
          screenplayId: screenplayId,
          sceneId: sceneId,
        ))!;
        final cameraId = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          shotId: shotId,
          layer: OcptFloorPlanLayer.cameras,
          xM: 1,
          yM: 1,
        ))!;

        final symbolsById = {for (final row in await readSymbols()) row.id: row};
        expect(symbolsById[wallId]!.setElementShape, OcptFloorPlanSetElementShape.wall);
        expect(symbolsById[wallId]!.shotId, isNull);
        expect(symbolsById[cameraId]!.setElementShape, isNull);
        expect(symbolsById[cameraId]!.shotId, shotId);
      },
    );
  });

  group("updateSymbol", () {
    test("moves, rotates, resizes, sets fov and label without touching layer/shotId/setId", () async {
      final sceneId = await seedScene();
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
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
      expect(symbol.setId, setId);
      expect(symbol.layer, OcptFloorPlanLayer.set);
      expect(symbol.shotId, isNull);
    });

    test("changes a set element's shape", () async {
      final sceneId = await seedScene();
      final setId = (await floorPlanService.addSet(database: database, sceneId: sceneId))!;
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
        setElementShape: OcptFloorPlanSetElementShape.wall,
      ))!;

      await floorPlanService.updateSymbol(
        database: database,
        symbolId: symbolId,
        setElementShape: const Value(OcptFloorPlanSetElementShape.door),
      );

      expect((await readSymbols()).single.setElementShape, OcptFloorPlanSetElementShape.door);
    });
  });

  group("deleteSymbol — the arrow cascade", () {
    test("tombstones every arrow whose fromSymbolId or toSymbolId names the removed symbol", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final setId = (await floorPlanService.addSet(
        database: database,
        sceneId: sceneRow.sceneId!,
      ))!;

      final camera = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;
      final character = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.characters,
        xM: 1,
        yM: 1,
      ))!;
      final untouchedA = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.lights,
        xM: 2,
        yM: 2,
      ))!;
      final untouchedB = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.props,
        xM: 3,
        yM: 3,
      ))!;

      final arrowFrom = (await floorPlanService.addArrow(
        database: database,
        setId: setId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: character,
        toSymbolId: camera,
      ))!;
      final arrowTo = (await floorPlanService.addArrow(
        database: database,
        setId: setId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.cameraMove,
        fromSymbolId: camera,
        toSymbolId: character,
      ))!;
      final untouchedArrow = (await floorPlanService.addArrow(
        database: database,
        setId: setId,
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
      final setId = (await floorPlanService.addSet(
        database: database,
        sceneId: sceneRow.sceneId!,
      ))!;
      final a = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;
      final b = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.characters,
        xM: 1,
        yM: 1,
      ))!;
      final arrowId = (await floorPlanService.addArrow(
        database: database,
        setId: setId,
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

  group("updateArrowCurve", () {
    test("sets and clears the control point, each through a single row write", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final setId = (await floorPlanService.addSet(
        database: database,
        sceneId: sceneRow.sceneId!,
      ))!;
      final a = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;
      final b = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.characters,
        xM: 1,
        yM: 1,
      ))!;
      final arrowId = (await floorPlanService.addArrow(
        database: database,
        setId: setId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: a,
        toSymbolId: b,
      ))!;

      await floorPlanService.updateArrowCurve(
        database: database,
        arrowId: arrowId,
        ctrlXM: const Value(0.5),
        ctrlYM: const Value(0.75),
      );
      final curved = (await readArrows()).single;
      expect(curved.ctrlXM, 0.5);
      expect(curved.ctrlYM, 0.75);
      expect(curved.label, ""); // untouched

      await floorPlanService.updateArrowCurve(
        database: database,
        arrowId: arrowId,
        ctrlXM: const Value(null),
        ctrlYM: const Value(null),
      );
      final straightened = (await readArrows()).single;
      expect(straightened.ctrlXM, isNull);
      expect(straightened.ctrlYM, isNull);
    });
  });

  group("tombstoneFloorPlanRowsOfShot", () {
    test("tombstones the shot's own shot-layer symbols and arrows, leaving sequence layers alone", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final setId = (await floorPlanService.addSet(
        database: database,
        sceneId: sceneRow.sceneId!,
      ))!;

      final decor = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;
      final camera = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      ))!;
      await floorPlanService.addArrow(
        database: database,
        setId: setId,
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
