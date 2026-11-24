// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comment_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_document_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_line_mapping.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_note_offsets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_title_page.dart';
import 'package:super_editor/super_editor.dart';

/// The commented-span half of `OcptWysiwygCodec`: how a document of nodes is laid out as lines of
/// plain text, where the boneyards and the notes fall in them, which nodes are inert, and the
/// requests that keep the nodes' comment and note attributions in step with that.
///
/// Pure and stateless but for [layoutCount]: it only reads a document and returns what a caller
/// must still execute against a live `Editor`.
final class OcptWysiwygComments {
  /// The number of times a document was laid out as source lines, for a test to tell how often a
  /// settle does it.
  @visibleForTesting
  static int layoutCount = 0;

  /// Private constructor: this class only exposes static members.
  const OcptWysiwygComments._();

  /// Compute the requests needed to bring every body node's [ocptFountainCommentAttribution] spans
  /// back in sync with the commented spans of the whole document: a boneyard or a note running
  /// over several nodes dims every one of them, and an inert node is dimmed whole. Like
  /// [noteAttributionRequests], only a node whose spans differ gets a request, and the requests are
  /// plain attribution changes, so they merge into the step of the edit that caused them.
  static List<EditRequest> commentAttributionRequests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
  }) {
    final requests = <EditRequest>[];
    final (nodes, layout, lineIndexOfNode) = resolve(document, documentLayout);

    for (var index = 0; index < nodes.length; index++) {
      requests.addAll(
        _attributionRequests(
          nodes[index],
          ocptFountainCommentAttribution,
          nodeRangesOf(nodes[index], layout.commentRangesByLine[lineIndexOfNode[index]]),
        ),
      );
    }

    return requests;
  }

  /// Compute the requests needed to bring every node's [ocptFountainNoteAttribution] spans back
  /// in sync with the `[[...]]` regions currently in its text, adding/removing spans only for a
  /// node whose desired spans actually differ from what it currently carries (so an edit outside
  /// any note leaves every node's note spans untouched).
  static List<EditRequest> noteAttributionRequests(Document document) {
    final requests = <EditRequest>[];

    for (final node in document) {
      if (node is! ParagraphNode) {
        continue;
      }

      requests.addAll(_attributionRequests(node, ocptFountainNoteAttribution, noteRangesOf(node)));
    }

    return requests;
  }

  /// Get the (start, exclusive end) ranges, in [node]'s text, of the notes it holds as text: the
  /// `[[ ... ]]` regions of its virtual text, an escaped `[[` leaving none. A note held as a
  /// placeholder is no such range: it has no text to dim.
  static List<(int, int)> noteRangesOf(ParagraphNode node) => [
    for (final (start, end) in nodeRangesOf(node, [
      for (final span in FountainCommentSpans.notes(virtualTextOf(node), honoursEscapes: false))
        (span.start, span.end),
    ]))
      if (!(end - start == 1 && node.text.placeholders[start] is OcptFountainNote)) (start, end),
  ];

  /// Get the text of [node] the commented spans are looked for in, one line of Fountain source:
  /// its plain text with every note it holds as a placeholder put back in its `[[text]]` form, and
  /// the characters that stand for an escaped bracket (see [ocptFountainEscapedAttribution]) made
  /// harmless.
  static String virtualTextOf(ParagraphNode node) {
    final plainText = node.text.toPlainText();
    final escaped = spansOf(node.text, ocptFountainEscapedAttribution);
    if (escaped.isEmpty) {
      return plainLineOf(node, plainText);
    }
    final characters = plainText.split("");
    for (final (start, end) in escaped) {
      for (var index = start; index < end; index++) {
        characters[index] = "(";
      }
    }
    return plainLineOf(node, characters.join());
  }

  /// Get [nodeText], the plain text of [node] (or a copy of it), with every note [node] holds as a
  /// placeholder written as its `[[text]]`: the line of Fountain source the node stands for.
  static String plainLineOf(ParagraphNode node, String nodeText) =>
      OcptWysiwygNoteOffsets.of(node.text).expand(nodeText);

  /// Get [lineRanges], (start, exclusive end) ranges of [node]'s line (what the layout answers),
  /// as ranges of [node]'s text, every note a range touches covered whole.
  static List<(int, int)> nodeRangesOf(ParagraphNode node, List<(int, int)> lineRanges) =>
      OcptWysiwygNoteOffsets.of(node.text).nodeRangesOf(lineRanges);

  /// Get the ids of the inert nodes of [document]: the body nodes whose whole text lies inside a
  /// boneyard or a note. Recomputed on every call, from the nodes' texts.
  static Set<String> inertNodeIds(Document document, {OcptWysiwygDocumentLayout? documentLayout}) {
    final (nodes, layout, lineIndexOfNode) = resolve(document, documentLayout);
    return {
      for (var index = 0; index < nodes.length; index++)
        if (layout.isInertByLine[lineIndexOfNode[index]]) nodes[index].id,
    };
  }

  /// Lay out the body of [document] as source lines, to hand to the passes of one settle (see
  /// [OcptWysiwygDocumentLayout]).
  static OcptWysiwygDocumentLayout layoutOf(Document document) {
    final nodes = bodyNodes(document);
    final (layout, lineIndexOfNode) = layoutOfNodes(nodes);
    return OcptWysiwygDocumentLayout(
      nodes: nodes,
      comments: layout,
      lineIndexOfNode: lineIndexOfNode,
    );
  }

  /// Lay out [nodes] (body nodes only) as lines of plain text, the blank runs folded into their
  /// metadata put back, and compute where the commented spans fall; the second part tells, for
  /// each node, its index in the layout's lines.
  static (OcptWysiwygCommentLayout, List<int>) layoutOfNodes(List<ParagraphNode> nodes) {
    layoutCount++;
    final lines = <String>[];
    final lineIndexOfNode = List<int>.filled(nodes.length, 0);
    for (var index = 0; index < nodes.length; index++) {
      for (var blank = 0; blank < blankLinesBeforeOf(nodes[index]); blank++) {
        lines.add("");
      }
      lineIndexOfNode[index] = lines.length;
      lines.add(virtualTextOf(nodes[index]));
    }
    return (OcptWysiwygCommentLayout.of(lines, honoursEscapes: false), lineIndexOfNode);
  }

  /// Get the body nodes of [document] with their layout: [given] when set, else computed.
  static (List<ParagraphNode>, OcptWysiwygCommentLayout, List<int>) resolve(
    Document document,
    OcptWysiwygDocumentLayout? given,
  ) {
    final resolved = given ?? layoutOf(document);
    return (resolved.nodes, resolved.comments, resolved.lineIndexOfNode);
  }

  /// Get the body paragraphs of [document], the title-page fields left out.
  static List<ParagraphNode> bodyNodes(Document document) => document
      .whereType<ParagraphNode>()
      .where((node) => node.getMetadataValue(ocptTitlePageKeyMetadataKey) is! String)
      .toList(growable: false);

  /// Put on the freshly decoded [nodes] the comment and note attributions the derived passes
  /// would put, so a decoded document is already settled: the editor's first history snapshot
  /// carries them, and no pass has anything to add on a document nobody edited.
  static void attributeCommentedText(List<ParagraphNode> nodes) {
    final (layout, lineIndexOfNode) = layoutOfNodes(nodes);
    for (var index = 0; index < nodes.length; index++) {
      final text = nodes[index].text;
      final length = text.length;
      void set(NamedAttribution attribution, List<(int, int)> desired) {
        final merged = mergeAdjacent(desired);
        if (OcptWysiwygInlineRuns.sameRanges(spansOf(text, attribution), merged)) {
          return;
        }
        if (length > 0) {
          text.removeAttribution(attribution, SpanRange(0, length - 1));
        }
        for (final (start, end) in merged) {
          text.addAttribution(attribution, SpanRange(start, end - 1));
        }
      }

      set(
        ocptFountainCommentAttribution,
        nodeRangesOf(nodes[index], layout.commentRangesByLine[lineIndexOfNode[index]]),
      );
      set(ocptFountainNoteAttribution, noteRangesOf(nodes[index]));
    }
  }

  /// Get the (start, exclusive end) ranges [attribution] covers in [text], ascending.
  static List<(int, int)> spansOf(AttributedText text, NamedAttribution attribution) =>
      text.getAttributionSpans({attribution}).map((span) => (span.start, span.end + 1)).toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));

  /// Get [ranges] (start, exclusive end, ascending) with every range that starts where the
  /// previous one ends joined to it, the way an attributed text merges two touching spans.
  static List<(int, int)> mergeAdjacent(List<(int, int)> ranges) {
    final merged = <(int, int)>[];
    for (final (start, end) in ranges) {
      if (merged.isNotEmpty && merged.last.$2 == start) {
        merged[merged.length - 1] = (merged.last.$1, end);
      } else {
        merged.add((start, end));
      }
    }
    return merged;
  }

  /// Read a node's [ocptBlankLinesBeforeMetadataKey] metadata, defaulting to 0 for a node that
  /// never had it set (for example one freshly split off by a default super_editor command).
  static int blankLinesBeforeOf(ParagraphNode node) {
    final value = node.getMetadataValue(ocptBlankLinesBeforeMetadataKey);
    return value is int ? value : 0;
  }

  /// Get the requests bringing [node]'s [attribution] spans to exactly [desiredRanges] (start,
  /// exclusive end), none when it already carries them.
  static List<EditRequest> _attributionRequests(
    TextNode node,
    NamedAttribution attribution,
    List<(int, int)> desiredRanges,
  ) {
    final plainText = node.text.toPlainText();
    final currentRanges =
        node.text
            .getAttributionSpans({attribution})
            .map((span) => (span.start, span.end + 1))
            .toList(growable: false)
          ..sort((a, b) => a.$1.compareTo(b.$1));

    final desired = mergeAdjacent(desiredRanges);
    if (OcptWysiwygInlineRuns.sameRanges(currentRanges, desired)) {
      return const [];
    }

    return [
      if (currentRanges.isNotEmpty)
        RemoveTextAttributionsRequest(
          documentRange: DocumentRange(
            start: DocumentPosition(
              nodeId: node.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            end: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: plainText.length),
            ),
          ),
          attributions: {attribution},
        ),
      for (final (start, end) in desired)
        AddTextAttributionsRequest(
          documentRange: DocumentRange(
            start: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: start),
            ),
            end: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: end),
            ),
          ),
          attributions: {attribution},
        ),
    ];
  }
}
