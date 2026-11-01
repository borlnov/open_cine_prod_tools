// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_shape_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_style.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:pdf/pdf.dart';

/// The glyph drawn inside each kind of floor plan symbol: a character, a camera, a light, a set
/// element and a door.
///
/// Stateless painters over a page layout.
abstract final class OcptFloorPlanGlyphSections {
  /// Paint a character's own filled disc, in its own derived colour
  /// (`ocptFloorPlanCharacterColourOf` —
  /// resolved once, into [OcptFloorPlanSymbolShape.colorArgb], by `OcptFloorPlanSheet`), never
  /// white: a [ocptFloorPlanCharacterDiscFillAlpha] fill with a [ocptFloorPlanCharacterStrokeWidth]
  /// stroke, both in that same colour, plus a facing indicator (a short rim notch and two forward
  /// arms, both in that colour too) pointing the symbol's own "up" — see
  /// [OcptFloorPlanShapeSections.localPointGraphics]'s own doc comment for the shared bearing
  /// convention. Mirrors `OcptFloorPlanCanvasPainter ._paintCharacterGlyph`'s own geometry exactly,
  /// so paper and screen agree.
  static void paintCharacterGlyph({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    final color = PdfColor.fromInt(symbol.colorArgb);
    final centre = layout.graphicsOf(layout.topDownPointOf(symbol.xM, symbol.yM));
    final radiusM = math.min(symbol.widthM, symbol.heightM) / 2;
    final radiusPt = radiusM * layout.pixelsPerMetre;

    canvas
      ..setFillColor(
        PdfColor(color.red, color.green, color.blue, ocptFloorPlanCharacterDiscFillAlpha).flatten(),
      )
      ..drawEllipse(centre.dx, centre.dy, radiusPt, radiusPt)
      ..fillPath();
    canvas
      ..setColor(color)
      ..setLineWidth(ocptFloorPlanCharacterStrokeWidth)
      ..drawEllipse(centre.dx, centre.dy, radiusPt, radiusPt)
      ..strokePath();

    Offset local(double xM, double yM) => OcptFloorPlanShapeSections.localPointGraphics(
      layout: layout,
      symbol: symbol,
      localXM: xM,
      localYM: yM,
    );

    // The unit direction at [angleRad] from local "up" (0° = up, clockwise positive) — the same
    // convention `paintCameraGlyph`'s own wedge reads its `left`/`right` reach through.
    Offset unitDirectionAt(double angleRad) => Offset(math.sin(angleRad), -math.cos(angleRad));

    final noseRimOffsetM = ocptFloorPlanCharacterNoseRimOffset / layout.pixelsPerMetre;
    final noseTipVector = unitDirectionAt(0) * (radiusM + noseRimOffsetM);
    final noseHalfWidthM = math.max(2 / layout.pixelsPerMetre, radiusM * 0.22);
    final noseLeft = local(-noseHalfWidthM, -radiusM);
    final noseTip = local(noseTipVector.dx, noseTipVector.dy);
    final noseRight = local(noseHalfWidthM, -radiusM);
    canvas
      ..setFillColor(color)
      ..moveTo(noseLeft.dx, noseLeft.dy)
      ..lineTo(noseTip.dx, noseTip.dy)
      ..lineTo(noseRight.dx, noseRight.dy)
      ..fillPath();

    canvas
      ..setColor(color)
      ..setLineWidth(1);
    for (final sign in [-1, 1]) {
      final direction = unitDirectionAt(sign * ocptFloorPlanCharacterArmAngleRad);
      final armStartVector = direction * (radiusM * ocptFloorPlanCharacterArmStartFactor);
      final armEndVector = direction * (radiusM * ocptFloorPlanCharacterArmEndFactor);
      final armStart = local(armStartVector.dx, armStartVector.dy);
      final armEnd = local(armEndVector.dx, armEndVector.dy);
      canvas.drawLine(armStart.dx, armStart.dy, armEnd.dx, armEnd.dy);
    }
    canvas.strokePath();
  }

  /// Paint a camera's own body, lens and, while [OcptFloorPlanSymbolShape.cameraFovWedgeDeg] is
  /// set, its
  /// field-of-view wedge — a cone [OcptFloorPlanSymbolShape.cameraFovWedgeReachM] **deep** (its own
  /// axial height, falling back to [ocptFloorPlanPdfCameraFovWedgeLengthM] when null), spanning
  /// that angle at that fixed depth (its far chord's own half-width is `depth * tan(halfAngle)`, so
  /// widening the angle never pulls the far side closer — identical geometry to the canvas
  /// painter's own `paintCameraGlyph`, screen and paper drawing the same cone), pointing the
  /// symbol's own "up" (see [OcptFloorPlanShapeSections.localPointGraphics]'s own doc comment).
  static void paintCameraGlyph({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    final color = PdfColor.fromInt(symbol.colorArgb);
    Offset local(double xM, double yM) => OcptFloorPlanShapeSections.localPointGraphics(
      layout: layout,
      symbol: symbol,
      localXM: xM,
      localYM: yM,
    );

    final fovWedgeDeg = symbol.cameraFovWedgeDeg;
    if (fovWedgeDeg != null) {
      final halfAngle = fovWedgeDeg * math.pi / 180 / 2;
      final tipYM = -symbol.heightM / 2;
      final wedgeHeightM = symbol.cameraFovWedgeReachM ?? ocptFloorPlanPdfCameraFovWedgeLengthM;
      final reachXM = wedgeHeightM * math.tan(halfAngle);
      final reachYM = tipYM - wedgeHeightM;
      final tip = local(0, tipYM);
      final left = local(-reachXM, reachYM);
      final right = local(reachXM, reachYM);
      canvas
        ..setFillColor(PdfColor(color.red, color.green, color.blue, 0.16).flatten())
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..fillPath();
      canvas
        ..setColor(color)
        ..setLineWidth(0.5)
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(tip.dx, tip.dy)
        ..strokePath();
    }

    final corners = OcptFloorPlanShapeSections.rotatedRectCorners(
      centreXM: symbol.xM,
      centreYM: symbol.yM,
      widthM: symbol.widthM,
      heightM: symbol.heightM,
      rotationDeg: symbol.rotationDeg,
    );
    OcptFloorPlanShapeSections.fillAndStrokePolygon(
      canvas: canvas,
      points: [
        for (final corner in corners)
          layout.graphicsOf(layout.topDownPointOf(corner.dx, corner.dy)),
      ],
      fillColor: PdfColor(
        color.red,
        color.green,
        color.blue,
        ocptFloorPlanSymbolFillOpacity,
      ).flatten(),
      strokeColor: color,
      strokeWidthPt: ocptFloorPlanSymbolStrokeWidthPt,
    );

    final lensRadiusM = math.min(symbol.widthM, symbol.heightM) * 0.24;
    final lensRadiusPt = lensRadiusM * layout.pixelsPerMetre;
    final lensCentre = local(0, -symbol.heightM / 2 - lensRadiusM * 0.5);
    canvas
      ..setColor(color)
      ..drawEllipse(lensCentre.dx, lensCentre.dy, lensRadiusPt, lensRadiusPt)
      ..fillPath();
    canvas
      ..setColor(color)
      ..setLineWidth(0.5)
      ..drawEllipse(lensCentre.dx, lensCentre.dy, lensRadiusPt, lensRadiusPt)
      ..strokePath();
  }

  /// Paint a light/projector's own body, barn doors and a warm beam [ocptFloorPlanLightBeamLengthM]
  /// long,
  /// pointing the symbol's own "up" (see [OcptFloorPlanShapeSections.localPointGraphics]'s own doc
  /// comment).
  static void paintLightGlyph({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    final color = PdfColor.fromInt(symbol.colorArgb);
    Offset local(double xM, double yM) => OcptFloorPlanShapeSections.localPointGraphics(
      layout: layout,
      symbol: symbol,
      localXM: xM,
      localYM: yM,
    );

    final tipYM = -symbol.heightM / 2;
    final beamYM = tipYM - ocptFloorPlanLightBeamLengthM;
    final beamHalfWidthM = symbol.widthM * 0.9;
    final tip = local(0, tipYM);
    final beamLeft = local(-beamHalfWidthM, beamYM);
    final beamRight = local(beamHalfWidthM, beamYM);
    canvas
      ..setFillColor(PdfColor(color.red, color.green, color.blue, 0.22).flatten())
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(beamLeft.dx, beamLeft.dy)
      ..lineTo(beamRight.dx, beamRight.dy)
      ..fillPath();

    final corners = OcptFloorPlanShapeSections.rotatedRectCorners(
      centreXM: symbol.xM,
      centreYM: symbol.yM,
      widthM: symbol.widthM,
      heightM: symbol.heightM,
      rotationDeg: symbol.rotationDeg,
    );
    OcptFloorPlanShapeSections.fillAndStrokePolygon(
      canvas: canvas,
      points: [
        for (final corner in corners)
          layout.graphicsOf(layout.topDownPointOf(corner.dx, corner.dy)),
      ],
      fillColor: PdfColor(color.red, color.green, color.blue, 0.5).flatten(),
      strokeColor: color,
      strokeWidthPt: ocptFloorPlanSymbolStrokeWidthPt,
    );

    final doorLeftStart = local(-symbol.widthM / 2, tipYM);
    final doorLeftEnd = local(
      -symbol.widthM / 2 - symbol.widthM * 0.3,
      tipYM - symbol.heightM * 0.4,
    );
    final doorRightStart = local(symbol.widthM / 2, tipYM);
    final doorRightEnd = local(
      symbol.widthM / 2 + symbol.widthM * 0.3,
      tipYM - symbol.heightM * 0.4,
    );
    canvas
      ..setColor(color)
      ..setLineWidth(0.75)
      ..drawLine(doorLeftStart.dx, doorLeftStart.dy, doorLeftEnd.dx, doorLeftEnd.dy)
      ..drawLine(doorRightStart.dx, doorRightStart.dy, doorRightEnd.dx, doorRightEnd.dy)
      ..strokePath();
  }

  /// Paint a décor symbol's own typed primitive: [OcptFloorPlanSetElementShape.wall] a thick filled
  /// segment, [OcptFloorPlanSetElementShape.door] an open-sided frame plus its own swing arc,
  /// [OcptFloorPlanSetElementShape.furniture] a filled, stroked rectangle in its own colour
  /// (today's generic look, kept for this one shape — the previous, undifferentiated footprint this
  /// method itself used to draw for every symbol), [OcptFloorPlanSetElementShape.freeform] the same
  /// rectangle with a dashed outline ([ocptFloorPlanDashPattern]) instead of a solid one, telling
  /// it apart from furniture.
  static void paintSetElementGlyph({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    final color = PdfColor.fromInt(symbol.colorArgb);
    final corners = OcptFloorPlanShapeSections.rotatedRectCorners(
      centreXM: symbol.xM,
      centreYM: symbol.yM,
      widthM: symbol.widthM,
      heightM: symbol.heightM,
      rotationDeg: symbol.rotationDeg,
    );
    final points = [
      for (final corner in corners) layout.graphicsOf(layout.topDownPointOf(corner.dx, corner.dy)),
    ];

    switch (symbol.setElementShape ?? OcptFloorPlanSetElementShape.freeform) {
      case OcptFloorPlanSetElementShape.wall:
        OcptFloorPlanShapeSections.fillAndStrokePolygon(
          canvas: canvas,
          points: points,
          fillColor: PdfColor(color.red, color.green, color.blue, 0.9).flatten(),
          strokeColor: color,
          strokeWidthPt: ocptFloorPlanSymbolStrokeWidthPt + 0.5,
        );
      case OcptFloorPlanSetElementShape.door:
        paintDoorGlyph(
          canvas: canvas,
          layout: layout,
          symbol: symbol,
          color: color,
          points: points,
        );
      case OcptFloorPlanSetElementShape.furniture:
        OcptFloorPlanShapeSections.fillAndStrokePolygon(
          canvas: canvas,
          points: points,
          fillColor: PdfColor(
            color.red,
            color.green,
            color.blue,
            ocptFloorPlanSymbolFillOpacity,
          ).flatten(),
          strokeColor: color,
          strokeWidthPt: ocptFloorPlanSymbolStrokeWidthPt,
        );
      case OcptFloorPlanSetElementShape.freeform:
        canvas
          ..setFillColor(PdfColor(color.red, color.green, color.blue, 0.2).flatten())
          ..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          canvas.lineTo(point.dx, point.dy);
        }
        canvas
          ..lineTo(points.first.dx, points.first.dy)
          ..fillPath();

        canvas
          ..setColor(color)
          ..setLineWidth(ocptFloorPlanSymbolStrokeWidthPt)
          ..setLineDashPattern(ocptFloorPlanDashPattern)
          ..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          canvas.lineTo(point.dx, point.dy);
        }
        canvas
          ..lineTo(points.first.dx, points.first.dy)
          ..strokePath(close: true);
        canvas.setLineDashPattern();
    }
  }

  /// Paint a door's own frame — its opening rect, tinted; three of its own four sides (the fourth
  /// is the
  /// opening); and its swing arc, a quarter circle traced from its own hinge (the rect's own
  /// bottom-left corner pre-rotation, [points]`[3]`) with a short polyline rather than
  /// `PdfGraphics.bezierArc` (an SVG-style arc whose parameters this simple quarter-turn does not
  /// need).
  static void paintDoorGlyph({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
    required PdfColor color,
    required List<Offset> points,
  }) {
    canvas
      ..setFillColor(PdfColor(color.red, color.green, color.blue, 0.15).flatten())
      ..moveTo(points[0].dx, points[0].dy);
    for (final point in points.skip(1)) {
      canvas.lineTo(point.dx, point.dy);
    }
    canvas
      ..lineTo(points[0].dx, points[0].dy)
      ..fillPath();

    // The frame's own three sides: top-left → bottom-left → bottom-right → top-right, leaving the
    // top-left → top-right edge (`points[0]` to `points[1]`) open as the opening.
    canvas
      ..setColor(color)
      ..setLineWidth(ocptFloorPlanSymbolStrokeWidthPt)
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..strokePath();

    const arcSteps = 8;
    final halfWidthM = symbol.widthM / 2;
    final halfHeightM = symbol.heightM / 2;
    final swingRadiusM = symbol.heightM;
    final arcPoints = [
      for (var i = 0; i <= arcSteps; i++)
        OcptFloorPlanShapeSections.localPointGraphics(
          layout: layout,
          symbol: symbol,
          localXM: -halfWidthM + swingRadiusM * math.sin(math.pi / 2 * i / arcSteps),
          localYM: halfHeightM - swingRadiusM * math.cos(math.pi / 2 * i / arcSteps),
        ),
    ];
    canvas
      ..setColor(color)
      ..setLineWidth(0.5)
      ..moveTo(arcPoints.first.dx, arcPoints.first.dy);
    for (final point in arcPoints.skip(1)) {
      canvas.lineTo(point.dx, point.dy);
    }
    canvas.strokePath();
  }
}
