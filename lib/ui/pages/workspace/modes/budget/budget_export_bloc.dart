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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_export_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';

/// This is the bloc class for the budget mode's exports: the quote, the financing plan and the
/// financial report as PDFs, and the cash journal as an XLSX workbook.
///
/// The exports read the budget rather than writing to it, so this bloc owns no data of its own:
/// it asks [OcptBudgetBloc] to write every pending edit first
/// ([OcptBudgetBloc.flushAllPendingWrites], which also reads the snapshot again, so a figure typed
/// seconds before the export is in the document and not only on screen), then hands what the
/// mode's state now carries to [OcptExportManager], which owns both the document building and the
/// native save dialog. A cancelled save dialog is a silent no-op; a failure raises the transient
/// export-failed notice in [OcptBudgetExportState.ioNotice]; and when a pending edit could not be
/// written nothing is exported, since the document would print the value the database still holds.
class OcptBudgetExportBloc
    extends AbsOcptViewBloc<OcptBudgetExportState, OcptBudgetState, OcptBudgetBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "budget_export_bloc";

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
  OcptBudgetExportBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptExportManager? exportManager,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       super(const OcptBudgetExportState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBudgetQuoteExportRequestedEvent>(_onQuoteExportRequested);
    on<OcptBudgetFinancingPlanExportRequestedEvent>(_onFinancingPlanExportRequested);
    on<OcptBudgetCashJournalExportRequestedEvent>(_onCashJournalExportRequested);
    on<OcptBudgetFinancialReportExportRequestedEvent>(_onFinancialReportExportRequested);
    on<OcptBudgetIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// Exports the quote as a single PDF, written through the native save dialog.
  ///
  /// Built exactly as every other mode's own export handlers are: have the mode write whatever
  /// field edit is still sitting in the debounce first — an export must never print a figure the user has typed
  /// but the debounce has not yet written (`OcptBudgetMode`'s own class doc comment) — then hand
  /// what the mode's state now carries to [OcptExportManager.exportBudgetQuote]. A cancelled save dialog is
  /// a silent no-op; a failure raises the transient export-failed notice. Nothing is exported when the write of a
  /// pending edit failed.
  Future<void> _onQuoteExportRequested(
    OcptBudgetQuoteExportRequestedEvent event,
    Emitter<OcptBudgetExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final modeState = modeBloc.state;
    final snapshot = modeState.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportBudgetQuote(
        snapshot: snapshot,
        elementNameById: event.elementNameById,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        taxBasis: options.taxBasis,
        labels: event.labels,
        projectName: modeState.title,
        includeTitlePage: options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWithIoNotice(
          ioNotice: OcptBudgetIoNotice(
            kind: OcptBudgetIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the quote of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the financing plan as a single PDF, written through the native save dialog. Mirrors
  /// [_onQuoteExportRequested] — see its own doc comment for the flush and the cancellation
  /// contract, identical here.
  Future<void> _onFinancingPlanExportRequested(
    OcptBudgetFinancingPlanExportRequestedEvent event,
    Emitter<OcptBudgetExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final modeState = modeBloc.state;
    final snapshot = modeState.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportBudgetFinancingPlan(
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: modeState.title,
        includeTitlePage: options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWithIoNotice(
          ioNotice: OcptBudgetIoNotice(
            kind: OcptBudgetIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the financing plan of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the cash journal as a single XLSX workbook, written through the native save dialog.
  ///
  /// Built exactly as [_onQuoteExportRequested] is: flush whatever is still pending, then hand what
  /// [state] now carries to [OcptExportManager.exportBudgetCashJournalXlsx]. There is no options
  /// dialog to read first — this export takes none.
  Future<void> _onCashJournalExportRequested(
    OcptBudgetCashJournalExportRequestedEvent event,
    Emitter<OcptBudgetExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final modeState = modeBloc.state;
    final snapshot = modeState.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final outcome = await _exportManager.exportBudgetCashJournalXlsx(
        snapshot: snapshot,
        linkLabelByEntryId: event.linkLabelByEntryId,
        labels: event.labels,
        projectName: modeState.title,
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
          state.copyWithIoNotice(
            ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed),
          ),
        );
        return;
      }

      emitter(
        state.copyWithIoNotice(
          ioNotice: OcptBudgetIoNotice(
            kind: OcptBudgetIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the cash journal of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the financial report as a single PDF, written through the native save dialog. Mirrors
  /// [_onQuoteExportRequested] — see its own doc comment for the flush and the cancellation
  /// contract, identical here.
  Future<void> _onFinancialReportExportRequested(
    OcptBudgetFinancialReportExportRequestedEvent event,
    Emitter<OcptBudgetExportState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final modeState = modeBloc.state;
    final snapshot = modeState.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final outcome = await _exportManager.exportBudgetFinancialReport(
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: modeState.title,
        includeTitlePage: options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
        shareAnchor: event.shareAnchor,
      );
      if (outcome == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWithIoNotice(
          ioNotice: OcptBudgetIoNotice(
            kind: OcptBudgetIoNoticeKind.fileExportSucceeded,
            path: outcome.savedPath,
            wasShared: outcome.wasShared,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to export the financial report of project "
        "${_projectsManager.currentProject?.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWithIoNotice(
          ioNotice: const OcptBudgetIoNotice(kind: OcptBudgetIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptBudgetIoNoticeDismissedEvent event,
    Emitter<OcptBudgetExportState> emitter,
  ) async {
    emitter(state.copyWithIoNoticeDismissed());
  }
}
