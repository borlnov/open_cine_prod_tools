// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart' show useResult;
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_breakdown_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_elements_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_locations_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_pending_edits.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_reload_scope.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_selection_cause.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_pending_writes_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_inspector_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/breakdown_state.dart';

/// This is the bloc class for the breakdown mode's inspector: the selected scene's own sheet and
/// the selected target's, with every write either offers.
///
/// The snapshot, and which scene and which target are selected, are the mode's. This bloc owns what
/// the two sheets do with them: every write (the service, then `await modeBloc.reload(…)` for the
/// snapshot the write changed, since a status, a category or a link feeds the left dock's rows, the
/// script's colours, the legend and the counters, which must be read back from the database rather
/// than patched in place) and the edits typed and not yet written
/// ([OcptBreakdownInspectorState]), which it writes [OcptBreakdownBloc.defaultFieldEditDebounce]
/// after the last keystroke, on a timer of its own; the mode flushes them ahead of anything that
/// needs the database to be up to date. A single pick (a status, a category, an owner, a link, a
/// tag removal) is written at once by its own event rather than typed.
///
/// **Reacting.** A scene or a target being selected clears nothing here, and a pending edit
/// survives the user moving on: it is written by its own debounce or by the flush the selection
/// starts. When the mode reads everything again (entry, a version preview, a restore) every pending
/// edit is dropped, as the mode itself did before the inspector had a bloc of its own, since the
/// database underneath may be another one. An ordinary re-read after a write clears nothing.
///
/// A flush that fails is only logged, by the service that failed: the edits are dropped and the
/// action behind the flush (a selection, a preview, an export) goes ahead on the value the
/// database holds, as it always did.
class OcptBreakdownInspectorBloc
    extends AbsOcptViewBloc<OcptBreakdownInspectorState, OcptBreakdownState, OcptBreakdownBloc> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "breakdown_inspector_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to write a scene's breakdown sheet and to remove or check a tag.
  final OcptBreakdownService _breakdownService;

  /// The service used to write the selected target's own fields.
  final OcptElementsService _elementsService;

  /// The service used to link a scene to a set, to create one and to rename one.
  final OcptLocationsService _locationsService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// {@template open_cine_prod_tools.viewBlocConstructorWithDebounce}
  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do; in the app they
  /// all resolve through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by
  /// tests, to keep it fast and deterministic.
  /// {@endtemplate}
  OcptBreakdownInspectorBloc({
    required super.modeBloc,
    OcptProjectsManager? projectsManager,
    OcptBreakdownService? breakdownService,
    OcptElementsService? elementsService,
    OcptLocationsService? locationsService,
    Duration fieldEditDebounce = OcptBreakdownBloc.defaultFieldEditDebounce,
  }) : _logger = buildOcptLogsHelper(_loggerCategory),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _breakdownService =
           breakdownService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).breakdownService,
       _elementsService =
           elementsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).elementsService,
       _locationsService =
           locationsService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).locationsService,
       _fieldEditDebounce = fieldEditDebounce,
       super(const OcptBreakdownInspectorState.init());

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptBreakdownSceneStatusChangedEvent>(_onSceneStatusChanged);
    on<OcptBreakdownSceneSetLinkedEvent>(_onSceneSetLinked);
    on<OcptBreakdownSceneSetUnlinkedEvent>(_onSceneSetUnlinked);
    on<OcptBreakdownSceneSetCreationRequestedEvent>(_onSceneSetCreationRequested);
    on<OcptBreakdownSceneNotesChangedEvent>(_onSceneNotesChanged);
    on<OcptBreakdownElementStatusChangedEvent>(_onElementStatusChanged);
    on<OcptBreakdownElementCategoryChangedEvent>(_onElementCategoryChanged);
    on<OcptBreakdownElementFieldChangedEvent>(_onElementFieldChanged);
    on<OcptBreakdownSetNameChangedEvent>(_onSetNameChanged);
    on<OcptBreakdownFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptBreakdownElementOwnerChangedEvent>(_onElementOwnerChanged);
    on<OcptBreakdownElementBringerChangedEvent>(_onElementBringerChanged);
    on<OcptBreakdownTagRemovalConfirmedEvent>(_onTagRemovalConfirmed);
    on<OcptBreakdownTagNeedsCheckClearedEvent>(_onTagNeedsCheckCleared);
    on<OcptBreakdownFlaggedTagRemovedEvent>(_onFlaggedTagRemoved);
  }

  /// Drop the edits the mode's fresh read makes meaningless.
  ///
  /// When the mode read everything again (`OcptBreakdownSelectionCause.load`: entry, a version
  /// preview or a restore) every pending edit goes, whichever row it was typed into: the database
  /// underneath may be another one, and the caller flushed first whenever losing an edit would
  /// matter. Nothing else clears anything here: a selection move leaves the edits alone, and an
  /// ordinary re-read after a write only brings newer rows.
  ///
  /// Reads the cause from the state that moved the epoch (`event.modeState`). Waits for nothing:
  /// the mode's change and this reaction must land in the same turn of the event loop.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptBreakdownState> event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final isLoaded =
        event.hasSelectionMoved &&
        event.modeState.selectionCause == OcptBreakdownSelectionCause.load;
    if (!isLoaded) {
      return;
    }

    cancelDebounce();
    if (_hasPendingEdits(state)) {
      emitter(state.copyWithPendingEditsCleared());
    }
  }

  /// Write every pending element field edit, scene notes edit and set rename immediately: cancels
  /// the debounce timer (a no-op if it already fired or there was none), writes each one through
  /// `OcptElementsService.updateElement`/`OcptBreakdownService.updateSceneBreakdown`/
  /// `OcptLocationsService.updateSet`, has the mode read the snapshot again so every derived
  /// aggregate reflects what the database now says, and only then forgets what it wrote, so what a
  /// field shows never falls back to a stale stored value between the two. A no-op while nothing is
  /// pending. Answers `nothingToWrite` when nothing was pending.
  ///
  /// A write that fails is logged by its service and what was meant to be written is forgotten, the
  /// snapshot is not read again, and the flush answers `ok` all the same: the action behind it goes
  /// ahead on the value the database holds. A read that fails after the write landed forgets what
  /// was written too, the mode having logged why it could not read.
  ///
  /// When the write landed and the `Versions` tab is the one showing, also asks the mode to refresh
  /// its working-copy card.
  ///
  /// Called by the debounce firing, and by the mode ahead of every action that needs the database
  /// to be up to date (a selection, a right dock tab change, a tag write, a version preview, an
  /// export).
  @override
  Future<OcptPendingWritesStatus> onFlushRequested(
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    cancelDebounce();

    final pendingElementFields = state.pendingElementFieldEdits;
    final pendingSceneNotes = state.pendingSceneNotesEdits;
    final pendingSetNames = state.pendingSetNameEdits;
    if (!_hasPendingEdits(state)) {
      return OcptPendingWritesStatus.nothingToWrite;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(state.copyWithPendingEditsCleared());
      return OcptPendingWritesStatus.ok;
    }

    final written = await _writeAllPendingFields(
      database: project.database,
      elementFields: pendingElementFields,
      sceneNotes: pendingSceneNotes,
      setNames: pendingSetNames,
    );
    final hasWritten = !written.isError;

    if (hasWritten) {
      await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
    }

    emitter(
      state.copyWithPendingEditsWritten(
        pendingElementFieldEdits: ocptPendingEditsAfterWrite(
          current: state.pendingElementFieldEdits,
          written: pendingElementFields,
        ),
        pendingSceneNotesEdits: ocptPendingEditsAfterWrite(
          current: state.pendingSceneNotesEdits,
          written: pendingSceneNotes,
        ),
        pendingSetNameEdits: ocptPendingEditsAfterWrite(
          current: state.pendingSetNameEdits,
          written: pendingSetNames,
        ),
      ),
    );

    // The other of the two moments the working-copy card needs a fresh read for (see
    // `OcptBreakdownBloc._onRightDockTabSelected`): a field edit landing while the tab showing it
    // is already open.
    if (hasWritten && modeBloc.state.rightDockTab == OcptBreakdownRightDockTab.versions) {
      addToMode(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }

    return OcptPendingWritesStatus.ok;
  }

  /// Write every pending edit directly to the database, bypassing the debounce timer, the bloc's
  /// own event queue and its state.
  ///
  /// Called by the mode's own `deactivate()` (through the flusher this bloc registered):
  /// `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
  /// this whole subtree out, and so does the workspace's own back navigation), so triggering the
  /// write here — rather than dispatching an event, which would only be processed on a later
  /// microtask this widget might not survive to see — is what guarantees the last
  /// [_fieldEditDebounce] worth of typing isn't lost.
  ///
  /// Unlike [onFlushRequested], this never touches [state]: `emit` may only be called from inside
  /// a registered `on<Event>` handler, and by the time this runs the widget tree that would show a
  /// fresh state is already gone anyway. A failure is logged by the service that failed, and
  /// leaves the edits to be written again by the next flush.
  @override
  Future<void> flushPendingWritesWithoutState() async {
    cancelDebounce();

    final pendingElementFields = state.pendingElementFieldEdits;
    final pendingSceneNotes = state.pendingSceneNotesEdits;
    final pendingSetNames = state.pendingSetNameEdits;
    if (!_hasPendingEdits(state)) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final elementsFlushed = await flushEditsWithoutState(
      pendingElementFields,
      (edits) => _writeAllPendingFields(
        database: project.database,
        elementFields: edits,
        sceneNotes: const {},
        setNames: const {},
      ),
    );
    // A flush that failed stops the ones after it, as the exception it used to raise did.
    if (elementsFlushed.isError) {
      return;
    }

    final notesFlushed = await flushEditsWithoutState(
      pendingSceneNotes,
      (edits) => _writeAllPendingFields(
        database: project.database,
        elementFields: const {},
        sceneNotes: edits,
        setNames: const {},
      ),
    );
    if (notesFlushed.isError) {
      return;
    }

    final _ = await flushEditsWithoutState(
      pendingSetNames,
      (edits) => _writeAllPendingFields(
        database: project.database,
        elementFields: const {},
        sceneNotes: const {},
        setNames: edits,
      ),
    );
  }

  /// Tell whether [inspectorState] holds a typed edit of any of the three kinds.
  bool _hasPendingEdits(OcptBreakdownInspectorState inspectorState) =>
      inspectorState.pendingElementFieldEdits.isNotEmpty ||
      inspectorState.pendingSceneNotesEdits.isNotEmpty ||
      inspectorState.pendingSetNameEdits.isNotEmpty;

  /// Write the selected scene's new breakdown status immediately — a single pick, not typing, so it
  /// rides no debounce — then have the mode read the snapshot again: a scene's status feeds the
  /// left dock's own rows, the scene inspector's chips and the snapshot's `doneSceneCount`, all of
  /// which must be read back from the database rather than patched in place, exactly as an
  /// element's status or category change already is.
  Future<void> _onSceneStatusChanged(
    OcptBreakdownSceneStatusChangedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _breakdownService.updateSceneBreakdown(
      database: project.database,
      sceneId: event.sceneId,
      status: Value(event.status),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Say scene `event.sceneId` is shot in set `event.setId`, written immediately through the very
  /// service the resources mode writes that link with, then have the mode read the snapshot again —
  /// the sets a scene is shot in are read off `OcptSet.sceneIds`, so the row has to come back from
  /// the database.
  ///
  /// Writes no tag: linking a scene to a set is a fact about the scene, not a passage of the
  /// script.
  Future<void> _onSceneSetLinked(
    OcptBreakdownSceneSetLinkedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final linked = await _locationsService.assignSceneToSet(
      database: project.database,
      sceneId: event.sceneId,
      setId: event.setId,
    );
    if (linked.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Create a set named `event.name` — inside `event.locationId`, or inside a location minted along
  /// with it when that is null — and say scene `event.sceneId` is shot in it, in one write
  /// (`OcptLocationsService.createSetLinkedToScene`), dispatched by the scene inspector's own
  /// `Create a set…` control.
  ///
  /// Writes no tag, exactly as [_onSceneSetLinked] doesn't: this is the sheet naming its décor, not
  /// a passage of the script being tagged. The selection is left where it is for the same reason —
  /// the user is filling in this scene's sheet, and the set they just created is already on it as a
  /// chip.
  Future<void> _onSceneSetCreationRequested(
    OcptBreakdownSceneSetCreationRequestedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null || modeBloc.state.isPreviewingVersion) {
      return;
    }

    final trimmedName = event.name.trim();
    final created = await _locationsService.createSetLinkedToScene(
      database: project.database,
      sceneId: event.sceneId,
      name: trimmedName.isEmpty ? event.name : trimmedName,
      locationId: event.locationId,
    );
    if (created.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Say scene `event.sceneId` is no longer shot in set `event.setId`, the mirror of
  /// [_onSceneSetLinked]. Leaves every tag pointing at that set untouched, for the reason
  /// `OcptBreakdownService.deleteTag` gives from the other side.
  Future<void> _onSceneSetUnlinked(
    OcptBreakdownSceneSetUnlinkedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final unlinked = await _locationsService.removeSceneFromSet(
      database: project.database,
      sceneId: event.sceneId,
      setId: event.setId,
    );
    if (unlinked.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Record the raw text just typed into scene `event.sceneId`'s own breakdown notes as a pending
  /// edit, visible immediately, and (re)starts the same field-edit debounce
  /// [_onElementFieldChanged] does — one debounce timer for the whole inspector.
  Future<void> _onSceneNotesChanged(
    OcptBreakdownSceneNotesChangedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final pending = Map<String, String>.of(state.pendingSceneNotesEdits)
      ..[event.sceneId] = event.rawValue;
    emitter(state.copyWithSceneNotesEditTyped(pendingSceneNotesEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptBreakdownFieldEditFlushRequestedEvent());
  }

  /// Write the selected element's new status immediately — a single pick, not typing, so it rides
  /// no debounce — then have the mode read the snapshot again so the script view's colours, the
  /// legend, the scene panel and the status bar all follow it exactly as they follow a category
  /// change.
  Future<void> _onElementStatusChanged(
    OcptBreakdownElementStatusChangedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      status: Value(event.status),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Write the selected element's new category immediately, then have the mode read the snapshot
  /// again for the same reason [_onElementStatusChanged] does — a category change moves the
  /// element's own colour, so every surface painting it must be redrawn from the database rather
  /// than patched in place.
  Future<void> _onElementCategoryChanged(
    OcptBreakdownElementCategoryChangedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      category: Value(event.category),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Record the raw text just typed into `event.field` of element `event.elementId` as a pending
  /// edit, visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onElementFieldChanged(
    OcptBreakdownElementFieldChangedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final pending = Map<(String, OcptElementField), String>.of(state.pendingElementFieldEdits)
      ..[(event.elementId, event.field)] = event.rawValue;
    emitter(state.copyWithElementFieldEditTyped(pendingElementFieldEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptBreakdownFieldEditFlushRequestedEvent());
  }

  /// Record the raw text just typed into the title of set `event.setId` as a pending rename,
  /// visible immediately, and (re)starts the same field-edit debounce [_onElementFieldChanged]
  /// does.
  Future<void> _onSetNameChanged(
    OcptBreakdownSetNameChangedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final pending = Map<String, String>.of(state.pendingSetNameEdits)
      ..[event.setId] = event.rawValue;
    emitter(state.copyWithSetNameEditTyped(pendingSetNameEdits: pending));

    restartDebounce(_fieldEditDebounce, const OcptBreakdownFieldEditFlushRequestedEvent());
  }

  /// Write every pending edit once the field-edit debounce elapses with no further typing.
  Future<void> _onFieldEditFlushRequested(
    OcptBreakdownFieldEditFlushRequestedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    await onFlushRequested(emitter);
  }

  /// Write every entry of [elementFields] through `OcptElementsService.updateElement`, translating
  /// each (only `name`, `subCategory`, `quantity` and `notes` ever land here — the target
  /// inspector's other fields are single picks written immediately by their own event, see this
  /// bloc's own doc comment) into the matching named argument, then every entry of [sceneNotes]
  /// through `OcptBreakdownService.updateSceneBreakdown`, then every entry of [setNames] through
  /// `OcptLocationsService.updateSet`.
  ///
  /// Stops at the first write that fails and answers its failure; what comes after it is not
  /// written.
  @useResult
  Future<OcptDatabaseOutcome> _writeAllPendingFields({
    required OcptProjectDatabase database,
    required Map<(String, OcptElementField), String> elementFields,
    required Map<String, String> sceneNotes,
    required Map<String, String> setNames,
  }) async {
    for (final entry in elementFields.entries) {
      final (elementId, field) = entry.key;
      final rawValue = entry.value;

      switch (field) {
        case OcptElementField.name:
          final nameWritten = await _elementsService.updateElement(
            database: database,
            elementId: elementId,
            name: Value(rawValue),
          );
          if (nameWritten.isError) {
            return nameWritten;
          }
        case OcptElementField.subCategory:
          final subCategoryWritten = await _elementsService.updateElement(
            database: database,
            elementId: elementId,
            subCategory: Value(rawValue),
          );
          if (subCategoryWritten.isError) {
            return subCategoryWritten;
          }
        case OcptElementField.quantity:
          final quantityWritten = await _elementsService.updateElement(
            database: database,
            elementId: elementId,
            quantity: Value(rawValue),
          );
          if (quantityWritten.isError) {
            return quantityWritten;
          }
        case OcptElementField.notes:
          final notesWritten = await _elementsService.updateElement(
            database: database,
            elementId: elementId,
            notes: Value(rawValue),
          );
          if (notesWritten.isError) {
            return notesWritten;
          }
        case OcptElementField.ownerNotes ||
            OcptElementField.storageNotes ||
            OcptElementField.cost ||
            OcptElementField.purposeNotes:
          _logger.w(
            "The breakdown mode's target inspector never edits OcptElementField.${field.name}; "
            "ignoring the pending edit for element $elementId",
          );
      }
    }

    for (final entry in sceneNotes.entries) {
      final notesWritten = await _breakdownService.updateSceneBreakdown(
        database: database,
        sceneId: entry.key,
        notes: Value(entry.value),
      );
      if (notesWritten.isError) {
        return notesWritten;
      }
    }

    for (final entry in setNames.entries) {
      final namesWritten = await _locationsService.updateSet(
        database: database,
        setId: entry.key,
        name: Value(entry.value),
      );
      if (namesWritten.isError) {
        return namesWritten;
      }
    }

    return const OcptDatabaseOutcome(status: OcptDatabaseStatus.ok);
  }

  /// Write the selected element's new owner immediately — a pick, not typing — then have the mode
  /// read the snapshot again so the inspector shows the newly named person.
  Future<void> _onElementOwnerChanged(
    OcptBreakdownElementOwnerChangedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      ownerPersonId: Value(event.personId),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Write the selected element's new who-brings-it immediately, mirroring
  /// [_onElementOwnerChanged].
  Future<void> _onElementBringerChanged(
    OcptBreakdownElementBringerChangedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final updated = await _elementsService.updateElement(
      database: project.database,
      elementId: event.elementId,
      broughtByPersonId: Value(event.personId),
    );
    if (updated.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Remove the selected target's tags from the selected scene for good — every live tag of
  /// `OcptBreakdownState.selectedTarget` within `OcptBreakdownState.selectedScene`, tombstoned one
  /// by one through `OcptBreakdownService.deleteTag`, which never removes the `scene_elements`/
  /// `scene_sets` link a tag once ensured — see that method's own doc comment: the resources mode
  /// lets a user make that link by hand, and dropping it silently here would destroy work the
  /// breakdown pass never did.
  ///
  /// A no-op when either half of the selection is gone (a stale click on a sheet the snapshot
  /// already rebuilt without it). Has the mode read the snapshot again afterwards: the target may
  /// disappear from it outright if this scene held its only tag.
  Future<void> _onTagRemovalConfirmed(
    OcptBreakdownTagRemovalConfirmedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final modeState = modeBloc.state;
    final target = modeState.selectedTarget;
    final scene = modeState.selectedScene;
    if (project == null || target == null || scene == null) {
      return;
    }

    final tagIds = [
      for (final tag in scene.tags)
        if (tag.targetKind == target.kind && tag.targetId == target.id) tag.id,
    ];
    for (final tagId in tagIds) {
      final deleted = await _breakdownService.deleteTag(database: project.database, tagId: tagId);
      if (deleted.isError) {
        return;
      }
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Clear tag `event.tagId`'s own `needsCheck` flag through
  /// `OcptBreakdownService.clearTagNeedsCheck`, then have the mode read the snapshot again: the
  /// flag
  /// feeds the scene panel's own warning mark and the status bar's "to check" counter, both of
  /// which must be read back from the database rather than patched in place.
  ///
  /// A no-op while no project is open, mirroring [_onTagRemovalConfirmed]'s own defensive check.
  Future<void> _onTagNeedsCheckCleared(
    OcptBreakdownTagNeedsCheckClearedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final cleared = await _breakdownService.clearTagNeedsCheck(
      database: project.database,
      tagId: event.tagId,
    );
    if (cleared.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }

  /// Remove tag `event.tagId` for good through `OcptBreakdownService.deleteTag`, then have the mode
  /// read the snapshot again, mirroring [_onTagNeedsCheckCleared] in every respect but the write it
  /// performs.
  ///
  /// A no-op while no project is open, mirroring [_onTagRemovalConfirmed]'s own defensive check.
  Future<void> _onFlaggedTagRemoved(
    OcptBreakdownFlaggedTagRemovedEvent event,
    Emitter<OcptBreakdownInspectorState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final deleted = await _breakdownService.deleteTag(
      database: project.database,
      tagId: event.tagId,
    );
    if (deleted.isError) {
      return;
    }

    await modeBloc.reload({OcptBreakdownReloadScope.snapshot});
  }
}
