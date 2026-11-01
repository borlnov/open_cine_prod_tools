// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_script_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_target_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_working_copy_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

import 'breakdown_mode_scenarios_test_doubles.dart';

/// How long a scenario waits, in real time, for the working copy capture throttle to let go.
const _captureThrottle = Duration(milliseconds: 2100);

/// Run the tests of the breakdown mode lifecycle scenarios.
void main() {
  final harness = BreakdownScenarioHarness();

  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the script view in the centre.
  Finder inScript(Finder target) =>
      find.descendant(of: find.byType(OcptBreakdownScriptView), matching: target);

  /// Finds [target] inside a dialog, such as the export panel or the options dialog.
  Finder inDialog(Finder target) => find.descendant(of: find.byType(AlertDialog), matching: target);

  /// Opens the export panel from the toolbar, leaving time for it to appear but not for the
  /// field-edit debounce to run out.
  Future<void> openExportPanel(WidgetTester tester) =>
      harness.tapOpening(tester, find.byTooltip(harness.trOf(tester).workspaceExportTooltip));

  /// Picks the workbook card of the open export panel and lets the export run.
  Future<void> exportWorkbook(WidgetTester tester) async {
    await openExportPanel(tester);
    await harness.tap(tester, inDialog(find.text(harness.trOf(tester).breakdownExportXlsxTitle)));
  }

  /// Picks the sheets card of the open export panel, then applies its options dialog as it opens.
  Future<void> exportSheets(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await openExportPanel(tester);
    await harness.tapQuickly(tester, inDialog(find.text(tr.breakdownExportSheetsTitle)));
    await tester.pump(const Duration(milliseconds: 300));
    await harness.tap(tester, inDialog(find.text(tr.editorExportPdfExportAction)));
  }

  /// Taps the version card to preview it and waits for the read-only banner to show.
  Future<void> previewFirstVersion(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await tester.tapAt(
      tester.getTopLeft(find.byType(OcptProjectVersionCard)) + const Offset(24, 12),
    );
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
  }

  /// Leaves the preview and waits for the banner to go.
  Future<void> exitPreview(WidgetTester tester) async {
    final tr = harness.trOf(tester);
    await tester.tap(find.text(tr.workspaceReadOnlyBannerExitAction));
    await harness.pumpUntil(
      tester,
      () => !harness.isShown(find.text(tr.workspaceReadOnlyBannerExitAction)),
    );
  }

  /// Whether the status or category chip labelled [label] of the open sheet answers a tap.
  ///
  /// A write refused on a previewed database would leave the screen as it is, so only the chip's
  /// own handler tells a withheld control from a refused write.
  bool isChipLive(WidgetTester tester, String label, {bool isCategory = false}) {
    final inkWell = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.descendant(
              of: find.byType(isCategory ? OcptBreakdownTargetInspector : OcptBreakdownRightDock),
              matching: find.text(label),
            ),
            matching: find.byType(InkWell),
          )
          .first,
    );
    return inkWell.onTap != null;
  }

  /// Seeds element "Teapot", tags its word in the first scene and marks that scene as in progress.
  Future<String> seedTaggedTeapot() async {
    final id = await harness.seedElement("Teapot");
    await harness.seedTag(
      sceneIndex: 0,
      text: "teapot",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: id,
    );
    return id;
  }

  testWidgets("the sheets export asks for its options, hands the document what was typed a moment "
      "ago, and says where the file went, or that it could not be written", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));

    await harness.type(tester, harness.fieldLabelled(tr.breakdownSceneNotesLabel), "Ladder");
    expect(await harness.readSceneNotes(0), "");
    await openExportPanel(tester);
    await harness.tapQuickly(tester, inDialog(find.text(tr.breakdownExportSheetsTitle)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(tr.breakdownExportSheetsDialogTitle), findsOneWidget);

    // Cancelling the options dialog exports nothing.
    await harness.tap(tester, find.text(tr.editorPageSetupCancelAction));
    expect(harness.exportManager.exports, isEmpty);

    await openExportPanel(tester);
    await harness.tapQuickly(tester, inDialog(find.text(tr.breakdownExportSheetsTitle)));
    await tester.pump(const Duration(milliseconds: 300));
    await harness.tap(tester, inDialog(find.text(tr.breakdownExportSheetsOnlyDoneLabel)));
    await harness.tap(tester, inDialog(find.text(tr.editorExportPdfExportAction)));

    final export = harness.exportManager.exports.single;
    expect(export.document, "sheets");
    expect(export.projectName, "My Movie");
    expect(export.episodeTag, isNull);
    expect(export.onlyDoneScenes, isTrue);
    expect(export.includeNotes, isTrue);
    expect(export.includeToFindList, isTrue);
    expect(export.pageSetup.format, OcptPageFormat.usLetter);
    expect(export.parsedSceneCount, 2);
    expect(export.snapshot.scenes.first.notes, "Ladder");
    expect(await harness.readSceneNotes(0), "Ladder");
    expect(find.text(tr.breakdownExportSheetsSuccessMessage("/tmp/sheets.out")), findsOneWidget);

    // A cancelled save dialog says nothing at all.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    harness.exportManager.shouldCancel = true;
    await exportSheets(tester);
    expect(harness.exportManager.exports, hasLength(2));
    expect(find.byType(SnackBar), findsNothing);

    // A write that throws raises the error notice.
    harness.exportManager
      ..shouldCancel = false
      ..shouldFail = true;
    await exportSheets(tester);
    expect(harness.exportManager.exports, hasLength(3));
    expect(find.text(tr.breakdownExportSheetsError), findsOneWidget);
  });

  testWidgets("the workbook export goes straight to the save dialog with what was typed a moment "
      "ago, and reports saved, cancelled, failed and thrown", (tester) async {
    await seedTaggedTeapot();
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, inScript(find.text("teapot")));

    await harness.type(tester, harness.fieldLabelled(tr.breakdownElementNotesLabel), "Chipped");
    await openExportPanel(tester);
    await harness.tapQuickly(tester, inDialog(find.text(tr.breakdownExportXlsxTitle)));
    await tester.pumpAndSettle();

    final export = harness.exportManager.exports.single;
    expect(export.document, "xlsx");
    expect(export.projectName, "My Movie");
    expect(export.episodeTag, isNull);
    expect(export.onlyDoneScenes, isNull);
    expect(export.parsedSceneCount, 2);
    expect(export.snapshot.elements.single.notes, "Chipped");
    expect(find.text(tr.breakdownExportXlsxSuccessMessage("/tmp/xlsx.out")), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    harness.exportManager.shouldCancel = true;
    await exportWorkbook(tester);
    expect(harness.exportManager.exports, hasLength(2));
    expect(find.byType(SnackBar), findsNothing);

    // The writer answering that it could not build the workbook is a failure too.
    harness.exportManager
      ..shouldCancel = false
      ..shouldAnswerFailed = true;
    await exportWorkbook(tester);
    expect(harness.exportManager.exports, hasLength(3));
    expect(find.text(tr.breakdownExportXlsxError), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    harness.exportManager
      ..shouldAnswerFailed = false
      ..shouldFail = true;
    await exportWorkbook(tester);
    expect(harness.exportManager.exports, hasLength(4));
    expect(find.text(tr.breakdownExportXlsxError), findsOneWidget);
  });

  testWidgets("the panel's project package card reaches the save dialog", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await openExportPanel(tester);
    await harness.tap(tester, inDialog(find.text(tr.workspaceExportProjectPackageTitle)));
    await harness.pumpUntil(tester, () => harness.exportManager.saveDialog.askedCount > 0);

    expect(harness.exportManager.saveDialog.askedCount, 1);
    expect(harness.exportManager.exports, isEmpty);
  });

  testWidgets("coming back from the project settings with a change re-reads the page format, "
      "while a plain return reads nothing", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.projectsManager.saveCurrentProjectPageFormat(OcptPageFormat.a4);

    harness.routerManager.pushAnswer = false;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    expect(harness.routerManager.pushCount, 1);
    await exportSheets(tester);
    expect(harness.exportManager.exports.last.pageSetup.format, OcptPageFormat.usLetter);

    harness.routerManager.pushAnswer = true;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));
    expect(harness.routerManager.pushCount, 2);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await exportSheets(tester);
    expect(harness.exportManager.exports.last.pageSetup.format, OcptPageFormat.a4);
  });

  testWidgets("the left dock folds away, the right dock reopens on its last tab, and the overflow "
      "menu resets the saved layout", (tester) async {
    await harness.propertiesManager.breakdownLeftDockFraction.store(0.31);
    await harness.propertiesManager.breakdownRightDockFraction.store(0.27);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(find.byType(OcptBreakdownScenePanel), findsOneWidget);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    expect(find.byType(OcptBreakdownScenePanel), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    expect(find.byType(OcptBreakdownScenePanel), findsOneWidget);

    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.byType(OcptBreakdownSceneInspector), findsOneWidget);
    await harness.tap(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);
    // The active tab closes the dock when picked again; the toolbar reopens it where it was.
    await harness.tap(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    expect(find.byType(OcptProjectVersionsPanel), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    expect(find.byType(OcptProjectVersionsPanel), findsOneWidget);
    await harness.tap(tester, find.byTooltip(tr.breakdownRightDockCloseTooltip));
    expect(find.byType(OcptProjectVersionsPanel), findsNothing);
    expect(
      await harness.propertiesManager.breakdownLastRightDockTab.load(),
      OcptBreakdownRightDockTab.versions,
    );

    expect(await harness.propertiesManager.breakdownLeftDockFraction.load(), 0.31);
    await harness.tap(
      tester,
      find.byTooltip(
        MaterialLocalizations.of(tester.element(find.byType(Scaffold))).showMenuTooltip,
      ),
    );
    await harness.tap(tester, find.text(tr.breakdownResetPanelLayoutAction));
    expect(
      await harness.propertiesManager.breakdownLeftDockFraction.load(),
      OcptWorkspaceDock.leftDefaultFraction,
    );
    expect(
      await harness.propertiesManager.breakdownRightDockFraction.load(),
      OcptWorkspaceDock.rightDefaultFraction,
    );
  });

  testWidgets("the Versions tab shows the working copy card and follows a flushed edit", (
    tester,
  ) async {
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await harness.tap(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    expect(find.text(tr.projectWorkingCopyIdenticalHint("v1")), findsOneWidget);

    // A typed edit reaching the database makes the card read the new state.
    await tester.runAsync(() => Future<void>.delayed(_captureThrottle));
    await harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));
    await harness.type(tester, harness.fieldLabelled(tr.breakdownSceneNotesLabel), "Ladder");
    await harness.tapQuickly(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    await harness.pumpUntil(
      tester,
      () => harness.isShown(find.text(tr.projectWorkingCopyModifiedHint("v1"))),
    );
    expect(find.byType(OcptProjectWorkingCopyCard), findsOneWidget);
    expect(find.text(tr.projectWorkingCopyModifiedHint("v1")), findsOneWidget);
  });

  testWidgets("previewing a version reloads the whole breakdown and withholds every write, "
      "leaving it brings the working copy back", (tester) async {
    await seedTaggedTeapot();
    await harness.seedRole("Sam");
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);

    // Written after the version was captured, so the preview cannot show it.
    final scenes = await harness.readScenes();
    await harness.projectsManager.breakdownService.updateSceneBreakdown(
      database: harness.database,
      sceneId: scenes.first.id,
      status: const Value(OcptBreakdownSceneStatus.done),
    );
    await harness.seedTag(
      sceneIndex: 0,
      text: "table",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: (await harness.readElements()).single.id,
    );

    await harness.mount(tester);
    final tr = harness.trOf(tester);
    final collision = tr.roleAlertCompactCollisionLine("SAM");
    expect(find.text(tr.breakdownScenesDoneCount(1, 2)), findsOneWidget);
    expect(find.text(collision), findsWidgets);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsOneWidget);
    await harness.tap(tester, inScript(find.text("teapot")));
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    expect(isChipLive(tester, tr.breakdownElementStatusConfirmed), isTrue);

    await harness.openRightDock(tester);
    await harness.tap(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    await previewFirstVersion(tester);

    // The version's own breakdown, the selection dropped and the alerts withheld.
    expect(find.text(tr.workspaceReadOnlyBannerExitAction), findsOneWidget);
    expect(find.text(tr.breakdownScenesDoneCount(0, 2)), findsOneWidget);
    expect(find.text(collision), findsNothing);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsNothing);
    expect(
      find.text("${tr.breakdownStatsTagged(1)} · ${tr.breakdownStatsCategories(1)}"),
      findsOneWidget,
    );

    // Words are no click target any more, a tagged one still shows its sheet, read only.
    await harness.tap(tester, inScript(find.text("enters ")));
    expect(inScript(find.text("enters ")), findsOneWidget);
    await harness.tap(tester, find.text(tr.breakdownRightDockInspectorTabLabel));
    expect(find.text(tr.breakdownInspectorNoSelectionHint), findsOneWidget);
    await harness.tap(tester, inScript(find.text("teapot")));
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OcptBreakdownTargetInspector),
        matching: harness.editableFields(),
      ),
      findsNothing,
    );
    expect(find.text(tr.breakdownRemoveFromBreakdownAction), findsNothing);
    expect(isChipLive(tester, tr.breakdownElementStatusConfirmed), isFalse);
    expect(isChipLive(tester, tr.resourcesElementCategoryCostume, isCategory: true), isFalse);

    // The scene sheet offers no set creation and its status chips do nothing.
    await harness.tap(tester, find.text(tr.breakdownInspectorBackToSceneAction));
    expect(find.text(tr.breakdownSceneInspectorAddSetAction), findsNothing);
    expect(isChipLive(tester, tr.breakdownSceneStatusDone), isFalse);

    // Switching the centre and searching only read, so they stay.
    await harness.tap(tester, find.text(tr.breakdownHeaderRecapSegmentLabel));
    await harness.type(tester, harness.fieldHinted(tr.breakdownHeaderSearchHint), "tea");
    await tester.pumpAndSettle();
    expect(find.text("Teapot"), findsWidgets);

    // The package export card says why it is unavailable.
    await harness.tap(tester, find.byTooltip(tr.workspaceExportTooltip));
    expect(inDialog(find.text(tr.workspaceExportProjectPackagePreviewReason)), findsOneWidget);

    // Back to the working copy: everything written since is there again, and writable.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await exitPreview(tester);
    expect(find.text(tr.breakdownScenesDoneCount(1, 2)), findsOneWidget);
    expect(find.text(collision), findsWidgets);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsOneWidget);
    // The search and the recap survive the round trip.
    expect(
      tester.widget<TextField>(harness.fieldHinted(tr.breakdownHeaderSearchHint)).controller!.text,
      "tea",
    );
  });

  testWidgets("a note typed just before previewing a version is written first, the preview shows "
      "the version's own, and leaving it brings the note back", (tester) async {
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleRightDockTooltip));
    await harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));

    await harness.type(tester, harness.fieldLabelled(tr.breakdownSceneNotesLabel), "Ladder");
    await harness.tapQuickly(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    await previewFirstVersion(tester);

    // The working copy file holds it already, though the debounce never ran out.
    final stored = await harness.projectsManager.breakdownService.loadScenes(
      database: harness.projectsManager.currentProject!.fileDatabase,
      screenplayId: harness.screenplayId,
      episodeNumber: null,
    );
    expect(stored.first.notes, "Ladder");

    // The preview shows the version, which never had it.
    await harness.tap(tester, find.text(tr.breakdownRightDockInspectorTabLabel));
    await harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));
    expect(harness.fieldLabelled(tr.breakdownSceneNotesLabel), findsOneWidget);
    expect(
      tester.widget<TextField>(harness.fieldLabelled(tr.breakdownSceneNotesLabel)).controller!.text,
      isEmpty,
    );

    await exitPreview(tester);
    await harness.tap(tester, inScript(find.text("INT. KITCHEN - DAY")));
    expect(
      tester.widget<TextField>(harness.fieldLabelled(tr.breakdownSceneNotesLabel)).controller!.text,
      "Ladder",
    );
  });

  testWidgets("restoring a version puts the breakdown back to it and drops the selection", (
    tester,
  ) async {
    await seedTaggedTeapot();
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.seedTag(
      sceneIndex: 1,
      text: "rake",
      targetKind: OcptBreakdownTargetKind.element,
      targetId: (await harness.readElements()).single.id,
    );
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    expect(
      find.text("${tr.breakdownStatsTagged(1)} · ${tr.breakdownStatsCategories(1)}"),
      findsOneWidget,
    );
    await harness.tap(tester, inScript(find.text("teapot")));
    expect(find.byType(OcptBreakdownTargetInspector), findsOneWidget);

    await harness.tap(tester, find.text(tr.breakdownRightDockVersionsTabLabel));
    await harness.tap(tester, find.text(tr.projectVersionRestoreAction));
    await harness.tap(tester, find.text(tr.projectVersionRestoreConfirmAction));
    await harness.pumpUntil(
      tester,
      () =>
          harness.isShown(find.byType(OcptProjectVersionsPanel)) &&
          harness.isShown(find.byType(OcptBreakdownScriptView)),
    );
    await harness.eventually(tester, () async => (await harness.readTags()).length == 1);

    expect((await harness.readTags()).single.taggedText, "teapot");
    await harness.tap(tester, find.text(tr.breakdownRightDockInspectorTabLabel));
    expect(find.byType(OcptBreakdownTargetInspector), findsNothing);
    expect(find.byType(OcptBreakdownSceneInspector), findsOneWidget);
  });
}
