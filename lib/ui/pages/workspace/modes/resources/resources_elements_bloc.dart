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
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_cost_amount.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_tracking_flag.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';

/// This is the bloc class for the resources mode's elements tab: the element sheet, its scene
/// links and the role links the role sheet adds.
///
/// The catalogue is the mode's data, in `OcptResourcesState.snapshot`, and which element is
/// selected is the mode's too. This bloc owns what the element sheet does with them: every write
/// (the service, then `await modeBloc.reload(…)` for the snapshot, and only then the selection of
/// the element it created) and the edits typed into the element's free-text fields and not yet
/// written ([OcptResourcesElementsState.pendingElementFieldEdits]), which it writes
/// [OcptResourcesBloc.defaultFieldEditDebounce] after the last keystroke, on a timer of its own;
/// the mode flushes them ahead of anything that needs the database to be up to date.
///
/// An element's category, provenance, owner, bringer, tracking flags, photo, scene links and role
/// links are written the moment they change. The role links are written here although the role
/// sheet is where they are added: the row is a link onto an element, written by
/// `OcptElementsService`, and the sheets only ever read it back. Referencing a file is a native
/// dialog and a path, with no bytes to read: see [_pickFilePath].
///
/// **Failing.** A write that fails raises the mode's write error (`OcptResourcesWriteFailedEvent`).
/// A flush that fails drops every edit typed into **any** sheet, not only this one's, through
/// `OcptResourcesPendingEditsLostEvent`: the mode shows the one error, and every view reacts by
/// emptying what it holds ([onModeStateChanged]).
class OcptResourcesElementsBloc
    extends AbsOcptViewBloc<OcptResourcesElementsState, OcptResourcesState, OcptResourcesBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "resources_elements_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read, and write, the physical elements catalogue.
  final OcptElementsService _elementsService;

  /// The manager used to show the native "open" dialog when a photo is referenced, or null to
  /// resolve it through [globalGetIt] the first time one actually is.
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
  OcptResourcesElementsBloc({
    required OcptResourcesBloc modeBloc,
    OcptProjectsManager? projectsManager,
    OcptElementsService? elementsService,
    FileSelectorManager? fileSelectorManager,
    Duration fieldEditDebounce = OcptResourcesBloc.defaultFieldEditDebounce,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       _fileSelectorManager = fileSelectorManager,
       _fieldEditDebounce = fieldEditDebounce,
       _lastLostEditsEpoch = modeBloc.state.lostEditsEpoch,
       super(const OcptResourcesElementsState.init(), modeBloc: modeBloc);

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptResourcesElementCreationRequestedEvent>(_onElementCreationRequested);
    on<OcptResourcesElementDeletionRequestedEvent>(_onElementDeletionRequested);
    on<OcptResourcesElementFieldChangedEvent>(_onElementFieldChanged);
    on<OcptResourcesElementsFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
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
    on<OcptResourcesElementPhotoPickRequestedEvent>(_onElementPhotoPickRequested);
    on<OcptResourcesElementPhotoClearedEvent>(_onElementPhotoCleared);
  }

  /// Drops the edits this bloc holds when the mode says writing them failed somewhere (see
  /// `OcptResourcesPendingEditsLostEvent`): the fields fall back to the stored values.
  ///
  /// Nothing else is scoped to the selection or to the data here: a pending edit survives the user
  /// selecting another element, since it is written by its own debounce or by the flush the
  /// selection starts, and the mode reading the catalogue again after a write changes nothing about
  /// what was typed. Waits for nothing, as the mode's change and this reaction must land in the
  /// same turn of the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptResourcesState> event,
    Emitter<OcptResourcesElementsState> emitter,
  ) async {
    final lostEditsEpoch = event.modeState.lostEditsEpoch;
    if (lostEditsEpoch <= _lastLostEditsEpoch) {
      return;
    }

    _lastLostEditsEpoch = lostEditsEpoch;
    cancelDebounce();
    if (state.pendingElementFieldEdits.isNotEmpty) {
      emitter(state.copyWithFieldEditsCleared());
    }
  }

  /// Creates a new, blank element of `event.category` at the end of the catalogue, reads the
  /// catalogue again and selects the new element so it can be named straight away.
  ///
  /// Unlike a person or a location, it is given no colour of its own: an element is told apart in a
  /// list by the category heading it sits under and by its code, and the palette is what a person,
  /// a location and a shot already share.
  ///
  /// Writes whatever is pending first, so adding an element right after typing never loses it.
  Future<void> _onElementCreationRequested(
    OcptResourcesElementCreationRequestedEvent event,
    Emitter<OcptResourcesElementsState> emitter,
  ) async {
    if (!await modeBloc.flushAllPendingWrites()) {
      return;
    }

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
      // The write was refused (a version is being previewed read-only); the shell already
      // withholds the button that dispatches this event, so this is only ever a race.
      if (elementId != null) {
        if (await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
          await addToModeAndWait(
            OcptResourcesRecordCreatedEvent(tab: OcptResourcesTab.elements, recordId: elementId),
          );
        }
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to create an element in project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// Deletes element `event.elementId`, clearing the selection when it was the selected one, and
  /// dropping any pending field edit that still targeted it.
  Future<void> _onElementDeletionRequested(
    OcptResourcesElementDeletionRequestedEvent event,
    Emitter<OcptResourcesElementsState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    if (_pendingWithoutElement(event.elementId).isEmpty) {
      cancelDebounce();
    }

    try {
      await _elementsService.deleteElement(database: project.database, elementId: event.elementId);
      if (await modeBloc.reload({OcptResourcesReloadScope.snapshot})) {
        emitter(
          state.copyWithElementDeleted(
            pendingElementFieldEdits: _pendingWithoutElement(event.elementId),
          ),
        );
        await addToModeAndWait(
          OcptResourcesRecordDroppedEvent(
            tab: OcptResourcesTab.elements,
            recordId: event.elementId,
          ),
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to delete element ${event.elementId} of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      addToMode(const OcptResourcesWriteFailedEvent());
    }
  }

  /// The pending element field edits of this bloc without those that target element [elementId].
  Map<(String, OcptElementField), String> _pendingWithoutElement(String elementId) =>
      Map<(String, OcptElementField), String>.of(state.pendingElementFieldEdits)
        ..removeWhere((key, _) => key.$1 == elementId);

  /// Records the raw text just typed into `event.field` of element `event.elementId` as a pending
  /// edit, visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onElementFieldChanged(
    OcptResourcesElementFieldChangedEvent event,
    Emitter<OcptResourcesElementsState> emitter,
  ) async {
    final pending = Map<(String, OcptElementField), String>.of(state.pendingElementFieldEdits)
      ..[(event.elementId, event.field)] = event.rawValue;
    emitter(state.copyWithFieldEditTyped(pendingElementFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptResourcesElementsFieldEditFlushRequestedEvent());
  }

  /// Fired by the field-edit debounce timer: writes every pending field edit.
  Future<void> _onFieldEditFlushRequested(
    OcptResourcesElementsFieldEditFlushRequestedEvent event,
    Emitter<OcptResourcesElementsState> emitter,
  ) async {
    await onFlushRequested(emitter);
  }

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it already
  /// fired or there was none), writes each one through `OcptElementsService.updateElement`, then
  /// has the mode read the catalogue again so every derived aggregate reflects what the database
  /// now says, and only then forgets what it wrote, so what a field shows never falls back to a
  /// stale stored value between the two. A no-op while nothing is pending. Answers whether there
  /// was anything pending.
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
  Future<bool> onFlushRequested(Emitter<OcptResourcesElementsState> emitter) async {
    cancelDebounce();

    final pending = state.pendingElementFieldEdits;
    if (pending.isEmpty) {
      return false;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithFieldEditsCleared());
      return true;
    }

    var isWritten = false;
    try {
      await _writeAllPendingElementFields(database: project.database, pending: pending);
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
        pendingElementFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingElementFieldEdits,
          written: pending,
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
  /// This bloc empties its own map as well, for the mode that is closing and no longer answers.
  Future<void> _loseEdits(Emitter<OcptResourcesElementsState> emitter) async {
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

    final pending = state.pendingElementFieldEdits;
    if (pending.isEmpty) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await flushEditsWithoutState(
        pending,
        (edits) => _writeAllPendingElementFields(database: project.database, pending: edits),
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

  /// Writes a discrete change to the elements catalogue through [action] and has the mode read the
  /// catalogue again, so every derived aggregate (the roles an element concerns, the status bar's
  /// counts) reflects what the database now says. A no-op while no project is open; a failure
  /// raises the mode's write error.
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

  /// Sets element `event.elementId`'s category, written immediately.
  Future<void> _onElementCategoryChanged(
    OcptResourcesElementCategoryChangedEvent event,
    Emitter<OcptResourcesElementsState> emitter,
  ) async {
    await _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "remove the scene ↔ element link ${event.id}",
    action: (project) =>
        _elementsService.removeSceneElement(database: project.database, id: event.id),
  );

  /// Links role `event.roleId` to element `event.elementId`, written immediately.
  Future<void> _onElementLinkedToRole(
    OcptResourcesElementLinkedToRoleEvent event,
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "remove the role ↔ element link ${event.id}",
    action: (project) =>
        _elementsService.removeRoleElement(database: project.database, id: event.id),
  );

  /// Asks for element `event.elementId`'s photo through the native picker and references the file
  /// picked, written immediately. A cancelled dialog leaves the photo already referenced alone.
  Future<void> _onElementPhotoPickRequested(
    OcptResourcesElementPhotoPickRequestedEvent event,
    Emitter<OcptResourcesElementsState> emitter,
  ) async {
    final path = await _pickFilePath(
      allowedExtensions: ocptImageFileExtensions,
      fileTypeLabel: event.fileTypeLabel,
    );
    if (path == null) {
      return;
    }

    await _writeCatalogueChange(
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
    Emitter<OcptResourcesElementsState> emitter,
  ) => _writeCatalogueChange(
    logContext: "drop the photo of element ${event.elementId}",
    action: (project) =>
        _elementsService.clearElementPhoto(database: project.database, elementId: event.elementId),
  );

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
}
