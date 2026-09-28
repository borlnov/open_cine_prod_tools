// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
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
  String sequenceCode = "7",
  String? shotCode,
  OcptFloorPlanTool activeTool = OcptFloorPlanTool.select,
  OcptFloorPlanSetElementShape activeSetElementShape = OcptFloorPlanSetElementShape.wall,
  OcptFloorPlanScope activeSetElementScope = OcptFloorPlanScope.set,
  String activeLabel = "",
  List<OcptFloorPlanPropChip> propsChips = const [],
  bool isReadOnly = false,
  Set<OcptFloorPlanLayer> hiddenLayers = const {},
  Map<OcptFloorPlanLayer, int> layerElementCounts = const {},
  ValueChanged<OcptFloorPlanTool>? onToolSelected,
  ValueChanged<OcptFloorPlanSetElementShape>? onSetElementShapeSelected,
  ValueChanged<OcptFloorPlanScope>? onSetElementScopeSelected,
  ValueChanged<String>? onPropChipSelected,
  VoidCallback? onOtherPropRequested,
  ValueChanged<OcptFloorPlanLayer>? onLayerVisibilityToggled,
}) => OcptFloorPlanPalette(
  setName: setName,
  sequenceCode: sequenceCode,
  shotCode: shotCode,
  activeTool: activeTool,
  activeSetElementShape: activeSetElementShape,
  activeSetElementScope: activeSetElementScope,
  activeLabel: activeLabel,
  propsChips: propsChips,
  isReadOnly: isReadOnly,
  hiddenLayers: hiddenLayers,
  layerElementCounts: layerElementCounts,
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
  onSetElementShapeSelected: onSetElementShapeSelected ?? (_) {},
  onSetElementScopeSelected: onSetElementScopeSelected ?? (_) {},
  onPropChipSelected: onPropChipSelected ?? (_) {},
  onOtherPropRequested: onOtherPropRequested ?? () {},
  onLayerVisibilityToggled: onLayerVisibilityToggled ?? (_) {},
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
                DragTarget<OcptFloorPlanPaletteDragPayload>(
                  onAcceptWithDetails: (details) => dropped = details.data.tool,
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

    expect(find.byType(Draggable<OcptFloorPlanPaletteDragPayload>), findsNothing);
  });

  testWidgets(
    "the Set group offers the four typed set-element entries, always available (no focused shot "
    "needed) — Furniture/Freeform also appear a second time, in the Sequence group",
    (tester) async {
      await _pump(tester, _buildPalette(setName: "Kitchen"));
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      expect(find.text(tr.shotListFloorPlanToolWallAction), findsOneWidget);
      expect(find.text(tr.shotListFloorPlanToolDoorAction), findsOneWidget);
      expect(find.text(tr.shotListFloorPlanToolFurnitureAction), findsNWidgets(2));
      expect(find.text(tr.shotListFloorPlanToolFreeformAction), findsNWidgets(2));
    },
  );

  testWidgets(
    "clicking a typed set-element entry arms the setElement tool and its own shape",
    (tester) async {
      OcptFloorPlanTool? armedTool;
      OcptFloorPlanSetElementShape? armedShape;
      await _pump(
        tester,
        _buildPalette(
          setName: "Kitchen",
          onToolSelected: (tool) => armedTool = tool,
          onSetElementShapeSelected: (shape) => armedShape = shape,
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      await tester.tap(find.text(tr.shotListFloorPlanToolDoorAction));
      await tester.pump();

      expect(armedTool, OcptFloorPlanTool.setElement);
      expect(armedShape, OcptFloorPlanSetElementShape.door);
    },
  );

  testWidgets(
    "a typed set-element entry is a drag source carrying its own shape once dropped",
    (tester) async {
      OcptFloorPlanPaletteDragPayload? dropped;

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
                  child: _buildPalette(setName: "Kitchen"),
                ),
                DragTarget<OcptFloorPlanPaletteDragPayload>(
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

      final source = tester.getCenter(find.text(tr.shotListFloorPlanToolWallAction));
      final target = tester.getCenter(find.byKey(const Key("drop-target")));

      final gesture = await tester.startGesture(source);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(target);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(dropped?.tool, OcptFloorPlanTool.setElement);
      expect(dropped?.setElementShape, OcptFloorPlanSetElementShape.wall);
    },
  );

  testWidgets(
    "the metrics toggle's own help button shows its explanation on press, and hides it again",
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2200);
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
          home: Scaffold(
            body: SizedBox(width: 220, height: 2000, child: _buildPalette(setName: "Kitchen")),
          ),
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      expect(find.text(tr.shotListFloorPlanMetricsHelpText), findsNothing);

      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pump();

      expect(find.text(tr.shotListFloorPlanMetricsHelpText), findsWidgets);
      expect(find.byIcon(Icons.help), findsOneWidget);

      await tester.tap(find.byIcon(Icons.help));
      await tester.pump();

      expect(find.text(tr.shotListFloorPlanMetricsHelpText), findsNothing);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    },
  );

  testWidgets("the View group's own set layer row shows the shared décor label", (tester) async {
    await _pump(tester, _buildPalette(setName: "Kitchen"));
    final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

    expect(
      find.text(tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerDecorLabel, 0)),
      findsOneWidget,
    );
    expect(
      find.text(
        tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerCharactersLabel, 0),
      ),
      findsOneWidget,
    );
    expect(
      find.text(tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerLightsLabel, 0)),
      findsOneWidget,
    );
    expect(
      find.text(tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerPropsLabel, 0)),
      findsOneWidget,
    );
  });

  group("the View group's own layer counts", () {
    testWidgets("shows each layer's own count next to its label", (tester) async {
      await _pump(
        tester,
        _buildPalette(
          setName: "Kitchen",
          layerElementCounts: const {
            OcptFloorPlanLayer.props: 3,
            OcptFloorPlanLayer.characters: 1,
          },
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      expect(
        find.text(tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerPropsLabel, 3)),
        findsOneWidget,
      );
      expect(
        find.text(
          tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerCharactersLabel, 1),
        ),
        findsOneWidget,
      );
      // Lights carries none of its own — reads as 0, not absent.
      expect(
        find.text(tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerLightsLabel, 0)),
        findsOneWidget,
      );
    });

    testWidgets("a layer's own eye is disabled while its count is 0", (tester) async {
      await _pump(tester, _buildPalette(setName: "Kitchen"));
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      final row = find.ancestor(
        of: find.text(tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerPropsLabel, 0)),
        matching: find.byType(Row),
      ).first;
      final eye = find.descendant(of: row, matching: find.byType(IconButton));

      expect(tester.widget<IconButton>(eye).onPressed, isNull);
    });

    testWidgets("a layer's own eye is enabled once it carries an element", (tester) async {
      await _pump(
        tester,
        _buildPalette(
          setName: "Kitchen",
          layerElementCounts: const {OcptFloorPlanLayer.props: 1},
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      final row = find.ancestor(
        of: find.text(tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerPropsLabel, 1)),
        matching: find.byType(Row),
      ).first;
      final eye = find.descendant(of: row, matching: find.byType(IconButton));

      expect(tester.widget<IconButton>(eye).onPressed, isNotNull);
    });

    testWidgets(
      "a hidden layer's own eye stays enabled even at a count of 0, so it can be shown again",
      (tester) async {
        OcptFloorPlanLayer? toggled;
        await _pump(
          tester,
          _buildPalette(
            setName: "Kitchen",
            hiddenLayers: const {OcptFloorPlanLayer.props},
            onLayerVisibilityToggled: (layer) => toggled = layer,
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

        final row = find.ancestor(
          of: find.text(
            tr.shotListFloorPlanLayerRowWithCountLabel(tr.shotListFloorPlanLayerPropsLabel, 0),
          ),
          matching: find.byType(Row),
        ).first;
        final eye = tester.widget<IconButton>(
          find.descendant(of: row, matching: find.byType(IconButton)),
        );

        expect(eye.onPressed, isNotNull);

        // Invoked directly rather than through a simulated tap: the eye sits at the row's own
        // trailing edge, under the `ListView`'s own interactive scrollbar hit region on this
        // narrow a test surface, which a raw pointer tap never reaches.
        eye.onPressed!();

        expect(toggled, OcptFloorPlanLayer.props);
      },
    );
  });

  group("the Sequence group (R5b)", () {
    testWidgets("shows its own header naming the focused sequence", (tester) async {
      await _pump(tester, _buildPalette(setName: "Kitchen"));
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      expect(find.text(tr.shotListFloorPlanPaletteSequenceGroupTitle("7")), findsOneWidget);
    });

    testWidgets(
      "the Set group's own typed entries arm set scope, the Sequence group's own arm scene scope",
      (tester) async {
        final armedScopes = <OcptFloorPlanScope>[];
        await _pump(
          tester,
          _buildPalette(
            setName: "Kitchen",
            onSetElementScopeSelected: armedScopes.add,
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

        // Two Furniture entries: the Set group's own first, the Sequence group's own second.
        final furnitureEntries = find.text(tr.shotListFloorPlanToolFurnitureAction);
        expect(furnitureEntries, findsNWidgets(2));

        await tester.tap(furnitureEntries.first);
        await tester.pump();
        await tester.tap(furnitureEntries.last);
        await tester.pump();

        expect(armedScopes, [OcptFloorPlanScope.set, OcptFloorPlanScope.scene]);
      },
    );

    testWidgets("shows one chip per prop, with its own quantity when it has one", (tester) async {
      await _pump(
        tester,
        _buildPalette(
          setName: "Kitchen",
          propsChips: const [
            OcptFloorPlanPropChip(elementId: "el-1", name: "Candles", quantity: "12"),
            OcptFloorPlanPropChip(elementId: "el-2", name: "Vase", quantity: ""),
          ],
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      expect(
        find.text(tr.shotListFloorPlanPropChipWithQuantityLabel("Candles", "12")),
        findsOneWidget,
      );
      expect(find.text("Vase"), findsOneWidget);
      expect(find.text(tr.shotListFloorPlanAddPropAction), findsOneWidget);
    });

    testWidgets(
      "clicking a prop chip click-to-arms the prop tool with its own name, and stays usable",
      (tester) async {
        OcptFloorPlanTool? armedTool;
        String? armedLabel;
        await _pump(
          tester,
          _buildPalette(
            setName: "Kitchen",
            propsChips: const [
              OcptFloorPlanPropChip(elementId: "el-1", name: "Candles", quantity: "12"),
            ],
            onToolSelected: (tool) => armedTool = tool,
            onPropChipSelected: (label) => armedLabel = label,
          ),
        );
        final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));
        final chip = find.text(
          tr.shotListFloorPlanPropChipWithQuantityLabel("Candles", "12"),
        );

        await tester.tap(chip);
        await tester.pump();
        expect(armedTool, OcptFloorPlanTool.prop);
        expect(armedLabel, "Candles");

        // The chip is still there and still tappable — two candles, two drops.
        armedTool = null;
        armedLabel = null;
        await tester.tap(chip);
        await tester.pump();
        expect(armedTool, OcptFloorPlanTool.prop);
        expect(armedLabel, "Candles");
      },
    );

    testWidgets("a prop chip is a drag source carrying its own name", (tester) async {
      OcptFloorPlanPaletteDragPayload? dropped;

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
                  child: _buildPalette(
                    setName: "Kitchen",
                    propsChips: const [
                      OcptFloorPlanPropChip(elementId: "el-1", name: "Candles", quantity: "12"),
                    ],
                  ),
                ),
                DragTarget<OcptFloorPlanPaletteDragPayload>(
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

      final source = tester.getCenter(
        find.text(tr.shotListFloorPlanPropChipWithQuantityLabel("Candles", "12")),
      );
      final target = tester.getCenter(find.byKey(const Key("drop-target")));

      final gesture = await tester.startGesture(source);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(target);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(dropped?.tool, OcptFloorPlanTool.prop);
      expect(dropped?.label, "Candles");
    });

    testWidgets("the add-prop button only asks — it never arms anything itself", (tester) async {
      var otherRequested = false;
      OcptFloorPlanTool? armedTool;
      await _pump(
        tester,
        _buildPalette(
          setName: "Kitchen",
          onOtherPropRequested: () => otherRequested = true,
          onToolSelected: (tool) => armedTool = tool,
        ),
      );
      final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

      await tester.tap(find.text(tr.shotListFloorPlanAddPropAction));
      await tester.pump();

      expect(otherRequested, isTrue);
      expect(armedTool, isNull);
    });

    testWidgets(
      "the add-prop button shows an add icon and the word alone, never a + in the label",
      (tester) async {
        await _pump(tester, _buildPalette(setName: "Kitchen"));
        final tr = Tr.of(tester.element(find.byType(OcptFloorPlanPalette)));

        expect(tr.shotListFloorPlanAddPropAction.contains("+"), isFalse);
        expect(find.text(tr.shotListFloorPlanAddPropAction), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      },
    );

    testWidgets("under a read-only preview, a prop chip is no longer a drag source", (tester) async {
      await _pump(
        tester,
        _buildPalette(
          setName: "Kitchen",
          isReadOnly: true,
          propsChips: const [
            OcptFloorPlanPropChip(elementId: "el-1", name: "Candles", quantity: "12"),
          ],
        ),
      );

      expect(find.byType(Draggable<OcptFloorPlanPaletteDragPayload>), findsNothing);
    });
  });
}
