// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_category_legend.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_recap_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_target_inspector.dart';

import 'breakdown_mode_scenarios_test_doubles.dart';

/// Run the tests of the breakdown mode centre scenarios.
void main() {
  final harness = BreakdownScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the script view in the centre.
  Finder inScript(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownScriptView), matching: target);

  /// Finds [target] inside the recap table.
  Finder inRecap(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownRecapTable), matching: target);

  /// Finds [target] inside the category legend under the scene list.
  Finder inLegend(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownCategoryLegend), matching: target);

  /// The box drawn behind the first word of the script shown as [text], or null when it has none.
  BoxDecoration? boxOf(WidgetTester tester, String text) {
    final container = tester.widget<Container>(
      find.ancestor(of: inScript(find.text(text)).first, matching: find.byType(Container)).first,
    );
    return container.decoration as BoxDecoration?;
  }

  /// The fill colour of the box drawn behind the word shown as [text], or null when it has none.
  Color? washOf(WidgetTester tester, String text) => boxOf(tester, text)?.color;

  /// Tags a prop "Teapot" in both scenes, a costume "Apron" on "enters" and a set "Main" on
  /// "table" in the first one, returning the ids in that order.
  Future<(String, String, String)> seedTagged() async {
    final teapotId = await harness.seedElement("Teapot");
    for (final sceneIndex in [0, 1]) {
      await harness.seedTag(
        sceneIndex: sceneIndex,
        text: "teapot",
        targetKind: OcptBreakdownTargetKind.element,
        targetId: teapotId,
      );
    }
    final apronId = (await harness.projectsManager.elementsService.createElement(
      database: harness.database,
      name: "Apron",
      category: OcptElementCategory.costume,
      sourceKind: OcptElementSourceKind.owned,
    ))!;
    await harness.seedTag(
      sceneIndex: 0,
      text: "enters",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: apronId,
    );
    final locationId = await harness.seedLocation("Kitchen");
    final setId = await harness.seedSet(locationId, "Main");
    await harness.seedTag(
      sceneIndex: 0,
      text: "table",
      targetKind: OcptBreakdownTargetKind.set,
      targetId: setId,
    );
    return (teapotId, apronId, setId);
  }

  testWidgets("the recap lists every tagged target against the scenes, and a row selects the "
      "target in its first scene", (tester) async {
    await seedTagged();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.text(tr.breakdownHeaderScriptHint), findsOneWidget);

    await harness.tap(tester, find.text(tr.breakdownHeaderRecapSegmentLabel));
    expect(find.byType(OcptBreakdownScriptView), findsNothing);
    expect(find.text(tr.breakdownHeaderRecapHint), findsOneWidget);
    expect(inRecap(find.text(tr.breakdownRecapSceneColumnLabel("1"))), findsOneWidget);
    expect(inRecap(find.text(tr.breakdownRecapSceneColumnLabel("2"))), findsOneWidget);
    for (final name in ["Teapot", "Apron", "Main"]) {
      expect(inRecap(find.text(name)), findsOneWidget);
    }

    // A row of a target tagged in the second scene only would land there; Teapot starts in the
    // first one, which is selected along with the target.
    await harness.tap(tester, inRecap(find.text("Teapot")));
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    await harness.scrollRightDockTo(
      tester,
      find.text(tr.breakdownOccurrenceSceneLabel("2", "EXT. GARDEN - NIGHT")),
    );
    expect(find.text(tr.breakdownOccurrenceSceneLabel("1", "INT. KITCHEN - DAY")), findsOneWidget);

    // Back on the script, the selection is still there: the tagged words carry its ring.
    await harness.tap(tester, find.text(tr.breakdownHeaderScriptSegmentLabel));
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    final decoration = boxOf(tester, "teapot");
    expect(decoration?.border, isNotNull);
  });

  testWidgets("typing in the search from the script switches to the recap carrying the text, "
      "filters its rows only, and clearing it does not switch back", (tester) async {
    await seedTagged();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final search = harness.fieldHinted(tr.breakdownHeaderSearchHint);

    await harness.type(tester, search, "tea");
    await tester.pumpAndSettle();
    expect(find.byType(OcptBreakdownScriptView), findsNothing);
    expect(tester.widget<TextField>(search).controller!.text, "tea");
    expect(inRecap(find.text("Teapot")), findsOneWidget);
    expect(inRecap(find.text("Apron")), findsNothing);
    expect(inRecap(find.text("Main")), findsNothing);
    // Rows only: both scene columns are still there.
    expect(inRecap(find.text(tr.breakdownRecapSceneColumnLabel("2"))), findsOneWidget);

    await harness.type(tester, search, "zzz");
    await tester.pumpAndSettle();
    expect(find.text(tr.breakdownRecapNoMatchesHint("zzz")), findsOneWidget);

    await harness.tap(tester, find.byTooltip(tr.breakdownHeaderSearchClearTooltip));
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(find.byType(OcptBreakdownScriptView), findsNothing);
    expect(inRecap(find.text("Apron")), findsOneWidget);

    // The query survives a trip to the script and back.
    await harness.type(tester, search, "apr");
    await harness.tap(tester, find.text(tr.breakdownHeaderScriptSegmentLabel));
    expect(find.byType(OcptBreakdownScriptView), findsOneWidget);
    await harness.tap(tester, find.text(tr.breakdownHeaderRecapSegmentLabel));
    expect(inRecap(find.text("Apron")), findsOneWidget);
    expect(inRecap(find.text("Teapot")), findsNothing);
  });

  testWidgets("leaving the script for the recap drops the open anchor", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, inScript(find.text("teapot ")).first);
    expect(inScript(find.text("teapot ")), findsOneWidget);
    await harness.tap(tester, find.text(tr.breakdownHeaderRecapSegmentLabel));
    expect(find.text(tr.breakdownRecapNothingTaggedHint), findsOneWidget);
    await harness.tap(tester, find.text(tr.breakdownHeaderScriptSegmentLabel));
    expect(inScript(find.text("teapot ")), findsNWidgets(2));
  });

  testWidgets("a legend entry hides its category's wash without taking away the click, Show all "
      "brings it back, and the choice survives a trip to the recap", (tester) async {
    await seedTagged();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final propsLabel = tr.resourcesElementCategoryProp;

    expect(inLegend(find.text(propsLabel)), findsOneWidget);
    expect(inLegend(find.text(tr.resourcesElementCategoryCostume)), findsOneWidget);
    expect(inLegend(find.text(tr.breakdownLegendShowAllAction)), findsNothing);
    expect(washOf(tester, "teapot"), isNotNull);

    await harness.tap(tester, inLegend(find.text(propsLabel)));
    expect(washOf(tester, "teapot "), isNull);
    expect(washOf(tester, "enters"), isNotNull);
    expect(inLegend(find.text(tr.breakdownLegendShowAllAction)), findsOneWidget);

    await harness.tap(tester, find.text(tr.breakdownHeaderRecapSegmentLabel));
    await harness.tap(tester, find.text(tr.breakdownHeaderScriptSegmentLabel));
    expect(washOf(tester, "teapot "), isNull);

    // The hidden category still answers a click with its sheet.
    await harness.tap(tester, inScript(find.text("teapot ")).first);
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);

    await harness.tap(tester, inLegend(find.text(tr.breakdownLegendShowAllAction)));
    expect(washOf(tester, "teapot"), isNotNull);
    expect(inLegend(find.text(tr.breakdownLegendShowAllAction)), findsNothing);
  });

  testWidgets("a role shared by two characters is flagged at the top of the centre and tapping "
      "the line reveals it in the resources mode", (tester) async {
    await harness.seedRole("Sam");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final line = find.text(tr.roleAlertCompactCollisionLine("SAM"));

    expect(line, findsWidgets);
    // It sits above whichever centre is shown.
    await harness.tap(tester, find.text(tr.breakdownHeaderRecapSegmentLabel));
    expect(line, findsWidgets);

    await harness.tap(tester, line.first);
    final state = harness.workspaceBlocOf(tester).state;
    expect(state.mode, OcptWorkspaceMode.resources);
    final request = state.revealRequest! as OcptResourcesRevealRequest;
    expect(request.tab, OcptResourcesTab.roles);
    expect((await harness.readRoles()).map((role) => role.id), contains(request.recordId));
  });

  testWidgets("a character no longer in the screenplay is flagged as removed", (tester) async {
    final project = harness.projectsManager.currentProject!;
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.text(tr.roleAlertCompactOrphanedLine("SAM")), findsNothing);

    await harness.projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: "INT. KITCHEN - DAY\n\nHe enters.\n\nEXT. GARDEN - NIGHT\n\nA teapot rests.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    // Any write reloads the snapshot the banner reads its cast from.
    await harness.openRightDock(tester);
    await harness.tap(tester, find.text("INT. KITCHEN - DAY").last);
    await harness.tap(tester, find.text(tr.breakdownSceneStatusInProgress).last);
    expect(find.text(tr.roleAlertCompactOrphanedLine("SAM")), findsOneWidget);
  });

  testWidgets("deleting a location or an element in the catalogue drops its targets from the "
      "breakdown at the next read, and the sheet falls back to the scene", (tester) async {
    final (teapotId, _, _) = await seedTagged();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(
      find.text("${tr.breakdownStatsTagged(3)} · ${tr.breakdownStatsCategories(3)}"),
      findsOneWidget,
    );
    await harness.tap(tester, inScript(find.text("teapot")).first);
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);

    await harness.projectsManager.elementsService.deleteElement(
      database: harness.database,
      elementId: teapotId,
    );
    final locationId = (await harness.readLocations()).single.id;
    await harness.projectsManager.locationsService.deleteLocation(
      database: harness.database,
      locationId: locationId,
    );

    // Nothing reloads by itself: the next write does.
    await harness.tap(tester, find.text(tr.breakdownRightDockInspectorTabLabel));
    await harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));
    await harness.tap(
      tester,
      find.descendant(
        of: find.byType(OcptBreakdownSceneInspector),
        matching: find.text(tr.breakdownSceneStatusDone),
      ),
    );
    expect(
      find.text("${tr.breakdownStatsTagged(1)} · ${tr.breakdownStatsCategories(1)}"),
      findsOneWidget,
    );
    expect(find.byType(OcptBreakdownTargetInspector), findsNothing);
    await harness.tap(tester, find.text(tr.breakdownHeaderRecapSegmentLabel));
    expect(inRecap(find.text("Teapot")), findsNothing);
    expect(inRecap(find.text("Main")), findsNothing);
    expect(inRecap(find.text("Apron")), findsOneWidget);
  });
}
