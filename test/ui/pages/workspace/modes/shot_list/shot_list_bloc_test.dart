// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
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

/// A shot list service whose [createShot] always fails, to exercise the bloc's write error path.
class _FailingShotListService extends OcptShotListService {
  /// Class constructor
  const _FailingShotListService();

  @override
  Future<String> createShot({
    required OcptProjectDatabase database,
    required String screenplayId,
    required String sceneId,
  }) async => throw StateError("shot creation intentionally failed for the test");
}

/// A shot coverage service whose [addRange] always fails, to exercise the bloc's coverage write
/// error path.
class _FailingShotCoverageService extends OcptShotCoverageService {
  /// Class constructor
  const _FailingShotCoverageService();

  @override
  Future<String> addRange({
    required OcptProjectDatabase database,
    required String shotId,
    required String sceneId,
    required int startOffset,
    required int endOffset,
    required String sceneText,
  }) async => throw StateError("coverage write intentionally failed for the test");
}

/// An export manager whose two exports are stubbed and whose calls are recorded, so the bloc's
/// export paths can be exercised without any real native dialog, workbook or PDF write.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({this.exportResult, this.fails = false})
    : super(fileSelectorManager: const FileSelectorManager());

  /// The path either export returns, or null to simulate a cancelled save dialog.
  final String? exportResult;

  /// Whether either export throws, to exercise the bloc's export failure path.
  final bool fails;

  /// The snapshot of the last export call, of either kind.
  OcptShotListSnapshot? lastExportedSnapshot;

  /// The labels of the last [exportShotListXlsx] call.
  OcptShotListXlsxLabels? lastExportedLabels;

  /// The project name of the last export call, of either kind.
  String? lastExportedProjectName;

  /// The file type label of the last export call, of either kind.
  String? lastExportedFileTypeLabel;

  /// The episode tag of the last export call, of either kind.
  String? lastExportedEpisodeTag;

  /// The screenplay text of the last [exportScenarioCoverage] call.
  String? lastCoverageScreenplayText;

  /// The parsed document of the last [exportScenarioCoverage] call.
  FountainDocument? lastCoverageDocument;

  /// The page setup of the last [exportScenarioCoverage] call.
  OcptPageSetup? lastCoveragePageSetup;

  /// The labels of the last [exportScenarioCoverage] call.
  OcptScenarioCoverageLabels? lastCoverageLabels;

  /// The four content toggles of the last [exportScenarioCoverage] call.
  ({bool sceneNumbers, bool titlePage, bool legendPage, bool summaryPage})? lastCoverageToggles;

  @override
  Future<OcptExportOutcome?> exportShotListXlsx({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedSnapshot = snapshot;
    lastExportedLabels = labels;
    lastExportedProjectName = projectName;
    lastExportedFileTypeLabel = fileTypeLabel;
    lastExportedEpisodeTag = episodeTag;

    if (fails) {
      throw StateError("shot list export intentionally failed for the test");
    }

    final result = exportResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportScenarioCoverage({
    required FountainDocument document,
    required String screenplayText,
    required OcptShotListSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptScenarioCoverageLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required bool includeLegendPage,
    required bool includeSummaryPage,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedSnapshot = snapshot;
    lastExportedProjectName = projectName;
    lastExportedFileTypeLabel = fileTypeLabel;
    lastExportedEpisodeTag = episodeTag;
    lastCoverageDocument = document;
    lastCoverageScreenplayText = screenplayText;
    lastCoveragePageSetup = pageSetup;
    lastCoverageLabels = labels;
    lastCoverageToggles = (
      sceneNumbers: includeSceneNumbers,
      titlePage: includeTitlePage,
      legendPage: includeLegendPage,
      summaryPage: includeSummaryPage,
    );

    if (fails) {
      throw StateError("scenario coverage export intentionally failed for the test");
    }

    final result = exportResult;
    return result == null ? null : OcptExportSaved(result);
  }
}

/// The labels the export tests dispatch, standing in for what `ocptShotListXlsxLabelsOf` builds
/// from a real `Tr`: the bloc only carries them through to the manager.
const _exportLabels = OcptShotListXlsxLabels(
  sheetName: "Shot list",
  columnHeaders: {},
  statusLabels: {},
  sequenceTitles: {},
  dayTagPrefix: "D",
);

/// The labels the scenario coverage export tests dispatch, standing in for what
/// `ocptScenarioCoverageLabelsOf` builds from a real `Tr`: the bloc only carries them through to the
/// manager.
const _coverageLabels = OcptScenarioCoverageLabels(
  fileNameSuffix: "coverage",
  legendTitle: "Shot legend",
  legendShotHeader: "Shot",
  legendShotSizeHeader: "Shot size",
  legendFramingHeader: "Framing & composition",
  legendCameraMoveHeader: "Camera move",
  summaryTitle: "Coverage summary",
  summarySequenceHeader: "Sequence",
  summaryShotCountHeader: "Shots",
  summaryCoveredHeader: "Covered",
  summaryStaleHeader: "To check",
  summaryUncoveredHeader: "Uncovered passages",
  laneOverflowNote: "Some pages ran out of lanes.",
  sequenceTitles: {},
);

/// The options the scenario coverage export tests dispatch, standing in for what the mode's own
/// options dialog returns.
const _coverageOptions = OcptScenarioCoverageExportOptions(
  format: OcptPageFormat.a4,
  margins: FountainPageMargins.standard(),
  includeSceneNumbers: true,
  includeTitlePage: false,
  includeLegendPage: true,
  includeSummaryPage: false,
);

void main() {
  const twoSceneText = "INT. HOUSE - DAY\n\nAction one.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";
  const dialogueText = "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
      "EXT. GARDEN - NIGHT\n\nAction two.\n";
  const twoCharactersText = "INT. HOUSE - DAY\n\nAction one.\n\nLÉA\nHello there.\n\n"
      "MARC\nHello back.\n";
  const oneCharacterLeftText = "INT. HOUSE - DAY\n\nAction one.\n\nMARC\nHello back.\n";
  // ELISA is introduced in capitals in an action line and never speaks: the screenwriting
  // convention for a character's first appearance, and the only way a silent role is ever named.
  const silentCharacterText = "INT. HOUSE - DAY\n\nELISA entre dans la pièce.\n\nLÉA\n"
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
    await propertiesManager.shotListVisibleColumns.store(
      OcptShotListColumn.defaultVisibleColumns,
    );
    await propertiesManager.shotListLeftDockFraction.store(
      OcptWorkspaceDock.leftDefaultFraction,
    );
    await propertiesManager.shotListRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );
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
  /// tests exercising the field-edit debounce don't have to wait out the real 2 s one,
  /// [exportManager] to a [_FakeExportManager] whose export cancels, so no test ever reaches a
  /// native save dialog, and [overrideProjectsManager] lets a test swap in a manager of its own
  /// (already holding an open project), for the one that needs to observe its calls.
  OcptShotListBloc buildBloc({
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptShotListService? shotListService,
    OcptShotCoverageService? shotCoverageService,
    OcptProjectsManager? overrideProjectsManager,
    Duration fieldEditDebounce = const Duration(milliseconds: 30),
    String? selectedEpisodeId,
  }) => OcptShotListBloc(
    projectsManager: overrideProjectsManager ?? projectsManager,
    propertiesManager: propertiesManager,
    routerManager: routerManager ?? _RecordingRouterManager(),
    exportManager: exportManager ?? _FakeExportManager(),
    shotListService: shotListService,
    shotCoverageService: shotCoverageService,
    fieldEditDebounce: fieldEditDebounce,
    selectedEpisodeId: selectedEpisodeId,
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

  /// Dispatches the two word clicks that draw a scenario coverage range across every word of
  /// [block] on shot [shotId] (first word opens the anchor, last word closes it), waiting for the
  /// anchor to land after the first click and for the range to land after the second.
  Future<void> drawCoverageRange(
    OcptShotListBloc bloc, {
    required String shotId,
    required OcptScriptWordBlock block,
  }) async {
    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: block.words.first.startOffset,
        wordEndOffset: block.words.first.endOffset,
      ),
    );
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: block.words.last.startOffset,
        wordEndOffset: block.words.last.endOffset,
      ),
    );
    await waitForState(
      bloc,
      (state) => state.snapshot!.shotsById[shotId]!.coverageRanges.isNotEmpty,
    );
  }

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

  test(
    'constructed with a second episode selected, reads and writes that episode rather than the '
    'primary screenplay',
    () async {
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
      expect((state.sequences.single as OcptSceneShotSequence).heading, "INT. SECOND EPISODE - NIGHT");

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
    },
  );

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

    bloc.add(
      const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata),
    );
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.metadata);

    // Selecting the active tab again closes the dock, but still remembers it.
    bloc.add(
      const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata),
    );
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
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created2 = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created2.selectedShotId!;

    // Only the mount above has captured so far (creating a shot is not a version operation);
    // waiting out the throttle window guarantees the tab selection below actually captures rather
    // than being silently skipped.
    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));
    final beforeTabSelected = countingManager.captureCount;

    bloc.add(
      const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.versions),
    );
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.versions);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(countingManager.captureCount, beforeTabSelected + 1);

    // Clear the throttle again, then flush a field edit while the tab opened above is still the
    // active one.
    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));
    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Wide",
      ),
    );
    await waitForState(bloc, (state) => state.selectedShot!.shotSize == "Wide");
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(countingManager.captureCount, beforeTabSelected + 2);

    await bloc.close();
    await countingManager.disposeLifeCycle();
  });

  test('the last right dock tab is persisted and restored on the next entry', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(
      const OcptShotListRightDockTabSelectedEvent(tab: OcptShotListRightDockTab.metadata),
    );
    await waitForState(bloc, (state) => state.rightDockTab == OcptShotListRightDockTab.metadata);
    await bloc.close();

    final reopenedBloc = buildBloc();
    final state = await waitForState(reopenedBloc, (state) => !state.isLoading);

    // The dock itself starts closed on every entry; only which tab it reopens on is remembered.
    expect(state.rightDockTab, isNull);
    expect(state.lastRightDockTab, OcptShotListRightDockTab.metadata);

    await reopenedBloc.close();
  });

  test('toggling a column persists the visible set, and it is restored on the next entry',
      () async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    expect(bloc.state.visibleColumns, OcptShotListColumn.defaultVisibleColumns);

    bloc.add(const OcptShotListColumnToggledEvent(column: OcptShotListColumn.lens));
    await waitForState(bloc, (state) => state.visibleColumns.contains(OcptShotListColumn.lens));

    bloc.add(const OcptShotListColumnToggledEvent(column: OcptShotListColumn.status));
    await waitForState(bloc, (state) => !state.visibleColumns.contains(OcptShotListColumn.status));
    await bloc.close();

    final reopenedBloc = buildBloc();
    final state = await waitForState(reopenedBloc, (state) => !state.isLoading);

    expect(state.visibleColumns, contains(OcptShotListColumn.lens));
    expect(state.visibleColumns, isNot(contains(OcptShotListColumn.status)));
    expect(state.visibleColumns, contains(OcptShotListColumn.duration));

    await reopenedBloc.close();
  });

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
    var state = await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 1);

    bloc.add(
      OcptShotListShotCharacterToggledEvent(shotId: state.selectedShotId!, characterName: "ELISA"),
    );
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.isNotEmpty);

    expect(state.selectedShot!.characters, ["ELISA"]);
    expect(state.removedCharacterAlerts, isEmpty);

    await bloc.close();
  });

  test('a typed field edit is visible as a pending value and writes once after the debounce',
      () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "W",
      ),
    );
    var state = await waitForState(
      bloc,
      (state) => state.pendingFieldEdits[(shotId, OcptShotListEditableField.shotSize)] == "W",
    );
    // Not written yet: still the field's default empty value.
    expect(state.selectedShot!.shotSize, isEmpty);

    // A second keystroke before the debounce elapses restarts it rather than firing twice: only
    // the last value typed is ever written.
    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Wide",
      ),
    );
    state = await waitForState(
      bloc,
      (state) => state.pendingFieldEdits[(shotId, OcptShotListEditableField.shotSize)] == "Wide",
    );
    expect(state.selectedShot!.shotSize, isEmpty);

    state = await waitForState(bloc, (state) => state.selectedShot!.shotSize == "Wide");
    expect(state.pendingFieldEdits, isEmpty);

    await bloc.close();
  });

  test('committing a shot size deduces the abbreviation once, then never again', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Plan moyen",
      ),
    );
    var state = await waitForState(bloc, (state) => state.selectedShot!.shotSize == "Plan moyen");
    expect(state.selectedShot!.abbreviation, "PM");

    // A later shot size never overwrites the abbreviation the shot already carries.
    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Gros plan",
      ),
    );
    state = await waitForState(bloc, (state) => state.selectedShot!.shotSize == "Gros plan");
    expect(state.selectedShot!.abbreviation, "PM");

    await bloc.close();
  });

  test('an abbreviation typed in the same flush wins over the deduced one', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Plan moyen",
      ),
    );
    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.abbreviation,
        rawValue: "PMS",
      ),
    );

    final state = await waitForState(bloc, (state) => state.selectedShot!.shotSize == "Plan moyen");
    expect(state.selectedShot!.abbreviation, "PMS");

    await bloc.close();
  });

  test('selecting another shot flushes a pending field edit immediately', () async {
    await writeScreenplay(twoSceneText);

    // A debounce long enough that the assertions below could only pass through the flush the
    // selection change performs, never through the debounce elapsing on its own.
    final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 5));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final firstShotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: firstShotId,
        field: OcptShotListEditableField.notes,
        rawValue: "Handheld",
      ),
    );
    await waitForState(
      bloc,
      (state) =>
          state.pendingFieldEdits[(firstShotId, OcptShotListEditableField.notes)] == "Handheld",
    );

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 2);

    expect(state.pendingFieldEdits, isEmpty);
    expect(state.snapshot!.shotsById[firstShotId]!.notes, "Handheld");

    await bloc.close();
  });

  test('flushPendingFieldEdits writes a pending edit directly, without touching state', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(fieldEditDebounce: const Duration(seconds: 5));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.sound,
        rawValue: "Wind noise",
      ),
    );
    await waitForState(
      bloc,
      (state) => state.pendingFieldEdits[(shotId, OcptShotListEditableField.sound)] == "Wind noise",
    );

    await bloc.flushPendingFieldEdits();

    // This flush never touches the bloc's own state...
    expect(bloc.state.pendingFieldEdits, isNotEmpty);
    // ...but the database already has the write.
    final reloaded = await projectsManager.shotListService.loadShotList(
      database: projectsManager.currentProject!.database,
      screenplayId: projectsManager.currentProject!.primaryScreenplayId,
      episodeNumber: null,
    );
    expect(reloaded.shotsById[shotId]!.sound, "Wind noise");

    await bloc.close();
  });

  test('a difficulty axis and a character toggle each write immediately', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotDifficultyChangedEvent(
        shotId: shotId,
        axis: OcptShotDifficultyAxis.sound,
        value: 4,
      ),
    );
    state = await waitForState(bloc, (state) => state.selectedShot!.difficultySound == 4);

    bloc.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, characterName: "LÉA"));
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.contains("LÉA"));

    bloc.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, characterName: "LÉA"));
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.isEmpty);

    await bloc.close();
  });

  /// Attaches [characterNames] to a freshly created shot of the first sequence, then closes the
  /// bloc that did it, and returns the new shot's derived code.
  ///
  /// The deleted-character tests all need the same starting point: a shot carrying characters the
  /// screenplay is then edited to no longer speak. The bloc reads the screenplay's speaking
  /// characters once, on entry, so a fresh bloc is what sees the edited screenplay — which is also
  /// what happens in the app, where the shot list mode is mounted anew every time it is switched
  /// to.
  Future<String> createShotWithCharacters(List<String> characterNames) async {
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    for (final characterName in characterNames) {
      bloc.add(
        OcptShotListShotCharacterToggledEvent(shotId: shotId, characterName: characterName),
      );
      state = await waitForState(
        bloc,
        (state) => state.selectedShot!.characters.contains(characterName),
      );
    }

    final code = state.selectedShot!.code;
    await bloc.close();

    return code;
  }

  test('a character the screenplay dropped is reported, then removable everywhere', () async {
    await writeScreenplay(twoCharactersText);
    final shotCode = await createShotWithCharacters(["LÉA", "MARC"]);

    await writeScreenplay(oneCharacterLeftText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.removedCharacterAlerts, hasLength(1));
    expect(state.removedCharacterAlerts.single.characterName, "LÉA");
    expect(state.removedCharacterAlerts.single.shotCodes, [shotCode]);

    bloc.add(const OcptShotListRemovedCharacterDroppedEvent(characterName: "LÉA"));
    state = await waitForState(bloc, (state) => state.removedCharacterAlerts.isEmpty);

    // The character still spoken is left untouched by the removal.
    expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

    await bloc.close();
  });

  test('a dropped character can be replaced by a still-speaking one on every shot', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA"]);

    await writeScreenplay(oneCharacterLeftText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);
    expect(state.removedCharacterAlerts, hasLength(1));

    bloc.add(
      const OcptShotListRemovedCharacterReplacedEvent(
        characterName: "LÉA",
        replacementName: "MARC",
      ),
    );
    state = await waitForState(bloc, (state) => state.removedCharacterAlerts.isEmpty);

    expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

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

  test('a first coverage click sets the pending anchor and writes nothing', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    final firstWord = actionBlock.words.first;

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    state = await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    expect(state.pendingCoverageAnchor!.wordStartOffset, actionBlock.startOffset);
    expect(state.pendingCoverageAnchor!.wordStartOffset, firstWord.startOffset);
    expect(state.selectedShot!.coverageRanges, isEmpty);

    await bloc.close();
  });

  test('a second click in the same block writes a range covering both words', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(bloc, shotId: shotId, block: actionBlock);
    state = bloc.state;

    expect(state.pendingCoverageAnchor, isNull);
    final range = state.selectedShot!.coverageRanges.single;
    expect(range.sceneId, layout.sceneId);
    expect(range.startOffset, actionBlock.words.first.startOffset);
    expect(range.endOffset, actionBlock.words.last.endOffset);

    await bloc.close();
  });

  test('closing a range over dialogue attaches the characters it covers', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;
    expect(state.selectedShot!.characters, isEmpty);

    final layout = state.buildSelectedCoverageLayout()!;
    final dialogueBlock = layout.blocks.firstWhere((block) => block.text == "Hello there.");

    await drawCoverageRange(bloc, shotId: shotId, block: dialogueBlock);
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.isNotEmpty);

    // The cue itself is outside the range: the speaker is named by their dialogue alone.
    expect(state.selectedShot!.characters, ["LÉA"]);

    await bloc.close();
  });

  test('a range covering no dialogue attaches nobody', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(bloc, shotId: shotId, block: actionBlock);
    state = bloc.state;

    expect(state.selectedShot!.coverageRanges, hasLength(1));
    expect(state.selectedShot!.characters, isEmpty);

    await bloc.close();
  });

  test('removing a range keeps the characters it had attached', () async {
    await writeScreenplay(dialogueText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final dialogueBlock = layout.blocks.firstWhere((block) => block.text == "Hello there.");

    await drawCoverageRange(bloc, shotId: shotId, block: dialogueBlock);
    await waitForState(bloc, (state) => state.selectedShot!.characters.isNotEmpty);

    bloc.add(OcptShotListCoverageClearRequestedEvent(shotId: shotId));
    state = await waitForState(bloc, (state) => state.selectedShot!.coverageRanges.isEmpty);

    // Attaching is one-way: only the user takes a character off a shot.
    expect(state.selectedShot!.characters, ["LÉA"]);

    await bloc.close();
  });

  test('a click on a covered word with no anchor removes that range', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    await drawCoverageRange(bloc, shotId: shotId, block: actionBlock);

    final firstWord = actionBlock.words.first;
    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: firstWord.startOffset,
        wordEndOffset: firstWord.endOffset,
      ),
    );
    state = await waitForState(bloc, (state) => state.selectedShot!.coverageRanges.isEmpty);
    expect(state.pendingCoverageAnchor, isNull);

    await bloc.close();
  });

  test("a second click in another block closes a range spanning both", () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final headingBlock = layout.blocks.firstWhere((block) => block.text == "INT. HOUSE - DAY");
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: headingBlock.words.first.startOffset,
        wordEndOffset: headingBlock.words.first.endOffset,
      ),
    );
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.last.startOffset,
        wordEndOffset: actionBlock.words.last.endOffset,
      ),
    );
    state = await waitForState(
      bloc,
      (state) => state.selectedShot!.coverageRanges.isNotEmpty,
    );

    final range = state.selectedShot!.coverageRanges.single;
    expect(range.startOffset, headingBlock.words.first.startOffset);
    expect(range.endOffset, actionBlock.words.last.endOffset);
    // The range genuinely runs through both blocks, blank line included.
    expect(layout.blocksSpannedBy(range), [headingBlock, actionBlock]);
    expect(state.pendingCoverageAnchor, isNull);

    await bloc.close();
  });

  test("a range drawn next to an existing one merges with it", () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final heading = layout.blocks.firstWhere((block) => block.text == "INT. HOUSE - DAY");

    Future<void> drawWord(OcptScriptWord word) async {
      final rangeCountBefore = state.selectedShot!.coverageRanges.length;
      for (var click = 0; click < 2; click++) {
        bloc.add(
          OcptShotListCoverageWordClickedEvent(
            shotId: shotId,
            wordStartOffset: word.startOffset,
            wordEndOffset: word.endOffset,
          ),
        );
      }
      state = await waitForState(
        bloc,
        (state) =>
            state.pendingCoverageAnchor == null &&
            state.selectedShot!.coverageRanges.length != rangeCountBefore - 1,
      );
    }

    // Two one-word ranges, drawn separately on two words a single space apart.
    await drawWord(heading.words[0]);
    await drawWord(heading.words[1]);

    final range = state.selectedShot!.coverageRanges.single;
    expect(layout.sceneText.substring(range.startOffset, range.endOffset), "INT. HOUSE");

    await bloc.close();
  });

  test("clearing coverage drops only the cleared shot's ranges", () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotAId = state.selectedShotId!;
    var layout = state.buildSelectedCoverageLayout()!;
    var actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(bloc, shotId: shotAId, block: actionBlock);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 2);
    final shotBId = state.selectedShotId!;
    layout = state.buildSelectedCoverageLayout()!;
    actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(bloc, shotId: shotBId, block: actionBlock);

    bloc.add(OcptShotListCoverageClearRequestedEvent(shotId: shotAId));
    state = await waitForState(
      bloc,
      (state) => state.snapshot!.shotsById[shotAId]!.coverageRanges.isEmpty,
    );

    expect(state.snapshot!.shotsById[shotBId]!.coverageRanges, isNotEmpty);

    await bloc.close();
  });

  test(
      'marking a shot as checked clears needsCheck and re-stamps digests so a following '
      'staleness pass stays quiet', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final created = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = created.selectedShotId!;

    final layout = created.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    await drawCoverageRange(bloc, shotId: shotId, block: actionBlock);
    await bloc.close();

    // Changing the scene's body (its heading is untouched, so the scene keeps its own id) makes
    // the recorded range's digest disagree with the text under it, raising needsCheck on save.
    const modifiedText =
        "INT. HOUSE - DAY\n\nAction one revised.\n\nEXT. GARDEN - NIGHT\n\nAction two.\n";
    await writeScreenplay(modifiedText);

    final reopenedBloc = buildBloc();
    var state = await waitForState(reopenedBloc, (state) => !state.isLoading);
    var shot = state.snapshot!.shotsById[shotId]!;
    expect(shot.needsCheck, isTrue);
    expect(shot.checkReason, OcptShotCheckReason.coveredTextChanged);

    reopenedBloc.add(OcptShotListShotMarkedAsCheckedEvent(shotId: shotId));
    state = await waitForState(
      reopenedBloc,
      (state) => !state.snapshot!.shotsById[shotId]!.needsCheck,
    );
    expect(state.pendingCoverageAnchor, isNull);

    await reopenedBloc.close();

    // Saving the very same (already stale-inducing) text again re-runs the staleness pass; the
    // digests were just re-stamped to it, so it stays quiet this time.
    await writeScreenplay(modifiedText);
    final finalBloc = buildBloc();
    final finalState = await waitForState(finalBloc, (state) => !state.isLoading);
    shot = finalState.snapshot!.shotsById[shotId]!;
    expect(shot.needsCheck, isFalse);
    expect(shot.checkReason, isNull);

    await finalBloc.close();
  });

  test('the pending coverage anchor is cleared when another shot is selected', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final firstShotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");
    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: firstShotId,
        wordStartOffset: actionBlock.words.first.startOffset,
        wordEndOffset: actionBlock.words.first.endOffset,
      ),
    );
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    state = await waitForState(bloc, (state) => state.totalShotCount == 2);

    expect(state.pendingCoverageAnchor, isNull);
    expect(state.selectedShotId, isNot(firstShotId));

    await bloc.close();
  });

  test('a coverage write failure surfaces as the transient write error', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(shotCoverageService: const _FailingShotCoverageService());
    await waitForState(bloc, (state) => !state.isLoading);
    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    final layout = state.buildSelectedCoverageLayout()!;
    final actionBlock = layout.blocks.firstWhere((block) => block.text == "Action one.");

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.first.startOffset,
        wordEndOffset: actionBlock.words.first.endOffset,
      ),
    );
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(
      OcptShotListCoverageWordClickedEvent(
        shotId: shotId,
        wordStartOffset: actionBlock.words.last.startOffset,
        wordEndOffset: actionBlock.words.last.endOffset,
      ),
    );
    state = await waitForState(bloc, (state) => state.hasWriteError);
    expect(state.pendingCoverageAnchor, isNull);
    expect(state.selectedShot!.coverageRanges, isEmpty);

    await bloc.close();
  });

  test('exporting the shot list hands the loaded snapshot to the export manager', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie.xlsx");
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    bloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
        episodeTag: "ep. 2",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.xlsxExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie.xlsx");
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "Excel workbook");
    expect(exportManager.lastExportedEpisodeTag, "ep. 2");
    expect(exportManager.lastExportedLabels, _exportLabels);
    // The whole shot list travels, not only the selected sequence.
    expect(exportManager.lastExportedSnapshot!.sequences, hasLength(2));
    expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);

    bloc.add(const OcptShotListIoNoticeDismissedEvent());
    final dismissedState = await waitForState(bloc, (state) => state.ioNotice == null);
    expect(dismissedState.hasWriteError, isFalse);

    await bloc.close();
  });

  test('exporting flushes a pending field edit first, so the workbook holds it', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie.xlsx");
    final bloc = buildBloc(exportManager: exportManager, fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Close-up",
      ),
    );
    await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

    bloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.pendingFieldEdits, isEmpty);
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Close-up");

    await bloc.close();
  });

  test('a cancelled save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(exportManager: _FakeExportManager());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    // Nothing to wait for: a cancellation emits no state of its own, so the assertion is that the
    // bloc settles back with no notice once the export has had time to resolve.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('a failing export raises the transient export failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(exportManager: _FakeExportManager(fails: true));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.xlsxExportFailed);
    expect(state.ioNotice!.path, isNull);

    await bloc.close();
  });

  test('exporting the scenario coverage hands the screenplay and its options to the manager',
      () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - coverage.pdf");
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    bloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: _coverageOptions,
        labels: _coverageLabels,
        fileTypeLabel: "PDF document",
        episodeTag: "ep. 2",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.scenarioCoverageExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie - coverage.pdf");
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "PDF document");
    expect(exportManager.lastExportedEpisodeTag, "ep. 2");
    expect(exportManager.lastCoverageLabels, _coverageLabels);
    // The document travels alongside the very text it was parsed from: a coverage range addresses
    // that text by character offset.
    expect(exportManager.lastCoverageScreenplayText, twoSceneText);
    expect(exportManager.lastCoverageDocument!.blocks, isNotEmpty);
    // The dialog's format wins over the project's own, and its margins are carried through.
    expect(exportManager.lastCoveragePageSetup!.format, OcptPageFormat.a4);
    expect(exportManager.lastCoveragePageSetup!.margins, _coverageOptions.margins);
    expect(
      exportManager.lastCoverageToggles,
      (sceneNumbers: true, titlePage: false, legendPage: true, summaryPage: false),
    );
    expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);

    await bloc.close();
  });

  test('exporting the scenario coverage flushes a pending field edit first', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - coverage.pdf");
    final bloc = buildBloc(exportManager: exportManager, fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Gros plan",
      ),
    );
    await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

    bloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: _coverageOptions,
        labels: _coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.pendingFieldEdits, isEmpty);
    // The legend prints the shot size the user typed seconds ago, and the abbreviation deduced
    // from it alongside.
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Gros plan");
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.abbreviation, "GP");

    await bloc.close();
  });

  test('a cancelled coverage save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(exportManager: _FakeExportManager());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: _coverageOptions,
        labels: _coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    // Nothing to wait for: a cancellation emits no state of its own, so the assertion is that the
    // bloc settles back with no notice once the export has had time to resolve.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('a failing coverage export raises its own transient failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(exportManager: _FakeExportManager(fails: true));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: _coverageOptions,
        labels: _coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.scenarioCoverageExportFailed);
    expect(state.ioNotice!.path, isNull);

    await bloc.close();
  });
}
