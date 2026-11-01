// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_glyph_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_style.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow_shape.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_glyph_kind.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_underlay_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The shapes of a floor plan page: the underlay, the symbols' outlines, the arrows, the captions
/// and the scale bar with the silhouette beside it.
///
/// Stateless painters over a page layout.
abstract final class OcptFloorPlanShapeSections {
  /// The underlay's own real image: a [pw.Positioned], unrotated rect sized and centred at its
  /// stored metres frame (mapped through [layout]), wrapped in a [pw.Transform.rotate] for
  /// [OcptFloorPlanUnderlayShape.rotationDeg] — mirroring `OcptFloorPlanCanvas
  /// ._buildUnderlayVisual`'s own `Positioned` + `Transform.rotate` around an unrotated rect
  /// exactly, `pw.BoxFit.fill` included, so the printed frame matches the screen's.
  ///
  /// Deliberately a widget, not a `PdfGraphics.drawImage` call from inside [paintShapes]: that
  /// low-level call only ever draws an axis-aligned rectangle, with no rotation of its own, while
  /// `Transform.rotate` (like its on-screen Flutter namesake) rotates around its own child's centre
  /// for free.
  static pw.Widget underlayImageWidget({
    required OcptFloorPlanUnderlayShape underlay,
    required pw.MemoryImage image,
    required OcptFloorPlanPageLayout layout,
  }) {
    final widthPt = underlay.widthM * layout.pixelsPerMetre;
    final heightPt = underlay.heightM * layout.pixelsPerMetre;
    final centre = layout.topDownPointOf(underlay.xM, underlay.yM);

    return pw.Positioned(
      left: centre.dx - widthPt / 2,
      top: centre.dy - heightPt / 2,
      child: pw.SizedBox(
        width: widthPt,
        height: heightPt,
        child: pw.Transform.rotate(
          angle: underlay.rotationDeg * math.pi / 180,
          child: pw.Image(image, fit: pw.BoxFit.fill),
        ),
      ),
    );
  }

  /// Draws [sheet]'s own arrows, symbol footprints, scale bar and reference silhouette onto
  /// [canvas] — every shape [layout] places, none of its captions (see `_buildPage`'s own doc
  /// comment for why those are separate [pw.Text] widgets instead). The underlay's own schematic
  /// frame is drawn here too, but only while [hasUnderlayImage] is false: a real image, drawn as
  /// its own widget beneath this `CustomPaint`, needs no placeholder rectangle under it as well.
  static void paintShapes({
    required PdfGraphics canvas,
    required OcptFloorPlanSheet sheet,
    required OcptFloorPlanPageLayout layout,
    required bool hasUnderlayImage,
  }) {
    if (layout.widthPt <= 0 || layout.heightPt <= 0) {
      return;
    }

    final underlay = sheet.underlay;
    if (underlay != null && !hasUnderlayImage) {
      paintUnderlayFrame(canvas: canvas, layout: layout, underlay: underlay);
    }
    for (final arrow in sheet.arrows) {
      paintArrow(canvas: canvas, layout: layout, arrow: arrow);
    }
    for (final symbol in ocptFloorPlanPrintableSymbolsOf(sheet)) {
      paintSymbolShape(canvas: canvas, layout: layout, symbol: symbol);
    }
    paintScaleAndSilhouette(canvas: canvas, layout: layout);
  }

  /// One [pw.Positioned] caption per symbol that carries one, placed near the symbol's own mapped
  /// centre: a camera's own derived number/letter ([OcptFloorPlanSymbolShape.cameraLabel], when
  /// set) as a filled pill in the camera's own colour — the printed equivalent of
  /// `OcptFloorPlanCanvasPainter._paintCameraLabelPill` — every other symbol's own free
  /// [OcptFloorPlanSymbolShape.label] as plain text, as before.
  static List<pw.Widget> captionOverlays({
    required OcptFloorPlanSheet sheet,
    required OcptFloorPlanPageLayout layout,
    required OcptScriptPagePainter painter,
  }) => [
    for (final symbol in ocptFloorPlanPrintableSymbolsOf(sheet))
      if ((symbol.cameraLabel ?? symbol.label).isNotEmpty)
        positionedTopDown(
          layout.topDownPointOf(symbol.xM, symbol.yM) + const Offset(4, 4),
          symbol.cameraLabel != null && symbol.cameraLabel!.isNotEmpty
              ? cameraLabelPill(
                  cameraLabel: symbol.cameraLabel!,
                  colorArgb: symbol.colorArgb,
                  painter: painter,
                )
              : pw.Text(
                  symbol.label,
                  style: pw.TextStyle(
                    font: painter.fonts.bold,
                    fontSize: ocptFloorPlanSymbolLabelFontSizePt,
                  ),
                ),
        ),
  ];

  /// A camera's own derived [cameraLabel] (`3A`), as a filled pill in [colorArgb] — the mockup's
  /// own filled-pill style, white bold text on the camera's own colour.
  static pw.Widget cameraLabelPill({
    required String cameraLabel,
    required int colorArgb,
    required OcptScriptPagePainter painter,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(colorArgb),
      borderRadius: pw.BorderRadius.circular(ocptFloorPlanSymbolLabelFontSizePt),
    ),
    child: pw.Text(
      cameraLabel,
      style: pw.TextStyle(
        font: painter.fonts.bold,
        fontSize: ocptFloorPlanSymbolLabelFontSizePt,
        color: PdfColors.white,
      ),
    ),
  );

  /// The scale bar's own printed length, positioned just above the bar [layout] placed.
  static pw.Widget scaleBarLabelOverlay({
    required OcptFloorPlanPageLayout layout,
    required OcptScriptPagePainter painter,
    required OcptFloorPlanLabels labels,
  }) => positionedTopDown(
    Offset(layout.scaleBarLeftTopDown, layout.scaleBarTopDown - 12),
    pw.Text(
      labels.scaleBarLabelOf(ocptFloorPlanScaleBarLengthLabelOf(layout.scaleBarLengthM)),
      style: pw.TextStyle(font: painter.fonts.regular, fontSize: 8, color: ocptFloorPlanScaleColor),
    ),
  );

  /// [child] positioned at [topDown] — a `pw.Positioned` measures its own `left`/`top` from the
  /// stack's own top-left corner, exactly the convention every `topDownPointOf` in this file
  /// already computes in, so no flip is needed here (unlike every `PdfGraphics` call, which is not
  /// a widget and measures its own Y from the page's bottom).
  static pw.Widget positionedTopDown(Offset topDown, pw.Widget child) =>
      pw.Positioned(left: topDown.dx, top: topDown.dy, child: child);

  /// The underlay's own frame, drawn as a schematic rectangle — the fallback for a missing or
  /// undecodable underlay file (see this class's own doc comment).
  static void paintUnderlayFrame({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanUnderlayShape underlay,
  }) {
    final corners = rotatedRectCorners(
      centreXM: underlay.xM,
      centreYM: underlay.yM,
      widthM: underlay.widthM,
      heightM: underlay.heightM,
      rotationDeg: underlay.rotationDeg,
    );
    fillAndStrokePolygon(
      canvas: canvas,
      points: [
        for (final corner in corners)
          layout.graphicsOf(layout.topDownPointOf(corner.dx, corner.dy)),
      ],
      fillColor: ocptFloorPlanUnderlayColor,
      strokeColor: ocptFloorPlanUnderlayColor,
      strokeWidthPt: 0.75,
    );
  }

  /// One symbol's own glyph — [OcptFloorPlanSymbolShape.glyphKind] names which
  /// (a character's own disc, a camera's own body/lens/wedge, a light's own body/beam, or a décor
  /// primitive), drawn from the very same shape data `OcptFloorPlanCanvasPainter` reads, so the
  /// printed page and the screen agree. Its caption is a separate [pw.Text] overlay (see
  /// `_buildPage`'s own doc comment for why).
  static void paintSymbolShape({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    switch (symbol.glyphKind) {
      case OcptFloorPlanSymbolGlyphKind.character:
        OcptFloorPlanGlyphSections.paintCharacterGlyph(
          canvas: canvas,
          layout: layout,
          symbol: symbol,
        );
      case OcptFloorPlanSymbolGlyphKind.camera:
        OcptFloorPlanGlyphSections.paintCameraGlyph(canvas: canvas, layout: layout, symbol: symbol);
      case OcptFloorPlanSymbolGlyphKind.light:
        OcptFloorPlanGlyphSections.paintLightGlyph(canvas: canvas, layout: layout, symbol: symbol);
      case OcptFloorPlanSymbolGlyphKind.setElement:
        OcptFloorPlanGlyphSections.paintSetElementGlyph(
          canvas: canvas,
          layout: layout,
          symbol: symbol,
        );
    }
  }

  /// `(localXM, localYM)` — metres in [symbol]'s own local frame, `(0, 0)` its own centre,
  /// unrotated, the sign convention [rotatedRectCorners] already uses (negative Y is the symbol's
  /// own "front"/"up", matching `OcptFloorPlanCanvasPainter`'s own `canvas.rotate` convention) —
  /// rotated by [symbol]'s own [OcptFloorPlanSymbolShape.rotationDeg], translated to its own
  /// centre, then mapped into [layout]'s own graphics space. The single-point sibling of
  /// [rotatedRectCorners], for every glyph feature beyond its own four corners: a camera's lens, a
  /// light's beam tip, a character's facing notch.
  static Offset localPointGraphics({
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
    required double localXM,
    required double localYM,
  }) {
    final radians = symbol.rotationDeg * math.pi / 180;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    final worldXM = symbol.xM + localXM * cosA - localYM * sinA;
    final worldYM = symbol.yM + localXM * sinA + localYM * cosA;
    return layout.graphicsOf(layout.topDownPointOf(worldXM, worldYM));
  }

  /// One arrow: a quadratic bezier shaft through [OcptFloorPlanArrowShape.ctrlXM]/
  /// [OcptFloorPlanArrowShape.ctrlYM] when set (converted to the cubic bezier `PdfGraphics.curveTo`
  /// draws, through the standard quadratic-to-cubic control-point formula `cp = end + 2/3 *
  /// (quadraticControl - end)`), a straight shaft otherwise, with a small filled arrowhead at its
  /// own end, in its own colour. A [OcptFloorPlanArrowKind.cameraMove] arrow's own shaft is drawn
  /// dashed ([ocptFloorPlanDashPattern]), the printed equivalent of the canvas painter's own
  /// dashing, keeping it visually distinct from a movement arrow's solid one, straight or curved
  /// alike.
  static void paintArrow({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
    required OcptFloorPlanArrowShape arrow,
  }) {
    final from = layout.graphicsOf(layout.topDownPointOf(arrow.fromXM, arrow.fromYM));
    final to = layout.graphicsOf(layout.topDownPointOf(arrow.toXM, arrow.toYM));
    final ctrlXM = arrow.ctrlXM;
    final ctrlYM = arrow.ctrlYM;
    final ctrl = ctrlXM != null && ctrlYM != null
        ? layout.graphicsOf(layout.topDownPointOf(ctrlXM, ctrlYM))
        : null;
    final color = PdfColor.fromInt(arrow.colorArgb);
    final isDashed = arrow.kind == OcptFloorPlanArrowKind.cameraMove;

    canvas
      ..setColor(color)
      ..setLineWidth(ocptFloorPlanArrowStrokeWidthPt);
    if (isDashed) {
      canvas.setLineDashPattern(ocptFloorPlanDashPattern);
    }
    canvas.moveTo(from.dx, from.dy);
    if (ctrl != null) {
      final cp1 = Offset(
        from.dx + 2 / 3 * (ctrl.dx - from.dx),
        from.dy + 2 / 3 * (ctrl.dy - from.dy),
      );
      final cp2 = Offset(to.dx + 2 / 3 * (ctrl.dx - to.dx), to.dy + 2 / 3 * (ctrl.dy - to.dy));
      canvas.curveTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);
    } else {
      canvas.lineTo(to.dx, to.dy);
    }
    canvas.strokePath();
    if (isDashed) {
      canvas.setLineDashPattern();
    }

    // The arrowhead's own direction: the shaft's tangent at its own `to` end — `to - ctrl` for a
    // curved shaft (a quadratic bezier's own tangent at t=1), `to - from` for a straight one.
    final headDirection = ctrl != null ? (to - ctrl) : (to - from);
    final angle = math.atan2(headDirection.dy, headDirection.dx);
    final left = Offset(
      to.dx - ocptFloorPlanArrowHeadLengthPt * math.cos(angle - ocptFloorPlanArrowHeadAnglePt),
      to.dy - ocptFloorPlanArrowHeadLengthPt * math.sin(angle - ocptFloorPlanArrowHeadAnglePt),
    );
    final right = Offset(
      to.dx - ocptFloorPlanArrowHeadLengthPt * math.cos(angle + ocptFloorPlanArrowHeadAnglePt),
      to.dy - ocptFloorPlanArrowHeadLengthPt * math.sin(angle + ocptFloorPlanArrowHeadAnglePt),
    );
    canvas
      ..setColor(color)
      ..moveTo(to.dx, to.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..fillPath();
  }

  /// The scale bar and the reference silhouette, bottom-right of the canvas — the printed
  /// equivalent of `ocpt_floor_plan_canvas_painter.dart`'s always-on pair, at the zoom [layout]
  /// fitted the set's own shapes at. The scale bar's own length is a separate [pw.Text] overlay
  /// (see `_buildPage`'s own doc comment for why).
  static void paintScaleAndSilhouette({
    required PdfGraphics canvas,
    required OcptFloorPlanPageLayout layout,
  }) {
    canvas
      ..setColor(ocptFloorPlanScaleColor)
      ..setLineWidth(1)
      ..drawEllipse(
        layout.silhouetteCentreGraphics.dx,
        layout.silhouetteCentreGraphics.dy,
        layout.silhouetteRadiusPt,
        layout.silhouetteRadiusPt,
      )
      ..strokePath();

    final barY = layout.graphicsOf(Offset(0, layout.scaleBarTopDown)).dy;
    final barLeft = layout.scaleBarLeftTopDown;
    final barRight = layout.scaleBarRightTopDown;
    canvas
      ..setColor(ocptFloorPlanScaleColor)
      ..setLineWidth(1.5)
      ..drawLine(barLeft, barY, barRight, barY)
      ..drawLine(barLeft, barY - 3, barLeft, barY + 3)
      ..drawLine(barRight, barY - 3, barRight, barY + 3)
      ..strokePath();
  }

  /// The four corners, in metres, of a footprint [widthM] × [heightM] centred at
  /// `(centreXM, centreYM)` and rotated by [rotationDeg] — the screen convention every floor plan
  /// renderer shares (clockwise, Y growing downward — `ocpt_floor_plan_canvas_painter.dart`'s own
  /// `canvas.rotate`), reproduced here rather than imported from that Flutter widget file, which
  /// the manager layer does not depend on.
  static List<Offset> rotatedRectCorners({
    required double centreXM,
    required double centreYM,
    required double widthM,
    required double heightM,
    required double rotationDeg,
  }) {
    final radians = rotationDeg * math.pi / 180;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    final halfW = widthM / 2;
    final halfH = heightM / 2;

    Offset corner(double x, double y) =>
        Offset(centreXM + x * cosA - y * sinA, centreYM + x * sinA + y * cosA);

    return [
      corner(-halfW, -halfH),
      corner(halfW, -halfH),
      corner(halfW, halfH),
      corner(-halfW, halfH),
    ];
  }

  /// Fills then strokes the closed polygon [points] (already in the canvas's own graphics space).
  static void fillAndStrokePolygon({
    required PdfGraphics canvas,
    required List<Offset> points,
    required PdfColor fillColor,
    required PdfColor strokeColor,
    required double strokeWidthPt,
  }) {
    if (points.isEmpty) {
      return;
    }

    canvas
      ..setFillColor(fillColor)
      ..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      canvas.lineTo(point.dx, point.dy);
    }
    canvas
      ..lineTo(points.first.dx, points.first.dy)
      ..fillPath();

    canvas
      ..setStrokeColor(strokeColor)
      ..setLineWidth(strokeWidthPt)
      ..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      canvas.lineTo(point.dx, point.dy);
    }
    canvas
      ..lineTo(points.first.dx, points.first.dy)
      ..strokePath(close: true);
  }
}
