// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_view.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_fit.dart';

/// Wraps [child] with the localization delegates so `Tr.of` lookups resolve, and sets the test
/// surface past the 800 px compact breakpoint (`docs/architecture/foundations.md`).
Future<void> _pumpView(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 800);
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
      home: Scaffold(body: child),
    ),
  );
}

/// A set-scope set-element symbol at ([xM], [yM]) on set [setId].
OcptFloorPlanSymbol _furnitureSymbol(String setId, String symbolId, double xM, double yM) =>
    OcptFloorPlanSymbol(
      id: symbolId,
      setId: setId,
      sceneId: null,
      shotId: null,
      layer: OcptFloorPlanLayer.set,
      sortKey: "a0",
      xM: xM,
      yM: yM,
      rotationDeg: 0,
      widthM: null,
      heightM: null,
      fovDeg: null,
      fovReachM: null,
      label: "",
      setElementShape: null,
      overridesSymbolId: null,
      isHidden: false,
    );

OcptFloorPlanSet _setOf(String id, List<OcptFloorPlanSymbol> symbols) => OcptFloorPlanSet(
  id: id,
  name: "Set $id",
  underlayAssetId: null,
  underlayPath: null,
  underlayXM: null,
  underlayYM: null,
  underlayWidthM: null,
  underlayHeightM: null,
  underlayRotationDeg: null,
  symbols: symbols,
  arrows: const [],
);

void main() {
  /// Builds a minimal [OcptFloorPlanView] over [floorPlanSet], reporting every settled zoom into
  /// [zoomSettledTo] — every write callback a plain no-op, since these tests are about framing
  /// (item 4), not about placement or editing.
  Widget viewOf({required OcptFloorPlanSet? floorPlanSet, required List<double> zoomSettledTo}) =>
      OcptFloorPlanView(
        floorPlanSet: floorPlanSet,
        shots: const [],
        shotRankByShotId: const {},
        focusSceneId: "scene-1",
        sequenceCode: "1",
        focusShotId: null,
        previousShotId: null,
        nextShotId: null,
        hasCameraOnSetOf: const {},
        sequenceCameras: const [],
        initialZoom: 1,
        hiddenLayers: const {},
        hiddenCameraSymbolIds: const {},
        isUnderlayHidden: false,
        isOnionSkinPreviousShown: false,
        isOnionSkinNextShown: false,
        onionSkinOpacity: 0.3,
        isMetricsShown: false,
        selectedSymbolId: null,
        selectedArrowId: null,
        pendingArrowAnchorSymbolId: null,
        activeTool: OcptFloorPlanTool.select,
        activeLayer: OcptFloorPlanLayer.set,
        activeSetElementShape: OcptFloorPlanSetElementShape.wall,
        activeSetElementScope: OcptFloorPlanScope.set,
        activeLabel: "",
        propsChips: const [],
        isReadOnly: false,
        symbolLabelValueOf: (_) => "",
        onToolSelected: (_) {},
        onLayerVisibilityToggled: (_) {},
        onActiveLayerChanged: (_) {},
        onSetElementShapeSelected: (_) {},
        onSetElementScopeSelected: (_) {},
        onPropChipSelected: (_) {},
        onCameraVisibilityToggled: (_) {},
        onOnionSkinToggled: (_) {},
        onOnionSkinOpacityChanged: (_) {},
        onMetricsToggled: () {},
        onUnderlayVisibilityToggled: () {},
        onUnderlayImportRequested: null,
        onUnderlayClearRequested: null,
        onSymbolSelected: (_) {},
        onSymbolPlaced: null,
        onSymbolMoved: null,
        onSymbolResized: null,
        onSymbolRotated: null,
        onSymbolFovChanged: null,
        onSymbolFovReachChanged: null,
        onSymbolDeleteRequested: null,
        onSymbolRestoreRequested: null,
        onArrowSymbolTapped: null,
        onArrowAnchorCancelled: null,
        onArrowSelected: (_) {},
        onArrowCurveChanged: null,
        onSymbolDuplicateRequested: null,
        onSymbolDuplicateDragged: null,
        onGhostShotFocusRequested: (_) {},
        onSymbolLabelChanged: null,
        onUnderlayTransformChanged: null,
        onZoomSettled: zoomSettledTo.add,
        onShotChipSelected: (_) {},
        onShotWalkRequested: (_) {},
      );

  /// The zoom [ocptFloorPlanFitOf] would fit [floorPlanSet]'s own content to inside a canvas of
  /// [canvasSize] — the same computation `_OcptFloorPlanViewState._fitToContent` makes, so a test
  /// can assert the exact reported value rather than just "it changed".
  double expectedFitZoom(OcptFloorPlanSet floorPlanSet, Size canvasSize) {
    final sheet = OcptFloorPlanSheet.of(
      floorPlanSet: floorPlanSet,
      focusSceneId: "scene-1",
      focusShotId: null,
      shotRankByShotId: const {},
    );
    return ocptFloorPlanFitOf(
      sheet: sheet,
      viewportWidthPx: canvasSize.width,
      viewportHeightPx: canvasSize.height,
    ).zoom;
  }

  testWidgets(
    "fits the viewport to content once a set opens, but not on an unrelated rebuild",
    (tester) async {
      final setA = _setOf("set-a", [_furnitureSymbol("set-a", "sym-1", 5, 3)]);
      final zoomSettledTo = <double>[];

      await _pumpView(tester, viewOf(floorPlanSet: setA, zoomSettledTo: zoomSettledTo));
      await tester.pumpAndSettle();

      expect(zoomSettledTo, hasLength(1));
      final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
      expect(zoomSettledTo.single, closeTo(expectedFitZoom(setA, canvasSize), 1e-6));

      // An unrelated rebuild of the very same set (its own symbols unchanged, just a fresh equal
      // instance passed down, mirroring a bloc emission) never refits: the guard tracks the set's
      // own id, not object identity.
      await _pumpView(
        tester,
        viewOf(
          floorPlanSet: _setOf("set-a", [_furnitureSymbol("set-a", "sym-1", 5, 3)]),
          zoomSettledTo: zoomSettledTo,
        ),
      );
      await tester.pumpAndSettle();
      expect(zoomSettledTo, hasLength(1));

      // That rebuild still carries the zoom persisted *before* the fit (the bloc's echo has not
      // arrived): the fitted zoom must survive it, or the plan is drawn off-centre with a pan
      // computed for a zoom that no longer applies.
      final controller = tester.widget<OcptFloorPlanCanvas>(find.byType(OcptFloorPlanCanvas))
          .viewportController;
      expect(controller.zoom, closeTo(zoomSettledTo.single, 1e-6));
    },
  );

  testWidgets("switching to a different set's own tab fits its own content", (tester) async {
    final setA = _setOf("set-a", [_furnitureSymbol("set-a", "sym-1", 5, 3)]);
    final setB = _setOf("set-b", [_furnitureSymbol("set-b", "sym-2", -6, -4)]);
    final zoomSettledTo = <double>[];

    await _pumpView(tester, viewOf(floorPlanSet: setA, zoomSettledTo: zoomSettledTo));
    await tester.pumpAndSettle();
    expect(zoomSettledTo, hasLength(1));

    await _pumpView(tester, viewOf(floorPlanSet: setB, zoomSettledTo: zoomSettledTo));
    await tester.pumpAndSettle();

    expect(zoomSettledTo, hasLength(2));
    final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
    expect(zoomSettledTo.last, closeTo(expectedFitZoom(setB, canvasSize), 1e-6));
  });

  testWidgets("an empty plan is left at the default view, no fit reported", (tester) async {
    final zoomSettledTo = <double>[];

    await _pumpView(
      tester,
      viewOf(floorPlanSet: _setOf("set-empty", const []), zoomSettledTo: zoomSettledTo),
    );
    await tester.pumpAndSettle();

    expect(zoomSettledTo, isEmpty);
  });

  testWidgets("the Recenter button fits the viewport back onto the content on demand", (
    tester,
  ) async {
    final setA = _setOf("set-a", [_furnitureSymbol("set-a", "sym-1", 5, 3)]);
    final zoomSettledTo = <double>[];

    await _pumpView(tester, viewOf(floorPlanSet: setA, zoomSettledTo: zoomSettledTo));
    await tester.pumpAndSettle();
    expect(zoomSettledTo, hasLength(1));

    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanView)));
    await tester.tap(find.byTooltip(tr.shotListFloorPlanRecenterAction));
    await tester.pumpAndSettle();

    expect(zoomSettledTo, hasLength(2));
    final canvasSize = tester.getSize(find.byType(OcptFloorPlanCanvas));
    expect(zoomSettledTo.last, closeTo(expectedFitZoom(setA, canvasSize), 1e-6));
  });
}
