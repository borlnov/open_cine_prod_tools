// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_list_service.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
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
/// Committing a shot size additionally deduces the shot's abbreviation from it while the shot has
/// none of its own ([_deduceAbbreviationIfEmpty]), which is the only write this bloc performs that
/// the user didn't type themselves.
///
/// A shot's scenario coverage ranges are a further set of discrete, immediately-written actions:
/// [_onCoverageWordClicked] resolves a word click against
/// [OcptShotListState.pendingCoverageAnchor] into adding, removing, or simply moving where the
/// next click would close a range (see that handler's own doc comment for the three-state
/// interaction) — a range being added also attaches the characters it covers to the shot, see
/// [_attachCharactersCoveredBy] —, [_onCoverageClearRequested] drops every range of a shot, and
/// [_onShotMarkedAsChecked] clears a shot's `needsCheck` flag and re-stamps its ranges' digests.
/// All three go through [OcptShotListState.screenplayText] — the screenplay's Fountain text as
/// last loaded, which [OcptShotListState.buildSelectedCoverageLayout] slices a scene's own text
/// out of — loaded once here rather than by [_screenplayCharactersOf] on its own, which used to
/// parse the screenplay text a second time to derive the same list of speaking characters.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does: the project's versions are a property of the *project*, so that tab and
/// its state are shared with the screenplay mode rather than reimplemented here. The two hooks the
/// mixin needs are answered by [flushPendingProjectWrites] (a field edit still sitting in the
/// debounce must reach the working copy before a preview swaps the database out) and
/// [reloadFromProjectDatabase]. `_onRightDockTabSelected` and `_flushPendingFieldEdits` each
/// dispatch [OcptProjectWorkingCopyRefreshRequestedEvent] — opening the `Versions` tab, and a
/// field edit landing while it is already open — the two moments the mixin's working-copy card is
/// worth a fresh, throttled read.
///
/// The two actions that read the shot list rather than writing to it are its exports — the XLSX
/// workbook ([_onXlsxExportRequested]) and the scenario coverage PDF
/// ([_onScenarioCoverageExportRequested]): both flush whatever is still pending, then hand the
/// loaded snapshot to [OcptExportManager], which owns both the document building and the native
/// save dialog.
class OcptShotListBloc extends BlocForMixin<OcptShotListState>
    with MixinOcptProjectVersionsBloc<OcptShotListState> {
  /// The default delay between the last field edit and its autosave write.
  static const defaultFieldEditDebounce = Duration(seconds: 2);

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the mode's dock fractions, visible columns and last
  /// right dock tab.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the workspace.
  final OcptRouterManager _routerManager;

  /// The manager used to export the shot list to an XLSX workbook.
  final OcptExportManager _exportManager;

  /// The service used to read and write the shot list.
  final OcptShotListService _shotListService;

  /// The service used to read and write a shot's scenario coverage ranges.
  final OcptShotCoverageService _shotCoverageService;

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
    OcptExportManager? exportManager,
    OcptShotListService? shotListService,
    OcptShotCoverageService? shotCoverageService,
    Duration fieldEditDebounce = defaultFieldEditDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _shotListService =
           shotListService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotListService,
       _shotCoverageService =
           shotCoverageService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).shotCoverageService,
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
    on<OcptShotListXlsxExportRequestedEvent>(_onXlsxExportRequested);
    on<OcptShotListScenarioCoverageExportRequestedEvent>(_onScenarioCoverageExportRequested);
    on<OcptShotListIoNoticeDismissedEvent>(_onIoNoticeDismissed);
    on<OcptShotListBackRequestedEvent>(_onBackRequested);
    on<OcptShotListShotFieldChangedEvent>(_onShotFieldChanged);
    on<OcptShotListFieldEditFlushRequestedEvent>(_onFieldEditFlushRequested);
    on<OcptShotListShotDifficultyChangedEvent>(_onShotDifficultyChanged);
    on<OcptShotListShotCharacterToggledEvent>(_onShotCharacterToggled);
    on<OcptShotListShotDeletionRequestedEvent>(_onShotDeletionRequested);
    on<OcptShotListRemovedCharacterDroppedEvent>(_onRemovedCharacterDropped);
    on<OcptShotListRemovedCharacterReplacedEvent>(_onRemovedCharacterReplaced);
    on<OcptShotListCoverageWordClickedEvent>(_onCoverageWordClicked);
    on<OcptShotListCoverageClearRequestedEvent>(_onCoverageClearRequested);
    on<OcptShotListShotMarkedAsCheckedEvent>(_onShotMarkedAsChecked);
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// Writes whatever field edit is still sitting in the field-edit debounce, so a preview about to
  /// swap the database can't send it into the previewed version instead.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptShotListState> emitter) =>
      _flushPendingFieldEdits(emitter);

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptShotListState> emitter) =>
      _onLoadRequested(const OcptShotListLoadRequestedEvent(), emitter);

  /// Loads the persisted preferences and the current project's shot list, selecting its first
  /// sequence.
  ///
  /// The workspace route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stops loading
  /// with no snapshot at all.
  ///
  /// This is also [MixinOcptProjectVersionsBloc]'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the shot list it just read: what it read comes from
  /// that very version's in-memory database, and the two must reach the mode together (see the
  /// hook's own doc comment).
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
          clearPreviewedVersionId: true,
        ),
      );
      return;
    }

    final previewedVersion = project.previewedVersion;
    final screenplayText = await _loadScreenplayText(project);
    final pageSetup = await _loadPageSetup(project);
    final snapshot = await _loadSnapshot(project);
    final screenplayCharacters = _screenplayCharactersOf(screenplayText);
    final suggestions = await _loadSuggestions(project);

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        previewedVersionId: previewedVersion?.id,
        clearPreviewedVersionId: previewedVersion == null,
        snapshot: snapshot,
        pageSetup: pageSetup,
        screenplayText: screenplayText,
        selectedSequenceId: snapshot.sequences.isEmpty ? null : snapshot.sequences.first.id,
        clearSelectedSequenceId: snapshot.sequences.isEmpty,
        clearSelectedShotId: true,
        clearPendingCoverageAnchor: true,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        visibleColumns: visibleColumns,
        lastRightDockTab: lastRightDockTab,
        screenplayCharacters: screenplayCharacters,
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

  /// Reads [project]'s current Fountain source text, kept in `OcptShotListState.screenplayText`
  /// for [_screenplayCharactersOf] and every scenario coverage read/write that needs the whole
  /// screenplay text rather than a single scene's own slice of it.
  Future<String> _loadScreenplayText(OcptOpenProjectModel project) =>
      _projectsManager.screenplayService.loadScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
      );

  /// Reads the page setup the screenplay is typeset with: the open project's own page format,
  /// paired with the app-wide margins preference, exactly as the screenplay editor's own bloc
  /// pairs them. The scenario coverage dialog's simulated paper sheet is laid out with it.
  ///
  /// A version being previewed is laid out with the setup it was written against instead, which
  /// travels on the open project model and is never written anywhere — again exactly as the
  /// screenplay editor's own bloc does it.
  Future<OcptPageSetup> _loadPageSetup(OcptOpenProjectModel project) async =>
      project.previewedPageSetup ??
      OcptPageSetup(
        format: await _projectsManager.loadCurrentProjectPageFormat() ?? OcptPageFormat.usLetter,
        margins: await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

  /// Parses [screenplayText] and delegates to `fountain_kit`'s `screenplayCharactersOf`, whose
  /// normalisation matches `shot_characters.characterName`'s own (both go through
  /// `normalizeCharacterName`) so a shot's character and a screenplay's own compare equal
  /// byte-for-byte.
  ///
  /// The whole cast, not only the speaking roles: a character introduced in capitals in an action
  /// line and never given a single line of dialogue (a silhouette, an extra, someone who only
  /// crosses the frame) still has to be attachable to a shot, and would otherwise be reported as
  /// removed from the screenplay by `OcptShotListState.removedCharacterAlerts` the moment somebody
  /// attached them.
  List<String> _screenplayCharactersOf(String screenplayText) {
    final document = const FountainParser().parse(screenplayText);
    return screenplayCharactersOf(document.blocks);
  }

  /// Reads every free-text field's project-wide suggestion list.
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
        clearPendingCoverageAnchor: true,
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
        clearPendingCoverageAnchor: true,
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
          clearPendingCoverageAnchor: true,
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
  ///
  /// Opening the `Versions` tab is one of the two moments `MixinOcptProjectVersionsBloc`'s
  /// working-copy card needs a fresh read for: the other is a field edit flushing while it is
  /// already the one showing (see `_flushPendingFieldEdits`).
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

    if (!isAlreadyActive && event.tab == OcptShotListRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
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

  /// Exports the whole shot list to an XLSX workbook.
  ///
  /// Flushes any pending field edit first — that flush re-reads the snapshot, so the workbook
  /// holds the value the user typed seconds ago rather than the one the database held before it —
  /// then hands what the state now carries to [OcptExportManager.exportShotListXlsx]. A cancelled
  /// save dialog is a silent no-op; a failure raises the transient export-failed notice.
  ///
  /// Exports the whole shot list, not only the selected sequence: the workbook is what leaves the
  /// app, and the orphan group travels with it exactly as the left dock shows it.
  Future<void> _onXlsxExportRequested(
    OcptShotListXlsxExportRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final path = await _exportManager.exportShotListXlsx(
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
          ioNotice: OcptShotListIoNotice(
            kind: OcptShotListIoNoticeKind.xlsxExportSucceeded,
            path: path,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the shot list of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptShotListIoNotice(kind: OcptShotListIoNoticeKind.xlsxExportFailed),
        ),
      );
    }
  }

  /// Exports the screenplay annotated with the shots covering it, as a PDF.
  ///
  /// The read-only sibling of [_onXlsxExportRequested], and built the same way: flush whatever is
  /// still pending — that flush re-reads the snapshot, so the legend holds the shot size the user
  /// typed seconds ago — then hand what the state now carries to
  /// [OcptExportManager.exportScenarioCoverage]. A cancelled save dialog is a silent no-op; a
  /// failure raises the transient export-failed notice.
  ///
  /// [OcptShotListState.screenplayText] is parsed here rather than kept parsed in the state: the
  /// document is only ever needed by this export, and the very string it is parsed from travels
  /// alongside it, since a coverage range addresses that text by character offset.
  Future<void> _onScenarioCoverageExportRequested(
    OcptShotListScenarioCoverageExportRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    await _flushPendingFieldEdits(emitter);

    final snapshot = state.snapshot;
    if (snapshot == null) {
      return;
    }

    try {
      final options = event.options;
      final path = await _exportManager.exportScenarioCoverage(
        document: const FountainParser().parse(state.screenplayText),
        screenplayText: state.screenplayText,
        snapshot: snapshot,
        pageSetup: OcptPageSetup(format: options.format, margins: options.margins),
        labels: event.labels,
        projectName: state.title,
        includeSceneNumbers: options.includeSceneNumbers,
        includeTitlePage: options.includeTitlePage,
        includeLegendPage: options.includeLegendPage,
        includeSummaryPage: options.includeSummaryPage,
        fileTypeLabel: event.fileTypeLabel,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptShotListIoNotice(
            kind: OcptShotListIoNoticeKind.scenarioCoverageExportSucceeded,
            path: path,
          ),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the scenario coverage of the project "
          "at ${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptShotListIoNotice(
            kind: OcptShotListIoNoticeKind.scenarioCoverageExportFailed,
          ),
        ),
      );
    }
  }

  /// Clears the transient export notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptShotListIoNoticeDismissedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    emitter(state.copyWith(clearIoNotice: true));
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

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a field edit landing while the tab showing it is already open.
      if (state.rightDockTab == OcptShotListRightDockTab.versions) {
        add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      }
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
  /// for the mapping), and deduces an abbreviation alongside every shot size committed here (see
  /// [_deduceAbbreviationIfEmpty]).
  ///
  /// A shot whose abbreviation is being typed in the very same flush is left out of the deduction:
  /// what the user is writing wins over what the shot size would have suggested, whichever of the
  /// two entries this loop happens to reach first.
  Future<void> _writeAllPendingFields({
    required OcptOpenProjectModel project,
    required Map<(String, OcptShotListEditableField), String> pending,
  }) async {
    for (final entry in pending.entries) {
      final (shotId, field) = entry.key;

      await _writeField(
        database: project.database,
        shotId: shotId,
        field: field,
        rawValue: entry.value,
      );

      if (field == OcptShotListEditableField.shotSize &&
          !pending.containsKey((shotId, OcptShotListEditableField.abbreviation))) {
        await _deduceAbbreviationIfEmpty(
          database: project.database,
          shotId: shotId,
          shotSize: entry.value,
        );
      }
    }
  }

  /// Writes onto shot [shotId] the abbreviation [ocptDeduceShotAbbreviation] reads out of the
  /// [shotSize] just committed, unless the shot already carries one.
  ///
  /// Deduced once, at that moment only: an abbreviation the user has typed — or one deduced from
  /// an earlier shot size — is never overwritten by a later edit of the shot size, and clearing
  /// the field leaves it empty until the shot size is committed again. A shot size with no
  /// initials to read at all (blank, or punctuation alone) deduces nothing rather than emptying
  /// what the shot holds.
  Future<void> _deduceAbbreviationIfEmpty({
    required OcptProjectDatabase database,
    required String shotId,
    required String shotSize,
  }) async {
    final stored = state.snapshot?.shotsById[shotId]?.abbreviation ?? "";
    if (stored.trim().isNotEmpty) {
      return;
    }

    final deduced = ocptDeduceShotAbbreviation(shotSize);
    if (deduced.isEmpty) {
      return;
    }

    await _shotListService.updateShot(
      database: database,
      shotId: shotId,
      abbreviation: Value(deduced),
    );
  }

  /// Writes a single field edit through `OcptShotListService.updateShot`.
  /// [OcptShotListEditableField.estimatedDuration] is parsed first; an entry whose raw text
  /// doesn't parse is silently skipped, leaving whatever the database already holds untouched,
  /// rather than failing the whole flush.
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
      case OcptShotListEditableField.abbreviation:
        await _shotListService.updateShot(
          database: database,
          shotId: shotId,
          abbreviation: Value(rawValue),
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
          clearPendingCoverageAnchor: wasSelected,
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to delete shot ${event.shotId} of the "
          "project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Detaches `event.characterName` from every shot of the screenplay, written immediately: the
  /// deleted-character banner's `Remove from every shot` button.
  ///
  /// The banner itself is derived from the snapshot (`OcptShotListState.removedCharacterAlerts`),
  /// so reloading it here is what makes the banner disappear — nothing dismisses it by hand.
  Future<void> _onRemovedCharacterDropped(
    OcptShotListRemovedCharacterDroppedEvent event,
    Emitter<OcptShotListState> emitter,
  ) => _writeCharacterChange(
    emitter: emitter,
    characterName: event.characterName,
    action: (project) => _shotListService.removeCharacterFromEveryShot(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      characterName: event.characterName,
    ),
  );

  /// Replaces `event.characterName` with `event.replacementName` on every shot of the screenplay,
  /// written immediately: the deleted-character banner's replacement chips.
  Future<void> _onRemovedCharacterReplaced(
    OcptShotListRemovedCharacterReplacedEvent event,
    Emitter<OcptShotListState> emitter,
  ) => _writeCharacterChange(
    emitter: emitter,
    characterName: event.characterName,
    action: (project) => _shotListService.replaceCharacterEverywhere(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
      oldCharacterName: event.characterName,
      newCharacterName: event.replacementName,
    ),
  );

  /// Writes a screenplay-wide character change through [action] and reloads the snapshot, so every
  /// view derived from it (the banners, a shot's own chips, the table's characters column) reflects
  /// what the database now says. Mirrors [_writeCoverageChange]'s own try/catch shape, for the two
  /// actions of the deleted-character banner.
  Future<void> _writeCharacterChange({
    required Emitter<OcptShotListState> emitter,
    required String characterName,
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
      appLogger().e("A problem occurred when tried to change the character $characterName on "
          "every shot of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true));
    }
  }

  /// Resolves a click on a scenario coverage word, exactly as `OcptShotListCoverageWordClickedEvent`
  /// documents: with no range open, a click on one of the selected shot's own already-covered words
  /// removes the range covering it and any other click opens a range on that word; with a range
  /// open, the click closes it wherever it lands. Written immediately, like every other coverage
  /// change; a stale click — a shot no longer selected, or nothing left to lay out — is silently
  /// ignored, since the layout the click was resolved against might no longer describe what is on
  /// screen.
  ///
  /// A closing click is never rejected for landing in another block than the one the range was
  /// opened in: a range legitimately runs from an action paragraph into the dialogue below it, and
  /// `OcptShotCoverageService.addRange` stopped enforcing anything about blocks along with it.
  ///
  /// The click that closes a range writes the characters that range covers alongside it, in the
  /// same [_writeCoverageChange] action so both land before the snapshot is re-read: see
  /// [_attachCharactersCoveredBy].
  Future<void> _onCoverageWordClicked(
    OcptShotListCoverageWordClickedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    final layout = state.buildSelectedCoverageLayout();
    if (project == null || layout == null || state.selectedShotId != event.shotId) {
      return;
    }

    final anchor = state.pendingCoverageAnchor;

    if (anchor == null) {
      final coveringRange = layout.rangeAt(
        event.wordStartOffset,
        state.selectedShot?.coverageRanges ?? const [],
      );
      if (coveringRange == null) {
        emitter(
          state.copyWith(
            pendingCoverageAnchor: (
              wordStartOffset: event.wordStartOffset,
              wordEndOffset: event.wordEndOffset,
            ),
          ),
        );
        return;
      }

      await _writeCoverageChange(
        emitter: emitter,
        project: project,
        shotId: event.shotId,
        action: () => _shotCoverageService.removeRange(
          database: project.database,
          rangeId: coveringRange.id,
        ),
      );
      return;
    }

    final range = layout.rangeBetween(
      OcptShotCoverageWord(
        text: layout.sceneText.substring(anchor.wordStartOffset, anchor.wordEndOffset),
        startOffset: anchor.wordStartOffset,
        endOffset: anchor.wordEndOffset,
      ),
      OcptShotCoverageWord(
        text: layout.sceneText.substring(event.wordStartOffset, event.wordEndOffset),
        startOffset: event.wordStartOffset,
        endOffset: event.wordEndOffset,
      ),
    );

    await _writeCoverageChange(
      emitter: emitter,
      project: project,
      shotId: event.shotId,
      action: () async {
        await _shotCoverageService.addRange(
          database: project.database,
          shotId: event.shotId,
          sceneId: layout.sceneId,
          startOffset: range.startOffset,
          endOffset: range.endOffset,
          sceneText: layout.sceneText,
        );
        await _attachCharactersCoveredBy(
          project: project,
          shotId: event.shotId,
          layout: layout,
          range: range,
        );
      },
    );
  }

  /// Attaches to shot [shotId] every character the range just recorded covers, so selecting a
  /// shot's scenario coverage ticks its character chips on its own instead of leaving the same
  /// names to be clicked twice.
  ///
  /// Deliberately additive: a range that stops covering a character (removed, or narrowed) never
  /// detaches anybody, since a shot's characters are the director's own list — a silent role, an
  /// extra, a character kept in frame through a reply they don't speak — and only the user knows
  /// which of them the coverage happens to explain. A name already attached is skipped, and so is
  /// one no longer among [OcptShotListState.screenplayCharacters], which would otherwise come back
  /// as a struck-through `(removed)` chip.
  Future<void> _attachCharactersCoveredBy({
    required OcptOpenProjectModel project,
    required String shotId,
    required OcptShotCoverageLayout layout,
    required ({int startOffset, int endOffset}) range,
  }) async {
    final attached = state.snapshot?.shotsById[shotId]?.characters ?? const <String>[];
    final covered = layout.charactersCoveredBy(
      startOffset: range.startOffset,
      endOffset: range.endOffset,
    );

    for (final characterName in covered) {
      if (attached.contains(characterName) || !state.screenplayCharacters.contains(characterName)) {
        continue;
      }

      await _shotListService.attachCharacter(
        database: project.database,
        shotId: shotId,
        characterName: characterName,
      );
    }
  }

  /// Removes every scenario coverage range of shot `event.shotId`, written immediately: the
  /// inspector's `Clear all` action.
  Future<void> _onCoverageClearRequested(
    OcptShotListCoverageClearRequestedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _writeCoverageChange(
      emitter: emitter,
      project: project,
      shotId: event.shotId,
      action: () => _shotCoverageService.clearRangesOfShot(
        database: project.database,
        shotId: event.shotId,
      ),
    );
  }

  /// Clears shot `event.shotId`'s `needsCheck` flag and re-stamps every one of its scenario
  /// coverage ranges' digests to the screenplay's current text, written immediately: the
  /// inspector's `Needs checking` callout's `Mark as checked` button.
  ///
  /// Passes the whole [OcptShotListState.screenplayText], not a single scene's slice of it: the
  /// offsets `OcptShotCoverageService.markAsChecked` re-stamps are scene-relative to each range's
  /// own scene's `charStart`, and a shot's ranges may span more than one scene. This also clears a
  /// `needsCheck` the shot carries for `OcptShotCheckReason.sceneDeleted` (an orphaned shot, which
  /// has no range to re-stamp at all) exactly as it clears any other reason.
  Future<void> _onShotMarkedAsChecked(
    OcptShotListShotMarkedAsCheckedEvent event,
    Emitter<OcptShotListState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _writeCoverageChange(
      emitter: emitter,
      project: project,
      shotId: event.shotId,
      action: () => _shotCoverageService.markAsChecked(
        database: project.database,
        shotId: event.shotId,
        currentFountainText: state.screenplayText,
      ),
    );
  }

  /// Writes a scenario coverage change through [action], reloads the snapshot so every dependent
  /// aggregate (the `modified` badge, the "also covered by" wash, a shot's `needsCheck`) reflects
  /// what the database now says, and clears the pending coverage anchor — a coverage write always
  /// leaves the interaction back at its initial, no-anchor state. Mirrors
  /// `_onShotDifficultyChanged`/`_onShotCharacterToggled`'s own try/catch shape.
  Future<void> _writeCoverageChange({
    required Emitter<OcptShotListState> emitter,
    required OcptOpenProjectModel project,
    required String shotId,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
      emitter(
        state.copyWith(snapshot: await _loadSnapshot(project), clearPendingCoverageAnchor: true),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to change the scenario coverage of shot "
          "$shotId of the project at ${project.path}: $error");
      emitter(state.copyWith(hasWriteError: true, clearPendingCoverageAnchor: true));
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
