// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart';
import 'package:super_editor/super_editor.dart';

/// The pure half of the styled editor's "Insert note" and "Remove note" commands: from a document
/// and a selection, resolve which block and which character range a command targets, and build
/// the requests carrying it out. Nothing here touches an editor or a widget, so the right-click
/// menu handler only asks whether a command applies (a null answer withholds its entry) and
/// executes the requests it gets back in one [Editor.execute] call, which is one undo step.
final class OcptFountainNoteActions {
  /// Private constructor: this class only exposes static members.
  const OcptFountainNoteActions._();

  /// Get the requests inserting a note at [selection] of [document], or null when the command is
  /// withheld.
  ///
  /// A collapsed caret gets an empty `[[]]` with the caret left between the brackets; a selection
  /// inside one block is wrapped in `[[` ... `]]` with the caret left just before the closing
  /// brackets. It is withheld when there is no selection, when the selection spans several blocks
  /// or sits on anything but a body paragraph (a title-page field, a page break), and when it
  /// touches an existing note, since notes never nest.
  static List<EditRequest>? insertRequests(Document document, DocumentSelection? selection) {
    final target = _target(document, selection);
    if (target == null) {
      return null;
    }

    final text = target.node.text;
    final plainText = text.toPlainText();
    final touchesNote = OcptWysiwygInlineRuns.noteRanges(plainText).any(
      (range) => target.start == target.end
          ? target.start > range.$1 && target.start < range.$2
          : target.start < range.$2 && target.end > range.$1,
    );
    if (touchesNote) {
      return null;
    }

    final wrapped = text
        .copyText(0, target.start)
        .copyAndAppend(AttributedText("[["))
        .copyAndAppend(text.copyText(target.start, target.end))
        .copyAndAppend(AttributedText("]]"))
        .copyAndAppend(text.copyText(target.end));
    final caretOffset = target.end + 2;

    return [
      OcptReplaceNodeTextRequest(nodeId: target.node.id, text: wrapped),
      _caretRequest(target.node.id, caretOffset),
    ];
  }

  /// Get the requests removing the note [selection] of [document] lies in, or null when the
  /// command is withheld: no selection, a selection over several blocks, or a caret or selection
  /// not wholly inside one `[[...]]` range of its block.
  ///
  /// The whole range goes, brackets and content, and the caret lands where the note started.
  static List<EditRequest>? removeRequests(Document document, DocumentSelection? selection) {
    final target = _target(document, selection);
    if (target == null) {
      return null;
    }

    final text = target.node.text;
    final range = OcptWysiwygInlineRuns.noteRanges(text.toPlainText())
        .where(
          (range) => target.start == target.end
              ? target.start > range.$1 && target.start < range.$2
              : target.start >= range.$1 && target.end <= range.$2,
        )
        .firstOrNull;
    if (range == null) {
      return null;
    }

    return [
      OcptReplaceNodeTextRequest(
        nodeId: target.node.id,
        text: text.copyText(0, range.$1).copyAndAppend(text.copyText(range.$2)),
      ),
      _caretRequest(target.node.id, range.$1),
    ];
  }

  /// Build the request collapsing the caret at [offset] of the node [nodeId].
  static EditRequest _caretRequest(String nodeId, int offset) => ChangeSelectionRequest(
    DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: offset),
      ),
    ),
    SelectionChangeType.insertContent,
    SelectionReason.userInteraction,
  );

  /// Resolve [selection] to the single body paragraph and the ordered, in-block offsets a note
  /// command works on, or null when it has none: no selection, two blocks, a node that is not a
  /// text paragraph, a title-page field or a page break.
  static _NoteTarget? _target(Document document, DocumentSelection? selection) {
    if (selection == null || selection.base.nodeId != selection.extent.nodeId) {
      return null;
    }

    final node = document.getNodeById(selection.extent.nodeId);
    final base = selection.base.nodePosition;
    final extent = selection.extent.nodePosition;
    if (node is! ParagraphNode ||
        base is! TextNodePosition ||
        extent is! TextNodePosition ||
        OcptWysiwygCodec.isTitlePageNode(node) ||
        OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")) ==
            FountainLineType.pageBreak) {
      return null;
    }

    final length = node.text.length;
    final start = base.offset < extent.offset ? base.offset : extent.offset;
    final end = base.offset < extent.offset ? extent.offset : base.offset;
    return _NoteTarget(node: node, start: start.clamp(0, length), end: end.clamp(0, length));
  }
}

/// The block and the ordered offsets (start, exclusive end) a note command targets.
final class _NoteTarget {
  /// The paragraph holding the selection.
  final ParagraphNode node;

  /// The lower selection offset in [node]'s text.
  final int start;

  /// The upper selection offset in [node]'s text; equal to [start] for a collapsed caret.
  final int end;

  /// Class constructor
  const _NoteTarget({required this.node, required this.start, required this.end});
}
