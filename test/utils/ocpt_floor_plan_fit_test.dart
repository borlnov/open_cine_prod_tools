// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_fit.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

OcptFloorPlanSymbolShape _symbolShape({
  required double xM,
  required double yM,
  double widthM = 1,
  double heightM = 1,
  double rotationDeg = 0,
}) => OcptFloorPlanSymbolShape(
  symbolId: "symbol-$xM-$yM",
  shotId: null,
  layer: OcptFloorPlanLayer.set,
  xM: xM,
  yM: yM,
  rotationDeg: rotationDeg,
  widthM: widthM,
  heightM: heightM,
  fovDeg: null,
  fovReachM: null,
  label: "",
  colorArgb: 0xFF000000,
  cameraLabel: null,
  isGhost: false,
  glyphKind: OcptFloorPlanSymbolGlyphKind.setElement,
  cameraFovWedgeDeg: null,
  cameraFovWedgeReachM: null,
  setElementShape: null,
);

OcptFloorPlanSheet _sheetOf({
  List<OcptFloorPlanSymbolShape> symbols = const [],
  List<OcptFloorPlanArrowShape> arrows = const [],
  OcptFloorPlanUnderlayShape? underlay,
}) => OcptFloorPlanSheet(
  setId: "set-1",
  setName: "Kitchen",
  underlay: underlay,
  symbols: symbols,
  arrows: arrows,
);

void main() {
  group("ocptFloorPlanContentBoundsOf", () {
    test("is null for an empty sheet", () {
      expect(ocptFloorPlanContentBoundsOf(_sheetOf()), isNull);
    });

    test("is the symbol's own unrotated bounding box for one axis-aligned symbol", () {
      final sheet = _sheetOf(symbols: [_symbolShape(xM: 2, yM: 3, widthM: 2)]);

      final bounds = ocptFloorPlanContentBoundsOf(sheet)!;

      expect(bounds.minXM, closeTo(1, 1e-9));
      expect(bounds.maxXM, closeTo(3, 1e-9));
      expect(bounds.minYM, closeTo(2.5, 1e-9));
      expect(bounds.maxYM, closeTo(3.5, 1e-9));
    });

    test("widens to a rotated symbol's own screen-aligned extent", () {
      // A 2×1 rectangle turned 90° reaches as far on X as it did on Y before the turn.
      final sheet = _sheetOf(
        symbols: [_symbolShape(xM: 0, yM: 0, widthM: 2, rotationDeg: 90)],
      );

      final bounds = ocptFloorPlanContentBoundsOf(sheet)!;

      expect(bounds.minXM, closeTo(-0.5, 1e-9));
      expect(bounds.maxXM, closeTo(0.5, 1e-9));
      expect(bounds.minYM, closeTo(-1, 1e-9));
      expect(bounds.maxYM, closeTo(1, 1e-9));
    });

    test("unions in every symbol, an arrow's ends and control point, and the underlay's frame", () {
      final sheet = _sheetOf(
        symbols: [_symbolShape(xM: 0, yM: 0, widthM: 0.2, heightM: 0.2)],
        arrows: [
          const OcptFloorPlanArrowShape(
            arrowId: "arrow-1",
            shotId: "shot-1",
            kind: OcptFloorPlanArrowKind.movement,
            fromXM: 0,
            fromYM: 0,
            toXM: 5,
            toYM: 0,
            label: "",
            colorArgb: 0xFF000000,
            isGhost: false,
            ctrlXM: 2.5,
            ctrlYM: -4,
          ),
        ],
        underlay: const OcptFloorPlanUnderlayShape(
          assetId: "asset-1",
          path: null,
          xM: -3,
          yM: 3,
          widthM: 2,
          heightM: 2,
          rotationDeg: 0,
        ),
      );

      final bounds = ocptFloorPlanContentBoundsOf(sheet)!;

      expect(bounds.minXM, closeTo(-4, 1e-9)); // the underlay's own left edge
      expect(bounds.maxXM, closeTo(5, 1e-9)); // the arrow's own end
      expect(bounds.minYM, closeTo(-4, 1e-9)); // the arrow's own curved control point
      expect(bounds.maxYM, closeTo(4, 1e-9)); // the underlay's own bottom edge
    });
  });

  group("ocptFloorPlanFitOf", () {
    test("returns the neutral zoom/pan for an empty sheet", () {
      final fit = ocptFloorPlanFitOf(
        sheet: _sheetOf(),
        viewportWidthPx: 200,
        viewportHeightPx: 100,
      );

      expect(fit, (zoom: 1.0, panXPx: 0.0, panYPx: 0.0));
    });

    test("returns the neutral zoom/pan for a degenerate viewport", () {
      final sheet = _sheetOf(symbols: [_symbolShape(xM: 0, yM: 0)]);

      final fit = ocptFloorPlanFitOf(sheet: sheet, viewportWidthPx: 0, viewportHeightPx: 100);

      expect(fit, (zoom: 1.0, panXPx: 0.0, panYPx: 0.0));
    });

    test("centres the content and scales it to fit the narrower axis", () {
      // Two 1×1 symbols 3 m apart on X: a 4 m × 1 m content box, inside a 100×100px viewport with
      // no margin. Width is the binding axis either way (4 m across 100 px vs. 1 m across 100 px),
      // so the fitted zoom must make exactly 4 m span 100 px.
      final sheet = _sheetOf(
        symbols: [
          _symbolShape(xM: -1.5, yM: 0),
          _symbolShape(xM: 1.5, yM: 0),
        ],
      );

      final fit = ocptFloorPlanFitOf(
        sheet: sheet,
        viewportWidthPx: 100,
        viewportHeightPx: 100,
        marginPx: 0,
      );

      final expectedPixelsPerMetre = 100 / 4;
      expect(
        ocptFloorPlanPixelsPerMetreAt(fit.zoom),
        closeTo(expectedPixelsPerMetre, 1e-6),
      );
      // The content is centred on the origin already, so no pan is needed to keep it centred.
      expect(fit.panXPx, closeTo(0, 1e-6));
      expect(fit.panYPx, closeTo(0, 1e-6));
    });

    test("pans off-centre content back to the viewport's own centre", () {
      final sheet = _sheetOf(symbols: [_symbolShape(xM: 10, yM: -10, widthM: 0.01, heightM: 0.01)]);

      final fit = ocptFloorPlanFitOf(
        sheet: sheet,
        viewportWidthPx: 200,
        viewportHeightPx: 200,
        marginPx: 0,
      );

      final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(fit.zoom);
      expect(fit.panXPx, closeTo(-10 * pixelsPerMetre, 1e-6));
      expect(fit.panYPx, closeTo(10 * pixelsPerMetre, 1e-6));
    });

    test("never zooms in past maxZoom for a tiny room", () {
      final sheet = _sheetOf(symbols: [_symbolShape(xM: 0, yM: 0, widthM: 0.01, heightM: 0.01)]);

      final fit = ocptFloorPlanFitOf(
        sheet: sheet,
        viewportWidthPx: 500,
        viewportHeightPx: 500,
      );

      expect(fit.zoom, 3.0);
    });
  });
}
