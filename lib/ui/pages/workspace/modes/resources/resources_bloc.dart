// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
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
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_display_number.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the resources production mode (the address book, the cast, locations
/// and the physical elements catalogue).
///
/// It loads the current project's whole catalogue from [_peopleService], [_roleIndexService],
/// [_roleCandidatesService], [_locationsService] and [_elementsService] on entry, combining the
/// five reads into one [OcptResourcesSnapshot] — the same "one read of everything, joined in
/// memory" shape `OcptShotListBloc` builds its own snapshot with — and holds the active tab, the
/// selected person, the dock geometry and the pending field edits on top of it.
///
/// Every one of the four [OcptResourcesTab]s now has real content: the address book, the cast
/// reconciled against the screenplay, the locations with their sets, and the elements catalogue
/// with the dépouillement links onto the scenes needing each item.
///
/// Alongside that catalogue, [OcptResourcesState.mileageRates] is read once from
/// `OcptProjectsManager.budgetFinancingService` on every load: the person sheet's own rate picker
/// reads this project-wide list, exactly as `currencyCode` is read once rather than folded into
/// [OcptResourcesSnapshot] — the mileage rates belong to the project settings page's own catalogue,
/// and this mode only ever reads it.
///
/// Most of a person's discrete fields (colour, birth date, transport autonomy, image rights status
/// and date), every sub-list (positions, skills, unavailabilities), a role's cast member and kind,
/// a location's colour, permit status and date, contact, sets, scene links and referenced files,
/// and an element's category, provenance, owner, bringer, tracking flags and scene links are
/// written to the project database the moment they change, exactly like a shot's difficulty axis or
/// its character chips are. A role's name is never written here for an `isFromScreenplay` role —
/// [_roleIndexService]'s own reconciliation owns it, and would overwrite a hand-typed name right
/// back on the next save; withholding that field is the widgets' job, not a special case here. The
/// sheets' typed free-text fields ([OcptPersonField], [OcptRoleField], [OcptLocationField],
/// [OcptSetField], [OcptElementField], [OcptRoleCandidateField]) are the exception: an edit is held
/// in the matching `OcptResourcesState.pending…FieldEdits` map and written
/// [defaultFieldEditDebounce] after the last keystroke, mirroring `OcptShotListBloc`'s own autosave
/// convention — the six maps ride the very same debounce timer, so pending edits are always flushed
/// together, never one kind without the others. The debounce is flushed immediately whenever the
/// selected record, or the active tab, changes, when the workspace is left, and (through
/// [flushPendingFieldEdits], called by the mode's own `deactivate()`) whenever the mode leaves the
/// widget tree for any other reason, so a pending edit is never silently dropped.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does. The two hooks the mixin needs are answered by [flushPendingProjectWrites]
/// (a field edit still sitting in the debounce must reach the working copy before a preview swaps
/// the database out) and [reloadFromProjectDatabase]. `_onRightDockTabSelected` and
/// `_flushPendingFieldEdits` each dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] — opening
/// the `Versions` tab, and a field edit landing while it is already open — the two moments the
/// mixin's working-copy card is worth a fresh, throttled read.
///
/// It mixes in [MixinOcptProjectPackageBloc] too, which writes the whole project out as a portable
/// package from the `Export` panel's own standing card. That mixin reuses
/// [flushPendingProjectWrites] — what a colleague receives is the project *file*, so a debounced
/// edit has to reach it first — and asks [exportManager] where to write, exactly as the mode's
/// own exports (`OcptResourcesExportBloc`) do.
class OcptResourcesBloc extends BlocForMixin<OcptResourcesState>
    with
        MixinOcptProjectVersionsBloc<OcptResourcesState>,
        MixinOcptProjectPackageBloc<OcptResourcesState>,
        MixinOcptModeBloc<OcptResourcesState, OcptResourcesReloadScope> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "resources_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The default delay between the last field edit and its autosave write.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

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

  /// The manager used to show the native "open" dialog when a photo or a document is referenced,
  /// or null to resolve it through [globalGetIt] the first time one actually is.
  ///
  /// The one manager of this bloc that isn't one of the app's own: referencing a file is a native
  /// dialog and a path, with no bytes to convert and no project document to write, so it needs
  /// nothing of what `OcptExportManager` owns around its own dialogs. It is also the one resolved
  /// lazily rather than in the constructor — a mode that never references a file never asks for it
  /// at all, which is every use of this bloc but two.
  final FileSelectorManager? _fileSelectorManager;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The running field-edit debounce timer, if any.
  Timer? _fieldEditTimer;

  /// What the first load should open on, handed over by the mode that sent the user here, or null
  /// to open on the mode's own default.
  ///
  /// Consumed — set back to null — by that first load, so it is applied exactly once: every later
  /// load goes through the very same handler (entering or leaving a version preview calls
  /// [reloadFromProjectDatabase], which is [_onLoadRequested]), and re-applying it there would
  /// yank the user back to a record they may well have navigated away from.
  OcptResourcesRevealRequest? _pendingRevealRequest;

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

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by tests, to keep
  /// it fast and deterministic.
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
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
    OcptResourcesRevealRequest? revealRequest,
    String? selectedEpisodeId,
  }) : _pendingRevealRequest = revealRequest,
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
       _fileSelectorManager = fileSelectorManager,
       _fieldEditDebounce = fieldEditDebounce,
       super(OcptResourcesState.init()) {
    add(const OcptResourcesLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptResourcesLoadRequestedEvent>(_onLoadRequested);
    on<OcptResourcesBackRequestedEvent>(_onBackRequested);
    on<OcptResourcesProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptResourcesTabSelectedEvent>(_onTabSelected);
    on<OcptResourcesPersonSelectedEvent>(_onPersonSelected);
    on<OcptResourcesWriteFailedEvent>(_onWriteFailed);
    onAwaited<OcptResourcesPendingEditsLostEvent>(_onPendingEditsLost);
    onAwaited<OcptResourcesRecordCreatedEvent>(_onRecordCreated);
    onAwaited<OcptResourcesRecordDroppedEvent>(_onRecordDropped);
    on<OcptResourcesFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptResourcesRoleSelectedEvent>(_onRoleSelected);
    on<OcptResourcesPersonSheetOpenRequestedEvent>(_onPersonSheetOpenRequested);
    on<OcptResourcesLocationSelectedEvent>(_onLocationSelected);
    on<OcptResourcesOpenSetInShotListRequestedEvent>(_onOpenSetInShotListRequested);
    on<OcptResourcesShotListRevealDismissedEvent>(_onShotListRevealDismissed);
    on<OcptResourcesElementPhotoPickRequestedEvent>(_onElementPhotoPickRequested);
    on<OcptResourcesElementPhotoClearedEvent>(_onElementPhotoCleared);
    on<OcptResourcesElementSelectedEvent>(_onElementSelected);
    on<OcptResourcesElementCreationRequestedEvent>(_onElementCreationRequested);
    on<OcptResourcesElementDeletionRequestedEvent>(_onElementDeletionRequested);
    on<OcptResourcesElementFieldChangedEvent>(_onElementFieldChanged);
    on<OcptResourcesElementCategoryChangedEvent>(_onElementCategoryChanged);
    on<OcptResourcesElementSourceKindChangedEvent>(_onElementSourceKindChanged);
    on<OcptResourcesElementOwnerChangedEvent>(_onElementOwnerChanged);
    on<OcptResourcesElementBringerChangedEvent>(_onElementBringerChanged);
    on<OcptResourcesElementTrackingFlagChangedEvent>(_onElementTrackingFlagChanged);
    on<OcptResourcesSceneAssignedToElementEvent>(_onSceneAssignedToElement);
    on<OcptResourcesSceneElementUpdatedEvent>(_onSceneElementUpdated);
    on<OcptResourcesSceneElementRemovedEvent>(_onSceneElementRemoved);
    on<OcptResourcesElementLinkedToRoleEvent>(_onElementLinkedToRole);
    on<OcptResourcesRoleElementUpdatedEvent>(_onRoleElementUpdated);
    on<OcptResourcesRoleElementRemovedEvent>(_onRoleElementRemoved);
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

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// {@macro open_cine_prod_tools.MixinOcptProjectPackageBloc.exportManager}
  @protected
  @override
  OcptExportManager get exportManager => _exportManager;

  /// The screenplay this bloc reads and writes: [_selectedEpisodeId], or [project]'s own
  /// [OcptOpenProjectModel.primaryScreenplayId] on the one path that can reach here with none
  /// selected (see [_selectedEpisodeId]'s own doc comment).
  String screenplayIdOf(OcptOpenProjectModel project) =>
      _selectedEpisodeId ?? project.primaryScreenplayId;

  /// Writes whatever field edit is still sitting in the field-edit debounce, so a preview about to
  /// swap the database can't send it into the previewed version instead.
  @protected
  @override
  Future<bool> flushPendingProjectWrites(Emitter<OcptResourcesState> emitter) async {
    await _flushAllPendingWrites(emitter);
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
    await _flushAllPendingWrites(emitter);
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

    try {
      OcptResourcesSnapshot? snapshot;

      // A switch statement over an enum must name every value: a scope added to the enum does not
      // compile until it is read here.
      for (final scope in scopes) {
        switch (scope) {
          case OcptResourcesReloadScope.snapshot:
            snapshot = await _loadSnapshot(project);
        }
      }

      emitter(state.copyWith(snapshot: snapshot));
      return true;
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to read again the $scopes of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
      return false;
    }
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptResourcesState> emitter) =>
      _onLoadRequested(const OcptResourcesLoadRequestedEvent(), emitter);

  /// Loads the persisted dock fractions and the current project's whole resources catalogue.
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
  Future<void> _onLoadRequested(
    OcptResourcesLoadRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final leftDockFraction =
        await _propertiesManager.resourcesLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.resourcesRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          isLoading: false,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          forcePreviewedVersionIdValue: true,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptResourcesSelectionCause.load,
        ),
      );
      return;
    }

    // Queued with the views' reloads: a read made here but emitted after a newer one would put
    // older data over it.
    await runSerially(() async {
      final previewedVersion = project.previewedVersion;
      final snapshot = await _loadSnapshot(project);
      final currencyCode = await _projectsManager.loadCurrentProjectCurrencyCode();
      final pageSetup = await _loadPageSetup(project);
      final mileageRates = await _projectsManager.budgetFinancingService.loadMileageRates(
        database: project.database,
      );
      final setIdsWithPlan = await _locationsService.floorPlanService.liveSetIdsWithPlan(
        database: project.database,
        setIds: [
          for (final location in snapshot.locations)
            for (final set in location.sets) set.id,
        ],
      );

      final revealRequest = _pendingRevealRequest;
      _pendingRevealRequest = null;

      emitter(
        _revealed(
          state.copyWith(
            isLoading: false,
            title: project.name,
            currencyCode: currencyCode ?? ocptDefaultCurrencyCode,
            previewedVersionId: previewedVersion?.id,
            forcePreviewedVersionIdValue: previewedVersion == null,
            snapshot: snapshot,
            pageSetup: pageSetup,
            mileageRates: mileageRates,
            setIdsWithPlan: setIdsWithPlan,
            forceSelectedPersonIdValue: true,
            forceSelectedRoleIdValue: true,
            forceSelectedLocationIdValue: true,
            forceSelectedElementIdValue: true,
            leftDockFraction: leftDockFraction,
            rightDockFraction: rightDockFraction,
            selectionEpoch: state.selectionEpoch + 1,
            selectionCause: OcptResourcesSelectionCause.load,
          ),
          revealRequest,
        ),
      );
    });
  }

  /// [loaded] with [revealRequest]'s own tab active and its record selected, or [loaded] untouched
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

    final tabbed = loaded.copyWith(activeTab: revealRequest.tab);
    final recordId = revealRequest.recordId;
    final snapshot = loaded.snapshot;
    if (recordId == null || snapshot == null) {
      return tabbed;
    }

    return switch (revealRequest.tab) {
      OcptResourcesTab.people =>
        snapshot.people.any((person) => person.id == recordId)
            ? tabbed.copyWith(selectedPersonId: recordId)
            : tabbed,
      OcptResourcesTab.roles =>
        snapshot.roles.any((role) => role.id == recordId)
            ? tabbed.copyWith(selectedRoleId: recordId)
            : tabbed,
      OcptResourcesTab.locations =>
        snapshot.locations.any((location) => location.id == recordId)
            ? tabbed.copyWith(selectedLocationId: recordId)
            : tabbed,
      OcptResourcesTab.elements =>
        snapshot.elements.any((element) => element.id == recordId)
            ? tabbed.copyWith(selectedElementId: recordId)
            : tabbed,
    };
  }

  /// Reads the page setup the contact list export dialog is pre-filled with: the open project's own
  /// page format, paired with the app-wide margins preference, exactly as `OcptBreakdownBloc`'s own
  /// `_loadPageSetup` pairs them.
  ///
  /// A version being previewed is laid out with the setup it was written against instead, which
  /// travels on the open project model and is never written anywhere.
  Future<OcptPageSetup> _loadPageSetup(OcptOpenProjectModel project) async =>
      project.previewedPageSetup ??
      OcptPageSetup(
        format: await _projectsManager.loadCurrentProjectPageFormat() ?? OcptPageFormat.usLetter,
        margins:
            await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

  /// Reads the whole resources catalogue of [project], joining the four services' own reads into
  /// one [OcptResourcesSnapshot].
  ///
  /// The scenes are numbered with their episode's own prefix: this bloc reads the project's live
  /// episodes through [_projectsManager]'s own `screenplayService` (never through
  /// [_locationsService], which `OcptScreenplayService` already depends on) and resolves the
  /// selected episode's number with `ocptEpisodePrefixNumberOf`, null on a single-episode project.
  Future<OcptResourcesSnapshot> _loadSnapshot(OcptOpenProjectModel project) async {
    final database = project.database;
    final screenplayId = screenplayIdOf(project);

    final people = await _peopleService.loadPeople(database: database);
    final roles = await _roleIndexService.loadRoles(database: database);
    final locations = await _locationsService.loadLocations(database: database);
    final elements = await _elementsService.loadElements(database: database);
    final candidatesByRoleId = await _roleCandidatesService.loadCandidatesByRoleId(
      database: database,
      people: people,
    );
    final episodes = await _projectsManager.screenplayService.loadEpisodes(database: database);
    final scenes = await _locationsService.loadScenes(
      database: database,
      screenplayId: screenplayId,
      episodeNumber: ocptEpisodePrefixNumberOf(episodes: episodes, screenplayId: screenplayId),
    );

    return OcptResourcesSnapshot.build(
      people: people,
      roles: roles,
      locations: locations,
      elements: elements,
      candidatesByRoleId: candidatesByRoleId,
      scenes: scenes,
    );
  }

  /// Leaves the workspace: flushes any pending field edit, closes the current project, and
  /// navigates back to the home page.
  Future<void> _onBackRequested(
    OcptResourcesBackRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Re-reads the project's currency and reloads the resources snapshot after the project
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
      final snapshot = await _loadSnapshot(project);
      final currencyCode = await _projectsManager.loadCurrentProjectCurrencyCode();

      emitter(
        state.copyWith(snapshot: snapshot, currencyCode: currencyCode ?? ocptDefaultCurrencyCode),
      );
    });
  }

  /// Selects tab `event.tab`, clearing every selected record when it actually changes tab.
  ///
  /// Also clears [OcptResourcesState.searchQuery] when it actually changes tab, but leaves the
  /// search field open (`isSearchVisible` untouched): each tab searches its own kind of record —
  /// a query that found three costume elements means nothing once the roles tab is showing — so
  /// carrying it across a tab change would filter the new list against words that describe the
  /// old one.
  ///
  /// Flushes any pending field edit first, so switching tabs right after typing never loses it.
  Future<void> _onTabSelected(
    OcptResourcesTabSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);

    final isSameTab = state.activeTab == event.tab;

    emitter(
      state.copyWith(
        activeTab: event.tab,
        forceSelectedPersonIdValue: !isSameTab,
        forceSelectedRoleIdValue: !isSameTab,
        forceSelectedLocationIdValue: !isSameTab,
        forceSelectedElementIdValue: !isSameTab,
        searchQuery: isSameTab ? null : "",
        selectionEpoch: isSameTab ? null : state.selectionEpoch + 1,
        selectionCause: isSameTab ? null : OcptResourcesSelectionCause.tab,
      ),
    );
  }

  /// Selects person `event.personId`.
  ///
  /// Flushes any pending field edit first, so switching people right after typing never loses it.
  /// A person id that no longer exists in the current snapshot (a stale click on a list rebuilt
  /// underneath) is ignored rather than selecting nothing.
  Future<void> _onPersonSelected(
    OcptResourcesPersonSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);

    final exists = state.people.any((person) => person.id == event.personId);
    if (!exists) {
      return;
    }

    emitter(
      state.copyWith(
        selectedPersonId: event.personId,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.person,
      ),
    );
  }

  /// (Re)starts the one field-edit debounce timer every typed field of the mode rides — a person's,
  /// a role's, a location's and a set's alike — so they are always written together, never one
  /// without the other.
  void _restartFieldEditTimer() {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptResourcesFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Cancels the field-edit debounce timer if, and only if, nothing of any kind is pending any
  /// more.
  ///
  /// Every handler that drops a record also drops the pending edits that targeted it, and the
  /// timer is shared by all six maps: cancelling it on the strength of one map having emptied
  /// would strand whatever the other five still hold until the next keystroke.
  void _cancelFieldEditTimerIfIdle({
    required Map<(String, OcptElementField), String> pendingElementEdits,
  }) {
    if (pendingElementEdits.isEmpty) {
      _fieldEditTimer?.cancel();
      _fieldEditTimer = null;
    }
  }

  /// Writes every pending field edit once the field-edit debounce elapses with no further typing.
  Future<void> _onFieldEditFlushRequested(
    OcptResourcesFieldEditFlushRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _flushPendingFieldEdits(emitter);

  /// Writes every pending write of the mode's views immediately, through the flushers they
  /// registered, then the edits the mode still holds itself.
  ///
  /// Up front of every handler that changes what is selected, that leaves the workspace, or that is
  /// about to read the database (an export, a preview): a pending edit is never silently dropped by
  /// one of them. A view that fails to write drops every edit of the mode (see
  /// `OcptResourcesPendingEditsLostEvent`) before the flush goes on, so the ones after it find
  /// nothing to write.
  Future<void> _flushAllPendingWrites(Emitter<OcptResourcesState> emitter) async {
    await runPendingWritesFlushers();
    await _flushPendingFieldEdits(emitter);
  }

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it
  /// already fired or there was none), writes every person field edit through each sheet's own
  /// service — `OcptPeopleService.updatePerson`, `OcptRoleIndexService.updateRole`,
  /// `OcptLocationsService.updateLocation`/`.updateSet`, `OcptElementsService.updateElement` and
  /// `OcptRoleCandidatesService.updateCandidate` — then reloads the snapshot so every derived
  /// aggregate reflects what the database now says. A
  /// no-op while nothing of any kind is pending.
  ///
  /// Used from inside an event handler, with that handler's own [emitter]: called by
  /// [_onFieldEditFlushRequested] (the debounce firing), and up front by every handler that changes
  /// which record, or which tab, is selected, or that leaves the workspace, so a pending edit is
  /// never silently dropped by a selection change. [flushPendingFieldEdits] is the sibling of this
  /// method used outside of an event handler.
  Future<void> _flushPendingFieldEdits(Emitter<OcptResourcesState> emitter) async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pendingElementEdits = state.pendingElementFieldEdits;
    if (pendingElementEdits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(pendingElementFieldEdits: const {}));
      return;
    }

    try {
      await _writeAllPendingElementFields(database: project.database, pending: pendingElementEdits);
      await runSerially(() async {
        final snapshot = await _loadSnapshot(project);
        emitter(state.copyWith(snapshot: snapshot, pendingElementFieldEdits: const {}));
      });

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a field edit landing while the tab showing it is already open.
      if (state.rightDockTab == OcptResourcesRightDockTab.versions) {
        add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending resources field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(
        state.copyWith(
          hasWriteError: true,
          lostEditsEpoch: state.lostEditsEpoch + 1,
          reloadEpoch: state.reloadEpoch + 1,
          pendingElementFieldEdits: const {},
        ),
      );
    }
  }

  /// Writes every pending field edit directly to the database, bypassing both the debounce timer
  /// and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()`, mirroring `OcptShotListBloc.flushPendingFieldEdits`:
  /// `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
  /// this whole subtree out, and so does the workspace's own back navigation), so triggering the
  /// write here — rather than dispatching an event, which would only be processed on a later
  /// microtask this widget might not survive to see — is what guarantees the last
  /// [defaultFieldEditDebounce] worth of typing isn't lost.
  ///
  /// Unlike [_flushPendingFieldEdits], this never touches [state]: `emit` may only be called from
  /// inside a registered `on<Event>` handler, and by the time this runs the widget tree that would
  /// show a fresh state is already gone anyway. A failure here is only logged.
  Future<void> flushPendingFieldEdits() async {
    await runPendingWritesFlushersWithoutState();

    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pendingElementEdits = state.pendingElementFieldEdits;
    if (pendingElementEdits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _writeAllPendingElementFields(database: project.database, pending: pendingElementEdits);
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending resources field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Writes every entry of [pending] through [_writeElementField].
  Future<void> _writeAllPendingElementFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptElementField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (elementId, field) = entry.key;
      await _writeElementField(
        database: database,
        elementId: elementId,
        field: field,
        rawValue: entry.value,
      );
    }
  }

  /// Writes a single element field edit through `OcptElementsService.updateElement`, translating
  /// [field] into the matching named argument (see `OcptElementField`'s own doc comment for the
  /// mapping).
  ///
  /// The cost is the only one not written as typed: what cannot be read as an amount of money is
  /// written as null rather than refused, so a `gratuit` costs nothing and a cleared field clears
  /// the price. Saying so is the sheet's job, not this one's — the same trade the two coordinate
  /// fields of a location make.
  Future<void> _writeElementField({
    required OcptProjectDatabase database,
    required String elementId,
    required OcptElementField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptElementField.name:
        await _elementsService.updateElement(
          database: database,
          elementId: elementId,
          name: Value(rawValue),
        );
      case OcptElementField.subCategory:
        await _elementsService.updateElement(
          database: database,
          elementId: elementId,
          subCategory: Value(rawValue),
        );
      case OcptElementField.quantity:
        await _elementsService.updateElement(
          database: database,
          elementId: elementId,
          quantity: Value(rawValue),
        );
      case OcptElementField.ownerNotes:
        await _elementsService.updateElement(
          database: database,
          elementId: elementId,
          ownerNotes: Value(rawValue),
        );
      case OcptElementField.storageNotes:
        await _elementsService.updateElement(
          database: database,
          elementId: elementId,
          storageNotes: Value(rawValue),
        );
      case OcptElementField.cost:
        await _elementsService.updateElement(
          database: database,
          elementId: elementId,
          cost: Value(ocptCostCentsOf(rawValue)),
        );
      case OcptElementField.purposeNotes:
        await _elementsService.updateElement(
          database: database,
          elementId: elementId,
          purposeNotes: Value(rawValue),
        );
      case OcptElementField.notes:
        await _elementsService.updateElement(
          database: database,
          elementId: elementId,
          notes: Value(rawValue),
        );
    }
  }

  /// Selects role `event.roleId`, expanding its row in place; selecting the already-selected role
  /// clears the selection instead, collapsing it back.
  ///
  /// Flushes any pending field edit first, so switching roles right after typing never loses it. A
  /// role id that no longer exists in the current snapshot (a stale click on a list rebuilt
  /// underneath) is ignored rather than selecting nothing.
  ///
  /// Selecting the already-selected role is a no-op rather than a way of clearing the selection,
  /// mirroring [_onPersonSelected]: the centre shows the role's sheet, and a click on a list row
  /// blanking it would be a surprising affordance.
  Future<void> _onRoleSelected(
    OcptResourcesRoleSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);

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
      state.copyWith(
        selectedRoleId: event.roleId,
        activeTab: OcptResourcesTab.roles,
        searchQuery: isAlreadyOnRolesTab ? null : "",
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.role,
      ),
    );
  }

  /// Opens person `event.personId`'s sheet from the role sheet's `↗` affordance: flushes any
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
    await _flushAllPendingWrites(emitter);

    emitter(
      state.copyWith(
        activeTab: OcptResourcesTab.people,
        selectedPersonId: event.personId,
        forceSelectedRoleIdValue: true,
        forceSelectedLocationIdValue: true,
        forceSelectedElementIdValue: true,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.personSheetOpened,
      ),
    );
  }

  /// Selects location `event.locationId`.
  ///
  /// Flushes any pending field edit first, so switching locations right after typing never loses
  /// it. A location id that no longer exists in the current snapshot (a stale click on a list
  /// rebuilt underneath) is ignored rather than selecting nothing, mirroring [_onPersonSelected].
  Future<void> _onLocationSelected(
    OcptResourcesLocationSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);

    final exists = state.locations.any((location) => location.id == event.locationId);
    if (!exists) {
      return;
    }

    emitter(
      state.copyWith(
        selectedLocationId: event.locationId,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.location,
      ),
    );
  }

  /// Resolves set `event.setId`'s own first linked sequence, in screenplay order
  /// (`OcptLocationsService.firstLinkedSceneOf`), and sets it as the pending cross-mode reveal the
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

    try {
      final firstLinkedScene = await _locationsService.firstLinkedSceneOf(
        database: project.database,
        setId: event.setId,
      );
      if (firstLinkedScene == null) {
        return;
      }

      emitter(
        state.copyWith(
          pendingShotListReveal: (
            episodeId: firstLinkedScene.screenplayId,
            sceneId: firstLinkedScene.sceneId,
            setId: event.setId,
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to resolve set ${event.setId}'s own first linked "
        "sequence of project ${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Clears [OcptResourcesState.pendingShotListReveal] once the mode has dispatched the cross-mode
  /// switch it named.
  Future<void> _onShotListRevealDismissed(
    OcptResourcesShotListRevealDismissedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(forcePendingShotListRevealValue: true));
  }

  /// Asks for element `event.elementId`'s photo through the native picker and references the file
  /// picked, written immediately. A cancelled dialog leaves the photo already referenced alone.
  Future<void> _onElementPhotoPickRequested(
    OcptResourcesElementPhotoPickRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final path = await _pickFilePath(
      allowedExtensions: ocptImageFileExtensions,
      fileTypeLabel: event.fileTypeLabel,
    );
    if (path == null) {
      return;
    }

    await _writeCatalogueChange(
      emitter: emitter,
      logContext: "reference the photo of element ${event.elementId}",
      action: (project) async {
        await _elementsService.setElementPhoto(
          database: project.database,
          elementId: event.elementId,
          path: path,
        );
      },
    );
  }

  /// Drops element `event.elementId`'s reference to its photo, written immediately.
  Future<void> _onElementPhotoCleared(
    OcptResourcesElementPhotoClearedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "drop the photo of element ${event.elementId}",
    action: (project) =>
        _elementsService.clearElementPhoto(database: project.database, elementId: event.elementId),
  );

  /// Shows the native "open" dialog and returns the path of the file picked, or null when the user
  /// cancelled it, when it failed, or when the platform gave a file with no path at all.
  ///
  /// **The file itself is never read here** (see
  /// `docs/adr/0013-binary-assets-referenced-by-path.md`) — unlike an import, which is exactly why
  /// this goes to [FileSelectorManager] directly rather than through `OcptExportManager`: there is
  /// nothing to decode, only a path to keep.
  Future<String?> _pickFilePath({
    required List<String> allowedExtensions,
    required String fileTypeLabel,
  }) async {
    final fileSelectorManager = _fileSelectorManager ?? globalGetIt().get<FileSelectorManager>();

    final selection = await fileSelectorManager.openSelector(
      allowedExtensions: allowedExtensions,
      label: fileTypeLabel,
    );

    final file = selection.value;
    if (!selection.status.isSuccess || file == null) {
      // The user cancelled the dialog, or the selection failed; the latter is a soft failure
      // deliberately not surfaced as an error, since the OS dialog itself already reported it.
      return null;
    }

    return file.path.isEmpty ? null : file.path;
  }

  /// Writes a discrete change to the catalogue — a person's field, position, skill or
  /// unavailability, a role's cast member or kind, a location's own picks, an element's category,
  /// provenance, owner, bringer, tracking flags or scene links — through [action] and reloads the
  /// snapshot, so every derived aggregate (a person's positions summary, the status bar's counts)
  /// reflects what the database now says. Mirrors `OcptShotListBloc`'s own `_writeCoverageChange`
  /// shape, shared by every discrete field, position, skill, unavailability and role write of this
  /// bloc. A no-op while no project is open.
  Future<void> _writeCatalogueChange({
    required Emitter<OcptResourcesState> emitter,
    required String logContext,
    required Future<void> Function(OcptOpenProjectModel project) action,
  }) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await action(project);
      emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to $logContext of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Selects element `event.elementId`.
  ///
  /// Flushes any pending field edit first, so switching elements right after typing never loses it.
  /// An element id that no longer exists in the current snapshot (a stale click on a list rebuilt
  /// underneath) is ignored rather than selecting nothing, mirroring [_onPersonSelected].
  Future<void> _onElementSelected(
    OcptResourcesElementSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);

    final exists = state.elements.any((element) => element.id == event.elementId);
    if (!exists) {
      return;
    }

    emitter(
      state.copyWith(
        selectedElementId: event.elementId,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.element,
      ),
    );
  }

  /// Creates a new, blank element of `event.category` at the end of the catalogue, reloads it and
  /// selects the new element so it can be named straight away.
  ///
  /// Unlike a person or a location, it is given no colour of its own: an element is told apart in a
  /// list by the category heading it sits under and by its code, and the palette is what a person,
  /// a location and a shot already share.
  Future<void> _onElementCreationRequested(
    OcptResourcesElementCreationRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final elementId = await _elementsService.createElement(
        database: project.database,
        name: "",
        category: event.category,
        sourceKind: OcptElementSourceKind.owned,
      );
      if (elementId == null) {
        // The write was refused (a version is being previewed read-only); the shell already
        // withholds the button that dispatches this event, so this is only ever a race.
        return;
      }

      final snapshot = await _loadSnapshot(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          selectedElementId: elementId,
          selectionEpoch: state.selectionEpoch + 1,
          selectionCause: OcptResourcesSelectionCause.created,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to create an element in project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Deletes element `event.elementId`, clearing the selection when it was the selected one, and
  /// dropping any pending field edit that still targeted it.
  Future<void> _onElementDeletionRequested(
    OcptResourcesElementDeletionRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final pendingWithoutElement = Map<(String, OcptElementField), String>.of(
      state.pendingElementFieldEdits,
    )..removeWhere((key, _) => key.$1 == event.elementId);
    _cancelFieldEditTimerIfIdle(pendingElementEdits: pendingWithoutElement);

    final wasSelected = state.selectedElementId == event.elementId;

    try {
      await _elementsService.deleteElement(database: project.database, elementId: event.elementId);
      final snapshot = await _loadSnapshot(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          pendingElementFieldEdits: pendingWithoutElement,
          forceSelectedElementIdValue: wasSelected,
          selectionEpoch: wasSelected ? state.selectionEpoch + 1 : null,
          selectionCause: wasSelected ? OcptResourcesSelectionCause.dropped : null,
        ),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete element ${event.elementId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Records the raw text just typed into `event.field` of element `event.elementId` as a pending
  /// edit, visible immediately, and (re)starts the same field-edit debounce every other typed field
  /// of the mode rides.
  Future<void> _onElementFieldChanged(
    OcptResourcesElementFieldChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final pending = Map<(String, OcptElementField), String>.of(state.pendingElementFieldEdits)
      ..[(event.elementId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingElementFieldEdits: pending));

    _restartFieldEditTimer();
  }

  /// Sets element `event.elementId`'s category, written immediately.
  Future<void> _onElementCategoryChanged(
    OcptResourcesElementCategoryChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _writeCatalogueChange(
      emitter: emitter,
      logContext: "change the category of element ${event.elementId}",
      action: (project) => _elementsService.updateElement(
        database: project.database,
        elementId: event.elementId,
        category: Value(event.category),
      ),
    );
  }

  /// Sets where element `event.elementId` comes from, written immediately.
  Future<void> _onElementSourceKindChanged(
    OcptResourcesElementSourceKindChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the provenance of element ${event.elementId}",
    action: (project) => _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      sourceKind: Value(event.sourceKind),
    ),
  );

  /// Sets who owns element `event.elementId`, written immediately.
  Future<void> _onElementOwnerChanged(
    OcptResourcesElementOwnerChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the owner of element ${event.elementId}",
    action: (project) => _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      ownerPersonId: Value(event.personId),
    ),
  );

  /// Sets who brings element `event.elementId` to set, written immediately.
  Future<void> _onElementBringerChanged(
    OcptResourcesElementBringerChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change who brings element ${event.elementId}",
    action: (project) => _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      broughtByPersonId: Value(event.personId),
    ),
  );

  /// Ticks or unticks one of element `event.elementId`'s three tracking flags, written immediately.
  Future<void> _onElementTrackingFlagChanged(
    OcptResourcesElementTrackingFlagChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the ${event.flag.name} flag of element ${event.elementId}",
    action: (project) => switch (event.flag) {
      OcptElementTrackingFlag.secured => _elementsService.updateElement(
        database: project.database,
        elementId: event.elementId,
        isSecured: Value(event.value),
      ),
      OcptElementTrackingFlag.readyForShoot => _elementsService.updateElement(
        database: project.database,
        elementId: event.elementId,
        isReadyForShoot: Value(event.value),
      ),
      OcptElementTrackingFlag.returned => _elementsService.updateElement(
        database: project.database,
        elementId: event.elementId,
        isReturned: Value(event.value),
      ),
    },
  );

  /// Says element `event.elementId` is needed in scene `event.sceneId`, written immediately.
  Future<void> _onSceneAssignedToElement(
    OcptResourcesSceneAssignedToElementEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "assign scene ${event.sceneId} to element ${event.elementId}",
    action: (project) async {
      await _elementsService.addSceneElement(
        database: project.database,
        sceneId: event.sceneId,
        elementId: event.elementId,
      );
    },
  );

  /// Updates the quantity and the notes of the scene ↔ element link `event.id`, written
  /// immediately.
  Future<void> _onSceneElementUpdated(
    OcptResourcesSceneElementUpdatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "update the scene ↔ element link ${event.id}",
    action: (project) => _elementsService.updateSceneElement(
      database: project.database,
      id: event.id,
      quantity: Value(event.quantity),
      notes: Value(event.notes),
    ),
  );

  /// Removes the scene ↔ element link `event.id`, written immediately.
  Future<void> _onSceneElementRemoved(
    OcptResourcesSceneElementRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "remove the scene ↔ element link ${event.id}",
    action: (project) =>
        _elementsService.removeSceneElement(database: project.database, id: event.id),
  );

  /// Links role `event.roleId` to element `event.elementId`, written immediately.
  Future<void> _onElementLinkedToRole(
    OcptResourcesElementLinkedToRoleEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "link element ${event.elementId} to role ${event.roleId}",
    action: (project) async {
      await _elementsService.addRoleElement(
        database: project.database,
        roleId: event.roleId,
        elementId: event.elementId,
      );
    },
  );

  /// Updates the notes of the role ↔ element link `event.id`, written immediately.
  Future<void> _onRoleElementUpdated(
    OcptResourcesRoleElementUpdatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "update the role ↔ element link ${event.id}",
    action: (project) => _elementsService.updateRoleElement(
      database: project.database,
      id: event.id,
      notes: event.notes,
    ),
  );

  /// Removes the role ↔ element link `event.id`, written immediately.
  Future<void> _onRoleElementRemoved(
    OcptResourcesRoleElementRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "remove the role ↔ element link ${event.id}",
    action: (project) =>
        _elementsService.removeRoleElement(database: project.database, id: event.id),
  );

  /// Switches to the roles tab and selects role `event.roleId`, the element sheet's
  /// `Roles concerned` chips being the one way in.
  ///
  /// [_onPersonSheetOpenRequested]'s sibling, down to the reason it emits one state rather than
  /// dispatching a tab change: `OcptResourcesTabSelectedEvent` clears the selection, so the sheet
  /// this was asked to open would be deselected in the very same frame.
  Future<void> _onRoleSheetOpenRequested(
    OcptResourcesRoleSheetOpenRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushAllPendingWrites(emitter);

    emitter(
      state.copyWith(
        activeTab: OcptResourcesTab.roles,
        selectedRoleId: event.roleId,
        forceSelectedPersonIdValue: true,
        forceSelectedLocationIdValue: true,
        forceSelectedElementIdValue: true,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.roleSheetOpened,
      ),
    );
  }

  /// Toggles the left (list) dock's visibility.
  Future<void> _onLeftPanelToggled(
    OcptResourcesLeftPanelToggledEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(isListPanelVisible: !state.isListPanelVisible));
  }

  /// Toggles whether the search field is shown.
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
    final isOpening = !state.isSearchVisible;

    emitter(
      state.copyWith(
        isSearchVisible: isOpening,
        isListPanelVisible: isOpening ? true : null,
        searchQuery: isOpening ? null : "",
      ),
    );
  }

  /// Records the search field's current text.
  ///
  /// This needs no debounce, unlike a sheet field's typed value (see
  /// `OcptResourcesSearchQueryChangedEvent`'s own doc comment): it writes nothing to the project
  /// database, so it is applied to the state the moment it is typed rather than after a pause.
  Future<void> _onSearchQueryChanged(
    OcptResourcesSearchQueryChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(searchQuery: event.query));
  }

  /// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it).
  ///
  /// Opening the `Versions` tab is one of the two moments `MixinOcptProjectVersionsBloc`'s
  /// working-copy card needs a fresh read for: the other is a field edit flushing while it is
  /// already the one showing (see `_flushPendingFieldEdits`).
  Future<void> _onRightDockTabSelected(
    OcptResourcesRightDockTabSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final isAlreadyActive = state.rightDockTab == event.tab;

    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        forceRightDockTabValue: isAlreadyActive,
      ),
    );

    if (!isAlreadyActive && event.tab == OcptResourcesRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on its single tab, and that reopening is one of the two moments the working-copy card needs a
  /// fresh read for.
  Future<void> _onRightDockToggled(
    OcptResourcesRightDockToggledEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWith(forceRightDockTabValue: true));
      return;
    }

    emitter(state.copyWith(rightDockTab: OcptResourcesRightDockTab.versions));
    add(const OcptProjectWorkingCopyRefreshRequestedEvent());
  }

  /// Closes the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptResourcesRightDockClosedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(forceRightDockTabValue: true));
  }

  /// Applies and persists whichever dock fraction the ended drag gesture reports.
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

    emitter(state.copyWith(leftDockFraction: left, rightDockFraction: right));
  }

  /// Restores both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptResourcesDockLayoutResetEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _propertiesManager.resourcesLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.resourcesRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWith(
        leftDockFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightDockFraction: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Raises the transient write error a view bloc reported.
  Future<void> _onWriteFailed(
    OcptResourcesWriteFailedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(hasWriteError: true));
  }

  /// Raises the transient write error and tells every view bloc to drop the edits it holds, since
  /// writing them failed.
  ///
  /// The reload epoch moves with the lost edits epoch because it is what makes a view bloc look at
  /// the mode's state: nothing is read again, and the views prune nothing else on it.
  Future<void> _onPendingEditsLost(
    OcptResourcesPendingEditsLostEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(
      state.copyWith(
        hasWriteError: true,
        lostEditsEpoch: state.lostEditsEpoch + 1,
        reloadEpoch: state.reloadEpoch + 1,
      ),
    );
  }

  /// Selects the record a view bloc has just created, in the list of `event.tab`.
  ///
  /// Neither switches tab nor writes what is pending: the view did so before creating, and has read
  /// the catalogue again, so the record is in the snapshot the selection names.
  Future<void> _onRecordCreated(
    OcptResourcesRecordCreatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(
      switch (event.tab) {
        OcptResourcesTab.people => state.copyWith(selectedPersonId: event.recordId),
        OcptResourcesTab.roles => state.copyWith(selectedRoleId: event.recordId),
        OcptResourcesTab.locations => state.copyWith(selectedLocationId: event.recordId),
        OcptResourcesTab.elements => state.copyWith(selectedElementId: event.recordId),
      }.copyWith(
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.created,
      ),
    );
  }

  /// Clears the selection of `event.tab`'s list when it is the record a view bloc has just
  /// deleted. A selection that moved elsewhere meanwhile is left alone.
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

    emitter(
      state.copyWith(
        forceSelectedPersonIdValue: event.tab == OcptResourcesTab.people,
        forceSelectedRoleIdValue: event.tab == OcptResourcesTab.roles,
        forceSelectedLocationIdValue: event.tab == OcptResourcesTab.locations,
        forceSelectedElementIdValue: event.tab == OcptResourcesTab.elements,
        selectionEpoch: state.selectionEpoch + 1,
        selectionCause: OcptResourcesSelectionCause.dropped,
      ),
    );
  }

  /// Dismisses the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptResourcesWriteErrorDismissedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(hasWriteError: false));
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
