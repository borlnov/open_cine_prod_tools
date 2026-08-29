// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/utils/ocpt_row_stamp_key.dart';

/// Parses [source] with the real Fountain parser, so scene reconciliation is exercised against a
/// realistic document rather than a hand-built one.
FountainDocument _parse(String source) => const FountainParser().parse(source);

/// The fixed device id every stamp this file's writes carry, so a stamping assertion can compare
/// against a known value rather than whatever `OcptPropertiesManager` would otherwise mint.
const _deviceId = "device-1";

Future<String> _testDeviceId() async => _deviceId;

void main() {
  // Refusing a write on a previewed version logs through appLogger(), which requires a global
  // manager instance to be set; merely accessing it creates the (otherwise unused) singleton.
  setUpAll(() => OcptGlobalManager.instance);

  const shotListService = OcptShotListService(deviceId: _testDeviceId);
  const sceneIndexService = OcptSceneIndexService();
  const assetsService = OcptAssetsService(deviceId: _testDeviceId);
  const elementsService = OcptElementsService(
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const locationsService = OcptLocationsService(
    assetsService: assetsService,
    deviceId: _testDeviceId,
  );
  const screenplayService = OcptScreenplayService(
    sceneIndexService: sceneIndexService,
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(deviceId: _testDeviceId),
    roleIndexService: OcptRoleIndexService(
      elementsService: elementsService,
      roleCandidatesService: OcptRoleCandidatesService(deviceId: _testDeviceId),
      deviceId: _testDeviceId,
    ),
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

  /// Reconciles the scene index from [source] and returns the resulting scene rows, ordered by
  /// position.
  Future<List<OcptSceneRow>> reconcile(String source) async {
    await sceneIndexService.reconcile(
      database: database,
      screenplayId: screenplayId,
      document: _parse(source),
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

  /// Every version stamp the project currently holds, keyed by `<table>/<row>/<column>` — the same
  /// shape `OcptProjectVersionsService`'s own tests read `row_field_versions` back through.
  Future<Map<String, OcptRowFieldVersionRow>> readStamps() async => {
    for (final stamp in await database.select(database.ocptRowFieldVersionsTable).get())
      "${stamp.targetTableName}/${stamp.rowId}/${stamp.columnName}": stamp,
  };

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
      expect(
        keysAfter.keys.where((id) => keysAfter[id] != keysBefore[id]),
        [firstId],
      );
    });

    test("reorderShot to the head, and repeatedly between the same pair, keeps the order", () async {
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
    });

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
  });

  group("shot characters", () {
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
        characterName: "  clara  ",
      );
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Marc");

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
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Clara");
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Marc");
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Théo");

      await shotListService.detachCharacter(database: database, shotId: shotId, characterName: "Marc");

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(snapshot.shotsById[shotId]!.characters, ["CLARA", "THÉO"]);
    });

    test("removeCharacterFromEveryShot removes it from every shot of the screenplay", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
''');
      final shotA = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes[0].id,
      ))!;
      final shotB = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes[1].id,
      ))!;
      await shotListService.attachCharacter(database: database, shotId: shotA, characterName: "Clara");
      await shotListService.attachCharacter(database: database, shotId: shotB, characterName: "Clara");
      await shotListService.attachCharacter(database: database, shotId: shotB, characterName: "Marc");

      await shotListService.removeCharacterFromEveryShot(
        database: database,
        screenplayId: screenplayId,
        characterName: "Clara",
      );

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(snapshot.shotsById[shotA]!.characters, isEmpty);
      expect(snapshot.shotsById[shotB]!.characters, ["MARC"]);
    });

    test("replaceCharacterEverywhere renames the character on every shot", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Clara");

      await shotListService.replaceCharacterEverywhere(
        database: database,
        screenplayId: screenplayId,
        oldCharacterName: "Clara",
        newCharacterName: "Julie",
      );

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(snapshot.shotsById[shotId]!.characters, ["JULIE"]);
    });

    test("replaceCharacterEverywhere drops the old name without duplicating an already-present one", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = (await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      ))!;
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Clara");
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Julie");

      await shotListService.replaceCharacterEverywhere(
        database: database,
        screenplayId: screenplayId,
        oldCharacterName: "Clara",
        newCharacterName: "Julie",
      );

      final snapshot = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(snapshot.shotsById[shotId]!.characters, ["JULIE"]);
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

    test("a scene with no scene number falls back to its 1-based index among the screenplay's scenes", () async {
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
    });
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

  test(
    "detaching a shot's scene through a real saveScreenplayText call preserves its shots, "
    "their heading and drops their coverage",
    () async {
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

      final liveCoverage =
          await (database.select(database.ocptShotCoveragesTable)
                ..where((row) => row.isDeleted.equals(false)))
              .get();
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
    },
  );

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
        characterName: "Clara",
      );
      await shotListService.attachCharacter(
        database: database,
        shotId: deletedId,
        characterName: "Marc",
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

      // Every other shot-wide write ignores it too: the replaced name must not come back on it.
      await shotListService.replaceCharacterEverywhere(
        database: database,
        screenplayId: screenplayId,
        oldCharacterName: "Marc",
        newCharacterName: "Julie",
      );
      final afterReplace = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: null,
      );
      expect(afterReplace.shotsById.keys, [keptId]);
      expect(afterReplace.shotsById[keptId]!.characters, ["CLARA"]);
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
        characterName: "Clara",
      );
      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        characterName: "Marc",
      );
      await shotListService.detachCharacter(
        database: database,
        shotId: shotId,
        characterName: "Clara",
      );

      Future<List<String>> charactersOfShot() async =>
          (await shotListService.loadShotList(
            database: database,
            screenplayId: screenplayId,
            episodeNumber: null,
          )).shotsById[shotId]!.characters;

      expect(await charactersOfShot(), ["MARC"]);

      // The primary key is `{shotId, characterName}`, so re-attaching cannot insert a second row:
      // it has to lift the tombstone the detach left behind, and append the character at the end.
      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        characterName: "Clara",
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
      final withoutEpisodeSequence =
          withoutEpisode.sequences.whereType<OcptSceneShotSequence>().firstWhere(
            (sequence) => sequence.sceneId == streetScene.id,
          );
      expect(withoutEpisodeSequence.displaySceneNumber, "2");

      final withEpisode = await shotListService.loadShotList(
        database: database,
        screenplayId: screenplayId,
        episodeNumber: 3,
      );
      final withEpisodeSequence = withEpisode.sequences.whereType<OcptSceneShotSequence>().firstWhere(
        (sequence) => sequence.sceneId == streetScene.id,
      );
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
      characterName: "CLARA",
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
        expect(stamp.deviceId, _deviceId);
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
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        characterName: "Clara",
      );

      final rowId = ocptCompositeRowStampKey([shotId, "CLARA"]);
      final stamps = await readStamps();
      final character = (await database.select(database.ocptShotCharactersTable).get()).single;
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
        characterName: "Clara",
      );
      await database.delete(database.ocptRowFieldVersionsTable).go();

      await shotListService.detachCharacter(
        database: database,
        shotId: shotId,
        characterName: "Clara",
      );

      final rowId = ocptCompositeRowStampKey([shotId, "CLARA"]);
      final stamps = await readStamps();
      expect(stamps.keys.toSet(), {"shot_characters/$rowId/isDeleted"});
      expect(stamps["shot_characters/$rowId/isDeleted"]!.version, 1);
    });
  });
}
