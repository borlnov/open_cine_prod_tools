// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_note_matches.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_highlight_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_note_text_input_formatter.dart';

/// The multiline field in which the text of the selected note is edited, in its card.
///
/// It takes the focus when it appears (unless [takesFocus] says it must not), and grows with its text. Every change is reported as soon
/// as it is made, written the way the Fountain source holds it (a line left empty is two spaces),
/// and the field follows [text] when it changes from elsewhere. It asks for what its keys mean
/// instead of doing it: Enter and Escape give the focus back to the text, Shift+Enter breaks the
/// line, and Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y act on the history of the editor, never on the one of
/// the field.
class OcptNoteCardField extends StatefulWidget {
  /// The text of the note, which the field shows.
  final String text;

  /// The text shown while the field is empty.
  final String hint;

  /// The style of the text, and of the hint.
  final TextStyle? style;

  /// Called with the text of the note, as Fountain holds it, when the writer changed it.
  final ValueChanged<String> onChanged;

  /// Called when the writer is done and the focus belongs back to the text.
  final VoidCallback onLeaveRequested;

  /// Called when the writer asked to undo.
  final VoidCallback onUndoRequested;

  /// Called when the writer asked to redo.
  final VoidCallback onRedoRequested;

  /// Called when the field lost the focus it had.
  final VoidCallback onFocusLost;

  /// Whether the note may hold a blank line: see [OcptNoteTextInputFormatter.normalised].
  final bool allowsBlankLines;

  /// The matches of the find/replace query inside the text, painted over it, or null for none.
  final OcptNoteMatches? matches;

  /// Whether the field takes the focus when it appears.
  final bool takesFocus;

  /// Class constructor.
  const OcptNoteCardField({
    super.key,
    required this.text,
    required this.hint,
    required this.style,
    required this.onChanged,
    required this.onLeaveRequested,
    required this.onUndoRequested,
    required this.onRedoRequested,
    required this.onFocusLost,
    this.allowsBlankLines = true,
    this.matches,
    this.takesFocus = true,
  });

  /// Create the [_OcptNoteCardFieldState] holding the controller and the focus of the field.
  @override
  State<OcptNoteCardField> createState() => _OcptNoteCardFieldState();
}

/// The state of [OcptNoteCardField]: the text controller, the focus, and the keys of the field.
class _OcptNoteCardFieldState extends State<OcptNoteCardField> {
  /// Holds the text being edited, the caret starting at its end.
  late final OcptNoteHighlightController _controller = OcptNoteHighlightController(
    value: TextEditingValue(
      text: widget.text,
      selection: TextSelection.collapsed(offset: widget.text.length),
    ),
  )..matches = widget.matches;

  /// The focus of the field.
  final FocusNode _focusNode = FocusNode();

  /// Whether the field had the focus at the last change of it.
  bool _hadFocus = false;

  /// Listen to the focus, and take it once the first frame is out.
  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    if (widget.takesFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  /// Show [OcptNoteCardField.text] again when it is no longer what the field holds, which is the
  /// case when the note changed from elsewhere (an undo, a redo).
  @override
  void didUpdateWidget(covariant OcptNoteCardField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.matches = widget.matches;
    if (widget.text != _normalised(_controller.text)) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  /// Build the field.
  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: _onKeyEvent,
    child: TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: widget.style,
      minLines: 1,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      inputFormatters: const [OcptNoteTextInputFormatter()],
      decoration: InputDecoration.collapsed(hintText: widget.hint),
      onChanged: _report,
    ),
  );

  /// Report that the field lost the focus it had.
  void _onFocusChanged() {
    final hasFocus = _focusNode.hasFocus;
    if (!hasFocus && _hadFocus) {
      widget.onFocusLost();
    }
    _hadFocus = hasFocus;
  }

  /// Report the text the field now holds.
  void _report(String text) => widget.onChanged(_normalised(text));

  /// Get [text] as the note writes it.
  String _normalised(String text) =>
      OcptNoteTextInputFormatter.normalised(text, allowsBlankLines: widget.allowsBlankLines);

  /// Handle the keys the field gives another meaning to, and let the others through.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      if (key == LogicalKeyboardKey.keyZ) {
        keyboard.isShiftPressed ? widget.onRedoRequested() : widget.onUndoRequested();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyY) {
        widget.onRedoRequested();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.escape) {
      widget.onLeaveRequested();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (keyboard.isShiftPressed) {
        _insertNewline();
      } else {
        widget.onLeaveRequested();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Replace the selection of the field with a line break, the way the keyboard would.
  void _insertNewline() {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final edited = TextEditingValue(
      text: value.text.replaceRange(start, end, "\n"),
      selection: TextSelection.collapsed(offset: start + 1),
    );
    final formatted = const OcptNoteTextInputFormatter().formatEditUpdate(value, edited);
    if (formatted != value) {
      _controller.value = formatted;
      _report(formatted.text);
    }
  }

  /// Stop listening to the focus, then release the controller and the focus node.
  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}
