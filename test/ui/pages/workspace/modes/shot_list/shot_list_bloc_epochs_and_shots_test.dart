// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_test_utility/act_test_utility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_floor_plan_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_canvas_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_inspector_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../../../../../ocpt_result_expectations.dart';
import 'shot_list_bloc_test_doubles.dart';

/// The fixed device id every stamping test double in this file uses.
Future<String> _testDeviceId() async => "test-device";

/// A shot list service whose [createShot] always fails, to exercise the bloc's write error path.
class _FailingShotListService extends OcptShotListService {
  /// Class constructor
  const _FailingShotListService()
    : super(
        logger: const SilentLogger(),
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
        storyboardService: const OcptStoryboardService(
          logger: SilentLogger(),
          assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
          deviceId: _testDeviceId,
        ),
        floorPlanService: const OcptFloorPlanService(
          logger: SilentLogger(),
          assetsService: OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
          deviceId: _testDeviceId,
        ),
        deviceId: _testDeviceId,
      );

  /// Fail as a refused shot creation does.
  @override
  Future<OcptDatabaseResult<String>> createShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String sceneId,
  }) async => const OcptDatabaseResult(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "shot creation intentionally failed for the test",
  );
}

/// A floor plan service whose next read can be held back until the test releases it: the read
/// takes its data at once, then waits, so a read queued behind it has to wait as well.
class _HoldingFloorPlanService extends OcptFloorPlanService {
  /// Whether the next read is held back.
  bool holdsNextRead = false;

  /// How many reads were held back so far.
  int holdCount = 0;

  /// Completes to let the held call go on.
  final Completer<void> _release = Completer<void>();

  /// Class constructor
  _HoldingFloorPlanService(OcptFloorPlanService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        deviceId: source.deviceId,
      );

  /// Lets the held read answer.
  void release() => _release.complete();

  /// Load the floor plans as the real service does, then hold the call when the next read is to be
  /// held.
  @override
  Future<OcptDatabaseResult<OcptFloorPlanSnapshot>> loadFloorPlans({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final snapshot = await super.loadFloorPlans(database: database, screenplayId: screenplayId);
    if (holdsNextRead) {
      holdsNextRead = false;
      holdCount++;
      await _release.future;
    }
    return snapshot;
  }
}

/// A projects manager that counts how many times a working-copy capture actually reads the whole
/// project, so a dispatch that is only supposed to *request* one (rather than always performing
/// it) can be told apart from one that skipped it.
class _CountingProjectsManager extends OcptProjectsManager {
  /// How many times [captureWorkingCopyState] actually ran.
  int captureCount = 0;

  /// Class constructor
  _CountingProjectsManager({required OcptPropertiesManager propertiesManager})
    : super(propertiesManager: propertiesManager, appLanguageCode: testAppLanguageCode);

  /// Count the capture, then delegate to the real one.
  @override
  Future<OcptDatabaseResult<OcptProjectWorkingCopyState>> captureWorkingCopyState() async {
    captureCount++;
    return super.captureWorkingCopyState();
  }
}

/// Run the tests of the shot list bloc epochs and shots.
void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

  late OcptPropertiesManager propertiesManager;

  late OcptProjectsManager projectsManager;

  late Directory tempDir;

  /// The floor plan sets bloc [setsOf] built for each mode bloc of a test, closed in [tearDown].
  final setsBlocs = Map<OcptShotListBloc, OcptShotListFloorPlanSetsBloc>.identity();

  /// The floor plan canvas bloc [canvasOf] built for each mode bloc of a test, closed in
  /// [tearDown].
  final canvasBlocs = Map<OcptShotListBloc, OcptShotListFloorPlanCanvasBloc>.identity();

  setUpAll(() async {
    // Creating the global manager makes appLogger() (used by the bloc's write error path)
    // resolvable; the bloc's dependencies themselves are passed to it explicitly below.
    OcptGlobalManager.instance;

    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    propertiesManager = OcptPropertiesManager();
    await propertiesManager.initLifeCycle();
  });

  setUp(() async {
    // The in-memory preference store outlives a single test, so every test that reads a
    // preference back seeds the ones it cares about rather than assuming a pristine store.
    await propertiesManager.shotListVisibleColumns.store(OcptShotListColumn.defaultVisibleColumns);
    await propertiesManager.shotListLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await propertiesManager.shotListRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
    await propertiesManager.shotListLastRightDockTab.store(OcptShotListRightDockTab.inspector);

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_bloc_test_");
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
    for (final canvas in canvasBlocs.values) {
      await canvas.close();
    }
    canvasBlocs.clear();
    for (final sets in setsBlocs.values) {
      await sets.close();
    }
    setsBlocs.clear();
    await projectsManager.disposeLifeCycle();
    await tempDir.delete(recursive: true);
  });

  /// Writes [text] as the project's screenplay, which reconciles its scene index and therefore
  /// gives the shot list its sequences.
  Future<void> writeScreenplay(String text) async {
    final project = projectsManager.currentProject!;

    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: text,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;
  }

  /// Builds a bloc wired to the test project. [overrideProjectsManager] lets a test swap in a
  /// manager of its own (already holding an open project), for the one that needs to observe its
  /// calls. Its export manager is a plain one nothing ever exports through: the exports are the
  /// export bloc's own, tested apart.
  OcptShotListBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptShotListService? shotListService,
    OcptStoryboardService? storyboardService,
    OcptFloorPlanService? floorPlanService,
    OcptProjectsManager? overrideProjectsManager,
    String? selectedEpisodeId,
  }) => OcptShotListBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    shotListService: shotListService,
    storyboardService: storyboardService,
    floorPlanService: floorPlanService,
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Builds the inspector bloc of [modeBloc], for the tests that write through it.
  /// [fieldEditDebounce] defaults to a short duration so tests exercising the field-edit debounce
  /// don't have to wait out the real 2 s one.
  OcptShotListInspectorBloc buildInspector(
    OcptShotListBloc modeBloc, {
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptShotListInspectorBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    fieldEditDebounce: fieldEditDebounce,
  );

  /// Waits until [isDone] holds, looking again every few milliseconds: for a condition that spans
  /// the mode bloc and the inspector bloc, whose states change in an order a test must not depend
  /// on.
  Future<void> waitUntil(bool Function() isDone) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!isDone()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException("The awaited condition never held");
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptShotListState> waitForState(
    OcptShotListBloc bloc,
    bool Function(OcptShotListState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  /// The floor plan sets bloc of [modeBloc], built on first use: the tests that need a set to work
  /// on ask it to create one, since the sets are its own to write.
  OcptShotListFloorPlanSetsBloc setsOf(OcptShotListBloc modeBloc) => setsBlocs.putIfAbsent(
    modeBloc,
    () => OcptShotListFloorPlanSetsBloc(
      modeBloc: modeBloc,
      projectsManager: projectsManager,
      fieldEditDebounce: const Duration(milliseconds: 30),
    ),
  );

  /// Creates a set on the first scene of [twoSceneText] through the sets bloc and returns its id,
  /// waiting for the selection the creation always makes once the mode holds the set.
  Future<String> createCase(OcptShotListBloc bloc) async {
    final epoch = bloc.state.selectionEpoch;
    setsOf(bloc).add(const OcptShotListSetCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.selectionEpoch > epoch);
    return created.selectedSetId!;
  }

  group("the shared epochs the view blocs react to", () {
    test("the first load moves both epochs and records itself as the cause", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();

      expect(bloc.state.reloadEpoch, 0);
      expect(bloc.state.selectionEpoch, 0);
      expect(bloc.state.selectionCause, OcptShotListSelectionCause.none);

      final state = await waitForState(bloc, (state) => !state.isLoading);

      expect(state.reloadEpoch, 1);
      expect(state.selectionEpoch, 1);
      expect(state.selectionCause, OcptShotListSelectionCause.load);

      await bloc.close();
    });

    test("selecting a sequence moves the selection, again even when it is the same one", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);
      final firstEpoch = state.selectionEpoch;

      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.last.id));
      state = await waitForState(bloc, (state) => state.selectionEpoch == firstEpoch + 1);
      expect(state.selectionCause, OcptShotListSelectionCause.sequence);

      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.last.id));
      state = await waitForState(bloc, (state) => state.selectionEpoch == firstEpoch + 2);
      expect(state.selectionCause, OcptShotListSelectionCause.sequenceReselected);
      expect(state.reloadEpoch, 1, reason: 'selecting reads nothing again');

      await bloc.close();
    });

    test(
      "selecting a shot moves the selection even when it is the selected one, a stale id not",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
        final shotId = state.selectedShotId!;
        final epoch = state.selectionEpoch;
        expect(epoch, 2, reason: 'the load, then the creation selecting the new shot');

        bloc.add(OcptShotListShotSelectedEvent(shotId: shotId));
        state = await waitForState(bloc, (state) => state.selectionEpoch == epoch + 1);
        expect(state.selectionCause, OcptShotListSelectionCause.shot);

        bloc.add(const OcptShotListShotSelectedEvent(shotId: "gone"));
        bloc.add(OcptShotListShotSelectedEvent(shotId: shotId));
        state = await waitForState(bloc, (state) => state.selectionEpoch == epoch + 2);
        expect(state.selectionEpoch, epoch + 2, reason: 'the stale id changed nothing');

        await bloc.close();
      },
    );

    test("a selection event can be waited for until the mode holds its result", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);
      final secondSequenceId = state.sequences.last.id;

      await bloc.addAndWait(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
      expect(bloc.state.selectedSequenceId, secondSequenceId);

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      state = await waitForState(bloc, (state) => state.totalShotCount == 1);
      final shotId = state.selectedShotId!;
      await bloc.addAndWait(
        OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.first.id),
      );
      expect(bloc.state.selectedShotId, isNot(shotId));

      await bloc.addAndWait(OcptShotListShotSelectedEvent(shotId: shotId));
      expect(bloc.state.selectedShotId, shotId);

      await bloc.close();
    });

    test("selecting a set moves the selection with its own cause", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      await createCase(bloc);
      var state = bloc.state;
      final epoch = state.selectionEpoch;

      bloc.add(OcptShotListSetSelectedEvent(setId: state.selectedSetId!));
      state = await waitForState(bloc, (state) => state.selectionEpoch == epoch + 1);

      expect(state.selectionCause, OcptShotListSelectionCause.set);

      await bloc.close();
    });

    test("creating a shot moves both epochs, the selection with its own cause", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);
      final selectionEpoch = state.selectionEpoch;
      final reloadEpoch = state.reloadEpoch;

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      state = await waitForState(bloc, (state) => state.totalShotCount == 1);

      expect(state.selectionEpoch, selectionEpoch + 1);
      expect(state.selectionCause, OcptShotListSelectionCause.shotCreated);
      expect(state.reloadEpoch, reloadEpoch + 1);

      await bloc.close();
    });

    test("a write that reads the shot list again moves the reload epoch alone", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      final inspector = buildInspector(bloc);
      await waitForState(bloc, (state) => !state.isLoading);
      bloc.add(const OcptShotListShotCreationRequestedEvent());
      var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
      final shotId = state.selectedShotId!;
      final selectionEpoch = state.selectionEpoch;
      final reloadEpoch = state.reloadEpoch;

      inspector.add(
        OcptShotListShotDifficultyChangedEvent(
          shotId: shotId,
          axis: OcptShotDifficultyAxis.sound,
          value: 4,
        ),
      );
      state = await waitForState(
        bloc,
        (state) => state.snapshot!.shotsById[shotId]!.difficultySound == 4,
      );

      expect(state.reloadEpoch, reloadEpoch + 1);
      expect(state.selectionEpoch, selectionEpoch);

      await inspector.close();
      await bloc.close();
    });

    test(
      "flushing a pending edit reads again and moves the reload epoch, flushing none does not",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        final inspector = buildInspector(bloc, fieldEditDebounce: const Duration(days: 1));
        await waitForState(bloc, (state) => !state.isLoading);
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
        final epoch = state.reloadEpoch;

        await bloc.flushAllPendingWrites();
        expect(bloc.state.reloadEpoch, epoch, reason: 'nothing was pending');

        inspector.add(
          OcptShotListShotFieldChangedEvent(
            shotId: state.selectedShotId!,
            field: OcptShotListEditableField.shotSize,
            rawValue: "Close-up",
          ),
        );
        await waitUntil(() => inspector.state.pendingFieldEdits.isNotEmpty);
        await bloc.flushAllPendingWrites();

        state = bloc.state;
        expect(inspector.state.pendingFieldEdits, isEmpty);
        expect(state.reloadEpoch, epoch + 1);

        await inspector.close();
        await bloc.close();
      },
    );

    test("reload reads only the scopes it is given, then moves the reload epoch", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);
      final storyboardBefore = state.storyboardSnapshot;

      final project = projectsManager.currentProject!;
      await projectsManager.shotListService
          .createShot(
            database: project.database,
            screenplayId: project.primaryScreenplayId,
            sceneId: (state.sequences.first as OcptSceneShotSequence).sceneId,
          )
          .maybeValueOrFail;
      expect(bloc.state.totalShotCount, 0, reason: 'the bloc was not told');

      await bloc.reload({OcptShotListReloadScope.snapshot});

      state = bloc.state;
      expect(state.totalShotCount, 1);
      expect(state.storyboardSnapshot, same(storyboardBefore));
      expect(state.reloadEpoch, 2);
      expect(state.selectionEpoch, 1, reason: 'reading again does not move the selection');

      await bloc.close();
    });

    test("reload reads the cast and the set-scope symbols when it is asked to", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final project = projectsManager.currentProject!;

      await projectsManager.roleIndexService
          .addRole(
            database: project.database,
            screenplayId: project.primaryScreenplayId,
            name: "NEWCOMER",
            kind: OcptRoleKind.silent,
          )
          .maybeValueOrFail;
      await projectsManager.floorPlanService
          .placeSymbol(
            database: project.database,
            setId: setId,
            sceneId: null,
            shotId: null,
            layer: OcptFloorPlanLayer.set,
            xM: 1,
            yM: 1,
            setElementShape: OcptFloorPlanSetElementShape.wall,
          )
          .maybeValueOrFail;
      final rolesBefore = bloc.state.roles.length;
      expect(bloc.state.setScopeSymbolsBySetId[setId] ?? const [], isEmpty);

      await bloc.reload({OcptShotListReloadScope.roles});
      expect(bloc.state.roles, hasLength(rolesBefore + 1));
      expect(bloc.state.setScopeSymbolsBySetId[setId] ?? const [], isEmpty);

      await bloc.reload({OcptShotListReloadScope.setScopeSymbols});
      expect(bloc.state.setScopeSymbolsBySetId[setId], hasLength(1));

      await bloc.close();
    });

    test(
      "deleting the selected shot moves both epochs, deleting another one the reload alone",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        await waitForState(bloc, (state) => state.totalShotCount == 1);
        final firstShotId = bloc.state.selectedShotId!;
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        var state = await waitForState(bloc, (state) => state.totalShotCount == 2);
        final secondShotId = state.selectedShotId!;
        final reloadEpoch = state.reloadEpoch;
        final selectionEpoch = state.selectionEpoch;

        bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: firstShotId));
        state = await waitForState(bloc, (state) => state.totalShotCount == 1);
        expect(state.reloadEpoch, reloadEpoch + 1);
        expect(state.selectionEpoch, selectionEpoch, reason: 'the selected shot is still there');

        bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: secondShotId));
        state = await waitForState(bloc, (state) => state.totalShotCount == 0);
        expect(state.reloadEpoch, reloadEpoch + 2);
        expect(state.selectionEpoch, selectionEpoch + 1);
        expect(state.selectionCause, OcptShotListSelectionCause.shotDeleted);

        await bloc.close();
      },
    );
  });

  group("the mode's own reads wait for the ones already running", () {
    test("a created shot reaches the state after the read that was already on its way", () async {
      await writeScreenplay(twoSceneText);
      final service = _HoldingFloorPlanService(projectsManager.floorPlanService);
      final bloc = buildBloc(floorPlanService: service);
      await waitForState(bloc, (state) => !state.isLoading);

      service.holdsNextRead = true;
      final reload = bloc.reload({OcptShotListReloadScope.floorPlans});
      await waitUntil(() => service.holdCount == 1);
      bloc.add(const OcptShotListShotCreationRequestedEvent());
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(bloc.state.totalShotCount, 0);

      service.release();
      await reload;
      await waitForState(bloc, (state) => state.totalShotCount == 1);

      await bloc.close();
    });

    test("a deleted shot leaves the state after the read that was already on its way", () async {
      await writeScreenplay(twoSceneText);
      final service = _HoldingFloorPlanService(projectsManager.floorPlanService);
      final bloc = buildBloc(floorPlanService: service);
      await waitForState(bloc, (state) => !state.isLoading);
      bloc.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(bloc, (state) => state.totalShotCount == 1);

      service.holdsNextRead = true;
      final reload = bloc.reload({OcptShotListReloadScope.floorPlans});
      await waitUntil(() => service.holdCount == 1);
      bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: created.selectedShotId!));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(bloc.state.totalShotCount, 1);

      service.release();
      await reload;
      await waitForState(bloc, (state) => state.totalShotCount == 0);

      await bloc.close();
    });

    test("a changed page setup reaches the state after the read already on its way", () async {
      await writeScreenplay(twoSceneText);
      final service = _HoldingFloorPlanService(projectsManager.floorPlanService);
      final bloc = buildBloc(floorPlanService: service);
      await waitForState(bloc, (state) => !state.isLoading);
      final format = bloc.state.pageSetup.format;
      final other = format == OcptPageFormat.a4 ? OcptPageFormat.usLetter : OcptPageFormat.a4;

      service.holdsNextRead = true;
      final reload = bloc.reload({OcptShotListReloadScope.floorPlans});
      await waitUntil(() => service.holdCount == 1);
      await projectsManager.saveCurrentProjectPageFormat(other);
      bloc.add(const OcptShotListProjectSettingsChangedEvent());
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(bloc.state.pageSetup.format, format);

      service.release();
      await reload;
      await waitForState(bloc, (state) => state.pageSetup.format == other);

      await bloc.close();
    });
  });

  test('loads the screenplay scenes as sequences and selects the first one', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.title, "My Movie");
    expect(state.sequences, hasLength(2));
    expect((state.sequences.first as OcptSceneShotSequence).heading, "INT. HOUSE - DAY");
    expect(state.selectedSequenceId, state.sequences.first.id);
    expect(state.selectedShotId, isNull);
    expect(state.totalShotCount, 0);

    await bloc.close();
  });

  test('constructed with a second episode selected, reads and writes that episode rather than the '
      'primary screenplay', () async {
    await writeScreenplay(twoSceneText);
    final project = projectsManager.currentProject!;
    final secondEpisodeId = await projectsManager.screenplayService
        .createEpisode(database: project.database)
        .maybeValueOrFail;
    await projectsManager.screenplayService
        .saveScreenplayText(
          database: project.database,
          screenplayId: secondEpisodeId!,
          fountainText: "INT. SECOND EPISODE - NIGHT\n\nAction two.\n",
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;

    final bloc = buildBloc(selectedEpisodeId: secondEpisodeId);
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.sequences, hasLength(1));
    expect(
      (state.sequences.single as OcptSceneShotSequence).heading,
      "INT. SECOND EPISODE - NIGHT",
    );

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    final primarySnapshot = await projectsManager.shotListService
        .loadShotList(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          episodeNumber: null,
        )
        .valueOrFail;
    final secondEpisodeSnapshot = await projectsManager.shotListService
        .loadShotList(
          database: project.database,
          screenplayId: secondEpisodeId,
          episodeNumber: null,
        )
        .valueOrFail;
    expect(primarySnapshot.shotsById, isEmpty);
    expect(secondEpisodeSnapshot.shotsById, hasLength(1));

    await bloc.close();
  });

  test('a screenplay with no scene leaves every selection empty', () async {
    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.sequences, isEmpty);
    expect(state.selectedSequenceId, isNull);
    expect(state.selectedShot, isNull);

    await bloc.close();
  });

  test('creating a shot appends it to the selected sequence and selects it', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(bloc, (state) => state.totalShotCount == 1);

    final shot = state.selectedShot;
    expect(shot, isNotNull);
    expect(state.sequences.first.shots.single.id, shot!.id);
    expect(state.sequences.last.shots, isEmpty);
    // The first scene has no explicit `#N#`, so its display number is its 1-based index.
    expect(shot.code, "1/1");
    // Selecting a shot opens the right dock on its inspector.
    expect(state.rightDockTab, OcptShotListRightDockTab.inspector);

    await bloc.close();
  });

  test('shot codes follow the sequence a shot is created in', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.last.id));
    await waitForState(bloc, (state) => state.selectedSequenceId == state.sequences.last.id);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    expect(state.selectedShot!.code, "2/1");

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 2);
    expect(state.selectedShot!.code, "2/2");
    expect(state.sequences.last.shots, hasLength(2));

    await bloc.close();
  });

  test('a failing shot creation raises the transient write error', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(shotListService: const _FailingShotListService());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.hasWriteError);

    bloc.add(const OcptShotListWriteErrorDismissedEvent());
    final dismissedState = await waitForState(bloc, (state) => !state.hasWriteError);
    expect(dismissedState.totalShotCount, 0);

    await bloc.close();
  });

  test('selecting another sequence clears the selected shot, reselecting it keeps it', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.selectedShotId != null);
    final shotId = state.selectedShotId;

    bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.last.id));
    state = await waitForState(bloc, (state) => state.selectedShotId == null);
    expect(state.selectedSequenceId, state.sequences.last.id);

    bloc.add(OcptShotListShotSelectedEvent(shotId: shotId!));
    state = await waitForState(bloc, (state) => state.selectedShotId != null);
    // Selecting a shot brings its own sequence back with it.
    expect(state.selectedSequenceId, state.sequences.first.id);

    // Reselecting the sequence already selected leaves the shot alone.
    bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences.first.id));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.selectedShotId, shotId);

    await bloc.close();
  });

  test('selecting a shot that no longer exists changes nothing', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotSelectedEvent(shotId: "not-a-shot"));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.selectedShotId, isNull);
    expect(bloc.state.selectedSequenceId, state.sequences.first.id);
    expect(bloc.state.rightDockTab, isNull);

    await bloc.close();
  });

  test('the right dock toggles closed, then reopens on the last tab selected', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.rightDockTab, isNull);

    bloc.add(const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata));
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.metadata);

    // Selecting the active tab again closes the dock, but still remembers it.
    bloc.add(const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata));
    await waitForState(bloc, (state) => state.rightDockTab == null);
    expect(bloc.state.lastRightDockTab, OcptShotListRightDockTab.metadata);

    bloc.add(const OcptShotListRightDockToggledEvent());
    await waitForState(bloc, (state) => state.rightDockTab != null);
    expect(bloc.state.rightDockTab, OcptShotListRightDockTab.metadata);

    bloc.add(const OcptShotListRightDockClosedEvent());
    await waitForState(bloc, (state) => state.rightDockTab == null);

    await bloc.close();
  });

  test('opening the Versions tab, and a field edit flushing while it is open, each capture the '
      'working copy afresh', () async {
    final countingManager = _CountingProjectsManager(propertiesManager: propertiesManager);
    await countingManager.initLifeCycle();
    final created = await countingManager.createProject(
      name: "Working Copy Movie",
      filePath: p.join(tempDir.path, "working_copy.ocpt"),
    );
    expect(created.status.isSuccess, isTrue);
    await countingManager.screenplayService
        .saveScreenplayText(
          database: countingManager.currentProject!.database,
          screenplayId: countingManager.currentProject!.primaryScreenplayId,
          fountainText: twoSceneText,
          snapshotReason: OcptSnapshotReason.manual,
        )
        .okOrFail;

    final bloc = buildBloc(overrideProjectsManager: countingManager);
    final inspector = OcptShotListInspectorBloc(
      modeBloc: bloc,
      projectsManager: countingManager,
      fieldEditDebounce: const Duration(milliseconds: 30),
    );
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created2 = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created2.selectedShotId!;

    // Only the mount above has captured so far (creating a shot is not a version operation);
    // waiting out the throttle window guarantees the tab selection below actually captures rather
    // than being silently skipped.
    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));
    final beforeTabSelected = countingManager.captureCount;

    // A capture runs after the state it follows, and how long that takes depends on the load of
    // the machine, so it is waited for rather than given a fixed window.
    Future<void> waitForCaptures(int expectedCount) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (countingManager.captureCount < expectedCount && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    bloc.add(const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.versions));
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.versions);
    await waitForCaptures(beforeTabSelected + 1);
    expect(countingManager.captureCount, beforeTabSelected + 1);

    // Clear the throttle again, then flush a field edit while the tab opened above is still the
    // active one.
    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));
    inspector.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Wide",
      ),
    );
    await waitForState(bloc, (state) => state.selectedShot!.shotSize == "Wide");
    await waitForCaptures(beforeTabSelected + 2);
    expect(countingManager.captureCount, beforeTabSelected + 2);

    await inspector.close();
    await bloc.close();
    await countingManager.disposeLifeCycle();
  });
}
