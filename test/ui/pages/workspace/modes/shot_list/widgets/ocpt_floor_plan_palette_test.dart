// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_palette.dart';

/// Wraps [child] with the localization delegates so `Tr.of` lookups resolve, and sets the test
/// surface past the 800 px compact breakpoint (`docs/architecture/foundations.md`), matching every
/// other shot list widget test of this milestone.
Future<void> _pump(WidgetTester tester, Widget child) async {
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
      home: Scaffold(body: SizedBox(width: 220, height: 700, child: child)),
    ),
  );
}

OcptFloorPlanPalette _buildPalette({
  required String setName,
  String? shotCode,
  OcptFloorPlanTool activeTool = OcptFloorPlanTool.select,
  bool isReadOnly = false,
  ValueChanged<OcptFloorPlanTool>? onToolSelected,
}) => OcptFloorPlanPalette(
  setName: setName,
  shotCode: shotCode,
  activeTool: activeTool,
  isReadOnly: isReadOnly,
  hiddenLayers: const {},
  sequenceCameras: const [],
  hiddenCameraSymbolIds: const {},
  isOnionSkinPreviousShown: true,
  isOnionSkinNextShown: true,
  onionSkinOpacity: 0.4,
  isMetricsShown: false,
  isShowFieldOfViewShown: true,
  isUnderlayHidden: false,
  hasUnderlay: false,
  onToolSelected: onToolSelected ?? (_) {},
  onLayerVisibilityToggled: (_) {},
  onCameraVisibilityToggled: (_) {},
  onOnionSkinToggled: (_) {},
  onOnionSkinOpacityChanged: (_) {},
  onMetricsToggled: () {},
  onShowFieldOfViewToggled: () {},
  onUnderlayVisibilityToggled: () {},
  onUnderlayClearRequested: null,
);

void main() {
  testWidgets("shows the Set group header naming the set, and no Shot group without a focused "
      "shot", (tester) async {
    await _pump(tester, _buildPalette(setName: "Kitchen"));
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

    expect(find.text(tr.shotListFloorPlanPaletteSetGroupTitle("Kitchen")), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanPaletteViewGroupTitle), findsOneWidget);
    // No shot focused: the Shot group and its three entries are absent.
    expect(find.text(tr.shotListFloorPlanToolCameraAction), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
  });

  testWidgets("shows the Shot group header naming the focused shot's own code", (tester) async {
    await _pump(tester, _buildPalette(setName: "Kitchen", shotCode: "12/3"));
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

    expect(find.text(tr.shotListFloorPlanPaletteShotGroupTitle("12/3")), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanToolCameraAction), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanToolCharacterAction), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanToolLightAction), findsOneWidget);
  });

  testWidgets("clicking an entry arms its own tool (click-to-arm)", (tester) async {
    OcptFloorPlanTool? armed;
    await _pump(
      tester,
      _buildPalette(
        setName: "Kitchen",
        shotCode: "12/3",
        onToolSelected: (tool) => armed = tool,
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

    await tester.tap(find.text(tr.shotListFloorPlanToolCameraAction));
    await tester.pump();

    expect(armed, OcptFloorPlanTool.camera);
  });

  testWidgets(
    "a placeable entry is a drag source reporting its own tool once dropped onto a target",
    (tester) async {
      OcptFloorPlanTool? dropped;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            Tr.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: Tr.delegate.supportedLocales,
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 220,
                  height: 700,
                  child: _buildPalette(setName: "Kitchen", shotCode: "12/3"),
                ),
                DragTarget<OcptFloorPlanTool>(
                  onAcceptWithDetails: (details) => dropped = details.data,
                  builder: (context, candidateData, rejectedData) =>
                      const SizedBox(key: Key("drop-target"), width: 200, height: 200),
                ),
              ],
            ),
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      final source = tester.getCenter(find.text(tr.shotListFloorPlanToolCameraAction));
      final target = tester.getCenter(find.byKey(const Key("drop-target")));

      final gesture = await tester.startGesture(source);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(target);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(dropped, OcptFloorPlanTool.camera);
    },
  );

  testWidgets("under a read-only preview, entries are no longer drag sources", (tester) async {
    await _pump(
      tester,
      _buildPalette(setName: "Kitchen", shotCode: "12/3", isReadOnly: true),
    );

    expect(find.byType(Draggable<OcptFloorPlanTool>), findsNothing);
  });

  testWidgets("the View group's own set layer row shows the shared décor label", (tester) async {
    await _pump(tester, _buildPalette(setName: "Kitchen"));
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

    expect(find.text(tr.shotListFloorPlanLayerDecorLabel), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanLayerCharactersLabel), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanLayerLightsLabel), findsOneWidget);
    expect(find.text(tr.shotListFloorPlanLayerHandPropsLabel), findsOneWidget);
  });
}
