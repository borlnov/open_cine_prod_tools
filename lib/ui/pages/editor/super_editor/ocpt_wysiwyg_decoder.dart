// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comment_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comments.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_markers.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_notes.dart';
import 'package:super_editor/super_editor.dart';

/// The decoding half of `OcptWysiwygCodec`: how the source lines of a Fountain text become the
/// body nodes of the styled editor, one node per non-blank line, the blank runs folded into each
/// node's metadata.
///
/// Pure and stateless: it only reads lines and returns the nodes.
final class OcptWysiwygDecoder {
  /// The classifier used to turn a line's text into its [FountainLineType].
  static const _classifier = FountainLineClassifier();

  /// The elements a group of lines bound by a note may be, none of them having a marker the lines
  /// after the first could be told apart by.
  static const _foldableTypes = {
    FountainLineType.action,
    FountainLineType.dialogue,
    FountainLineType.parenthetical,
  };

  /// Private constructor: this class only exposes static members.
  const OcptWysiwygDecoder._();

  /// Run the shared per-line decoding loop behind [OcptWysiwygCodec.decode] and
  /// [OcptWysiwygCodec.decodeNodesFromFountain]: turns [lines] into one node per non-blank line,
  /// or per group of lines a note running over several of them binds together (see [_foldsOf]),
  /// folding blank runs into [ocptBlankLinesBeforeMetadataKey] metadata. Answers, in call order,
  /// the resulting nodes, their blank-lines-before counts and the number of source lines each
  /// covers (same length, same order as the nodes), and the number of blank lines still pending
  /// after the last non-blank line (the trailing run [OcptWysiwygCodec.decode] alone turns into
  /// `trailingBlankLines`).
  static (List<ParagraphNode>, List<int>, List<int>, int) decodeLines(List<String> lines) {
    final layout = OcptWysiwygCommentLayout.of(lines);
    final types = _classifier.classify(layout.classificationLines);
    final folds = _foldsOf(lines, layout, types);

    final nodes = <ParagraphNode>[];
    final blankLinesBeforeByNode = <int>[];
    final lineCountByNode = <int>[];
    var pendingBlanks = 0;

    var index = 0;
    while (index < lines.length) {
      final fold = folds[index];
      final isInert = fold?.isInert ?? layout.isInertByLine[index];
      if (fold == null && !isInert && types[index] == FountainLineType.blank) {
        pendingBlanks++;
        index++;
        continue;
      }

      final type = isInert ? FountainLineType.action : types[index];
      final (strippedText, hadForcingMarker) = isInert
          ? (lines[index], false)
          : OcptWysiwygMarkers.stripDisplayText(
              lines[index],
              type,
              layout.classificationLines[index],
            );
      final lastLine = fold?.lastLine ?? index;
      final (sceneText, sceneNumber) = type == FountainLineType.sceneHeading
          ? OcptWysiwygMarkers.extractSceneNumber(strippedText)
          : (strippedText, null);
      final (headText, dualSuffix) = !isInert && type == FountainLineType.character
          ? OcptWysiwygDualDialogue.extractSuffix(sceneText)
          : (sceneText, null);
      // The lines a note binds to the first one are kept as written: only the first line of a
      // node is ever a line of its own, the rest being what its notes run over.
      final displayText = [headText, ...lines.sublist(index + 1, lastLine + 1)].join("\n");
      nodes.add(
        ParagraphNode(
          id: Editor.createNodeId(),
          text: OcptWysiwygInlineRuns.parseInline(
            displayText,
            fold == null
                ? _starsWithin(layout.boneyardStarsByLine[index], lines[index], displayText)
                : const {},
          ),
          metadata: {
            "blockType": OcptFountainLineAttributions.attributionOf(type),
            ocptBlankLinesBeforeMetadataKey: pendingBlanks,
            ocptTypeLockedMetadataKey: false,
            ocptHadForcingMarkerMetadataKey: hadForcingMarker,
            ocptSceneNumberMetadataKey: sceneNumber,
            ocptDualDialogueMetadataKey: dualSuffix,
            if (type == FountainLineType.section && hadForcingMarker)
              ocptSectionLevelMetadataKey: OcptWysiwygMarkers.sectionLevelOf(lines[index]),
          },
        ),
      );
      blankLinesBeforeByNode.add(pendingBlanks);
      lineCountByNode.add(lastLine - index + 1);
      pendingBlanks = 0;
      index = lastLine + 1;
    }

    final absorbedNodes = OcptWysiwygNotes.absorbedNodes(nodes);
    OcptWysiwygComments.attributeCommentedText(absorbedNodes);
    return (absorbedNodes, blankLinesBeforeByNode, lineCountByNode, pendingBlanks);
  }

  /// Find the groups of [lines] that become one node each: the lines a note running over several
  /// of them covers, as the folds keyed by the index of their first line.
  ///
  /// Lines are bound together when a note crosses them, the notes sharing a line being bound
  /// to one another. A group is refused, its lines staying nodes of their own with the note as
  /// dimmed text, unless folding it changes nothing of what the parser reads of the lines:
  ///
  /// - no boneyard touches it, since a boneyard is no placeholder and would have to be told from
  ///   the note's text;
  /// - every character of it that is not whitespace lies inside a note (the node is then inert,
  ///   whatever its lines hold), or else no line of it is blank and the parser's classifier makes
  ///   the same element of every one of them, [types] being what it answers for each line, that
  ///   element being an action, a dialogue or a parenthetical, which have no marker to be told
  ///   apart by.
  static Map<int, _Fold> _foldsOf(
    List<String> lines,
    OcptWysiwygCommentLayout layout,
    List<FountainLineType> types,
  ) {
    final folds = <int, _Fold>{};
    final boneyardLines = [
      for (final span in layout.spans)
        if (span.isBoneyard) (_lineOf(layout, span.start), _lineOf(layout, span.end - 1)),
    ];

    void consider(int first, int last) {
      if (boneyardLines.any((range) => range.$1 <= last && range.$2 >= first)) {
        return;
      }
      if (layout.isInertOfNode(first, last - first + 1)) {
        folds[first] = _Fold(lastLine: last, isInert: true);
        return;
      }
      final type = types[first];
      if (!_foldableTypes.contains(type)) {
        return;
      }
      for (var line = first; line <= last; line++) {
        if (lines[line].trim().isEmpty || types[line] != type) {
          return;
        }
      }
      folds[first] = _Fold(lastLine: last, isInert: false);
    }

    int? groupFirst;
    var groupLast = 0;
    for (final span in layout.spans) {
      if (span.isBoneyard) {
        continue;
      }
      final first = _lineOf(layout, span.start);
      final last = _lineOf(layout, span.end - 1);
      if (groupFirst != null && first <= groupLast) {
        groupLast = last > groupLast ? last : groupLast;
        continue;
      }
      if (groupFirst != null) {
        consider(groupFirst, groupLast);
      }
      if (first == last) {
        groupFirst = null;
        continue;
      }
      groupFirst = first;
      groupLast = last;
    }
    if (groupFirst != null) {
      consider(groupFirst, groupLast);
    }
    return folds;
  }

  /// Get the index of the line of [layout] holding the character at [offset] of its joined text.
  static int _lineOf(OcptWysiwygCommentLayout layout, int offset) {
    var low = 0;
    var high = layout.lineStarts.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (layout.lineStarts[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  /// Get the offsets [stars] of a source line [rawLine] hold, as offsets in [displayText], the line
  /// once its forcing marker was stripped.
  static Set<int> _starsWithin(List<int> stars, String rawLine, String displayText) {
    final shift = rawLine.endsWith(displayText)
        ? rawLine.length - displayText.length
        : rawLine.indexOf(displayText);
    if (shift < 0) {
      return const {};
    }
    return {
      for (final star in stars)
        if (star >= shift && star - shift < displayText.length) star - shift,
    };
  }
}

/// A group of source lines [OcptWysiwygDecoder] folds into one node, as the line it ends on.
final class _Fold {
  /// The index of the last line of the group.
  final int lastLine;

  /// Whether every character of the group that is not whitespace lies inside a note.
  final bool isInert;

  /// Class constructor.
  const _Fold({required this.lastLine, required this.isInert});
}
