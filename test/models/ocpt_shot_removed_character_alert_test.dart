// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_removed_character_alert.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Builds a shot carrying [characters], everything else left at a neutral value: these tests only
/// read a shot's code and its attached characters.
OcptShot _buildShot({
  required String id,
  required String code,
  required List<String> characters,
}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: "scene",
  orphanedHeading: null,
  position: 0,
  shotSize: "",
  framing: "",
  cameraMove: "",
  lens: "",
  recordingFormat: "",
  estimatedDurationMs: null,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: OcptShotStatus.toShoot,
  difficultySet: 1,
  difficultyCamera: 1,
  difficultyActing: 1,
  difficultySound: 1,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: characters,
  coverageRanges: const [],
  code: code,
  averageDifficulty: 1,
);

/// Builds a scene sequence numbered [displaySceneNumber] holding [shots].
OcptSceneShotSequence _buildSequence({
  required String sceneId,
  required String displaySceneNumber,
  required List<OcptShot> shots,
}) => OcptSceneShotSequence(
  sceneId: sceneId,
  heading: "INT. HOUSE - DAY",
  sceneNumber: displaySceneNumber,
  displaySceneNumber: displaySceneNumber,
  charStart: 0,
  charEnd: 40,
  shots: shots,
);

void main() {
  final snapshot = OcptShotListSnapshot.build(
    screenplayId: "screenplay",
    sequences: [
      _buildSequence(
        sceneId: "scene-1",
        displaySceneNumber: "1",
        shots: [
          _buildShot(id: "shot-1", code: "1/1", characters: const ["LÉA"]),
          _buildShot(id: "shot-2", code: "1/4", characters: const ["LÉA", "CLARA"]),
        ],
      ),
      _buildSequence(
        sceneId: "scene-3",
        displaySceneNumber: "3",
        shots: [
          _buildShot(id: "shot-3", code: "3/1", characters: const ["CLARA"]),
          _buildShot(id: "shot-4", code: "3/2", characters: const ["CLARA", "MARC"]),
        ],
      ),
    ],
  );

  group("OcptShotRemovedCharacterAlert.buildAll", () {
    test("reports every character no longer speaking, with the shots still carrying it", () {
      final alerts = OcptShotRemovedCharacterAlert.buildAll(
        snapshot: snapshot,
        screenplayCharacters: const ["LÉA", "MARC"],
      );

      expect(alerts.length, 1);
      expect(alerts.single.characterName, "CLARA");
      // The codes read in the shot list's own display order, sequence by sequence.
      expect(alerts.single.shotCodes, ["1/4", "3/1", "3/2"]);
    });

    test("reports nothing while every attached character still speaks", () {
      final alerts = OcptShotRemovedCharacterAlert.buildAll(
        snapshot: snapshot,
        screenplayCharacters: const ["LÉA", "CLARA", "MARC"],
      );

      expect(alerts, isEmpty);
    });

    test("sorts several removed characters by name, so the banners keep a stable order", () {
      final alerts = OcptShotRemovedCharacterAlert.buildAll(
        snapshot: snapshot,
        screenplayCharacters: const [],
      );

      expect(alerts.map((alert) => alert.characterName), ["CLARA", "LÉA", "MARC"]);
      expect(alerts.last.shotCodes, ["3/2"]);
    });

    test("reports nothing while no shot list is loaded yet", () {
      expect(
        OcptShotRemovedCharacterAlert.buildAll(snapshot: null, screenplayCharacters: const ["LÉA"]),
        isEmpty,
      );
    });
  });
}
