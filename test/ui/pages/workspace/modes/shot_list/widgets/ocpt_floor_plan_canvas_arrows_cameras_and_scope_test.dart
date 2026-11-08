// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_arrow.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas_painter.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_symbol_live_override.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';
import 'ocpt_floor_plan_canvas_test_doubles.dart';

/// Two shot-scoped character symbols, connected by one movement arrow (bent through [ctrlXM]/
/// [ctrlYM] when given, straight otherwise), on set `case-1` and shot `shot-1` —
/// [OcptFloorPlanCanvas.focusShotId] must be `"shot-1"` for both to be editable/selectable.
OcptFloorPlanSet _caseWithArrow({double? ctrlXM, double? ctrlYM}) {
  const fromSymbol = OcptFloorPlanSymbol(
    id: "sym-from",
    setId: "case-1",
    sceneId: null,
    shotId: "shot-1",
    layer: OcptFloorPlanLayer.characters,
    sortKey: "a0",
    xM: 0,
    yM: 0,
    rotationDeg: 0,
    widthM: null,
    heightM: null,
    fovDeg: null,
    fovReachM: null,
    label: "SAM",
    setElementShape: null,
    overridesSymbolId: null,
    isHidden: false,
  );
  const toSymbol = OcptFloorPlanSymbol(
    id: "sym-to",
    setId: "case-1",
    sceneId: null,
    shotId: "shot-1",
    layer: OcptFloorPlanLayer.characters,
    sortKey: "a1",
    xM: 3,
    yM: 0,
    rotationDeg: 0,
    widthM: null,
    heightM: null,
    fovDeg: null,
    fovReachM: null,
    label: "LEA",
    setElementShape: null,
    overridesSymbolId: null,
    isHidden: false,
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
    name: "Case",
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

/// Run the tests of the floor plan canvas arrows cameras and scope.
void main() {
  /// Builds an [OcptFloorPlanCanvas] under the `select` tool, focused on the `Sequence` scope (so
  /// the sequence-layer [symbol] is editable), reporting every move/resize into
  /// [movedTo]/[resizedTo].
  Widget canvasOf({
    required OcptFloorPlanSymbol symbol,
    required OcptFloorPlanViewportController controller,
    required List<({double xM, double yM})> movedTo,
    required List<({double widthM, double heightM})> resizedTo,
    List<double>? rotatedTo,
    List<double>? fovChangedTo,
    List<double>? fovReachChangedTo,
    String? selectedArrowId,
    List<String?>? arrowSelectedTo,
    List<({double? ctrlXM, double? ctrlYM})>? arrowCurveChangedTo,
    OcptFloorPlanSymbolLiveOverride? pendingScopeLiveOverride,
    String? scopeBubbleEveryLabel,
    String? scopeBubbleOnlyLabel,
    String? scopeBubbleCancelLabel,
    VoidCallback? onScopeBubbleEveryRequested,
    VoidCallback? onScopeBubbleOnlyRequested,
    VoidCallback? onScopeBubbleCancelRequested,
  }) => OcptFloorPlanCanvas(
    floorPlanSet: caseOf(symbol),
    shotRankByShotId: const {},
    focusSceneId: "scene-1",
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
    activeSetElementShape: OcptFloorPlanSetElementShape.wall,
    activeSetElementScope: OcptFloorPlanScope.set,
    activeLabel: "",
    viewportController: controller,
    isReadOnly: false,
    symbolLabelValueOf: (_) => "",
    onSymbolSelected: (_) {},
    onSymbolPlaced: (_, __, ___, ____, _____, {setElementShape, label = ""}) {},
    onSymbolMoved: (_, xM, yM) => movedTo.add((xM: xM, yM: yM)),
    onSymbolResized: (_, widthM, heightM) => resizedTo.add((widthM: widthM, heightM: heightM)),
    onSymbolRotated: (_, rotationDeg) => rotatedTo?.add(rotationDeg),
    onSymbolFovChanged: (_, fovDeg) => fovChangedTo?.add(fovDeg),
    onSymbolFovReachChanged: (_, fovReachM) => fovReachChangedTo?.add(fovReachM),
    onSymbolDeleteRequested: (_) {},
    onSymbolRestoreRequested: (_) {},
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
    pendingScopeLiveOverride: pendingScopeLiveOverride,
    scopeBubbleEveryLabel: scopeBubbleEveryLabel,
    scopeBubbleOnlyLabel: scopeBubbleOnlyLabel,
    scopeBubbleCancelLabel: scopeBubbleCancelLabel,
    onScopeBubbleEveryRequested: onScopeBubbleEveryRequested,
    onScopeBubbleOnlyRequested: onScopeBubbleOnlyRequested,
    onScopeBubbleCancelRequested: onScopeBubbleCancelRequested,
  );

  testWidgets("selecting an arrow near its shaft, bending it, then straightening it back out", (
    tester,
  ) async {
    final controller = OcptFloorPlanViewportController(zoom: 1);
    var floorPlanSet = _caseWithArrow();
    final arrowSelectedTo = <String?>[];
    final arrowCurveChangedTo = <({double? ctrlXM, double? ctrlYM})>[];

    Widget buildCanvas({required String? selectedArrowId}) => OcptFloorPlanCanvas(
      floorPlanSet: floorPlanSet,
      shotRankByShotId: const {"shot-1": 1},
      focusSceneId: "scene-1",
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
      activeSetElementShape: OcptFloorPlanSetElementShape.wall,
      activeSetElementScope: OcptFloorPlanScope.set,
      activeLabel: "",
      viewportController: controller,
      isReadOnly: false,
      symbolLabelValueOf: (_) => "",
      onSymbolSelected: (_) {},
      onSymbolPlaced: (_, __, ___, ____, _____, {setElementShape, label = ""}) {},
      onSymbolMoved: (_, __, ___) {},
      onSymbolResized: (_, __, ___) {},
      onSymbolRotated: (_, __) {},
      onSymbolFovChanged: (_, __) {},
      onSymbolFovReachChanged: (_, __) {},
      onSymbolDeleteRequested: (_) {},
      onSymbolRestoreRequested: (_) {},
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

    await pumpCanvas(tester, buildCanvas(selectedArrowId: null));

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
    await pumpCanvas(tester, buildCanvas(selectedArrowId: "arrow-1"));

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
    await pumpCanvas(tester, buildCanvas(selectedArrowId: "arrow-1"));

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
  });

  testWidgets("hiding a camera drops it from the sheet with a shot focused", (tester) async {
    final controller = OcptFloorPlanViewportController(zoom: 1);
    final symbol = cameraSymbol(xM: 0, yM: 0);
    final selectedTo = <String?>[];

    Widget buildCanvas({required Set<String> hiddenCameraSymbolIds}) => OcptFloorPlanCanvas(
      floorPlanSet: caseOf(symbol),
      shotRankByShotId: const {"shot-1": 1},
      focusSceneId: "scene-1",
      focusShotId: "shot-1",
      previousShotId: null,
      nextShotId: null,
      isOnionSkinPreviousShown: false,
      isOnionSkinNextShown: false,
      onionSkinOpacity: 0.3,
      hiddenLayers: const {},
      hiddenCameraSymbolIds: hiddenCameraSymbolIds,
      isUnderlayHidden: false,
      selectedSymbolId: null,
      selectedArrowId: null,
      pendingArrowAnchorSymbolId: null,
      isMetricsShown: false,
      activeTool: OcptFloorPlanTool.select,
      activeSetElementShape: OcptFloorPlanSetElementShape.wall,
      activeSetElementScope: OcptFloorPlanScope.set,
      activeLabel: "",
      viewportController: controller,
      isReadOnly: false,
      symbolLabelValueOf: (_) => "",
      onSymbolSelected: selectedTo.add,
      onSymbolPlaced: (_, __, ___, ____, _____, {setElementShape, label = ""}) {},
      onSymbolMoved: (_, __, ___) {},
      onSymbolResized: (_, __, ___) {},
      onSymbolRotated: (_, __) {},
      onSymbolFovChanged: (_, __) {},
      onSymbolFovReachChanged: (_, __) {},
      onSymbolDeleteRequested: (_) {},
      onSymbolRestoreRequested: (_) {},
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
    );

    // Visible: tapping the camera's own screen position selects it.
    await pumpCanvas(tester, buildCanvas(hiddenCameraSymbolIds: const {}));
    final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
    final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));
    final centreScreen = ocptFloorPlanScreenPointOf(
      xM: symbol.xM,
      yM: symbol.yM,
      canvasSize: canvasSize,
      zoom: controller.zoom,
      pan: controller.pan,
    );
    await tester.tapAt(canvasTopLeft + centreScreen);
    await tester.pump();
    expect(selectedTo, ["cam-1"]);

    // Hidden (the toggle a shot focus used to ignore): the very same tap now hits empty
    // canvas — no hit overlay was built for it at all — and clears the selection instead.
    selectedTo.clear();
    await pumpCanvas(tester, buildCanvas(hiddenCameraSymbolIds: const {"cam-1"}));
    await tester.tapAt(canvasTopLeft + centreScreen);
    await tester.pump();
    expect(selectedTo, [null]);
  });

  testWidgets("a camera has no resize handle (characters and lights keep theirs)", (tester) async {
    final controller = OcptFloorPlanViewportController(zoom: 1);
    final symbol = cameraSymbol(xM: 0, yM: 0);
    final resizedTo = <({double widthM, double heightM})>[];

    await pumpCanvas(
      tester,
      OcptFloorPlanCanvas(
        floorPlanSet: caseOf(symbol),
        shotRankByShotId: const {"shot-1": 1},
        focusSceneId: "scene-1",
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
        activeSetElementShape: OcptFloorPlanSetElementShape.wall,
        activeSetElementScope: OcptFloorPlanScope.set,
        activeLabel: "",
        viewportController: controller,
        isReadOnly: false,
        symbolLabelValueOf: (_) => "",
        onSymbolSelected: (_) {},
        onSymbolPlaced: (_, __, ___, ____, _____, {setElementShape, label = ""}) {},
        onSymbolMoved: (_, __, ___) {},
        onSymbolResized: (_, widthM, heightM) => resizedTo.add((widthM: widthM, heightM: heightM)),
        onSymbolRotated: (_, __) {},
        onSymbolFovChanged: (_, __) {},
        onSymbolFovReachChanged: (_, __) {},
        onSymbolDeleteRequested: (_) {},
        onSymbolRestoreRequested: (_) {},
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
    const cameraFootprintM = 0.3; // ocptFloorPlanCameraFootprintM
    final resizeScreen = ocptFloorPlanScreenPointOf(
      xM: symbol.xM + cameraFootprintM / 2,
      yM: symbol.yM + cameraFootprintM / 2,
      canvasSize: canvasSize,
      zoom: controller.zoom,
      pan: controller.pan,
    );

    // Where a resize handle would sit on any other symbol: a drag started there on a camera must
    // never report a resize — either no handle caught the gesture at all, or the field-of-view
    // wedge's own edge handle happens to sit nearby and reports through its own callback instead.
    final gesture = await tester.startGesture(canvasTopLeft + resizeScreen);
    await gesture.moveBy(const Offset(20, 20));
    await gesture.up();
    await tester.pump();

    expect(resizedTo, isEmpty);
  });

  group("the scope bubble", () {
    testWidgets("shows nothing while no scope decision is pending", (tester) async {
      final controller = OcptFloorPlanViewportController(zoom: 1);
      await pumpCanvas(
        tester,
        canvasOf(
          symbol: furnitureSymbol(xM: 0, yM: 0),
          controller: controller,
          movedTo: [],
          resizedTo: [],
        ),
      );

      expect(find.text("Every sequence (3)"), findsNothing);
    });

    testWidgets(
      "shows the three actions once a decision is pending, each calling its own callback",
      (tester) async {
        final controller = OcptFloorPlanViewportController(zoom: 1);
        var everyRequested = false;
        var onlyRequested = false;
        var cancelRequested = false;

        await pumpCanvas(
          tester,
          canvasOf(
            symbol: furnitureSymbol(xM: 0, yM: 0),
            controller: controller,
            movedTo: [],
            resizedTo: [],
            pendingScopeLiveOverride: const OcptFloorPlanSymbolLiveOverride(
              symbolId: "sym-1",
              xM: 2,
              yM: 2,
              widthM: 0.5,
              heightM: 0.5,
              rotationDeg: 0,
            ),
            scopeBubbleEveryLabel: "Every sequence (3)",
            scopeBubbleOnlyLabel: "Only sequence 7",
            scopeBubbleCancelLabel: "Cancel",
            onScopeBubbleEveryRequested: () => everyRequested = true,
            onScopeBubbleOnlyRequested: () => onlyRequested = true,
            onScopeBubbleCancelRequested: () => cancelRequested = true,
          ),
        );

        expect(find.text("Every sequence (3)"), findsOneWidget);
        expect(find.text("Only sequence 7"), findsOneWidget);
        expect(find.text("Cancel"), findsOneWidget);

        await tester.tap(find.text("Only sequence 7"));
        await tester.pump();
        expect(onlyRequested, isTrue);
        expect(everyRequested, isFalse);
        expect(cancelRequested, isFalse);

        await tester.tap(find.text("Every sequence (3)"));
        await tester.pump();
        expect(everyRequested, isTrue);

        await tester.tap(find.text("Cancel"));
        await tester.pump();
        expect(cancelRequested, isTrue);
      },
    );

    testWidgets(
      "clicking empty canvas while the bubble is showing calls onScopeBubbleCancelRequested, "
      "not the plain background-tap handling",
      (tester) async {
        final controller = OcptFloorPlanViewportController(zoom: 1);
        var cancelRequested = false;
        String? selected = "sym-1";

        await pumpCanvas(
          tester,
          OcptFloorPlanCanvas(
            floorPlanSet: caseOf(furnitureSymbol(xM: 0, yM: 0)),
            shotRankByShotId: const {},
            focusSceneId: "scene-1",
            focusShotId: null,
            previousShotId: null,
            nextShotId: null,
            isOnionSkinPreviousShown: false,
            isOnionSkinNextShown: false,
            onionSkinOpacity: 0.3,
            hiddenLayers: const {},
            hiddenCameraSymbolIds: const {},
            isUnderlayHidden: false,
            selectedSymbolId: "sym-1",
            selectedArrowId: null,
            pendingArrowAnchorSymbolId: null,
            isMetricsShown: false,
            activeTool: OcptFloorPlanTool.select,
            activeSetElementShape: OcptFloorPlanSetElementShape.wall,
            activeSetElementScope: OcptFloorPlanScope.set,
            activeLabel: "",
            viewportController: controller,
            isReadOnly: false,
            symbolLabelValueOf: (_) => "",
            onSymbolSelected: (symbolId) => selected = symbolId,
            onSymbolPlaced: (_, __, ___, ____, _____, {setElementShape, label = ""}) {},
            onSymbolMoved: (_, __, ___) {},
            onSymbolResized: (_, __, ___) {},
            onSymbolRotated: (_, __) {},
            onSymbolFovChanged: (_, __) {},
            onSymbolFovReachChanged: (_, __) {},
            onSymbolDeleteRequested: (_) {},
            onSymbolRestoreRequested: (_) {},
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
            pendingScopeLiveOverride: const OcptFloorPlanSymbolLiveOverride(
              symbolId: "sym-1",
              xM: 0,
              yM: 0,
              widthM: 0.5,
              heightM: 0.5,
              rotationDeg: 0,
            ),
            scopeBubbleEveryLabel: "Every sequence (3)",
            scopeBubbleOnlyLabel: "Only sequence 7",
            scopeBubbleCancelLabel: "Cancel",
            onScopeBubbleEveryRequested: () {},
            onScopeBubbleOnlyRequested: () {},
            onScopeBubbleCancelRequested: () => cancelRequested = true,
          ),
        );

        // Tap the far corner of the canvas, well away from the symbol and the bubble.
        final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));
        await tester.tapAt(canvasTopLeft + const Offset(5, 5));
        await tester.pump();

        expect(cancelRequested, isTrue);
        // The plain background-tap selection-clearing never ran instead.
        expect(selected, "sym-1");
      },
    );
  });
}
