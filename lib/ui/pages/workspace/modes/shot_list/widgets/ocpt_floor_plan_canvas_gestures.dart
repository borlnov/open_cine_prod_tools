// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_symbol_drag_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_constants.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';

/// How many segments a curved arrow's own quadratic bezier is subdivided into for
/// [ocptFloorPlanDistanceToArrowM]'s own hit test — coarse enough to stay cheap on every tap, fine
/// enough that the sampled polyline never visibly diverges from the drawn curve.
const int _arrowCurveHitTestSamples = 12;

/// Get the geometry [symbol] is drawn with: [liveOverride] while it names [symbol] (the symbol is
/// being
/// dragged), the symbol's own stored geometry otherwise.
OcptFloorPlanSymbolLiveOverride ocptFloorPlanSymbolGeometryOf(
  OcptFloorPlanSymbolShape symbol,
  OcptFloorPlanSymbolLiveOverride? liveOverride,
) {
  if (liveOverride != null && liveOverride.symbolId == symbol.symbolId) {
    return liveOverride;
  }
  return OcptFloorPlanSymbolLiveOverride(
    symbolId: symbol.symbolId,
    xM: symbol.xM,
    yM: symbol.yM,
    widthM: symbol.widthM,
    heightM: symbol.heightM,
    rotationDeg: symbol.rotationDeg,
  );
}

/// Get [override] after a move or resize drag by [screenDelta] logical pixels, or null for any
/// other
/// [kind] — those are not driven by a pointer delta.
///
/// The move handle's own `GestureDetector` is wrapped in a `Transform.rotate`, so Flutter hands
/// [screenDelta] already expressed in that rotated **local** frame (the hit-test transform a drag's
/// own `onPanUpdate` reads is the one captured at `onPanStart`, and stays the rotated one for the
/// whole gesture) — it has to be turned back into the **world** frame a symbol's `xM`/`yM` are
/// stored in before it is added, by [ocptFloorPlanRotateVector]'s own forward convention
/// (`+rotationDeg`, local → world; the resize branch instead turns a genuinely world-frame delta
/// *into* the symbol's own local width/height axes, hence its own `-rotationDeg`). At
/// `rotationDeg == 0` the two frames coincide, which is why an unrotated symbol never showed the
/// drift. Every drag handle's own `dragStartBehavior: DragStartBehavior.down` is the other half of
/// the fix: left at its default (`.start`), the pointer movement spent recognising the gesture as
/// a drag at all (crossing the touch slop) is silently dropped from ever reaching an
/// `onPanUpdate`, so the dragged point permanently trails the pointer by that amount — the "slight
/// offset" on every drag alike, unrelated to rotation.
OcptFloorPlanSymbolLiveOverride? ocptFloorPlanSymbolDraggedBy({
  required OcptFloorPlanSymbolLiveOverride override,
  required OcptFloorPlanSymbolDragKind kind,
  required Offset screenDelta,
  required double zoom,
}) {
  final metresDelta = ocptFloorPlanScreenVectorToMetres(screenDelta: screenDelta, zoom: zoom);

  if (kind == OcptFloorPlanSymbolDragKind.move) {
    final worldDelta = ocptFloorPlanRotateVector(metresDelta, override.rotationDeg);
    return OcptFloorPlanSymbolLiveOverride(
      symbolId: override.symbolId,
      xM: override.xM + worldDelta.dx,
      yM: override.yM + worldDelta.dy,
      widthM: override.widthM,
      heightM: override.heightM,
      rotationDeg: override.rotationDeg,
    );
  }

  if (kind == OcptFloorPlanSymbolDragKind.resize) {
    final local = ocptFloorPlanRotateVector(metresDelta, -override.rotationDeg);
    return OcptFloorPlanSymbolLiveOverride(
      symbolId: override.symbolId,
      xM: override.xM,
      yM: override.yM,
      widthM: math.max(ocptFloorPlanMinSymbolFootprintM, override.widthM + 2 * local.dx),
      heightM: math.max(ocptFloorPlanMinSymbolFootprintM, override.heightM + 2 * local.dy),
      rotationDeg: override.rotationDeg,
    );
  }

  return null;
}

/// Get [override] with its own rotation (bearing) set from the pointer's own bearing around the
/// symbol's centre (0° pointing up, clockwise positive — see `ocptFloorPlanRotateVector`'s own doc
/// comment for the same screen convention read the other way), **[localPosition] already converted
/// to canvas space** — the handle's own local position is relative to that tiny hit box rather
/// than to the canvas the symbol's own centre is placed in, so a bearing computed from it would
/// bear no relation to where the pointer actually is. [isSnapping] (`Shift` held) snaps the
/// result to [ocptFloorPlanRotateSnapStepDeg]° steps.
OcptFloorPlanSymbolLiveOverride ocptFloorPlanSymbolAimedAt({
  required OcptFloorPlanSymbolLiveOverride override,
  required Offset localPosition,
  required Size canvasSize,
  required double zoom,
  required Offset pan,
  required bool isSnapping,
}) {
  final centreScreen = ocptFloorPlanScreenPointOf(
    xM: override.xM,
    yM: override.yM,
    canvasSize: canvasSize,
    zoom: zoom,
    pan: pan,
  );
  final pointerVector = localPosition - centreScreen;
  var bearingDeg = math.atan2(pointerVector.dx, -pointerVector.dy) * 180 / math.pi;
  bearingDeg = bearingDeg < 0 ? bearingDeg + 360 : bearingDeg;
  if (isSnapping) {
    bearingDeg =
        (bearingDeg / ocptFloorPlanRotateSnapStepDeg).round() *
        ocptFloorPlanRotateSnapStepDeg %
        360;
  }

  return OcptFloorPlanSymbolLiveOverride(
    symbolId: override.symbolId,
    xM: override.xM,
    yM: override.yM,
    widthM: override.widthM,
    heightM: override.heightM,
    rotationDeg: bearingDeg,
  );
}

/// Get [override] with its own field-of-view angle set from the pointer's own bearing around the
/// symbol's centre, in **canvas space** ([localPosition], converted as for
/// [ocptFloorPlanSymbolAimedAt]), turned into the symbol's own **local** frame (`-rotationDeg`,
/// undoing its own heading) so `0°` always means "straight ahead" whichever way the camera itself
/// is aimed — the wedge's own half-angle is simply that local bearing's absolute value, doubled
/// and clamped.
OcptFloorPlanSymbolLiveOverride ocptFloorPlanSymbolFovDraggedTo({
  required OcptFloorPlanSymbolLiveOverride override,
  required Offset localPosition,
  required Size canvasSize,
  required double zoom,
  required Offset pan,
}) {
  final centreScreen = ocptFloorPlanScreenPointOf(
    xM: override.xM,
    yM: override.yM,
    canvasSize: canvasSize,
    zoom: zoom,
    pan: pan,
  );
  final pointerVector = localPosition - centreScreen;
  final worldBearingRad = math.atan2(pointerVector.dx, -pointerVector.dy);
  final localBearingRad = worldBearingRad - override.rotationDeg * math.pi / 180;
  final halfAngleDeg = (localBearingRad * 180 / math.pi).abs() % 360;
  final fovDeg = (2 * halfAngleDeg).clamp(
    ocptFloorPlanMinCameraFovDeg,
    ocptFloorPlanMaxCameraFovDeg,
  );

  return OcptFloorPlanSymbolLiveOverride(
    symbolId: override.symbolId,
    xM: override.xM,
    yM: override.yM,
    widthM: override.widthM,
    heightM: override.heightM,
    rotationDeg: override.rotationDeg,
    fovDeg: fovDeg,
  );
}

/// Get [override] with its own field-of-view reach (the wedge's own axial height/depth) set from
/// the
/// pointer's own distance from the symbol's centre, projected onto its own heading vector (so a
/// pointer straying sideways still reads as a forward/backward depth rather than snapping — the
/// wedge's own half-width at that depth is for the edge handles' own corners to derive, never this
/// drag's concern), in **canvas space** ([localPosition], converted as for
/// [ocptFloorPlanSymbolAimedAt]), minus the half-footprint already between the centre and the lens
/// — clamped to [ocptFloorPlanMinCameraFovReachM]..[ocptFloorPlanMaxCameraFovReachM].
OcptFloorPlanSymbolLiveOverride ocptFloorPlanSymbolFovReachDraggedTo({
  required OcptFloorPlanSymbolLiveOverride override,
  required Offset localPosition,
  required Size canvasSize,
  required double zoom,
  required Offset pan,
}) {
  final centreScreen = ocptFloorPlanScreenPointOf(
    xM: override.xM,
    yM: override.yM,
    canvasSize: canvasSize,
    zoom: zoom,
    pan: pan,
  );
  final pointerVector = localPosition - centreScreen;
  final headingRad = override.rotationDeg * math.pi / 180;
  final headingVector = Offset(math.sin(headingRad), -math.cos(headingRad));
  final forwardPx = pointerVector.dx * headingVector.dx + pointerVector.dy * headingVector.dy;
  final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
  final fovReachM = (forwardPx / pixelsPerMetre - override.heightM / 2).clamp(
    ocptFloorPlanMinCameraFovReachM,
    ocptFloorPlanMaxCameraFovReachM,
  );

  return OcptFloorPlanSymbolLiveOverride(
    symbolId: override.symbolId,
    xM: override.xM,
    yM: override.yM,
    widthM: override.widthM,
    heightM: override.heightM,
    rotationDeg: override.rotationDeg,
    fovReachM: fovReachM,
  );
}

/// Get the id of the closest editable (non-ghost) arrow of [sheet] whose own shaft (straight or
/// curved) comes within [ocptFloorPlanArrowHitTolerancePx] of the point [xM]/[yM] (set metres), or
/// null while none does.
String? ocptFloorPlanArrowHitAt(OcptFloorPlanSheet sheet, double xM, double yM, double zoom) {
  final thresholdM = ocptFloorPlanPixelsToMetres(
    pixels: ocptFloorPlanArrowHitTolerancePx,
    zoom: zoom,
  );
  String? bestId;
  var bestDistanceM = thresholdM;

  for (final arrow in sheet.arrows) {
    if (arrow.isGhost) {
      continue;
    }
    final distanceM = ocptFloorPlanDistanceToArrowM(arrow, xM, yM);
    if (distanceM <= bestDistanceM) {
      bestDistanceM = distanceM;
      bestId = arrow.arrowId;
    }
  }

  return bestId;
}

/// Get the shortest distance, in metres, from point [xM]/[yM] to [arrow]'s own shaft: a straight
/// point-to-segment distance while it carries no control point, otherwise the smallest
/// point-to-segment distance over [_arrowCurveHitTestSamples] chords approximating its own
/// quadratic bezier — the same curve `OcptFloorPlanCanvasPainter._paintArrow` draws.
double ocptFloorPlanDistanceToArrowM(OcptFloorPlanArrowShape arrow, double xM, double yM) {
  if (arrow.ctrlXM == null || arrow.ctrlYM == null) {
    return ocptFloorPlanDistanceToSegmentM(
      xM,
      yM,
      arrow.fromXM,
      arrow.fromYM,
      arrow.toXM,
      arrow.toYM,
    );
  }

  var previous = Offset(arrow.fromXM, arrow.fromYM);
  var minDistanceM = double.infinity;
  for (var i = 1; i <= _arrowCurveHitTestSamples; i++) {
    final point = _quadraticBezierPointM(arrow, i / _arrowCurveHitTestSamples);
    final distanceM = ocptFloorPlanDistanceToSegmentM(
      xM,
      yM,
      previous.dx,
      previous.dy,
      point.dx,
      point.dy,
    );
    if (distanceM < minDistanceM) {
      minDistanceM = distanceM;
    }
    previous = point;
  }
  return minDistanceM;
}

/// Get [arrow]'s own quadratic bezier point at parameter [t] (0 = [OcptFloorPlanArrowShape.fromXM]/
/// `.fromYM`, 1 = `.toXM`/`.toYM`), through its own control point — requires
/// [OcptFloorPlanArrowShape.ctrlXM]/`.ctrlYM` to be set.
Offset _quadraticBezierPointM(OcptFloorPlanArrowShape arrow, double t) {
  final oneMinusT = 1 - t;
  final ctrlXM = arrow.ctrlXM!;
  final ctrlYM = arrow.ctrlYM!;
  return Offset(
    oneMinusT * oneMinusT * arrow.fromXM + 2 * oneMinusT * t * ctrlXM + t * t * arrow.toXM,
    oneMinusT * oneMinusT * arrow.fromYM + 2 * oneMinusT * t * ctrlYM + t * t * arrow.toYM,
  );
}

/// Get the shortest distance from point [px]/[py] to the segment `(x1, y1)`–`(x2, y2)`, all in the
/// same unit (metres throughout the floor plans).
double ocptFloorPlanDistanceToSegmentM(
  double px,
  double py,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return math.sqrt(math.pow(px - x1, 2) + math.pow(py - y1, 2));
  }

  final t = (((px - x1) * dx + (py - y1) * dy) / lengthSquared).clamp(0.0, 1.0);
  final projectedX = x1 + t * dx;
  final projectedY = y1 + t * dy;
  return math.sqrt(math.pow(px - projectedX, 2) + math.pow(py - projectedY, 2));
}
