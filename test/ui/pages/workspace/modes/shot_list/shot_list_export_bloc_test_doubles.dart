// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:ui';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
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

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String testAppLanguageCode() => "en";

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
class RecordingRouterManager extends OcptRouterManager {
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
class FakeExportManager extends OcptExportManager {
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

  /// Class constructor
  FakeExportManager({this.exportResult, this.fails = false, this.buildFails = false})
    : super(fileSelectorManager: const FileSelectorManager());

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
const exportLabels = OcptShotListXlsxLabels(
  sheetName: "Shot list",
  columnHeaders: {},
  statusLabels: {},
  sequenceTitles: {},
  dayTagPrefix: "D",
);

/// The labels the scenario coverage export tests dispatch, standing in for what
/// `ocptScenarioCoverageLabelsOf` builds from a real `Tr`: the bloc only carries them through to
/// the manager.
const coverageLabels = OcptScenarioCoverageLabels(
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
const coverageOptions = OcptScenarioCoverageExportOptions(
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
const storyboardLabels = OcptStoryboardLabels(
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
const testFloorPlanLabels = OcptFloorPlanLabels(
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
const storyboardOptions = OcptStoryboardExportOptions(
  format: OcptPageFormat.a4,
  margins: FountainPageMargins.standard(),
  shotsPerPage: 2,
  includeFloorPlansAfterEachSequence: false,
);
