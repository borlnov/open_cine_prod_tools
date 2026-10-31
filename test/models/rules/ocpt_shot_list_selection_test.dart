// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_list_selection.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

OcptShot _shot({required String id, List<String> characters = const []}) => OcptShot(
  id: id,
  screenplayId: "screenplay-1",
  sceneId: "scene-1",
  orphanedHeading: null,
  position: 0,
  shotSize: "",
  abbreviation: "",
  framing: "",
  cameraMove: "",
  lens: "",
  recordingFormat: "",
  estimatedDurationMs: null,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: OcptShotStatus.toShoot,
  difficultySet: 0,
  difficultyCamera: 0,
  difficultyActing: 0,
  difficultySound: 0,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: characters,
  coverageRanges: const [],
  code: "1/1",
  averageDifficulty: 0,
);

OcptFloorPlanSymbol _symbol({
  required String id,
  String? shotId,
  OcptFloorPlanLayer layer = OcptFloorPlanLayer.characters,
  String label = "",
}) => OcptFloorPlanSymbol(
  id: id,
  setId: "set-1",
  sceneId: null,
  shotId: shotId,
  layer: layer,
  sortKey: "a$id",
  xM: 0,
  yM: 0,
  rotationDeg: 0,
  widthM: null,
  heightM: null,
  fovDeg: null,
  fovReachM: null,
  label: label,
  setElementShape: null,
  overridesSymbolId: null,
  isHidden: false,
);

OcptFloorPlanSymbol _scopedSymbol({
  required String id,
  String? sceneId,
  String? shotId,
  String? overridesSymbolId,
  bool isHidden = false,
}) => OcptFloorPlanSymbol(
  id: id,
  setId: "set-1",
  sceneId: sceneId,
  shotId: shotId,
  layer: OcptFloorPlanLayer.set,
  sortKey: "a$id",
  xM: 0,
  yM: 0,
  rotationDeg: 0,
  widthM: null,
  heightM: null,
  fovDeg: null,
  fovReachM: null,
  label: "",
  setElementShape: null,
  overridesSymbolId: overridesSymbolId,
  isHidden: isHidden,
);

OcptFloorPlanSet _set({String id = "set-1", List<OcptFloorPlanSymbol> symbols = const []}) =>
    OcptFloorPlanSet(
      id: id,
      name: "Cuisine",
      underlayAssetId: null,
      underlayPath: null,
      underlayXM: null,
      underlayYM: null,
      underlayWidthM: null,
      underlayHeightM: null,
      underlayRotationDeg: null,
      symbols: symbols,
      arrows: const [],
    );

OcptSceneShotSequence _sequence({required String sceneId, List<OcptShot> shots = const []}) =>
    OcptSceneShotSequence(
      sceneId: sceneId,
      heading: "INT. KITCHEN - DAY",
      sceneNumber: null,
      displaySceneNumber: "1",
      charStart: 0,
      charEnd: 0,
      shots: shots,
    );

void main() {
  final floorPlans = OcptFloorPlanSnapshot.build(
    screenplayId: "screenplay-1",
    setsBySceneId: {
      "scene-1": [_set(), _set(id: "set-2")],
    },
  );
  final snapshot = OcptShotListSnapshot.build(
    screenplayId: "screenplay-1",
    sequences: [
      _sequence(
        sceneId: "scene-1",
        shots: [
          _shot(id: "shot-1"),
          _shot(id: "shot-2"),
        ],
      ),
      _sequence(sceneId: "scene-2"),
      const OcptOrphanShotSequence(shots: []),
    ],
  );

  group("ocptRevealedSequenceIdOf", () {
    test("names the sequence a live reveal request targets", () {
      const request = OcptShotListRevealRequest(sceneId: "scene-2", setId: "set-1");

      expect(ocptRevealedSequenceIdOf(revealRequest: request, snapshot: snapshot), "scene-2");
    });

    test("reads a dangling or absent request as none", () {
      const dangling = OcptShotListRevealRequest(sceneId: "gone", setId: "set-1");

      expect(ocptRevealedSequenceIdOf(revealRequest: dangling, snapshot: snapshot), isNull);
      expect(ocptRevealedSequenceIdOf(revealRequest: null, snapshot: snapshot), isNull);
    });
  });

  group("ocptRevealedSetIdOf", () {
    test("names the set only while it is linked to the sequence", () {
      const linked = OcptShotListRevealRequest(sceneId: "scene-1", setId: "set-2");
      const elsewhere = OcptShotListRevealRequest(sceneId: "scene-1", setId: "set-9");

      expect(
        ocptRevealedSetIdOf(
          revealRequest: linked,
          floorPlanSnapshot: floorPlans,
          sequenceId: "scene-1",
        ),
        "set-2",
      );
      expect(
        ocptRevealedSetIdOf(
          revealRequest: elsewhere,
          floorPlanSnapshot: floorPlans,
          sequenceId: "scene-1",
        ),
        isNull,
      );
      expect(
        ocptRevealedSetIdOf(revealRequest: linked, floorPlanSnapshot: floorPlans, sequenceId: null),
        isNull,
      );
    });
  });

  group("ocptFirstSetIdOf", () {
    test("is the first tab of a sequence, and null when there is none", () {
      expect(ocptFirstSetIdOf(floorPlanSnapshot: floorPlans, sequenceId: "scene-1"), "set-1");
      expect(ocptFirstSetIdOf(floorPlanSnapshot: floorPlans, sequenceId: "scene-2"), isNull);
      expect(ocptFirstSetIdOf(floorPlanSnapshot: null, sequenceId: "scene-1"), isNull);
      expect(ocptFirstSetIdOf(floorPlanSnapshot: floorPlans, sequenceId: null), isNull);
    });
  });

  group("ocptFirstShotIdOf", () {
    test("is the first shot of a scene sequence, and null otherwise", () {
      expect(ocptFirstShotIdOf(snapshot: snapshot, sequenceId: "scene-1"), "shot-1");
      expect(ocptFirstShotIdOf(snapshot: snapshot, sequenceId: "scene-2"), isNull);
      expect(ocptFirstShotIdOf(snapshot: snapshot, sequenceId: null), isNull);
      expect(ocptFirstShotIdOf(snapshot: null, sequenceId: "scene-1"), isNull);
    });
  });

  group("ocptSequenceHolding", () {
    test("finds the sequence holding a shot, or none", () {
      expect(ocptSequenceHolding(sequences: snapshot.sequences, shotId: "shot-2")?.id, "scene-1");
      expect(ocptSequenceHolding(sequences: snapshot.sequences, shotId: "gone"), isNull);
    });
  });

  group("ocptFloorPlanSymbolById", () {
    test("searches every set of the snapshot", () {
      final withSymbol = OcptFloorPlanSnapshot.build(
        screenplayId: "screenplay-1",
        setsBySceneId: {
          "scene-1": [
            _set(),
            _set(
              id: "set-2",
              symbols: [_symbol(id: "symbol-1")],
            ),
          ],
        },
      );

      expect(
        ocptFloorPlanSymbolById(floorPlanSnapshot: withSymbol, symbolId: "symbol-1")?.id,
        "symbol-1",
      );
      expect(ocptFloorPlanSymbolById(floorPlanSnapshot: withSymbol, symbolId: "x"), isNull);
      expect(ocptFloorPlanSymbolById(floorPlanSnapshot: null, symbolId: "symbol-1"), isNull);
    });
  });

  group("ocptIsFloorPlanSymbolMaskedAt", () {
    OcptFloorPlanSnapshot snapshotOf(List<OcptFloorPlanSymbol> symbols) =>
        OcptFloorPlanSnapshot.build(
          screenplayId: "screenplay-1",
          setsBySceneId: {
            "scene-1": [_set(symbols: symbols)],
          },
        );

    bool isMasked(OcptFloorPlanSnapshot snapshot, {String? sceneId, String? shotId}) =>
        ocptIsFloorPlanSymbolMaskedAt(
          floorPlanSnapshot: snapshot,
          symbolId: "wall",
          sceneId: sceneId,
          shotId: shotId,
        );

    test("a symbol with no hidden override of it, or none at all, is not masked", () {
      final plain = snapshotOf([_scopedSymbol(id: "wall")]);

      expect(isMasked(plain, sceneId: "scene-1"), isFalse);
      expect(
        ocptIsFloorPlanSymbolMaskedAt(
          floorPlanSnapshot: plain,
          symbolId: "gone",
          sceneId: "scene-1",
          shotId: null,
        ),
        isFalse,
      );
      expect(
        ocptIsFloorPlanSymbolMaskedAt(
          floorPlanSnapshot: null,
          symbolId: "wall",
          sceneId: "scene-1",
          shotId: null,
        ),
        isFalse,
      );
    });

    test("a hidden override is a ghost to restore, not itself masked", () {
      final ghost = snapshotOf([_scopedSymbol(id: "wall", isHidden: true)]);

      expect(isMasked(ghost, sceneId: "scene-1"), isFalse);
    });

    test("a hidden override for the sequence masks the symbol there and nowhere else", () {
      final masked = snapshotOf([
        _scopedSymbol(id: "wall"),
        _scopedSymbol(id: "mask", sceneId: "scene-1", overridesSymbolId: "wall", isHidden: true),
      ]);

      expect(isMasked(masked, sceneId: "scene-1"), isTrue);
      expect(isMasked(masked, sceneId: "scene-2"), isFalse);
      expect(isMasked(masked), isFalse);
    });

    test("a hidden override for the shot masks the symbol under that shot alone", () {
      final masked = snapshotOf([
        _scopedSymbol(id: "wall", sceneId: "scene-1"),
        _scopedSymbol(id: "mask", shotId: "shot-1", overridesSymbolId: "wall", isHidden: true),
      ]);

      expect(isMasked(masked, sceneId: "scene-1", shotId: "shot-1"), isTrue);
      expect(isMasked(masked, sceneId: "scene-1", shotId: "shot-2"), isFalse);
      expect(isMasked(masked, sceneId: "scene-1"), isFalse);
    });

    test("a visible override of the symbol masks nothing", () {
      final moved = snapshotOf([
        _scopedSymbol(id: "wall"),
        _scopedSymbol(id: "moved", sceneId: "scene-1", overridesSymbolId: "wall"),
      ]);

      expect(isMasked(moved, sceneId: "scene-1"), isFalse);
    });
  });

  group("ocptFloorPlanArrowExists", () {
    test("searches every set of the snapshot", () {
      final withArrow = OcptFloorPlanSnapshot.build(
        screenplayId: "screenplay-1",
        setsBySceneId: {
          "scene-1": [
            _set(),
            const OcptFloorPlanSet(
              id: "set-2",
              name: "Salon",
              underlayAssetId: null,
              underlayPath: null,
              underlayXM: null,
              underlayYM: null,
              underlayWidthM: null,
              underlayHeightM: null,
              underlayRotationDeg: null,
              symbols: [],
              arrows: [
                OcptFloorPlanArrow(
                  id: "arrow-1",
                  setId: "set-2",
                  shotId: "shot-1",
                  kind: OcptFloorPlanArrowKind.movement,
                  fromSymbolId: "a",
                  toSymbolId: "b",
                  label: "",
                  ctrlXM: null,
                  ctrlYM: null,
                ),
              ],
            ),
          ],
        },
      );

      expect(ocptFloorPlanArrowExists(floorPlanSnapshot: withArrow, arrowId: "arrow-1"), isTrue);
      expect(ocptFloorPlanArrowExists(floorPlanSnapshot: withArrow, arrowId: "x"), isFalse);
      expect(ocptFloorPlanArrowExists(floorPlanSnapshot: null, arrowId: "arrow-1"), isFalse);
    });
  });

  group("ocptDefaultCharacterLabelOf", () {
    test("offers the first character no live symbol of the shot carries yet", () {
      final shot = _shot(id: "shot-1", characters: const ["ALICE", "BOB"]);
      final floorPlanSet = _set(
        symbols: [_symbol(id: "symbol-1", shotId: "shot-1", label: "ALICE")],
      );

      expect(ocptDefaultCharacterLabelOf(shot: shot, floorPlanSet: floorPlanSet), "BOB");
    });

    test("ignores another shot's symbols and falls back to empty when all are placed", () {
      final shot = _shot(id: "shot-1", characters: const ["ALICE"]);
      final otherShot = _set(
        symbols: [_symbol(id: "symbol-1", shotId: "shot-2", label: "ALICE")],
      );
      final allPlaced = _set(
        symbols: [_symbol(id: "symbol-2", shotId: "shot-1", label: "ALICE")],
      );

      expect(ocptDefaultCharacterLabelOf(shot: shot, floorPlanSet: otherShot), "ALICE");
      expect(ocptDefaultCharacterLabelOf(shot: shot, floorPlanSet: allPlaced), "");
      expect(ocptDefaultCharacterLabelOf(shot: null, floorPlanSet: allPlaced), "");
    });
  });
}
