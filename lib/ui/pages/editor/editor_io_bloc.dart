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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';

/// This is the bloc class for the screenplay editor's file exchanges: the `.fountain` export, the
/// PDF export, and importing a screenplay file over the current text.
///
/// The text stays the mode's: this bloc asks it to write what is pending before an export reads it
/// (`OcptEditorBloc` saves a dirty text tagged `OcptSnapshotReason.export`), reads the text the
/// mode's state then holds, and hands it to [OcptExportManager], which owns both the document
/// building and the native save dialog. An import is the one flow that writes: it has the mode save
/// the typed text first, so the snapshot of the replaced screenplay holds it, writes the imported
/// text through [OcptScreenplayService], and hands it to the mode to show. A cancelled dialog is a
/// silent no-op; a failure raises the transient notice in [OcptEditorIoState.ioNotice].
class OcptEditorIoBloc extends AbsOcptViewBloc<OcptEditorIoState, OcptEditorState, OcptEditorBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "editor_io_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to export the screenplay to, and import it from, a file.
  final OcptExportManager _exportManager;

  /// The service used to write the imported text.
  final OcptScreenplayService _screenplayService;

  /// {@template open_cine_prod_tools.viewBlocConstructor}
  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt].
  /// {@endtemplate}
  OcptEditorIoBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptExportManager? exportManager,
    OcptScreenplayService? screenplayService,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _screenplayService =
           screenplayService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).screenplayService,
       super(const OcptEditorIoState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptEditorExportRequestedEvent>(_onExportRequested);
    on<OcptEditorExportPdfRequestedEvent>(_onExportPdfRequested);
    on<OcptEditorImportRequestedEvent>(_onImportRequested);
    on<OcptEditorIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// Export the current screenplay to a `.fountain` file.
  ///
  /// Has the mode save the current text first (tagged `OcptSnapshotReason.export`) if it's dirty,
  /// so the exported file matches exactly what the project stores. A cancelled save dialog is a
  /// silent no-op; a failure raises the transient export-failed notice.
  Future<void> _onExportRequested(
    OcptEditorExportRequestedEvent event,
    Emitter<OcptEditorIoState> emitter,
  ) async {
    await addToModeAndWait(const OcptEditorSaveForExportRequestedEvent());

    try {
      final outcome = await _exportManager.exportFountain(
        fountainText: modeBloc.state.text,
        projectName: modeBloc.state.title,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      // A null outcome is the user cancelling the save dialog: nothing is reported.
      if (outcome != null) {
        emitter(
          state.copyWithIoNotice(
            ioNotice: OcptEditorIoNotice(
              kind: OcptEditorIoNoticeKind.exportSucceeded,
              path: outcome.savedPath,
              wasShared: outcome.wasShared,
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the screenplay of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Export the current screenplay to a PDF file.
  ///
  /// Has the mode save the current text first (tagged `OcptSnapshotReason.export`) if it's dirty,
  /// so the exported PDF matches exactly what the project stores. The document is re-parsed fresh
  /// from `OcptEditorState.text` rather than reusing `OcptEditorState.document`, since the latter
  /// lags behind by the parse debounce. A cancelled save dialog is a silent no-op; a failure raises
  /// the transient PDF-export-failed notice.
  Future<void> _onExportPdfRequested(
    OcptEditorExportPdfRequestedEvent event,
    Emitter<OcptEditorIoState> emitter,
  ) async {
    await addToModeAndWait(const OcptEditorSaveForExportRequestedEvent());

    try {
      final document = const FountainParser().parse(modeBloc.state.text);
      final pageSetup = OcptPageSetup(format: event.options.format, margins: event.options.margins);
      final outcome = await _exportManager.exportPdf(
        document: document,
        pageSetup: pageSetup,
        projectName: modeBloc.state.title,
        includeSceneNumbers: event.options.includeSceneNumbers,
        includeTitlePage: event.options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
        episodeTag: event.episodeTag,
        shareAnchor: event.shareAnchor,
      );
      // A null outcome is the user cancelling the save dialog: nothing is reported.
      if (outcome != null) {
        emitter(
          state.copyWithIoNotice(
            ioNotice: OcptEditorIoNotice(
              kind: OcptEditorIoNoticeKind.pdfExportSucceeded,
              path: outcome.savedPath,
              wasShared: outcome.wasShared,
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the screenplay of project "
        "${_projectsManager.currentProject?.primaryScreenplayId} to PDF: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.pdfExportFailed),
        ),
      );
    }
  }

  /// Replace the current screenplay text with the content of a picked screenplay file.
  ///
  /// The picked file may be a `.fountain`, an `.fdx` or a `.celtx`, the last two being converted
  /// to Fountain as they are read, so what replaces the text is Fountain either way.
  ///
  /// If the editor is dirty, the mode saves the current text first (tagged
  /// `OcptSnapshotReason.manual`) so the pre-import snapshot holds the user's latest keystrokes
  /// rather than a stale database copy; the imported text is then saved, tagged
  /// `OcptSnapshotReason.import`, which snapshots the pre-import text, and handed to the mode to
  /// show. A cancelled file dialog is a silent no-op; a file that cannot be read as a screenplay
  /// raises the transient import-unreadable notice and replaces nothing, and a write failure raises
  /// the import-failed one.
  Future<void> _onImportRequested(
    OcptEditorImportRequestedEvent event,
    Emitter<OcptEditorIoState> emitter,
  ) async {
    final result = await _exportManager.pickAndReadScreenplay(fileTypeLabel: event.fileTypeLabel);
    final imported = result.value;
    if (!result.status.isSuccess || imported == null) {
      // A cancelled dialog, or a selection that failed, is a silent no-op: the OS dialog itself
      // already reported the latter. A file that could not be read is the one outcome worth
      // stating, and it leaves the screenplay on screen exactly as it was.
      if (result.status != OcptScreenplayImportStatus.cancelled) {
        emitter(
          state.copyWithIoNotice(
            ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.importUnreadable),
          ),
        );
      }
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      if (await modeBloc.flushAllPendingWrites()) {
        await _screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: modeBloc.screenplayIdOf(project),
          fountainText: imported.fountainText,
          snapshotReason: OcptSnapshotReason.import,
        );

        await addToModeAndWait(OcptEditorImportedTextAppliedEvent(text: imported.fountainText));

        emitter(
          state.copyWithIoNotice(
            ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.importSucceeded),
          ),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to import a fountain file into project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.importFailed),
        ),
      );
    }
  }

  /// Clear the transient export/import notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptEditorIoNoticeDismissedEvent event,
    Emitter<OcptEditorIoState> emitter,
  ) async {
    emitter(state.copyWithIoNoticeDismissed());
  }
}
