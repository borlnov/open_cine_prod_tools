// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:act_dart_result/act_dart_result.dart';
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
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_override_level.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_scope_choice.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
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

/// A file selector manager answering the picker with a file of its own, so a test never opens a
/// native dialog: [pickedPath] is what the user is pretending to pick, and null is a
/// cancellation. Mirrors `OcptResourcesBloc`'s own test double,
/// `resources_bloc_test.dart`'s `_StubFileSelectorManager`.
class _StubFileSelectorManager extends FileSelectorManager {
  /// The path the next pick answers with, or null to answer as a cancelled dialog does.
  final String? pickedPath;

  /// Class constructor
  const _StubFileSelectorManager({required this.pickedPath});

  /// Answers with [pickedPath] instead of opening the platform's own dialog.
  @override
  Future<ResultWithBoolStatus<XFile>> openSelector({
    required List<String> allowedExtensions,
    required String label,
    bool strictOnExtensions = true,
  }) async {
    final pickedPath = this.pickedPath;
    if (pickedPath == null) {
      return const ResultWithBoolStatus(status: BoolResultStatus.error);
    }

    return ResultWithBoolStatus(status: BoolResultStatus.success, value: XFile(pickedPath));
  }
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
    FileSelectorManager? fileSelectorManager,
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
    fileSelectorManager: fileSelectorManager,
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
      bloc.add(const OcptShotListSetCreationRequestedEvent());
      var state = await waitForState(bloc, (state) => state.setsOfSelectedSequence.isNotEmpty);
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

    test("every way a set becomes the selected one moves the selection epoch", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      var state = await waitForState(bloc, (state) => !state.isLoading);

      // Created.
      var epoch = state.selectionEpoch;
      var reloadEpoch = state.reloadEpoch;
      bloc.add(const OcptShotListSetCreationRequestedEvent());
      state = await waitForState(bloc, (state) => state.setsOfSelectedSequence.length == 1);
      final firstSetId = state.selectedSetId!;
      expect(state.selectionEpoch, epoch + 1, reason: 'created');
      expect(state.reloadEpoch, reloadEpoch + 1, reason: 'created');
      expect(state.selectionCause, OcptShotListSelectionCause.setAdded, reason: 'created');

      // Linked, from the second sequence.
      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: state.sequences[1].id));
      state = await waitForState(
        bloc,
        (state) => state.selectedSequenceId == state.sequences[1].id,
      );
      epoch = state.selectionEpoch;
      reloadEpoch = state.reloadEpoch;
      bloc.add(OcptShotListSetLinkRequestedEvent(setId: firstSetId));
      state = await waitForState(bloc, (state) => state.setsOfSelectedSequence.isNotEmpty);
      expect(state.selectionEpoch, epoch + 1, reason: 'linked');
      expect(state.reloadEpoch, reloadEpoch + 1, reason: 'linked');
      expect(state.selectionCause, OcptShotListSelectionCause.setAdded, reason: 'linked');

      // Duplicated.
      epoch = state.selectionEpoch;
      reloadEpoch = state.reloadEpoch;
      bloc.add(OcptShotListSetDuplicationRequestedEvent(setId: firstSetId, newSetName: "Copy"));
      state = await waitForState(bloc, (state) => state.setsOfSelectedSequence.length == 2);
      final copyId = state.selectedSetId!;
      expect(state.selectionEpoch, epoch + 1, reason: 'duplicated');
      expect(state.reloadEpoch, reloadEpoch + 1, reason: 'duplicated');
      expect(state.selectionCause, OcptShotListSelectionCause.setAdded, reason: 'duplicated');

      // Unlinked while selected: the sequence's next set is selected.
      epoch = state.selectionEpoch;
      reloadEpoch = state.reloadEpoch;
      bloc.add(OcptShotListSetDeletionRequestedEvent(setId: copyId));
      state = await waitForState(bloc, (state) => state.setsOfSelectedSequence.length == 1);
      expect(state.selectionEpoch, epoch + 1, reason: 'unlinked');
      expect(state.reloadEpoch, reloadEpoch + 1, reason: 'unlinked');
      expect(state.selectionCause, OcptShotListSelectionCause.setRemoved, reason: 'unlinked');

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
      var state = await waitForState(bloc, (state) => !state.isLoading);
      bloc.add(const OcptShotListSetCreationRequestedEvent());
      state = await waitForState(bloc, (state) => state.setsOfSelectedSequence.isNotEmpty);
      final setId = state.selectedSetId!;
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
    /// Creates a set on the first scene of [twoSceneText] and returns its id, waiting for the
    /// selection the creation event always makes.
    Future<String> createCase(OcptShotListBloc bloc) async {
      bloc.add(const OcptShotListSetCreationRequestedEvent());
      final created = await waitForState(bloc, (state) => state.setsOfSelectedSequence.isNotEmpty);
      return created.selectedSetId!;
    }

    test("a fresh set is named from the scene heading's place and selected", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);

      final setId = await createCase(bloc);
      final state = bloc.state;

      expect(state.setsOfSelectedSequence, hasLength(1));
      expect(state.selectedSetId, setId);
      expect(state.selectedSet!.name, "HOUSE");

      await bloc.close();
    });

    test("renaming a set debounces then writes", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: "Living room"));
      final pending = await waitForState(
        bloc,
        (state) => state.pendingFieldEdits.containsKey(OcptShotListSetNameEditKey(setId: setId)),
      );
      expect(pending.selectedSet!.name, "HOUSE");

      final flushed = await waitForState(bloc, (state) => state.selectedSet!.name == "Living room");
      expect(flushed.pendingFieldEdits, isEmpty);

      await bloc.close();
    });

    test(
      "unlinking the selected set removes its tab and selects the sequence's next first set",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final firstSetId = await createCase(bloc);
        bloc.add(const OcptShotListSetCreationRequestedEvent());
        final afterSecond = await waitForState(
          bloc,
          (state) => state.setsOfSelectedSequence.length == 2,
        );
        final secondSetId = afterSecond.selectedSetId!;
        expect(secondSetId, isNot(firstSetId));

        bloc.add(OcptShotListSetDeletionRequestedEvent(setId: secondSetId));
        final afterDelete = await waitForState(
          bloc,
          (state) => state.setsOfSelectedSequence.length == 1,
        );
        expect(afterDelete.selectedSetId, firstSetId);

        bloc.add(OcptShotListSetDeletionRequestedEvent(setId: firstSetId));
        final afterLastDelete = await waitForState(
          bloc,
          (state) => state.setsOfSelectedSequence.isEmpty,
        );
        expect(afterLastDelete.selectedSetId, isNull);

        await bloc.close();
      },
    );

    test("linking an existing set to another sequence adds it to that sequence's own tabs and "
        "selects it", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);
      final secondSequenceId = bloc.state.sequences[1].id;

      bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
      await waitForState(bloc, (state) => state.selectedSequenceId == secondSequenceId);
      expect(bloc.state.setsOfSelectedSequence, isEmpty);

      bloc.add(OcptShotListSetLinkRequestedEvent(setId: setId));
      final linked = await waitForState(bloc, (state) => state.setsOfSelectedSequence.isNotEmpty);

      expect(linked.setsOfSelectedSequence.single.id, setId);
      expect(linked.selectedSetId, setId);

      await bloc.close();
    });

    test("placing a set element writes a sequence-scoped symbol on the active layer", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(const OcptShotListFloorPlanActiveLayerChangedEvent(layer: OcptFloorPlanLayer.set));
      await waitForState(bloc, (state) => state.floorPlanActiveLayer == OcptFloorPlanLayer.set);

      bloc.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 1.5,
          yM: -2,
        ),
      );
      final state = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);

      final symbol = state.selectedSet!.symbols.single;
      expect(symbol.shotId, isNull);
      expect(symbol.layer, OcptFloorPlanLayer.set);
      expect(symbol.xM, 1.5);
      expect(symbol.yM, -2);
      expect(state.selectedFloorPlanSymbolId, symbol.id);

      await bloc.close();
    });

    test("the palette's own typed set-element entries each write their own setElementShape, and "
        "arming one becomes the click-to-arm default", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      // A drop from the palette carries its own shape on the event itself.
      bloc.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 0,
          yM: 0,
          setElementShape: OcptFloorPlanSetElementShape.wall,
        ),
      );
      final withWall = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      expect(
        withWall.selectedSet!.symbols.single.setElementShape,
        OcptFloorPlanSetElementShape.wall,
      );

      // Arming the door entry (click-to-arm) becomes the state's own default shape.
      bloc.add(
        const OcptShotListFloorPlanActiveSetElementShapeChangedEvent(
          shape: OcptFloorPlanSetElementShape.door,
        ),
      );
      await waitForState(
        bloc,
        (state) => state.floorPlanActiveSetElementShape == OcptFloorPlanSetElementShape.door,
      );

      bloc.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 1,
          yM: 1,
          setElementShape: OcptFloorPlanSetElementShape.door,
        ),
      );
      final withDoor = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
      final door = withDoor.selectedSet!.symbols.firstWhere((symbol) => symbol.xM == 1);
      expect(door.setElementShape, OcptFloorPlanSetElementShape.door);

      await bloc.close();
    });

    test("moving a symbol writes one row on drag end", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final symbolId = placed.selectedSet!.symbols.single.id;

      bloc.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: symbolId, xM: 3, yM: 4));
      final moved = await waitForState(bloc, (state) => state.selectedSet!.symbols.single.xM == 3);
      expect(moved.selectedSet!.symbols.single.yM, 4);

      await bloc.close();
    });

    test("resizing and rotating a symbol writes one row each", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final symbolId = placed.selectedSet!.symbols.single.id;

      bloc.add(
        OcptShotListFloorPlanSymbolResizedEvent(symbolId: symbolId, widthM: 1.2, heightM: 0.8),
      );
      final resized = await waitForState(
        bloc,
        (state) => state.selectedSet!.symbols.single.widthM == 1.2,
      );
      expect(resized.selectedSet!.symbols.single.heightM, 0.8);

      bloc.add(OcptShotListFloorPlanSymbolRotatedEvent(symbolId: symbolId, rotationDeg: 45));
      final rotated = await waitForState(
        bloc,
        (state) => state.selectedSet!.symbols.single.rotationDeg == 45,
      );
      expect(rotated.selectedSet!.symbols.single.id, symbolId);

      await bloc.close();
    });

    test("deleting a symbol removes it and clears its own selection", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
          sceneId: null,
          xM: 0,
          yM: 0,
        ),
      );
      final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final symbolId = placed.selectedFloorPlanSymbolId!;

      bloc.add(OcptShotListFloorPlanSymbolDeletionRequestedEvent(symbolId: symbolId));
      final deleted = await waitForState(bloc, (state) => state.selectedSet!.symbols.isEmpty);
      expect(deleted.selectedFloorPlanSymbolId, isNull);

      await bloc.close();
    });

    test("importing an underlay frames it at the default rectangle", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/plans/kitchen.png"),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(
        OcptShotListFloorPlanUnderlayImportRequestedEvent(setId: setId, fileTypeLabel: "Images"),
      );
      final state = await waitForState(bloc, (state) => state.selectedSet!.underlayAssetId != null);

      expect(state.selectedSet!.underlayPath, "/plans/kitchen.png");
      expect(state.selectedSet!.underlayWidthM, isNotNull);
      expect(state.selectedSet!.underlayHeightM, isNotNull);

      await bloc.close();
    });

    test("moving/resizing the underlay re-frames it through updateUnderlayFrame, minting or "
        "tombstoning no asset", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/plans/kitchen.png"),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(
        OcptShotListFloorPlanUnderlayImportRequestedEvent(setId: setId, fileTypeLabel: "Images"),
      );
      final imported = await waitForState(
        bloc,
        (state) => state.selectedSet!.underlayAssetId != null,
      );
      final assetId = imported.selectedSet!.underlayAssetId;
      final database = projectsManager.currentProject!.database;
      final assetsBeforeMove = await database.select(database.ocptAssetsTable).get();

      bloc.add(
        OcptShotListFloorPlanUnderlayTransformChangedEvent(
          setId: setId,
          xM: 2,
          yM: 1,
          widthM: 5,
          heightM: 3,
        ),
      );
      final transformed = await waitForState(
        bloc,
        (state) => state.selectedSet!.underlayWidthM == 5,
      );
      expect(transformed.selectedSet!.underlayXM, 2);
      expect(transformed.selectedSet!.underlayYM, 1);
      expect(transformed.selectedSet!.underlayHeightM, 3);
      expect(transformed.selectedSet!.underlayPath, "/plans/kitchen.png");
      // The very defect this fixes: dragging the underlay must never mint a fresh `assets` row
      // and tombstone the old one — it keeps writing the very same one.
      expect(transformed.selectedSet!.underlayAssetId, assetId);
      final assetsAfterMove = await database.select(database.ocptAssetsTable).get();
      expect(assetsAfterMove, hasLength(assetsBeforeMove.length));
      expect(assetsAfterMove.single.id, assetsBeforeMove.single.id);
      expect(assetsAfterMove.single.isDeleted, isFalse);

      await bloc.close();
    });

    test("clearing the underlay removes it", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/plans/kitchen.png"),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(
        OcptShotListFloorPlanUnderlayImportRequestedEvent(setId: setId, fileTypeLabel: "Images"),
      );
      await waitForState(bloc, (state) => state.selectedSet!.underlayAssetId != null);

      bloc.add(OcptShotListFloorPlanUnderlayClearRequestedEvent(setId: setId));
      final cleared = await waitForState(
        bloc,
        (state) => state.selectedSet!.underlayAssetId == null,
      );
      expect(cleared.selectedSet!.underlayPath, isNull);

      await bloc.close();
    });

    test("zoom, tool, active layer and layer visibility are session view state", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      expect(bloc.state.floorPlanZoom, 1);
      expect(bloc.state.floorPlanActiveTool, OcptFloorPlanTool.select);

      bloc.add(const OcptShotListFloorPlanZoomChangedEvent(zoom: 2));
      await waitForState(bloc, (state) => state.floorPlanZoom == 2);

      bloc.add(const OcptShotListFloorPlanToolSelectedEvent(tool: OcptFloorPlanTool.setElement));
      await waitForState(
        bloc,
        (state) => state.floorPlanActiveTool == OcptFloorPlanTool.setElement,
      );

      bloc.add(
        const OcptShotListFloorPlanActiveSetElementShapeChangedEvent(
          shape: OcptFloorPlanSetElementShape.freeform,
        ),
      );
      await waitForState(
        bloc,
        (state) => state.floorPlanActiveSetElementShape == OcptFloorPlanSetElementShape.freeform,
      );

      bloc.add(
        const OcptShotListFloorPlanLayerVisibilityToggledEvent(layer: OcptFloorPlanLayer.set),
      );
      final hidden = await waitForState(
        bloc,
        (state) => state.floorPlanHiddenLayers.contains(OcptFloorPlanLayer.set),
      );

      bloc.add(
        const OcptShotListFloorPlanLayerVisibilityToggledEvent(layer: OcptFloorPlanLayer.set),
      );
      final shown = await waitForState(
        bloc,
        (state) => !state.floorPlanHiddenLayers.contains(OcptFloorPlanLayer.set),
      );
      expect(hidden.floorPlanHiddenLayers, contains(OcptFloorPlanLayer.set));
      expect(shown.floorPlanHiddenLayers, isNot(contains(OcptFloorPlanLayer.set)));

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

      test("placing a camera/character/light symbol is shot-scoped to the focused shot", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final shotId = await createShot(bloc);

        for (final layer in [
          OcptFloorPlanLayer.cameras,
          OcptFloorPlanLayer.characters,
          OcptFloorPlanLayer.lights,
        ]) {
          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: layer,
              shotId: shotId,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          final placed = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.any((symbol) => symbol.layer == layer),
          );
          final symbol = placed.selectedSet!.symbols.firstWhere((symbol) => symbol.layer == layer);
          expect(symbol.shotId, shotId);
        }

        await bloc.close();
      });

      test(
        "two cameras placed on the same shot derive rank/letter labels (1A, 1B style)",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final shotId = await createShot(bloc);

          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.cameras,
              shotId: shotId,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 1);
          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.cameras,
              shotId: shotId,
              sceneId: null,
              xM: 1,
              yM: 1,
            ),
          );
          final state = await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

          // The derivation itself (`ocptFloorPlanCameraLabelOf`/`OcptFloorPlanSheet.of`) is a pure
          // rule already unit-tested on its own; this proves the production path — the bloc's own
          // writes through `OcptFloorPlanService.placeSymbol` — feeds it the right rows.
          final sheet = OcptFloorPlanSheet.of(
            floorPlanSet: state.selectedSet!,
            focusSceneId: state.selectedSequenceId!,
            focusShotId: shotId,
            shotRankByShotId: {shotId: 1},
          );
          final labels = sheet.symbols.map((symbol) => symbol.cameraLabel).toList()..sort();
          expect(labels, ["1A", "1B"]);

          await bloc.close();
        },
      );

      test("the arrow tool's own pending anchor completes a movement on the second tap, and "
          "Escape/the cancel event abandons it", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final shotId = await createShot(bloc);

        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.characters,
            shotId: shotId,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        final withFirst = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 1,
        );
        final firstSymbolId = withFirst.selectedSet!.symbols.single.id;

        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.characters,
            shotId: shotId,
            sceneId: null,
            xM: 2,
            yM: 2,
          ),
        );
        final withSecond = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 2,
        );
        final secondSymbolId = withSecond.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != firstSymbolId)
            .id;

        // First tap: picks the pending anchor, writes nothing.
        bloc.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: firstSymbolId));
        final anchored = await waitForState(
          bloc,
          (state) => state.pendingFloorPlanArrowAnchorSymbolId == firstSymbolId,
        );
        expect(anchored.selectedSet!.arrows, isEmpty);

        // Cancelled (mirrors `Escape`): the anchor is abandoned, still nothing written.
        bloc.add(const OcptShotListFloorPlanArrowAnchorCancelledEvent());
        final cancelled = await waitForState(
          bloc,
          (state) => state.pendingFloorPlanArrowAnchorSymbolId == null,
        );
        expect(cancelled.selectedSet!.arrows, isEmpty);

        // Re-anchor and complete on the second tap.
        bloc.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: firstSymbolId));
        await waitForState(
          bloc,
          (state) => state.pendingFloorPlanArrowAnchorSymbolId == firstSymbolId,
        );
        bloc.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: secondSymbolId));
        final completed = await waitForState(bloc, (state) => state.selectedSet!.arrows.isNotEmpty);
        expect(completed.pendingFloorPlanArrowAnchorSymbolId, isNull);
        expect(completed.selectedSet!.arrows.single.fromSymbolId, firstSymbolId);
        expect(completed.selectedSet!.arrows.single.toSymbolId, secondSymbolId);
        expect(completed.selectedSet!.arrows.single.shotId, shotId);

        bloc.add(
          OcptShotListFloorPlanArrowDeletionRequestedEvent(
            arrowId: completed.selectedSet!.arrows.single.id,
          ),
        );
        final deleted = await waitForState(bloc, (state) => state.selectedSet!.arrows.isEmpty);
        expect(deleted.selectedSet!.arrows, isEmpty);

        await bloc.close();
      });

      test("editing a symbol's label debounces then writes", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final shotId = await createShot(bloc);

        bloc.add(
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
        "per-camera visibility, onion skin and the metrics toggle are session view state",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          expect(bloc.state.isFloorPlanOnionSkinPreviousShown, isTrue);
          expect(bloc.state.isFloorPlanOnionSkinNextShown, isTrue);
          expect(bloc.state.isFloorPlanMetricsShown, isFalse);

          bloc.add(const OcptShotListFloorPlanCameraVisibilityToggledEvent(symbolId: "cam-1"));
          final hidden = await waitForState(
            bloc,
            (state) => state.floorPlanHiddenCameraSymbolIds.contains("cam-1"),
          );
          bloc.add(const OcptShotListFloorPlanCameraVisibilityToggledEvent(symbolId: "cam-1"));
          final shown = await waitForState(
            bloc,
            (state) => !state.floorPlanHiddenCameraSymbolIds.contains("cam-1"),
          );
          expect(hidden.floorPlanHiddenCameraSymbolIds, contains("cam-1"));
          expect(shown.floorPlanHiddenCameraSymbolIds, isNot(contains("cam-1")));

          bloc.add(const OcptShotListFloorPlanOnionSkinToggledEvent(isPrevious: true));
          final prevOff = await waitForState(
            bloc,
            (state) => !state.isFloorPlanOnionSkinPreviousShown,
          );
          expect(prevOff.isFloorPlanOnionSkinNextShown, isTrue);

          bloc.add(const OcptShotListFloorPlanOnionSkinOpacityChangedEvent(opacity: 0.7));
          final opacityChanged = await waitForState(
            bloc,
            (state) => state.floorPlanOnionSkinOpacity == 0.7,
          );
          expect(opacityChanged.floorPlanOnionSkinOpacity, 0.7);

          bloc.add(const OcptShotListFloorPlanMetricsToggledEvent());
          final metricsOn = await waitForState(bloc, (state) => state.isFloorPlanMetricsShown);
          expect(metricsOn.isFloorPlanMetricsShown, isTrue);

          await bloc.close();
        },
      );

      test("← / → walk the sequence's own shots, stopping at either end", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);

        final firstShotId = await createShot(bloc);
        final secondShotId = await createShot(bloc);
        expect(secondShotId, isNot(firstShotId));
        expect(bloc.state.selectedShotId, secondShotId);

        // Already the last shot: walking further does nothing.
        bloc.add(const OcptShotListFloorPlanShotWalkRequestedEvent(delta: 1));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state.selectedShotId, secondShotId);

        bloc.add(const OcptShotListFloorPlanShotWalkRequestedEvent(delta: -1));
        await waitForState(bloc, (state) => state.selectedShotId == firstShotId);

        // Already the first shot: walking backward does nothing.
        bloc.add(const OcptShotListFloorPlanShotWalkRequestedEvent(delta: -1));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state.selectedShotId, firstShotId);

        bloc.add(const OcptShotListFloorPlanShotWalkRequestedEvent(delta: 1));
        await waitForState(bloc, (state) => state.selectedShotId == secondShotId);

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

          bloc.add(
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
          expect(deleted.selectedFloorPlanSymbolId, isNull);

          await bloc.close();
        },
      );

      test("placing a character symbol arms the name prompt, dismissed clears it", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final shotId = await createShot(bloc);

        bloc.add(
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
        expect(placed.pendingCharacterNamePromptSymbolId, symbolId);

        bloc.add(const OcptShotListFloorPlanCharacterNamePromptDismissedEvent());
        final dismissed = await waitForState(
          bloc,
          (state) => state.pendingCharacterNamePromptSymbolId == null,
        );
        expect(dismissed.selectedSet!.symbols.single.id, symbolId);

        // A camera, a light or a set element never arms the prompt at all.
        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.cameras,
            shotId: shotId,
            sceneId: null,
            xM: 1,
            yM: 1,
          ),
        );
        final cameraPlaced = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 2,
        );
        expect(cameraPlaced.pendingCharacterNamePromptSymbolId, isNull);

        await bloc.close();
      });

      test(
        "changing a camera's field of view writes it (OcptShotListFloorPlanSymbolFovChangedEvent)",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final shotId = await createShot(bloc);

          bloc.add(
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

      test("selecting an arrow, bending it and straightening it back out writes the control "
          "point", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final shotId = await createShot(bloc);

        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.characters,
            shotId: shotId,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        final withFirst = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 1,
        );
        final firstSymbolId = withFirst.selectedSet!.symbols.single.id;

        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.characters,
            shotId: shotId,
            sceneId: null,
            xM: 2,
            yM: 2,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);

        bloc.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: firstSymbolId));
        await waitForState(
          bloc,
          (state) => state.pendingFloorPlanArrowAnchorSymbolId == firstSymbolId,
        );
        final secondSymbolId = bloc.state.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != firstSymbolId)
            .id;
        bloc.add(OcptShotListFloorPlanArrowSymbolTappedEvent(symbolId: secondSymbolId));
        final withArrow = await waitForState(bloc, (state) => state.selectedSet!.arrows.isNotEmpty);
        final arrowId = withArrow.selectedSet!.arrows.single.id;

        // Selecting the arrow is mutually exclusive with a symbol's own selection.
        bloc.add(OcptShotListFloorPlanSymbolSelectedEvent(symbolId: firstSymbolId));
        await waitForState(bloc, (state) => state.selectedFloorPlanSymbolId == firstSymbolId);
        bloc.add(OcptShotListFloorPlanArrowSelectedEvent(arrowId: arrowId));
        final selected = await waitForState(
          bloc,
          (state) => state.selectedFloorPlanArrowId == arrowId,
        );
        expect(selected.selectedFloorPlanSymbolId, isNull);

        bloc.add(
          OcptShotListFloorPlanArrowCurveChangedEvent(arrowId: arrowId, ctrlXM: 1.5, ctrlYM: 0.2),
        );
        final bent = await waitForState(
          bloc,
          (state) => state.selectedSet!.arrows.single.ctrlXM == 1.5,
        );
        expect(bent.selectedSet!.arrows.single.ctrlYM, 0.2);

        bloc.add(
          OcptShotListFloorPlanArrowCurveChangedEvent(arrowId: arrowId, ctrlXM: null, ctrlYM: null),
        );
        final straightened = await waitForState(
          bloc,
          (state) => state.selectedSet!.arrows.single.ctrlXM == null,
        );
        expect(straightened.selectedSet!.arrows.single.ctrlYM, isNull);

        bloc.add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: arrowId));
        final deletedArrow = await waitForState(bloc, (state) => state.selectedSet!.arrows.isEmpty);
        expect(deletedArrow.selectedFloorPlanArrowId, isNull);

        await bloc.close();
      });

      test("Ctrl+D duplicates a symbol offset from its source, an Alt-drag duplicates at the "
          "drag's own position, neither touching the source", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final shotId = await createShot(bloc);

        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.lights,
            shotId: shotId,
            sceneId: null,
            xM: 1,
            yM: 1,
          ),
        );
        final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final sourceId = placed.selectedSet!.symbols.single.id;

        // No explicit position (the `Ctrl+D` shortcut): offsets from the source.
        bloc.add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId));
        final duplicated = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 2,
        );
        expect(duplicated.selectedSet!.symbols.map((symbol) => symbol.id), contains(sourceId));
        final firstCopy = duplicated.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id != sourceId,
        );
        expect(firstCopy.xM, isNot(1));
        expect(firstCopy.layer, OcptFloorPlanLayer.lights);
        expect(duplicated.selectedFloorPlanSymbolId, firstCopy.id);
        // The source itself is untouched.
        expect(duplicated.selectedSet!.symbols.firstWhere((symbol) => symbol.id == sourceId).xM, 1);

        // An explicit position (an `Alt`-drag's own settled point) places the copy exactly
        // there instead of at the default offset.
        bloc.add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId, xM: 9, yM: -4));
        final secondDuplicate = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 3,
        );
        final secondCopy = secondDuplicate.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id != sourceId && symbol.id != firstCopy.id,
        );
        expect(secondCopy.xM, 9);
        expect(secondCopy.yM, -4);
        expect(
          secondDuplicate.selectedSet!.symbols.firstWhere((symbol) => symbol.id == sourceId).xM,
          1,
        );

        await bloc.close();
      });

      test("duplicating a camera carries its own field-of-view reach to the copy", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final shotId = await createShot(bloc);

        bloc.add(
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
        final sourceId = placed.selectedSet!.symbols.single.id;

        bloc.add(
          OcptShotListFloorPlanSymbolFovReachChangedEvent(symbolId: sourceId, fovReachM: 4.5),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.single.fovReachM == 4.5);

        bloc.add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId));
        final duplicated = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 2,
        );
        final copy = duplicated.selectedSet!.symbols.firstWhere((symbol) => symbol.id != sourceId);
        expect(copy.fovReachM, 4.5);

        await bloc.close();
      });
    });

    group("chrome and duplication", () {
      /// Creates a fresh shot on the sole selected sequence and returns its id, waiting for the
      /// selection to actually change — mirrors "the shot half" group's own helper.
      Future<String> createFreshShot(OcptShotListBloc bloc) async {
        final previousShotId = bloc.state.selectedShotId;
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        final created = await waitForState(
          bloc,
          (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
        );
        return created.selectedShotId!;
      }

      test("duplicating the selected set copies its own set-scope placements as independent rows, "
          "into a new Resources set linked to the same sequence, and selects the copy", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);

        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 1,
            yM: 2,
          ),
        );
        final withDecor = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.isNotEmpty,
        );
        final sourceSymbolId = withDecor.selectedSet!.symbols.single.id;

        bloc.add(OcptShotListSetDuplicationRequestedEvent(setId: setId, newSetName: "House copy"));
        final afterDuplicate = await waitForState(
          bloc,
          (state) => state.setsOfSelectedSequence.length == 2,
        );
        final newSetId = afterDuplicate.selectedSetId!;
        expect(newSetId, isNot(setId));
        expect(afterDuplicate.selectedSet!.name, "House copy");
        expect(afterDuplicate.selectedSet!.symbols, hasLength(1));
        final copiedSymbolId = afterDuplicate.selectedSet!.symbols.single.id;
        expect(copiedSymbolId, isNot(sourceSymbolId));

        // Independent: moving the copy leaves the source set's own symbol untouched.
        bloc.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: copiedSymbolId, xM: 9, yM: 9));
        await waitForState(bloc, (state) => state.selectedSet!.symbols.single.xM == 9);
        final sourceSet = bloc.state.setsOfSelectedSequence.firstWhere((s) => s.id == setId);
        expect(sourceSet.symbols.single.xM, 1);

        await bloc.close();
      });

      test(
        "copying another shot's own blocking writes independent copies onto the focused shot",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final sourceShotId = await createFreshShot(bloc);

          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.cameras,
              shotId: sourceShotId,
              sceneId: null,
              xM: 1,
              yM: 1,
            ),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);

          final destinationShotId = await createFreshShot(bloc);
          // The set's own symbols carry every shot's placements — only the destination shot's
          // own slice is still empty at this point.
          expect(
            bloc.state.selectedSet!.symbols.where((symbol) => symbol.shotId == destinationShotId),
            isEmpty,
          );

          bloc.add(
            OcptShotListFloorPlanBlockingCopyRequestedEvent(
              setId: setId,
              sourceShotId: sourceShotId,
            ),
          );
          final copied = await waitForState(
            bloc,
            (state) =>
                state.selectedSet!.symbols.any((symbol) => symbol.shotId == destinationShotId),
          );

          final destinationSymbols = copied.selectedSet!.symbols
              .where((symbol) => symbol.shotId == destinationShotId)
              .toList();
          expect(destinationSymbols, hasLength(1));
          final copiedSymbol = destinationSymbols.single;
          expect(copiedSymbol.layer, OcptFloorPlanLayer.cameras);

          // Independent: moving the copy leaves the source shot's own symbol untouched.
          bloc.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: copiedSymbol.id, xM: 5, yM: 5));
          await waitForState(
            bloc,
            (state) =>
                state.selectedSet!.symbols
                    .firstWhere((symbol) => symbol.id == copiedSymbol.id)
                    .xM ==
                5,
          );
          final sourceSymbol = bloc.state.selectedSet!.symbols.firstWhere(
            (symbol) => symbol.shotId == sourceShotId,
          );
          expect(sourceSymbol.xM, 1);

          await bloc.close();
        },
      );
    });

    group("the scope bubble", () {
      /// Links [setId] to the sequence's own second scene too, selects that second sequence, and
      /// returns its own id — building the "set linked to two sequences" fixture every test here
      /// needs, then the caller re-selects whichever sequence it actually wants focused.
      Future<String> linkSecondSequence(OcptShotListBloc bloc, String setId) async {
        final secondSequenceId = bloc.state.sequences[1].id;
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == secondSequenceId);
        bloc.add(OcptShotListSetLinkRequestedEvent(setId: setId));
        await waitForState(bloc, (state) => state.setsOfSelectedSequence.isNotEmpty);
        return secondSequenceId;
      }

      /// Places a wall on [setId], returns its id, and re-selects [sequenceId] once done — every
      /// test here starts from the wall already placed and the intended sequence focused.
      Future<String> placeWallAndFocus(
        OcptShotListBloc bloc, {
        required String setId,
        required String sequenceId,
      }) async {
        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final symbolId = placed.selectedFloorPlanSymbolId!;

        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: sequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == sequenceId);
        return symbolId;
      }

      test("a set-scope symbol on a set linked to a single sequence is never a scope-decision "
          "candidate — the mode dispatches the plain move event straight away, and this bloc has "
          "no notion of a pending decision to store one for", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final symbolId = await placeWallAndFocus(
          bloc,
          setId: setId,
          sequenceId: bloc.state.selectedSequenceId!,
        );

        bloc.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: symbolId, xM: 5, yM: 5));
        final moved = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.single.xM == 5,
        );
        expect(moved.pendingFloorPlanScopeDecision, isNull);

        await bloc.close();
      });

      test("OcptShotListFloorPlanScopeDecisionRequestedEvent only stores the pending decision — "
          "nothing is written until it is resolved", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
        await linkSecondSequence(bloc, setId);
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 9,
            yM: 9,
          ),
        );
        final pending = await waitForState(
          bloc,
          (state) => state.pendingFloorPlanScopeDecision != null,
        );

        expect(pending.pendingFloorPlanScopeDecision!.symbolId, symbolId);
        expect(pending.pendingFloorPlanScopeDecision!.sequenceCount, 2);
        // Nothing written yet: the original still sits at its own placed position.
        expect(pending.selectedSet!.symbols.single.xM, 0);

        await bloc.close();
      });

      test("cancel drops the pending decision, writing nothing at all", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
        await linkSecondSequence(bloc, setId);
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 9,
            yM: 9,
          ),
        );
        await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);

        bloc.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.cancel,
          ),
        );
        final resolved = await waitForState(
          bloc,
          (state) => state.pendingFloorPlanScopeDecision == null,
        );

        expect(resolved.selectedSet!.symbols, hasLength(1));
        expect(resolved.selectedSet!.symbols.single.xM, 0); // untouched

        await bloc.close();
      });

      test("every sequence writes the change onto the original itself", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
        await linkSecondSequence(bloc, setId);
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 9,
            yM: 9,
          ),
        );
        await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);

        bloc.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.every,
          ),
        );
        final resolved = await waitForState(
          bloc,
          (state) => state.pendingFloorPlanScopeDecision == null,
        );

        expect(resolved.selectedSet!.symbols, hasLength(1));
        final original = resolved.selectedSet!.symbols.single;
        expect(original.id, symbolId);
        expect(original.xM, 9);
        expect(original.yM, 9);
        expect(original.sceneId, isNull); // still set-scope, no override created

        await bloc.close();
      });

      test("only sequence n creates a scene-scope override of the focused sequence alone, leaving "
          "the original untouched", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
        await linkSecondSequence(bloc, setId);
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 9,
            yM: 9,
          ),
        );
        await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);

        bloc.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.only,
          ),
        );
        final resolved = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 2,
        );

        final original = resolved.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id == symbolId,
        );
        expect(original.xM, 0); // untouched
        expect(original.sceneId, isNull);

        final override = resolved.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id != symbolId,
        );
        expect(override.overridesSymbolId, symbolId);
        expect(override.sceneId, firstSequenceId);
        expect(override.xM, 9);
        expect(override.yM, 9);
        expect(override.isHidden, isFalse);

        await bloc.close();
      });

      test("only sequence n updates an override that already exists instead of creating a second "
          "one", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final firstSequenceId = bloc.state.selectedSequenceId!;
        final symbolId = await placeWallAndFocus(bloc, setId: setId, sequenceId: firstSequenceId);
        await linkSecondSequence(bloc, setId);
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

        // A first "only" resolution creates the override.
        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 9,
            yM: 9,
          ),
        );
        await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);
        bloc.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.only,
          ),
        );
        await waitForState(bloc, (state) => state.selectedSet!.symbols.length == 2);
        final overrideId = bloc.state.selectedSet!.symbols
            .firstWhere((symbol) => symbol.id != symbolId)
            .id;

        // A second "only" resolution, rotating it this time, updates that very same override.
        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            rotationDeg: 45,
          ),
        );
        await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);
        bloc.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.only,
          ),
        );
        final resolved = await waitForState(
          bloc,
          (state) =>
              state.selectedSet!.symbols
                  .firstWhere((symbol) => symbol.id == overrideId)
                  .rotationDeg ==
              45,
        );

        // Still only two symbols: no second override was created.
        expect(resolved.selectedSet!.symbols, hasLength(2));
        final override = resolved.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id == overrideId,
        );
        expect(override.xM, 9); // the move from before survives the later rotate
        expect(override.rotationDeg, 45);

        await bloc.close();
      });
    });

    group("restore / hide / delete everywhere", () {
      Future<String> linkSecondSequence(OcptShotListBloc bloc, String setId) async {
        final secondSequenceId = bloc.state.sequences[1].id;
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == secondSequenceId);
        bloc.add(OcptShotListSetLinkRequestedEvent(setId: setId));
        await waitForState(bloc, (state) => state.setsOfSelectedSequence.isNotEmpty);
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

          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.set,
              shotId: null,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
          final originalId = placed.selectedFloorPlanSymbolId!;

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
        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final originalId = placed.selectedFloorPlanSymbolId!;

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
        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: null,
            xM: 0,
            yM: 0,
          ),
        );
        final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        final originalId = placed.selectedFloorPlanSymbolId!;
        final secondSequenceId = await linkSecondSequence(bloc, setId);
        bloc.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
        await waitForState(bloc, (state) => state.selectedSequenceId == firstSequenceId);

        // "Only sequence n" first, creating a **visible** override.
        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: originalId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.sequence,
            sequenceCount: 2,
            xM: 3,
            yM: 3,
          ),
        );
        await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);
        bloc.add(
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
          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.set,
              shotId: null,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
          final originalId = placed.selectedFloorPlanSymbolId!;

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
          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.set,
              shotId: null,
              sceneId: null,
              xM: 0,
              yM: 0,
            ),
          );
          final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
          final originalId = placed.selectedFloorPlanSymbolId!;

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
    });

    group("the scope bubble, shot level", () {
      /// Creates a shot on the sole selected sequence and returns its id, waiting for the
      /// selection to actually change — mirrors "the shot half" group's own helper.
      Future<String> createShot(OcptShotListBloc bloc) async {
        final previousShotId = bloc.state.selectedShotId;
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        final created = await waitForState(
          bloc,
          (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
        );
        return created.selectedShotId!;
      }

      /// Places a plain scene-scope furniture item (no `overridesSymbolId` — never a sequence
      /// override) on [setId], for the sequence currently selected, and returns its id.
      Future<String> placeSceneFurniture(OcptShotListBloc bloc, String setId) async {
        final sceneId = bloc.state.selectedSequenceId!;
        bloc.add(
          OcptShotListFloorPlanSymbolPlacedEvent(
            setId: setId,
            layer: OcptFloorPlanLayer.set,
            shotId: null,
            sceneId: sceneId,
            xM: 0,
            yM: 0,
          ),
        );
        final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
        return placed.selectedFloorPlanSymbolId!;
      }

      test("a scene-scope symbol of a sequence with two or more shots is a scope-decision "
          "candidate at shot level", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final symbolId = await placeSceneFurniture(bloc, setId);
        final firstShotId = await createShot(bloc);
        await createShot(bloc);
        bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
        await waitForState(bloc, (state) => state.selectedShotId == firstShotId);

        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.shot,
            xM: 9,
            yM: 9,
          ),
        );
        final pending = await waitForState(
          bloc,
          (state) => state.pendingFloorPlanScopeDecision != null,
        );

        expect(pending.pendingFloorPlanScopeDecision!.symbolId, symbolId);
        expect(pending.pendingFloorPlanScopeDecision!.level, OcptFloorPlanOverrideLevel.shot);
        // Nothing written yet: the scene symbol still sits at its own placed position.
        expect(pending.selectedSet!.symbols.single.xM, 0);

        await bloc.close();
      });

      test("the whole sequence writes the change onto the scene-scope original itself", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final symbolId = await placeSceneFurniture(bloc, setId);
        await createShot(bloc);
        await createShot(bloc);

        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.shot,
            xM: 7,
            yM: 7,
          ),
        );
        await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);
        bloc.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.every,
          ),
        );
        final resolved = await waitForState(
          bloc,
          (state) => state.pendingFloorPlanScopeDecision == null,
        );

        expect(resolved.selectedSet!.symbols, hasLength(1));
        expect(resolved.selectedSet!.symbols.single.id, symbolId);
        expect(resolved.selectedSet!.symbols.single.xM, 7);

        await bloc.close();
      });

      test("only shot n creates a shot-scope override of the focused shot alone, leaving the "
          "scene symbol untouched", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final symbolId = await placeSceneFurniture(bloc, setId);
        final firstShotId = await createShot(bloc);
        await createShot(bloc);
        bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
        await waitForState(bloc, (state) => state.selectedShotId == firstShotId);

        bloc.add(
          OcptShotListFloorPlanScopeDecisionRequestedEvent(
            symbolId: symbolId,
            setId: setId,
            level: OcptFloorPlanOverrideLevel.shot,
            xM: 5,
            yM: 5,
          ),
        );
        await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);
        bloc.add(
          const OcptShotListFloorPlanScopeDecisionResolvedEvent(
            choice: OcptFloorPlanScopeChoice.only,
          ),
        );
        final resolved = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.length == 2,
        );

        final original = resolved.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id == symbolId,
        );
        final override = resolved.selectedSet!.symbols.firstWhere(
          (symbol) => symbol.id != symbolId,
        );
        expect(original.xM, 0);
        expect(override.overridesSymbolId, symbolId);
        expect(override.shotId, firstShotId);
        expect(override.sceneId, isNull);
        expect(override.xM, 5);

        await bloc.close();
      });

      test(
        "only shot n updates an override that already exists instead of creating a second one",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final symbolId = await placeSceneFurniture(bloc, setId);
          final firstShotId = await createShot(bloc);
          await createShot(bloc);
          bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));
          await waitForState(bloc, (state) => state.selectedShotId == firstShotId);

          for (final xM in [5.0, 6.0]) {
            bloc.add(
              OcptShotListFloorPlanScopeDecisionRequestedEvent(
                symbolId: symbolId,
                setId: setId,
                level: OcptFloorPlanOverrideLevel.shot,
                xM: xM,
                yM: 0,
              ),
            );
            await waitForState(bloc, (state) => state.pendingFloorPlanScopeDecision != null);
            bloc.add(
              const OcptShotListFloorPlanScopeDecisionResolvedEvent(
                choice: OcptFloorPlanScopeChoice.only,
              ),
            );
            await waitForState(
              bloc,
              (state) =>
                  state.pendingFloorPlanScopeDecision == null &&
                  state.selectedSet!.symbols.length == 2,
            );
          }

          final override = bloc.state.selectedSet!.symbols.firstWhere(
            (symbol) => symbol.id != symbolId,
          );
          expect(override.xM, 6);
          expect(bloc.state.selectedSet!.symbols, hasLength(2));

          await bloc.close();
        },
      );

      test("hiding a scene-scope symbol with no shot override yet creates a hidden one, masking "
          "it for the target shot", () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);
        final symbolId = await placeSceneFurniture(bloc, setId);
        final firstShotId = await createShot(bloc);
        await createShot(bloc);

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
