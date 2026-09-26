// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
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

/// The length of one dash and of the gap following it, in logical pixels — the same technique
/// `OcptStoryboardAnnotationOverlayPainter._drawDashedLine` uses for its own camera-move arrows,
/// generalised here to any path (a straight or curved shaft, a décor freeform's own rect outline)
/// through `_dashedPathOf`, since `Paint` carries no dash pattern of its own in Flutter.
const double _dashLength = 6;

/// How far, in metres, a light's own beam reaches from its body.
const double _lightBeamLengthM = 1;

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

  /// The symbol's live field-of-view wedge angle, in degrees, while its own edge handle is being
  /// dragged — null for every other kind of drag (move, resize, rotate, tip), in which case the
  /// painter keeps reading the symbol's own already-resolved `cameraFovWedgeDeg`.
  final double? fovDeg;

  /// The symbol's live field-of-view wedge reach, in metres, while its own tip handle is being
  /// dragged — null for every other kind of drag, in which case the painter keeps reading the
  /// symbol's own already-resolved `cameraFovWedgeReachM`.
  final double? fovReachM;

  /// Class constructor
  const OcptFloorPlanSymbolLiveOverride({
    required this.symbolId,
    required this.xM,
    required this.yM,
    required this.widthM,
    required this.heightM,
    required this.rotationDeg,
    this.fovDeg,
    this.fovReachM,
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

  /// One movement or camera-move arrow: a quadratic bezier shaft through
  /// [OcptFloorPlanArrowShape.ctrlXM]/[OcptFloorPlanArrowShape.ctrlYM] when set, a straight shaft
  /// otherwise, with a small head at its own [OcptFloorPlanArrowShape.toXM]/
  /// [OcptFloorPlanArrowShape.toYM] end, at reduced opacity while [OcptFloorPlanArrowShape.isGhost]
  /// (the onion skin). A [OcptFloorPlanArrowKind.cameraMove] arrow's own shaft is drawn dashed
  /// ([_dashedPathOf]), keeping it visually distinct from a movement arrow's solid one, straight or
  /// curved alike.
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
    final ctrlXM = arrow.ctrlXM;
    final ctrlYM = arrow.ctrlYM;
    final ctrl = ctrlXM != null && ctrlYM != null
        ? ocptFloorPlanScreenPointOf(xM: ctrlXM, yM: ctrlYM, canvasSize: size, zoom: zoom, pan: pan)
        : null;
    final opacity = arrow.isGhost ? onionSkinOpacity : 1.0;

    final shaftPath = Path()..moveTo(from.dx, from.dy);
    if (ctrl != null) {
      shaftPath.quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
    } else {
      shaftPath.lineTo(to.dx, to.dy);
    }

    final strokePaint = Paint()
      ..color = Color(arrow.colorArgb).withValues(alpha: opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final isDashed = arrow.kind == OcptFloorPlanArrowKind.cameraMove;
    canvas.drawPath(isDashed ? _dashedPathOf(shaftPath) : shaftPath, strokePaint);

    // The arrowhead's own direction: the shaft's tangent at its own `to` end — `to - ctrl` for a
    // curved shaft (a quadratic bezier's own tangent at t=1), `to - from` for a straight one.
    final headDirection = ctrl != null ? (to - ctrl) : (to - from);
    final angle = math.atan2(headDirection.dy, headDirection.dx);
    final fillPaint = Paint()..color = Color(arrow.colorArgb).withValues(alpha: opacity);
    final headPath = Path()
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
    canvas.drawPath(headPath, fillPaint);

    if (arrow.label.isNotEmpty) {
      final midpoint = ctrl != null
          ? Offset(
              0.25 * from.dx + 0.5 * ctrl.dx + 0.25 * to.dx,
              0.25 * from.dy + 0.5 * ctrl.dy + 0.25 * to.dy,
            )
          : Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      _paintLabel(canvas, midpoint, arrow.label);
    }
  }

  /// [source] split into short dashes and gaps ([_dashLength] each), along whatever shape it draws
  /// — straight, curved, or a closed rect outline — since `Paint` carries no dash pattern of its
  /// own in Flutter.
  Path _dashedPathOf(Path source) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var isDash = true;
      while (distance < metric.length) {
        final next = math.min(distance + _dashLength, metric.length);
        if (isDash) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        isDash = !isDash;
      }
    }
    return dashed;
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

  /// Paints one symbol shape, applying [liveOverride] when it names this very symbol — the glyph
  /// [OcptFloorPlanSymbolShape.glyphKind] names (a character's own disc, a camera's own body/lens/
  /// wedge, a light's own body/beam, or a décor primitive), the selected/arrow-anchor ring on top,
  /// unchanged for every glyph.
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
    // The edge handles' own live drag only ever overrides a camera's wedge angle — every other
    // symbol, and a camera outside that one drag, keeps reading its own already-resolved
    // `cameraFovWedgeDeg` (null while the wedge is off, or this isn't a camera at all).
    final fovWedgeDeg = override != null && override.symbolId == symbol.symbolId
        ? (override.fovDeg ?? symbol.cameraFovWedgeDeg)
        : symbol.cameraFovWedgeDeg;
    final fovWedgeReachM = override != null && override.symbolId == symbol.symbolId
        ? (override.fovReachM ?? symbol.cameraFovWedgeReachM)
        : symbol.cameraFovWedgeReachM;

    final centre = ocptFloorPlanScreenPointOf(xM: xM, yM: yM, canvasSize: size, zoom: zoom, pan: pan);
    final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(zoom);
    final widthPx = widthM * pixelsPerMetre;
    final heightPx = heightM * pixelsPerMetre;
    final isSelected = symbol.symbolId == selectedSymbolId;
    final isArrowAnchor = symbol.symbolId == arrowAnchorSymbolId;
    final opacity = symbol.isGhost ? onionSkinOpacity : 1.0;
    final color = Color(symbol.colorArgb);
    final borderColor = (isSelected ? selectionColor : symbolBorderColor).withValues(alpha: opacity);
    final borderWidth = isSelected ? 2.5 : 1.5;

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(rotationDeg * math.pi / 180);

    final rect = Rect.fromCenter(center: Offset.zero, width: widthPx, height: heightPx);

    switch (symbol.glyphKind) {
      case OcptFloorPlanSymbolGlyphKind.character:
        _paintCharacterGlyph(canvas, rect, color, opacity, borderColor, borderWidth, isSelected);
      case OcptFloorPlanSymbolGlyphKind.camera:
        _paintCameraGlyph(
          canvas,
          rect,
          color,
          opacity,
          borderColor,
          borderWidth,
          fovWedgeDeg,
          fovWedgeReachM,
          pixelsPerMetre,
          symbol.cameraLabel,
        );
      case OcptFloorPlanSymbolGlyphKind.light:
        _paintLightGlyph(canvas, rect, color, opacity, borderColor, borderWidth, pixelsPerMetre);
      case OcptFloorPlanSymbolGlyphKind.setElement:
        _paintSetElementGlyph(
          canvas,
          rect,
          color,
          opacity,
          borderColor,
          borderWidth,
          symbol.setElementShape ?? OcptFloorPlanSetElementShape.freeform,
        );
    }

    if (isArrowAnchor) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(3)),
        Paint()
          ..color = arrowAnchorColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    canvas.restore();

    // A camera with its own derived label draws it as a filled pill attached to its body (inside
    // `_paintCameraGlyph`, still under the rotate transform above) instead of the generic
    // below-symbol caption every other glyph — and a camera with no derived label yet (its shot's
    // rank not known) falls back to that generic caption, same as before.
    final isCameraWithDerivedLabel =
        symbol.glyphKind == OcptFloorPlanSymbolGlyphKind.camera &&
        (symbol.cameraLabel ?? "").isNotEmpty;
    if (!isCameraWithDerivedLabel && symbol.label.isNotEmpty) {
      _paintLabel(canvas, Offset(centre.dx, centre.dy + heightPx / 2 + 4), symbol.label);
    }
  }

  /// A character's own filled disc, in its own derived [color] (`ocptFloorPlanCharacterColourOf`
  /// — resolved once, into [OcptFloorPlanSymbolShape.colorArgb], by `OcptFloorPlanSheet`), never
  /// white: a ~22% fill of [color] ([ocptFloorPlanCharacterDiscFillAlpha]) with a
  /// [ocptFloorPlanCharacterStrokeWidth] stroke in that same colour, plus a facing indicator (a
  /// short rim notch and two forward arms, both in [color] too) drawn pointing local "up" — 0°
  /// rotation means facing up, clockwise positive, the same bearing convention
  /// `OcptFloorPlanCanvas._updateRotateDrag` already reads a rotate-handle drag through — so the
  /// canvas's own `rotate` call (already applied by [_paintSymbol]) turns it to the symbol's own
  /// heading for free. [isSelected] draws an extra ring, in [borderColor]/[borderWidth], around the
  /// disc — the disc's own stroke no longer doubles as the selection indicator now that it is
  /// always [color], never [borderColor].
  void _paintCharacterGlyph(
    Canvas canvas,
    Rect rect,
    Color color,
    double opacity,
    Color borderColor,
    double borderWidth,
    bool isSelected,
  ) {
    final radius = math.min(rect.width, rect.height) / 2;

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = color.withValues(alpha: ocptFloorPlanCharacterDiscFillAlpha * opacity),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ocptFloorPlanCharacterStrokeWidth,
    );

    if (isSelected) {
      canvas.drawCircle(
        Offset.zero,
        radius + 3,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }

    // 0° = local "up", clockwise positive — the same convention `_paintCameraGlyph`'s own wedge
    // reads its `left`/`right` reach through.
    Offset directionAt(double angleRad) => Offset(math.sin(angleRad), -math.cos(angleRad));

    final indicatorColor = color.withValues(alpha: opacity);
    final noseHalfWidth = math.max(2, radius * 0.22).toDouble();
    final noseTip = directionAt(0) * (radius + ocptFloorPlanCharacterNoseRimOffset);
    final nosePath = Path()
      ..moveTo(-noseHalfWidth, -radius)
      ..lineTo(noseTip.dx, noseTip.dy)
      ..lineTo(noseHalfWidth, -radius)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = indicatorColor);

    final armPaint = Paint()
      ..color = indicatorColor
      ..strokeWidth = math.max(1.5, radius * 0.18)
      ..strokeCap = StrokeCap.round;
    for (final sign in [-1, 1]) {
      final direction = directionAt(sign * ocptFloorPlanCharacterArmAngleRad);
      canvas.drawLine(
        direction * (radius * ocptFloorPlanCharacterArmStartFactor),
        direction * (radius * ocptFloorPlanCharacterArmEndFactor),
        armPaint,
      );
    }
  }

  /// A camera's own body, lens, its own derived [cameraLabel] as a filled pill attached to its
  /// back edge (drawn after the body/lens, opposite the lens' own "forward" direction) and, while
  /// [fovWedgeDeg] is set, its field-of-view wedge — a cone [fovWedgeReachM] **deep** (its own axial
  /// height, falling back to [ocptFloorPlanCameraFovWedgeLengthM] when null), spanning [fovWedgeDeg]
  /// at that fixed depth (its far chord's own half-width is `depth * tan(halfAngle)`, so widening
  /// the angle never pulls the far side closer), pointing local "up" (the camera's own heading, see
  /// [_paintCharacterGlyph]'s own doc comment for the shared bearing convention).
  void _paintCameraGlyph(
    Canvas canvas,
    Rect rect,
    Color color,
    double opacity,
    Color borderColor,
    double borderWidth,
    double? fovWedgeDeg,
    double? fovWedgeReachM,
    double pixelsPerMetre,
    String? cameraLabel,
  ) {
    if (fovWedgeDeg != null) {
      final halfAngle = fovWedgeDeg * math.pi / 180 / 2;
      final wedgeHeight = (fovWedgeReachM ?? ocptFloorPlanCameraFovWedgeLengthM) * pixelsPerMetre;
      final tip = Offset(0, -rect.height / 2);
      final halfWidth = wedgeHeight * math.tan(halfAngle);
      final left = tip + Offset(-halfWidth, -wedgeHeight);
      final right = tip + Offset(halfWidth, -wedgeHeight);
      final wedgePath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(wedgePath, Paint()..color = color.withValues(alpha: opacity * 0.16));
      canvas.drawPath(
        wedgePath,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.55 * opacity));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    final lensRadius = math.min(rect.width, rect.height) * 0.24;
    final lensCentre = Offset(0, -rect.height / 2 - lensRadius * 0.5);
    canvas.drawCircle(lensCentre, lensRadius, Paint()..color = color.withValues(alpha: opacity));
    canvas.drawCircle(
      lensCentre,
      lensRadius,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (cameraLabel != null && cameraLabel.isNotEmpty) {
      _paintCameraLabelPill(canvas, rect, color, opacity, cameraLabel);
    }
  }

  /// The camera's own derived [cameraLabel] (`3A`), as a filled pill near/behind its body — anchored
  /// on the back edge (the "down"/local `+y` side, opposite the lens), drawn wider than the body so
  /// it reads as a badge the camera sits on rather than a caption competing with `_paintLabel`'s own
  /// below-symbol placement (skipped for a camera whose label this pill already draws).
  void _paintCameraLabelPill(Canvas canvas, Rect rect, Color color, double opacity, String cameraLabel) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: cameraLabel,
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final pillWidth = math.max(rect.width, textPainter.width + 10);
    final pillHeight = textPainter.height + 4;
    final pillCentre = Offset(0, rect.height / 2);
    final pillRect = Rect.fromCenter(center: pillCentre, width: pillWidth, height: pillHeight);

    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, Radius.circular(pillHeight / 2)),
      Paint()..color = color.withValues(alpha: opacity),
    );
    textPainter.paint(
      canvas,
      Offset(pillCentre.dx - textPainter.width / 2, pillCentre.dy - textPainter.height / 2),
    );
  }

  /// A light/projector's own body, barn doors and a warm beam [_lightBeamLengthM] long, pointing
  /// local "up" (see [_paintCharacterGlyph]'s own doc comment for the shared bearing convention).
  void _paintLightGlyph(
    Canvas canvas,
    Rect rect,
    Color color,
    double opacity,
    Color borderColor,
    double borderWidth,
    double pixelsPerMetre,
  ) {
    final beamLength = _lightBeamLengthM * pixelsPerMetre;
    final tip = Offset(0, -rect.height / 2);
    final beamPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - rect.width * 0.9, tip.dy - beamLength)
      ..lineTo(tip.dx + rect.width * 0.9, tip.dy - beamLength)
      ..close();
    canvas.drawPath(beamPath, Paint()..color = color.withValues(alpha: opacity * 0.22));

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.65 * opacity));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    final doorPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(-rect.width * 0.3, -rect.height * 0.4), doorPaint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(rect.width * 0.3, -rect.height * 0.4), doorPaint);
  }

  /// A décor symbol's own typed primitive: [OcptFloorPlanSetElementShape.wall] a thick filled
  /// segment, [OcptFloorPlanSetElementShape.door] an open-sided frame plus its swing arc,
  /// [OcptFloorPlanSetElementShape.furniture] a filled rounded rect (today's generic look, kept for
  /// this one shape), [OcptFloorPlanSetElementShape.freeform] the same rect with a dashed outline
  /// instead of a solid one, telling it apart from furniture.
  void _paintSetElementGlyph(
    Canvas canvas,
    Rect rect,
    Color color,
    double opacity,
    Color borderColor,
    double borderWidth,
    OcptFloorPlanSetElementShape shape,
  ) {
    switch (shape) {
      case OcptFloorPlanSetElementShape.wall:
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.9 * opacity));
        canvas.drawRect(
          rect,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth + 0.5,
        );
      case OcptFloorPlanSetElementShape.door:
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.15 * opacity));
        final framePath = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.left, rect.bottom)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.right, rect.top);
        canvas.drawPath(
          framePath,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth,
        );
        canvas.drawArc(
          Rect.fromCircle(center: rect.bottomLeft, radius: rect.width),
          -math.pi / 2,
          math.pi / 2,
          false,
          Paint()
            ..color = borderColor.withValues(alpha: borderColor.a * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case OcptFloorPlanSetElementShape.furniture:
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.35 * opacity));
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth,
        );
      case OcptFloorPlanSetElementShape.freeform:
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.2 * opacity));
        canvas.drawPath(
          _dashedPathOf(Path()..addRect(rect)),
          Paint()
            ..color = borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth,
        );
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
