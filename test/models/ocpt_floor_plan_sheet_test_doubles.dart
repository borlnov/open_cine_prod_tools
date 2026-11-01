// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';

/// A symbol with everything but the fields under test defaulted, so each test only spells out
/// what it actually varies.
OcptFloorPlanSymbol testSymbol({
  required String id,
  String? sceneId,
  String? shotId,
  required OcptFloorPlanLayer layer,
  String sortKey = "a",
  double xM = 0,
  double yM = 0,
  double? widthM,
  double? heightM,
  double? fovDeg,
  double? fovReachM,
  String label = "",
  OcptFloorPlanSetElementShape? setElementShape,
  String? overridesSymbolId,
  bool isHidden = false,
}) => OcptFloorPlanSymbol(
  id: id,
  setId: "case-1",
  sceneId: sceneId,
  shotId: shotId,
  layer: layer,
  sortKey: sortKey,
  xM: xM,
  yM: yM,
  rotationDeg: 0,
  widthM: widthM,
  heightM: heightM,
  fovDeg: fovDeg,
  fovReachM: fovReachM,
  label: label,
  setElementShape: setElementShape,
  overridesSymbolId: overridesSymbolId,
  isHidden: isHidden,
);

/// An arrow of shot [shotId] from [fromSymbolId] to [toSymbolId].
OcptFloorPlanArrow testArrow({
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

/// A set holding [symbols] and [arrows], with every other field at its default.
OcptFloorPlanSet caseOf({
  List<OcptFloorPlanSymbol> symbols = const [],
  List<OcptFloorPlanArrow> arrows = const [],
  String? underlayAssetId,
  double? underlayXM,
  double? underlayYM,
  double? underlayWidthM,
  double? underlayHeightM,
}) => OcptFloorPlanSet(
  id: "case-1",
  name: "Kitchen",
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
