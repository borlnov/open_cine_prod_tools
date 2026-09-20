// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';

/// Wraps [child] with the localization delegates so `Tr.of` lookups resolve, and sets the test
/// surface past the 800 px compact breakpoint (`docs/architecture/foundations.md`), matching every
/// other shot list widget test of this milestone.
Future<void> _pumpCanvas(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: Scaffold(body: SizedBox(width: 900, height: 700, child: child)),
    ),
  );
}

/// A sequence-scoped set-element symbol at ([xM], [yM]), rotated [rotationDeg], with no
/// `widthM`/`heightM` override (the layer's own default footprint applies).
OcptFloorPlanSymbol _furnitureSymbol({
  required double xM,
  required double yM,
  double rotationDeg = 0,
}) => OcptFloorPlanSymbol(
  id: "sym-1",
  setId: "case-1",
  shotId: null,
  layer: OcptFloorPlanLayer.set,
  sortKey: "a0",
  xM: xM,
  yM: yM,
  rotationDeg: rotationDeg,
  widthM: null,
  heightM: null,
  fovDeg: null,
  label: "",
  setElementShape: null,
);

OcptFloorPlanSet _caseOf(OcptFloorPlanSymbol symbol) => OcptFloorPlanSet(
  id: "case-1",
  sceneId: "scene-1",
  name: "Case",
  sortKey: "a0",
  underlayAssetId: null,
  underlayPath: null,
  underlayXM: null,
  underlayYM: null,
  underlayWidthM: null,
  underlayHeightM: null,
  underlayRotationDeg: null,
  symbols: [symbol],
  arrows: const [],
);

void main() {
  /// Builds an [OcptFloorPlanCanvas] under the `select` tool, focused on the `Sequence` scope (so
  /// the sequence-layer [symbol] is editable), reporting every move/resize into [movedTo]/[resizedTo].
  Widget canvasOf({
    required OcptFloorPlanSymbol symbol,
    required OcptFloorPlanViewportController controller,
    required List<({double xM, double yM})> movedTo,
    required List<({double widthM, double heightM})> resizedTo,
  }) => OcptFloorPlanCanvas(
    floorPlanSet: _caseOf(symbol),
    shotRankByShotId: const {},
    focusShotId: null,
    previousShotId: null,
    nextShotId: null,
    isOnionSkinPreviousShown: false,
    isOnionSkinNextShown: false,
    onionSkinOpacity: 0.3,
    hiddenLayers: const {},
    hiddenCameraSymbolIds: const {},
    isUnderlayHidden: false,
    selectedSymbolId: symbol.id,
    pendingArrowAnchorSymbolId: null,
    isMetricsShown: false,
    activeTool: OcptFloorPlanTool.select,
    activeLayer: OcptFloorPlanLayer.set,
    viewportController: controller,
    isReadOnly: false,
    symbolLabelValueOf: (_) => "",
    onSymbolSelected: (_) {},
    onSymbolPlaced: (_, __, ___, ____) {},
    onSymbolMoved: (_, xM, yM) => movedTo.add((xM: xM, yM: yM)),
    onSymbolResized: (_, widthM, heightM) => resizedTo.add((widthM: widthM, heightM: heightM)),
    onSymbolRotated: (_, __) {},
    onSymbolDeleteRequested: (_) {},
    onArrowSymbolTapped: (_) {},
    onArrowAnchorCancelled: () {},
    onGhostShotFocusRequested: (_) {},
    onSymbolLabelChanged: (_, __) {},
    onUnderlayTransformChanged: (_, __, ___, ____) {},
    onZoomSettled: (_) {},
  );

  testWidgets(
    "dragging a symbol at 2x zoom keeps the grabbed point under the pointer",
    (tester) async {
      // zoom = 2 alone already exposes a missing zoom-divide: at zoom 1 (48 px/m) a 96 px screen
      // drag and a 1 m metres drag are numerically identical, hiding that bug.
      final controller = OcptFloorPlanViewportController(zoom: 2, pan: const Offset(40, -20));
      final symbol = _furnitureSymbol(xM: 1, yM: 0.5);
      final movedTo = <({double xM, double yM})>[];

      await _pumpCanvas(
        tester,
        canvasOf(
          symbol: symbol,
          controller: controller,
          movedTo: movedTo,
          resizedTo: [],
        ),
      );

      final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
      final symbolScreen = ocptFloorPlanScreenPointOf(
        xM: symbol.xM,
        yM: symbol.yM,
        canvasSize: canvasSize,
        zoom: controller.zoom,
        pan: controller.pan,
      );
      final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));

      // Grab a point offset from the symbol's own centre (not the centre itself), so a "snap to
      // pointer" bug (the grab offset lost) would show as a jump, not just a wrong-magnitude move.
      const grabOffset = Offset(6, -4);
      final startGlobal = canvasTopLeft + symbolScreen + grabOffset;
      const screenDelta = Offset(64, 32);

      final gesture = await tester.startGesture(startGlobal);
      await gesture.moveBy(screenDelta);
      await gesture.up();
      await tester.pump();

      expect(movedTo, hasLength(1));
      final pixelsPerMetre = controller.zoom * 48;
      final expectedXM = symbol.xM + screenDelta.dx / pixelsPerMetre;
      final expectedYM = symbol.yM + screenDelta.dy / pixelsPerMetre;
      expect(movedTo.single.xM, closeTo(expectedXM, 1e-9));
      expect(movedTo.single.yM, closeTo(expectedYM, 1e-9));
    },
  );

  testWidgets(
    "dragging a rotated symbol still follows the pointer, in world metres",
    (tester) async {
      // The move handle's own GestureDetector sits inside a Transform.rotate (it rotates to match
      // the drawn symbol), so Flutter reports its onPanUpdate delta already in that rotated local
      // frame; the fix turns it back into world-frame metres before adding it to xM/yM. At 0°
      // rotation the two frames coincide, which is why an unrotated drag never showed the bug —
      // this pins it at a rotation where a missing correction would drag the symbol sideways.
      final controller = OcptFloorPlanViewportController(zoom: 1.5, pan: const Offset(10, 15));
      final symbol = _furnitureSymbol(xM: 0, yM: 0, rotationDeg: 90);
      final movedTo = <({double xM, double yM})>[];

      await _pumpCanvas(
        tester,
        canvasOf(
          symbol: symbol,
          controller: controller,
          movedTo: movedTo,
          resizedTo: [],
        ),
      );

      final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
      final symbolScreen = ocptFloorPlanScreenPointOf(
        xM: symbol.xM,
        yM: symbol.yM,
        canvasSize: canvasSize,
        zoom: controller.zoom,
        pan: controller.pan,
      );
      final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));

      const screenDelta = Offset(50, 0);
      final gesture = await tester.startGesture(canvasTopLeft + symbolScreen);
      await gesture.moveBy(screenDelta);
      await gesture.up();
      await tester.pump();

      expect(movedTo, hasLength(1));
      final pixelsPerMetre = controller.zoom * 48;
      // A rightward screen drag must still move the symbol rightward in world metres (yM
      // unchanged), whatever its own drawn rotation — never rotated into the wrong axis.
      expect(movedTo.single.xM, closeTo(screenDelta.dx / pixelsPerMetre, 1e-6));
      expect(movedTo.single.yM, closeTo(0, 1e-6));
    },
  );

  testWidgets(
    "resizing a symbol at a non-default zoom keeps the handle under the pointer",
    (tester) async {
      final controller = OcptFloorPlanViewportController(zoom: 2, pan: const Offset(-15, 25));
      final symbol = _furnitureSymbol(xM: 0.5, yM: 0.5);
      final resizedTo = <({double widthM, double heightM})>[];

      await _pumpCanvas(
        tester,
        canvasOf(
          symbol: symbol,
          controller: controller,
          movedTo: [],
          resizedTo: resizedTo,
        ),
      );
      await tester.pump();

      final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
      const defaultFootprintM = 0.6; // ocptFloorPlanDefaultElementFootprintM
      final pixelsPerMetre = controller.zoom * 48;
      final resizeScreen = ocptFloorPlanScreenPointOf(
        xM: symbol.xM + defaultFootprintM / 2,
        yM: symbol.yM + defaultFootprintM / 2,
        canvasSize: canvasSize,
        zoom: controller.zoom,
        pan: controller.pan,
      );
      final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));

      const screenDelta = Offset(30, 20);
      final gesture = await tester.startGesture(canvasTopLeft + resizeScreen);
      await gesture.moveBy(screenDelta);
      await gesture.up();
      await tester.pump();

      expect(resizedTo, hasLength(1));
      final expectedWidthM = defaultFootprintM + 2 * screenDelta.dx / pixelsPerMetre;
      final expectedHeightM = defaultFootprintM + 2 * screenDelta.dy / pixelsPerMetre;
      expect(resizedTo.single.widthM, closeTo(expectedWidthM, 1e-6));
      expect(resizedTo.single.heightM, closeTo(expectedHeightM, 1e-6));
    },
  );
}
