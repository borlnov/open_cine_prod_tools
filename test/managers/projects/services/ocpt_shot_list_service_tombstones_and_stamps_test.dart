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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_row_stamp_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_row_stamp_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'ocpt_shot_list_service_test_doubles.dart';

/// Run the tests of the shot list service tombstones and stamps.
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

  /// Resolves [characterName] to a live role's id, or creates a hand-added silent one — exactly
  /// what the shot list's own add-character affordance does (see
  /// `docs/adr/0030-a-shots-characters-are-the-productions-roles.md`), now that
  /// `attachCharacter`/`detachCharacter` are roleId-native and no longer resolve a name on their
  /// own. The test suite's own stand-in for what the bloc does before calling either of them.
  Future<String> roleIdOf(String characterName) async => (await shotListService
      .resolveOrCreateRoleId(database: database, screenplayId: screenplayId, name: characterName))!;

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptProjectVersionsService`'s own tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

  group("a tombstoned row is invisible to every reader", () {
    test("a deleted shot is gone from the shot list, its characters and its suggestions", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final keptId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final deletedId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      await shotListService.attachCharacter(
        database: database,
        shotId: keptId,
        roleId: await roleIdOf("Clara"),
      );
      await shotListService.attachCharacter(
        database: database,
        shotId: deletedId,
        roleId: await roleIdOf("Marc"),
      );
      await shotListService.updateShot(
        database: database,
        shotId: keptId,
        shotSize: const Value("CU"),
        framing: const Value("Low angle"),
      );
      await shotListService.updateShot(
        database: database,
        shotId: deletedId,
        shotSize: const Value("WIDE"),
        framing: const Value("Dutch angle"),
      );

      await shotListService.deleteShot(database: database, shotId: deletedId);

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(snapshot.shotsById.keys, [keptId]);
      expect(snapshot.shotsById[keptId]!.characters, ["CLARA"]);
      expect((snapshot.sequences.single as OcptSceneShotSequence).shots.single.id, keptId);

      // The suggestion lists are the readers most easily forgotten, and a deleted shot's free text
      // has no business still being offered.
      expect(
        await shotListService.distinctShotSizes(database: database, screenplayId: screenplayId),
        ["CU"],
      );
      expect(
        await shotListService.distinctFramings(database: database, screenplayId: screenplayId),
        ["Low angle"],
      );
    });

    test("a detached character is gone, and re-attaching it lifts its tombstone", () async {
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
      await shotListService.detachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Clara"),
      );

      Future<List<String>> charactersOfShot() async => (await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      )).shotsById[shotId]!.characters;

      expect(await charactersOfShot(), ["MARC"]);

      // The primary key is `{shotId, roleId}`, and "Clara" resolves back to the very same live
      // role it did before being detached, so re-attaching cannot insert a second row: it has to
      // lift the tombstone the detach left behind, and append the character at the end.
      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Clara"),
      );
      expect(await charactersOfShot(), ["MARC", "CLARA"]);
    });

    test("a scene tombstoned by a save no longer shows a sequence of its own", () async {
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

      expect(
        (await shotListService.loadShotList(
          database: database,
          screenplayId: screenplayId,
          episodeNumber: null,
        )).sequences,
        hasLength(2),
      );

      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one.
''',
        snapshotReason: OcptSnapshotReason.manual,
      );

      final sequences = (await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      )).sequences;
      expect(sequences, hasLength(1));
      expect((sequences.single as OcptSceneShotSequence).heading, "INT. HOUSE - DAY");
    });

    test("prefixes a scene sequence's displaySceneNumber with the given episode number", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''');
      final streetScene = scenes.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");

      final withoutEpisode = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      final withoutEpisodeSequence = withoutEpisode.sequences
          .whereType<OcptSceneShotSequence>()
          .firstWhere((sequence) => sequence.sceneId == streetScene.id);
      expect(withoutEpisodeSequence.displaySceneNumber, "2");

      final withEpisode = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: 3,
      );
      final withEpisodeSequence = withEpisode.sequences
          .whereType<OcptSceneShotSequence>()
          .firstWhere((sequence) => sequence.sceneId == streetScene.id);
      expect(withEpisodeSequence.displaySceneNumber, "3.2");
    });

    test("never prefixes the orphaned-shot placeholder", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action one.

EXT. STREET - NIGHT

Action two.
''');
      final streetScene = scenes.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");
      await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: streetScene.id,
      );

      // Dropping the street scene orphans its shot.
      await screenplayService.saveScreenplayText(
        database: database,
        screenplayId: screenplayId,
        fountainText: '''
INT. HOUSE - DAY

Action one.
''',
        snapshotReason: OcptSnapshotReason.manual,
      );

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: 3,
      );
      final orphanSequence = snapshot.sequences.last as OcptOrphanShotSequence;
      expect(orphanSequence.shots.single.code, "—/1");
    });
  });

  test('every write handed the read-only database of a previewed version is refused', () async {
    final preview = OcptProjectDatabase.memory(isPreview: true);
    addTearDown(preview.close);

    await preview
        .into(preview.ocptScreenplaysTable)
        .insert(
          OcptScreenplaysTableCompanion.insert(
            id: screenplayId,
            title: "Draft",
            updatedAt: DateTime.now(),
          ),
        );
    await preview
        .into(preview.ocptScenesTable)
        .insert(
          OcptScenesTableCompanion.insert(
            id: "scene-1",
            screenplayId: screenplayId,
            position: 0,
            heading: "INT. HOUSE - DAY",
            charStart: 0,
            charEnd: 16,
          ),
        );
    await preview
        .into(preview.ocptShotsTable)
        .insert(
          OcptShotsTableCompanion.insert(
            id: "shot-1",
            screenplayId: screenplayId,
            sceneId: const Value("scene-1"),
            position: 0,
            sortKey: const Value("V"),
            framing: const Value("Low angle"),
          ),
        );

    final createdId = await shotListService.createShot(
      database: preview,
      screenplayId: screenplayId,
      sceneId: "scene-1",
    );
    await shotListService.updateShot(
      database: preview,
      shotId: "shot-1",
      framing: const Value("Close up"),
    );
    await shotListService.reorderShot(database: preview, shotId: "shot-1", newPosition: 3);
    await shotListService.attachCharacter(
      database: preview,
      shotId: "shot-1",
      roleId: await roleIdOf("CLARA"),
    );
    await shotListService.deleteShot(database: preview, shotId: "shot-1");

    // A version the user is only reading isn't editable, and it is the service that says so: a UI
    // bug must not be able to write a preview's shot list.
    expect(createdId, isNull);

    final shots = await preview.select(preview.ocptShotsTable).get();
    expect(shots, hasLength(1));
    expect(shots.single.framing, "Low angle");
    expect(shots.single.sortKey, "V");
    expect(shots.single.isDeleted, isFalse);
    expect(await preview.select(preview.ocptShotCharactersTable).get(), isEmpty);
  });

  group("row-field-version stamps", () {
    /// A shot appended to a fresh scene, ready for a test to write against.
    Future<String> insertShot() async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      return (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;
    }

    test("createShot stamps every column of the new row", () async {
      final shotId = await insertShot();

      final stamps = await readStamps();
      final shot = (await readShots()).single;
      final ownStamps = {
        for (final entry in stamps.entries)
          if (entry.key.startsWith("shots/$shotId/")) entry.key: entry.value,
      };

      expect(ownStamps.keys, hasLength(shot.toJson().length));
      for (final column in shot.toJson().keys) {
        final stamp = ownStamps["shots/$shotId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
        expect(stamp.deviceId, deviceId);
      }
    });

    test("updateShot stamps only the columns that actually changed", () async {
      final shotId = await insertShot();
      // Clears what `createShot` itself stamped, so only `updateShot`'s own stamps remain below.
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await shotListService.updateShot(
        database: database,
        shotId: shotId,
        framing: const Value("Low angle"),
        shotSize: const Value("CU"),
      );

      final stamps = await readStamps();
      final ownKeys = stamps.keys.where((key) => key.startsWith("shots/$shotId/")).toSet();
      expect(ownKeys, {"shots/$shotId/framing", "shots/$shotId/shotSize"});
      expect(stamps["shots/$shotId/framing"]!.version, 1);
      expect(stamps["shots/$shotId/shotSize"]!.version, 1);

      // Writing the same values again touches nothing: there is nothing left to stamp.
      await shotListService.updateShot(
        database: database,
        shotId: shotId,
        framing: const Value("Low angle"),
      );
      expect(await readStamps(), stamps);
    });

    test("deleteShot stamps isDeleted on the shot, like any other column", () async {
      final shotId = await insertShot();
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await shotListService.deleteShot(database: database, shotId: shotId);

      final stamps = await readStamps();
      expect(stamps.keys.where((key) => key.startsWith("shots/$shotId/")).toSet(), {
        "shots/$shotId/isDeleted",
      });
      expect(stamps["shots/$shotId/isDeleted"]!.version, 1);
    });

    test("attachCharacter stamps the composite shot_characters row id", () async {
      final shotId = await insertShot();
      // A live role already exists for "Clara": attachCharacter resolves it rather than minting a
      // fresh one, so only the shot_characters row itself is stamped below, in isolation.
      await roleIndexService.addRole(
        database: database,
        screenplayId: screenplayId,
        name: "CLARA",
        kind: OcptRoleKind.silent,
      );
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Clara"),
      );

      final character = (await database.select(database.ocptShotCharactersTable).get()).single;
      final rowId = ocptCompositeRowStampKey([shotId, character.roleId]);
      final stamps = await readStamps();
      for (final column in character.toJson().keys) {
        final stamp = stamps["shot_characters/$rowId/$column"];
        expect(stamp, isNotNull, reason: "$column should be stamped");
        expect(stamp!.version, 1);
      }
    });

    test("detachCharacter stamps isDeleted on the composite shot_characters row id", () async {
      final shotId = await insertShot();
      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Clara"),
      );
      final roleId = (await database.select(database.ocptShotCharactersTable).get()).single.roleId;
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await shotListService.detachCharacter(
        database: database,
        shotId: shotId,
        roleId: await roleIdOf("Clara"),
      );

      final rowId = ocptCompositeRowStampKey([shotId, roleId]);
      final stamps = await readStamps();
      expect(stamps.keys.toSet(), {"shot_characters/$rowId/isDeleted"});
      expect(stamps["shot_characters/$rowId/isDeleted"]!.version, 1);
    });
  });

  group("tombstoneShotsOfScreenplay — the storyboard/floor plan cascade", () {
    test("tombstones every shot's storyboard panels and floor plan shot-layer placements across "
        "the whole screenplay, leaving sequence layers alone", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final firstShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;
      final secondShotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      ))!;

      final firstPanelId = (await storyboardService.addPanel(
        database: database,
        shotId: firstShotId,
      ))!;
      final secondPanelId = (await storyboardService.addPanel(
        database: database,
        shotId: secondShotId,
      ))!;

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
      final firstCameraId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: firstShotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 1,
      ))!;
      final secondCameraId = (await floorPlanService.placeSymbol(
        database: database,
        setId: setId,
        sceneId: null,
        shotId: secondShotId,
        layer: OcptFloorPlanLayer.cameras,
        xM: 2,
        yM: 2,
      ))!;

      await database.transaction(() async {
        final stamps = await OcptRowStampService.seed(database: database, deviceId: deviceId);
        await shotListService.tombstoneShotsOfScreenplay(
          database: database,
          screenplayId: screenplayId,
          stamps: stamps,
        );
        await stamps.flush(database);
      });

      final livePanels = await (database.select(
        database.ocptStoryboardPanelsTable,
      )..where((row) => row.isDeleted.equals(false))).get();
      expect(livePanels, isEmpty, reason: "$firstPanelId and $secondPanelId should be gone");

      final liveSymbolIds = (await (database.select(
        database.ocptFloorPlanSymbolsTable,
      )..where((row) => row.isDeleted.equals(false))).get()).map((row) => row.id).toSet();
      expect(liveSymbolIds.contains(firstCameraId), isFalse);
      expect(liveSymbolIds.contains(secondCameraId), isFalse);
      expect(liveSymbolIds.contains(decorSymbolId), isTrue);
    });
  });
}
