// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_screenplay_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/types/ocpt_snapshot_reason.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/mixin_ocpt_project_versions_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_current_scene_index.dart';
import 'package:open_cine_prod_tools/utils/ocpt_spell_checked_lines.dart';
import 'package:spell_kit/spell_kit.dart';

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
class OcptEditorBloc extends BlocForMixin<OcptEditorState>
    with MixinOcptProjectVersionsBloc<OcptEditorState> {
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

  /// The manager owning the spell-check worker isolate this bloc requests raw-mode checks from.
  final OcptSpellCheckManager _spellCheckManager;

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

  /// The (text, ranges) last checked per raw-mode block index — see [_rawSpellCheckBlocksOf]'s own
  /// doc comment for what an index addresses. `ranges` are relative to that block's own source
  /// substring, not document-absolute: [_requestSpellCheck] re-translates by the block's *current*
  /// `startOffset` on every pass regardless of whether this entry's text changed, which is what
  /// lets an edit to an *earlier*, unrelated block shift a later one's absolute offset without
  /// invalidating this cache entry — only the block's own text does that.
  final Map<int, ({String text, List<SpellRange> ranges})> _rawSpellCheckCache = {};

  /// The (language, visibility, manager generation) combination [_rawSpellCheckCache] was last
  /// built under — see [_resetSpellCheckCacheIfStale]'s own doc comment.
  ({OcptScreenplayLanguage? language, bool isVisible, int generation})? _rawSpellCheckCacheKey;

  /// The (text, ranges) last checked per styled-mode node id, the styled mode's own counterpart to
  /// [_rawSpellCheckCache]. Node ids are already a stable key on their own — unlike the raw path's
  /// positional block index, a node id doesn't shift when an *earlier* node's own text changes — so
  /// no analogous "re-translate by current offset" step is needed here: a styled `SpellRange` is
  /// already relative to its own node's display text, exactly the addressing `SpellingAndGrammarStyler`
  /// wants.
  final Map<String, ({String text, List<SpellRange> ranges})> _styledSpellCheckCache = {};

  /// The (language, visibility, manager generation) combination [_styledSpellCheckCache] was last
  /// built under — the styled mode's own counterpart to [_rawSpellCheckCacheKey], see
  /// [_resetStyledSpellCheckCacheIfStale]'s own doc comment.
  ({OcptScreenplayLanguage? language, bool isVisible, int generation})? _styledSpellCheckCacheKey;

  /// Unregisters this bloc's unsaved-changes reporter, called when it is disposed.
  late final void Function() _unregisterUnsavedChangesReporter;

  /// The episode this bloc reads and writes, handed down by `EditorPage` from
  /// `OcptWorkspaceBloc.state.selectedEpisodeId` at construction time — safe to capture once
  /// rather than watch, since `WorkspacePage` remounts this whole bloc on every episode switch (see
  /// `WorkspacePage._buildActiveMode`'s own doc comment), so the field can never go stale.
  ///
  /// Null only for a project holding no episode at all: `OcptWorkspaceBloc` lands on the first one
  /// before it clears `isLoading`, and a mode is never built before that, so [_screenplayIdOf]'s
  /// fallback to [OcptOpenProjectModel.primaryScreenplayId] is the honest last resort rather than a
  /// routine path.
  final String? _selectedEpisodeId;

  /// Class constructor
  ///
  /// [parseDebounce], [autosaveDebounce] and [statisticsDebounce] are only meant to be overridden
  /// by tests, to keep them fast and deterministic. [spellCheckManager] is injectable for the same
  /// reason every other manager here is: a test hands in a fake rather than resolving the real,
  /// isolate-backed one.
  OcptEditorBloc({
    OcptProjectsManager? projectsManager,
    OcptPropertiesManager? propertiesManager,
    OcptRouterManager? routerManager,
    OcptScreenplayService? screenplayService,
    OcptExportManager? exportManager,
    OcptSpellCheckManager? spellCheckManager,
    Duration parseDebounce = defaultParseDebounce,
    Duration autosaveDebounce = defaultAutosaveDebounce,
    Duration statisticsDebounce = defaultStatisticsDebounce,
    String? selectedEpisodeId,
  }) : _selectedEpisodeId = selectedEpisodeId,
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _propertiesManager = propertiesManager ?? globalGetIt().get<OcptPropertiesManager>(),
       _routerManager = routerManager ?? globalGetIt().get<OcptRouterManager>(),
       _screenplayService =
           screenplayService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).screenplayService,
       _exportManager = exportManager ?? globalGetIt().get<OcptExportManager>(),
       _spellCheckManager = spellCheckManager ?? globalGetIt().get<OcptSpellCheckManager>(),
       _parseDebounce = parseDebounce,
       _autosaveDebounce = autosaveDebounce,
       _statisticsDebounce = statisticsDebounce,
       super(const OcptEditorState.init()) {
    // The screenplay is the one thing in the app that lives in memory between two writes (the
    // autosave debounce), so this is the mode that has an answer to give when the projects manager
    // asks whether it may swap the database under everyone to preview a version.
    _unregisterUnsavedChangesReporter = _projectsManager.registerUnsavedChangesReporter(
      () => state.isDirty,
    );

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
    on<OcptEditorRightDockToggledEvent>(_onRightDockToggled);
    on<OcptEditorRightDockClosedEvent>(_onRightDockClosed);
    on<OcptEditorDockFractionsChangedEvent>(_onDockFractionsChanged);
    on<OcptEditorDockLayoutResetEvent>(_onDockLayoutReset);
    on<OcptEditorModeToggledEvent>(_onModeToggled);
    on<OcptEditorPageSimulationToggledEvent>(_onPageSimulationToggled);
    on<OcptEditorStyledSceneNumbersToggledEvent>(_onStyledSceneNumbersToggled);
    on<OcptEditorSpellCheckToggledEvent>(_onSpellCheckToggled);
    on<OcptEditorSpellCheckRangesReportedEvent>(_onSpellCheckRangesReported);
    on<OcptEditorStyledSpellCheckTextsReportedEvent>(_onStyledSpellCheckTextsReported);
    on<OcptEditorStyledSpellCheckRangesReportedEvent>(_onStyledSpellCheckRangesReported);
    on<OcptEditorPageSetupChangedEvent>(_onPageSetupChanged);
    on<OcptEditorProjectSettingsChangedEvent>(_onProjectSettingsChanged);
    on<OcptEditorSaveErrorDismissedEvent>(_onSaveErrorDismissed);
    on<OcptEditorBackRequestedEvent>(_onBackRequested);
    on<OcptEditorExportRequestedEvent>(_onExportRequested);
    on<OcptEditorExportPdfRequestedEvent>(_onExportPdfRequested);
    on<OcptEditorImportRequestedEvent>(_onImportRequested);
    on<OcptEditorIoNoticeDismissedEvent>(_onIoNoticeDismissed);
    on<OcptEditorTitlePageChangedEvent>(_onTitlePageChanged);
    on<OcptEditorSearchOpenedEvent>(_onSearchOpened);
    on<OcptEditorSearchClosedEvent>(_onSearchClosed);
    on<OcptEditorSearchReplaceRowToggledEvent>(_onSearchReplaceRowToggled);
    on<OcptEditorSearchQueryChangedEvent>(_onSearchQueryChanged);
    on<OcptEditorSearchReplacementChangedEvent>(_onSearchReplacementChanged);
    on<OcptEditorSearchCaseSensitivityToggledEvent>(_onSearchCaseSensitivityToggled);
    on<OcptEditorSearchWholeWordToggledEvent>(_onSearchWholeWordToggled);
    on<OcptEditorSearchMatchesReportedEvent>(_onSearchMatchesReported);
    on<OcptEditorSearchNextRequestedEvent>(_onSearchNextRequested);
    on<OcptEditorSearchPreviousRequestedEvent>(_onSearchPreviousRequested);
    on<OcptEditorSearchCurrentMatchSelectedEvent>(_onSearchCurrentMatchSelected);
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.projectsManager}
  @protected
  @override
  OcptProjectsManager get projectsManager => _projectsManager;

  /// The screenplay this bloc reads and writes: [_selectedEpisodeId], or [project]'s own
  /// [OcptOpenProjectModel.primaryScreenplayId] on the one path that can reach here with none
  /// selected (see [_selectedEpisodeId]'s own doc comment).
  String _screenplayIdOf(OcptOpenProjectModel project) =>
      _selectedEpisodeId ?? project.primaryScreenplayId;

  /// Saves the screenplay if it holds unsaved changes, so a preview about to swap the database
  /// can't send the text sitting in the autosave debounce into the previewed version instead.
  ///
  /// Tagged [OcptSnapshotReason.manual] like every other save the user's own action triggers: from
  /// the screenplay's point of view, clicking a version card is as deliberate as pressing Ctrl+S.
  @protected
  @override
  Future<void> flushPendingProjectWrites(Emitter<OcptEditorState> emitter) async {
    if (!state.isDirty) {
      return;
    }

    await _saveCurrentText(reason: OcptSnapshotReason.manual, emitter: emitter);
  }

  /// {@macro open_cine_prod_tools.MixinOcptProjectVersionsBloc.reloadFromProjectDatabase}
  @protected
  @override
  Future<void> reloadFromProjectDatabase(Emitter<OcptEditorState> emitter) =>
      _onLoadRequested(const OcptEditorLoadRequestedEvent(), emitter);

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
  Future<void> _onLoadRequested(
    OcptEditorLoadRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    // A (re)load always starts both spell-check caches fresh: an episode switch, a version preview
    // entering or leaving, and the very first load all hand `_requestSpellCheck`/the styled editor a
    // document built from a different Fountain source than whatever the caches last described, and
    // keeping either around risks a stale entry coincidentally matching a new block's/node's text.
    // The styled editor rebuilds its own document from scratch on the very same triggers (see its
    // own `didUpdateWidget`), so it will report a fresh set of node ids on its own; this only clears
    // the bloc's own half.
    _rawSpellCheckCache.clear();
    _rawSpellCheckCacheKey = null;
    _styledSpellCheckCache.clear();
    _styledSpellCheckCacheKey = null;

    final mode = await _propertiesManager.editorMode.load() ?? OcptEditorMode.styled;
    final isPageSimulationEnabled = await _propertiesManager.isPageSimulationEnabled.load() ?? true;
    final areStyledSceneNumbersVisible =
        await _propertiesManager.styledSceneNumbersVisible.load() ?? true;
    final leftDockFraction =
        await _propertiesManager.editorLeftDockFraction.load() ?? OcptWorkspaceDock.leftDefaultFraction;
    final rightDockFraction =
        await _propertiesManager.editorRightDockFraction.load() ?? OcptWorkspaceDock.rightDefaultFraction;
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
        state.copyWith(
          isLoading: false,
          document: document,
          mode: mode,
          clearPreviewedVersionId: true,
          isPageSimulationEnabled: isPageSimulationEnabled,
          areStyledSceneNumbersVisible: areStyledSceneNumbersVisible,
          isSpellCheckVisible: isSpellCheckVisible,
          screenplayLanguage: screenplayLanguage,
          clearScreenplayLanguage: screenplayLanguage == null,
          // A fresh load's document is never the one the previous rawSpellCheckRanges/
          // styledSpellCheckRanges were computed against (a different project, episode, or preview
          // state entirely) — cleared here so a stale underline never survives the swap, exactly as
          // both caches are cleared just above. _requestSpellCheck (fired by
          // _reconcileSpellCheckLanguage, right below) repopulates the raw one fresh when the new
          // state actually wants a check; the styled one is repopulated by the styled editor's own
          // fresh report once it rebuilds from the new document.
          rawSpellCheckRanges: const [],
          styledSpellCheckRanges: const {},
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
      unawaited(_reconcileSpellCheckLanguage());
      return;
    }

    final text = await _screenplayService.loadScreenplayText(
      database: project.database,
      screenplayId: _screenplayIdOf(project),
    );
    final document = _fountainParser.parse(text);
    final pageSetup = await _loadPageSetup(project);
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
        previewedVersionId: previewedVersion?.id,
        clearPreviewedVersionId: previewedVersion == null,
        text: text,
        document: document,
        pageSetup: pageSetup,
        isPageSimulationEnabled: isPageSimulationEnabled,
        areStyledSceneNumbersVisible: areStyledSceneNumbersVisible,
        isSpellCheckVisible: isSpellCheckVisible,
        screenplayLanguage: screenplayLanguage,
        clearScreenplayLanguage: screenplayLanguage == null,
        // See the same fields in the project == null branch above for why a fresh load always
        // clears these rather than carrying over a previous document's ranges.
        rawSpellCheckRanges: const [],
        styledSpellCheckRanges: const {},
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
    unawaited(_reconcileSpellCheckLanguage());
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
        margins: await _propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
      );

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
    bool clearRightDockTab,
    OcptEditorRightDockTab? autoClosedRightDockTab,
    bool clearAutoClosedRightDockTab,
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
        clearRightDockTab: true,
        autoClosedRightDockTab: OcptEditorRightDockTab.preview,
        clearAutoClosedRightDockTab: false,
      );
    }
    if (isPreviewTabAvailable && rightDockTab == null && autoClosedRightDockTab != null) {
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
  ///
  /// Also fires the raw mode's spell-check pass ([_requestSpellCheck]) right after the fresh
  /// document is emitted, exactly where `docs/plans/screenplay-spell-check.md` §3.2 puts it: on
  /// this same parse debounce, never a keystroke. This is what makes an import
  /// (`_onImportRequested`) and a title-page rewrite (`_onTitlePageChanged`) — the two other
  /// callers of this method — request a fresh check too, alongside every ordinary edit.
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
    _requestSpellCheck();
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
        screenplayId: _screenplayIdOf(project),
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

      // The other of the two moments the working-copy card needs a fresh read for (see
      // `_onRightDockTabSelected`): a save that lands while the tab showing it is already open.
      if (state.rightDockTab == OcptEditorRightDockTab.versions) {
        add(const OcptProjectWorkingCopyRefreshRequestedEvent());
      }
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
  /// closes the dock, any other tab opens or switches to it), records it as
  /// [OcptEditorState.lastRightDockTab] (even when it just closed the dock: that's still the tab
  /// the toolbar's toggle must bring back), and clears
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
        lastRightDockTab: event.tab,
        clearAutoClosedRightDockTab: true,
      ),
    );

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
      emitter(state.copyWith(clearRightDockTab: true, clearAutoClosedRightDockTab: true));
      return;
    }

    final isPreviewForbidden =
        !state.isPreviewTabAvailable && state.lastRightDockTab == OcptEditorRightDockTab.preview;

    emitter(
      state.copyWith(
        rightDockTab: isPreviewForbidden ? OcptEditorRightDockTab.syntax : state.lastRightDockTab,
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
  ///
  /// Also fires [_requestSpellCheck] the moment raw becomes the mounted mode: [_requestSpellCheck]
  /// is a no-op while any other mode is mounted (see its own doc comment), so
  /// [OcptEditorState.rawSpellCheckRanges] can otherwise sit unrefreshed for as long as the styled
  /// editor was the one showing — every edit made there still reaches `state.document` through the
  /// ordinary parse debounce, so a check request made *right here* (rather than waiting for the next
  /// edit-triggered one) is what keeps the raw controller from painting underlines computed against
  /// whatever text was current the last time raw mode itself was mounted, rather than the text it is
  /// about to display. The styled mode's own equivalent needs no such nudge: the styled editor
  /// reports its checkable texts fresh the moment it (re)mounts, in its own `initState`.
  Future<void> _onModeToggled(
    OcptEditorModeToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newMode = state.mode == OcptEditorMode.styled ? OcptEditorMode.raw : OcptEditorMode.styled;
    final dockTabTransition = _rightDockTransitionFor(
      newMode: newMode,
      isReadOnly: state.isPreviewingVersion,
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
    if (newMode == OcptEditorMode.raw) {
      _requestSpellCheck();
    }
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

  /// Toggles whether this machine shows the spell-check underlines, persists the new value, and
  /// re-drives [_reconcileSpellCheckLanguage] (loading or unloading the dictionary as the two
  /// switches of `docs/plans/screenplay-spell-check.md` §4.2 now dictate).
  ///
  /// Switching off also clears [OcptEditorState.rawSpellCheckRanges] and
  /// [OcptEditorState.styledSpellCheckRanges] right here, synchronously, rather than waiting for
  /// [_reconcileSpellCheckLanguage]'s own async tail: with the switch off, [_requestSpellCheck]
  /// never runs again (and the styled editor reports nothing to check — its own `isSpellCheckVisible`
  /// parameter, mirrored from this same field), so nothing would otherwise clear a stale underline
  /// still on screen in either mode. Switching on leaves the (already empty, from the last time it
  /// was off) ranges alone — the very next check answers them for real.
  Future<void> _onSpellCheckToggled(
    OcptEditorSpellCheckToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final newValue = !state.isSpellCheckVisible;
    emitter(
      state.copyWith(
        isSpellCheckVisible: newValue,
        rawSpellCheckRanges: newValue ? null : const [],
        styledSpellCheckRanges: newValue ? null : const {},
      ),
    );
    await _propertiesManager.spellCheckVisible.store(newValue);
    unawaited(_reconcileSpellCheckLanguage());
  }

  /// Answers [OcptEditorSpellCheckRangesReportedEvent], the async tail of [_requestSpellCheck].
  ///
  /// Drops the answer (per `docs/plans/screenplay-spell-check.md` §5, M3's "a stale generation's
  /// answer is dropped") when: [OcptEditorSpellCheckRangesReportedEvent.generation] no longer
  /// matches [OcptSpellCheckManager.generation] (a language change, or a word learned or ignored,
  /// happened while the isolate round trip was in flight); spell-checking is now off (either
  /// switch) or a version is now being previewed (both can have flipped mid-flight too); or
  /// [OcptEditorSpellCheckRangesReportedEvent.checkedText] no longer matches
  /// `OcptEditorState.document`'s own `sourceText` — the document has moved on to a newer parse
  /// since this request was issued, and painting these ranges over it would misplace every one of
  /// them.
  Future<void> _onSpellCheckRangesReported(
    OcptEditorSpellCheckRangesReportedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    if (event.generation != _spellCheckManager.generation) {
      return;
    }
    if (state.isPreviewingVersion || !state.isSpellCheckVisible || state.screenplayLanguage == null) {
      return;
    }
    final document = state.document;
    if (document == null || document.sourceText != event.checkedText) {
      return;
    }

    emitter(state.copyWith(rawSpellCheckRanges: event.ranges));
  }

  /// Answers [OcptEditorStyledSpellCheckTextsReportedEvent], the styled mode's own counterpart to
  /// [_onParseRequested]'s raw-mode trigger: fires a check over `event.textsByNodeId` without
  /// awaiting the isolate round trip (an [Emitter] can't be used once this handler has returned),
  /// answered back as its own [OcptEditorStyledSpellCheckRangesReportedEvent].
  ///
  /// A no-op — nothing sent, [OcptEditorState.styledSpellCheckRanges] left exactly as it is — while
  /// a version is being previewed or spell-checking is off (either switch): the styled editor itself
  /// already withholds every checkable text under those same conditions (its own `isSpellCheckVisible`
  /// parameter, and it is simply never mounted under a preview), so this event would only ever carry
  /// an empty map then in practice, but the guard is kept here too for the same reason
  /// [_requestSpellCheck]'s own guard is: a stray event arriving right as either switch flips
  /// underneath it must never reach the manager.
  ///
  /// Only *changed* texts are sent to [OcptSpellCheckManager.check], mirroring [_requestSpellCheck]'s
  /// own dedup and for the identical reason — a keystroke in one node costs one node's check, not the
  /// whole reported set — except keyed by node id rather than by a positional block index: a node id
  /// is already a stable key on its own (see [_styledSpellCheckCache]'s own doc comment), so no
  /// offset-translation step is needed when re-assembling the answer.
  Future<void> _onStyledSpellCheckTextsReported(
    OcptEditorStyledSpellCheckTextsReportedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    if (state.isPreviewingVersion) {
      return;
    }
    if (!state.isSpellCheckVisible || state.screenplayLanguage == null) {
      return;
    }

    _resetStyledSpellCheckCacheIfStale();

    final textsByNodeId = event.textsByNodeId;
    final textsToSend = <String, String>{
      for (final entry in textsByNodeId.entries)
        if (_styledSpellCheckCache[entry.key]?.text != entry.value) entry.key: entry.value,
    };
    _styledSpellCheckCache.removeWhere((nodeId, _) => !textsByNodeId.containsKey(nodeId));

    final requestGeneration = _spellCheckManager.generation;

    unawaited(
      _spellCheckManager.check(textsToSend).then((rangesByNodeId) {
        if (isClosed) {
          return;
        }

        for (final entry in rangesByNodeId.entries) {
          final text = textsToSend[entry.key];
          if (text == null) {
            continue;
          }
          _styledSpellCheckCache[entry.key] = (
            text: text,
            ranges: _dropSkippedSpellRanges(entry.value, text),
          );
        }

        final ranges = <String, List<SpellRange>>{
          for (final nodeId in textsByNodeId.keys)
            if (_styledSpellCheckCache[nodeId] != null) nodeId: _styledSpellCheckCache[nodeId]!.ranges,
        };

        add(
          OcptEditorStyledSpellCheckRangesReportedEvent(
            generation: requestGeneration,
            ranges: ranges,
          ),
        );
      }),
    );
  }

  /// Answers [OcptEditorStyledSpellCheckRangesReportedEvent], the async tail of
  /// [_onStyledSpellCheckTextsReported].
  ///
  /// Drops the answer under the same three conditions [_onSpellCheckRangesReported] does, minus the
  /// `checkedText` comparison that event has no counterpart for: ranges here are keyed by node id
  /// rather than by document-absolute offset, so a range computed against a node's text that has
  /// since changed is instead clamped and dropped by the styled editor itself, at the point it's
  /// turned into a `TextError` (see [OcptEditorStyledSpellCheckRangesReportedEvent]'s own doc
  /// comment) — the very last of the plan's own §5, M3 guards, and the one place left that can
  /// actually tell a node's *current* text length from here.
  Future<void> _onStyledSpellCheckRangesReported(
    OcptEditorStyledSpellCheckRangesReportedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    if (event.generation != _spellCheckManager.generation) {
      return;
    }
    if (state.isPreviewingVersion || !state.isSpellCheckVisible || state.screenplayLanguage == null) {
      return;
    }

    emitter(state.copyWith(styledSpellCheckRanges: event.ranges));
  }

  /// Loads or unloads `OcptSpellCheckManager`'s dictionary to match
  /// `OcptEditorState.screenplayLanguage`/[OcptEditorState.isSpellCheckVisible] (the plan's two
  /// independent on/off switches, §4.2: with either off, the isolate stays unloaded and nothing is
  /// checked), then requests a fresh raw-mode pass so the underlines catch up once a dictionary
  /// that needed loading has actually finished doing so.
  ///
  /// Never awaited by its own callers ([_onLoadRequested], [_onSpellCheckToggled],
  /// [_onProjectSettingsChanged]): `OcptSpellCheckManager.useLanguage` can take ~300 ms the first
  /// time a language loads, and none of them should hold the editor's own state update back for
  /// it.
  Future<void> _reconcileSpellCheckLanguage() async {
    final wantsSpellCheck = state.isSpellCheckVisible && state.screenplayLanguage != null;
    await _spellCheckManager.useLanguage(wantsSpellCheck ? state.screenplayLanguage : null);
    if (isClosed) {
      return;
    }
    _requestSpellCheck();
  }

  /// Clears [_rawSpellCheckCache] the first time it is asked to work under a different (language,
  /// visibility, manager generation) combination than the one it was last built under: a cached
  /// entry was found by a dictionary, ignore list or learned-word set that has since changed
  /// (`OcptSpellCheckManager.generation` bumps on every one of those), and keeping it around would
  /// answer with a checker that no longer exists.
  void _resetSpellCheckCacheIfStale() {
    final key = (
      language: state.screenplayLanguage,
      isVisible: state.isSpellCheckVisible,
      generation: _spellCheckManager.generation,
    );
    if (key == _rawSpellCheckCacheKey) {
      return;
    }
    _rawSpellCheckCache.clear();
    _rawSpellCheckCacheKey = key;
  }

  /// Clears [_styledSpellCheckCache] the first time it is asked to work under a different
  /// (language, visibility, manager generation) combination than the one it was last built under —
  /// the styled mode's own counterpart to [_resetSpellCheckCacheIfStale], same reasoning.
  void _resetStyledSpellCheckCacheIfStale() {
    final key = (
      language: state.screenplayLanguage,
      isVisible: state.isSpellCheckVisible,
      generation: _spellCheckManager.generation,
    );
    if (key == _styledSpellCheckCacheKey) {
      return;
    }
    _styledSpellCheckCache.clear();
    _styledSpellCheckCacheKey = key;
  }

  /// Fires a raw-mode spell-check request over `state.document`'s prose blocks, without awaiting
  /// the isolate round trip: the answer arrives later as its own
  /// [OcptEditorSpellCheckRangesReportedEvent], since an [Emitter] can't be used once the handler
  /// that called this has already returned (true of every caller: [_onParseRequested]'s own parse
  /// debounce tick, and [_reconcileSpellCheckLanguage]'s async tail).
  ///
  /// A no-op while a version is being previewed, while spell-checking is off (either switch), or
  /// while the styled mode is the one mounted — the raw controller is the only thing that ever
  /// paints [OcptEditorState.rawSpellCheckRanges] (`OcptEditorSearchTextController`, wired only into
  /// `OcptEditorSourceField`), so a styled-mode pass here would be an isolate round trip for a
  /// squiggle nothing paints. In every no-op case [OcptEditorState.rawSpellCheckRanges] is left
  /// exactly as it is: [_onSpellCheckToggled] already clears it synchronously the moment the switch
  /// flips off, so there is nothing stale left for this method to clear, and [_onModeToggled] is
  /// what calls this again the moment raw mode becomes the mounted one, so the field never answers
  /// with a document version older than whatever raw mode is about to show.
  ///
  /// Only *changed* texts are sent to [OcptSpellCheckManager.check] (`docs/plans/screenplay-spell-
  /// check.md` §3.2): [_rawSpellCheckBlocksOf] keys every checked block by its index in the walk
  /// order, and [_rawSpellCheckCache] is compared against by that same index, so a block whose own
  /// source text hasn't changed since the index last held it is skipped. `OcptSpellCheckManager
  /// .check` itself fast-paths an empty request map to an empty answer with no isolate round trip
  /// at all (its own doc comment), so calling it unconditionally here — even when nothing changed —
  /// costs nothing extra while still re-assembling and re-reporting the full, current set of
  /// absolute ranges: a block's cached *relative* ranges are re-translated by its *current*
  /// `startOffset` on every pass, which is what keeps an edit to an earlier, unrelated block from
  /// leaving every later misspelling underlined in the wrong place.
  void _requestSpellCheck() {
    final document = state.document;
    if (document == null || state.isPreviewingVersion || state.mode != OcptEditorMode.raw) {
      return;
    }
    if (!state.isSpellCheckVisible || state.screenplayLanguage == null) {
      return;
    }

    _resetSpellCheckCacheIfStale();

    final blocks = _rawSpellCheckBlocksOf(document);
    final textsToSend = <int, String>{
      for (final block in blocks)
        if (_rawSpellCheckCache[block.index]?.text != block.text) block.index: block.text,
    };
    final liveIndices = blocks.map((block) => block.index).toSet();
    _rawSpellCheckCache.removeWhere((index, _) => !liveIndices.contains(index));

    final requestGeneration = _spellCheckManager.generation;
    final checkedText = document.sourceText;

    unawaited(
      _spellCheckManager.check(textsToSend).then((rangesByIndex) {
        if (isClosed) {
          return;
        }

        for (final entry in rangesByIndex.entries) {
          final blockText = textsToSend[entry.key];
          if (blockText == null) {
            continue;
          }
          _rawSpellCheckCache[entry.key] = (
            text: blockText,
            ranges: _dropSkippedSpellRanges(entry.value, blockText),
          );
        }

        final absoluteRanges = <SpellRange>[
          for (final block in blocks)
            for (final relative in _rawSpellCheckCache[block.index]?.ranges ?? const <SpellRange>[])
              SpellRange(relative.start + block.startOffset, relative.end + block.startOffset),
        ];

        add(
          OcptEditorSpellCheckRangesReportedEvent(
            generation: requestGeneration,
            checkedText: checkedText,
            ranges: absoluteRanges,
          ),
        );
      }),
    );
  }

  /// The screenplay's own prose blocks of [document], walked in source order and addressed by a
  /// dense 0-based index over just those blocks (a `FountainSceneHeading`, unchecked, is simply
  /// never given one — [_requestSpellCheck]'s cache is bounded by how many *checked* blocks the
  /// screenplay holds, not by its block count as a whole).
  ///
  /// Recurses into a `FountainDialogueGroup`'s `children` rather than ever handing the group itself
  /// to [ocptLineTypeOfBlock] (which answers null for it, per that function's own doc comment): the
  /// group is a container, and its cue and its dialogue lines each carry their own line type.
  /// A [_RawSpellCheckBlock]'s own `text` is a block's own substring of [FountainDocument.sourceText] — the
  /// exact text raw mode displays and its `OcptEditorSearchTextController` paints offsets into,
  /// which is not necessarily [OcptEditorState.text]: the parser may have normalized the source's
  /// line endings, so the two can disagree on length and offsets even when they read the same.
  List<_RawSpellCheckBlock> _rawSpellCheckBlocksOf(FountainDocument document) {
    final result = <_RawSpellCheckBlock>[];
    var index = 0;

    void visit(FountainBlock block) {
      if (block is FountainDialogueGroup) {
        for (final child in block.children) {
          visit(child);
        }
        return;
      }

      final lineType = ocptLineTypeOfBlock(block);
      if (lineType == null || !ocptIsSpellCheckedLineType(lineType)) {
        return;
      }

      final range = block.sourceRange;
      result.add(
        (
          index: index++,
          text: document.sourceText.substring(range.startOffset, range.endOffset),
          startOffset: range.startOffset,
        ),
      );
    }

    for (final block in document.blocks) {
      visit(block);
    }

    return result;
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

  /// Re-reads the project's page format and screenplay language after the project settings page
  /// changed something, repaginating against the former and re-driving
  /// [_reconcileSpellCheckLanguage] against the latter.
  ///
  /// These are the only two fields of the project settings page this bloc's own state depends on:
  /// the currency has nothing to do with a screenplay's pagination or its spell-checking. Re-reading
  /// them rather than carrying them on the event is what lets the project settings page own the
  /// write without this bloc having to learn its shape.
  Future<void> _onProjectSettingsChanged(
    OcptEditorProjectSettingsChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final pageFormat = await _projectsManager.loadCurrentProjectPageFormat();
    if (pageFormat != null && pageFormat != state.pageSetup.format) {
      final pageSetup = state.pageSetup.copyWith(format: pageFormat);
      emitter(state.copyWith(pageSetup: pageSetup));

      final document = state.document;
      if (document != null) {
        _recomputeStatisticsNow(document: document, pageSetup: pageSetup, emitter: emitter);
      }
    }

    final screenplayLanguage = await _projectsManager.loadCurrentProjectScreenplayLanguage();
    if (screenplayLanguage != state.screenplayLanguage) {
      emitter(
        state.copyWith(
          screenplayLanguage: screenplayLanguage,
          clearScreenplayLanguage: screenplayLanguage == null,
        ),
      );
      unawaited(_reconcileSpellCheckLanguage());
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
        episodeTag: event.episodeTag,
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
        episodeTag: event.episodeTag,
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
        screenplayId: _screenplayIdOf(project),
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

  /// Opens the find/replace bar (see `OcptEditorSearchOpenedEvent`'s own doc comment for exactly
  /// what folds and what doesn't).
  Future<void> _onSearchOpened(
    OcptEditorSearchOpenedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(
        search: state.search.copyWith(
          isOpen: true,
          isReplaceRowOpen: state.search.isReplaceRowOpen || event.withReplaceRow,
          focusRequestId: state.search.focusRequestId + 1,
        ),
      ),
    );
  }

  /// Closes the find/replace bar, clearing the highlight but keeping the query, the replacement
  /// and both options (see `OcptEditorSearchClosedEvent`'s own doc comment).
  Future<void> _onSearchClosed(
    OcptEditorSearchClosedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(
        search: state.search.copyWith(
          isOpen: false,
          matchCount: 0,
          clearCurrentMatchIndex: true,
        ),
      ),
    );
  }

  /// Folds or unfolds the replace row.
  Future<void> _onSearchReplaceRowToggled(
    OcptEditorSearchReplaceRowToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(
        search: state.search.copyWith(isReplaceRowOpen: !state.search.isReplaceRowOpen),
      ),
    );
  }

  /// Stores the find field's new text and resets the current match index to 0, ready to be
  /// clamped by the mounted surface's next match count report.
  Future<void> _onSearchQueryChanged(
    OcptEditorSearchQueryChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(search: state.search.copyWith(query: event.query, currentMatchIndex: 0)),
    );
  }

  /// Stores the replace field's new text.
  Future<void> _onSearchReplacementChanged(
    OcptEditorSearchReplacementChangedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(search: state.search.copyWith(replacement: event.replacement)),
    );
  }

  /// Toggles the "match case" option.
  Future<void> _onSearchCaseSensitivityToggled(
    OcptEditorSearchCaseSensitivityToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(
        search: state.search.copyWith(isCaseSensitive: !state.search.isCaseSensitive),
      ),
    );
  }

  /// Toggles the "whole word" option.
  Future<void> _onSearchWholeWordToggled(
    OcptEditorSearchWholeWordToggledEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(
      state.copyWith(search: state.search.copyWith(isWholeWord: !state.search.isWholeWord)),
    );
  }

  /// Records the mounted surface's current match count, clamping the current match index into the
  /// new range (null once [OcptEditorSearchMatchesReportedEvent.matchCount] is 0).
  Future<void> _onSearchMatchesReported(
    OcptEditorSearchMatchesReportedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final matchCount = event.matchCount;
    if (matchCount == 0) {
      emitter(
        state.copyWith(
          search: state.search.copyWith(matchCount: 0, clearCurrentMatchIndex: true),
        ),
      );
      return;
    }

    final clampedIndex = (state.search.currentMatchIndex ?? 0).clamp(0, matchCount - 1);
    emitter(
      state.copyWith(
        search: state.search.copyWith(matchCount: matchCount, currentMatchIndex: clampedIndex),
      ),
    );
  }

  /// Moves to the next match, wrapping from the last one back to the first. A no-op while there is
  /// no match.
  Future<void> _onSearchNextRequested(
    OcptEditorSearchNextRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final matchCount = state.search.matchCount;
    if (matchCount == 0) {
      return;
    }

    final nextIndex = ((state.search.currentMatchIndex ?? -1) + 1) % matchCount;
    emitter(state.copyWith(search: state.search.copyWith(currentMatchIndex: nextIndex)));
  }

  /// Moves to the previous match, wrapping from the first one back to the last. A no-op while
  /// there is no match.
  Future<void> _onSearchPreviousRequested(
    OcptEditorSearchPreviousRequestedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    final matchCount = state.search.matchCount;
    if (matchCount == 0) {
      return;
    }

    final previousIndex = ((state.search.currentMatchIndex ?? 0) - 1 + matchCount) % matchCount;
    emitter(state.copyWith(search: state.search.copyWith(currentMatchIndex: previousIndex)));
  }

  /// Sets the current match directly to [OcptEditorSearchCurrentMatchSelectedEvent.index], computed
  /// by whichever editing surface just performed a `Replace` against the text it just wrote (see
  /// the event's own doc comment for why this can't simply keep the previous index).
  Future<void> _onSearchCurrentMatchSelected(
    OcptEditorSearchCurrentMatchSelectedEvent event,
    Emitter<OcptEditorState> emitter,
  ) async {
    emitter(state.copyWith(search: state.search.copyWith(currentMatchIndex: event.index)));
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
    _unregisterUnsavedChangesReporter();

    final project = _projectsManager.currentProject;
    if (project != null && state.isDirty && !state.isSaving) {
      try {
        await _screenplayService.saveScreenplayText(
          database: project.database,
          screenplayId: _screenplayIdOf(project),
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

/// One block `OcptEditorBloc._rawSpellCheckBlocksOf` hands back: `index` is this block's position
/// among only the checked blocks (its `OcptEditorBloc._rawSpellCheckCache` key), `text` is its own
/// substring of [FountainDocument.sourceText], and `startOffset` is where that substring begins in
/// the document, used to translate the manager's block-relative [SpellRange]s back into
/// document-absolute ones.
typedef _RawSpellCheckBlock = ({int index, String text, int startOffset});

/// Drops every range of [misspellings] that falls inside one of [text]'s own
/// [ocptSpellCheckSkipSpansIn] spans — an inline authoring note or boneyard comment sitting inside
/// a line of action or dialogue is scaffolding, not the script, per that function's own doc
/// comment. [misspellings] and the spans it's tested against are both relative to the very same
/// [text], so no offset translation is needed here.
List<SpellRange> _dropSkippedSpellRanges(List<SpellRange> misspellings, String text) {
  final skipSpans = ocptSpellCheckSkipSpansIn(text);
  if (skipSpans.isEmpty) {
    return misspellings;
  }

  return [
    for (final range in misspellings)
      if (!skipSpans.any((span) => range.start >= span.start && range.end <= span.end)) range,
  ];
}
