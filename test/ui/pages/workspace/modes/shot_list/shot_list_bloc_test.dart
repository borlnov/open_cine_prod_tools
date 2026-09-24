// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:act_dart_result/act_dart_result.dart';
import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_storyboard_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_word_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_tool.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_pending_edit_key.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_tool.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
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

/// The fixed device id every stamping test double in this file uses.
Future<String> _testDeviceId() async => "test-device";

/// A shot list service whose [createShot] always fails, to exercise the bloc's write error path.
class _FailingShotListService extends OcptShotListService {
  /// Class constructor
  const _FailingShotListService()
    : super(
        roleIndexService: const OcptRoleIndexService(
          elementsService: OcptElementsService(
            assetsService: OcptAssetsService(deviceId: _testDeviceId),
            deviceId: _testDeviceId,
          ),
          roleCandidatesService: OcptRoleCandidatesService(deviceId: _testDeviceId),
          deviceId: _testDeviceId,
        ),
        storyboardService: const OcptStoryboardService(
          assetsService: OcptAssetsService(deviceId: _testDeviceId),
          deviceId: _testDeviceId,
        ),
        floorPlanService: const OcptFloorPlanService(
          assetsService: OcptAssetsService(deviceId: _testDeviceId),
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

/// A shot coverage service whose [addRange] always fails, to exercise the bloc's coverage write
/// error path.
class _FailingShotCoverageService extends OcptShotCoverageService {
  /// Class constructor
  const _FailingShotCoverageService() : super(deviceId: _testDeviceId);

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

  /// The storyboard snapshot of the last [exportStoryboard] call.
  OcptStoryboardSnapshot? lastStoryboardSnapshot;

  /// The labels of the last [exportStoryboard] call.
  OcptStoryboardLabels? lastStoryboardLabels;

  /// The `shotsPerPage`/`includeFloorPlansAfterEachSequence` options of the last
  /// [exportStoryboard] call.
  ({int shotsPerPage, bool includeFloorPlans})? lastStoryboardOptions;

  /// The floor plan snapshot handed to the last [exportStoryboard] call (may be null even when
  /// [lastStoryboardOptions]' `includeFloorPlans` is false).
  OcptFloorPlanSnapshot? lastStoryboardFloorPlanSnapshot;

  /// The floor plan snapshot of the last [exportFloorPlans] call.
  OcptFloorPlanSnapshot? lastFloorPlanSnapshot;

  /// The labels of the last [exportFloorPlans] call.
  OcptFloorPlanLabels? lastFloorPlanLabels;

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

  @override
  Future<OcptExportOutcome?> exportStoryboard({
    required OcptShotListSnapshot snapshot,
    required OcptStoryboardSnapshot storyboardSnapshot,
    required OcptPageSetup pageSetup,
    required OcptStoryboardLabels labels,
    required String projectName,
    required int shotsPerPage,
    required bool includeFloorPlansAfterEachSequence,
    OcptFloorPlanSnapshot? floorPlanSnapshot,
    OcptFloorPlanLabels? floorPlanLabels,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedSnapshot = snapshot;
    lastExportedProjectName = projectName;
    lastExportedFileTypeLabel = fileTypeLabel;
    lastExportedEpisodeTag = episodeTag;
    lastStoryboardSnapshot = storyboardSnapshot;
    lastStoryboardLabels = labels;
    lastStoryboardOptions = (
      shotsPerPage: shotsPerPage,
      includeFloorPlans: includeFloorPlansAfterEachSequence,
    );
    lastStoryboardFloorPlanSnapshot = floorPlanSnapshot;

    if (fails) {
      throw StateError("storyboard export intentionally failed for the test");
    }

    final result = exportResult;
    return result == null ? null : OcptExportSaved(result);
  }

  @override
  Future<OcptExportOutcome?> exportFloorPlans({
    required OcptShotListSnapshot snapshot,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
    required OcptPageSetup pageSetup,
    required OcptFloorPlanLabels labels,
    required String projectName,
    required String fileTypeLabel,
    String? episodeTag,
    Rect? shareAnchor,
  }) async {
    lastExportedSnapshot = snapshot;
    lastExportedProjectName = projectName;
    lastExportedFileTypeLabel = fileTypeLabel;
    lastExportedEpisodeTag = episodeTag;
    lastFloorPlanSnapshot = floorPlanSnapshot;
    lastFloorPlanLabels = labels;

    if (fails) {
      throw StateError("floor plans export intentionally failed for the test");
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

/// The labels the storyboard export tests dispatch, standing in for what
/// `ocptStoryboardLabelsOf` builds from a real `Tr`: the bloc only carries them through to the
/// manager.
const _storyboardLabels = OcptStoryboardLabels(
  fileNameSuffix: "storyboard",
  documentTitle: "Storyboard",
  shotSizeLabel: "Shot size",
  framingLabel: "Framing",
  cameraMoveLabel: "Camera move",
  lensLabel: "Lens",
  recordingFormatLabel: "Format",
  castLabel: "Cast",
  statusLabels: {},
  noPanelNote: "no panel yet",
  fileNotFoundNote: "File not found",
  sequenceTitles: {},
);

/// The labels the floor plans export tests dispatch, standing in for what `ocptFloorPlanLabelsOf`
/// builds from a real `Tr`: the bloc only carries them through to the manager.
const _floorPlanLabels = OcptFloorPlanLabels(
  fileNameSuffix: "floor plans",
  documentTitle: "Floor plans",
  shotSizeLabel: "Shot size",
  framingLabel: "Framing",
  cameraMoveLabel: "Camera move",
  lensLabel: "Lens",
  recordingFormatLabel: "Format",
  castLabel: "Cast",
  statusLabels: {},
  sequenceTitles: {},
  noCameraNote: "No camera placed on this case yet.",
  scaleBarUnitLabel: "m",
);

/// The options the storyboard export tests dispatch, standing in for what the mode's own options
/// dialog returns.
const _storyboardOptions = OcptStoryboardExportOptions(
  format: OcptPageFormat.a4,
  margins: FountainPageMargins.standard(),
  shotsPerPage: 2,
  includeFloorPlansAfterEachSequence: false,
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
    exportManager: exportManager ?? _FakeExportManager(),
    shotListService: shotListService,
    shotCoverageService: shotCoverageService,
    storyboardService: storyboardService,
    floorPlanService: floorPlanService,
    fileSelectorManager: fileSelectorManager,
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

    final elisaRoleId = state.roles.firstWhere((role) => role.name == "ELISA").id;
    bloc.add(
      OcptShotListShotCharacterToggledEvent(shotId: state.selectedShotId!, roleId: elisaRoleId),
    );
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.isNotEmpty);

    expect(state.selectedShot!.characters, ["ELISA"]);
    expect(state.orphanedRoleAlerts, isEmpty);

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
      (state) => state.pendingFieldEdits[OcptShotListShotFieldEditKey(shotId: shotId, field: OcptShotListEditableField.shotSize)] == "W",
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
      (state) => state.pendingFieldEdits[OcptShotListShotFieldEditKey(shotId: shotId, field: OcptShotListEditableField.shotSize)] == "Wide",
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
          state.pendingFieldEdits[OcptShotListShotFieldEditKey(shotId: firstShotId, field: OcptShotListEditableField.notes)] == "Handheld",
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
      (state) => state.pendingFieldEdits[OcptShotListShotFieldEditKey(shotId: shotId, field: OcptShotListEditableField.sound)] == "Wind noise",
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

    final leaRoleId = state.roles.firstWhere((role) => role.name == "LÉA").id;
    bloc.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: leaRoleId));
    state = await waitForState(bloc, (state) => state.selectedShot!.characters.contains("LÉA"));

    bloc.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: leaRoleId));
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
      final roleId = state.roles.firstWhere((role) => role.name == characterName).id;
      bloc.add(OcptShotListShotCharacterToggledEvent(shotId: shotId, roleId: roleId));
      state = await waitForState(
        bloc,
        (state) => state.selectedShot!.characters.contains(characterName),
      );
    }

    final code = state.selectedShot!.code;
    await bloc.close();

    return code;
  }

  test('an orphaned role is reported, then deletable everywhere', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA", "MARC"]);

    await writeScreenplay(oneCharacterLeftText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);

    expect(state.orphanedRoleAlerts, hasLength(1));
    expect(state.orphanedRoleAlerts.single.characterName, "LÉA");
    final leaRoleId = state.orphanedRoleAlerts.single.roleId;

    bloc.add(OcptShotListOrphanedRoleDeleteRequestedEvent(roleId: leaRoleId));
    state = await waitForState(bloc, (state) => state.orphanedRoleAlerts.isEmpty);

    // The character still spoken is left untouched by the deletion, and the role's own cascade
    // drops it from the shot rather than leaving a dangling attachment.
    expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

    await bloc.close();
  });

  test('an orphaned role can be merged into a still-speaking one, carrying its shots along', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA"]);

    await writeScreenplay(oneCharacterLeftText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);
    expect(state.orphanedRoleAlerts, hasLength(1));
    final leaRoleId = state.orphanedRoleAlerts.single.roleId;
    final marcRoleId = state.roles.firstWhere((role) => role.name == "MARC").id;

    bloc.add(
      OcptShotListRoleMergeRequestedEvent(sourceRoleId: leaRoleId, targetRoleId: marcRoleId),
    );
    state = await waitForState(bloc, (state) => state.orphanedRoleAlerts.isEmpty);

    expect(state.snapshot!.shotsById.values.single.characters, ["MARC"]);

    await bloc.close();
  });

  test('an orphaned role can be kept as silent, its casting untouched and its shot kept', () async {
    await writeScreenplay(twoCharactersText);
    await createShotWithCharacters(["LÉA", "MARC"]);

    await writeScreenplay(oneCharacterLeftText);

    final bloc = buildBloc();
    var state = await waitForState(bloc, (state) => !state.isLoading);
    expect(state.orphanedRoleAlerts, hasLength(1));
    final leaRoleId = state.orphanedRoleAlerts.single.roleId;

    bloc.add(OcptShotListOrphanedRoleKeptEvent(roleId: leaRoleId));
    state = await waitForState(bloc, (state) => state.orphanedRoleAlerts.isEmpty);

    final leaRole = state.roles.firstWhere((role) => role.id == leaRoleId);
    expect(leaRole.isFromScreenplay, isFalse);
    expect(leaRole.kind, OcptRoleKind.silent);
    // Kept, not dropped: the shot still carries both characters.
    expect(state.snapshot!.shotsById.values.single.characters, ["LÉA", "MARC"]);

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

  test('cancelling the pending anchor clears it without recording a range', () async {
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
    await waitForState(bloc, (state) => state.pendingCoverageAnchor != null);

    bloc.add(const OcptShotListCoverageAnchorCancelledEvent());
    state = await waitForState(bloc, (state) => state.pendingCoverageAnchor == null);

    expect(state.pendingCoverageAnchor, isNull);
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

  test('exporting the storyboard hands the loaded snapshots and options to the export manager',
      () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - storyboard.pdf");
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    bloc.add(
      const OcptShotListStoryboardExportRequestedEvent(
        options: _storyboardOptions,
        labels: _storyboardLabels,
        floorPlanLabels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
        episodeTag: "ep. 2",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.storyboardExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie - storyboard.pdf");
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "PDF document");
    expect(exportManager.lastExportedEpisodeTag, "ep. 2");
    expect(exportManager.lastStoryboardLabels, _storyboardLabels);
    expect(exportManager.lastStoryboardOptions, (shotsPerPage: 2, includeFloorPlans: false));
    expect(exportManager.lastStoryboardSnapshot, isNotNull);
    expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);
    // The toggle is off, but the loaded floor plan snapshot still rides along on every call —
    // whether it is used is the service's own decision, not something withheld at the bloc.
    expect(exportManager.lastStoryboardFloorPlanSnapshot, isNotNull);

    await bloc.close();
  });

  test('exporting the storyboard flushes a pending field edit first, so the document holds it',
      () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - storyboard.pdf");
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
      const OcptShotListStoryboardExportRequestedEvent(
        options: _storyboardOptions,
        labels: _storyboardLabels,
        floorPlanLabels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.pendingFieldEdits, isEmpty);
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Close-up");

    await bloc.close();
  });

  test('a cancelled storyboard save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(exportManager: _FakeExportManager());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptShotListStoryboardExportRequestedEvent(
        options: _storyboardOptions,
        labels: _storyboardLabels,
        floorPlanLabels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('a failing storyboard export raises its own transient failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(exportManager: _FakeExportManager(fails: true));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptShotListStoryboardExportRequestedEvent(
        options: _storyboardOptions,
        labels: _storyboardLabels,
        floorPlanLabels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.storyboardExportFailed);
    expect(state.ioNotice!.path, isNull);

    await bloc.close();
  });

  test('exporting the floor plans hands the loaded snapshot to the export manager', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - floor plans.pdf");
    final bloc = buildBloc(exportManager: exportManager);
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    bloc.add(
      const OcptShotListFloorPlansExportRequestedEvent(
        labels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
        episodeTag: "ep. 2",
      ),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.floorPlansExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie - floor plans.pdf");
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "PDF document");
    expect(exportManager.lastExportedEpisodeTag, "ep. 2");
    expect(exportManager.lastFloorPlanLabels, _floorPlanLabels);
    expect(exportManager.lastFloorPlanSnapshot, isNotNull);
    expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);

    await bloc.close();
  });

  test('exporting the floor plans flushes a pending field edit first', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - floor plans.pdf");
    final bloc = buildBloc(exportManager: exportManager, fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    var state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Wide shot",
      ),
    );
    await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

    bloc.add(
      const OcptShotListFloorPlansExportRequestedEvent(
        labels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.pendingFieldEdits, isEmpty);
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Wide shot");

    await bloc.close();
  });

  test('a cancelled floor plans save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(exportManager: _FakeExportManager());
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptShotListFloorPlansExportRequestedEvent(labels: _floorPlanLabels, fileTypeLabel: "PDF document"),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.ioNotice, isNull);

    await bloc.close();
  });

  test('a failing floor plans export raises its own transient failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc(exportManager: _FakeExportManager(fails: true));
    await waitForState(bloc, (state) => !state.isLoading);

    bloc.add(
      const OcptShotListFloorPlansExportRequestedEvent(labels: _floorPlanLabels, fileTypeLabel: "PDF document"),
    );
    final state = await waitForState(bloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.floorPlansExportFailed);
    expect(state.ioNotice!.path, isNull);

    await bloc.close();
  });

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
      expect(
        await propertiesManager.shotListLastCentreView.load(),
        OcptShotListCentreView.board,
      );

      await bloc.close();
    });

    test("importing a frame appends a panel to the shot and selects it", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/shot.png"),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final shotId = await createShot(bloc);

      bloc.add(
        OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
      );
      final state = await waitForState(bloc, (state) => state.panelsOfShot(shotId).length == 1);

      final panel = state.panelsOfShot(shotId).single;
      expect(panel.imagePath, "/frames/shot.png");
      expect(panel.comment, isEmpty);
      expect(state.selectedPanelId, panel.id);

      await bloc.close();
    });

    test("a cancelled import leaves the shot with no panel", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: null),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final shotId = await createShot(bloc);

      bloc.add(
        OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
      );
      // Nothing to wait for: a cancellation emits no state of its own.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.panelsOfShot(shotId), isEmpty);

      await bloc.close();
    });

    test("replacing a panel's image re-points it without changing its id", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/first.png"),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final shotId = await createShot(bloc);

      bloc.add(
        OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
      );
      final imported = await waitForState(
        bloc,
        (state) => state.panelsOfShot(shotId).length == 1,
      );
      final panelId = imported.panelsOfShot(shotId).single.id;

      bloc.add(
        OcptShotListPanelReplaceRequestedEvent(panelId: panelId, fileTypeLabel: "Images"),
      );
      // The stub always answers the very same path, so wait past the moment `addPanel`'s own
      // event lands and assert the panel count never grows: only its image is re-pointed.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.panelsOfShot(shotId).single.id, panelId);
      expect(bloc.state.panelsOfShot(shotId), hasLength(1));

      await bloc.close();
    });

    test("reordering a panel moves it to the requested position, writing one row", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final shotId = await createShot(bloc);

      for (var i = 0; i < 3; i++) {
        bloc.add(
          OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
        );
        await waitForState(bloc, (state) => state.panelsOfShot(shotId).length == i + 1);
      }

      final panelIds = bloc.state.panelsOfShot(shotId).map((panel) => panel.id).toList();

      // Moves the first panel (index 0) to the last position (index 2).
      bloc.add(
        OcptShotListPanelReorderedEvent(shotId: shotId, panelId: panelIds[0], newPosition: 2),
      );
      final reordered = await waitForState(
        bloc,
        (state) => state.panelsOfShot(shotId).first.id != panelIds[0],
      );

      expect(
        reordered.panelsOfShot(shotId).map((panel) => panel.id).toList(),
        [panelIds[1], panelIds[2], panelIds[0]],
      );

      await bloc.close();
    });

    test(
      "a panel comment is visible as a pending value and writes once after the debounce",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc(
          fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
        );
        await waitForState(bloc, (state) => !state.isLoading);
        final shotId = await createShot(bloc);
        bloc.add(
          OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
        );
        final imported = await waitForState(
          bloc,
          (state) => state.panelsOfShot(shotId).length == 1,
        );
        final panelId = imported.panelsOfShot(shotId).single.id;

        bloc.add(
          OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Push in"),
        );
        var state = await waitForState(
          bloc,
          (state) =>
              state.pendingFieldEdits[OcptShotListPanelCommentEditKey(panelId: panelId)] ==
              "Push in",
        );
        expect(state.panelsOfShot(shotId).single.comment, isEmpty);

        state = await waitForState(
          bloc,
          (state) => state.panelsOfShot(shotId).single.comment == "Push in",
        );
        expect(state.pendingFieldEdits, isEmpty);

        await bloc.close();
      },
    );

    test("selecting another shot flushes a pending panel comment edit immediately", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
        fieldEditDebounce: const Duration(seconds: 30),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final firstShotId = await createShot(bloc);
      bloc.add(
        OcptShotListPanelImportRequestedEvent(shotId: firstShotId, fileTypeLabel: "Images"),
      );
      final imported = await waitForState(
        bloc,
        (state) => state.panelsOfShot(firstShotId).length == 1,
      );
      final panelId = imported.panelsOfShot(firstShotId).single.id;

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      await waitForState(bloc, (state) => state.totalShotCount == 2);

      bloc.add(
        OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Handheld"),
      );
      // Switches back to the shot that owns the panel just typed into — a genuine change of
      // selection, unlike reselecting [secondShotId].
      bloc.add(OcptShotListShotSelectedEvent(shotId: firstShotId));

      final state = await waitForState(
        bloc,
        (state) => state.panelsOfShot(firstShotId).single.comment == "Handheld",
      );
      expect(state.pendingFieldEdits, isEmpty);

      await bloc.close();
    });

    test("deleting a panel removes it and clears the selection", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final shotId = await createShot(bloc);
      bloc.add(
        OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
      );
      final imported = await waitForState(
        bloc,
        (state) => state.panelsOfShot(shotId).length == 1,
      );
      final panelId = imported.panelsOfShot(shotId).single.id;

      bloc.add(OcptShotListPanelSelectedEvent(panelId: panelId));
      await waitForState(bloc, (state) => state.selectedPanelId == panelId);

      bloc.add(OcptShotListPanelDeletionRequestedEvent(panelId: panelId));
      final state = await waitForState(bloc, (state) => state.panelsOfShot(shotId).isEmpty);

      expect(state.selectedPanelId, isNull);

      await bloc.close();
    });

    test("deleting the shot cascades its panels and drops its pending comment edit", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(
        fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
        fieldEditDebounce: const Duration(seconds: 30),
      );
      await waitForState(bloc, (state) => !state.isLoading);
      final shotId = await createShot(bloc);
      bloc.add(
        OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
      );
      final imported = await waitForState(
        bloc,
        (state) => state.panelsOfShot(shotId).length == 1,
      );
      final panelId = imported.panelsOfShot(shotId).single.id;

      bloc.add(
        OcptShotListPanelCommentChangedEvent(panelId: panelId, rawValue: "Never written"),
      );
      await waitForState(
        bloc,
        (state) =>
            state.pendingFieldEdits[OcptShotListPanelCommentEditKey(panelId: panelId)] ==
            "Never written",
      );

      bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: shotId));
      final state = await waitForState(bloc, (state) => state.totalShotCount == 0);

      expect(state.pendingFieldEdits, isEmpty);
      expect(state.storyboardSnapshot?.panelsOfShot(shotId), isEmpty);

      await bloc.close();
    });

    test(
      "a captured panel is still there once its version is previewed, and once the preview "
      "is left",
      () async {
        // Dispatched to the very same, already-mounted bloc throughout — the path
        // `MixinOcptProjectVersionsBloc` actually uses (the Versions panel's own card),
        // mirroring `OcptResourcesBloc`'s own "a person created before the version is
        // captured, so it belongs to it" test. `OcptShotListBloc.reloadFromProjectDatabase`
        // is `_onLoadRequested`, which reads `_loadStoryboard` unconditionally, exactly as it
        // reads `_loadSnapshot` for the shots themselves — the board follows the identical
        // reload path a previewed version's shots already do.
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc(
          fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
        );
        await waitForState(bloc, (state) => !state.isLoading);
        final shotId = await createShot(bloc);

        bloc.add(const OcptShotListCentreViewSelectedEvent(view: OcptShotListCentreView.board));
        bloc.add(
          OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
        );
        await waitForState(bloc, (state) => state.panelsOfShot(shotId).length == 1);

        bloc.add(
          const OcptProjectVersionCreationRequestedEvent(name: "With a panel", note: ""),
        );
        final withVersion = await waitForState(
          bloc,
          (state) => state.projectVersions.isNotEmpty,
        );
        final versionId = withVersion.projectVersions.single.id;

        bloc.add(OcptProjectVersionPreviewRequestedEvent(versionId: versionId));
        final previewing = await waitForState(
          bloc,
          (state) => state.previewedVersionId != null,
        );

        expect(previewing.isPreviewingVersion, isTrue);
        expect(previewing.centreView, OcptShotListCentreView.board);
        final previewedPanels = previewing.panelsOfShot(shotId);
        expect(previewedPanels, hasLength(1));
        expect(previewedPanels.single.imagePath, "/frames/a.png");

        bloc.add(const OcptProjectVersionPreviewExitRequestedEvent());
        final backToWorkingCopy = await waitForState(
          bloc,
          (state) => state.previewedVersionId == null,
        );

        expect(backToWorkingCopy.panelsOfShot(shotId), hasLength(1));

        await bloc.close();
      },
    );

    group("annotations", () {
      /// Creates a shot, imports one panel onto it (selecting it, per [_onPanelImportRequested]),
      /// and returns the bloc alongside the shot's and the panel's own ids.
      Future<({OcptShotListBloc bloc, String shotId, String panelId})>
      mountWithASelectedPanel() async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc(
          fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/frames/a.png"),
        );
        await waitForState(bloc, (state) => !state.isLoading);
        final shotId = await createShot(bloc);
        bloc.add(
          OcptShotListPanelImportRequestedEvent(shotId: shotId, fileTypeLabel: "Images"),
        );
        final imported = await waitForState(
          bloc,
          (state) => state.panelsOfShot(shotId).length == 1,
        );
        return (bloc: bloc, shotId: shotId, panelId: imported.panelsOfShot(shotId).single.id);
      }

      test("picking a tool sets it, and picking null again turns it off", () async {
        final seeded = await mountWithASelectedPanel();
        final bloc = seeded.bloc;

        bloc.add(
          const OcptShotListAnnotationToolSelectedEvent(
            tool: OcptStoryboardAnnotationTool.movementArrow,
          ),
        );
        final withTool = await waitForState(
          bloc,
          (state) => state.activeAnnotationTool == OcptStoryboardAnnotationTool.movementArrow,
        );
        expect(withTool.activeAnnotationTool, OcptStoryboardAnnotationTool.movementArrow);

        bloc.add(const OcptShotListAnnotationToolSelectedEvent(tool: null));
        final withoutTool = await waitForState(
          bloc,
          (state) => state.activeAnnotationTool == null,
        );
        expect(withoutTool.activeAnnotationTool, isNull);

        await bloc.close();
      });

      test("drawing an arrow adds a mark of that kind, normalised, and selects it", () async {
        final seeded = await mountWithASelectedPanel();
        final bloc = seeded.bloc;

        bloc.add(
          OcptShotListAnnotationDrawnEvent(
            panelId: seeded.panelId,
            kind: OcptStoryboardAnnotationKind.movementArrow,
            x1: 0.2,
            y1: 0.3,
            x2: 0.8,
            y2: 0.3,
          ),
        );
        final state = await waitForState(
          bloc,
          (state) => state.panelsOfShot(seeded.shotId).single.annotations.isNotEmpty,
        );

        final mark = state.panelsOfShot(seeded.shotId).single.annotations.single;
        expect(mark.kind, OcptStoryboardAnnotationKind.movementArrow);
        expect(mark.x1, 0.2);
        expect(mark.y1, 0.3);
        expect(mark.x2, 0.8);
        expect(mark.y2, 0.3);
        expect(state.selectedAnnotationId, mark.id);

        await bloc.close();
      });

      test(
        "placing a label adds it and selects it, and its text writes once after the debounce",
        () async {
          final seeded = await mountWithASelectedPanel();
          final bloc = seeded.bloc;

          bloc.add(
            OcptShotListAnnotationPlacedEvent(panelId: seeded.panelId, x1: 0.5, y1: 0.4),
          );
          final placed = await waitForState(
            bloc,
            (state) => state.panelsOfShot(seeded.shotId).single.annotations.isNotEmpty,
          );
          final mark = placed.panelsOfShot(seeded.shotId).single.annotations.single;
          expect(mark.kind, OcptStoryboardAnnotationKind.label);
          expect(mark.x1, 0.5);
          expect(mark.y1, 0.4);
          expect(placed.selectedAnnotationId, mark.id);

          // "Opens its text inline for editing": the mark is already selected once placed, ready
          // for the inspector's own text field to write into.
          bloc.add(
            OcptShotListAnnotationTextChangedEvent(annotationId: mark.id, rawValue: "Dolly in"),
          );
          var state = await waitForState(
            bloc,
            (state) =>
                state.pendingFieldEdits[OcptShotListAnnotationTextEditKey(
                  annotationId: mark.id,
                )] ==
                "Dolly in",
          );
          expect(state.panelsOfShot(seeded.shotId).single.annotations.single.text, isEmpty);

          state = await waitForState(
            bloc,
            (state) =>
                state.panelsOfShot(seeded.shotId).single.annotations.single.text == "Dolly in",
          );
          expect(state.pendingFieldEdits, isEmpty);

          await bloc.close();
        },
      );

      test("selecting a mark records its id", () async {
        final seeded = await mountWithASelectedPanel();
        final bloc = seeded.bloc;

        bloc.add(
          OcptShotListAnnotationDrawnEvent(
            panelId: seeded.panelId,
            kind: OcptStoryboardAnnotationKind.movementArrow,
            x1: 0.1,
            y1: 0.1,
            x2: 0.3,
            y2: 0.1,
          ),
        );
        final first = await waitForState(
          bloc,
          (state) => state.panelsOfShot(seeded.shotId).single.annotations.length == 1,
        );
        final firstMarkId = first.selectedAnnotationId!;

        // Drawing a second mark auto-selects it instead, moving selection away from the first.
        bloc.add(
          OcptShotListAnnotationDrawnEvent(
            panelId: seeded.panelId,
            kind: OcptStoryboardAnnotationKind.cameraMoveArrow,
            x1: 0.5,
            y1: 0.5,
            x2: 0.7,
            y2: 0.5,
          ),
        );
        final second = await waitForState(
          bloc,
          (state) => state.panelsOfShot(seeded.shotId).single.annotations.length == 2,
        );
        expect(second.selectedAnnotationId, isNot(firstMarkId));

        bloc.add(OcptShotListAnnotationSelectedEvent(annotationId: firstMarkId));
        final state = await waitForState(
          bloc,
          (state) => state.selectedAnnotationId == firstMarkId,
        );
        expect(state.selectedAnnotationId, firstMarkId);

        await bloc.close();
      });

      test("deleting a mark removes it and clears its own selection", () async {
        final seeded = await mountWithASelectedPanel();
        final bloc = seeded.bloc;

        bloc.add(
          OcptShotListAnnotationDrawnEvent(
            panelId: seeded.panelId,
            kind: OcptStoryboardAnnotationKind.movementArrow,
            x1: 0.2,
            y1: 0.2,
            x2: 0.6,
            y2: 0.2,
          ),
        );
        final withMark = await waitForState(
          bloc,
          (state) => state.panelsOfShot(seeded.shotId).single.annotations.isNotEmpty,
        );
        final markId = withMark.selectedAnnotationId!;

        bloc.add(OcptShotListAnnotationDeletionRequestedEvent(annotationId: markId));
        final state = await waitForState(
          bloc,
          (state) => state.panelsOfShot(seeded.shotId).single.annotations.isEmpty,
        );
        expect(state.selectedAnnotationId, isNull);

        await bloc.close();
      });

      test("deleting the panel cascades its marks and drops a pending mark-text edit", () async {
        final seeded = await mountWithASelectedPanel();
        final bloc = seeded.bloc;

        bloc.add(
          OcptShotListAnnotationPlacedEvent(panelId: seeded.panelId, x1: 0.5, y1: 0.5),
        );
        final placed = await waitForState(
          bloc,
          (state) => state.panelsOfShot(seeded.shotId).single.annotations.isNotEmpty,
        );
        final markId = placed.panelsOfShot(seeded.shotId).single.annotations.single.id;

        bloc.add(
          OcptShotListAnnotationTextChangedEvent(
            annotationId: markId,
            rawValue: "Never written",
          ),
        );
        await waitForState(
          bloc,
          (state) =>
              state.pendingFieldEdits[OcptShotListAnnotationTextEditKey(annotationId: markId)] ==
              "Never written",
        );

        bloc.add(OcptShotListPanelDeletionRequestedEvent(panelId: seeded.panelId));
        final state = await waitForState(
          bloc,
          (state) => state.panelsOfShot(seeded.shotId).isEmpty,
        );

        expect(state.pendingFieldEdits, isEmpty);

        await bloc.close();
      });

      test(
        "selecting a different panel clears the active tool and the mark selection",
        () async {
          final seeded = await mountWithASelectedPanel();
          final bloc = seeded.bloc;

          bloc.add(
            OcptShotListAnnotationDrawnEvent(
              panelId: seeded.panelId,
              kind: OcptStoryboardAnnotationKind.movementArrow,
              x1: 0.2,
              y1: 0.2,
              x2: 0.6,
              y2: 0.2,
            ),
          );
          await waitForState(bloc, (state) => state.selectedAnnotationId != null);

          bloc.add(
            const OcptShotListAnnotationToolSelectedEvent(
              tool: OcptStoryboardAnnotationTool.label,
            ),
          );
          await waitForState(
            bloc,
            (state) => state.activeAnnotationTool == OcptStoryboardAnnotationTool.label,
          );

          // Importing onto the very same shot appends and selects a second panel.
          bloc.add(
            OcptShotListPanelImportRequestedEvent(
              shotId: seeded.shotId,
              fileTypeLabel: "Images",
            ),
          );
          final state = await waitForState(
            bloc,
            (state) => state.panelsOfShot(seeded.shotId).length == 2,
          );

          expect(state.selectedPanelId, isNot(seeded.panelId));
          expect(state.activeAnnotationTool, isNull);
          expect(state.selectedAnnotationId, isNull);

          await bloc.close();
        },
      );
    });
  });

  group("floor plans", () {
    /// Creates a case on the first scene of [twoSceneText] and returns its id, waiting for the
    /// selection the creation event always makes.
    Future<String> createCase(OcptShotListBloc bloc) async {
      bloc.add(const OcptShotListSetCreationRequestedEvent());
      final created = await waitForState(bloc, (state) => state.setsOfSelectedSequence.isNotEmpty);
      return created.selectedSetId!;
    }

    test("a fresh case is named from the scene heading's place and selected", () async {
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

    test("renaming a case debounces then writes", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(OcptShotListSetNameChangedEvent(setId: setId, rawValue: "Living room"));
      final pending = await waitForState(
        bloc,
        (state) => state.pendingFieldEdits.containsKey(
          OcptShotListSetNameEditKey(setId: setId),
        ),
      );
      expect(pending.selectedSet!.name, "HOUSE");

      final flushed = await waitForState(
        bloc,
        (state) => state.selectedSet!.name == "Living room",
      );
      expect(flushed.pendingFieldEdits, isEmpty);

      await bloc.close();
    });

    test("reordering two cases writes the new tab order", () async {
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
      expect(afterSecond.setsOfSelectedSequence.map((c) => c.id), [firstSetId, secondSetId]);

      bloc.add(OcptShotListSetReorderedEvent(setId: secondSetId, newPosition: 0));
      final reordered = await waitForState(
        bloc,
        (state) => state.setsOfSelectedSequence.first.id == secondSetId,
      );
      expect(reordered.setsOfSelectedSequence.map((c) => c.id), [secondSetId, firstSetId]);

      await bloc.close();
    });

    test(
      "deleting the selected case tombstones it and selects the sequence's next first case",
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

    test("placing a set element writes a sequence-scoped symbol on the active layer", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final setId = await createCase(bloc);

      bloc.add(
        const OcptShotListFloorPlanActiveLayerChangedEvent(layer: OcptFloorPlanLayer.set),
      );
      await waitForState(bloc, (state) => state.floorPlanActiveLayer == OcptFloorPlanLayer.set);

      bloc.add(
        OcptShotListFloorPlanSymbolPlacedEvent(
          setId: setId,
          layer: OcptFloorPlanLayer.set,
          shotId: null,
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
          xM: 0,
          yM: 0,
        ),
      );
      final placed = await waitForState(bloc, (state) => state.selectedSet!.symbols.isNotEmpty);
      final symbolId = placed.selectedSet!.symbols.single.id;

      bloc.add(OcptShotListFloorPlanSymbolMovedEvent(symbolId: symbolId, xM: 3, yM: 4));
      final moved = await waitForState(
        bloc,
        (state) => state.selectedSet!.symbols.single.xM == 3,
      );
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
      final state = await waitForState(
        bloc,
        (state) => state.selectedSet!.underlayAssetId != null,
      );

      expect(state.selectedSet!.underlayPath, "/plans/kitchen.png");
      expect(state.selectedSet!.underlayWidthM, isNotNull);
      expect(state.selectedSet!.underlayHeightM, isNotNull);

      await bloc.close();
    });

    test(
      "moving/resizing the underlay re-frames it through updateUnderlayFrame, minting or "
      "tombstoning no asset",
      () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc(
          fileSelectorManager: const _StubFileSelectorManager(pickedPath: "/plans/kitchen.png"),
        );
        await waitForState(bloc, (state) => !state.isLoading);
        final setId = await createCase(bloc);

        bloc.add(
          OcptShotListFloorPlanUnderlayImportRequestedEvent(
            setId: setId,
            fileTypeLabel: "Images",
          ),
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
      },
    );

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

    test("switching sequences clears the case and symbol selection", () async {
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

    group("the shot half (M6)", () {
      /// Creates a shot on the sole selected sequence and returns its id, waiting for the
      /// selection the creation event always makes — mirrors "the board" group's own helper.
      ///
      /// Waits for `selectedShotId` to actually **change** from whatever it already was, not
      /// merely to be non-null: since R2 guarantees a current shot whenever the sequence already
      /// holds one, a second call in the same test would otherwise resolve against the still-
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

      test(
        "always a current shot (R2): creating the sequence's first shot focuses it, deleting "
        "it reselects the sequence's own next first shot rather than clearing to null",
        () async {
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
          final afterLastDelete = await waitForState(
            bloc,
            (state) => state.totalShotCount == 0,
          );
          expect(afterLastDelete.selectedShotId, isNull);
          expect(afterLastDelete.selectedSequenceId, sequenceId);

          await bloc.close();
        },
      );

      test(
        "always a current shot (R2): switching to a sequence holding shots selects its own "
        "first one",
        () async {
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
        },
      );

      test(
        "placing a camera/character/light symbol is shot-scoped to the focused shot",
        () async {
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
                xM: 0,
                yM: 0,
              ),
            );
            final placed = await waitForState(
              bloc,
              (state) => state.selectedSet!.symbols.any((symbol) => symbol.layer == layer),
            );
            final symbol = placed.selectedSet!.symbols.firstWhere(
              (symbol) => symbol.layer == layer,
            );
            expect(symbol.shotId, shotId);
          }

          await bloc.close();
        },
      );

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
              xM: 1,
              yM: 1,
            ),
          );
          final state = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.length == 2,
          );

          // The derivation itself (`ocptFloorPlanCameraLabelOf`/`OcptFloorPlanSheet.of`) is a pure
          // rule already unit-tested on its own; this proves the production path — the bloc's own
          // writes through `OcptFloorPlanService.placeSymbol` — feeds it the right rows.
          final sheet = OcptFloorPlanSheet.of(
            floorPlanSet: state.selectedSet!,
            focusShotId: shotId,
            shotRankByShotId: {shotId: 1},
          );
          final labels = sheet.symbols.map((symbol) => symbol.cameraLabel).toList()..sort();
          expect(labels, ["1A", "1B"]);

          await bloc.close();
        },
      );

      test(
        "the arrow tool's own pending anchor completes a movement on the second tap, and "
        "Escape/the cancel event abandons it",
        () async {
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
          final completed = await waitForState(
            bloc,
            (state) => state.selectedSet!.arrows.isNotEmpty,
          );
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
        },
      );

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
            xM: 0,
            yM: 0,
          ),
        );
        final placed = await waitForState(
          bloc,
          (state) => state.selectedSet!.symbols.isNotEmpty,
        );
        final symbolId = placed.selectedSet!.symbols.single.id;

        bloc.add(
          OcptShotListFloorPlanSymbolLabelChangedEvent(symbolId: symbolId, rawValue: "SAM"),
        );
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

      test("deleting a shot tombstones its own floor plan symbols and reloads the snapshot", () async {
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
      });

      test(
        "placing a character symbol arms the name prompt, dismissed clears it (R2)",
        () async {
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
              xM: 0,
              yM: 0,
            ),
          );
          final placed = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.isNotEmpty,
          );
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

          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.cameras,
              shotId: shotId,
              xM: 0,
              yM: 0,
            ),
          );
          final placed = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.isNotEmpty,
          );
          final symbolId = placed.selectedSet!.symbols.single.id;
          expect(placed.selectedSet!.symbols.single.fovDeg, isNull);

          bloc.add(
            OcptShotListFloorPlanSymbolFovChangedEvent(symbolId: symbolId, fovDeg: 35),
          );
          final changed = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.single.fovDeg == 35,
          );
          expect(changed.selectedSet!.symbols.single.fovDeg, 35);

          await bloc.close();
        },
      );

      test(
        "selecting an arrow, bending it and straightening it back out writes the control "
        "point (R2)",
        () async {
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
          final withArrow = await waitForState(
            bloc,
            (state) => state.selectedSet!.arrows.isNotEmpty,
          );
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
            OcptShotListFloorPlanArrowCurveChangedEvent(
              arrowId: arrowId,
              ctrlXM: null,
              ctrlYM: null,
            ),
          );
          final straightened = await waitForState(
            bloc,
            (state) => state.selectedSet!.arrows.single.ctrlXM == null,
          );
          expect(straightened.selectedSet!.arrows.single.ctrlYM, isNull);

          bloc.add(OcptShotListFloorPlanArrowDeletionRequestedEvent(arrowId: arrowId));
          final deletedArrow = await waitForState(
            bloc,
            (state) => state.selectedSet!.arrows.isEmpty,
          );
          expect(deletedArrow.selectedFloorPlanArrowId, isNull);

          await bloc.close();
        },
      );

      test(
        "Ctrl+D duplicates a symbol offset from its source, an Alt-drag duplicates at the "
        "drag's own position, neither touching the source (R2)",
        () async {
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
              xM: 1,
              yM: 1,
            ),
          );
          final placed = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.isNotEmpty,
          );
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
          expect(
            duplicated.selectedSet!.symbols.firstWhere((symbol) => symbol.id == sourceId).xM,
            1,
          );

          // An explicit position (an `Alt`-drag's own settled point) places the copy exactly
          // there instead of at the default offset.
          bloc.add(
            OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId, xM: 9, yM: -4),
          );
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
        },
      );

      test(
        "duplicating a camera carries its own field-of-view reach to the copy",
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
              xM: 0,
              yM: 0,
            ),
          );
          final placed = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.isNotEmpty,
          );
          final sourceId = placed.selectedSet!.symbols.single.id;

          bloc.add(
            OcptShotListFloorPlanSymbolFovReachChangedEvent(symbolId: sourceId, fovReachM: 4.5),
          );
          await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.single.fovReachM == 4.5,
          );

          bloc.add(OcptShotListFloorPlanSymbolDuplicatedEvent(symbolId: sourceId));
          final duplicated = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.length == 2,
          );
          final copy = duplicated.selectedSet!.symbols.firstWhere(
            (symbol) => symbol.id != sourceId,
          );
          expect(copy.fovReachM, 4.5);

          await bloc.close();
        },
      );
    });

    group("R3 — chrome and duplication", () {
      /// Creates a fresh shot on the sole selected sequence and returns its id, waiting for the
      /// selection to actually change — mirrors "the shot half (M6)" group's own helper.
      Future<String> createFreshShot(OcptShotListBloc bloc) async {
        final previousShotId = bloc.state.selectedShotId;
        bloc.add(const OcptShotListShotCreationRequestedEvent());
        final created = await waitForState(
          bloc,
          (state) => state.selectedShotId != null && state.selectedShotId != previousShotId,
        );
        return created.selectedShotId!;
      }

      test('the "All cameras" toggle is session view state', () async {
        await writeScreenplay(twoSceneText);
        final bloc = buildBloc();
        await waitForState(bloc, (state) => !state.isLoading);
        expect(bloc.state.isFloorPlanAllCamerasShown, isFalse);

        bloc.add(const OcptShotListFloorPlanAllCamerasToggledEvent());
        final on = await waitForState(bloc, (state) => state.isFloorPlanAllCamerasShown);
        expect(on.isFloorPlanAllCamerasShown, isTrue);

        bloc.add(const OcptShotListFloorPlanAllCamerasToggledEvent());
        final off = await waitForState(bloc, (state) => !state.isFloorPlanAllCamerasShown);
        expect(off.isFloorPlanAllCamerasShown, isFalse);

        await bloc.close();
      });

      test(
        "duplicating the selected set copies its own placements as independent rows and "
        "selects the copy",
        () async {
          await writeScreenplay(twoSceneText);
          final bloc = buildBloc();
          await waitForState(bloc, (state) => !state.isLoading);
          final setId = await createCase(bloc);
          final shotId = await createFreshShot(bloc);

          bloc.add(
            OcptShotListFloorPlanSymbolPlacedEvent(
              setId: setId,
              layer: OcptFloorPlanLayer.cameras,
              shotId: shotId,
              xM: 1,
              yM: 2,
            ),
          );
          final withCamera = await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols.isNotEmpty,
          );
          final sourceSymbolId = withCamera.selectedSet!.symbols.single.id;

          bloc.add(OcptShotListSetDuplicationRequestedEvent(setId: setId));
          final afterDuplicate = await waitForState(
            bloc,
            (state) => state.setsOfSelectedSequence.length == 2,
          );
          final newSetId = afterDuplicate.selectedSetId!;
          expect(newSetId, isNot(setId));
          expect(afterDuplicate.selectedSet!.symbols, hasLength(1));
          final copiedSymbolId = afterDuplicate.selectedSet!.symbols.single.id;
          expect(copiedSymbolId, isNot(sourceSymbolId));

          // Independent: moving the copy leaves the source set's own symbol untouched.
          bloc.add(
            OcptShotListFloorPlanSymbolMovedEvent(symbolId: copiedSymbolId, xM: 9, yM: 9),
          );
          await waitForState(bloc, (state) => state.selectedSet!.symbols.single.xM == 9);
          final sourceSet = bloc.state.setsOfSelectedSequence.firstWhere((s) => s.id == setId);
          expect(sourceSet.symbols.single.xM, 1);

          await bloc.close();
        },
      );

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
          bloc.add(
            OcptShotListFloorPlanSymbolMovedEvent(symbolId: copiedSymbol.id, xM: 5, yM: 5),
          );
          await waitForState(
            bloc,
            (state) => state.selectedSet!.symbols
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
  });
}
