// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'editor_page_scenarios_test_doubles.dart';

void main() {
  BlinkController.indeterminateAnimationsEnabled = false;

  final harness = EditorScenarioHarness();

  setUpAll(harness.setUpAll);
  tearDownAll(harness.tearDownAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Finds [target] inside the scene panel.
  Finder inPanel(Finder target) =>
      find.descendant(of: find.byType(OcptEditorScenePanel), matching: target);

  /// Whether the toolbar currently says the screenplay holds unsaved changes.
  bool isUnsaved(WidgetTester tester) =>
      harness.isShown(find.byTooltip(harness.trOf(tester).editorUnsavedChangesTooltip));

  testWidgets("entry loads the stored screenplay into the raw field, the scene panel and the "
      "counters, with nothing to save", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    expect(harness.rawText(tester), scenarioSampleText);
    expect(find.text("My Movie"), findsOneWidget);
    expect(inPanel(find.text("INT. KITCHEN - DAY")), findsOneWidget);
    expect(inPanel(find.text("EXT. GARDEN - NIGHT")), findsOneWidget);
    expect(find.textContaining(tr.editorStatsScenes(2)), findsOneWidget);
    expect(find.textContaining(tr.editorStatsCharacters(1)), findsOneWidget);
    expect(find.text(tr.editorStatsNeverSaved), findsOneWidget);
    expect(isUnsaved(tester), isFalse);
  });

  testWidgets("typing is saved by the autosave debounce, not before, and reconciles the scene "
      "index keeping the ids of the scenes that stayed", (tester) async {
    await harness.mount(tester);
    final before = await harness.storedScenes();
    expect(before.map((scene) => scene.heading), ["INT. KITCHEN - DAY", "EXT. GARDEN - NIGHT"]);

    await harness.type(tester, harness.rawField, "INT. CELLAR - NIGHT\n\n$scenarioSampleText");
    expect(isUnsaved(tester), isTrue);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(await harness.storedText(), scenarioSampleText);
    expect(isUnsaved(tester), isTrue);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(await harness.storedText(), startsWith("INT. CELLAR - NIGHT"));
    expect(isUnsaved(tester), isFalse);

    final after = await harness.storedScenes();
    expect(after.map((scene) => scene.heading), [
      "INT. CELLAR - NIGHT",
      "INT. KITCHEN - DAY",
      "EXT. GARDEN - NIGHT",
    ]);
    expect(after[1].id, before[0].id);
    expect(after[2].id, before[1].id);
    expect({after[0].id}.intersection(before.map((scene) => scene.id).toSet()), isEmpty);
    expect((await harness.snapshotReasons()).last, OcptSnapshotReason.timer);
  });

  testWidgets("every keystroke restarts the autosave debounce", (tester) async {
    await harness.mount(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nOne.");
    await tester.pump(const Duration(milliseconds: 1500));
    await harness.type(tester, harness.rawField, "$scenarioSampleText\nOne. Two.");
    await tester.pump(const Duration(milliseconds: 1500));

    // 3 s since the first keystroke, 1.5 s since the last: nothing was written yet.
    expect(await harness.storedText(), scenarioSampleText);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(await harness.storedText(), "$scenarioSampleText\nOne. Two.");
  });

  testWidgets("the toolbar's save button and Ctrl+S write at once, tagged as manual saves", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nFirst.");
    await harness.tap(tester, find.byTooltip(tr.editorSaveTooltip));
    expect(await harness.storedText(), "$scenarioSampleText\nFirst.");
    expect(isUnsaved(tester), isFalse);
    expect(find.text(tr.editorStatsNeverSaved), findsNothing);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nSecond.");
    await tester.tap(harness.rawField);
    await harness.chord(tester, LogicalKeyboardKey.keyS);
    expect(await harness.storedText(), "$scenarioSampleText\nSecond.");

    expect(
      (await harness.snapshotReasons()).reversed.take(2),
      everyElement(OcptSnapshotReason.manual),
    );
  });

  testWidgets("a save with nothing to save writes nothing", (tester) async {
    await harness.mount(tester);
    final snapshotsBefore = await harness.snapshotReasons();

    await harness.tap(tester, find.byTooltip(harness.trOf(tester).editorSaveTooltip));

    expect(await harness.snapshotReasons(), snapshotsBefore);
  });

  testWidgets("leaving the page right after typing flushes the text to the project", (
    tester,
  ) async {
    await harness.mount(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nLast words.");
    await tester.pump(const Duration(milliseconds: 100));
    await harness.unmount(tester);

    expect(await harness.storedText(), "$scenarioSampleText\nLast words.");
    expect((await harness.snapshotReasons()).last, OcptSnapshotReason.timer);
  });

  testWidgets("the back button saves a manual snapshot, closes the project and leaves", (
    tester,
  ) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nGoodbye.");
    await harness.tapQuickly(tester, find.byTooltip(tr.editorBackToProjectsTooltip));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(harness.projectsManager.currentProject, isNull);
    expect(harness.routerManager.popCount, 1);
    await harness.reopenProject();
    expect(await harness.storedText(), "$scenarioSampleText\nGoodbye.");
    // Reopening the project took its own safety snapshot, right after the manual one.
    final reasons = await harness.snapshotReasons();
    expect(reasons.sublist(reasons.length - 2), [
      OcptSnapshotReason.manual,
      OcptSnapshotReason.open,
    ]);
  });

  testWidgets("a text typed just before changing mode is in the project, and the screenplay "
      "mode comes back to it", (tester) async {
    await harness.mountWorkspace(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nBetween modes.");
    await harness.tapQuickly(tester, find.text(tr.workspaceModeBudget));
    await tester.pumpAndSettle();

    expect(find.byType(OcptEditorSourceField), findsNothing);
    expect(await harness.storedText(), "$scenarioSampleText\nBetween modes.");

    await harness.tap(tester, find.text(tr.workspaceModeScreenplay));
    expect(harness.rawText(tester), "$scenarioSampleText\nBetween modes.");
    expect(isUnsaved(tester), isFalse);
  });

  testWidgets("a text typed just before changing episode is saved into the episode it was typed "
      "in, and each episode keeps its own text", (tester) async {
    final project = harness.projectsManager.currentProject!;
    final secondId = (await harness.projectsManager.screenplayService.createEpisode(
      database: project.database,
      title: "Episode two",
    ))!;
    await harness.seedScreenplay("INT. ATTIC - DAY\n\nDust.\n", screenplayId: secondId);
    await harness.mountWorkspace(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nIn episode one.");
    await harness.tapOpening(tester, find.byTooltip(tr.workspaceEpisodeSelectorTooltip));
    await harness.tap(tester, find.text(tr.workspaceEpisodeTitledLabel(2, "Episode two")));

    expect(harness.rawText(tester), "INT. ATTIC - DAY\n\nDust.\n");
    expect(await harness.storedText(), "$scenarioSampleText\nIn episode one.");
    expect(await harness.storedText(screenplayId: secondId), "INT. ATTIC - DAY\n\nDust.\n");

    await harness.type(tester, harness.rawField, "INT. ATTIC - DAY\n\nDust and cobwebs.\n");
    await harness.tapOpening(tester, find.byTooltip(tr.workspaceEpisodeSelectorTooltip));
    await harness.tap(tester, find.text(tr.workspaceEpisodeTitledLabel(1, "My Movie")));

    expect(harness.rawText(tester), "$scenarioSampleText\nIn episode one.");
    expect(
      await harness.storedText(screenplayId: secondId),
      "INT. ATTIC - DAY\n\nDust and cobwebs.\n",
    );
  });

  testWidgets("a failing save raises the error once, keeps the text dirty, and the next save "
      "goes through", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.setSaveFailing(isFailing: true);
    await harness.type(tester, harness.rawField, "$scenarioSampleText\nUnsafe.");
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text(tr.editorSaveError), findsOneWidget);
    expect(isUnsaved(tester), isTrue);
    expect(harness.rawText(tester), "$scenarioSampleText\nUnsafe.");

    // The error is a transient: it is gone once the snackbar leaves, and does not come back.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(tr.editorSaveError), findsNothing);
    expect(isUnsaved(tester), isTrue);

    await harness.setSaveFailing(isFailing: false);
    await harness.tap(tester, find.byTooltip(tr.editorSaveTooltip));
    expect(await harness.storedText(), "$scenarioSampleText\nUnsafe.");
    expect(isUnsaved(tester), isFalse);
  });

  testWidgets("leaving the page while the save fails only logs it", (tester) async {
    await harness.mount(tester);

    await harness.setSaveFailing(isFailing: true);
    await harness.type(tester, harness.rawField, "$scenarioSampleText\nLost.");
    await harness.unmount(tester);

    await harness.setSaveFailing(isFailing: false);
    expect(await harness.storedText(), scenarioSampleText);
  });

  testWidgets("text typed while a save is in flight stays dirty for the next one", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nA.");
    final release = harness.holdDatabase();
    await tester.tap(find.byTooltip(tr.editorSaveTooltip));
    await tester.pump();
    // The save is waiting on the database; a second keystroke lands meanwhile.
    await harness.type(tester, harness.rawField, "$scenarioSampleText\nA. B.");
    await release();
    await tester.pump(const Duration(milliseconds: 100));

    expect(await harness.storedText(), "$scenarioSampleText\nA.");
    expect(isUnsaved(tester), isTrue);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(await harness.storedText(), "$scenarioSampleText\nA. B.");
    expect(isUnsaved(tester), isFalse);
  });

  testWidgets("opening the styled editor numbers the scene headings, which the page saves by "
      "itself", (tester) async {
    await harness.propertiesManager.editorMode.store(OcptEditorMode.styled);
    await harness.mount(tester);

    // Nothing was typed, yet the styled editor normalised the headings and said so.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final stored = await harness.storedText();
    expect(stored, contains("INT. KITCHEN - DAY #1#"));
    expect(stored, contains("EXT. GARDEN - NIGHT #2#"));
    expect((await harness.storedScenes()).map((scene) => scene.number), ["1", "2"]);
  });

  testWidgets("what survives leaving and coming back: the text, the mode, the display "
      "preferences; what does not: the panels, the dock and the find bar", (tester) async {
    await harness.mount(tester);
    final tr = harness.trOf(tester);

    await harness.type(tester, harness.rawField, "$scenarioSampleText\nStill here.");
    await harness.tap(tester, find.byTooltip(tr.workspaceToggleLeftDockTooltip));
    await harness.tap(tester, find.byTooltip(tr.editorToggleSyntaxGuideTooltip));
    await harness.tapOverflowEntry(tester, tr.editorFindAction);
    expect(find.byType(OcptEditorFindBar), findsOneWidget);
    expect(find.byType(OcptEditorScenePanel), findsNothing);
    await harness.tap(tester, find.byTooltip(tr.editorSwitchToStyledModeTooltip));

    await harness.unmount(tester);
    await harness.mount(tester);

    expect(find.byType(OcptStyledScreenplayEditor), findsOneWidget);
    expect(find.byType(OcptEditorScenePanel), findsOneWidget);
    expect(find.byType(OcptEditorFindBar), findsNothing);
    expect(find.byType(OcptEditorRightDock), findsNothing);
    final document = SuperEditorInspector.findDocument()!;
    expect(
      (document.getNodeAt(document.nodeCount - 1)! as ParagraphNode).text.toPlainText(),
      "Still here.",
    );
  });
}
