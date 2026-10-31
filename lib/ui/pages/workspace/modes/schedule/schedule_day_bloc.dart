// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_day_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';

/// This is the bloc class for the schedule mode's day view: the slots of the selected day, the
/// crew, the cast, the guests and the candidacies they convoke, the blocks of each slot and the
/// day's own events, together with the free-text fields typed into the day view and the inspector.
///
/// The schedule is the mode's data, in `OcptScheduleState.snapshot`, and which day, block and shot
/// are selected is the mode's too. This bloc owns what the day view does with them: every write
/// (the service, then `await modeBloc.reload(…)` for the part of the data it changed) and the
/// edits typed and not yet written ([OcptScheduleDayState.pendingFieldEdits]), which it writes
/// [OcptScheduleBloc.defaultFieldEditDebounce] after the last keystroke, on a timer of its own; the
/// mode flushes them ahead of anything that needs the database to be up to date.
///
/// **Reacting.** A day, a block or a shot being selected clears nothing here, and a pending edit
/// survives the user moving to another day: it is written by its own debounce. When the mode reads
/// everything again (entry, a version preview, a restore, the project settings page) every pending
/// edit is dropped, as the mode itself did before the day view had a bloc of its own, since the
/// database underneath may be another one; when it reads the schedule again after a write, an edit
/// typed into a row that no longer exists is dropped.
///
/// A write that lands while the `Versions` tab is open has the mode refresh its working-copy card:
/// it does so in the very reload this bloc asks for.
class OcptScheduleDayBloc
    extends AbsOcptViewBloc<OcptScheduleDayState, OcptScheduleState, OcptScheduleBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "schedule_day_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and write the shooting schedule.
  final OcptScheduleService _scheduleService;

  /// The service used to write a shot's status.
  final OcptShotListService _shotListService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The start minute a slot created by [_onSlotCreated] is given: 08:00, mirroring
  /// `OcptScheduleService`'s own private `_defaultStartMinute` (not exported, so this is its own
  /// copy of the same figure).
  static const int _defaultSlotStartMinute = 480;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by
  /// tests, to keep it fast and deterministic.
  OcptScheduleDayBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptScheduleService? scheduleService,
    OcptShotListService? shotListService,
    Duration fieldEditDebounce = OcptScheduleBloc.defaultFieldEditDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _scheduleService =
           scheduleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).scheduleService,
       _shotListService =
           shotListService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotListService,
       _fieldEditDebounce = fieldEditDebounce,
       super(const OcptScheduleDayState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptScheduleSlotCreatedEvent>(_onSlotCreated);
    on<OcptScheduleSlotPlaceChangedEvent>(_onSlotPlaceChanged);
    on<OcptScheduleSlotAnchorChangedEvent>(_onSlotAnchorChanged);
    on<OcptScheduleSlotReorderedEvent>(_onSlotReordered);
    on<OcptScheduleSlotDeletionConfirmedEvent>(_onSlotDeletionConfirmed);
    on<OcptScheduleSlotCrewMemberAddedEvent>(_onSlotCrewMemberAdded);
    on<OcptScheduleSlotCrewMemberPositionChangedEvent>(_onSlotCrewMemberPositionChanged);
    on<OcptScheduleSlotCrewMemberRemovedEvent>(_onSlotCrewMemberRemoved);
    on<OcptScheduleSlotCastRoleAddedEvent>(_onSlotCastRoleAdded);
    on<OcptScheduleSlotCastRoleRemovedEvent>(_onSlotCastRoleRemoved);
    on<OcptScheduleBlockCandidateAddedEvent>(_onBlockCandidateAdded);
    on<OcptScheduleBlockCandidateRemovedEvent>(_onBlockCandidateRemoved);
    on<OcptScheduleSlotGuestAddedEvent>(_onSlotGuestAdded);
    on<OcptScheduleSlotGuestRemovedEvent>(_onSlotGuestRemoved);
    on<OcptScheduleDayEventCreatedEvent>(_onDayEventCreated);
    on<OcptScheduleDayEventMinuteChangedEvent>(_onDayEventMinuteChanged);
    on<OcptScheduleDayEventDeletionConfirmedEvent>(_onDayEventDeletionConfirmed);
    on<OcptScheduleShotStatusChangedEvent>(_onShotStatusChanged);
    on<OcptScheduleBlockCreatedEvent>(_onBlockCreated);
    on<OcptScheduleShotBlockCreatedEvent>(_onShotBlockCreated);
    on<OcptScheduleBlockDurationChangedEvent>(_onBlockDurationChanged);
    on<OcptScheduleBlockAnchorChangedEvent>(_onBlockAnchorChanged);
    on<OcptScheduleBlockSequenceChangedEvent>(_onBlockSequenceChanged);
    on<OcptScheduleBlockReorderedEvent>(_onBlockReordered);
    on<OcptScheduleBlockMovedToSlotEvent>(_onBlockMovedToSlot);
    on<OcptScheduleBlockDeletionConfirmedEvent>(_onBlockDeletionConfirmed);
    on<OcptScheduleFieldChangedEvent>(_onFieldChanged);
    on<OcptScheduleFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
  }

  /// Drops what the mode's fresh data no longer holds.
  ///
  /// When the mode read everything again (`OcptScheduleSelectionCause.load`: entry, a version
  /// preview or a restore, the project settings page) every pending edit goes, whichever row it was
  /// typed into: the database underneath may be another one. When it only read the schedule again, a
  /// pending edit whose row no longer exists in it (deleted, or cascaded away) goes, and only
  /// that one. Selecting a day, a block or a shot clears nothing: this bloc holds no selection.
  ///
  /// Reads the schedule from [modeBloc]'s current state — the latest data — but the cause of the
  /// selection move from the state that moved it (`event.modeState`). Waits for nothing: the mode's
  /// change and this reaction must land in the same turn of the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptScheduleState> event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final isLoaded =
        event.hasSelectionMoved &&
        event.modeState.selectionCause == OcptScheduleSelectionCause.load;
    if (isLoaded) {
      cancelDebounce();
      if (state.pendingFieldEdits.isNotEmpty) {
        emitter(state.copyWith(pendingFieldEdits: const {}));
      }
      return;
    }

    final snapshot = modeBloc.state.snapshot;
    if (!event.hasReloaded || snapshot == null || state.pendingFieldEdits.isEmpty) {
      return;
    }

    final rowIds = _scheduleRowIdsOf(snapshot);
    final pending = Map<OcptSchedulePendingFieldKey, String>.of(state.pendingFieldEdits)
      ..removeWhere((key, _) => !rowIds.contains(key.$1));
    if (pending.length == state.pendingFieldEdits.length) {
      return;
    }

    if (pending.isEmpty) {
      cancelDebounce();
    }
    emitter(state.copyWith(pendingFieldEdits: pending));
  }

  /// The ids of every row of [snapshot] a free-text field can be typed into: the days, the slots
  /// and what they convoke, the blocks and the events.
  Set<String> _scheduleRowIdsOf(OcptScheduleSnapshot snapshot) => {
    for (final day in snapshot.days) day.id,
    for (final slots in snapshot.slotsByDayId.values)
      for (final slot in slots) ...[
        slot.id,
        for (final crewMember in slot.crew) crewMember.id,
        for (final castMember in slot.cast) castMember.id,
        for (final guest in slot.guests) guest.id,
      ],
    for (final blocks in snapshot.blocksByDayId.values)
      for (final block in blocks) block.id,
    for (final events in snapshot.eventsByDayId.values)
      for (final event in events) event.id,
  };

  /// Creates a new slot inside a day.
  Future<void> _onSlotCreated(
    OcptScheduleSlotCreatedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.createSlot(
      database: project.database,
      shootingDayId: event.dayId,
      anchorMinute: _defaultSlotStartMinute,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Writes a new location/set onto a slot.
  Future<void> _onSlotPlaceChanged(
    OcptScheduleSlotPlaceChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateSlot(
      database: project.database,
      slotId: event.slotId,
      locationId: Value(event.locationId),
      setId: Value(event.setId),
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Pins a slot's own anchored edge to a typed hour or to another slot's opposite edge.
  Future<void> _onSlotAnchorChanged(
    OcptScheduleSlotAnchorChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.setSlotAnchor(
      database: project.database,
      slotId: event.slotId,
      edge: event.edge,
      minute: event.minute,
      sourceSlotId: event.sourceSlotId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Moves a slot to a new position within its own day.
  Future<void> _onSlotReordered(
    OcptScheduleSlotReorderedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.reorderSlot(
      database: project.database,
      slotId: event.slotId,
      newPosition: event.newPosition,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Deletes a slot for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onSlotDeletionConfirmed(
    OcptScheduleSlotDeletionConfirmedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.deleteSlot(database: project.database, slotId: event.slotId);
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Adds a crew member to a slot.
  Future<void> _onSlotCrewMemberAdded(
    OcptScheduleSlotCrewMemberAddedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.addSlotCrewMember(
      database: project.database,
      slotId: event.slotId,
      personId: event.personId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Writes a new position onto a crew assignment.
  Future<void> _onSlotCrewMemberPositionChanged(
    OcptScheduleSlotCrewMemberPositionChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateSlotCrewMember(
      database: project.database,
      crewMemberId: event.crewMemberId,
      positionId: Value(event.positionId),
      customLabel: Value(event.customLabel),
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Removes a crew assignment for good.
  Future<void> _onSlotCrewMemberRemoved(
    OcptScheduleSlotCrewMemberRemovedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.removeSlotCrewMember(
      database: project.database,
      crewMemberId: event.crewMemberId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Convokes a role during a slot.
  Future<void> _onSlotCastRoleAdded(
    OcptScheduleSlotCastRoleAddedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.addSlotCastRole(
      database: project.database,
      slotId: event.slotId,
      roleId: event.roleId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Removes a cast convocation for good.
  Future<void> _onSlotCastRoleRemoved(
    OcptScheduleSlotCastRoleRemovedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.removeSlotCastRole(
      database: project.database,
      castRoleId: event.castRoleId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Names a candidacy on an **audition** block — the hour that candidate is expected at.
  Future<void> _onBlockCandidateAdded(
    OcptScheduleBlockCandidateAddedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.addBlockCandidate(
      database: project.database,
      blockId: event.blockId,
      roleCandidateId: event.roleCandidateId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Takes a candidacy off an audition block, leaving the block and the candidacy alone.
  Future<void> _onBlockCandidateRemoved(
    OcptScheduleBlockCandidateRemovedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.removeBlockCandidate(
      database: project.database,
      blockCandidateId: event.blockCandidateId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Adds a guest to a slot, from the address book alone.
  Future<void> _onSlotGuestAdded(
    OcptScheduleSlotGuestAddedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.addSlotGuest(
      database: project.database,
      slotId: event.slotId,
      personId: event.personId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Removes a guest attendance for good.
  Future<void> _onSlotGuestRemoved(
    OcptScheduleSlotGuestRemovedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.deleteSlotGuest(database: project.database, guestId: event.guestId);
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Creates a new event on a day, at the hour the mode's own default-hour helper computed.
  Future<void> _onDayEventCreated(
    OcptScheduleDayEventCreatedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.createDayEvent(
      database: project.database,
      dayId: event.dayId,
      minute: event.minute,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Writes a new hour onto an event, the moment its own minute field commits.
  Future<void> _onDayEventMinuteChanged(
    OcptScheduleDayEventMinuteChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateDayEvent(
      database: project.database,
      eventId: event.eventId,
      minute: Value(event.minute),
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Removes an event for good.
  Future<void> _onDayEventDeletionConfirmed(
    OcptScheduleDayEventDeletionConfirmedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.deleteDayEvent(database: project.database, eventId: event.eventId);
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Writes a new shooting status onto a shot — the very column the shot list mode's own inspector
  /// edits — then reloads every episode's own shot list so every shot code, block chip and
  /// inspector line that shows it follows.
  Future<void> _onShotStatusChanged(
    OcptScheduleShotStatusChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _shotListService.updateShot(
      database: project.database,
      shotId: event.shotId,
      status: Value(event.status),
    );

    await modeBloc.reload({OcptScheduleReloadScope.shotLists});
  }

  /// Creates a new non-shot block (a milestone or a `hold`) at the end of the timetable named by
  /// the event's own [OcptScheduleBlockCreatedEvent.slotId] — the slot card whose own `+ Block`
  /// menu dispatched it.
  Future<void> _onBlockCreated(
    OcptScheduleBlockCreatedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null || event.kind == OcptShootingBlockKind.shot) {
      return;
    }

    await _scheduleService.createBlock(
      database: project.database,
      slotId: event.slotId,
      kind: event.kind,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Creates a new **shot** block at the end of the timetable named by the event's own
  /// [OcptScheduleShotBlockCreatedEvent.slotId], placing the shot it names — the slot card's own
  /// `+ Block` menu's `Shot` entry, once the mode's own picker dialog resolved to a pick.
  Future<void> _onShotBlockCreated(
    OcptScheduleShotBlockCreatedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.placeShot(
      database: project.database,
      slotId: event.slotId,
      shotId: event.shotId,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Writes a new duration onto a block.
  Future<void> _onBlockDurationChanged(
    OcptScheduleBlockDurationChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateBlock(
      database: project.database,
      blockId: event.blockId,
      durationMinutes: Value(event.durationMinutes),
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Writes a new anchor onto a block.
  Future<void> _onBlockAnchorChanged(
    OcptScheduleBlockAnchorChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateBlock(
      database: project.database,
      blockId: event.blockId,
      anchorMinute: Value(event.anchorMinute),
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Writes a new sequence onto a hold block — `OcptScheduleService.updateBlock` itself refuses the
  /// column on any other kind, so this handler passes it through unconditionally rather than
  /// checking the block's own kind a second time.
  Future<void> _onBlockSequenceChanged(
    OcptScheduleBlockSequenceChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateBlock(
      database: project.database,
      blockId: event.blockId,
      sceneId: Value(event.sceneId),
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Moves a block to a new position within its own slot's timetable.
  Future<void> _onBlockReordered(
    OcptScheduleBlockReorderedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.reorderBlock(
      database: project.database,
      blockId: event.blockId,
      newPosition: event.newPosition,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Moves a block to another slot, appended at the end of its own timetable.
  Future<void> _onBlockMovedToSlot(
    OcptScheduleBlockMovedToSlotEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final targetBlocks = [
      for (final blocks
          in modeBloc.state.snapshot?.blocksByDayId.values ?? const <List<OcptShootingDayBlock>>[])
        for (final block in blocks)
          if (block.slotId == event.targetSlotId) block,
    ];
    await _scheduleService.moveBlockToSlot(
      database: project.database,
      blockId: event.blockId,
      targetSlotId: event.targetSlotId,
      newPosition: targetBlocks.length,
    );
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Deletes a block for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onBlockDeletionConfirmed(
    OcptScheduleBlockDeletionConfirmedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.deleteBlock(database: project.database, blockId: event.blockId);
    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Records the raw text just typed into a field as a pending edit, visible immediately, and
  /// (re)starts the field-edit debounce.
  Future<void> _onFieldChanged(
    OcptScheduleFieldChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final pending = Map<OcptSchedulePendingFieldKey, String>.of(state.pendingFieldEdits)
      ..[(event.targetId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptScheduleFieldEditFlushRequestedEvent());
  }

  /// Fired by the field-edit debounce timer: writes every pending field edit.
  Future<void> _onFieldEditFlushRequested(
    OcptScheduleFieldEditFlushRequestedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    await onFlushRequested(emitter);
  }

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each one, then has the mode read the schedule again — which
  /// also refreshes the working-copy card if the `Versions` tab is open — and only then forgets
  /// what it wrote, so what a field shows never falls back to a stale stored value between the two.
  /// A no-op while nothing is pending. Answers whether there was anything pending.
  ///
  /// When the mode could not read the schedule again the edits stay pending: they were written, but
  /// what is on screen is still the older data.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<bool> onFlushRequested(Emitter<OcptScheduleDayState> emitter) async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return false;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(pendingFieldEdits: const {}));
      return true;
    }

    await _writeAllPendingFieldEdits(project, pending);
    if (!await modeBloc.reload({OcptScheduleReloadScope.schedule})) {
      return true;
    }

    emitter(
      state.copyWith(
        pendingFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingFieldEdits,
          written: pending,
        ),
      ),
    );
    return true;
  }

  /// Writes every pending field edit directly to the database, bypassing both the debounce timer
  /// and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()` (through the flushers it registered), mirroring
  /// `OcptBreakdownBloc.flushPendingFieldEdits`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree, so triggering the write here — rather than dispatching an event, which
  /// would only be processed on a later microtask this widget might not survive to see — is what
  /// guarantees the last [_fieldEditDebounce] worth of typing isn't lost. Unlike [onFlushRequested],
  /// this never touches [state]: `emit` may only be called from inside a registered `on<Event>`
  /// handler, and by the time this runs the widget tree that would show a fresh state is already
  /// gone anyway. A failure here is only logged.
  @override
  Future<void> flushPendingWritesWithoutState() async {
    cancelDebounce();

    final edits = state.pendingFieldEdits;
    if (edits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _writeAllPendingFieldEdits(project, edits);
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending schedule field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Writes every one of [edits] to [project]'s database, one write per entry — the shared write
  /// loop [onFlushRequested] and [flushPendingWritesWithoutState] both run, so the switch over
  /// [OcptScheduleField] is written once.
  Future<void> _writeAllPendingFieldEdits(
    OcptOpenProjectModel project,
    Map<OcptSchedulePendingFieldKey, String> edits,
  ) async {
    for (final entry in edits.entries) {
      final (targetId, field) = entry.key;
      final value = entry.value;

      switch (field) {
        case OcptScheduleField.dayCrewNote:
          await _scheduleService.updateDay(
            database: project.database,
            dayId: targetId,
            crewNote: Value(value),
          );
        case OcptScheduleField.dayWeatherNote:
          await _scheduleService.updateDay(
            database: project.database,
            dayId: targetId,
            weatherNote: Value(value),
          );
        case OcptScheduleField.dayNotes:
          await _scheduleService.updateDay(
            database: project.database,
            dayId: targetId,
            notes: Value(value),
          );
        case OcptScheduleField.slotLabel:
          await _scheduleService.updateSlot(
            database: project.database,
            slotId: targetId,
            label: Value(value),
          );
        case OcptScheduleField.slotNotes:
          await _scheduleService.updateSlot(
            database: project.database,
            slotId: targetId,
            notes: Value(value),
          );
        case OcptScheduleField.blockLabel:
          await _scheduleService.updateBlock(
            database: project.database,
            blockId: targetId,
            label: Value(value),
          );
        case OcptScheduleField.blockNotes:
          await _scheduleService.updateBlock(
            database: project.database,
            blockId: targetId,
            notes: Value(value),
          );
        case OcptScheduleField.blockCrewNote:
          await _scheduleService.updateBlock(
            database: project.database,
            blockId: targetId,
            crewNote: Value(value),
          );
        case OcptScheduleField.crewMemberCustomLabel:
          await _scheduleService.updateSlotCrewMember(
            database: project.database,
            crewMemberId: targetId,
            customLabel: Value(value),
          );
        case OcptScheduleField.crewMemberNotes:
          await _scheduleService.updateSlotCrewMember(
            database: project.database,
            crewMemberId: targetId,
            notes: Value(value),
          );
        case OcptScheduleField.castMemberNotes:
          await _scheduleService.updateSlotCastRole(
            database: project.database,
            castRoleId: targetId,
            notes: Value(value),
          );
        case OcptScheduleField.guestReason:
          await _scheduleService.updateSlotGuest(
            database: project.database,
            guestId: targetId,
            reason: Value(value),
          );
        case OcptScheduleField.guestNotes:
          await _scheduleService.updateSlotGuest(
            database: project.database,
            guestId: targetId,
            notes: Value(value),
          );
        case OcptScheduleField.dayEventLabel:
          await _scheduleService.updateDayEvent(
            database: project.database,
            eventId: targetId,
            label: Value(value),
          );
        case OcptScheduleField.dayEventNotes:
          await _scheduleService.updateDayEvent(
            database: project.database,
            eventId: targetId,
            notes: Value(value),
          );
      }
    }
  }
}
