// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_current_scene_index.dart';

/// This is the bloc class for the editor page.
///
/// It loads the current project's screenplay from [OcptProjectsManager] on entry, re-parses the
/// source text with [FountainParser] after a short debounce on every edit (parsing a full feature
/// script takes single-digit milliseconds, so it runs synchronously in the bloc), and autosaves
/// through [OcptScreenplayService] (which snapshots the previous text and reconciles the scene
/// index) after a longer debounce. Manual saves (toolbar button, Ctrl+S) go through the same save
/// path, only tagged [OcptSnapshotReason.manual] instead of [OcptSnapshotReason.timer].
/// `OcptEditorState.statistics` is recomputed on its own debounce, restarted on every parse tick,
/// since pagination is too heavy to run on every one of those.
/// `OcptEditorState.sceneStatistics` composes the whole document too, but only to read off one
/// scene's slice of it, so it is recomputed directly on the parse tick (never on every keystroke,
/// since typing only reaches it through that debounce) plus whenever the caret lands on a
/// different scene (a comparatively rare event, unlike typing).
///
/// When the bloc closes (the user leaves the page), any pending unsaved change is flushed with a
/// best-effort save: the debounce timers are cancelled and the save runs directly against the
/// service, so no edit is lost by navigating away right after typing.
class OcptEditorBloc extends BlocForMixin<OcptEditorState> {
  /// The default delay between the last edit and the re-parse of the source text.
  static const defaultParseDebounce = Duration(milliseconds: 150);

  /// The default delay between the last edit and the autosave.
  static const defaultAutosaveDebounce = Duration(seconds: 2);

  /// The default delay between the last parse tick and recomputing statistics, kept separate
  /// from [defaultParseDebounce]: `FountainScriptComposer.compose` (which
  /// `FountainScriptStatistics.of` calls to get the page count) measured at ~14 ms per pass on a
  /// 141-page script, close enough to a frame budget that it must not run on every 150 ms parse
  /// tick while the user is typing continuously.
  static const defaultStatisticsDebounce = Duration(milliseconds: 500);

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

  /// The delay between the last parse tick and recomputing statistics.
  final Duration _statisticsDebounce;

  /// The running parse debounce timer, if any.
  Timer? _parseTimer;

  /// The running autosave debounce timer, if any.
  Timer? _autosaveTimer;

  /// The running statistics debounce timer, if any.
  Timer? _statisticsTimer;

  /// The id given to the next [OcptEditorJumpRequest], increased after each one.
  int _nextJumpRequestId = 0;

  /// Class constructor
  ///
  /// [parseDebounce], [autosaveDebounce] and [statisticsDebounce] are only meant to be overridden
  /// by tests, to keep them fast and deterministic.
  OcptEditorBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptScreenplayService? screenplayService,
    OcptExportManager? exportManager,
    Duration parseDebounce = defaultParseDebounce,
    Duration autosaveDebounce = defaultAutosaveDebounce,
    Duration statisticsDebounce = defaultStatisticsDebounce,
  }) : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _screenplayService =
           screenplayService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).screenplayService,
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _parseDebounce = parseDebounce,
       _autosaveDebounce = autosaveDebounce,
       _statisticsDebounce = statisticsDebounce,
       super(const OcptEditorState.init()) {
    add(const OcptEditorLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptEditorLoadRequestedEvent>(_onLoadRequested);
    on<OcptEditorTextChangedEvent>(_onTextChanged);
    on<OcptEditorParseRequestedEvent>(_onParseRequested);
    on<OcptEditorStatisticsRecomputeRequestedEvent>(_onStatisticsRecomputeRequested);
    on<OcptEditorSaveRequestedEvent>(_onSaveRequested);
    on<OcptEditorCaretMovedEvent>(_onCaretMoved);
    on<OcptEditorSceneJumpRequestedEvent>(_onSceneJumpRequested);
    on<OcptEditorScenePanelToggledEvent>(_onScenePanelToggled);
    on<OcptEditorRightDockTabSelectedEvent>(_onRightDockTabSelected);
    on<OcptEditorRightDockClosedEvent>(_onRightDockClosed);
    on<OcptEditorDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptEditorDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptEditorModeToggledEvent>(_onModeToggled);
    on<OcptEditorPageSimulationToggledEvent>(_onPageSimulationToggled);
    on<OcptEditorStyledSceneNumbersToggledEvent>(_onStyledSceneNumbersToggled);
    on<OcptEditorPageSetupChangedEvent>(_onPageSetupChanged);
    on<OcptEditorSaveErrorDismissedEvent>(_onSaveErrorDismissed);
    on<OcptEditorBackRequestedEvent>(_onBackRequested);
    on<OcptEditorExportRequestedEvent>(_onExportRequested);
    on<OcptEditorExportPdfRequestedEvent>(_onExportPdfRequested);
    on<OcptEditorImportRequestedEvent>(_onImportRequested);
    on<OcptEditorIoNoticeDismissedEvent>(_onIoNoticeDismissed);
    on<OcptEditorTitlePageChangedEvent>(_onTitlePageChanged);
  }

  /// Loads the current project's screenplay text, title and page format, and parses the text,
  /// together with the persisted preferred editor mode.
  ///
  /// The editor route is guarded by the router manager, so a project is normally always open
  /// here; if none is (e.g. the bloc is built directly in a test), the state simply stays in its
  /// init form with an empty document.
  Future<void> _onLoadRequested(
    OcptEditorLoadRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final mode = await _propertiesManager.editorMode.load() ?? OcptEditorMode.styled;
    final isPageSimulationEnabled = await _propertiesManager.isPageSimulationEnabled.load() ?? true;
    final areStyledSceneNumbersVisible =
        await _propertiesManager.styledSceneNumbersVisible.load() ?? true;
    final leftDockFraction =
        await _propertiesManager.editorLeftDockFraction.load() ?? OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.editorRightDockFraction.load() ?? OcptWorkspaceDock.rightDefaultFraction;

    // Applies the same raw/styled right-dock transition the mode toggle itself applies (see
    // `_rightDockTransitionFor`), now that the persisted mode is known: e.g. an editor that was
    // left in styled mode last session starts with its (session-local, always-preview-by-default)
    // dock already closed and remembered, rather than briefly showing a preview tab that mode
    // immediately forbids.
    final dockTabTransition = _rightDockTransitionFor(
      newMode: mode,
      rightDockTab: state.rightDockTab,
      autoClosedRightDockTab: state.autoClosedRightDockTab,
    );

    final project = _projectsManager.currentProject;
    if (project == null) {
      final document = _fountainParser.parse("");
      emitter(
        state.copyWith(
          isLoading: false,
          document: document,
          mode: mode,
          isPageSimulationEnabled: isPageSimulationEnabled,
          areStyledSceneNumbersVisible: areStyledSceneNumbersVisible,
          leftDockFraction: leftDockFraction,
          rightDockFraction: rightDockFraction,
          rightDockTab: dockTabTransition.rightDockTab,
          clearRightDockTab: dockTabTransition.clearRightDockTab,
          autoClosedRightDockTab: dockTabTransition.autoClosedRightDockTab,
          clearAutoClosedRightDockTab: dockTabTransition.clearAutoClosedRightDockTab,
          statistics: _statisticsFor(document, state.pageSetup),
          clearSceneStatistics: true,
        ),
      );
      return;
    }

    final text = await _screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: project.primaryScreenplayId,
    );
    final pageFormat = await _projectsManager.loadCurrentProjectPageFormat();
    final margins = await _propertiesManager.pageMargins.load();
    final document = _fountainParser.parse(text);
    final pageSetup = OcptPageSetup(
      format: pageFormat ?? OcptPageFormat.usLetter,
      margins: margins ?? const FountainPageMargins.standard(),
    );
    final sceneStats = _sceneStatisticsFor(
      document,
      pageSetup,
      currentSceneIndexFor(document.scenes, state.currentLine),
    );

    emitter(
      state.copyWith(
        isLoading: false,
        title: project.name,
        mode: mode,
        text: text,
        document: document,
        pageSetup: pageSetup,
        isPageSimulationEnabled: isPageSimulationEnabled,
        areStyledSceneNumbersVisible: areStyledSceneNumbersVisible,
        leftDockFraction: leftDockFraction,
        rightDockFraction: rightDockFraction,
        rightDockTab: dockTabTransition.rightDockTab,
        clearRightDockTab: dockTabTransition.clearRightDockTab,
        autoClosedRightDockTab: dockTabTransition.autoClosedRightDockTab,
        clearAutoClosedRightDockTab: dockTabTransition.clearAutoClosedRightDockTab,
        statistics: _statisticsFor(document, pageSetup),
        sceneStatistics: sceneStats,
        clearSceneStatistics: sceneStats == null,
      ),
    );
  }

  /// Computes the statistics of [document] laid out at [pageSetup]'s metrics.
  FountainScriptStatistics _statisticsFor(FountainDocument document, OcptPageSetup pageSetup) =>
      FountainScriptStatistics.of(document, pageSetup.toMetrics());

  /// Computes the statistics of the scene at [sceneIndex] in [document] laid out at [pageSetup]'s
  /// metrics, or null if [sceneIndex] is null (the caret precedes every scene, or [document] has
  /// no scenes at all).
  FountainSceneStatistics? _sceneStatisticsFor(
    FountainDocument document,
    OcptPageSetup pageSetup,
    int? sceneIndex,
  ) => sceneIndex == null ? null : FountainSceneStatistics.of(document, pageSetup.toMetrics(), sceneIndex);

  /// Computes how the right dock's active tab and its "auto-closed" memory should change when the
  /// editing mode becomes [newMode], applied identically by [_onModeToggled] and by
  /// [_onLoadRequested] once the persisted mode is known.
  ///
  /// - switching to styled while the preview tab is active closes the dock and remembers that tab
  ///   in [autoClosedRightDockTab] (decision 4: styled mode has no preview tab at all);
  /// - switching to raw with the dock closed and a tab remembered reopens it on that tab and
  ///   forgets it;
  /// - any other combination (the syntax tab active, the dock already closed with nothing
  ///   remembered, switching to the mode it's already in, …) is left untouched — in particular,
  ///   this never touches a dock the user closed by hand (which never leaves anything in
  ///   [autoClosedRightDockTab] to restore, since every explicit close/tab-selection clears it).
  ({
    OcptEditorRightDockTab? rightDockTab,
    bool clearRightDockTab,
    OcptEditorRightDockTab? autoClosedRightDockTab,
    bool clearAutoClosedRightDockTab,
  })
  _rightDockTransitionFor({
    required OcptEditorMode newMode,
    required OcptEditorRightDockTab? rightDockTab,
    required OcptEditorRightDockTab? autoClosedRightDockTab,
  }) {
    if (newMode == OcptEditorMode.styled && rightDockTab == OcptEditorRightDockTab.preview) {
      return (
        rightDockTab: null,
        clearRightDockTab: true,
        autoClosedRightDockTab: OcptEditorRightDockTab.preview,
        clearAutoClosedRightDockTab: false,
      );
    }
    if (newMode == OcptEditorMode.raw && rightDockTab == null && autoClosedRightDockTab != null) {
      return (
        rightDockTab: autoClosedRightDockTab,
        clearRightDockTab: false,
        autoClosedRightDockTab: null,
        clearAutoClosedRightDockTab: true,
      );
    }
    return (
      rightDockTab: rightDockTab,
      clearRightDockTab: false,
      autoClosedRightDockTab: autoClosedRightDockTab,
      clearAutoClosedRightDockTab: false,
    );
  }

  /// Stores the edited text, marks it dirty, and restarts the parse and autosave debounces.
  Future<void> _onTextChanged(
    OcptEditorTextChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(text: event.text, isDirty: true));

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

  /// Re-parses the current text into a fresh document, recomputes the current scene's statistics
  /// right away (cheap relative to [_scheduleStatisticsRecompute]'s script-wide pagination, and
  /// tied to this same 150 ms parse debounce rather than typing itself), then (re)starts the
  /// script-wide statistics debounce.
  Future<void> _onParseRequested(
    OcptEditorParseRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final document = _fountainParser.parse(state.text);
    final sceneStats = _sceneStatisticsFor(
      document,
      state.pageSetup,
      currentSceneIndexFor(document.scenes, state.currentLine),
    );
    emitter(
      state.copyWith(
        document: document,
        sceneStatistics: sceneStats,
        clearSceneStatistics: sceneStats == null,
      ),
    );
    _scheduleStatisticsRecompute();
  }

  /// (Re)starts the statistics debounce timer: while the user keeps typing, each parse tick
  /// restarts it, so the heavy pagination pass behind `FountainScriptStatistics.of` only actually
  /// runs once typing pauses for [_statisticsDebounce], never on every parse tick.
  void _scheduleStatisticsRecompute() {
    _statisticsTimer?.cancel();
    _statisticsTimer = Timer(_statisticsDebounce, () {
      if (!isClosed) {
        add(const OcptEditorStatisticsRecomputeRequestedEvent());
      }
    });
  }

  /// Recomputes statistics from the current document and page setup, once the statistics
  /// debounce elapses. A no-op if nothing has been parsed yet.
  Future<void> _onStatisticsRecomputeRequested(
    OcptEditorStatisticsRecomputeRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final document = state.document;
    if (document == null) {
      return;
    }
    emitter(state.copyWith(statistics: _statisticsFor(document, state.pageSetup)));
  }

  /// Recomputes statistics for [document] at [pageSetup] and emits them immediately, cancelling
  /// any pending debounced recompute so it doesn't redundantly fire again right after. Used by the
  /// deliberate, infrequent actions (load, import, title-page edit, page-setup change) that should
  /// show up-to-date counts at once rather than waiting out the typing debounce.
  void _recomputeStatisticsNow({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required Emitter<OcptEditorState> emitter,
  }) {
    _statisticsTimer?.cancel();
    final sceneStats = _sceneStatisticsFor(
      document,
      pageSetup,
      currentSceneIndexFor(document.scenes, state.currentLine),
    );
    emitter(
      state.copyWith(
        statistics: _statisticsFor(document, pageSetup),
        sceneStatistics: sceneStats,
        clearSceneStatistics: sceneStats == null,
      ),
    );
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
    emitter(state.copyWith(isSaving: true));

    try {
      await _screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: textToSave,
        snapshotReason: reason,
      );

      emitter(
        state.copyWith(
          isSaving: false,
          isDirty: state.text != textToSave,
          lastSavedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to save the screenplay of the project at "
          "${project.path}: $error");
      emitter(state.copyWith(isSaving: false, hasSaveError: true));
    }
  }

  /// Records the source line the caret moved to, and, if that actually lands the caret on a
  /// different scene, recomputes that scene's statistics right away rather than waiting for the
  /// next parse tick — moving the caret is far rarer than typing a character, so this stays well
  /// clear of the "never per keystroke" cost [OcptEditorState.sceneStatistics] documents.
  Future<void> _onCaretMoved(
    OcptEditorCaretMovedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final previousSceneIndex = state.currentSceneIndex;
    emitter(state.copyWith(currentLine: event.line));

    final document = state.document;
    final newSceneIndex = state.currentSceneIndex;
    if (document != null && newSceneIndex != previousSceneIndex) {
      final sceneStats = _sceneStatisticsFor(document, state.pageSetup, newSceneIndex);
      emitter(
        state.copyWith(sceneStatistics: sceneStats, clearSceneStatistics: sceneStats == null),
      );
    }
  }

  /// Emits a fresh jump request for the page to move the caret to the clicked scene's start.
  Future<void> _onSceneJumpRequested(
    OcptEditorSceneJumpRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(
        jumpRequest: OcptEditorJumpRequest(charOffset: event.charOffset, id: _nextJumpRequestId++),
      ),
    );
  }

  /// Toggles the scene panel's visibility.
  Future<void> _onScenePanelToggled(
    OcptEditorScenePanelToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(isScenePanelVisible: !state.isScenePanelVisible));
  }

  /// Selects a tab of the right dock (decision 3's toggle semantics: the already-active tab
  /// closes the dock, any other tab opens or switches to it), and clears
  /// [OcptEditorState.autoClosedRightDockTab] since this is an explicit user action.
  Future<void> _onRightDockTabSelected(
    OcptEditorRightDockTabSelectedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final isAlreadyActive = state.rightDockTab == event.tab;
    emitter(
      state.copyWith(
        rightDockTab: isAlreadyActive ? null : event.tab,
        clearRightDockTab: isAlreadyActive,
        clearAutoClosedRightDockTab: true,
      ),
    );
  }

  /// Closes the right dock via its own × close button, and clears
  /// [OcptEditorState.autoClosedRightDockTab] since this is an explicit user action.
  Future<void> _onRightDockClosed(
    OcptEditorRightDockClosedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(clearRightDockTab: true, clearAutoClosedRightDockTab: true));
  }

  /// Applies and persists whichever of [OcptEditorDockFractionsChangedEvent.left]/[.right] is
  /// given, dispatched once per drag gesture rather than per frame (see the event's doc comment).
  Future<void> _onDockFractionsChanged(
    OcptEditorDockFractionsChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(leftDockFraction: event.left, rightDockFraction: event.right),
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
      state.copyWith(
        leftDockFraction: OcptWorkspaceDock.leftDefaultFraction,
        rightDockFraction: OcptWorkspaceDock.rightDefaultFraction,
      ),
    );
    await _propertiesManager.editorLeftDockFraction.store(OcptWorkspaceDock.leftDefaultFraction);
    await _propertiesManager.editorRightDockFraction.store(OcptWorkspaceDock.rightDefaultFraction);
  }

  /// Toggles the editing mode between styled and raw, persists the new mode, and applies the
  /// right dock's raw/styled transition (see [_rightDockTransitionFor]).
  Future<void> _onModeToggled(
    OcptEditorModeToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newMode = state.mode == OcptEditorMode.styled ? OcptEditorMode.raw : OcptEditorMode.styled;
    final dockTabTransition = _rightDockTransitionFor(
      newMode: newMode,
      rightDockTab: state.rightDockTab,
      autoClosedRightDockTab: state.autoClosedRightDockTab,
    );

    emitter(
      state.copyWith(
        mode: newMode,
        rightDockTab: dockTabTransition.rightDockTab,
        clearRightDockTab: dockTabTransition.clearRightDockTab,
        autoClosedRightDockTab: dockTabTransition.autoClosedRightDockTab,
        clearAutoClosedRightDockTab: dockTabTransition.clearAutoClosedRightDockTab,
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
    emitter(state.copyWith(isPageSimulationEnabled: newValue));
    await _propertiesManager.isPageSimulationEnabled.store(newValue);
  }

  /// Toggles whether the styled editor shows scene numbers, and persists the new value.
  Future<void> _onStyledSceneNumbersToggled(
    OcptEditorStyledSceneNumbersToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newValue = !state.areStyledSceneNumbersVisible;
    emitter(state.copyWith(areStyledSceneNumbersVisible: newValue));
    await _propertiesManager.styledSceneNumbersVisible.store(newValue);
  }

  /// Persists the new page setup (format per-project, margins app-wide), applies it live, and
  /// recomputes statistics immediately since [FountainScriptStatistics.pageCount] depends on the
  /// page format.
  Future<void> _onPageSetupChanged(
    OcptEditorPageSetupChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectPageFormat(event.pageSetup.format);
    await _propertiesManager.pageMargins.store(event.pageSetup.margins);
    emitter(state.copyWith(pageSetup: event.pageSetup));

    final document = state.document;
    if (document != null) {
      _recomputeStatisticsNow(document: document, pageSetup: event.pageSetup, emitter: emitter);
    }
  }

  /// Clears the transient save error currently shown, if any.
  Future<void> _onSaveErrorDismissed(
    OcptEditorSaveErrorDismissedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(hasSaveError: false));
  }

  /// Exports the current screenplay to a `.fountain` file.
  ///
  /// Saves the current text first (tagged [OcptSnapshotReason.export]) if it's dirty, so the
  /// exported file matches exactly what the project stores. A cancelled save dialog is a silent
  /// no-op; a failure raises the transient export-failed notice.
  Future<void> _onExportRequested(
    OcptEditorExportRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();
    _statisticsTimer?.cancel();

    if (state.isDirty) {
      await _saveCurrentText(reason: OcptSnapshotReason.export, emitter: emitter);
    }

    try {
      final path = await _exportManager.exportFountain(
        fountainText: state.text,
        projectName: state.title,
        fileTypeLabel: event.fileTypeLabel,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.exportSucceeded, path: path),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the screenplay of the project at "
          "${_projectsManager.currentProject?.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.exportFailed),
        ),
      );
    }
  }

  /// Exports the current screenplay to a PDF file.
  ///
  /// Saves the current text first (tagged [OcptSnapshotReason.export]) if it's dirty, so the
  /// exported PDF matches exactly what the project stores. The document is re-parsed fresh from
  /// [OcptEditorState.text] rather than reusing [OcptEditorState.document], since the latter lags
  /// behind by the parse debounce. A cancelled save dialog is a silent no-op; a failure raises the
  /// transient PDF-export-failed notice.
  Future<void> _onExportPdfRequested(
    OcptEditorExportPdfRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();
    _statisticsTimer?.cancel();

    if (state.isDirty) {
      await _saveCurrentText(reason: OcptSnapshotReason.export, emitter: emitter);
    }

    try {
      final document = _fountainParser.parse(state.text);
      final pageSetup = OcptPageSetup(format: event.options.format, margins: event.options.margins);
      final path = await _exportManager.exportPdf(
        document: document,
        pageSetup: pageSetup,
        projectName: state.title,
        includeSceneNumbers: event.options.includeSceneNumbers,
        includeTitlePage: event.options.includeTitlePage,
        fileTypeLabel: event.fileTypeLabel,
      );
      if (path == null) {
        // The user cancelled the save dialog.
        return;
      }

      emitter(
        state.copyWith(
          ioNotice: OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.pdfExportSucceeded, path: path),
        ),
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to export the screenplay of the project at "
          "${_projectsManager.currentProject?.path} to PDF: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.pdfExportFailed),
        ),
      );
    }
  }

  /// Replaces the current screenplay text with the content of a picked `.fountain` file.
  ///
  /// If the editor is dirty, the current text is saved first (tagged
  /// [OcptSnapshotReason.manual]) so the pre-import snapshot holds the user's latest keystrokes
  /// rather than a stale database copy; the imported text is then saved, tagged
  /// [OcptSnapshotReason.import], which snapshots the pre-import text. A cancelled file dialog is
  /// a silent no-op; a failure raises the transient import-failed notice.
  Future<void> _onImportRequested(
    OcptEditorImportRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final imported = await _exportManager.pickAndReadFountain(fileTypeLabel: event.fileTypeLabel);
    if (imported == null) {
      // The user cancelled the dialog, or the selection failed; the latter is a soft failure
      // deliberately not surfaced as an error, since the OS dialog itself already reported it.
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    try {
      if (state.isDirty) {
        await _saveCurrentText(reason: OcptSnapshotReason.manual, emitter: emitter);
      }

      await _screenplayService.saveScreenplayText(
        database: project.database,
        screenplayId: project.primaryScreenplayId,
        fountainText: imported.fountainText,
        snapshotReason: OcptSnapshotReason.import,
      );

      _parseTimer?.cancel();
      _autosaveTimer?.cancel();

      emitter(
        state.copyWith(
          text: imported.fountainText,
          isDirty: false,
          currentLine: 0,
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.importSucceeded),
        ),
      );
      await _onParseRequested(const OcptEditorParseRequestedEvent(), emitter);
      _recomputeStatisticsNow(document: state.document!, pageSetup: state.pageSetup, emitter: emitter);
    } catch (error) {
      appLogger().e("A problem occurred when tried to import a fountain file into the project at "
          "${project.path}: $error");
      emitter(
        state.copyWith(
          ioNotice: const OcptEditorIoNotice(kind: OcptEditorIoNoticeKind.importFailed),
        ),
      );
    }
  }

  /// Clears the transient export/import notice currently shown, if any.
  Future<void> _onIoNoticeDismissed(
    OcptEditorIoNoticeDismissedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(clearIoNotice: true));
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
    emitter(state.copyWith(text: newText));
    await _saveCurrentText(reason: OcptSnapshotReason.manual, emitter: emitter);
    await _onParseRequested(const OcptEditorParseRequestedEvent(), emitter);
    _recomputeStatisticsNow(document: state.document!, pageSetup: state.pageSetup, emitter: emitter);
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
    _statisticsTimer?.cancel();

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
    _parseTimer?.cancel();
    _autosaveTimer?.cancel();
    _statisticsTimer?.cancel();

    final project = _projectsManager.currentProject;
    if (project != null && state.isDirty && !state.isSaving) {
      try {
        await _screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: project.primaryScreenplayId,
          fountainText: state.text,
          snapshotReason: OcptSnapshotReason.timer,
        );
      } catch (error) {
        appLogger().e("A problem occurred when tried to flush the screenplay of the project at "
            "${project.path} while leaving the editor: $error");
      }
    }

    return super.disposeLifeCycle();
  }
}
