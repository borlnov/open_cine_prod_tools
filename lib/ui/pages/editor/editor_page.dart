// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_toolbar.dart';

/// The screenplay editor: the raw Fountain source in the center, the collapsible scene panel on
/// the left, the formatted paper preview on the right, and a thin toolbar above them.
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

  /// Whether the loaded screenplay text was already applied to [_textController].
  bool _hasAppliedInitialText = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
      SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
    },
    child: Actions(
      actions: {
        _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (intent) => _requestManualSave()),
      },
      child: Scaffold(
        body: BlocConsumer<OcptEditorBloc, OcptEditorState>(
          listener: _onStateChanged,
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                OcptEditorToolbar(
                  title: state.title,
                  isDirty: state.isDirty,
                  isSaving: state.isSaving,
                  isScenePanelVisible: state.isScenePanelVisible,
                  isPreviewVisible: state.isPreviewVisible,
                  onSave: _requestManualSave,
                  onToggleScenePanel: () => context.read<OcptEditorBloc>().add(
                    const OcptEditorScenePanelToggledEvent(),
                  ),
                  onTogglePreview: () => context.read<OcptEditorBloc>().add(
                    const OcptEditorPreviewToggledEvent(),
                  ),
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
                        child: OcptEditorSourceField(
                          controller: _textController,
                          scrollController: _editorScrollController,
                          focusNode: _editorFocusNode,
                        ),
                      ),
                      if (state.isPreviewVisible)
                        Expanded(
                          flex: 6,
                          child: OcptEditorPreview(
                            document: state.document,
                            pageFormat: state.pageFormat,
                            currentLine: state.currentLine,
                          ),
                        ),
                    ],
                  ),
                ),
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

  /// Applies bloc-driven effects onto the page: the initial text, scene jump requests, and the
  /// transient save error SnackBar.
  void _onStateChanged(BuildContext context, OcptEditorState state) {
    if (!state.isLoading && !_hasAppliedInitialText) {
      _hasAppliedInitialText = true;
      _isApplyingProgrammaticChange = true;
      try {
        _textController.text = state.text;
        _textController.selection = const TextSelection.collapsed(offset: 0);
        _lastReportedText = state.text;
      } finally {
        _isApplyingProgrammaticChange = false;
      }
    }

    final jumpRequest = state.jumpRequest;
    if (jumpRequest != null && jumpRequest.id != _lastAppliedJumpRequestId) {
      _lastAppliedJumpRequestId = jumpRequest.id;
      _applyJumpRequest(jumpRequest.charOffset);
    }

    if (state.hasSaveError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).editorSaveError)));
      context.read<OcptEditorBloc>().add(const OcptEditorSaveErrorDismissedEvent());
    }
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
