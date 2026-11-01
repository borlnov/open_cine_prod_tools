// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_settings_reveal.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_statistics_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_dialog_flows.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_raw_scroller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_sync.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_text_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_centre.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_dock_tab_toggle.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_format_controls.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_format_overflow_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_mode_toggle.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock_view.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_toolbar_menu_item_label.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shortcut_labels.dart';

/// The screenplay editor: either the styled block editor or the raw Fountain source in the center
/// (depending on the persisted `OcptEditorMode`, forced to the styled editor on a phone — see
/// `_EditorViewState._liveMode`), the collapsible scene panel on the left,
/// the tabbed right dock (formatted preview, raw mode only; the Fountain syntax guide, the scene
/// inspector, the read-only metadata panel and the project versions, all four in both modes)
/// hosting at most one panel at a time, and a thin toolbar above them.
///
/// While a project version is being previewed, the mode shows the version instead of the working
/// copy, and shows it read-only: the centre becomes the formatted preview whichever editing mode is
/// active (there is no editor at all then, see `OcptProjectVersionsPanel`: making the styled editor
/// read-only would mean a second super_editor rendering path to maintain forever), every control
/// that would write is withheld, and the shell carries the band naming the version. Reading the
/// screenplay, browsing its scenes, exporting it and looking at its statistics all stay available:
/// none of them touches the project.
///
/// The `OcptRouterManager` editor guard guarantees a project is open when this page is reached.
class OcptEditorPage extends StatelessWidget {
  /// Creates the editor page.
  const OcptEditorPage({super.key});

  /// Build the editor page as a [MultiBlocProvider].
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => OcptEditorBloc(
          selectedEpisodeId: context.read<OcptWorkspaceBloc>().state.selectedEpisodeId,
        ),
      ),
      // Built with the mode rather than on first read: a view bloc registers itself with the mode
      // bloc when it is built, and one that is not there yet cannot be asked to write what it holds.
      BlocProvider(
        lazy: false,
        create: (context) => OcptEditorSpellCheckBloc(modeBloc: context.read<OcptEditorBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptEditorSearchBloc(modeBloc: context.read<OcptEditorBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptEditorIoBloc(modeBloc: context.read<OcptEditorBloc>()),
      ),
      BlocProvider(
        lazy: false,
        create: (context) => OcptEditorStatisticsBloc(modeBloc: context.read<OcptEditorBloc>()),
      ),
    ],
    child: const _EditorView(),
  );
}

/// The intent behind the Ctrl+S / Cmd+S shortcut: save the screenplay now.
class _SaveIntent extends Intent {
  /// Class constructor
  const _SaveIntent();
}

/// The intent behind the Ctrl+Shift+M / Cmd+Shift+M shortcut: toggle the styled/raw editing mode.
class _ModeToggleIntent extends Intent {
  /// Class constructor
  const _ModeToggleIntent();
}

/// The intent behind the Ctrl+F / Cmd+F shortcut: open the find/replace bar on find.
class _FindIntent extends Intent {
  /// Class constructor
  const _FindIntent();
}

/// The intent behind the Ctrl+H / Cmd+H shortcut: open the find/replace bar on replace.
class _ReplaceIntent extends Intent {
  /// Class constructor
  const _ReplaceIntent();
}

/// The intent behind the Escape shortcut: close the find/replace bar.
class _CloseFindIntent extends Intent {
  /// Class constructor
  const _CloseFindIntent();
}

/// The content of [OcptEditorPage], separated from it so [OcptEditorPage] only wires the
/// [OcptEditorBloc] up.
///
/// This is a StatefulWidget (the documented exception) because it owns the text editing
/// controller: the source text lives in the controller (the bloc only receives change events),
/// and applying bloc-driven effects (initial text, scene jumps) requires imperative access to it.
class _EditorView extends StatefulWidget {
  /// Class constructor
  const _EditorView();

  /// Create the [_EditorViewState] holding the state of the editor view.
  @override
  State<_EditorView> createState() => _EditorViewState();
}

/// The state of [_EditorView]: owns the editing/scroll/focus controllers and bridges them to the
/// bloc in both directions (controller changes become bloc events; bloc jump requests and the
/// initial load are applied back onto the controllers).
class _EditorViewState extends State<_EditorView> {
  /// The controller holding the live source text and selection.
  ///
  /// An [OcptEditorSearchTextController] rather than a plain [TextEditingController]: raw mode's
  /// half of the find/replace bar's highlight is painted straight into this same field, per the
  /// plan's decision that each editing surface highlights what it shows.
  final OcptEditorSearchTextController _textController = OcptEditorSearchTextController();

  /// The controller bridging the toolbar's block-type dropdown and B/I/U toggles to the live
  /// styled editor; detached (and the toolbar's format controls hidden) whenever the styled editor
  /// isn't mounted, i.e. in raw mode.
  final OcptStyledEditorController _styledEditorController = OcptStyledEditorController();

  /// The live source of truth for the two dock fractions while dragging a divider: notifies the
  /// dock layout on every drag update without emitting a bloc state per frame (see the
  /// controller's own doc comment). Initialized with the defaults; synced to the bloc's persisted
  /// values once the load (or a reset) resolves, in [_onStateChanged].
  final OcptWorkspaceDockLayoutController _dockLayoutController = OcptWorkspaceDockLayoutController(
    leftFraction: OcptWorkspaceDock.leftDefaultFraction,
    rightFraction: OcptWorkspaceDock.rightDefaultFraction,
  );

  /// The handle on the undo history Flutter keeps for the raw mode's own `TextField` (every
  /// `EditableText` carries one), owned here so the `⋮` menu's `Undo`/`Redo` entries can read
  /// whether that field has anything to take back and drive it — the raw half of what
  /// [_styledEditorController] answers for the styled editor.
  ///
  /// The history belongs to the editing surface, and switching surface starts a fresh one: this
  /// one only ever answers for raw mode, and is simply not what the entries read while the styled
  /// editor is the one on screen.
  final UndoHistoryController _undoHistoryController = UndoHistoryController();

  /// The controller of the editor's vertical scroll, used when jumping to a scene.
  final ScrollController _editorScrollController = ScrollController();

  /// The editor's focus node, focused back when jumping to a scene.
  final FocusNode _editorFocusNode = FocusNode();

  /// The last text reported to the bloc, to only send [OcptEditorTextChangedEvent] on real text
  /// changes (the controller also notifies for pure selection changes).
  String _lastReportedText = "";

  /// The last caret line reported to the bloc, to only send [OcptEditorCaretMovedEvent] when the
  /// caret actually changes line.
  int _lastReportedLine = 0;

  /// The id of the last [OcptEditorJumpRequest] applied, to apply each request exactly once.
  int? _lastAppliedJumpRequestId;

  /// The `OcptStyledEditorController.spellCheckTextsByNodeId` last reported to the bloc, so
  /// [_onStyledEditorControllerChanged] only dispatches
  /// `OcptEditorStyledSpellCheckTextsReportedEvent` on a genuine change — the controller notifies
  /// its listeners for reasons that have nothing to do with spell-checking either (a block-type or
  /// history read-state refresh, or the search match count), the same reason
  /// `OcptEditorSearchSync` exists for the search count.
  Map<String, String> _lastReportedStyledSpellCheckTexts = const {};

  /// What [_styledEditorController] last answered about its own history, so
  /// [_onStyledEditorControllerChanged] only rebuilds the `⋮` menu's entries when the styled
  /// editor gained or lost something to undo or redo — that controller notifies for the toolbar's
  /// block-type and inline-style read state too, on caret moves that leave the history untouched.
  ///
  /// The raw side needs no counterpart: [UndoHistoryController] is a `ValueNotifier` over an
  /// `UndoHistoryValue` that compares by value, so it only ever notifies on a genuine change.
  ({bool canUndo, bool canRedo}) _lastStyledHistoryAvailability = (canUndo: false, canRedo: false);

  /// Whether [_onTextControllerChanged] must ignore notifications, used while applying the
  /// loaded text programmatically to [_textController] (so it doesn't loop back into the bloc
  /// as a user edit).
  bool _isApplyingProgrammaticChange = false;

  /// Moves the raw field's caret and scroll for a scene jump or the match the find bar is on.
  late final OcptEditorRawScroller _rawScroller = OcptEditorRawScroller(
    textController: _textController,
    editorScrollController: _editorScrollController,
    editorFocusNode: _editorFocusNode,
  );

  /// Applies the find/replace bar onto the live editing surface and carries out its replacements.
  late final OcptEditorSearchSync _searchSync = OcptEditorSearchSync(
    textController: _textController,
    styledEditorController: _styledEditorController,
    liveMode: _liveMode,
    navigateToMatch: _rawScroller.navigateToMatch,
  );

  /// Whether the window this page is laid out in is a phone ([ocptIsPhoneWidth]) narrow enough to
  /// force the styled editor as the only editing surface, and page simulation off, regardless of
  /// what [OcptEditorState.mode] and [OcptEditorState.isPageSimulationEnabled] are persisted as:
  /// raw source (and its own find/replace and spell-check wiring) and a real-size simulated page
  /// have no room to be usable there. Deliberately the *phone* breakpoint rather than
  /// [ocptIsCompactWidth]'s wider one: a tablet window between the two still has room for the
  /// toolbar's format controls (hidden in raw mode, shown the moment the styled editor is forced
  /// on) beside everything else the toolbar already carries there, which a phone-width toolbar has
  /// separately been folded down for (`OcptWorkspaceShell`) but a merely-compact one has not.
  ///
  /// Read straight off [MediaQuery] rather than a value captured once by a `LayoutBuilder` in
  /// [build]: the search and spell-check syncs run from the `BlocConsumer`'s `listener`, which
  /// fires independently of (and sometimes before) a rebuild, so they need a getter that always
  /// answers with the window's current width rather than a stale build-time snapshot.
  bool get _isPhoneWidth => ocptIsPhoneWidth(MediaQuery.sizeOf(context).width);

  /// Whether the window this page is laid out in is narrow enough ([ocptIsCompactWidth]) that the
  /// styled editor — forced on by [_isPhoneWidth], or simply the user's own live preference at any
  /// width — should carry its block hierarchy by style rather than by the real screenplay indents
  /// (see [OcptStyledScreenplayEditor.isCompact]): a tablet window has more
  /// room than a phone, but still not the width a real screenplay page wants.
  bool get _isCompactWidth => ocptIsCompactWidth(MediaQuery.sizeOf(context).width);

  /// Register [_onTextControllerChanged] as a listener of [_textController] and
  /// [_onStyledEditorControllerChanged] as a listener of [_styledEditorController] and
  /// [_onRawHistoryChanged] as a listener of [_undoHistoryController].
  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextControllerChanged);
    _styledEditorController.addListener(_onStyledEditorControllerChanged);
    _undoHistoryController.addListener(_onRawHistoryChanged);
  }

  /// Build the editor view as a [Shortcuts].
  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
      SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
      SingleActivator(LogicalKeyboardKey.keyM, control: true, shift: true): _ModeToggleIntent(),
      SingleActivator(LogicalKeyboardKey.keyM, meta: true, shift: true): _ModeToggleIntent(),
      SingleActivator(LogicalKeyboardKey.keyF, control: true): _FindIntent(),
      SingleActivator(LogicalKeyboardKey.keyF, meta: true): _FindIntent(),
      SingleActivator(LogicalKeyboardKey.keyH, control: true): _ReplaceIntent(),
      SingleActivator(LogicalKeyboardKey.keyH, meta: true): _ReplaceIntent(),
      SingleActivator(LogicalKeyboardKey.escape): _CloseFindIntent(),
    },
    child: Actions(
      actions: {
        _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (intent) => _requestManualSave()),
        _ModeToggleIntent: CallbackAction<_ModeToggleIntent>(onInvoke: (intent) => _toggleMode()),
        _FindIntent: CallbackAction<_FindIntent>(
          onInvoke: (intent) => _requestOpenSearch(withReplaceRow: false),
        ),
        _ReplaceIntent: CallbackAction<_ReplaceIntent>(
          onInvoke: (intent) => _requestOpenSearch(withReplaceRow: true),
        ),
        _CloseFindIntent: CallbackAction<_CloseFindIntent>(
          onInvoke: (intent) => _requestCloseSearch(),
        ),
      },
      child: Scaffold(
        body: MultiBlocListener(
          listeners: [
            BlocListener<OcptEditorSpellCheckBloc, OcptEditorSpellCheckState>(
              listener: (context, spellState) =>
                  _syncSpellCheck(context.read<OcptEditorBloc>().state, spellState),
            ),
            BlocListener<OcptEditorSearchBloc, OcptEditorSearchState>(
              listener: (context, search) => _searchSync.sync(
                context.read<OcptEditorBloc>().state,
                search,
                context.read<OcptEditorSearchBloc>(),
              ),
            ),
            BlocListener<OcptEditorIoBloc, OcptEditorIoState>(listener: _onIoStateChanged),
          ],
          child: BlocConsumer<OcptEditorBloc, OcptEditorState>(
            listener: _onStateChanged,
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final isReadOnly = state.isPreviewingVersion;
              final isRawMode = _liveMode(state) == OcptEditorMode.raw;
              final workspaceState = context.watch<OcptWorkspaceBloc>().state;

              return OcptWorkspaceShell(
                title: state.title,
                isDirty: state.isDirty,
                isReadOnly: isReadOnly,
                onBack: () =>
                    context.read<OcptEditorBloc>().add(const OcptEditorBackRequestedEvent()),
                episodes: workspaceState.episodes,
                selectedEpisodeId: workspaceState.selectedEpisodeId,
                onEpisodeSelected: (episodeId) => context.read<OcptWorkspaceBloc>().add(
                  OcptWorkspaceEpisodeSelectedEvent(episodeId: episodeId),
                ),
                // Withheld under a preview like every other way into the project settings: a preview
                // has nothing there that may be written.
                onAddEpisodeRequested: isReadOnly
                    ? null
                    : () => OcptEditorDialogFlows.projectSettings(
                        context,
                        reveal: OcptProjectSettingsReveal.episodes,
                      ),
                // A version being previewed leaves the whole group out: the format controls write,
                // and the two remaining ones are about an editing mode that isn't shown at all then
                // (the centre is the formatted preview whichever mode is active, and the dock's
                // preview tab doesn't exist). Every dock tab stays reachable from the dock's own tab
                // row. Below the compact breakpoint the format controls fold into the overflow
                // menu: the fixed-width inline row has no room left beside everything else the
                // toolbar already carries there. Both widgets read and write the very same
                // controller, so this is never a second flow, only how it is presented. The preview
                // and syntax selectors are raw-mode only: the styled mode has no preview tab at all.
                toolbarActions: isReadOnly
                    ? const []
                    : [
                        if (_isCompactWidth)
                          OcptEditorFormatOverflowMenu(controller: _styledEditorController)
                        else
                          OcptEditorFormatControls(controller: _styledEditorController),
                        if (isRawMode) ...[
                          OcptEditorDockTabToggle(
                            tab: OcptEditorRightDockTab.preview,
                            isActive: state.rightDockTab == OcptEditorRightDockTab.preview,
                            activeIcon: Icons.article,
                            inactiveIcon: Icons.article_outlined,
                            tooltip: Tr.of(context).editorTogglePreviewTooltip,
                          ),
                          OcptEditorDockTabToggle(
                            tab: OcptEditorRightDockTab.syntax,
                            isActive: state.rightDockTab == OcptEditorRightDockTab.syntax,
                            activeIcon: Icons.help,
                            inactiveIcon: Icons.help_outline,
                            tooltip: Tr.of(context).editorToggleSyntaxGuideTooltip,
                          ),
                        ],
                        OcptEditorModeToggle(mode: state.mode, onPressed: _toggleMode),
                      ],
                modeLabel: Tr.of(context).workspaceModeLabelScreenplay,
                onExportRequested: (anchor) =>
                    unawaited(OcptEditorDialogFlows.export(context, anchor)),
                overflowEntries: _overflowEntriesOf(context, state),
                isLeftDockOpen: state.isScenePanelVisible,
                onToggleLeftDock: () =>
                    context.read<OcptEditorBloc>().add(const OcptEditorScenePanelToggledEvent()),
                isRightDockOpen: state.rightDockTab != null,
                onToggleRightDock: () =>
                    context.read<OcptEditorBloc>().add(const OcptEditorRightDockToggledEvent()),
                // A previewed version has nothing to save: the whole point of the preview is that
                // nothing the user does reaches the project.
                onSave: isReadOnly ? null : _requestManualSave,
                isSaving: state.isSaving,
                onProjectSettingsRequested: isReadOnly
                    ? null
                    : () => OcptEditorDialogFlows.projectSettings(context),
                banner: state.previewedVersion == null
                    ? null
                    : OcptEditorReadOnlyBanner(version: state.previewedVersion!),
                leftPanel: state.isScenePanelVisible
                    ? OcptEditorScenePanel(
                        scenes: state.scenes,
                        currentLine: state.currentLine,
                        onSceneSelected: (charOffset) => context.read<OcptEditorBloc>().add(
                          OcptEditorSceneJumpRequestedEvent(charOffset: charOffset),
                        ),
                      )
                    : null,
                rightPanel: state.rightDockTab == null
                    ? null
                    : OcptEditorRightDockView(
                        state: state,
                        liveMode: _liveMode(state),
                        onEditTitlePage: isReadOnly
                            ? null
                            : () => OcptEditorDialogFlows.titlePage(context),
                      ),
                centre: OcptEditorCentre(
                  state: state,
                  isRawMode: isRawMode,
                  isPageSimulationLive: _isPageSimulationLive(state),
                  isCompact: _isCompactWidth,
                  isPhoneWidth: _isPhoneWidth,
                  textController: _textController,
                  scrollController: _editorScrollController,
                  focusNode: _editorFocusNode,
                  undoController: _undoHistoryController,
                  styledController: _styledEditorController,
                  searchSync: _searchSync,
                  // The consumer's context stays mounted when the shell moves the centre.
                  onReplaceAllRequested: (search) => unawaited(
                    isRawMode
                        ? _searchSync.requestRawReplaceAll(context, search)
                        : _searchSync.requestStyledReplaceAll(context, search),
                  ),
                ),
                statusBar: OcptEditorStatusBar(lastSavedAt: state.lastSavedAt),
                dockLayoutController: _dockLayoutController,
                onDockFractionsChanged: (fractions) => context.read<OcptEditorBloc>().add(
                  OcptEditorDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  /// The editing mode actually driving which surface is live and wired up:
  /// [OcptEditorState.mode], unless [_isPhoneWidth] forces the styled editor regardless. The
  /// user's own raw/styled toggle (the toolbar icon, Ctrl+Shift+M) is left untouched by this —
  /// it keeps persisting whatever the user picks, and widening the window back out returns to it.
  OcptEditorMode _liveMode(OcptEditorState state) =>
      _isPhoneWidth ? OcptEditorMode.styled : state.mode;

  /// Whether page simulation is actually applied to the live editing surface:
  /// [OcptEditorState.isPageSimulationEnabled], forced off at [_isPhoneWidth] for the same reason
  /// [_liveMode] forces the mode — a real-size simulated page has no room to be legible on a
  /// phone. The user's own toggle is left untouched the same way [_liveMode] leaves the mode
  /// toggle untouched.
  bool _isPageSimulationLive(OcptEditorState state) =>
      state.isPageSimulationEnabled && !_isPhoneWidth;

  /// Builds the screenplay's `⋮` overflow menu entries: undo and redo, import and replace, find,
  /// find and replace, the page-simulation and scene-numbers toggles, page setup, title page, and
  /// resetting the panel layout.
  ///
  /// `Undo` and `Redo` come first, the way an edit menu always states them, and each is *withheld*
  /// rather than shown disabled when the active editing surface has nothing left to take back or
  /// put back (see [_historyAvailability]) — the repository rule every read-only affordance
  /// already follows. They act on whichever surface is showing, never on a mode of their own: a
  /// menu whose entries answered in only one of the two editing modes would be worse than no menu
  /// at all.
  ///
  /// Finding and replacing are two entries rather than one, each opening the bar the way its own
  /// shortcut does — on the find row alone, or with the replace row unfolded — since looking
  /// something up is by far the more common of the two and asking for it should not put a replace
  /// field under the caret. Both state their shortcut on the right through
  /// [OcptToolbarMenuItemLabel]; every other entry here has none to state and stays a plain [Text].
  ///
  /// The two exports moved to the toolbar's own `Export` button and its panel (see
  /// `OcptEditorDialogFlows.export`) — this menu keeps everything else. While a version is being previewed, the
  /// entries that rewrite the screenplay — import and replace, find and replace, page setup, title
  /// page — are left out, and so is plain find: the centre is then the read-only preview, which
  /// carries no bar to open. The rest stays: the page-simulation, scene-numbers, spell-check and
  /// panel-layout entries are app-wide display preferences that never touch a project.
  List<PopupMenuEntry<void>> _overflowEntriesOf(BuildContext context, OcptEditorState state) {
    final tr = Tr.of(context);
    final isReadOnly = state.isPreviewingVersion;

    final history = _historyAvailability(state);

    return [
      if (!isReadOnly) ...[
        if (history.canUndo)
          PopupMenuItem<void>(
            onTap: () => _requestUndo(state),
            child: OcptToolbarMenuItemLabel(
              label: tr.editorUndoAction,
              shortcut: ocptPrimaryShortcutLabel("Z"),
            ),
          ),
        if (history.canRedo)
          PopupMenuItem<void>(
            onTap: () => _requestRedo(state),
            child: OcptToolbarMenuItemLabel(
              label: tr.editorRedoAction,
              shortcut: ocptPrimaryShortcutLabel("Z", isShifted: true),
            ),
          ),
        PopupMenuItem<void>(
          onTap: () => OcptEditorDialogFlows.importAndReplace(context),
          child: Text(tr.editorImportAndReplaceAction),
        ),
        PopupMenuItem<void>(
          onTap: () => _requestOpenSearch(withReplaceRow: false),
          child: OcptToolbarMenuItemLabel(
            label: tr.editorFindAction,
            shortcut: ocptPrimaryShortcutLabel("F"),
          ),
        ),
        PopupMenuItem<void>(
          onTap: () => _requestOpenSearch(withReplaceRow: true),
          child: OcptToolbarMenuItemLabel(
            label: tr.editorFindAndReplaceAction,
            shortcut: ocptPrimaryShortcutLabel("H"),
          ),
        ),
      ],
      // Reads the persisted preference, not [_isPageSimulationLive], for the same reason the
      // raw/styled toggle above does: this checkbox states what the user asked for, forced off at
      // a phone width or not.
      CheckedPopupMenuItem<void>(
        checked: state.isPageSimulationEnabled,
        onTap: () =>
            context.read<OcptEditorBloc>().add(const OcptEditorPageSimulationToggledEvent()),
        child: Text(tr.editorTogglePageSimulationAction),
      ),
      CheckedPopupMenuItem<void>(
        checked: state.areStyledSceneNumbersVisible,
        onTap: () =>
            context.read<OcptEditorBloc>().add(const OcptEditorStyledSceneNumbersToggledEvent()),
        child: Text(tr.editorToggleSceneNumbersAction),
      ),
      CheckedPopupMenuItem<void>(
        checked: state.isSpellCheckVisible,
        onTap: () => context.read<OcptEditorBloc>().add(const OcptEditorSpellCheckToggledEvent()),
        child: Text(tr.editorToggleSpellCheckAction),
      ),
      if (!isReadOnly) ...[
        PopupMenuItem<void>(
          onTap: () => OcptEditorDialogFlows.pageSetup(context),
          child: Text(tr.editorPageSetupAction),
        ),
        PopupMenuItem<void>(
          onTap: () => OcptEditorDialogFlows.titlePage(context),
          child: Text(tr.editorTitlePageAction),
        ),
      ],
      PopupMenuItem<void>(
        onTap: () => context.read<OcptEditorBloc>().add(const OcptEditorDockLayoutResetEvent()),
        child: Text(tr.editorResetPanelLayoutAction),
      ),
    ];
  }

  /// Sends the manual save request (toolbar button or Ctrl+S).
  void _requestManualSave() {
    context.read<OcptEditorBloc>().add(const OcptEditorSaveRequestedEvent(isManual: true));
  }

  /// Sends the mode toggle request (toolbar button or Ctrl+Shift+M).
  void _toggleMode() {
    context.read<OcptEditorBloc>().add(const OcptEditorModeToggledEvent());
  }

  /// What the editing surface [state] currently shows has left to take back and to put back: the
  /// raw field's own Flutter history in raw mode, the styled editor's `Editor` history in styled
  /// mode.
  ///
  /// Asking the *active* surface is the whole rule here — the undo history belongs to the surface,
  /// and switching surface starts a fresh one, which is what every editor with two views does.
  /// Neither branch answers anything while a version is being previewed: there is no editing
  /// surface at all then, and the entries reading this are withheld before it is even called.
  ({bool canUndo, bool canRedo}) _historyAvailability(OcptEditorState state) =>
      _liveMode(state) == OcptEditorMode.raw
      ? (
          canUndo: _undoHistoryController.value.canUndo,
          canRedo: _undoHistoryController.value.canRedo,
        )
      : (canUndo: _styledEditorController.canUndo, canRedo: _styledEditorController.canRedo);

  /// Takes back the last gesture made in the surface [state] shows (the `⋮` menu's `Undo` entry),
  /// which is what Ctrl+Z reaches inside that same surface on its own.
  void _requestUndo(OcptEditorState state) {
    if (_liveMode(state) == OcptEditorMode.raw) {
      _undoHistoryController.undo();
    } else {
      _styledEditorController.undo();
    }
  }

  /// Puts back the last gesture taken back in the surface [state] shows (the `⋮` menu's `Redo`
  /// entry); the styled editor refuses one a later edit has overtaken, exactly as its own
  /// Ctrl+Shift+Z does.
  void _requestRedo(OcptEditorState state) {
    if (_liveMode(state) == OcptEditorMode.raw) {
      _undoHistoryController.redo();
    } else {
      _styledEditorController.redo();
    }
  }

  /// Rebuilds the page when the raw field's undo history gained or lost something to take back or
  /// put back, so the `⋮` menu's entries appear and vanish with it.
  ///
  /// The rebuild is deferred past the current frame when the notification lands in the middle of
  /// one: `UndoHistory` refreshes its controller from its own `initState` when the field is
  /// mounted already focused, which runs synchronously inside this page's build, and `setState`
  /// there trips Flutter's "called during build" guard. Every other occasion (the push throttle
  /// firing, an undo, a redo, a focus change) is outside any build phase already.
  void _onRawHistoryChanged() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });

      return;
    }

    setState(() {});
  }

  /// Opens the find/replace bar (Ctrl+F, Ctrl+H, or the `⋮` menu's `Find…` / `Find and replace…`
  /// entries).
  ///
  /// A no-op while a project version is being previewed: the bar is withheld entirely then (there
  /// is no editing surface to search), the same way `Import and replace…` already is — but unlike
  /// that entry, Ctrl+F/Ctrl+H stay bound at the page level whatever is on screen, so this is the
  /// one place that has to check.
  void _requestOpenSearch({required bool withReplaceRow}) {
    if (context.read<OcptEditorBloc>().state.isPreviewingVersion) {
      return;
    }
    final searchBloc = context.read<OcptEditorSearchBloc>();
    searchBloc.add(OcptEditorSearchOpenedEvent(withReplaceRow: withReplaceRow));
  }

  /// Closes the find/replace bar (Escape).
  void _requestCloseSearch() {
    context.read<OcptEditorSearchBloc>().add(const OcptEditorSearchClosedEvent());
  }

  /// Pushes both sets of spell-check ranges onto the live editing surface, see
  /// [_syncRawSpellCheck] and [_syncStyledSpellCheck].
  void _syncSpellCheck(OcptEditorState state, OcptEditorSpellCheckState spellState) {
    _syncRawSpellCheck(state, spellState);
    _syncStyledSpellCheck(state, spellState);
  }

  /// Pushes [OcptEditorSpellCheckState.rawSpellCheckRanges] onto [_textController]'s own
  /// [OcptEditorSearchTextController.updateSpellCheckRanges], the raw mode's half of the rule
  /// that each editing surface paints what it shows.
  ///
  /// Guarded exactly the way the raw search sync opens (raw mode, not previewing a version): the
  /// styled mode is a later slice that addresses each node by id instead, and there is no editing
  /// surface at all under a read-only preview to underline anything in. Both cases clear the
  /// controller's ranges rather than leaving a raw field the user can no longer see holding a stale
  /// set — harmless on its own since nothing repaints it, but exactly the kind of state a mode
  /// switch back to raw should never resurrect uninvited.
  void _syncRawSpellCheck(OcptEditorState state, OcptEditorSpellCheckState spellState) {
    if (_liveMode(state) != OcptEditorMode.raw || state.isPreviewingVersion) {
      _textController.updateSpellCheckRanges(const []);
      return;
    }

    _textController.updateSpellCheckRanges(spellState.rawSpellCheckRanges);
  }

  /// Pushes [OcptEditorSpellCheckState.styledSpellCheckRanges] onto [_styledEditorController]'s own
  /// [OcptStyledEditorController.updateSpellCheckRanges], the styled mode's own half of the rule
  /// that each editing surface paints what it shows — the raw mode's own counterpart is
  /// [_syncRawSpellCheck].
  ///
  /// Guarded exactly the way [_syncRawSpellCheck] is (styled mode, not previewing a version): there
  /// is no live styled editor to push anything onto otherwise, and a version preview has no editing
  /// surface at all to underline anything in. Both cases clear the controller's ranges, for the
  /// identical reason [_syncRawSpellCheck]'s own doc comment gives.
  void _syncStyledSpellCheck(OcptEditorState state, OcptEditorSpellCheckState spellState) {
    if (_liveMode(state) != OcptEditorMode.styled || state.isPreviewingVersion) {
      _styledEditorController.updateSpellCheckRanges(const {});
      return;
    }

    _styledEditorController.updateSpellCheckRanges(spellState.styledSpellCheckRanges);
  }

  /// Rebuilds the `⋮` menu's entries when the styled editor gained or lost something to undo or
  /// redo, reports [_styledEditorController]'s own checkable spell-check texts to the bloc whenever
  /// the styled editing surface is actually the live one, then reports its search match count too
  /// — each exactly once per genuine change: the controller notifies its listeners for several
  /// unrelated reasons (a block-type or inline-style read-state refresh, either of the other two),
  /// and [_lastReportedStyledSpellCheckTexts] are what keep
  /// those from being mistaken for a fresh report of their own kind.
  ///
  /// Spell-check reporting is gated on the styled surface actually being live (styled mode, not
  /// previewing) but, unlike the search-match report below it, **not** on the find bar being open:
  /// spell-checking runs whether or not the bar is showing. Search reporting keeps its own,
  /// narrower gate (also requiring `state.search.isOpen`) since the bloc has nothing useful to do
  /// with a match count while there's no bar to show it in — a stray report right as the mode/bar
  /// state changes underneath either must never reach the bloc.
  void _onStyledEditorControllerChanged() {
    final historyAvailability = (
      canUndo: _styledEditorController.canUndo,
      canRedo: _styledEditorController.canRedo,
    );
    if (historyAvailability != _lastStyledHistoryAvailability) {
      _lastStyledHistoryAvailability = historyAvailability;
      // `OcptStyledEditorController` never notifies from inside a build phase (see its own
      // `_notifySafely`), so this one needs none of [_onRawHistoryChanged]'s deferral.
      setState(() {});
    }

    final bloc = context.read<OcptEditorBloc>();
    final state = bloc.state;
    final isStyledSurfaceLive =
        _liveMode(state) == OcptEditorMode.styled && !state.isPreviewingVersion;

    if (isStyledSurfaceLive) {
      final spellCheckTexts = _styledEditorController.spellCheckTextsByNodeId;
      if (!mapEquals(spellCheckTexts, _lastReportedStyledSpellCheckTexts)) {
        _lastReportedStyledSpellCheckTexts = spellCheckTexts;
        context.read<OcptEditorSpellCheckBloc>().add(
          OcptEditorStyledSpellCheckTextsReportedEvent(textsByNodeId: spellCheckTexts),
        );
      }
    }

    _searchSync.reportStyledMatchCount(
      isStyledSurfaceLive: isStyledSurfaceLive,
      searchBloc: context.read<OcptEditorSearchBloc>(),
    );
  }

  /// Reports the controller's text and caret line changes to the bloc.
  void _onTextControllerChanged() {
    if (_isApplyingProgrammaticChange) {
      return;
    }

    final bloc = context.read<OcptEditorBloc>();
    final text = _textController.text;
    if (text != _lastReportedText) {
      _lastReportedText = text;
      bloc.add(OcptEditorTextChangedEvent(text: text));
    }

    final line = _caretLine();
    if (line != _lastReportedLine) {
      _lastReportedLine = line;
      bloc.add(OcptEditorCaretMovedEvent(line: line));
    }
  }

  /// The 0-based line the caret is currently on (0 when there is no valid selection).
  int _caretLine() {
    final baseOffset = _textController.selection.baseOffset;
    if (baseOffset < 0) {
      return 0;
    }

    final text = _textController.text;
    final clampedOffset = baseOffset > text.length ? text.length : baseOffset;
    return "\n".allMatches(text.substring(0, clampedOffset)).length;
  }

  /// Applies bloc-driven effects onto the page: keeping the raw text controller in sync with any
  /// text change that didn't originate from it (the initial load, or an edit made in styled
  /// mode), scene jump requests, the transient save error SnackBar, and the live dock fractions.
  ///
  /// The styled editor is handed [OcptEditorState.text] directly as a widget property and syncs
  /// itself (see `OcptStyledScreenplayEditor`); only the raw controller needs this imperative
  /// nudge, since it's a plain [TextEditingController] rather than something driven by `build`.
  void _onStateChanged(BuildContext context, OcptEditorState state) {
    // Pushes the bloc's persisted fractions (the initial load, or "Reset panel layout") onto the
    // live controller; a no-op once a drag's own end-of-gesture event brings the bloc back in
    // sync with the value the controller already holds.
    _dockLayoutController.syncFromPersisted(
      leftFraction: state.leftDockFraction,
      rightFraction: state.rightDockFraction,
    );

    if (!state.isLoading && state.text != _lastReportedText) {
      _isApplyingProgrammaticChange = true;
      try {
        final previousSelection = _textController.selection;
        _textController.text = state.text;
        _textController.selection =
            previousSelection.isValid && previousSelection.end <= state.text.length
            ? previousSelection
            : const TextSelection.collapsed(offset: 0);
        _lastReportedText = state.text;
      } finally {
        _isApplyingProgrammaticChange = false;
      }
    }

    // Scene jumps are only applied to the raw controller while raw mode is actually visible: the
    // styled editor applies its own jump requests independently, and forcing focus onto the
    // hidden raw field here would otherwise steal it away from the visible styled editor.
    if (_liveMode(state) == OcptEditorMode.raw) {
      final jumpRequest = state.jumpRequest;
      if (jumpRequest != null && jumpRequest.id != _lastAppliedJumpRequestId) {
        _lastAppliedJumpRequestId = jumpRequest.id;
        _rawScroller.applyJumpRequest(jumpRequest.charOffset);
      }
    }

    _searchSync.sync(
      state,
      context.read<OcptEditorSearchBloc>().state,
      context.read<OcptEditorSearchBloc>(),
    );
    _syncSpellCheck(state, context.read<OcptEditorSpellCheckBloc>().state);

    if (state.hasSaveError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).editorSaveError)));
      context.read<OcptEditorBloc>().add(const OcptEditorSaveErrorDismissedEvent());
    }

    final versionNotice = state.projectVersionNotice;
    if (versionNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectVersionNoticeMessage(context, versionNotice))),
        );
      context.read<OcptEditorBloc>().add(const OcptProjectVersionNoticeDismissedEvent());
    }

    final packagePendingExport = state.projectPackagePendingExport;
    if (packagePendingExport != null) {
      context.read<OcptEditorBloc>().add(const OcptProjectPackageMissingFilesAskDismissedEvent());
      unawaited(OcptEditorDialogFlows.askAboutMissingPackagedFiles(context, packagePendingExport));
    }

    final packageNotice = state.projectPackageNotice;
    if (packageNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectPackageNoticeMessage(context, packageNotice))),
        );
      context.read<OcptEditorBloc>().add(const OcptProjectPackageNoticeDismissedEvent());
    }
  }

  /// Shows the outcome of an export or an import as a SnackBar, then dismisses it.
  void _onIoStateChanged(BuildContext context, OcptEditorIoState ioState) {
    final ioNotice = ioState.ioNotice;
    if (ioNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(OcptEditorDialogFlows.ioNoticeMessage(context, ioNotice))),
        );
      context.read<OcptEditorIoBloc>().add(const OcptEditorIoNoticeDismissedEvent());
    }
  }

  /// Dispose [_textController], [_editorScrollController] and [_editorFocusNode], detach
  /// [_onRawHistoryChanged] from [_undoHistoryController], dispose [_undoHistoryController], detach
  /// [_onStyledEditorControllerChanged] from [_styledEditorController], then dispose
  /// [_styledEditorController] and [_dockLayoutController].
  @override
  void dispose() {
    _textController.dispose();
    _editorScrollController.dispose();
    _editorFocusNode.dispose();
    _undoHistoryController.removeListener(_onRawHistoryChanged);
    _undoHistoryController.dispose();
    _styledEditorController.removeListener(_onStyledEditorControllerChanged);
    _styledEditorController.dispose();
    _dockLayoutController.dispose();
    super.dispose();
  }
}
