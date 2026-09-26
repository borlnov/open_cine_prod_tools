// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

/// The square canvas every render in this file paints onto.
const _canvasSize = Size(200, 200);

/// A symbol shape with everything but the fields under test defaulted, so each test only spells
/// out what it actually varies.
OcptFloorPlanSymbolShape _symbolShape({
  String symbolId = "sym-1",
  OcptFloorPlanLayer layer = OcptFloorPlanLayer.cameras,
  OcptFloorPlanSymbolGlyphKind glyphKind = OcptFloorPlanSymbolGlyphKind.camera,
  double xM = 0,
  double yM = 0,
  double rotationDeg = 0,
  double widthM = 0.3,
  double heightM = 0.3,
  double? cameraFovWedgeDeg,
  double? cameraFovWedgeReachM,
  OcptFloorPlanSetElementShape? setElementShape,
  int colorArgb = 0xFF2196F3,
  String? cameraLabel,
  String label = "",
}) => OcptFloorPlanSymbolShape(
  symbolId: symbolId,
  shotId: "shot-1",
  layer: layer,
  xM: xM,
  yM: yM,
  rotationDeg: rotationDeg,
  widthM: widthM,
  heightM: heightM,
  fovDeg: null,
  fovReachM: null,
  label: label,
  colorArgb: colorArgb,
  cameraLabel: cameraLabel,
  isGhost: false,
  glyphKind: glyphKind,
  cameraFovWedgeDeg: cameraFovWedgeDeg,
  cameraFovWedgeReachM: cameraFovWedgeReachM,
  setElementShape: setElementShape,
);

/// An arrow shape with everything but the fields under test defaulted.
OcptFloorPlanArrowShape _arrowShape({
  String arrowId = "arrow-1",
  OcptFloorPlanArrowKind kind = OcptFloorPlanArrowKind.movement,
  double fromXM = -1,
  double fromYM = 0,
  double toXM = 1,
  double toYM = 0,
  double? ctrlXM,
  double? ctrlYM,
}) => OcptFloorPlanArrowShape(
  arrowId: arrowId,
  shotId: "shot-1",
  kind: kind,
  fromXM: fromXM,
  fromYM: fromYM,
  toXM: toXM,
  toYM: toYM,
  label: "",
  colorArgb: 0xFF37474F,
  isGhost: false,
  ctrlXM: ctrlXM,
  ctrlYM: ctrlYM,
);

/// Paints [sheet] through a fresh [OcptFloorPlanCanvasPainter] and returns its own raw RGBA pixels
/// — the structural fingerprint two renders are compared by, since neither `Canvas` nor
/// `CustomPainter` exposes the drawing calls it made.
Future<Uint8List> _renderRgba(OcptFloorPlanSheet sheet, {String? selectedSymbolId}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & _canvasSize);
  final painter = OcptFloorPlanCanvasPainter(
    sheet: sheet,
    zoom: 1,
    pan: Offset.zero,
    selectedSymbolId: selectedSymbolId,
    arrowAnchorSymbolId: null,
    liveOverride: null,
    symbolBorderColor: Colors.black,
    selectionColor: Colors.blue,
    arrowAnchorColor: Colors.green,
    arrowColor: Colors.black,
    labelTextColor: Colors.black,
    scaleColor: Colors.black,
    scaleBarLabel: "1 m",
    onionSkinOpacity: 0.4,
    metricLines: const [],
    metricLineColor: Colors.red,
  );
  painter.paint(canvas, _canvasSize);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_canvasSize.width.toInt(), _canvasSize.height.toInt());
  final byteData = await image.toByteData();
  return byteData!.buffer.asUint8List();
}

OcptFloorPlanSheet _sheetOf({
  List<OcptFloorPlanSymbolShape> symbols = const [],
  List<OcptFloorPlanArrowShape> arrows = const [],
}) => OcptFloorPlanSheet(
  setId: "case-1",
  setName: "Kitchen",
  underlay: null,
  symbols: symbols,
  arrows: arrows,
);

/// The RGBA colour of [rgba] (as returned by [_renderRgba]) at pixel ([x], [y]) of a canvas
/// [_canvasSize] wide, as `(red, green, blue, alpha)`.
(int, int, int, int) _pixelAt(Uint8List rgba, int x, int y) {
  final index = (y * _canvasSize.width.toInt() + x) * 4;
  return (rgba[index], rgba[index + 1], rgba[index + 2], rgba[index + 3]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("OcptFloorPlanCanvasPainter — camera field-of-view wedge", () {
    test("a camera with a wedge paints differently from one without", () async {
      final withWedge = await _renderRgba(
        _sheetOf(symbols: [_symbolShape(cameraFovWedgeDeg: 50)]),
      );
      final withoutWedge = await _renderRgba(
        _sheetOf(symbols: [_symbolShape()]),
      );

      expect(withWedge, isNot(equals(withoutWedge)));
    });

    test("two different wedge angles paint differently from each other", () async {
      final narrow = await _renderRgba(_sheetOf(symbols: [_symbolShape(cameraFovWedgeDeg: 20)]));
      final wide = await _renderRgba(_sheetOf(symbols: [_symbolShape(cameraFovWedgeDeg: 150)]));

      expect(narrow, isNot(equals(wide)));
    });

    // The wedge's own reach is its axial height, from the lens tip to its far chord — never the
    // length of either angled edge. Widening the angle spreads the two far corners apart; it must
    // never pull the far chord itself closer to the lens.
    group("the reach sets the wedge's own axial height, not its edge length", () {
      const reachM = 1.0;
      final pixelsPerMetre = ocptFloorPlanPixelsPerMetreAt(1);
      final tipScreenY = 100 - ocptFloorPlanCameraFootprintM / 2 * pixelsPerMetre;
      final chordScreenY = tipScreenY - reachM * pixelsPerMetre;

      test(
        "the far chord sits at the very same depth for a narrow and for a wide angle",
        () async {
          final narrow = await _renderRgba(
            _sheetOf(
              symbols: [_symbolShape(cameraFovWedgeDeg: 20, cameraFovWedgeReachM: reachM)],
            ),
          );
          final wide = await _renderRgba(
            _sheetOf(
              symbols: [_symbolShape(cameraFovWedgeDeg: 140, cameraFovWedgeReachM: reachM)],
            ),
          );

          // Straight ahead of the lens (screen x = 100), at the chord's own depth: inside the
          // wedge whatever the angle, since every angle's chord passes through the axis.
          final narrowAtChord = _pixelAt(narrow, 100, chordScreenY.round());
          final wideAtChord = _pixelAt(wide, 100, chordScreenY.round());
          expect(narrowAtChord.$4, greaterThan(0));
          expect(wideAtChord.$4, greaterThan(0));

          // A few pixels past the chord (further from the lens than the reach): outside the wedge
          // for both — the edge-length bug used to let a wide angle's far side sit short of this
          // depth, or a narrow one overshoot it; the height is fixed regardless of the angle.
          final narrowPastChord = _pixelAt(narrow, 100, (chordScreenY - 6).round());
          final widePastChord = _pixelAt(wide, 100, (chordScreenY - 6).round());
          expect(narrowPastChord.$4, 0);
          expect(widePastChord.$4, 0);
        },
      );

      test("the far corner sits at (height × tan(halfAngle), −height) from the lens tip", () async {
        // A 90° wedge: half angle 45°, tan(45°) == 1, so the corner sits exactly `reachM` to the
        // side of the axis at the chord's own depth — an angle picked so the expected geometry
        // needs no trigonometric tolerance in the test itself.
        final rgba = await _renderRgba(
          _sheetOf(symbols: [_symbolShape(cameraFovWedgeDeg: 90, cameraFovWedgeReachM: reachM)]),
        );

        // A few pixels shallower than the chord (closer to the lens than the reach), so the
        // sampled row is still inside the wedge's own depth range.
        final sampleScreenY = chordScreenY + 6;
        final depth = tipScreenY - sampleScreenY;
        final halfWidthAtDepth = depth * math.tan(45 * math.pi / 180);

        // Just inside the right edge at that depth (smaller half-width than the wedge's own).
        final inside = _pixelAt(
          rgba,
          (100 + halfWidthAtDepth - 6).round(),
          sampleScreenY.round(),
        );
        // Just outside it (larger half-width than the wedge's own), at the very same depth.
        final outside = _pixelAt(
          rgba,
          (100 + halfWidthAtDepth + 6).round(),
          sampleScreenY.round(),
        );

        expect(inside.$4, greaterThan(0));
        expect(outside.$4, 0);
      });
    });
  });

  group("OcptFloorPlanCanvasPainter — décor primitives", () {
    OcptFloorPlanSymbolShape decorOf(OcptFloorPlanSetElementShape shape) => _symbolShape(
      layer: OcptFloorPlanLayer.set,
      glyphKind: OcptFloorPlanSymbolGlyphKind.setElement,
      widthM: 1.2,
      heightM: 0.6,
      setElementShape: shape,
      colorArgb: 0xFF6B7280,
    );

    test("each décor primitive paints its own pixels", () async {
      final wall = await _renderRgba(_sheetOf(symbols: [decorOf(OcptFloorPlanSetElementShape.wall)]));
      final door = await _renderRgba(_sheetOf(symbols: [decorOf(OcptFloorPlanSetElementShape.door)]));
      final furniture = await _renderRgba(
        _sheetOf(symbols: [decorOf(OcptFloorPlanSetElementShape.furniture)]),
      );
      final freeform = await _renderRgba(
        _sheetOf(symbols: [decorOf(OcptFloorPlanSetElementShape.freeform)]),
      );

      expect(wall, isNot(equals(door)));
      expect(door, isNot(equals(furniture)));
      expect(furniture, isNot(equals(freeform)));
      expect(freeform, isNot(equals(wall)));
    });
  });

  group("OcptFloorPlanCanvasPainter — character and light glyphs", () {
    test("a character glyph paints differently from a camera glyph of the same footprint", () async {
      final character = await _renderRgba(
        _sheetOf(
          symbols: [
            _symbolShape(
              layer: OcptFloorPlanLayer.characters,
              glyphKind: OcptFloorPlanSymbolGlyphKind.character,
              colorArgb: 0xFFFF9800,
            ),
          ],
        ),
      );
      final camera = await _renderRgba(_sheetOf(symbols: [_symbolShape()]));

      expect(character, isNot(equals(camera)));
    });

    test("a light glyph paints differently from an unlit footprint of the same size", () async {
      final light = await _renderRgba(
        _sheetOf(
          symbols: [
            _symbolShape(
              layer: OcptFloorPlanLayer.lights,
              glyphKind: OcptFloorPlanSymbolGlyphKind.light,
              colorArgb: 0xFFFBC02D,
            ),
          ],
        ),
      );
      final empty = await _renderRgba(_sheetOf());

      expect(light, isNot(equals(empty)));
    });
  });

  group("OcptFloorPlanCanvasPainter — character glyph geometry", () {
    const characterColorArgb = 0xFF224488;

    /// A 1×1 m character, centred at the canvas's own centre (radius 24px at zoom 1) — a round
    /// footprint that makes every geometry pixel below land on an exact integer.
    OcptFloorPlanSymbolShape characterOf() => _symbolShape(
      layer: OcptFloorPlanLayer.characters,
      glyphKind: OcptFloorPlanSymbolGlyphKind.character,
      widthM: 1,
      heightM: 1,
      colorArgb: characterColorArgb,
    );

    test("the rim notch draws in the character's own colour, never white", () async {
      final rgba = await _renderRgba(_sheetOf(symbols: [characterOf()]));

      // Interior of the notch triangle, just past the disc's own rim in the facing ("up")
      // direction (rim at 24px, notch tip 6px further, so this sits well inside its own fill).
      final (red, green, blue, alpha) = _pixelAt(rgba, 100, 73);

      expect(alpha, 255);
      expect((red, green, blue), isNot((255, 255, 255)));
      expect(red, closeTo(0x22, 4));
      expect(green, closeTo(0x44, 4));
      expect(blue, closeTo(0x88, 4));
    });

    test("the arms point forward, not backward, from the facing direction", () async {
      final rgba = await _renderRgba(_sheetOf(symbols: [characterOf()]));

      // Where the earlier, unvalidated glyph drew its own right arm's end — below and to the
      // right of the disc (facing "backward"). The validated glyph's own arms never reach there.
      final backward = _pixelAt(rgba, 128, 112);
      expect(backward.$4, 0);

      // The validated glyph's own right arm, forward (up) and to the side of the disc, at its own
      // midpoint (0.55r..1.35r along +66° from facing).
      final forward = _pixelAt(rgba, 121, 91);
      expect(forward.$4, greaterThan(0));
      expect((forward.$1, forward.$2, forward.$3), isNot((255, 255, 255)));
    });

    test("a selected character paints an extra selection ring beyond an unselected one", () async {
      final symbol = characterOf();

      final unselected = await _renderRgba(_sheetOf(symbols: [symbol]));
      final selected = await _renderRgba(_sheetOf(symbols: [symbol]), selectedSymbolId: symbol.symbolId);

      expect(selected, isNot(equals(unselected)));
    });
  });

  group("OcptFloorPlanCanvasPainter — camera label pill", () {
    test("a camera's own derived label paints a filled pill below its body; one with no label "
        "paints nothing there", () async {
      final withLabel = await _renderRgba(_sheetOf(symbols: [_symbolShape(cameraLabel: "3A")]));
      final withoutLabel = await _renderRgba(_sheetOf(symbols: [_symbolShape()]));

      // Below the 0.3m camera body's own bottom edge (screen y ≈ 107), where only the pill —
      // never the body itself — can reach.
      final withLabelPixel = _pixelAt(withLabel, 100, 112);
      final withoutLabelPixel = _pixelAt(withoutLabel, 100, 112);

      expect(withLabelPixel.$4, greaterThan(0));
      expect(withoutLabelPixel.$4, 0);
    });

    test("a camera with a derived label paints differently from the same camera with none", () async {
      final withLabel = await _renderRgba(_sheetOf(symbols: [_symbolShape(cameraLabel: "3A")]));
      final withoutLabel = await _renderRgba(_sheetOf(symbols: [_symbolShape()]));

      expect(withLabel, isNot(equals(withoutLabel)));
    });
  });

  group("OcptFloorPlanCanvasPainter — arrow curve", () {
    test("a curved arrow paints differently from a straight one", () async {
      final straight = await _renderRgba(_sheetOf(arrows: [_arrowShape()]));
      final curved = await _renderRgba(_sheetOf(arrows: [_arrowShape(ctrlXM: 0, ctrlYM: -2)]));

      expect(straight, isNot(equals(curved)));
    });

    test("a camera-move arrow's own dashed shaft paints differently from a movement arrow's solid "
        "one, on the very same path", () async {
      final movement = await _renderRgba(_sheetOf(arrows: [_arrowShape()]));
      final cameraMove = await _renderRgba(
        _sheetOf(arrows: [_arrowShape(kind: OcptFloorPlanArrowKind.cameraMove)]),
      );

      expect(movement, isNot(equals(cameraMove)));
    });
  });
}
