// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_export_document.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_export_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_call_sheets_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_centre.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_out_of_days_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_month_grid.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_named_call_sheets_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_one_line_schedule_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_right_dock_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shooting_plan_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shooting_plan_xlsx_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shot_picker_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_sides_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_status_bar_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_strip_agenda.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_view_effects.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_week_grid.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// The schedule production mode: planning the shoot day by day.
///
/// The left dock lists the shooting days over the shots still to place, grouped by sequence — a
/// click on an unplaced shot brings its own read-out up in the inspector, purely informative; a
/// shot is placed from a slot card's own `+ Block` menu instead, in the day view. The centre is
/// `OcptScheduleHeader`'s own `Agenda`/`Day` switch over either the agenda —
/// [OcptScheduleStripAgenda], [OcptScheduleWeekGrid] or [OcptScheduleMonthGrid], per
/// [OcptScheduleState.agendaMode] — or [OcptScheduleDayView], the mode's own working surface (the
/// day's summary band, then one slot card per convocation, each carrying its own chained
/// timetable). The right dock is `Inspector` (the selected block's own read-out, else the selected
/// shot's own, else the selected day's own) + `Convocations` (the selected day's whole call, one
/// row per person or per uncast role, ADR 0018) + the shared `Versions` tab.
///
/// **There is no save control and no mode-specific toolbar action**: every write here is its own
/// event, exactly as the breakdown mode's own shell is built. **Nor is there an episode
/// selector**: the mode reads every episode of the project at once, so it withholds the shell's
/// own `onEpisodeSelected` outright.
class OcptScheduleMode extends StatelessWidget {
  /// Create the schedule mode.
  const OcptScheduleMode({super.key});

  /// Build the schedule mode as a [MultiBlocProvider].
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (context) => OcptScheduleBloc()),
      // Built with the mode rather than on first read: a view bloc registers itself with the mode
      // bloc when it is built, and one that is not there yet cannot be asked to write what it
      // holds.
      BlocProvider(
        lazy: false,
        create: (context) => OcptScheduleExportBloc(modeBloc: context.read<OcptScheduleBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptScheduleDayBloc(modeBloc: context.read<OcptScheduleBloc>()),
      ),
    ],
    child: const OcptScheduleViewEffects(child: _ScheduleView()),
  );
}

/// The content of [OcptScheduleMode], separated from it so [OcptScheduleMode] only wires the
/// [OcptScheduleBloc] up.
///
/// A StatefulWidget (the documented exception) because it owns the dock layout controller,
/// mirroring `_BreakdownView`/`_ShotListView`/`_ResourcesView`.
class _ScheduleView extends StatefulWidget {
  /// Class constructor
  const _ScheduleView();

  /// Create the [_ScheduleViewState] holding the state of the schedule view.
  @override
  State<_ScheduleView> createState() => _ScheduleViewState();
}

/// The state of [_ScheduleView]: owns the dock layout controller and keeps it in sync with the
/// fractions the bloc holds.
class _ScheduleViewState extends State<_ScheduleView> {
  /// The live source of truth for the two dock fractions while dragging a divider.
  final OcptWorkspaceDockLayoutController _dockLayoutController = OcptWorkspaceDockLayoutController(
    leftFraction: OcptWorkspaceDock.leftDefaultFraction,
    rightFraction: OcptWorkspaceDock.rightDefaultFraction,
  );

  /// Flush the pending field edits of the bloc before the view leaves the tree.
  @override
  void deactivate() {
    // Triggering the flush here, rather than dispatching an event, is what guarantees the last
    // debounce worth of typing into the inspector's own note fields survives a mode switch — going
    // back to the projects flushes in the bloc, before the project is closed. See
    // `OcptScheduleBloc.flushPendingFieldEdits`'s own doc comment.
    unawaited(context.read<OcptScheduleBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

  /// Build the schedule view as a [BlocConsumer].
  @override
  Widget build(BuildContext context) => BlocConsumer<OcptScheduleBloc, OcptScheduleState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return OcptWorkspaceShell(
        title: state.title,
        isDirty: false,
        isReadOnly: state.isPreviewingVersion,
        onBack: () => context.read<OcptScheduleBloc>().add(const OcptScheduleBackRequestedEvent()),
        // No episode selector here, left at its default null: the schedule reads every episode of
        // the project at once, so a selector would either do nothing or lie about what the day
        // view and the agenda show.
        modeLabel: Tr.of(context).workspaceModeLabelSchedule,
        onExportRequested: (anchor) => unawaited(_requestExport(context, state, anchor)),
        // The mode's `⋮` overflow menu: resetting the panel layout, alone — the exports are the
        // toolbar's own `Export` button and its panel (see [_requestExport]). A `⋮` holding one
        // entry is thin, but honest: moving it somewhere else is a separate question.
        overflowEntries: [
          PopupMenuItem<void>(
            onTap: () =>
                context.read<OcptScheduleBloc>().add(const OcptScheduleDockLayoutResetEvent()),
            child: Text(Tr.of(context).scheduleResetPanelLayoutAction),
          ),
        ],
        isLeftDockOpen: state.isListPanelVisible,
        onToggleLeftDock: () =>
            context.read<OcptScheduleBloc>().add(const OcptScheduleLeftPanelToggledEvent()),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () =>
            context.read<OcptScheduleBloc>().add(const OcptScheduleRightDockToggledEvent()),
        onProjectSettingsRequested: state.isPreviewingVersion
            ? null
            : () => unawaited(_requestProjectSettings(context)),
        banner: state.previewedVersion == null
            ? null
            : OcptScheduleReadOnlyBanner(previewedVersion: state.previewedVersion!),
        leftPanel: state.isListPanelVisible
            ? OcptScheduleLeftDockView(
                state: state,
                onDayDeletionRequested: (dayId) =>
                    unawaited(_handleDayDeletionRequested(context, dayId)),
              )
            : null,
        rightPanel: state.rightDockTab == null
            ? null
            : OcptScheduleRightDockView(
                state: state,
                onEventDeletionRequested: (eventId) =>
                    unawaited(_handleDayEventDeletionRequested(context, eventId)),
              ),
        centre: OcptScheduleCentre(
          state: state,
          onSlotDeletionRequested: (slotId) =>
              unawaited(_handleSlotDeletionRequested(context, slotId)),
          onBlockDeletionRequested: (blockId) =>
              unawaited(_handleBlockDeletionRequested(context, blockId)),
          onEventDeletionRequested: (eventId) =>
              unawaited(_handleDayEventDeletionRequested(context, eventId)),
          onShotBlockRequested: (slotId) => unawaited(_handleShotBlockRequested(context, slotId)),
        ),
        statusBar: OcptScheduleStatusBarView(state: state),
        dockLayoutController: _dockLayoutController,
        onDockFractionsChanged: (fractions) => context.read<OcptScheduleBloc>().add(
          OcptScheduleDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
        ),
      );
    },
  );

  /// Build the seven entries the toolbar's `Export` button offers, disabled together when the
  /// project holds no live day at all — there would be nothing to print, and the sides dialog
  /// additionally relies on it, its day dropdown having to open on some day.
  ///
  /// The named call sheets entry needs no further check of its own: which recipients (and which
  /// days) it prints is a question answered **inside** `OcptScheduleNamedCallSheetsExportDialog`
  /// itself, whose own `Export` button is already disabled while no day or no recipient is ticked —
  /// walking every ticked day's own convocations here too, on every rebuild of this shell, would
  /// repeat that same read for no reason.
  List<OcptWorkspaceExportEntry<OcptScheduleExportDocument>> _buildExportEntries(
    BuildContext context,
    OcptScheduleState state,
  ) {
    final tr = Tr.of(context);
    final unavailableReason = state.days.isNotEmpty ? null : tr.scheduleExportUnavailableReason;

    return [
      OcptWorkspaceExportEntry<OcptScheduleExportDocument>(
        value: OcptScheduleExportDocument.callSheets,
        title: tr.scheduleExportPanelCallSheetsTitle,
        description: tr.scheduleExportPanelCallSheetsDescription,
        formatLabel: "PDF",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptScheduleExportDocument>(
        value: OcptScheduleExportDocument.namedCallSheets,
        title: tr.scheduleExportPanelNamedCallSheetsTitle,
        description: tr.scheduleExportPanelNamedCallSheetsDescription,
        formatLabel: "PDF",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptScheduleExportDocument>(
        value: OcptScheduleExportDocument.shootingPlan,
        title: tr.scheduleExportPanelShootingPlanTitle,
        description: tr.scheduleExportPanelShootingPlanDescription,
        formatLabel: "PDF",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptScheduleExportDocument>(
        value: OcptScheduleExportDocument.shootingPlanXlsx,
        title: tr.scheduleExportPanelShootingPlanXlsxTitle,
        description: tr.scheduleExportPanelShootingPlanXlsxDescription,
        formatLabel: "XLSX",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptScheduleExportDocument>(
        value: OcptScheduleExportDocument.dayOutOfDays,
        title: tr.scheduleExportPanelDayOutOfDaysTitle,
        description: tr.scheduleExportPanelDayOutOfDaysDescription,
        formatLabel: "PDF",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptScheduleExportDocument>(
        value: OcptScheduleExportDocument.oneLineSchedule,
        title: tr.scheduleExportPanelOneLineScheduleTitle,
        description: tr.scheduleExportPanelOneLineScheduleDescription,
        formatLabel: "PDF",
        unavailableReason: unavailableReason,
      ),
      OcptWorkspaceExportEntry<OcptScheduleExportDocument>(
        value: OcptScheduleExportDocument.sides,
        title: tr.scheduleExportPanelSidesTitle,
        description: tr.scheduleExportPanelSidesDescription,
        formatLabel: "PDF",
        unavailableReason: unavailableReason,
      ),
    ];
  }

  /// Open the export panel, then dispatch the picked document's own request onto the mode's
  /// existing `_request…Export` methods, unchanged: every one of the six opens its own options
  /// dialog, exactly as it always has.
  Future<void> _requestExport(
    BuildContext context,
    OcptScheduleState state,
    Rect? shareAnchor,
  ) async {
    final tr = Tr.of(context);
    final picked = await OcptWorkspaceExportDialog.show<OcptScheduleExportDocument>(
      context,
      title: tr.scheduleExportPanelTitle,
      message: tr.scheduleExportPanelMessage,
      entries: _buildExportEntries(context, state),
      isPreviewingVersion: state.isPreviewingVersion,
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    switch (picked) {
      case OcptWorkspaceExportDocumentPick<OcptScheduleExportDocument>(:final document):
        switch (document) {
          case OcptScheduleExportDocument.callSheets:
            await _requestCallSheetsExport(context, state, shareAnchor);
          case OcptScheduleExportDocument.namedCallSheets:
            await _requestNamedCallSheetsExport(context, state, shareAnchor);
          case OcptScheduleExportDocument.shootingPlan:
            await _requestShootingPlanExport(context, state, shareAnchor);
          case OcptScheduleExportDocument.shootingPlanXlsx:
            await _requestShootingPlanXlsxExport(context, state, shareAnchor);
          case OcptScheduleExportDocument.dayOutOfDays:
            await _requestDayOutOfDaysExport(context, state, shareAnchor);
          case OcptScheduleExportDocument.oneLineSchedule:
            await _requestOneLineScheduleExport(context, state, shareAnchor);
          case OcptScheduleExportDocument.sides:
            await _requestSidesExport(context, state, shareAnchor);
        }
      case OcptWorkspaceExportProjectPackagePick<OcptScheduleExportDocument>():
        _requestProjectPackageExport(context);
    }
  }

  /// Get [dayId]'s own convocations that a named call sheet can be addressed to — every one
  /// carrying an
  /// [OcptDayConvocation.selectionKey], which is to say everybody but its **guests** — read by the
  /// named call sheets dialog for whichever days the user ticks there, rather than
  /// [OcptScheduleState.convocationsOfDay] directly.
  ///
  /// A guest is not a call sheet recipient, and every reader downstream of this list — the dialog's
  /// own selection keys among them — assumes every entry has one. A crew member, a cast member, an
  /// uncast role and a **candidate** all do: somebody coming to be seen for a part is convoked like
  /// anybody else (ADR 0018) and is owed the sheet saying when.
  List<OcptDayConvocation> _namedCallSheetRecipientsOf(OcptScheduleState state, String dayId) => [
    for (final convocation in state.convocationsOfDay(dayId))
      if (convocation.selectionKey != null) convocation,
  ];

  /// Show the general call sheets export options dialog, then dispatch the export request if the
  /// user applied it, resolving here — the last place with a [BuildContext] — every localized
  /// string the exported documents and the native folder dialog carry.
  Future<void> _requestCallSheetsExport(
    BuildContext context,
    OcptScheduleState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptScheduleExportBloc>();
    final options = await OcptScheduleCallSheetsExportDialog.show(
      context,
      current: state.pageSetup,
      days: state.days,
      selectedDayId: state.selectedDayId,
    );
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptScheduleCallSheetsExportRequestedEvent(
        options: options,
        labels: ocptCallSheetLabelsOf(context, days: state.days, people: state.people),
        confirmButtonText: tr.scheduleExportChooseFolderAction,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the named call sheets export options dialog, then dispatch the export request if the
  /// user applied it — mirrors [_requestCallSheetsExport]. The dialog picks its own days (the
  /// mode's own selection ticked by default, as [_requestCallSheetsExport]'s general dialog does),
  /// so no day needs to be selected for this to run.
  Future<void> _requestNamedCallSheetsExport(
    BuildContext context,
    OcptScheduleState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptScheduleExportBloc>();
    final options = await OcptScheduleNamedCallSheetsExportDialog.show(
      context,
      current: state.pageSetup,
      days: state.days,
      selectedDayId: state.selectedDayId,
      recipientsOfDay: (dayId) => _namedCallSheetRecipientsOf(state, dayId),
      personById: state.personById,
      roleById: state.roleById,
    );
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptScheduleNamedCallSheetsExportRequestedEvent(
        options: options,
        labels: ocptCallSheetLabelsOf(context, days: state.days, people: state.people),
        confirmButtonText: tr.scheduleExportChooseFolderAction,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the shooting plan export options dialog, then dispatch the export request if the user
  /// applied it — mirrors [_requestCallSheetsExport].
  Future<void> _requestShootingPlanExport(
    BuildContext context,
    OcptScheduleState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptScheduleExportBloc>();
    final options = await OcptScheduleShootingPlanExportDialog.show(
      context,
      current: state.pageSetup,
      days: state.days,
    );
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptScheduleShootingPlanExportRequestedEvent(
        options: options,
        labels: ocptShootingPlanLabelsOf(context, days: state.days, people: state.people),
        fileTypeLabel: tr.scheduleExportFileTypeLabel,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the shooting plan **workbook**'s own export options dialog, then dispatch the export
  /// request if the user applied it — mirrors [_requestShootingPlanExport], its dialog asking for
  /// the days and nothing else (`OcptScheduleShootingPlanXlsxExportDialog`'s own doc comment).
  Future<void> _requestShootingPlanXlsxExport(
    BuildContext context,
    OcptScheduleState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptScheduleExportBloc>();
    final options = await OcptScheduleShootingPlanXlsxExportDialog.show(context, days: state.days);
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptScheduleShootingPlanXlsxExportRequestedEvent(
        options: options,
        labels: ocptShootingPlanXlsxLabelsOf(context),
        fileTypeLabel: tr.scheduleExportXlsxFileTypeLabel,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the *Day Out of Days* export options dialog, then dispatch the export request if the
  /// user applied it — mirrors [_requestShootingPlanExport].
  Future<void> _requestDayOutOfDaysExport(
    BuildContext context,
    OcptScheduleState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptScheduleExportBloc>();
    final options = await OcptScheduleDayOutOfDaysExportDialog.show(
      context,
      current: state.pageSetup,
      days: state.days,
    );
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptScheduleDayOutOfDaysExportRequestedEvent(
        options: options,
        labels: ocptDayOutOfDaysLabelsOf(context, days: state.days, people: state.people),
        fileTypeLabel: tr.scheduleExportFileTypeLabel,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the one-line schedule export options dialog, then dispatch the export request if the
  /// user applied it — mirrors [_requestDayOutOfDaysExport].
  Future<void> _requestOneLineScheduleExport(
    BuildContext context,
    OcptScheduleState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptScheduleExportBloc>();
    final options = await OcptScheduleOneLineScheduleExportDialog.show(
      context,
      current: state.pageSetup,
      days: state.days,
    );
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptScheduleOneLineScheduleExportRequestedEvent(
        options: options,
        labels: ocptOneLineScheduleLabelsOf(context, days: state.days, people: state.people),
        fileTypeLabel: tr.scheduleExportFileTypeLabel,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Show the sides export options dialog, then dispatch the export request if the user applied
  /// it — mirrors [_requestOneLineScheduleExport], but hands the dialog the mode's own selected day
  /// to open on, a booklet being about one day rather than a range.
  Future<void> _requestSidesExport(
    BuildContext context,
    OcptScheduleState state,
    Rect? shareAnchor,
  ) async {
    final bloc = context.read<OcptScheduleExportBloc>();
    final options = await OcptScheduleSidesExportDialog.show(
      context,
      current: state.pageSetup,
      days: state.days,
      selectedDayId: state.selectedDayId,
    );
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final tr = Tr.of(context);
    bloc.add(
      OcptScheduleSidesExportRequestedEvent(
        options: options,
        labels: ocptSidesLabelsOf(
          context,
          day: state.days.where((day) => day.id == options.dayId).firstOrNull,
          episodes: state.episodes,
        ),
        fileTypeLabel: tr.scheduleExportFileTypeLabel,
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Ask `OcptConfirmDialog` whether day [dayId] really is to be deleted, then dispatch the
  /// deletion if the user answered `Delete`.
  Future<void> _handleDayDeletionRequested(BuildContext context, String dayId) async {
    final bloc = context.read<OcptScheduleBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.scheduleDeleteDayConfirmTitle,
      message: tr.scheduleDeleteDayConfirmMessage,
      cancelLabel: tr.scheduleDeleteDayCancelAction,
      confirmLabel: tr.scheduleDeleteDayConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptScheduleDayDeletionConfirmedEvent(dayId: dayId));
  }

  /// Open the project settings page, then re-read the page setup if the user changed something —
  /// mirrors `OcptBreakdownMode._requestProjectSettings`/`OcptShotListMode`'s own handler: the page
  /// format is what the three export dialogs pre-fill their format dropdown from.
  ///
  /// Also tells `OcptWorkspaceBloc` to reload its episodes: the settings page's own `Episodes`
  /// card can add or delete one, which the workspace bloc otherwise only learns about from
  /// `OcptProjectsManager.currentProjectStream`, an event the episode CRUD does not fire. This mode
  /// shows no episode selector of its own (it reads every episode at once, `docs/adr/0019`), but
  /// `OcptWorkspaceBloc`'s own list must still be current the moment the user switches to a mode
  /// that does show one.
  Future<void> _requestProjectSettings(BuildContext context) async {
    final bloc = context.read<OcptScheduleBloc>();
    final workspaceBloc = context.read<OcptWorkspaceBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptScheduleProjectSettingsChangedEvent());
    workspaceBloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
  }

  /// Open `OcptScheduleShotPickerDialog` for slot [slotId] — the slot card's own `+ Block` menu's
  /// `Shot` entry — then dispatch [OcptScheduleShotBlockCreatedEvent] once the user picked a
  /// shot. Does nothing while the dialog is dismissed with no pick.
  Future<void> _handleShotBlockRequested(BuildContext context, String slotId) async {
    final bloc = context.read<OcptScheduleBloc>();
    final dayBloc = context.read<OcptScheduleDayBloc>();
    final state = bloc.state;

    final shotId = await OcptScheduleShotPickerDialog.show(
      context,
      shotListSnapshots: state.shotListSnapshots,
      episodes: state.episodes,
      placedDayNumbersByShotId: state.placedDayNumbersByShotId,
    );
    if (shotId == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    dayBloc.add(OcptScheduleShotBlockCreatedEvent(slotId: slotId, shotId: shotId));
  }

  /// Ask `OcptConfirmDialog` whether slot [slotId] really is to be deleted, then dispatch the
  /// deletion if the user answered `Delete`.
  Future<void> _handleSlotDeletionRequested(BuildContext context, String slotId) async {
    final dayBloc = context.read<OcptScheduleDayBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.scheduleDeleteSlotConfirmTitle,
      message: tr.scheduleDeleteSlotConfirmMessage,
      cancelLabel: tr.scheduleDeleteDayCancelAction,
      confirmLabel: tr.scheduleDeleteDayConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    dayBloc.add(OcptScheduleSlotDeletionConfirmedEvent(slotId: slotId));
  }

  /// Ask `OcptConfirmDialog` whether block [blockId] really is to be deleted, then dispatch the
  /// deletion if the user answered `Delete`.
  Future<void> _handleBlockDeletionRequested(BuildContext context, String blockId) async {
    final dayBloc = context.read<OcptScheduleDayBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.scheduleDeleteBlockConfirmTitle,
      message: tr.scheduleDeleteBlockConfirmMessage,
      cancelLabel: tr.scheduleDeleteDayCancelAction,
      confirmLabel: tr.scheduleDeleteDayConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    dayBloc.add(OcptScheduleBlockDeletionConfirmedEvent(blockId: blockId));
  }

  /// Ask `OcptConfirmDialog` whether event [eventId] really is to be deleted, then dispatch the
  /// deletion if the user answered `Delete`.
  Future<void> _handleDayEventDeletionRequested(BuildContext context, String eventId) async {
    final dayBloc = context.read<OcptScheduleDayBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.scheduleDeleteDayEventConfirmTitle,
      message: tr.scheduleDeleteDayEventConfirmMessage,
      cancelLabel: tr.scheduleDeleteDayCancelAction,
      confirmLabel: tr.scheduleDeleteDayConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    dayBloc.add(OcptScheduleDayEventDeletionConfirmedEvent(eventId: eventId));
  }

  /// Apply bloc-driven effects onto the page: the live dock fractions, the transient version
  /// notice SnackBar and the project package questions and notices.
  void _onStateChanged(BuildContext context, OcptScheduleState state) {
    _dockLayoutController.syncFromPersisted(
      leftFraction: state.leftDockFraction,
      rightFraction: state.rightDockFraction,
    );

    final versionNotice = state.projectVersionNotice;
    if (versionNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))),
        );
      context.read<OcptScheduleBloc>().add(const OcptProjectVersionNoticeDismissedEvent());
    }

    final packagePendingExport = state.projectPackagePendingExport;
    if (packagePendingExport != null) {
      context.read<OcptScheduleBloc>().add(const OcptProjectPackageMissingFilesAskDismissedEvent());
      unawaited(_askAboutMissingPackagedFiles(context, packagePendingExport));
    }

    final packageNotice = state.projectPackageNotice;
    if (packageNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectPackageNoticeMessage(context, packageNotice))),
        );
      context.read<OcptScheduleBloc>().add(const OcptProjectPackageNoticeDismissedEvent());
    }
  }

  /// Dispatch the project package export, resolving here — the last place with a
  /// [BuildContext] — the label the native save dialog carries.
  ///
  /// What happens next depends on what the project references: everything being there, the save
  /// dialog opens straight away; anything missing, the bloc asks back through its own state and
  /// [_askAboutMissingPackagedFiles] is what puts that question on screen.
  void _requestProjectPackageExport(BuildContext context) {
    context.read<OcptScheduleBloc>().add(
      OcptProjectPackageExportRequestedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }

  /// {@macro open_cine_prod_tools.packageMissingFilesDialogFlow}
  Future<void> _askAboutMissingPackagedFiles(
    BuildContext context,
    OcptProjectPackagePreflight preflight,
  ) async {
    final bloc = context.read<OcptScheduleBloc>();
    final confirmed = await ocptAskAboutMissingPackagedFiles(context, preflight);
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptProjectPackageExportConfirmedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }

  /// Dispose [_dockLayoutController].
  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }
}
