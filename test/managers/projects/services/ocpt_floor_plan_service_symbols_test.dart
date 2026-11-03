// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_test_utility/act_test_utility.dart';
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
import '../../../ocpt_result_expectations.dart';
import 'ocpt_floor_plan_service_test_doubles.dart';

/// Run the tests of the floor plan service symbols.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const assetsService = OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId);

  const floorPlanService = OcptFloorPlanService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  const elementsService = OcptElementsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  const locationsService = OcptLocationsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    floorPlanService: floorPlanService,
    deviceId: testDeviceId,
  );

  const roleIndexService = OcptRoleIndexService(
    logger: SilentLogger(),
    elementsService: elementsService,
    roleCandidatesService: OcptRoleCandidatesService(
      logger: SilentLogger(),
      deviceId: testDeviceId,
    ),
    deviceId: testDeviceId,
  );

  const shotListService = OcptShotListService(
    logger: SilentLogger(),
    roleIndexService: roleIndexService,
    storyboardService: OcptStoryboardService(
      logger: SilentLogger(),
      assetsService: assetsService,
      deviceId: testDeviceId,
    ),
    floorPlanService: floorPlanService,
    deviceId: testDeviceId,
  );

  const screenplayService = OcptScreenplayService(
    logger: SilentLogger(),
    sceneIndexService: OcptSceneIndexService(logger: SilentLogger()),
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(logger: SilentLogger(), deviceId: testDeviceId),
    roleIndexService: roleIndexService,
    breakdownService: OcptBreakdownService(
      logger: SilentLogger(),
      elementsService: elementsService,
      locationsService: locationsService,
      deviceId: testDeviceId,
    ),
    scheduleService: OcptScheduleService(logger: SilentLogger(), deviceId: testDeviceId),
    deviceId: testDeviceId,
  );

  const screenplayId = "screenplay-1";

  late OcptProjectDatabase database;

  /// Every row of the tables a placement writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in ["floor_plan_sets", "floor_plan_symbols", "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Expect [call] to answer a database error, having written nothing: a call that breaks the
  /// scope rules is refused rather than raised.
  Future<void> expectRefused<T extends MixinResultStatus>(
    Future<StatusWithExtraInfo<T>> Function() call,
  ) async {
    final before = await snapshot();

    final answer = await call();

    expect(answer.isError, isTrue);
    expect(await snapshot(), before);
  }

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
    final rows = await (database.select(
      database.ocptScenesTable,
    )..where((row) => row.isDeleted.equals(false))).get();
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
    final setId = (await locationsService
        .createSetLinkedToScene(database: database, sceneId: resolvedSceneId, name: name)
        .valueOrFail);
    return (resolvedSceneId, setId);
  }

  Future<List<OcptFloorPlanSetRow>> readPlans() => (database.select(
    database.ocptFloorPlanSetsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptFloorPlanSymbolRow>> readSymbols() => (database.select(
    database.ocptFloorPlanSymbolsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptFloorPlanArrowRow>> readArrows() => (database.select(
    database.ocptFloorPlanArrowsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  group("placeSymbol — the scope invariant", () {
    test("a set layer accepts set scope (no sceneId, no shotId)", () async {
      final (_, setId) = await seedLinkedSet();

      final symbolId = await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
          )
          .maybeValueOrFail;

      expect(symbolId, isNotNull);
    });

    test("a set layer accepts scene scope (sceneId, no shotId)", () async {
      final (sceneId, setId) = await seedLinkedSet();

      final symbolId = await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: sceneId,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
          )
          .maybeValueOrFail;

      expect(symbolId, isNotNull);
    });

    test("a set layer rejects shot scope", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

      await expectRefused(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: shotId,
          layer: OcptFloorPlanLayer.set,
          xM: 0,
          yM: 0,
        ),
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

        final symbolId = await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: null,
              shotId: shotId,
              layer: layer,
              xM: 0,
              yM: 0,
            )
            .maybeValueOrFail;
        expect(symbolId, isNotNull);

        await expectRefused(
          () => floorPlanService.placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: layer,
            xM: 0,
            yM: 0,
          ),
        );
        await expectRefused(
          () => floorPlanService.placeSymbol(
            database: database,
            setId: setId,
            sceneId: sceneId,
            shotId: null,
            layer: layer,
            xM: 0,
            yM: 0,
          ),
        );
      });
    }

    test("props accepts scene scope only, never set scope nor shot scope", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (sceneId, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

      expect(
        await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: sceneId,
              shotId: null,
              layer: OcptFloorPlanLayer.props,
              xM: 0,
              yM: 0,
            )
            .maybeValueOrFail,
        isNotNull,
      );
      await expectRefused(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: shotId,
          layer: OcptFloorPlanLayer.props,
          xM: 1,
          yM: 1,
        ),
      );
      await expectRefused(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.props,
          xM: 2,
          yM: 2,
        ),
      );
    });

    test("a rejected write leaves nothing behind", () async {
      final (_, setId) = await seedLinkedSet();

      await expectRefused(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: null,
          layer: OcptFloorPlanLayer.lights,
          xM: 0,
          yM: 0,
        ),
      );

      expect(await readSymbols(), isEmpty);
      expect(await readPlans(), isEmpty);
    });

    test("records a set element's shape; a camera symbol placed alongside it stays null", () async {
      final (sceneId, setId) = await seedLinkedSet();

      final wallId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
            setElementShape: OcptFloorPlanSetElementShape.wall,
          )
          .valueOrFail);

      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final cameraId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: shotId,
            layer: OcptFloorPlanLayer.cameras,
            xM: 1,
            yM: 1,
          )
          .valueOrFail);

      final symbolsById = {for (final row in await readSymbols()) row.id: row};
      expect(symbolsById[wallId]!.setElementShape, OcptFloorPlanSetElementShape.wall);
      expect(symbolsById[wallId]!.shotId, isNull);
      expect(symbolsById[cameraId]!.setElementShape, isNull);
      expect(symbolsById[cameraId]!.shotId, shotId);
    });
  });

  group("placeSymbol — overridesSymbolId (scene-scope override)", () {
    test(
      "a scene-scope symbol may override a live set-scope symbol of the same set/layer",
      () async {
        final (sceneId, setId) = await seedLinkedSet();
        final originalId = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: null,
              shotId: null,
              layer: OcptFloorPlanLayer.set,
              xM: 0,
              yM: 0,
            )
            .valueOrFail);

        final overrideId = await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: sceneId,
              shotId: null,
              layer: OcptFloorPlanLayer.set,
              xM: 1,
              yM: 1,
              overridesSymbolId: originalId,
            )
            .maybeValueOrFail;

        expect(overrideId, isNotNull);
        final overrideRow = (await readSymbols()).singleWhere((row) => row.id == overrideId);
        expect(overrideRow.overridesSymbolId, originalId);
      },
    );

    test("overridesSymbolId on a set-scope or shot-scope symbol throws", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final originalId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
          )
          .valueOrFail);

      await expectRefused(
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
      );
    });

    test("overridesSymbolId naming a non-existent symbol throws", () async {
      final (sceneId, setId) = await seedLinkedSet();

      await expectRefused(
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
      );
    });

    test("overridesSymbolId naming a symbol of a different layer throws", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (sceneId, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final cameraId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: shotId,
            layer: OcptFloorPlanLayer.cameras,
            xM: 0,
            yM: 0,
          )
          .valueOrFail);

      await expectRefused(
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
      );
    });

    test("overridesSymbolId naming a symbol of a different set throws", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final (_, otherSetId) = await seedLinkedSet(name: "Hallway");
      final otherOriginalId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: otherSetId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
          )
          .valueOrFail);

      await expectRefused(
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
      );
    });
  });

  group("placeSymbol — shot-scope override", () {
    test("a shot-scope set symbol may override a live scene-scope symbol of the same set/layer, "
        "its shot belonging to that symbol's own sequence", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final sceneOriginalId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: sceneId,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
          )
          .valueOrFail);
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      final overrideId = await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: shotId,
            layer: OcptFloorPlanLayer.set,
            xM: 1,
            yM: 1,
            overridesSymbolId: sceneOriginalId,
          )
          .maybeValueOrFail;

      expect(overrideId, isNotNull);
      final overrideRow = (await readSymbols()).singleWhere((row) => row.id == overrideId);
      expect(overrideRow.overridesSymbolId, sceneOriginalId);
      expect(overrideRow.shotId, shotId);
      expect(overrideRow.sceneId, isNull);
    });

    test("a shot-scope props symbol may likewise override a live scene-scope prop", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final propId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: sceneId,
            shotId: null,
            layer: OcptFloorPlanLayer.props,
            xM: 0,
            yM: 0,
            label: "Candle",
          )
          .valueOrFail);
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      final overrideId = await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: shotId,
            layer: OcptFloorPlanLayer.props,
            xM: 2,
            yM: 2,
            overridesSymbolId: propId,
          )
          .maybeValueOrFail;

      expect(overrideId, isNotNull);
    });

    for (final layer in [OcptFloorPlanLayer.set, OcptFloorPlanLayer.props]) {
      test("a non-override shot-scope $layer symbol still throws", () async {
        final shotId = await seedShot();

        await expectRefused(
          () => floorPlanService.placeSymbol(
            database: database,
            setId: "does-not-matter",
            sceneId: null,
            shotId: shotId,
            layer: layer,
            xM: 0,
            yM: 0,
          ),
        );
      });
    }

    test("overridesSymbolId at shot scope must name a live scene-scope symbol, never a set-scope "
        "one", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final setOriginalId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
          )
          .valueOrFail);
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      await expectRefused(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: shotId,
          layer: OcptFloorPlanLayer.set,
          xM: 1,
          yM: 1,
          overridesSymbolId: setOriginalId,
        ),
      );
    });

    test("the shot must belong to the overridden scene-scope symbol's own sequence", () async {
      final scenes = await seedScenes(2);
      final (_, setId) = await seedLinkedSet(sceneId: scenes[0]);
      await locationsService
          .assignSceneToSet(database: database, sceneId: scenes[1], setId: setId)
          .maybeValueOrFail;

      final sceneOriginalId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: scenes[0],
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
          )
          .valueOrFail);
      final otherSequenceShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes[1],
      ))!;

      await expectRefused(
        () => floorPlanService.placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: otherSequenceShotId,
          layer: OcptFloorPlanLayer.set,
          xM: 1,
          yM: 1,
          overridesSymbolId: sceneOriginalId,
        ),
      );
    });
  });

  group("updateSymbol", () {
    test(
      "moves, rotates, resizes, sets fov and label without touching layer/scope/setId",
      () async {
        final (_, setId) = await seedLinkedSet();
        final symbolId = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: null,
              shotId: null,
              layer: OcptFloorPlanLayer.set,
              xM: 0,
              yM: 0,
            )
            .valueOrFail);

        await floorPlanService
            .updateSymbol(
              database: database,
              symbolId: symbolId,
              xM: const Value(2.5),
              yM: const Value(3.5),
              rotationDeg: const Value(90),
              widthM: const Value(1.1),
              heightM: const Value(0.6),
              label: const Value("sofa"),
            )
            .okOrFail;

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
      },
    );

    test("changes a set element's shape", () async {
      final (_, setId) = await seedLinkedSet();
      final symbolId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
            setElementShape: OcptFloorPlanSetElementShape.wall,
          )
          .valueOrFail);

      await floorPlanService
          .updateSymbol(
            database: database,
            symbolId: symbolId,
            setElementShape: const Value(OcptFloorPlanSetElementShape.door),
          )
          .okOrFail;

      expect((await readSymbols()).single.setElementShape, OcptFloorPlanSetElementShape.door);
    });

    test("sets and changes a camera's own field-of-view reach", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final symbolId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: shotId,
            layer: OcptFloorPlanLayer.cameras,
            xM: 0,
            yM: 0,
            fovReachM: 3.5,
          )
          .valueOrFail);

      expect((await readSymbols()).single.fovReachM, 3.5);

      await floorPlanService
          .updateSymbol(database: database, symbolId: symbolId, fovReachM: const Value(5))
          .okOrFail;

      expect((await readSymbols()).single.fovReachM, 5);
    });
  });

  group("deleteSymbol — the arrow cascade", () {
    test(
      "tombstones every arrow whose fromSymbolId or toSymbolId names the removed symbol",
      () async {
        final shotId = await seedShot();
        final sceneRow = await (database.select(
          database.ocptShotsTable,
        )..where((row) => row.id.equals(shotId))).getSingle();
        final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);

        final camera = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: null,
              shotId: shotId,
              layer: OcptFloorPlanLayer.cameras,
              xM: 0,
              yM: 0,
            )
            .valueOrFail);
        final character = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: null,
              shotId: shotId,
              layer: OcptFloorPlanLayer.characters,
              xM: 1,
              yM: 1,
            )
            .valueOrFail);
        final untouchedA = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: null,
              shotId: shotId,
              layer: OcptFloorPlanLayer.lights,
              xM: 2,
              yM: 2,
            )
            .valueOrFail);
        final untouchedB = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: sceneRow.sceneId,
              shotId: null,
              layer: OcptFloorPlanLayer.props,
              xM: 3,
              yM: 3,
            )
            .valueOrFail);

        final arrowFrom = (await floorPlanService
            .addArrow(
              database: database,
              setId: setId,
              shotId: shotId,
              kind: OcptFloorPlanArrowKind.movement,
              fromSymbolId: character,
              toSymbolId: camera,
            )
            .valueOrFail);
        final arrowTo = (await floorPlanService
            .addArrow(
              database: database,
              setId: setId,
              shotId: shotId,
              kind: OcptFloorPlanArrowKind.cameraMove,
              fromSymbolId: camera,
              toSymbolId: character,
            )
            .valueOrFail);
        final untouchedArrow = (await floorPlanService
            .addArrow(
              database: database,
              setId: setId,
              shotId: shotId,
              kind: OcptFloorPlanArrowKind.movement,
              fromSymbolId: untouchedA,
              toSymbolId: untouchedB,
            )
            .valueOrFail);

        await floorPlanService.deleteSymbol(database: database, symbolId: camera).okOrFail;

        final liveArrowIds = (await readArrows()).map((row) => row.id).toSet();
        expect(liveArrowIds.contains(arrowFrom), isFalse);
        expect(liveArrowIds.contains(arrowTo), isFalse);
        expect(liveArrowIds.contains(untouchedArrow), isTrue);

        final liveSymbolIds = (await readSymbols()).map((row) => row.id).toSet();
        expect(liveSymbolIds.contains(camera), isFalse);
        expect(liveSymbolIds.contains(character), isTrue);
      },
    );

    test(
      "deleting a set-scope original also tombstones its overrides, even an unlinked scene's",
      () async {
        final (sceneId, setId) = await seedLinkedSet();
        final originalId = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: null,
              shotId: null,
              layer: OcptFloorPlanLayer.set,
              xM: 0,
              yM: 0,
            )
            .valueOrFail);
        final overrideId = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: sceneId,
              shotId: null,
              layer: OcptFloorPlanLayer.set,
              xM: 1,
              yM: 1,
              overridesSymbolId: originalId,
            )
            .valueOrFail);
        final untouchedId = (await floorPlanService
            .placeSymbol(
              database: database,
              setId: setId,
              sceneId: null,
              shotId: null,
              layer: OcptFloorPlanLayer.set,
              xM: 2,
              yM: 2,
            )
            .valueOrFail);

        await floorPlanService.deleteSymbol(database: database, symbolId: originalId).okOrFail;

        final liveSymbolIds = (await readSymbols()).map((row) => row.id).toSet();
        expect(liveSymbolIds.contains(originalId), isFalse);
        expect(liveSymbolIds.contains(overrideId), isFalse);
        expect(liveSymbolIds.contains(untouchedId), isTrue);
      },
    );
  });
}
