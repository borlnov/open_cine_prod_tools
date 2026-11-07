// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart' show useResult;
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_schedule_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_page_setup_loading.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/schedule_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the schedule production mode.
///
/// It loads the current project's title and the mode's own whole read on entry: the schedule
/// itself ([_scheduleService]), every live episode's own shot list ([_shotListService], through
/// [_loadShotLists] — every placed or unplaced shot's own code, size, duration and characters,
/// across the whole project rather than one screenplay, a shooting day belonging to no episode),
/// and the five resources catalogues the slot cards and the call sheet exports read from
/// ([_locationsService], [_roleIndexService], [_peopleService], [_elementsService],
/// [_roleCandidatesService] — the elements read for a named call sheet's own "to bring" section
/// alone, nothing here shows an element on screen, and the candidacies read for the days that do
/// not shoot: an audition block and a candidate's convocation are both resolved to a name and a
/// part through them). It holds the selected day, block and shot, the dock geometry, the centre
/// view and the agenda's presentation on top, and writes the shooting days themselves (creating,
/// re-dating, re-statusing, duplicating and deleting one), a day being the selection's root and the
/// left dock's list.
///
/// What the day view does with a day — its slots, the crew, cast, guests and candidacies they
/// convoke, their blocks, the day's own events, a shot's status and every free-text field typed
/// into them — belongs to `OcptScheduleDayBloc`, which writes through the services and then asks
/// this bloc to read the data again ([reload]). The seven exports belong to
/// `OcptScheduleExportBloc`, which asks this bloc to write every pending edit
/// ([flushAllPendingWrites]) and then reads the plan this bloc holds.
///
/// Every pending edit the day bloc holds is flushed immediately whenever the right dock changes
/// tab, a version is previewed, an export is asked for, and (through [flushPendingFieldEdits],
/// called by the mode's own `deactivate()`) whenever the mode leaves the widget tree, so a pending
/// edit is never silently dropped. [defaultFieldEditDebounce] is the delay it writes after.
///
/// Reading the schedule again ([reloadScopesIn]) also reconciles
/// [OcptScheduleState.selectedDayId]/[OcptScheduleState.selectedBlockId] against the freshly
/// loaded snapshot (a selection whose row disappeared is dropped rather than trusted to still mean
/// something) and, while the `Versions` tab is open, asks [MixinOcptProjectVersionsBloc] for a
/// fresh working-copy capture — the mode's own stand-in for "a save landing while it is open",
/// since nothing here is a single save.
///
/// It mixes in [MixinOcptProjectVersionsBloc], answering its two hooks through
/// [flushPendingProjectWrites] and [reloadFromProjectDatabase] (the entry read, [_load]),
/// and [MixinOcptProjectPackageBloc] too, which writes the whole project out as a portable package
/// from the `Export` panel's own standing card. That mixin reuses [flushPendingProjectWrites] —
/// what a colleague receives is the project *file*, so a debounced edit has to reach it first — and
/// asks [exportManager] where to write.
///
/// The two dock fractions and the last right dock tab are persisted through
/// [_propertiesManager]'s `scheduleLeftDockFraction`/`scheduleRightDockFraction`/
/// `scheduleLastRightDockTab`, mirroring `OcptBreakdownBloc` exactly.
class OcptScheduleBloc extends BlocForMixin<OcptScheduleState>
    with
        MixinAsyncInitBloc<OcptScheduleState>,
        MixinOcptProjectVersionsBloc<OcptScheduleState>,
        MixinOcptProjectPackageBloc<OcptScheduleState>,
        MixinOcptModeBloc<OcptScheduleState, OcptScheduleReloadScope> {
  /// The default delay between the last field edit and its autosave write, for the view blocs.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions and last right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager the three PDF exports (the two call sheet kinds and the shooting plan) go through.
  final OcptExportManager _exportManager;

  /// The service used to read and write the shooting schedule.
  final OcptScheduleService _scheduleService;

  /// The service used to read the shot list (unplaced shots, and every placed block's own shot)
  /// and to write a shot's status.
  final OcptShotListService _shotListService;

  /// The service used to read locations and their sets.
  final OcptLocationsService _locationsService;

  /// The service used to read the cast, reconciled against the project's episodes.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read the address book.
  final OcptPeopleService _peopleService;

  /// The service used to read the elements catalogue — what a named call sheet's own "to bring"
  /// section is joined from.
  final OcptElementsService _elementsService;

  /// The service used to read the people seen for each part — what an audition block and a
  /// candidate's own convocation are resolved through on a day that does not shoot.
  final OcptRoleCandidatesService _roleCandidatesService;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// {@macro open_cine_prod_tools.modeBlocConstructor}
  OcptScheduleBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptScheduleService? scheduleService,
    OcptShotListService? shotListService,
    OcptLocationsService? locationsService,
    OcptRoleIndexService? roleIndexService,
    OcptPeopleService? peopleService,
    OcptElementsService? elementsService,
    OcptRoleCandidatesService? roleCandidatesService,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
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
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       _roleCandidatesService =
           roleCandidatesService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleCandidatesService,
       super(OcptScheduleState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
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
    on<OcptScheduleAgendaColorModeSelectedEvent>(_onAgendaColorModeSelected);
    on<OcptScheduleAgendaAnchorDateChangedEvent>(_onAgendaAnchorDateChanged);
    on<OcptScheduleDayCreatedEvent>(_onDayCreated);
    on<OcptScheduleDayDateChangedEvent>(_onDayDateChanged);
    on<OcptScheduleDayStatusChangedEvent>(_onDayStatusChanged);
    on<OcptScheduleDayDuplicationRequestedEvent>(_onDayDuplicationRequested);
    on<OcptScheduleDayDeletionConfirmedEvent>(_onDayDeletionConfirmed);
    on<OcptScheduleShotSelectedEvent>(_onShotSelected);
    on<OcptScheduleProjectSettingsChangedEvent>(_onProjectSettingsChanged);
  }

  /// Write whatever free-text field edit is still sitting in the field-edit debounce, so a preview
  /// about to swap the database can't send it into the previewed version instead, then clear the
  /// selected shot: a shot selected out of the working copy's own shot list means nothing once a
  /// preview swaps that data out.
  ///
  /// Answers false when a typed edit could not be written: the preview, the restore, the saved
  /// version or the package then does not happen, and the edit stays pending, rather than being
  /// swept away by the data the action replaces.
  @protected
  @override
  Future<bool> flushPendingProjectWrites(Emitter<OcptScheduleState> emitter) async {
    if (!await _flushAllPendingWrites(emitter)) {
      return false;
    }

    emitter(state.copyWithShotCleared());
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  ///
  /// False when a typed edit could not be written, for the reason [flushPendingProjectWrites]
  /// gives: an export would print the value the database still holds and report success.
  @protected
  @override
  Future<bool> flushAllPendingWritesIn(Emitter<OcptScheduleState> emitter) =>
      _flushAllPendingWrites(emitter);

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.reloadScopesIn}
  ///
  /// Reading the schedule also reconciles the selection against what was read: a selected day or
  /// block that disappeared (deleted, or a block whose slot was) is dropped rather than trusted to
  /// still mean something. While the `Versions` tab is the one open, the working-copy card is
  /// refreshed once the data has landed: every write a view makes ends in a reload, which makes it
  /// the mode's stand-in for "a save landing while the tab is open", since nothing here is a
  /// single save.
  @protected
  @override
  Future<bool> reloadScopesIn(
    Set<OcptScheduleReloadScope> scopes,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return false;
    }

    OcptScheduleSnapshot? snapshot;
    ({List<OcptEpisode> episodes, List<OcptShotListSnapshot> shotLists})? shotLists;

    // A switch statement over an enum must name every value: a scope added to the enum does not
    // compile until it is read here.
    for (final scope in scopes) {
      switch (scope) {
        case OcptScheduleReloadScope.schedule:
          final read = await _loadScheduleSnapshot(project);
          if (read.isError) {
            return false;
          }

          snapshot = read.value;
        case OcptScheduleReloadScope.shotLists:
          final read = await _loadShotLists(project);
          if (read.isError) {
            return false;
          }

          shotLists = read.value;
      }
    }

    final selectedDayId = state.selectedDayId;
    final selectedBlockId = state.selectedBlockId;
    final isDayDropped =
        snapshot != null && selectedDayId != null && !snapshot.daysById.containsKey(selectedDayId);
    final isBlockDropped =
        snapshot != null &&
        selectedBlockId != null &&
        (isDayDropped ||
            !(snapshot.blocksByDayId[selectedDayId] ?? const []).any(
              (block) => block.id == selectedBlockId,
            ));

    emitter(
      state.copyWithReloadedSchedule(
        snapshot: snapshot,
        shotListSnapshots: shotLists?.shotLists,
        episodes: shotLists?.episodes,
        isDayDropped: isDayDropped,
        isBlockDropped: isBlockDropped,
      ),
    );

    _requestWorkingCopyRefreshIfVersionsOpen();
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<bool> reloadFromProjectDatabase(Emitter<OcptScheduleState> emitter) => _load(emitter);

  /// {@macro act_flutter_utility.MixinAsyncInitBloc.initAsyncBloc}
  ///
  /// Loads the mode for the first time, see [_load]; adding an [AsyncInitEvent] again loads it
  /// again.
  @protected
  @override
  Future<void> initAsyncBloc({required Emitter<OcptScheduleState> emit}) async {
    await super.initAsyncBloc(emit: emit);
    final _ = await _load(emit);
  }

  /// Write every pending edit of the views directly to the database, without touching [state].
  ///
  /// Called by the mode's own `deactivate()`, mirroring `OcptBreakdownBloc.flushPendingFieldEdits`:
  /// `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
  /// this whole subtree out, and so does the workspace's own back navigation), so triggering the
  /// write here — rather than dispatching an event, which would only be processed on a later
  /// microtask this widget might not survive to see — is what guarantees the last
  /// [defaultFieldEditDebounce] worth of typing isn't lost.
  Future<void> flushPendingFieldEdits() => runPendingWritesFlushersWithoutState();

  /// Load the current project's whole schedule read: the schedule itself, the shot list and the
  /// three resources catalogues.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the read it just performed (see that hook's own
  /// doc comment). The selected block, the selected shot and any pending field edit are always
  /// cleared on a (re)load: a preview or a restore changes the whole database underneath, so a
  /// stale one is dropped rather than trusted to still mean the same thing. The selected **day**
  /// is dropped for the same reason and then chosen afresh out of what was just read, by
  /// [_defaultSelectedDayOf] — never carried over.
  ///
  /// Answers false when the schedule, the shot lists, the locations, the casting (the roles, the
  /// people, the elements and the candidacies), the page format or the minimum rest could not be
  /// read, in which case nothing is emitted and the caller stops there.
  @useResult
  Future<bool> _load(Emitter<OcptScheduleState> emitter) async {
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
        state.copyToLoadedWithoutProject(
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
          firstWeekday: firstWeekday,
        ),
      );
      return true;
    }

    // Queued with the views' reloads: a read made here but emitted after a newer one would put
    // older data over it.
    return runSerially(() async {
      final previewedVersion = project.previewedVersion;
      final scheduleRead = await _loadScheduleSnapshot(project);
      if (scheduleRead.isError) {
        return false;
      }

      final snapshot = scheduleRead.value!;
      final shotListsRead = await _loadShotLists(project);
      if (shotListsRead.isError) {
        return false;
      }

      final shotLists = shotListsRead.value!;
      final locationsRead = await _locationsService.loadLocations(database: project.database);
      if (locationsRead.isError) {
        return false;
      }

      final locations = locationsRead.value!;
      final rolesRead = await _roleIndexService.loadRoles(database: project.database);
      if (rolesRead.isError) {
        return false;
      }

      final roles = rolesRead.value!;
      final peopleRead = await _peopleService.loadPeople(database: project.database);
      if (peopleRead.isError) {
        return false;
      }

      final people = peopleRead.value!;
      final elementsRead = await _elementsService.loadElements(database: project.database);
      if (elementsRead.isError) {
        return false;
      }

      final elements = elementsRead.value!;
      // Read after the address book, and out of it: a candidacy travels with the person it names,
      // and resolving one twice is how two readings of the same casting come to disagree.
      final roleCandidatesRead = await _loadRoleCandidates(project, people: people);
      if (roleCandidatesRead.isError) {
        return false;
      }

      final roleCandidates = roleCandidatesRead.value!;
      final pageSetupRead = await ocptLoadPageSetup(
        project: project,
        projectsManager: _projectsManager,
        propertiesManager: _propertiesManager,
      );
      if (pageSetupRead.isError) {
        return false;
      }

      final pageSetup = pageSetupRead.value!;
      final minimumRestRead = await _projectsManager.loadCurrentProjectMinimumRestMinutes();
      if (minimumRestRead.isError) {
        return false;
      }

      final minimumRestMinutes = minimumRestRead.value;

      final defaultDay = _defaultSelectedDayOf(snapshot.days);

      emitter(
        state.copyToLoaded(
          title: project.name,
          previewedVersion: previewedVersion,
          snapshot: snapshot,
          shotListSnapshots: shotLists.shotLists,
          episodes: shotLists.episodes,
          locations: locations,
          roles: roles,
          people: people,
          elements: elements,
          roleCandidates: roleCandidates,
          pageSetup: pageSetup,
          minimumRestMinutes: minimumRestMinutes,
          agendaAnchorDate: defaultDay?.date ?? DateTime.now(),
          defaultDayId: defaultDay?.id,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          lastRightDockTab: lastRightDockTab,
          firstWeekday: firstWeekday,
        ),
      );
      return true;
    });
  }

  /// Get the day a load lands on: the one dated today, failing that the next one still to come, and
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

  /// Read [project]'s whole schedule.
  @useResult
  Future<OcptDatabaseResult<OcptScheduleSnapshot>> _loadScheduleSnapshot(
    OcptOpenProjectModel project,
  ) => _scheduleService.loadSchedule(database: project.database);

  /// Read every live candidacy of [project], flattened out of the per-role map the service
  /// answers with: this mode never asks "who was seen for this part" — it asks "who is this
  /// convocation for", one candidacy at a time, which the state's own map answers.
  ///
  /// [people] is the address book this very load has already read, handed straight back in rather
  /// than read a second time.
  @useResult
  Future<OcptDatabaseResult<List<OcptRoleCandidate>>> _loadRoleCandidates(
    OcptOpenProjectModel project, {
    required List<OcptPerson> people,
  }) async {
    final candidatesRead = await _roleCandidatesService.loadCandidatesByRoleId(
      database: project.database,
      people: people,
    );
    if (candidatesRead.isError) {
      return OcptDatabaseResult<List<OcptRoleCandidate>>(
        status: candidatesRead.status,
        extraInfo: candidatesRead.extraInfo,
      );
    }

    return OcptDatabaseResult<List<OcptRoleCandidate>>(
      status: OcptDatabaseStatus.ok,
      value: [for (final candidates in candidatesRead.value!.values) ...candidates],
    );
  }

  /// Read every live episode's own whole shot list, in the same order — the schedule reading
  /// across the whole project rather than one screenplay (`docs/adr/0019`): a shooting day belongs
  /// to no episode, and regularly places shots of more than one.
  ///
  /// This bloc reads the project's live episodes through [_projectsManager]'s own
  /// `screenplayService` (never through [_shotListService], which `OcptScreenplayService` already
  /// depends on) and resolves each episode's own number with `ocptEpisodePrefixNumberOf`, null on a
  /// single-episode project, so every shot list's own scene numbers are prefixed exactly as
  /// `OcptShotListBloc`'s own single-episode read prefixes its one.
  ///
  /// Returns the episodes alongside their shot lists rather than the shot lists alone: every caller
  /// (the initial load and [reloadScopesIn]) puts both into
  /// [OcptScheduleState.episodes]/[OcptScheduleState.shotListSnapshots] in one write, and a second
  /// read of [_projectsManager]'s own `screenplayService` right after this one returned would risk
  /// disagreeing with it if an episode was renamed or reordered in between.
  ///
  /// Answers the failure of the episodes, or of the first shot list that could not be read, in
  /// place of the episodes and their shot lists.
  @useResult
  Future<OcptDatabaseResult<({List<OcptEpisode> episodes, List<OcptShotListSnapshot> shotLists})>>
  _loadShotLists(OcptOpenProjectModel project) async {
    final database = project.database;
    final episodesRead = await _projectsManager.screenplayService.loadEpisodes(database: database);
    if (episodesRead.isError) {
      return OcptDatabaseResult(status: episodesRead.status, extraInfo: episodesRead.extraInfo);
    }

    final episodes = episodesRead.value!;
    final shotLists = <OcptShotListSnapshot>[];
    for (final episode in episodes) {
      final shotListRead = await _shotListService.loadShotList(
        database: database,
        screenplayId: episode.id,
        episodeNumber: ocptEpisodePrefixNumberOf(episodes: episodes, screenplayId: episode.id),
      );
      if (shotListRead.isError) {
        return OcptDatabaseResult(status: shotListRead.status, extraInfo: shotListRead.extraInfo);
      }

      shotLists.add(shotListRead.value!);
    }

    return OcptDatabaseResult(
      status: OcptDatabaseStatus.ok,
      value: (episodes: episodes, shotLists: shotLists),
    );
  }

  /// Leave the workspace: flushes any pending field edit, closes the current project, and
  /// navigates back to the home page.
  Future<void> _onBackRequested(
    OcptScheduleBackRequestedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final _ = await _flushAllPendingWrites(emitter);
    final closed = await _projectsManager.closeCurrentProject();
    if (closed.isError) {
      return;
    }

    _routerManager.pop();
  }

  /// Toggle the left (days) dock's visibility.
  Future<void> _onLeftPanelToggled(
    OcptScheduleLeftPanelToggledEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWithListPanelToggled());
  }

  /// Select a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it). Flushes any pending field edit first, mirroring every other mode.
  Future<void> _onRightDockTabSelected(
    OcptScheduleRightDockTabSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    if (!await _flushAllPendingWrites(emitter)) {
      return;
    }

    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);
    emitter(state.copyWithRightDockTabSelected(tab: event.tab, isAlreadyActive: isAlreadyActive));

    if (!isAlreadyActive && event.tab == OcptScheduleRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggle the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptScheduleState.lastRightDockTab].
  Future<void> _onRightDockToggled(
    OcptScheduleRightDockToggledEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWithRightDockClosed());
      return;
    }

    emitter(state.copyWithRightDockReopened());

    if (state.lastRightDockTab == OcptScheduleRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Close the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptScheduleRightDockClosedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWithRightDockClosed());
  }

  /// Apply and persist whichever dock fraction the ended drag gesture reports.
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

    emitter(state.copyWithDockFractions(left: left, right: right));
  }

  /// Restore both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptScheduleDockLayoutResetEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    await _propertiesManager.scheduleLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.scheduleRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWithDockFractions(
        left: OcptWorkspaceDock.leftDefaultFraction,
        right: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Persist [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptScheduleRightDockTab tab) async {
    if (state.lastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.scheduleLastRightDockTab.store(tab);
  }

  /// Select day [OcptScheduleDaySelectedEvent.dayId], clearing both the selected block and the
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

    emitter(state.copyWithSelectedDay(dayId: event.dayId));
  }

  /// Select block [OcptScheduleBlockSelectedEvent.blockId] and its own day, opening the right dock
  /// on the `Inspector` tab, and clear the selected shot: the two selections are mutually
  /// exclusive.
  Future<void> _onBlockSelected(
    OcptScheduleBlockSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    if (!state.daysById.containsKey(event.dayId)) {
      return;
    }

    emitter(state.copyWithSelectedBlock(dayId: event.dayId, blockId: event.blockId));
  }

  /// Select shot [OcptScheduleShotSelectedEvent.shotId], opening the right dock on the `Inspector`
  /// tab, and clear the selected block: the two selections are mutually exclusive. A shot id
  /// naming no live shot of the current shot list is ignored.
  Future<void> _onShotSelected(
    OcptScheduleShotSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    if (state.shotById(event.shotId) == null) {
      return;
    }

    emitter(state.copyWithSelectedShot(shotId: event.shotId));
  }

  /// Switch the centre between the agenda and the day view.
  Future<void> _onCentreViewSelected(
    OcptScheduleCentreViewSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWithCentreView(view: event.view));
  }

  /// Switch the agenda's own presentation.
  Future<void> _onAgendaModeSelected(
    OcptScheduleAgendaModeSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWithAgendaMode(mode: event.mode));
  }

  /// Switch what fact the agenda tints a day with.
  Future<void> _onAgendaColorModeSelected(
    OcptScheduleAgendaColorModeSelectedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWithAgendaColorMode(mode: event.mode));
  }

  /// Page the week/month agenda to a new anchor date.
  Future<void> _onAgendaAnchorDateChanged(
    OcptScheduleAgendaAnchorDateChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    emitter(state.copyWithAgendaAnchorDate(date: event.date));
  }

  /// Create a new shooting day and select it.
  Future<void> _onDayCreated(
    OcptScheduleDayCreatedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final created = await _scheduleService.createDay(database: project.database, date: event.date);
    if (created.isError) {
      return;
    }

    if (!await _applyScheduleSnapshot(emitter)) {
      return;
    }

    final dayId = created.value;
    if (dayId != null) {
      emitter(state.copyWithAddedDay(dayId: dayId));
    }
  }

  /// Write a new date onto the selected day.
  Future<void> _onDayDateChanged(
    OcptScheduleDayDateChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _scheduleService.updateDay(
      database: project.database,
      dayId: event.dayId,
      date: Value(event.date),
    );
    if (updated.isError) {
      return;
    }

    final _ = await _applyScheduleSnapshot(emitter);
  }

  /// Write a new status onto the selected day.
  Future<void> _onDayStatusChanged(
    OcptScheduleDayStatusChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _scheduleService.updateDay(
      database: project.database,
      dayId: event.dayId,
      status: Value(event.status),
    );
    if (updated.isError) {
      return;
    }

    final _ = await _applyScheduleSnapshot(emitter);
  }

  /// Duplicate a day and select the new one.
  Future<void> _onDayDuplicationRequested(
    OcptScheduleDayDuplicationRequestedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final duplicated = await _scheduleService.duplicateDay(
      database: project.database,
      sourceDayId: event.sourceDayId,
      date: event.date,
    );
    if (duplicated.isError) {
      return;
    }

    if (!await _applyScheduleSnapshot(emitter)) {
      return;
    }

    final newDayId = duplicated.value;
    if (newDayId != null) {
      emitter(state.copyWithAddedDay(dayId: newDayId));
    }
  }

  /// Delete a day for good, confirmed by the mode's own `OcptConfirmDialog`.
  Future<void> _onDayDeletionConfirmed(
    OcptScheduleDayDeletionConfirmedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final deleted = await _scheduleService.deleteDay(
      database: project.database,
      dayId: event.dayId,
    );
    if (deleted.isError) {
      return;
    }

    final _ = await _applyScheduleSnapshot(emitter);
  }

  /// Re-read the schedule and apply it, reconciling the selected day and block against what the
  /// fresh snapshot still holds (see [reloadScopesIn]).
  ///
  /// Every handler that writes to the schedule tables ends here.
  ///
  /// Answers false when the read failed, so that a handler with something left to do after it
  /// stops there. With no project open when it is called nothing is read and nothing fails: that
  /// answers true, whatever happens to the project meanwhile.
  @useResult
  Future<bool> _applyScheduleSnapshot(Emitter<OcptScheduleState> emitter) async {
    final hasProject = _projectsManager.currentProject != null;
    final isRead = await reloadSerially({OcptScheduleReloadScope.schedule}, emitter);

    return isRead || !hasProject;
  }

  /// Write every pending write of the mode's views immediately, through the flushers they
  /// registered. A view that wrote reads the schedule again itself, which also refreshes the
  /// `Versions` tab's working-copy card if it is the one showing.
  ///
  /// Up front of every handler that is about to read the database (an export, a preview) or that
  /// changes the right dock's tab: a pending edit is never silently dropped by one of them. Answers
  /// whether every view wrote what it held, and a handler that gets false stops: the edit is still
  /// pending, and going on would show, print or replace the data without it. Moving
  /// the selected day, block or shot and switching the centre view do **not** flush: an edit typed
  /// before them is written by its own debounce, whichever day is showing by then. Going back
  /// flushes too, but leaves whatever the answer.
  @useResult
  Future<bool> _flushAllPendingWrites(Emitter<OcptScheduleState> emitter) async {
    final run = await runPendingWritesFlushers();
    return !run.hasFailed;
  }

  /// Dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] while the `Versions` tab is the one
  /// currently open — see the class doc comment for why every write here counts as "a save landing
  /// while it is open".
  void _requestWorkingCopyRefreshIfVersionsOpen() {
    if (state.rightDockTab == OcptScheduleRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Re-read the project's whole schedule after the project settings page changed something.
  ///
  /// The page setup and the minimum rest are the obvious two — the three export dialogs pre-fill
  /// their format dropdown from the one, and the rest-time alert reads the other, and that page is
  /// exactly where either is changed. But that page also **manages the project's episodes**, and
  /// this mode is the one that reads every one of them at once: deleting an episode there
  /// tombstones its scenes, its shots and the blocks placing them, none of which the shell's own
  /// episode reload can tell this mode about — the mode is keyed on the *selected* episode
  /// (`OcptWorkspacePage._buildActiveMode`) and a mode showing no selector never sees that key
  /// change. A partial re-read would leave a deleted episode's shots on the board, so the whole
  /// read is redone, exactly as [reloadFromProjectDatabase] redoes it.
  ///
  /// The cost is the one [_load] always carries and states: the selected day is chosen
  /// afresh, and the selected block and shot are dropped. Coming back from a page reached through
  /// the toolbar is a deliberate detour, and a selection kept over a database that may have lost
  /// rows underneath it is worth less than one that is certainly true.
  Future<void> _onProjectSettingsChanged(
    OcptScheduleProjectSettingsChangedEvent event,
    Emitter<OcptScheduleState> emitter,
  ) async {
    final _ = await _load(emitter);
  }
}
