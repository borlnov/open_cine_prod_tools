// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_unlink_counts.dart';

/// A minimal live symbol, every geometry field defaulted since this rule reads none of them.
OcptFloorPlanSymbol _symbol({
  required String id,
  required OcptFloorPlanLayer layer,
  String? sceneId,
  String? shotId,
}) => OcptFloorPlanSymbol(
  id: id,
  setId: "set-1",
  sceneId: sceneId,
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
  label: "",
  setElementShape: null,
  overridesSymbolId: null,
);

OcptFloorPlanSet _setOf(List<OcptFloorPlanSymbol> symbols) => OcptFloorPlanSet(
  id: "set-1",
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

void main() {
  group("ocptFloorPlanUnlinkCountsOf", () {
    test("counts every category with nothing placed", () {
      final counts = ocptFloorPlanUnlinkCountsOf(
        floorPlanSet: _setOf(const []),
        sceneId: "scene-1",
        shotIdsOfScene: const {},
      );

      expect(counts, (cameras: 0, characters: 0, props: 0));
    });

    test("counts a shot's own cameras, characters and props", () {
      final symbols = [
        _symbol(id: "cam-1", layer: OcptFloorPlanLayer.cameras, shotId: "shot-1"),
        _symbol(id: "cam-2", layer: OcptFloorPlanLayer.cameras, shotId: "shot-2"),
        _symbol(id: "char-1", layer: OcptFloorPlanLayer.characters, shotId: "shot-1"),
        _symbol(id: "prop-1", layer: OcptFloorPlanLayer.props, shotId: "shot-1"),
      ];

      final counts = ocptFloorPlanUnlinkCountsOf(
        floorPlanSet: _setOf(symbols),
        sceneId: "scene-1",
        shotIdsOfScene: {"shot-1", "shot-2"},
      );

      expect(counts, (cameras: 2, characters: 1, props: 1));
    });

    test("counts a scene-scope prop too, added to a shot-scope one", () {
      final symbols = [
        _symbol(id: "prop-1", layer: OcptFloorPlanLayer.props, shotId: "shot-1"),
        _symbol(id: "prop-2", layer: OcptFloorPlanLayer.props, sceneId: "scene-1"),
      ];

      final counts = ocptFloorPlanUnlinkCountsOf(
        floorPlanSet: _setOf(symbols),
        sceneId: "scene-1",
        shotIdsOfScene: {"shot-1"},
      );

      expect(counts.props, 2);
    });

    test("never counts a set-scope symbol", () {
      final symbols = [_symbol(id: "wall-1", layer: OcptFloorPlanLayer.set)];

      final counts = ocptFloorPlanUnlinkCountsOf(
        floorPlanSet: _setOf(symbols),
        sceneId: "scene-1",
        shotIdsOfScene: const {},
      );

      expect(counts, (cameras: 0, characters: 0, props: 0));
    });

    test("never counts another sequence's own shot or scene-scope symbol", () {
      final symbols = [
        _symbol(id: "cam-1", layer: OcptFloorPlanLayer.cameras, shotId: "other-shot"),
        _symbol(id: "prop-1", layer: OcptFloorPlanLayer.props, sceneId: "other-scene"),
        _symbol(id: "light-1", layer: OcptFloorPlanLayer.lights, shotId: "shot-1"),
      ];

      final counts = ocptFloorPlanUnlinkCountsOf(
        floorPlanSet: _setOf(symbols),
        sceneId: "scene-1",
        shotIdsOfScene: {"shot-1"},
      );

      expect(counts, (cameras: 0, characters: 0, props: 0));
    });
  });
}
