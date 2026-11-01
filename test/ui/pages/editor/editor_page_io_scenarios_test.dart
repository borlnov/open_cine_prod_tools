// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_settings_reveal.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:super_editor/super_editor.dart';

import 'editor_page_scenarios_test_doubles.dart';

/// What the screenplay reads in the version the preview and restore scenarios capture.
const _versionText = "INT. LIGHTHOUSE - NIGHT\n\nThe lamp turns.\n";

/// Run the tests of the editor page io scenarios.
void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  final harness = EditorScenarioHarness();

  setUpAll(harness.setUpAll);
  tearDownAll(harness.tearDownAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Picks the export card titled [title] of the open panel.
  Future<void> pickExportCard(WidgetTester tester, String title) async {
    await harness.openExportPanel(tester);
    await harness.tapQuickly(tester, harness.inDialog(find.text(title)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Applies the options dialog of the PDF export.
  Future<void> applyPdfOptions(WidgetTester tester) => harness.tap(
    tester,
    harness.inDialog(find.text(harness.trOf(tester).editorExportPdfExportAction)),
  );

  /// Captures the working copy as the version "v1" once the screenplay reads [_versionText], then
  /// puts [workingCopy] in its place.
  Future<void> captureVersionThenRewrite(String workingCopy) async {
    await harness.seedScreenplay(_versionText);
    expect(await harness.projectsManager.createProjectVersion(name: "v1", note: ""), isNotNull);
    await harness.seedScreenplay(workingCopy);
  }

  /// Previews the only version of the open Versions tab, waiting for the banner.
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

  testWidgets("exporting to Fountain right after typing saves the text first and exports exactly "
      "it, then says where", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nJust typed.");
    await pickExportCard(tester, tr.editorExportFountainTitle);
    await tester.pumpAndSettle();

    final export = harness.exportManager.exports.single;
    expect(export.kind, "fountain");
    expect(export.text, "$scenarioSampleText\nJust typed.");
    expect(export.projectName, "My Movie");
    expect(export.episodeTag, isNull);
    expect(await harness.storedText(), "$scenarioSampleText\nJust typed.");
    expect((await harness.snapshotReasons()).last, OcptSnapshotReason.export);
    expect(find.text(tr.editorExportSuccessMessage("/tmp/My Movie.fountain")), findsOneWidget);
  });

  testWidgets("a cancelled Fountain export is silent, a failing one says so", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    harness.exportManager.shouldCancel = true;
    await pickExportCard(tester, tr.editorExportFountainTitle);
    await tester.pumpAndSettle();
    expect(harness.exportManager.exports, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);

    harness.exportManager
      ..shouldCancel = false
      ..shouldFail = true;
    await pickExportCard(tester, tr.editorExportFountainTitle);
    await tester.pumpAndSettle();
    expect(find.text(tr.editorExportError), findsOneWidget);
  });

  testWidgets("exporting to PDF right after typing typesets the text just typed with the options "
      "of the dialog", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nPrinted at once.");
    await pickExportCard(tester, tr.editorExportPdfTitle);
    expect(find.byType(OcptEditorExportPdfOptionsDialog), findsOneWidget);
    await applyPdfOptions(tester);

    final export = harness.exportManager.exports.single;
    expect(export.kind, "pdf");
    // The document is parsed again from the typed text, not taken from the parse debounce's.
    expect(export.text, "$scenarioSampleText\nPrinted at once.");
    expect(export.projectName, "My Movie");
    expect(export.pageSetup, isNotNull);
    expect(export.includeSceneNumbers, isNotNull);
    expect(await harness.storedText(), "$scenarioSampleText\nPrinted at once.");
    expect((await harness.snapshotReasons()).last, OcptSnapshotReason.export);
    expect(find.text(tr.editorExportPdfSuccessMessage("/tmp/My Movie.pdf")), findsOneWidget);
  });

  testWidgets("a cancelled PDF options dialog exports nothing, a failing export says so", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await pickExportCard(tester, tr.editorExportPdfTitle);
    await harness.tap(tester, harness.inDialog(find.text(tr.editorPageSetupCancelAction)));
    expect(harness.exportManager.exports, isEmpty);

    harness.exportManager.shouldFail = true;
    await pickExportCard(tester, tr.editorExportPdfTitle);
    await applyPdfOptions(tester);
    expect(find.text(tr.editorExportPdfError), findsOneWidget);
  });

  testWidgets("the project package card flushes a pending text before it asks where to save", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nBefore packing.");
    await pickExportCard(tester, tr.workspaceExportProjectPackageTitle);
    await harness.pumpUntil(tester, () => harness.exportManager.saveDialog.askedCount == 1);

    expect(await harness.storedText(), "$scenarioSampleText\nBefore packing.");
    expect(harness.exportManager.saveDialog.askedCount, 1);
  });

  testWidgets("importing asks first: declining reads no file and changes nothing", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    harness.exportManager.importing("INT. ATTIC - DAY\n\nDust.\n");

    await harness.tapOverflowEntry(tester, tr.editorImportAndReplaceAction);
    expect(find.byType(OcptConfirmDialog), findsOneWidget);
    expect(find.text(tr.editorImportConfirmTitle), findsOneWidget);
    await harness.tap(tester, find.text(tr.editorImportConfirmCancelAction));

    expect(harness.exportManager.pickCount, 0);
    expect(harness.rawText(tester), scenarioSampleText);
  });

  testWidgets("a confirmed import replaces the screenplay, keeping the text typed just before it "
      "and the replaced one as snapshots", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);
    harness.exportManager.importing("INT. ATTIC - DAY\n\nDust.\n");

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nTyped before.");
    await harness.tapOverflowEntry(tester, tr.editorImportAndReplaceAction);
    await harness.tap(tester, find.text(tr.editorImportConfirmReplaceAction).last);

    expect(harness.exportManager.pickCount, 1);
    expect(harness.rawText(tester), "INT. ATTIC - DAY\n\nDust.\n");
    expect(await harness.storedText(), "INT. ATTIC - DAY\n\nDust.\n");
    expect(find.text(tr.editorImportSuccessMessage), findsOneWidget);
    expect((await harness.storedScenes()).map((scene) => scene.heading), ["INT. ATTIC - DAY"]);
    // The text typed just before was saved first, so the import's own snapshot holds it rather
    // than the text the project had before the typing.
    final snapshots = await harness.snapshots();
    expect(snapshots.last.reason, OcptSnapshotReason.import);
    expect(snapshots.last.text, "$scenarioSampleText\nTyped before.");
    expect(snapshots[snapshots.length - 2].reason, OcptSnapshotReason.manual);
    expect(snapshots[snapshots.length - 2].text, scenarioSampleText);
    // The scene panel and the counters describe the imported screenplay at once.
    expect(find.textContaining(tr.editorStatsScenes(1)), findsOneWidget);
    expect(find.text("EXT. GARDEN - NIGHT"), findsNothing);
  });

  testWidgets("an import whose picker is dismissed changes nothing silently, an unreadable file "
      "says so", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.tapOverflowEntry(tester, tr.editorImportAndReplaceAction);
    await harness.tap(tester, find.text(tr.editorImportConfirmReplaceAction).last);
    expect(harness.exportManager.pickCount, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(harness.rawText(tester), scenarioSampleText);

    harness.exportManager.importUnreadable();
    await harness.tapOverflowEntry(tester, tr.editorImportAndReplaceAction);
    await harness.tap(tester, find.text(tr.editorImportConfirmReplaceAction).last);
    expect(find.text(tr.editorImportUnreadableError), findsOneWidget);
    expect(harness.rawText(tester), scenarioSampleText);
  });

  testWidgets("a text typed just before previewing a version is written first, the preview shows "
      "the version read-only, and leaving it brings the typed text back", (tester) async {
    await captureVersionThenRewrite("INT. DOCK - DAY\n\nThe working copy.\n");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "INT. DOCK - DAY\n\nTyped before.\n");
    await harness.tapQuickly(tester, find.text(tr.editorRightDockVersionsTabLabel));
    await previewFirstVersion(tester);

    // The working copy file holds the typed text though the debounce never ran out.
    expect(await harness.storedText(), "INT. DOCK - DAY\n\nTyped before.\n");
    expect(find.byType(OcptWorkspaceReadOnlyBanner), findsOneWidget);
    expect(find.byType(OcptEditorSourceField), findsNothing);
    expect(find.text("INT. LIGHTHOUSE - NIGHT", findRichText: true), findsWidgets);
    expect(find.text("The lamp turns.", findRichText: true), findsWidgets);
    expect(find.byType(OcptEditorPreview), findsWidgets);
    // Nothing that writes is offered.
    expect(find.byTooltip(tr.editorSaveTooltip), findsNothing);
    expect(find.byTooltip(tr.workspaceProjectSettingsTooltip), findsNothing);
    expect(find.text(tr.workspaceAddEpisodeAction), findsNothing);

    // The page-level shortcuts only hear a key pressed with the focus somewhere under them: Tab
    // moves it onto the first toolbar button.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await harness.chord(tester, LogicalKeyboardKey.keyF);
    expect(find.byType(OcptEditorFindBar), findsNothing);
    await harness.chord(tester, LogicalKeyboardKey.keyS);
    expect(await harness.storedText(), "INT. DOCK - DAY\n\nTyped before.\n");

    await exitPreview(tester);
    expect(harness.rawText(tester), "INT. DOCK - DAY\n\nTyped before.\n");
    expect(find.byTooltip(tr.editorSaveTooltip), findsOneWidget);
    // The shortcut pressed during the preview opened nothing behind its back.
    expect(find.byType(OcptEditorFindBar), findsNothing);
  });

  testWidgets("restoring a version puts its text back, after saving what was typed, and keeps "
      "the replaced text as a version of its own", (tester) async {
    await captureVersionThenRewrite("INT. DOCK - DAY\n\nThe working copy.\n");
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "INT. DOCK - DAY\n\nTyped before.\n");
    await harness.tapQuickly(tester, find.text(tr.editorRightDockVersionsTabLabel));
    await harness.tap(tester, find.text(tr.projectVersionRestoreAction));
    await harness.tap(tester, find.text(tr.projectVersionRestoreConfirmAction));
    await harness.pumpUntil(tester, () => harness.rawText(tester) == _versionText);
    await harness.eventually(tester, () async => await harness.storedText() == _versionText);

    expect(harness.rawText(tester), _versionText);
    expect((await harness.storedScenes()).map((scene) => scene.heading), [
      "INT. LIGHTHOUSE - NIGHT",
    ]);
    // The safety version names the text the restore replaced.
    expect(await harness.projectsManager.listProjectVersions(), hasLength(2));
    expect(find.byTooltip(tr.editorSaveTooltip), findsOneWidget);
  });

  testWidgets("Add an episode opens the project settings on the episodes card, and a change "
      "there brings the new episode into the selector", (tester) async {
    await harness.mountWorkspace(tester);
    final tr = harness.trOf(tester);

    await harness.projectsManager.screenplayService.createEpisode(
      database: harness.projectsManager.currentProject!.database,
      title: "Episode two",
    );
    harness.routerManager.pushAnswer = true;
    await harness.tap(tester, find.text(tr.workspaceAddEpisodeAction));

    expect(harness.routerManager.pushed.single.route, OcptRoute.projectSettings);
    expect(harness.routerManager.pushed.single.extra, OcptProjectSettingsReveal.episodes);
    expect(find.text(tr.workspaceAddEpisodeAction), findsNothing);
    expect(find.byTooltip(tr.workspaceEpisodeSelectorTooltip), findsOneWidget);
  });

  testWidgets("the plain settings action opens the project settings at the top", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    harness.routerManager.pushAnswer = false;
    await harness.tap(tester, find.byTooltip(tr.workspaceProjectSettingsTooltip));

    expect(harness.routerManager.pushed.single.route, OcptRoute.projectSettings);
    expect(harness.routerManager.pushed.single.extra, isNull);
  });
}
