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

  /// Private constructor: this class only exposes static members.
  const OcptWysiwygDecoder._();

  /// Run the shared per-line decoding loop behind [OcptWysiwygCodec.decode] and
  /// [OcptWysiwygCodec.decodeNodesFromFountain]: turns [lines] into one node per non-blank line
  /// (folding blank runs into [ocptBlankLinesBeforeMetadataKey] metadata) plus, in call order, the
  /// resulting nodes, their blank-lines-before counts (same length, same order as the nodes) and
  /// the number of blank lines still pending after the last non-blank line (the trailing run
  /// [OcptWysiwygCodec.decode] alone turns into `trailingBlankLines`).
  static (List<ParagraphNode>, List<int>, int) decodeLines(List<String> lines) {
    final layout = OcptWysiwygCommentLayout.of(lines);
    final types = _classifier.classify(layout.classificationLines);

    final nodes = <ParagraphNode>[];
    final blankLinesBeforeByNode = <int>[];
    var pendingBlanks = 0;

    for (var index = 0; index < lines.length; index++) {
      final isInert = layout.isInertByLine[index];
      if (!isInert && types[index] == FountainLineType.blank) {
        pendingBlanks++;
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
      final (sceneText, sceneNumber) = type == FountainLineType.sceneHeading
          ? OcptWysiwygMarkers.extractSceneNumber(strippedText)
          : (strippedText, null);
      final (displayText, dualSuffix) = !isInert && type == FountainLineType.character
          ? OcptWysiwygDualDialogue.extractSuffix(sceneText)
          : (sceneText, null);
      nodes.add(
        ParagraphNode(
          id: Editor.createNodeId(),
          text: OcptWysiwygInlineRuns.parseInline(
            displayText,
            _starsWithin(layout.boneyardStarsByLine[index], lines[index], displayText),
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
      pendingBlanks = 0;
    }

    final absorbedNodes = OcptWysiwygNotes.absorbedNodes(nodes);
    OcptWysiwygComments.attributeCommentedText(absorbedNodes);
    return (absorbedNodes, blankLinesBeforeByNode, pendingBlanks);
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
