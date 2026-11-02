// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';

/// This is the bloc class for the shot list mode's exports: the XLSX workbook, the scenario
/// coverage PDF, the storyboard PDF and the floor plans PDF.
///
/// The exports read the shot list rather than writing to it, so this bloc owns no data of its own:
/// it asks [OcptShotListBloc] to write every pending edit first
/// ([OcptShotListBloc.flushAllPendingWrites], which also reads the snapshots again, so a value
/// typed seconds before the export is in the document and not only on screen), then hands what the
/// mode's state now carries to [OcptExportManager], which owns both the document building and the
/// native save dialog. A cancelled save dialog is a silent no-op; a failure raises the transient
/// export-failed notice in [OcptShotListExportState.ioNotice].
class OcptShotListExportBloc
    extends AbsOcptViewBloc<OcptShotListExportState, OcptShotListState, OcptShotListBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "shot_list_export_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to read which project is open, for the log of a failed export.
  final OcptProjectsManager _projectsManager;

  /// The manager used to build and save each document.
  final OcptExportManager _exportManager;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt].
  OcptShotListExportBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptExportManager? exportManager,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       super(const OcptShotListExportState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptShotListXlsxExportRequestedEvent>(_onXlsxExportRequested);
    on<OcptShotListScenarioCoverageExportRequestedEvent>(_onScenarioCoverageExportRequested);
    on<OcptShotListStoryboardExportRequestedEvent>(_onStoryboardExportRequested);
    on<OcptShotListFloorPlansExportRequestedEvent>(_onFloorPlansExportRequested);
    on<OcptShotListIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// Export the whole shot list to an XLSX workbook.
  ///
  /// Writes every pending edit first — that also re-reads the snapshot, so the workbook holds the
  /// value the user typed seconds ago rather than the one the database held before it — then hands
  /// what the mode's state now carries to [OcptExportManager.exportShotListXlsx]. A cancelled save
  /// dialog is a silent no-op; a failure raises the transient export-failed notice.
  ///
  /// Exports the whole shot list, not only the selected sequence: the workbook is what leaves the
  /// app, and the orphan group travels with it exactly as the left dock shows it.
  Future<void> _onXlsxExportRequested(
    OcptShotListXlsxExportRequestedEvent event,
    Emitter<OcptShotListExportState> emitter,
  ) async {
    await modeBloc.flushAllPendingWrites();

    final snapshot = modeBloc.state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final outcome = await _exportManager.exportShotListXlsx(
        snapshot: snapshot,
        labels: event.labels,
        projectName: modeBloc.state.title,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      // The user cancelled the save dialog (a null outcome): nothing is reported.
      if (outcome != null) {
        if (outcome is OcptExportFailed) {
          // The manager already logged why the workbook could not be built.
          emitter(
            state.copyWithIoNotice(
              ioNotice: const OcptShotListIoNotice(kind: OcptShotListIoNoticeKind.xlsxExportFailed),
            ),
          );
        } else {
          emitter(
            state.copyWithIoNotice(
              ioNotice: OcptShotListIoNotice(
                kind: OcptShotListIoNoticeKind.xlsxExportSucceeded,
                path: outcome.savedPath,
                wasShared: outcome.wasShared,
              ),
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the shot list of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptShotListIoNotice(kind: OcptShotListIoNoticeKind.xlsxExportFailed),
        ),
      );
    }
  }

  /// Export the screenplay annotated with the shots covering it, as a PDF.
  ///
  /// The read-only sibling of [_onXlsxExportRequested], and built the same way: write whatever is
  /// still pending — that also re-reads the snapshot, so the legend holds the shot size the user
  /// typed seconds ago — then hand what the mode's state now carries to
  /// [OcptExportManager.exportScenarioCoverage]. A cancelled save dialog is a silent no-op; a
  /// failure raises the transient export-failed notice.
  ///
  /// [OcptShotListState.screenplayText] is parsed here rather than kept parsed in the state: the
  /// document is only ever needed by this export, and the very string it is parsed from travels
  /// alongside it, since a coverage range addresses that text by character offset.
  Future<void> _onScenarioCoverageExportRequested(
    OcptShotListScenarioCoverageExportRequestedEvent event,
    Emitter<OcptShotListExportState> emitter,
  ) async {
    await modeBloc.flushAllPendingWrites();

    final snapshot = modeBloc.state.snapshot;
    if (snapshot == null) {
      return;
    }

    await _runExport(
      emitter: emitter,
      what: "scenario coverage",
      succeededKind: OcptShotListIoNoticeKind.scenarioCoverageExportSucceeded,
      failedKind: OcptShotListIoNoticeKind.scenarioCoverageExportFailed,
      export: () async {
        final options = event.options;
        return _exportManager.exportScenarioCoverage(
          document: const FountainParser().parse(modeBloc.state.screenplayText),
          screenplayText: modeBloc.state.screenplayText,
          snapshot: snapshot,
          pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
          labels: event.labels,
          projectName: modeBloc.state.title,
          includeSceneNumbers: options.includeSceneNumbers,
          includeTitlePage: options.includeTitlePage,
          includeLegendPage: options.includeLegendPage,
          includeSummaryPage: options.includeSummaryPage,
          fileTypeLabel: event.fileTypeLabel,
          episodeTag: event.episodeTag,
          shareAnchor: event.shareAnchor,
        );
      },
    );
  }

  /// Export the storyboard — every shot's imported frames, annotated, with its key information —
  /// as a PDF.
  ///
  /// Built the same way as [_onXlsxExportRequested] and [_onScenarioCoverageExportRequested]: write
  /// whatever field or panel comment edit is still pending — so the export holds it — then hand
  /// what the mode's state now carries to [OcptExportManager.exportStoryboard]. When
  /// [OcptShotListStoryboardExportRequestedEvent.options] asks for the floor plans to be appended,
  /// [OcptShotListState.floorPlanSnapshot] rides along too; a cancelled save dialog is a silent
  /// no-op, a failure raises the transient export-failed notice.
  Future<void> _onStoryboardExportRequested(
    OcptShotListStoryboardExportRequestedEvent event,
    Emitter<OcptShotListExportState> emitter,
  ) async {
    await modeBloc.flushAllPendingWrites();

    final snapshot = modeBloc.state.snapshot;
    final storyboardSnapshot = modeBloc.state.storyboardSnapshot;
    if (snapshot == null || storyboardSnapshot == null) {
      return;
    }

    await _runExport(
      emitter: emitter,
      what: "storyboard",
      succeededKind: OcptShotListIoNoticeKind.storyboardExportSucceeded,
      failedKind: OcptShotListIoNoticeKind.storyboardExportFailed,
      export: () async {
        final options = event.options;
        return _exportManager.exportStoryboard(
          snapshot: snapshot,
          storyboardSnapshot: storyboardSnapshot,
          pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
          labels: event.labels,
          projectName: modeBloc.state.title,
          shotsPerPage: options.shotsPerPage,
          includeFloorPlansAfterEachSequence: options.includeFloorPlansAfterEachSequence,
          floorPlanSnapshot: modeBloc.state.floorPlanSnapshot,
          floorPlanLabels: event.floorPlanLabels,
          fileTypeLabel: event.fileTypeLabel,
          episodeTag: event.episodeTag,
          shareAnchor: event.shareAnchor,
        );
      },
    );
  }

  /// Export the floor plans — one plan per shot that has a camera placed on it — as a PDF.
  ///
  /// The read-only sibling of [_onStoryboardExportRequested], opening no options dialog of its own
  /// (its page format is [OcptShotListState.pageSetup], exactly as the shot list workbook's own
  /// export is): write whatever is still pending — so a symbol label typed seconds ago is on the
  /// plan — then hand what the mode's state now carries to [OcptExportManager.exportFloorPlans]. A
  /// cancelled save dialog is a silent no-op; a failure raises the transient export-failed notice.
  Future<void> _onFloorPlansExportRequested(
    OcptShotListFloorPlansExportRequestedEvent event,
    Emitter<OcptShotListExportState> emitter,
  ) async {
    await modeBloc.flushAllPendingWrites();

    final snapshot = modeBloc.state.snapshot;
    final floorPlanSnapshot = modeBloc.state.floorPlanSnapshot;
    if (snapshot == null || floorPlanSnapshot == null) {
      return;
    }

    await _runExport(
      emitter: emitter,
      what: "floor plans",
      succeededKind: OcptShotListIoNoticeKind.floorPlansExportSucceeded,
      failedKind: OcptShotListIoNoticeKind.floorPlansExportFailed,
      export: () => _exportManager.exportFloorPlans(
        snapshot: snapshot,
        floorPlanSnapshot: floorPlanSnapshot,
        pageSetup: modeBloc.state.pageSetup,
        labels: event.labels,
        projectName: modeBloc.state.title,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      ),
    );
  }

  /// Run one of the read-only exports through [export], then raise the transient notice of its
  /// outcome: [succeededKind] with the saved path, nothing at all when [export] answers null (the
  /// user cancelled the save dialog), or [failedKind] when it throws (logged as a problem exporting
  /// [what]).
  Future<void> _runExport({
    required Emitter<OcptShotListExportState> emitter,
    required String what,
    required OcptShotListIoNoticeKind succeededKind,
    required OcptShotListIoNoticeKind failedKind,
    required Future<OcptExportOutcome?> Function() export,
  }) async {
    try {
      final outcome = await export();
      // The user cancelled the save dialog (a null outcome): nothing is reported.
      if (outcome != null) {
        emitter(
          state.copyWithIoNotice(
            ioNotice: OcptShotListIoNotice(
              kind: succeededKind,
              path: outcome.savedPath,
              wasShared: outcome.wasShared,
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the $what of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWithIoNotice(ioNotice: OcptShotListIoNotice(kind: failedKind)));
    }
  }

  /// Clear the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptShotListIoNoticeDismissedEvent event,
    Emitter<OcptShotListExportState> emitter,
  ) async {
    emitter(state.copyWithIoNoticeDismissed());
  }
}
