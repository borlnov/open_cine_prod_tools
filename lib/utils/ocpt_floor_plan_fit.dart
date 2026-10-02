// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

/// A floor plan sheet's own tight bounding box, in metres, or null while it draws nothing at all
/// (an empty plan — no set-scope symbol, no arrow, no underlay): there is no room to fit a
/// viewport to.
///
/// Every symbol's own rotated bounding box is unioned in (a wall standing at 90° reaches as far
/// sideways as it does lengthwise unrotated), together with every arrow's own two ends and its
/// bezier control point when it is curved, and the underlay's own frame — the empty-state
/// gallery's own thumbnail is the one caller today
/// ([ocptFloorPlanFitOf]), but this is the plain geometric fact a floor plan sheet draws, useful
/// wherever a viewport needs to fit its content.
({double minXM, double minYM, double maxXM, double maxYM})? ocptFloorPlanContentBoundsOf(
  OcptFloorPlanSheet sheet,
) {
  double? minX;
  double? minY;
  double? maxX;
  double? maxY;

  void expand(double x, double y) {
    minX = minX == null ? x : math.min(minX!, x);
    minY = minY == null ? y : math.min(minY!, y);
    maxX = maxX == null ? x : math.max(maxX!, x);
    maxY = maxY == null ? y : math.max(maxY!, y);
  }

  for (final symbol in sheet.symbols) {
    final halfWidthM = symbol.widthM / 2;
    final halfHeightM = symbol.heightM / 2;
    final radians = symbol.rotationDeg * math.pi / 180;
    final cosA = math.cos(radians).abs();
    final sinA = math.sin(radians).abs();
    final extentXM = halfWidthM * cosA + halfHeightM * sinA;
    final extentYM = halfWidthM * sinA + halfHeightM * cosA;
    expand(symbol.xM - extentXM, symbol.yM - extentYM);
    expand(symbol.xM + extentXM, symbol.yM + extentYM);
  }

  for (final arrow in sheet.arrows) {
    expand(arrow.fromXM, arrow.fromYM);
    expand(arrow.toXM, arrow.toYM);
    final ctrlXM = arrow.ctrlXM;
    final ctrlYM = arrow.ctrlYM;
    if (ctrlXM != null && ctrlYM != null) {
      expand(ctrlXM, ctrlYM);
    }
  }

  final underlay = sheet.underlay;
  if (underlay != null) {
    expand(underlay.xM - underlay.widthM / 2, underlay.yM - underlay.heightM / 2);
    expand(underlay.xM + underlay.widthM / 2, underlay.yM + underlay.heightM / 2);
  }

  final resolvedMinX = minX;
  final resolvedMinY = minY;
  final resolvedMaxX = maxX;
  final resolvedMaxY = maxY;
  if (resolvedMinX == null || resolvedMinY == null || resolvedMaxX == null || resolvedMaxY == null) {
    return null;
  }

  return (minXM: resolvedMinX, minYM: resolvedMinY, maxXM: resolvedMaxX, maxYM: resolvedMaxY);
}

/// The zoom and pan — this canvas's own convention (`ocpt_floor_plan_canvas_painter.dart`'s
/// `ocptFloorPlanScreenPointOf`: metres `(0, 0)` at the viewport's own centre before `pan`, in
/// logical pixels) — that fit [sheet]'s own [ocptFloorPlanContentBoundsOf] inside a viewport
/// [viewportWidthPx] × [viewportHeightPx], centred, with [marginPx] of breathing room on every
/// side and never zooming in past [maxZoom] for a very small room.
///
/// An empty sheet (no bounds at all) or a degenerate (zero or negative) viewport size returns the
/// neutral `zoom: 1.0, panXPx: 0, panYPx: 0` unchanged — the caller (the empty-state gallery's own
/// card) is the one that decides an empty sheet draws its own
/// "empty" placeholder instead of a painted, pointlessly-neutral canvas.
({double zoom, double panXPx, double panYPx}) ocptFloorPlanFitOf({
  required OcptFloorPlanSheet sheet,
  required double viewportWidthPx,
  required double viewportHeightPx,
  double marginPx = 8,
  double maxZoom = 3,
}) {
  const neutral = (zoom: 1.0, panXPx: 0.0, panYPx: 0.0);

  final bounds = ocptFloorPlanContentBoundsOf(sheet);
  if (bounds == null || viewportWidthPx <= 0 || viewportHeightPx <= 0) {
    return neutral;
  }

  final contentWidthM = math.max(bounds.maxXM - bounds.minXM, 0.01);
  final contentHeightM = math.max(bounds.maxYM - bounds.minYM, 0.01);
  final availableWidthPx = math.max(viewportWidthPx - marginPx * 2, 1);
  final availableHeightPx = math.max(viewportHeightPx - marginPx * 2, 1);

  final pixelsPerMetreForWidth = availableWidthPx / contentWidthM;
  final pixelsPerMetreForHeight = availableHeightPx / contentHeightM;
  final pixelsPerMetre = math.min(pixelsPerMetreForWidth, pixelsPerMetreForHeight);
  final zoom = (pixelsPerMetre / ocptFloorPlanBasePixelsPerMetre).clamp(0.0, maxZoom);
  final resolvedPixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);

  final contentCentreXM = (bounds.minXM + bounds.maxXM) / 2;
  final contentCentreYM = (bounds.minYM + bounds.maxYM) / 2;

  return (
    zoom: zoom,
    panXPx: -contentCentreXM * resolvedPixelsPerMetre,
    panYPx: -contentCentreYM * resolvedPixelsPerMetre,
  );
}
