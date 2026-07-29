// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';

/// Parses [source] with the real Fountain parser, so scene reconciliation is exercised against a
/// realistic document rather than a hand-built one.
FountainDocument _parse(String source) => const FountainParser().parse(source);

void main() {
  const shotListService = OcptShotListService();
  const sceneIndexService = OcptSceneIndexService();
  const screenplayService = OcptScreenplayService(
    sceneIndexService: sceneIndexService,
    shotListService: shotListService,
    shotCoverageService: OcptShotCoverageService(),
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
    return (database.select(
      database.ocptScenesTable,
    )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
  }

  Future<List<OcptShotRow>> readShots() => (database.select(
    database.ocptShotsTable,
  )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();

  group("shot CRUD and position renumbering", () {
    test("createShot appends at the end of its scene", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final firstId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      final secondId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );

      final shots = await readShots();
      expect(shots, hasLength(2));
      expect(shots.firstWhere((row) => row.id == firstId).position, 0);
      expect(shots.firstWhere((row) => row.id == secondId).position, 1);
    });

    test("deleteShot renumbers the remaining shots of its scene contiguously", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final firstId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      final secondId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      final thirdId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );

      await shotListService.deleteShot(database: database, shotId: firstId);

      final shots = await readShots();
      expect(shots, hasLength(2));
      expect(shots.firstWhere((row) => row.id == secondId).position, 0);
      expect(shots.firstWhere((row) => row.id == thirdId).position, 1);
    });

    test("reorderShot moves a shot and renumbers its whole scene contiguously", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;

      final firstId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      final secondId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );
      final thirdId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );

      // Moves the first shot to the end: expected new order is second, third, first.
      await shotListService.reorderShot(database: database, shotId: firstId, newPosition: 2);

      final shots = await readShots();
      expect(shots.firstWhere((row) => row.id == secondId).position, 0);
      expect(shots.firstWhere((row) => row.id == thirdId).position, 1);
      expect(shots.firstWhere((row) => row.id == firstId).position, 2);
    });

    test("updateShot only touches the fields it's given a Value for", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final sceneId = scenes.single.id;
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: sceneId,
      );

      await shotListService.updateShot(
        database: database,
        shotId: shotId,
        shotSize: const Value("CU"),
        notes: const Value("Watch the eyeline."),
      );

      final shot = (await readShots()).single;
      expect(shot.shotSize, "CU");
      expect(shot.notes, "Watch the eyeline.");
      expect(shot.framing, ""); // untouched, still its column default
      expect(shot.position, 0); // untouched
    });
  });

  group("shot characters", () {
    test("attachCharacter normalises the name and appends it", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      );

      await shotListService.attachCharacter(
        database: database,
        shotId: shotId,
        characterName: "  clara  ",
      );
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Marc");

      final snapshot = await shotListService.loadShotList(database: database, screenplayId: screenplayId);
      expect(snapshot.shotsById[shotId]!.characters, ["CLARA", "MARC"]);
    });

    test("detachCharacter removes it and renumbers the remaining ones", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      );
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Clara");
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Marc");
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Théo");

      await shotListService.detachCharacter(database: database, shotId: shotId, characterName: "Marc");

      final snapshot = await shotListService.loadShotList(database: database, screenplayId: screenplayId);
      expect(snapshot.shotsById[shotId]!.characters, ["CLARA", "THÉO"]);
    });

    test("removeCharacterFromEveryShot removes it from every shot of the screenplay", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.

EXT. STREET - NIGHT

Action.
''');
      final shotA = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes[0].id,
      );
      final shotB = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes[1].id,
      );
      await shotListService.attachCharacter(database: database, shotId: shotA, characterName: "Clara");
      await shotListService.attachCharacter(database: database, shotId: shotB, characterName: "Clara");
      await shotListService.attachCharacter(database: database, shotId: shotB, characterName: "Marc");

      await shotListService.removeCharacterFromEveryShot(
        database: database,
        screenplayId: screenplayId,
        characterName: "Clara",
      );

      final snapshot = await shotListService.loadShotList(database: database, screenplayId: screenplayId);
      expect(snapshot.shotsById[shotA]!.characters, isEmpty);
      expect(snapshot.shotsById[shotB]!.characters, ["MARC"]);
    });

    test("replaceCharacterEverywhere renames the character on every shot", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      );
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Clara");

      await shotListService.replaceCharacterEverywhere(
        database: database,
        screenplayId: screenplayId,
        oldCharacterName: "Clara",
        newCharacterName: "Julie",
      );

      final snapshot = await shotListService.loadShotList(database: database, screenplayId: screenplayId);
      expect(snapshot.shotsById[shotId]!.characters, ["JULIE"]);
    });

    test("replaceCharacterEverywhere drops the old name without duplicating an already-present one", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY

Action.
''');
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      );
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Clara");
      await shotListService.attachCharacter(database: database, shotId: shotId, characterName: "Julie");

      await shotListService.replaceCharacterEverywhere(
        database: database,
        screenplayId: screenplayId,
        oldCharacterName: "Clara",
        newCharacterName: "Julie",
      );

      final snapshot = await shotListService.loadShotList(database: database, screenplayId: screenplayId);
      expect(snapshot.shotsById[shotId]!.characters, ["JULIE"]);
    });
  });

  group("derived shot code", () {
    test("a scene with an explicit scene number uses it as the code's scene number", () async {
      final scenes = await reconcile('''
INT. HOUSE - DAY #5#

Action.
''');
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      );
      await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes.single.id,
      );

      final snapshot = await shotListService.loadShotList(database: database, screenplayId: screenplayId);
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
      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: scenes[1].id,
      );

      final snapshot = await shotListService.loadShotList(database: database, screenplayId: screenplayId);
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

      final scenesBefore = await (database.select(
        database.ocptScenesTable,
      )..orderBy([(row) => OrderingTerm.asc(row.position)])).get();
      final streetScene = scenesBefore.firstWhere((row) => row.heading == "EXT. STREET - NIGHT");

      final shotId = await shotListService.createShot(
        database: database,
        screenplayId: screenplayId,
        sceneId: streetScene.id,
      );
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
      expect(shot.position, 0);

      final remainingCoverage = await database.select(database.ocptShotCoveragesTable).get();
      expect(remainingCoverage, isEmpty);

      final snapshot = await shotListService.loadShotList(database: database, screenplayId: screenplayId);
      final orphanSequence = snapshot.sequences.last as OcptOrphanShotSequence;
      expect(orphanSequence.shots.single.id, shotId);
      expect(orphanSequence.shots.single.orphanedHeading, "EXT. STREET - NIGHT");
    },
  );
}
