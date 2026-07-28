// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// This is the bloc class for the shot list (découpage technique) production mode.
///
/// It loads the current project's whole shot list from [OcptShotListService] on entry — sequences
/// are built in memory by joining the scene index with the shots referencing it, so the mode
/// always shows the screenplay as it stands rather than a duplicated copy of it — together with
/// the screenplay's speaking characters (for the inspector's character chips) and every free-text
/// field's project-wide suggestion list, and holds the selection, the dock geometry and the
/// visible table columns on top of it.
///
/// Most of a shot's fields are authored one discrete action at a time (picking a status, clicking
/// a difficulty dot, toggling a character chip) and each of those is written to the project
/// database immediately, then the snapshot is re-read so every derived aggregate the UI shows (a
/// sequence's shot count, its average difficulty, a shot's code) stays exactly what the database
/// says. The inspector's typed free-text fields are the exception: an edit is held in
/// [OcptShotListState.pendingFieldEdits] and written [defaultFieldEditDebounce] after the last
/// keystroke, mirroring `OcptEditorBloc`'s own autosave convention. The debounce is flushed
/// immediately whenever the selected shot or sequence changes, when the workspace is left, and
/// (through [flushPendingFieldEdits], called by the mode's own `deactivate()`) whenever the mode
/// leaves the widget tree for any other reason, so a pending edit is never silently dropped.
class OcptShotListBloc extends BlocForMixin<OcptShotListState> {
  /// The default delay between the last field edit and its autosave write.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions, visible columns and last
  /// right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The service used to read and write the shot list.
  final OcptShotListService _shotListService;

  /// The delay between the last field edit and its autosave write.
  final Duration _fieldEditDebounce;

  /// The running field-edit debounce timer, if any.
  Timer? _fieldEditTimer;

  /// Class constructor
  ///
  /// Every dependency can be overridden, which is what the tests do; in the app they all resolve
  /// through [globalGetIt]. [fieldEditDebounce] is only meant to be overridden by tests, to keep
  /// it fast and deterministic.
  OcptShotListBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptShotListService? shotListService,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _shotListService =
           shotListService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotListService,
       _fieldEditDebounce = fieldEditDebounce,
       super(OcptShotListState.init()) {
    add(const OcptShotListLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptShotListLoadRequestedEvent>(_onLoadRequested);
    on<OcptShotListSequenceSelectedEvent>(_onSequenceSelected);
    on<OcptShotListShotSelectedEvent>(_onShotSelected);
    on<OcptShotListShotCreationRequestedEvent>(_onShotCreationRequested);
    on<OcptShotListSequencePanelToggledEvent>(_onSequencePanelToggled);
    on<OcptShotListRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptShotListRightDockToggledEvent>(_onRightDockToggled);
    on<OcptShotListRightDockClosedEvent>(_onRightDockClosed);
    on<OcptShotListDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptShotListDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptShotListColumnToggledEvent>(_onColumnToggled);
    on<OcptShotListWriteErrorDismissedEvent>(_onWriteErrorDismissed);
    on<OcptShotListBackRequestedEvent>(_onBackRequested);
    on<OcptShotListShotFieldChangedEvent>(_onShotFieldChanged);
    on<OcptShotListFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptShotListShotStatusChangedEvent>(_onShotStatusChanged);
    on<OcptShotListShotDifficultyChangedEvent>(_onShotDifficultyChanged);
    on<OcptShotListShotCharacterToggledEvent>(_onShotCharacterToggled);
    on<OcptShotListShotDeletionRequestedEvent>(_onShotDeletionRequested);
  }

  /// Loads the persisted preferences and the current project's shot list, selecting its first
  /// sequence.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
  Future<void> _onLoadRequested(
    OcptShotListLoadRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final leftDockFraction =
        await _propertiesManager.shotListLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.shotListRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;
    final visibleColumns =
        await _propertiesManager.shotListVisibleColumns.load() ??
        OcptShotListColumn.defaultVisibleColumns;
    final lastRightDockTab =
        await _propertiesManager.shotListLastRightDockTab.load() ??
        OcptShotListRightDockTab.inspector;

    final project = _projectsManager.currentProject;
    if (project == null) {
      emitter(
        state.copyWith(
          isLoading: false,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          visibleColumns: visibleColumns,
          lastRightDockTab: lastRightDockTab,
        ),
      );
      return;
    }

    final snapshot = await _loadSnapshot(project);
    final speakingCharacters = await _loadSpeakingCharacters(project);
    final suggestions = await _loadSuggestions(project);

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        snapshot: snapshot,
        selectedSequenceId: snapshot.sequences.isEmpty ? null : snapshot.sequences.first.id,
        clearSelectedSequenceId: snapshot.sequences.isEmpty,
        clearSelectedShotId: true,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        visibleColumns: visibleColumns,
        lastRightDockTab: lastRightDockTab,
        speakingCharacters: speakingCharacters,
        suggestions: suggestions,
      ),
    );
  }

  /// Reads the whole shot list of [project]'s primary screenplay.
  Future<OcptShotListSnapshot> _loadSnapshot(OcptOpenProjectModel project) =>
      _shotListService.loadShotList(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );

  /// Reads the screenplay's speaking characters, parsing its current source text and delegating to
  /// `fountain_kit`'s `speakingCharactersOf`, whose normalisation matches
  /// `shot_characters.characterName`'s own (both go through `normalizeCharacterName`) so a shot's
  /// character and a screenplay's speaking role compare equal byte-for-byte.
  Future<List<String>> _loadSpeakingCharacters(OcptOpenProjectModel project) async {
    final text = await _projectsManager.screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    final document = const FountainParser().parse(text);
    return speakingCharactersOf(document.blocks);
  }

  /// Reads every free-text field's project-wide suggestion list (decision 6 of the shot list
  /// plan).
  Future<OcptShotFieldSuggestions> _loadSuggestions(OcptOpenProjectModel project) async {
    final database = project.database;
    final screenplayId = project.primaryScreenplayId;

    return OcptShotFieldSuggestions(
      shotSizes: await _shotListService.distinctShotSizes(
        database: database,
        screenplayId: screenplayId,
      ),
      framings: await _shotListService.distinctFramings(
        database: database,
        screenplayId: screenplayId,
      ),
      cameraMoves: await _shotListService.distinctCameraMoves(
        database: database,
        screenplayId: screenplayId,
      ),
      lenses: await _shotListService.distinctLenses(
        database: database,
        screenplayId: screenplayId,
      ),
      recordingFormats: await _shotListService.distinctRecordingFormats(
        database: database,
        screenplayId: screenplayId,
      ),
      sounds: await _shotListService.distinctSounds(
        database: database,
        screenplayId: screenplayId,
      ),
    );
  }

  /// Selects a sequence, clearing the selected shot when it actually changes sequence (the centre
  /// table then lists shots the previous selection isn't among).
  ///
  /// Flushes any pending field edit first, so switching sequences right after typing never loses
  /// it.
  Future<void> _onSequenceSelected(
    OcptShotListSequenceSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final isSameSequence = state.selectedSequenceId == event.sequenceId;

    emitter(
      state.copyWith(
        selectedSequenceId: event.sequenceId,
        clearSelectedShotId: !isSameSequence,
      ),
    );
  }

  /// Selects a shot, together with the sequence holding it, and opens the right dock on its
  /// inspector tab.
  ///
  /// Flushes any pending field edit first, so switching shots right after typing never loses it.
  /// A shot id that no longer exists in the current snapshot (a stale click on a list rebuilt
  /// underneath) is ignored rather than selecting nothing.
  Future<void> _onShotSelected(
    OcptShotListShotSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final sequence = _sequenceHolding(event.shotId);
    if (sequence == null) {
      return;
    }

    await _persistLastRightDockTab(OcptShotListRightDockTab.inspector);

    emitter(
      state.copyWith(
        selectedSequenceId: sequence.id,
        selectedShotId: event.shotId,
        rightDockTab: OcptShotListRightDockTab.inspector,
        lastRightDockTab: OcptShotListRightDockTab.inspector,
      ),
    );
  }

  /// The sequence of the current snapshot holding the shot [shotId], or null if no sequence does.
  OcptShotSequence? _sequenceHolding(String shotId) {
    for (final sequence in state.sequences) {
      for (final shot in sequence.shots) {
        if (shot.id == shotId) {
          return sequence;
        }
      }
    }

    return null;
  }

  /// Creates a shot at the end of the selected scene sequence, reloads the shot list and selects
  /// the new shot.
  ///
  /// Deliberately a no-op when the selected sequence is the orphan group (or when nothing is
  /// selected at all): see [OcptShotListShotCreationRequestedEvent].
  Future<void> _onShotCreationRequested(
    OcptShotListShotCreationRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final project = _projectsManager.currentProject;
    final sequence = state.selectedSequence;
    if (project == null || sequence is! OcptSceneShotSequence) {
      return;
    }

    try {
      final shotId = await _shotListService.createShot(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        sceneId: sequence.sceneId,
      );
      final snapshot = await _loadSnapshot(project);

      await _persistLastRightDockTab(OcptShotListRightDockTab.inspector);

      emitter(
        state.copyWith(
          snapshot: snapshot,
          selectedSequenceId: sequence.sceneId,
          selectedShotId: shotId,
          rightDockTab: OcptShotListRightDockTab.inspector,
          lastRightDockTab: OcptShotListRightDockTab.inspector,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to create a shot in the scene "
          "${sequence.sceneId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Toggles the left (sequences) dock's visibility.
  Future<void> _onSequencePanelToggled(
    OcptShotListSequencePanelToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(isSequencePanelVisible: !state.isSequencePanelVisible));
  }

  /// Selects a tab of the right dock (the already-active tab closes the dock, any other one opens
  /// or switches to it) and records it as the tab the toolbar's toggle reopens the dock on.
  Future<void> _onRightDockTabSelected(
    OcptShotListRightDockTabSelectedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final isAlreadyActive = state.rightDockTab == event.tab;
    await _persistLastRightDockTab(event.tab);

    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        clearRightDockTab: isAlreadyActive,
        lastRightDockTab: event.tab,
      ),
    );
  }

  /// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptShotListState.lastRightDockTab].
  Future<void> _onRightDockToggled(
    OcptShotListRightDockToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(
      state.rightDockTab != null
          ? state.copyWith(clearRightDockTab: true)
          : state.copyWith(rightDockTab: state.lastRightDockTab),
    );
  }

  /// Closes the right dock via its own × close button.
  Future<void> _onRightDockClosed(
    OcptShotListRightDockClosedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(clearRightDockTab: true));
  }

  /// Persists [tab] as the mode's last right dock tab, unless it already is.
  Future<void> _persistLastRightDockTab(OcptShotListRightDockTab tab) async {
    if (state.lastRightDockTab == tab) {
      return;
    }

    await _propertiesManager.shotListLastRightDockTab.store(tab);
  }

  /// Applies and persists whichever dock fraction the ended drag gesture reports.
  Future<void> _onDockFractionsChanged(
    OcptShotListDockFractionsChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final left = event.left;
    final right = event.right;

    if (left != null) {
      await _propertiesManager.shotListLeftDockFraction.store(left);
    }
    if (right != null) {
      await _propertiesManager.shotListRightDockFraction.store(right);
    }

    emitter(state.copyWith(leftDockFraction: left, rightDockFraction: right));
  }

  /// Restores both dock fractions to their defaults, persisting them.
  Future<void> _onDockLayoutReset(
    OcptShotListDockLayoutResetEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _propertiesManager.shotListLeftDockFraction.store(
      OcptWorkspaceDock.leftDefaultFraction,
    );
    await _propertiesManager.shotListRightDockFraction.store(
      OcptWorkspaceDock.rightDefaultFraction,
    );

    emitter(
      state.copyWith(
        leftDockFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightDockFraction: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
  }

  /// Shows or hides an optional table column, persisting the new set.
  Future<void> _onColumnToggled(
    OcptShotListColumnToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final visibleColumns = Set<OcptShotListColumn>.of(state.visibleColumns);
    if (!visibleColumns.remove(event.column)) {
      visibleColumns.add(event.column);
    }

    await _propertiesManager.shotListVisibleColumns.store(visibleColumns);
    emitter(state.copyWith(visibleColumns: visibleColumns));
  }

  /// Dismisses the transient write error currently shown.
  Future<void> _onWriteErrorDismissed(
    OcptShotListWriteErrorDismissedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(hasWriteError: false));
  }

  /// Leaves the workspace: flushes any pending field edit, closes the current project, and
  /// navigates back to the home page.
  Future<void> _onBackRequested(
    OcptShotListBackRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);
    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// Records the raw text just typed into `event.field` of shot `event.shotId` as a pending edit,
  /// visible immediately, and (re)starts the field-edit debounce that eventually writes it.
  Future<void> _onShotFieldChanged(
    OcptShotListShotFieldChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final pending = Map<(String, OcptShotListEditableField), String>.of(state.pendingFieldEdits)
      ..[(event.shotId, event.field)] = event.rawValue;
    emitter(state.copyWith(pendingFieldEdits: pending));

    _fieldEditTimer?.cancel();
    _fieldEditTimer = Timer(_fieldEditDebounce, () {
      if (!isClosed) {
        add(const OcptShotListFieldEditFlushRequestedEvent());
      }
    });
  }

  /// Writes every pending field edit once the field-edit debounce elapses with no further typing.
  Future<void> _onFieldEditFlushRequested(
    OcptShotListFieldEditFlushRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) => _flushPendingFieldEdits(emitter);

  /// Writes every pending field edit immediately: cancels the debounce timer (a no-op if it
  /// already fired or there was none), writes each one through
  /// `OcptShotListService.updateShot`, then reloads the snapshot and the suggestion lists so every
  /// derived aggregate and every field's suggestions reflect what the database now says. A no-op
  /// while nothing is pending.
  ///
  /// Used from inside an event handler, with that handler's own [emitter]: called by
  /// [_onFieldEditFlushRequested] (the debounce firing), and up front by every handler that
  /// changes what shot or sequence is selected, or that leaves the workspace, so a pending edit
  /// is never silently dropped by a selection change. [flushPendingFieldEdits] is the sibling of
  /// this method used outside of an event handler.
  Future<void> _flushPendingFieldEdits(Emitter<OcptShotListState> emitter) async {
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
      await _writeAllPendingFields(project: project, pending: pending);
      final snapshot = await _loadSnapshot(project);
      final suggestions = await _loadSuggestions(project);
      emitter(
        state.copyWith(snapshot: snapshot, suggestions: suggestions, pendingFieldEdits: const {}),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending shot list field edit of "
          "the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true, pendingFieldEdits: const {}));
    }
  }

  /// Writes every pending field edit directly to the database, bypassing both the debounce timer
  /// and the bloc's own event queue.
  ///
  /// Called by the mode's own `deactivate()`, mirroring
  /// `OcptStyledScreenplayEditor.deactivate()`: `deactivate()` runs before `dispose()` for every
  /// removal from the tree (a mode switch swaps this whole subtree out, and so does the
  /// workspace's own back navigation), so triggering the write here — rather than dispatching an
  /// event, which would only be processed on a later microtask this widget might not survive to
  /// see — is what guarantees the last [defaultFieldEditDebounce] worth of typing isn't lost.
  ///
  /// Unlike [_flushPendingFieldEdits], this never touches [state]: `emit` may only be called from
  /// inside a registered `on<Event>` handler (the package's own rule, enforced by the analyzer's
  /// `visible_for_testing` lint on `Bloc.emit`), and by the time this runs the widget tree that
  /// would show a fresh state is already gone anyway. Like `OcptEditorBloc.disposeLifeCycle`'s own
  /// flush, a failure here is only logged.
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
      await _writeAllPendingFields(project: project, pending: pending);
    } catch (error) {
      appLogger().e("A problem occurred when tried to flush a pending shot list field edit of "
          "the project at ${project.path}: $error");
    }
  }

  /// Writes every entry of [pending] through `OcptShotListService.updateShot`, translating each
  /// field into the matching named argument (see `OcptShotListEditableField`'s own doc comment
  /// for the mapping).
  Future<void> _writeAllPendingFields({
    required OcptOpenProjectModel project,
    required Map<(String, OcptShotListEditableField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      await _writeField(
        database: project.database,
        shotId: entry.key.$1,
        field: entry.key.$2,
        rawValue: entry.value,
      );
    }
  }

  /// Writes a single field edit through `OcptShotListService.updateShot`.
  /// [OcptShotListEditableField.estimatedDuration] and [OcptShotListEditableField.plannedTakes]
  /// are parsed first; an entry whose raw text doesn't parse is silently skipped, leaving
  /// whatever the database already holds untouched, rather than failing the whole flush.
  Future<void> _writeField({
    required OcptProjectDatabase database,
    required String shotId,
    required OcptShotListEditableField field,
    required String rawValue,
  }) async {
    switch (field) {
      case OcptShotListEditableField.shotSize:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          shotSize: Value(rawValue),
        );
      case OcptShotListEditableField.framing:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          framing: Value(rawValue),
        );
      case OcptShotListEditableField.cameraMove:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          cameraMove: Value(rawValue),
        );
      case OcptShotListEditableField.lens:
        await _shotListService.updateShot(database: database, shotId: shotId, lens: Value(rawValue));
      case OcptShotListEditableField.recordingFormat:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          recordingFormat: Value(rawValue),
        );
      case OcptShotListEditableField.shootingDay:
        final trimmed = rawValue.trim();
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          shootingDay: Value(trimmed.isEmpty ? null : trimmed),
        );
      case OcptShotListEditableField.sound:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          sound: Value(rawValue),
        );
      case OcptShotListEditableField.notes:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          notes: Value(rawValue),
        );
      case OcptShotListEditableField.locationNotes:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          locationNotes: Value(rawValue),
        );
      case OcptShotListEditableField.estimatedDuration:
        final parsed = _tryParseDuration(rawValue);
        if (!parsed.isValid) {
          return;
        }
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          estimatedDurationMs: Value(parsed.value),
        );
      case OcptShotListEditableField.plannedTakes:
        final parsed = _tryParsePlannedTakes(rawValue);
        if (!parsed.isValid) {
          return;
        }
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          plannedTakes: Value(parsed.value),
        );
    }
  }

  /// Attempts to parse [raw] as a shot's estimated duration through [ocptParseShotDuration],
  /// reporting whether it succeeded rather than throwing: a rejected edit is meant to be silently
  /// skipped, not to crash the flush of every other pending edit alongside it.
  ({bool isValid, int? value}) _tryParseDuration(String raw) {
    try {
      return (isValid: true, value: ocptParseShotDuration(raw));
    } on FormatException {
      return (isValid: false, value: null);
    }
  }

  /// Attempts to parse [raw] as a shot's planned take count: blank means null, a non-negative
  /// integer means itself, anything else is rejected.
  ({bool isValid, int? value}) _tryParsePlannedTakes(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (isValid: true, value: null);
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      return (isValid: false, value: null);
    }

    return (isValid: true, value: parsed);
  }

  /// Sets the shooting status of shot `event.shotId`, written immediately.
  Future<void> _onShotStatusChanged(
    OcptShotListShotStatusChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      await _shotListService.updateShot(
        database: project.database,
        shotId: event.shotId,
        status: Value(event.status),
      );
      emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to change the status of shot ${event.shotId} "
          "of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Sets one difficulty axis of shot `event.shotId` to `event.value`, written immediately.
  Future<void> _onShotDifficultyChanged(
    OcptShotListShotDifficultyChangedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      final database = project.database;
      switch (event.axis) {
        case OcptShotDifficultyAxis.set:
          await _shotListService.updateShot(
            database: database,
            shotId: event.shotId,
            difficultySet: Value(event.value),
          );
        case OcptShotDifficultyAxis.camera:
          await _shotListService.updateShot(
            database: database,
            shotId: event.shotId,
            difficultyCamera: Value(event.value),
          );
        case OcptShotDifficultyAxis.acting:
          await _shotListService.updateShot(
            database: database,
            shotId: event.shotId,
            difficultyActing: Value(event.value),
          );
        case OcptShotDifficultyAxis.sound:
          await _shotListService.updateShot(
            database: database,
            shotId: event.shotId,
            difficultySound: Value(event.value),
          );
      }
      emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to change the difficulty of shot "
          "${event.shotId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Attaches `event.characterName` to shot `event.shotId` if it isn't already, detaches it
  /// otherwise, written immediately.
  Future<void> _onShotCharacterToggled(
    OcptShotListShotCharacterToggledEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final shot = state.snapshot?.shotsById[event.shotId];
    if (project == null || shot == null) {
      return;
    }

    final isAttached = shot.characters.contains(normalizeCharacterName(event.characterName));

    try {
      if (isAttached) {
        await _shotListService.detachCharacter(
          database: project.database,
          shotId: event.shotId,
          characterName: event.characterName,
        );
      } else {
        await _shotListService.attachCharacter(
          database: project.database,
          shotId: event.shotId,
          characterName: event.characterName,
        );
      }
      emitter(state.copyWith(snapshot: await _loadSnapshot(project)));
    } catch (error) {
      appLogger().e("A problem occurred when tried to toggle character ${event.characterName} on "
          "shot ${event.shotId} of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Deletes shot `event.shotId`, clearing the selection when it was the selected shot (the
  /// sequence stays selected), and dropping any pending field edit that still targeted it (the
  /// shot it would have written to no longer exists).
  Future<void> _onShotDeletionRequested(
    OcptShotListShotDeletionRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final pendingWithoutShot = Map<(String, OcptShotListEditableField), String>.of(
      state.pendingFieldEdits,
    )..removeWhere((key, _) => key.$1 == event.shotId);
    if (pendingWithoutShot.isEmpty) {
      _fieldEditTimer?.cancel();
      _fieldEditTimer = null;
    }

    final wasSelected = state.selectedShotId == event.shotId;

    try {
      await _shotListService.deleteShot(database: project.database, shotId: event.shotId);
      emitter(
        state.copyWith(
          snapshot: await _loadSnapshot(project),
          suggestions: await _loadSuggestions(project),
          pendingFieldEdits: pendingWithoutShot,
          clearSelectedShotId: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete shot ${event.shotId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// A further safety net alongside [flushPendingFieldEdits] (the mode's own `deactivate()`) and
  /// the flush every selection-changing handler already performs: whichever path the bloc closes
  /// through, a pending field edit still gets written rather than silently dropped, mirroring
  /// `OcptEditorBloc.disposeLifeCycle`'s own best-effort flush.
  @override
  Future<void> disposeLifeCycle() async {
    await flushPendingFieldEdits();
    return super.disposeLifeCycle();
  }
}
