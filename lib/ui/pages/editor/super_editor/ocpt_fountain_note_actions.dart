// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
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
  /// command is withheld: no selection, or a caret or selection not wholly inside one `[[...]]`
  /// range.
  ///
  /// A note inside one block goes whole, brackets and content, along with the one space that would
  /// otherwise be left doubled or dangling, and the caret lands where the removed text started. A
  /// note running over several blocks goes the same way: the blocks it covers are dropped, and what
  /// stood before it in its first block is joined to what stood after it in its last, all in the
  /// same request list, so one undo step puts it back.
  static List<EditRequest>? removeRequests(Document document, DocumentSelection? selection) {
    final target = _target(document, selection, allowsNotedPageBreak: true);
    if (target != null) {
      final text = target.node.text;
      final range = OcptWysiwygInlineRuns.noteRanges(text.toPlainText())
          .where(
            (range) => target.start == target.end
                ? target.start > range.$1 && target.start < range.$2
                : target.start >= range.$1 && target.end <= range.$2,
          )
          .firstOrNull;
      if (range != null) {
        final (start, end) = _withOneSurroundingSpace(text.toPlainText(), range);
        return [
          OcptReplaceNodeTextRequest(
            nodeId: target.node.id,
            text: text.copyText(0, start).copyAndAppend(text.copyText(end)),
          ),
          _caretRequest(target.node.id, start),
        ];
      }
    }

    return _removeAcrossBlocks(document, selection);
  }

  /// Get the requests removing the note of [document] that [selection] lies in when that note runs
  /// over several blocks, or null when there is none.
  static List<EditRequest>? _removeAcrossBlocks(Document document, DocumentSelection? selection) {
    if (selection == null) {
      return null;
    }

    final nodes = document
        .whereType<ParagraphNode>()
        .where((node) => !OcptWysiwygCodec.isTitlePageNode(node))
        .toList(growable: false);
    final nodeStarts = <String, int>{};
    var offset = 0;
    for (final node in nodes) {
      nodeStarts[node.id] = offset;
      offset += node.text.length + 1;
    }

    final base = _globalOffset(nodeStarts, selection.base);
    final extent = _globalOffset(nodeStarts, selection.extent);
    if (base == null || extent == null) {
      return null;
    }
    final start = base < extent ? base : extent;
    final end = base < extent ? extent : base;

    final joined = nodes.map((node) => node.text.toPlainText()).join("\n");
    final note = FountainCommentSpans.of(joined)
        .where((span) => !span.isBoneyard)
        .where(
          (span) => start == end
              ? start > span.start && start < span.end
              : start >= span.start && end <= span.end,
        )
        .firstOrNull;
    if (note == null) {
      return null;
    }

    // The block holding each end of the note, and the offset of each end inside it.
    final first = nodes.lastWhere((node) => nodeStarts[node.id]! <= note.start);
    final last = nodes.lastWhere((node) => nodeStarts[node.id]! <= note.end - 1);
    if (first.id == last.id) {
      return null;
    }
    final firstOffset = note.start - nodeStarts[first.id]!;
    final lastOffset = note.end - nodeStarts[last.id]!;

    final before = first.text.copyText(0, firstOffset);
    final after = last.text.copyText(lastOffset);
    var beforeText = before.toPlainText();
    var afterText = after.toPlainText();
    // Drop the one space the removal would leave doubled or dangling.
    var joinedText = before;
    var afterPart = after;
    if (beforeText.endsWith(" ") && (afterText.isEmpty || afterText.startsWith(" "))) {
      joinedText = before.copyText(0, beforeText.length - 1);
    } else if (beforeText.isEmpty && afterText.startsWith(" ")) {
      afterPart = after.copyText(1);
    }
    beforeText = joinedText.toPlainText();
    afterText = afterPart.toPlainText();

    final firstIndex = nodes.indexOf(first);
    final lastIndex = nodes.indexOf(last);
    final covered = nodes.sublist(firstIndex + 1, lastIndex + 1);

    if (beforeText.isEmpty && afterText.isEmpty && nodes.length > covered.length + 1) {
      // The note took whole blocks: drop them all, and the caret goes to a neighbour.
      final dropped = [first, ...covered];
      final next = firstIndex + dropped.length < nodes.length
          ? nodes[firstIndex + dropped.length]
          : null;
      final previous = firstIndex > 0 ? nodes[firstIndex - 1] : null;
      final blankLinesBefore = first.getMetadataValue(ocptBlankLinesBeforeMetadataKey);
      final nextBlankLines = next?.getMetadataValue(ocptBlankLinesBeforeMetadataKey);
      return [
        for (final node in dropped) DeleteNodeRequest(nodeId: node.id),
        if (next != null && blankLinesBefore is int && nextBlankLines is int)
          OcptChangeNodeMetadataRequest(
            nodeId: next.id,
            metadata: {
              // Nothing above the note: what follows it takes the place of the note, so it keeps
              // the note's own blank lines, never the gap that used to separate the two.
              ocptBlankLinesBeforeMetadataKey: previous == null || blankLinesBefore > nextBlankLines
                  ? blankLinesBefore
                  : nextBlankLines,
            },
          ),
        if (next != null)
          _caretRequest(next.id, 0)
        else
          _caretRequest(previous!.id, previous.text.length),
      ];
    }

    return [
      OcptReplaceNodeTextRequest(nodeId: first.id, text: joinedText.copyAndAppend(afterPart)),
      for (final node in covered) DeleteNodeRequest(nodeId: node.id),
      _caretRequest(first.id, beforeText.length),
    ];
  }

  /// Get the offset of [position] in the text of the body blocks joined by newlines, whose block
  /// starts are [nodeStarts], or null when it lies in no body paragraph.
  static int? _globalOffset(Map<String, int> nodeStarts, DocumentPosition position) {
    final nodeStart = nodeStarts[position.nodeId];
    final nodePosition = position.nodePosition;
    if (nodeStart == null || nodePosition is! TextNodePosition) {
      return null;
    }
    return nodeStart + nodePosition.offset;
  }

  /// Get [range] of [plainText] widened by the one space that would otherwise be left doubled or
  /// dangling once the note is gone: the space before it when a space or the end of the line
  /// follows (`a [[x]] b`, `DAY [[x]]`), else the space after it when it opens the line
  /// (`[[x]] word`).
  static (int, int) _withOneSurroundingSpace(String plainText, (int, int) range) {
    final (start, end) = range;
    final spaceOrEndAfter = end == plainText.length || plainText[end] == " ";
    if (start > 0 && plainText[start - 1] == " " && spaceOrEndAfter) {
      return (start - 1, end);
    }
    if (start == 0 && end < plainText.length && plainText[end] == " ") {
      return (start, end + 1);
    }
    return range;
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
  /// text paragraph, a title-page field or a page break ([allowsNotedPageBreak] lets through a
  /// page break that holds a note, which a command removing it can still work on).
  static _NoteTarget? _target(
    Document document,
    DocumentSelection? selection, {
    bool allowsNotedPageBreak = false,
  }) {
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
        (OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType")) ==
                FountainLineType.pageBreak &&
            !(allowsNotedPageBreak && node.text.toPlainText().contains("[[")))) {
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
