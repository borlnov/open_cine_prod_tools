// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
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
    floorPlanService: floorPlanService,
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

  /// Saves a screenplay of [count] one-line scenes and returns their ids, in source order.
  Future<List<String>> seedScenes(int count) async {
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      buffer
        ..writeln("INT. LOCATION $i - DAY")
        ..writeln()
        ..writeln("Action.")
        ..writeln();
    }
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: buffer.toString(),
      snapshotReason: OcptSnapshotReason.manual,
    );
    final rows =
        await (database.select(
              database.ocptScenesTable,
            )..where((row) => row.isDeleted.equals(false)))
            .get();
    rows.sort((a, b) => a.position.compareTo(b.position));
    return rows.map((row) => row.id).toList();
  }

  /// Saves a one-scene screenplay and returns its scene id.
  Future<String> seedScene() async => (await seedScenes(1)).single;

  /// Saves a scene and creates a shot on it, returning the shot id.
  Future<String> seedShot() async {
    final sceneId = await seedScene();
    return (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: sceneId,
    ))!;
  }

  /// Creates a fresh Resources set linked to scene [sceneId] (a fresh one of its own if omitted),
  /// through `OcptLocationsService.createSetLinkedToScene` — the floor plan service no longer
  /// mints a set of its own or owns its tab: a sequence's tabs are its live `scene_sets` links.
  /// Returns `(sceneId, setId)`.
  Future<(String, String)> seedLinkedSet({String? sceneId, String name = "Kitchen"}) async {
    final resolvedSceneId = sceneId ?? await seedScene();
    final setId = (await locationsService.createSetLinkedToScene(
      database: database,
      sceneId: resolvedSceneId,
      name: name,
    ))!;
    return (resolvedSceneId, setId);
  }

  Future<List<OcptFloorPlanSetRow>> readPlans() =>
      (database.select(
            database.ocptFloorPlanSetsTable,
          )..where((row) => row.isDeleted.equals(false)))
          .get();

  Future<List<OcptFloorPlanSymbolRow>> readSymbols() => (database.select(
    database.ocptFloorPlanSymbolsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptFloorPlanArrowRow>> readArrows() => (database.select(
    database.ocptFloorPlanArrowsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  group("loadFloorPlans", () {
    test("returns an empty snapshot for a screenplay with no linked sets", () async {
      final snapshot = await floorPlanService.loadFloorPlans(
        database: database,
        screenplayId: screenplayId,
      );

      expect(snapshot.setsById, isEmpty);
    });

    test("groups a linked set under its scene, carrying its own live symbols and arrows", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 1,
        yM: 1,
      ))!;

      final snapshot = await floorPlanService.loadFloorPlans(
        database: database,
        screenplayId: screenplayId,
      );

      final tabs = snapshot.setsOfScene(sceneId);
      expect(tabs, hasLength(1));
      expect(tabs.single.id, setId);
      expect(tabs.single.name, "Kitchen");
      expect(tabs.single.symbols.single.id, symbolId);
      expect(snapshot.setsById[setId], isNotNull);
    });

    test("a set linked to two scenes shows the same set-scope symbols in both", () async {
      final scenes = await seedScenes(2);
      final (_, setId) = await seedLinkedSet(sceneId: scenes[0]);
      await locationsService.assignSceneToSet(
        database: database,
        sceneId: scenes[1],
        setId: setId,
      );
      await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
        label: "Counter",
      );

      final snapshot = await floorPlanService.loadFloorPlans(
        database: database,
        screenplayId: screenplayId,
      );

      final firstTab = snapshot.setsOfScene(scenes[0]).single;
      final secondTab = snapshot.setsOfScene(scenes[1]).single;
      expect(firstTab.id, setId);
      expect(secondTab.id, setId);
      expect(firstTab.symbols.single.label, "Counter");
      expect(secondTab.symbols.single.label, "Counter");
    });

    test("a scene-scope symbol is loaded regardless of which scene reads the set", () async {
      final scenes = await seedScenes(2);
      final (_, setId) = await seedLinkedSet(sceneId: scenes[0]);
      await locationsService.assignSceneToSet(
        database: database,
        sceneId: scenes[1],
        setId: setId,
      );
      await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: scenes[0],
        shotId: null,
        layer: OcptFloorPlanLayer.props,
        xM: 0,
        yM: 0,
        label: "Only scene 0's own prop",
      );

      final snapshot = await floorPlanService.loadFloorPlans(
        database: database,
        screenplayId: screenplayId,
      );

      // The store carries every scope on the one shared row; narrowing a scene-scope symbol down
      // to its own sequence is `OcptFloorPlanSheet.of`'s job (tested in
      // `ocpt_floor_plan_sheet_test.dart`), not the loader's.
      expect(snapshot.setsById[setId]!.symbols.single.sceneId, scenes[0]);
    });

    test("a linked set with no plan yet reads as an empty plan", () async {
      final (sceneId, setId) = await seedLinkedSet();

      final snapshot = await floorPlanService.loadFloorPlans(
        database: database,
        screenplayId: screenplayId,
      );

      final tab = snapshot.setsOfScene(sceneId).single;
      expect(tab.id, setId);
      expect(tab.symbols, isEmpty);
      expect(tab.underlayAssetId, isNull);
      expect(await readPlans(), isEmpty, reason: "no plan row was ever created for it");
    });
  });

  group("ensurePlan (lazy creation)", () {
    test("placeSymbol creates the plan row, id equal to the set id, idempotently", () async {
      final (_, setId) = await seedLinkedSet();

      await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      );
      await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 1,
        yM: 1,
      );

      final plans = await readPlans();
      expect(plans, hasLength(1));
      expect(plans.single.id, setId);
    });

    test("setSetUnderlay mints an asset and frames it, clearSetUnderlay tombstones it", () async {
      final (_, setId) = await seedLinkedSet();

      await floorPlanService.setSetUnderlay(
        database: database,
        setId: setId,
        path: "/tmp/plan.jpg",
        xM: 1,
        yM: 2,
        widthM: 5,
        heightM: 4,
      );

      final withUnderlay = (await readPlans()).single;
      expect(withUnderlay.id, setId);
      expect(withUnderlay.underlayAssetId, isNotNull);
      expect(withUnderlay.underlayWidthM, 5);

      final assetId = withUnderlay.underlayAssetId!;

      await floorPlanService.clearSetUnderlay(database: database, setId: setId);

      final cleared = (await readPlans()).single;
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
        final (_, setId) = await seedLinkedSet();
        await floorPlanService.setSetUnderlay(
          database: database,
          setId: setId,
          path: "/tmp/plan.jpg",
          xM: 0,
          yM: 0,
          widthM: 4,
          heightM: 3,
        );
        final imported = (await readPlans()).single;
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

        final reframed = (await readPlans()).single;
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

    test("updateUnderlayFrame is a no-op while the set carries no plan yet", () async {
      final (_, setId) = await seedLinkedSet();

      await floorPlanService.updateUnderlayFrame(
        database: database,
        setId: setId,
        xM: const Value(2),
        yM: const Value(2),
      );

      expect(await readPlans(), isEmpty);
      expect(await database.select(database.ocptAssetsTable).get(), isEmpty);
    });
  });

  group("tombstoneFloorPlanRowsOfSet", () {
    test("tombstones the plan row, its symbols and its arrows", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

      final decor = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;
      final camera = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      ))!;
      await floorPlanService.addArrow(
        database: database,
        setId: setId,
        shotId: shotId,
        kind: OcptFloorPlanArrowKind.movement,
        fromSymbolId: decor,
        toSymbolId: camera,
      );

      await database.transaction(() async {
        final stamps = await OcptRowStampService.seed(database: database, deviceId: _deviceId);
        await floorPlanService.tombstoneFloorPlanRowsOfSet(
          database: database,
          setId: setId,
          stamps: stamps,
        );
        await stamps.flush(database);
      });

      expect(await readPlans(), isEmpty);
      expect(await readSymbols(), isEmpty);
      expect(await readArrows(), isEmpty);
    });

    test("is a no-op while the set carries no plan yet", () async {
      final (_, setId) = await seedLinkedSet();

      await database.transaction(() async {
        final stamps = await OcptRowStampService.seed(database: database, deviceId: _deviceId);
        await floorPlanService.tombstoneFloorPlanRowsOfSet(
          database: database,
          setId: setId,
          stamps: stamps,
        );
        await stamps.flush(database);
      });

      expect(await readPlans(), isEmpty);
    });
  });

  group("duplicateSet", () {
    test("copies the source's set-scope symbols only, into an already-minted destination", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (sceneId, sourceSetId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final decor = (await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
        label: "Table",
      ))!;
      // A scene-scope prop and a shot-scope camera, neither of which travels with the copy.
      await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        sceneId: sceneId,
        shotId: null,
        layer: OcptFloorPlanLayer.props,
        xM: 2,
        yM: 2,
      );
      await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      );

      final destinationSetId = (await locationsService.createSiblingSet(
        database: database,
        sourceSetId: sourceSetId,
        name: "Kitchen copy",
      ))!;

      await floorPlanService.duplicateSet(
        database: database,
        sourceSetId: sourceSetId,
        destinationSetId: destinationSetId,
      );

      final newSymbols = (await readSymbols())
          .where((row) => row.setId == destinationSetId)
          .toList();
      expect(newSymbols, hasLength(1));
      expect(newSymbols.single.id, isNot(decor));
      expect(newSymbols.single.label, "Table");
      expect(newSymbols.single.sceneId, isNull);
      expect(newSymbols.single.shotId, isNull);

      // The source set is untouched.
      final sourceSymbols = (await readSymbols()).where((row) => row.setId == sourceSetId);
      expect(sourceSymbols, hasLength(3));
    });

    test("mutating the copy never touches the source (independent copies, not links)", () async {
      final (_, sourceSetId) = await seedLinkedSet();
      final sourceSymbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;
      final destinationSetId = (await locationsService.createSiblingSet(
        database: database,
        sourceSetId: sourceSetId,
        name: "Copy",
      ))!;

      await floorPlanService.duplicateSet(
        database: database,
        sourceSetId: sourceSetId,
        destinationSetId: destinationSetId,
      );
      final copiedSymbolId = (await readSymbols())
          .firstWhere((row) => row.setId == destinationSetId)
          .id;

      await floorPlanService.updateSymbol(
        database: database,
        symbolId: copiedSymbolId,
        xM: const Value(9),
        yM: const Value(9),
      );

      final sourceSymbol = (await readSymbols()).singleWhere((row) => row.id == sourceSymbolId);
      expect(sourceSymbol.xM, 0);
      expect(sourceSymbol.yM, 0);
    });

    test("a tombstoned set-scope symbol of the source is not copied", () async {
      final (_, sourceSetId) = await seedLinkedSet();
      await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      );
      final removedId = (await floorPlanService.placeSymbol(
        database: database,
        setId: sourceSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 1,
        yM: 1,
      ))!;
      await floorPlanService.deleteSymbol(database: database, symbolId: removedId);

      final destinationSetId = (await locationsService.createSiblingSet(
        database: database,
        sourceSetId: sourceSetId,
        name: "Copy",
      ))!;
      await floorPlanService.duplicateSet(
        database: database,
        sourceSetId: sourceSetId,
        destinationSetId: destinationSetId,
      );

      final newSymbols = (await readSymbols())
          .where((row) => row.setId == destinationSetId)
          .toList();
      expect(newSymbols, hasLength(1));
      expect(newSymbols.single.xM, 0);
    });

    test("is a no-op while the source carries no set-scope symbol at all", () async {
      final (_, sourceSetId) = await seedLinkedSet();
      final destinationSetId = (await locationsService.createSiblingSet(
        database: database,
        sourceSetId: sourceSetId,
        name: "Copy",
      ))!;

      await floorPlanService.duplicateSet(
        database: database,
        sourceSetId: sourceSetId,
        destinationSetId: destinationSetId,
      );

      expect(await readPlans(), isEmpty, reason: "nothing to copy, so no plan was ever minted");
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
        final (_, setId) = await seedLinkedSet(sceneId: sceneId);
        final sourceCamera = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: sourceShotId,
          layer: OcptFloorPlanLayer.cameras,
          xM: 0,
          yM: 0,
          label: "wide",
          fovReachM: 6,
        ))!;
        final sourceCharacter = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
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
          sceneId: null,
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
        expect(copiedCamera.fovReachM, 6);
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
      final (_, setId) = await seedLinkedSet(sceneId: sceneId);
      final sourceLightId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
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
      "an arrow touching a set-scope symbol is not copied",
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
        final (_, setId) = await seedLinkedSet(sceneId: sceneId);
        final decor = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 0,
          yM: 0,
        ))!;
        final character = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
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
      final (_, setId) = await seedLinkedSet(sceneId: sceneId);

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
    test("a set layer accepts set scope (no sceneId, no shotId)", () async {
      final (_, setId) = await seedLinkedSet();

      final symbolId = await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      );

      expect(symbolId, isNotNull);
    });

    test("a set layer accepts scene scope (sceneId, no shotId)", () async {
      final (sceneId, setId) = await seedLinkedSet();

      final symbolId = await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: sceneId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      );

      expect(symbolId, isNotNull);
    });

    test("a set layer rejects shot scope", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: shotId,
          layer: OcptFloorPlanLayer.set,
          xM: 0,
          yM: 0,
        ),
        throwsArgumentError,
      );
    });

    for (final layer in [
      OcptFloorPlanLayer.cameras,
      OcptFloorPlanLayer.characters,
      OcptFloorPlanLayer.lights,
    ]) {
      test("$layer accepts shot scope only", () async {
        final shotId = await seedShot();
        final sceneRow = await (database.select(
          database.ocptShotsTable,
        )..where((row) => row.id.equals(shotId))).getSingle();
        final (sceneId, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

        final symbolId = await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: shotId,
          layer: layer,
          xM: 0,
          yM: 0,
        );
        expect(symbolId, isNotNull);

        expect(
          () => floorPlanService.placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: layer,
            xM: 0,
            yM: 0,
          ),
          throwsArgumentError,
        );
        expect(
          () => floorPlanService.placeSymbol(
            database: database,
            setId: setId,
            sceneId: sceneId,
            shotId: null,
            layer: layer,
            xM: 0,
            yM: 0,
          ),
          throwsArgumentError,
        );
      });
    }

    test("props accepts scene scope or shot scope, but not set scope", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (sceneId, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

      expect(
        await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: sceneId,
          shotId: null,
          layer: OcptFloorPlanLayer.props,
          xM: 0,
          yM: 0,
        ),
        isNotNull,
      );
      expect(
        await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: shotId,
          layer: OcptFloorPlanLayer.props,
          xM: 1,
          yM: 1,
        ),
        isNotNull,
      );
      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.props,
          xM: 2,
          yM: 2,
        ),
        throwsArgumentError,
      );
    });

    test("a rejected write leaves nothing behind", () async {
      final (_, setId) = await seedLinkedSet();

      await expectLater(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.lights,
          xM: 0,
          yM: 0,
        ),
        throwsArgumentError,
      );

      expect(await readSymbols(), isEmpty);
      expect(await readPlans(), isEmpty);
    });

    test(
      "records a set element's shape; a camera symbol placed alongside it stays null",
      () async {
        final (sceneId, setId) = await seedLinkedSet();

        final wallId = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
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
          sceneId: null,
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

  group("placeSymbol — overridesSymbolId (scene-scope override)", () {
    test("a scene-scope symbol may override a live set-scope symbol of the same set/layer", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final originalId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;

      final overrideId = await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: sceneId,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 1,
        yM: 1,
        overridesSymbolId: originalId,
      );

      expect(overrideId, isNotNull);
      final overrideRow = (await readSymbols()).singleWhere((row) => row.id == overrideId);
      expect(overrideRow.overridesSymbolId, originalId);
    });

    test("overridesSymbolId on a set-scope or shot-scope symbol throws", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final originalId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 1,
          yM: 1,
          overridesSymbolId: originalId,
        ),
        throwsArgumentError,
      );
    });

    test("overridesSymbolId naming a non-existent symbol throws", () async {
      final (sceneId, setId) = await seedLinkedSet();

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: sceneId,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 0,
          yM: 0,
          overridesSymbolId: "nope",
        ),
        throwsArgumentError,
      );
    });

    test("overridesSymbolId naming a symbol of a different layer throws", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (sceneId, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final cameraId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: sceneId,
          shotId: null,
          layer: OcptFloorPlanLayer.props,
          xM: 1,
          yM: 1,
          overridesSymbolId: cameraId,
        ),
        throwsArgumentError,
      );
    });

    test("overridesSymbolId naming a symbol of a different set throws", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final (_, otherSetId) = await seedLinkedSet(name: "Hallway");
      final otherOriginalId = (await floorPlanService.placeSymbol(
        database: database,
        setId: otherSetId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;

      expect(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: sceneId,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 1,
          yM: 1,
          overridesSymbolId: otherOriginalId,
        ),
        throwsArgumentError,
      );
    });
  });

  group("updateSymbol", () {
    test("moves, rotates, resizes, sets fov and label without touching layer/scope/setId", () async {
      final (_, setId) = await seedLinkedSet();
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
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
      expect(symbol.sceneId, isNull);
      expect(symbol.shotId, isNull);
    });

    test("changes a set element's shape", () async {
      final (_, setId) = await seedLinkedSet();
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
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

    test("sets and changes a camera's own field-of-view reach", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final symbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
        fovReachM: 3.5,
      ))!;

      expect((await readSymbols()).single.fovReachM, 3.5);

      await floorPlanService.updateSymbol(
        database: database,
        symbolId: symbolId,
        fovReachM: const Value(5),
      );

      expect((await readSymbols()).single.fovReachM, 5);
    });
  });

  group("deleteSymbol — the arrow cascade", () {
    test("tombstones every arrow whose fromSymbolId or toSymbolId names the removed symbol", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

      final camera = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;
      final character = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.characters,
        xM: 1,
        yM: 1,
      ))!;
      final untouchedA = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.lights,
        xM: 2,
        yM: 2,
      ))!;
      final untouchedB = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
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
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final a = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;
      final b = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
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
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final a = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: shotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 0,
        yM: 0,
      ))!;
      final b = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
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
    test(
      "tombstones the shot's own shot-layer symbols and arrows, leaving set/scene layers alone",
      () async {
        final shotId = await seedShot();
        final sceneRow = await (database.select(
          database.ocptShotsTable,
        )..where((row) => row.id.equals(shotId))).getSingle();
        final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

        final decor = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.set,
          xM: 0,
          yM: 0,
        ))!;
        final camera = (await floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
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
      },
    );
  });
}
