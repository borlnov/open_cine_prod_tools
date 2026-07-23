// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_import_confirm_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_page_setup_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_status_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_title_page_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_toolbar.dart';

/// The screenplay editor: either the styled block editor or the raw Fountain source in the
/// center (depending on the persisted `OcptEditorMode`), the collapsible scene panel on the left,
/// the formatted paper preview on the right (raw mode only: the styled mode's own layout already
/// is the formatted screenplay), and a thin toolbar above them.
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

            return Column(
              children: [
                OcptEditorToolbar(
                  title: state.title,
                  isDirty: state.isDirty,
                  isSaving: state.isSaving,
                  isScenePanelVisible: state.isScenePanelVisible,
                  isPreviewVisible: state.isPreviewVisible,
                  isPageSimulationEnabled: state.isPageSimulationEnabled,
                  mode: state.mode,
                  onBack: () => context.read<OcptEditorBloc>().add(
                    const OcptEditorBackRequestedEvent(),
                  ),
                  onSave: _requestManualSave,
                  onToggleScenePanel: () => context.read<OcptEditorBloc>().add(
                    const OcptEditorScenePanelToggledEvent(),
                  ),
                  onTogglePreview: () => context.read<OcptEditorBloc>().add(
                    const OcptEditorPreviewToggledEvent(),
                  ),
                  onToggleMode: _toggleMode,
                  onExport: () => context.read<OcptEditorBloc>().add(
                    const OcptEditorExportRequestedEvent(),
                  ),
                  onExportPdf: () => _requestExportPdf(context),
                  onImportAndReplace: () => _requestImportAndReplace(context),
                  onTogglePageSimulation: () => context.read<OcptEditorBloc>().add(
                    const OcptEditorPageSimulationToggledEvent(),
                  ),
                  onPageSetup: () => _requestPageSetup(context),
                  onTitlePage: () => _requestTitlePage(context),
                  styledController: _styledEditorController,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.isScenePanelVisible)
                        OcptEditorScenePanel(
                          scenes: state.scenes,
                          currentLine: state.currentLine,
                          onSceneSelected: (charOffset) => context.read<OcptEditorBloc>().add(
                            OcptEditorSceneJumpRequestedEvent(charOffset: charOffset),
                          ),
                        ),
                      Expanded(
                        flex: 5,
                        child: isRawMode
                            ? OcptEditorSourceField(
                                controller: _textController,
                                scrollController: _editorScrollController,
                                focusNode: _editorFocusNode,
                              )
                            : OcptStyledScreenplayEditor(
                                text: state.text,
                                pageSetup: state.pageSetup,
                                isPageSimulationEnabled: state.isPageSimulationEnabled,
                                onTextChanged: (text) => context.read<OcptEditorBloc>().add(
                                  OcptEditorTextChangedEvent(text: text),
                                ),
                                onCaretLineChanged: (line) => context.read<OcptEditorBloc>().add(
                                  OcptEditorCaretMovedEvent(line: line),
                                ),
                                jumpRequest: state.jumpRequest,
                                styledController: _styledEditorController,
                              ),
                      ),
                      if (isRawMode && state.isPreviewVisible)
                        Expanded(
                          flex: 6,
                          child: OcptEditorPreview(
                            document: state.document,
                            pageSetup: state.pageSetup,
                            currentLine: state.currentLine,
                            isPageSimulationEnabled: state.isPageSimulationEnabled,
                          ),
                        ),
                    ],
                  ),
                ),
                OcptEditorStatusBar(statistics: state.statistics, lastSavedAt: state.lastSavedAt),
              ],
            );
          },
        ),
      ),
    ),
  );

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

    bloc.add(OcptEditorExportPdfRequestedEvent(options: options));
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
  /// mode), scene jump requests, and the transient save error SnackBar.
  ///
  /// The styled editor is handed [OcptEditorState.text] directly as a widget property and syncs
  /// itself (see `OcptStyledScreenplayEditor`); only the raw controller needs this imperative
  /// nudge, since it's a plain [TextEditingController] rather than something driven by `build`.
  void _onStateChanged(BuildContext context, OcptEditorState state) {
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
