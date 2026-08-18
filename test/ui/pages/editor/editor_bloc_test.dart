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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_imported_fountain_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_pdf_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A screenplay service whose saves always fail, to exercise the bloc's save error path. Loads
/// still go through the real implementation.
class _FailingScreenplayService extends OcptScreenplayService {
  /// Class constructor
  const _FailingScreenplayService()
    : super(
        sceneIndexService: const OcptSceneIndexService(),
        shotListService: const OcptShotListService(),
        shotCoverageService: const OcptShotCoverageService(),
        roleIndexService: const OcptRoleIndexService(),
        breakdownService: const OcptBreakdownService(
          elementsService: OcptElementsService(),
          locationsService: OcptLocationsService(),
        ),
        scheduleService: const OcptScheduleService(),
      );

  /// {@macro open_cine_prod_tools.OcptScreenplayService.snapshotPolicy}
  @override
  Future<void> saveScreenplayText({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String fountainText,
    required OcptSnapshotReason snapshotReason,
  }) async => throw StateError("save intentionally failed for the test");
}

/// A projects manager that counts how many times a working-copy capture actually reads the whole
/// project, so a dispatch that only *requests* one (rather than always performing it) can be told
/// apart from one that the throttle skipped.
class _CountingProjectsManager extends OcptProjectsManager {
  /// Class constructor
  _CountingProjectsManager({required OcptPropertiesManager propertiesManager})
    : super(propertiesManager: propertiesManager);

  /// How many times [captureWorkingCopyState] actually ran.
  int captureCount = 0;

  @override
  Future<OcptProjectWorkingCopyState?> captureWorkingCopyState() async {
    captureCount++;
    return super.captureWorkingCopyState();
  }
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
    : super(fileSelectorManager: const FileSelectorManager());

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

  /// The file type label of the last [exportFountain] call.
  String? lastExportedFileTypeLabel;

  /// The episode tag of the last [exportFountain] call.
  String? lastExportedEpisodeTag;

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

  /// The file type label of the last [exportPdf] call.
  String? lastExportedPdfFileTypeLabel;

  /// The episode tag of the last [exportPdf] call.
  String? lastExportedPdfEpisodeTag;

  @override
  Future<String?> exportFountain({
    required String fountainText,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
  }) async {
    lastExportedText = fountainText;
    lastExportedProjectName = projectName;
    lastExportedFileTypeLabel = fileTypeLabel;
    lastExportedEpisodeTag = episodeTag;
    return exportResult;
  }

  @override
  Future<String?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
    String? episodeTag,
  }) async {
    lastExportedPdfDocument = document;
    lastExportedPdfPageSetup = pageSetup;
    lastExportedPdfProjectName = projectName;
    lastExportedPdfIncludeSceneNumbers = includeSceneNumbers;
    lastExportedPdfIncludeTitlePage = includeTitlePage;
    lastExportedPdfFileTypeLabel = fileTypeLabel;
    lastExportedPdfEpisodeTag = episodeTag;
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
  _ThrowingPdfExportManager() : super(fileSelectorManager: const FileSelectorManager());

  @override
  Future<String?> exportPdf({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required String fileTypeLabel,
    String? episodeTag,
  }) async => throw StateError("PDF export intentionally failed for the test");
}

void main() {
  const editedText = "INT. HOUSE - DAY\n\nAction.\n";
  // Scene headings start at line 0 and line 4; the two scenes are deliberately given different
  // word counts (6 and 7) so a test can tell "the first scene's stats" and "the second scene's
  // stats" apart just by comparing counts.
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two here.\n";

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
  /// touches a real file dialog. [overrideProjectsManager] lets a test swap in a manager of its
  /// own (already holding an open project), for the one that needs to observe its calls.
  OcptEditorBloc buildBloc({
    OcptScreenplayService? screenplayService,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptProjectsManager? overrideProjectsManager,
    String? selectedEpisodeId,
  }) => OcptEditorBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    screenplayService: screenplayService,
    exportManager: exportManager ?? _FakeExportManager(),
    parseDebounce: const Duration(milliseconds: 20),
    autosaveDebounce: const Duration(milliseconds: 60),
    statisticsDebounce: const Duration(milliseconds: 30),
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
    expect(state.statistics, FountainScriptStatistics.empty);

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

  test('sceneStatistics is recomputed on the parse debounce, for the scene under the caret',
      () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.sceneStatistics, isNull);

    bloc.add(const OcptEditorTextChangedEvent(text: twoSceneText));
    // The document already reflects the edit once this resolves, but that alone must not have
    // populated the scene statistics synchronously (they piggyback on the same parse tick, not a
    // separate, earlier one).
    final parsedState = await waitForState(bloc, (state) => state.scenes.length == 2);
    expect(parsedState.sceneStatistics, isNotNull);
    expect(parsedState.sceneStatistics!.wordCount, greaterThan(0));

    await bloc.close();
  });

  test(
    'sceneStatistics is recomputed immediately when the caret crosses into a different scene',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: twoSceneText));
      await waitForState(bloc, (state) => state.scenes.length == 2);
      final firstSceneWords = bloc.state.sceneStatistics!.wordCount;

      bloc.add(const OcptEditorCaretMovedEvent(line: 6));
      final secondSceneState = await waitForState(
        bloc,
        (state) => state.currentSceneIndex == 1 && state.sceneStatistics!.wordCount != firstSceneWords,
      );
      // "EXT. GARDEN - NIGHT" (4) + "Action two here." (3).
      expect(secondSceneState.sceneStatistics!.wordCount, 4 + 3);

      await bloc.close();
    },
  );

  test('sceneStatistics goes back to null once the caret moves back before every scene', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorTextChangedEvent(text: "\n\n$twoSceneText"));
    await waitForState(bloc, (state) => state.scenes.length == 2);
    // The caret (still on line 0) precedes the first heading, now pushed to line 2.
    expect(bloc.state.sceneStatistics, isNull);

    bloc.add(const OcptEditorCaretMovedEvent(line: 2));
    final withinFirstScene = await waitForState(bloc, (state) => state.sceneStatistics != null);
    expect(withinFirstScene.currentSceneIndex, 0);

    bloc.add(const OcptEditorCaretMovedEvent(line: 0));
    final beforeEveryScene = await waitForState(bloc, (state) => state.sceneStatistics == null);
    expect(beforeEveryScene.currentSceneIndex, isNull);

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
    expect(leftState.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);
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
      (state) => state.leftDockFraction == OcptWorkspaceDock.leftDefaultFraction,
    );

    expect(state.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);
    expect(await propertiesManager.editorLeftDockFraction.load(), OcptWorkspaceDock.leftDefaultFraction);
    expect(await propertiesManager.editorRightDockFraction.load(), OcptWorkspaceDock.rightDefaultFraction);

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

  test(
    'the project settings changed event re-reads the page format and repaginates',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      final otherFormat = bloc.state.pageSetup.format == OcptPageFormat.usLetter
          ? OcptPageFormat.a4
          : OcptPageFormat.usLetter;
      // Written directly through the manager, the way the project settings page itself writes it
      // — this bloc never sees the new value on an event, only the fact that something changed.
      await projectsManager.saveCurrentProjectPageFormat(otherFormat);

      bloc.add(const OcptEditorProjectSettingsChangedEvent());
      final state = await waitForState(bloc, (state) => state.pageSetup.format == otherFormat);

      expect(
        state.statistics,
        FountainScriptStatistics.of(state.document!, state.pageSetup.toMetrics()),
      );

      await bloc.close();
    },
  );

  test('the project settings changed event is a no-op when the format did not change', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final setupBefore = bloc.state.pageSetup;

    bloc.add(const OcptEditorProjectSettingsChangedEvent());
    // Nothing to wait for: assert the very next state (if any) still matches, after giving the
    // handler's async work a chance to run.
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.pageSetup, setupBefore);

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

      bloc.add(
        const OcptEditorExportRequestedEvent(
          fileTypeLabel: "Fountain screenplay",
          episodeTag: "ep. 2",
        ),
      );
      final state = await waitForState(
        bloc,
        (state) => state.ioNotice?.kind == OcptEditorIoNoticeKind.exportSucceeded,
      );

      expect(state.isDirty, isFalse);
      expect(state.ioNotice?.path, "/tmp/My Movie.fountain");
      expect(exportManager.lastExportedText, editedText);
      expect(exportManager.lastExportedProjectName, "My Movie");
      expect(exportManager.lastExportedFileTypeLabel, "Fountain screenplay");
      expect(exportManager.lastExportedEpisodeTag, "ep. 2");

      final snapshots = await readSnapshots();
      expect(snapshots.last.reason, OcptSnapshotReason.export);

      await bloc.close();
    },
  );

  test('a cancelled export dialog raises no notice', () async {
    final exportManager = _FakeExportManager();
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptEditorExportRequestedEvent(fileTypeLabel: "Fountain screenplay"));
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
      bloc.add(
        const OcptEditorExportPdfRequestedEvent(
          options: options,
          fileTypeLabel: "PDF document",
          episodeTag: "ep. 2",
        ),
      );
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
      expect(exportManager.lastExportedPdfFileTypeLabel, "PDF document");
      expect(exportManager.lastExportedPdfEpisodeTag, "ep. 2");

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
        fileTypeLabel: "PDF document",
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
        fileTypeLabel: "PDF document",
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

  group('find/replace', () {
    test('OcptEditorState.init starts with the bar closed and no search', () {
      const state = OcptEditorState.init();

      expect(state.search.isOpen, isFalse);
      expect(state.search.isReplaceRowOpen, isFalse);
      expect(state.search.query, "");
      expect(state.search.matchCount, 0);
      expect(state.search.currentMatchIndex, isNull);
    });

    test('Ctrl+F opens the bar with the replace row folded and bumps the focus request id',
        () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final focusRequestIdBefore = bloc.state.search.focusRequestId;

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      final state = await waitForState(bloc, (state) => state.search.isOpen);

      expect(state.search.isReplaceRowOpen, isFalse);
      expect(state.search.focusRequestId, greaterThan(focusRequestIdBefore));

      await bloc.close();
    });

    test('Ctrl+H opens the bar with the replace row unfolded', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: true));
      final state = await waitForState(bloc, (state) => state.search.isOpen);

      expect(state.search.isReplaceRowOpen, isTrue);

      await bloc.close();
    });

    test('opening an already-open, replace-unfolded bar with Ctrl+F never folds the row back',
        () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: true));
      await waitForState(bloc, (state) => state.search.isReplaceRowOpen);
      final focusRequestIdBefore = bloc.state.search.focusRequestId;

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      final state = await waitForState(
        bloc,
        (state) => state.search.focusRequestId > focusRequestIdBefore,
      );

      expect(state.search.isReplaceRowOpen, isTrue);

      await bloc.close();
    });

    test('the chevron folds and unfolds the replace row', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchReplaceRowToggledEvent());
      final openState = await waitForState(bloc, (state) => state.search.isReplaceRowOpen);
      expect(openState.search.isReplaceRowOpen, isTrue);

      bloc.add(const OcptEditorSearchReplaceRowToggledEvent());
      final closedState = await waitForState(
        bloc,
        (state) => !state.search.isReplaceRowOpen,
      );
      expect(closedState.search.isReplaceRowOpen, isFalse);

      await bloc.close();
    });

    test('closing the bar clears the highlight but keeps the query, the replacement and both '
        'options, so reopening comes back to the same search', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: true));
      bloc.add(const OcptEditorSearchQueryChangedEvent(query: "MARIE"));
      bloc.add(const OcptEditorSearchReplacementChangedEvent(replacement: "JEANNE"));
      bloc.add(const OcptEditorSearchCaseSensitivityToggledEvent());
      bloc.add(const OcptEditorSearchWholeWordToggledEvent());
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 3));
      await waitForState(bloc, (state) => state.search.matchCount == 3);

      bloc.add(const OcptEditorSearchClosedEvent());
      final closedState = await waitForState(bloc, (state) => !state.search.isOpen);

      expect(closedState.search.matchCount, 0);
      expect(closedState.search.currentMatchIndex, isNull);
      expect(closedState.search.query, "MARIE");
      expect(closedState.search.replacement, "JEANNE");
      expect(closedState.search.isCaseSensitive, isTrue);
      expect(closedState.search.isWholeWord, isTrue);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      final reopenedState = await waitForState(bloc, (state) => state.search.isOpen);

      expect(reopenedState.search.query, "MARIE");
      expect(reopenedState.search.replacement, "JEANNE");
      expect(reopenedState.search.isCaseSensitive, isTrue);
      expect(reopenedState.search.isWholeWord, isTrue);

      await bloc.close();
    });

    test('a query change resets the current match index to 0', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 5));
      await waitForState(bloc, (state) => state.search.matchCount == 5);
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      await waitForState(bloc, (state) => state.search.currentMatchIndex == 1);

      bloc.add(const OcptEditorSearchQueryChangedEvent(query: "MARIE"));
      final state = await waitForState(bloc, (state) => state.search.query == "MARIE");

      expect(state.search.currentMatchIndex, 0);

      await bloc.close();
    });

    test('reporting zero matches clears the current match index back to null', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 2));
      await waitForState(bloc, (state) => state.search.matchCount == 2);

      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 0));
      final state = await waitForState(bloc, (state) => state.search.matchCount == 0);

      expect(state.search.currentMatchIndex, isNull);

      await bloc.close();
    });

    test('the current match index clamps down when a reported count shrinks', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 5));
      await waitForState(bloc, (state) => state.search.matchCount == 5);
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      final lastIndexState = await waitForState(bloc, (state) => state.search.currentMatchIndex == 4);
      expect(lastIndexState.search.currentMatchIndex, 4);

      // The count shrinks to 2 (indices 0 and 1 only): the current index clamps down into range
      // rather than pointing past the end of the new, shorter match list.
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 2));
      final clampedState = await waitForState(bloc, (state) => state.search.matchCount == 2);

      expect(clampedState.search.currentMatchIndex, 1);

      await bloc.close();
    });

    test('next/previous wrap around in both directions', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 3));
      final firstState = await waitForState(bloc, (state) => state.search.matchCount == 3);
      expect(firstState.search.currentMatchIndex, 0);

      bloc.add(const OcptEditorSearchPreviousRequestedEvent());
      final wrappedBackState = await waitForState(
        bloc,
        (state) => state.search.currentMatchIndex == 2,
      );
      expect(wrappedBackState.search.currentMatchIndex, 2);

      bloc.add(const OcptEditorSearchNextRequestedEvent());
      final nextState = await waitForState(
        bloc,
        (state) => state.search.currentMatchIndex == 0,
      );
      expect(nextState.search.currentMatchIndex, 0);

      bloc.add(const OcptEditorSearchNextRequestedEvent());
      await waitForState(bloc, (state) => state.search.currentMatchIndex == 1);

      bloc.add(const OcptEditorSearchNextRequestedEvent());
      await waitForState(bloc, (state) => state.search.currentMatchIndex == 2);

      // One more step past the last index wraps back to the first.
      bloc.add(const OcptEditorSearchNextRequestedEvent());
      final wrappedToStartState = await waitForState(
        bloc,
        (state) => state.search.currentMatchIndex == 0,
      );
      expect(wrappedToStartState.search.currentMatchIndex, 0);

      await bloc.close();
    });

    test('next/previous are a no-op while there is no match', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
      await waitForState(bloc, (state) => state.search.isOpen);

      bloc.add(const OcptEditorSearchNextRequestedEvent());
      // No state change to wait for: give the handler a beat to run, then assert nothing moved.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.search.currentMatchIndex, isNull);

      await bloc.close();
    });

    test('the case-sensitivity and whole-word toggles flip their own flag only', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSearchCaseSensitivityToggledEvent());
      final caseState = await waitForState(bloc, (state) => state.search.isCaseSensitive);
      expect(caseState.search.isWholeWord, isFalse);

      bloc.add(const OcptEditorSearchWholeWordToggledEvent());
      final wholeWordState = await waitForState(bloc, (state) => state.search.isWholeWord);
      expect(wholeWordState.search.isCaseSensitive, isTrue);

      await bloc.close();
    });

    test(
      'a current-match-selected event sets the index directly, not relative to the previous one',
      () async {
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);

        bloc.add(const OcptEditorSearchOpenedEvent(withReplaceRow: false));
        bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 5));
        await waitForState(bloc, (state) => state.search.matchCount == 5);

        // Sets the index straight to 3, with no relationship to the current one (0): the event
        // exists precisely because the mounted surface, not the bloc, knows which match a replace
        // just landed on.
        bloc.add(const OcptEditorSearchCurrentMatchSelectedEvent(index: 3));
        final state = await waitForState(bloc, (state) => state.search.currentMatchIndex == 3);

        expect(state.search.currentMatchIndex, 3);

        // The report that follows a replace (a fresh match count) still clamps it, exactly as
        // any other match count report does.
        bloc.add(const OcptEditorSearchMatchesReportedEvent(matchCount: 2));
        final clampedState = await waitForState(bloc, (state) => state.search.matchCount == 2);
        expect(clampedState.search.currentMatchIndex, 1);

        await bloc.close();
      },
    );
  });
}
