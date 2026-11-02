// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
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
  /// The start minute a slot created by [_onSlotCreated] is given: 08:00, mirroring
  /// `OcptScheduleService`'s own private `_defaultStartMinute` (not exported, so this is its own
  /// copy of the same figure).
  static const int _defaultSlotStartMinute = 480;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and write the shooting schedule.
  final OcptScheduleService _scheduleService;

  /// The service used to write a shot's status.
  final OcptShotListService _shotListService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// {@macro open_cine_prod_tools.viewBlocConstructorWithDebounce}
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

  /// Drop what the mode's fresh data no longer holds.
  ///
  /// When the mode read everything again (`OcptScheduleSelectionCause.load`: entry, a version
  /// preview or a restore, the project settings page) every pending edit goes, whichever row it was
  /// typed into: the database underneath may be another one. When it only read the schedule again,
  /// a pending edit whose row no longer exists in it (deleted, or cascaded away) goes, and only
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
        emitter(state.copyWithFieldEditsCleared());
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
    emitter(state.copyWithPrunedFieldEdits(pendingFieldEdits: pending));
  }

  /// Write every pending field edit immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each one, then has the mode read the schedule again — which
  /// also refreshes the working-copy card if the `Versions` tab is open — and only then forgets
  /// what it wrote, so what a field shows never falls back to a stale stored value between the two.
  /// A no-op while nothing is pending. Answers `nothingToWrite` when nothing was pending.
  ///
  /// When the mode could not read the schedule again the flush answers `failed` and the edits stay
  /// pending: they were written, but what is on screen is still the older data.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<OcptPendingWritesStatus> onFlushRequested(Emitter<OcptScheduleDayState> emitter) async {
    cancelDebounce();

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return OcptPendingWritesStatus.nothingToWrite;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return OcptPendingWritesStatus.ok;
    }

    final written = await _writeAllPendingFieldEdits(project, pending);
    if (written.isError) {
      return OcptPendingWritesStatus.failed;
    }

    if (!await modeBloc.reload({OcptScheduleReloadScope.schedule})) {
      // The write landed but the mode could not read it back: answering that all went well
      // would let a preview, an export or a restore run on the snapshot from before the write, so
      // the flush answers that it failed. The edit stays pending, and the next flush writes it
      // again.
      return OcptPendingWritesStatus.failed;
    }

    emitter(
      state.copyWithFlushedFieldEdits(
        pendingFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingFieldEdits,
          written: pending,
        ),
      ),
    );
    return OcptPendingWritesStatus.ok;
  }

  /// Write every pending field edit directly to the database, bypassing both the debounce timer
  /// and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()` (through the flushers it registered), mirroring
  /// `OcptBreakdownBloc.flushPendingFieldEdits`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree, so triggering the write here — rather than dispatching an event, which
  /// would only be processed on a later microtask this widget might not survive to see — is what
  /// guarantees the last [_fieldEditDebounce] worth of typing isn't lost. Unlike
  /// [onFlushRequested], this never touches [state]: `emit` may only be called from inside a
  /// registered `on<Event>` handler, and by the time this runs the widget tree that would show a
  /// fresh state is already gone anyway. A write that fails is logged by the service, and the
  /// edit is left to be written again by the next flush.
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

    await flushEditsWithoutState(
      edits,
      (unwritten) => _writeAllPendingFieldEdits(project, unwritten),
    );
  }

  /// Get the ids of every row of [snapshot] a free-text field can be typed into: the days, the
  /// slots
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

  /// Create a new slot inside a day.
  Future<void> _onSlotCreated(
    OcptScheduleSlotCreatedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final created = await _scheduleService.createSlot(
      database: project.database,
      shootingDayId: event.dayId,
      anchorMinute: _defaultSlotStartMinute,
    );
    if (created.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Write a new location/set onto a slot.
  Future<void> _onSlotPlaceChanged(
    OcptScheduleSlotPlaceChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _scheduleService.updateSlot(
      database: project.database,
      slotId: event.slotId,
      locationId: Value(event.locationId),
      setId: Value(event.setId),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Pin a slot's own anchored edge to a typed hour or to another slot's opposite edge.
  Future<void> _onSlotAnchorChanged(
    OcptScheduleSlotAnchorChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final anchored = await _scheduleService.setSlotAnchor(
      database: project.database,
      slotId: event.slotId,
      edge: event.edge,
      minute: event.minute,
      sourceSlotId: event.sourceSlotId,
    );
    if (anchored.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Move a slot to a new position within its own day.
  Future<void> _onSlotReordered(
    OcptScheduleSlotReorderedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final reordered = await _scheduleService.reorderSlot(
      database: project.database,
      slotId: event.slotId,
      newPosition: event.newPosition,
    );
    if (reordered.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Delete a slot for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onSlotDeletionConfirmed(
    OcptScheduleSlotDeletionConfirmedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final deleted = await _scheduleService.deleteSlot(
      database: project.database,
      slotId: event.slotId,
    );
    if (deleted.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Add a crew member to a slot.
  Future<void> _onSlotCrewMemberAdded(
    OcptScheduleSlotCrewMemberAddedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final added = await _scheduleService.addSlotCrewMember(
      database: project.database,
      slotId: event.slotId,
      personId: event.personId,
    );
    if (added.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Write a new position onto a crew assignment.
  Future<void> _onSlotCrewMemberPositionChanged(
    OcptScheduleSlotCrewMemberPositionChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _scheduleService.updateSlotCrewMember(
      database: project.database,
      crewMemberId: event.crewMemberId,
      positionId: Value(event.positionId),
      customLabel: Value(event.customLabel),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Remove a crew assignment for good.
  Future<void> _onSlotCrewMemberRemoved(
    OcptScheduleSlotCrewMemberRemovedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final removed = await _scheduleService.removeSlotCrewMember(
      database: project.database,
      crewMemberId: event.crewMemberId,
    );
    if (removed.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Convoke a role during a slot.
  Future<void> _onSlotCastRoleAdded(
    OcptScheduleSlotCastRoleAddedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final added = await _scheduleService.addSlotCastRole(
      database: project.database,
      slotId: event.slotId,
      roleId: event.roleId,
    );
    if (added.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Remove a cast convocation for good.
  Future<void> _onSlotCastRoleRemoved(
    OcptScheduleSlotCastRoleRemovedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final removed = await _scheduleService.removeSlotCastRole(
      database: project.database,
      castRoleId: event.castRoleId,
    );
    if (removed.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Name a candidacy on an **audition** block — the hour that candidate is expected at.
  Future<void> _onBlockCandidateAdded(
    OcptScheduleBlockCandidateAddedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final added = await _scheduleService.addBlockCandidate(
      database: project.database,
      blockId: event.blockId,
      roleCandidateId: event.roleCandidateId,
    );
    if (added.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Take a candidacy off an audition block, leaving the block and the candidacy alone.
  Future<void> _onBlockCandidateRemoved(
    OcptScheduleBlockCandidateRemovedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final removed = await _scheduleService.removeBlockCandidate(
      database: project.database,
      blockCandidateId: event.blockCandidateId,
    );
    if (removed.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Add a guest to a slot, from the address book alone.
  Future<void> _onSlotGuestAdded(
    OcptScheduleSlotGuestAddedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final added = await _scheduleService.addSlotGuest(
      database: project.database,
      slotId: event.slotId,
      personId: event.personId,
    );
    if (added.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Remove a guest attendance for good.
  Future<void> _onSlotGuestRemoved(
    OcptScheduleSlotGuestRemovedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final deleted = await _scheduleService.deleteSlotGuest(
      database: project.database,
      guestId: event.guestId,
    );
    if (deleted.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Create a new event on a day, at the hour the mode's own default-hour helper computed.
  Future<void> _onDayEventCreated(
    OcptScheduleDayEventCreatedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final created = await _scheduleService.createDayEvent(
      database: project.database,
      dayId: event.dayId,
      minute: event.minute,
    );
    if (created.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Write a new hour onto an event, the moment its own minute field commits.
  Future<void> _onDayEventMinuteChanged(
    OcptScheduleDayEventMinuteChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _scheduleService.updateDayEvent(
      database: project.database,
      eventId: event.eventId,
      minute: Value(event.minute),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Remove an event for good.
  Future<void> _onDayEventDeletionConfirmed(
    OcptScheduleDayEventDeletionConfirmedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final deleted = await _scheduleService.deleteDayEvent(
      database: project.database,
      eventId: event.eventId,
    );
    if (deleted.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Write a new shooting status onto a shot — the very column the shot list mode's own inspector
  /// edits — then reload every episode's own shot list so every shot code, block chip and
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

  /// Create a new non-shot block (a milestone or a `hold`) at the end of the timetable named by
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

    final created = await _scheduleService.createBlock(
      database: project.database,
      slotId: event.slotId,
      kind: event.kind,
    );
    if (created.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Create a new **shot** block at the end of the timetable named by the event's own
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

    final placed = await _scheduleService.placeShot(
      database: project.database,
      slotId: event.slotId,
      shotId: event.shotId,
    );
    if (placed.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Write a new duration onto a block.
  Future<void> _onBlockDurationChanged(
    OcptScheduleBlockDurationChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _scheduleService.updateBlock(
      database: project.database,
      blockId: event.blockId,
      durationMinutes: Value(event.durationMinutes),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Write a new anchor onto a block.
  Future<void> _onBlockAnchorChanged(
    OcptScheduleBlockAnchorChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _scheduleService.updateBlock(
      database: project.database,
      blockId: event.blockId,
      anchorMinute: Value(event.anchorMinute),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Write a new sequence onto a hold block — `OcptScheduleService.updateBlock` itself refuses the
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

    final updated = await _scheduleService.updateBlock(
      database: project.database,
      blockId: event.blockId,
      sceneId: Value(event.sceneId),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Move a block to a new position within its own slot's timetable.
  Future<void> _onBlockReordered(
    OcptScheduleBlockReorderedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final reordered = await _scheduleService.reorderBlock(
      database: project.database,
      blockId: event.blockId,
      newPosition: event.newPosition,
    );
    if (reordered.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Move a block to another slot, appended at the end of its own timetable.
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
    final moved = await _scheduleService.moveBlockToSlot(
      database: project.database,
      blockId: event.blockId,
      targetSlotId: event.targetSlotId,
      newPosition: targetBlocks.length,
    );
    if (moved.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Delete a block for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onBlockDeletionConfirmed(
    OcptScheduleBlockDeletionConfirmedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final deleted = await _scheduleService.deleteBlock(
      database: project.database,
      blockId: event.blockId,
    );
    if (deleted.isError) {
      return;
    }

    await modeBloc.reload({OcptScheduleReloadScope.schedule});
  }

  /// Record the raw text just typed into a field as a pending edit, visible immediately, and
  /// (re)starts the field-edit debounce.
  Future<void> _onFieldChanged(
    OcptScheduleFieldChangedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    final pending = Map<OcptSchedulePendingFieldKey, String>.of(state.pendingFieldEdits)
      ..[(event.targetId, event.field)] = event.rawValue;
    emitter(state.copyWithTypedFieldEdits(pendingFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptScheduleFieldEditFlushRequestedEvent());
  }

  /// Write every pending field edit once the field-edit debounce timer fires.
  Future<void> _onFieldEditFlushRequested(
    OcptScheduleFieldEditFlushRequestedEvent event,
    Emitter<OcptScheduleDayState> emitter,
  ) async {
    await onFlushRequested(emitter);
  }

  /// Write every one of [edits] to [project]'s database, one write per entry — the shared write
  /// loop [onFlushRequested] and [flushPendingWritesWithoutState] both run, so the switch over
  /// [OcptScheduleField] is written once.
  ///
  /// Stops at the first write that failed and answers its failure, leaving the entries after it
  /// unwritten.
  Future<OcptDatabaseOutcome> _writeAllPendingFieldEdits(
    OcptOpenProjectModel project,
    Map<OcptSchedulePendingFieldKey, String> edits,
  ) async {
    for (final entry in edits.entries) {
      final (targetId, field) = entry.key;
      final value = entry.value;

      final written = switch (field) {
        OcptScheduleField.dayCrewNote => await _scheduleService.updateDay(
          database: project.database,
          dayId: targetId,
          crewNote: Value(value),
        ),
        OcptScheduleField.dayWeatherNote => await _scheduleService.updateDay(
          database: project.database,
          dayId: targetId,
          weatherNote: Value(value),
        ),
        OcptScheduleField.dayNotes => await _scheduleService.updateDay(
          database: project.database,
          dayId: targetId,
          notes: Value(value),
        ),
        OcptScheduleField.slotLabel => await _scheduleService.updateSlot(
          database: project.database,
          slotId: targetId,
          label: Value(value),
        ),
        OcptScheduleField.slotNotes => await _scheduleService.updateSlot(
          database: project.database,
          slotId: targetId,
          notes: Value(value),
        ),
        OcptScheduleField.blockLabel => await _scheduleService.updateBlock(
          database: project.database,
          blockId: targetId,
          label: Value(value),
        ),
        OcptScheduleField.blockNotes => await _scheduleService.updateBlock(
          database: project.database,
          blockId: targetId,
          notes: Value(value),
        ),
        OcptScheduleField.blockCrewNote => await _scheduleService.updateBlock(
          database: project.database,
          blockId: targetId,
          crewNote: Value(value),
        ),
        OcptScheduleField.crewMemberCustomLabel => await _scheduleService.updateSlotCrewMember(
          database: project.database,
          crewMemberId: targetId,
          customLabel: Value(value),
        ),
        OcptScheduleField.crewMemberNotes => await _scheduleService.updateSlotCrewMember(
          database: project.database,
          crewMemberId: targetId,
          notes: Value(value),
        ),
        OcptScheduleField.castMemberNotes => await _scheduleService.updateSlotCastRole(
          database: project.database,
          castRoleId: targetId,
          notes: Value(value),
        ),
        OcptScheduleField.guestReason => await _scheduleService.updateSlotGuest(
          database: project.database,
          guestId: targetId,
          reason: Value(value),
        ),
        OcptScheduleField.guestNotes => await _scheduleService.updateSlotGuest(
          database: project.database,
          guestId: targetId,
          notes: Value(value),
        ),
        OcptScheduleField.dayEventLabel => await _scheduleService.updateDayEvent(
          database: project.database,
          eventId: targetId,
          label: Value(value),
        ),
        OcptScheduleField.dayEventNotes => await _scheduleService.updateDayEvent(
          database: project.database,
          eventId: targetId,
          notes: Value(value),
        ),
      };
      if (written.isError) {
        return written;
      }
    }

    return const OcptDatabaseOutcome(status: OcptDatabaseStatus.ok);
  }
}
