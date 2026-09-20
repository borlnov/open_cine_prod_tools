// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';

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
  OcptFloorPlanSetElementShape? setElementShape,
  int colorArgb = 0xFF2196F3,
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
  label: "",
  colorArgb: colorArgb,
  cameraLabel: null,
  isGhost: false,
  glyphKind: glyphKind,
  cameraFovWedgeDeg: cameraFovWedgeDeg,
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
Future<Uint8List> _renderRgba(OcptFloorPlanSheet sheet) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & _canvasSize);
  final painter = OcptFloorPlanCanvasPainter(
    sheet: sheet,
    zoom: 1,
    pan: Offset.zero,
    selectedSymbolId: null,
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
