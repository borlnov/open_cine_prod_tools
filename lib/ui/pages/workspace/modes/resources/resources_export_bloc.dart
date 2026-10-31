// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';

/// This is the bloc class for the resources mode's exports: the four-sheet XLSX workbook and the
/// contact list PDF.
///
/// The exports read the catalogue rather than writing to it, so this bloc owns no data of its own:
/// it asks [OcptResourcesBloc] to write every pending edit first
/// ([OcptResourcesBloc.flushAllPendingWrites], which also reads the snapshot again, so a value
/// typed seconds before the export is in the document and not only on screen), then hands what the
/// mode's state now carries to [OcptExportManager], which owns both the document building and the
/// native save dialog. A cancelled save dialog is a silent no-op; a failure raises the transient
/// export-failed notice in [OcptResourcesExportState.ioNotice].
class OcptResourcesExportBloc
    extends AbsOcptViewBloc<OcptResourcesExportState, OcptResourcesState, OcptResourcesBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "resources_export_bloc";

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
  OcptResourcesExportBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptExportManager? exportManager,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       super(const OcptResourcesExportState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptResourcesXlsxExportRequestedEvent>(_onXlsxExportRequested);
    on<OcptResourcesContactListExportRequestedEvent>(_onContactListExportRequested);
    on<OcptResourcesIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// Exports the whole resources catalogue to a four-sheet XLSX workbook.
  ///
  /// Writes every pending edit first — that also re-reads the snapshot, so the workbook holds the
  /// value the user typed seconds ago rather than the one the database held before it — then hands
  /// what the mode's state now carries to [OcptExportManager.exportResourcesXlsx]. A cancelled save
  /// dialog is a silent no-op; a failure raises the transient export-failed notice.
  Future<void> _onXlsxExportRequested(
    OcptResourcesXlsxExportRequestedEvent event,
    Emitter<OcptResourcesExportState> emitter,
  ) async {
    await modeBloc.flushAllPendingWrites();

    final snapshot = modeBloc.state.snapshot;
    final project = _projectsManager.currentProject;
    if (snapshot == null || project == null) {
      return;
    }

    try {
      final outcome = await _exportManager.exportResourcesXlsx(
        snapshot: snapshot,
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
            ioNotice: const OcptResourcesIoNotice(kind: OcptResourcesIoNoticeKind.xlsxExportFailed),
          ),
        );
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptResourcesIoNotice(
            kind: OcptResourcesIoNoticeKind.xlsxExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the resources catalogue of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptResourcesIoNotice(kind: OcptResourcesIoNoticeKind.xlsxExportFailed),
        ),
      );
    }
  }

  /// Exports the crew and the cast to a standalone contact list PDF.
  ///
  /// Writes every pending edit first, exactly as [_onXlsxExportRequested] does, then hands what the
  /// mode's state now carries and [event]'s own options to [OcptExportManager.exportContactList].
  /// A cancelled save dialog is a silent no-op; a failure raises the transient export-failed
  /// notice.
  Future<void> _onContactListExportRequested(
    OcptResourcesContactListExportRequestedEvent event,
    Emitter<OcptResourcesExportState> emitter,
  ) async {
    await modeBloc.flushAllPendingWrites();

    final snapshot = modeBloc.state.snapshot;
    final project = _projectsManager.currentProject;
    if (snapshot == null || project == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportContactList(
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: modeBloc.state.title,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptResourcesIoNotice(
            kind: OcptResourcesIoNoticeKind.contactListExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the contact list of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          ioNotice: const OcptResourcesIoNotice(
            kind: OcptResourcesIoNoticeKind.contactListExportFailed,
          ),
        ),
      );
    }
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptResourcesIoNoticeDismissedEvent event,
    Emitter<OcptResourcesExportState> emitter,
  ) async {
    emitter(state.copyWith(forceIoNoticeValue: true));
  }
}
