// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_pdf_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A screenplay service whose saves always fail, to exercise the bloc's save error path. Loads
/// still go through the real implementation.
class _FailingScreenplayService extends OcptScreenplayService {
  /// Class constructor
  const _FailingScreenplayService() : super(sceneIndexService: const OcptSceneIndexService());

  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  @override
  Future<void> saveScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason snapshotReason,
  }) async => throw StateError("save intentionally failed for the test");
}

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
///
/// [onPop] lets a test await the exact moment [pop] is called, rather than racing on an unrelated
/// state emitted earlier in the same event handler (the emitted state and the handler's own
/// completion are not ordered with respect to a stream listener in the test).
class _RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

  /// Whether [pop] was called.
  bool get popped => _popCompleter.isCompleted;

  /// Completes the moment [pop] is called.
  Future<void> get onPop => _popCompleter.future;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete();
    }
  }
}

/// An export manager whose export/import calls are recorded and stubbed, to exercise the bloc's
/// export and import-and-replace paths without any real file dialog.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({this.exportResult, this.importResult, this.exportPdfResult})
    : super(
        fileSaverManager: const FileSaverManager(),
        fileSelectorManager: const FileSelectorManager(),
      );

  /// The path [exportFountain] returns, or null to simulate a cancelled save dialog.
  final String? exportResult;

  /// The model [pickAndReadFountain] returns, or null to simulate a cancelled open dialog.
  final OcptImportedFountainModel? importResult;

  /// The path [exportPdf] returns, or null to simulate a cancelled save dialog.
  final String? exportPdfResult;

  /// The text of the last [exportFountain] call.
  String? lastExportedText;

  /// The project name of the last [exportFountain] call.
  String? lastExportedProjectName;

  /// The file type label of the last [pickAndReadFountain] call.
  String? lastImportFileTypeLabel;

  /// The document of the last [exportPdf] call.
  FountainDocument? lastExportedPdfDocument;

  /// The page setup of the last [exportPdf] call.
  OcptPageSetup? lastExportedPdfPageSetup;

  /// The project name of the last [exportPdf] call.
  String? lastExportedPdfProjectName;

  /// The "include scene numbers" flag of the last [exportPdf] call.
  bool? lastExportedPdfIncludeSceneNumbers;

  /// The "include title page" flag of the last [exportPdf] call.
  bool? lastExportedPdfIncludeTitlePage;

  @override
  Future<String?> exportFountain({
    required String fountainText,
    required String projectName,
  }) async {
    lastExportedText = fountainText;
    lastExportedProjectName = projectName;
    return exportResult;
  }

  @override
  Future<String?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
  }) async {
    lastExportedPdfDocument = document;
    lastExportedPdfPageSetup = pageSetup;
    lastExportedPdfProjectName = projectName;
    lastExportedPdfIncludeSceneNumbers = includeSceneNumbers;
    lastExportedPdfIncludeTitlePage = includeTitlePage;
    return exportPdfResult;
  }

  @override
  Future<OcptImportedFountainModel?> pickAndReadFountain({required String fileTypeLabel}) async {
    lastImportFileTypeLabel = fileTypeLabel;
    return importResult;
  }
}

/// An export manager whose [exportPdf] always throws, to exercise the bloc's PDF export failure
/// path.
class _ThrowingPdfExportManager extends OcptExportManager {
  /// Class constructor
  _ThrowingPdfExportManager()
    : super(
        fileSaverManager: const FileSaverManager(),
        fileSelectorManager: const FileSelectorManager(),
      );

  @override
  Future<String?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
  }) async => throw StateError("PDF export intentionally failed for the test");
}

void main() {
  const editedText = "INT. HOUSE - DAY\n\nAction.\n";

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
    projectsManager = OcptProjectsManager(propertiesManager: propertiesManager);
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
  /// [exportManager] defaults to a [_FakeExportManager] whose export/import calls both cancel
  /// (return null): every test not exercising the export/import paths gets a bloc that never
  /// touches a real file dialog.
  OcptEditorBloc buildBloc({
    OcptScreenplayService? screenplayService,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
  }) => OcptEditorBloc(
    projectsManager: projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    screenplayService: screenplayService,
    exportManager: exportManager ?? _FakeExportManager(),
    parseDebounce: const Duration(milliseconds: 20),
    autosaveDebounce: const Duration(milliseconds: 60),
    statisticsDebounce: const Duration(milliseconds: 30),
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
    expect(state.statistics, FountainScriptStatistics.empty);

    await bloc.close();
  });

  test('statistics are populated from the screenplay already on disk once the load completes',
      () async {
    final project = projectsManager.currentProject!;
    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: editedText,
      snapshotReason: OcptSnapshotReason.manual,
    );

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.statistics.sceneCount, 1);
    expect(state.statistics.pageCount, 1);
    expect(state.statistics.wordCount, greaterThan(0));

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

  test('statistics recompute, on their own debounce, once the parsed document changes', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.statistics, FountainScriptStatistics.empty);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.scenes.isNotEmpty);
    // The document already reflects the edit, but the statistics debounce hasn't elapsed yet.
    expect(bloc.state.statistics, FountainScriptStatistics.empty);

    final state = await waitForState(bloc, (state) => state.statistics.sceneCount == 1);
    expect(state.statistics.pageCount, 1);
    expect(state.statistics.wordCount, greaterThan(0));

    await bloc.close();
  });

  test('autosaves after the debounce, clearing the dirty flag and tagging the snapshot "timer"',
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
  });

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
    final bloc = buildBloc(screenplayService: const _FailingScreenplayService());
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

  test(
    'loading the editor in styled mode closes the preview tab and remembers it, exactly like a '
    'live mode switch would',
    () async {
      await propertiesManager.editorMode.store(OcptEditorMode.styled);

      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.mode, OcptEditorMode.styled);
      expect(state.rightDockTab, isNull);
      expect(state.autoClosedRightDockTab, OcptEditorRightDockTab.preview);

      await bloc.close();
    },
  );

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
    final styledState = await waitForState(
      bloc,
      (state) => state.mode == OcptEditorMode.styled,
    );
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

  test('defaults to the dock fractions defaults when nothing was ever persisted', () async {
    await propertiesManager.editorLeftDockFraction.delete();
    await propertiesManager.editorRightDockFraction.delete();

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.leftDockFraction, OcptEditorDock.leftDefaultFraction);
    expect(state.rightDockFraction, OcptEditorDock.rightDefaultFraction);

    await bloc.close();
  });

  test('loads the persisted dock fractions on entry', () async {
    await propertiesManager.editorLeftDockFraction.store(0.25);
    await propertiesManager.editorRightDockFraction.store(0.55);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.leftDockFraction, 0.25);
    expect(state.rightDockFraction, 0.55);

    await bloc.close();
  });

  test('a dock fractions changed event persists whichever side is given', () async {
    await propertiesManager.editorLeftDockFraction.delete();
    await propertiesManager.editorRightDockFraction.delete();

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorDockFractionsChangedEvent(left: 0.3));
    final leftState = await waitForState(bloc, (state) => state.leftDockFraction == 0.3);
    expect(leftState.rightDockFraction, OcptEditorDock.rightDefaultFraction);
    expect(await propertiesManager.editorLeftDockFraction.load(), 0.3);
    expect(await propertiesManager.editorRightDockFraction.load(), isNull);

    bloc.add(const OcptEditorDockFractionsChangedEvent(right: 0.6));
    final rightState = await waitForState(bloc, (state) => state.rightDockFraction == 0.6);
    expect(rightState.leftDockFraction, 0.3);
    expect(await propertiesManager.editorRightDockFraction.load(), 0.6);

    await bloc.close();
  });

  test('the dock layout reset event restores and persists both defaults', () async {
    await propertiesManager.editorLeftDockFraction.store(0.3);
    await propertiesManager.editorRightDockFraction.store(0.6);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorDockLayoutResetEvent());
    final state = await waitForState(
      bloc,
      (state) => state.leftDockFraction == OcptEditorDock.leftDefaultFraction,
    );

    expect(state.rightDockFraction, OcptEditorDock.rightDefaultFraction);
    expect(await propertiesManager.editorLeftDockFraction.load(), OcptEditorDock.leftDefaultFraction);
    expect(await propertiesManager.editorRightDockFraction.load(), OcptEditorDock.rightDefaultFraction);

    await bloc.close();
  });

  test('changing the page setup applies it live and persists format and margins', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    const newSetup = OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 2,
        rightInches: 0.5,
        topInches: 0.75,
        bottomInches: 0.75,
      ),
    );
    bloc.add(const OcptEditorPageSetupChangedEvent(pageSetup: newSetup));

    final state = await waitForState(bloc, (state) => state.pageSetup == newSetup);
    expect(state.pageSetup, newSetup);
    expect(await projectsManager.loadCurrentProjectPageFormat(), OcptPageFormat.a4);
    expect(await propertiesManager.pageMargins.load(), newSetup.margins);

    await bloc.close();
  });

  test('changing the page setup recomputes statistics for the new format immediately', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.statistics.sceneCount == 1);

    const newSetup = OcptPageSetup(
      format: OcptPageFormat.a4,
      margins: FountainPageMargins(
        leftInches: 2,
        rightInches: 0.5,
        topInches: 0.75,
        bottomInches: 0.75,
      ),
    );
    bloc.add(const OcptEditorPageSetupChangedEvent(pageSetup: newSetup));

    final state = await waitForState(bloc, (state) => state.pageSetup == newSetup);
    expect(state.statistics, FountainScriptStatistics.of(state.document!, newSetup.toMetrics()));

    await bloc.close();
  });

  test('closing the bloc flushes the pending unsaved change', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    // Close well before the autosave debounce (60 ms) elapses: the close itself must save.
    await bloc.close();

    final project = projectsManager.currentProject!;
    final storedText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    expect(storedText, editedText);
  });

  test('going back flushes the pending change, closes the project and pops the router', () async {
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(routerManager: routerManager);
    await waitForState(bloc, (state) => !state.isLoading);

    final projectPath = projectsManager.currentProject!.path;
    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    // Go back well before the autosave debounce (60 ms) elapses: the back itself must save.
    bloc.add(const OcptEditorBackRequestedEvent());
    await routerManager.onPop.timeout(const Duration(seconds: 5));

    expect(routerManager.popped, isTrue);
    expect(projectsManager.currentProject, isNull);

    // The close-flush must now be a no-op: the project is already closed, and closing the bloc
    // must not try to save through the closed database.
    await bloc.close();

    // Reopen the project file to check the pending change was flushed before it was closed.
    final reopened = await projectsManager.openProject(filePath: projectPath);
    expect(reopened.status.isSuccess, isTrue);

    final project = projectsManager.currentProject!;
    final storedText = await projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    expect(storedText, editedText);
  });

  test(
    'exporting a dirty screenplay saves it with the "export" reason and hands the current text '
    'to the manager',
    () async {
      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie.fountain");
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      await waitForState(bloc, (state) => state.isDirty);

      bloc.add(const OcptEditorExportRequestedEvent());
      final state = await waitForState(
        bloc,
        (state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.exportSucceeded,
      );

      expect(state.isDirty, isFalse);
      expect(state.ioNotice?.path, "/tmp/My Movie.fountain");
      expect(exportManager.lastExportedText, editedText);
      expect(exportManager.lastExportedProjectName, "My Movie");

      final snapshots = await readSnapshots();
      expect(snapshots.last.reason, OcptSnapshotReason.export);

      await bloc.close();
    },
  );

  test('a cancelled export dialog raises no notice', () async {
    final exportManager = _FakeExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorExportRequestedEvent());
    // No state change to wait for on a cancelled dialog: give the handler a beat to run.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test(
    'exporting a dirty screenplay to PDF saves it with the "export" reason and hands the '
    'manager a document parsed from the current text, the project name, and the pageSetup built '
    'from the event options',
    () async {
      final exportManager = _FakeExportManager(exportPdfResult: "/tmp/My Movie.pdf");
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      final formatBefore = await projectsManager.loadCurrentProjectPageFormat();
      final marginsBefore = await propertiesManager.pageMargins.load();

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      await waitForState(bloc, (state) => state.isDirty);

      // A format/margins deliberately different from `bloc.state.pageSetup`, to prove they're
      // taken from the event's options rather than the live state.
      const options = OcptPdfExportOptions(
        format: OcptPageFormat.a4,
        margins: FountainPageMargins(
          leftInches: 2,
          rightInches: 0.5,
          topInches: 0.75,
          bottomInches: 0.75,
        ),
        includeSceneNumbers: false,
        includeTitlePage: false,
      );
      bloc.add(const OcptEditorExportPdfRequestedEvent(options: options));
      final state = await waitForState(
        bloc,
        (state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.pdfExportSucceeded,
      );

      expect(state.isDirty, isFalse);
      expect(state.ioNotice?.path, "/tmp/My Movie.pdf");
      expect(exportManager.lastExportedPdfProjectName, "My Movie");
      expect(exportManager.lastExportedPdfDocument?.scenes.single.headingText, "INT. HOUSE - DAY");
      expect(
        exportManager.lastExportedPdfPageSetup,
        OcptPageSetup(format: options.format, margins: options.margins),
      );
      expect(exportManager.lastExportedPdfIncludeSceneNumbers, isFalse);
      expect(exportManager.lastExportedPdfIncludeTitlePage, isFalse);

      final snapshots = await readSnapshots();
      expect(snapshots.last.reason, OcptSnapshotReason.export);

      // The PDF export's format/options choice is a one-off, export-time setting: it must never
      // persist the project's page format or the app-wide margins.
      expect(await projectsManager.loadCurrentProjectPageFormat(), formatBefore);
      expect(await propertiesManager.pageMargins.load(), marginsBefore);

      await bloc.close();
    },
  );

  test('a cancelled PDF export dialog raises no notice', () async {
    final exportManager = _FakeExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptEditorExportPdfRequestedEvent(
        options: OcptPdfExportOptions(
          format: OcptPageFormat.usLetter,
          margins: FountainPageMargins.standard(),
          includeSceneNumbers: true,
          includeTitlePage: true,
        ),
      ),
    );
    // No state change to wait for on a cancelled dialog: give the handler a beat to run.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('a failed PDF export raises the transient PDF export error', () async {
    final exportManager = _ThrowingPdfExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptEditorExportPdfRequestedEvent(
        options: OcptPdfExportOptions(
          format: OcptPageFormat.usLetter,
          margins: FountainPageMargins.standard(),
          includeSceneNumbers: true,
          includeTitlePage: true,
        ),
      ),
    );
    final failedState = await waitForState(
      bloc,
      (state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.pdfExportFailed,
    );
    expect(failedState.ioNotice?.path, isNull);

    await bloc.close();
  });

  test(
    'importing replaces the text, tags the snapshot "import", leaves isDirty false and '
    're-parses',
    () async {
      const importedText = "INT. OFFICE - DAY\n\nA new script.\n";
      final exportManager = _FakeExportManager(
        importResult: const OcptImportedFountainModel(
          fountainText: importedText,
          sourceFileName: "draft.fountain",
        ),
      );
      final bloc = buildBloc(exportManager: exportManager);
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Fountain screenplay"));
      // The text/dirty/notice change, the re-parse and the statistics recompute are three
      // separate emissions (the notice arrives with the first one and survives into the next
      // two, since re-parsing only replaces `document`): wait for the statistics recompute, the
      // last of the three, to also have landed before asserting on `scenes`/`statistics`.
      final state = await waitForState(bloc, (state) => state.statistics.sceneCount != 0);

      expect(state.text, importedText);
      expect(state.isDirty, isFalse);
      expect(state.currentLine, 0);
      expect(state.ioNotice?.kind, OcptEditorIoNoticeKind.importSucceeded);
      expect(state.scenes, hasLength(1));
      expect(state.scenes.single.headingText, "INT. OFFICE - DAY");
      expect(exportManager.lastImportFileTypeLabel, "Fountain screenplay");
      expect(state.statistics.sceneCount, 1);
      expect(state.statistics.pageCount, 1);

      final snapshots = await readSnapshots();
      expect(snapshots.last.reason, OcptSnapshotReason.import);

      await bloc.close();
    },
  );

  test('a cancelled import dialog changes nothing', () async {
    final exportManager = _FakeExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: editedText));
    await waitForState(bloc, (state) => state.isDirty);

    bloc.add(const OcptEditorImportRequestedEvent(fileTypeLabel: "Fountain screenplay"));
    // No state change to wait for on a cancelled dialog: give the handler a beat to run.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.text, editedText);
    expect(bloc.state.isDirty, isTrue);
    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test(
    'adding title page fields to a screenplay with none inserts one, saves it "manual", and '
    're-parses',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      await waitForState(bloc, (state) => state.scenes.isNotEmpty);

      bloc.add(
        const OcptEditorTitlePageChangedEvent(
          title: 'My Screenplay',
          credit: 'written by',
          author: 'Jane Doe',
          draftDate: '',
          contact: '',
          source: '',
        ),
      );

      final state = await waitForState(bloc, (state) => state.document?.titlePage != null);
      expect(state.document!.titlePage!.title, 'My Screenplay');
      expect(state.document!.titlePage!.credit, 'written by');
      expect(state.document!.titlePage!.authors, ['Jane Doe']);
      expect(
        state.text,
        'Title: My Screenplay\nCredit: written by\nAuthor: Jane Doe\n\n$editedText',
      );
      expect(state.scenes.single.headingText, 'INT. HOUSE - DAY');

      final project = projectsManager.currentProject!;
      final storedText = await projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );
      expect(storedText, state.text);

      final snapshots = await readSnapshots();
      expect(snapshots.last.reason, OcptSnapshotReason.manual);

      await bloc.close();
    },
  );

  test("editing an existing title page's fields replaces it, leaving the body unchanged", () async {
    const initialText = 'Title: Old\nCredit: written by\n\n$editedText';

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: initialText));
    await waitForState(bloc, (state) => state.document?.titlePage != null);

    bloc.add(
      const OcptEditorTitlePageChangedEvent(
        title: 'New Title',
        credit: 'written by',
        author: '',
        draftDate: '',
        contact: '',
        source: '',
      ),
    );

    final state = await waitForState(
      bloc,
      (state) => state.document?.titlePage?.title == 'New Title',
    );
    expect(state.text, 'Title: New Title\nCredit: written by\n\n$editedText');
    expect(state.scenes.single.headingText, 'INT. HOUSE - DAY');

    await bloc.close();
  });

  test(
    'clearing every field on a screenplay with a title page removes it, leaving only the body',
    () async {
      const initialText = 'Title: Old\n\n$editedText';

      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: initialText));
      await waitForState(bloc, (state) => state.document?.titlePage != null);

      bloc.add(
        const OcptEditorTitlePageChangedEvent(
          title: '',
          credit: '',
          author: '',
          draftDate: '',
          contact: '',
          source: '',
        ),
      );

      final state = await waitForState(bloc, (state) => state.document?.titlePage == null);
      expect(state.text, editedText);
      expect(state.scenes.single.headingText, 'INT. HOUSE - DAY');

      await bloc.close();
    },
  );
}
