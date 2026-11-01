// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_scene_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_reload_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_reload_scope.dart';
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

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String _testAppLanguageCode() => "en";

/// The fixed device id every stamping service built in this file uses.
Future<String> _testDeviceId() async => "test-device";

/// A screenplay service whose saves always fail, to exercise the bloc's save error path. Loads
/// still go through the real implementation.
class _FailingScreenplayService extends OcptScreenplayService {
  /// Class constructor
  const _FailingScreenplayService()
    : super(
        logger: const SilentLogger(),
        sceneIndexService: const OcptSceneIndexService(logger: SilentLogger()),
        shotListService: const OcptShotListService(
          logger: SilentLogger(),
          roleIndexService: OcptRoleIndexService(
            logger: SilentLogger(),
            elementsService: OcptElementsService(
              logger: SilentLogger(),
              assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
              deviceId: _testDeviceId,
            ),
            roleCandidatesService: OcptRoleCandidatesService(
              logger: SilentLogger(),
              deviceId: _testDeviceId,
            ),
            deviceId: _testDeviceId,
          ),
          storyboardService: OcptStoryboardService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          floorPlanService: OcptFloorPlanService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          deviceId: _testDeviceId,
        ),
        shotCoverageService: const OcptShotCoverageService(
          logger: SilentLogger(),
          deviceId: _testDeviceId,
        ),
        roleIndexService: const OcptRoleIndexService(
          logger: SilentLogger(),
          elementsService: OcptElementsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          roleCandidatesService: OcptRoleCandidatesService(
            logger: SilentLogger(),
            deviceId: _testDeviceId,
          ),
          deviceId: _testDeviceId,
        ),
        breakdownService: const OcptBreakdownService(
          logger: SilentLogger(),
          elementsService: OcptElementsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          locationsService: OcptLocationsService(
            logger: SilentLogger(),
            assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
            floorPlanService: OcptFloorPlanService(
              logger: SilentLogger(),
              assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
              deviceId: _testDeviceId,
            ),
            deviceId: _testDeviceId,
          ),
          deviceId: _testDeviceId,
        ),
        scheduleService: const OcptScheduleService(logger: SilentLogger(), deviceId: _testDeviceId),
        deviceId: _testDeviceId,
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
    : super(propertiesManager: propertiesManager, appLanguageCode: _testAppLanguageCode);

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

/// An export manager that is never asked for anything: these tests do not export.
class _InertExportManager extends OcptExportManager {
  /// Class constructor
  _InertExportManager() : super(fileSelectorManager: const FileSelectorManager());
}

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
      appLanguageCode: _testAppLanguageCode,
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
  /// [exportManager] defaults to an [_InertExportManager]: no test here exports. [overrideProjectsManager]
  /// lets a test swap in a manager of its own (already holding an open project), for the one that
  /// needs to observe its calls.
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
    exportManager: exportManager ?? _InertExportManager(),
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
    expect(
      await propertiesManager.editorLeftDockFraction.load(),
      OcptWorkspaceDock.leftDefaultFraction,
    );
    expect(
      await propertiesManager.editorRightDockFraction.load(),
      OcptWorkspaceDock.rightDefaultFraction,
    );

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

  test('adding title page fields to a screenplay with none inserts one, saves it "manual", and '
      're-parses', () async {
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
    expect(state.text, 'Title: My Screenplay\nCredit: written by\nAuthor: Jane Doe\n\n$editedText');
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
  });

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

  group('epochs and the mode contract', () {
    test('the load moves the reload epoch once and names itself as the cause', () async {
      final bloc = buildBloc();
      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.reloadEpoch, 1);
      expect(state.reloadCause, OcptEditorReloadCause.load);
      expect(state.selectionEpoch, 0);

      await bloc.close();
    });

    test('typing moves neither epoch', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      final state = await waitForState(bloc, (state) => state.document?.sourceText == editedText);

      expect(state.reloadEpoch, 1);
      expect(state.selectionEpoch, 0);

      await bloc.close();
    });

    test('a scene jump request moves the selection epoch, the same scene twice too', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorSceneJumpRequestedEvent(charOffset: 4));
      bloc.add(const OcptEditorSceneJumpRequestedEvent(charOffset: 4));
      final state = await waitForState(bloc, (state) => state.selectionEpoch == 2);

      expect(state.reloadEpoch, 1);

      await bloc.close();
    });

    test('a page setup change moves the reload epoch with its own cause', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptEditorPageSetupChangedEvent(
          pageSetup: OcptPageSetup(
            format: OcptPageFormat.a4,
            margins: FountainPageMargins.standard(),
          ),
        ),
      );
      final state = await waitForState(bloc, (state) => state.reloadEpoch == 2);

      expect(state.reloadCause, OcptEditorReloadCause.pageSetup);

      await bloc.close();
    });

    test('a title page rewrite moves the reload epoch as a replaced text', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(
        const OcptEditorTitlePageChangedEvent(
          title: "My Movie",
          credit: "",
          author: "",
          draftDate: "",
          contact: "",
          source: "",
        ),
      );
      final state = await waitForState(bloc, (state) => state.reloadEpoch == 2);

      expect(state.reloadCause, OcptEditorReloadCause.textReplaced);

      await bloc.close();
    });

    test('flushAllPendingWrites saves a dirty text as manual and answers true', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      await waitForState(bloc, (state) => state.isDirty);

      expect(await bloc.flushAllPendingWrites(), isTrue);

      expect(bloc.state.isDirty, isFalse);
      expect((await readSnapshots()).last.reason, OcptSnapshotReason.manual);

      await bloc.close();
    });

    test('flushAllPendingWrites writes nothing when the text is clean', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      expect(await bloc.flushAllPendingWrites(), isTrue);
      expect(await readSnapshots(), isEmpty);

      await bloc.close();
    });

    test('a failing save still answers true and keeps the text dirty', () async {
      final bloc = buildBloc(screenplayService: const _FailingScreenplayService());
      await waitForState(bloc, (state) => !state.isLoading);

      bloc.add(const OcptEditorTextChangedEvent(text: editedText));
      await waitForState(bloc, (state) => state.isDirty);

      expect(await bloc.flushAllPendingWrites(), isTrue);
      expect(bloc.state.isDirty, isTrue);
      expect(bloc.state.hasSaveError, isTrue);

      await bloc.close();
    });

    test('reload of the screenplay scope reads the stored text and moves the epoch', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final project = projectsManager.currentProject!;
      await projectsManager.screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: editedText,
        snapshotReason: OcptSnapshotReason.manual,
      );

      expect(await bloc.reload({OcptEditorReloadScope.screenplay}), isTrue);

      expect(bloc.state.text, editedText);
      expect(bloc.state.reloadEpoch, 2);
      expect(bloc.state.reloadCause, OcptEditorReloadCause.textReplaced);

      await bloc.close();
    });

    test('flushAllPendingWrites and reload answer at once on a closed bloc', () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      await bloc.close();

      expect(await bloc.flushAllPendingWrites(), isFalse);
      expect(await bloc.reload({OcptEditorReloadScope.screenplay}), isFalse);
    });
  });
}
