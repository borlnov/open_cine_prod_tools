// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:super_editor/super_editor.dart';

/// Clips a document selection to the paragraph nodes it spans, for the clipboard export of
/// `OcptWysiwygCodec.encodeSelectionToFountain`.
final class OcptWysiwygSelectionClip {
  /// Private constructor: this class only exposes static members.
  const OcptWysiwygSelectionClip._();

  /// The [ParagraphNode]s [selection] spans in [document], in document order, with the first and
  /// last node's text clipped to the selection's own start/end offsets (a selection collapsed to
  /// a single node clips both ends of that one node). A non-[ParagraphNode] inside the span (none
  /// exist in this model today, but [Document.getNodesInside]'s contract allows any [DocumentNode]
  /// type) is skipped rather than crashing, since it carries nothing this codec can serialize.
  static List<ParagraphNode> clippedNodes(Document document, DocumentSelection selection) {
    final range = selection.normalize(document);
    final startPosition = range.start.nodePosition;
    final endPosition = range.end.nodePosition;
    if (startPosition is! TextNodePosition || endPosition is! TextNodePosition) {
      return const [];
    }

    final nodes = document
        .getNodesInside(range.start, range.end)
        .whereType<ParagraphNode>()
        .toList(growable: false);
    if (nodes.isEmpty) {
      return const [];
    }

    return [
      for (var index = 0; index < nodes.length; index++)
        _clipNode(
          nodes[index],
          startOffset: range.start.nodeId == nodes[index].id ? startPosition.offset : 0,
          endOffset: range.end.nodeId == nodes[index].id ? endPosition.offset : null,
        ),
    ];
  }

  /// A copy of [node] whose text is clipped to `[startOffset, endOffset)` (or to the end of the
  /// text when [endOffset] is null), attributions preserved; every other field, including
  /// metadata, is left untouched.
  static ParagraphNode _clipNode(ParagraphNode node, {required int startOffset, int? endOffset}) {
    final clippedText = endOffset != null
        ? node.text.copyText(startOffset, endOffset)
        : node.text.copyText(startOffset);
    return node.copyParagraphWith(text: clippedText);
  }
}
