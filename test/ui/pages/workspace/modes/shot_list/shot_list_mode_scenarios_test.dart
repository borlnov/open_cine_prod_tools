// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panel_strip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_shot_leader_card.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

import 'shot_list_mode_scenarios_test_doubles.dart';

/// How long a scenario lets the mode's 2 s field-edit debounce run out.
const _debounceElapsed = Duration(milliseconds: 2500);

/// How long a scenario waits while staying clear of the 2 s field-edit debounce.
const _beforeDebounce = Duration(milliseconds: 300);

/// Run the tests of the shot list mode scenarios.
void main() {
  final harness = ShotListScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  testWidgets("entry selects the first sequence and its first shot, table shown, right dock shut", (
    tester,
  ) async {
    await harness.seedShots(2);
    await harness.seedShots(1, sceneIndex: 1);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    // The first sequence is the selected one: its two shots are the table's rows.
    expect(find.byType(OcptShotListRow), findsNWidgets(2));
    expect(find.textContaining(tr.shotListStatsSequences(2)), findsWidgets);
    expect(find.textContaining(tr.shotListShotsCount(3)), findsWidgets);
    expect(find.byType(OcptShotListRightDock), findsNothing);
    expect(find.byType(OcptStoryboardShotLeaderCard), findsNothing);
    expect(find.byType(OcptFloorPlanCanvas), findsNothing);

    // The first shot is the selected one: opening the right dock reads it.
    await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await tester.pumpAndSettle();
    expect(harness.inspectorHeader(tr, "1/1"), findsOneWidget);
  });

  testWidgets("a project with no shot yet says so, and + Shot adds one and opens its inspector", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.text(tr.shotListShotsEmptyHint), findsOneWidget);
    expect(find.byType(OcptShotInspectorPanel), findsNothing);

    await tester.tap(find.text(tr.shotListAddShotAction));
    await tester.pumpAndSettle();

    expect(find.byType(OcptShotListRow), findsOneWidget);
    expect(harness.tableRow("1/1"), findsOneWidget);
    expect(harness.inspectorHeader(tr, "1/1"), findsOneWidget);
    expect(find.text(tr.shotListShotsCount(1)), findsWidgets);
    expect((await harness.readShotList()).shotsById.values.map((shot) => shot.code), ["1/1"]);

    // A second one is appended and becomes the selected one.
    await tester.tap(find.text(tr.shotListAddShotAction));
    await tester.pumpAndSettle();

    expect(find.byType(OcptShotListRow), findsNWidgets(2));
    expect(harness.inspectorHeader(tr, "1/2"), findsOneWidget);
    expect((await harness.readShotList()).shotsById, hasLength(2));
  });

  testWidgets("a typed inspector field outlives a view switch and is written when its debounce "
      "runs out, then shows in the table", (tester) async {
    await harness.seedShots(1);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tapRow(tester, 0);
    await harness.typeIntoInspector(tester, tr.shotListColumnFraming, "Two-shot");

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await tester.pump(_beforeDebounce);

    // Still typed in the inspector the board keeps beside it.
    expect(find.text("Two-shot"), findsOneWidget);

    await tester.pump(_debounceElapsed);
    final written = (await harness.readShotList()).shotsById.values.single;
    expect(written.framing, "Two-shot");

    await harness.switchView(tester, tr.shotListBoardTableSegmentLabel);
    expect(
      find.descendant(of: find.byType(OcptShotListRow), matching: find.text("Two-shot")),
      findsOneWidget,
    );
  });

  testWidgets("a typed field is written at once when another shot, or another sequence, is "
      "selected", (tester) async {
    final shotIds = await harness.seedShots(2);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tapRow(tester, 0);
    await harness.typeIntoInspector(tester, tr.shotListColumnFraming, "Wide");

    // Another shot of the table: nothing waits for the debounce.
    await harness.tapRow(tester, 1);
    var snapshot = await harness.readShotList();
    expect(snapshot.shotsById[shotIds[0]]!.framing, "Wide");
    expect(harness.inspectorHeader(tr, "1/2"), findsOneWidget);

    // Another sequence of the left dock: same.
    await harness.typeIntoInspector(tester, tr.shotListColumnFraming, "Close");
    await tester.tap(harness.sequenceEntry("EXT. GARDEN - NIGHT"));
    await tester.pump(_beforeDebounce);
    await tester.pumpAndSettle();
    snapshot = await harness.readShotList();
    expect(snapshot.shotsById[shotIds[1]]!.framing, "Close");
    expect(find.text(tr.shotListShotsEmptyHint), findsOneWidget);
  });

  testWidgets("a panel comment typed on the board is written, and reads back after a trip through "
      "the table", (tester) async {
    final shotIds = await harness.seedShots(1);
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: shotIds.single,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await tester.tap(find.byType(OcptStoryboardShotLeaderCard));
    await tester.pumpAndSettle();

    await tester.enterText(harness.panelCommentField(), "Hands on the cup");
    await tester.pump();

    await harness.switchView(tester, tr.shotListBoardTableSegmentLabel);
    await tester.pump(_debounceElapsed);

    final storyboard = await harness.readStoryboard();
    expect(storyboard.panelsByShotId[shotIds.single]!.single.comment, "Hands on the cup");

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    expect(find.text("Hands on the cup"), findsOneWidget);
  });

  testWidgets("deleting the selected shot from the inspector while on the board cascades to its "
      "panels and floor plan, and falls back to the first shot left", (tester) async {
    final shotIds = await harness.seedShots(2);
    final setId = await harness.seedLinkedSet("KITCHEN");
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: shotIds.first,
    );
    await harness.projectsManager.floorPlanService.placeSymbol(
      database: harness.database,
      setId: setId,
      sceneId: null,
      shotId: shotIds.first,
      layer: OcptFloorPlanLayer.cameras,
      xM: 0,
      yM: 0,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    expect(find.byType(OcptStoryboardShotLeaderCard), findsNWidgets(2));
    await tester.tap(find.byType(OcptStoryboardShotLeaderCard).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OcptStoryboardShotLeaderCard).first);
    await tester.pumpAndSettle();
    expect(harness.inspectorHeader(tr, "1/1"), findsOneWidget);

    await harness.scrollInspectorTo(tester, find.text(tr.shotListDeleteShotAction));
    await tester.tap(find.text(tr.shotListDeleteShotAction));
    await tester.pumpAndSettle();
    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    await tester.tap(find.text(tr.shotListDeleteConfirmDeleteAction));
    await tester.pumpAndSettle();

    // On screen: one shot left, selected and renumbered.
    expect(find.byType(OcptStoryboardShotLeaderCard), findsOneWidget);
    await harness.scrollInspectorTo(tester, harness.inspectorHeader(tr, "1/1"));
    expect(harness.inspectorHeader(tr, "1/1"), findsOneWidget);
    expect(find.byType(OcptStoryboardPanelFrame), findsNothing);

    // In the database: the shot, its panel and its camera are gone.
    final shotList = await harness.readShotList();
    expect(shotList.shotsById.keys, [shotIds.last]);
    final storyboard = await harness.readStoryboard();
    expect(storyboard.panelsByShotId[shotIds.first], anyOf(isNull, isEmpty));
    final floorPlans = await harness.readFloorPlans();
    expect(floorPlans.setsById[setId]!.symbols, isEmpty);

    // The export panel reads the same snapshots: with the only panel and the only camera gone,
    // neither document is on offer any more.
    await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
    await tester.pumpAndSettle();
    expect(
      harness.inPanel(find.text(tr.shotListExportStoryboardUnavailableReason)),
      findsOneWidget,
    );
    expect(
      harness.inPanel(find.text(tr.shotListExportFloorPlansUnavailableReason)),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Nothing is left to write, so the debounce running out raises no error.
    await tester.pump(_debounceElapsed);
    expect(find.text(tr.shotListWriteError), findsNothing);
  });

  testWidgets("selecting from the board: a panel's selection is cleared by re-picking its shot or "
      "changing sequence, and kept by re-picking the same sequence", (tester) async {
    await harness.seedShots(2);
    final shotIds = (await harness.readShotList()).shotsById.keys.toList();
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: shotIds.first,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final panelSelected = find.textContaining(tr.shotListBoardPanelSelectedHint(1, 1));

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await tester.tap(find.byType(OcptStoryboardShotLeaderCard).first);
    await tester.pumpAndSettle();
    expect(panelSelected, findsNothing);

    await tester.tap(find.byType(OcptStoryboardPanelFrame));
    await tester.pumpAndSettle();
    expect(panelSelected, findsOneWidget);

    // Re-picking the sequence already selected keeps the panel.
    await tester.tap(harness.sequenceEntry("INT. KITCHEN - DAY"));
    await tester.pumpAndSettle();
    expect(panelSelected, findsOneWidget);

    // The selection survives a trip through the table.
    await harness.switchView(tester, tr.shotListBoardTableSegmentLabel);
    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    expect(panelSelected, findsOneWidget);

    // Re-picking the very shot already selected clears the panel all the same.
    await tester.tap(find.byType(OcptStoryboardShotLeaderCard).first);
    await tester.pumpAndSettle();
    expect(panelSelected, findsNothing);

    // Another sequence clears it, and coming back does not bring it back.
    await tester.tap(find.byType(OcptStoryboardPanelFrame));
    await tester.pumpAndSettle();
    expect(panelSelected, findsOneWidget);
    await tester.tap(harness.sequenceEntry("EXT. GARDEN - NIGHT"));
    await tester.pumpAndSettle();
    await tester.tap(harness.sequenceEntry("INT. KITCHEN - DAY"));
    await tester.pumpAndSettle();
    expect(panelSelected, findsNothing);
  });

  testWidgets("on the floor plans, the arrow keys walk the shots and the inspector follows", (
    tester,
  ) async {
    await harness.seedShots(3);
    await harness.seedLinkedSet("KITCHEN");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    expect(find.byType(OcptFloorPlanCanvas), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(harness.inspectorHeader(tr, "1/2"), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(harness.inspectorHeader(tr, "1/3"), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(harness.inspectorHeader(tr, "1/2"), findsOneWidget);

    // The shot walked to is the one the table reads too.
    await harness.switchView(tester, tr.shotListBoardTableSegmentLabel);
    expect(harness.inspectorHeader(tr, "1/2"), findsOneWidget);
  });

  testWidgets("a floor plan symbol stays selected through re-picking the same sequence, and is "
      "dropped by changing sequence", (tester) async {
    await harness.seedShots(1);
    await harness.seedLinkedSet("KITCHEN");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final deleteSymbol = find.byTooltip(tr.shotListFloorPlanDeleteSymbolAction);

    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    expect(deleteSymbol, findsNothing);

    await tester.tap(find.byTooltip(tr.shotListFloorPlanToolSetElementAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OcptFloorPlanCanvas));
    await tester.pumpAndSettle();
    expect(deleteSymbol, findsOneWidget);

    await tester.tap(harness.sequenceEntry("INT. KITCHEN - DAY"));
    await tester.pumpAndSettle();
    expect(deleteSymbol, findsOneWidget);

    // It also survives a trip through the other two views.
    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    expect(deleteSymbol, findsOneWidget);

    // Leaving the sequence and coming back finds nothing selected, though the symbol is still there.
    await tester.tap(harness.sequenceEntry("EXT. GARDEN - NIGHT"));
    await tester.pumpAndSettle();
    await tester.tap(harness.sequenceEntry("INT. KITCHEN - DAY"));
    await tester.pumpAndSettle();
    expect(deleteSymbol, findsNothing);
    final floorPlans = await harness.readFloorPlans();
    expect(floorPlans.setsById.values.single.symbols, hasLength(1));
  });

  testWidgets("the export panel offers the floor plans once a camera is placed, and the "
      "storyboard once a frame is imported, each export reading that view", (tester) async {
    final shotIds = await harness.seedShots(1);
    final setId = await harness.seedLinkedSet("KITCHEN");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    Future<void> openExportPanel() async {
      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();
    }

    Future<void> dismissExportPanel() async {
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }

    await openExportPanel();
    expect(
      harness.inPanel(find.text(tr.shotListExportStoryboardUnavailableReason)),
      findsOneWidget,
    );
    expect(
      harness.inPanel(find.text(tr.shotListExportFloorPlansUnavailableReason)),
      findsOneWidget,
    );
    await dismissExportPanel();

    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    await tester.tap(find.byTooltip(tr.shotListFloorPlanToolCameraAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OcptFloorPlanCanvas));
    await tester.pumpAndSettle();

    await openExportPanel();
    expect(harness.inPanel(find.text(tr.shotListExportFloorPlansUnavailableReason)), findsNothing);
    expect(
      harness.inPanel(find.text(tr.shotListExportStoryboardUnavailableReason)),
      findsOneWidget,
    );
    await tester.tap(harness.inPanel(find.text(tr.shotListExportFloorPlansTitle)));
    await tester.pumpAndSettle();

    final floorPlanExport = harness.exportManager.lastFloorPlanSnapshot!;
    final exportedSymbols = floorPlanExport.setsById[setId]!.symbols;
    expect(exportedSymbols.map((symbol) => symbol.layer), [OcptFloorPlanLayer.cameras]);
    expect(exportedSymbols.single.shotId, shotIds.single);

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();

    await openExportPanel();
    expect(harness.inPanel(find.text(tr.shotListExportStoryboardUnavailableReason)), findsNothing);
    await tester.tap(harness.inPanel(find.text(tr.shotListExportStoryboardTitle)));
    await tester.pumpAndSettle();
    await tester.tap(harness.inPanel(find.text(tr.editorExportPdfExportAction)));
    await tester.pumpAndSettle();

    final storyboardExport = harness.exportManager.lastStoryboardSnapshot!;
    expect(storyboardExport.panelsByShotId[shotIds.single], hasLength(1));
    expect(harness.exportManager.exportCount, 2);
  });

  testWidgets("exporting right after typing exports what was typed, from the table and from the "
      "board", (tester) async {
    final shotIds = await harness.seedShots(1);
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: shotIds.single,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    Future<void> pickExport(String title) async {
      await tester.tap(find.byTooltip(tr.workspaceExportTooltip));
      await tester.pumpAndSettle();
      await tester.tap(harness.inPanel(find.text(title)));
      await tester.pumpAndSettle();
    }

    await harness.tapRow(tester, 0);
    await harness.typeIntoInspector(tester, tr.shotListColumnFraming, "Over the shoulder");
    await pickExport(tr.shotListExportXlsxTitle);
    expect(
      harness.exportManager.lastShotListSnapshot!.shotsById[shotIds.single]!.framing,
      "Over the shoulder",
    );

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await tester.enterText(harness.panelCommentField(), "Steam rising");
    await tester.pump();
    await pickExport(tr.shotListExportStoryboardTitle);
    await tester.tap(harness.inPanel(find.text(tr.editorExportPdfExportAction)));
    await tester.pumpAndSettle();
    expect(
      harness.exportManager.lastStoryboardSnapshot!.panelsByShotId[shotIds.single]!.single.comment,
      "Steam rising",
    );
    expect(harness.exportManager.exportCount, 2);
  });
}
