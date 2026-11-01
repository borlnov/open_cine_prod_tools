// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_test_utility/act_test_utility.dart';
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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'ocpt_shot_list_service_test_doubles.dart';

/// Run the tests of the shot list service crud and characters.
void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const sceneIndexService = OcptSceneIndexService(logger: SilentLogger());

  const assetsService = OcptAssetsService(logger: SilentLogger(), deviceId: testDeviceId);

  const elementsService = OcptElementsService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  const floorPlanService = OcptFloorPlanService(
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

  const storyboardService = OcptStoryboardService(
    logger: SilentLogger(),
    assetsService: assetsService,
    deviceId: testDeviceId,
  );

  const shotListService = OcptShotListService(
    logger: SilentLogger(),
    roleIndexService: roleIndexService,
    storyboardService: storyboardService,
    floorPlanService: floorPlanService,
    deviceId: testDeviceId,
  );

  const screenplayService = OcptScreenplayService(
    logger: SilentLogger(),
    sceneIndexService: sceneIndexService,
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

  /// Reconciles the scene index from [source] and returns the resulting scene rows, ordered by
  /// position.
  Future<List<OcptSceneRow>> reconcile(String source) async {
    await sceneIndexService.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: parse(source),
    );
    return (database.select(database.ocptScenesTable)
          ..where((row) => row.isDeleted.equals(false))
          ..orderBy([(row) => OrderingTerm.asc(row.position)]))
        .get();
  }

  /// Every live shot, in the order `sortKey` puts them in — which is what the shot list displays
  /// and what its codes are numbered from, `position` having stopped being renumbered.
  Future<List<OcptShotRow>> readShots() =>
      (database.select(database.ocptShotsTable)
            ..where((row) => row.isDeleted.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.sortKey)]))
          .get();

  /// Every shot row, tombstones included.
  Future<List<OcptShotRow>> readShotsIncludingTombstones() => (database.select(
    database.ocptShotsTable,
  )..orderBy([(row) => OrderingTerm.asc(row.sortKey)])).get();

  /// Resolves [characterName] to a live role's id, or creates a hand-added silent one — exactly
  /// what the shot list's own add-character affordance does (see
  /// `docs/adr/0030-a-shots-characters-are-the-productions-roles.md`), now that
  /// `attachCharacter`/`detachCharacter` are roleId-native and no longer resolve a name on their
  /// own. The test suite's own stand-in for what the bloc does before calling either of them.
  Future<String> roleIdOf(String characterName) async => (await shotListService
      .resolveOrCreateRoleId(database: database, screenplayId: screenplayId, name: characterName))!;

  /// Every live shot's `sortKey`, keyed by shot id: what a test compares before and after a write
  /// to count how many rows that write actually touched.
  Future<Map<String, String>> readSortKeys() async => {
    for (final row in await readShots()) row.id: row.sortKey,
  };

  group("shot CRUD and ordering", () {
    test("createShot appends at the end of its scene", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final firstId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final secondId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      final shots = await readShots();
      expect(shots, hasLength(2));
      expect(shots.map((row) => row.id), [firstId, secondId]);
    });

    test("deleteShot tombstones the shot and leaves every other row untouched", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final firstId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final secondId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final thirdId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      final keysBefore = await readSortKeys();
      await shotListService.deleteShot(database: database, shotId: firstId);
      final keysAfter = await readSortKeys();

      final shots = await readShots();
      expect(shots.map((row) => row.id), [secondId, thirdId]);
      // Removing one row of an ascending run leaves the rest ascending, so a deletion rewrites
      // nothing but the row it deletes.
      expect(keysAfter[secondId], keysBefore[secondId]);
      expect(keysAfter[thirdId], keysBefore[thirdId]);

      final everyRow = await readShotsIncludingTombstones();
      expect(everyRow, hasLength(3));
      expect(everyRow.singleWhere((row) => row.id == firstId).isDeleted, isTrue);
    });

    test("deleteShot also tombstones the shot's storyboard panels and floor plan shot-layer "
        "placements, leaving sequence layers and other shots alone", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final deletedShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final survivingShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      final panelId = (await storyboardService.addPanel(
        database: database,
        shotId: deletedShotId,
      ))!;
      await storyboardService.replacePanelImage(
        database: database,
        panelId: panelId,
        path: "/tmp/frame.jpg",
      );
      final panelAssetId = (await (database.select(
        database.ocptStoryboardPanelsTable,
      )..where((row) => row.id.equals(panelId))).getSingle()).imageAssetId!;
      await storyboardService.addAnnotation(
        database: database,
        panelId: panelId,
        kind: OcptStoryboardAnnotationKind.label,
        x1: 0.5,
        y1: 0.5,
        text: "note",
      );

      final setId = (await locationsService.createSetLinkedToScene(
        database: database,
        sceneId: sceneId,
        name: "Kitchen",
      ))!;
      final decorSymbolId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 0,
        yM: 0,
      ))!;
      final deletedCameraId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: deletedShotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      ))!;
      final survivingCameraId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: survivingShotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 2,
        yM: 2,
      ))!;
      await floorPlanService.addArrow(
        database: database,
        setId: setId,
        shotId: deletedShotId,
        kind: OcptFloorPlanArrowKind.cameraMove,
        fromSymbolId: deletedCameraId,
        toSymbolId: decorSymbolId,
      );

      await shotListService.deleteShot(database: database, shotId: deletedShotId);

      final livePanels = await (database.select(
        database.ocptStoryboardPanelsTable,
      )..where((row) => row.isDeleted.equals(false))).get();
      expect(livePanels, isEmpty);

      final liveAnnotations = await (database.select(
        database.ocptStoryboardAnnotationsTable,
      )..where((row) => row.isDeleted.equals(false))).get();
      expect(liveAnnotations, isEmpty);

      final panelAsset = await (database.select(
        database.ocptAssetsTable,
      )..where((row) => row.id.equals(panelAssetId))).getSingle();
      expect(panelAsset.isDeleted, isTrue);

      final liveSymbolIds = (await (database.select(
        database.ocptFloorPlanSymbolsTable,
      )..where((row) => row.isDeleted.equals(false))).get()).map((row) => row.id).toSet();
      expect(liveSymbolIds.contains(deletedCameraId), isFalse);
      expect(liveSymbolIds.contains(decorSymbolId), isTrue);
      expect(liveSymbolIds.contains(survivingCameraId), isTrue);

      final liveArrows = await (database.select(
        database.ocptFloorPlanArrowsTable,
      )..where((row) => row.isDeleted.equals(false))).get();
      expect(liveArrows, isEmpty);
    });

    test("reorderShot moves a shot by writing exactly one row", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final firstId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final secondId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final thirdId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      // Moves the first shot to the end: expected new order is second, third, first.
      final keysBefore = await readSortKeys();
      await shotListService.reorderShot(database: database, shotId: firstId, newPosition: 2);
      final keysAfter = await readSortKeys();

      expect((await readShots()).map((row) => row.id), [secondId, thirdId, firstId]);
      // This is the whole point of the fractional index: however far a shot moves and however
      // large its scene, only the shot that moved is written.
      expect(keysAfter.keys.where((id) => keysAfter[id] != keysBefore[id]), [firstId]);
    });

    test(
      "reorderShot to the head, and repeatedly between the same pair, keeps the order",
      () async {
        final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
        final sceneId = scenes.single.id;

        final ids = [
          for (var i = 0; i < 4; i++)
            (await shotListService.createShot(
              database: database,
              screenplayId: screenplayId,
              sceneId: sceneId,
            ))!,
        ];

        // To the head, from the tail.
        await shotListService.reorderShot(database: database, shotId: ids[3], newPosition: 0);
        expect((await readShots()).map((row) => row.id), [ids[3], ids[0], ids[1], ids[2]]);

        // Then squeeze the last one between the same two neighbours, over and over: a fractional
        // key always has room for one more, it just grows a digit when it runs out.
        for (var i = 0; i < 5; i++) {
          await shotListService.reorderShot(database: database, shotId: ids[2], newPosition: 1);
          expect((await readShots()).map((row) => row.id), [ids[3], ids[2], ids[0], ids[1]]);
          await shotListService.reorderShot(database: database, shotId: ids[0], newPosition: 1);
          expect((await readShots()).map((row) => row.id), [ids[3], ids[0], ids[2], ids[1]]);
        }
      },
    );

    test("updateShot only touches the fields it's given a Value for", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      await shotListService.updateShot(
        database: database,
        shotId: shotId,
        shotSize: const Value("CU"),
        abbreviation: const Value("GP"),
        notes: const Value("Watch the eyeline."),
      );

      final shot = (await readShots()).single;
      expect(shot.shotSize, "CU");
      expect(shot.abbreviation, "GP");
      expect(shot.notes, "Watch the eyeline.");
      expect(shot.framing, ""); // untouched, still its column default
    });

    test("updateTextField writes the column its field names and nothing else", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;

      await shotListService.updateTextField(
        database: database,
        shotId: shotId,
        field: OcptShotListEditableField.lens,
        rawValue: "35mm",
      );
      await shotListService.updateTextField(
        database: database,
        shotId: shotId,
        field: OcptShotListEditableField.locationNotes,
        rawValue: "Second floor",
      );
      await shotListService.updateTextField(
        database: database,
        shotId: shotId,
        field: OcptShotListEditableField.estimatedDuration,
        rawValue: "12",
      );

      final shot = (await readShots()).single;
      expect(shot.lens, "35mm");
      expect(shot.locationNotes, "Second floor");
      expect(shot.estimatedDurationMs, isNull);
      expect(shot.notes, "");
    });

    test("updateDifficulty writes the one axis it is given", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;

      await shotListService.updateDifficulty(
        database: database,
        shotId: shotId,
        axis: OcptShotDifficultyAxis.acting,
        value: 4,
      );

      final shot = (await readShots()).single;
      expect(shot.difficultyActing, 4);
      expect(shot.difficultySet, 1);
      expect(shot.difficultyCamera, 1);
      expect(shot.difficultySound, 1);
    });
  });

  group("resolveOrCreateRoleId", () {
    test("resolves to a live role already named that way, normalised", () async {
      final roleId = await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "CLARA",
        kind: OcptRoleKind.silent,
      );

      final resolved = await shotListService.resolveOrCreateRoleId(
        database: database,
        screenplayId: screenplayId,
        name: "  clara  ",
      );

      expect(resolved, roleId);
    });

    test("creates a hand-added silent role linked to the given episode when none exists", () async {
      final roleId = await shotListService.resolveOrCreateRoleId(
        database: database,
        screenplayId: screenplayId,
        name: "Nouveau",
      );

      final role = (await roleIndexService.loadRoles(database: database)).single;
      expect(role.id, roleId);
      expect(role.name, "NOUVEAU");
      expect(role.kind, OcptRoleKind.silent);
      expect(role.isFromScreenplay, isFalse);
      expect(role.episodeIds, [screenplayId]);
    });
  });

  group("shot characters", () {
    test("attachCharacter does nothing when handed a role id naming no live role", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;

      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: "no-such-role",
      );

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(snapshot.shotsById[shotId]!.characters, isEmpty);
    });

    test("attachCharacter normalises the name and appends it", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;

      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("  clara  "),
      );
      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Marc"),
      );

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(snapshot.shotsById[shotId]!.characters, ["CLARA", "MARC"]);
    });

    test("detachCharacter removes it and renumbers the remaining ones", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;
      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Clara"),
      );
      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Marc"),
      );
      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Théo"),
      );

      await shotListService.detachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Marc"),
      );

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(snapshot.shotsById[shotId]!.characters, ["CLARA", "THÉO"]);
    });
  });

  group("derived shot code", () {
    test("a scene with an explicit scene number uses it as the code's scene number", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY #5#

Action.
''');
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;
      await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      );

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      final sequence = snapshot.sequences.single as OcptSceneShotSequence;

      expect(sequence.displaySceneNumber, "5");
      expect(snapshot.shotsById[shotId]!.code, "5/1");
      expect(sequence.shots[1].code, "5/2");
    });

    test(
      "a scene with no scene number falls back to its 1-based index among the screenplay's scenes",
      () async {
        final scenes = await reconcile('''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
''');
        final shotId = (await shotListService.createShot(
          database: database,
          screenplayId: screenplayId,
          sceneId: scenes[1].id,
        ))!;

        final snapshot = await shotListService.loadShotList(
          database: database,
          screenplayId: screenplayId,
          episodeNumber: null,
        );
        final secondSequence = snapshot.sequences[1] as OcptSceneShotSequence;

        expect(secondSequence.sceneNumber, isNull);
        expect(secondSequence.displaySceneNumber, "2");
        expect(snapshot.shotsById[shotId]!.code, "2/1");
      },
    );
  });

  test("a scene sequence's charStart/charEnd come straight from its scene row", () async {
    final scenes = await reconcile('''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''');

    final snapshot = await shotListService.loadShotList(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: null,
    );
    final firstSequence = snapshot.sequences[0] as OcptSceneShotSequence;
    final secondSequence = snapshot.sequences[1] as OcptSceneShotSequence;

    expect(firstSequence.charStart, scenes[0].charStart);
    expect(firstSequence.charEnd, scenes[0].charEnd);
    expect(secondSequence.charStart, scenes[1].charStart);
    expect(secondSequence.charEnd, scenes[1].charEnd);
  });

  test("detaching a shot's scene through a real saveScreenplayText call preserves its shots, "
      "their heading and drops their coverage", () async {
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final scenesBefore =
        await (database.select(database.ocptScenesTable)
              ..where((row) => row.isDeleted.equals(false))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();
    final streetScene = scenesBefore.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");

    final shotId = (await shotListService.createShot(
      database: database,
      screenplayId: screenplayId,
      sceneId: streetScene.id,
    ))!;
    await database
        .into(database.ocptShotCoveragesTable)
        .insert(
          OcptShotCoveragesTableCompanion.insert(
            id: "range-1",
            shotId: shotId,
            sceneId: streetScene.id,
            startOffset: 0,
            endOffset: 5,
            coveredTextDigest: "irrelevant-for-this-test",
          ),
        );

    // The new text drops the street scene entirely.
    await screenplayService.saveScreenplayText(
      database: database,
      screenplayId: screenplayId,
      fountainText: '''
INT. HOUSE - DAY

Action one.
''',
      snapshotReason: OcptSnapshotReason.manual,
    );

    final shot = (await readShots()).singleWhere((row) => row.id == shotId);
    expect(shot.sceneId, isNull);
    expect(shot.orphanedHeading, "EXT. STREET - NIGHT");
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.sceneDeleted);

    final liveCoverage = await (database.select(
      database.ocptShotCoveragesTable,
    )..where((row) => row.isDeleted.equals(false))).get();
    expect(liveCoverage, isEmpty);
    // Tombstoned, not deleted: the range's row is still there for a replica to learn about.
    final everyCoverage = await database.select(database.ocptShotCoveragesTable).get();
    expect(everyCoverage.single.isDeleted, isTrue);

    final snapshot = await shotListService.loadShotList(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: null,
    );
    final orphanSequence = snapshot.sequences.last as OcptOrphanShotSequence;
    expect(orphanSequence.shots.single.id, shotId);
    expect(orphanSequence.shots.single.orphanedHeading, "EXT. STREET - NIGHT");
  });
}
