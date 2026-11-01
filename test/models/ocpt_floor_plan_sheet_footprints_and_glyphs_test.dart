// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_glyph_kind.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_character_colour.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'ocpt_floor_plan_sheet_test_doubles.dart';

/// Run the tests of the floor plan sheet footprints and glyphs.
void main() {
  group("OcptFloorPlanSheet.of — footprints", () {
    test("a symbol with no widthM/heightM of its own draws at the layer's default footprint", () {
      final light = testSymbol(id: "light-1", shotId: "shot-1", layer: OcptFloorPlanLayer.lights);
      final floorPlanSet = caseOf(symbols: [light]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final shape = sheet.symbols.single;
      expect(shape.widthM, greaterThan(0));
      expect(shape.heightM, greaterThan(0));
    });

    test("a symbol with its own footprint keeps it rather than the layer default", () {
      final furniture = testSymbol(
        id: "furn-1",
        layer: OcptFloorPlanLayer.set,
        widthM: 1.2,
        heightM: 0.6,
      );
      final floorPlanSet = caseOf(symbols: [furniture]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      final shape = sheet.symbols.single;
      expect(shape.widthM, 1.2);
      expect(shape.heightM, 0.6);
    });

    test("a wall with no footprint of its own draws long and thin", () {
      final wall = testSymbol(
        id: "wall-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.wall,
      );
      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: caseOf(symbols: [wall]),
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      final shape = sheet.symbols.single;
      expect(shape.widthM, ocptFloorPlanWallDefaultFootprintM.widthM);
      expect(shape.heightM, ocptFloorPlanWallDefaultFootprintM.heightM);
    });

    test("a door with no footprint of its own draws at a standard door's own width", () {
      final door = testSymbol(
        id: "door-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.door,
      );
      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: caseOf(symbols: [door]),
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      final shape = sheet.symbols.single;
      expect(shape.widthM, ocptFloorPlanDoorDefaultFootprintM.widthM);
      expect(shape.heightM, ocptFloorPlanDoorDefaultFootprintM.heightM);
    });

    test("furniture and freeform with no footprint of their own keep the generic square", () {
      final furniture = testSymbol(
        id: "furn-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.furniture,
      );
      final freeform = testSymbol(
        id: "free-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.freeform,
        sortKey: "b",
      );
      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: caseOf(symbols: [furniture, freeform]),
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      for (final shape in sheet.symbols) {
        expect(shape.widthM, ocptFloorPlanDefaultElementFootprintM);
        expect(shape.heightM, ocptFloorPlanDefaultElementFootprintM);
      }
    });

    test("a hand prop keeps its own layer default footprint, unaffected by décor shapes", () {
      final prop = testSymbol(id: "prop-1", shotId: "shot-1", layer: OcptFloorPlanLayer.props);
      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: caseOf(symbols: [prop]),
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final shape = sheet.symbols.single;
      expect(shape.widthM, ocptFloorPlanHandPropFootprintM);
      expect(shape.heightM, ocptFloorPlanHandPropFootprintM);
    });
  });

  group("OcptFloorPlanSheet.of — glyph kind", () {
    test("derives each layer's own glyph kind", () {
      final character = testSymbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
      );
      final camera = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final light = testSymbol(id: "light-1", shotId: "shot-1", layer: OcptFloorPlanLayer.lights);
      final decor = testSymbol(id: "decor-1", layer: OcptFloorPlanLayer.set);
      final floorPlanSet = caseOf(symbols: [character, camera, light, decor]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final kindBySymbolId = {for (final shape in sheet.symbols) shape.symbolId: shape.glyphKind};
      expect(kindBySymbolId["char-1"], OcptFloorPlanSymbolGlyphKind.character);
      expect(kindBySymbolId["cam-1"], OcptFloorPlanSymbolGlyphKind.camera);
      expect(kindBySymbolId["light-1"], OcptFloorPlanSymbolGlyphKind.light);
      expect(kindBySymbolId["decor-1"], OcptFloorPlanSymbolGlyphKind.setElement);
    });
  });

  group("OcptFloorPlanSheet.of — character colour", () {
    test("a character shape's own colour is derived from its label, not the layer palette", () {
      final character = testSymbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
        label: "Sam",
      );
      final floorPlanSet = caseOf(symbols: [character]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.colorArgb, ocptFloorPlanCharacterColourOf("Sam"));
    });

    test("two character shapes of different names draw with the very colour the rule derives", () {
      final sam = testSymbol(
        id: "char-sam",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
        label: "Sam",
      );
      final alex = testSymbol(
        id: "char-alex",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
        label: "Alex",
      );
      final floorPlanSet = caseOf(symbols: [sam, alex]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final colorBySymbolId = {for (final shape in sheet.symbols) shape.symbolId: shape.colorArgb};
      expect(colorBySymbolId["char-sam"], ocptFloorPlanCharacterColourOf("Sam"));
      expect(colorBySymbolId["char-alex"], ocptFloorPlanCharacterColourOf("Alex"));
    });
  });

  group("OcptFloorPlanSheet.of — camera field-of-view wedge", () {
    test("a camera emits a wedge at its own fovDeg while showFieldOfView is on", () {
      final camera = testSymbol(
        id: "cam-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        fovDeg: 35,
      );
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.cameraFovWedgeDeg, 35);
    });

    test("a camera left at the drawing default falls back to the default wedge angle", () {
      final camera = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.cameraFovWedgeDeg, ocptFloorPlanDefaultCameraFovDeg);
    });

    test("no wedge is emitted while showFieldOfView is off", () {
      final camera = testSymbol(
        id: "cam-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        fovDeg: 35,
      );
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
        showFieldOfView: false,
      );

      expect(sheet.symbols.single.cameraFovWedgeDeg, isNull);
    });

    test("a non-camera symbol never carries a wedge", () {
      final light = testSymbol(id: "light-1", shotId: "shot-1", layer: OcptFloorPlanLayer.lights);
      final floorPlanSet = caseOf(symbols: [light]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.cameraFovWedgeDeg, isNull);
    });

    test("a camera emits a wedge at its own fovReachM while showFieldOfView is on", () {
      final camera = testSymbol(
        id: "cam-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        fovReachM: 5,
      );
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.cameraFovWedgeReachM, 5);
    });

    test("a camera left at the drawing default falls back to the default wedge reach", () {
      final camera = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.cameraFovWedgeReachM, ocptFloorPlanCameraFovWedgeLengthM);
    });

    test("no wedge reach is resolved while showFieldOfView is off", () {
      final camera = testSymbol(
        id: "cam-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.cameras,
        fovReachM: 5,
      );
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
        showFieldOfView: false,
      );

      expect(sheet.symbols.single.cameraFovWedgeReachM, isNull);
    });
  });

  group("OcptFloorPlanSheet.of — décor primitive", () {
    test("each own setElementShape carries through to its shape", () {
      final wall = testSymbol(
        id: "wall-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.wall,
      );
      final door = testSymbol(
        id: "door-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.door,
      );
      final furniture = testSymbol(
        id: "furn-1",
        layer: OcptFloorPlanLayer.set,
        setElementShape: OcptFloorPlanSetElementShape.furniture,
      );
      final floorPlanSet = caseOf(symbols: [wall, door, furniture]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
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
      final decor = testSymbol(id: "decor-1", layer: OcptFloorPlanLayer.set);
      final floorPlanSet = caseOf(symbols: [decor]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.symbols.single.setElementShape, OcptFloorPlanSetElementShape.freeform);
    });

    test("a camera, character or light never carries a set-element shape", () {
      final camera = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final floorPlanSet = caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.symbols.single.setElementShape, isNull);
    });
  });

  group("OcptFloorPlanSheet.of — arrow control point", () {
    test("an arrow with a control point carries it into its own shape", () {
      final camera = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final character = testSymbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
      );
      final arrow = testArrow(
        id: "arrow-1",
        shotId: "shot-1",
        fromSymbolId: "char-1",
        toSymbolId: "cam-1",
        ctrlXM: 1.5,
        ctrlYM: -0.5,
      );
      final floorPlanSet = caseOf(symbols: [camera, character], arrows: [arrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final shape = sheet.arrows.single;
      expect(shape.ctrlXM, 1.5);
      expect(shape.ctrlYM, -0.5);
    });

    test("an arrow with no control point draws straight", () {
      final camera = testSymbol(id: "cam-1", shotId: "shot-1", layer: OcptFloorPlanLayer.cameras);
      final character = testSymbol(
        id: "char-1",
        shotId: "shot-1",
        layer: OcptFloorPlanLayer.characters,
      );
      final arrow = testArrow(
        id: "arrow-1",
        shotId: "shot-1",
        fromSymbolId: "char-1",
        toSymbolId: "cam-1",
      );
      final floorPlanSet = caseOf(symbols: [camera, character], arrows: [arrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: "scene-1",
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      final shape = sheet.arrows.single;
      expect(shape.ctrlXM, isNull);
      expect(shape.ctrlYM, isNull);
    });
  });
}
