// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_case.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';

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
  String label = "",
}) => OcptFloorPlanSymbol(
  id: id,
  caseId: "case-1",
  shotId: shotId,
  layer: layer,
  sortKey: sortKey,
  xM: xM,
  yM: yM,
  rotationDeg: 0,
  widthM: widthM,
  heightM: heightM,
  fovDeg: null,
  label: label,
);

OcptFloorPlanArrow _arrow({
  required String id,
  required String shotId,
  required String fromSymbolId,
  required String toSymbolId,
  OcptFloorPlanArrowKind kind = OcptFloorPlanArrowKind.movement,
}) => OcptFloorPlanArrow(
  id: id,
  caseId: "case-1",
  shotId: shotId,
  kind: kind,
  fromSymbolId: fromSymbolId,
  toSymbolId: toSymbolId,
  label: "",
);

OcptFloorPlanCase _caseOf({
  List<OcptFloorPlanSymbol> symbols = const [],
  List<OcptFloorPlanArrow> arrows = const [],
  String? underlayAssetId,
  double? underlayXM,
  double? underlayYM,
  double? underlayWidthM,
  double? underlayHeightM,
}) => OcptFloorPlanCase(
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
      final decor = _symbol(id: "decor-1", layer: OcptFloorPlanLayer.decor);
      final floorPlanCase = _caseOf(symbols: [decor]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(symbols: [camera1, character1, camera2]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(symbols: [camera1, camera2]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(symbols: [camera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(symbols: [ownCamera, otherCamera]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(
        symbols: [focusCamera, previousCamera, nextCamera, farCamera],
      );

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(symbols: [camera, character], arrows: [arrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(
        symbols: [previousCamera, previousCharacter],
        arrows: [previousArrow],
      );

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(symbols: [farCameraA, farCameraB], arrows: [farArrow]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
        focusShotId: "shot-1",
        shotRankByShotId: const {"shot-1": 1},
      );

      expect(sheet.arrows, isEmpty);
    });
  });

  group("OcptFloorPlanSheet.of — underlay", () {
    test("draws no underlay while the case's frame is incomplete", () {
      final floorPlanCase = _caseOf(underlayAssetId: "asset-1");

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
        focusShotId: null,
        shotRankByShotId: const {},
      );

      expect(sheet.underlay, isNull);
    });

    test("draws the underlay once its frame is fully placed", () {
      final floorPlanCase = _caseOf(
        underlayAssetId: "asset-1",
        underlayXM: 1,
        underlayYM: 2,
        underlayWidthM: 3,
        underlayHeightM: 4,
      );

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
      final floorPlanCase = _caseOf(symbols: [light]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
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
        layer: OcptFloorPlanLayer.furniture,
        widthM: 1.2,
        heightM: 0.6,
      );
      final floorPlanCase = _caseOf(symbols: [furniture]);

      final sheet = OcptFloorPlanSheet.of(
        floorPlanCase: floorPlanCase,
        focusShotId: null,
        shotRankByShotId: const {},
      );

      final shape = sheet.symbols.single;
      expect(shape.widthM, 1.2);
      expect(shape.heightM, 0.6);
    });
  });
}
