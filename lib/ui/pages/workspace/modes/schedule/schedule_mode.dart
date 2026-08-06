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
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_agenda_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_header.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_left_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_strip_agenda.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The schedule production mode: planning the shoot day by day (`docs/plans/schedule-mode.md`,
/// milestone M1).
///
/// The left dock lists the shooting days over the shots still to place, grouped by sequence — a
/// click on an unplaced shot starts a *placing*, a click on a day (here, or on the strip agenda)
/// answers it. The centre is `OcptScheduleHeader`'s own `Agenda`/`Day` switch over either the
/// agenda — this milestone building only its `strip` presentation
/// ([OcptScheduleStripAgenda]; `week`/`month` show a placeholder, see `_buildAgenda`'s own doc
/// comment) — or the day view, a placeholder here too, since building its slot/block timetable is
/// the second agent's own task. The right dock is `Inspector` (the selected block's own read-out,
/// or, with none selected, the selected day's own) + the shared `Versions` tab.
///
/// **There is no save control and no mode-specific toolbar action**: every write here is its own
/// event, exactly as the breakdown mode's own shell is built — see `OcptScheduleBloc`'s own doc
/// comment for the one thing that does deviate from that mode's shape (the two dock fractions and
/// the last right dock tab are not persisted in this milestone).
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
          selectedDayEndMinute: state.selectedDayId == null
              ? null
              : state.timelineOfDay(state.selectedDayId!)?.dayEndMinute,
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
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: state.centreView == OcptScheduleCentreView.day
                ? _buildDayViewPlaceholder(context)
                : _buildAgenda(context, state),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Builds the agenda: the strip presentation this milestone actually builds, or a placeholder
  /// for the week/month grids — those are the second agent's own task, per this mode's own
  /// scope note (see the class doc comment).
  Widget _buildAgenda(BuildContext context, OcptScheduleState state) {
    final bloc = context.read<OcptScheduleBloc>();
    final isReadOnly = state.isPreviewingVersion;

    return switch (state.agendaMode) {
      OcptScheduleAgendaMode.strip => OcptScheduleStripAgenda(
        days: state.days,
        selectedDayId: state.selectedDayId,
        firstLocationByDayId: {
          for (final day in state.days) day.id: state.firstLocationOfDay(day.id),
        },
        blocksByDayId: state.snapshot?.blocksByDayId ?? const <String, List<OcptShootingDayBlock>>{},
        shotOf: state.shotById,
        timelineOf: state.timelineOfDay,
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
      // The week/month grid and the day view are built next.
      OcptScheduleAgendaMode.week => OcptWorkspaceEmptyMode(
        icon: Icons.calendar_view_week_outlined,
        message: Tr.of(context).scheduleAgendaWeekComingHint,
      ),
      OcptScheduleAgendaMode.month => OcptWorkspaceEmptyMode(
        icon: Icons.calendar_view_month_outlined,
        message: Tr.of(context).scheduleAgendaMonthComingHint,
      ),
    };
  }

  /// Builds the day view's own placeholder.
  // The week/month grid and the day view are built next.
  Widget _buildDayViewPlaceholder(BuildContext context) => OcptWorkspaceEmptyMode(
    icon: Icons.view_day_outlined,
    message: Tr.of(context).scheduleDayViewComingHint,
  );

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
          state.timelineOfDay(state.selectedDayId ?? "")?.entries ?? const <OcptShootingTimelineEntry>[];
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
      timeline: state.selectedDayId == null ? null : state.timelineOfDay(state.selectedDayId!),
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
