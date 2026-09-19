// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

/// The margin, in logical pixels, the scale bar and the reference silhouette are drawn from the
/// canvas's own bottom-right corner.
const double _scaleCornerMargin = 16;

/// The gap, in logical pixels, between the reference silhouette and the scale bar above it.
const double _scaleBlockGap = 10;

/// The screen point (logical pixels, this canvas's own local coordinate space) [xM]/[yM] (case
/// metres) draws at, given the canvas's [canvasSize], current [zoom] and current [pan].
///
/// The **origin convention** every renderer sharing this canvas agrees on: metres `(0, 0)` sits at
/// the canvas's own geometric centre before any pan is applied, so a freshly opened case is
/// centred on screen rather than pinned to a corner. [zoom]/[pan] are the very values
/// `OcptFloorPlanViewportController` owns; see its own doc comment for why they never reach the
/// bloc's persisted state.
Offset ocptFloorPlanScreenPointOf({
  required double xM,
  required double yM,
  required Size canvasSize,
  required double zoom,
  required Offset pan,
}) {
  final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
  return Offset(
    canvasSize.width / 2 + pan.dx + xM * pixelsPerMetre,
    canvasSize.height / 2 + pan.dy + yM * pixelsPerMetre,
  );
}

/// The inverse of [ocptFloorPlanScreenPointOf]: the case metres [screenPoint] (this canvas's own
/// local coordinate space) names.
Offset ocptFloorPlanMetrePointOf({
  required Offset screenPoint,
  required Size canvasSize,
  required double zoom,
  required Offset pan,
}) {
  final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
  return Offset(
    (screenPoint.dx - canvasSize.width / 2 - pan.dx) / pixelsPerMetre,
    (screenPoint.dy - canvasSize.height / 2 - pan.dy) / pixelsPerMetre,
  );
}

/// A screen-space vector, converted from case metres at [zoom] — a pure scale with no translation,
/// what a drag's own per-frame delta is converted through (never through
/// [ocptFloorPlanMetrePointOf], which would also subtract the canvas centre and the pan offset).
Offset ocptFloorPlanMetresToScreenVector({required Offset metres, required double zoom}) {
  final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
  return metres * pixelsPerMetre;
}

/// The inverse of [ocptFloorPlanMetresToScreenVector]: a screen-space delta converted to case
/// metres at [zoom].
Offset ocptFloorPlanScreenVectorToMetres({required Offset screenDelta, required double zoom}) {
  final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
  return Offset(screenDelta.dx / pixelsPerMetre, screenDelta.dy / pixelsPerMetre);
}

/// [vector] turned by [degrees] clockwise (screen convention: Y grows downward) — what un-rotating
/// a resize handle's own screen-space drag delta into the symbol's own local width/height axes
/// needs, and what placing a rotate handle at the current rotation needs the other way around.
Offset ocptFloorPlanRotateVector(Offset vector, double degrees) {
  final radians = degrees * math.pi / 180;
  final cosA = math.cos(radians);
  final sinA = math.sin(radians);
  return Offset(
    vector.dx * cosA - vector.dy * sinA,
    vector.dx * sinA + vector.dy * cosA,
  );
}

/// The half-length, in logical pixels, of an arrowhead's own two strokes.
const double _arrowheadLength = 8;

/// The angle, in radians, each of an arrowhead's own two strokes opens from the shaft.
const double _arrowheadAngle = 0.5;

/// One line the metrics overlay draws, from the selected symbol to another visible one — a pure
/// data record `OcptFloorPlanCanvas` builds (it alone can resolve a localized label) and this
/// painter only ever draws from metres to pixels, exactly as it does every symbol shape.
class OcptFloorPlanMetricLine extends Equatable {
  /// The line's own starting point X, in metres (the selected symbol's own centre).
  final double fromXM;

  /// The line's own starting point Y, in metres.
  final double fromYM;

  /// The line's own end point X, in metres (the other symbol's own centre).
  final double toXM;

  /// The line's own end point Y, in metres.
  final double toYM;

  /// The line's own already-localized distance label (`3.2 m`).
  final String label;

  /// Class constructor
  const OcptFloorPlanMetricLine({
    required this.fromXM,
    required this.fromYM,
    required this.toXM,
    required this.toYM,
    required this.label,
  });

  /// Object properties
  @override
  List<Object?> get props => [fromXM, fromYM, toXM, toYM, label];
}

/// A live, in-progress edit of one symbol's geometry — the drag preview `OcptFloorPlanCanvas` feeds
/// into [OcptFloorPlanCanvasPainter] so the shape being dragged redraws every frame without a
/// database write, or a bloc emission, per frame.
class OcptFloorPlanSymbolLiveOverride {
  /// The id of the symbol being edited.
  final String symbolId;

  /// The symbol's live centre X, in metres.
  final double xM;

  /// The symbol's live centre Y, in metres.
  final double yM;

  /// The symbol's live footprint width, in metres.
  final double widthM;

  /// The symbol's live footprint height, in metres.
  final double heightM;

  /// The symbol's live rotation, in degrees.
  final double rotationDeg;

  /// Class constructor
  const OcptFloorPlanSymbolLiveOverride({
    required this.symbolId,
    required this.xM,
    required this.yM,
    required this.widthM,
    required this.heightM,
    required this.rotationDeg,
  });
}

/// Paints a `OcptFloorPlanSheet`'s own symbols, the always-on scale bar and reference silhouette
/// (`docs/adr/0031-storyboard-panels-and-floor-plans-in-metres.md`), for the floor plans canvas.
///
/// The underlay itself is **not** drawn here: it is a real `OcptReferencedImage` positioned by
/// `OcptFloorPlanCanvas` underneath this painter's own `CustomPaint`, which is what gets it
/// `OcptReferencedImage`'s missing-file fallback for free and keeps its drag/resize interaction
/// ordinary widget-level gestures rather than painter-side hit testing.
///
/// Geometry is drawn from **metres → logical pixels at [zoom]**, through
/// [ocptFloorPlanScreenPointOf] and `ocpt_floor_plan_geometry.dart` — never a stored pixel value,
/// per `OcptFloorPlanSheet`'s own doc comment. [liveOverride], when set, replaces the matching
/// symbol's stored geometry with its own drag-in-progress one, so the shape being dragged tracks
/// the pointer every frame; every other symbol still draws from [sheet].
class OcptFloorPlanCanvasPainter extends CustomPainter {
  /// The sheet this painter draws — already filtered to the tray's own visible layers by
  /// `OcptFloorPlanCanvas`.
  final OcptFloorPlanSheet sheet;

  /// The canvas's current zoom (1.0 = neutral/100%).
  final double zoom;

  /// The canvas's current pan offset, in logical pixels.
  final Offset pan;

  /// The id of the currently selected symbol, or null while none is.
  final String? selectedSymbolId;

  /// The id of the symbol currently picked as the arrow tool's own pending anchor, or null while
  /// none is.
  final String? arrowAnchorSymbolId;

  /// A drag-in-progress override of one symbol's geometry, or null while no drag is in progress.
  final OcptFloorPlanSymbolLiveOverride? liveOverride;

  /// The colour a symbol's own border is drawn with while not selected.
  final Color symbolBorderColor;

  /// The colour the selected symbol's own border and handles are drawn with.
  final Color selectionColor;

  /// The colour the arrow tool's own pending anchor is ringed with.
  final Color arrowAnchorColor;

  /// The colour an arrow's own shaft and head are drawn with, tinted by
  /// [OcptFloorPlanArrowShape.colorArgb] — see [_paintArrow].
  final Color arrowColor;

  /// The colour a symbol's own label text is painted in.
  final Color labelTextColor;

  /// The colour the reference silhouette and the scale bar are drawn with.
  final Color scaleColor;

  /// The scale bar's own already-localized length label (`2 m`), resolved by the caller — this
  /// painter formats no number and reads no `Tr` of its own.
  final String scaleBarLabel;

  /// The onion skin's own ghost opacity, 0..1 — every [OcptFloorPlanSymbolShape.isGhost] shape and
  /// [OcptFloorPlanArrowShape.isGhost] shape draws at this opacity instead of fully opaque.
  final double onionSkinOpacity;

  /// The metrics overlay's own lines, already resolved by `OcptFloorPlanCanvas` — empty while the
  /// overlay is off or nothing is selected.
  final List<OcptFloorPlanMetricLine> metricLines;

  /// The colour a metrics overlay line and its label are drawn with.
  final Color metricLineColor;

  /// Class constructor
  const OcptFloorPlanCanvasPainter({
    required this.sheet,
    required this.zoom,
    required this.pan,
    required this.selectedSymbolId,
    required this.arrowAnchorSymbolId,
    required this.liveOverride,
    required this.symbolBorderColor,
    required this.selectionColor,
    required this.arrowAnchorColor,
    required this.arrowColor,
    required this.labelTextColor,
    required this.scaleColor,
    required this.scaleBarLabel,
    required this.onionSkinOpacity,
    required this.metricLines,
    required this.metricLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in metricLines) {
      _paintMetricLine(canvas, size, line);
    }
    for (final arrow in sheet.arrows) {
      _paintArrow(canvas, size, arrow);
    }
    for (final symbol in sheet.symbols) {
      _paintSymbol(canvas, size, symbol);
    }
    _paintScaleAndSilhouette(canvas, size);
  }

  /// One movement or camera-move arrow, a straight shaft with a small head at its own
  /// [OcptFloorPlanArrowShape.toXM]/[OcptFloorPlanArrowShape.toYM] end, at reduced opacity while
  /// [OcptFloorPlanArrowShape.isGhost] (the onion skin).
  void _paintArrow(Canvas canvas, Size size, OcptFloorPlanArrowShape arrow) {
    final from = ocptFloorPlanScreenPointOf(
      xM: arrow.fromXM,
      yM: arrow.fromYM,
      canvasSize: size,
      zoom: zoom,
      pan: pan,
    );
    final to = ocptFloorPlanScreenPointOf(
      xM: arrow.toXM,
      yM: arrow.toYM,
      canvasSize: size,
      zoom: zoom,
      pan: pan,
    );
    final opacity = arrow.isGhost ? onionSkinOpacity : 1.0;
    final paint = Paint()
      ..color = Color(arrow.colorArgb).withValues(alpha: opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(from, to, paint);

    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final fillPaint = Paint()..color = Color(arrow.colorArgb).withValues(alpha: opacity);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - _arrowheadLength * math.cos(angle - _arrowheadAngle),
        to.dy - _arrowheadLength * math.sin(angle - _arrowheadAngle),
      )
      ..lineTo(
        to.dx - _arrowheadLength * math.cos(angle + _arrowheadAngle),
        to.dy - _arrowheadLength * math.sin(angle + _arrowheadAngle),
      )
      ..close();
    canvas.drawPath(path, fillPaint);

    if (arrow.label.isNotEmpty) {
      _paintLabel(canvas, Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2), arrow.label);
    }
  }

  /// One metrics overlay line: a thin dashed-looking (short, evenly spaced) segment from the
  /// selected symbol to another visible one, its own distance label at the midpoint.
  void _paintMetricLine(Canvas canvas, Size size, OcptFloorPlanMetricLine line) {
    final from = ocptFloorPlanScreenPointOf(
      xM: line.fromXM,
      yM: line.fromYM,
      canvasSize: size,
      zoom: zoom,
      pan: pan,
    );
    final to = ocptFloorPlanScreenPointOf(
      xM: line.toXM,
      yM: line.toYM,
      canvasSize: size,
      zoom: zoom,
      pan: pan,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = metricLineColor.withValues(alpha: 0.7)
        ..strokeWidth = 1,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: line.label, style: TextStyle(color: metricLineColor, fontSize: 9)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final midpoint = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    canvas.drawRect(
      Rect.fromCenter(
        center: midpoint,
        width: textPainter.width + 4,
        height: textPainter.height + 2,
      ),
      Paint()..color = metricLineColor.withValues(alpha: 0.12),
    );
    textPainter.paint(
      canvas,
      Offset(midpoint.dx - textPainter.width / 2, midpoint.dy - textPainter.height / 2),
    );
  }

  /// Paints one symbol shape, applying [liveOverride] when it names this very symbol.
  void _paintSymbol(Canvas canvas, Size size, OcptFloorPlanSymbolShape symbol) {
    final override = liveOverride;
    final xM = override != null && override.symbolId == symbol.symbolId ? override.xM : symbol.xM;
    final yM = override != null && override.symbolId == symbol.symbolId ? override.yM : symbol.yM;
    final widthM = override != null && override.symbolId == symbol.symbolId
        ? override.widthM
        : symbol.widthM;
    final heightM = override != null && override.symbolId == symbol.symbolId
        ? override.heightM
        : symbol.heightM;
    final rotationDeg = override != null && override.symbolId == symbol.symbolId
        ? override.rotationDeg
        : symbol.rotationDeg;

    final centre = ocptFloorPlanScreenPointOf(xM: xM, yM: yM, canvasSize: size, zoom: zoom, pan: pan);
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final widthPx = widthM * pixelsPerMetre;
    final heightPx = heightM * pixelsPerMetre;
    final isSelected = symbol.symbolId == selectedSymbolId;
    final isArrowAnchor = symbol.symbolId == arrowAnchorSymbolId;
    final opacity = symbol.isGhost ? onionSkinOpacity : 1.0;

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(rotationDeg * math.pi / 180);

    final rect = Rect.fromCenter(center: Offset.zero, width: widthPx, height: heightPx);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));

    canvas.drawRRect(
      rrect,
      Paint()..color = Color(symbol.colorArgb).withValues(alpha: 0.35 * opacity),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = (isSelected ? selectionColor : symbolBorderColor).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5,
    );
    if (isArrowAnchor) {
      canvas.drawRRect(
        rrect.inflate(3),
        Paint()
          ..color = arrowAnchorColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    canvas.restore();

    if (symbol.label.isNotEmpty) {
      _paintLabel(canvas, Offset(centre.dx, centre.dy + heightPx / 2 + 4), symbol.label);
    }
  }

  /// A symbol's own free-text label, centred under its footprint.
  void _paintLabel(Canvas canvas, Offset anchor, String text) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: labelTextColor, fontSize: 10)),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 120);
    textPainter.paint(canvas, Offset(anchor.dx - textPainter.width / 2, anchor.dy));
  }

  /// Paints the always-on reference silhouette (the [ocptFloorPlanCharacterFootprintM] character,
  /// from above) and the scale bar, bottom-right of the canvas, both from
  /// `ocpt_floor_plan_geometry.dart` at the current [zoom] — the one place a viewer can check the
  /// plan's own scale against, with no calibration step (ADR 0031).
  void _paintScaleAndSilhouette(Canvas canvas, Size size) {
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final silhouetteDiameter = ocptFloorPlanCharacterFootprintM * pixelsPerMetre;
    final barLengthM = ocptFloorPlanScaleBarLengthM(zoom: zoom);
    final barLengthPx = ocptFloorPlanMetresToPixels(metres: barLengthM, zoom: zoom);

    final silhouetteCentre = Offset(
      size.width - _scaleCornerMargin - silhouetteDiameter / 2,
      size.height - _scaleCornerMargin - silhouetteDiameter / 2,
    );
    canvas.drawCircle(
      silhouetteCentre,
      silhouetteDiameter / 2,
      Paint()..color = scaleColor.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      silhouetteCentre,
      silhouetteDiameter / 2,
      Paint()
        ..color = scaleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final barY = silhouetteCentre.dy - silhouetteDiameter / 2 - _scaleBlockGap;
    final barRight = size.width - _scaleCornerMargin;
    final barLeft = barRight - barLengthPx;
    final barPaint = Paint()
      ..color = scaleColor
      ..strokeWidth = 2;
    canvas.drawLine(Offset(barLeft, barY), Offset(barRight, barY), barPaint);
    canvas.drawLine(Offset(barLeft, barY - 4), Offset(barLeft, barY + 4), barPaint);
    canvas.drawLine(Offset(barRight, barY - 4), Offset(barRight, barY + 4), barPaint);

    final labelPainter = TextPainter(
      text: TextSpan(text: scaleBarLabel, style: TextStyle(color: scaleColor, fontSize: 11)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(barRight - labelPainter.width, barY - _scaleBlockGap - labelPainter.height),
    );
  }

  @override
  bool shouldRepaint(covariant OcptFloorPlanCanvasPainter oldDelegate) =>
      oldDelegate.sheet != sheet ||
      oldDelegate.zoom != zoom ||
      oldDelegate.pan != pan ||
      oldDelegate.selectedSymbolId != selectedSymbolId ||
      oldDelegate.arrowAnchorSymbolId != arrowAnchorSymbolId ||
      oldDelegate.liveOverride != liveOverride ||
      oldDelegate.symbolBorderColor != symbolBorderColor ||
      oldDelegate.selectionColor != selectionColor ||
      oldDelegate.arrowAnchorColor != arrowAnchorColor ||
      oldDelegate.arrowColor != arrowColor ||
      oldDelegate.labelTextColor != labelTextColor ||
      oldDelegate.scaleColor != scaleColor ||
      oldDelegate.scaleBarLabel != scaleBarLabel ||
      oldDelegate.onionSkinOpacity != onionSkinOpacity ||
      !const ListEquality<OcptFloorPlanMetricLine>().equals(oldDelegate.metricLines, metricLines) ||
      oldDelegate.metricLineColor != metricLineColor;
}
