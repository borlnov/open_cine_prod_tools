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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';

/// This is the bloc class for the breakdown mode's exports: the breakdown sheets PDF and the
/// two-sheet XLSX workbook.
///
/// The exports read the breakdown rather than writing to it, so this bloc owns no data of its own:
/// it asks [OcptBreakdownBloc] to write every pending edit first
/// ([OcptBreakdownBloc.flushAllPendingWrites], which also reads the snapshot again, so a note
/// typed seconds before the export is in the document and not only on screen), then hands what the
/// mode's state now carries to [OcptExportManager], which owns both the document building and the
/// native save dialog. A cancelled save dialog is a silent no-op; a failure raises the transient
/// export-failed notice in [OcptBreakdownExportState.ioNotice].
class OcptBreakdownExportBloc
    extends AbsOcptViewBloc<OcptBreakdownExportState, OcptBreakdownState, OcptBreakdownBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "breakdown_export_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The manager used to read which project is open, for the log of a failed export.
  final OcptProjectsManager _projectsManager;

  /// The manager used to build and save each document.
  final OcptExportManager _exportManager;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt].
  OcptBreakdownExportBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptExportManager? exportManager,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       super(const OcptBreakdownExportState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBreakdownSheetsExportRequestedEvent>(_onSheetsExportRequested);
    on<OcptBreakdownXlsxExportRequestedEvent>(_onXlsxExportRequested);
    on<OcptBreakdownIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// Exports one breakdown sheet per scene, as a PDF.
  ///
  /// Writes every pending edit first — that also re-reads the snapshot, so a sheet holds the name or
  /// the note the user typed seconds ago — then hands what the mode's state now carries to
  /// [OcptExportManager.exportBreakdownSheets]. A cancelled save dialog is a silent no-op; a
  /// failure raises the transient export-failed notice.
  ///
  /// `OcptBreakdownState.screenplayText` is parsed here rather than kept parsed in the state: the
  /// document is only needed by this export, and only for each scene's own length.
  Future<void> _onSheetsExportRequested(
    OcptBreakdownSheetsExportRequestedEvent event,
    Emitter<OcptBreakdownExportState> emitter,
  ) async {
    await modeBloc.flushAllPendingWrites();

    final modeState = modeBloc.state;
    final snapshot = modeState.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportBreakdownSheets(
        document: const FountainParser().parse(modeState.screenplayText),
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: modeState.title,
        onlyDoneScenes: options.onlyDoneScenes,
        includeNotes: options.includeNotes,
        includeToFindList: options.includeToFindList,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWithIoNotice(
          ioNotice: OcptBreakdownIoNotice(
            kind: OcptBreakdownIoNoticeKind.sheetsExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the breakdown sheets of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptBreakdownIoNotice(kind: OcptBreakdownIoNoticeKind.sheetsExportFailed),
        ),
      );
    }
  }

  /// Exports the whole breakdown as a two-sheet XLSX workbook.
  ///
  /// Built exactly as [_onSheetsExportRequested] is: write every pending edit, then hand what the
  /// mode's state now carries to [OcptExportManager.exportBreakdownXlsx]. There is no options
  /// dialog to read first — this export takes none.
  Future<void> _onXlsxExportRequested(
    OcptBreakdownXlsxExportRequestedEvent event,
    Emitter<OcptBreakdownExportState> emitter,
  ) async {
    await modeBloc.flushAllPendingWrites();

    final modeState = modeBloc.state;
    final snapshot = modeState.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final outcome = await _exportManager.exportBreakdownXlsx(
        document: const FountainParser().parse(modeState.screenplayText),
        snapshot: snapshot,
        pageSetup: modeState.pageSetup,
        labels: event.labels,
        projectName: modeState.title,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      if (outcome is OcptExportFailed) {
        // The manager already logged why the workbook could not be built.
        emitter(
          state.copyWithIoNotice(
            ioNotice: const OcptBreakdownIoNotice(kind: OcptBreakdownIoNoticeKind.xlsxExportFailed),
          ),
        );
        return;
      }

      emitter(
        state.copyWithIoNotice(
          ioNotice: OcptBreakdownIoNotice(
            kind: OcptBreakdownIoNoticeKind.xlsxExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the breakdown workbook of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptBreakdownIoNotice(kind: OcptBreakdownIoNoticeKind.xlsxExportFailed),
        ),
      );
    }
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptBreakdownIoNoticeDismissedEvent event,
    Emitter<OcptBreakdownExportState> emitter,
  ) async {
    emitter(state.copyWithIoNoticeDismissed());
  }
}
