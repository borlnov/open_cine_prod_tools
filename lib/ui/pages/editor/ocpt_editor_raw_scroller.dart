// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_text_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_text_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';

/// Moves the caret of the raw source field and scrolls it into view: a scene jump, or the match the
/// find bar is on.
class OcptEditorRawScroller {
  /// The controller holding the live source text and selection.
  final OcptEditorSearchTextController _textController;

  /// The controller of the editor's vertical scroll.
  final ScrollController _editorScrollController;

  /// The editor's focus node, focused back when jumping to a scene.
  final FocusNode _editorFocusNode;

  /// Class constructor
  OcptEditorRawScroller({
    required OcptEditorSearchTextController textController,
    required ScrollController editorScrollController,
    required FocusNode editorFocusNode,
  }) : _textController = textController,
       _editorScrollController = editorScrollController,
       _editorFocusNode = editorFocusNode;

  /// Places the raw controller's selection on [match] and scrolls it into view exactly as
  /// [applyJumpRequest] does ([scrollTo]) — deliberately does not focus
  /// [_editorFocusNode]: the find field must keep the keyboard focus while the user types a query
  /// or presses Next/Previous.
  void navigateToMatch(OcptTextMatch match) {
    _textController.selection = TextSelection(baseOffset: match.start, extentOffset: match.end);
    scrollTo(match.start);
  }

  /// Moves the editor caret to [charOffset], focuses the editor, scrolls the caret's line into view
  /// ([scrollTo]), and lets the controller listener report the caret move to the bloc.
  void applyJumpRequest(int charOffset) {
    final text = _textController.text;
    final clampedOffset = charOffset > text.length ? text.length : charOffset;

    _textController.selection = TextSelection.collapsed(offset: clampedOffset);
    _editorFocusNode.requestFocus();
    scrollTo(clampedOffset);
  }

  /// Scrolls the raw editor so the line holding [offset] sits a third of the way down its viewport.
  ///
  /// The line's position is **measured** off the field's own laid-out text
  /// ([_rawCaretContentTop]) rather than counted in newlines: an action or dialogue paragraph wraps
  /// over several visual lines, and a newline count drifts further from the truth with every one
  /// of them the target sits past. Landing the caret well inside the viewport also leaves the
  /// field's own caret-reveal scroll, which runs after a selection change, nothing to correct. The
  /// newline estimate remains only as the fallback for a field not laid out yet.
  void scrollTo(int offset) {
    if (!_editorScrollController.hasClients) {
      return;
    }

    final position = _editorScrollController.position;
    final lineTop = _rawCaretContentTop(offset) ?? _estimatedRawLineTop(offset);
    final target = (lineTop - position.viewportDimension / 3).clamp(0.0, position.maxScrollExtent);
    _editorScrollController.jumpTo(target);
  }

  /// The top of the caret at [offset] in the raw field's own scrollable content, read off the
  /// field's `RenderEditable` — or null while the field is not built or laid out.
  ///
  /// [_editorFocusNode] is attached inside the field's own `EditableText`, which is how the
  /// `EditableTextState` (and through it the render object) is reached without a key of its own.
  /// `getLocalRectForCaret` answers in the render object's own coordinates, already shifted by the
  /// current scroll offset, so that offset is added back.
  double? _rawCaretContentTop(int offset) {
    final editableText = _editorFocusNode.context?.findAncestorStateOfType<EditableTextState>();
    if (editableText == null || !editableText.mounted) {
      return null;
    }

    final renderEditable = editableText.renderEditable;
    if (!renderEditable.hasSize) {
      return null;
    }

    final caretRect = renderEditable.getLocalRectForCaret(TextPosition(offset: offset));
    return caretRect.top + _editorScrollController.offset;
  }

  /// The top of the line holding [offset], estimated from its newline count and the field's fixed
  /// line height: exact for unwrapped lines only — [_rawCaretContentTop]'s fallback.
  double _estimatedRawLineTop(int offset) {
    final text = _textController.text;
    final clampedOffset = offset > text.length ? text.length : offset;
    final line = "\n".allMatches(text.substring(0, clampedOffset)).length;
    const lineHeight = OcptEditorSourceField.fontSize * OcptEditorSourceField.lineHeightFactor;

    return line * lineHeight;
  }
}
