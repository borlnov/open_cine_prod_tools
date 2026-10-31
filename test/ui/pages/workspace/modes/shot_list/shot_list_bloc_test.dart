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
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
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

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String _testAppLanguageCode() => "en";

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class _RecordingRouterManager extends OcptRouterManager {
  final _popCompleter = Completer<void>();

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

/// A projects manager that counts how many times a working-copy capture actually reads the whole
/// project, so a dispatch that is only supposed to *request* one (rather than always performing
/// it) can be told apart from one that skipped it.
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

  @override
  Future<String> createShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String sceneId,
  }) async => throw StateError("shot creation intentionally failed for the test");
}

void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";
  const dialogueText =
      "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
      "EXT. GARDEN - NIGHT\n\nAction two.\n";
  // ELISA is introduced in capitals in an action line and never speaks: the screenwriting
  // convention for a character's first appearance, and the only way a silent role is ever named.
  const silentCharacterText =
      "INT. HOUSE - DAY\n\nELISA entre dans la pièce.\n\nLÉA\n"
      "Hello there.\n";

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

    await projectsManager.screenplayService.saveScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      fountainText: text,
      snapshotReason: OcptSnapshotReason.manual,
    );
  }

  /// Builds a bloc wired to the test project. [fieldEditDebounce] defaults to a short duration so
  /// tests exercising the field-edit debounce don't have to wait out the real 2 s one, and
  /// [overrideProjectsManager] lets a test swap in a manager of its own (already holding an open
  /// project), for the one that needs to observe its calls. Its export manager is a plain one
  /// nothing ever exports through: the exports are the export bloc's own, tested apart.
  OcptShotListBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptShotListService? shotListService,
    OcptStoryboardService? storyboardService,
    OcptFloorPlanService? floorPlanService,
    OcptProjectsManager? overrideProjectsManager,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
    String? selectedEpisodeId,
  }) => OcptShotListBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
    shotListService: shotListService,
    storyboardService: storyboardService,
    floorPlanService: floorPlanService,
    fieldEditDebounce: fieldEditDebounce,
    selectedEpisodeId: selectedEpisodeId,
  );

  /// Builds the inspector bloc of [modeBloc], for the tests that write through it. [fieldEditDebounce]
  /// defaults to a short duration so tests exercising the field-edit debounce don't have to wait out
  /// the real 2 s one.
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

  /// The floor plan canvas bloc of [modeBloc], built on first use: the tests that need a symbol to
  /// work on ask it to place one, since the gestures on the plan are its own.
  OcptShotListFloorPlanCanvasBloc canvasOf(OcptShotListBloc modeBloc) => canvasBlocs.putIfAbsent(
    modeBloc,
    () => OcptShotListFloorPlanCanvasBloc(modeBloc: modeBloc, projectsManager: projectsManager),
  );

  /// The id of the symbol the canvas bloc of [bloc] has selected, once it does: a placement
  /// selects the symbol it wrote, after the mode holds it.
  Future<String> selectedSymbolIdOf(OcptShotListBloc bloc) async {
    await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId != null);
    return canvasOf(bloc).state.selectedFloorPlanSymbolId!;
  }

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
      await projectsManager.shotListService.createShot(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        sceneId: (state.sequences.first as OcptSceneShotSequence).sceneId,
      );
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

      await projectsManager.roleIndexService.addRole(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        name: "NEWCOMER",
        kind: OcptRoleKind.silent,
      );
      await projectsManager.floorPlanService.placeSymbol(
        database: project.database,
        setId: setId,
        sceneId: null,
        shotId: null,
        layer: OcptFloorPlanLayer.set,
        xM: 1,
        yM: 1,
        setElementShape: OcptFloorPlanSetElementShape.wall,
      );
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

    expect(state.sequences, hasLength(1));
    expect(
      (state.sequences.single as OcptSceneShotSequence).heading,
      "INT. SECOND EPISODE - NIGHT",
    );

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    final primarySnapshot = await projectsManager.shotListService.loadShotList(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      episodeNumber: null,
    );
    final secondEpisodeSnapshot = await projectsManager.shotListService.loadShotList(
      database: project.database,
      screenplayId: secondEpisodeId,
      episodeNumber: null,
    );
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
    await countingManager.screenplayService.saveScreenplayText(
      database: countingManager.currentProject!.database,
      screenplayId: countingManager.currentProject!.primaryScreenplayId,
      fountainText: twoSceneText,
      snapshotReason: OcptSnapshotReason.manual,
    );

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

    bloc.add(const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.versions));
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.versions);
    await Future<void>.delayed(const Duration(milliseconds: 100));
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
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(countingManager.captureCount, beforeTabSelected + 2);

    await inspector.close();
    await bloc.close();
    await countingManager.disposeLifeCycle();
  });

  test('the last right dock tab is persisted and restored on the next entry', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata));
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.metadata);
    await bloc.close();

    final reopenedBloc = buildBloc();
    final state = await waitForState(reopenedBloc, (state) => !state.isLoading);

    // The dock itself starts closed on every entry; only which tab it reopens on is remembered.
    expect(state.rightDockTab, isNull);
    expect(state.lastRightDockTab, OcptShotListRightDockTab.metadata);

    await reopenedBloc.close();
  });

  test(
    'toggling a column persists the visible set, and it is restored on the next entry',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      expect(bloc.state.visibleColumns, OcptShotListColumn.defaultVisibleColumns);

      bloc.add(const OcptShotListColumnToggledEvent(column: OcptShotListColumn.lens));
      await waitForState(bloc, (state) => state.visibleColumns.contains(OcptShotListColumn.lens));

      bloc.add(const OcptShotListColumnToggledEvent(column: OcptShotListColumn.status));
      await waitForState(
        bloc,
        (state) => !state.visibleColumns.contains(OcptShotListColumn.status),
      );
      await bloc.close();

      final reopenedBloc = buildBloc();
      final state = await waitForState(reopenedBloc, (state) => !state.isLoading);

      expect(state.visibleColumns, contains(OcptShotListColumn.lens));
      expect(state.visibleColumns, isNot(contains(OcptShotListColumn.status)));
      expect(state.visibleColumns, contains(OcptShotListColumn.duration));

      await reopenedBloc.close();
    },
  );

  test('hiding every optional column is restored as such, not as the defaults', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    for (final column in Set<OcptShotListColumn>.of(bloc.state.visibleColumns)) {
      bloc.add(OcptShotListColumnToggledEvent(column: column));
    }
    await waitForState(bloc, (state) => state.visibleColumns.isEmpty);
    await bloc.close();

    final reopenedBloc = buildBloc();
    final state = await waitForState(reopenedBloc, (state) => !state.isLoading);
    expect(state.visibleColumns, isEmpty);

    await reopenedBloc.close();
  });

  test('dock fractions are persisted per drag and restored on the next entry', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListDockFractionsChangedEvent(left: 0.3));
    await waitForState(bloc, (state) => state.leftDockFraction == 0.3);
    // The other side is left exactly where it was.
    expect(bloc.state.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);

    bloc.add(const OcptShotListDockFractionsChangedEvent(right: 0.5));
    await waitForState(bloc, (state) => state.rightDockFraction == 0.5);
    await bloc.close();

    final reopenedBloc = buildBloc();
    var state = await waitForState(reopenedBloc, (state) => !state.isLoading);
    expect(state.leftDockFraction, 0.3);
    expect(state.rightDockFraction, 0.5);

    reopenedBloc.add(const OcptShotListDockLayoutResetEvent());
    state = await waitForState(
      reopenedBloc,
      (state) => state.leftDockFraction == OcptWorkspaceDock.leftDefaultFraction,
    );
    expect(state.rightDockFraction, OcptWorkspaceDock.rightDefaultFraction);

    await reopenedBloc.close();
  });

  test('the sequence panel toggles', () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.isSequencePanelVisible, isTrue);

    bloc.add(const OcptShotListSequencePanelToggledEvent());
    await waitForState(bloc, (state) => !state.isSequencePanelVisible);

    await bloc.close();
  });

  test('going back closes the current project and pops', () async {
    final routerManager = _RecordingRouterManager();
    final bloc = buildBloc(routerManager: routerManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListBackRequestedEvent());
    await routerManager.onPop.timeout(const Duration(seconds: 5));

    expect(projectsManager.currentProject, isNull);

    await bloc.close();
  });

  test('loads the screenplay characters and the field suggestion lists', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.screenplayCharacters, ["LÉA"]);
    expect(state.suggestions.shotSizes, isEmpty);
    expect(state.suggestions.sounds, isEmpty);

    await bloc.close();
  });

  test('a character only introduced in an action line is part of the cast', () async {
    await writeScreenplay(silentCharacterText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    // ELISA never speaks: the action line introducing her in capitals is the only place the
    // screenplay names her, and she still has to be attachable to a shot.
    expect(state.screenplayCharacters, ["ELISA", "LÉA"]);

    await bloc.close();
  });

  test('a character named only in an action line is never reported as removed', () async {
    await writeScreenplay(silentCharacterText);

    final bloc = buildBloc();
    final inspector = buildInspector(bloc);
    var state = await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 1);

    final elisaRoleId = state.roles.firstWhere((role) => role.name == "ELISA").id;
    inspector.add(
      OcptShotListShotCharacterToggledEvent(shotId: state.selectedShotId!, roleId: elisaRoleId),
    );
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.isNotEmpty);

    expect(state.selectedShot!.characters, ["ELISA"]);
    expect(state.orphanedRoleAlerts, isEmpty);

    await inspector.close();
    await bloc.close();
  });

  test('deleting the selected shot removes it and clears the selection', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;
    final sequenceId = state.selectedSequenceId;

    bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
    state = await waitForState(bloc, (state) => state.totalShotCount == 0);

    expect(state.selectedShotId, isNull);
    expect(state.selectedSequenceId, sequenceId);

    await bloc.close();
  });

  test('the screenplay text is loaded into the state', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    final state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.screenplayText, twoSceneText);

    await bloc.close();
  });

  test(
    'the project settings changed event re-reads the page setup the export dialog pre-fills from',
    () async {
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      final otherFormat = bloc.state.pageSetup.format == OcptPageFormat.usLetter
          ? OcptPageFormat.a4
          : OcptPageFormat.usLetter;
      // Written directly through the manager, the way the project settings page itself writes it
      // — this bloc never sees the new value on an event, only the fact that something changed.
      await projectsManager.saveCurrentProjectPageFormat(otherFormat);

      bloc.add(const OcptShotListProjectSettingsChangedEvent());
      final state = await waitForState(bloc, (state) => state.pageSetup.format == otherFormat);

      expect(state.pageSetup.format, otherFormat);

      await bloc.close();
    },
  );

  group("the board", () {
    /// Creates a shot in the first scene of [twoSceneText] and returns its id, waiting for the
    /// selection the creation event always makes.
    Future<String> createShot(OcptShotListBloc bloc) async {
      bloc.add(const OcptShotListShotCreationRequestedEvent());
      final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
      return created.selectedShotId!;
    }

    test("switching to the board keeps the selected shot and persists the choice", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final shotId = await createShot(bloc);

      bloc.add(const OcptShotListCentreViewSelectedEvent(view: OcptShotListCentreView.board));
      final state = await waitForState(
        bloc,
        (state) => state.centreView == OcptShotListCentreView.board,
      );

      expect(state.selectedShotId, shotId);
      expect(await propertiesManager.shotListLastCentreView.load(), OcptShotListCentreView.board);

      await bloc.close();
    });
  });

  group("floor plans", () {
    test("deleting a symbol removes it and clears its own selection", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      canvasOf(bloc).add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final symbolId = await selectedSymbolIdOf(bloc);

      bloc.add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: symbolId));
      await waitForState(bloc, (state) => state.selectedSet!.symbols.isEmpty);
      await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId == null);
      expect(canvasOf(bloc).state.selectedFloorPlanSymbolId, isNull);

      await bloc.close();
    });

    test("switching sequences clears the set and symbol selection", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      final loaded = await waitForState(bloc, (state) => !state.isLoading);
      final firstSequenceId = loaded.sequences.first.id;
      final secondSequenceId = loaded.sequences[1].id;
      await createCase(bloc);

      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
      final onSecond = await waitForState(
        bloc,
        (state) => state.selectedSequenceId == secondSequenceId,
      );
      expect(onSecond.selectedSetId, isNull);
      expect(onSecond.setsOfSelectedSequence, isEmpty);

      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      final backOnFirst = await waitForState(
        bloc,
        (state) => state.selectedSequenceId == firstSequenceId,
      );
      expect(backOnFirst.selectedSetId, isNotNull);

      await bloc.close();
    });

    group("the shot half", () {
      /// Creates a shot on the sole selected sequence and returns its id, waiting for the
      /// selection the creation event always makes — mirrors "the board" group's own helper.
      ///
      /// Waits for `selectedShotId` to actually **change** from whatever it already was, not
      /// merely to be non-null: a current shot is always guaranteed whenever the sequence already
      /// holds one, so a second call in the same test would otherwise resolve against the still-
      /// current previous shot before the new one's own creation event is even processed.
      Future<String> createShot(OcptShotListBloc bloc) async {
        final previousShotId = bloc.state.selectedShotId;
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        final created = await waitForState(
          bloc,
          (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
        );
        return created.selectedShotId!;
      }

      test("always a current shot: creating the sequence's first shot focuses it, deleting "
          "it reselects the sequence's own next first shot rather than clearing to null", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        final loaded = await waitForState(bloc, (state) => !state.isLoading);
        final sequenceId = loaded.selectedSequenceId;
        // No shot exists yet: the invariant only ever guarantees a current shot while the
        // sequence holds at least one.
        expect(loaded.selectedShotId, isNull);
        expect(loaded.isFloorPlanShotFocusActive, isFalse);

        final firstShotId = await createShot(bloc);
        expect(bloc.state.isFloorPlanShotFocusActive, isTrue);
        expect(bloc.state.selectedShotId, firstShotId);

        final secondShotId = await createShot(bloc);
        expect(secondShotId, isNot(firstShotId));
        expect(bloc.state.selectedShotId, secondShotId);

        // Deleting the currently focused shot reselects the sequence's own remaining shot
        // rather than clearing the selection to null.
        bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: secondShotId));
        final afterDelete = await waitForState(
          bloc,
          (state) => state.selectedShotId == firstShotId,
        );
        expect(afterDelete.selectedSequenceId, sequenceId);
        expect(afterDelete.isFloorPlanShotFocusActive, isTrue);

        // Deleting the sequence's own last shot finally clears the selection: there is no shot
        // left to be the current one.
        bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: firstShotId));
        final afterLastDelete = await waitForState(bloc, (state) => state.totalShotCount == 0);
        expect(afterLastDelete.selectedShotId, isNull);
        expect(afterLastDelete.selectedSequenceId, sequenceId);

        await bloc.close();
      });

      test("always a current shot: switching to a sequence holding shots selects its own "
          "first one", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        final loaded = await waitForState(bloc, (state) => !state.isLoading);
        final firstSequenceId = loaded.sequences.first.id;
        final secondSequenceId = loaded.sequences[1].id;

        final firstSequenceShotId = await createShot(bloc);

        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
        final onSecond = await waitForState(
          bloc,
          (state) => state.selectedSequenceId == secondSequenceId,
        );
        // The second sequence holds no shot of its own yet.
        expect(onSecond.selectedShotId, isNull);

        bloc.add(const OcptShotListShotCreationRequestedEvent());
        final secondSequenceShotId = await waitForState(
          bloc,
          (state) => state.selectedShotId != null,
        ).then((state) => state.selectedShotId!);

        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        final backOnFirst = await waitForState(
          bloc,
          (state) => state.selectedShotId == firstSequenceShotId,
        );
        expect(backOnFirst.selectedSequenceId, firstSequenceId);

        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
        final backOnSecond = await waitForState(
          bloc,
          (state) => state.selectedShotId == secondSequenceShotId,
        );
        expect(backOnSecond.selectedSequenceId, secondSequenceId);

        await bloc.close();
      });

      test("editing a symbol's label debounces then writes", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final shotId = await createShot(bloc);

        canvasOf(bloc).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.characters,
            shotId: shotId,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final symbolId = placed.selectedSet!.symbols.single.id;

        bloc.add(OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: symbolId, rawValue: "SAM"));
        final pending = await waitForState(
          bloc,
          (state) => state.pendingFieldEdits.containsKey(
            OcptShotListSymbolLabelEditKey(symbolId: symbolId),
          ),
        );
        expect(pending.selectedSet!.symbols.single.label, isEmpty);

        final flushed = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.single.label == "SAM",
        );
        expect(flushed.pendingFieldEdits, isEmpty);

        await bloc.close();
      });

      test(
        "deleting a shot tombstones its own floor plan symbols and reloads the snapshot",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final shotId = await createShot(bloc);

          canvasOf(bloc).add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.cameras,
              shotId: shotId,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);

          bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
          final deleted = await waitForState(bloc, (state) => state.totalShotCount == 0);
          expect(deleted.selectedSet!.symbols, isEmpty);
          await waitUntil(() => canvasOf(bloc).state.selectedFloorPlanSymbolId == null);
          expect(canvasOf(bloc).state.selectedFloorPlanSymbolId, isNull);

          await bloc.close();
        },
      );

      test(
        "changing a camera's field of view writes it (OcptShotListFloorPlanSymbolFovChangedEvent)",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final shotId = await createShot(bloc);

          canvasOf(bloc).add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.cameras,
              shotId: shotId,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
          final symbolId = placed.selectedSet!.symbols.single.id;
          expect(placed.selectedSet!.symbols.single.fovDeg, isNull);

          bloc.add(OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: symbolId, fovDeg: 35));
          final changed = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.single.fovDeg == 35,
          );
          expect(changed.selectedSet!.symbols.single.fovDeg, 35);

          await bloc.close();
        },
      );
    });

    group("restore / hide / delete everywhere", () {
      Future<String> linkSecondSequence(OcptShotListBloc bloc, String setId) async {
        final secondSequenceId = bloc.state.sequences[1].id;
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == secondSequenceId);
        final epoch = bloc.state.selectionEpoch;
        setsOf(bloc).add(OcptShotListSetLinkRequestedEvent(setId: setId));
        await waitForState(
          bloc,
          (state) => state.setsOfSelectedSequence.isNotEmpty && state.selectionEpoch > epoch,
        );
        return secondSequenceId;
      }

      test(
        "restoring an override tombstones it, so the original reappears for that sequence",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final firstSequenceId = bloc.state.selectedSequenceId!;

          canvasOf(bloc).add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.set,
              shotId: null,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
          final originalId = await selectedSymbolIdOf(bloc);

          // Hiding it (with no override yet) is what creates the override end to end.
          bloc.add(
            OcptShotListFloorPlanSymbolHideRequestedEvent(
              symbolId: originalId,
              targetSceneId: firstSequenceId,
            ),
          );
          final hidden = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.length == 2,
          );
          final overrideId = hidden.selectedSet!.symbols
              .firstWhere((symbol) => symbol.id != originalId)
              .id;
          expect(
            hidden.selectedSet!.symbols.firstWhere((symbol) => symbol.id == overrideId).isHidden,
            isTrue,
          );

          bloc.add(OcptShotListFloorPlanSymbolRestoreRequestedEvent(symbolId: overrideId));
          final restored = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.length == 1,
          );

          expect(restored.selectedSet!.symbols.single.id, originalId);

          await bloc.close();
        },
      );

      test("hiding a set-scope original with no override yet creates a hidden one, masking it for "
          "the target sequence", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        canvasOf(bloc).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final originalId = await selectedSymbolIdOf(bloc);

        bloc.add(
          OcptShotListFloorPlanSymbolHideRequestedEvent(
            symbolId: originalId,
            targetSceneId: firstSequenceId,
          ),
        );
        final hidden = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

        final override = hidden.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id != originalId,
        );
        expect(override.overridesSymbolId, originalId);
        expect(override.sceneId, firstSequenceId);
        expect(override.isHidden, isTrue);

        await bloc.close();
      });

      test("hiding a symbol that already has a visible override sets isHidden on it, without "
          "creating a second one", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        canvasOf(bloc).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final originalId = await selectedSymbolIdOf(bloc);
        final secondSequenceId = await linkSecondSequence(bloc, setId);
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

        // "Only sequence n" first, creating a **visible** override.
        canvasOf(bloc).add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: originalId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 3,
            yM: 3,
          ),
        );
        await waitUntil(() => canvasOf(bloc).state.pendingFloorPlanScopeDecision != null);
        canvasOf(bloc).add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.only,
          ),
        );
        final withVisibleOverride = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 2,
        );
        final overrideId = withVisibleOverride.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != originalId)
            .id;
        expect(
          withVisibleOverride.selectedSet!.symbols
              .firstWhere((symbol) => symbol.id == overrideId)
              .isHidden,
          isFalse,
        );

        // Hiding it now must flip that very same row, not add a third one.
        bloc.add(
          OcptShotListFloorPlanSymbolHideRequestedEvent(
            symbolId: originalId,
            targetSceneId: firstSequenceId,
          ),
        );
        final hidden = await waitForState(
          bloc,
          (state) =>
              state.selectedSet!.symbols.firstWhere((symbol) => symbol.id == overrideId).isHidden,
        );

        expect(hidden.selectedSet!.symbols, hasLength(2));
        expect(secondSequenceId, isNot(firstSequenceId));

        await bloc.close();
      });

      test(
        "delete everywhere tombstones the original and every override of it, in every sequence",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final firstSequenceId = bloc.state.selectedSequenceId!;
          canvasOf(bloc).add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.set,
              shotId: null,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
          final originalId = await selectedSymbolIdOf(bloc);

          final secondSequenceId = await linkSecondSequence(bloc, setId);
          bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
          await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

          bloc.add(
            OcptShotListFloorPlanSymbolHideRequestedEvent(
              symbolId: originalId,
              targetSceneId: firstSequenceId,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

          bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
          await waitForState(bloc, (state) => state.selectedSequenceId == secondSequenceId);
          bloc.add(
            OcptShotListFloorPlanSymbolHideRequestedEvent(
              symbolId: originalId,
              targetSceneId: secondSequenceId,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 3);

          bloc.add(OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent(symbolId: originalId));
          final deleted = await waitForState(bloc, (state) => state.selectedSet!.symbols.isEmpty);

          expect(deleted.selectedSet!.symbols, isEmpty);

          await bloc.close();
        },
      );

      test(
        "delete everywhere resolves an override id to its own original before cascading",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final firstSequenceId = bloc.state.selectedSequenceId!;
          canvasOf(bloc).add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.set,
              shotId: null,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
          final originalId = await selectedSymbolIdOf(bloc);

          bloc.add(
            OcptShotListFloorPlanSymbolHideRequestedEvent(
              symbolId: originalId,
              targetSceneId: firstSequenceId,
            ),
          );
          final hidden = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.length == 2,
          );
          final overrideId = hidden.selectedSet!.symbols
              .firstWhere((symbol) => symbol.id != originalId)
              .id;

          bloc.add(OcptShotListFloorPlanSymbolDeleteEverywhereRequestedEvent(symbolId: overrideId));
          final deleted = await waitForState(bloc, (state) => state.selectedSet!.symbols.isEmpty);

          expect(deleted.selectedSet!.symbols, isEmpty);

          await bloc.close();
        },
      );

      test("hiding a scene-scope symbol with no shot override yet creates a hidden one, masking "
          "it for the target shot", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);

        // A plain scene-scope furniture item (no `overridesSymbolId` — never a sequence override).
        canvasOf(bloc).add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: bloc.state.selectedSequenceId,
            xM: 0,
            yM: 0,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final symbolId = await selectedSymbolIdOf(bloc);

        Future<String> createShot() async {
          final previousShotId = bloc.state.selectedShotId;
          bloc.add(const OcptShotListShotCreationRequestedEvent());
          final created = await waitForState(
            bloc,
            (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
          );
          return created.selectedShotId!;
        }

        final firstShotId = await createShot();
        await createShot();

        bloc.add(
          OcptShotListFloorPlanSymbolHideForShotRequestedEvent(
            symbolId: symbolId,
            targetShotId: firstShotId,
          ),
        );
        final hidden = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

        final override = hidden.selectedSet!.symbols.firstWhere((symbol) => symbol.id != symbolId);
        expect(override.overridesSymbolId, symbolId);
        expect(override.shotId, firstShotId);
        expect(override.isHidden, isTrue);

        await bloc.close();
      });
    });
  });
}
