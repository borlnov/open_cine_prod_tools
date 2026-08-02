// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_format_controls.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_import_confirm_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_metadata_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_page_setup_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_saved_time_segment.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_title_page_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_versions_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_version_create_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_project_versions_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_notice_message.dart';

/// The screenplay editor: either the styled block editor or the raw Fountain source in the
/// center (depending on the persisted `OcptEditorMode`), the collapsible scene panel on the left,
/// the tabbed right dock (formatted preview, raw mode only; the Fountain syntax guide, the scene
/// inspector and the read-only metadata panel, all three in both modes) hosting at most one panel
/// at a time, and a thin toolbar above them.
///
/// The `OcptRouterManager` editor guard guarantees a project is open when this page is reached.
class EditorPage extends StatelessWidget {
  /// Creates the editor page.
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptEditorBloc(), child: const _EditorView());
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
  final TextEditingController _textController = TextEditingController();

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

  /// Whether [_onTextControllerChanged] must ignore notifications, used while applying the
  /// loaded text programmatically to [_textController] (so it doesn't loop back into the bloc
  /// as a user edit).
  bool _isApplyingProgrammaticChange = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextControllerChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _editorScrollController.dispose();
    _editorFocusNode.dispose();
    _styledEditorController.dispose();
    _dockLayoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
      SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
      SingleActivator(LogicalKeyboardKey.keyM, control: true, shift: true): _ModeToggleIntent(),
      SingleActivator(LogicalKeyboardKey.keyM, meta: true, shift: true): _ModeToggleIntent(),
    },
    child: Actions(
      actions: {
        _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (intent) => _requestManualSave()),
        _ModeToggleIntent: CallbackAction<_ModeToggleIntent>(onInvoke: (intent) => _toggleMode()),
      },
      child: Scaffold(
        body: BlocConsumer<OcptEditorBloc, OcptEditorState>(
          listener: _onStateChanged,
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final isRawMode = state.mode == OcptEditorMode.raw;

            return OcptWorkspaceShell(
              title: state.title,
              isDirty: state.isDirty,
              onBack: () => context.read<OcptEditorBloc>().add(
                const OcptEditorBackRequestedEvent(),
              ),
              toolbarActions: _buildToolbarActions(context, state, isRawMode: isRawMode),
              modeLabel: Tr.of(context).workspaceModeLabelScreenplay,
              overflowEntries: _buildOverflowEntries(context, state),
              isLeftDockOpen: state.isScenePanelVisible,
              onToggleLeftDock: () => context.read<OcptEditorBloc>().add(
                const OcptEditorScenePanelToggledEvent(),
              ),
              isRightDockOpen: state.rightDockTab != null,
              onToggleRightDock: () => context.read<OcptEditorBloc>().add(
                const OcptEditorRightDockToggledEvent(),
              ),
              onSave: _requestManualSave,
              isSaving: state.isSaving,
              leftPanel: _buildScenePanel(context, state),
              rightPanel: _buildRightDock(context, state, isRawMode: isRawMode),
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

  /// Builds the screenplay's own toolbar controls, right-aligned before the chrome the shell
  /// builds itself (the mode label, the dock toggles, the save action and the overflow menu): the
  /// block-type/format controls (rendered only while attached to a live styled editor), the right
  /// dock's preview and syntax tab selectors, and the styled/raw mode toggle.
  ///
  /// Both tab selectors are raw-mode only: the styled mode has no preview tab at all, and its own
  /// layout leaves the syntax guide reachable through the dock's tab row alone, which keeps the
  /// toolbar from carrying a shortcut to a tab the mode barely uses.
  List<Widget> _buildToolbarActions(
    BuildContext context,
    OcptEditorState state, {
    required bool isRawMode,
  }) {
    final tr = Tr.of(context);

    return [
      OcptEditorFormatControls(controller: _styledEditorController),
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
      IconButton(
        icon: Icon(state.mode == OcptEditorMode.styled ? Icons.code : Icons.style, size: 20),
        tooltip: state.mode == OcptEditorMode.styled
            ? tr.editorSwitchToRawModeTooltip
            : tr.editorSwitchToStyledModeTooltip,
        onPressed: _toggleMode,
      ),
    ];
  }

  /// Builds the screenplay's `⋮` overflow menu entries: export, export to PDF, import and
  /// replace, the page-simulation and scene-numbers toggles, page setup, title page, and resetting
  /// the panel layout.
  List<PopupMenuEntry<void>> _buildOverflowEntries(BuildContext context, OcptEditorState state) {
    final tr = Tr.of(context);

    return [
      PopupMenuItem<void>(
        onTap: () => context.read<OcptEditorBloc>().add(
          OcptEditorExportRequestedEvent(fileTypeLabel: tr.editorImportFileTypeLabel),
        ),
        child: Text(tr.editorExportAction),
      ),
      PopupMenuItem<void>(
        onTap: () => _requestExportPdf(context),
        child: Text(tr.editorExportPdfAction),
      ),
      PopupMenuItem<void>(
        onTap: () => _requestImportAndReplace(context),
        child: Text(tr.editorImportAndReplaceAction),
      ),
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
      PopupMenuItem<void>(
        onTap: () => _requestPageSetup(context),
        child: Text(tr.editorPageSetupAction),
      ),
      PopupMenuItem<void>(
        onTap: () => _requestTitlePage(context),
        child: Text(tr.editorTitlePageAction),
      ),
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

  /// Builds the editor itself (raw source field or styled block editor), the shell's `centre`.
  Widget _buildCentre(BuildContext context, OcptEditorState state, {required bool isRawMode}) =>
      isRawMode
      ? OcptEditorSourceField(
          controller: _textController,
          scrollController: _editorScrollController,
          focusNode: _editorFocusNode,
        )
      : OcptStyledScreenplayEditor(
          text: state.text,
          pageSetup: state.pageSetup,
          isPageSimulationEnabled: state.isPageSimulationEnabled,
          areSceneNumbersVisible: state.areStyledSceneNumbersVisible,
          onTextChanged: (text) => context.read<OcptEditorBloc>().add(
            OcptEditorTextChangedEvent(text: text),
          ),
          onCaretLineChanged: (line) => context.read<OcptEditorBloc>().add(
            OcptEditorCaretMovedEvent(line: line),
          ),
          jumpRequest: state.jumpRequest,
          styledController: _styledEditorController,
        );

  /// Builds the tabbed right dock (formatted preview, raw mode only; the Fountain syntax guide,
  /// the scene inspector and the read-only metadata panel, all three in both modes), the shell's
  /// `rightPanel`, or null while the dock is closed.
  Widget? _buildRightDock(BuildContext context, OcptEditorState state, {required bool isRawMode}) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return null;
    }

    final previewChild = isRawMode && rightDockTab == OcptEditorRightDockTab.preview
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
      isPreviewTabAvailable: isRawMode,
      previewChild: previewChild,
      inspectorChild: OcptEditorInspectorPanel(
        scene: currentSceneIndex == null ? null : state.scenes[currentSceneIndex],
        sceneOrdinal: currentSceneIndex == null ? null : currentSceneIndex + 1,
        statistics: state.sceneStatistics,
      ),
      metadataChild: OcptEditorMetadataPanel(
        titlePage: state.document?.titlePage,
        statistics: state.statistics,
        onEditTitlePage: () => _requestTitlePage(context),
      ),
      versionsChild: _buildVersionsPanel(context, state),
      onTabSelected: (tab) => context.read<OcptEditorBloc>().add(
        OcptEditorRightDockTabSelectedEvent(tab: tab),
      ),
      onClose: () => context.read<OcptEditorBloc>().add(const OcptEditorRightDockClosedEvent()),
    );
  }

  /// Builds the right dock's `Versions` tab: the project's named versions, the same panel every
  /// production mode's dock hosts, wired to the events `MixinOcptProjectVersionsBloc` handles.
  ///
  /// `Create a version` is disabled while one is being previewed: the capture reads the project
  /// file, so it would record a state the user isn't looking at.
  Widget _buildVersionsPanel(BuildContext context, OcptEditorState state) =>
      OcptProjectVersionsPanel(
        versions: state.projectVersions,
        previewedVersionId: state.previewedVersionId,
        versionPendingDeletionId: state.versionPendingDeletionId,
        onCreateRequested: state.isPreviewingVersion
            ? null
            : () => _requestVersionCreation(context),
        onPreviewRequested: (versionId) => context.read<OcptEditorBloc>().add(
          OcptProjectVersionPreviewRequestedEvent(versionId: versionId),
        ),
        onPreviewExitRequested: () => context.read<OcptEditorBloc>().add(
          const OcptProjectVersionPreviewExitRequestedEvent(),
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

  /// Shows the import confirmation dialog, then dispatches the import request if the user
  /// confirmed the replacement.
  Future<void> _requestImportAndReplace(BuildContext context) async {
    final bloc = context.read<OcptEditorBloc>();
    final confirmed = await OcptEditorImportConfirmDialog.show(context);
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

  /// Shows the PDF export options dialog, then dispatches the export request if the user applied
  /// it.
  Future<void> _requestExportPdf(BuildContext context) async {
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
      ),
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
    if (state.mode == OcptEditorMode.raw) {
      final jumpRequest = state.jumpRequest;
      if (jumpRequest != null && jumpRequest.id != _lastAppliedJumpRequestId) {
        _lastAppliedJumpRequestId = jumpRequest.id;
        _applyJumpRequest(jumpRequest.charOffset);
      }
    }

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
  }

  /// Maps [notice] to its localized, user-facing message.
  String _ioNoticeMessage(BuildContext context, OcptEditorIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptEditorIoNoticeKind.exportSucceeded => tr.editorExportSuccessMessage(notice.path ?? ""),
      OcptEditorIoNoticeKind.exportFailed => tr.editorExportError,
      OcptEditorIoNoticeKind.importSucceeded => tr.editorImportSuccessMessage,
      OcptEditorIoNoticeKind.importFailed => tr.editorImportError,
      OcptEditorIoNoticeKind.pdfExportSucceeded => tr.editorExportPdfSuccessMessage(
        notice.path ?? "",
      ),
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
