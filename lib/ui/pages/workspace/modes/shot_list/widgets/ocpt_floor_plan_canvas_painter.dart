// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui' as ui;

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

  /// A drag-in-progress override of one symbol's geometry, or null while no drag is in progress.
  final OcptFloorPlanSymbolLiveOverride? liveOverride;

  /// The colour a symbol's own border is drawn with while not selected.
  final Color symbolBorderColor;

  /// The colour the selected symbol's own border and handles are drawn with.
  final Color selectionColor;

  /// The colour a symbol's own label text is painted in.
  final Color labelTextColor;

  /// The colour the reference silhouette and the scale bar are drawn with.
  final Color scaleColor;

  /// The scale bar's own already-localized length label (`2 m`), resolved by the caller — this
  /// painter formats no number and reads no `Tr` of its own.
  final String scaleBarLabel;

  /// Class constructor
  const OcptFloorPlanCanvasPainter({
    required this.sheet,
    required this.zoom,
    required this.pan,
    required this.selectedSymbolId,
    required this.liveOverride,
    required this.symbolBorderColor,
    required this.selectionColor,
    required this.labelTextColor,
    required this.scaleColor,
    required this.scaleBarLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final symbol in sheet.symbols) {
      _paintSymbol(canvas, size, symbol);
    }
    _paintScaleAndSilhouette(canvas, size);
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
    final opacity = symbol.isGhost ? 0.4 : 1.0;

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
      oldDelegate.liveOverride != liveOverride ||
      oldDelegate.symbolBorderColor != symbolBorderColor ||
      oldDelegate.selectionColor != selectionColor ||
      oldDelegate.labelTextColor != labelTextColor ||
      oldDelegate.scaleColor != scaleColor ||
      oldDelegate.scaleBarLabel != scaleBarLabel;
}
