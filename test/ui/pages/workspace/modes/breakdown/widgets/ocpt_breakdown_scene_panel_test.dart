// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_tag.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_panel.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the `OcptWorkspaceDock` the panel fills in the app.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 280, height: 600, child: child)),
);

/// Builds a scene with the few fields these tests read, everything else left at a neutral value.
OcptBreakdownScene _buildScene({
  required String id,
  required int position,
  required String heading,
  OcptBreakdownSceneStatus status = OcptBreakdownSceneStatus.toDo,
  List<OcptBreakdownTag> tags = const [],
}) => OcptBreakdownScene(
  id: id,
  position: position,
  heading: heading,
  sceneNumber: null,
  charStart: 0,
  charEnd: heading.length,
  status: status,
  notes: "",
  tags: tags,
  episodeNumber: null,
);

/// Builds a tag pointing scene [sceneId] at target [targetId] of [targetKind], the rest at neutral
/// values.
OcptBreakdownTag _buildTag({
  required String sceneId,
  required OcptBreakdownTargetKind targetKind,
  required String targetId,
  bool needsCheck = false,
}) => OcptBreakdownTag(
  id: "$sceneId-$targetId",
  sceneId: sceneId,
  targetKind: targetKind,
  targetId: targetId,
  startOffset: 0,
  endOffset: 1,
  taggedText: "x",
  needsCheck: needsCheck,
);

/// Builds an element target of [category] named [name].
OcptBreakdownTarget _buildElementTarget({
  required String id,
  required String name,
  required OcptElementCategory category,
}) => OcptBreakdownTarget(
  kind: OcptBreakdownTargetKind.element,
  id: id,
  name: name,
  category: category,
  status: OcptElementStatus.toFind,
  sceneIds: const [],
  occurrenceCount: 1,
);

/// Builds a role target named [name].
OcptBreakdownTarget _buildRoleTarget({required String id, required String name}) =>
    OcptBreakdownTarget(
      kind: OcptBreakdownTargetKind.role,
      id: id,
      name: name,
      category: null,
      status: null,
      sceneIds: const [],
      occurrenceCount: 1,
    );

void main() {
  final propTarget = _buildElementTarget(id: "el-1", name: "Lamp", category: OcptElementCategory.prop);
  final costumeTarget = _buildElementTarget(
    id: "el-2",
    name: "Jacket",
    category: OcptElementCategory.costume,
  );
  final roleTarget = _buildRoleTarget(id: "role-1", name: "LÉA");

  final taggedScene = _buildScene(
    id: "scene-2",
    position: 1,
    heading: "EXT. GARDEN - NIGHT",
    status: OcptBreakdownSceneStatus.inProgress,
    tags: [
      _buildTag(
        sceneId: "scene-2",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-1",
      ),
      _buildTag(
        sceneId: "scene-2",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: "el-2",
      ),
      _buildTag(sceneId: "scene-2", targetKind: OcptBreakdownTargetKind.role, targetId: "role-1"),
    ],
  );
  final untaggedScene = _buildScene(id: "scene-1", position: 0, heading: "INT. HOUSE - DAY");
  final doneScene = _buildScene(
    id: "scene-3",
    position: 2,
    heading: "INT. KITCHEN - DAY",
    status: OcptBreakdownSceneStatus.done,
  );

  final targetById = ocptBreakdownTargetsById([propTarget, costumeTarget, roleTarget]);

  /// Pumps the panel with [selectedSceneId] selected, recording every selection it reports.
  Future<List<String>> pumpPanel(
    WidgetTester tester, {
    required String? selectedSceneId,
    List<OcptBreakdownScene>? scenes,
  }) async {
    final selections = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptBreakdownScenePanel(
          scenes: scenes ?? [untaggedScene, taggedScene, doneScene],
          targetById: targetById,
          selectedSceneId: selectedSceneId,
          onSceneSelected: selections.add,
          legendEntries: const [],
          hiddenLegendKeys: const {},
          onLegendEntryToggled: (_) {},
          onShowAllLegendKeysRequested: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    return selections;
  }

  testWidgets("lists every scene with its number, heading and done count", (tester) async {
    await pumpPanel(tester, selectedSceneId: null);

    expect(find.text("1"), findsOneWidget);
    expect(find.text("INT. HOUSE - DAY"), findsOneWidget);
    expect(find.text("EXT. GARDEN - NIGHT"), findsOneWidget);
    expect(find.text("INT. KITCHEN - DAY"), findsOneWidget);
    // One of the three scenes is done.
    expect(find.text("1/3 done"), findsOneWidget);
  });

  testWidgets("clicking a scene reports its id", (tester) async {
    final selections = await pumpPanel(tester, selectedSceneId: null);

    await tester.tap(find.text("EXT. GARDEN - NIGHT"));
    await tester.pump();

    expect(selections, ["scene-2"]);
  });

  testWidgets("each scene shows its own breakdown status label", (tester) async {
    await pumpPanel(tester, selectedSceneId: null);

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownScenePanel)));
    expect(find.text(tr.breakdownSceneStatusToDo), findsOneWidget);
    expect(find.text(tr.breakdownSceneStatusInProgress), findsOneWidget);
    expect(find.text(tr.breakdownSceneStatusDone), findsOneWidget);
  });

  testWidgets("a scene with no tag shows no category bar and a zero count", (tester) async {
    await pumpPanel(tester, selectedSceneId: null, scenes: [untaggedScene]);

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownScenePanel)));
    expect(find.text(tr.breakdownSceneElementsCount(0)), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets("a scene's tagged targets each get one coloured bar per category or kind", (
    tester,
  ) async {
    await pumpPanel(tester, selectedSceneId: null);

    // Two element categories (Props, Costumes) plus the role bucket (Characters): three bars.
    expect(find.byTooltip("Props"), findsOneWidget);
    expect(find.byTooltip("Costumes"), findsOneWidget);
    expect(find.byTooltip("Characters"), findsOneWidget);

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownScenePanel)));
    // Three distinct targets tagged in that one scene.
    expect(find.text(tr.breakdownSceneElementsCount(3)), findsOneWidget);
  });

  testWidgets("the selected scene's row is tinted with the accent wash", (tester) async {
    await pumpPanel(tester, selectedSceneId: "scene-2");

    final coloredBoxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).toList();
    expect(coloredBoxes.any((box) => box.color != Colors.transparent), isTrue);
  });

  testWidgets("an empty screenplay shows the hint instead of the list", (tester) async {
    await pumpPanel(tester, selectedSceneId: null, scenes: const []);

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownScenePanel)));
    expect(find.text(tr.breakdownScenesEmptyHint), findsOneWidget);
  });

  testWidgets("marks only the scenes holding a flagged tag with a warning icon", (tester) async {
    final flaggedScene = _buildScene(
      id: "scene-4",
      position: 3,
      heading: "INT. ATTIC - NIGHT",
      tags: [
        _buildTag(
          sceneId: "scene-4",
          targetKind: OcptBreakdownTargetKind.element,
          targetId: "el-1",
          needsCheck: true,
        ),
      ],
    );

    await pumpPanel(
      tester,
      selectedSceneId: null,
      scenes: [untaggedScene, taggedScene, flaggedScene],
    );

    final tr = Tr.of(tester.element(find.byType(OcptBreakdownScenePanel)));
    expect(find.byTooltip(tr.breakdownTagNeedsCheckTooltip), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
