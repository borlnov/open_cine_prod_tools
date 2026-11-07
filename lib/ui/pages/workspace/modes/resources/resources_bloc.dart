// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_candidates_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_page_setup_loading.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the resources production mode (the address book, the cast, locations
/// and the physical elements catalogue): its **mode bloc**.
///
/// It loads the current project's whole catalogue from [_peopleService], [_roleIndexService],
/// [_roleCandidatesService], [_locationsService] and [_elementsService] on entry, combining the
/// reads into one [OcptResourcesSnapshot] — the same "one read of everything, joined in memory"
/// shape `OcptShotListBloc` builds its own snapshot with — and owns that data, the active tab, the
/// selected person, role, location and element, the search, the dock geometry and the transient
/// write error. [OcptResourcesState.mileageRates] and [OcptResourcesState.setIdsWithPlan] are read
/// once on every load alongside it: the mileage rates belong to the project settings page's own
/// catalogue, and this mode only ever reads them.
///
/// Everything a tab's sheet writes belongs to that tab's view bloc — `OcptResourcesPeopleBloc`,
/// `OcptResourcesRolesBloc`, `OcptResourcesLocationsBloc` and `OcptResourcesElementsBloc` — which
/// writes through the services, asks this bloc to read the snapshot again ([reload]) and keeps the
/// typed edits of its sheets in a debounce of its own; `OcptResourcesExportBloc` owns the two
/// exports. A view moves the selection through [OcptResourcesRecordCreatedEvent] and
/// [OcptResourcesRecordDroppedEvent], and shows a failed write through
/// [OcptResourcesWriteFailedEvent]: the one write error is this bloc's, so it is shown once
/// whichever view it came from.
///
/// Every pending edit the views hold is flushed immediately whenever the selected record, or the
/// active tab, changes, when the workspace is left, ahead of a version preview or a package export,
/// and (through [flushPendingFieldEdits], called by the mode's own `deactivate()`) whenever the
/// mode leaves the widget tree for any other reason, so a pending edit is never silently dropped. A
/// flush that fails drops the edits of every view, shows the one write error and lets the action go
/// ahead on the value the database still holds ([OcptResourcesPendingEditsLostEvent]).
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does. The two hooks the mixin needs are answered by [flushPendingProjectWrites]
/// and [reloadFromProjectDatabase]. Opening the `Versions` tab and a field edit landing while it is
/// already open dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] — the two moments the
/// mixin's working-copy card is worth a fresh, throttled read.
///
/// It mixes in [MixinOcptProjectPackageBloc] too, which writes the whole project out as a portable
/// package from the `Export` panel's own standing card. That mixin reuses
/// [flushPendingProjectWrites] — what a colleague receives is the project *file*, so a debounced
/// edit has to reach it first — and asks [exportManager] where to write, exactly as the mode's
/// own exports (`OcptResourcesExportBloc`) do.
class OcptResourcesBloc extends BlocForMixin<OcptResourcesState>
    with
        MixinAsyncInitBloc<OcptResourcesState>,
        MixinOcptProjectVersionsBloc<OcptResourcesState>,
        MixinOcptProjectPackageBloc<OcptResourcesState>,
        MixinOcptModeBloc<OcptResourcesState, OcptResourcesReloadScope> {
  /// The default delay between the last field edit and its autosave write, for the view blocs.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The logger category linked to this BLoC.
  static const _loggerCategory = "resources_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager the project package export asks where to write (the catalogue's own exports are
  /// `OcptResourcesExportBloc`'s).
  final OcptExportManager _exportManager;

  /// The service used to read and write the address book.
  final OcptPeopleService _peopleService;

  /// The service used to read the cast, reconciled against the project's episodes.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read, and write, the people seen for each role.
  final OcptRoleCandidatesService _roleCandidatesService;

  /// The service used to read locations and their sets.
  final OcptLocationsService _locationsService;

  /// The service used to read the physical elements catalogue.
  final OcptElementsService _elementsService;

  /// The episode this bloc reads and writes, handed down by `OcptResourcesMode` from
  /// `OcptWorkspaceBloc.state.selectedEpisodeId` at construction time — safe to capture once rather
  /// than watch, since `OcptWorkspacePage` remounts this whole bloc on every episode switch (see
  /// `OcptWorkspacePage._buildActiveMode`'s own doc comment), so the field can never go stale.
  ///
  /// Null only for a project holding no episode at all: `OcptWorkspaceBloc` lands on the first one
  /// before it clears `isLoading`, and a mode is never built before that, so [screenplayIdOf]'s
  /// fallback to [OcptOpenProjectModel.primaryScreenplayId] is the honest last resort rather than a
  /// routine path.
  ///
  /// Only [_loadSnapshot]'s own scene numbering and a hand-added role's own episode link
  /// (`OcptResourcesRolesBloc`, through [screenplayIdOf]) read it: every other read here — the
  /// people, the locations, the elements — is already the production's, not one screenplay's.
  final String? _selectedEpisodeId;

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// {@macro open_cine_prod_tools.modeBlocConstructor}
  OcptResourcesBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptExportManager? exportManager,
    OcptPeopleService? peopleService,
    OcptRoleIndexService? roleIndexService,
    OcptRoleCandidatesService? roleCandidatesService,
    OcptLocationsService? locationsService,
    OcptElementsService? elementsService,
    OcptResourcesRevealRequest? revealRequest,
    String? selectedEpisodeId,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _selectedEpisodeId = selectedEpisodeId,
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _peopleService =
           peopleService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).peopleService,
       _roleIndexService =
           roleIndexService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleIndexService,
       _roleCandidatesService =
           roleCandidatesService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).roleCandidatesService,
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       super(OcptResourcesState.init(revealRequest: revealRequest));

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptResourcesBackRequestedEvent>(_onBackRequested);
    on<OcptResourcesProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptResourcesTabSelectedEvent>(_onTabSelected);
    on<OcptResourcesPersonSelectedEvent>(_onPersonSelected);
    on<OcptResourcesWriteFailedEvent>(_onWriteFailed);
    onAwaited<OcptResourcesPendingEditsLostEvent>(_onPendingEditsLost);
    onAwaited<OcptResourcesRecordCreatedEvent>(_onRecordCreated);
    onAwaited<OcptResourcesRecordDroppedEvent>(_onRecordDropped);
    on<OcptResourcesRoleSelectedEvent>(_onRoleSelected);
    on<OcptResourcesPersonSheetOpenRequestedEvent>(_onPersonSheetOpenRequested);
    on<OcptResourcesLocationSelectedEvent>(_onLocationSelected);
    on<OcptResourcesOpenSetInShotListRequestedEvent>(_onOpenSetInShotListRequested);
    on<OcptResourcesShotListRevealDismissedEvent>(_onShotListRevealDismissed);
    on<OcptResourcesElementSelectedEvent>(_onElementSelected);
    on<OcptResourcesRoleSheetOpenRequestedEvent>(_onRoleSheetOpenRequested);
    on<OcptResourcesLeftPanelToggledEvent>(_onLeftPanelToggled);
    on<OcptResourcesSearchToggledEvent>(_onSearchToggled);
    on<OcptResourcesSearchQueryChangedEvent>(_onSearchQueryChanged);
    on<OcptResourcesRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptResourcesRightDockToggledEvent>(_onRightDockToggled);
    on<OcptResourcesRightDockClosedEvent>(_onRightDockClosed);
    on<OcptResourcesDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptResourcesDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptResourcesWriteErrorDismissedEvent>(_onWriteErrorDismissed);
  }

  /// Get the screenplay this bloc reads and writes: [_selectedEpisodeId], or [project]'s own
  /// [OcptOpenProjectModel.primaryScreenplayId] on the one path that can reach here with none
  /// selected (see [_selectedEpisodeId]'s own doc comment).
  String screenplayIdOf(OcptOpenProjectModel project) =>
      _selectedEpisodeId ?? project.primaryScreenplayId;

  /// Write whatever field edit is still sitting in the field-edit debounce, so a preview about to
  /// swap the database can't send it into the previewed version instead.
  @protected
  @override
  Future<bool> flushPendingProjectWrites(Emitter<OcptResourcesState> emitter) async {
    await runPendingWritesFlushers();
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  ///
  /// Always true, for the reason [flushPendingProjectWrites] gives: a write that fails is shown by
  /// the mode itself (its transient write error), the edits that could not be written are dropped,
  /// and the action goes ahead on the value the database still holds.
  @protected
  @override
  Future<bool> flushAllPendingWritesIn(Emitter<OcptResourcesState> emitter) async {
    await runPendingWritesFlushers();
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.reloadScopesIn}
  ///
  /// A failed read raises the transient write error, like a failed write: the view that asked has
  /// already written its row, and what is on screen no longer says what the database holds.
  @protected
  @override
  Future<bool> reloadScopesIn(
    Set<OcptResourcesReloadScope> scopes,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return false;
    }

    var isReloaded = false;
    var hasFailed = false;
    try {
      OcptResourcesSnapshot? snapshot;

      // A switch statement over an enum must name every value: a scope added to the enum does not
      // compile until it is read here.
      for (final scope in scopes) {
        switch (scope) {
          case OcptResourcesReloadScope.snapshot:
            final read = await _loadSnapshot(project);
            if (read.isError) {
              hasFailed = true;
            } else {
              snapshot = read.value;
            }
        }
      }

      if (!hasFailed) {
        emitter(state.copyWithReloadedSnapshot(snapshot: snapshot));
        isReloaded = true;
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to read again the $scopes of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      hasFailed = true;
    }

    if (hasFailed) {
      emitter(state.copyWithWriteError());
    }

    return isReloaded;
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<bool> reloadFromProjectDatabase(Emitter<OcptResourcesState> emitter) => _load(emitter);

  /// {@macro act_flutter_utility.MixinAsyncInitBloc.initAsyncBloc}
  @protected
  @override
  Future<void> initAsyncBloc({required Emitter<OcptResourcesState> emit}) async {
    await super.initAsyncBloc(emit: emit);
    final _ = await _load(emit);
  }

  /// Write every pending edit of the views directly to the database, without touching [state].
  ///
  /// Called by the mode's own `deactivate()`, mirroring `OcptShotListBloc.flushPendingFieldEdits`:
  /// `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
  /// this whole subtree out, and so does the workspace's own back navigation), so triggering the
  /// write here — rather than dispatching an event, which would only be processed on a later
  /// microtask this widget might not survive to see — is what guarantees the last
  /// [defaultFieldEditDebounce] worth of typing isn't lost.
  Future<void> flushPendingFieldEdits() => runPendingWritesFlushersWithoutState();

  /// Load the persisted dock fractions and the current project's whole resources catalogue.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the catalogue it just read: what it read comes
  /// from that very version's in-memory database, and the two must reach the mode together (see
  /// the hook's own doc comment). The selected person and the selected role are always cleared on a
  /// (re)load, and so are the selected location and element, mirroring `OcptShotListBloc`'s own
  /// selection reset: a preview or a restore changes the whole database underneath, so a stale
  /// selection is dropped rather than trusted to still mean the same thing.
  ///
  /// Answers false when the catalogue, the currency, the page format, the mileage rates or the sets
  /// with a floor plan could not be read, in which case nothing is emitted and the caller stops
  /// there.
  @useResult
  Future<bool> _load(Emitter<OcptResourcesState> emitter) async {
    final leftDockFraction =
        await _propertiesManager.resourcesLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.resourcesRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyToLoadedWithoutProject(
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
        ),
      );
      return true;
    }

    // Queued with the views' reloads: a read made here but emitted after a newer one would put
    // older data over it.
    return runSerially(() async {
      final previewedVersion = project.previewedVersion;
      final snapshotRead = await _loadSnapshot(project);
      if (snapshotRead.isError) {
        return false;
      }

      final snapshot = snapshotRead.value!;
      final currencyRead = await _projectsManager.loadCurrentProjectCurrencyCode();
      if (currencyRead.isError) {
        return false;
      }

      final currencyCode = currencyRead.value;
      final pageSetupRead = await ocptLoadPageSetup(
        project: project,
        projectsManager: _projectsManager,
        propertiesManager: _propertiesManager,
      );
      if (pageSetupRead.isError) {
        return false;
      }

      final pageSetup = pageSetupRead.value!;
      final mileageRatesRead = await _projectsManager.budgetFinancingService.loadMileageRates(
        database: project.database,
      );
      if (mileageRatesRead.isError) {
        return false;
      }

      final mileageRates = mileageRatesRead.value!;
      final setIdsWithPlanRead = await _locationsService.floorPlanService.liveSetIdsWithPlan(
        database: project.database,
        setIds: [
          for (final location in snapshot.locations)
            for (final set in location.sets) set.id,
        ],
      );
      if (setIdsWithPlanRead.isError) {
        return false;
      }

      final setIdsWithPlan = setIdsWithPlanRead.value!;

      final revealRequest = state.pendingRevealRequest;

      emitter(
        _revealed(
          state.copyToLoaded(
            title: project.name,
            currencyCode: currencyCode ?? ocptDefaultCurrencyCode,
            previewedVersionId: previewedVersion?.id,
            snapshot: snapshot,
            pageSetup: pageSetup,
            mileageRates: mileageRates,
            setIdsWithPlan: setIdsWithPlan,
            leftDockFraction: leftDockFraction,
            rightDockFraction: rightDockFraction,
          ),
          revealRequest,
        ),
      );
      return true;
    });
  }

  /// Get [loaded] with [revealRequest]'s own tab active and its record selected, or [loaded]
  /// untouched
  /// while there is no request — the ordinary case.
  ///
  /// Applied to the loaded state rather than emitted after it: the load clears all four selections,
  /// so a selection landing beside it rather than inside it would be racing the very handler that
  /// wipes it.
  ///
  /// A request naming no record, or one that isn't in the catalogue it was looked for in, only
  /// selects the tab. That is the truthful reading of a request naming a row tombstoned since it
  /// was built — the mode has a tab to show, and no sheet to show on it — and it is why this reads
  /// the loaded snapshot rather than trusting the id.
  OcptResourcesState _revealed(
    OcptResourcesState loaded,
    OcptResourcesRevealRequest? revealRequest,
  ) {
    if (revealRequest == null) {
      return loaded;
    }

    final tabbed = loaded.copyWithRevealedTab(tab: revealRequest.tab);
    final recordId = revealRequest.recordId;
    final snapshot = loaded.snapshot;
    if (recordId == null || snapshot == null) {
      return tabbed;
    }

    return switch (revealRequest.tab) {
      OcptResourcesTab.people =>
        snapshot.people.any((person) => person.id == recordId)
            ? tabbed.copyWithRevealedPerson(personId: recordId)
            : tabbed,
      OcptResourcesTab.roles =>
        snapshot.roles.any((role) => role.id == recordId)
            ? tabbed.copyWithRevealedRole(roleId: recordId)
            : tabbed,
      OcptResourcesTab.locations =>
        snapshot.locations.any((location) => location.id == recordId)
            ? tabbed.copyWithRevealedLocation(locationId: recordId)
            : tabbed,
      OcptResourcesTab.elements =>
        snapshot.elements.any((element) => element.id == recordId)
            ? tabbed.copyWithRevealedElement(elementId: recordId)
            : tabbed,
    };
  }

  /// Read the whole resources catalogue of [project], joining the four services' own reads into
  /// one [OcptResourcesSnapshot].
  ///
  /// The scenes are numbered with their episode's own prefix: this bloc reads the project's live
  /// episodes through [_projectsManager]'s own `screenplayService` (never through
  /// [_locationsService], which `OcptScreenplayService` already depends on) and resolves the
  /// selected episode's number with `ocptEpisodePrefixNumberOf`, null on a single-episode project.
  @useResult
  Future<OcptDatabaseResult<OcptResourcesSnapshot>> _loadSnapshot(
    OcptOpenProjectModel project,
  ) async {
    final database = project.database;
    final screenplayId = screenplayIdOf(project);

    final peopleRead = await _peopleService.loadPeople(database: database);
    if (peopleRead.isError) {
      return OcptDatabaseResult<OcptResourcesSnapshot>(
        status: peopleRead.status,
        extraInfo: peopleRead.extraInfo,
      );
    }

    final people = peopleRead.value!;
    final rolesRead = await _roleIndexService.loadRoles(database: database);
    if (rolesRead.isError) {
      return OcptDatabaseResult<OcptResourcesSnapshot>(
        status: rolesRead.status,
        extraInfo: rolesRead.extraInfo,
      );
    }

    final roles = rolesRead.value!;
    final locationsRead = await _locationsService.loadLocations(database: database);
    if (locationsRead.isError) {
      return OcptDatabaseResult<OcptResourcesSnapshot>(
        status: locationsRead.status,
        extraInfo: locationsRead.extraInfo,
      );
    }

    final locations = locationsRead.value!;
    final elementsRead = await _elementsService.loadElements(database: database);
    if (elementsRead.isError) {
      return OcptDatabaseResult<OcptResourcesSnapshot>(
        status: elementsRead.status,
        extraInfo: elementsRead.extraInfo,
      );
    }

    final elements = elementsRead.value!;
    final candidatesRead = await _roleCandidatesService.loadCandidatesByRoleId(
      database: database,
      people: people,
    );
    if (candidatesRead.isError) {
      return OcptDatabaseResult<OcptResourcesSnapshot>(
        status: candidatesRead.status,
        extraInfo: candidatesRead.extraInfo,
      );
    }

    final candidatesByRoleId = candidatesRead.value!;
    final episodesRead = await _projectsManager.screenplayService.loadEpisodes(database: database);
    if (episodesRead.isError) {
      return OcptDatabaseResult<OcptResourcesSnapshot>(
        status: episodesRead.status,
        extraInfo: episodesRead.extraInfo,
      );
    }

    final scenesRead = await _locationsService.loadScenes(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: ocptEpisodePrefixNumberOf(
        episodes: episodesRead.value!,
        screenplayId: screenplayId,
      ),
    );
    if (scenesRead.isError) {
      return OcptDatabaseResult<OcptResourcesSnapshot>(
        status: scenesRead.status,
        extraInfo: scenesRead.extraInfo,
      );
    }

    final scenes = scenesRead.value!;

    return OcptDatabaseResult<OcptResourcesSnapshot>(
      status: OcptDatabaseStatus.ok,
      value: OcptResourcesSnapshot.build(
        people: people,
        roles: roles,
        locations: locations,
        elements: elements,
        candidatesByRoleId: candidatesByRoleId,
        scenes: scenes,
      ),
    );
  }

  /// Leave the workspace: flushes any pending field edit, closes the current project, and
  /// navigates back to the home page.
  Future<void> _onBackRequested(
    OcptResourcesBackRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await runPendingWritesFlushers();
    final closed = await _projectsManager.closeCurrentProject();
    if (closed.isError) {
      return;
    }

    _routerManager.pop();
  }

  /// Re-read the project's currency and reload the resources snapshot after the project
  /// settings page changed something.
  ///
  /// The currency is what the element sheet's cost field and the exported workbook's cost column
  /// both read off this state; nothing in the snapshot itself depends on it or on the page format,
  /// but reloading it here too is what keeps this mode from being the one place a change made on
  /// the project settings page is silently missed — the same reasoning that has
  /// `OcptProjectWorkingCopyRefreshRequestedEvent` refresh the working-copy card proactively rather
  /// than only on the writes this bloc already knows about.
  Future<void> _onProjectSettingsChanged(
    OcptResourcesProjectSettingsChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await runSerially(() async {
      final snapshotRead = await _loadSnapshot(project);
      if (snapshotRead.isError) {
        return;
      }

      final snapshot = snapshotRead.value!;
      final currencyRead = await _projectsManager.loadCurrentProjectCurrencyCode();
      if (currencyRead.isError) {
        return;
      }

      final currencyCode = currencyRead.value;

      emitter(
        state.copyWithReloadedProjectSettings(
          snapshot: snapshot,
          currencyCode: currencyCode ?? ocptDefaultCurrencyCode,
        ),
      );
    });
  }

  /// Select tab `event.tab`, clearing every selected record when it actually changes tab.
  ///
  /// Also clears [OcptResourcesState.searchQuery] when it actually changes tab, but leaves the
  /// search field open (`isSearchVisible` untouched): each tab searches its own kind of record —
  /// a query that found three costume elements means nothing once the roles tab is showing — so
  /// carrying it across a tab change would filter the new list against words that describe the
  /// old one.
  ///
  /// Writes every pending edit first, so switching tabs right after typing never loses it.
  Future<void> _onTabSelected(
    OcptResourcesTabSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final isSameTab = state.activeTab == event.tab;

    emitter(state.copyWithSelectedTab(tab: event.tab, isSameTab: isSameTab));
  }

  /// Select person `event.personId`.
  ///
  /// Writes every pending edit first, so switching people right after typing never loses it.
  /// A person id that no longer exists in the current snapshot (a stale click on a list rebuilt
  /// underneath) is ignored rather than selecting nothing.
  Future<void> _onPersonSelected(
    OcptResourcesPersonSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final exists = state.people.any((person) => person.id == event.personId);
    if (!exists) {
      return;
    }

    emitter(state.copyWithSelectedPerson(personId: event.personId));
  }

  /// Select role `event.roleId`, and switch to the roles tab.
  ///
  /// Writes every pending edit first, so switching roles right after typing never loses it. A role
  /// id that no longer exists in the current snapshot (a stale click on a list rebuilt underneath)
  /// is ignored rather than selecting nothing. Selecting the already-selected role is not a way of
  /// clearing the selection: the centre shows the role's sheet, and a click on a list row blanking
  /// it would be a surprising affordance.
  Future<void> _onRoleSelected(
    OcptResourcesRoleSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final exists = state.roles.any((role) => role.id == event.roleId);
    if (!exists) {
      return;
    }

    // Always lands on the roles tab, exactly like [_onTabSelected] switching to it: this event is
    // dispatched from a row of `OcptRolesList` — already there, a no-op below — and, from the
    // compact role banner, from any tab at all, which is the case this actually has to answer.
    // Clears the search query the same way a genuine tab switch does, so a query left over from
    // another tab's list can never keep filtering the roles tab it lands on.
    final isAlreadyOnRolesTab = state.activeTab == OcptResourcesTab.roles;

    emitter(
      state.copyWithSelectedRole(roleId: event.roleId, isAlreadyOnRolesTab: isAlreadyOnRolesTab),
    );
  }

  /// Open person `event.personId`'s sheet from the role sheet's `↗` affordance: flushes any
  /// pending field edit, then switches the left dock to [OcptResourcesTab.people] and selects
  /// `event.personId`, in one state.
  ///
  /// Deliberately does **not** go through [_onTabSelected] (which clears the selection on every tab
  /// change): the person this event was asked to select would be deselected again in the very same
  /// frame if it did.
  Future<void> _onPersonSheetOpenRequested(
    OcptResourcesPersonSheetOpenRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await runPendingWritesFlushers();

    emitter(state.copyWithOpenedPersonSheet(personId: event.personId));
  }

  /// Select location `event.locationId`.
  ///
  /// Flushes any pending field edit first, so switching locations right after typing never loses
  /// it. A location id that no longer exists in the current snapshot (a stale click on a list
  /// rebuilt underneath) is ignored rather than selecting nothing, mirroring [_onPersonSelected].
  Future<void> _onLocationSelected(
    OcptResourcesLocationSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final exists = state.locations.any((location) => location.id == event.locationId);
    if (!exists) {
      return;
    }

    emitter(state.copyWithSelectedLocation(locationId: event.locationId));
  }

  /// Resolve set `event.setId`'s own first linked sequence, in screenplay order
  /// (`OcptLocationsService.firstLinkedSceneOf`), and set it as the pending cross-mode reveal the
  /// mode's own listener reads next — the sets card's own `Open in shot list` action. A no-op
  /// while the set carries no live link at all
  /// (defensive only: the card never offers the action then).
  Future<void> _onOpenSetInShotListRequested(
    OcptResourcesOpenSetInShotListRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final linkedRead = await _locationsService.firstLinkedSceneOf(
      database: project.database,
      setId: event.setId,
    );
    if (linkedRead.isError) {
      return;
    }

    final firstLinkedScene = linkedRead.value;
    if (firstLinkedScene != null) {
      emitter(
        state.copyWithShotListReveal(
          reveal: (
            episodeId: firstLinkedScene.screenplayId,
            sceneId: firstLinkedScene.sceneId,
            setId: event.setId,
          ),
        ),
      );
    }
  }

  /// Clear [OcptResourcesState.pendingShotListReveal] once the mode has dispatched the cross-mode
  /// switch it named.
  Future<void> _onShotListRevealDismissed(
    OcptResourcesShotListRevealDismissedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithShotListRevealDismissed());
  }

  /// Select element `event.elementId`.
  ///
  /// Flushes any pending field edit first, so switching elements right after typing never loses it.
  /// An element id that no longer exists in the current snapshot (a stale click on a list rebuilt
  /// underneath) is ignored rather than selecting nothing, mirroring [_onPersonSelected].
  Future<void> _onElementSelected(
    OcptResourcesElementSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await runPendingWritesFlushers();

    final exists = state.elements.any((element) => element.id == event.elementId);
    if (!exists) {
      return;
    }

    emitter(state.copyWithSelectedElement(elementId: event.elementId));
  }

  /// Switch to the roles tab and select role `event.roleId`, the element sheet's
  /// `Roles concerned` chips being the one way in.
  ///
  /// [_onPersonSheetOpenRequested]'s sibling, down to the reason it emits one state rather than
  /// dispatching a tab change: `OcptResourcesTabSelectedEvent` clears the selection, so the sheet
  /// this was asked to open would be deselected in the very same frame.
  Future<void> _onRoleSheetOpenRequested(
    OcptResourcesRoleSheetOpenRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await runPendingWritesFlushers();

    emitter(state.copyWithOpenedRoleSheet(roleId: event.roleId));
  }

  /// Toggle the left (list) dock's visibility.
  Future<void> _onLeftPanelToggled(
    OcptResourcesLeftPanelToggledEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithToggledListPanel());
  }

  /// Toggle whether the search field is shown.
  ///
  /// Opening it forces the left dock open too (`isListPanelVisible: true` regardless of what it
  /// already was) — a field in a hidden dock would be a toggle that visibly does nothing — while
  /// closing it leaves the dock exactly as the user left it. Closing it also clears
  /// [OcptResourcesState.searchQuery], so a hidden field can never keep filtering a list nobody can
  /// see any more.
  Future<void> _onSearchToggled(
    OcptResourcesSearchToggledEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithToggledSearch());
  }

  /// Record the search field's current text.
  ///
  /// This needs no debounce, unlike a sheet field's typed value (see
  /// `OcptResourcesSearchQueryChangedEvent`'s own doc comment): it writes nothing to the project
  /// database, so it is applied to the state the moment it is typed rather than after a pause.
  Future<void> _onSearchQueryChanged(
    OcptResourcesSearchQueryChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithSearchQuery(query: event.query));
  }

  /// Select a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it).
  ///
  /// Opening the `Versions` tab is one of the two moments `MixinOcptProjectVersionsBloc`'s
  /// working-copy card needs a fresh read for: the other is a field edit flushing while it is
  /// already the one showing (see the views' flushes).
  Future<void> _onRightDockTabSelected(
    OcptResourcesRightDockTabSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final isAlreadyActive = state.rightDockTab == event.tab;

    emitter(state.copyWithToggledRightDockTab(tab: event.tab, isAlreadyActive: isAlreadyActive));

    if (!isAlreadyActive && event.tab == OcptResourcesRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggle the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on its single tab, and that reopening is one of the two moments the working-copy card needs a
  /// fresh read for.
  Future<void> _onRightDockToggled(
    OcptResourcesRightDockToggledEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWithRightDockClosed());
      return;
    }

    emitter(state.copyWithVersionsDockOpened());
    add(const OcptProjectWorkingCopyRefreshRequestedEvent());
  }

  /// Close the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptResourcesRightDockClosedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithRightDockClosed());
  }

  /// Apply and persist whichever dock fraction the ended drag gesture reports.
  Future<void> _onDockFractionsChanged(
    OcptResourcesDockFractionsChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final left = event.left;
    final right = event.right;

    if (left != null) {
      await _propertiesManager.resourcesLeftDockFraction.store(left);
    }
    if (right != null) {
      await _propertiesManager.resourcesRightDockFraction.store(right);
    }

    emitter(state.copyWithDockFractions(left: left, right: right));
  }

  /// Restore both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptResourcesDockLayoutResetEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _propertiesManager.resourcesLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.resourcesRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWithDockFractions(
        left: OcptWorkspaceDock.leftDefaultFraction,
        right: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Raise the transient write error a view bloc reported.
  Future<void> _onWriteFailed(
    OcptResourcesWriteFailedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithWriteError());
  }

  /// Raise the transient write error and tell every view bloc to drop the edits it holds, since
  /// writing them failed. The reload epoch moves with the lost edits epoch because it is what makes
  /// a view bloc look at the mode's state: nothing is read again.
  Future<void> _onPendingEditsLost(
    OcptResourcesPendingEditsLostEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithPendingEditsLost());
  }

  /// Select the record a view bloc has just created, in the list of `event.tab`, without switching
  /// tab nor writing what is pending: the view did so, and has read the catalogue again.
  Future<void> _onRecordCreated(
    OcptResourcesRecordCreatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithCreatedRecord(tab: event.tab, recordId: event.recordId));
  }

  /// Clear the selection of `event.tab`'s list when it is the record a view bloc has just deleted.
  Future<void> _onRecordDropped(
    OcptResourcesRecordDroppedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final wasSelected =
        switch (event.tab) {
          OcptResourcesTab.people => state.selectedPersonId,
          OcptResourcesTab.roles => state.selectedRoleId,
          OcptResourcesTab.locations => state.selectedLocationId,
          OcptResourcesTab.elements => state.selectedElementId,
        } ==
        event.recordId;
    if (!wasSelected) {
      return;
    }

    emitter(state.copyWithDroppedRecord(tab: event.tab));
  }

  /// Dismiss the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptResourcesWriteErrorDismissedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWithWriteErrorDismissed());
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// A further safety net alongside [flushPendingFieldEdits] (the mode's own `deactivate()`) and
  /// the flush every selection-changing handler already performs: whichever path the bloc closes
  /// through, a pending field edit still gets written rather than silently dropped, mirroring
  /// `OcptShotListBloc.disposeLifeCycle`'s own best-effort flush.
  @override
  Future<void> disposeLifeCycle() async {
    await flushPendingFieldEdits();
    return super.disposeLifeCycle();
  }
}
