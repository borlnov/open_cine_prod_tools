// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_scope_decision.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';
import 'ocpt_floor_plan_service_test_doubles.dart';

/// Run the tests of the floor plan service arrows and scopes.
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
    await screenplayService
        .saveScreenplayText(
          database: database,
          screenplayId: screenplayId,
          fountainText: buffer.toString(),
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
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
    return shotListService
        .createShot(database: database, screenplayId: screenplayId, sceneId: sceneId)
        .valueOrFail;
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

  Future<List<OcptFloorPlanSymbolRow>> readSymbols() => (database.select(
    database.ocptFloorPlanSymbolsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  Future<List<OcptFloorPlanArrowRow>> readArrows() => (database.select(
    database.ocptFloorPlanArrowsTable,
  )..where((row) => row.isDeleted.equals(false))).get();

  group("arrow CRUD", () {
    test("setArrowLabel updates only the label, deleteArrow tombstones it", () async {
      final shotId = await seedShot();
      final sceneRow = await (database.select(
        database.ocptShotsTable,
      )..where((row) => row.id.equals(shotId))).getSingle();
      final (_, setId) = await seedLinkedSet(sceneId: sceneRow.sceneId);
      final a = (await floorPlanService
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
      final b = (await floorPlanService
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
      final arrowId = (await floorPlanService
          .addArrow(
            database: database,
            setId: setId,
            shotId: shotId,
            kind: OcptFloorPlanArrowKind.movement,
            fromSymbolId: a,
            toSymbolId: b,
          )
          .valueOrFail);

      await floorPlanService
          .setArrowLabel(database: database, arrowId: arrowId, label: "walks to")
          .okOrFail;
      expect((await readArrows()).single.label, "walks to");

      await floorPlanService.deleteArrow(database: database, arrowId: arrowId).okOrFail;
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
      final a = (await floorPlanService
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
      final b = (await floorPlanService
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
      final arrowId = (await floorPlanService
          .addArrow(
            database: database,
            setId: setId,
            shotId: shotId,
            kind: OcptFloorPlanArrowKind.movement,
            fromSymbolId: a,
            toSymbolId: b,
          )
          .valueOrFail);

      await floorPlanService
          .updateArrowCurve(
            database: database,
            arrowId: arrowId,
            ctrlXM: const Value(0.5),
            ctrlYM: const Value(0.75),
          )
          .okOrFail;
      final curved = (await readArrows()).single;
      expect(curved.ctrlXM, 0.5);
      expect(curved.ctrlYM, 0.75);
      expect(curved.label, ""); // untouched

      await floorPlanService
          .updateArrowCurve(
            database: database,
            arrowId: arrowId,
            ctrlXM: const Value(null),
            ctrlYM: const Value(null),
          )
          .okOrFail;
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

        final shootingSet = (await floorPlanService
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
        final camera = (await floorPlanService
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
        await floorPlanService
            .addArrow(
              database: database,
              setId: setId,
              shotId: shotId,
              kind: OcptFloorPlanArrowKind.cameraMove,
              fromSymbolId: camera,
              toSymbolId: shootingSet,
            )
            .maybeValueOrFail;

        await database.transaction(() async {
          final stamps = await OcptRowStampService.seed(database: database, deviceId: deviceId);
          await floorPlanService.tombstoneFloorPlanRowsOfShot(
            database: database,
            shotId: shotId,
            stamps: stamps,
          );
          await stamps.flush(database);
        });

        final liveSymbolIds = (await readSymbols()).map((row) => row.id).toSet();
        expect(liveSymbolIds.contains(camera), isFalse);
        expect(liveSymbolIds.contains(shootingSet), isTrue);
        expect(await readArrows(), isEmpty);
      },
    );
  });

  group("loadSetScopeSymbolsByProjectSetId (the empty-state gallery's own thumbnail read)", () {
    test("reads only set-scope symbols, project-wide, keyed by set id", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final shotId = (await shotListService
          .createShot(database: database, screenplayId: screenplayId, sceneId: sceneId)
          .valueOrFail);

      final setScopeSymbolId = (await floorPlanService
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
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: sceneId,
            shotId: null,
            layer: OcptFloorPlanLayer.props,
            xM: 1,
            yM: 1,
          )
          .maybeValueOrFail;
      await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: shotId,
            layer: OcptFloorPlanLayer.cameras,
            xM: 2,
            yM: 2,
          )
          .maybeValueOrFail;

      final bySetId = await floorPlanService
          .loadSetScopeSymbolsByProjectSetId(database: database)
          .valueOrFail;

      expect(bySetId.keys, [setId]);
      expect(bySetId[setId]!.map((symbol) => symbol.id), [setScopeSymbolId]);
    });

    test("is empty while no set holds a set-scope symbol", () async {
      await seedLinkedSet();

      final bySetId = await floorPlanService
          .loadSetScopeSymbolsByProjectSetId(database: database)
          .valueOrFail;

      expect(bySetId, isEmpty);
    });
  });

  group("liveSetIdsWithPlan", () {
    test("names only the sets that actually hold a live plan row", () async {
      final (_, setWithPlanId) = await seedLinkedSet();
      await floorPlanService
          .placeSymbol(
            database: database,
            setId: setWithPlanId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 0,
            yM: 0,
          )
          .maybeValueOrFail;
      final setWithNoPlanId = (await locationsService
          .createSet(
            database: database,
            locationId: (await database.select(database.ocptSetsTable).get()).first.locationId,
            name: "Hallway",
          )
          .valueOrFail);

      final withPlan = await floorPlanService
          .liveSetIdsWithPlan(database: database, setIds: [setWithPlanId, setWithNoPlanId])
          .valueOrFail;

      expect(withPlan, {setWithPlanId});
    });

    test("is empty for an empty set of ids", () async {
      final withPlan = await floorPlanService
          .liveSetIdsWithPlan(database: database, setIds: const [])
          .valueOrFail;
      expect(withPlan, isEmpty);
    });
  });

  group("hideSymbolForScope", () {
    /// Places a set-scope wall on a fresh set and returns the scene id, the set id and the loaded
    /// original.
    Future<(String, String, OcptFloorPlanSymbol)> seedWall() async {
      final (sceneId, setId) = await seedLinkedSet();
      await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 1,
            yM: 2,
            widthM: 3,
            heightM: 0.2,
            label: "Wall",
            setElementShape: OcptFloorPlanSetElementShape.wall,
          )
          .maybeValueOrFail;
      final snapshot = await floorPlanService
          .loadFloorPlans(database: database, screenplayId: screenplayId)
          .valueOrFail;
      return (sceneId, setId, snapshot.setsById[setId]!.symbols.single);
    }

    test("creates a hidden scene-scope override copied from the original", () async {
      final (sceneId, setId, original) = await seedWall();

      await floorPlanService
          .hideSymbolForScope(
            database: database,
            original: original,
            existingOverride: null,
            sceneId: sceneId,
            shotId: null,
          )
          .okOrFail;

      final symbols = (await readSymbols()).where((row) => row.id != original.id).toList();
      expect(symbols, hasLength(1));
      expect(symbols.single.setId, setId);
      expect(symbols.single.sceneId, sceneId);
      expect(symbols.single.overridesSymbolId, original.id);
      expect(symbols.single.isHidden, isTrue);
      expect(symbols.single.xM, 1);
      expect(symbols.single.label, "Wall");
    });

    test("hides the existing override instead of creating another", () async {
      final (sceneId, _, original) = await seedWall();
      await floorPlanService
          .hideSymbolForScope(
            database: database,
            original: original,
            existingOverride: null,
            sceneId: sceneId,
            shotId: null,
          )
          .okOrFail;
      final override = (await readSymbols()).firstWhere((row) => row.id != original.id);
      await floorPlanService
          .updateSymbol(database: database, symbolId: override.id, isHidden: const Value(false))
          .okOrFail;
      final snapshot = await floorPlanService
          .loadFloorPlans(database: database, screenplayId: screenplayId)
          .valueOrFail;
      final existing = snapshot.setsById.values.single.symbols.firstWhere(
        (symbol) => symbol.id == override.id,
      );

      await floorPlanService
          .hideSymbolForScope(
            database: database,
            original: original,
            existingOverride: existing,
            sceneId: sceneId,
            shotId: null,
          )
          .okOrFail;

      final symbols = await readSymbols();
      expect(symbols, hasLength(2));
      expect(symbols.firstWhere((row) => row.id == override.id).isHidden, isTrue);
    });
  });

  group("applyScopeDecision", () {
    test("moves the original itself on every scope", () async {
      final (_, setId) = await seedLinkedSet();
      final symbolId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 1,
            yM: 2,
          )
          .valueOrFail);

      final isWritten = await floorPlanService
          .applyScopeDecision(
            database: database,
            decision: OcptFloorPlanScopeDecision(
              symbolId: symbolId,
              setId: setId,
              level: OcptFloorPlanOverrideLevel.sequence,
              sequenceCount: 2,
              xM: 5,
            ),
            onEveryScope: true,
            original: null,
            existingOverride: null,
            targetSceneId: null,
            targetShotId: null,
          )
          .valueOrFail;

      final row = (await readSymbols()).single;
      expect(isWritten, isTrue);
      expect(row.xM, 5);
      expect(row.yM, 2);
    });

    test("creates an override moved by the decision, leaving the original alone", () async {
      final (sceneId, setId) = await seedLinkedSet();
      final symbolId = (await floorPlanService
          .placeSymbol(
            database: database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 1,
            yM: 2,
          )
          .valueOrFail);
      final snapshot = await floorPlanService
          .loadFloorPlans(database: database, screenplayId: screenplayId)
          .valueOrFail;

      final isWritten = await floorPlanService
          .applyScopeDecision(
            database: database,
            decision: OcptFloorPlanScopeDecision(
              symbolId: symbolId,
              setId: setId,
              level: OcptFloorPlanOverrideLevel.sequence,
              sequenceCount: 2,
              yM: 7,
            ),
            onEveryScope: false,
            original: snapshot.setsById[setId]!.symbols.single,
            existingOverride: null,
            targetSceneId: sceneId,
            targetShotId: null,
          )
          .valueOrFail;

      final rows = await readSymbols();
      final override = rows.firstWhere((row) => row.id != symbolId);
      expect(isWritten, isTrue);
      expect(rows.firstWhere((row) => row.id == symbolId).yM, 2);
      expect(override.overridesSymbolId, symbolId);
      expect(override.sceneId, sceneId);
      expect(override.xM, 1);
      expect(override.yM, 7);
    });

    test("writes nothing and answers false when there is no original to copy", () async {
      final (sceneId, _) = await seedLinkedSet();

      final isWritten = await floorPlanService
          .applyScopeDecision(
            database: database,
            decision: const OcptFloorPlanScopeDecision(
              symbolId: "gone",
              setId: "set-1",
              level: OcptFloorPlanOverrideLevel.sequence,
              sequenceCount: 2,
            ),
            onEveryScope: false,
            original: null,
            existingOverride: null,
            targetSceneId: sceneId,
            targetShotId: null,
          )
          .valueOrFail;

      expect(isWritten, isFalse);
      expect(await readSymbols(), isEmpty);
    });
  });
}
