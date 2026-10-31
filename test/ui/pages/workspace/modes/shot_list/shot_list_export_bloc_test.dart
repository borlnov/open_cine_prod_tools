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
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_state.dart';
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

/// An export manager whose two exports are stubbed and whose calls are recorded, so the bloc's
/// export paths can be exercised without any real native dialog, workbook or PDF write.
class _FakeExportManager extends OcptExportManager {
  /// Class constructor
  _FakeExportManager({this.exportResult, this.fails = false, this.buildFails = false})
    : super(fileSelectorManager: const FileSelectorManager());

  /// The path either export returns, or null to simulate a cancelled save dialog.
  final String? exportResult;

  /// Whether either export throws, to exercise the bloc's export failure path.
  final bool fails;

  /// Whether the workbook export answers [OcptExportFailed], as the manager does when the
  /// workbook cannot be encoded.
  final bool buildFails;

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

    if (buildFails) {
      return const OcptExportFailed();
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
/// `ocptScenarioCoverageLabelsOf` builds from a real `Tr`: the bloc only carries them through to
/// the manager.
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
  noCameraNote: "No camera placed on this set yet.",
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

  /// Builds the mode bloc wired to the test project. [fieldEditDebounce] defaults to a short
  /// duration so tests exercising the field-edit debounce don't have to wait out the real 2 s one.
  OcptShotListBloc buildBloc({Duration fieldEditDebounce = const Duration(milliseconds: 30)}) =>
      OcptShotListBloc(
        projectsManager: projectsManager,
        propertiesManager: propertiesManager,
        routerManager: _RecordingRouterManager(),
        exportManager: OcptExportManager(fileSelectorManager: const FileSelectorManager()),
        fieldEditDebounce: fieldEditDebounce,
      );

  /// Builds the export bloc of [modeBloc], exporting through [exportManager] — a
  /// [_FakeExportManager] whose export cancels unless the test says otherwise, so no test ever
  /// reaches a native save dialog.
  OcptShotListExportBloc buildExportBloc(
    OcptShotListBloc modeBloc, {
    required OcptExportManager exportManager,
  }) => OcptShotListExportBloc(
    modeBloc: modeBloc,
    projectsManager: projectsManager,
    exportManager: exportManager,
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

  /// Waits for the first state of [bloc] matching [predicate] (the current one included).
  Future<OcptShotListExportState> waitForExportState(
    OcptShotListExportBloc bloc,
    bool Function(OcptShotListExportState state) predicate,
  ) async {
    if (predicate(bloc.state)) {
      return bloc.state;
    }

    return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
  }

  test('exporting the shot list hands the loaded snapshot to the export manager', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie.xlsx");
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
        episodeTag: "ep. 2",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.xlsxExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie.xlsx");
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "Excel workbook");
    expect(exportManager.lastExportedEpisodeTag, "ep. 2");
    expect(exportManager.lastExportedLabels, _exportLabels);
    // The whole shot list travels, not only the selected sequence.
    expect(exportManager.lastExportedSnapshot!.sequences, hasLength(2));
    expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);

    exportBloc.add(const OcptShotListIoNoticeDismissedEvent());
    await waitForExportState(exportBloc, (state) => state.ioNotice == null);
    expect(bloc.state.hasWriteError, isFalse);

    await exportBloc.close();
    await bloc.close();
  });

  test('exporting flushes a pending field edit first, so the workbook holds it', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie.xlsx");
    final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Close-up",
      ),
    );
    await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(bloc.state.pendingFieldEdits, isEmpty);
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Close-up");

    await exportBloc.close();
    await bloc.close();
  });

  test('a cancelled save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager());

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    // Nothing to wait for: a cancellation emits no state of its own, so the assertion is that the
    // bloc settles back with no notice once the export has had time to resolve.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a workbook that cannot be built raises the transient export failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager(buildFails: true));

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.xlsxExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a failing export raises the transient export failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager(fails: true));

    exportBloc.add(
      const OcptShotListXlsxExportRequestedEvent(
        labels: _exportLabels,
        fileTypeLabel: "Excel workbook",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.xlsxExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test(
    'exporting the scenario coverage hands the screenplay and its options to the manager',
    () async {
      await writeScreenplay(twoSceneText);

      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - coverage.pdf");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      await waitForState(bloc, (state) => state.totalShotCount == 1);

      exportBloc.add(
        const OcptShotListScenarioCoverageExportRequestedEvent(
          options: _coverageOptions,
          labels: _coverageLabels,
          fileTypeLabel: "PDF document",
          episodeTag: "ep. 2",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

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
      expect(exportManager.lastCoverageToggles, (
        sceneNumbers: true,
        titlePage: false,
        legendPage: true,
        summaryPage: false,
      ));
      expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);

      await exportBloc.close();
      await bloc.close();
    },
  );

  test('exporting the scenario coverage flushes a pending field edit first', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - coverage.pdf");
    final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Gros plan",
      ),
    );
    await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

    exportBloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: _coverageOptions,
        labels: _coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(bloc.state.pendingFieldEdits, isEmpty);
    // The legend prints the shot size the user typed seconds ago, and the abbreviation deduced
    // from it alongside.
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Gros plan");
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.abbreviation, "GP");

    await exportBloc.close();
    await bloc.close();
  });

  test('a cancelled coverage save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager());

    exportBloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: _coverageOptions,
        labels: _coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    // Nothing to wait for: a cancellation emits no state of its own, so the assertion is that the
    // bloc settles back with no notice once the export has had time to resolve.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a failing coverage export raises its own transient failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager(fails: true));

    exportBloc.add(
      const OcptShotListScenarioCoverageExportRequestedEvent(
        options: _coverageOptions,
        labels: _coverageLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.scenarioCoverageExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test(
    'exporting the storyboard hands the loaded snapshots and options to the export manager',
    () async {
      await writeScreenplay(twoSceneText);

      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - storyboard.pdf");
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      await waitForState(bloc, (state) => state.totalShotCount == 1);

      exportBloc.add(
        const OcptShotListStoryboardExportRequestedEvent(
          options: _storyboardOptions,
          labels: _storyboardLabels,
          floorPlanLabels: _floorPlanLabels,
          fileTypeLabel: "PDF document",
          episodeTag: "ep. 2",
        ),
      );
      final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

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

      await exportBloc.close();
      await bloc.close();
    },
  );

  test(
    'exporting the storyboard flushes a pending field edit first, so the document holds it',
    () async {
      await writeScreenplay(twoSceneText);

      final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - storyboard.pdf");
      final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

      bloc.add(const OcptShotListShotCreationRequestedEvent());
      final state = await waitForState(bloc, (state) => state.totalShotCount == 1);
      final shotId = state.selectedShotId!;

      bloc.add(
        OcptShotListShotFieldChangedEvent(
          shotId: shotId,
          field: OcptShotListEditableField.shotSize,
          rawValue: "Close-up",
        ),
      );
      await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

      exportBloc.add(
        const OcptShotListStoryboardExportRequestedEvent(
          options: _storyboardOptions,
          labels: _storyboardLabels,
          floorPlanLabels: _floorPlanLabels,
          fileTypeLabel: "PDF document",
        ),
      );
      await waitForExportState(exportBloc, (state) => state.ioNotice != null);

      expect(bloc.state.pendingFieldEdits, isEmpty);
      expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Close-up");

      await exportBloc.close();
      await bloc.close();
    },
  );

  test('a cancelled storyboard save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager());

    exportBloc.add(
      const OcptShotListStoryboardExportRequestedEvent(
        options: _storyboardOptions,
        labels: _storyboardLabels,
        floorPlanLabels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a failing storyboard export raises its own transient failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager(fails: true));

    exportBloc.add(
      const OcptShotListStoryboardExportRequestedEvent(
        options: _storyboardOptions,
        labels: _storyboardLabels,
        floorPlanLabels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.storyboardExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('exporting the floor plans hands the loaded snapshot to the export manager', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - floor plans.pdf");
    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    await waitForState(bloc, (state) => state.totalShotCount == 1);

    exportBloc.add(
      const OcptShotListFloorPlansExportRequestedEvent(
        labels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
        episodeTag: "ep. 2",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.floorPlansExportSucceeded);
    expect(state.ioNotice!.path, "/tmp/My Movie - floor plans.pdf");
    expect(exportManager.lastExportedProjectName, "My Movie");
    expect(exportManager.lastExportedFileTypeLabel, "PDF document");
    expect(exportManager.lastExportedEpisodeTag, "ep. 2");
    expect(exportManager.lastFloorPlanLabels, _floorPlanLabels);
    expect(exportManager.lastFloorPlanSnapshot, isNotNull);
    expect(exportManager.lastExportedSnapshot!.totalShotCount, 1);

    await exportBloc.close();
    await bloc.close();
  });

  test('exporting the floor plans flushes a pending field edit first', () async {
    await writeScreenplay(twoSceneText);

    final exportManager = _FakeExportManager(exportResult: "/tmp/My Movie - floor plans.pdf");
    final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: exportManager);

    bloc.add(const OcptShotListShotCreationRequestedEvent());
    final state = await waitForState(bloc, (state) => state.totalShotCount == 1);
    final shotId = state.selectedShotId!;

    bloc.add(
      OcptShotListShotFieldChangedEvent(
        shotId: shotId,
        field: OcptShotListEditableField.shotSize,
        rawValue: "Wide shot",
      ),
    );
    await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

    exportBloc.add(
      const OcptShotListFloorPlansExportRequestedEvent(
        labels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(bloc.state.pendingFieldEdits, isEmpty);
    expect(exportManager.lastExportedSnapshot!.shotsById[shotId]!.shotSize, "Wide shot");

    await exportBloc.close();
    await bloc.close();
  });

  test('a cancelled floor plans save dialog leaves no export notice at all', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager());

    exportBloc.add(
      const OcptShotListFloorPlansExportRequestedEvent(
        labels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(exportBloc.state.ioNotice, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  test('a failing floor plans export raises its own transient failure notice', () async {
    await writeScreenplay(twoSceneText);

    final bloc = buildBloc();
    await waitForState(bloc, (state) => !state.isLoading);
    final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager(fails: true));

    exportBloc.add(
      const OcptShotListFloorPlansExportRequestedEvent(
        labels: _floorPlanLabels,
        fileTypeLabel: "PDF document",
      ),
    );
    final state = await waitForExportState(exportBloc, (state) => state.ioNotice != null);

    expect(state.ioNotice!.kind, OcptShotListIoNoticeKind.floorPlansExportFailed);
    expect(state.ioNotice!.path, isNull);

    await exportBloc.close();
    await bloc.close();
  });

  group("the bloc as a whole", () {
    /// Names [event] by the exhaustive switch over the sealed hierarchy: adding an event to it makes
    /// this fail to compile until the list below names it too.
    String nameOf(OcptShotListExportEvent event) => switch (event) {
      OcptShotListXlsxExportRequestedEvent() => "xlsx",
      OcptShotListScenarioCoverageExportRequestedEvent() => "coverage",
      OcptShotListStoryboardExportRequestedEvent() => "storyboard",
      OcptShotListFloorPlansExportRequestedEvent() => "floor plans",
      OcptShotListIoNoticeDismissedEvent() => "dismiss",
    };

    test("every event of its hierarchy has a handler", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc();
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(bloc, exportManager: _FakeExportManager());

      const events = <OcptShotListExportEvent>[
        OcptShotListXlsxExportRequestedEvent(labels: _exportLabels, fileTypeLabel: "Excel"),
        OcptShotListScenarioCoverageExportRequestedEvent(
          options: _coverageOptions,
          labels: _coverageLabels,
          fileTypeLabel: "PDF",
        ),
        OcptShotListStoryboardExportRequestedEvent(
          options: _storyboardOptions,
          labels: _storyboardLabels,
          floorPlanLabels: _floorPlanLabels,
          fileTypeLabel: "PDF",
        ),
        OcptShotListFloorPlansExportRequestedEvent(labels: _floorPlanLabels, fileTypeLabel: "PDF"),
        OcptShotListIoNoticeDismissedEvent(),
      ];
      expect(events.map(nameOf).toSet(), hasLength(5));

      // A bloc asserts, in debug mode, that an event it is given has a handler registered.
      for (final event in events) {
        expect(() => exportBloc.add(event), returnsNormally, reason: nameOf(event));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await exportBloc.close();
      await bloc.close();
    });

    test("an export asked just as the mode closes neither hangs nor throws", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeExportManager(exportResult: "/tmp/My Movie.xlsx"),
      );
      bloc.add(const OcptShotListShotCreationRequestedEvent());
      final state = await waitForState(bloc, (state) => state.totalShotCount == 1);
      bloc.add(
        OcptShotListShotFieldChangedEvent(
          shotId: state.selectedShotId!,
          field: OcptShotListEditableField.shotSize,
          rawValue: "Close-up",
        ),
      );
      await waitForState(bloc, (state) => state.pendingFieldEdits.isNotEmpty);

      exportBloc.add(
        const OcptShotListXlsxExportRequestedEvent(labels: _exportLabels, fileTypeLabel: "Excel"),
      );
      // The mode closes while the export is still waiting for it to write what is pending.
      await bloc.close().timeout(const Duration(seconds: 5));
      await exportBloc.close().timeout(const Duration(seconds: 5));
    });

    test("closing the export bloc while an export waits for the mode does not hang", () async {
      await writeScreenplay(twoSceneText);
      final bloc = buildBloc(fieldEditDebounce: const Duration(days: 1));
      await waitForState(bloc, (state) => !state.isLoading);
      final exportBloc = buildExportBloc(
        bloc,
        exportManager: _FakeExportManager(exportResult: "/tmp/My Movie.xlsx"),
      );

      exportBloc.add(
        const OcptShotListXlsxExportRequestedEvent(labels: _exportLabels, fileTypeLabel: "Excel"),
      );
      await exportBloc.close().timeout(const Duration(seconds: 5));
      await bloc.close().timeout(const Duration(seconds: 5));
    });
  });
}
