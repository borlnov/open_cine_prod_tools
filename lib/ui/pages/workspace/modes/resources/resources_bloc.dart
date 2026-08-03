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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_people_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_role_index_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_person_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the resources production mode (the address book, the cast, locations
/// and the physical elements catalogue).
///
/// It loads the current project's whole catalogue from [_peopleService], [_roleIndexService],
/// [_locationsService] and [_elementsService] on entry, combining the four reads into one
/// [OcptResourcesSnapshot] — the same "one read of everything, joined in memory" shape
/// `OcptShotListBloc` builds its own snapshot with — and holds the active tab, the selected person,
/// the dock geometry and the pending field edits on top of it.
///
/// This milestone only gives the [OcptResourcesTab.people] tab real content: [OcptResourcesTab.roles],
/// [OcptResourcesTab.locations] and [OcptResourcesTab.elements] are read (their counts already feed
/// the status bar) but nothing here yet creates, edits or deletes a role, a location or an element.
///
/// Most of a person's discrete fields (colour, birth date, transport autonomy, image rights status
/// and date) and every sub-list (positions, skills, unavailabilities) are written to the project
/// database the moment they change, exactly like a shot's difficulty axis or its character chips
/// are. The sheet's typed free-text fields ([OcptPersonField]) are the exception: an edit is held
/// in [OcptResourcesState.pendingFieldEdits] and written [defaultFieldEditDebounce] after the last
/// keystroke, mirroring `OcptShotListBloc`'s own autosave convention. The debounce is flushed
/// immediately whenever the selected person or the active tab changes, when the workspace is left,
/// and (through [flushPendingFieldEdits], called by the mode's own `deactivate()`) whenever the
/// mode leaves the widget tree for any other reason, so a pending edit is never silently dropped.
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

  /// The service used to read and write the address book.
  final OcptPeopleService _peopleService;

  /// The service used to read the cast reconciled against the screenplay.
  final OcptRoleIndexService _roleIndexService;

  /// The service used to read locations and their sets.
  final OcptLocationsService _locationsService;

  /// The service used to read the physical elements catalogue.
  final OcptElementsService _elementsService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The running field-edit debounce timer, if any.
  Timer? _fieldEditTimer;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by tests, to keep
  /// it fast and deterministic.
  OcptResourcesBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptPeopleService? peopleService,
    OcptRoleIndexService? roleIndexService,
    OcptLocationsService? locationsService,
    OcptElementsService? elementsService,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
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
    on<OcptResourcesLeftPanelToggledEvent>(_onLeftPanelToggled);
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
  /// the hook's own doc comment). The selected person is always cleared on a (re)load, mirroring
  /// `OcptShotListBloc`'s own selection reset: a preview or a restore changes the whole database
  /// underneath, so a stale selection is dropped rather than trusted to still mean the same thing.
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

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        previewedVersionId: previewedVersion?.id,
        clearPreviewedVersionId: previewedVersion == null,
        snapshot: snapshot,
        clearSelectedPersonId: true,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
      ),
    );
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

    return OcptResourcesSnapshot.build(
      people: people,
      roles: roles,
      locations: locations,
      elements: elements,
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

  /// Selects tab `event.tab`, clearing the selected person when it actually changes tab.
  ///
  /// Flushes any pending field edit first, so switching tabs right after typing never loses it.
  Future<void> _onTabSelected(
    OcptResourcesTabSelectedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final isSameTab = state.activeTab == event.tab;

    emitter(state.copyWith(activeTab: event.tab, clearSelectedPersonId: !isSameTab));
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
    if (pendingWithoutPerson.isEmpty) {
      _fieldEditTimer?.cancel();
      _fieldEditTimer = null;
    }

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

    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptResourcesFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Writes every pending field edit once the field-edit debounce elapses with no further typing.
  Future<void> _onFieldEditFlushRequested(
    OcptResourcesFieldEditFlushRequestedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _flushPendingFieldEdits(emitter);

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it
  /// already fired or there was none), writes each one through
  /// `OcptPeopleService.updatePerson`, then reloads the snapshot so every derived aggregate
  /// reflects what the database now says. A no-op while nothing is pending.
  ///
  /// Used from inside an event handler, with that handler's own [emitter]: called by
  /// [_onFieldEditFlushRequested] (the debounce firing), and up front by every handler that
  /// changes what person or tab is selected, or that leaves the workspace, so a pending edit is
  /// never silently dropped by a selection change. [flushPendingFieldEdits] is the sibling of this
  /// method used outside of an event handler.
  Future<void> _flushPendingFieldEdits(Emitter<OcptResourcesState> emitter) async {
    _fieldEditTimer?.cancel();
    _fieldEditTimer = null;

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWith(pendingFieldEdits: const {}));
      return;
    }

    try {
      await _writeAllPendingFields(database: project.database, pending: pending);
      final snapshot = await _loadSnapshot(project);
      emitter(state.copyWith(snapshot: snapshot, pendingFieldEdits: const {}));

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a field edit landing while the tab showing it is already open.
      if (state.rightDockTab == OcptResourcesRightDockTab.versions) {
        add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      }
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending resources field edit of "
          "the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true, pendingFieldEdits: const {}));
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

    final pending = state.pendingFieldEdits;
    if (pending.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _writeAllPendingFields(database: project.database, pending: pending);
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
      case OcptPersonField.address:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          address: Value(rawValue),
        );
      case OcptPersonField.city:
        await _peopleService.updatePerson(
          database: database,
          personId: personId,
          city: Value(rawValue),
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

  /// Sets person `event.personId`'s avatar colour index, written immediately.
  Future<void> _onPersonColorChanged(
    OcptResourcesPersonColorChangedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writePersonChange(
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
  ) => _writePersonChange(
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
  ) => _writePersonChange(
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
  ) => _writePersonChange(
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
  ) => _writePersonChange(
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
  ) => _writePersonChange(
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
  ) => _writePersonChange(
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
  ) => _writePersonChange(
    emitter: emitter,
    logContext: "remove position ${event.id}",
    action: (project) =>
        _peopleService.removePosition(database: project.database, id: event.id),
  );

  /// Adds a skill to person `event.personId`, written immediately.
  Future<void> _onSkillAdded(
    OcptResourcesSkillAddedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writePersonChange(
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
  ) => _writePersonChange(
    emitter: emitter,
    logContext: "update skill ${event.id}",
    action: (project) =>
        _peopleService.updateSkill(database: project.database, id: event.id, label: event.label),
  );

  /// Removes skill `event.id`, written immediately.
  Future<void> _onSkillRemoved(
    OcptResourcesSkillRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writePersonChange(
    emitter: emitter,
    logContext: "remove skill ${event.id}",
    action: (project) => _peopleService.removeSkill(database: project.database, id: event.id),
  );

  /// Adds an unavailability to person `event.personId`, written immediately.
  Future<void> _onUnavailabilityAdded(
    OcptResourcesUnavailabilityAddedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writePersonChange(
    emitter: emitter,
    logContext: "add an unavailability to person ${event.personId}",
    action: (project) async {
      await _peopleService.addUnavailability(
        database: project.database,
        personId: event.personId,
        date: event.date,
        halfDay: event.halfDay,
        reason: event.reason,
      );
    },
  );

  /// Updates unavailability `event.id`, written immediately.
  Future<void> _onUnavailabilityUpdated(
    OcptResourcesUnavailabilityUpdatedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writePersonChange(
    emitter: emitter,
    logContext: "update unavailability ${event.id}",
    action: (project) => _peopleService.updateUnavailability(
      database: project.database,
      id: event.id,
      date: Value(event.date),
      halfDay: Value(event.halfDay),
      reason: Value(event.reason),
    ),
  );

  /// Removes unavailability `event.id`, written immediately.
  Future<void> _onUnavailabilityRemoved(
    OcptResourcesUnavailabilityRemovedEvent event,
    Emitter<OcptResourcesState> emitter,
  ) => _writePersonChange(
    emitter: emitter,
    logContext: "remove unavailability ${event.id}",
    action: (project) =>
        _peopleService.removeUnavailability(database: project.database, id: event.id),
  );

  /// Writes a discrete person-related change through [action] and reloads the snapshot, so every
  /// derived aggregate (a person's positions summary, the status bar's position count) reflects
  /// what the database now says. Mirrors `OcptShotListBloc`'s own `_writeCoverageChange` shape,
  /// shared by every discrete field, position, skill and unavailability write of this bloc. A
  /// no-op while no project is open.
  Future<void> _writePersonChange({
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

  /// Toggles the left (list) dock's visibility.
  Future<void> _onLeftPanelToggled(
    OcptResourcesLeftPanelToggledEvent event,
    Emitter<OcptResourcesState> emitter,
  ) async {
    emitter(state.copyWith(isListPanelVisible: !state.isListPanelVisible));
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
