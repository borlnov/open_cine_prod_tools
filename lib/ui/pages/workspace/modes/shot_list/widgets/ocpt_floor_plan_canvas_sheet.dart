// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/painting.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_metric_line.dart';

/// The sheet a floor plan canvas draws for [floorPlanSet], under [focusShotId]'s own focus,
/// filtered to [hiddenLayers] and [hiddenCameraSymbolIds] — applied to every camera shape alike,
/// the focused shot's own or an onion-skin ghost's (the bug this once had: the filter used to run
/// only under the old `Sequence` focus — there is always a current shot now, so it silently
/// stopped applying at all). The onion skin's own ghost shots ([previousShotId]/[nextShotId]) are
/// passed to `OcptFloorPlanSheet.of` only while their own tray toggle is on
/// ([isOnionSkinPreviousShown]/[isOnionSkinNextShown]), so a hidden neighbour draws nothing at all
/// rather than a ghost the canvas then has to filter back out.
OcptFloorPlanSheet ocptFloorPlanVisibleSheetOf({
  required OcptFloorPlanSet floorPlanSet,
  required String focusSceneId,
  required String? focusShotId,
  required Map<String, int> shotRankByShotId,
  required String? previousShotId,
  required String? nextShotId,
  required bool isOnionSkinPreviousShown,
  required bool isOnionSkinNextShown,
  required bool showFieldOfView,
  required Set<OcptFloorPlanLayer> hiddenLayers,
  required Set<String> hiddenCameraSymbolIds,
}) {
  final full = OcptFloorPlanSheet.of(
    floorPlanSet: floorPlanSet,
    focusSceneId: focusSceneId,
    focusShotId: focusShotId,
    shotRankByShotId: shotRankByShotId,
    previousShotId: isOnionSkinPreviousShown ? previousShotId : null,
    nextShotId: isOnionSkinNextShown ? nextShotId : null,
    showFieldOfView: showFieldOfView,
  );

  return OcptFloorPlanSheet(
    setId: full.setId,
    setName: full.setName,
    underlay: full.underlay,
    symbols: [
      for (final symbol in full.symbols)
        if (!hiddenLayers.contains(symbol.layer) &&
            !(symbol.layer == OcptFloorPlanLayer.cameras &&
                hiddenCameraSymbolIds.contains(symbol.symbolId)))
          symbol,
    ],
    arrows: full.arrows,
  );
}

/// The metrics overlay's own lines, from [selected] to every other symbol [sheet] draws — empty
/// while the overlay is off ([isMetricsShown]) or nothing is selected.
List<OcptFloorPlanMetricLine> ocptFloorPlanMetricLinesOf({
  required OcptFloorPlanSheet sheet,
  required OcptFloorPlanSymbolShape? selected,
  required bool isMetricsShown,
  required Tr tr,
}) {
  if (!isMetricsShown || selected == null) {
    return const [];
  }

  return [
    for (final other in sheet.symbols)
      if (other.symbolId != selected.symbolId)
        OcptFloorPlanMetricLine(
          fromXM: selected.xM,
          fromYM: selected.yM,
          toXM: other.xM,
          toYM: other.yM,
          label: tr.shotListFloorPlanScaleBarLengthLabel(
            ocptFloorPlanScaleBarLengthLabelOf(
              _roundToOneDecimetre(
                ocptFloorPlanDistanceM(
                  x1M: selected.xM,
                  y1M: selected.yM,
                  x2M: other.xM,
                  y2M: other.yM,
                ),
              ),
            ),
          ),
        ),
  ];
}

/// [metres] rounded to the nearest tenth, for the metrics overlay's own labels — the distance
/// rule ([ocptFloorPlanDistanceM]) is exact, but a floor plan is never measured that precisely.
double _roundToOneDecimetre(double metres) => (metres * 10).round() / 10;

/// The symbol [symbolId] names out of [sheet], or null while none is selected or it isn't
/// (currently) visible.
OcptFloorPlanSymbolShape? ocptFloorPlanSymbolOf(OcptFloorPlanSheet sheet, String? symbolId) {
  if (symbolId == null) {
    return null;
  }
  for (final symbol in sheet.symbols) {
    if (symbol.symbolId == symbolId) {
      return symbol;
    }
  }
  return null;
}

/// The arrow [arrowId] names out of [sheet], or null while none is selected or it isn't
/// (currently) visible — [ocptFloorPlanSymbolOf]'s own equivalent for arrows.
OcptFloorPlanArrowShape? ocptFloorPlanArrowOf(OcptFloorPlanSheet sheet, String? arrowId) {
  if (arrowId == null) {
    return null;
  }
  for (final arrow in sheet.arrows) {
    if (arrow.arrowId == arrowId) {
      return arrow;
    }
  }
  return null;
}

/// The underlay's own screen rect, un-rotated (its rotation is applied by a `Transform.rotate`
/// wrapping whichever widget this sizes), from [frame] — the live frame of an underlay drag in
/// progress — or [floorPlanSet]'s own stored one.
Rect ocptFloorPlanUnderlayScreenRect({
  required OcptFloorPlanSet floorPlanSet,
  required ({double xM, double yM, double widthM, double heightM})? frame,
  required Size canvasSize,
  required double zoom,
  required Offset pan,
}) {
  final xM = frame?.xM ?? floorPlanSet.underlayXM ?? 0;
  final yM = frame?.yM ?? floorPlanSet.underlayYM ?? 0;
  final widthM = frame?.widthM ?? floorPlanSet.underlayWidthM ?? 0;
  final heightM = frame?.heightM ?? floorPlanSet.underlayHeightM ?? 0;
  final centre = ocptFloorPlanScreenPointOf(
    xM: xM,
    yM: yM,
    canvasSize: canvasSize,
    zoom: zoom,
    pan: pan,
  );
  final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
  final widthPx = widthM * pixelsPerMetre;
  final heightPx = heightM * pixelsPerMetre;
  return Rect.fromCenter(center: centre, width: widthPx, height: heightPx);
}
