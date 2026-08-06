// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the schedule production mode.
///
/// It loads the current project's title and the mode's own whole read on entry: the schedule
/// itself ([_scheduleService]), the shot list ([_shotListService] — every placed or unplaced
/// shot's own code, size, duration and characters), the three resources catalogues the slot
/// cards read from ([_locationsService], [_roleIndexService], [_peopleService]), and the
/// breakdown pass's own role tags ([_breakdownService] — every scene's own
/// [OcptScheduleState.roleIdsBySceneId], what a **hold** block's own roles are resolved through).
/// It mixes in [MixinOcptProjectVersionsBloc], answering its two hooks through
/// [_flushPendingFieldEdits] and [_onLoadRequested].
///
/// The two dock fractions and the last right dock tab are persisted through
/// [_propertiesManager]'s `scheduleLeftDockFraction`/`scheduleRightDockFraction`/
/// `scheduleLastRightDockTab`, mirroring `OcptBreakdownBloc` exactly.
///
/// Every write but the free-text fields (which ride [_fieldEditDebounce], flushed by
/// [_flushPendingFieldEdits] on a version preview and by the mode's own `deactivate()`) lands the
/// moment it is dispatched, then reloads the schedule snapshot through [_applyScheduleSnapshot] —
/// which also reconciles [OcptScheduleState.selectedDayId]/[OcptScheduleState.selectedBlockId]
/// against the freshly loaded snapshot (a selection whose row disappeared is dropped rather than
/// trusted to still mean something) and, while the `Versions` tab is open, asks
/// [MixinOcptProjectVersionsBloc] for a fresh working-copy capture — the mode's own stand-in for
/// "a save landing while it is open", since nothing here is a single save.
class OcptScheduleBloc extends BlocForMixin<OcptScheduleState>
    with MixinOcptProjectVersionsBloc<OcptScheduleState> {
  /// The default delay between the last field edit and its autosave write.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions and last right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The service used to read and write the shooting schedule.
  final OcptScheduleService _scheduleService;

  /// The service used to read the shot list (unplaced shots, and every placed block's own shot)
  /// and to write a shot's status.
  final OcptShotListService _shotListService;

  /// The service used to read locations and their sets.
  final OcptLocationsService _locationsService;

  /// The service used to read the cast reconciled against the screenplay.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read the address book.
  final OcptPeopleService _peopleService;

  /// The service used to read the breakdown pass's own role tags — what a **hold** block's own
  /// roles are resolved through, once its `sceneId` names a sequence.
  final OcptBreakdownService _breakdownService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The start minute a slot created by [_onSlotCreated] is given: 08:00, mirroring
  /// `OcptScheduleService`'s own private `_defaultStartMinute` (not exported, so this is its own
  /// copy of the same figure).
  static const int _defaultSlotStartMinute = 480;

  /// The running field-edit debounce timer, if any.
  Timer? _fieldEditTimer;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by tests, to keep it
  /// fast and deterministic.
  OcptScheduleBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptScheduleService? scheduleService,
    OcptShotListService? shotListService,
    OcptLocationsService? locationsService,
    OcptRoleIndexService? roleIndexService,
    OcptPeopleService? peopleService,
    OcptBreakdownService? breakdownService,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _scheduleService =
           scheduleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).scheduleService,
       _shotListService =
           shotListService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotListService,
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _roleIndexService =
           roleIndexService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleIndexService,
       _peopleService =
           peopleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).peopleService,
       _breakdownService =
           breakdownService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).breakdownService,
       _fieldEditDebounce = fieldEditDebounce,
       super(OcptScheduleState.init()) {
    add(const OcptScheduleLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptScheduleLoadRequestedEvent>(_onLoadRequested);
    on<OcptScheduleBackRequestedEvent>(_onBackRequested);
    on<OcptScheduleLeftPanelToggledEvent>(_onLeftPanelToggled);
    on<OcptScheduleRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptScheduleRightDockToggledEvent>(_onRightDockToggled);
    on<OcptScheduleRightDockClosedEvent>(_onRightDockClosed);
    on<OcptScheduleDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptScheduleDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptScheduleDaySelectedEvent>(_onDaySelected);
    on<OcptScheduleBlockSelectedEvent>(_onBlockSelected);
    on<OcptScheduleCentreViewSelectedEvent>(_onCentreViewSelected);
    on<OcptScheduleAgendaModeSelectedEvent>(_onAgendaModeSelected);
    on<OcptScheduleAgendaAnchorDateChangedEvent>(_onAgendaAnchorDateChanged);
    on<OcptScheduleDayCreatedEvent>(_onDayCreated);
    on<OcptScheduleDayDateChangedEvent>(_onDayDateChanged);
    on<OcptScheduleDayStatusChangedEvent>(_onDayStatusChanged);
    on<OcptScheduleDayDuplicationRequestedEvent>(_onDayDuplicationRequested);
    on<OcptScheduleDayDeletionConfirmedEvent>(_onDayDeletionConfirmed);
    on<OcptScheduleGroupCreatedEvent>(_onGroupCreated);
    on<OcptScheduleGroupLeadChangedEvent>(_onGroupLeadChanged);
    on<OcptScheduleGroupDeletionConfirmedEvent>(_onGroupDeletionConfirmed);
    on<OcptScheduleSlotCreatedEvent>(_onSlotCreated);
    on<OcptScheduleSlotPlaceChangedEvent>(_onSlotPlaceChanged);
    on<OcptScheduleSlotStartChangedEvent>(_onSlotStartChanged);
    on<OcptScheduleSlotReorderedEvent>(_onSlotReordered);
    on<OcptScheduleSlotDeletionConfirmedEvent>(_onSlotDeletionConfirmed);
    on<OcptScheduleSlotCrewMemberAddedEvent>(_onSlotCrewMemberAdded);
    on<OcptScheduleSlotCrewMemberPositionChangedEvent>(_onSlotCrewMemberPositionChanged);
    on<OcptScheduleSlotCrewMemberRemovedEvent>(_onSlotCrewMemberRemoved);
    on<OcptScheduleSlotCrewMemberLeadChangedEvent>(_onSlotCrewMemberLeadChanged);
    on<OcptScheduleSlotCrewMemberGroupChangedEvent>(_onSlotCrewMemberGroupChanged);
    on<OcptScheduleSlotCastRoleAddedEvent>(_onSlotCastRoleAdded);
    on<OcptScheduleSlotCastRoleRemovedEvent>(_onSlotCastRoleRemoved);
    on<OcptScheduleSlotCastRoleLeadChangedEvent>(_onSlotCastRoleLeadChanged);
    on<OcptScheduleSlotCastRoleGroupChangedEvent>(_onSlotCastRoleGroupChanged);
    on<OcptScheduleShotSelectedEvent>(_onShotSelected);
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

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// Writes whatever free-text field edit is still sitting in the field-edit debounce, so a preview
  /// about to swap the database can't send it into the previewed version instead, then clears the
  /// selected shot: a shot selected out of the working copy's own shot list means nothing once a
  /// preview swaps that data out.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptScheduleState> emitter) async {
    await _flushPendingFieldEdits(emitter);
    emitter(state.copyWith(clearSelectedShotId: true));
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptScheduleState> emitter) =>
      _onLoadRequested(const OcptScheduleLoadRequestedEvent(), emitter);

  /// Loads the current project's whole schedule read: the schedule itself, the shot list and the
  /// three resources catalogues.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the read it just performed (see that hook's own
  /// doc comment). The selected block, the selected shot and any pending field edit are always
  /// cleared on a (re)load: a preview or a restore changes the whole database underneath, so a
  /// stale one is dropped rather than trusted to still mean the same thing. The selected **day**
  /// is dropped for the same reason and then chosen afresh out of what was just read, by
  /// [_defaultSelectedDayOf] — never carried over.
  Future<void> _onLoadRequested(
    OcptScheduleLoadRequestedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final leftDockFraction =
        await _propertiesManager.scheduleLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.scheduleRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;
    final lastRightDockTab =
        await _propertiesManager.scheduleLastRightDockTab.load() ??
        OcptScheduleRightDockTab.inspector;
    final firstWeekday = await _propertiesManager.firstWeekday.load() ?? OcptFirstWeekday.monday;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          isLoading: false,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
          firstWeekday: firstWeekday,
          clearPreviewedVersionId: true,
          clearSelectedDayId: true,
          clearSelectedBlockId: true,
          clearSelectedShotId: true,
          pendingFieldEdits: const {},
        ),
      );
      return;
    }

    final previewedVersion = project.previewedVersion;
    final snapshot = await _loadScheduleSnapshot(project);
    final shotListSnapshot = await _shotListService.loadShotList(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    final locations = await _locationsService.loadLocations(database: project.database);
    final roles = await _roleIndexService.loadRoles(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    final people = await _peopleService.loadPeople(database: project.database);
    final breakdownTags = await _breakdownService.loadTags(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    final roleIdsBySceneId = <String, Set<String>>{};
    for (final tag in breakdownTags) {
      final roleId = tag.roleId;
      if (tag.targetKind == OcptBreakdownTargetKind.role && roleId != null) {
        (roleIdsBySceneId[tag.sceneId] ??= <String>{}).add(roleId);
      }
    }

    final defaultDay = _defaultSelectedDayOf(snapshot.days);

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        previewedVersionId: previewedVersion?.id,
        clearPreviewedVersionId: previewedVersion == null,
        snapshot: snapshot,
        shotListSnapshot: shotListSnapshot,
        locations: locations,
        roles: roles,
        people: people,
        roleIdsBySceneId: roleIdsBySceneId,
        agendaAnchorDate: defaultDay?.date ?? DateTime.now(),
        selectedDayId: defaultDay?.id,
        clearSelectedDayId: defaultDay == null,
        clearSelectedBlockId: true,
        clearSelectedShotId: true,
        pendingFieldEdits: const {},
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        lastRightDockTab: lastRightDockTab,
        firstWeekday: firstWeekday,
      ),
    );
  }

  /// The day a load lands on: the one dated today, failing that the next one still to come, and
  /// failing that the last one shot — null only for a project holding no day at all.
  ///
  /// The mode opens on the day view, which without a selection shows nothing but a hint, so a load
  /// has to name a day rather than leave the user to hunt for one. "Where the production is today"
  /// is the honest reading of that: mid-shoot it is the day being shot, before it starts the first
  /// one, and once it is over the last — never a day chosen for being first in the list.
  ///
  /// [days] arrives in `dayNumber` order, which is `sortKey` order and not necessarily date order:
  /// a day inserted late sits where the user put it. The scan therefore compares dates rather than
  /// trusting the order, and falls back on the list's own last entry.
  OcptShootingDay? _defaultSelectedDayOf(List<OcptShootingDay> days) {
    if (days.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    OcptShootingDay? nextToCome;

    for (final day in days) {
      final date = DateTime(day.date.year, day.date.month, day.date.day);
      if (date == today) {
        return day;
      }
      if (date.isAfter(today) && (nextToCome == null || date.isBefore(nextToCome.date))) {
        nextToCome = day;
      }
    }

    return nextToCome ?? days.last;
  }

  /// Reads [project]'s whole schedule.
  Future<OcptScheduleSnapshot> _loadScheduleSnapshot(OcptOpenProjectModel project) =>
      _scheduleService.loadSchedule(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );

  /// Leaves the workspace: closes the current project and navigates back to the home page.
  Future<void> _onBackRequested(
    OcptScheduleBackRequestedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Toggles the left (days) dock's visibility.
  Future<void> _onLeftPanelToggled(
    OcptScheduleLeftPanelToggledEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWith(isListPanelVisible: !state.isListPanelVisible));
  }

  /// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it). Flushes any pending field edit first, mirroring every other mode.
  Future<void> _onRightDockTabSelected(
    OcptScheduleRightDockTabSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);
    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        clearRightDockTab: isAlreadyActive,
        lastRightDockTab: event.tab,
      ),
    );

    if (!isAlreadyActive && event.tab == OcptScheduleRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptScheduleState.lastRightDockTab].
  Future<void> _onRightDockToggled(
    OcptScheduleRightDockToggledEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWith(clearRightDockTab: true));
      return;
    }

    emitter(state.copyWith(rightDockTab: state.lastRightDockTab));

    if (state.lastRightDockTab == OcptScheduleRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Closes the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptScheduleRightDockClosedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWith(clearRightDockTab: true));
  }

  /// Applies and persists whichever dock fraction the ended drag gesture reports.
  Future<void> _onDockFractionsChanged(
    OcptScheduleDockFractionsChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final left = event.left;
    final right = event.right;

    if (left != null) {
      await _propertiesManager.scheduleLeftDockFraction.store(left);
    }
    if (right != null) {
      await _propertiesManager.scheduleRightDockFraction.store(right);
    }

    emitter(state.copyWith(leftDockFraction: left, rightDockFraction: right));
  }

  /// Restores both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptScheduleDockLayoutResetEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    await _propertiesManager.scheduleLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.scheduleRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWith(
        leftDockFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightDockFraction: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Persists [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptScheduleRightDockTab tab) async {
    if (state.lastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.scheduleLastRightDockTab.store(tab);
  }

  /// Selects day [OcptScheduleDaySelectedEvent.dayId], clearing both the selected block and the
  /// selected shot: a day selected on its own has neither, and the day's own read-out is what the
  /// inspector must fall back to (see the event's own doc comment). A day id that no longer exists
  /// in the current snapshot is ignored.
  Future<void> _onDaySelected(
    OcptScheduleDaySelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    if (!state.daysById.containsKey(event.dayId)) {
      return;
    }

    emitter(
      state.copyWith(
        selectedDayId: event.dayId,
        clearSelectedBlockId: true,
        clearSelectedShotId: true,
      ),
    );
  }

  /// Selects block [OcptScheduleBlockSelectedEvent.blockId] and its own day, opening the right dock
  /// on the `Inspector` tab, and clears the selected shot: the two selections are mutually
  /// exclusive.
  Future<void> _onBlockSelected(
    OcptScheduleBlockSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    if (!state.daysById.containsKey(event.dayId)) {
      return;
    }

    emitter(
      state.copyWith(
        selectedDayId: event.dayId,
        selectedBlockId: event.blockId,
        clearSelectedShotId: true,
        rightDockTab: OcptScheduleRightDockTab.inspector,
        lastRightDockTab: OcptScheduleRightDockTab.inspector,
      ),
    );
  }

  /// Selects shot [OcptScheduleShotSelectedEvent.shotId], opening the right dock on the `Inspector`
  /// tab, and clears the selected block: the two selections are mutually exclusive. A shot id
  /// naming no live shot of the current shot list is ignored.
  Future<void> _onShotSelected(
    OcptScheduleShotSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    if (state.shotById(event.shotId) == null) {
      return;
    }

    emitter(
      state.copyWith(
        selectedShotId: event.shotId,
        clearSelectedBlockId: true,
        rightDockTab: OcptScheduleRightDockTab.inspector,
        lastRightDockTab: OcptScheduleRightDockTab.inspector,
      ),
    );
  }

  /// Switches the centre between the agenda and the day view.
  Future<void> _onCentreViewSelected(
    OcptScheduleCentreViewSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWith(centreView: event.view));
  }

  /// Switches the agenda's own presentation.
  Future<void> _onAgendaModeSelected(
    OcptScheduleAgendaModeSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWith(agendaMode: event.mode));
  }

  /// Pages the week/month agenda to a new anchor date.
  Future<void> _onAgendaAnchorDateChanged(
    OcptScheduleAgendaAnchorDateChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWith(agendaAnchorDate: event.date));
  }

  /// Creates a new shooting day and selects it.
  Future<void> _onDayCreated(
    OcptScheduleDayCreatedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final dayId = await _scheduleService.createDay(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      date: event.date,
    );

    await _applyScheduleSnapshot(emitter, project);
    if (dayId != null) {
      emitter(state.copyWith(selectedDayId: dayId, clearSelectedBlockId: true));
    }
  }

  /// Writes a new date onto the selected day.
  Future<void> _onDayDateChanged(
    OcptScheduleDayDateChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateDay(
      database: project.database,
      dayId: event.dayId,
      date: Value(event.date),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new status onto the selected day.
  Future<void> _onDayStatusChanged(
    OcptScheduleDayStatusChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateDay(
      database: project.database,
      dayId: event.dayId,
      status: Value(event.status),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Duplicates a day and selects the new one.
  Future<void> _onDayDuplicationRequested(
    OcptScheduleDayDuplicationRequestedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final newDayId = await _scheduleService.duplicateDay(
      database: project.database,
      sourceDayId: event.sourceDayId,
      date: event.date,
    );

    await _applyScheduleSnapshot(emitter, project);
    if (newDayId != null) {
      emitter(state.copyWith(selectedDayId: newDayId, clearSelectedBlockId: true));
    }
  }

  /// Deletes a day for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onDayDeletionConfirmed(
    OcptScheduleDayDeletionConfirmedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.deleteDay(database: project.database, dayId: event.dayId);
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Creates a new group on a day.
  Future<void> _onGroupCreated(
    OcptScheduleGroupCreatedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.createGroup(database: project.database, shootingDayId: event.dayId);
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new lead time onto a group.
  Future<void> _onGroupLeadChanged(
    OcptScheduleGroupLeadChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateGroup(
      database: project.database,
      groupId: event.groupId,
      leadMinutes: Value(event.leadMinutes),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Deletes a group for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onGroupDeletionConfirmed(
    OcptScheduleGroupDeletionConfirmedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.deleteGroup(database: project.database, groupId: event.groupId);
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Creates a new slot inside a day.
  Future<void> _onSlotCreated(
    OcptScheduleSlotCreatedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.createSlot(
      database: project.database,
      shootingDayId: event.dayId,
      startMinute: _defaultSlotStartMinute,
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new location/set onto a slot.
  Future<void> _onSlotPlaceChanged(
    OcptScheduleSlotPlaceChangedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new start minute onto a slot.
  Future<void> _onSlotStartChanged(
    OcptScheduleSlotStartChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateSlot(
      database: project.database,
      slotId: event.slotId,
      startMinute: Value(event.startMinute),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Moves a slot to a new position within its own day.
  Future<void> _onSlotReordered(
    OcptScheduleSlotReorderedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Deletes a slot for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onSlotDeletionConfirmed(
    OcptScheduleSlotDeletionConfirmedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.deleteSlot(database: project.database, slotId: event.slotId);
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Adds a crew member to a slot.
  Future<void> _onSlotCrewMemberAdded(
    OcptScheduleSlotCrewMemberAddedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new position onto a crew assignment.
  Future<void> _onSlotCrewMemberPositionChanged(
    OcptScheduleSlotCrewMemberPositionChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateSlotCrewMember(
      database: project.database,
      crewMemberId: event.crewMemberId,
      positionId: Value(event.positionId),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Removes a crew assignment for good.
  Future<void> _onSlotCrewMemberRemoved(
    OcptScheduleSlotCrewMemberRemovedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.removeSlotCrewMember(
      database: project.database,
      crewMemberId: event.crewMemberId,
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new lead time onto a crew assignment, or clears it back to reading its group's.
  Future<void> _onSlotCrewMemberLeadChanged(
    OcptScheduleSlotCrewMemberLeadChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateSlotCrewMember(
      database: project.database,
      crewMemberId: event.crewMemberId,
      leadMinutes: Value(event.leadMinutes),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new group onto a crew assignment, or clears it back to no group.
  Future<void> _onSlotCrewMemberGroupChanged(
    OcptScheduleSlotCrewMemberGroupChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateSlotCrewMember(
      database: project.database,
      crewMemberId: event.crewMemberId,
      groupId: Value(event.groupId),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Convokes a role during a slot.
  Future<void> _onSlotCastRoleAdded(
    OcptScheduleSlotCastRoleAddedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Removes a cast convocation for good.
  Future<void> _onSlotCastRoleRemoved(
    OcptScheduleSlotCastRoleRemovedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.removeSlotCastRole(database: project.database, castRoleId: event.castRoleId);
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new lead time onto a cast convocation, or clears it back to reading its group's.
  Future<void> _onSlotCastRoleLeadChanged(
    OcptScheduleSlotCastRoleLeadChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateSlotCastRole(
      database: project.database,
      castRoleId: event.castRoleId,
      leadMinutes: Value(event.leadMinutes),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new group onto a cast convocation, or clears it back to no group.
  Future<void> _onSlotCastRoleGroupChanged(
    OcptScheduleSlotCastRoleGroupChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.updateSlotCastRole(
      database: project.database,
      castRoleId: event.castRoleId,
      groupId: Value(event.groupId),
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new shooting status onto a shot — the very column the shot list mode's own inspector
  /// edits — then reloads the shot list read so every shot code, block chip and inspector line
  /// that shows it follows.
  Future<void> _onShotStatusChanged(
    OcptScheduleShotStatusChangedEvent event,
    Emitter<OcptScheduleState> emitter,
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

    final shotListSnapshot = await _shotListService.loadShotList(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    emitter(state.copyWith(shotListSnapshot: shotListSnapshot));
    _requestWorkingCopyRefreshIfVersionsOpen();
  }

  /// Creates a new non-shot block (a milestone or a `hold`) at the end of the timetable named by
  /// the event's own [OcptScheduleBlockCreatedEvent.slotId] — the slot card whose own `+ Block`
  /// menu dispatched it.
  Future<void> _onBlockCreated(
    OcptScheduleBlockCreatedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null || event.kind == OcptShootingBlockKind.shot) {
      return;
    }

    await _scheduleService.createBlock(database: project.database, slotId: event.slotId, kind: event.kind);
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Creates a new **shot** block at the end of the timetable named by the event's own
  /// [OcptScheduleShotBlockCreatedEvent.slotId], placing the shot it names — the slot card's own
  /// `+ Block` menu's `Shot` entry, once the mode's own picker dialog resolved to a pick.
  Future<void> _onShotBlockCreated(
    OcptScheduleShotBlockCreatedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new duration onto a block.
  Future<void> _onBlockDurationChanged(
    OcptScheduleBlockDurationChangedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new anchor onto a block.
  Future<void> _onBlockAnchorChanged(
    OcptScheduleBlockAnchorChangedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes a new sequence onto a hold block — `OcptScheduleService.updateBlock` itself refuses the
  /// column on any other kind, so this handler passes it through unconditionally rather than
  /// checking the block's own kind a second time.
  Future<void> _onBlockSequenceChanged(
    OcptScheduleBlockSequenceChangedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Moves a block to a new position within its own slot's timetable.
  Future<void> _onBlockReordered(
    OcptScheduleBlockReorderedEvent event,
    Emitter<OcptScheduleState> emitter,
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
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Moves a block to another slot, appended at the end of its own timetable.
  Future<void> _onBlockMovedToSlot(
    OcptScheduleBlockMovedToSlotEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final targetBlocks = [
      for (final blocks in state.snapshot?.blocksByDayId.values ?? const <List<OcptShootingDayBlock>>[])
        for (final block in blocks)
          if (block.slotId == event.targetSlotId) block,
    ];
    await _scheduleService.moveBlockToSlot(
      database: project.database,
      blockId: event.blockId,
      targetSlotId: event.targetSlotId,
      newPosition: targetBlocks.length,
    );
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Deletes a block for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onBlockDeletionConfirmed(
    OcptScheduleBlockDeletionConfirmedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _scheduleService.deleteBlock(database: project.database, blockId: event.blockId);
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Records the raw text just typed into a field as a pending edit, visible immediately, and
  /// (re)starts the field-edit debounce.
  Future<void> _onFieldChanged(
    OcptScheduleFieldChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final pending = Map<OcptSchedulePendingFieldKey, String>.of(state.pendingFieldEdits)
      ..[(event.targetId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingFieldEdits: pending));

    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptScheduleFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Fired by the field-edit debounce timer: writes every pending field edit.
  Future<void> _onFieldEditFlushRequested(
    OcptScheduleFieldEditFlushRequestedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) => _flushPendingFieldEdits(emitter);

  /// Writes every field edit still sitting in the debounce, cancelling the running timer first.
  ///
  /// A no-op when nothing is pending: called on every selection-changing path and on every
  /// version-preview transition, most of which have nothing waiting.
  Future<void> _flushPendingFieldEdits(Emitter<OcptScheduleState> emitter) async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final edits = state.pendingFieldEdits;
    if (edits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(pendingFieldEdits: const {}));
      return;
    }

    await _writeAllPendingFieldEdits(project, edits);

    emitter(state.copyWith(pendingFieldEdits: const {}));
    await _applyScheduleSnapshot(emitter, project);
  }

  /// Writes every pending field edit directly to the database, bypassing both the debounce timer
  /// and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()`, mirroring `OcptBreakdownBloc.flushPendingFieldEdits`:
  /// `deactivate()` runs before `dispose()` for every removal from the tree, so triggering the
  /// write here — rather than dispatching an event, which would only be processed on a later
  /// microtask this widget might not survive to see — is what guarantees the last
  /// [_fieldEditDebounce] worth of typing isn't lost. Unlike [_flushPendingFieldEdits], this never
  /// touches [state]: `emit` may only be called from inside a registered `on<Event>` handler, and
  /// by the time this runs the widget tree that would show a fresh state is already gone anyway. A
  /// failure here is only logged.
  Future<void> flushPendingFieldEdits() async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

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
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending schedule field edit of the "
          "project at ${project.path}: $error");
    }
  }

  /// Writes every one of [edits] to [project]'s database, one write per entry — the shared write
  /// loop [_flushPendingFieldEdits] and [flushPendingFieldEdits] both run, so the switch over
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
        case OcptScheduleField.groupLabel:
          await _scheduleService.updateGroup(
            database: project.database,
            groupId: targetId,
            label: Value(value),
          );
      }
    }
  }

  /// Re-reads the schedule of [project] and applies it, reconciling
  /// [OcptScheduleState.selectedDayId]/[OcptScheduleState.selectedBlockId] against what the fresh
  /// snapshot still holds — a selected row that disappeared (deleted, or a slot that dropped its
  /// block's own anchor) is dropped rather than trusted to still mean something.
  ///
  /// Every handler that writes to the schedule tables ends here, which is also the mode's own
  /// stand-in for "a save landing while the `Versions` tab is open" (see the class doc comment):
  /// [_requestWorkingCopyRefreshIfVersionsOpen] is called once the fresh snapshot has landed.
  Future<void> _applyScheduleSnapshot(
    Emitter<OcptScheduleState> emitter,
    OcptOpenProjectModel project,
  ) async {
    final snapshot = await _loadScheduleSnapshot(project);

    final dayStillExists = state.selectedDayId == null || snapshot.daysById.containsKey(state.selectedDayId);
    final blockStillExists =
        dayStillExists &&
        state.selectedBlockId != null &&
        (snapshot.blocksByDayId[state.selectedDayId] ?? const []).any(
          (block) => block.id == state.selectedBlockId,
        );

    emitter(
      state.copyWith(
        snapshot: snapshot,
        clearSelectedDayId: !dayStillExists,
        clearSelectedBlockId: !blockStillExists,
      ),
    );

    _requestWorkingCopyRefreshIfVersionsOpen();
  }

  /// Dispatches [OcptProjectWorkingCopyRefreshRequestedEvent] while the `Versions` tab is the one
  /// currently open — see the class doc comment for why every write here counts as "a save landing
  /// while it is open".
  void _requestWorkingCopyRefreshIfVersionsOpen() {
    if (state.rightDockTab == OcptScheduleRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }
}
