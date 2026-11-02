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
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_scope_decision.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import '../../../ocpt_result_expectations.dart';
import 'ocpt_floor_plan_service_test_doubles.dart';

/// The rows the calls of this file work on.
typedef _Fixture = ({
  String sceneId,
  String setId,
  String otherSetId,
  String firstShot,
  String secondShot,
  String setSymbol,
  String camera,
  String character,
  String arrow,
  OcptFloorPlanSymbol original,
});

/// Run the tests of what [OcptFloorPlanService] answers when the database fails or refuses.
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

  late _Fixture rows;

  const tables = ["floor_plan_sets", "floor_plan_symbols", "floor_plan_arrows", "assets"];

  /// Build a set with a décor symbol, two shots, a camera and a character on the first one, an
  /// arrow between them, an arrow from the camera to the décor symbol, an underlay, and a second
  /// set without any plan.
  Future<_Fixture> seed() async {
    final sceneId = await seedScene();
    final firstShot = (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: sceneId,
    ))!;
    final secondShot = (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: sceneId,
    ))!;
    final (_, setId) = await seedLinkedSet(sceneId: sceneId);
    final (_, otherSetId) = await seedLinkedSet(sceneId: sceneId, name: "Garden");
    Future<String> place(OcptFloorPlanLayer layer, String? shotId, double at) => floorPlanService
        .placeSymbol(
          database: database,
          setId: setId,
          sceneId: null,
          shotId: shotId,
          layer: layer,
          xM: at,
          yM: at,
        )
        .valueOrFail;
    final setSymbol = await place(OcptFloorPlanLayer.set, null, 1);
    final camera = await place(OcptFloorPlanLayer.cameras, firstShot, 2);
    final character = await place(OcptFloorPlanLayer.characters, firstShot, 3);
    final arrow = await floorPlanService
        .addArrow(
          database: database,
          setId: setId,
          shotId: firstShot,
          kind: OcptFloorPlanArrowKind.movement,
          fromSymbolId: camera,
          toSymbolId: character,
        )
        .valueOrFail;
    await floorPlanService
        .addArrow(
          database: database,
          setId: setId,
          shotId: firstShot,
          kind: OcptFloorPlanArrowKind.movement,
          fromSymbolId: camera,
          toSymbolId: setSymbol,
        )
        .valueOrFail;
    await floorPlanService
        .setSetUnderlay(
          database: database,
          setId: setId,
          path: "/tmp/plan.jpg",
          xM: 0,
          yM: 0,
          widthM: 4,
          heightM: 3,
        )
        .okOrFail;
    final snapshot = await floorPlanService
        .loadFloorPlans(database: database, screenplayId: screenplayId)
        .valueOrFail;

    return (
      sceneId: sceneId,
      setId: setId,
      otherSetId: otherSetId,
      firstShot: firstShot,
      secondShot: secondShot,
      setSymbol: setSymbol,
      camera: camera,
      character: character,
      arrow: arrow,
      original: snapshot.setsById[setId]!.symbols.firstWhere((symbol) => symbol.id == setSymbol),
    );
  }

  /// Every write of the service, with an input that changes a row.
  final writes = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "setSetUnderlay": (r) async => (await floorPlanService.setSetUnderlay(
      database: database,
      setId: r.setId,
      path: "/tmp/other.jpg",
      xM: 1,
      yM: 1,
      widthM: 5,
      heightM: 5,
    )).status,
    "clearSetUnderlay": (r) async =>
        (await floorPlanService.clearSetUnderlay(database: database, setId: r.setId)).status,
    "updateUnderlayFrame": (r) async => (await floorPlanService.updateUnderlayFrame(
      database: database,
      setId: r.setId,
      xM: const Value(9),
    )).status,
    "placeSymbol": (r) async => (await floorPlanService.placeSymbol(
      database: database,
      setId: r.setId,
      sceneId: null,
      shotId: r.firstShot,
      layer: OcptFloorPlanLayer.lights,
      xM: 4,
      yM: 4,
    )).status,
    "updateSymbol": (r) async => (await floorPlanService.updateSymbol(
      database: database,
      symbolId: r.camera,
      xM: const Value(7),
    )).status,
    "deleteSymbol": (r) async =>
        (await floorPlanService.deleteSymbol(database: database, symbolId: r.character)).status,
    "deleteSymbolEverywhere": (r) async => (await floorPlanService.deleteSymbolEverywhere(
      database: database,
      symbolId: r.setSymbol,
    )).status,
    "hideSymbolForScope": (r) async => (await floorPlanService.hideSymbolForScope(
      database: database,
      original: r.original,
      existingOverride: null,
      sceneId: r.sceneId,
      shotId: null,
    )).status,
    "applyScopeDecision": (r) async => (await floorPlanService.applyScopeDecision(
      database: database,
      decision: OcptFloorPlanScopeDecision(
        symbolId: r.setSymbol,
        setId: r.setId,
        level: OcptFloorPlanOverrideLevel.sequence,
        sequenceCount: 2,
        xM: 5,
      ),
      onEveryScope: false,
      original: r.original,
      existingOverride: null,
      targetSceneId: r.sceneId,
      targetShotId: null,
    )).status,
    "addArrow": (r) async => (await floorPlanService.addArrow(
      database: database,
      setId: r.setId,
      shotId: r.firstShot,
      kind: OcptFloorPlanArrowKind.movement,
      fromSymbolId: r.character,
      toSymbolId: r.camera,
    )).status,
    "setArrowLabel": (r) async => (await floorPlanService.setArrowLabel(
      database: database,
      arrowId: r.arrow,
      label: "walks",
    )).status,
    "updateArrowCurve": (r) async => (await floorPlanService.updateArrowCurve(
      database: database,
      arrowId: r.arrow,
      ctrlXM: const Value(1),
      ctrlYM: const Value(1),
    )).status,
    "deleteArrow": (r) async =>
        (await floorPlanService.deleteArrow(database: database, arrowId: r.arrow)).status,
    "duplicateSet": (r) async => (await floorPlanService.duplicateSet(
      database: database,
      sourceSetId: r.setId,
      destinationSetId: r.otherSetId,
    )).status,
    "copyShotBlocking": (r) async => (await floorPlanService.copyShotBlocking(
      database: database,
      sourceSetId: r.setId,
      sourceShotId: r.firstShot,
      destinationSetId: r.setId,
      destinationShotId: r.secondShot,
    )).status,
  };

  /// Every read of the service.
  final reads = <String, Future<MixinResultStatus> Function(_Fixture)>{
    "loadFloorPlans": (r) async => (await floorPlanService.loadFloorPlans(
      database: database,
      screenplayId: screenplayId,
    )).status,
    "loadSetScopeSymbolsByProjectSetId": (r) async =>
        (await floorPlanService.loadSetScopeSymbolsByProjectSetId(database: database)).status,
    "liveSetIdsWithPlan": (r) async =>
        (await floorPlanService.liveSetIdsWithPlan(database: database, setIds: [r.setId])).status,
  };

  /// Every row of the tables the service writes, plus the stamps, as a comparable text.
  Future<String> snapshot() async {
    final buffer = StringBuffer();
    for (final table in [...tables, "row_field_versions"]) {
      final result = await database.customSelect("SELECT * FROM $table ORDER BY 1, 2, 3").get();
      buffer.writeln("$table: ${[for (final row in result) row.data]}");
    }

    return buffer.toString();
  }

  /// Refuse the [verbs] on [table].
  Future<void> refuse(String table, List<String> verbs) async {
    for (final verb in verbs) {
      await database.customStatement(
        "CREATE TRIGGER refuse_${verb.toLowerCase()}_$table BEFORE $verb ON $table "
        "BEGIN SELECT RAISE(ABORT, 'refused'); END",
      );
    }
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
    rows = await seed();
  });

  tearDown(() async {
    await database.close();
  });

  group("every write answers a database error when the database refuses it", () {
    for (final entry in writes.entries) {
      test("${entry.key} writes nothing", () async {
        // The call must change something when nothing is wrong, or the refusal proves nothing.
        final before = await snapshot();
        expect(await entry.value(rows), OcptDatabaseStatus.ok);
        expect(await snapshot(), isNot(before), reason: "the input changes no row");
        await database.close();
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
        rows = await seed();

        final untouched = await snapshot();
        for (final table in tables) {
          await refuse(table, ["INSERT", "UPDATE"]);
        }

        final status = await entry.value(rows);

        expect(status, OcptDatabaseStatus.databaseError);
        expect(await snapshot(), untouched, reason: "the failed call rolled back whole");
      });
    }
  });

  group("every method answers a database error when its tables are gone", () {
    for (final entry in {...writes, ...reads}.entries) {
      test("${entry.key} answers a database error", () async {
        for (final table in tables) {
          await database.customStatement("ALTER TABLE $table RENAME TO ${table}_gone");
        }

        expect(await entry.value(rows), OcptDatabaseStatus.databaseError);
      });
    }
  });

  group("on the database of a version being previewed", () {
    late OcptProjectDatabase preview;

    setUp(() => preview = OcptProjectDatabase.memory(isPreview: true));

    tearDown(() => preview.close());

    test("every write is refused as a call that went well, and writes nothing", () async {
      final previous = database;
      database = preview;
      final untouched = await snapshot();

      for (final entry in writes.entries) {
        expect(await entry.value(rows), OcptDatabaseStatus.ok, reason: entry.key);
      }

      expect(await snapshot(), untouched);
      database = previous;
    });

    test("a write that answers an id answers none", () async {
      final symbol = await floorPlanService
          .placeSymbol(
            database: preview,
            setId: rows.setId,
            sceneId: null,
            shotId: rows.firstShot,
            layer: OcptFloorPlanLayer.lights,
            xM: 4,
            yM: 4,
          )
          .maybeValueOrFail;
      final arrow = await floorPlanService
          .addArrow(
            database: preview,
            setId: rows.setId,
            shotId: rows.firstShot,
            kind: OcptFloorPlanArrowKind.movement,
            fromSymbolId: rows.camera,
            toSymbolId: rows.character,
          )
          .maybeValueOrFail;

      expect(symbol, isNull);
      expect(arrow, isNull);
    });

    test("a read is not refused", () async {
      final plans = await floorPlanService
          .loadFloorPlans(database: preview, screenplayId: screenplayId)
          .valueOrFail;
      final ids = await floorPlanService
          .liveSetIdsWithPlan(database: preview, setIds: [rows.setId])
          .valueOrFail;

      expect(plans.setsById, isEmpty);
      expect(ids, isEmpty);
    });
  });

  group("a call that breaks the scope rules is refused, not raised", () {
    test("hiding a symbol for no scope at all writes nothing", () async {
      final untouched = await snapshot();

      final hidden = await floorPlanService.hideSymbolForScope(
        database: database,
        original: rows.original,
        existingOverride: null,
        sceneId: null,
        shotId: null,
      );

      expect(hidden.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched);
    });

    test("an override of a camera for a scene writes nothing", () async {
      final untouched = await snapshot();
      final snapshotRead = await floorPlanService
          .loadFloorPlans(database: database, screenplayId: screenplayId)
          .valueOrFail;
      final camera = snapshotRead.setsById[rows.setId]!.symbols.firstWhere(
        (symbol) => symbol.id == rows.camera,
      );

      final applied = await floorPlanService.applyScopeDecision(
        database: database,
        decision: OcptFloorPlanScopeDecision(
          symbolId: rows.camera,
          setId: rows.setId,
          level: OcptFloorPlanOverrideLevel.sequence,
          sequenceCount: 2,
          xM: 5,
        ),
        onEveryScope: false,
        original: camera,
        existingOverride: null,
        targetSceneId: rows.sceneId,
        targetShotId: null,
      );

      expect(applied.status, OcptDatabaseStatus.databaseError);
      expect(applied.value, isNull);
      expect(await snapshot(), untouched);
    });
  });

  group("a write that touches several rows is one transaction", () {
    test("an underlay whose new image cannot be minted keeps the former one", () async {
      final untouched = await snapshot();
      await refuse("assets", ["INSERT"]);

      final set = await floorPlanService.setSetUnderlay(
        database: database,
        setId: rows.setId,
        path: "/tmp/other.jpg",
        xM: 1,
        yM: 1,
        widthM: 5,
        heightM: 5,
      );

      expect(set.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the former image stayed tombstoned");
    });

    test("a symbol deleted everywhere keeps its arrows when it cannot be tombstoned", () async {
      final untouched = await snapshot();
      await refuse("floor_plan_symbols", ["UPDATE"]);

      final deleted = await floorPlanService.deleteSymbolEverywhere(
        database: database,
        symbolId: rows.setSymbol,
      );

      expect(deleted.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the arrows stayed tombstoned");
    });

    test("a duplicated set has no plan when its symbols cannot be copied", () async {
      final untouched = await snapshot();
      await refuse("floor_plan_symbols", ["INSERT"]);

      final duplicated = await floorPlanService.duplicateSet(
        database: database,
        sourceSetId: rows.setId,
        destinationSetId: rows.otherSetId,
      );

      expect(duplicated.status, OcptDatabaseStatus.databaseError);
      expect(await snapshot(), untouched, reason: "the destination kept a plan with no symbol");
    });
  });
}
