// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:pdf/pdf.dart';

/// The minimum half-span, in metres, a set's own bounding box is padded to on either axis when it
/// holds too little (or nothing at all) to size a sensible page from — a freshly created set with
/// one lone camera symbol still prints a legible sheet rather than one zoomed in on a single pixel.
const double ocptFloorPlanMinimumHalfSpanM = 1.5;

/// The fraction of a set's own bounding box span added as breathing room on every side, so a
/// symbol sitting exactly on the edge of what was placed is never printed flush against the page's
/// own margin.
const double ocptFloorPlanBoundingBoxPaddingFraction = 0.15;

/// The font size, in points, of the running head naming the project and the document.
const double ocptFloorPlanHeadFontSizePt = 7;

/// The font size, in points, of a page's own title band (the sequence and the set).
const double ocptFloorPlanTitleFontSizePt = 13;

/// The font size, in points, of the shot's key-information line, or the bare-décor note.
const double ocptFloorPlanKeyInfoFontSizePt = 9;

/// The height, in points, reserved for the header block above the canvas.
const double ocptFloorPlanHeaderHeightPt = 70;

/// The font size, in points, a symbol's own caption is printed at.
const double ocptFloorPlanSymbolLabelFontSizePt = 7;

/// The stroke width, in points, a symbol's own border is drawn with.
const double ocptFloorPlanSymbolStrokeWidthPt = 1;

/// The fill opacity a symbol's own footprint is drawn at, over its [OcptFloorPlanSymbolShape
/// .colorArgb].
const double ocptFloorPlanSymbolFillOpacity = 0.3;

/// The stroke width, in points, an arrow's own shaft is drawn with.
const double ocptFloorPlanArrowStrokeWidthPt = 1.5;

/// The length, in points, of an arrow head's own two strokes.
const double ocptFloorPlanArrowHeadLengthPt = 8;

/// The angle, in radians, an arrow head's two strokes open at.
const double ocptFloorPlanArrowHeadAnglePt = 0.5;

/// The dash pattern (`[dash, gap]`, in points) a [OcptFloorPlanArrowKind.cameraMove] arrow's own
/// shaft, and a [OcptFloorPlanSetElementShape.freeform] décor primitive's own outline, are drawn
/// with — `PdfGraphics.setLineDashPattern`'s own units, the printed equivalent of the canvas
/// painter's manually dashed path.
const List<num> ocptFloorPlanDashPattern = [3, 2];

/// How deep, in metres, a camera's own field-of-view wedge reaches along its own heading — the
/// wedge's own axial height from the lens to its far chord, mirroring
/// `ocptFloorPlanCameraFovWedgeLengthM`.
const double ocptFloorPlanPdfCameraFovWedgeLengthM = 2;

/// How far, in metres, a light's own beam reaches from its body.
const double ocptFloorPlanLightBeamLengthM = 1;

/// The colour every rule, band and running head is drawn with.
const PdfColor ocptFloorPlanMutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The colour the underlay's own placeholder frame is drawn with — a schematic rectangle rather
/// than the referenced image itself (see this class's own doc comment).
const PdfColor ocptFloorPlanUnderlayColor = PdfColor.fromInt(0xFFDDDDDD);

/// The colour the scale bar and the reference silhouette are drawn with.
const PdfColor ocptFloorPlanScaleColor = PdfColor.fromInt(0xFF3A3A3A);

/// The radius, in points, of the reference silhouette printed beside the scale bar, at neutral
/// zoom — scaled by the very same pixels-per-metre the rest of the page's shapes are.
const double ocptFloorPlanSilhouetteMarginPt = 10;

/// One page's own fit-to-content layout: the metre-space bounding box a sheet's own symbols and
/// underlay are fit to a page of `widthPt` × `heightPt`, the pixels-per-metre scale that follows
/// from it (through the very same `ocpt_floor_plan_geometry.dart` rule the on-screen canvas reads,
/// `ocptFloorPlanPixelsPerMetreAt`), and the scale bar's own geometry at that scale.
///
/// Every point this class hands out is in **top-down page space** (`(0, 0)` at the canvas's own
/// top-left corner, Y growing downward) — the convention a `pw.Positioned` widget already measures
/// its own `left`/`top` in, and the one every `topDownPointOf` caller in this file uses directly
/// for text. [graphicsOf] is the one conversion into `PdfGraphics`'s own bottom-up space, applied
/// only where this file draws through a raw canvas call.
class OcptFloorPlanPageLayout {
  /// Class constructor
  const OcptFloorPlanPageLayout({
    required this.widthPt,
    required this.heightPt,
    required this.centerXM,
    required this.centerYM,
    required this.pixelsPerMetre,
  });

  /// Builds the layout [sheet] is drawn under, fit to a page of [widthPt] × [heightPt].
  factory OcptFloorPlanPageLayout.of({
    required OcptFloorPlanSheet sheet,
    required double widthPt,
    required double heightPt,
  }) {
    double? minX;
    double? maxX;
    double? minY;
    double? maxY;

    void include(double x, double y) {
      minX = minX == null ? x : math.min(minX!, x);
      maxX = maxX == null ? x : math.max(maxX!, x);
      minY = minY == null ? y : math.min(minY!, y);
      maxY = maxY == null ? y : math.max(maxY!, y);
    }

    for (final symbol in ocptFloorPlanPrintableSymbolsOf(sheet)) {
      final halfDiagonal =
          math.sqrt(symbol.widthM * symbol.widthM + symbol.heightM * symbol.heightM) / 2;
      include(symbol.xM - halfDiagonal, symbol.yM - halfDiagonal);
      include(symbol.xM + halfDiagonal, symbol.yM + halfDiagonal);
    }
    final underlay = sheet.underlay;
    if (underlay != null) {
      // The half-diagonal, not the half-width/height: a rotated underlay's own true footprint can
      // reach further than its unrotated width/height, and the page's own fit-to-content box must
      // never clip it.
      final halfDiagonal =
          math.sqrt(underlay.widthM * underlay.widthM + underlay.heightM * underlay.heightM) / 2;
      include(underlay.xM - halfDiagonal, underlay.yM - halfDiagonal);
      include(underlay.xM + halfDiagonal, underlay.yM + halfDiagonal);
    }

    final resolvedMinX = minX;
    final resolvedMaxX = maxX;
    final resolvedMinY = minY;
    final resolvedMaxY = maxY;

    double boxWidthM;
    double boxHeightM;
    double centerXM;
    double centerYM;
    if (resolvedMinX == null ||
        resolvedMaxX == null ||
        resolvedMinY == null ||
        resolvedMaxY == null) {
      boxWidthM = ocptFloorPlanMinimumHalfSpanM * 2;
      boxHeightM = ocptFloorPlanMinimumHalfSpanM * 2;
      centerXM = 0;
      centerYM = 0;
    } else {
      centerXM = (resolvedMinX + resolvedMaxX) / 2;
      centerYM = (resolvedMinY + resolvedMaxY) / 2;
      boxWidthM =
          math.max(
            ocptFloorPlanMinimumHalfSpanM,
            (resolvedMaxX - resolvedMinX) / 2 * (1 + ocptFloorPlanBoundingBoxPaddingFraction),
          ) *
          2;
      boxHeightM =
          math.max(
            ocptFloorPlanMinimumHalfSpanM,
            (resolvedMaxY - resolvedMinY) / 2 * (1 + ocptFloorPlanBoundingBoxPaddingFraction),
          ) *
          2;
    }

    final pixelsPerMetre = widthPt <= 0 || heightPt <= 0
        ? 0.0
        : math.min(widthPt / boxWidthM, heightPt / boxHeightM);

    return OcptFloorPlanPageLayout(
      widthPt: widthPt,
      heightPt: heightPt,
      centerXM: centerXM,
      centerYM: centerYM,
      pixelsPerMetre: pixelsPerMetre,
    );
  }

  /// The page's own content width, in points.
  final double widthPt;

  /// The page's own content height, in points.
  final double heightPt;

  /// The metre-space bounding box's own centre X, mapped to the page's own centre.
  final double centerXM;

  /// The metre-space bounding box's own centre Y, mapped to the page's own centre.
  final double centerYM;

  /// How many points one metre draws at, on this page (`ocptFloorPlanPixelsPerMetreAt`'s own
  /// "logical pixel" read as a page point).
  final double pixelsPerMetre;

  /// The zoom [pixelsPerMetre] corresponds to, for `ocpt_floor_plan_geometry.dart`'s own
  /// zoom-keyed rules ([ocptFloorPlanScaleBarLengthM]).
  double get zoom => pixelsPerMetre / ocptFloorPlanBasePixelsPerMetre;

  /// The screen point, in this page's own top-down space, `(xM, yM)` maps to — the fit-to-page
  /// sibling of `ocptFloorPlanScreenPointOf`'s own canvas-centred convention.
  Offset topDownPointOf(double xM, double yM) => Offset(
    widthPt / 2 + (xM - centerXM) * pixelsPerMetre,
    heightPt / 2 + (yM - centerYM) * pixelsPerMetre,
  );

  /// [topDown] converted into `PdfGraphics`'s own bottom-up space — the one flip every raw canvas
  /// call in this file applies, and the only one (see this class's own doc comment).
  Offset graphicsOf(Offset topDown) => Offset(topDown.dx, heightPt - topDown.dy);

  /// The reference silhouette's own radius, in points, at [pixelsPerMetre].
  double get silhouetteRadiusPt => ocptFloorPlanCharacterFootprintM * pixelsPerMetre / 2;

  /// The reference silhouette's own centre, in graphics space, bottom-right of the page.
  Offset get silhouetteCentreGraphics => Offset(
    widthPt - ocptFloorPlanSilhouetteMarginPt - silhouetteRadiusPt,
    heightPt - ocptFloorPlanSilhouetteMarginPt - silhouetteRadiusPt,
  );

  /// The scale bar's own length, in metres, at [zoom] (`ocptFloorPlanScaleBarLengthM`).
  double get scaleBarLengthM => ocptFloorPlanScaleBarLengthM(zoom: zoom, targetPixelLength: 72);

  /// The scale bar's own length, in points.
  double get _scaleBarLengthPt => ocptFloorPlanMetresToPixels(metres: scaleBarLengthM, zoom: zoom);

  /// The scale bar's own top-down Y — just above the reference silhouette.
  double get scaleBarTopDown =>
      heightPt - ocptFloorPlanSilhouetteMarginPt - silhouetteRadiusPt * 2 - 10;

  /// The scale bar's own right edge, in top-down X (and graphics X, the two coinciding on this
  /// axis since no flip ever touches X).
  double get scaleBarRightTopDown => widthPt - ocptFloorPlanSilhouetteMarginPt;

  /// The scale bar's own left edge.
  double get scaleBarLeftTopDown => scaleBarRightTopDown - _scaleBarLengthPt;
}

/// [sheet]'s own symbols, minus the two kinds of ghost the canvas alone draws
/// ([OcptFloorPlanSymbolShape.isOverriddenOriginalGhost]/`.isHiddenOverrideGhost`) — the PDF prints
/// the **effective** plan: an override draws normally, in its
/// own place, a hidden element is simply omitted, and neither ghost nor pin badge ever reaches the
/// page. [OcptFloorPlanSymbolShape.isOverride] itself needs no filtering here: nothing in this file
/// reads it, so an override already prints exactly like any other symbol.
Iterable<OcptFloorPlanSymbolShape> ocptFloorPlanPrintableSymbolsOf(OcptFloorPlanSheet sheet) =>
    sheet.symbols.where(
      (symbol) => !symbol.isOverriddenOriginalGhost && !symbol.isHiddenOverrideGhost,
    );
