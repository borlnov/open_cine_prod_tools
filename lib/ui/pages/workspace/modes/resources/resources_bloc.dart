// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_reveal_request.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// This is the bloc class for the resources production mode (the address book, the cast, locations
/// and the physical elements catalogue).
///
/// It loads the current project's whole catalogue from [_peopleService], [_roleIndexService],
/// [_locationsService] and [_elementsService] on entry, combining the four reads into one
/// [OcptResourcesSnapshot] — the same "one read of everything, joined in memory" shape
/// `OcptShotListBloc` builds its own snapshot with — and holds the active tab, the selected person,
/// the dock geometry and the pending field edits on top of it.
///
/// Every one of the four [OcptResourcesTab]s now has real content: the address book, the cast
/// reconciled against the screenplay, the locations with their sets, and the elements catalogue with
/// the dépouillement links onto the scenes needing each item.
///
/// Most of a person's discrete fields (colour, birth date, transport autonomy, image rights status
/// and date), every sub-list (positions, skills, unavailabilities), a role's cast member and kind,
/// a location's colour, permit status and date, contact, sets, scene links and referenced files, and
/// an element's category, provenance, owner, bringer, tracking flags and scene links are written to
/// the project database the moment they change, exactly like a shot's difficulty axis or its
/// character chips are. A role's name is never written here for an
/// `isFromScreenplay` role — [_roleIndexService]'s own reconciliation owns it, and would overwrite
/// a hand-typed name right back on the next save; withholding that field is the widgets' job, not a
/// special case here. The sheets' typed free-text fields ([OcptPersonField], [OcptRoleField],
/// [OcptLocationField], [OcptSetField], [OcptElementField]) are the exception: an edit is held in the
/// matching `OcptResourcesState.pending…FieldEdits` map and written [defaultFieldEditDebounce] after
/// the last keystroke, mirroring `OcptShotListBloc`'s own autosave convention — the five maps ride
/// the very same debounce timer, so pending edits are always flushed together, never one kind
/// without the others. The debounce is flushed immediately whenever the selected record, or the active tab,
/// changes, when the workspace is left, and (through [flushPendingFieldEdits], called by the mode's
/// own `deactivate()`) whenever the mode leaves the widget tree for any other reason, so a pending
/// edit is never silently dropped.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does. The two hooks the mixin needs are answered by [flushPendingProjectWrites]
/// (a field edit still sitting in the debounce must reach the working copy before a preview swaps
/// the database out) and [reloadFromProjectDatabase]. `_onRightDockTabSelected` and
/// `_flushPendingFieldEdits` each dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] — opening
/// the `Versions` tab, and a field edit landing while it is already open — the two moments the
/// mixin's working-copy card is worth a fresh, throttled read.
class OcptResourcesBloc extends BlocForMixin<OcptResourcesState>
    with MixinOcptProjectVersionsBloc<OcptResourcesState> {
  /// The default delay between the last field edit and its autosave write.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager used to export the resources catalogue to a four-sheet XLSX workbook.
  final OcptExportManager _exportManager;

  /// The service used to read and write the address book.
  final OcptPeopleService _peopleService;

  /// The service used to read the cast reconciled against the screenplay.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read locations and their sets.
  final OcptLocationsService _locationsService;

  /// The service used to read the physical elements catalogue.
  final OcptElementsService _elementsService;

  /// The service used to drop a file reference, whatever owns it.
  ///
  /// Referencing a file is the owning service's — a person's photo is `OcptPeopleService`'s, since
  /// which asset is *the* headshot is a fact about the person — but dropping one by its id is not:
  /// this bloc's `⨯` control answers for a scouting photo exactly as it does for anything else, and
  /// having it pick a service by the kind of the row would be inventing a distinction the row does
  /// not make.
  final OcptAssetsService _assetsService;

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
    OcptLocationsService? locationsService,
    OcptElementsService? elementsService,
    OcptAssetsService? assetsService,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
    OcptResourcesRevealRequest? revealRequest,
  }) : _pendingRevealRequest = revealRequest,
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
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       _assetsService =
           assetsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).assetsService,
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
    on<OcptResourcesPersonCreationRequestedEvent>(_onPersonCreationRequested);
    on<OcptResourcesPersonDeletionRequestedEvent>(_onPersonDeletionRequested);
    on<OcptResourcesPersonFieldChangedEvent>(_onPersonFieldChanged);
    on<OcptResourcesFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptResourcesPersonColorChangedEvent>(_onPersonColorChanged);
    on<OcptResourcesPersonBirthDateChangedEvent>(_onPersonBirthDateChanged);
    on<OcptResourcesPersonTransportAutonomyChangedEvent>(_onPersonTransportAutonomyChanged);
    on<OcptResourcesPersonImageRightsStatusChangedEvent>(_onPersonImageRightsStatusChanged);
    on<OcptResourcesPersonImageRightsDateChangedEvent>(_onPersonImageRightsDateChanged);
    on<OcptResourcesPositionAddedEvent>(_onPositionAdded);
    on<OcptResourcesPositionUpdatedEvent>(_onPositionUpdated);
    on<OcptResourcesPositionRemovedEvent>(_onPositionRemoved);
    on<OcptResourcesSkillAddedEvent>(_onSkillAdded);
    on<OcptResourcesSkillUpdatedEvent>(_onSkillUpdated);
    on<OcptResourcesSkillRemovedEvent>(_onSkillRemoved);
    on<OcptResourcesUnavailabilityAddedEvent>(_onUnavailabilityAdded);
    on<OcptResourcesUnavailabilityUpdatedEvent>(_onUnavailabilityUpdated);
    on<OcptResourcesUnavailabilityRemovedEvent>(_onUnavailabilityRemoved);
    on<OcptResourcesRoleSelectedEvent>(_onRoleSelected);
    on<OcptResourcesRoleCreationRequestedEvent>(_onRoleCreationRequested);
    on<OcptResourcesRoleFieldChangedEvent>(_onRoleFieldChanged);
    on<OcptResourcesRoleCastChangedEvent>(_onRoleCastChanged);
    on<OcptResourcesRoleKindChangedEvent>(_onRoleKindChanged);
    on<OcptResourcesRoleDeletionRequestedEvent>(_onRoleDeletionRequested);
    on<OcptResourcesOrphanedRoleKeptEvent>(_onOrphanedRoleKept);
    on<OcptResourcesPersonSheetOpenRequestedEvent>(_onPersonSheetOpenRequested);
    on<OcptResourcesLocationSelectedEvent>(_onLocationSelected);
    on<OcptResourcesLocationCreationRequestedEvent>(_onLocationCreationRequested);
    on<OcptResourcesLocationDeletionRequestedEvent>(_onLocationDeletionRequested);
    on<OcptResourcesLocationFieldChangedEvent>(_onLocationFieldChanged);
    on<OcptResourcesLocationColorChangedEvent>(_onLocationColorChanged);
    on<OcptResourcesLocationPermitStatusChangedEvent>(_onLocationPermitStatusChanged);
    on<OcptResourcesLocationPermitDateChangedEvent>(_onLocationPermitDateChanged);
    on<OcptResourcesLocationContactChangedEvent>(_onLocationContactChanged);
    on<OcptResourcesSetAddedEvent>(_onSetAdded);
    on<OcptResourcesSetFieldChangedEvent>(_onSetFieldChanged);
    on<OcptResourcesSetRemovedEvent>(_onSetRemoved);
    on<OcptResourcesSetLocationChangedEvent>(_onSetLocationChanged);
    on<OcptResourcesSceneAssignedToSetEvent>(_onSceneAssignedToSet);
    on<OcptResourcesSceneRemovedFromSetEvent>(_onSceneRemovedFromSet);
    on<OcptResourcesLocationPhotoAddRequestedEvent>(_onLocationPhotoAddRequested);
    on<OcptResourcesPersonPhotoPickRequestedEvent>(_onPersonPhotoPickRequested);
    on<OcptResourcesPersonPhotoClearedEvent>(_onPersonPhotoCleared);
    on<OcptResourcesImageRightsDocumentPickRequestedEvent>(_onImageRightsDocumentPickRequested);
    on<OcptResourcesImageRightsDocumentClearedEvent>(_onImageRightsDocumentCleared);
    on<OcptResourcesElementPhotoPickRequestedEvent>(_onElementPhotoPickRequested);
    on<OcptResourcesElementPhotoClearedEvent>(_onElementPhotoCleared);
    on<OcptResourcesPermitDocumentPickRequestedEvent>(_onPermitDocumentPickRequested);
    on<OcptResourcesPermitDocumentClearedEvent>(_onPermitDocumentCleared);
    on<OcptResourcesAssetRemovedEvent>(_onAssetRemoved);
    on<OcptResourcesLocationAvailabilityAddedEvent>(_onLocationAvailabilityAdded);
    on<OcptResourcesLocationAvailabilityUpdatedEvent>(_onLocationAvailabilityUpdated);
    on<OcptResourcesLocationAvailabilityRemovedEvent>(_onLocationAvailabilityRemoved);
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
    on<OcptResourcesXlsxExportRequestedEvent>(_onXlsxExportRequested);
    on<OcptResourcesIoNoticeDismissedEvent>(_onIoNoticeDismissed);
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// Writes whatever field edit is still sitting in the field-edit debounce, so a preview about to
  /// swap the database can't send it into the previewed version instead.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptResourcesState> emitter) =>
      _flushPendingFieldEdits(emitter);

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
          clearPreviewedVersionId: true,
        ),
      );
      return;
    }

    final previewedVersion = project.previewedVersion;
    final snapshot = await _loadSnapshot(project);
    final currencyCode = await _projectsManager.loadCurrentProjectCurrencyCode();

    final revealRequest = _pendingRevealRequest;
    _pendingRevealRequest = null;

    emitter(
      _revealed(
        state.copyWith(
          isLoading: false,
          title: project.name,
          currencyCode: currencyCode ?? ocptDefaultCurrencyCode,
          previewedVersionId: previewedVersion?.id,
          clearPreviewedVersionId: previewedVersion == null,
          snapshot: snapshot,
          clearSelectedPersonId: true,
          clearSelectedRoleId: true,
          clearSelectedLocationId: true,
          clearSelectedElementId: true,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
        ),
        revealRequest,
      ),
    );
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

  /// Reads the whole resources catalogue of [project], joining the four services' own reads into
  /// one [OcptResourcesSnapshot].
  Future<OcptResourcesSnapshot> _loadSnapshot(OcptOpenProjectModel project) async {
    final database = project.database;

    final people = await _peopleService.loadPeople(database: database);
    final roles = await _roleIndexService.loadRoles(
      database: database,
      screenplayId: project.primaryScreenplayId,
    );
    final locations = await _locationsService.loadLocations(database: database);
    final elements = await _elementsService.loadElements(database: database);
    final scenes = await _locationsService.loadScenes(
      database: database,
      screenplayId: project.primaryScreenplayId,
    );

    return OcptResourcesSnapshot.build(
      people: people,
      roles: roles,
      locations: locations,
      elements: elements,
      scenes: scenes,
    );
  }

  /// Leaves the workspace: flushes any pending field edit, closes the current project, and
  /// navigates back to the home page.
  Future<void> _onBackRequested(
    OcptResourcesBackRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);
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

    final snapshot = await _loadSnapshot(project);
    final currencyCode = await _projectsManager.loadCurrentProjectCurrencyCode();

    emitter(
      state.copyWith(snapshot: snapshot, currencyCode: currencyCode ?? ocptDefaultCurrencyCode),
    );
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
    await _flushPendingFieldEdits(emitter);

    final isSameTab = state.activeTab == event.tab;

    emitter(
      state.copyWith(
        activeTab: event.tab,
        clearSelectedPersonId: !isSameTab,
        clearSelectedRoleId: !isSameTab,
        clearSelectedLocationId: !isSameTab,
        clearSelectedElementId: !isSameTab,
        searchQuery: isSameTab ? null : "",
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
    await _flushPendingFieldEdits(emitter);

    final exists = state.people.any((person) => person.id == event.personId);
    if (!exists) {
      return;
    }

    emitter(state.copyWith(selectedPersonId: event.personId));
  }

  /// Creates a new, blank person at the end of the address book, reloads the catalogue and selects
  /// the new person.
  ///
  /// The freshly created person is immediately given an avatar colour derived from their rank in
  /// the address book — `state.peopleCount` read *before* the insert, so the first person is 0,
  /// the second 1, and so on — rather than being left at `people.colorIndex`'s own table default
  /// of 0, which would otherwise make every new person share the same avatar tint.
  /// `OcptPerson.colorIndex` is read back through `ocptCoverageColorAt` wherever a person's avatar
  /// is painted (`OcptPeopleList`, `OcptPersonSheet`), the same way a shot's colour is derived from
  /// its rank within its sequence.
  Future<void> _onPersonCreationRequested(
    OcptResourcesPersonCreationRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final rank = state.peopleCount;
      final personId = await _peopleService.createPerson(database: project.database);
      if (personId == null) {
        // The write was refused (a version is being previewed read-only); the shell already
        // withholds the button that dispatches this event, so this is only ever a race.
        return;
      }

      await _peopleService.updatePerson(
        database: project.database,
        personId: personId,
        colorIndex: Value(rank),
      );

      final snapshot = await _loadSnapshot(project);
      emitter(state.copyWith(snapshot: snapshot, selectedPersonId: personId));
    } catch (error) {
      appLogger().e("A problem occurred when tried to create a person in the project at "
          "${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Erases person `event.personId`, clearing the selection when it was the selected person, and
  /// dropping any pending field edit that still targeted it (the person it would have written to
  /// no longer holds any personal data).
  Future<void> _onPersonDeletionRequested(
    OcptResourcesPersonDeletionRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final pendingWithoutPerson = Map<(String, OcptPersonField), String>.of(
      state.pendingFieldEdits,
    )..removeWhere((key, _) => key.$1 == event.personId);
    _cancelFieldEditTimerIfIdle(
      pendingPersonEdits: pendingWithoutPerson,
      pendingRoleEdits: state.pendingRoleFieldEdits,
      pendingLocationEdits: state.pendingLocationFieldEdits,
      pendingSetEdits: state.pendingSetFieldEdits,
      pendingElementEdits: state.pendingElementFieldEdits,
    );

    final wasSelected = state.selectedPersonId == event.personId;

    try {
      await _peopleService.deletePerson(database: project.database, personId: event.personId);
      final snapshot = await _loadSnapshot(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          pendingFieldEdits: pendingWithoutPerson,
          clearSelectedPersonId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to erase person ${event.personId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Records the raw text just typed into `event.field` of person `event.personId` as a pending
  /// edit, visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onPersonFieldChanged(
    OcptResourcesPersonFieldChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final pending = Map<(String, OcptPersonField), String>.of(state.pendingFieldEdits)
      ..[(event.personId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingFieldEdits: pending));

    _restartFieldEditTimer();
  }

  /// Records the raw text just typed into `event.field` of role `event.roleId` as a pending edit,
  /// visible immediately, and (re)starts the same field-edit debounce
  /// `_onPersonFieldChanged` does: a person's and a role's pending edits are always flushed
  /// together, by the very same timer.
  Future<void> _onRoleFieldChanged(
    OcptResourcesRoleFieldChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final pending = Map<(String, OcptRoleField), String>.of(state.pendingRoleFieldEdits)
      ..[(event.roleId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingRoleFieldEdits: pending));

    _restartFieldEditTimer();
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
  /// timer is shared by all five maps: cancelling it on the strength of one map having emptied
  /// would strand whatever the other four still hold until the next keystroke.
  void _cancelFieldEditTimerIfIdle({
    required Map<(String, OcptPersonField), String> pendingPersonEdits,
    required Map<(String, OcptRoleField), String> pendingRoleEdits,
    required Map<(String, OcptLocationField), String> pendingLocationEdits,
    required Map<(String, OcptSetField), String> pendingSetEdits,
    required Map<(String, OcptElementField), String> pendingElementEdits,
  }) {
    if (pendingPersonEdits.isEmpty &&
        pendingRoleEdits.isEmpty &&
        pendingLocationEdits.isEmpty &&
        pendingSetEdits.isEmpty &&
        pendingElementEdits.isEmpty) {
      _fieldEditTimer?.cancel();
      _fieldEditTimer = null;
    }
  }

  /// Writes every pending field edit once the field-edit debounce elapses with no further typing.
  Future<void> _onFieldEditFlushRequested(
    OcptResourcesFieldEditFlushRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _flushPendingFieldEdits(emitter);

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it
  /// already fired or there was none), writes every person field edit through
  /// each sheet's own service — `OcptPeopleService.updatePerson`, `OcptRoleIndexService.updateRole`,
  /// `OcptLocationsService.updateLocation`/`.updateSet` and `OcptElementsService.updateElement` —
  /// then reloads the snapshot so every derived aggregate reflects what the database now says. A
  /// no-op while nothing of any kind is pending.
  ///
  /// Used from inside an event handler, with that handler's own [emitter]: called by
  /// [_onFieldEditFlushRequested] (the debounce firing), and up front by every handler that
  /// changes which record, or which tab, is selected, or that leaves the workspace, so a pending
  /// edit is never silently dropped by a selection change. [flushPendingFieldEdits] is the sibling of
  /// this method used outside of an event handler.
  Future<void> _flushPendingFieldEdits(Emitter<OcptResourcesState> emitter) async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pendingPersonEdits = state.pendingFieldEdits;
    final pendingRoleEdits = state.pendingRoleFieldEdits;
    final pendingLocationEdits = state.pendingLocationFieldEdits;
    final pendingSetEdits = state.pendingSetFieldEdits;
    final pendingElementEdits = state.pendingElementFieldEdits;
    if (pendingPersonEdits.isEmpty &&
        pendingRoleEdits.isEmpty &&
        pendingLocationEdits.isEmpty &&
        pendingSetEdits.isEmpty &&
        pendingElementEdits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(
        pendingFieldEdits: const {},
        pendingRoleFieldEdits: const {},
        pendingLocationFieldEdits: const {},
        pendingSetFieldEdits: const {},
        pendingElementFieldEdits: const {},
      ));
      return;
    }

    try {
      await _writeAllPendingFields(database: project.database, pending: pendingPersonEdits);
      await _writeAllPendingRoleFields(database: project.database, pending: pendingRoleEdits);
      await _writeAllPendingLocationFields(
        database: project.database,
        pending: pendingLocationEdits,
      );
      await _writeAllPendingSetFields(database: project.database, pending: pendingSetEdits);
      await _writeAllPendingElementFields(
        database: project.database,
        pending: pendingElementEdits,
      );
      final snapshot = await _loadSnapshot(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          pendingFieldEdits: const {},
          pendingRoleFieldEdits: const {},
          pendingLocationFieldEdits: const {},
          pendingSetFieldEdits: const {},
          pendingElementFieldEdits: const {},
        ),
      );

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a field edit landing while the tab showing it is already open.
      if (state.rightDockTab == OcptResourcesRightDockTab.versions) {
        add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      }
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending resources field edit of "
          "the project at ${project.path}: $error");
      emitter(
        state.copyWith(
          hasWriteError: true,
          pendingFieldEdits: const {},
          pendingRoleFieldEdits: const {},
          pendingLocationFieldEdits: const {},
          pendingSetFieldEdits: const {},
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
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pendingPersonEdits = state.pendingFieldEdits;
    final pendingRoleEdits = state.pendingRoleFieldEdits;
    final pendingLocationEdits = state.pendingLocationFieldEdits;
    final pendingSetEdits = state.pendingSetFieldEdits;
    final pendingElementEdits = state.pendingElementFieldEdits;
    if (pendingPersonEdits.isEmpty &&
        pendingRoleEdits.isEmpty &&
        pendingLocationEdits.isEmpty &&
        pendingSetEdits.isEmpty &&
        pendingElementEdits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _writeAllPendingFields(database: project.database, pending: pendingPersonEdits);
      await _writeAllPendingRoleFields(database: project.database, pending: pendingRoleEdits);
      await _writeAllPendingLocationFields(
        database: project.database,
        pending: pendingLocationEdits,
      );
      await _writeAllPendingSetFields(database: project.database, pending: pendingSetEdits);
      await _writeAllPendingElementFields(
        database: project.database,
        pending: pendingElementEdits,
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending resources field edit of "
          "the project at ${project.path}: $error");
    }
  }

  /// Writes every entry of [pending] through [_writeField].
  Future<void> _writeAllPendingFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptPersonField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (personId, field) = entry.key;
      await _writeField(database: database, personId: personId, field: field, rawValue: entry.value);
    }
  }

  /// Writes a single field edit through `OcptPeopleService.updatePerson`, translating [field] into
  /// the matching named argument (see `OcptPersonField`'s own doc comment for the mapping).
  Future<void> _writeField({
    required OcptProjectDatabase database,
    required String personId,
    required OcptPersonField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptPersonField.firstName:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          firstName: Value(rawValue),
        );
      case OcptPersonField.lastName:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          lastName: Value(rawValue),
        );
      case OcptPersonField.email:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          email: Value(rawValue),
        );
      case OcptPersonField.phone:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          phone: Value(rawValue),
        );
      case OcptPersonField.addressLine1:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          addressLine1: Value(rawValue),
        );
      case OcptPersonField.addressLine2:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          addressLine2: Value(rawValue),
        );
      case OcptPersonField.postalCode:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          postalCode: Value(rawValue),
        );
      case OcptPersonField.city:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          city: Value(rawValue),
        );
      case OcptPersonField.region:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          region: Value(rawValue),
        );
      case OcptPersonField.country:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          country: Value(rawValue),
        );
      case OcptPersonField.minorNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          minorNotes: Value(rawValue),
        );
      case OcptPersonField.accommodationNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          accommodationNotes: Value(rawValue),
        );
      case OcptPersonField.travelNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          travelNotes: Value(rawValue),
        );
      case OcptPersonField.dietaryNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          dietaryNotes: Value(rawValue),
        );
      case OcptPersonField.allergies:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          allergies: Value(rawValue),
        );
      case OcptPersonField.measurementHeight:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          measurementHeight: Value(rawValue),
        );
      case OcptPersonField.measurementChest:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          measurementChest: Value(rawValue),
        );
      case OcptPersonField.measurementWaist:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          measurementWaist: Value(rawValue),
        );
      case OcptPersonField.measurementHips:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          measurementHips: Value(rawValue),
        );
      case OcptPersonField.sizeTop:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          sizeTop: Value(rawValue),
        );
      case OcptPersonField.sizeBottom:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          sizeBottom: Value(rawValue),
        );
      case OcptPersonField.sizeShoes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          sizeShoes: Value(rawValue),
        );
      case OcptPersonField.hmcNotes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          hmcNotes: Value(rawValue),
        );
      case OcptPersonField.notes:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          notes: Value(rawValue),
        );
    }
  }

  /// Writes every entry of [pending] through [_writeRoleField].
  Future<void> _writeAllPendingRoleFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptRoleField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (roleId, field) = entry.key;
      await _writeRoleField(database: database, roleId: roleId, field: field, rawValue: entry.value);
    }
  }

  /// Writes a single role field edit through `OcptRoleIndexService.updateRole`, translating
  /// [field] into the matching named argument (see `OcptRoleField`'s own doc comment for the
  /// mapping).
  ///
  /// Writes [rawValue] as-is even for an `isFromScreenplay` role's [OcptRoleField.name]: the
  /// widgets are what withhold that field from being typed into in the first place, since
  /// `OcptRoleIndexService.reconcile` would overwrite it right back on the next save.
  Future<void> _writeRoleField({
    required OcptProjectDatabase database,
    required String roleId,
    required OcptRoleField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptRoleField.name:
        await _roleIndexService.updateRole(database: database, roleId: roleId, name: Value(rawValue));
      case OcptRoleField.castingNotes:
        await _roleIndexService.updateRole(
          database: database,
          roleId: roleId,
          castingNotes: Value(rawValue),
        );
    }
  }

  /// Writes every entry of [pending] through [_writeLocationField].
  Future<void> _writeAllPendingLocationFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptLocationField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (locationId, field) = entry.key;
      await _writeLocationField(
        database: database,
        locationId: locationId,
        field: field,
        rawValue: entry.value,
      );
    }
  }

  /// Writes a single location field edit through `OcptLocationsService.updateLocation`, translating
  /// [field] into the matching named argument (see `OcptLocationField`'s own doc comment for the
  /// mapping).
  ///
  /// The two coordinate fields are the only ones not written as typed: what cannot be read as a
  /// number is written as null rather than refused, so a half-typed `48.` costs nothing and a
  /// cleared field clears the coordinate. Saying so is the sheet's job, not this one's.
  Future<void> _writeLocationField({
    required OcptProjectDatabase database,
    required String locationId,
    required OcptLocationField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptLocationField.name:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          name: Value(rawValue),
        );
      case OcptLocationField.addressLine1:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          addressLine1: Value(rawValue),
        );
      case OcptLocationField.addressLine2:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          addressLine2: Value(rawValue),
        );
      case OcptLocationField.postalCode:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          postalCode: Value(rawValue),
        );
      case OcptLocationField.city:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          city: Value(rawValue),
        );
      case OcptLocationField.region:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          region: Value(rawValue),
        );
      case OcptLocationField.country:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          country: Value(rawValue),
        );
      case OcptLocationField.latitude:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          latitude: Value(double.tryParse(rawValue.trim())),
        );
      case OcptLocationField.longitude:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          longitude: Value(double.tryParse(rawValue.trim())),
        );
      case OcptLocationField.contactNotes:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          contactNotes: Value(rawValue),
        );
      case OcptLocationField.permitLabel:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          permitLabel: Value(rawValue),
        );
      case OcptLocationField.parkingNotes:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          parkingNotes: Value(rawValue),
        );
      case OcptLocationField.powerNotes:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          powerNotes: Value(rawValue),
        );
      case OcptLocationField.facilitiesNotes:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          facilitiesNotes: Value(rawValue),
        );
      case OcptLocationField.constraintsNotes:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          constraintsNotes: Value(rawValue),
        );
      case OcptLocationField.notes:
        await _locationsService.updateLocation(
          database: database,
          locationId: locationId,
          notes: Value(rawValue),
        );
    }
  }

  /// Writes every entry of [pending] through [_writeSetField].
  Future<void> _writeAllPendingSetFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptSetField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (setId, field) = entry.key;
      await _writeSetField(
        database: database,
        setId: setId,
        field: field,
        rawValue: entry.value,
      );
    }
  }

  /// Writes a single set field edit through `OcptLocationsService.updateSet`, translating [field]
  /// into the matching named argument (see `OcptSetField`'s own doc comment for the mapping).
  Future<void> _writeSetField({
    required OcptProjectDatabase database,
    required String setId,
    required OcptSetField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptSetField.name:
        await _locationsService.updateSet(
          database: database,
          setId: setId,
          name: Value(rawValue),
        );
      case OcptSetField.notes:
        await _locationsService.updateSet(
          database: database,
          setId: setId,
          notes: Value(rawValue),
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

  /// Sets person `event.personId`'s avatar colour index, written immediately.
  Future<void> _onPersonColorChanged(
    OcptResourcesPersonColorChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the colour of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      colorIndex: Value(event.colorIndex),
    ),
  );

  /// Sets person `event.personId`'s date of birth, written immediately.
  Future<void> _onPersonBirthDateChanged(
    OcptResourcesPersonBirthDateChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the date of birth of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      birthDate: Value(event.date),
    ),
  );

  /// Sets whether person `event.personId` can travel to set on their own, written immediately.
  Future<void> _onPersonTransportAutonomyChanged(
    OcptResourcesPersonTransportAutonomyChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the transport autonomy of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      isTransportAutonomous: Value(event.isTransportAutonomous),
    ),
  );

  /// Sets person `event.personId`'s image rights status, written immediately.
  Future<void> _onPersonImageRightsStatusChanged(
    OcptResourcesPersonImageRightsStatusChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the image rights status of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      imageRightsStatus: Value(event.status),
    ),
  );

  /// Sets the date person `event.personId`'s image rights status last changed, written
  /// immediately.
  Future<void> _onPersonImageRightsDateChanged(
    OcptResourcesPersonImageRightsDateChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the image rights date of person ${event.personId}",
    action: (project) => _peopleService.updatePerson(
      database: project.database,
      personId: event.personId,
      imageRightsDate: Value(event.date),
    ),
  );

  /// Adds a crew position assignment to person `event.personId`, written immediately.
  Future<void> _onPositionAdded(
    OcptResourcesPositionAddedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "add a position to person ${event.personId}",
    action: (project) async {
      await _peopleService.addPosition(
        database: project.database,
        personId: event.personId,
        positionId: event.positionId,
        customLabel: event.customLabel,
      );
    },
  );

  /// Updates position assignment `event.id`, written immediately.
  Future<void> _onPositionUpdated(
    OcptResourcesPositionUpdatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "update position ${event.id}",
    action: (project) => _peopleService.updatePosition(
      database: project.database,
      id: event.id,
      positionId: Value(event.positionId),
      customLabel: Value(event.customLabel),
    ),
  );

  /// Removes position assignment `event.id`, written immediately.
  Future<void> _onPositionRemoved(
    OcptResourcesPositionRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "remove position ${event.id}",
    action: (project) =>
        _peopleService.removePosition(database: project.database, id: event.id),
  );

  /// Adds a skill to person `event.personId`, written immediately.
  Future<void> _onSkillAdded(
    OcptResourcesSkillAddedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "add a skill to person ${event.personId}",
    action: (project) async {
      await _peopleService.addSkill(
        database: project.database,
        personId: event.personId,
        label: event.label,
      );
    },
  );

  /// Updates skill `event.id`'s label, written immediately.
  Future<void> _onSkillUpdated(
    OcptResourcesSkillUpdatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "update skill ${event.id}",
    action: (project) =>
        _peopleService.updateSkill(database: project.database, id: event.id, label: event.label),
  );

  /// Removes skill `event.id`, written immediately.
  Future<void> _onSkillRemoved(
    OcptResourcesSkillRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "remove skill ${event.id}",
    action: (project) => _peopleService.removeSkill(database: project.database, id: event.id),
  );

  /// Adds an unavailability to person `event.personId`, written immediately.
  Future<void> _onUnavailabilityAdded(
    OcptResourcesUnavailabilityAddedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "add an unavailability to person ${event.personId}",
    action: (project) async {
      await _peopleService.addUnavailability(
        database: project.database,
        personId: event.personId,
        startDate: event.startDate,
        endDate: event.endDate,
        slot: event.slot,
        startMinute: event.startMinute,
        endMinute: event.endMinute,
        reason: event.reason,
      );
    },
  );

  /// Updates unavailability `event.id`, written immediately.
  Future<void> _onUnavailabilityUpdated(
    OcptResourcesUnavailabilityUpdatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "update unavailability ${event.id}",
    action: (project) => _peopleService.updateUnavailability(
      database: project.database,
      id: event.id,
      startDate: Value(event.startDate),
      endDate: Value(event.endDate),
      slot: Value(event.slot),
      startMinute: Value(event.startMinute),
      endMinute: Value(event.endMinute),
      reason: Value(event.reason),
    ),
  );

  /// Removes unavailability `event.id`, written immediately.
  Future<void> _onUnavailabilityRemoved(
    OcptResourcesUnavailabilityRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "remove unavailability ${event.id}",
    action: (project) =>
        _peopleService.removeUnavailability(database: project.database, id: event.id),
  );

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
    await _flushPendingFieldEdits(emitter);

    final exists = state.roles.any((role) => role.id == event.roleId);
    if (!exists) {
      return;
    }

    emitter(state.copyWith(selectedRoleId: event.roleId));
  }

  /// Adds a hand-added role of `event.kind` at the end of the cast, reloads the catalogue and
  /// selects the new role so it can be named straight away.
  Future<void> _onRoleCreationRequested(
    OcptResourcesRoleCreationRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final roleId = await _roleIndexService.addRole(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        name: "",
        kind: event.kind,
      );
      if (roleId == null) {
        // The write was refused (a version is being previewed read-only); the shell already
        // withholds the button that dispatches this event, so this is only ever a race.
        return;
      }

      final snapshot = await _loadSnapshot(project);
      emitter(state.copyWith(snapshot: snapshot, selectedRoleId: roleId));
    } catch (error) {
      appLogger().e("A problem occurred when tried to create a role in the project at "
          "${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Casts `event.personId` to role `event.roleId` (or uncasts it, when null), written
  /// immediately.
  Future<void> _onRoleCastChanged(
    OcptResourcesRoleCastChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "cast a person to role ${event.roleId}",
    action: (project) => _roleIndexService.updateRole(
      database: project.database,
      roleId: event.roleId,
      personId: Value(event.personId),
    ),
  );

  /// Sets role `event.roleId`'s kind, written immediately.
  Future<void> _onRoleKindChanged(
    OcptResourcesRoleKindChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the kind of role ${event.roleId}",
    action: (project) => _roleIndexService.updateRole(
      database: project.database,
      roleId: event.roleId,
      kind: Value(event.kind),
    ),
  );

  /// Deletes role `event.roleId`, clearing the selection when it was the selected role, and
  /// dropping any pending field edit that still targeted it.
  Future<void> _onRoleDeletionRequested(
    OcptResourcesRoleDeletionRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final pendingWithoutRole = Map<(String, OcptRoleField), String>.of(
      state.pendingRoleFieldEdits,
    )..removeWhere((key, _) => key.$1 == event.roleId);
    _cancelFieldEditTimerIfIdle(
      pendingPersonEdits: state.pendingFieldEdits,
      pendingRoleEdits: pendingWithoutRole,
      pendingLocationEdits: state.pendingLocationFieldEdits,
      pendingSetEdits: state.pendingSetFieldEdits,
      pendingElementEdits: state.pendingElementFieldEdits,
    );

    final wasSelected = state.selectedRoleId == event.roleId;

    try {
      await _roleIndexService.deleteRole(database: project.database, roleId: event.roleId);
      final snapshot = await _loadSnapshot(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          pendingRoleFieldEdits: pendingWithoutRole,
          clearSelectedRoleId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete role ${event.roleId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// The removed-role banner's "keep it" action for role `event.roleId`, written immediately.
  Future<void> _onOrphanedRoleKept(
    OcptResourcesOrphanedRoleKeptEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "keep orphaned role ${event.roleId} as silent",
    action: (project) =>
        _roleIndexService.keepOrphanedRoleAsSilent(database: project.database, roleId: event.roleId),
  );

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
    await _flushPendingFieldEdits(emitter);

    emitter(
      state.copyWith(
        activeTab: OcptResourcesTab.people,
        selectedPersonId: event.personId,
        clearSelectedRoleId: true,
        clearSelectedLocationId: true,
        clearSelectedElementId: true,
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
    await _flushPendingFieldEdits(emitter);

    final exists = state.locations.any((location) => location.id == event.locationId);
    if (!exists) {
      return;
    }

    emitter(state.copyWith(selectedLocationId: event.locationId));
  }

  /// Creates a new, blank location at the end of the list, reloads the catalogue and selects it.
  ///
  /// It is given a colour derived from its rank — `state.locationCount` read *before* the insert —
  /// for the reason `_onPersonCreationRequested` gives: the column's own default of 0 would make
  /// every location share one colour bar, and the bar is how a location is told apart in a list of
  /// names that all start with "La maison…".
  Future<void> _onLocationCreationRequested(
    OcptResourcesLocationCreationRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final rank = state.locationCount;
      final locationId = await _locationsService.createLocation(
        database: project.database,
        name: "",
      );
      if (locationId == null) {
        // The write was refused (a version is being previewed read-only); the shell already
        // withholds the button that dispatches this event, so this is only ever a race.
        return;
      }

      await _locationsService.updateLocation(
        database: project.database,
        locationId: locationId,
        colorIndex: Value(rank),
      );

      final snapshot = await _loadSnapshot(project);
      emitter(state.copyWith(snapshot: snapshot, selectedLocationId: locationId));
    } catch (error) {
      appLogger().e("A problem occurred when tried to create a location in the project at "
          "${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Deletes location `event.locationId`, clearing the selection when it was the selected one, and
  /// dropping any pending field edit that still targeted it or one of its sets — the rows those
  /// edits would have written to are gone.
  Future<void> _onLocationDeletionRequested(
    OcptResourcesLocationDeletionRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final setIds = {
      for (final location in state.locations)
        if (location.id == event.locationId)
          for (final set in location.sets) set.id,
    };

    final pendingWithoutLocation = Map<(String, OcptLocationField), String>.of(
      state.pendingLocationFieldEdits,
    )..removeWhere((key, _) => key.$1 == event.locationId);
    final pendingWithoutSets = Map<(String, OcptSetField), String>.of(state.pendingSetFieldEdits)
      ..removeWhere((key, _) => setIds.contains(key.$1));
    _cancelFieldEditTimerIfIdle(
      pendingPersonEdits: state.pendingFieldEdits,
      pendingRoleEdits: state.pendingRoleFieldEdits,
      pendingLocationEdits: pendingWithoutLocation,
      pendingSetEdits: pendingWithoutSets,
      pendingElementEdits: state.pendingElementFieldEdits,
    );

    final wasSelected = state.selectedLocationId == event.locationId;

    try {
      await _locationsService.deleteLocation(
        database: project.database,
        locationId: event.locationId,
      );
      final snapshot = await _loadSnapshot(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          pendingLocationFieldEdits: pendingWithoutLocation,
          pendingSetFieldEdits: pendingWithoutSets,
          clearSelectedLocationId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete location ${event.locationId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Records the raw text just typed into `event.field` of location `event.locationId` as a pending
  /// edit, visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onLocationFieldChanged(
    OcptResourcesLocationFieldChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final pending = Map<(String, OcptLocationField), String>.of(state.pendingLocationFieldEdits)
      ..[(event.locationId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingLocationFieldEdits: pending));

    _restartFieldEditTimer();
  }

  /// Records the raw text just typed into `event.field` of set `event.setId` as a pending edit,
  /// visible immediately, and (re)starts the same field-edit debounce every other typed field of
  /// the mode rides.
  Future<void> _onSetFieldChanged(
    OcptResourcesSetFieldChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final pending = Map<(String, OcptSetField), String>.of(state.pendingSetFieldEdits)
      ..[(event.setId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingSetFieldEdits: pending));

    _restartFieldEditTimer();
  }

  /// Sets location `event.locationId`'s colour index, written immediately.
  Future<void> _onLocationColorChanged(
    OcptResourcesLocationColorChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the colour of location ${event.locationId}",
    action: (project) => _locationsService.updateLocation(
      database: project.database,
      locationId: event.locationId,
      colorIndex: Value(event.colorIndex),
    ),
  );

  /// Sets location `event.locationId`'s filming permit status, written immediately.
  Future<void> _onLocationPermitStatusChanged(
    OcptResourcesLocationPermitStatusChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the permit status of location ${event.locationId}",
    action: (project) => _locationsService.updateLocation(
      database: project.database,
      locationId: event.locationId,
      permitStatus: Value(event.status),
    ),
  );

  /// Sets the date location `event.locationId`'s permit status last changed, written immediately.
  Future<void> _onLocationPermitDateChanged(
    OcptResourcesLocationPermitDateChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the permit date of location ${event.locationId}",
    action: (project) => _locationsService.updateLocation(
      database: project.database,
      locationId: event.locationId,
      permitDate: Value(event.date),
    ),
  );

  /// Sets who to contact about location `event.locationId`, written immediately.
  Future<void> _onLocationContactChanged(
    OcptResourcesLocationContactChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "change the contact of location ${event.locationId}",
    action: (project) => _locationsService.updateLocation(
      database: project.database,
      locationId: event.locationId,
      contactPersonId: Value(event.personId),
    ),
  );

  /// Adds a new, blank set at the end of location `event.locationId`'s sets, written immediately.
  Future<void> _onSetAdded(
    OcptResourcesSetAddedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "add a set to location ${event.locationId}",
    action: (project) async {
      await _locationsService.createSet(
        database: project.database,
        locationId: event.locationId,
        name: "",
      );
    },
  );

  /// Removes set `event.setId`, written immediately, dropping any pending edit that still targeted
  /// it.
  Future<void> _onSetRemoved(
    OcptResourcesSetRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final pendingWithoutSet = Map<(String, OcptSetField), String>.of(state.pendingSetFieldEdits)
      ..removeWhere((key, _) => key.$1 == event.setId);
    _cancelFieldEditTimerIfIdle(
      pendingPersonEdits: state.pendingFieldEdits,
      pendingRoleEdits: state.pendingRoleFieldEdits,
      pendingLocationEdits: state.pendingLocationFieldEdits,
      pendingSetEdits: pendingWithoutSet,
      pendingElementEdits: state.pendingElementFieldEdits,
    );

    emitter(state.copyWith(pendingSetFieldEdits: pendingWithoutSet));

    await _writeCatalogueChange(
      emitter: emitter,
      logContext: "remove set ${event.setId}",
      action: (project) => _locationsService.deleteSet(
        database: project.database,
        setId: event.setId,
      ),
    );
  }

  /// Moves set `event.setId` to location `event.locationId`, written immediately. The set leaves
  /// the sheet currently shown, which is what the reloaded snapshot then says.
  Future<void> _onSetLocationChanged(
    OcptResourcesSetLocationChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "move set ${event.setId} to location ${event.locationId}",
    action: (project) => _locationsService.moveSetToLocation(
      database: project.database,
      setId: event.setId,
      locationId: event.locationId,
    ),
  );

  /// Says scene `event.sceneId` is shot in set `event.setId`, written immediately.
  Future<void> _onSceneAssignedToSet(
    OcptResourcesSceneAssignedToSetEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "assign scene ${event.sceneId} to set ${event.setId}",
    action: (project) async {
      await _locationsService.assignSceneToSet(
        database: project.database,
        sceneId: event.sceneId,
        setId: event.setId,
      );
    },
  );

  /// Says scene `event.sceneId` is no longer shot in set `event.setId`, written immediately.
  Future<void> _onSceneRemovedFromSet(
    OcptResourcesSceneRemovedFromSetEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "remove scene ${event.sceneId} from set ${event.setId}",
    action: (project) => _locationsService.removeSceneFromSet(
      database: project.database,
      sceneId: event.sceneId,
      setId: event.setId,
    ),
  );

  /// Asks for a scouting photo through the native picker and references the file picked, written
  /// immediately. A cancelled dialog changes nothing at all.
  Future<void> _onLocationPhotoAddRequested(
    OcptResourcesLocationPhotoAddRequestedEvent event,
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
      logContext: "reference a scouting photo of location ${event.locationId}",
      action: (project) async {
        await _locationsService.addLocationPhoto(
          database: project.database,
          locationId: event.locationId,
          path: path,
        );
      },
    );
  }

  /// Asks for person `event.personId`'s photo through the native picker and references the file
  /// picked, written immediately. A cancelled dialog leaves the photo already referenced alone.
  Future<void> _onPersonPhotoPickRequested(
    OcptResourcesPersonPhotoPickRequestedEvent event,
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
      logContext: "reference the photo of person ${event.personId}",
      action: (project) async {
        await _peopleService.setPersonPhoto(
          database: project.database,
          personId: event.personId,
          path: path,
        );
      },
    );
  }

  /// Drops person `event.personId`'s reference to their photo, written immediately.
  Future<void> _onPersonPhotoCleared(
    OcptResourcesPersonPhotoClearedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "drop the photo of person ${event.personId}",
    action: (project) =>
        _peopleService.clearPersonPhoto(database: project.database, personId: event.personId),
  );

  /// Asks for person `event.personId`'s signed image rights release through the native picker and
  /// references the file picked, written immediately. A cancelled dialog leaves the document
  /// already referenced alone, and neither outcome touches `imageRightsStatus`.
  Future<void> _onImageRightsDocumentPickRequested(
    OcptResourcesImageRightsDocumentPickRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final path = await _pickFilePath(
      allowedExtensions: ocptDocumentFileExtensions,
      fileTypeLabel: event.fileTypeLabel,
    );
    if (path == null) {
      return;
    }

    await _writeCatalogueChange(
      emitter: emitter,
      logContext: "reference the image rights document of person ${event.personId}",
      action: (project) async {
        await _peopleService.setImageRightsDocument(
          database: project.database,
          personId: event.personId,
          path: path,
        );
      },
    );
  }

  /// Drops person `event.personId`'s reference to their signed image rights release, written
  /// immediately.
  Future<void> _onImageRightsDocumentCleared(
    OcptResourcesImageRightsDocumentClearedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "drop the image rights document of person ${event.personId}",
    action: (project) => _peopleService.clearImageRightsDocument(
      database: project.database,
      personId: event.personId,
    ),
  );

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

  /// Asks for the filming permit document through the native picker and references the file picked,
  /// written immediately. A cancelled dialog leaves the document already referenced alone.
  Future<void> _onPermitDocumentPickRequested(
    OcptResourcesPermitDocumentPickRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    final path = await _pickFilePath(
      allowedExtensions: ocptDocumentFileExtensions,
      fileTypeLabel: event.fileTypeLabel,
    );
    if (path == null) {
      return;
    }

    await _writeCatalogueChange(
      emitter: emitter,
      logContext: "reference the permit document of location ${event.locationId}",
      action: (project) async {
        await _locationsService.setPermitDocument(
          database: project.database,
          locationId: event.locationId,
          path: path,
        );
      },
    );
  }

  /// Drops location `event.locationId`'s reference to its permit document, written immediately.
  Future<void> _onPermitDocumentCleared(
    OcptResourcesPermitDocumentClearedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "drop the permit document of location ${event.locationId}",
    action: (project) => _locationsService.clearPermitDocument(
      database: project.database,
      locationId: event.locationId,
    ),
  );

  /// Drops the asset reference `event.assetId`, written immediately.
  Future<void> _onAssetRemoved(
    OcptResourcesAssetRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "drop the asset reference ${event.assetId}",
    action: (project) =>
        _assetsService.removeAsset(database: project.database, assetId: event.assetId),
  );

  /// Adds an availability window to location `event.locationId`, written immediately.
  Future<void> _onLocationAvailabilityAdded(
    OcptResourcesLocationAvailabilityAddedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "add an availability window to location ${event.locationId}",
    action: (project) async {
      await _locationsService.addAvailability(
        database: project.database,
        locationId: event.locationId,
        startDate: event.startDate,
        endDate: event.endDate,
        weekdays: event.weekdays,
        slot: event.slot,
        startMinute: event.startMinute,
        endMinute: event.endMinute,
        kind: event.kind,
        note: event.note,
      );
    },
  );

  /// Updates availability window `event.id`, written immediately.
  Future<void> _onLocationAvailabilityUpdated(
    OcptResourcesLocationAvailabilityUpdatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "update the availability window ${event.id}",
    action: (project) => _locationsService.updateAvailability(
      database: project.database,
      id: event.id,
      startDate: Value(event.startDate),
      endDate: Value(event.endDate),
      weekdays: Value(event.weekdays),
      slot: Value(event.slot),
      startMinute: Value(event.startMinute),
      endMinute: Value(event.endMinute),
      kind: Value(event.kind),
      note: Value(event.note),
    ),
  );

  /// Removes availability window `event.id`, written immediately.
  Future<void> _onLocationAvailabilityRemoved(
    OcptResourcesLocationAvailabilityRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writeCatalogueChange(
    emitter: emitter,
    logContext: "remove the availability window ${event.id}",
    action: (project) =>
        _locationsService.removeAvailability(database: project.database, id: event.id),
  );

  /// Shows the native "open" dialog and returns the path of the file picked, or null when the user
  /// cancelled it, when it failed, or when the platform gave a file with no path at all.
  ///
  /// **The file itself is never read here** (see `docs/adr/0013-binary-assets-referenced-by-path.md`)
  /// — unlike an import, which is exactly why this goes to [FileSelectorManager] directly rather
  /// than through `OcptExportManager`: there is nothing to decode, only a path to keep.
  Future<String?> _pickFilePath({
    required List<String> allowedExtensions,
    required String fileTypeLabel,
  }) async {
    final fileSelectorManager =
        _fileSelectorManager ?? globalGetIt().get<FileSelectorManager>();

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
    } catch (error) {
      appLogger().e("A problem occurred when tried to $logContext of the project at "
          "${project.path}: $error");
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
    await _flushPendingFieldEdits(emitter);

    final exists = state.elements.any((element) => element.id == event.elementId);
    if (!exists) {
      return;
    }

    emitter(state.copyWith(selectedElementId: event.elementId));
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
    await _flushPendingFieldEdits(emitter);

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
      emitter(state.copyWith(snapshot: snapshot, selectedElementId: elementId));
    } catch (error) {
      appLogger().e("A problem occurred when tried to create an element in the project at "
          "${project.path}: $error");
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
    _cancelFieldEditTimerIfIdle(
      pendingPersonEdits: state.pendingFieldEdits,
      pendingRoleEdits: state.pendingRoleFieldEdits,
      pendingLocationEdits: state.pendingLocationFieldEdits,
      pendingSetEdits: state.pendingSetFieldEdits,
      pendingElementEdits: pendingWithoutElement,
    );

    final wasSelected = state.selectedElementId == event.elementId;

    try {
      await _elementsService.deleteElement(database: project.database, elementId: event.elementId);
      final snapshot = await _loadSnapshot(project);
      emitter(
        state.copyWith(
          snapshot: snapshot,
          pendingElementFieldEdits: pendingWithoutElement,
          clearSelectedElementId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete element ${event.elementId} of the "
          "project at ${project.path}: $error");
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
    await _flushPendingFieldEdits(emitter);

    emitter(
      state.copyWith(
        activeTab: OcptResourcesTab.roles,
        selectedRoleId: event.roleId,
        clearSelectedPersonId: true,
        clearSelectedLocationId: true,
        clearSelectedElementId: true,
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
      state.copyWith(rightDockTab: isAlreadyActive ? null : event.tab, clearRightDockTab: isAlreadyActive),
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
      emitter(state.copyWith(clearRightDockTab: true));
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
    emitter(state.copyWith(clearRightDockTab: true));
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

  /// Dismisses the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptResourcesWriteErrorDismissedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(hasWriteError: false));
  }

  /// Exports the whole resources catalogue to a four-sheet XLSX workbook.
  ///
  /// Flushes every pending field edit first — that flush re-reads the snapshot, so the workbook
  /// holds the value the user typed seconds ago rather than the one the database held before it —
  /// then hands what the state now carries to [OcptExportManager.exportResourcesXlsx], mirroring
  /// `OcptShotListBloc._onXlsxExportRequested`. A cancelled save dialog is a silent no-op; a
  /// failure raises the transient export-failed notice.
  Future<void> _onXlsxExportRequested(
    OcptResourcesXlsxExportRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    final project = _projectsManager.currentProject;
    if (snapshot == null || project == null) {
      return;
    }

    try {
      final path = await _exportManager.exportResourcesXlsx(
        snapshot: snapshot,
        labels: event.labels,
        projectName: state.title,
        fileTypeLabel: event.fileTypeLabel,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptResourcesIoNotice(
            kind: OcptResourcesIoNoticeKind.xlsxExportSucceeded,
            path: path,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the resources catalogue of the "
          "project at ${project.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptResourcesIoNotice(kind: OcptResourcesIoNoticeKind.xlsxExportFailed),
        ),
      );
    }
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptResourcesIoNoticeDismissedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(clearIoNotice: true));
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
