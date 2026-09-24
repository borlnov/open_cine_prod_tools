// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_placements_group.dart';

/// Wraps [child] with the localization delegates so `Tr.of` lookups resolve.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      home: Scaffold(body: SizedBox(width: 300, height: 700, child: child)),
    ),
  );
}

/// A symbol shape with everything but the fields under test defaulted.
OcptFloorPlanSymbolShape _symbol({
  required String symbolId,
  OcptFloorPlanLayer layer = OcptFloorPlanLayer.characters,
  String label = "SAM",
}) => OcptFloorPlanSymbolShape(
  symbolId: symbolId,
  shotId: "shot-1",
  layer: layer,
  xM: 0,
  yM: 0,
  rotationDeg: 0,
  widthM: 0.5,
  heightM: 0.5,
  fovDeg: null,
  fovReachM: null,
  label: label,
  colorArgb: 0xFFFF9800,
  cameraLabel: layer == OcptFloorPlanLayer.cameras ? "1" : null,
  isGhost: false,
  glyphKind: layer == OcptFloorPlanLayer.cameras
      ? OcptFloorPlanSymbolGlyphKind.camera
      : OcptFloorPlanSymbolGlyphKind.character,
  cameraFovWedgeDeg: null,
  cameraFovWedgeReachM: null,
  setElementShape: null,
);

Widget _buildGroup({
  String? selectedSymbolId,
  String? selectedArrowId,
  List<OcptFloorPlanSymbolShape> characters = const [],
}) => OcptFloorPlanPlacementsGroup(
  setName: "Kitchen",
  selectedSymbolId: selectedSymbolId,
  selectedArrowId: selectedArrowId,
  cameras: const [],
  characters: characters,
  lights: const [],
  handProps: const [],
  arrows: const [],
  otherSets: const [],
  isReadOnly: false,
  onSymbolDeleteRequested: (_) {},
  onArrowDeleteRequested: (_) {},
  onCameraFovChanged: (_, __) {},
);

void main() {
  testWidgets("shows the three headed sections: Selection, On this shot, Set", (tester) async {
    await _pump(tester, _buildGroup());
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPlacementsGroup)));

    expect(find.text(tr.shotListFloorPlanSelectionGroupTitle), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanOnThisShotGroupTitle), findsOneWidget);
  });

  testWidgets("the Selection section shows the nothing-selected hint while nothing is selected", (
    tester,
  ) async {
    await _pump(tester, _buildGroup());
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPlacementsGroup)));

    expect(find.text(tr.shotListFloorPlanSelectionNoneHint), findsOneWidget);
  });

  testWidgets(
    "the Selection section shows the selected symbol's own read-out, not the nothing-selected "
    "hint",
    (tester) async {
      final character = _symbol(symbolId: "sym-1");

      await _pump(
        tester,
        _buildGroup(selectedSymbolId: "sym-1", characters: [character]),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPlacementsGroup)));

      expect(find.text(tr.shotListFloorPlanSelectionNoneHint), findsNothing);
      // "SAM" appears twice: once in the Selection section, once in the On this shot section's
      // own Characters list — both read the very same live placement.
      expect(find.text("SAM"), findsNWidgets(2));
    },
  );

  testWidgets(
    "the Set section and its own header only show once the sequence holds another set",
    (tester) async {
      await _pump(tester, _buildGroup());
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPlacementsGroup)));

      expect(find.text(tr.shotListFloorPlanSetGroupTitle), findsNothing);

      await _pump(
        tester,
        OcptFloorPlanPlacementsGroup(
          setName: "Kitchen",
          selectedSymbolId: null,
          selectedArrowId: null,
          cameras: const [],
          characters: const [],
          lights: const [],
          handProps: const [],
          arrows: const [],
          otherSets: const [
            OcptFloorPlanPlacementsOtherSet(setName: "Hallway", cameraCount: 0),
          ],
          isReadOnly: false,
          onSymbolDeleteRequested: (_) {},
          onArrowDeleteRequested: (_) {},
          onCameraFovChanged: (_, __) {},
        ),
      );

      expect(find.text(tr.shotListFloorPlanSetGroupTitle), findsOneWidget);
    },
  );
}
