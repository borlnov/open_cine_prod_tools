// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_sides_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';

/// This is the bloc class for the schedule mode's exports: the two call sheet runs, the shooting
/// plan as a PDF and as a workbook, the *Day Out of Days*, the one-line schedule and the sides.
///
/// The exports read the schedule rather than writing to it, so this bloc owns no data of its own:
/// it asks [OcptScheduleBloc] to write every pending edit first
/// ([OcptScheduleBloc.flushAllPendingWrites], which also reads the schedule again, so a printed
/// sheet holds the note or the label the user typed seconds ago), then hands what the mode's
/// `planSnapshot` now carries to [OcptExportManager], which owns both the document building and the
/// native dialog. A cancelled dialog is a silent no-op; a failure raises the transient
/// export-failed notice in [OcptScheduleExportState.ioNotice].
class OcptScheduleExportBloc
    extends AbsOcptViewBloc<OcptScheduleExportState, OcptScheduleState, OcptScheduleBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "schedule_export_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager the exports (the two call sheet kinds, the shooting plan and the others) go
  /// through.
  final OcptExportManager _exportManager;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt].
  OcptScheduleExportBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptExportManager? exportManager,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       super(const OcptScheduleExportState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptScheduleCallSheetsExportRequestedEvent>(_onCallSheetsExportRequested);
    on<OcptScheduleNamedCallSheetsExportRequestedEvent>(_onNamedCallSheetsExportRequested);
    on<OcptScheduleShootingPlanExportRequestedEvent>(_onShootingPlanExportRequested);
    on<OcptScheduleShootingPlanXlsxExportRequestedEvent>(_onShootingPlanXlsxExportRequested);
    on<OcptScheduleDayOutOfDaysExportRequestedEvent>(_onDayOutOfDaysExportRequested);
    on<OcptScheduleOneLineScheduleExportRequestedEvent>(_onOneLineScheduleExportRequested);
    on<OcptScheduleSidesExportRequestedEvent>(_onSidesExportRequested);
    on<OcptScheduleIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// Exports the general call sheets of `event.options.dayIds`, one PDF per day, into a folder the
  /// user picks.
  ///
  /// Flushes whatever is still pending first — that flush re-reads the plan snapshot, so a printed
  /// sheet holds the note or the label the user typed seconds ago — then hands what
  /// [OcptScheduleState.planSnapshot] now carries to [OcptExportManager.exportGeneralCallSheets]. A
  /// cancelled folder dialog is a silent no-op; a write failure is reported per file through
  /// [OcptScheduleIoNoticeKind.folderExportPartiallySucceeded] rather than an exception, so only an
  /// exception thrown before a folder was even chosen reaches the `catch` below.
  Future<void> _onCallSheetsExportRequested(
    OcptScheduleCallSheetsExportRequestedEvent event,
    Emitter<OcptScheduleExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final plan = modeBloc.state.planSnapshot;
    if (plan == null) {
      return;
    }

    try {
      final result = await _exportManager.exportGeneralCallSheets(
        plan: plan,
        dayIds: event.options.dayIds,
        pageSetup: OcptPageSetup(format: event.options.format, margins: event.options.margins),
        labels: event.labels,
        projectName: modeBloc.state.title,
        confirmButtonText: event.confirmButtonText,
        shareAnchor: event.shareAnchor,
      );
      if (result == null) {
        // The user cancelled the folder dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptScheduleIoNotice(
            kind: result.isComplete
                ? OcptScheduleIoNoticeKind.folderExportSucceeded
                : OcptScheduleIoNoticeKind.folderExportPartiallySucceeded,
            folderPath: result.folderPath,
            writtenCount: result.writtenFileNames.length,
            failedCount: result.failedFileNames.length,
            wasShared: result.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the call sheets of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptScheduleIoNotice(kind: OcptScheduleIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the named call sheets of `event.options.dayIds`, one PDF per (selected convocation ×
  /// day), into a folder the user picks. See [_onCallSheetsExportRequested]'s own doc comment for
  /// the flush, the cancellation and the partial-failure contract, identical here.
  Future<void> _onNamedCallSheetsExportRequested(
    OcptScheduleNamedCallSheetsExportRequestedEvent event,
    Emitter<OcptScheduleExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final plan = modeBloc.state.planSnapshot;
    if (plan == null || event.options.dayIds.isEmpty) {
      return;
    }

    try {
      final result = await _exportManager.exportNamedCallSheets(
        plan: plan,
        dayIds: event.options.dayIds,
        convocationKeys: event.options.selectedConvocationKeys,
        pageSetup: OcptPageSetup(format: event.options.format, margins: event.options.margins),
        labels: event.labels,
        projectName: modeBloc.state.title,
        confirmButtonText: event.confirmButtonText,
        shareAnchor: event.shareAnchor,
      );
      if (result == null) {
        // The user cancelled the folder dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptScheduleIoNotice(
            kind: result.isComplete
                ? OcptScheduleIoNoticeKind.folderExportSucceeded
                : OcptScheduleIoNoticeKind.folderExportPartiallySucceeded,
            folderPath: result.folderPath,
            writtenCount: result.writtenFileNames.length,
            failedCount: result.failedFileNames.length,
            wasShared: result.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the named call sheets of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptScheduleIoNotice(kind: OcptScheduleIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the whole-shoot shooting plan of `event.options.dayIds` as a single PDF, written
  /// through the native save dialog.
  ///
  /// Flushes whatever is still pending first, exactly as [_onCallSheetsExportRequested]; a
  /// cancelled save dialog is a silent no-op (`OcptExportManager.exportShootingPlan` returns null
  /// for it, the same convention every single-file export of this app follows).
  Future<void> _onShootingPlanExportRequested(
    OcptScheduleShootingPlanExportRequestedEvent event,
    Emitter<OcptScheduleExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final plan = modeBloc.state.planSnapshot;
    if (plan == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportShootingPlan(
        plan: plan,
        dayIds: options.dayIds,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: modeBloc.state.title,
        includeTitlePage: options.includeTitlePage,
        includeLocationsGrid: options.includeLocationsGrid,
        includeSequencesGrid: options.includeSequencesGrid,
        includePeopleGrid: options.includePeopleGrid,
        includeTenMinuteGrid: options.includeTenMinuteGrid,
        includeElementsGrid: options.includeElementsGrid,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptScheduleIoNotice(
            kind: OcptScheduleIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the shooting plan of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptScheduleIoNotice(kind: OcptScheduleIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the whole-shoot shooting plan's own five-sheet workbook of `event.options.dayIds` as a
  /// single XLSX file, written through the native save dialog. Mirrors
  /// [_onShootingPlanExportRequested] — see its own doc comment for the flush and the cancellation
  /// contract, identical here.
  Future<void> _onShootingPlanXlsxExportRequested(
    OcptScheduleShootingPlanXlsxExportRequestedEvent event,
    Emitter<OcptScheduleExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final plan = modeBloc.state.planSnapshot;
    if (plan == null) {
      return;
    }

    try {
      final outcome = await _exportManager.exportShootingPlanXlsx(
        plan: plan,
        dayIds: event.options.dayIds,
        labels: event.labels,
        projectName: modeBloc.state.title,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      if (outcome is OcptExportFailed) {
        // The manager already logged why the workbook could not be built.
        emitter(
          state.copyWith(
            ioNotice: const OcptScheduleIoNotice(kind: OcptScheduleIoNoticeKind.exportFailed),
          ),
        );
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptScheduleIoNotice(
            kind: OcptScheduleIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the shooting plan workbook of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptScheduleIoNotice(kind: OcptScheduleIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the cast's own *Day Out of Days* over `event.options.dayIds` as a single PDF, written
  /// through the native save dialog. Mirrors [_onShootingPlanExportRequested] — see its own doc
  /// comment for the flush and the cancellation contract, identical here.
  Future<void> _onDayOutOfDaysExportRequested(
    OcptScheduleDayOutOfDaysExportRequestedEvent event,
    Emitter<OcptScheduleExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final plan = modeBloc.state.planSnapshot;
    if (plan == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportDayOutOfDays(
        plan: plan,
        dayIds: options.dayIds,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: modeBloc.state.title,
        includeTitlePage: options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptScheduleIoNotice(
            kind: OcptScheduleIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the day out of days of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptScheduleIoNotice(kind: OcptScheduleIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the one-line schedule over `event.options.dayIds` as a single PDF, written through the
  /// native save dialog. Mirrors [_onDayOutOfDaysExportRequested] — see its own doc comment for the
  /// flush and the cancellation contract, identical here.
  Future<void> _onOneLineScheduleExportRequested(
    OcptScheduleOneLineScheduleExportRequestedEvent event,
    Emitter<OcptScheduleExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final plan = modeBloc.state.planSnapshot;
    if (plan == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportOneLineSchedule(
        plan: plan,
        dayIds: options.dayIds,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: modeBloc.state.title,
        includeTitlePage: options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptScheduleIoNotice(
            kind: OcptScheduleIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the one-line schedule of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptScheduleIoNotice(kind: OcptScheduleIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports `event.options.dayId`'s own sides booklet as a single PDF, written through the native
  /// save dialog. Mirrors [_onOneLineScheduleExportRequested] — see its own doc comment for the
  /// flush and the cancellation contract, identical here.
  ///
  /// It is the one export of this mode that reads the **screenplay**, and it reads it here rather
  /// than out of the state: nothing else the schedule mode draws needs the Fountain text, so
  /// loading it on every load of the mode would be a seventh read serving one rarely-run export.
  /// It is read straight from the open project's own database, which is where the shot list
  /// snapshot's scene offsets were indexed against — a version preview swaps that database out
  /// wholesale, so a previewed booklet reads the previewed screenplay, exactly as its scenes do.
  ///
  /// A day now regularly plays more than one episode, so this reads **every** episode [options
  /// .dayId] plays rather than [OcptOpenProjectModel.primaryScreenplayId] alone: [_documentsOfDay]
  /// resolves which ones through [OcptSchedulePlanSnapshot.screenplayIdBySceneId], narrowed to
  /// [OcptScheduleState.episodes] and kept in that list's own order — the order
  /// [OcptSidesPdfService.generate] then chains the booklet's runs in.
  Future<void> _onSidesExportRequested(
    OcptScheduleSidesExportRequestedEvent event,
    Emitter<OcptScheduleExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final plan = modeBloc.state.planSnapshot;
    final project = _projectsManager.currentProject;
    if (plan == null || project == null) {
      return;
    }

    try {
      final options = event.options;
      final documents = await _documentsOfDay(project: project, plan: plan, dayId: options.dayId);

      final outcome = await _exportManager.exportSides(
        plan: plan,
        dayId: options.dayId,
        documents: documents,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: modeBloc.state.title,
        includeSceneNumbers: options.includeSceneNumbers,
        presentation: options.presentation,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptScheduleIoNotice(
            kind: OcptScheduleIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the sides of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptScheduleIoNotice(kind: OcptScheduleIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Every live episode [dayId] plays, in [OcptScheduleState.episodes]' own order, each paired with
  /// its own freshly-parsed screenplay text — what [_onSidesExportRequested] hands
  /// [OcptExportManager.exportSides].
  ///
  /// [OcptSchedulePlanSnapshot.sceneIdsOfDay] gives the day's own scenes, and
  /// [OcptSchedulePlanSnapshot.screenplayIdBySceneId] the episode each belongs to; the resulting id
  /// set is walked against [OcptScheduleState.episodes] rather than the other way round, so an
  /// episode the day does not play is silently absent and the ones it does play come out in the
  /// project's own episode order regardless of which scene happened to name them first.
  Future<List<({String screenplayId, FountainDocument document})>> _documentsOfDay({
    required OcptOpenProjectModel project,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
  }) async {
    final dayEpisodeIds = {
      for (final sceneId in plan.sceneIdsOfDay(dayId))
        if (plan.screenplayIdBySceneId[sceneId] case final screenplayId?) screenplayId,
    };

    const parser = FountainParser();
    final documents = <({String screenplayId, FountainDocument document})>[];
    for (final episode in modeBloc.state.episodes) {
      if (!dayEpisodeIds.contains(episode.id)) {
        continue;
      }

      final screenplayText = await _projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: episode.id,
      );
      documents.add((screenplayId: episode.id, document: parser.parse(screenplayText)));
    }

    return documents;
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptScheduleIoNoticeDismissedEvent event,
    Emitter<OcptScheduleExportState> emitter,
  ) async {
    emitter(state.copyWith(forceIoNoticeValue: true));
  }
}
