// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

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

/// A shot-scoped camera symbol at ([xM], [yM]), not rotated, carrying no `fovDeg` of its own — the
/// drawing default (`ocptFloorPlanDefaultCameraFovDeg`) applies, so its own field-of-view wedge (and
/// edge handles) always draw.
OcptFloorPlanSymbol _cameraSymbol({required double xM, required double yM}) => OcptFloorPlanSymbol(
  id: "cam-1",
  setId: "case-1",
  shotId: "shot-1",
  layer: OcptFloorPlanLayer.cameras,
  sortKey: "a0",
  xM: xM,
  yM: yM,
  rotationDeg: 0,
  widthM: null,
  heightM: null,
  fovDeg: null,
  label: "",
  setElementShape: null,
);

/// Two shot-scoped character symbols, connected by one movement arrow (bent through [ctrlXM]/
/// [ctrlYM] when given, straight otherwise), on set `case-1` and shot `shot-1` —
/// [OcptFloorPlanCanvas.focusShotId] must be `"shot-1"` for both to be editable/selectable.
OcptFloorPlanSet _caseWithArrow({double? ctrlXM, double? ctrlYM}) {
  const fromSymbol = OcptFloorPlanSymbol(
    id: "sym-from",
    setId: "case-1",
    shotId: "shot-1",
    layer: OcptFloorPlanLayer.characters,
    sortKey: "a0",
    xM: 0,
    yM: 0,
    rotationDeg: 0,
    widthM: null,
    heightM: null,
    fovDeg: null,
    label: "SAM",
    setElementShape: null,
  );
  const toSymbol = OcptFloorPlanSymbol(
    id: "sym-to",
    setId: "case-1",
    shotId: "shot-1",
    layer: OcptFloorPlanLayer.characters,
    sortKey: "a1",
    xM: 3,
    yM: 0,
    rotationDeg: 0,
    widthM: null,
    heightM: null,
    fovDeg: null,
    label: "LEA",
    setElementShape: null,
  );
  final arrow = OcptFloorPlanArrow(
    id: "arrow-1",
    setId: "case-1",
    shotId: "shot-1",
    kind: OcptFloorPlanArrowKind.movement,
    fromSymbolId: "sym-from",
    toSymbolId: "sym-to",
    label: "",
    ctrlXM: ctrlXM,
    ctrlYM: ctrlYM,
  );

  return OcptFloorPlanSet(
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
    symbols: const [fromSymbol, toSymbol],
    arrows: [arrow],
  );
}

void main() {
  /// Builds an [OcptFloorPlanCanvas] under the `select` tool, focused on the `Sequence` scope (so
  /// the sequence-layer [symbol] is editable), reporting every move/resize into [movedTo]/[resizedTo].
  Widget canvasOf({
    required OcptFloorPlanSymbol symbol,
    required OcptFloorPlanViewportController controller,
    required List<({double xM, double yM})> movedTo,
    required List<({double widthM, double heightM})> resizedTo,
    List<double>? rotatedTo,
    List<double>? fovChangedTo,
    String? selectedArrowId,
    List<String?>? arrowSelectedTo,
    List<({double? ctrlXM, double? ctrlYM})>? arrowCurveChangedTo,
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
    selectedArrowId: selectedArrowId,
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
    onSymbolRotated: (_, rotationDeg) => rotatedTo?.add(rotationDeg),
    onSymbolFovChanged: (_, fovDeg) => fovChangedTo?.add(fovDeg),
    onSymbolDeleteRequested: (_) {},
    onArrowSymbolTapped: (_) {},
    onArrowAnchorCancelled: () {},
    onArrowSelected: (arrowId) => arrowSelectedTo?.add(arrowId),
    onArrowCurveChanged: (_, ctrlXM, ctrlYM) =>
        arrowCurveChangedTo?.add((ctrlXM: ctrlXM, ctrlYM: ctrlYM)),
    onSymbolDuplicateRequested: (_) {},
    onSymbolDuplicateDragged: (_, __, ___) {},
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

  testWidgets(
    "dragging the aim handle rotates from the pointer's own bearing in canvas space (the R2 "
    "rotation fix), not the handle's own local position",
    (tester) async {
      final controller = OcptFloorPlanViewportController(zoom: 1, pan: const Offset(20, -10));
      final symbol = _furnitureSymbol(xM: 0, yM: 0);
      final rotatedTo = <double>[];

      await _pumpCanvas(
        tester,
        canvasOf(
          symbol: symbol,
          controller: controller,
          movedTo: [],
          resizedTo: [],
          rotatedTo: rotatedTo,
        ),
      );

      final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
      final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));

      const defaultFootprintM = 0.6; // ocptFloorPlanDefaultElementFootprintM
      const rotateHandleGapM = 0.3; // _rotateHandleGapM
      final pixelsPerMetre = controller.zoom * 48;
      final symbolCentreScreen = ocptFloorPlanScreenPointOf(
        xM: symbol.xM,
        yM: symbol.yM,
        canvasSize: canvasSize,
        zoom: controller.zoom,
        pan: controller.pan,
      );
      final handleScreen =
          symbolCentreScreen +
          Offset(0, -(defaultFootprintM / 2 + rotateHandleGapM) * pixelsPerMetre);

      // The bug this milestone fixes read the pointer relative to the handle's own 18x18 hit
      // box instead of canvas space: the handle's own starting point (up, away from the centre)
      // is itself proof the two frames disagree, so driving the gesture from here and asserting
      // an exact bearing below is what a still-buggy `details.localPosition` reader would fail.
      final gesture = await tester.startGesture(canvasTopLeft + handleScreen);
      // Move the pointer to a point due east of the symbol's own centre: a 90° bearing (0° = up,
      // clockwise positive), whatever the handle's own starting position was.
      await gesture.moveTo(canvasTopLeft + symbolCentreScreen + const Offset(120, 0));
      await gesture.up();
      await tester.pump();

      expect(rotatedTo, hasLength(1));
      expect(rotatedTo.single, closeTo(90, 1e-6));
    },
  );

  testWidgets(
    "holding Shift while dragging the aim handle snaps the rotation to 15° steps",
    (tester) async {
      final controller = OcptFloorPlanViewportController(zoom: 1);
      final symbol = _furnitureSymbol(xM: 0, yM: 0);
      final rotatedTo = <double>[];

      await _pumpCanvas(
        tester,
        canvasOf(
          symbol: symbol,
          controller: controller,
          movedTo: [],
          resizedTo: [],
          rotatedTo: rotatedTo,
        ),
      );

      final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
      final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));
      const defaultFootprintM = 0.6; // ocptFloorPlanDefaultElementFootprintM
      const rotateHandleGapM = 0.3; // _rotateHandleGapM
      final pixelsPerMetre = controller.zoom * 48;
      final symbolCentreScreen = ocptFloorPlanScreenPointOf(
        xM: symbol.xM,
        yM: symbol.yM,
        canvasSize: canvasSize,
        zoom: controller.zoom,
        pan: controller.pan,
      );
      final handleScreen =
          symbolCentreScreen +
          Offset(0, -(defaultFootprintM / 2 + rotateHandleGapM) * pixelsPerMetre);

      // A raw bearing of 40°, a few degrees off the nearest 15° step (45°).
      const rawBearingDeg = 40.0;
      final rawBearingRad = rawBearingDeg * math.pi / 180;
      final target =
          symbolCentreScreen +
          Offset(math.sin(rawBearingRad), -math.cos(rawBearingRad)) * 120;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final gesture = await tester.startGesture(canvasTopLeft + handleScreen);
      await gesture.moveTo(canvasTopLeft + target);
      await gesture.up();
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      expect(rotatedTo, hasLength(1));
      expect(rotatedTo.single, closeTo(45, 1e-6));
    },
  );

  testWidgets(
    "dragging a camera's own field-of-view edge handle narrows or widens its wedge",
    (tester) async {
      final controller = OcptFloorPlanViewportController(zoom: 1);
      final symbol = _cameraSymbol(xM: 0, yM: 0);
      final fovChangedTo = <double>[];

      await _pumpCanvas(
        tester,
        OcptFloorPlanCanvas(
          floorPlanSet: OcptFloorPlanSet(
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
          ),
          shotRankByShotId: const {"shot-1": 1},
          focusShotId: "shot-1",
          previousShotId: null,
          nextShotId: null,
          isOnionSkinPreviousShown: false,
          isOnionSkinNextShown: false,
          onionSkinOpacity: 0.3,
          hiddenLayers: const {},
          hiddenCameraSymbolIds: const {},
          isUnderlayHidden: false,
          selectedSymbolId: symbol.id,
          selectedArrowId: null,
          pendingArrowAnchorSymbolId: null,
          isMetricsShown: false,
          activeTool: OcptFloorPlanTool.select,
          activeLayer: OcptFloorPlanLayer.set,
          viewportController: controller,
          isReadOnly: false,
          symbolLabelValueOf: (_) => "",
          onSymbolSelected: (_) {},
          onSymbolPlaced: (_, __, ___, ____) {},
          onSymbolMoved: (_, __, ___) {},
          onSymbolResized: (_, __, ___) {},
          onSymbolRotated: (_, __) {},
          onSymbolFovChanged: (_, fovDeg) => fovChangedTo.add(fovDeg),
          onSymbolDeleteRequested: (_) {},
          onArrowSymbolTapped: (_) {},
          onArrowAnchorCancelled: () {},
          onArrowSelected: (_) {},
          onArrowCurveChanged: (_, __, ___) {},
          onSymbolDuplicateRequested: (_) {},
          onSymbolDuplicateDragged: (_, __, ___) {},
          onGhostShotFocusRequested: (_) {},
          onSymbolLabelChanged: (_, __) {},
          onUnderlayTransformChanged: (_, __, ___, ____) {},
          onZoomSettled: (_) {},
        ),
      );

      final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
      final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));
      final pixelsPerMetre = controller.zoom * 48;
      final centreScreen = ocptFloorPlanScreenPointOf(
        xM: symbol.xM,
        yM: symbol.yM,
        canvasSize: canvasSize,
        zoom: controller.zoom,
        pan: controller.pan,
      );

      final halfAngleRad = ocptFloorPlanDefaultCameraFovDeg * math.pi / 180 / 2;
      final wedgeLengthPx = ocptFloorPlanCameraFovWedgeLengthM * pixelsPerMetre;
      final tipLocalPx = Offset(0, -ocptFloorPlanCameraFootprintM / 2 * pixelsPerMetre);
      final rightHandleScreen =
          centreScreen +
          tipLocalPx +
          Offset(math.sin(halfAngleRad), -math.cos(halfAngleRad)) * wedgeLengthPx;

      // Drag the right edge handle out to a 40° bearing from the camera's own forward
      // direction (0° = up): the wedge is symmetric, so the new field of view is 2 × 40 = 80°.
      const targetBearingDeg = 40.0;
      final targetBearingRad = targetBearingDeg * math.pi / 180;
      final target =
          centreScreen + Offset(math.sin(targetBearingRad), -math.cos(targetBearingRad)) * 150;

      final gesture = await tester.startGesture(canvasTopLeft + rightHandleScreen);
      await gesture.moveTo(canvasTopLeft + target);
      await gesture.up();
      await tester.pump();

      expect(fovChangedTo, hasLength(1));
      expect(fovChangedTo.single, closeTo(80, 1e-6));
    },
  );

  testWidgets(
    "selecting an arrow near its shaft, bending it, then straightening it back out",
    (tester) async {
      final controller = OcptFloorPlanViewportController(zoom: 1);
      var floorPlanSet = _caseWithArrow();
      final arrowSelectedTo = <String?>[];
      final arrowCurveChangedTo = <({double? ctrlXM, double? ctrlYM})>[];

      Widget buildCanvas({required String? selectedArrowId}) => OcptFloorPlanCanvas(
        floorPlanSet: floorPlanSet,
        shotRankByShotId: const {"shot-1": 1},
        focusShotId: "shot-1",
        previousShotId: null,
        nextShotId: null,
        isOnionSkinPreviousShown: false,
        isOnionSkinNextShown: false,
        onionSkinOpacity: 0.3,
        hiddenLayers: const {},
        hiddenCameraSymbolIds: const {},
        isUnderlayHidden: false,
        selectedSymbolId: null,
        selectedArrowId: selectedArrowId,
        pendingArrowAnchorSymbolId: null,
        isMetricsShown: false,
        activeTool: OcptFloorPlanTool.select,
        activeLayer: OcptFloorPlanLayer.set,
        viewportController: controller,
        isReadOnly: false,
        symbolLabelValueOf: (_) => "",
        onSymbolSelected: (_) {},
        onSymbolPlaced: (_, __, ___, ____) {},
        onSymbolMoved: (_, __, ___) {},
        onSymbolResized: (_, __, ___) {},
        onSymbolRotated: (_, __) {},
        onSymbolFovChanged: (_, __) {},
        onSymbolDeleteRequested: (_) {},
        onArrowSymbolTapped: (_) {},
        onArrowAnchorCancelled: () {},
        onArrowSelected: arrowSelectedTo.add,
        onArrowCurveChanged: (_, ctrlXM, ctrlYM) =>
            arrowCurveChangedTo.add((ctrlXM: ctrlXM, ctrlYM: ctrlYM)),
        onSymbolDuplicateRequested: (_) {},
        onSymbolDuplicateDragged: (_, __, ___) {},
        onGhostShotFocusRequested: (_) {},
        onSymbolLabelChanged: (_, __) {},
        onUnderlayTransformChanged: (_, __, ___, ____) {},
        onZoomSettled: (_) {},
      );

      await _pumpCanvas(tester, buildCanvas(selectedArrowId: null));

      final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
      final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));
      final fromScreen = ocptFloorPlanScreenPointOf(
        xM: 0,
        yM: 0,
        canvasSize: canvasSize,
        zoom: controller.zoom,
        pan: controller.pan,
      );
      final toScreen = ocptFloorPlanScreenPointOf(
        xM: 3,
        yM: 0,
        canvasSize: canvasSize,
        zoom: controller.zoom,
        pan: controller.pan,
      );
      final midpointScreen = Offset(
        (fromScreen.dx + toScreen.dx) / 2,
        (fromScreen.dy + toScreen.dy) / 2,
      );

      // A tap on empty canvas, near the straight shaft's own midpoint (well clear of either
      // symbol's own footprint) selects the arrow under `select`.
      await tester.tapAt(canvasTopLeft + midpointScreen);
      await tester.pump();
      expect(arrowSelectedTo, ["arrow-1"]);

      // Re-pump with the arrow now selected, so its own midpoint handle (starting, with no
      // `ctrlXM`/`ctrlYM` of its own yet, exactly at the straight line's own midpoint) draws.
      await _pumpCanvas(tester, buildCanvas(selectedArrowId: "arrow-1"));

      const bendTarget = Offset(0, -60);
      final bendGesture = await tester.startGesture(canvasTopLeft + midpointScreen);
      await bendGesture.moveTo(canvasTopLeft + midpointScreen + bendTarget);
      await bendGesture.up();
      await tester.pump();

      expect(arrowCurveChangedTo, hasLength(1));
      final pixelsPerMetre = controller.zoom * 48;
      final bentCtrlXM = arrowCurveChangedTo.single.ctrlXM!;
      final bentCtrlYM = arrowCurveChangedTo.single.ctrlYM!;
      expect(bentCtrlXM, closeTo(1.5, 1e-6));
      expect(bentCtrlYM, closeTo(bendTarget.dy / pixelsPerMetre, 1e-6));

      // Re-pump with the arrow's own curve now written (mirroring the bloc reloading the
      // snapshot after the drag's own settled write), so the handle actually renders at its new,
      // bent position before the next gesture starts.
      floorPlanSet = _caseWithArrow(ctrlXM: bentCtrlXM, ctrlYM: bentCtrlYM);
      await _pumpCanvas(tester, buildCanvas(selectedArrowId: "arrow-1"));

      // Dragging the (now bent) handle back onto the straight from-to line straightens the arrow
      // back out instead of writing a new, barely-off-straight curve.
      final bentHandleScreen = midpointScreen + bendTarget;
      final straightenGesture = await tester.startGesture(canvasTopLeft + bentHandleScreen);
      await straightenGesture.moveTo(canvasTopLeft + midpointScreen);
      await straightenGesture.up();
      await tester.pump();

      expect(arrowCurveChangedTo, hasLength(2));
      expect(arrowCurveChangedTo.last.ctrlXM, isNull);
      expect(arrowCurveChangedTo.last.ctrlYM, isNull);
    },
  );
}
