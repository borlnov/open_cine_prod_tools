// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/constants/ocpt_asset_file_types.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_assets_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_location_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_set_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';

/// This is the bloc class for the resources mode's locations tab: the location sheet and its sets
/// card.
///
/// The catalogue is the mode's data, in `OcptResourcesState.snapshot`, and which location is
/// selected is the mode's too. This bloc owns what the location sheet does with them: every write
/// (the service, then `await modeBloc.reload(…)` for the snapshot, and only then the selection of
/// the location it created) and the edits typed into the location's fields and into each of its
/// sets' name and notes and not yet written ([OcptResourcesLocationsState]), which it writes
/// [OcptResourcesBloc.defaultFieldEditDebounce] after the last keystroke, on a timer of its own
/// shared by the two maps; the mode flushes them ahead of anything that needs the database to be up
/// to date.
///
/// A location's colour, permit status and date, contact, sets, scene links, referenced files and
/// availability windows are written the moment they change. Referencing a file is a native dialog
/// and a path, with no bytes to read: see [_pickFilePath]. The sets card's `Open in shot list`
/// action resolves a cross-mode reveal and stays with the mode.
///
/// **Failing.** A write that fails raises the mode's write error (`OcptResourcesWriteFailedEvent`).
/// A flush that fails drops every edit typed into **any** sheet, not only this one's, through
/// `OcptResourcesPendingEditsLostEvent`: the mode shows the one error, and every view reacts by
/// emptying what it holds ([onModeStateChanged]).
class OcptResourcesLocationsBloc
    extends AbsOcptViewBloc<OcptResourcesLocationsState, OcptResourcesState, OcptResourcesBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "resources_locations_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read, and write, locations and their sets.
  final OcptLocationsService _locationsService;

  /// The service used to drop a file reference, whatever owns it.
  ///
  /// Referencing a file is the owning service's — a location's permit document is
  /// `OcptLocationsService`'s — but dropping one by its id is not: the `⨯` control answers for a
  /// scouting photo exactly as it does for anything else, and having it pick a service by the kind
  /// of the row would be inventing a distinction the row does not make.
  final OcptAssetsService _assetsService;

  /// The manager used to show the native "open" dialog when a photo or a document is referenced,
  /// or null to resolve it through [globalGetIt] the first time one actually is.
  final FileSelectorManager? _fileSelectorManager;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The `lostEditsEpoch` of the mode state this bloc last reacted to.
  int _lastLostEditsEpoch;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by
  /// tests, to keep it fast and deterministic.
  OcptResourcesLocationsBloc({
    required OcptResourcesBloc modeBloc,
    OcptProjectsManager? projectsManager,
    OcptLocationsService? locationsService,
    OcptAssetsService? assetsService,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = OcptResourcesBloc.defaultFieldEditDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _assetsService =
           assetsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).assetsService,
       _fileSelectorManager = fileSelectorManager,
       _fieldEditDebounce = fieldEditDebounce,
       _lastLostEditsEpoch = modeBloc.state.lostEditsEpoch,
       super(const OcptResourcesLocationsState.init(), modeBloc: modeBloc);

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptResourcesLocationCreationRequestedEvent>(_onLocationCreationRequested);
    on<OcptResourcesLocationDeletionRequestedEvent>(_onLocationDeletionRequested);
    on<OcptResourcesLocationFieldChangedEvent>(_onLocationFieldChanged);
    on<OcptResourcesSetFieldChangedEvent>(_onSetFieldChanged);
    on<OcptResourcesSetRemovedEvent>(_onSetRemoved);
    on<OcptResourcesLocationsFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptResourcesLocationColorChangedEvent>(_onLocationColorChanged);
    on<OcptResourcesLocationPermitStatusChangedEvent>(_onLocationPermitStatusChanged);
    on<OcptResourcesLocationPermitDateChangedEvent>(_onLocationPermitDateChanged);
    on<OcptResourcesLocationContactChangedEvent>(_onLocationContactChanged);
    on<OcptResourcesSetAddedEvent>(_onSetAdded);
    on<OcptResourcesSetLocationChangedEvent>(_onSetLocationChanged);
    on<OcptResourcesSceneAssignedToSetEvent>(_onSceneAssignedToSet);
    on<OcptResourcesSceneRemovedFromSetEvent>(_onSceneRemovedFromSet);
    on<OcptResourcesLocationPhotoAddRequestedEvent>(_onLocationPhotoAddRequested);
    on<OcptResourcesPermitDocumentPickRequestedEvent>(_onPermitDocumentPickRequested);
    on<OcptResourcesPermitDocumentClearedEvent>(_onPermitDocumentCleared);
    on<OcptResourcesAssetValidFromChangedEvent>(_onAssetValidFromChanged);
    on<OcptResourcesAssetValidUntilChangedEvent>(_onAssetValidUntilChanged);
    on<OcptResourcesAssetRemovedEvent>(_onAssetRemoved);
    on<OcptResourcesLocationAvailabilityAddedEvent>(_onLocationAvailabilityAdded);
    on<OcptResourcesLocationAvailabilityUpdatedEvent>(_onLocationAvailabilityUpdated);
    on<OcptResourcesLocationAvailabilityRemovedEvent>(_onLocationAvailabilityRemoved);
  }

  /// Drops the edits this bloc holds when the mode says writing them failed somewhere (see
  /// `OcptResourcesPendingEditsLostEvent`): the fields fall back to the stored values.
  ///
  /// Nothing else is scoped to the selection or to the data here: a pending edit survives the user
  /// selecting another location, since it is written by its own debounce or by the flush the
  /// selection starts, and the mode reading the catalogue again after a write changes nothing about
  /// what was typed, a set unlinked from the selected episode included. Waits for nothing, as the
  /// mode's change and this reaction must land in the same turn of the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptResourcesState> event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    final lostEditsEpoch = event.modeState.lostEditsEpoch;
    if (lostEditsEpoch <= _lastLostEditsEpoch) {
      return;
    }

    _lastLostEditsEpoch = lostEditsEpoch;
    cancelDebounce();
    if (state.pendingLocationFieldEdits.isNotEmpty || state.pendingSetFieldEdits.isNotEmpty) {
      emitter(state.copyWithFieldEditsCleared());
    }
  }

  /// Creates a new, blank location at the end of the list, reads the catalogue again and selects
  /// it.
  ///
  /// It is given a colour derived from its rank — `locationCount` read *before* the insert — for
  /// the reason `OcptResourcesPeopleBloc`'s creation gives: the column's own default of 0 would make
  /// every location share one colour bar, and the bar is how a location is told apart in a list of
  /// names that all start with "La maison…".
  ///
  /// Writes whatever is pending first, so adding a location right after typing never loses it.
  Future<void> _onLocationCreationRequested(
    OcptResourcesLocationCreationRequestedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final rank = modeBloc.state.locationCount;
      final locationId = await _locationsService.createLocation(
        database: project.database,
        name: "",
      );
      // The write was refused (a version is being previewed read-only); the shell already
      // withholds the button that dispatches this event, so this is only ever a race.
      if (locationId != null) {
        await _locationsService.updateLocation(
          database: project.database,
          locationId: locationId,
          colorIndex: Value(rank),
        );

        if (await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
          await addToModeAndWait(
            OcptResourcesRecordCreatedEvent(tab: OcptResourcesTab.locations, recordId: locationId),
          );
        }
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to create a location in project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// Deletes location `event.locationId`, clearing the selection when it was the selected one, and
  /// dropping any pending field edit that still targeted it or one of its sets — the rows those
  /// edits would have written to are gone.
  Future<void> _onLocationDeletionRequested(
    OcptResourcesLocationDeletionRequestedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final setIds = {
      for (final location in modeBloc.state.locations)
        if (location.id == event.locationId)
          for (final set in location.sets) set.id,
    };

    if (_pendingLocationsWithout(event.locationId).isEmpty && _pendingSetsWithout(setIds).isEmpty) {
      cancelDebounce();
    }

    try {
      await _locationsService.deleteLocation(
        database: project.database,
        locationId: event.locationId,
      );
      if (await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
        emitter(
          state.copyWithLocationDeleted(
            pendingLocationFieldEdits: _pendingLocationsWithout(event.locationId),
            pendingSetFieldEdits: _pendingSetsWithout(setIds),
          ),
        );
        await addToModeAndWait(
          OcptResourcesRecordDroppedEvent(
            tab: OcptResourcesTab.locations,
            recordId: event.locationId,
          ),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete location ${event.locationId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// The pending location field edits of this bloc without those that target location
  /// [locationId].
  Map<(String, OcptLocationField), String> _pendingLocationsWithout(String locationId) =>
      Map<(String, OcptLocationField), String>.of(state.pendingLocationFieldEdits)
        ..removeWhere((key, _) => key.$1 == locationId);

  /// The pending set field edits of this bloc without those that target one of the sets [setIds].
  Map<(String, OcptSetField), String> _pendingSetsWithout(Set<String> setIds) =>
      Map<(String, OcptSetField), String>.of(state.pendingSetFieldEdits)
        ..removeWhere((key, _) => setIds.contains(key.$1));

  /// Records the raw text just typed into `event.field` of location `event.locationId` as a pending
  /// edit, visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onLocationFieldChanged(
    OcptResourcesLocationFieldChangedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    final pending = Map<(String, OcptLocationField), String>.of(state.pendingLocationFieldEdits)
      ..[(event.locationId, event.field)] = event.rawValue;
    emitter(state.copyWithLocationFieldEditTyped(pendingLocationFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptResourcesLocationsFieldEditFlushRequestedEvent());
  }

  /// Records the raw text just typed into `event.field` of set `event.setId` as a pending edit,
  /// visible immediately, and (re)starts the same field-edit debounce [_onLocationFieldChanged]
  /// does.
  Future<void> _onSetFieldChanged(
    OcptResourcesSetFieldChangedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    final pending = Map<(String, OcptSetField), String>.of(state.pendingSetFieldEdits)
      ..[(event.setId, event.field)] = event.rawValue;
    emitter(state.copyWithSetFieldEditTyped(pendingSetFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptResourcesLocationsFieldEditFlushRequestedEvent());
  }

  /// Removes set `event.setId`, written immediately, dropping any pending edit that still targeted
  /// it first: the edit is forgotten at once, before the write, and the debounce goes on for
  /// whatever else is typed.
  Future<void> _onSetRemoved(
    OcptResourcesSetRemovedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    final pendingWithoutSet = _pendingSetsWithout({event.setId});
    if (pendingWithoutSet.isEmpty && state.pendingLocationFieldEdits.isEmpty) {
      cancelDebounce();
    }

    emitter(state.copyWithSetRemoved(pendingSetFieldEdits: pendingWithoutSet));

    await _writeCatalogueChange(
      logContext: "remove set ${event.setId}",
      action: (project) =>
          _locationsService.deleteSet(database: project.database, setId: event.setId),
    );
  }

  /// Fired by the field-edit debounce timer: writes every pending field edit.
  Future<void> _onFieldEditFlushRequested(
    OcptResourcesLocationsFieldEditFlushRequestedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    await onFlushRequested(emitter);
  }

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each location field through
  /// `OcptLocationsService.updateLocation` and each set field through
  /// `OcptLocationsService.updateSet`, then has the mode read the catalogue again so every derived
  /// aggregate reflects what the database now says, and only then forgets what it wrote, so what a
  /// field shows never falls back to a stale stored value between the two. A no-op while nothing is
  /// pending. Answers whether there was anything pending.
  ///
  /// A write that fails drops **every** edit of the mode and raises the one write error (see
  /// [_loseEdits]); the snapshot is not read again, so the fields show the value they had. A read
  /// after a write that landed which fails only raises the write error: what was written is
  /// forgotten and the other views keep what they hold, to be written in their turn. When the write landed and the `Versions` tab is the one showing, also asks the mode
  /// to refresh its working-copy card.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date.
  @override
  Future<bool> onFlushRequested(Emitter<OcptResourcesLocationsState> emitter) async {
    cancelDebounce();

    final pendingLocationEdits = state.pendingLocationFieldEdits;
    final pendingSetEdits = state.pendingSetFieldEdits;
    if (pendingLocationEdits.isEmpty && pendingSetEdits.isEmpty) {
      return false;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return true;
    }

    var isWritten = false;
    try {
      await _writeAllPendingLocationFields(
        database: project.database,
        pending: pendingLocationEdits,
      );
      await _writeAllPendingSetFields(database: project.database, pending: pendingSetEdits);
      isWritten = true;
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending resources field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      await _loseEdits(emitter);
    }

    if (!isWritten) {
      return true;
    }

    // A read that fails changes nothing here: the write landed, so what was written is forgotten
    // all the same, and the mode has already raised the write error. Dropping the edits of the
    // other views as well would lose what no write failure has touched.
    await modeBloc.reload({OcptResourcesReloadScope.snapshot});

    emitter(
      state.copyWithFieldEditsWritten(
        pendingLocationFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingLocationFieldEdits,
          written: pendingLocationEdits,
        ),
        pendingSetFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingSetFieldEdits,
          written: pendingSetEdits,
        ),
      ),
    );

    // The other of the two moments the working-copy card needs a fresh read for (see
    // `OcptResourcesBloc._onRightDockTabSelected`): a field edit landing while the tab showing it
    // is already open.
    if (modeBloc.state.rightDockTab == OcptResourcesRightDockTab.versions) {
      addToMode(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }

    return true;
  }

  /// Tells the mode that writing the typed edits failed, which raises its write error and makes
  /// every view drop what it holds, this one included; waits for that, so the flush goes on to the
  /// other views with nothing left for them to write.
  ///
  /// This bloc empties its own maps as well, for the mode that is closing and no longer answers.
  Future<void> _loseEdits(Emitter<OcptResourcesLocationsState> emitter) async {
    await addToModeAndWait(const OcptResourcesPendingEditsLostEvent());
    emitter(state.copyWithFieldEditsCleared());
  }

  /// Writes every pending field edit directly to the database, bypassing the debounce timer, the
  /// bloc's own event queue and its state.
  ///
  /// Called by the mode's own `deactivate()` (through the flushers it registered), mirroring
  /// `OcptShotListBloc.flushPendingFieldEdits`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree (a mode switch swaps this whole subtree out, and so does the workspace's
  /// own back navigation), so triggering the write here — rather than dispatching an event, which
  /// would only be processed on a later microtask this widget might not survive to see — is what
  /// guarantees the last [OcptResourcesBloc.defaultFieldEditDebounce] worth of typing isn't lost.
  ///
  /// Unlike [onFlushRequested], this never touches [state]: `emit` may only be called from inside
  /// a registered `on<Event>` handler, and by the time this runs the widget tree that would show a
  /// fresh state is already gone anyway. A failure here is only logged.
  @override
  Future<void> flushPendingWritesWithoutState() async {
    cancelDebounce();

    final pendingLocationEdits = state.pendingLocationFieldEdits;
    final pendingSetEdits = state.pendingSetFieldEdits;
    if (pendingLocationEdits.isEmpty && pendingSetEdits.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await flushEditsWithoutState(
        pendingLocationEdits,
        (edits) => _writeAllPendingLocationFields(database: project.database, pending: edits),
      );
      await flushEditsWithoutState(
        pendingSetEdits,
        (edits) => _writeAllPendingSetFields(database: project.database, pending: edits),
      );
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to flush a pending resources field edit of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
    }
  }

  /// Writes a discrete change to the locations through [action] and has the mode read the
  /// catalogue again, so every derived aggregate (the sets card's lines, the status bar) reflects
  /// what the database now says. A no-op while no project is open; a failure raises the mode's
  /// write error.
  Future<void> _writeCatalogueChange({
    required String logContext,
    required Future<void> Function(OcptOpenProjectModel project) action,
  }) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await action(project);
      await modeBloc.reload({OcptResourcesReloadScope.snapshot});
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to $logContext of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

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

  /// Sets location `event.locationId`'s colour index, written immediately.
  Future<void> _onLocationColorChanged(
    OcptResourcesLocationColorChangedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "add a set to location ${event.locationId}",
    action: (project) async {
      await _locationsService.createSet(
        database: project.database,
        locationId: event.locationId,
        name: "",
      );
    },
  );

  /// Moves set `event.setId` to location `event.locationId`, written immediately. The set leaves
  /// the sheet currently shown, which is what the reloaded snapshot then says.
  Future<void> _onSetLocationChanged(
    OcptResourcesSetLocationChangedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    final path = await _pickFilePath(
      allowedExtensions: ocptImageFileExtensions,
      fileTypeLabel: event.fileTypeLabel,
    );
    if (path == null) {
      return;
    }

    await _writeCatalogueChange(
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

  /// Asks for the filming permit document through the native picker and references the file picked,
  /// written immediately. A cancelled dialog leaves the document already referenced alone.
  Future<void> _onPermitDocumentPickRequested(
    OcptResourcesPermitDocumentPickRequestedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) async {
    final path = await _pickFilePath(
      allowedExtensions: ocptDocumentFileExtensions,
      fileTypeLabel: event.fileTypeLabel,
    );
    if (path == null) {
      return;
    }

    await _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "drop the permit document of location ${event.locationId}",
    action: (project) => _locationsService.clearPermitDocument(
      database: project.database,
      locationId: event.locationId,
    ),
  );

  /// Sets asset `event.assetId`'s "valid from" date, written immediately.
  Future<void> _onAssetValidFromChanged(
    OcptResourcesAssetValidFromChangedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the valid-from date of asset ${event.assetId}",
    action: (project) => _assetsService.updateAssetValidity(
      database: project.database,
      assetId: event.assetId,
      validFrom: Value(event.date),
    ),
  );

  /// Sets asset `event.assetId`'s "valid until" date, written immediately.
  Future<void> _onAssetValidUntilChanged(
    OcptResourcesAssetValidUntilChangedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "change the valid-until date of asset ${event.assetId}",
    action: (project) => _assetsService.updateAssetValidity(
      database: project.database,
      assetId: event.assetId,
      validUntil: Value(event.date),
    ),
  );

  /// Drops the asset reference `event.assetId`, written immediately.
  Future<void> _onAssetRemoved(
    OcptResourcesAssetRemovedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "drop the asset reference ${event.assetId}",
    action: (project) =>
        _assetsService.removeAsset(database: project.database, assetId: event.assetId),
  );

  /// Adds an availability window to location `event.locationId`, written immediately.
  Future<void> _onLocationAvailabilityAdded(
    OcptResourcesLocationAvailabilityAddedEvent event,
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesLocationsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "remove the availability window ${event.id}",
    action: (project) =>
        _locationsService.removeAvailability(database: project.database, id: event.id),
  );

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
      await _writeSetField(database: database, setId: setId, field: field, rawValue: entry.value);
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
        await _locationsService.updateSet(database: database, setId: setId, name: Value(rawValue));
      case OcptSetField.notes:
        await _locationsService.updateSet(database: database, setId: setId, notes: Value(rawValue));
    }
  }
}
