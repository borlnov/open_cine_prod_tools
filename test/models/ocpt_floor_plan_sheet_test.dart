// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_character_colour.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

/// A symbol with everything but the fields under test defaulted, so each test only spells out
/// what it actually varies.
OcptFloorPlanSymbol _symbol({
  required String id,
  String? shotId,
  required OcptFloorPlanLayer layer,
  String sortKey = "a",
  double xM = 0,
  double yM = 0,
  double? widthM,
  double? heightM,
  double? fovDeg,
  String label = "",
  OcptFloorPlanSetElementShape? setElementShape,
}) => OcptFloorPlanSymbol(
  id: id,
  setId: "case-1",
  shotId: shotId,
  layer: layer,
  sortKey: sortKey,
  xM: xM,
  yM: yM,
  rotationDeg: 0,
  widthM: widthM,
  heightM: heightM,
  fovDeg: fovDeg,
  label: label,
  setElementShape: setElementShape,
);

OcptFloorPlanArrow _arrow({
  required String id,
  required String shotId,
  required String fromSymbolId,
  required String toSymbolId,
  OcptFloorPlanArrowKind kind = OcptFloorPlanArrowKind.movement,
  double? ctrlXM,
  double? ctrlYM,
}) => OcptFloorPlanArrow(
  id: id,
  setId: "case-1",
  shotId: shotId,
  kind: kind,
  fromSymbolId: fromSymbolId,
  toSymbolId: toSymbolId,
  label: "",
  ctrlXM: ctrlXM,
  ctrlYM: ctrlYM,
);

OcptFloorPlanSet _caseOf({
  List<OcptFloorPlanSymbol> symbols = const [],
  List<OcptFloorPlanArrow> arrows = const [],
  String? underlayAssetId,
  double? underlayXM,
  double? underlayYM,
  double? underlayWidthM,
  double? underlayHeightM,
}) => OcptFloorPlanSet(
  id: "case-1",
  sceneId: "scene-1",
  name: "Kitchen",
  sortKey: "a",
  underlayAssetId: underlayAssetId,
  underlayPath: underlayAssetId == null ? null : "/tmp/underlay.jpg",
  underlayXM: underlayXM,
  underlayYM: underlayYM,
  underlayWidthM: underlayWidthM,
  underlayHeightM: underlayHeightM,
  underlayRotationDeg: null,
  symbols: symbols,
  arrows: arrows,
);

void main() {
  group("OcptFloorPlanSheet.of — sequence scope", () {
    test("always includes sequence-scoped symbols, never ghosted", () {
      final decor = _symbol(id: "decor-1", layer: OcptFloorPlanLayer.set);
      final floorPlanSet = _caseOf(symbols: [decor]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {},
      );

      expect(sheet.symbols, hasLength(1));
      expect(sheet.symbols.single.symbolId, "decor-1");
      expect(sheet.symbols.single.isGhost, isFalse);
    });
  });

  group("OcptFloorPlanSheet.of — sequence focus (focusShotId null)", () {
    test("shows every live camera of every shot, numbered, and nothing else of the shot scope", () {
      final camera1 = _symbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final character1 = _symbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
      );
      final camera2 = _symbol(id: "cam-2", shotId: "shot-2", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = _caseOf(symbols: [camera1, character1, camera2]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {"shot-1": 1, "shot-2": 2},
      );

      final symbolIds = sheet.symbols.map((shape) => shape.symbolId).toSet();
      expect(symbolIds, {"cam-1", "cam-2"});
      expect(sheet.arrows, isEmpty);
    });

    test("numbers several cameras of one shot as rank/letter pairs", () {
      final camera1 = _symbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final camera2 = _symbol(
        id: "cam-2",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        sortKey: "b",
      );
      final floorPlanSet = _caseOf(symbols: [camera1, camera2]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {"shot-1": 3},
      );

      final labelBySymbolId = {
        for (final shape in sheet.symbols) shape.symbolId: shape.cameraLabel,
      };
      expect(labelBySymbolId["cam-1"], "3");
      expect(labelBySymbolId["cam-2"], "3A");
    });

    test("a camera whose shot has no known rank draws with no camera label", () {
      final camera = _symbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = _caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols.single.cameraLabel, isNull);
    });
  });

  group("OcptFloorPlanSheet.of — shot focus", () {
    test("shows the focused shot's own shot layers, not another shot's", () {
      final ownCamera = _symbol(id: "cam-own", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final otherCamera = _symbol(
        id: "cam-other",
        shotId: "shot-2",
        layer: OcptFloorPlanLayer.cameras,
      );
      final floorPlanSet = _caseOf(symbols: [ownCamera, otherCamera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final symbolIds = sheet.symbols.map((shape) => shape.symbolId).toSet();
      expect(symbolIds, {"cam-own"});
    });

    test("draws the previous and next shot's placements as ghosts, and no one else's", () {
      final focusCamera = _symbol(
        id: "cam-focus",
        shotId: "shot-2",
        layer: OcptFloorPlanLayer.cameras,
      );
      final previousCamera = _symbol(
        id: "cam-prev",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
      );
      final nextCamera = _symbol(id: "cam-next", shotId: "shot-3", layer: OcptFloorPlanLayer.cameras);
      final farCamera = _symbol(id: "cam-far", shotId: "shot-9", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = _caseOf(
        symbols: [focusCamera, previousCamera, nextCamera, farCamera],
      );

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-2",
        shotRankByShotId: const {"shot-1": 1, "shot-2": 2, "shot-3": 3},
        previousShotId: "shot-1",
        nextShotId: "shot-3",
      );

      final ghostBySymbolId = {
        for (final shape in sheet.symbols) shape.symbolId: shape.isGhost,
      };
      expect(ghostBySymbolId, {"cam-focus": false, "cam-prev": true, "cam-next": true});
    });

    test("draws an arrow of the focus shot with both endpoints resolved to symbol positions", () {
      final camera = _symbol(
        id: "cam-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        xM: 1,
        yM: 2,
      );
      final character = _symbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
        xM: 4,
        yM: 6,
      );
      final arrow = _arrow(
        id: "arrow-1",
        shotId: "shot-1",
        fromSymbolId: "char-1",
        toSymbolId: "cam-1",
      );
      final floorPlanSet = _caseOf(symbols: [camera, character], arrows: [arrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.arrows, hasLength(1));
      final shape = sheet.arrows.single;
      expect(shape.arrowId, "arrow-1");
      expect(shape.fromXM, 4);
      expect(shape.fromYM, 6);
      expect(shape.toXM, 1);
      expect(shape.toYM, 2);
      expect(shape.isGhost, isFalse);
    });

    test("flags a ghosted neighbour's own arrow as a ghost too", () {
      final previousCamera = _symbol(
        id: "cam-prev",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
      );
      final previousCharacter = _symbol(
        id: "char-prev",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
      );
      final previousArrow = _arrow(
        id: "arrow-prev",
        shotId: "shot-1",
        fromSymbolId: "char-prev",
        toSymbolId: "cam-prev",
      );
      final floorPlanSet = _caseOf(
        symbols: [previousCamera, previousCharacter],
        arrows: [previousArrow],
      );

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-2",
        shotRankByShotId: const {"shot-1": 1, "shot-2": 2},
        previousShotId: "shot-1",
      );

      expect(sheet.arrows.single.isGhost, isTrue);
    });

    test("an arrow of a shot outside the focus and its ghosts is not drawn at all", () {
      final farCameraA = _symbol(id: "cam-a", shotId: "shot-9", layer: OcptFloorPlanLayer.cameras);
      final farCameraB = _symbol(id: "cam-b", shotId: "shot-9", layer: OcptFloorPlanLayer.cameras);
      final farArrow = _arrow(
        id: "arrow-far",
        shotId: "shot-9",
        fromSymbolId: "cam-a",
        toSymbolId: "cam-b",
      );
      final floorPlanSet = _caseOf(symbols: [farCameraA, farCameraB], arrows: [farArrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.arrows, isEmpty);
    });
  });

  group("OcptFloorPlanSheet.of — showAllCameras (R3)", () {
    test("off by default: only the focused shot's own camera draws, not another shot's", () {
      final ownCamera = _symbol(id: "cam-own", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final otherCamera = _symbol(
        id: "cam-other",
        shotId: "shot-9",
        layer: OcptFloorPlanLayer.cameras,
      );
      final floorPlanSet = _caseOf(symbols: [ownCamera, otherCamera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1, "shot-9": 9},
      );

      expect(sheet.symbols.map((symbol) => symbol.symbolId), ["cam-own"]);
    });

    test("on: every other shot's own camera draws too, as a ghost", () {
      final ownCamera = _symbol(id: "cam-own", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final otherCamera = _symbol(
        id: "cam-other",
        shotId: "shot-9",
        layer: OcptFloorPlanLayer.cameras,
      );
      final floorPlanSet = _caseOf(symbols: [ownCamera, otherCamera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1, "shot-9": 9},
        showAllCameras: true,
      );

      expect(sheet.symbols, hasLength(2));
      final own = sheet.symbols.singleWhere((symbol) => symbol.symbolId == "cam-own");
      final other = sheet.symbols.singleWhere((symbol) => symbol.symbolId == "cam-other");
      expect(own.isGhost, isFalse);
      expect(other.isGhost, isTrue);
    });

    test("on: never duplicates a camera already drawn by the focus or the onion skin", () {
      final ownCamera = _symbol(id: "cam-own", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final prevCamera = _symbol(id: "cam-prev", shotId: "shot-0", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = _caseOf(symbols: [ownCamera, prevCamera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-0": 1, "shot-1": 2},
        previousShotId: "shot-0",
        showAllCameras: true,
      );

      expect(sheet.symbols, hasLength(2));
      expect(sheet.symbols.map((symbol) => symbol.symbolId).toSet(), {"cam-own", "cam-prev"});
    });

    test("on: a non-camera symbol of another shot is never added", () {
      final ownCamera = _symbol(id: "cam-own", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final otherCharacter = _symbol(
        id: "char-other",
        shotId: "shot-9",
        layer: OcptFloorPlanLayer.characters,
      );
      final floorPlanSet = _caseOf(symbols: [ownCamera, otherCharacter]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1, "shot-9": 9},
        showAllCameras: true,
      );

      expect(sheet.symbols.map((symbol) => symbol.symbolId), ["cam-own"]);
    });

    test("ignored under the sequence focus (no focused shot): already drawing every camera", () {
      final cameraA = _symbol(id: "cam-a", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final cameraB = _symbol(id: "cam-b", shotId: "shot-2", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = _caseOf(symbols: [cameraA, cameraB]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {"shot-1": 1, "shot-2": 2},
        showAllCameras: true,
      );

      expect(sheet.symbols, hasLength(2));
    });
  });

  group("OcptFloorPlanSheet.of — underlay", () {
    test("draws no underlay while the case's frame is incomplete", () {
      final floorPlanSet = _caseOf(underlayAssetId: "asset-1");

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.underlay, isNull);
    });

    test("draws the underlay once its frame is fully placed", () {
      final floorPlanSet = _caseOf(
        underlayAssetId: "asset-1",
        underlayXM: 1,
        underlayYM: 2,
        underlayWidthM: 3,
        underlayHeightM: 4,
      );

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.underlay, isNotNull);
      expect(sheet.underlay!.assetId, "asset-1");
      expect(sheet.underlay!.path, "/tmp/underlay.jpg");
      expect(sheet.underlay!.widthM, 3);
      expect(sheet.underlay!.heightM, 4);
    });
  });

  group("OcptFloorPlanSheet.of — footprints", () {
    test("a symbol with no widthM/heightM of its own draws at the layer's default footprint", () {
      final light = _symbol(id: "light-1", shotId: "shot-1", layer: OcptFloorPlanLayer.lights);
      final floorPlanSet = _caseOf(symbols: [light]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final shape = sheet.symbols.single;
      expect(shape.widthM, greaterThan(0));
      expect(shape.heightM, greaterThan(0));
    });

    test("a symbol with its own footprint keeps it rather than the layer default", () {
      final furniture = _symbol(
        id: "furn-1",
        layer: OcptFloorPlanLayer.set,
        widthM: 1.2,
        heightM: 0.6,
      );
      final floorPlanSet = _caseOf(symbols: [furniture]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {},
      );

      final shape = sheet.symbols.single;
      expect(shape.widthM, 1.2);
      expect(shape.heightM, 0.6);
    });
  });

  group("OcptFloorPlanSheet.of — glyph kind", () {
    test("derives each layer's own glyph kind", () {
      final character = _symbol(id: "char-1", shotId: "shot-1", layer: OcptFloorPlanLayer.characters);
      final camera = _symbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final light = _symbol(id: "light-1", shotId: "shot-1", layer: OcptFloorPlanLayer.lights);
      final decor = _symbol(id: "decor-1", layer: OcptFloorPlanLayer.set);
      final floorPlanSet = _caseOf(symbols: [character, camera, light, decor]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final kindBySymbolId = {
        for (final shape in sheet.symbols) shape.symbolId: shape.glyphKind,
      };
      expect(kindBySymbolId["char-1"], OcptFloorPlanSymbolGlyphKind.character);
      expect(kindBySymbolId["cam-1"], OcptFloorPlanSymbolGlyphKind.camera);
      expect(kindBySymbolId["light-1"], OcptFloorPlanSymbolGlyphKind.light);
      expect(kindBySymbolId["decor-1"], OcptFloorPlanSymbolGlyphKind.setElement);
    });
  });

  group("OcptFloorPlanSheet.of — character colour", () {
    test("a character shape's own colour is derived from its label, not the layer palette", () {
      final character = _symbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
        label: "Sam",
      );
      final floorPlanSet = _caseOf(symbols: [character]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.colorArgb, ocptFloorPlanCharacterColourOf("Sam"));
    });

    test("two character shapes of different names draw with the very colour the rule derives", () {
      final sam = _symbol(id: "char-sam", shotId: "shot-1", layer: OcptFloorPlanLayer.characters, label: "Sam");
      final alex = _symbol(
        id: "char-alex",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
        label: "Alex",
      );
      final floorPlanSet = _caseOf(symbols: [sam, alex]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final colorBySymbolId = {
        for (final shape in sheet.symbols) shape.symbolId: shape.colorArgb,
      };
      expect(colorBySymbolId["char-sam"], ocptFloorPlanCharacterColourOf("Sam"));
      expect(colorBySymbolId["char-alex"], ocptFloorPlanCharacterColourOf("Alex"));
    });
  });

  group("OcptFloorPlanSheet.of — camera field-of-view wedge", () {
    test("a camera emits a wedge at its own fovDeg while showFieldOfView is on", () {
      final camera = _symbol(
        id: "cam-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        fovDeg: 35,
      );
      final floorPlanSet = _caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.cameraFovWedgeDeg, 35);
    });

    test("a camera left at the drawing default falls back to the default wedge angle", () {
      final camera = _symbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = _caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.cameraFovWedgeDeg, ocptFloorPlanDefaultCameraFovDeg);
    });

    test("no wedge is emitted while showFieldOfView is off", () {
      final camera = _symbol(
        id: "cam-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        fovDeg: 35,
      );
      final floorPlanSet = _caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
        showFieldOfView: false,
      );

      expect(sheet.symbols.single.cameraFovWedgeDeg, isNull);
    });

    test("a non-camera symbol never carries a wedge", () {
      final light = _symbol(id: "light-1", shotId: "shot-1", layer: OcptFloorPlanLayer.lights);
      final floorPlanSet = _caseOf(symbols: [light]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.cameraFovWedgeDeg, isNull);
    });
  });

  group("OcptFloorPlanSheet.of — décor primitive", () {
    test("each own setElementShape carries through to its shape", () {
      final wall = _symbol(
        id: "wall-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.wall,
      );
      final door = _symbol(
        id: "door-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.door,
      );
      final furniture = _symbol(
        id: "furn-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.furniture,
      );
      final floorPlanSet = _caseOf(symbols: [wall, door, furniture]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {},
      );

      final shapeBySymbolId = {
        for (final shape in sheet.symbols) shape.symbolId: shape.setElementShape,
      };
      expect(shapeBySymbolId["wall-1"], OcptFloorPlanSetElementShape.wall);
      expect(shapeBySymbolId["door-1"], OcptFloorPlanSetElementShape.door);
      expect(shapeBySymbolId["furn-1"], OcptFloorPlanSetElementShape.furniture);
    });

    test("a set element with no shape of its own defaults to freeform", () {
      final decor = _symbol(id: "decor-1", layer: OcptFloorPlanLayer.set);
      final floorPlanSet = _caseOf(symbols: [decor]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols.single.setElementShape, OcptFloorPlanSetElementShape.freeform);
    });

    test("a camera, character or light never carries a set-element shape", () {
      final camera = _symbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = _caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.setElementShape, isNull);
    });
  });

  group("OcptFloorPlanSheet.of — arrow control point", () {
    test("an arrow with a control point carries it into its own shape", () {
      final camera = _symbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final character = _symbol(id: "char-1", shotId: "shot-1", layer: OcptFloorPlanLayer.characters);
      final arrow = _arrow(
        id: "arrow-1",
        shotId: "shot-1",
        fromSymbolId: "char-1",
        toSymbolId: "cam-1",
        ctrlXM: 1.5,
        ctrlYM: -0.5,
      );
      final floorPlanSet = _caseOf(symbols: [camera, character], arrows: [arrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final shape = sheet.arrows.single;
      expect(shape.ctrlXM, 1.5);
      expect(shape.ctrlYM, -0.5);
    });

    test("an arrow with no control point draws straight", () {
      final camera = _symbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final character = _symbol(id: "char-1", shotId: "shot-1", layer: OcptFloorPlanLayer.characters);
      final arrow = _arrow(
        id: "arrow-1",
        shotId: "shot-1",
        fromSymbolId: "char-1",
        toSymbolId: "cam-1",
      );
      final floorPlanSet = _caseOf(symbols: [camera, character], arrows: [arrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final shape = sheet.arrows.single;
      expect(shape.ctrlXM, isNull);
      expect(shape.ctrlYM, isNull);
    });
  });
}
