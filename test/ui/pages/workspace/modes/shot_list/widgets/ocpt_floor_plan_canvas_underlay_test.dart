// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_underlay_visual.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_viewport_controller.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';
import 'ocpt_floor_plan_canvas_test_doubles.dart';

/// Run the tests of the floor plan canvas under a set holding an underlay.
void main() {
  /// Build an [OcptFloorPlanCanvas] over a set whose underlay image is the file at [imagePath],
  /// hidden or not.
  Widget canvasOf({required String imagePath, bool isUnderlayHidden = false}) {
    final symbol = furnitureSymbol(xM: 0, yM: 0);

    return OcptFloorPlanCanvas(
      floorPlanSet: OcptFloorPlanSet(
        id: "case-1",
        name: "Case",
        underlayAssetId: "asset-1",
        underlayPath: imagePath,
        underlayXM: -2,
        underlayYM: -1,
        underlayWidthM: 4,
        underlayHeightM: 2,
        underlayRotationDeg: 0,
        symbols: [symbol],
        arrows: const [],
      ),
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
      isUnderlayHidden: isUnderlayHidden,
      selectedSymbolId: symbol.id,
      selectedArrowId: null,
      pendingArrowAnchorSymbolId: null,
      isMetricsShown: false,
      activeTool: OcptFloorPlanTool.select,
      activeSetElementShape: OcptFloorPlanSetElementShape.wall,
      activeSetElementScope: OcptFloorPlanScope.set,
      activeLabel: "",
      viewportController: OcptFloorPlanViewportController(zoom: 1),
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
      onArrowSelected: (_) {},
      onArrowCurveChanged: (_, __, ___) {},
      onSymbolDuplicateRequested: (_) {},
      onSymbolDuplicateDragged: (_, __, ___) {},
      onGhostShotFocusRequested: (_) {},
      onSymbolLabelChanged: (_, __) {},
      onUnderlayTransformChanged: (_, __, ___, ____) {},
      onZoomSettled: (_) {},
    );
  }

  /// Write a 1x1 PNG into a fresh temporary directory and get its path.
  String writeImage() {
    final dir = Directory.systemTemp.createTempSync("ocpt_underlay_test");
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File("${dir.path}/plan.png")
      ..writeAsBytesSync(
        base64Decode(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf"
          "DwAChwGA60e6kgAAAABJRU5ErkJggg==",
        ),
      );

    return file.path;
  }

  testWidgets("a visible underlay mounts without error and sits at its screen rect", (
    tester,
  ) async {
    await pumpCanvas(tester, canvasOf(imagePath: writeImage()));

    expect(tester.takeException(), isNull);
    expect(find.byType(OcptFloorPlanUnderlayVisual), findsOneWidget);

    final visual = tester.widget<OcptFloorPlanUnderlayVisual>(
      find.byType(OcptFloorPlanUnderlayVisual),
    );
    final canvasTopLeft = tester.getTopLeft(find.byType(OcptFloorPlanCanvas));
    final imageRect = tester.getRect(find.byType(OcptReferencedImage));

    expect(visual.rect.size, isNot(Size.zero));
    expect(imageRect.topLeft - canvasTopLeft, offsetMoreOrLessEquals(visual.rect.topLeft));
    expect(imageRect.size, visual.rect.size);
  });

  testWidgets("a hidden underlay draws no visual", (tester) async {
    await pumpCanvas(tester, canvasOf(imagePath: writeImage(), isUnderlayHidden: true));

    expect(tester.takeException(), isNull);
    expect(find.byType(OcptFloorPlanUnderlayVisual), findsNothing);
  });
}
