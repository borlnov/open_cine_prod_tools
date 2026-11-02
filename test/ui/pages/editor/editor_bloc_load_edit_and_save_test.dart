// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'editor_bloc_test_doubles.dart';

/// A projects manager that counts how many times a working-copy capture actually reads the whole
/// project, so a dispatch that only *requests* one (rather than always performing it) can be told
/// apart from one that the throttle skipped.
class _CountingProjectsManager extends OcptProjectsManager {
  /// How many times [captureWorkingCopyState] actually ran.
  int captureCount = 0;

  /// Class constructor
  _CountingProjectsManager({required OcptPropertiesManager propertiesManager})
    : super(propertiesManager: propertiesManager, appLanguageCode: testAppLanguageCode);

  /// Count the capture, then delegate to the real one.
  @override
  Future<OcptProjectWorkingCopyState?> captureWorkingCopyState() async {
    captureCount++;
    return super.captureWorkingCopyState();
  }
}

/// Run the tests of the editor bloc load edit and save.
void main() {
  const editedText = "INT. HOUSE - DAY\n\nAction.\n";

  // Scene headings start at line 0 and line 4; the two scenes are deliberately given different
  // word counts (6 and 7) so a test can tell "the first scene's stats" and "the second scene's
  // stats" apart just by comparing counts.
  const twoSceneText =
      "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two here.\n";

  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's save error paths)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("ocpt_editor_bloc_test_");
    projectsManager = OcptProjectsManager(
      propertiesManager: propertiesManager,
      appLanguageCode: testAppLanguageCode,
    );
    await projectsManager.initLifeCycle();

    final result = await projectsManager.createProject(
      name: "My Movie",
      filePath: p.join(tempDir.path, "movie.ocpt"),
    );
    expect(result.status.isSuccess, isTrue);
  });

  tearDown(() async {
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Builds a bloc wired to the test project, with debounces short enough to await in a test.
  ///
  /// [exportManager] defaults to an [InertExportManager]: no test here exports.
  /// [overrideProjectsManager] lets a test swap in a manager of its own (already holding an open
  /// project), for the one that needs to observe its calls.
  OcptEditorBloc buildBloc({
    OcptScreenplayService? screenplayService,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptProjectsManager? overrideProjectsManager,
    String? selectedEpisodeId,
  }) => OcptEditorBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? RecordingRouterManager(),
    screenplayService: screenplayService,
    exportManager: exportManager ?? InertExportManager(),
    parseDebounce: const Duration(milliseconds: 20),
    autosaveDebounce: const Duration(milliseconds: 60),
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptEditorState> waitForState(
    OcptEditorBloc bloc,
    bool Function(OcptEditorState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// Reads the screenplay snapshots of the test project, oldest first.
  Future<List<OcptScreenplaySnapshotRow>> readSnapshots() {
    final database = projectsManager.currentProject!.database;

    return (database.select(
      database.ocptScreenplaySnapshotsTable,
    )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();
  }

  test('loads the screenplay (text, title, empty document) on entry', () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.title, "My Movie");
    expect(state.text, "");
    expect(state.document, isNotNull);
    expect(state.scenes, isEmpty);
    expect(state.isDirty, isFalse);

    await bloc.close();
  });

  test('constructed with a second episode selected, reads and writes that episode rather than '
      'the primary screenplay', () async {
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: "INT. PRIMARY - DAY\n\nAction one.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );
    final secondEpisodeId = await projectsManager.screenplayService.createEpisode(
      database: project.database,
    );
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: secondEpisodeId!,
      fountainText: "INT. SECOND EPISODE - NIGHT\n\nAction two.\n",
      snapshotReason: OcptSnapshotReason.manual,
    );

    final bloc = buildBloc(selectedEpisodeId: secondEpisodeId);
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.text, contains("SECOND EPISODE"));
    expect(state.text, isNot(contains("PRIMARY")));

    bloc.add(const OcptEditorTextChangedEvent(text: "INT. REWRITTEN - DAY\n\nAction.\n"));
    await waitForState(bloc, (state) => state.isDirty);
    bloc.add(const OcptEditorSaveRequestedEvent(isManual: true));
    await waitForState(bloc, (state) => !state.isDirty && !state.isSaving);

    final primaryText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    final secondEpisodeText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: secondEpisodeId,
    );
    expect(primaryText, contains("PRIMARY"));
    expect(secondEpisodeText, contains("REWRITTEN"));

    await bloc.close();
  });

  test('marks the text dirty on edit, then re-parses it after the debounce', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));

    final dirtyState = await waitForState(bloc, (state) => state.isDirty);
    // The document still lags behind: the parse debounce hasn't elapsed yet.
    expect(dirtyState.scenes, isEmpty);

    final parsedState = await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    expect(parsedState.scenes.single.headingText, "INT. HOUSE - DAY");

    await bloc.close();
  });

  test('currentSceneIndex tracks the caret across scenes, live, no debounce wait needed', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: twoSceneText));
    await waitForState(bloc, (state) => state.scenes.length == 2);
    expect(bloc.state.currentSceneIndex, 0);

    bloc.add(const OcptEditorCaretMovedEvent(line: 6));
    final secondSceneState = await waitForState(bloc, (state) => state.currentSceneIndex == 1);
    expect(secondSceneState.currentLine, 6);

    bloc.add(const OcptEditorCaretMovedEvent(line: 2));
    final firstSceneState = await waitForState(bloc, (state) => state.currentSceneIndex == 0);
    expect(firstSceneState.currentLine, 2);

    await bloc.close();
  });

  test(
    'currentSceneIndex is null while the caret precedes every scene, or nothing is parsed yet',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      expect(bloc.state.currentSceneIndex, isNull);

      bloc.add(const OcptEditorTextChangedEvent(text: "\n\n$twoSceneText"));
      await waitForState(bloc, (state) => state.scenes.length == 2);
      // The caret is still on line 0, which now precedes the first scene heading (pushed to
      // line 2 by the two leading blank lines).
      expect(bloc.state.currentSceneIndex, isNull);

      await bloc.close();
    },
  );

  test(
    'autosaves after the debounce, clearing the dirty flag and tagging the snapshot "timer"',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      final savedState = await waitForState(
        bloc,
        (state) => !state.isDirty && state.lastSavedAt != null,
      );

      expect(savedState.isSaving, isFalse);

      final project = projectsManager.currentProject!;
      final storedText = await projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );
      expect(storedText, editedText);

      final snapshots = await readSnapshots();
      expect(snapshots.last.reason, OcptSnapshotReason.timer);

      await bloc.close();
    },
  );

  test('a manual save request saves immediately and tags the snapshot "manual"', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);
    bloc.add(const OcptEditorSaveRequestedEvent(isManual: true));

    await waitForState(bloc, (state) => !state.isDirty && state.lastSavedAt != null);

    final snapshots = await readSnapshots();
    expect(snapshots.last.reason, OcptSnapshotReason.manual);

    await bloc.close();
  });

  test('a failed save keeps the text dirty and raises the transient save error', () async {
    final bloc = buildBloc(screenplayService: const FailingScreenplayService());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);
    bloc.add(const OcptEditorSaveRequestedEvent(isManual: true));

    final failedState = await waitForState(bloc, (state) => state.hasSaveError);
    expect(failedState.isDirty, isTrue);
    expect(failedState.isSaving, isFalse);
    expect(failedState.lastSavedAt, isNull);

    bloc.add(const OcptEditorSaveErrorDismissedEvent());
    final dismissedState = await waitForState(bloc, (state) => !state.hasSaveError);
    expect(dismissedState.isDirty, isTrue);

    await bloc.close();
  });

  test('scene jump requests carry the offset and a fresh id every time', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorSceneJumpRequestedEvent(charOffset: 42));
    final firstState = await waitForState(bloc, (state) => state.jumpRequest != null);
    final firstId = firstState.jumpRequest!.id;
    expect(firstState.jumpRequest!.charOffset, 42);

    // A second jump to the same offset still produces a distinguishable request.
    bloc.add(const OcptEditorSceneJumpRequestedEvent(charOffset: 42));
    final secondState = await waitForState(
      bloc,
      (state) => state.jumpRequest != null && state.jumpRequest!.id != firstId,
    );
    expect(secondState.jumpRequest!.charOffset, 42);

    await bloc.close();
  });

  test('the scene panel visibility toggle flips its flag', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.isScenePanelVisible, isTrue);

    bloc.add(const OcptEditorScenePanelToggledEvent());
    final state = await waitForState(bloc, (state) => !state.isScenePanelVisible);
    expect(state.isScenePanelVisible, isFalse);

    await bloc.close();
  });

  test('OcptEditorState.init defaults the right dock to the preview tab', () {
    const state = OcptEditorState.init();

    expect(state.rightDockTab, OcptEditorRightDockTab.preview);
    expect(state.autoClosedRightDockTab, isNull);
  });

  test('loading the editor in raw mode leaves the preview tab active', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptEditorMode.raw);
    expect(state.rightDockTab, OcptEditorRightDockTab.preview);
    expect(state.autoClosedRightDockTab, isNull);

    await bloc.close();
  });

  test('loading the editor in styled mode closes the preview tab and remembers it, exactly like a '
      'live mode switch would', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptEditorMode.styled);
    expect(state.rightDockTab, isNull);
    expect(state.autoClosedRightDockTab, OcptEditorRightDockTab.preview);

    await bloc.close();
  });

  test('selecting a closed tab opens the dock on it', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorRightDockClosedEvent());
    await waitForState(bloc, (state) => state.rightDockTab == null);

    bloc.add(const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.syntax));
    final state = await waitForState(bloc, (state) => state.rightDockTab != null);
    expect(state.rightDockTab, OcptEditorRightDockTab.syntax);

    await bloc.close();
  });

  test('selecting the currently active tab closes the dock', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, OcptEditorRightDockTab.preview);

    bloc.add(const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.preview));
    final state = await waitForState(bloc, (state) => state.rightDockTab == null);
    expect(state.rightDockTab, isNull);

    await bloc.close();
  });

  test('selecting a different tab than the active one switches the dock to it', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, OcptEditorRightDockTab.preview);

    bloc.add(const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.syntax));
    final state = await waitForState(
      bloc,
      (state) => state.rightDockTab == OcptEditorRightDockTab.syntax,
    );
    expect(state.rightDockTab, OcptEditorRightDockTab.syntax);

    await bloc.close();
  });

  test('opening the Versions tab, and a save landing while it is open, each capture the working '
      'copy afresh', () async {
    final countingManager = _CountingProjectsManager(propertiesManager: propertiesManager);
    await countingManager.initLifeCycle();
    final created = await countingManager.createProject(
      name: "Working Copy Movie",
      filePath: p.join(tempDir.path, "working_copy.ocpt"),
    );
    expect(created.status.isSuccess, isTrue);

    final bloc = buildBloc(overrideProjectsManager: countingManager);
    await waitForState(bloc, (state) => !state.isLoading);
    // The initial refresh on mount already captured the working copy once, unthrottled.
    expect(countingManager.captureCount, 1);

    // Past the mixin's throttle window, so opening the tab below is guaranteed to actually
    // capture rather than be silently skipped.
    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));

    bloc.add(const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.versions));
    await waitForState(bloc, (state) => state.rightDockTab == OcptEditorRightDockTab.versions);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(countingManager.captureCount, 2);

    // Clear the throttle again, then save while the tab opened above is still the active one.
    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));
    bloc.add(const OcptEditorTextChangedEvent(text: "INT. HOUSE - DAY\n\nAction.\n"));
    bloc.add(const OcptEditorSaveRequestedEvent(isManual: true));
    await waitForState(bloc, (state) => !state.isDirty && !state.isSaving);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(countingManager.captureCount, 3);

    await bloc.close();
    await countingManager.disposeLifeCycle();
  });

  test("the dock's own close button closes it regardless of the active tab", () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.syntax));
    await waitForState(bloc, (state) => state.rightDockTab == OcptEditorRightDockTab.syntax);

    bloc.add(const OcptEditorRightDockClosedEvent());
    final state = await waitForState(bloc, (state) => state.rightDockTab == null);
    expect(state.rightDockTab, isNull);

    await bloc.close();
  });

  test("the toolbar's toggle closes an open dock and reopens it on the last tab used", () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.metadata));
    await waitForState(bloc, (state) => state.rightDockTab == OcptEditorRightDockTab.metadata);

    bloc.add(const OcptEditorRightDockToggledEvent());
    final closedState = await waitForState(bloc, (state) => state.rightDockTab == null);
    expect(closedState.lastRightDockTab, OcptEditorRightDockTab.metadata);

    bloc.add(const OcptEditorRightDockToggledEvent());
    final reopenedState = await waitForState(bloc, (state) => state.rightDockTab != null);
    expect(reopenedState.rightDockTab, OcptEditorRightDockTab.metadata);

    await bloc.close();
  });

  test("the toolbar's toggle reopens a dock the dock's own × closed, on the same tab", () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, OcptEditorRightDockTab.preview);

    bloc.add(const OcptEditorRightDockClosedEvent());
    await waitForState(bloc, (state) => state.rightDockTab == null);

    bloc.add(const OcptEditorRightDockToggledEvent());
    final state = await waitForState(bloc, (state) => state.rightDockTab != null);
    expect(state.rightDockTab, OcptEditorRightDockTab.preview);

    await bloc.close();
  });

  test('reopening the right dock in styled mode never lands on the preview tab', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);
    final bloc = buildBloc();
    final loadedState = await waitForState(bloc, (state) => !state.isLoading);

    // Styled mode auto-closed the (default) preview tab on load, and it stays the remembered one.
    expect(loadedState.rightDockTab, isNull);
    expect(loadedState.lastRightDockTab, OcptEditorRightDockTab.preview);

    bloc.add(const OcptEditorRightDockToggledEvent());
    final styledState = await waitForState(bloc, (state) => state.rightDockTab != null);
    expect(styledState.rightDockTab, OcptEditorRightDockTab.syntax);
    // The memory itself is untouched, so the preview comes back once raw mode does.
    expect(styledState.lastRightDockTab, OcptEditorRightDockTab.preview);

    bloc.add(const OcptEditorRightDockToggledEvent());
    await waitForState(bloc, (state) => state.rightDockTab == null);
    bloc.add(const OcptEditorModeToggledEvent());
    await waitForState(bloc, (state) => state.mode == OcptEditorMode.raw);

    bloc.add(const OcptEditorRightDockToggledEvent());
    final rawState = await waitForState(bloc, (state) => state.rightDockTab != null);
    expect(rawState.rightDockTab, OcptEditorRightDockTab.preview);

    await bloc.close();
  });

  test('switching to styled mode with the preview tab active closes the dock and remembers it, '
      'switching back to raw restores it', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, OcptEditorRightDockTab.preview);

    bloc.add(const OcptEditorModeToggledEvent());
    final styledState = await waitForState(bloc, (state) => state.mode == OcptEditorMode.styled);
    expect(styledState.rightDockTab, isNull);
    expect(styledState.autoClosedRightDockTab, OcptEditorRightDockTab.preview);

    bloc.add(const OcptEditorModeToggledEvent());
    final rawState = await waitForState(bloc, (state) => state.mode == OcptEditorMode.raw);
    expect(rawState.rightDockTab, OcptEditorRightDockTab.preview);
    expect(rawState.autoClosedRightDockTab, isNull);

    await bloc.close();
  });

  test('a dock the user closed explicitly stays closed across mode switches', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, OcptEditorRightDockTab.preview);

    // The user explicitly closes the dock by hand.
    bloc.add(const OcptEditorRightDockClosedEvent());
    await waitForState(bloc, (state) => state.rightDockTab == null);

    // Switching to styled and back must never reopen it, and must not remember anything either.
    bloc.add(const OcptEditorModeToggledEvent());
    final styledState = await waitForState(bloc, (state) => state.mode == OcptEditorMode.styled);
    expect(styledState.rightDockTab, isNull);
    expect(styledState.autoClosedRightDockTab, isNull);

    bloc.add(const OcptEditorModeToggledEvent());
    final rawState = await waitForState(bloc, (state) => state.mode == OcptEditorMode.raw);
    expect(rawState.rightDockTab, isNull);
    expect(rawState.autoClosedRightDockTab, isNull);

    await bloc.close();
  });

  test('selecting a tab clears a previously remembered auto-closed tab', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    // Switch to styled to have the active preview tab remembered.
    bloc.add(const OcptEditorModeToggledEvent());
    final styledState = await waitForState(bloc, (state) => state.mode == OcptEditorMode.styled);
    expect(styledState.autoClosedRightDockTab, OcptEditorRightDockTab.preview);

    // Opening the syntax tab (an explicit action, valid in styled mode) must clear the memory.
    bloc.add(const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.syntax));
    final syntaxState = await waitForState(
      bloc,
      (state) => state.rightDockTab == OcptEditorRightDockTab.syntax,
    );
    expect(syntaxState.autoClosedRightDockTab, isNull);

    // So switching to raw no longer force-reopens the preview tab.
    bloc.add(const OcptEditorModeToggledEvent());
    final rawState = await waitForState(bloc, (state) => state.mode == OcptEditorMode.raw);
    expect(rawState.rightDockTab, OcptEditorRightDockTab.syntax);

    await bloc.close();
  });

  test('defaults to styled mode when nothing was ever persisted', () async {
    await propertiesManager.editorMode.delete();

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptEditorMode.styled);

    await bloc.close();
  });

  test('loads the persisted editor mode on entry', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.raw);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.mode, OcptEditorMode.raw);

    await bloc.close();
  });

  test('toggling the mode flips it and persists the new value', () async {
    await propertiesManager.editorMode.store(OcptEditorMode.styled);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorModeToggledEvent());
    final rawState = await waitForState(bloc, (state) => state.mode == OcptEditorMode.raw);
    expect(rawState.mode, OcptEditorMode.raw);
    expect(await propertiesManager.editorMode.load(), OcptEditorMode.raw);

    bloc.add(const OcptEditorModeToggledEvent());
    final styledState = await waitForState(bloc, (state) => state.mode == OcptEditorMode.styled);
    expect(styledState.mode, OcptEditorMode.styled);
    expect(await propertiesManager.editorMode.load(), OcptEditorMode.styled);

    await bloc.close();
  });

  test('defaults to page simulation enabled when nothing was ever persisted', () async {
    await propertiesManager.isPageSimulationEnabled.delete();

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.isPageSimulationEnabled, isTrue);

    await bloc.close();
  });

  test('loads the persisted page simulation flag on entry', () async {
    await propertiesManager.isPageSimulationEnabled.store(false);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.isPageSimulationEnabled, isFalse);

    await bloc.close();
  });

  test('toggling page simulation flips it and persists the new value', () async {
    await propertiesManager.isPageSimulationEnabled.store(true);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorPageSimulationToggledEvent());
    final disabledState = await waitForState(bloc, (state) => !state.isPageSimulationEnabled);
    expect(disabledState.isPageSimulationEnabled, isFalse);
    expect(await propertiesManager.isPageSimulationEnabled.load(), isFalse);

    bloc.add(const OcptEditorPageSimulationToggledEvent());
    final enabledState = await waitForState(bloc, (state) => state.isPageSimulationEnabled);
    expect(enabledState.isPageSimulationEnabled, isTrue);
    expect(await propertiesManager.isPageSimulationEnabled.load(), isTrue);

    await bloc.close();
  });

  test('defaults to styled scene numbers visible when nothing was ever persisted', () async {
    await propertiesManager.styledSceneNumbersVisible.delete();

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.areStyledSceneNumbersVisible, isTrue);

    await bloc.close();
  });

  test('loads the persisted styled scene numbers flag on entry', () async {
    await propertiesManager.styledSceneNumbersVisible.store(false);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.areStyledSceneNumbersVisible, isFalse);

    await bloc.close();
  });

  test('toggling styled scene numbers flips it and persists the new value', () async {
    await propertiesManager.styledSceneNumbersVisible.store(true);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorStyledSceneNumbersToggledEvent());
    final disabledState = await waitForState(bloc, (state) => !state.areStyledSceneNumbersVisible);
    expect(disabledState.areStyledSceneNumbersVisible, isFalse);
    expect(await propertiesManager.styledSceneNumbersVisible.load(), isFalse);

    bloc.add(const OcptEditorStyledSceneNumbersToggledEvent());
    final enabledState = await waitForState(bloc, (state) => state.areStyledSceneNumbersVisible);
    expect(enabledState.areStyledSceneNumbersVisible, isTrue);
    expect(await propertiesManager.styledSceneNumbersVisible.load(), isTrue);

    await bloc.close();
  });

  test('defaults to the dock fractions defaults when nothing was ever persisted', () async {
    await propertiesManager.editorLeftDockFraction.delete();
    await propertiesManager.editorRightDockFraction.delete();

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.leftDockFraction, OcptWorkspaceDock.leftDefaultFraction);
    expect(state.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);

    await bloc.close();
  });
}
