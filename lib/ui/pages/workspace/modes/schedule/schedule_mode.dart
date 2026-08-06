// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_month_grid.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_right_dock.dart';
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
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The schedule production mode: planning the shoot day by day (`docs/plans/schedule-mode.md`,
/// milestone M1).
///
/// The left dock lists the shooting days over the shots still to place, grouped by sequence — a
/// click on an unplaced shot starts a *placing*, a click on a day (here, on the strip agenda, or on
/// a week/month cell) answers it. The centre is `OcptScheduleHeader`'s own `Agenda`/`Day` switch
/// over either the agenda — [OcptScheduleStripAgenda], [OcptScheduleWeekGrid] or
/// [OcptScheduleMonthGrid], per [OcptScheduleState.agendaMode] — or [OcptScheduleDayView], the
/// mode's own working surface (the day's summary band, then one slot card per convocation, each
/// carrying its own chained timetable). The right dock is `Inspector` (the selected block's own
/// read-out, or, with none selected, the selected day's own) + the shared `Versions` tab.
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
        overflowEntries: _buildOverflowEntries(context),
        isLeftDockOpen: state.isListPanelVisible,
        onToggleLeftDock: () =>
            context.read<OcptScheduleBloc>().add(const OcptScheduleLeftPanelToggledEvent()),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () =>
            context.read<OcptScheduleBloc>().add(const OcptScheduleRightDockToggledEvent()),
        onProjectSettingsRequested: state.isPreviewingVersion
            ? null
            : () => unawaited(
                globalGetIt().get<OcptRouterManager>().push(OcptRoute.projectSettings),
              ),
        banner: _buildReadOnlyBanner(context, state),
        leftPanel: state.isListPanelVisible ? _buildLeftDock(context, state) : null,
        rightPanel: _buildRightDock(context, state),
        centre: _buildCentre(context, state),
        statusBar: OcptScheduleStatusBar(
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

  /// Builds the mode's `⋮` overflow menu entries: only "reset panel layout" in this milestone —
  /// the exports arrive with M2.
  List<PopupMenuEntry<void>> _buildOverflowEntries(BuildContext context) => [
    PopupMenuItem<void>(
      onTap: () => context.read<OcptScheduleBloc>().add(const OcptScheduleDockLayoutResetEvent()),
      child: Text(Tr.of(context).scheduleResetPanelLayoutAction),
    ),
  ];

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
      onDaySelected: (dayId) => bloc.add(OcptScheduleDaySelectedEvent(dayId: dayId)),
      onDayCreated: isReadOnly
          ? null
          : (date) => bloc.add(OcptScheduleDayCreatedEvent(date: date)),
      onDayDuplicationRequested: isReadOnly
          ? null
          : (dayId, date) => bloc.add(
              OcptScheduleDayDuplicationRequestedEvent(sourceDayId: dayId, date: date),
            ),
      onDayDeletionRequested: isReadOnly
          ? null
          : (dayId) => unawaited(_handleDayDeletionRequested(context, dayId)),
      unplacedGroups: state.unplacedGroups,
      placingShotId: state.placingShotId,
      onShotPlacingToggled: isReadOnly
          ? null
          : (shotId) => bloc.add(OcptSchedulePlacingStartedEvent(shotId: shotId)),
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
          agendaAnchorDate: state.agendaAnchorDate,
          onAgendaAnchorDateChanged: (date) =>
              bloc.add(OcptScheduleAgendaAnchorDateChangedEvent(date: date)),
          firstWeekday: state.firstWeekday,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: state.centreView == OcptScheduleCentreView.day
                ? _buildDayView(context, state)
                : _buildAgenda(context, state),
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
    final isReadOnly = state.isPreviewingVersion;
    final firstLocationByDayId = {
      for (final day in state.days) day.id: state.firstLocationOfDay(day.id),
    };
    final blocksByDayId =
        state.snapshot?.blocksByDayId ?? const <String, List<OcptShootingDayBlock>>{};

    return switch (state.agendaMode) {
      OcptScheduleAgendaMode.strip => OcptScheduleStripAgenda(
        days: state.days,
        selectedDayId: state.selectedDayId,
        firstLocationByDayId: firstLocationByDayId,
        blocksByDayId: blocksByDayId,
        shotOf: state.shotById,
        timelineOf: state.timelinesOfDay,
        placingShotId: state.placingShotId,
        onDaySelected: (dayId) => bloc.add(OcptScheduleDaySelectedEvent(dayId: dayId)),
        onPlaceHereRequested: isReadOnly || state.placingShotId == null
            ? null
            : (dayId) => bloc.add(
                OcptScheduleShotPlacedEvent(shotId: state.placingShotId!, dayId: dayId),
              ),
        onShotUnplaceRequested: isReadOnly
            ? null
            : (shotId) => bloc.add(OcptScheduleShotUnplacedEvent(shotId: shotId)),
        onBlockSelected: (blockId, dayId) =>
            bloc.add(OcptScheduleBlockSelectedEvent(blockId: blockId, dayId: dayId)),
      ),
      OcptScheduleAgendaMode.week => OcptScheduleWeekGrid(
        anchorDate: state.agendaAnchorDate,
        firstWeekday: state.firstWeekday,
        days: state.days,
        firstLocationByDayId: firstLocationByDayId,
        blocksByDayId: blocksByDayId,
        shotOf: state.shotById,
        timelineOf: state.timelinesOfDay,
        sunTimesOf: state.sunTimesOfDay,
        selectedDayId: state.selectedDayId,
        onDayOpenRequested: (dayId) => _openDay(context, dayId),
      ),
      OcptScheduleAgendaMode.month => OcptScheduleMonthGrid(
        anchorDate: state.agendaAnchorDate,
        firstWeekday: state.firstWeekday,
        days: state.days,
        slotsByDayId: state.snapshot?.slotsByDayId ?? const <String, List<OcptShootingSlot>>{},
        firstLocationByDayId: firstLocationByDayId,
        timelineOf: state.timelinesOfDay,
        sunTimesOf: state.sunTimesOfDay,
        selectedDayId: state.selectedDayId,
        onDayOpenRequested: (dayId) => _openDay(context, dayId),
      ),
    };
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
      groups: state.selectedDayGroups,
      groupMemberCounts: state.groupMemberCountsOfDay(day.id),
      blocks: state.selectedDayBlocks,
      timeline: state.timelinesOfDay(day.id),
      sunTimes: state.sunTimesOfDay(day.id),
      locationById: state.locationById,
      setById: state.setById,
      locations: state.locations,
      personById: state.personById,
      roleById: state.roleById,
      people: state.people,
      roles: state.roles,
      shotOf: state.shotById,
      selectedBlockId: state.selectedBlockId,
      slotLabelValueOf: (slotId) {
        final slot = state.selectedDaySlots.firstWhere((candidate) => candidate.id == slotId);
        return state.fieldValueOf(slotId, OcptScheduleField.slotLabel, slot.label);
      },
      groupLabelValueOf: (groupId) {
        final group = state.selectedDayGroups.firstWhere((candidate) => candidate.id == groupId);
        return state.fieldValueOf(groupId, OcptScheduleField.groupLabel, group.label);
      },
      slotConvocationsOf: state.convocationsOfSlot,
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
      onSlotPlaceChanged: isReadOnly
          ? null
          : (slotId, locationId, setId) => bloc.add(
              OcptScheduleSlotPlaceChangedEvent(slotId: slotId, locationId: locationId, setId: setId),
            ),
      onSlotStartChanged: isReadOnly
          ? null
          : (slotId, startMinute) =>
                bloc.add(OcptScheduleSlotStartChangedEvent(slotId: slotId, startMinute: startMinute)),
      onSlotDeletionRequested: isReadOnly
          ? null
          : (slotId) => unawaited(_handleSlotDeletionRequested(context, slotId)),
      onGroupLabelChanged: isReadOnly
          ? null
          : (groupId, rawValue) => bloc.add(
              OcptScheduleFieldChangedEvent(
                targetId: groupId,
                field: OcptScheduleField.groupLabel,
                rawValue: rawValue,
              ),
            ),
      onGroupLeadChanged: isReadOnly
          ? null
          : (groupId, leadMinutes) =>
                bloc.add(OcptScheduleGroupLeadChangedEvent(groupId: groupId, leadMinutes: leadMinutes)),
      onGroupAdded: isReadOnly ? null : () => bloc.add(OcptScheduleGroupCreatedEvent(dayId: day.id)),
      onGroupDeletionRequested: isReadOnly
          ? null
          : (groupId) => unawaited(_handleGroupDeletionRequested(context, groupId)),
      onSlotCrewMemberAdded: isReadOnly
          ? null
          : (slotId, personId) =>
                bloc.add(OcptScheduleSlotCrewMemberAddedEvent(slotId: slotId, personId: personId)),
      onSlotCrewMemberPositionChanged: isReadOnly
          ? null
          : (crewMemberId, positionId) => bloc.add(
              OcptScheduleSlotCrewMemberPositionChangedEvent(
                crewMemberId: crewMemberId,
                positionId: positionId,
              ),
            ),
      onSlotCrewMemberRemoved: isReadOnly
          ? null
          : (crewMemberId) =>
                bloc.add(OcptScheduleSlotCrewMemberRemovedEvent(crewMemberId: crewMemberId)),
      onSlotCrewMemberLeadChanged: isReadOnly
          ? null
          : (crewMemberId, leadMinutes) => bloc.add(
              OcptScheduleSlotCrewMemberLeadChangedEvent(
                crewMemberId: crewMemberId,
                leadMinutes: leadMinutes,
              ),
            ),
      onSlotCrewMemberGroupChanged: isReadOnly
          ? null
          : (crewMemberId, groupId) => bloc.add(
              OcptScheduleSlotCrewMemberGroupChangedEvent(crewMemberId: crewMemberId, groupId: groupId),
            ),
      onSlotCastRoleAdded: isReadOnly
          ? null
          : (slotId, roleId) => bloc.add(OcptScheduleSlotCastRoleAddedEvent(slotId: slotId, roleId: roleId)),
      onSlotCastRoleRemoved: isReadOnly
          ? null
          : (castRoleId) => bloc.add(OcptScheduleSlotCastRoleRemovedEvent(castRoleId: castRoleId)),
      onSlotCastRoleLeadChanged: isReadOnly
          ? null
          : (castRoleId, leadMinutes) => bloc.add(
              OcptScheduleSlotCastRoleLeadChangedEvent(castRoleId: castRoleId, leadMinutes: leadMinutes),
            ),
      onSlotCastRoleGroupChanged: isReadOnly
          ? null
          : (castRoleId, groupId) => bloc.add(
              OcptScheduleSlotCastRoleGroupChangedEvent(castRoleId: castRoleId, groupId: groupId),
            ),
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
      onBlockDeletionRequested: isReadOnly
          ? null
          : (blockId) => unawaited(_handleBlockDeletionRequested(context, blockId)),
      onBlockAdded: isReadOnly
          ? null
          : (slotId, kind) => bloc.add(OcptScheduleBlockCreatedEvent(slotId: slotId, kind: kind)),
      onBlockMovedToSlot: isReadOnly
          ? null
          : (blockId, targetSlotId) =>
                bloc.add(OcptScheduleBlockMovedToSlotEvent(blockId: blockId, targetSlotId: targetSlotId)),
    );
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

  /// Asks `OcptConfirmDialog` whether group [groupId] really is to be deleted, then dispatches the
  /// deletion if the user answered `Delete`. What the dialog says matters here specifically: unlike
  /// a day, a slot or a block, deleting a group doesn't remove anybody from the day — it leaves
  /// every crew and cast row that pointed at it with no group at all
  /// (`OcptScheduleService.deleteGroup`'s own rule), which `scheduleDeleteGroupConfirmMessage` says
  /// rather than the generic "this cannot be undone" the other three share.
  Future<void> _handleGroupDeletionRequested(BuildContext context, String groupId) async {
    final bloc = context.read<OcptScheduleBloc>();
    final tr = Tr.of(context);

    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.scheduleDeleteGroupConfirmTitle,
      message: tr.scheduleDeleteGroupConfirmMessage,
      cancelLabel: tr.scheduleDeleteDayCancelAction,
      confirmLabel: tr.scheduleDeleteDayConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptScheduleGroupDeletionConfirmedEvent(groupId: groupId));
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
      versionsChild: _buildVersionsPanel(context, state),
      onTabSelected: (tab) =>
          context.read<OcptScheduleBloc>().add(OcptScheduleRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptScheduleBloc>().add(const OcptScheduleRightDockClosedEvent()),
    );
  }

  /// Builds the `Inspector` tab's own content: the selected block's read-out, or the selected
  /// day's.
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

    final day = state.selectedDay;

    return OcptScheduleInspector(
      day: day,
      slots: state.selectedDaySlots,
      locationById: state.locationById,
      setById: state.setById,
      timeline: state.selectedDayId == null ? null : state.timelinesOfDay(state.selectedDayId!),
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
      block: block,
      blockShot: blockShot,
      blockSlotLabel: blockSlotLabel,
      blockEntry: blockEntry,
      onShotStatusChanged: isReadOnly || blockShot == null
          ? null
          : (status) =>
                bloc.add(OcptScheduleShotStatusChangedEvent(shotId: blockShot.id, status: status)),
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

  /// Applies bloc-driven effects onto the page: the live dock fractions and the transient version
  /// notice SnackBar.
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
  }
}
