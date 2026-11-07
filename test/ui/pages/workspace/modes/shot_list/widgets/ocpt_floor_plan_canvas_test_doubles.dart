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

/// Wraps [child] with the localization delegates so `Tr.of` lookups resolve, and sets the test
/// surface past the 800 px compact breakpoint (`docs/architecture/foundations.md`), matching every
/// other shot list widget test.
Future<void> pumpCanvas(WidgetTester tester, Widget child) async {
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
OcptFloorPlanSymbol furnitureSymbol({
  required double xM,
  required double yM,
  double rotationDeg = 0,
}) => OcptFloorPlanSymbol(
  id: "sym-1",
  setId: "case-1",
  sceneId: null,
  shotId: null,
  layer: OcptFloorPlanLayer.set,
  sortKey: "a0",
  xM: xM,
  yM: yM,
  rotationDeg: rotationDeg,
  widthM: null,
  heightM: null,
  fovDeg: null,
  fovReachM: null,
  label: "",
  setElementShape: null,
  overridesSymbolId: null,
  isHidden: false,
);

/// A set holding the single [symbol].
OcptFloorPlanSet caseOf(OcptFloorPlanSymbol symbol) => OcptFloorPlanSet(
  id: "case-1",
  name: "Case",
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
/// drawing default (`ocptFloorPlanDefaultCameraFovDeg`) applies, so its own field-of-view wedge
/// (and edge handles) always draw.
OcptFloorPlanSymbol cameraSymbol({required double xM, required double yM}) => OcptFloorPlanSymbol(
  id: "cam-1",
  setId: "case-1",
  sceneId: null,
  shotId: "shot-1",
  layer: OcptFloorPlanLayer.cameras,
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
