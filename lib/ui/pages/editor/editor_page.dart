// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_export_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_settings_reveal.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_text_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_format_controls.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_metadata_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_page_setup_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_saved_time_segment.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_title_page_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_toolbar_menu_item_label.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_read_only_banner.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shortcut_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_export_tag.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/utils/ocpt_text_search.dart';

/// The screenplay editor: either the styled block editor or the raw Fountain source in the center
/// (depending on the persisted `OcptEditorMode`, forced to the styled editor on a phone — see
/// `_EditorViewState._liveMode`/`docs/plans/tablet.md`), the collapsible scene panel on the left,
/// the tabbed right dock (formatted preview, raw mode only; the Fountain syntax guide, the scene
/// inspector, the read-only metadata panel and the project versions, all four in both modes)
/// hosting at most one panel at a time, and a thin toolbar above them.
///
/// While a project version is being previewed, the mode shows the version instead of the working
/// copy, and shows it read-only: the centre becomes the formatted preview whichever editing mode is
/// active (there is no editor at all then, see `OcptProjectVersionsPanel` and the plan's decision
/// 7 — making the styled editor read-only would mean a second super_editor rendering path to
/// maintain forever), every control that would write is withheld, and the shell carries the band
/// naming the version. Reading the screenplay, browsing its scenes, exporting it and looking at its
/// statistics all stay available: none of them touches the project.
///
/// The `OcptRouterManager` editor guard guarantees a project is open when this page is reached.
class EditorPage extends StatelessWidget {
  /// Creates the editor page.
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => OcptEditorBloc(
      selectedEpisodeId: context.read<OcptWorkspaceBloc>().state.selectedEpisodeId,
    ),
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

/// The content of [EditorPage], separated from it so [EditorPage] only wires the [OcptEditorBloc]
/// up (RFL3).
///
/// This is a StatefulWidget (the documented RFL1 exception) because it owns the text editing
/// controller: the source text lives in the controller (the bloc only receives change events),
/// and applying bloc-driven effects (initial text, scene jumps) requires imperative access to it.
class _EditorView extends StatefulWidget {
  /// Class constructor
  const _EditorView();

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

  /// The `(query, isCaseSensitive, isWholeWord, text)` combination [_textController]'s matches
  /// were last computed from and reported to the bloc, in raw mode.
  ///
  /// Reset to null whenever raw mode's search sync is skipped (styled mode is active, a version is
  /// being previewed, or the bar is closed), so the next time it applies again always recomputes
  /// and re-reports rather than trusting a coincidental match against stale state from before the
  /// gap — see [_syncRawSearch]'s own doc comment.
  ({String query, bool isCaseSensitive, bool isWholeWord, String text})? _lastReportedRawSearchInputs;

  /// The `(query, isCaseSensitive, isWholeWord, currentMatchIndex)` combination the raw
  /// controller's selection/scroll were last navigated to.
  ///
  /// Deliberately excludes the source text itself: recomputing matches after every keystroke made
  /// *inside* the raw editor must not keep yanking the caret back to "the current match" while the
  /// user is simply typing somewhere else. It's still included as part of [_syncRawSearch]'s own
  /// reset-on-gap behaviour, alongside [_lastReportedRawSearchInputs].
  ({String query, bool isCaseSensitive, bool isWholeWord, int? currentMatchIndex})?
  _lastNavigatedRawSearchTarget;

  /// The `(query, isCaseSensitive, isWholeWord, currentMatchIndex)` combination
  /// [_styledEditorController] was last handed a navigation for, the styled mode's own counterpart
  /// to [_lastNavigatedRawSearchTarget] — the styled editor's own delegate is what recomputes and
  /// re-highlights matches reactively on every keystroke made *inside* the document (it alone has
  /// live access to each node's current text), so this dedup only needs to gate genuine navigation
  /// (opening the bar, Next/Previous, a query/option change, a replace's own follow-up selection),
  /// exactly like [_lastNavigatedRawSearchTarget] gates raw mode's.
  ({String query, bool isCaseSensitive, bool isWholeWord, int? currentMatchIndex})?
  _lastNavigatedStyledSearchTarget;

  /// The [OcptStyledEditorController.searchMatchCount] last reported to the bloc, so
  /// [_onStyledEditorControllerChanged] only dispatches [OcptEditorSearchMatchesReportedEvent] on
  /// a genuine change — the controller notifies its listeners for other reasons too (a block-type
  /// or inline-style read-state refresh), which must never be mistaken for a fresh match count.
  int? _lastReportedStyledSearchMatchCount;

  /// The `OcptStyledEditorController.spellCheckTextsByNodeId` last reported to the bloc, so
  /// [_onStyledEditorControllerChanged] only dispatches
  /// `OcptEditorStyledSpellCheckTextsReportedEvent` on a genuine change — the controller notifies
  /// its listeners for reasons that have nothing to do with spell-checking either (a block-type or
  /// history read-state refresh, or the search match count), the same reason
  /// [_lastReportedStyledSearchMatchCount] exists for the search count.
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

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextControllerChanged);
    _styledEditorController.addListener(_onStyledEditorControllerChanged);
    _undoHistoryController.addListener(_onRawHistoryChanged);
  }

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

  /// Whether the window this page is laid out in is a phone ([ocptIsPhoneWidth]/
  /// `docs/plans/tablet.md`) narrow enough to force the styled editor as the only editing surface,
  /// and page simulation off, regardless of what [OcptEditorState.mode] and
  /// [OcptEditorState.isPageSimulationEnabled] are persisted as: raw source (and its own
  /// find/replace and spell-check wiring) and a real-size simulated page have no room to be usable
  /// there. Deliberately the *phone* breakpoint rather than [ocptIsCompactWidth]'s wider one: a
  /// tablet window between the two still has room for the toolbar's format controls (hidden in raw
  /// mode, shown the moment the styled editor is forced on) beside everything else the toolbar
  /// already carries there, which a phone-width toolbar has separately been folded down for
  /// (`OcptWorkspaceShell`) but a merely-compact one has not.
  ///
  /// Read straight off [MediaQuery] rather than a value captured once by a `LayoutBuilder` in
  /// [build]: [_syncRawSearch] and its siblings run from the `BlocConsumer`'s `listener`, which
  /// fires independently of (and sometimes before) a rebuild, so they need a getter that always
  /// answers with the window's current width rather than a stale build-time snapshot.
  bool get _isPhoneWidth => ocptIsPhoneWidth(MediaQuery.sizeOf(context).width);

  /// Whether the window this page is laid out in is narrow enough ([ocptIsCompactWidth]) that the
  /// styled editor — forced on by [_isPhoneWidth], or simply the user's own live preference at any
  /// width — should carry its block hierarchy by style rather than by the real screenplay indents
  /// (see [OcptStyledScreenplayEditor.isCompact]/`docs/plans/tablet.md`): a tablet window has more
  /// room than a phone, but still not the width a real screenplay page wants.
  bool get _isCompactWidth => ocptIsCompactWidth(MediaQuery.sizeOf(context).width);

  /// The editing mode actually driving which surface is live and wired up:
  /// [OcptEditorState.mode], unless [_isPhoneWidth] forces the styled editor regardless. The
  /// user's own raw/styled toggle (the toolbar icon, Ctrl+Shift+M) is left untouched by this —
  /// it keeps persisting whatever the user picks, and widening the window back out returns to it.
  OcptEditorMode _liveMode(OcptEditorState state) => _isPhoneWidth ? OcptEditorMode.styled : state.mode;

  /// Whether page simulation is actually applied to the live editing surface:
  /// [OcptEditorState.isPageSimulationEnabled], forced off at [_isPhoneWidth] for the same reason
  /// [_liveMode] forces the mode — a real-size simulated page has no room to be legible on a
  /// phone. The user's own toggle is left untouched the same way [_liveMode] leaves the mode
  /// toggle untouched.
  bool _isPageSimulationLive(OcptEditorState state) => state.isPageSimulationEnabled && !_isPhoneWidth;

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
        _CloseFindIntent: CallbackAction<_CloseFindIntent>(onInvoke: (intent) => _requestCloseSearch()),
      },
      child: Scaffold(
        body: BlocConsumer<OcptEditorBloc, OcptEditorState>(
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
              onBack: () => context.read<OcptEditorBloc>().add(
                const OcptEditorBackRequestedEvent(),
              ),
              episodes: workspaceState.episodes,
              selectedEpisodeId: workspaceState.selectedEpisodeId,
              onEpisodeSelected: (episodeId) => context.read<OcptWorkspaceBloc>().add(
                OcptWorkspaceEpisodeSelectedEvent(episodeId: episodeId),
              ),
              // Withheld under a preview like every other way into the project settings: a preview
              // has nothing there that may be written.
              onAddEpisodeRequested: isReadOnly
                  ? null
                  : () => _requestProjectSettings(
                      context,
                      reveal: OcptProjectSettingsReveal.episodes,
                    ),
              toolbarActions: _buildToolbarActions(context, state, isRawMode: isRawMode),
              modeLabel: Tr.of(context).workspaceModeLabelScreenplay,
              onExportRequested: (anchor) => unawaited(_requestExport(context, anchor)),
              overflowEntries: _buildOverflowEntries(context, state),
              isLeftDockOpen: state.isScenePanelVisible,
              onToggleLeftDock: () => context.read<OcptEditorBloc>().add(
                const OcptEditorScenePanelToggledEvent(),
              ),
              isRightDockOpen: state.rightDockTab != null,
              onToggleRightDock: () => context.read<OcptEditorBloc>().add(
                const OcptEditorRightDockToggledEvent(),
              ),
              // A previewed version has nothing to save: the whole point of the preview is that
              // nothing the user does reaches the project.
              onSave: isReadOnly ? null : _requestManualSave,
              isSaving: state.isSaving,
              onProjectSettingsRequested: isReadOnly
                  ? null
                  : () => _requestProjectSettings(context),
              banner: _buildReadOnlyBanner(context, state),
              leftPanel: _buildScenePanel(context, state),
              rightPanel: _buildRightDock(context, state),
              centre: _buildCentre(context, state, isRawMode: isRawMode),
              statusBar: _buildStatusBar(context, state),
              dockLayoutController: _dockLayoutController,
              onDockFractionsChanged: (fractions) => context.read<OcptEditorBloc>().add(
                OcptEditorDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
              ),
            );
          },
        ),
      ),
    ),
  );

  /// Builds the band naming the version being previewed, the shell's `banner`, or null while the
  /// working copy is on screen.
  ///
  /// Null too — the banner is simply not drawn — in the narrow window where the previewed version
  /// isn't in the list the panel was drawn from any more: the refresh ending every version handler
  /// resolves it on its own, and a band that named nothing would say less than no band at all.
  Widget? _buildReadOnlyBanner(BuildContext context, OcptEditorState state) {
    final previewedVersion = state.previewedVersion;
    if (previewedVersion == null) {
      return null;
    }

    final tr = Tr.of(context);

    return OcptWorkspaceReadOnlyBanner(
      version: previewedVersion,
      // `Start from this version` is a plain restore of the version being previewed:
      // `OcptProjectsManager.restoreProjectVersion` leaves the preview on its own before writing
      // anything, so the handler needs nothing beyond the same event a version's own card
      // dispatches.
      onForkRequested: () => context.read<OcptEditorBloc>().add(
        OcptProjectVersionRestoreConfirmedEvent(
          versionId: previewedVersion.id,
          safetyVersionName: tr.projectVersionRestoreSafetyName(previewedVersion.name),
        ),
      ),
      onExitPreview: () => context.read<OcptEditorBloc>().add(
        const OcptProjectVersionPreviewExitRequestedEvent(),
      ),
    );
  }

  /// Builds the screenplay's own toolbar controls, right-aligned before the chrome the shell
  /// builds itself (the mode label, the dock toggles, the save action and the overflow menu): the
  /// block-type/format controls (rendered only while attached to a live styled editor), the right
  /// dock's preview and syntax tab selectors, and the styled/raw mode toggle.
  ///
  /// Both tab selectors are raw-mode only: the styled mode has no preview tab at all, and its own
  /// layout leaves the syntax guide reachable through the dock's tab row alone, which keeps the
  /// toolbar from carrying a shortcut to a tab the mode barely uses.
  ///
  /// The format controls are additionally withheld on a phone ([_isPhoneWidth]): they render a
  /// block-type dropdown plus three toggle buttons the moment they attach to a live styled editor,
  /// and the styled editor is exactly what a phone always shows ([_liveMode]) — the phone-width
  /// toolbar (already folded down by `OcptWorkspaceShell`) has no room left for this on top of
  /// everything else it carries, and a phone writer still has every one of these through
  /// `OcptEditorContextMenu`'s block-type submenu (block type) or simply typing the Fountain
  /// markup (bold/italic/underline).
  ///
  /// A version being previewed leaves the whole group out: the format controls write, and the two
  /// remaining ones are about an editing mode that isn't shown at all then (the centre is the
  /// formatted preview whichever mode is active, and the dock's preview tab doesn't exist — see
  /// [OcptEditorState.isPreviewTabAvailable]). Every dock tab stays reachable from the dock's own
  /// tab row.
  List<Widget> _buildToolbarActions(
    BuildContext context,
    OcptEditorState state, {
    required bool isRawMode,
  }) {
    final tr = Tr.of(context);

    if (state.isPreviewingVersion) {
      return const [];
    }

    return [
      if (!_isPhoneWidth) OcptEditorFormatControls(controller: _styledEditorController),
      if (isRawMode) ...[
        IconButton(
          icon: Icon(
            state.rightDockTab == OcptEditorRightDockTab.preview
                ? Icons.article
                : Icons.article_outlined,
            size: 20,
          ),
          tooltip: tr.editorTogglePreviewTooltip,
          isSelected: state.rightDockTab == OcptEditorRightDockTab.preview,
          onPressed: () => context.read<OcptEditorBloc>().add(
            const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.preview),
          ),
        ),
        IconButton(
          icon: Icon(
            state.rightDockTab == OcptEditorRightDockTab.syntax ? Icons.help : Icons.help_outline,
            size: 20,
          ),
          tooltip: tr.editorToggleSyntaxGuideTooltip,
          isSelected: state.rightDockTab == OcptEditorRightDockTab.syntax,
          onPressed: () => context.read<OcptEditorBloc>().add(
            const OcptEditorRightDockTabSelectedEvent(tab: OcptEditorRightDockTab.syntax),
          ),
        ),
      ],
      // Reads the persisted `state.mode` rather than [_liveMode]: this toggle is the user's own
      // desktop preference (`docs/plans/tablet.md`), left untouched by a phone width forcing the
      // styled editor onto the screen — it keeps stating (and toggling) what will apply once the
      // window widens back out, not what happens to be rendered right this moment.
      IconButton(
        icon: Icon(state.mode == OcptEditorMode.styled ? Icons.code : Icons.style, size: 20),
        tooltip: state.mode == OcptEditorMode.styled
            ? tr.editorSwitchToRawModeTooltip
            : tr.editorSwitchToStyledModeTooltip,
        onPressed: _toggleMode,
      ),
    ];
  }

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
  /// [_requestExport]) — this menu keeps everything else. While a version is being previewed, the
  /// entries that rewrite the screenplay — import and replace, find and replace, page setup, title
  /// page — are left out, and so is plain find: the centre is then the read-only preview, which
  /// carries no bar to open. The rest stays: the page-simulation, scene-numbers, spell-check and
  /// panel-layout entries are app-wide display preferences that never touch a project.
  List<PopupMenuEntry<void>> _buildOverflowEntries(BuildContext context, OcptEditorState state) {
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
          onTap: () => _requestImportAndReplace(context),
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
        onTap: () => context.read<OcptEditorBloc>().add(
          const OcptEditorPageSimulationToggledEvent(),
        ),
        child: Text(tr.editorTogglePageSimulationAction),
      ),
      CheckedPopupMenuItem<void>(
        checked: state.areStyledSceneNumbersVisible,
        onTap: () => context.read<OcptEditorBloc>().add(
          const OcptEditorStyledSceneNumbersToggledEvent(),
        ),
        child: Text(tr.editorToggleSceneNumbersAction),
      ),
      CheckedPopupMenuItem<void>(
        checked: state.isSpellCheckVisible,
        onTap: () => context.read<OcptEditorBloc>().add(
          const OcptEditorSpellCheckToggledEvent(),
        ),
        child: Text(tr.editorToggleSpellCheckAction),
      ),
      if (!isReadOnly) ...[
        PopupMenuItem<void>(
          onTap: () => _requestPageSetup(context),
          child: Text(tr.editorPageSetupAction),
        ),
        PopupMenuItem<void>(
          onTap: () => _requestTitlePage(context),
          child: Text(tr.editorTitlePageAction),
        ),
      ],
      PopupMenuItem<void>(
        onTap: () => context.read<OcptEditorBloc>().add(
          const OcptEditorDockLayoutResetEvent(),
        ),
        child: Text(tr.editorResetPanelLayoutAction),
      ),
    ];
  }

  /// Builds the scene panel, the shell's `leftPanel`, or null while it's hidden.
  Widget? _buildScenePanel(BuildContext context, OcptEditorState state) => state.isScenePanelVisible
      ? OcptEditorScenePanel(
          scenes: state.scenes,
          currentLine: state.currentLine,
          onSceneSelected: (charOffset) => context.read<OcptEditorBloc>().add(
            OcptEditorSceneJumpRequestedEvent(charOffset: charOffset),
          ),
        )
      : null;

  /// Builds the editor itself (raw source field or styled block editor), the shell's `centre`, or
  /// the read-only formatted preview while a project version is being previewed.
  ///
  /// That substitution is the plan's decision 7: the preview renders the version exactly as it
  /// would print, and reusing it costs nothing, whereas making the styled editor read-only would
  /// mean a second super_editor rendering path (`SuperReader`, its own stylesheet, its own
  /// title-page components) to maintain forever. It applies in both editing modes, since neither of
  /// them may be typed into.
  ///
  /// [isRawMode] is already [_liveMode]'s answer by the time it reaches here (see [build]), so on a
  /// phone the raw source field is never the one built here even when [OcptEditorState.mode] itself
  /// still says raw — the styled editor is, with page simulation forced off ([_isPageSimulationLive])
  /// and [OcptStyledScreenplayEditor.isCompact] set whenever the window is merely compact (a tablet
  /// too, not only a phone — see [_isCompactWidth]), which is the phone default `docs/plans/tablet.md`
  /// settled on: raw source and this same read-only preview (its own version-preview branch above)
  /// have no room to be usable there either.
  Widget _buildCentre(BuildContext context, OcptEditorState state, {required bool isRawMode}) {
    if (state.isPreviewingVersion) {
      return OcptEditorPreview(
        document: state.document,
        pageSetup: state.pageSetup,
        currentLine: state.currentLine,
        isPageSimulationEnabled: state.isPageSimulationEnabled,
      );
    }

    final editingSurface = isRawMode
        ? OcptEditorSourceField(
            controller: _textController,
            scrollController: _editorScrollController,
            focusNode: _editorFocusNode,
            undoController: _undoHistoryController,
          )
        : OcptStyledScreenplayEditor(
            text: state.text,
            pageSetup: state.pageSetup,
            isPageSimulationEnabled: _isPageSimulationLive(state),
            isCompact: _isCompactWidth,
            areSceneNumbersVisible: state.areStyledSceneNumbersVisible,
            isSpellCheckVisible: state.isSpellCheckVisible,
            onTextChanged: (text) => context.read<OcptEditorBloc>().add(
              OcptEditorTextChangedEvent(text: text),
            ),
            onCaretLineChanged: (line) => context.read<OcptEditorBloc>().add(
              OcptEditorCaretMovedEvent(line: line),
            ),
            jumpRequest: state.jumpRequest,
            styledController: _styledEditorController,
            onSpellingSuggestionsRequested: (word) =>
                context.read<OcptEditorBloc>().spellingSuggestionsFor(word),
            onWordIgnored: (word) => context.read<OcptEditorBloc>().add(
              OcptEditorWordIgnoredEvent(word: word),
            ),
            onWordLearned: (word) => context.read<OcptEditorBloc>().add(
              OcptEditorWordLearnedEvent(word: word),
            ),
          );

    // The find/replace bar is a *slot* that is always there — an empty box while it is closed —
    // rather than a child that comes and goes. A collection-`if` would move `editingSurface`
    // between two different positions in this column every time the bar opened or closed, and a
    // widget that changes position in the element tree is remounted whole rather than rebuilt: a
    // fresh `OcptStyledScreenplayEditor` state re-decodes the document, loses the caret, and
    // re-applies the pending scene-jump request — whose own `requestFocus()` then took the keyboard
    // focus straight back from the find field the bar had just opened, so the query being typed
    // landed in the screenplay instead of in the search.
    return Column(
      children: [
        _buildFindBar(context, state, isRawMode: isRawMode),
        Expanded(child: editingSurface),
      ],
    );
  }

  /// Builds the find/replace bar, the first row of [_buildCentre]'s column, or the empty box that
  /// holds its place while the bar is closed — see [_buildCentre] on why that slot is never removed.
  Widget _buildFindBar(BuildContext context, OcptEditorState state, {required bool isRawMode}) {
    if (!state.search.isOpen) {
      return const SizedBox.shrink();
    }

    return OcptEditorFindBar(
      query: state.search.query,
      replacement: state.search.replacement,
      isCaseSensitive: state.search.isCaseSensitive,
      isWholeWord: state.search.isWholeWord,
      isReplaceRowOpen: state.search.isReplaceRowOpen,
      matchCount: state.search.matchCount,
      currentMatchIndex: state.search.currentMatchIndex,
      focusRequestId: state.search.focusRequestId,
      onQueryChanged: (query) =>
          context.read<OcptEditorBloc>().add(OcptEditorSearchQueryChangedEvent(query: query)),
      onReplacementChanged: (replacement) => context.read<OcptEditorBloc>().add(
        OcptEditorSearchReplacementChangedEvent(replacement: replacement),
      ),
      onCaseSensitivityToggled: () =>
          context.read<OcptEditorBloc>().add(const OcptEditorSearchCaseSensitivityToggledEvent()),
      onWholeWordToggled: () =>
          context.read<OcptEditorBloc>().add(const OcptEditorSearchWholeWordToggledEvent()),
      onNextRequested: () =>
          context.read<OcptEditorBloc>().add(const OcptEditorSearchNextRequestedEvent()),
      onPreviousRequested: () =>
          context.read<OcptEditorBloc>().add(const OcptEditorSearchPreviousRequestedEvent()),
      onReplaceRowToggled: () =>
          context.read<OcptEditorBloc>().add(const OcptEditorSearchReplaceRowToggledEvent()),
      // Raw mode acts straight on `_textController`; styled mode goes through
      // `OcptStyledEditorController`, the styled editor's own bridge — either way the button
      // stays enabled the moment there's at least one match (`OcptEditorFindBar` itself gates
      // that on `matchCount`), which the repository rule admits no second, mode-specific path.
      onReplaceRequested: () => isRawMode ? _requestRawReplace(state) : _requestStyledReplace(state),
      onReplaceAllRequested: () => unawaited(
        isRawMode ? _requestRawReplaceAll(context, state) : _requestStyledReplaceAll(context, state),
      ),
      onCloseRequested: () => context.read<OcptEditorBloc>().add(const OcptEditorSearchClosedEvent()),
    );
  }

  /// Builds the tabbed right dock (formatted preview, raw mode only; the Fountain syntax guide,
  /// the scene inspector, the read-only metadata panel and the project versions, all four in both
  /// modes), the shell's `rightPanel`, or null while the dock is closed.
  ///
  /// The preview tab is gated on [_liveMode] rather than [OcptEditorState.mode]: on a phone the
  /// centre already is the formatted styled editor (see [_buildCentre]), the same reason
  /// [OcptEditorState.isPreviewTabAvailable]'s own doc comment gives for leaving it out of styled
  /// mode, so it would be redundant chrome even while the persisted preference is raw.
  Widget? _buildRightDock(BuildContext context, OcptEditorState state) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return null;
    }

    final isPreviewTabAvailable = OcptEditorState.isPreviewTabAvailableFor(
      mode: _liveMode(state),
      isReadOnly: state.isPreviewingVersion,
    );
    final previewChild = isPreviewTabAvailable && rightDockTab == OcptEditorRightDockTab.preview
        ? OcptEditorPreview(
            document: state.document,
            pageSetup: state.pageSetup,
            currentLine: state.currentLine,
            isPageSimulationEnabled: state.isPageSimulationEnabled,
          )
        : null;

    final currentSceneIndex = state.currentSceneIndex;

    return OcptEditorRightDock(
      activeTab: rightDockTab,
      isPreviewTabAvailable: isPreviewTabAvailable,
      previewChild: previewChild,
      inspectorChild: OcptEditorInspectorPanel(
        scene: currentSceneIndex == null ? null : state.scenes[currentSceneIndex],
        sceneOrdinal: currentSceneIndex == null ? null : currentSceneIndex + 1,
        statistics: state.sceneStatistics,
      ),
      metadataChild: OcptEditorMetadataPanel(
        titlePage: state.document?.titlePage,
        statistics: state.statistics,
        onEditTitlePage: state.isPreviewingVersion ? null : () => _requestTitlePage(context),
      ),
      versionsChild: _buildVersionsPanel(context, state),
      onTabSelected: (tab) => context.read<OcptEditorBloc>().add(
        OcptEditorRightDockTabSelectedEvent(tab: tab),
      ),
      onClose: () => context.read<OcptEditorBloc>().add(const OcptEditorRightDockClosedEvent()),
    );
  }

  /// Builds the right dock's `Versions` tab: the working copy's own card and the project's named
  /// versions, the same panel every production mode's dock hosts, wired to the events
  /// `MixinOcptProjectVersionsBloc` handles.
  Widget _buildVersionsPanel(BuildContext context, OcptEditorState state) =>
      OcptProjectVersionsPanel(
        versions: state.projectVersions,
        previewedVersionId: state.previewedVersionId,
        workingCopy: state.workingCopy,
        versionPendingDeletionId: state.versionPendingDeletionId,
        versionPendingRestoreId: state.versionPendingRestoreId,
        versionPendingRenameId: state.versionPendingRenameId,
        onCreateRequested: () => _requestVersionCreation(context),
        onPreviewRequested: (versionId) => context.read<OcptEditorBloc>().add(
          OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
        ),
        onPreviewExitRequested: () => context.read<OcptEditorBloc>().add(
          const OcptProjectVersionPreviewExitRequestedEvent(),
        ),
        onRestoreRequested: (versionId) => context.read<OcptEditorBloc>().add(
          OcptProjectVersionRestoreRequestedEvent(versionId: versionId),
        ),
        onRestoreCancelled: () => context.read<OcptEditorBloc>().add(
          const OcptProjectVersionRestoreCancelledEvent(),
        ),
        onRestoreConfirmed: (version) => context.read<OcptEditorBloc>().add(
          OcptProjectVersionRestoreConfirmedEvent(
            versionId: version.id,
            safetyVersionName: Tr.of(context).projectVersionRestoreSafetyName(version.name),
          ),
        ),
        onDeleteRequested: (versionId) => context.read<OcptEditorBloc>().add(
          OcptProjectVersionDeletionRequestedEvent(versionId: versionId),
        ),
        onDeleteCancelled: () => context.read<OcptEditorBloc>().add(
          const OcptProjectVersionDeletionCancelledEvent(),
        ),
        onDeleteConfirmed: (versionId) => context.read<OcptEditorBloc>().add(
          OcptProjectVersionDeletionConfirmedEvent(versionId: versionId),
        ),
        onRenameRequested: (versionId) => context.read<OcptEditorBloc>().add(
          OcptProjectVersionRenameRequestedEvent(versionId: versionId),
        ),
        onRenameCancelled: () => context.read<OcptEditorBloc>().add(
          const OcptProjectVersionRenameCancelledEvent(),
        ),
        onRenameConfirmed: (versionId, name, note) => context.read<OcptEditorBloc>().add(
          OcptProjectVersionRenameConfirmedEvent(versionId: versionId, name: name, note: note),
        ),
      );

  /// Shows the version creation dialog, then dispatches the capture if the user confirmed it.
  Future<void> _requestVersionCreation(BuildContext context) async {
    final bloc = context.read<OcptEditorBloc>();
    final fields = await OcptProjectVersionCreateDialog.show(context);
    if (fields == null) {
      return;
    }

    bloc.add(
      OcptProjectVersionCreationRequestedEvent(name: fields.name, note: fields.note),
    );
  }

  /// Builds the shell's `statusBar`: the screenplay's own ordered counters (pages, scenes,
  /// characters, words, signs — the first three never dropped) plus the self-refreshing
  /// last-saved segment.
  Widget _buildStatusBar(BuildContext context, OcptEditorState state) {
    final tr = Tr.of(context);
    final statistics = state.statistics;

    return OcptWorkspaceStatusBar(
      counters: [
        tr.editorStatsPages(statistics.pageCount),
        tr.editorStatsScenes(statistics.sceneCount),
        tr.editorStatsCharacters(statistics.speakingCharacterCount),
        tr.editorStatsWords(statistics.wordCount),
        tr.editorStatsSigns(statistics.signCount),
      ],
      nonDroppableCount: 3,
      trailingText: OcptEditorSavedTimeSegment.textFor(context, state.lastSavedAt),
      trailing: OcptEditorSavedTimeSegment(lastSavedAt: state.lastSavedAt),
    );
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
    final bloc = context.read<OcptEditorBloc>();
    if (bloc.state.isPreviewingVersion) {
      return;
    }
    bloc.add(OcptEditorSearchOpenedEvent(withReplaceRow: withReplaceRow));
  }

  /// Closes the find/replace bar (Escape).
  void _requestCloseSearch() {
    context.read<OcptEditorBloc>().add(const OcptEditorSearchClosedEvent());
  }

  /// The current find/replace query, built from [state], reused by every raw-mode search
  /// operation ([_syncRawSearch], [_requestRawReplace], [_requestRawReplaceAll]) so none of them
  /// can drift from what the bar itself last reported.
  OcptEditorSearchQuery _rawSearchQueryOf(OcptEditorState state) => OcptEditorSearchQuery(
    query: state.search.query,
    isCaseSensitive: state.search.isCaseSensitive,
    isWholeWord: state.search.isWholeWord,
  );

  /// Recomputes [_textController]'s matches from its own live text whenever the find/replace bar
  /// is open in raw mode, paints them through [_textController]'s own
  /// [OcptEditorSearchTextController.updateMatches], reports the count to the bloc, and navigates
  /// the selection/scroll to the current match when the navigation target actually changed.
  ///
  /// Two separate signatures gate the two side effects this performs, both reset to null whenever
  /// the sync is skipped (see [_lastReportedRawSearchInputs]/[_lastNavigatedRawSearchTarget]'s own
  /// doc comments):
  ///
  /// - [_lastReportedRawSearchInputs] includes the live text, so the report re-runs on every edit
  ///   (a match's own count must track what's actually on screen);
  /// - [_lastNavigatedRawSearchTarget] deliberately does not, so typing inside the raw editor while
  ///   the bar is open never yanks the caret back to "the current match" on every keystroke — only
  ///   an actual navigation (opening the bar, Next/Previous, a query/option change, the current
  ///   match's own index moving because the match count changed) does.
  void _syncRawSearch(OcptEditorState state) {
    if (_liveMode(state) != OcptEditorMode.raw || state.isPreviewingVersion) {
      _lastReportedRawSearchInputs = null;
      _lastNavigatedRawSearchTarget = null;
      return;
    }

    final search = state.search;
    if (!search.isOpen) {
      _textController.updateMatches(const [], null);
      _lastReportedRawSearchInputs = null;
      _lastNavigatedRawSearchTarget = null;
      return;
    }

    final text = _textController.text;
    final matches = _rawSearchQueryOf(state).matchesIn(text);
    _textController.updateMatches(matches, search.currentMatchIndex);

    final reportedInputs = (
      query: search.query,
      isCaseSensitive: search.isCaseSensitive,
      isWholeWord: search.isWholeWord,
      text: text,
    );
    if (reportedInputs != _lastReportedRawSearchInputs) {
      _lastReportedRawSearchInputs = reportedInputs;
      context.read<OcptEditorBloc>().add(
        OcptEditorSearchMatchesReportedEvent(matchCount: matches.length),
      );
    }

    final navigationTarget = (
      query: search.query,
      isCaseSensitive: search.isCaseSensitive,
      isWholeWord: search.isWholeWord,
      currentMatchIndex: search.currentMatchIndex,
    );
    if (navigationTarget != _lastNavigatedRawSearchTarget) {
      _lastNavigatedRawSearchTarget = navigationTarget;
      final currentIndex = search.currentMatchIndex;
      if (currentIndex != null && currentIndex < matches.length) {
        _navigateToMatch(matches[currentIndex]);
      }
    }
  }

  /// Pushes [OcptEditorState.rawSpellCheckRanges] onto [_textController]'s own
  /// [OcptEditorSearchTextController.updateSpellCheckRanges], the raw mode's half of the rule
  /// that each editing surface paints what it shows.
  ///
  /// Guarded exactly the way [_syncRawSearch] opens (raw mode, not previewing a version): the
  /// styled mode is a later slice that addresses each node by id instead, and there is no editing
  /// surface at all under a read-only preview to underline anything in. Both cases clear the
  /// controller's ranges rather than leaving a raw field the user can no longer see holding a stale
  /// set — harmless on its own since nothing repaints it, but exactly the kind of state a mode
  /// switch back to raw should never resurrect uninvited.
  void _syncRawSpellCheck(OcptEditorState state) {
    if (_liveMode(state) != OcptEditorMode.raw || state.isPreviewingVersion) {
      _textController.updateSpellCheckRanges(const []);
      return;
    }

    _textController.updateSpellCheckRanges(state.rawSpellCheckRanges);
  }

  /// Pushes [OcptEditorState.styledSpellCheckRanges] onto [_styledEditorController]'s own
  /// [OcptStyledEditorController.updateSpellCheckRanges], the styled mode's own half of the rule
  /// that each editing surface paints what it shows — the raw mode's own counterpart is
  /// [_syncRawSpellCheck].
  ///
  /// Guarded exactly the way [_syncRawSpellCheck] is (styled mode, not previewing a version): there
  /// is no live styled editor to push anything onto otherwise, and a version preview has no editing
  /// surface at all to underline anything in. Both cases clear the controller's ranges, for the
  /// identical reason [_syncRawSpellCheck]'s own doc comment gives.
  void _syncStyledSpellCheck(OcptEditorState state) {
    if (_liveMode(state) != OcptEditorMode.styled || state.isPreviewingVersion) {
      _styledEditorController.updateSpellCheckRanges(const {});
      return;
    }

    _styledEditorController.updateSpellCheckRanges(state.styledSpellCheckRanges);
  }

  /// Places the raw controller's selection on [match] and scrolls its line into view, the same
  /// estimate [_applyJumpRequest] uses — deliberately does not focus [_editorFocusNode]: the find
  /// field must keep the keyboard focus while the user types a query or presses Next/Previous.
  void _navigateToMatch(OcptTextMatch match) {
    _textController.selection = TextSelection(baseOffset: match.start, extentOffset: match.end);

    if (_editorScrollController.hasClients) {
      final text = _textController.text;
      final clampedOffset = match.start > text.length ? text.length : match.start;
      final line = "\n".allMatches(text.substring(0, clampedOffset)).length;
      final position = _editorScrollController.position;
      const lineHeight = OcptEditorSourceField.fontSize * OcptEditorSourceField.lineHeightFactor;
      final target = (line * lineHeight - position.viewportDimension / 3).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _editorScrollController.jumpTo(target);
    }
  }

  /// Replaces the current match in raw mode with the replacement field's text, then selects
  /// whichever match now starts at or after the end of what was just written — never simply the
  /// match that ends up at the same index, which a replacement that itself still matches the query
  /// (`MARIE` → `MARIE-JEANNE`, the plan's own headline scenario for putting replace in scope)
  /// would land back inside, turning every further `Replace` press into
  /// `MARIE-JEANNE-JEANNE-JEANNE…` forever — see `OcptEditorSearchCurrentMatchSelectedEvent`'s own
  /// doc comment. Wraps to the first remaining match when none starts after the edit; dispatches
  /// nothing at all when none remain, since [_syncRawSearch]'s own reactive report already clears
  /// the index to null the moment it sees the match count drop to 0.
  ///
  /// The replacement itself is an ordinary text edit, applied straight onto [_textController]: the
  /// resulting [OcptEditorTextChangedEvent] flows through the existing reclassify/autosave
  /// debounces with no special case, and [_syncRawSearch] is what turns the edit into a fresh
  /// [OcptEditorSearchMatchesReportedEvent] on its own.
  void _requestRawReplace(OcptEditorState state) {
    final currentIndex = state.search.currentMatchIndex;
    if (currentIndex == null) {
      return;
    }

    final text = _textController.text;
    final query = _rawSearchQueryOf(state);
    final matches = query.matchesIn(text);
    if (currentIndex >= matches.length) {
      return;
    }

    final match = matches[currentIndex];
    final replacement = state.search.replacement;
    final newText = text.replaceRange(match.start, match.end, replacement);
    final writtenEnd = match.start + replacement.length;

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: writtenEnd),
    );

    final newMatches = query.matchesIn(newText);
    if (newMatches.isEmpty) {
      return;
    }
    final nextIndex = newMatches.indexWhere((candidate) => candidate.start >= writtenEnd);
    context.read<OcptEditorBloc>().add(
      OcptEditorSearchCurrentMatchSelectedEvent(index: nextIndex == -1 ? 0 : nextIndex),
    );
  }

  /// Replaces every match in raw mode with the replacement field's text, behind
  /// [OcptConfirmDialog] naming how many matches will be replaced (the repository rule: an
  /// irreversible action is always confirmed by a dialog, never an inline yes/no).
  Future<void> _requestRawReplaceAll(BuildContext context, OcptEditorState state) async {
    final text = _textController.text;
    final matches = _rawSearchQueryOf(state).matchesIn(text);
    if (matches.isEmpty) {
      return;
    }

    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.editorReplaceAllConfirmTitle,
      message: tr.editorReplaceAllConfirmMessage(matches.length),
      cancelLabel: tr.editorReplaceAllConfirmCancelAction,
      confirmLabel: tr.editorReplaceAllConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final replacement = state.search.replacement;
    final buffer = StringBuffer();
    var cursor = 0;
    for (final match in matches) {
      buffer
        ..write(text.substring(cursor, match.start))
        ..write(replacement);
      cursor = match.end;
    }
    buffer.write(text.substring(cursor));

    _textController.value = TextEditingValue(
      text: buffer.toString(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  /// Recomputes and applies the styled mode's own half of the find/replace bar's wiring
  /// (`OcptStyledEditorController.updateSearch`), the counterpart to [_syncRawSearch].
  ///
  /// Unlike [_syncRawSearch], this has nothing to *report*: the styled editor's own delegate
  /// recomputes matches reactively from the live document on every keystroke made inside it (only
  /// it has access to each node's current text) and reports the count itself, through
  /// [_onStyledEditorControllerChanged]. This method's only job is *navigation* — placing the
  /// selection on the current match and scrolling it into view — which it only forwards when
  /// [_lastNavigatedStyledSearchTarget] shows the navigation target actually changed, exactly like
  /// [_syncRawSearch] gates [_navigateToMatch] the same way (so typing elsewhere in the styled
  /// document never yanks the caret back onto "the current match" on every keystroke either).
  void _syncStyledSearch(OcptEditorState state) {
    final isStyledSurfaceLive = _liveMode(state) == OcptEditorMode.styled;
    if (!isStyledSurfaceLive || state.isPreviewingVersion || !state.search.isOpen) {
      if (_lastNavigatedStyledSearchTarget != null) {
        _lastNavigatedStyledSearchTarget = null;
        _lastReportedStyledSearchMatchCount = null;
        _styledEditorController.updateSearch(query: null, currentMatchIndex: null);
      }
      return;
    }

    final search = state.search;
    final navigationTarget = (
      query: search.query,
      isCaseSensitive: search.isCaseSensitive,
      isWholeWord: search.isWholeWord,
      currentMatchIndex: search.currentMatchIndex,
    );
    if (navigationTarget == _lastNavigatedStyledSearchTarget) {
      return;
    }
    _lastNavigatedStyledSearchTarget = navigationTarget;
    _styledEditorController.updateSearch(
      query: OcptEditorSearchQuery(
        query: search.query,
        isCaseSensitive: search.isCaseSensitive,
        isWholeWord: search.isWholeWord,
      ),
      currentMatchIndex: search.currentMatchIndex,
    );
  }

  /// Rebuilds the `⋮` menu's entries when the styled editor gained or lost something to undo or
  /// redo, reports [_styledEditorController]'s own checkable spell-check texts to the bloc whenever
  /// the styled editing surface is actually the live one, then reports its search match count too
  /// — each exactly once per genuine change: the controller notifies its listeners for several
  /// unrelated reasons (a block-type or inline-style read-state refresh, either of the other two),
  /// and [_lastReportedStyledSpellCheckTexts]/[_lastReportedStyledSearchMatchCount] are what keep
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
    final isStyledSurfaceLive = _liveMode(state) == OcptEditorMode.styled && !state.isPreviewingVersion;

    if (isStyledSurfaceLive) {
      final spellCheckTexts = _styledEditorController.spellCheckTextsByNodeId;
      if (!mapEquals(spellCheckTexts, _lastReportedStyledSpellCheckTexts)) {
        _lastReportedStyledSpellCheckTexts = spellCheckTexts;
        bloc.add(OcptEditorStyledSpellCheckTextsReportedEvent(textsByNodeId: spellCheckTexts));
      }
    }

    if (!isStyledSurfaceLive || !state.search.isOpen) {
      return;
    }

    final matchCount = _styledEditorController.searchMatchCount;
    if (matchCount == _lastReportedStyledSearchMatchCount) {
      return;
    }
    _lastReportedStyledSearchMatchCount = matchCount;
    bloc.add(OcptEditorSearchMatchesReportedEvent(matchCount: matchCount));
  }

  /// Replaces the current match in styled mode (`OcptStyledEditorController.replaceCurrentMatch`),
  /// then dispatches [OcptEditorSearchCurrentMatchSelectedEvent] with the index it returns — see
  /// that controller method's own doc comment for why this can't simply keep the previous index,
  /// the same reason [_requestRawReplace] computes its own `nextIndex` by hand. A no-op (dispatches
  /// nothing) when the controller reports there's nothing left to select.
  void _requestStyledReplace(OcptEditorState state) {
    final nextIndex = _styledEditorController.replaceCurrentMatch(state.search.replacement);
    if (nextIndex == null) {
      return;
    }
    context.read<OcptEditorBloc>().add(OcptEditorSearchCurrentMatchSelectedEvent(index: nextIndex));
  }

  /// Replaces every match in styled mode with the replacement field's text, behind
  /// [OcptConfirmDialog] naming how many matches will be replaced — the same repository rule
  /// [_requestRawReplaceAll] follows, reusing the exact same dialog copy so a replace-all reads
  /// identically whichever editing mode triggered it.
  Future<void> _requestStyledReplaceAll(BuildContext context, OcptEditorState state) async {
    final matchCount = _styledEditorController.searchMatchCount;
    if (matchCount == 0) {
      return;
    }

    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.editorReplaceAllConfirmTitle,
      message: tr.editorReplaceAllConfirmMessage(matchCount),
      cancelLabel: tr.editorReplaceAllConfirmCancelAction,
      confirmLabel: tr.editorReplaceAllConfirmAction,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    _styledEditorController.replaceAllMatches(state.search.replacement);
  }

  /// Shows the import confirmation dialog, then dispatches the import request if the user
  /// confirmed the replacement.
  Future<void> _requestImportAndReplace(BuildContext context) async {
    final bloc = context.read<OcptEditorBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.editorImportConfirmTitle,
      message: tr.editorImportConfirmMessage,
      cancelLabel: tr.editorImportConfirmCancelAction,
      confirmLabel: tr.editorImportConfirmReplaceAction,
      isDestructive: false,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptEditorImportRequestedEvent(fileTypeLabel: Tr.of(context).editorImportFileTypeLabel),
    );
  }

  /// Shows the page setup dialog, then dispatches the new page setup if the user applied it.
  Future<void> _requestPageSetup(BuildContext context) async {
    final bloc = context.read<OcptEditorBloc>();
    final setup = await OcptEditorPageSetupDialog.show(context, current: bloc.state.pageSetup);
    if (setup == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptEditorPageSetupChangedEvent(pageSetup: setup));
  }

  /// Opens the project settings page, then reloads the page format (and repaginates) if the user
  /// changed anything there.
  ///
  /// Also tells `OcptWorkspaceBloc` to reload its episodes: the settings page's own `Episodes`
  /// card can add or delete one, which the workspace bloc otherwise only learns about from
  /// `OcptProjectsManager.currentProjectStream`, an event the episode CRUD does not fire.
  ///
  /// [reveal] names the card the page opens on, for the toolbar's `Add an episode…` button which
  /// promised one; the toolbar's plain settings action passes none and lands at the top.
  Future<void> _requestProjectSettings(
    BuildContext context, {
    OcptProjectSettingsReveal? reveal,
  }) async {
    final bloc = context.read<OcptEditorBloc>();
    final workspaceBloc = context.read<OcptWorkspaceBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
      extra: reveal,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptEditorProjectSettingsChangedEvent());
    workspaceBloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
  }

  /// Builds the two entries the toolbar's `Export` button offers: the screenplay's own Fountain
  /// source and the typeset PDF. Both are always available — see `OcptEditorExportDocument`'s own
  /// doc comment.
  List<OcptWorkspaceExportEntry<OcptEditorExportDocument>> _buildExportEntries(
    BuildContext context,
  ) {
    final tr = Tr.of(context);

    return [
      OcptWorkspaceExportEntry<OcptEditorExportDocument>(
        value: OcptEditorExportDocument.fountain,
        title: tr.editorExportFountainTitle,
        description: tr.editorExportFountainDescription,
        formatLabel: ".fountain",
      ),
      OcptWorkspaceExportEntry<OcptEditorExportDocument>(
        value: OcptEditorExportDocument.pdf,
        title: tr.editorExportPdfTitle,
        description: tr.editorExportPdfDescription,
        formatLabel: "PDF",
      ),
    ];
  }

  /// Opens the export panel, then dispatches the picked document's own request: the `.fountain`
  /// export event directly (it opens no options dialog of its own), or [_requestExportPdf], which
  /// opens the PDF export options dialog exactly as it always has.
  Future<void> _requestExport(BuildContext context, Rect? shareAnchor) async {
    final tr = Tr.of(context);
    final picked = await OcptWorkspaceExportDialog.show<OcptEditorExportDocument>(
      context,
      title: tr.editorExportPanelTitle,
      message: tr.editorExportPanelMessage,
      entries: _buildExportEntries(context),
      isPreviewingVersion: context.read<OcptEditorBloc>().state.isPreviewingVersion,
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    switch (picked) {
      case OcptWorkspaceExportDocumentPick<OcptEditorExportDocument>(:final document):
        switch (document) {
          case OcptEditorExportDocument.fountain:
            context.read<OcptEditorBloc>().add(
              OcptEditorExportRequestedEvent(
                fileTypeLabel: tr.editorImportFileTypeLabel,
                episodeTag: _episodeExportTag(context),
                shareAnchor: shareAnchor,
              ),
            );
          case OcptEditorExportDocument.pdf:
            await _requestExportPdf(context, shareAnchor);
        }
      case OcptWorkspaceExportProjectPackagePick<OcptEditorExportDocument>():
        _requestProjectPackageExport(context);
    }
  }

  /// Shows the PDF export options dialog, then dispatches the export request if the user applied
  /// it.
  Future<void> _requestExportPdf(BuildContext context, Rect? shareAnchor) async {
    final bloc = context.read<OcptEditorBloc>();
    final options = await OcptEditorExportPdfOptionsDialog.show(context, current: bloc.state.pageSetup);
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptEditorExportPdfRequestedEvent(
        options: options,
        fileTypeLabel: Tr.of(context).editorExportPdfFileTypeLabel,
        episodeTag: _episodeExportTag(context),
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// The selected episode's own tag (`ep. 2`), or null while the open project holds one episode or
  /// none — read here, the last place with a [BuildContext] before an export event is dispatched,
  /// exactly as every other localized export payload already is.
  String? _episodeExportTag(BuildContext context) {
    final workspaceState = context.read<OcptWorkspaceBloc>().state;
    return ocptWorkspaceEpisodeExportTagOf(
      context: context,
      episodes: workspaceState.episodes,
      selectedEpisodeId: workspaceState.selectedEpisodeId,
    );
  }

  /// Shows the title page dialog, then dispatches the edited fields if the user applied them.
  Future<void> _requestTitlePage(BuildContext context) async {
    final bloc = context.read<OcptEditorBloc>();
    final fields = await OcptEditorTitlePageDialog.show(
      context,
      current: bloc.state.document?.titlePage,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptEditorTitlePageChangedEvent(
        title: fields.title,
        credit: fields.credit,
        author: fields.author,
        draftDate: fields.draftDate,
        contact: fields.contact,
        source: fields.source,
      ),
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
        _textController.selection = previousSelection.isValid && previousSelection.end <= state.text.length
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
        _applyJumpRequest(jumpRequest.charOffset);
      }
    }

    _syncRawSearch(state);
    _syncStyledSearch(state);
    _syncRawSpellCheck(state);
    _syncStyledSpellCheck(state);

    if (state.hasSaveError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).editorSaveError)));
      context.read<OcptEditorBloc>().add(const OcptEditorSaveErrorDismissedEvent());
    }

    final ioNotice = state.ioNotice;
    if (ioNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_ioNoticeMessage(context, ioNotice))));
      context.read<OcptEditorBloc>().add(const OcptEditorIoNoticeDismissedEvent());
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
      context.read<OcptEditorBloc>().add(
        const OcptProjectPackageMissingFilesAskDismissedEvent(),
      );
      unawaited(_askAboutMissingPackagedFiles(context, packagePendingExport));
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

  /// Dispatches the project package export, resolving here — the last place with a
  /// [BuildContext] — the label the native save dialog carries.
  ///
  /// What happens next depends on what the project references: everything being there, the save
  /// dialog opens straight away; anything missing, the bloc asks back through its own state and
  /// [_askAboutMissingPackagedFiles] is what puts that question on screen.
  void _requestProjectPackageExport(BuildContext context) {
    context.read<OcptEditorBloc>().add(
      OcptProjectPackageExportRequestedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }

  /// Asks whether to write the package even though some referenced files are gone, then dispatches
  /// the export if the user said to go on.
  ///
  /// Opened from the bloc's state rather than from the panel's own click, since only the bloc can
  /// read the project file the pre-flight scanned. The question is cleared from that state the
  /// moment this opens, so a later emission never stacks a second dialog behind this one.
  Future<void> _askAboutMissingPackagedFiles(
    BuildContext context,
    OcptProjectPackagePreflight preflight,
  ) async {
    final bloc = context.read<OcptEditorBloc>();
    final confirmed = await ocptAskAboutMissingPackagedFiles(context, preflight);
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptProjectPackageExportConfirmedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }

  /// Maps [notice] to its localized, user-facing message.
  ///
  /// A succeeded export kind degrades to the generic "shared" message on mobile
  /// ([OcptEditorIoNotice.wasShared]): there is no path to name, the export having been handed to
  /// the OS share sheet rather than written to a location the user picked.
  String _ioNoticeMessage(BuildContext context, OcptEditorIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptEditorIoNoticeKind.exportSucceeded => notice.wasShared
          ? tr.exportSharedMessage
          : tr.editorExportSuccessMessage(notice.path ?? ""),
      OcptEditorIoNoticeKind.exportFailed => tr.editorExportError,
      OcptEditorIoNoticeKind.importSucceeded => tr.editorImportSuccessMessage,
      OcptEditorIoNoticeKind.importFailed => tr.editorImportError,
      OcptEditorIoNoticeKind.importUnreadable => tr.editorImportUnreadableError,
      OcptEditorIoNoticeKind.pdfExportSucceeded => notice.wasShared
          ? tr.exportSharedMessage
          : tr.editorExportPdfSuccessMessage(notice.path ?? ""),
      OcptEditorIoNoticeKind.pdfExportFailed => tr.editorExportPdfError,
    };
  }

  /// Moves the editor caret to [charOffset], focuses the editor, scrolls the caret's line into
  /// view, and lets the controller listener report the caret move to the bloc.
  ///
  /// The scroll target is estimated from the caret's line number and the editor's fixed line
  /// height, which is exact for unwrapped lines and close enough when long lines wrap.
  void _applyJumpRequest(int charOffset) {
    final text = _textController.text;
    final clampedOffset = charOffset > text.length ? text.length : charOffset;

    _textController.selection = TextSelection.collapsed(offset: clampedOffset);
    _editorFocusNode.requestFocus();

    if (_editorScrollController.hasClients) {
      final line = "\n".allMatches(text.substring(0, clampedOffset)).length;
      final position = _editorScrollController.position;
      const lineHeight = OcptEditorSourceField.fontSize * OcptEditorSourceField.lineHeightFactor;
      final target = (line * lineHeight - position.viewportDimension / 3).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _editorScrollController.jumpTo(target);
    }
  }
}
