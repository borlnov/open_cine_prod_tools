// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_panel_size.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_floor_plan_sets_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_storyboard_bloc.dart';
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

/// The fixed device id every stamping test double in this file uses.
Future<String> _testDeviceId() async => "test-device";

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

/// A storyboard service whose panel creation, reordering and comment writes always fail, to exercise
/// the board's write error path.
class _FailingStoryboardService extends OcptStoryboardService {
  /// Class constructor
  const _FailingStoryboardService()
    : super(
        logger: const SilentLogger(),
        assetsService: const OcptAssetsService(logger: SilentLogger(), deviceId: _testDeviceId),
        deviceId: _testDeviceId,
      );

  @override
  Future<String?> addPanel({required OcptProjectDatabase database, required String shotId}) async =>
      throw StateError("panel creation intentionally failed for the test");

  @override
  Future<void> updatePanelComment({
    required OcptProjectDatabase database,
    required String panelId,
    required String comment,
  }) async => throw StateError("comment write intentionally failed for the test");
}

/// A storyboard service whose reads can be held back: while [heldReads] is positive, a read takes
/// its data from the database at once, then waits for [release] before answering, so what it
/// answers is older than the database by the time it arrives.
class _HoldingStoryboardService extends OcptStoryboardService {
  /// How many of the next reads are held back.
  int heldReads = 0;

  /// How many reads were held back so far.
  int holdCount = 0;

  final Completer<void> _release = Completer<void>();

  /// Class constructor
  _HoldingStoryboardService(OcptStoryboardService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        deviceId: source.deviceId,
      );

  /// Lets every held read answer.
  void release() => _release.complete();

  @override
  Future<OcptStoryboardSnapshot> loadStoryboard({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    final snapshot = await super.loadStoryboard(database: database, screenplayId: screenplayId);
    if (heldReads > 0) {
      heldReads--;
      holdCount++;
      await _release.future;
    }
    return snapshot;
  }
}

/// A storyboard service whose reads fail once [failsReads] is set, so the mode cannot read again
/// what the board has just written.
class _ReadFailingStoryboardService extends OcptStoryboardService {
  /// Whether the reads fail.
  bool failsReads = false;

  /// Class constructor
  _ReadFailingStoryboardService(OcptStoryboardService source)
    : super(
        logger: const SilentLogger(),
        assetsService: source.assetsService,
        deviceId: source.deviceId,
      );

  @override
  Future<OcptStoryboardSnapshot> loadStoryboard({
    required OcptProjectDatabase database,
    required String screenplayId,
  }) async {
    if (failsReads) {
      throw StateError("storyboard read intentionally failed for the test");
    }
    return super.loadStoryboard(database: database, screenplayId: screenplayId);
  }
}

/// A shot list service whose snapshot reads can be held back, like [_HoldingStoryboardService]'s.
class _HoldingShotListService extends OcptShotListService {
  /// How many of the next reads are held back.
  int heldReads = 0;

  /// How many reads were held back so far.
  int holdCount = 0;

  final Completer<void> _release = Completer<void>();

  /// Class constructor
  _HoldingShotListService(OcptShotListService source)
    : super(
        logger: const SilentLogger(),
        roleIndexService: source.roleIndexService,
        storyboardService: source.storyboardService,
        floorPlanService: source.floorPlanService,
        deviceId: source.deviceId,
      );

  /// Lets every held read answer.
  void release() => _release.complete();

  @override
  Future<OcptShotListSnapshot> loadShotList({
    required OcptProjectDatabase database,
    required String screenplayId,
    required int? episodeNumber,
  }) async {
    final snapshot = await super.loadShotList(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: episodeNumber,
    );
    if (heldReads > 0) {
      heldReads--;
      holdCount++;
      await _release.future;
    }
    return snapshot;
  }
}

void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";

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

    tempDir = await Directory.systemTemp.createTemp("ocpt_shot_list_storyboard_bloc_test_");
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

  /// Builds the mode bloc wired to the test project.
  OcptShotListBloc buildBloc({
    OcptStoryboardService? storyboardService,
    OcptShotListService? shotListService,
  }) => OcptShotListBloc(
    projectsManager: projectsManager,
    storyboardService: storyboardService,
    shotListService: shotListService,
    propertiesManager: propertiesManager,
    routerManager: _RecordingRouterManager(),
    exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
  );

  /// Builds the storyboard bloc of [modeBloc], picking frames through [fileSelectorManager] — a
  /// cancelled dialog unless the test says otherwise, so no test ever reaches a native one.
  OcptShotListStoryboardBloc buildBoard(
    OcptShotListBloc modeBloc, {
    FileSelectorManager fileSelectorManager = const _StubFileSelectorManager(pickedPath: null),
    OcptStoryboardService? storyboardService,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
  }) => OcptShotListStoryboardBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    storyboardService: storyboardService,
    fileSelectorManager: fileSelectorManager,
    fieldEditDebounce: fieldEditDebounce,
  );

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

  /// Waits until [isDone] holds, looking again every few milliseconds: for a condition that spans
  /// the mode bloc and the storyboard bloc, whose states change in an order a test must not depend
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

  /// Creates a shot in the first scene of [twoSceneText] and returns its id, waiting for the
  /// selection the creation event always makes.
  Future<String> createShot(OcptShotListBloc bloc) async {
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    return created.selectedShotId!;
  }

  /// Creates a set on the selected sequence of [mode] through a floor plan sets bloc, which it
  /// closes again, waiting for the mode to select the set. Answers the set's id.
  Future<String> createSet(OcptShotListBloc mode) async {
    final sets = OcptShotListFloorPlanSetsBloc(modeBloc: mode, projectsManager: projectsManager);
    final epoch = mode.state.selectionEpoch;
    sets.add(const OcptShotListSetCreationRequestedEvent());
    await waitUntil(() => mode.state.selectionEpoch > epoch);
    await sets.close();
    return mode.state.selectedSetId!;
  }

  /// Mounts both blocs on [twoSceneText] with one shot, and imports one panel onto it (selecting it,
  /// per the import handler), answering the blocs and the ids.
  Future<({OcptShotListBloc mode, OcptShotListStoryboardBloc board, String shotId, String panelId})>
  mountWithAPanel({
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
    OcptStoryboardService? storyboardService,
    OcptShotListService? shotListService,
  }) async {
    await writeScreenplay(twoSceneText);
    final mode = buildBloc(storyboardService: storyboardService, shotListService: shotListService);
    final board = buildBoard(
      mode,
      storyboardService: storyboardService,
      fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
      fieldEditDebounce: fieldEditDebounce,
    );
    await waitForState(mode, (state) => !state.isLoading);
    final shotId = await createShot(mode);

    board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));
    await waitUntil(
      () => mode.state.panelsOfShot(shotId).length == 1 && board.state.selectedPanelId != null,
    );

    return (
      mode: mode,
      board: board,
      shotId: shotId,
      panelId: mode.state.panelsOfShot(shotId).single.id,
    );
  }

  /// Closes the board and the mode, in the order the widget tree does.
  Future<void> closeAll(OcptShotListStoryboardBloc board, OcptShotListBloc mode) async {
    await board.close();
    await mode.close();
  }

  test("importing a frame appends a panel to the shot and selects it", () async {
    await writeScreenplay(twoSceneText);
    final mode = buildBloc();
    final board = buildBoard(
      mode,
      fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/shot.png"),
    );
    await waitForState(mode, (state) => !state.isLoading);
    final shotId = await createShot(mode);

    board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));
    await waitUntil(
      () => mode.state.panelsOfShot(shotId).length == 1 && board.state.selectedPanelId != null,
    );

    final panel = mode.state.panelsOfShot(shotId).single;
    expect(panel.imagePath, "/frames/shot.png");
    expect(panel.comment, isEmpty);
    expect(board.state.selectedPanelId, panel.id);

    await closeAll(board, mode);
  });

  test("a cancelled import leaves the shot with no panel", () async {
    await writeScreenplay(twoSceneText);
    final mode = buildBloc();
    final board = buildBoard(mode);
    await waitForState(mode, (state) => !state.isLoading);
    final shotId = await createShot(mode);

    board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));
    // Nothing to wait for: a cancellation emits no state of its own.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(mode.state.panelsOfShot(shotId), isEmpty);

    await closeAll(board, mode);
  });

  test("replacing a panel's image re-points it without changing its id", () async {
    final mounted = await mountWithAPanel();
    final mode = mounted.mode;

    mounted.board.add(
      OcptShotListPanelReplaceRequestedEvent(panelId: mounted.panelId, fileTypeLabel: "Images"),
    );
    // The stub always answers the very same path, so wait past the moment `addPanel`'s own
    // event lands and assert the panel count never grows: only its image is re-pointed.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(mode.state.panelsOfShot(mounted.shotId).single.id, mounted.panelId);
    expect(mode.state.panelsOfShot(mounted.shotId), hasLength(1));

    await closeAll(mounted.board, mode);
  });

  test("reordering a panel moves it to the requested position, writing one row", () async {
    final mounted = await mountWithAPanel();
    final mode = mounted.mode;
    final shotId = mounted.shotId;

    for (var i = 1; i < 3; i++) {
      mounted.board.add(
        OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
      );
      await waitUntil(() => mode.state.panelsOfShot(shotId).length == i + 1);
    }

    final panelIds = mode.state.panelsOfShot(shotId).map((panel) => panel.id).toList();

    // Moves the first panel (index 0) to the last position (index 2).
    mounted.board.add(
      OcptShotListPanelReorderedEvent(shotId: shotId, panelId: panelIds[0], newPosition: 2),
    );
    await waitUntil(() => mode.state.panelsOfShot(shotId).first.id != panelIds[0]);

    expect(mode.state.panelsOfShot(shotId).map((panel) => panel.id).toList(), [
      panelIds[1],
      panelIds[2],
      panelIds[0],
    ]);

    await closeAll(mounted.board, mode);
  });

  test(
    "a panel comment is visible as a pending value and writes once after the debounce",
    () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;
      final shotId = mounted.shotId;
      final panelId = mounted.panelId;

      board.add(OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Push in"));
      await waitUntil(
        () =>
            board.state.pendingFieldEdits[OcptShotListPanelCommentEditKey(panelId: panelId)] ==
            "Push in",
      );
      expect(mode.state.panelsOfShot(shotId).single.comment, isEmpty);

      await waitUntil(
        () =>
            mode.state.panelsOfShot(shotId).single.comment == "Push in" &&
            board.state.pendingFieldEdits.isEmpty,
      );
      expect(board.state.pendingFieldEdits, isEmpty);

      await closeAll(board, mode);
    },
  );

  test("selecting another shot flushes a pending panel comment edit immediately", () async {
    final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(seconds: 30));
    final mode = mounted.mode;
    final board = mounted.board;
    final firstShotId = mounted.shotId;
    final panelId = mounted.panelId;

    mode.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(mode, (state) => state.totalShotCount == 2);

    board.add(OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Handheld"));
    // Switches back to the shot that owns the panel just typed into — a genuine change of
    // selection, unlike reselecting the second shot.
    mode.add(OcptShotListShotSelectedEvent(shotId: firstShotId));

    await waitUntil(
      () =>
          mode.state.panelsOfShot(firstShotId).single.comment == "Handheld" &&
          board.state.pendingFieldEdits.isEmpty,
    );
    expect(board.state.pendingFieldEdits, isEmpty);

    await closeAll(board, mode);
  });

  test("deleting a panel removes it and clears the selection", () async {
    final mounted = await mountWithAPanel();
    final mode = mounted.mode;
    final board = mounted.board;

    board.add(OcptShotListPanelSelectedEvent(panelId: mounted.panelId));
    await waitUntil(() => board.state.selectedPanelId == mounted.panelId);

    board.add(OcptShotListPanelDeletionRequestedEvent(panelId: mounted.panelId));
    await waitUntil(
      () => mode.state.panelsOfShot(mounted.shotId).isEmpty && board.state.selectedPanelId == null,
    );
    expect(board.state.selectedPanelId, isNull);

    await closeAll(board, mode);
  });

  test("deleting the shot cascades its panels and drops its pending comment edit", () async {
    final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(seconds: 30));
    final mode = mounted.mode;
    final board = mounted.board;
    final shotId = mounted.shotId;
    final panelId = mounted.panelId;

    board.add(OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Never written"));
    await waitUntil(
      () =>
          board.state.pendingFieldEdits[OcptShotListPanelCommentEditKey(panelId: panelId)] ==
          "Never written",
    );

    mode.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
    await waitUntil(() => mode.state.totalShotCount == 0 && board.state.pendingFieldEdits.isEmpty);

    expect(board.state.pendingFieldEdits, isEmpty);
    expect(mode.state.storyboardSnapshot?.panelsOfShot(shotId), isEmpty);

    await closeAll(board, mode);
  });

  test("a captured panel is still there once its version is previewed, and once the preview "
      "is left", () async {
    // Dispatched to the very same, already-mounted blocs throughout — the path
    // `MixinOcptProjectVersionsBloc` actually uses (the Versions panel's own card),
    // mirroring `OcptResourcesBloc`'s own "a person created before the version is
    // captured, so it belongs to it" test. `OcptShotListBloc.reloadFromProjectDatabase`
    // is `_onLoadRequested`, which reads `_loadStoryboard` unconditionally, exactly as it
    // reads `_loadSnapshot` for the shots themselves — the board follows the identical
    // reload path a previewed version's shots already do.
    final mounted = await mountWithAPanel();
    final mode = mounted.mode;
    final shotId = mounted.shotId;

    mode.add(const OcptShotListCentreViewSelectedEvent(view: OcptShotListCentreView.board));

    mode.add(const OcptProjectVersionCreationRequestedEvent(name: "With a panel", note: ""));
    final withVersion = await waitForState(mode, (state) => state.projectVersions.isNotEmpty);
    final versionId = withVersion.projectVersions.single.id;

    mode.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
    final previewing = await waitForState(mode, (state) => state.previewedVersionId != null);

    expect(previewing.isPreviewingVersion, isTrue);
    expect(previewing.centreView, OcptShotListCentreView.board);
    final previewedPanels = previewing.panelsOfShot(shotId);
    expect(previewedPanels, hasLength(1));
    expect(previewedPanels.single.imagePath, "/frames/a.png");

    mode.add(const OcptProjectVersionPreviewExitRequestedEvent());
    final backToWorkingCopy = await waitForState(mode, (state) => state.previewedVersionId == null);

    expect(backToWorkingCopy.panelsOfShot(shotId), hasLength(1));

    await closeAll(mounted.board, mode);
  });

  group("annotations", () {
    test("picking a tool sets it, and picking null again turns it off", () async {
      final mounted = await mountWithAPanel();
      final board = mounted.board;

      board.add(
        const OcptShotListAnnotationToolSelectedEvent(
          tool: OcptStoryboardAnnotationTool.movementArrow,
        ),
      );
      await waitUntil(
        () => board.state.activeAnnotationTool == OcptStoryboardAnnotationTool.movementArrow,
      );
      expect(board.state.activeAnnotationTool, OcptStoryboardAnnotationTool.movementArrow);

      board.add(const OcptShotListAnnotationToolSelectedEvent(tool: null));
      await waitUntil(() => board.state.activeAnnotationTool == null);
      expect(board.state.activeAnnotationTool, isNull);

      await closeAll(board, mounted.mode);
    });

    test("drawing an arrow adds a mark of that kind, normalised, and selects it", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0.2,
          y1: 0.3,
          x2: 0.8,
          y2: 0.3,
        ),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.isNotEmpty &&
            board.state.selectedAnnotationId != null,
      );

      final mark = mode.state.panelsOfShot(mounted.shotId).single.annotations.single;
      expect(mark.kind, OcptStoryboardAnnotationKind.movementArrow);
      expect(mark.x1, 0.2);
      expect(mark.y1, 0.3);
      expect(mark.x2, 0.8);
      expect(mark.y2, 0.3);
      expect(board.state.selectedAnnotationId, mark.id);

      await closeAll(board, mode);
    });

    test(
      "placing a label adds it and selects it, and its text writes once after the debounce",
      () async {
        final mounted = await mountWithAPanel();
        final mode = mounted.mode;
        final board = mounted.board;

        board.add(OcptShotListAnnotationPlacedEvent(panelId: mounted.panelId, x1: 0.5, y1: 0.4));
        await waitUntil(
          () =>
              mode.state.panelsOfShot(mounted.shotId).single.annotations.isNotEmpty &&
              board.state.selectedAnnotationId != null,
        );
        final mark = mode.state.panelsOfShot(mounted.shotId).single.annotations.single;
        expect(mark.kind, OcptStoryboardAnnotationKind.label);
        expect(mark.x1, 0.5);
        expect(mark.y1, 0.4);
        expect(board.state.selectedAnnotationId, mark.id);

        // "Opens its text inline for editing": the mark is already selected once placed, ready
        // for the inspector's own text field to write into.
        board.add(
          OcptShotListAnnotationTextChangedEvent(annotationId: mark.id, rawValue: "Dolly in"),
        );
        await waitUntil(
          () =>
              board.state.pendingFieldEdits[OcptShotListAnnotationTextEditKey(
                annotationId: mark.id,
              )] ==
              "Dolly in",
        );
        expect(mode.state.panelsOfShot(mounted.shotId).single.annotations.single.text, isEmpty);

        await waitUntil(
          () =>
              mode.state.panelsOfShot(mounted.shotId).single.annotations.single.text ==
                  "Dolly in" &&
              board.state.pendingFieldEdits.isEmpty,
        );
        expect(board.state.pendingFieldEdits, isEmpty);

        await closeAll(board, mode);
      },
    );

    test("selecting a mark records its id", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0.1,
          y1: 0.1,
          x2: 0.3,
          y2: 0.1,
        ),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.length == 1 &&
            board.state.selectedAnnotationId != null,
      );
      final firstMarkId = board.state.selectedAnnotationId!;

      // Drawing a second mark auto-selects it instead, moving selection away from the first.
      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.cameraMoveArrow,
          x1: 0.5,
          y1: 0.5,
          x2: 0.7,
          y2: 0.5,
        ),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.length == 2 &&
            board.state.selectedAnnotationId != firstMarkId,
      );
      expect(board.state.selectedAnnotationId, isNot(firstMarkId));

      board.add(OcptShotListAnnotationSelectedEvent(annotationId: firstMarkId));
      await waitUntil(() => board.state.selectedAnnotationId == firstMarkId);
      expect(board.state.selectedAnnotationId, firstMarkId);

      await closeAll(board, mode);
    });

    test("deleting a mark removes it and clears its own selection", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0.2,
          y1: 0.2,
          x2: 0.6,
          y2: 0.2,
        ),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.isNotEmpty &&
            board.state.selectedAnnotationId != null,
      );
      final markId = board.state.selectedAnnotationId!;

      board.add(OcptShotListAnnotationDeletionRequestedEvent(annotationId: markId));
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).single.annotations.isEmpty &&
            board.state.selectedAnnotationId == null,
      );
      expect(board.state.selectedAnnotationId, isNull);

      await closeAll(board, mode);
    });

    test("deleting the panel cascades its marks and drops a pending mark-text edit", () async {
      final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(seconds: 30));
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(OcptShotListAnnotationPlacedEvent(panelId: mounted.panelId, x1: 0.5, y1: 0.5));
      await waitUntil(() => mode.state.panelsOfShot(mounted.shotId).single.annotations.isNotEmpty);
      final markId = mode.state.panelsOfShot(mounted.shotId).single.annotations.single.id;

      board.add(
        OcptShotListAnnotationTextChangedEvent(annotationId: markId, rawValue: "Never written"),
      );
      await waitUntil(
        () =>
            board.state.pendingFieldEdits[OcptShotListAnnotationTextEditKey(
              annotationId: markId,
            )] ==
            "Never written",
      );

      board.add(OcptShotListPanelDeletionRequestedEvent(panelId: mounted.panelId));
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).isEmpty &&
            board.state.pendingFieldEdits.isEmpty,
      );
      expect(board.state.pendingFieldEdits, isEmpty);

      await closeAll(board, mode);
    });

    test("selecting a different panel clears the active tool and the mark selection", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(
        OcptShotListAnnotationDrawnEvent(
          panelId: mounted.panelId,
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0.2,
          y1: 0.2,
          x2: 0.6,
          y2: 0.2,
        ),
      );
      await waitUntil(() => board.state.selectedAnnotationId != null);

      board.add(
        const OcptShotListAnnotationToolSelectedEvent(tool: OcptStoryboardAnnotationTool.label),
      );
      await waitUntil(() => board.state.activeAnnotationTool == OcptStoryboardAnnotationTool.label);

      // Importing onto the very same shot appends and selects a second panel.
      board.add(
        OcptShotListPanelImportRequestedEvent(shotId: mounted.shotId, fileTypeLabel: "Images"),
      );
      await waitUntil(
        () =>
            mode.state.panelsOfShot(mounted.shotId).length == 2 &&
            board.state.selectedPanelId != mounted.panelId,
      );

      expect(board.state.selectedPanelId, isNot(mounted.panelId));
      expect(board.state.activeAnnotationTool, isNull);
      expect(board.state.selectedAnnotationId, isNull);

      await closeAll(board, mode);
    });
  });

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it makes
    /// this fail to compile until the list below names it too.
    String nameOf(OcptShotListStoryboardEvent event) => switch (event) {
      OcptShotListPanelSelectedEvent() => "panel selected",
      OcptShotListPanelSizeChangedEvent() => "panel size",
      OcptShotListPanelImportRequestedEvent() => "import",
      OcptShotListPanelReplaceRequestedEvent() => "replace",
      OcptShotListPanelReorderedEvent() => "reorder",
      OcptShotListPanelCommentChangedEvent() => "comment",
      OcptShotListPanelDeletionRequestedEvent() => "panel deletion",
      OcptShotListAnnotationToolSelectedEvent() => "tool",
      OcptShotListAnnotationDrawnEvent() => "drawn",
      OcptShotListAnnotationPlacedEvent() => "placed",
      OcptShotListAnnotationSelectedEvent() => "annotation selected",
      OcptShotListAnnotationTextChangedEvent() => "annotation text",
      OcptShotListAnnotationDeletionRequestedEvent() => "annotation deletion",
      OcptShotListStoryboardFieldEditFlushRequestedEvent() => "flush",
      OcptShotListStoryboardWriteErrorDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final board = buildBoard(mode);
      await waitForState(mode, (state) => !state.isLoading);

      const events = <OcptShotListStoryboardEvent>[
        OcptShotListPanelSelectedEvent(panelId: "p"),
        OcptShotListPanelSizeChangedEvent(size: OcptStoryboardPanelSize.large),
        OcptShotListPanelImportRequestedEvent(shotId: "s", fileTypeLabel: "Images"),
        OcptShotListPanelReplaceRequestedEvent(panelId: "p", fileTypeLabel: "Images"),
        OcptShotListPanelReorderedEvent(shotId: "s", panelId: "p", newPosition: 0),
        OcptShotListPanelCommentChangedEvent(panelId: "p", rawValue: ""),
        OcptShotListPanelDeletionRequestedEvent(panelId: "p"),
        OcptShotListAnnotationToolSelectedEvent(tool: null),
        OcptShotListAnnotationDrawnEvent(
          panelId: "p",
          kind: OcptStoryboardAnnotationKind.movementArrow,
          x1: 0,
          y1: 0,
          x2: 1,
          y2: 1,
        ),
        OcptShotListAnnotationPlacedEvent(panelId: "p", x1: 0, y1: 0),
        OcptShotListAnnotationSelectedEvent(annotationId: "a"),
        OcptShotListAnnotationTextChangedEvent(annotationId: "a", rawValue: ""),
        OcptShotListAnnotationDeletionRequestedEvent(annotationId: "a"),
        OcptShotListStoryboardFieldEditFlushRequestedEvent(),
        OcptShotListStoryboardWriteErrorDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(15));

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => board.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await closeAll(board, mode);
    });

    test("the mode moving its selection clears the board's, by what moved it", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;
      final firstSequenceId = mode.state.selectedSequenceId!;
      final secondSequenceId = mode.state.sequences.last.id;

      Future<void> selectPanelAndTool() async {
        board.add(OcptShotListPanelSelectedEvent(panelId: mounted.panelId));
        board.add(
          const OcptShotListAnnotationToolSelectedEvent(tool: OcptStoryboardAnnotationTool.label),
        );
        await waitUntil(
          () =>
              board.state.selectedPanelId == mounted.panelId &&
              board.state.activeAnnotationTool != null,
        );
      }

      // The sequence already shown, selected again: nothing is cleared.
      await selectPanelAndTool();
      final epoch = mode.state.selectionEpoch;
      mode.add(OcptShotListSequenceSelectedEvent(sequenceId: firstSequenceId));
      await waitUntil(() => mode.state.selectionEpoch == epoch + 1);
      await pumpEventQueue();
      expect(board.state.selectedPanelId, mounted.panelId);
      expect(board.state.activeAnnotationTool, isNotNull);

      // A set selected: nothing is cleared either.
      await createSet(mode);
      mode.add(OcptShotListSetSelectedEvent(setId: mode.state.selectedSetId!));
      await waitUntil(() => mode.state.selectionCause == OcptShotListSelectionCause.set);
      await pumpEventQueue();
      expect(board.state.selectedPanelId, mounted.panelId);

      // The shot already selected, selected again: everything is cleared.
      mode.add(OcptShotListShotSelectedEvent(shotId: mounted.shotId));
      await waitUntil(() => board.state.selectedPanelId == null);
      expect(board.state.activeAnnotationTool, isNull);
      expect(board.state.selectedAnnotationId, isNull);

      // A different sequence: everything is cleared.
      await selectPanelAndTool();
      mode.add(OcptShotListSequenceSelectedEvent(sequenceId: secondSequenceId));
      await waitUntil(() => board.state.selectedPanelId == null);
      expect(board.state.activeAnnotationTool, isNull);

      await closeAll(board, mode);
    });

    test("no frame can be drawn between the mode's selection change and the board's", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;
      expect(board.state.selectedPanelId, mounted.panelId);

      // A frame is drawn in a task of the event loop of its own, so a task scheduled the moment the
      // mode's state is delivered stands for the next frame: what the board holds in it is what that
      // frame would draw. A reaction that waited for a timer, or for anything but microtasks, would
      // not have happened yet.
      final boardInTheNextTask = Completer<String?>();
      final subscription = mode.stream.listen((state) {
        if (state.selectionCause == OcptShotListSelectionCause.shot &&
            !boardInTheNextTask.isCompleted) {
          Timer.run(() => boardInTheNextTask.complete(board.state.selectedPanelId));
        }
      });

      mode.add(OcptShotListShotSelectedEvent(shotId: mounted.shotId));

      expect(await boardInTheNextTask.future.timeout(const Duration(seconds: 5)), isNull);

      await subscription.cancel();
      await closeAll(board, mode);
    });

    test("creating a shot, which selects it, leaves the board's panel selection alone", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;
      expect(board.state.selectedPanelId, mounted.panelId);
      final epoch = mode.state.selectionEpoch;

      mode.add(const OcptShotListShotCreationRequestedEvent());
      await waitUntil(() => mode.state.totalShotCount == 2);
      await pumpEventQueue();

      expect(mode.state.selectionEpoch, epoch + 1);
      expect(mode.state.selectionCause, OcptShotListSelectionCause.shotCreated);
      expect(board.state.selectedPanelId, mounted.panelId);

      await closeAll(board, mode);
    });

    test("a write waits for the mode to hold the row before the board selects it", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final board = buildBoard(
        mode,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
      );
      await waitForState(mode, (state) => !state.isLoading);
      final shotId = await createShot(mode);

      // What the mode held at the very moment the board first named a selected panel.
      final panelCountWhenSelected = board.stream
          .firstWhere((state) => state.selectedPanelId != null)
          .then((_) => mode.state.panelsOfShot(shotId).length);

      board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));

      expect(await panelCountWhenSelected.timeout(const Duration(seconds: 5)), 1);

      await closeAll(board, mode);
    });

    test(
      "a storyboard read that fails leaves the board's selection and edits as they were",
      () async {
        final service = _ReadFailingStoryboardService(projectsManager.storyboardService);
        final mounted = await mountWithAPanel(
          fieldEditDebounce: const Duration(days: 1),
          storyboardService: service,
        );
        final mode = mounted.mode;
        final board = mounted.board;
        board.add(OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "Kept"));
        await waitUntil(() => board.state.pendingFieldEdits.isNotEmpty);
        service.failsReads = true;

        /// Sends [event], waits for the mode's error and for the board to have had its say.
        Future<void> failWith(OcptShotListStoryboardEvent event) async {
          board.add(event);
          await waitUntil(() => mode.state.hasWriteError);
          await pumpEventQueue();
          mode.add(const OcptShotListWriteErrorDismissedEvent());
          await waitUntil(() => !mode.state.hasWriteError);
        }

        await failWith(
          OcptShotListPanelImportRequestedEvent(shotId: mounted.shotId, fileTypeLabel: "Images"),
        );
        expect(board.state.selectedPanelId, mounted.panelId);

        await failWith(
          OcptShotListAnnotationDrawnEvent(
            panelId: mounted.panelId,
            kind: OcptStoryboardAnnotationKind.movementArrow,
            x1: 0.2,
            y1: 0.3,
            x2: 0.8,
            y2: 0.3,
          ),
        );
        expect(board.state.selectedAnnotationId, isNull);

        await failWith(
          OcptShotListAnnotationPlacedEvent(panelId: mounted.panelId, x1: 0.5, y1: 0.5),
        );
        expect(board.state.selectedAnnotationId, isNull);

        await failWith(OcptShotListPanelDeletionRequestedEvent(panelId: mounted.panelId));
        expect(board.state.selectedPanelId, mounted.panelId);
        expect(board.state.pendingFieldEdits.values, ["Kept"]);

        await closeAll(board, mode);
      },
    );

    test("a reload the board did not ask for drops a pending edit whose panel is gone", () async {
      final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(days: 1));
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "Lost"));
      await waitUntil(() => board.state.pendingFieldEdits.isNotEmpty);

      // The panel goes away behind the board's back, then the mode reads the storyboard again.
      final project = projectsManager.currentProject!;
      await projectsManager.storyboardService.deletePanel(
        database: project.database,
        panelId: mounted.panelId,
      );
      await mode.reload({OcptShotListReloadScope.storyboard});

      await waitUntil(
        () => board.state.pendingFieldEdits.isEmpty && board.state.selectedPanelId == null,
      );

      await closeAll(board, mode);
    });

    test("entering a version preview, which reads everything again, clears the board", () async {
      final mounted = await mountWithAPanel();
      final mode = mounted.mode;
      final board = mounted.board;
      expect(board.state.selectedPanelId, mounted.panelId);

      mode.add(const OcptProjectVersionCreationRequestedEvent(name: "With a panel", note: ""));
      final withVersion = await waitForState(mode, (state) => state.projectVersions.isNotEmpty);
      mode.add(
        OcptProjectVersionPreviewRequestedEvent(versionId: withVersion.projectVersions.single.id),
      );
      await waitForState(mode, (state) => state.previewedVersionId != null);

      await waitUntil(() => board.state.selectedPanelId == null);
      expect(mode.state.selectionCause, OcptShotListSelectionCause.load);

      await closeAll(board, mode);
    });

    test(
      "a version preview writes the comment still being typed before it swaps the database",
      () async {
        final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(days: 1));
        final mode = mounted.mode;
        final board = mounted.board;

        board.add(
          OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "Typed"),
        );
        await waitUntil(() => board.state.pendingFieldEdits.isNotEmpty);

        mode.add(const OcptProjectVersionCreationRequestedEvent(name: "Typing", note: ""));
        await waitForState(mode, (state) => state.projectVersions.isNotEmpty);

        // The working copy holds the comment: the flush went through the mode, to the board.
        expect(board.state.pendingFieldEdits, isEmpty);
        expect(mode.state.panelsOfShot(mounted.shotId).single.comment, "Typed");

        await closeAll(board, mode);
      },
    );

    test("a flush asked while a reload is in flight writes the comment and settles", () async {
      final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(days: 1));
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "Both"));
      await waitUntil(() => board.state.pendingFieldEdits.isNotEmpty);

      final reload = mode.reload({OcptShotListReloadScope.storyboard});
      final flush = mode.flushAllPendingWrites();
      await Future.wait([reload, flush]).timeout(const Duration(seconds: 5));

      expect(board.state.pendingFieldEdits, isEmpty);
      expect(mode.state.panelsOfShot(mounted.shotId).single.comment, "Both");

      await closeAll(board, mode);
    });

    test(
      "a comment still being typed is written whichever of the board and the mode closes first",
      () async {
        for (final boardFirst in [true, false]) {
          final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(days: 1));
          final mode = mounted.mode;
          final board = mounted.board;

          board.add(
            OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "Kept"),
          );
          await waitUntil(() => board.state.pendingFieldEdits.isNotEmpty);

          if (boardFirst) {
            await board.close();
            await mode.close();
          } else {
            await mode.close();
            await board.close();
          }

          final project = projectsManager.currentProject!;
          final snapshot = await projectsManager.storyboardService.loadStoryboard(
            database: project.database,
            screenplayId: project.primaryScreenplayId,
          );
          expect(
            snapshot.panelsOfShot(mounted.shotId).single.comment,
            "Kept",
            reason: boardFirst ? "board closed first" : "mode closed first",
          );

          // The next round starts from a project without that panel.
          await projectsManager.storyboardService.deletePanel(
            database: project.database,
            panelId: mounted.panelId,
          );
        }
      },
    );

    test("closing the mode while an import waits for it neither hangs nor throws", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final board = buildBoard(
        mode,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
      );
      await waitForState(mode, (state) => !state.isLoading);
      final shotId = await createShot(mode);

      board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));
      await mode.close().timeout(const Duration(seconds: 5));
      await board.close().timeout(const Duration(seconds: 5));
    });

    test("a failing write raises the board's own write error, which can be dismissed", () async {
      await writeScreenplay(twoSceneText);
      final mode = buildBloc();
      final board = buildBoard(
        mode,
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
        storyboardService: const _FailingStoryboardService(),
      );
      await waitForState(mode, (state) => !state.isLoading);
      final shotId = await createShot(mode);

      board.add(OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"));
      await waitUntil(() => board.state.hasWriteError);
      expect(mode.state.hasWriteError, isFalse, reason: 'the mode did not fail');

      board.add(const OcptShotListStoryboardWriteErrorDismissedEvent());
      await waitUntil(() => !board.state.hasWriteError);

      await closeAll(board, mode);
    });

    test("a write that reads while another read lands does not roll the epochs back", () async {
      final service = _HoldingShotListService(projectsManager.shotListService);
      final mounted = await mountWithAPanel(shotListService: service);
      final mode = mounted.mode;
      final epoch = mode.state.reloadEpoch;

      // Creating a shot reads the snapshot and is held there, holding the state it started from.
      service.heldReads = 1;
      mode.add(const OcptShotListShotCreationRequestedEvent());
      await waitUntil(() => service.holdCount == 1);

      // Meanwhile the storyboard changes and the mode reads it.
      final project = projectsManager.currentProject!;
      await projectsManager.storyboardService.updatePanelComment(
        database: project.database,
        panelId: mounted.panelId,
        comment: "Meanwhile",
      );
      final reload = mode.reload({OcptShotListReloadScope.storyboard});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mode.state.reloadEpoch, epoch, reason: 'the read waits for the creation before it');

      service.release();
      await reload.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(mode.state.reloadEpoch, greaterThan(epoch));
      expect(mode.state.panelsOfShot(mounted.shotId).single.comment, "Meanwhile");

      await closeAll(mounted.board, mode);
    });

    test("a comment typed while the board's flush is in flight is kept and written", () async {
      final service = _HoldingStoryboardService(projectsManager.storyboardService);
      final mounted = await mountWithAPanel(
        fieldEditDebounce: const Duration(days: 1),
        storyboardService: service,
      );
      final mode = mounted.mode;
      final board = mounted.board;

      board.add(OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "a"));
      await waitUntil(() => board.state.pendingFieldEdits.isNotEmpty);

      // The flush writes "a" and is held while the mode reads it back.
      service.heldReads = 1;
      final flush = board.flushPendingWrites();
      await waitUntil(() => service.holdCount == 1);

      board.add(OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "ab"));
      await waitUntil(() => board.state.pendingFieldEdits.values.contains("ab"));
      service.release();
      await flush;

      expect(board.state.pendingFieldEdits.values, ["ab"], reason: 'the keystroke is not lost');
      await board.flushPendingWrites();
      expect(mode.state.panelsOfShot(mounted.shotId).single.comment, "ab");

      await closeAll(board, mode);
    });

    test("a flush finishing after the mode started closing asks it for nothing", () async {
      final service = _HoldingStoryboardService(projectsManager.storyboardService);
      final mounted = await mountWithAPanel(storyboardService: service);
      final mode = mounted.mode;
      final board = mounted.board;

      // With the Versions tab open, a landed flush asks the mode to refresh its working copy.
      mode.add(const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.versions));
      await waitUntil(() => mode.state.rightDockTab == OcptShotListRightDockTab.versions);

      // The debounce fires, the comment is written, and the read that follows is held.
      service.heldReads = 1;
      board.add(OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "Late"));
      await waitUntil(() => service.holdCount == 1);

      // The mode starts closing while the board still waits for that read.
      final closing = mode.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      service.release();
      await closing.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await board.close();
    });

    test("a full reload does not put an older storyboard over a newer one", () async {
      final service = _HoldingStoryboardService(projectsManager.storyboardService);
      final mounted = await mountWithAPanel(
        fieldEditDebounce: const Duration(days: 1),
        storyboardService: service,
      );
      final mode = mounted.mode;
      final board = mounted.board;

      // The mode loads everything again (what a version preview does), and its read of the
      // storyboard, made while the comment is still empty, is held.
      final selectionEpochBefore = mode.state.selectionEpoch;
      service.heldReads = 1;
      mode.add(const OcptShotListLoadRequestedEvent());
      await waitUntil(() => service.holdCount == 1);

      // Meanwhile the board writes a comment and has the mode read it.
      board.add(OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "Newer"));
      await waitUntil(() => board.state.pendingFieldEdits.isNotEmpty);
      final boardFlush = board.flushPendingWrites();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      service.release();
      await boardFlush.timeout(const Duration(seconds: 5));
      // The load is the only thing that moves the selection epoch here.
      await waitUntil(() => mode.state.selectionEpoch > selectionEpochBefore);

      expect(mode.state.panelsOfShot(mounted.shotId).single.comment, "Newer");

      await closeAll(board, mode);
    });

    test("a failing comment write raises the write error and forgets the comment", () async {
      await writeScreenplay(twoSceneText);
      final mounted = await mountWithAPanel(fieldEditDebounce: const Duration(days: 1));
      final mode = mounted.mode;
      await mounted.board.close();
      final board = buildBoard(
        mode,
        storyboardService: const _FailingStoryboardService(),
        fieldEditDebounce: const Duration(days: 1),
      );

      board.add(OcptShotListPanelCommentChangedEvent(panelId: mounted.panelId, rawValue: "Nope"));
      await waitUntil(() => board.state.pendingFieldEdits.isNotEmpty);
      await mode.flushAllPendingWrites();

      expect(board.state.hasWriteError, isTrue);
      expect(board.state.pendingFieldEdits, isEmpty);

      await closeAll(board, mode);
    });
  });
}
