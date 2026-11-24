// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';

/// The `ParagraphNode` metadata key holding the number of blank source lines that preceded a node
/// (0 inside a dialogue group, since a real blank line there would break the group).
const String ocptBlankLinesBeforeMetadataKey = "ocptBlankLinesBefore";

/// The node-index ↔ source-line mapping produced by both [OcptWysiwygCodec.decode] and
/// [OcptWysiwygCodec.encode], letting the styled editor report caret lines and resolve scene-panel
/// jump requests without the old model's "node index == line index" invariant, now that blank
/// source lines are folded into node metadata instead of being their own node.
class OcptWysiwygLineMapping {
  /// The text [nodeIndexOfCharOffset] resolves a character offset against.
  final String _sourceText;

  /// The 0-based source line of each node, indexed by node index.
  final List<int> _lineByNodeIndex;

  /// The number of source lines each node covers, indexed by node index.
  final List<int> _lineCountByNodeIndex;

  /// The node index owning each 0-based source line (a blank line's entry points at the node
  /// following it), indexed by line number.
  final List<int> _nodeIndexByLine;

  /// Build the mapping for [sourceText] (only [OcptWysiwygCodec] does), given, in node order, each
  /// node's (already resolved, in
  /// the case of [OcptWysiwygCodec.encode]'s dialogue-group override) blank-line-before count, and
  /// the number of blank lines trailing the last node.
  ///
  /// [lineCountByNode] is the number of source lines each node covers, in node order: one for
  /// every node when null, more for a node holding a note that runs over several lines. The blank
  /// lines inside such a note are part of it and counted in no node's blank-line-before count.
  OcptWysiwygLineMapping.build({
    required String sourceText,
    required List<int> blankLinesBeforeByNode,
    required int trailingBlankLines,
    List<int>? lineCountByNode,
  }) : _lineByNodeIndex = [],
       _lineCountByNodeIndex = [],
       _nodeIndexByLine = [],
       _sourceText = sourceText {
    var line = 0;
    for (var nodeIndex = 0; nodeIndex < blankLinesBeforeByNode.length; nodeIndex++) {
      for (var blank = 0; blank < blankLinesBeforeByNode[nodeIndex]; blank++) {
        _nodeIndexByLine.add(nodeIndex);
        line++;
      }
      final lineCount = lineCountByNode?[nodeIndex] ?? 1;
      _lineByNodeIndex.add(line);
      _lineCountByNodeIndex.add(lineCount);
      for (var covered = 0; covered < lineCount; covered++) {
        _nodeIndexByLine.add(nodeIndex);
      }
      line += lineCount;
    }

    final lastNodeIndex = blankLinesBeforeByNode.isEmpty ? 0 : blankLinesBeforeByNode.length - 1;
    for (var blank = 0; blank < trailingBlankLines; blank++) {
      _nodeIndexByLine.add(lastNodeIndex);
    }
  }

  /// Get the 0-based source line the node at [nodeIndex] sits on, accounting for every preceding
  /// node's [ocptBlankLinesBeforeMetadataKey] metadata; [nodeIndex] is clamped to a valid index.
  int lineOfNodeIndex(int nodeIndex) =>
      _lineByNodeIndex[nodeIndex.clamp(0, _lineByNodeIndex.length - 1)];

  /// Get the number of source lines the node at [nodeIndex] covers, one unless it holds a note
  /// running over several lines; [nodeIndex] is clamped to a valid index.
  int lineCountOfNodeIndex(int nodeIndex) =>
      _lineCountByNodeIndex[nodeIndex.clamp(0, _lineCountByNodeIndex.length - 1)];

  /// Get the 0-based node index owning the source line containing character offset [charOffset] of
  /// this mapping's own source text, clamped to a valid line (out-of-range clamps to the text's
  /// length, i.e. the last line, the same convention the old `lineIndexForCharOffset` used). A
  /// blank line's offset snaps to the node immediately following it (or, if it's a trailing blank
  /// line with no following node, to the last node).
  int nodeIndexOfCharOffset(int charOffset) {
    final clampedOffset = charOffset.clamp(0, _sourceText.length);
    final line = "\n".allMatches(_sourceText.substring(0, clampedOffset)).length;
    return _nodeIndexByLine[line.clamp(0, _nodeIndexByLine.length - 1)];
  }
}
