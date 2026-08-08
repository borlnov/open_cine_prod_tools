// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_presence_cell.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_color_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_alerts_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_call_sheets_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_convocations_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_month_grid.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_named_call_sheets_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_positions_matrix.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_presence_grid.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shooting_plan_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_shot_picker_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_strip_agenda.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_week_grid.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

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
/// event, exactly as the breakdown mode's own shell is built.
class OcptScheduleMode extends StatelessWidget {
  /// Creates the schedule mode.
  const OcptScheduleMode({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptScheduleBloc(), child: const _ScheduleView());
}

/// The content of [OcptScheduleMode], separated from it so [OcptScheduleMode] only wires the
/// [OcptScheduleBloc] up (RFL3).
///
/// A StatefulWidget (the documented RFL1 exception) because it owns the dock layout controller,
/// mirroring `_BreakdownView`/`_ShotListView`/`_ResourcesView`.
class _ScheduleView extends StatefulWidget {
  /// Class constructor
  const _ScheduleView();

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

  @override
  void deactivate() {
    // Triggering the flush here, rather than dispatching an event, is what guarantees the last
    // debounce worth of typing into the inspector's own note fields survives a mode switch or back
    // navigation — see `OcptScheduleBloc.flushPendingFieldEdits`'s own doc comment.
    unawaited(context.read<OcptScheduleBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }

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
        modeLabel: Tr.of(context).workspaceModeLabelSchedule,
        overflowEntries: _buildOverflowEntries(context, state),
        isLeftDockOpen: state.isListPanelVisible,
        onToggleLeftDock: () =>
            context.read<OcptScheduleBloc>().add(const OcptScheduleLeftPanelToggledEvent()),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () =>
            context.read<OcptScheduleBloc>().add(const OcptScheduleRightDockToggledEvent()),
        onProjectSettingsRequested: state.isPreviewingVersion
            ? null
            : () => unawaited(_requestProjectSettings(context)),
        banner: _buildReadOnlyBanner(context, state),
        leftPanel: state.isListPanelVisible ? _buildLeftDock(context, state) : null,
        rightPanel: _buildRightDock(context, state),
        centre: _buildCentre(context, state),
        statusBar: OcptScheduleStatusBar(
          alertCount: state.planSnapshot?.alerts.length ?? 0,
          dayCount: state.dayCount,
          placedShotCount: state.placedShotCount,
          shotsLeftToPlaceCount: state.shotsLeftToPlaceCount,
          isDaySelected: state.selectedDayId != null,
          selectedDayEndMinute: state.selectedDayId == null
              ? null
              : state.timelinesOfDay(state.selectedDayId!)?.dayEndMinute,
        ),
        dockLayoutController: _dockLayoutController,
        onDockFractionsChanged: (fractions) => context.read<OcptScheduleBloc>().add(
          OcptScheduleDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
        ),
      );
    },
  );

  /// Builds the mode's `⋮` overflow menu entries: the three PDF exports, then "reset panel layout".
  ///
  /// The two call sheet entries and the shooting plan one are disabled together when the project
  /// holds no live day at all — there would be nothing to print — and the named call sheets entry
  /// is disabled further still when the selected day convokes nobody, a call sheet with no recipient
  /// having nothing to send. All three stay offered under a version preview, exactly as the
  /// breakdown mode's own export entry does: an export only ever reads.
  List<PopupMenuEntry<void>> _buildOverflowEntries(BuildContext context, OcptScheduleState state) {
    final hasAnyDay = state.days.isNotEmpty;
    final selectedDayId = state.selectedDayId;
    final hasNamedRecipients =
        selectedDayId != null && state.convocationsOfDay(selectedDayId).isNotEmpty;

    return [
      PopupMenuItem<void>(
        enabled: hasAnyDay,
        // `onTap` fires as the menu closes, so the dialog this opens is shown from the mode's own
        // context rather than from the entry's, which is already on its way out of the tree.
        onTap: () => unawaited(_requestCallSheetsExport(context, state)),
        child: Text(Tr.of(context).scheduleExportCallSheetsMenuAction),
      ),
      PopupMenuItem<void>(
        enabled: hasAnyDay && hasNamedRecipients,
        onTap: () => unawaited(_requestNamedCallSheetsExport(context, state)),
        child: Text(Tr.of(context).scheduleExportNamedCallSheetsMenuAction),
      ),
      PopupMenuItem<void>(
        enabled: hasAnyDay,
        onTap: () => unawaited(_requestShootingPlanExport(context, state)),
        child: Text(Tr.of(context).scheduleExportShootingPlanMenuAction),
      ),
      PopupMenuItem<void>(
        onTap: () => context.read<OcptScheduleBloc>().add(const OcptScheduleDockLayoutResetEvent()),
        child: Text(Tr.of(context).scheduleResetPanelLayoutAction),
      ),
    ];
  }

  /// Shows the general call sheets export options dialog, then dispatches the export request if the
  /// user applied it, resolving here — the last place with a [BuildContext] — every localized string
  /// the exported documents and the native folder dialog carry.
  Future<void> _requestCallSheetsExport(BuildContext context, OcptScheduleState state) async {
    final bloc = context.read<OcptScheduleBloc>();
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
      ),
    );
  }

  /// Shows the named call sheets export options dialog for the selected day, then dispatches the
  /// export request if the user applied it — mirrors [_requestCallSheetsExport].
  ///
  /// Does nothing when no day is selected: the `⋮` entry that opens this is disabled in that case
  /// (see [_buildOverflowEntries]), so this only ever runs against a real day.
  Future<void> _requestNamedCallSheetsExport(BuildContext context, OcptScheduleState state) async {
    final day = state.selectedDay;
    if (day == null) {
      return;
    }

    final bloc = context.read<OcptScheduleBloc>();
    final options = await OcptScheduleNamedCallSheetsExportDialog.show(
      context,
      current: state.pageSetup,
      day: day,
      convocations: state.convocationsOfDay(day.id),
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
      ),
    );
  }

  /// Shows the shooting plan export options dialog, then dispatches the export request if the user
  /// applied it — mirrors [_requestCallSheetsExport].
  Future<void> _requestShootingPlanExport(BuildContext context, OcptScheduleState state) async {
    final bloc = context.read<OcptScheduleBloc>();
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
      ),
    );
  }

  /// Builds the left dock, or null while it's hidden.
  Widget _buildLeftDock(BuildContext context, OcptScheduleState state) {
    final bloc = context.read<OcptScheduleBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptScheduleLeftDock(
      days: state.days,
      selectedDayId: state.selectedDayId,
      blockCountByDayId: {
        for (final day in state.days) day.id: state.snapshot?.blocksByDayId[day.id]?.length ?? 0,
      },
      firstLocationByDayId: {for (final day in state.days) day.id: state.firstLocationOfDay(day.id)},
      alertsOfDay: state.alertsOfDay,
      onDaySelected: (dayId) => bloc.add(OcptScheduleDaySelectedEvent(dayId: dayId)),
      onDayCreated: isReadOnly
          ? null
          : (date) => bloc.add(OcptScheduleDayCreatedEvent(date: date)),
      onDayDateChangeRequested: isReadOnly
          ? null
          : (dayId, date) => bloc.add(OcptScheduleDayDateChangedEvent(dayId: dayId, date: date)),
      onDayDuplicationRequested: isReadOnly
          ? null
          : (dayId, date) => bloc.add(
              OcptScheduleDayDuplicationRequestedEvent(sourceDayId: dayId, date: date),
            ),
      onDayDeletionRequested: isReadOnly
          ? null
          : (dayId) => unawaited(_handleDayDeletionRequested(context, dayId)),
      unplacedGroups: state.unplacedGroups,
      selectedShotId: state.selectedShotId,
      onShotSelected: (shotId) => bloc.add(OcptScheduleShotSelectedEvent(shotId: shotId)),
    );
  }

  /// Asks `OcptConfirmDialog` whether day [dayId] really is to be deleted, then dispatches the
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

  /// Opens the project settings page, then re-reads the page setup if the user changed something —
  /// mirrors `OcptBreakdownMode._requestProjectSettings`/`OcptShotListMode`'s own handler: the page
  /// format is what the three export dialogs pre-fill their format dropdown from.
  Future<void> _requestProjectSettings(BuildContext context) async {
    final bloc = context.read<OcptScheduleBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptScheduleProjectSettingsChangedEvent());
  }

  /// Builds the shell's `centre`: the header band, then whichever of the agenda or the day view
  /// [OcptScheduleState.centreView] currently names.
  Widget _buildCentre(BuildContext context, OcptScheduleState state) {
    final bloc = context.read<OcptScheduleBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcptScheduleHeader(
          centreView: state.centreView,
          onCentreViewSelected: (view) => bloc.add(OcptScheduleCentreViewSelectedEvent(view: view)),
          agendaMode: state.agendaMode,
          onAgendaModeSelected: (mode) => bloc.add(OcptScheduleAgendaModeSelectedEvent(mode: mode)),
          agendaColorMode: state.agendaColorMode,
          onAgendaColorModeSelected: (mode) =>
              bloc.add(OcptScheduleAgendaColorModeSelectedEvent(mode: mode)),
          agendaAnchorDate: state.agendaAnchorDate,
          onAgendaAnchorDateChanged: (date) =>
              bloc.add(OcptScheduleAgendaAnchorDateChangedEvent(date: date)),
          firstWeekday: state.firstWeekday,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: switch (state.centreView) {
              OcptScheduleCentreView.day => _buildDayView(context, state),
              OcptScheduleCentreView.agenda => _buildAgenda(context, state),
              OcptScheduleCentreView.positions => _buildPositionsMatrix(context, state),
              OcptScheduleCentreView.presence => _buildPresenceGrid(context, state),
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Selects day [dayId] and switches the centre to the day view — the shared "open this day"
  /// gesture the strip's own header click, a week column header click and a month cell click all
  /// answer the same way.
  void _openDay(BuildContext context, String dayId) {
    final bloc = context.read<OcptScheduleBloc>();
    bloc
      ..add(OcptScheduleDaySelectedEvent(dayId: dayId))
      ..add(const OcptScheduleCentreViewSelectedEvent(view: OcptScheduleCentreView.day));
  }

  /// Builds the agenda: whichever of the three presentations [OcptScheduleState.agendaMode] names.
  Widget _buildAgenda(BuildContext context, OcptScheduleState state) {
    final bloc = context.read<OcptScheduleBloc>();
    final firstLocationByDayId = {
      for (final day in state.days) day.id: state.firstLocationOfDay(day.id),
    };
    final dayTintOf = _dayTintOf(context, state);
    final blocksByDayId =
        state.snapshot?.blocksByDayId ?? const <String, List<OcptShootingDayBlock>>{};
    final slotsByDayId = state.snapshot?.slotsByDayId ?? const <String, List<OcptShootingSlot>>{};

    return switch (state.agendaMode) {
      OcptScheduleAgendaMode.strip => OcptScheduleStripAgenda(
        days: state.days,
        selectedDayId: state.selectedDayId,
        firstLocationByDayId: firstLocationByDayId,
        dayTintOf: dayTintOf,
        blocksByDayId: blocksByDayId,
        shotOf: state.shotById,
        timelineOf: state.timelinesOfDay,
        arrivalMinuteOf: state.dayArrivalMinute,
        alertsOfDay: state.alertsOfDay,
        onDayOpenRequested: (dayId) => _openDay(context, dayId),
        onBlockSelected: (blockId, dayId) =>
            bloc.add(OcptScheduleBlockSelectedEvent(blockId: blockId, dayId: dayId)),
      ),
      OcptScheduleAgendaMode.week => OcptScheduleWeekGrid(
        anchorDate: state.agendaAnchorDate,
        firstWeekday: state.firstWeekday,
        days: state.days,
        dayTintOf: dayTintOf,
        slotsByDayId: slotsByDayId,
        blocksByDayId: blocksByDayId,
        shotOf: state.shotById,
        timelineOf: state.timelinesOfDay,
        sunTimesOf: state.sunTimesOfDay,
        selectedDayId: state.selectedDayId,
        alertsOfDay: state.alertsOfDay,
        onDayOpenRequested: (dayId) => _openDay(context, dayId),
      ),
      OcptScheduleAgendaMode.month => OcptScheduleMonthGrid(
        anchorDate: state.agendaAnchorDate,
        firstWeekday: state.firstWeekday,
        days: state.days,
        slotsByDayId: slotsByDayId,
        firstLocationByDayId: firstLocationByDayId,
        dayTintOf: dayTintOf,
        timelineOf: state.timelinesOfDay,
        sunTimesOf: state.sunTimesOfDay,
        selectedDayId: state.selectedDayId,
        alertsOfDay: state.alertsOfDay,
        onDayOpenRequested: (dayId) => _openDay(context, dayId),
      ),
    };
  }

  /// The resolver every one of the three agendas' own tint reads through — a day's own
  /// [OcptScheduleState.firstLocationOfDay] under [OcptScheduleAgendaColorMode.location], or its
  /// `OcptSchedulePlanSnapshot.effectCategoryOfDay` under [OcptScheduleAgendaColorMode.effect] —
  /// built once per build so switching the "Colour by" control re-tints all three presentations at
  /// once without any of them knowing which fact they are currently reading.
  Color Function(String dayId) _dayTintOf(BuildContext context, OcptScheduleState state) =>
      switch (state.agendaColorMode) {
        OcptScheduleAgendaColorMode.location => (dayId) =>
            ocptScheduleDayLocationTint(context, state.firstLocationOfDay(dayId)),
        OcptScheduleAgendaColorMode.effect => (dayId) =>
            ocptScheduleDayEffectTint(context, state.planSnapshot?.effectCategoryOfDay(dayId)),
      };

  /// Builds the positions matrix: who holds which crew position, slot by slot, across the whole
  /// shoot — [OcptSchedulePositionLostAlert] is read straight out of `state.planSnapshot`'s own
  /// alerts (rule 4 of `lib/utils/ocpt_schedule_alerts.dart`) rather than recomputed here, so this
  /// view can never disagree with the alerts panel about what "lost" means.
  Widget _buildPositionsMatrix(BuildContext context, OcptScheduleState state) => OcptSchedulePositionsMatrix(
    days: state.days,
    slotsByDayId: state.snapshot?.slotsByDayId ?? const <String, List<OcptShootingSlot>>{},
    personById: state.personById,
    timelinesOfDay: state.timelinesOfDay,
    lostPositionAlerts: [
      for (final alert in state.planSnapshot?.alerts ?? const <OcptScheduleAlert>[])
        if (alert is OcptSchedulePositionLostAlert) alert,
    ],
    onDayOpenRequested: (dayId) => _openDay(context, dayId),
  );

  /// Builds the presence grid: who is working, available, travelling or unavailable, day by day,
  /// across the whole shoot. [OcptSchedulePersonUnavailableAlert] is read straight out of
  /// `state.planSnapshot`'s own alerts (rule 1 of `lib/utils/ocpt_schedule_alerts.dart`) rather than
  /// recomputed here, exactly as [_buildPositionsMatrix] reads rule 4 for its own "lost" marker.
  Widget _buildPresenceGrid(BuildContext context, OcptScheduleState state) {
    final bloc = context.read<OcptScheduleBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final planSnapshot = state.planSnapshot;

    return OcptSchedulePresenceGrid(
      days: state.days,
      people: state.people,
      roles: state.roles,
      presenceCellOf: (dayId, personId) =>
          planSnapshot?.presenceCellOf(dayId: dayId, personId: personId) ??
          const OcptSchedulePresenceCell(code: null, isOverridden: false),
      unavailableAlerts: [
        for (final alert in planSnapshot?.alerts ?? const <OcptScheduleAlert>[])
          if (alert is OcptSchedulePersonUnavailableAlert) alert,
      ],
      onDayOpenRequested: (dayId) => _openDay(context, dayId),
      onCellTapped: isReadOnly
          ? null
          : (dayId, personId) => bloc.add(
              OcptSchedulePresenceCellClickedEvent(dayId: dayId, personId: personId),
            ),
    );
  }

  /// Builds the day view: the selected day's own summary band and its slot cards, each with its own
  /// timetable — or a plain hint while no day is selected yet.
  Widget _buildDayView(BuildContext context, OcptScheduleState state) {
    final day = state.selectedDay;
    if (day == null) {
      return Center(
        child: Text(
          Tr.of(context).scheduleInspectorEmptyHint,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final bloc = context.read<OcptScheduleBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return OcptScheduleDayView(
      day: day,
      slots: state.selectedDaySlots,
      blocks: state.selectedDayBlocks,
      timeline: state.timelinesOfDay(day.id),
      dayArrivalMinute: state.dayArrivalMinute(day.id),
      sunTimes: state.sunTimesOfDay(day.id),
      alerts: state.alertsOfDay(day.id),
      locationById: state.locationById,
      setById: state.setById,
      locations: state.locations,
      personById: state.personById,
      roleById: state.roleById,
      people: state.people,
      roles: state.roles,
      shotOf: state.shotById,
      selectedBlockId: state.selectedBlockId,
      sequences: state.sceneSequences,
      slotLabelValueOf: (slotId) {
        final slot = state.selectedDaySlots.firstWhere((candidate) => candidate.id == slotId);
        return state.fieldValueOf(slotId, OcptScheduleField.slotLabel, slot.label);
      },
      slotNotesValueOf: (slotId) {
        final slot = state.selectedDaySlots.firstWhere((candidate) => candidate.id == slotId);
        return state.fieldValueOf(slotId, OcptScheduleField.slotNotes, slot.notes);
      },
      onSlotAdded: isReadOnly ? null : () => bloc.add(OcptScheduleSlotCreatedEvent(dayId: day.id)),
      onSlotLabelChanged: isReadOnly
          ? null
          : (slotId, rawValue) => bloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: slotId,
                field: OcptScheduleField.slotLabel,
                rawValue: rawValue,
              ),
            ),
      onSlotNotesChanged: isReadOnly
          ? null
          : (slotId, rawValue) => bloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: slotId,
                field: OcptScheduleField.slotNotes,
                rawValue: rawValue,
              ),
            ),
      onSlotPlaceChanged: isReadOnly
          ? null
          : (slotId, locationId, setId) => bloc.add(
              OcptScheduleSlotPlaceChangedEvent(slotId: slotId, locationId: locationId, setId: setId),
            ),
      onSlotAnchorChanged: isReadOnly
          ? null
          : (slotId, edge, minute, sourceSlotId) => bloc.add(
              OcptScheduleSlotAnchorChangedEvent(
                slotId: slotId,
                edge: edge,
                minute: minute,
                sourceSlotId: sourceSlotId,
              ),
            ),
      onSlotMoved: isReadOnly
          ? null
          : (slotId, newPosition) => bloc.add(
              OcptScheduleSlotReorderedEvent(
                dayId: day.id,
                slotId: slotId,
                newPosition: newPosition,
              ),
            ),
      onSlotDeletionRequested: isReadOnly
          ? null
          : (slotId) => unawaited(_handleSlotDeletionRequested(context, slotId)),
      onSlotCrewMemberAdded: isReadOnly
          ? null
          : (slotId, personId) =>
                bloc.add(OcptScheduleSlotCrewMemberAddedEvent(slotId: slotId, personId: personId)),
      onSlotCrewMemberPositionChanged: isReadOnly
          ? null
          : (crewMemberId, position) => bloc.add(
              OcptScheduleSlotCrewMemberPositionChangedEvent(
                crewMemberId: crewMemberId,
                positionId: position.positionId,
                customLabel: position.customLabel,
              ),
            ),
      onSlotCrewMemberRemoved: isReadOnly
          ? null
          : (crewMemberId) =>
                bloc.add(OcptScheduleSlotCrewMemberRemovedEvent(crewMemberId: crewMemberId)),
      onSlotCastRoleAdded: isReadOnly
          ? null
          : (slotId, roleId) => bloc.add(OcptScheduleSlotCastRoleAddedEvent(slotId: slotId, roleId: roleId)),
      onSlotCastRoleRemoved: isReadOnly
          ? null
          : (castRoleId) => bloc.add(OcptScheduleSlotCastRoleRemovedEvent(castRoleId: castRoleId)),
      onBlockSelected: (blockId) =>
          bloc.add(OcptScheduleBlockSelectedEvent(blockId: blockId, dayId: day.id)),
      onBlockReordered: isReadOnly
          ? null
          : (blockId, newPosition) =>
                bloc.add(OcptScheduleBlockReorderedEvent(blockId: blockId, newPosition: newPosition)),
      onBlockDurationChanged: isReadOnly
          ? null
          : (blockId, durationMinutes) => bloc.add(
              OcptScheduleBlockDurationChangedEvent(blockId: blockId, durationMinutes: durationMinutes),
            ),
      onBlockAnchorChanged: isReadOnly
          ? null
          : (blockId, anchorMinute) =>
                bloc.add(OcptScheduleBlockAnchorChangedEvent(blockId: blockId, anchorMinute: anchorMinute)),
      onShotStatusChanged: isReadOnly
          ? null
          : (shotId, status) => bloc.add(OcptScheduleShotStatusChangedEvent(shotId: shotId, status: status)),
      onBlockSequenceChanged: isReadOnly
          ? null
          : (blockId, sceneId) =>
                bloc.add(OcptScheduleBlockSequenceChangedEvent(blockId: blockId, sceneId: sceneId)),
      onBlockDeletionRequested: isReadOnly
          ? null
          : (blockId) => unawaited(_handleBlockDeletionRequested(context, blockId)),
      onBlockAdded: isReadOnly
          ? null
          : (slotId, kind) => bloc.add(OcptScheduleBlockCreatedEvent(slotId: slotId, kind: kind)),
      onShotBlockRequested: isReadOnly
          ? null
          : (slotId) => unawaited(_handleShotBlockRequested(context, slotId)),
      onBlockMovedToSlot: isReadOnly
          ? null
          : (blockId, targetSlotId) =>
                bloc.add(OcptScheduleBlockMovedToSlotEvent(blockId: blockId, targetSlotId: targetSlotId)),
    );
  }

  /// Opens `OcptScheduleShotPickerDialog` for slot [slotId] — the slot card's own `+ Block` menu's
  /// `Shot` entry — then dispatches [OcptScheduleShotBlockCreatedEvent] once the user picked a
  /// shot. Does nothing while the dialog is dismissed with no pick.
  Future<void> _handleShotBlockRequested(BuildContext context, String slotId) async {
    final bloc = context.read<OcptScheduleBloc>();
    final state = bloc.state;

    final shotId = await OcptScheduleShotPickerDialog.show(
      context,
      sequences: state.shotListSnapshot?.sequences ?? const [],
      placedDayNumbersByShotId: state.placedDayNumbersByShotId,
    );
    if (shotId == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptScheduleShotBlockCreatedEvent(slotId: slotId, shotId: shotId));
  }

  /// Asks `OcptConfirmDialog` whether slot [slotId] really is to be deleted, then dispatches the
  /// deletion if the user answered `Delete`.
  Future<void> _handleSlotDeletionRequested(BuildContext context, String slotId) async {
    final bloc = context.read<OcptScheduleBloc>();
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

    bloc.add(OcptScheduleSlotDeletionConfirmedEvent(slotId: slotId));
  }

  /// Asks `OcptConfirmDialog` whether block [blockId] really is to be deleted, then dispatches the
  /// deletion if the user answered `Delete`.
  Future<void> _handleBlockDeletionRequested(BuildContext context, String blockId) async {
    final bloc = context.read<OcptScheduleBloc>();
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

    bloc.add(OcptScheduleBlockDeletionConfirmedEvent(blockId: blockId));
  }

  /// Builds the right dock, or null while it's closed.
  Widget? _buildRightDock(BuildContext context, OcptScheduleState state) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return null;
    }

    return OcptScheduleRightDock(
      activeTab: rightDockTab,
      inspectorChild: _buildInspector(context, state),
      convocationsChild: _buildConvocationsPanel(context, state),
      alertsChild: _buildAlertsPanel(context, state),
      versionsChild: _buildVersionsPanel(context, state),
      onTabSelected: (tab) =>
          context.read<OcptScheduleBloc>().add(OcptScheduleRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptScheduleBloc>().add(const OcptScheduleRightDockClosedEvent()),
    );
  }

  /// Builds the `Convocations` tab's own content: the selected day's whole call, or nothing while
  /// no day is selected — [OcptScheduleConvocationsPanel] tells the two apart through whether
  /// [OcptScheduleState.selectedDayId] itself is null, rather than through the emptiness of the
  /// list, a day with no convocation yet being a different fact from no day chosen at all.
  Widget _buildConvocationsPanel(BuildContext context, OcptScheduleState state) {
    final selectedDayId = state.selectedDayId;

    return OcptScheduleConvocationsPanel(
      convocations: selectedDayId == null ? null : state.convocationsOfDay(selectedDayId),
      personById: state.personById,
      roleById: state.roleById,
      slotById: {for (final slot in state.selectedDaySlots) slot.id: slot},
    );
  }

  /// Builds the `Alerts` tab's own content: every alert the whole shoot currently raises, with the
  /// whole-schedule slot and block maps its cards need to resolve a card that isn't scoped to the
  /// selected day — unlike [_buildConvocationsPanel]'s own `slotById`, which only ever needs the
  /// selected day's slots.
  Widget _buildAlertsPanel(BuildContext context, OcptScheduleState state) {
    final snapshot = state.snapshot;

    final slotById = <String, OcptShootingSlot>{
      for (final slots in snapshot?.slotsByDayId.values ?? const <List<OcptShootingSlot>>[])
        for (final slot in slots) slot.id: slot,
    };
    final blockById = <String, OcptShootingDayBlock>{
      for (final blocks in snapshot?.blocksByDayId.values ?? const <List<OcptShootingDayBlock>>[])
        for (final block in blocks) block.id: block,
    };

    return OcptScheduleAlertsPanel(
      alerts: state.planSnapshot?.alerts ?? const <OcptScheduleAlert>[],
      personById: state.personById,
      roleById: state.roleById,
      locationById: state.locationById,
      daysById: state.daysById,
      slotById: slotById,
      blockById: blockById,
      shotOf: state.shotById,
      onDayOpenRequested: (dayId) => _openDay(context, dayId),
    );
  }

  /// Builds the `Inspector` tab's own content: the selected block's read-out, else the selected
  /// shot's own, else the selected day's — see `OcptScheduleInspector`'s own doc comment for why
  /// that order.
  Widget _buildInspector(BuildContext context, OcptScheduleState state) {
    final bloc = context.read<OcptScheduleBloc>();
    final isReadOnly = state.isPreviewingVersion;
    final block = state.selectedBlock;
    final blockShot = block?.shotId == null ? null : state.shotById(block!.shotId!);
    String? blockSlotLabel;
    if (block?.slotId != null) {
      for (final slot in state.selectedDaySlots) {
        if (slot.id == block!.slotId) {
          blockSlotLabel = slot.label;
          break;
        }
      }
    }
    OcptShootingTimelineEntry? blockEntry;
    if (block != null) {
      final entries =
          state.timelinesOfDay(state.selectedDayId ?? "")?.entries ?? const <OcptShootingTimelineEntry>[];
      for (final entry in entries) {
        if (entry.blockId == block.id) {
          blockEntry = entry;
          break;
        }
      }
    }

    final shot = state.selectedShot;
    final shotSequenceLabel = shot == null ? null : _sequenceLabelOfShot(context, state, shot);
    final shotPlacedDayNumbers = shot == null
        ? const <int>[]
        : state.placedDayNumbersByShotId[shot.id] ?? const [];

    // The two selections are mutually exclusive (`OcptScheduleBloc` keeps them so), so exactly one
    // of `blockShot`/`shot` is ever non-null: this is what feeds the status control either
    // read-out shows.
    final effectiveShot = blockShot ?? shot;

    final day = state.selectedDay;

    return OcptScheduleInspector(
      day: day,
      slots: state.selectedDaySlots,
      locationById: state.locationById,
      setById: state.setById,
      timeline: state.selectedDayId == null ? null : state.timelinesOfDay(state.selectedDayId!),
      dayArrivalMinute: state.selectedDayId == null ? null : state.dayArrivalMinute(state.selectedDayId!),
      sunTimes: state.selectedDayId == null ? null : state.sunTimesOfDay(state.selectedDayId!),
      crewNoteValue: day == null
          ? ""
          : state.fieldValueOf(day.id, OcptScheduleField.dayCrewNote, day.crewNote),
      weatherNoteValue: day == null
          ? ""
          : state.fieldValueOf(day.id, OcptScheduleField.dayWeatherNote, day.weatherNote),
      onDayStatusChanged: isReadOnly || day == null
          ? null
          : (status) => bloc.add(OcptScheduleDayStatusChangedEvent(dayId: day.id, status: status)),
      onCrewNoteChanged: isReadOnly || day == null
          ? null
          : (rawValue) => bloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: day.id,
                field: OcptScheduleField.dayCrewNote,
                rawValue: rawValue,
              ),
            ),
      onWeatherNoteChanged: isReadOnly || day == null
          ? null
          : (rawValue) => bloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: day.id,
                field: OcptScheduleField.dayWeatherNote,
                rawValue: rawValue,
              ),
            ),
      shot: shot,
      shotSequenceLabel: shotSequenceLabel,
      shotPlacedDayNumbers: shotPlacedDayNumbers,
      block: block,
      blockShot: blockShot,
      blockSlotLabel: blockSlotLabel,
      blockEntry: blockEntry,
      onShotStatusChanged: isReadOnly || effectiveShot == null
          ? null
          : (status) =>
                bloc.add(OcptScheduleShotStatusChangedEvent(shotId: effectiveShot.id, status: status)),
      onBlockDurationChanged: isReadOnly || block == null
          ? null
          : (durationMinutes) => bloc.add(
              OcptScheduleBlockDurationChangedEvent(blockId: block.id, durationMinutes: durationMinutes),
            ),
      blockNotesValue: block == null
          ? ""
          : state.fieldValueOf(block.id, OcptScheduleField.blockNotes, block.notes),
      onBlockNotesChanged: isReadOnly || block == null
          ? null
          : (rawValue) => bloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: block.id,
                field: OcptScheduleField.blockNotes,
                rawValue: rawValue,
              ),
            ),
      isReadOnly: isReadOnly,
    );
  }

  /// [shot]'s own sequence label, exactly as the left dock heads that sequence's own section of
  /// the unplaced-shots list (`Tr.scheduleUnplacedSequenceLabel`/`Tr.scheduleUnplacedOrphanGroupLabel`
  /// plus the heading) — resolved here, out of [OcptScheduleState.shotListSnapshot], rather than by
  /// the inspector itself, so a widget never has to search the snapshot on its own. Null while
  /// [shot]'s own sequence isn't found there (the shot list hasn't loaded yet).
  String? _sequenceLabelOfShot(BuildContext context, OcptScheduleState state, OcptShot shot) {
    final tr = Tr.of(context);

    for (final sequence in state.shotListSnapshot?.sequences ?? const <OcptShotSequence>[]) {
      if (!sequence.shots.any((candidate) => candidate.id == shot.id)) {
        continue;
      }

      if (sequence is OcptSceneShotSequence) {
        final tag = tr.scheduleUnplacedSequenceLabel(sequence.displaySceneNumber);
        return sequence.heading.isEmpty ? tag : "$tag  ${sequence.heading}";
      }

      return tr.scheduleUnplacedOrphanGroupLabel;
    }

    return null;
  }

  /// Builds the band naming the version being previewed, or null while the working copy is on
  /// screen.
  Widget? _buildReadOnlyBanner(BuildContext context, OcptScheduleState state) {
    final previewedVersion = state.previewedVersion;
    if (previewedVersion == null) {
      return null;
    }

    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      onForkRequested: () => context.read<OcptScheduleBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () => context.read<OcptScheduleBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
    );
  }

  /// Builds the right dock's `Versions` tab, wired exactly as every other mode's own dock.
  Widget _buildVersionsPanel(BuildContext context, OcptScheduleState state) => OcptProjectVersionsPanel(
    versions: state.projectVersions,
    previewedVersionId: state.previewedVersionId,
    workingCopy: state.workingCopy,
    versionPendingDeletionId: state.versionPendingDeletionId,
    versionPendingRestoreId: state.versionPendingRestoreId,
    versionPendingRenameId: state.versionPendingRenameId,
    onCreateRequested: () => _requestVersionCreation(context),
    onPreviewRequested: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
    ),
    onPreviewExitRequested: () => context.read<OcptScheduleBloc>().add(
      const OcptProjectVersionPreviewExitRequestedEvent(),
    ),
    onRestoreRequested: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
    ),
    onRestoreCancelled: () => context.read<OcptScheduleBloc>().add(
      const OcptProjectVersionRestoreCancelledEvent(),
    ),
    onRestoreConfirmed: (version) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionRestoreConfirmedEvent(
        versionId: version.id,
        safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
      ),
    ),
    onDeleteRequested: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
    ),
    onDeleteCancelled: () => context.read<OcptScheduleBloc>().add(
      const OcptProjectVersionDeletionCancelledEvent(),
    ),
    onDeleteConfirmed: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
    ),
    onRenameRequested: (versionId) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionRenameRequestedEvent(versionId: versionId),
    ),
    onRenameCancelled: () => context.read<OcptScheduleBloc>().add(
      const OcptProjectVersionRenameCancelledEvent(),
    ),
    onRenameConfirmed: (versionId, name, note) => context.read<OcptScheduleBloc>().add(
      OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
    ),
  );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptScheduleBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note));
  }

  /// Applies bloc-driven effects onto the page: the live dock fractions, the transient export notice
  /// SnackBar and the transient version notice SnackBar.
  void _onStateChanged(BuildContext context, OcptScheduleState state) {
    _dockLayoutController.syncFromPersisted(
      leftFraction: state.leftDockFraction,
      rightFraction: state.rightDockFraction,
    );

    final ioNotice = state.ioNotice;
    if (ioNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
      context.read<OcptScheduleBloc>().add(const OcptScheduleIoNoticeDismissedEvent());
    }

    final versionNotice = state.projectVersionNotice;
    if (versionNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))),
        );
      context.read<OcptScheduleBloc>().add(const OcptProjectVersionNoticeDismissedEvent());
    }
  }

  /// Maps [notice] to its localized, user-facing message, mirroring
  /// `OcptBreakdownMode._ioNoticeMessage`.
  String _ioNoticeMessage(BuildContext context, OcptScheduleIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptScheduleIoNoticeKind.fileExportSucceeded => tr.scheduleExportFileSuccessMessage(
        notice.path ?? "",
      ),
      OcptScheduleIoNoticeKind.folderExportSucceeded => tr.scheduleExportFolderSuccessMessage(
        notice.writtenCount ?? 0,
        notice.folderPath ?? "",
      ),
      OcptScheduleIoNoticeKind.folderExportPartiallySucceeded => tr.scheduleExportFolderPartialMessage(
        notice.writtenCount ?? 0,
        notice.folderPath ?? "",
        notice.failedCount ?? 0,
      ),
      OcptScheduleIoNoticeKind.exportFailed => tr.scheduleExportError,
    };
  }
}
