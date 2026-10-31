// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_canvas.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_floor_plan_set_tabs.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panel_strip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_panels_group.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_shot_leader_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_working_copy_card.dart';

import 'shot_list_mode_scenarios_test_doubles.dart';

void main() {
  final harness = ShotListScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  testWidgets("the right dock opens on Versions, fills the working copy card, and reopens on "
      "the tab it was closed on", (tester) async {
    await harness.seedShots(1);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.byType(OcptProjectVersionsPanel), findsNothing);

    await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptShotInspectorPanel), findsOneWidget);

    await tester.tap(find.text(tr.shotListRightDockVersionsTabLabel));
    await tester.pumpAndSettle();
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);
    expect(find.byType(OcptProjectWorkingCopyCard), findsOneWidget);

    await tester.tap(find.byTooltip(tr.shotListRightDockCloseTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptProjectVersionsPanel), findsNothing);

    await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);
    expect(find.byType(OcptShotInspectorPanel), findsNothing);
  });

  testWidgets("previewing a version reloads every view and withholds their writes, leaving it "
      "brings the working copy back", (tester) async {
    final shotIds = await harness.seedShots(1);
    final setId = await harness.seedLinkedSet("KITCHEN");
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: shotIds.single,
    );
    final version = await harness.projectsManager.createProjectVersion(name: "v1", note: "");
    expect(version, isNotNull);

    // Written after the version was captured, so the preview cannot show it.
    final secondShotId = (await harness.seedShots(1)).single;
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: secondShotId,
    );
    await harness.projectsManager.floorPlanService.placeSymbol(
      database: harness.database,
      setId: setId,
      sceneId: null,
      shotId: secondShotId,
      layer: OcptFloorPlanLayer.cameras,
      xM: 0,
      yM: 0,
    );

    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.byType(OcptShotListRow), findsNWidgets(2));

    await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.shotListRightDockVersionsTabLabel));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byType(OcptProjectVersionCard)) + const Offset(24, 12),
    );
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );

    // Preview: the version's table, board and floor plan, none of them writable.
    expect(find.text(tr.workspaceReadOnlyBannerExitAction), findsOneWidget);
    expect(find.byType(OcptShotListRow), findsOneWidget);
    final addShot = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, tr.shotListAddShotAction),
    );
    expect(addShot.onPressed, isNull);

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    expect(find.byType(OcptStoryboardShotLeaderCard), findsOneWidget);
    expect(find.byType(OcptStoryboardPanelFrame), findsOneWidget);
    final importSlot = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.byIcon(Icons.add_photo_alternate_outlined),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(importSlot.onTap, isNull);

    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    final canvas = tester.widget<OcptFloorPlanCanvas>(find.byType(OcptFloorPlanCanvas));
    expect(canvas.onSymbolPlaced, isNull);
    final cameraTool = tester.widget<IconButton>(
      find.descendant(
        of: find.byTooltip(tr.shotListFloorPlanToolCameraAction),
        matching: find.byType(IconButton),
      ),
    );
    expect(cameraTool.onPressed, isNull);

    // Back to the working copy: everything written since is there again, in the three views.
    await tester.tap(find.text(tr.workspaceReadOnlyBannerExitAction));
    await harness.pumpUntil(
      tester,
      () => !harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
    expect(find.text(tr.workspaceReadOnlyBannerExitAction), findsNothing);
    expect(
      find.textContaining(tr.shotListFloorPlanCameraStatusHint("KITCHEN", 1, 1)),
      findsOneWidget,
    );
    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    expect(find.byType(OcptStoryboardShotLeaderCard), findsNWidgets(2));
    expect(find.byType(OcptStoryboardPanelFrame), findsNWidgets(2));
    await harness.switchView(tester, tr.shotListBoardTableSegmentLabel);
    expect(find.byType(OcptShotListRow), findsNWidgets(2));
  });

  testWidgets("a comment typed just before previewing a version is written first, the preview "
      "shows the version's own, and leaving it brings the comment back", (tester) async {
    final shotIds = await harness.seedShots(1);
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: shotIds.single,
    );
    final version = await harness.projectsManager.createProjectVersion(name: "v1", note: "");
    expect(version, isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await tester.tap(find.byType(OcptStoryboardShotLeaderCard));
    await tester.pumpAndSettle();
    await tester.enterText(harness.panelCommentField(), "Late note");
    await tester.pump();

    await tester.tap(find.text(tr.shotListRightDockVersionsTabLabel));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byType(OcptProjectVersionCard)) + const Offset(24, 12),
    );
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );

    // The working copy file holds it already, though the debounce never ran out.
    final fileDatabase = harness.projectsManager.currentProject!.fileDatabase;
    final stored = await harness.projectsManager.storyboardService.loadStoryboard(
      database: fileDatabase,
      screenplayId: harness.screenplayId,
    );
    expect(stored.panelsByShotId[shotIds.single]!.single.comment, "Late note");

    // The preview shows the version, which never had it.
    await tester.tap(find.text(tr.shotListRightDockInspectorTabLabel));
    await tester.pumpAndSettle();
    expect(find.text("Late note"), findsNothing);

    await tester.tap(find.text(tr.workspaceReadOnlyBannerExitAction));
    await harness.pumpUntil(
      tester,
      () => !harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
    expect(find.text("Late note"), findsOneWidget);
  });

  testWidgets("restoring a version puts the table, the board and the floor plans back to it", (
    tester,
  ) async {
    final shotIds = await harness.seedShots(1);
    final setId = await harness.seedLinkedSet("KITCHEN");
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: shotIds.single,
    );
    final version = await harness.projectsManager.createProjectVersion(name: "v1", note: "");
    expect(version, isNotNull);

    final laterShotId = (await harness.seedShots(1)).single;
    await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: laterShotId,
    );
    await harness.projectsManager.floorPlanService.placeSymbol(
      database: harness.database,
      setId: setId,
      sceneId: null,
      shotId: laterShotId,
      layer: OcptFloorPlanLayer.cameras,
      xM: 0,
      yM: 0,
    );

    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(find.byType(OcptShotListRow), findsNWidgets(2));

    await tester.tap(find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.shotListRightDockVersionsTabLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.projectVersionRestoreAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.projectVersionRestoreConfirmAction));
    await harness.pumpUntil(tester, () => find.byType(OcptShotListRow).evaluate().length == 1);

    expect(find.byType(OcptShotListRow), findsOneWidget);
    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    expect(find.byType(OcptStoryboardShotLeaderCard), findsOneWidget);
    expect(find.byType(OcptStoryboardPanelFrame), findsOneWidget);
    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    expect(
      find.textContaining(tr.shotListFloorPlanCameraStatusHint("KITCHEN", 0, 0)),
      findsOneWidget,
    );

    final shotList = await harness.readShotList();
    expect(shotList.shotsById.keys, [shotIds.single]);
    final floorPlans = await harness.readFloorPlans();
    expect(floorPlans.setsById[setId]!.symbols, isEmpty);
  });

  testWidgets("a failing write raises the error snackbar from the table, the board and the "
      "canvas alike", (tester) async {
    await harness.seedShots(1);
    await harness.seedLinkedSet("KITCHEN");
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final failures = harness.projectsManager.failures;
    final writeError = find.text(tr.shotListWriteError);

    failures.failShotCreation = true;
    await tester.tap(find.text(tr.shotListAddShotAction));
    await tester.pumpAndSettle();
    expect(writeError, findsOneWidget);
    expect(find.byType(OcptShotListRow), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(writeError, findsNothing);

    failures.failPanelCreation = true;
    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();
    expect(writeError, findsOneWidget);
    expect(find.byType(OcptStoryboardPanelFrame), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(writeError, findsNothing);

    failures.failSymbolPlacement = true;
    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    await tester.tap(find.byTooltip(tr.shotListFloorPlanToolSetElementAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OcptFloorPlanCanvas));
    await tester.pumpAndSettle();
    expect(writeError, findsOneWidget);
    expect((await harness.readFloorPlans()).setsById.values.single.symbols, isEmpty);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets("keeping an orphaned role as silent removes its banner and keeps the shot's cast", (
    tester,
  ) async {
    final shotIds = await harness.seedShots(1);
    final role = (await harness.projectsManager.roleIndexService.loadRoles(
      database: harness.database,
    )).firstWhere((role) => role.name == "SAM");
    await harness.projectsManager.shotListService.attachCharacter(
      database: harness.database,
      shotId: shotIds.single,
      roleId: role.id,
    );
    await harness.projectsManager.screenplayService.saveScreenplayText(
      database: harness.database,
      screenplayId: harness.screenplayId,
      fountainText: "INT. KITCHEN - DAY\n\nNobody speaks.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.text(tr.roleAlertOrphanedMessage("SAM")), findsOneWidget);

    await tester.tap(find.text(tr.roleAlertOrphanedKeepAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.roleAlertOrphanedMessage("SAM")), findsNothing);
    expect(find.byType(OcptShotListRow), findsOneWidget);
    final shot = (await harness.readShotList()).shotsById[shotIds.single]!;
    expect(shot.characters, ["SAM"]);
  });

  testWidgets("a reveal request lands on the floor plans of its sequence and set", (tester) async {
    await harness.seedShots(1);
    await harness.seedShots(1, sceneIndex: 1);
    await harness.seedLinkedSet("KITCHEN");
    final gardenSetId = await harness.seedLinkedSet("GARDEN", sceneIndex: 1);
    final gardenSceneId = (await harness.sceneIds())[1];

    await harness.mount(
      tester,
      revealRequest: OcptShotListRevealRequest(sceneId: gardenSceneId, setId: gardenSetId),
    );
    final tr = harness.trOf(tester);

    expect(find.byType(OcptFloorPlanCanvas), findsOneWidget);
    expect(
      find.textContaining(tr.shotListFloorPlanCameraStatusHint("GARDEN", 0, 0)),
      findsOneWidget,
    );

    // Entering again without a request opens on the mode's own default.
    await harness.unmount(tester);
    await harness.mount(tester);
    expect(find.byType(OcptFloorPlanCanvas), findsNothing);
  });

  testWidgets("leaving the mode right after typing writes the last keystrokes", (tester) async {
    final shotIds = await harness.seedShots(1);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tapRow(tester, 0);
    await harness.typeIntoInspector(tester, tr.shotListColumnFraming, "Last words");

    await harness.unmount(tester);

    final shot = (await harness.readShotList()).shotsById[shotIds.single]!;
    expect(shot.framing, "Last words");
  });

  testWidgets("moving a set element of a set linked to two sequences asks the scope, and Only "
      "sequence writes an override beside the untouched original", (tester) async {
    await harness.seedShots(1);
    final setId = await harness.seedLinkedSet("KITCHEN");
    final secondSceneId = (await harness.sceneIds())[1];
    await harness.projectsManager.locationsService.assignSceneToSet(
      database: harness.database,
      sceneId: secondSceneId,
      setId: setId,
    );
    final originalId = await harness.projectsManager.floorPlanService.placeSymbol(
      database: harness.database,
      setId: setId,
      sceneId: null,
      shotId: null,
      layer: OcptFloorPlanLayer.set,
      xM: 0,
      yM: 0,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    await tester.tap(find.byType(OcptFloorPlanCanvas));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(OcptFloorPlanCanvas), const Offset(80, 40));
    await tester.pumpAndSettle();

    final only = find.text(tr.shotListFloorPlanScopeBubbleOnlyAction("1"));
    expect(only, findsOneWidget);
    // Nothing is written until the choice is made.
    expect((await harness.readFloorPlans()).setsById[setId]!.symbols, hasLength(1));

    await tester.tap(only);
    await tester.pumpAndSettle();

    final symbols = (await harness.readFloorPlans()).setsById[setId]!.symbols;
    expect(symbols, hasLength(2));
    final original = symbols.firstWhere((symbol) => symbol.id == originalId);
    expect(original.xM, 0);
    final override = symbols.firstWhere((symbol) => symbol.id != originalId);
    expect(override.overridesSymbolId, originalId);
    expect(override.sceneId, (await harness.sceneIds()).first);
  });

  testWidgets("leaving the mode writes every kind of typed field at once: shot field, panel "
      "comment, mark text, set name and symbol label", (tester) async {
    final shotIds = await harness.seedShots(1);
    final setId = await harness.seedLinkedSet("KITCHEN");
    final panelId = (await harness.projectsManager.storyboardService.addPanel(
      database: harness.database,
      shotId: shotIds.single,
    ))!;
    final annotationId = (await harness.projectsManager.storyboardService.addAnnotation(
      database: harness.database,
      panelId: panelId,
      kind: OcptStoryboardAnnotationKind.label,
      x1: 0.5,
      y1: 0.5,
    ))!;
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tapRow(tester, 0);
    await harness.typeIntoInspector(tester, tr.shotListColumnFraming, "Tracking");

    await harness.switchView(tester, tr.shotListBoardBoardSegmentLabel);
    await tester.tap(find.byType(OcptStoryboardPanelFrame));
    await tester.pumpAndSettle();
    final groupFields = find.descendant(
      of: find.byType(OcptStoryboardPanelsGroup),
      matching: find.byType(TextField),
    );
    await tester.enterText(groupFields.first, "Wide on the window");
    await tester.enterText(groupFields.last, "Sun here");
    await tester.pump();

    // The open right dock would cover the tool bar.
    await tester.tap(find.byTooltip(tr.shotListRightDockCloseTooltip));
    await tester.pumpAndSettle();
    await harness.switchView(tester, tr.shotListFloorPlanSegmentLabel);
    await tester.tap(find.byTooltip(tr.shotListFloorPlanToolSetElementAction));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OcptFloorPlanCanvas));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tr.shotListFloorPlanToolLabelAction));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(OcptFloorPlanCanvas), matching: find.byType(TextField)),
      "Long table",
    );
    await tester.enterText(
      find.descendant(of: find.byType(OcptFloorPlanSetTabs), matching: find.byType(TextField)),
      "Big kitchen",
    );
    await tester.pump();

    await harness.unmount(tester);

    expect((await harness.readShotList()).shotsById[shotIds.single]!.framing, "Tracking");
    final panel = (await harness.readStoryboard()).panelsByShotId[shotIds.single]!.single;
    expect(panel.comment, "Wide on the window");
    expect(panel.annotations.single.id, annotationId);
    expect(panel.annotations.single.text, "Sun here");
    final plan = (await harness.readFloorPlans()).setsById[setId]!;
    expect(plan.name, "Big kitchen");
    expect(plan.symbols.single.label, "Long table");
  });
}
