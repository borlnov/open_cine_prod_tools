// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/logging/ocpt_logs_helper_builder.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_mode_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_package_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';

/// This is the bloc class for the editor page.
///
/// It loads the current project's screenplay from [OcptProjectsManager] on entry, re-parses the
/// source text with [FountainParser] after a short debounce on every edit (parsing a full feature
/// script takes single-digit milliseconds, so it runs synchronously in the bloc), and autosaves
/// through [OcptScreenplayService] (which snapshots the previous text and reconciles the scene
/// index) after a longer debounce. Manual saves (toolbar button, Ctrl+S) go through the same save
/// path, only tagged [OcptSnapshotReason.manual] instead of [OcptSnapshotReason.timer].
/// The counters belong to `OcptEditorStatisticsBloc`, which reads the document this bloc parses.
///
/// When the bloc closes (the user leaves the page), any pending unsaved change is flushed with a
/// best-effort save: the debounce timers are cancelled and the save runs directly against the
/// service, so no edit is lost by navigating away right after typing.
///
/// It also mixes in [MixinOcptProjectVersionsBloc], which owns everything the right dock's
/// `Versions` tab does: the project's versions are a property of the *project*, so that tab and
/// its state are shared with every other production mode rather than reimplemented here. The two
/// hooks the mixin needs are answered by [flushPendingProjectWrites] (a pending autosave must
/// reach the working copy before a preview swaps the database out) and
/// [reloadFromProjectDatabase]. `_onRightDockTabSelected` and `_saveCurrentText` each dispatch
/// [OcptProjectWorkingCopyRefreshRequestedEvent] — opening the `Versions` tab, and a save landing
/// while it is already open — the two moments the mixin's working-copy card is worth a fresh,
/// throttled read.
///
/// It mixes in [MixinOcptProjectPackageBloc] too, which writes the whole project out as a portable
/// package from the `Export` panel's own standing card. That mixin reuses
/// [flushPendingProjectWrites] — what a colleague receives is the project *file*, so a debounced
/// edit has to reach it first — and asks [exportManager] where to write, exactly as this mode's
/// own exports do.
class OcptEditorBloc extends BlocForMixin<OcptEditorState>
    with
        MixinOcptProjectVersionsBloc<OcptEditorState>,
        MixinOcptProjectPackageBloc<OcptEditorState>,
        MixinOcptModeBloc<OcptEditorState, Never>,
        MixinAsyncInitBloc<OcptEditorState> {
  /// The logger category linked to this BLoC.
  static const _loggerCategory = "editor_bloc";

  /// The logger this BLoC writes to.
  final LogsHelper _logger = buildOcptLogsHelper(_loggerCategory);

  /// The default delay between the last edit and the re-parse of the source text.
  static const defaultParseDebounce = Duration(milliseconds: 150);

  /// The default delay between the last edit and the autosave.
  static const defaultAutosaveDebounce = Duration(seconds: 2);

  /// The parser used to build the [FountainDocument] shown in the preview and the scene panel.
  static const _fountainParser = FountainParser();

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The manager used to load and persist the preferred editor mode.
  final OcptPropertiesManager _propertiesManager;

  /// The router manager used to navigate back to the home page when leaving the editor.
  final OcptRouterManager _routerManager;

  /// The service used to load and save the screenplay's text.
  final OcptScreenplayService _screenplayService;

  /// The manager used to export the screenplay to, and import it from, a `.fountain` file.
  final OcptExportManager _exportManager;

  /// The delay between the last edit and the re-parse of the source text.
  final Duration _parseDebounce;

  /// The delay between the last edit and the autosave.
  final Duration _autosaveDebounce;

  /// The running parse debounce timer, if any.
  Timer? _parseTimer;

  /// The running autosave debounce timer, if any.
  Timer? _autosaveTimer;

  /// The text of the latest [OcptEditorTextChangedEvent] added and not handled yet, if any.
  ///
  /// The styled editor hands its last edit over from its own `deactivate`, which runs just before
  /// the bloc is closed, and an event is delivered to its handler asynchronously: [disposeLifeCycle]
  /// would otherwise flush a text older than the one the user left behind.
  String? _undeliveredText;

  /// Whether [disposeLifeCycle] has started.
  bool _isDisposing = false;

  /// The id given to the next [OcptEditorJumpRequest], increased after each one.
  int _nextJumpRequestId = 0;

  /// Unregisters this bloc's unsaved-changes reporter, called when it is disposed.
  late final void Function() _unregisterUnsavedChangesReporter;

  /// The episode this bloc reads and writes, handed down by `OcptEditorPage` from
  /// `OcptWorkspaceBloc.state.selectedEpisodeId` at construction time — safe to capture once rather
  /// than watch, since `OcptWorkspacePage` remounts this whole bloc on every episode switch (see
  /// `OcptWorkspacePage._buildActiveMode`'s own doc comment), so the field can never go stale.
  ///
  /// Null only for a project holding no episode at all: `OcptWorkspaceBloc` lands on the first one
  /// before it clears `isLoading`, and a mode is never built before that, so [screenplayIdOf]'s
  /// fallback to [OcptOpenProjectModel.primaryScreenplayId] is the honest last resort rather than a
  /// routine path.
  final String? _selectedEpisodeId;

  /// Class constructor
  ///
  /// [parseDebounce] and [autosaveDebounce] are only meant to be overridden
  /// by tests, to keep them fast and deterministic.
  OcptEditorBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptScreenplayService? screenplayService,
    OcptExportManager? exportManager,
    Duration parseDebounce = defaultParseDebounce,
    Duration autosaveDebounce = defaultAutosaveDebounce,
    String? selectedEpisodeId,
  }) : _selectedEpisodeId = selectedEpisodeId,
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _screenplayService =
           screenplayService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).screenplayService,
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _parseDebounce = parseDebounce,
       _autosaveDebounce = autosaveDebounce,
       super(const OcptEditorState.init()) {
    // The screenplay is the one thing in the app that lives in memory between two writes (the
    // autosave debounce), so this is the mode that has an answer to give when the projects manager
    // asks whether it may swap the database under everyone to preview a version.
    _unregisterUnsavedChangesReporter = _projectsManager.registerUnsavedChangesReporter(
      () => state.isDirty,
    );
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptEditorTextChangedEvent>(_onTextChanged);
    on<OcptEditorParseRequestedEvent>(_onParseRequested);
    on<OcptEditorSaveRequestedEvent>(_onSaveRequested);
    on<OcptEditorCaretMovedEvent>(_onCaretMoved);
    on<OcptEditorSceneJumpRequestedEvent>(_onSceneJumpRequested);
    on<OcptEditorScenePanelToggledEvent>(_onScenePanelToggled);
    on<OcptEditorRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptEditorRightDockToggledEvent>(_onRightDockToggled);
    on<OcptEditorRightDockClosedEvent>(_onRightDockClosed);
    on<OcptEditorDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptEditorDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptEditorModeToggledEvent>(_onModeToggled);
    on<OcptEditorPageSimulationToggledEvent>(_onPageSimulationToggled);
    on<OcptEditorStyledSceneNumbersToggledEvent>(_onStyledSceneNumbersToggled);
    on<OcptEditorSpellCheckToggledEvent>(_onSpellCheckToggled);
    on<OcptEditorPageSetupChangedEvent>(_onPageSetupChanged);
    on<OcptEditorProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptEditorSaveErrorDismissedEvent>(_onSaveErrorDismissed);
    on<OcptEditorBackRequestedEvent>(_onBackRequested);
    on<OcptEditorTitlePageChangedEvent>(_onTitlePageChanged);
    onAwaited<OcptEditorSaveForExportRequestedEvent>(_onSaveForExportRequested);
    onAwaited<OcptEditorImportedTextAppliedEvent>(_onImportedTextApplied);
  }

  /// {@macro bloc.Bloc.add}
  ///
  /// Remembers the text of a [OcptEditorTextChangedEvent] until its handler has run, see
  /// [_undeliveredText].
  @override
  void add(BlocEventForMixin event) {
    if (event is OcptEditorTextChangedEvent) {
      _undeliveredText = event.text;
    }
    super.add(event);
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

  /// Saves the screenplay if it holds unsaved changes, so a preview about to swap the database
  /// can't send the text sitting in the autosave debounce into the previewed version instead.
  ///
  /// Tagged [OcptSnapshotReason.manual] like every other save the user's own action triggers: from
  /// the screenplay's point of view, clicking a version card is as deliberate as pressing Ctrl+S.
  @protected
  @override
  Future<bool> flushPendingProjectWrites(Emitter<OcptEditorState> emitter) =>
      flushAllPendingWritesIn(emitter);

  /// {@macro open_cine_prod_tools.MixinOcptModeBloc.flushAllPendingWritesIn}
  ///
  /// Always true: a save that fails raises the transient save error, keeps the text dirty and is
  /// not retried here, and the action behind the flush (a preview, a restore, an export, a package)
  /// goes ahead on the text the database still holds, as it always did.
  @protected
  @override
  Future<bool> flushAllPendingWritesIn(Emitter<OcptEditorState> emitter) async {
    if (state.isDirty) {
      await _saveCurrentText(reason: OcptSnapshotReason.manual, emitter: emitter);
    }

    await runPendingWritesFlushers();
    return true;
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptEditorState> emitter) => _load(emitter);

  /// {@macro act_flutter_utility.MixinAsyncInitBloc.initAsyncBloc}
  ///
  /// Loads the mode for the first time, see [_load]; adding an [AsyncInitEvent] again loads it
  /// again.
  @protected
  @override
  Future<void> initAsyncBloc({required Emitter<OcptEditorState> emit}) async {
    await super.initAsyncBloc(emit: emit);
    await _load(emit);
  }

  /// Loads the current project's screenplay text, title and page format, and parses the text,
  /// together with the persisted preferred editor mode.
  ///
  /// The editor route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stays in its
  /// init form with an empty document.
  ///
  /// This is also `MixinOcptProjectVersionsBloc`'s [reloadFromProjectDatabase] hook, so it emits
  /// which version is being previewed alongside the text it just read: what it read comes from that
  /// very version's in-memory database, and the two must reach the page together (see the hook's
  /// own doc comment).
  Future<void> _load(Emitter<OcptEditorState> emitter) async {
    final mode = await _propertiesManager.editorMode.load() ?? OcptEditorMode.styled;
    final isPageSimulationEnabled = await _propertiesManager.isPageSimulationEnabled.load() ?? true;
    final areStyledSceneNumbersVisible =
        await _propertiesManager.styledSceneNumbersVisible.load() ?? true;
    final leftDockFraction =
        await _propertiesManager.editorLeftDockFraction.load() ??
        OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.editorRightDockFraction.load() ??
        OcptWorkspaceDock.rightDefaultFraction;
    final isSpellCheckVisible = await _propertiesManager.spellCheckVisible.load() ?? true;
    final screenplayLanguage = await _projectsManager.loadCurrentProjectScreenplayLanguage();

    final project = _projectsManager.currentProject;
    final previewedVersion = project?.previewedVersion;

    // Applies the same raw/styled right-dock transition the mode toggle itself applies (see
    // `_rightDockTransitionFor`), now that the persisted mode is known: e.g. an editor that was
    // left in styled mode last session starts with its (session-local, always-preview-by-default)
    // dock already closed and remembered, rather than briefly showing a preview tab that mode
    // immediately forbids.
    final dockTabTransition = _rightDockTransitionFor(
      newMode: mode,
      isReadOnly: project?.isReadOnly ?? false,
      rightDockTab: state.rightDockTab,
      autoClosedRightDockTab: state.autoClosedRightDockTab,
    );

    if (project == null) {
      final document = _fountainParser.parse("");
      emitter(
        state.copyToLoadedWithoutProject(
          document: document,
          mode: mode,
          isPageSimulationEnabled: isPageSimulationEnabled,
          areStyledSceneNumbersVisible: areStyledSceneNumbersVisible,
          isSpellCheckVisible: isSpellCheckVisible,
          screenplayLanguage: screenplayLanguage,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          rightDockTab: dockTabTransition.rightDockTab,
          forceRightDockTabValue: dockTabTransition.forceRightDockTabValue,
          autoClosedRightDockTab: dockTabTransition.autoClosedRightDockTab,
          forceAutoClosedRightDockTabValue: dockTabTransition.forceAutoClosedRightDockTabValue,
        ),
      );
      return;
    }

    final text = await _screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: screenplayIdOf(project),
    );
    final document = _fountainParser.parse(text);
    final pageSetup = await _loadPageSetup(project);

    emitter(
      state.copyToLoaded(
        title: project.name,
        mode: mode,
        previewedVersionId: previewedVersion?.id,
        text: text,
        document: document,
        pageSetup: pageSetup,
        isPageSimulationEnabled: isPageSimulationEnabled,
        areStyledSceneNumbersVisible: areStyledSceneNumbersVisible,
        isSpellCheckVisible: isSpellCheckVisible,
        screenplayLanguage: screenplayLanguage,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        rightDockTab: dockTabTransition.rightDockTab,
        forceRightDockTabValue: dockTabTransition.forceRightDockTabValue,
        autoClosedRightDockTab: dockTabTransition.autoClosedRightDockTab,
        forceAutoClosedRightDockTabValue: dockTabTransition.forceAutoClosedRightDockTabValue,
      ),
    );
  }

  /// Reads the page setup [project] is typeset with: the version's own while one is being
  /// previewed, and the project's page format paired with the app-wide margins preference
  /// otherwise.
  ///
  /// A previewed version is laid out with the setup it was written against — that is what keeps the
  /// page count shown on its card true — and that setup travels on the open project model alone: a
  /// preview never writes it anywhere, since its margins half is an app-wide preference that has
  /// nothing to do with this project.
  Future<OcptPageSetup> _loadPageSetup(OcptOpenProjectModel project) async =>
      project.previewedPageSetup ??
      OcptPageSetup(
        format: await _projectsManager.loadCurrentProjectPageFormat() ?? OcptPageFormat.usLetter,
        margins:
            await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

  /// Computes how the right dock's active tab and its "auto-closed" memory should change when the
  /// editing mode becomes [newMode], applied identically by [_onModeToggled] and by
  /// [_load] once the persisted mode is known.
  ///
  /// - becoming a mode with no preview tab while that tab is active closes the dock and remembers
  ///   it in [autoClosedRightDockTab] (decision 4: styled mode has no preview tab at all, and
  ///   neither has a read-only preview, whose whole centre already *is* the formatted screenplay);
  /// - becoming a mode that has one again, with the dock closed and a tab remembered, reopens it on
  ///   that tab and forgets it;
  /// - any other combination (the syntax tab active, the dock already closed with nothing
  ///   remembered, switching to the mode it's already in, …) is left untouched — in particular,
  ///   this never touches a dock the user closed by hand (which never leaves anything in
  ///   [autoClosedRightDockTab] to restore, since every explicit close/tab-selection clears it).
  ({
    OcptEditorRightDockTab? rightDockTab,
    bool forceRightDockTabValue,
    OcptEditorRightDockTab? autoClosedRightDockTab,
    bool forceAutoClosedRightDockTabValue,
  })
  _rightDockTransitionFor({
    required OcptEditorMode newMode,
    required bool isReadOnly,
    required OcptEditorRightDockTab? rightDockTab,
    required OcptEditorRightDockTab? autoClosedRightDockTab,
  }) {
    final isPreviewTabAvailable = OcptEditorState.isPreviewTabAvailableFor(
      mode: newMode,
      isReadOnly: isReadOnly,
    );

    if (!isPreviewTabAvailable && rightDockTab == OcptEditorRightDockTab.preview) {
      return (
        rightDockTab: null,
        forceRightDockTabValue: true,
        autoClosedRightDockTab: OcptEditorRightDockTab.preview,
        forceAutoClosedRightDockTabValue: false,
      );
    }
    if (isPreviewTabAvailable && rightDockTab == null && autoClosedRightDockTab != null) {
      return (
        rightDockTab: autoClosedRightDockTab,
        forceRightDockTabValue: false,
        autoClosedRightDockTab: null,
        forceAutoClosedRightDockTabValue: true,
      );
    }
    return (
      rightDockTab: rightDockTab,
      forceRightDockTabValue: false,
      autoClosedRightDockTab: autoClosedRightDockTab,
      forceAutoClosedRightDockTabValue: false,
    );
  }

  /// Stores the edited text, marks it dirty, and restarts the parse and autosave debounces.
  Future<void> _onTextChanged(
    OcptEditorTextChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    if (_undeliveredText == event.text) {
      _undeliveredText = null;
    }

    // The close has flushed this edit by itself: starting timers now would outlive the bloc.
    if (_isDisposing) {
      return;
    }

    emitter(state.copyWithTypedText(text: event.text));

    _parseTimer?.cancel();
    _parseTimer = Timer(_parseDebounce, () {
      if (!isClosed) {
        add(const OcptEditorParseRequestedEvent());
      }
    });

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounce, () {
      if (!isClosed) {
        add(const OcptEditorSaveRequestedEvent(isManual: false));
      }
    });
  }

  /// Re-parses the current text into a fresh document.
  ///
  /// The spell-check bloc requests its raw pass off the fresh document this emits, exactly where
  /// `docs/architecture/screenplay.md` puts it: on this same parse debounce, never a keystroke. The
  /// statistics bloc refreshes its counters off it too.
  Future<void> _onParseRequested(
    OcptEditorParseRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWithParsedDocument(document: _fountainParser.parse(state.text)));
  }

  /// Saves the current text to the project database, unless there is nothing dirty to save.
  ///
  /// Delegates to [_saveCurrentText], tagged [OcptSnapshotReason.manual] or
  /// [OcptSnapshotReason.timer] depending on [OcptEditorSaveRequestedEvent.isManual].
  Future<void> _onSaveRequested(
    OcptEditorSaveRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    if (_projectsManager.currentProject == null || !state.isDirty) {
      return;
    }

    await _saveCurrentText(
      reason: event.isManual ? OcptSnapshotReason.manual : OcptSnapshotReason.timer,
      emitter: emitter,
    );
  }

  /// Saves the current text to the project database, tagged [reason]. Does nothing if no project
  /// is open.
  ///
  /// If the text is edited again while the save is in flight, the screenplay stays dirty once the
  /// save completes (the newer text will be picked up by the next autosave). A failed save keeps
  /// the screenplay dirty and raises the transient save error.
  Future<void> _saveCurrentText({
    required OcptSnapshotReason reason,
    required Emitter<OcptEditorState> emitter,
  }) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    _autosaveTimer?.cancel();
    final textToSave = state.text;
    emitter(state.copyWithSaving());

    try {
      await _screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: screenplayIdOf(project),
        fountainText: textToSave,
        snapshotReason: reason,
      );

      emitter(state.copyWithSaved(isDirty: state.text != textToSave, lastSavedAt: DateTime.now()));

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a save that lands while the tab showing it is already open.
      if (state.rightDockTab == OcptEditorRightDockTab.versions) {
        add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      }
    } catch (error, stackTrace) {
      _logger.e(
        "A problem occurred when tried to save the screenplay of project "
        "${project.primaryScreenplayId}: ${error.runtimeType}",
        null,
        stackTrace,
      );
      emitter(state.copyWithSaveFailed());
    }
  }

  /// Records the source line the caret moved to. The statistics bloc recomputes the scene's counters
  /// when that lands the caret on a different scene.
  Future<void> _onCaretMoved(
    OcptEditorCaretMovedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWithCurrentLine(currentLine: event.line));
  }

  /// Emits a fresh jump request for the page to move the caret to the clicked scene's start.
  Future<void> _onSceneJumpRequested(
    OcptEditorSceneJumpRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWithJumpRequest(
        jumpRequest: OcptEditorJumpRequest(charOffset: event.charOffset, id: _nextJumpRequestId++),
      ),
    );
  }

  /// Toggles the scene panel's visibility.
  Future<void> _onScenePanelToggled(
    OcptEditorScenePanelToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWithScenePanelVisibility(isScenePanelVisible: !state.isScenePanelVisible));
  }

  /// Selects a tab of the right dock (decision 3's toggle semantics: the already-active tab
  /// closes the dock, any other tab opens or switches to it), records it as
  /// [OcptEditorState.lastRightDockTab] (even when it just closed the dock: that's still the tab
  /// the toolbar's toggle must bring back), and clears
  /// [OcptEditorState.autoClosedRightDockTab] since this is an explicit user action.
  Future<void> _onRightDockTabSelected(
    OcptEditorRightDockTabSelectedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final isAlreadyActive = state.rightDockTab == event.tab;
    emitter(state.copyWithRightDockTabSelected(tab: event.tab, isAlreadyActive: isAlreadyActive));

    // Opening the `Versions` tab is one of the two moments `MixinOcptProjectVersionsBloc`'s
    // working-copy card needs a fresh read for: the other is a save landing while it is already
    // the one showing (see `_saveCurrentText`).
    if (!isAlreadyActive && event.tab == OcptEditorRightDockTab.versions) {
      add(const OcptProjectWorkingCopyRefreshRequestedEvent());
    }
  }

  /// Toggles the right dock from the workspace toolbar: an open dock closes, a closed one reopens
  /// on [OcptEditorState.lastRightDockTab], and clears
  /// [OcptEditorState.autoClosedRightDockTab] since this is an explicit user action.
  ///
  /// Reopening applies the same rule on the remembered tab as [_rightDockTransitionFor] does on a
  /// mode switch: the styled mode and a version's read-only preview both have no preview tab at
  /// all, so a remembered preview tab falls back to the syntax guide there rather than reopening a
  /// dock with nothing to show. The memory itself is left untouched, so going back to raw mode (or
  /// leaving the preview) still brings the preview back.
  Future<void> _onRightDockToggled(
    OcptEditorRightDockToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    if (state.rightDockTab != null) {
      emitter(state.copyWithRightDockClosed());
      return;
    }

    final isPreviewForbidden =
        !state.isPreviewTabAvailable && state.lastRightDockTab == OcptEditorRightDockTab.preview;

    emitter(
      state.copyWithRightDockReopened(
        rightDockTab: isPreviewForbidden ? OcptEditorRightDockTab.syntax : state.lastRightDockTab,
      ),
    );
  }

  /// Closes the right dock via its own × close button, and clears
  /// [OcptEditorState.autoClosedRightDockTab] since this is an explicit user action.
  Future<void> _onRightDockClosed(
    OcptEditorRightDockClosedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWithRightDockClosed());
  }

  /// Applies and persists whichever of [OcptEditorDockFractionsChangedEvent.left]/[.right] is
  /// given, dispatched once per drag gesture rather than per frame (see the event's doc comment).
  Future<void> _onDockFractionsChanged(
    OcptEditorDockFractionsChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWithDockFractions(leftDockFraction: event.left, rightDockFraction: event.right),
    );

    final left = event.left;
    if (left != null) {
      await _propertiesManager.editorLeftDockFraction.store(left);
    }
    final right = event.right;
    if (right != null) {
      await _propertiesManager.editorRightDockFraction.store(right);
    }
  }

  /// Restores both dock fractions to their defaults and persists them ("Reset panel layout").
  Future<void> _onDockLayoutReset(
    OcptEditorDockLayoutResetEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWithDockFractions(
        leftDockFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightDockFraction: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
    await _propertiesManager.editorLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.editorRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
  }

  /// Toggles the editing mode between styled and raw, persists the new mode, and applies the
  /// right dock's raw/styled transition (see [_rightDockTransitionFor]).
  ///
  /// The spell-check bloc requests a raw pass the moment raw becomes the mounted mode, see
  /// `OcptEditorSpellCheckBloc`.
  Future<void> _onModeToggled(
    OcptEditorModeToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newMode = state.mode == OcptEditorMode.styled
        ? OcptEditorMode.raw
        : OcptEditorMode.styled;
    final dockTabTransition = _rightDockTransitionFor(
      newMode: newMode,
      isReadOnly: state.isPreviewingVersion,
      rightDockTab: state.rightDockTab,
      autoClosedRightDockTab: state.autoClosedRightDockTab,
    );

    emitter(
      state.copyWithMode(
        mode: newMode,
        rightDockTab: dockTabTransition.rightDockTab,
        forceRightDockTabValue: dockTabTransition.forceRightDockTabValue,
        autoClosedRightDockTab: dockTabTransition.autoClosedRightDockTab,
        forceAutoClosedRightDockTabValue: dockTabTransition.forceAutoClosedRightDockTabValue,
      ),
    );
    await _propertiesManager.editorMode.store(newMode);
  }

  /// Toggles the "Word-like" page simulation, and persists the new value.
  Future<void> _onPageSimulationToggled(
    OcptEditorPageSimulationToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newValue = !state.isPageSimulationEnabled;
    emitter(state.copyWithPageSimulation(isPageSimulationEnabled: newValue));
    await _propertiesManager.isPageSimulationEnabled.store(newValue);
  }

  /// Toggles whether the styled editor shows scene numbers, and persists the new value.
  Future<void> _onStyledSceneNumbersToggled(
    OcptEditorStyledSceneNumbersToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newValue = !state.areStyledSceneNumbersVisible;
    emitter(state.copyWithStyledSceneNumbers(areStyledSceneNumbersVisible: newValue));
    await _propertiesManager.styledSceneNumbersVisible.store(newValue);
  }

  /// Toggles whether this machine shows the spell-check underlines, and persists the new value.
  ///
  /// `OcptEditorSpellCheckBloc` sees the switch move: it clears the underlines when it is now off and
  /// loads or unloads the dictionary as the two switches of `docs/architecture/screenplay.md` dictate.
  Future<void> _onSpellCheckToggled(
    OcptEditorSpellCheckToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newValue = !state.isSpellCheckVisible;
    emitter(state.copyWithSpellCheckVisibility(isSpellCheckVisible: newValue));
    await _propertiesManager.spellCheckVisible.store(newValue);
  }

  /// Persists the new page setup (format per-project, margins app-wide), and applies it live. The
  /// statistics bloc recomputes the counters at once, since the page count depends on the page
  /// format.
  Future<void> _onPageSetupChanged(
    OcptEditorPageSetupChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectPageFormat(event.pageSetup.format);
    await _propertiesManager.pageMargins.store(event.pageSetup.margins);
    emitter(state.copyWithPageSetup(pageSetup: event.pageSetup));
  }

  /// Re-reads the project's page format and screenplay language after the project settings page
  /// changed something, repaginating against the first and emitting the second, which
  /// `OcptEditorSpellCheckBloc` drives its dictionary from.
  ///
  /// These are the only fields of the project settings page this bloc's own state depends on: the
  /// currency has nothing to do with a screenplay's pagination or its spell-checking. Re-reading them
  /// rather than carrying them on the event is what lets the project settings page own the write
  /// without this bloc having to learn its shape.
  Future<void> _onProjectSettingsChanged(
    OcptEditorProjectSettingsChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final pageFormat = await _projectsManager.loadCurrentProjectPageFormat();
    if (pageFormat != null && pageFormat != state.pageSetup.format) {
      emitter(state.copyWithPageFormat(pageFormat: pageFormat));
    }

    final screenplayLanguage = await _projectsManager.loadCurrentProjectScreenplayLanguage();
    if (screenplayLanguage != state.screenplayLanguage) {
      emitter(state.copyWithScreenplayLanguage(screenplayLanguage: screenplayLanguage));
    }
  }

  /// Clears the transient save error currently shown, if any.
  Future<void> _onSaveErrorDismissed(
    OcptEditorSaveErrorDismissedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWithSaveErrorDismissed());
  }

  /// Writes the unsaved text, tagged [OcptSnapshotReason.export], before an export reads it, so the
  /// exported file matches exactly what the project stores.
  ///
  /// The parse and autosave debounces are cancelled first: the save below is the one that counts, and
  /// the export that asked for it hands the text over as it stands once this is done. A failed save
  /// raises the transient save error like any other and the export carries on with the text.
  Future<void> _onSaveForExportRequested(
    OcptEditorSaveForExportRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();

    if (state.isDirty) {
      await _saveCurrentText(reason: OcptSnapshotReason.export, emitter: emitter);
    }
  }

  /// Replaces the screenplay text with the one an import has just written to the project: the text
  /// is clean (the import saved it), the caret goes back to the first line, and the document and the
  /// counters follow at once instead of waiting for the typing debounces.
  Future<void> _onImportedTextApplied(
    OcptEditorImportedTextAppliedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();

    emitter(state.copyWithImportedText(text: event.text));
    await _onParseRequested(const OcptEditorParseRequestedEvent(), emitter);
    emitter(state.copyWithTextReplaced());
  }

  /// A placeholder source range for the title-page entries built from a title-page change event's
  /// fields: [FountainTitlePageWriter] only reads an entry's key and values, never its source
  /// range, so this stands in without needing a real one.
  static const _placeholderTitlePageEntryRange = FountainSourceRange(
    startLine: 0,
    endLine: 0,
    startOffset: 0,
    endOffset: 0,
  );

  /// Rewrites the screenplay's title-page section from [event]'s six fields, saves the result
  /// (tagged [OcptSnapshotReason.manual]), and re-parses it.
  ///
  /// Reuses [_saveCurrentText] for the save itself, so a failure surfaces through the same
  /// [OcptEditorState.hasSaveError] path a normal edit's save would.
  Future<void> _onTitlePageChanged(
    OcptEditorTitlePageChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final entries = _titlePageEntriesFrom(event);
    final newText = const FountainTitlePageWriter().apply(
      source: state.text,
      existingRange: state.document?.titlePage?.sourceRange,
      entries: entries,
    );
    if (newText == state.text) {
      return;
    }

    _parseTimer?.cancel();
    emitter(state.copyWithTitlePageText(text: newText));
    await _saveCurrentText(reason: OcptSnapshotReason.manual, emitter: emitter);
    await _onParseRequested(const OcptEditorParseRequestedEvent(), emitter);
    emitter(state.copyWithTextReplaced());
  }

  /// Builds the title-page entries [event] describes, skipping every field left blank.
  List<FountainTitlePageEntry> _titlePageEntriesFrom(OcptEditorTitlePageChangedEvent event) {
    final fields = {
      'Title': event.title,
      'Credit': event.credit,
      'Author': event.author,
      'Draft date': event.draftDate,
      'Contact': event.contact,
      'Source': event.source,
    };

    return [
      for (final field in fields.entries)
        if (field.value.trim().isNotEmpty)
          FountainTitlePageEntry(
            key: field.key,
            values: [field.value.trim()],
            sourceRange: _placeholderTitlePageEntryRange,
          ),
    ];
  }

  /// Leaves the editor: cancels the pending debounce timers, flushes the unsaved change if there
  /// is one, closes the current project, and navigates back to the home page.
  ///
  /// The project is closed before navigating, so [disposeLifeCycle]'s own close-flush (guarded on
  /// [OcptProjectsManager.currentProject]) finds no project any more and stays a no-op instead of
  /// trying to save through the already-closed database.
  Future<void> _onBackRequested(
    OcptEditorBackRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();

    if (state.isDirty) {
      await _onSaveRequested(const OcptEditorSaveRequestedEvent(isManual: true), emitter);
    }

    await _projectsManager.closeCurrentProject();
    _routerManager.pop();
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  ///
  /// Cancels the debounce timers and flushes any pending unsaved change with a best-effort save,
  /// so leaving the page right after typing never loses the last edits. The flush bypasses the
  /// event queue (the bloc is closing), and a failure here is only logged: the page is already
  /// gone, so there is no UI left to surface it to.
  @override
  Future<void> disposeLifeCycle() async {
    _isDisposing = true;
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();
    _unregisterUnsavedChangesReporter();

    // An edit handed over just before the close has not reached its handler yet: it is the newest
    // text, so it is the one to flush.
    final undeliveredText = _undeliveredText;
    final project = _projectsManager.currentProject;
    if (project != null && (state.isDirty || undeliveredText != null) && !state.isSaving) {
      try {
        await _screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: screenplayIdOf(project),
          fountainText: undeliveredText ?? state.text,
          snapshotReason: OcptSnapshotReason.timer,
        );
      } catch (error, stackTrace) {
        _logger.e(
          "A problem occurred when tried to flush the screenplay of project "
          "${project.primaryScreenplayId} while leaving the editor: ${error.runtimeType}",
          null,
          stackTrace,
        );
      }
    }

    return super.disposeLifeCycle();
  }
}
