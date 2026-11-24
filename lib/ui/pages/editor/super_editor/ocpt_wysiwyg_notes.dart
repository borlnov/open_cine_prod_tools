// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comment_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_comments.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_document_layout.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_inline_runs.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_note_offsets.dart';
import 'package:super_editor/super_editor.dart';

/// A new text for a node together with where the offsets of its former text now fall.
typedef OcptWysiwygNoteEdit = ({AttributedText text, int Function(int offset) mapOffset});

/// The note half of `OcptWysiwygCodec`: which notes of the document the styled editor holds as
/// inline placeholders ([OcptFountainNote]) and which it leaves as text, and the requests keeping
/// that in step with what is typed.
///
/// **The invariant:** a node holds a placeholder for exactly each note the parser would see that
/// opens and closes on its line, lies outside every boneyard and holds neither `/*` nor `*/`;
/// every other note stays text, bracketed and dimmed. A note typed or pasted as text is *absorbed*
/// into a placeholder as soon as it satisfies it, and a placeholder whose expansion stops being
/// such a note is *dissolved* back into its text, so the Fountain source a node writes never
/// depends on which form its notes took.
///
/// Pure and stateless: it only reads a document and returns what a caller must still execute
/// against a live `Editor`.
final class OcptWysiwygNotes {
  /// The markers of a boneyard: a note holding one is never a placeholder, since a boneyard opened
  /// or closed around it would swallow it.
  static const List<String> _boneyardMarkers = ["/*", "*/"];

  /// Private constructor: this class only exposes static members.
  const OcptWysiwygNotes._();

  /// Compute the requests bringing the notes of every body node of [document] in line with the
  /// invariant, one text replacement per node that differs, carrying the selection through it.
  ///
  /// A node in [composingNodeIds], whose text an input method is still composing, is left alone and
  /// dealt with at the settle that follows the composition's end. Run it before any pass reading
  /// the nodes' texts, in an `execute` of its own, and lay the document out again after it: it
  /// rewrites texts, so the requests of another pass computed from the same layout would address
  /// offsets that no longer exist.
  static List<EditRequest> requests(
    Document document, {
    OcptWysiwygDocumentLayout? documentLayout,
    Set<String> composingNodeIds = const {},
  }) {
    final requests = <EditRequest>[];
    final (nodes, layout, lineRangeOfNode) = OcptWysiwygComments.resolve(document, documentLayout);

    for (var index = 0; index < nodes.length; index++) {
      if (composingNodeIds.contains(nodes[index].id)) {
        continue;
      }
      final edit = editOf(nodes[index], layout, lineRangeOfNode[index]);
      if (edit != null) {
        requests.add(
          OcptReplaceNodeTextRequest(
            nodeId: nodes[index].id,
            text: edit.text,
            mapOffset: edit.mapOffset,
          ),
        );
      }
    }

    return requests;
  }

  /// Get [nodes], freshly decoded body nodes, with their notes absorbed into placeholders: the
  /// same rule [requests] applies, so a decoded document is already settled and no pass has
  /// anything to ask of it.
  static List<ParagraphNode> absorbedNodes(List<ParagraphNode> nodes) {
    final (layout, lineRangeOfNode) = OcptWysiwygComments.layoutOfNodes(nodes);
    return [
      for (var index = 0; index < nodes.length; index++)
        _withEdit(nodes[index], editOf(nodes[index], layout, lineRangeOfNode[index])),
    ];
  }

  /// Get what [node], whose lines are [lineRange] (first line, line count) of [layout], must become
  /// for its notes to satisfy the invariant, or null when they already do.
  static OcptWysiwygNoteEdit? editOf(
    ParagraphNode node,
    OcptWysiwygCommentLayout layout,
    (int, int) lineRange,
  ) {
    final text = node.text;
    final offsets = OcptWysiwygNoteOffsets.of(text);
    final line = offsets.expand(text.toPlainText());
    final desired = [
      for (final range in layout.noteRangesOfNode(lineRange.$1, lineRange.$2))
        if (!_holdsBoneyardMarker(line.substring(range.$1 + 2, range.$2 - 2))) range,
    ];
    final current = offsets.noteLineRanges;
    if (OcptWysiwygInlineRuns.sameRanges(current, desired)) {
      return null;
    }

    final regions = <_Region>[];
    for (final range in desired) {
      if (current.contains(range)) {
        continue;
      }
      final (start, end) = offsets.nodeRangeOf(range.$1, range.$2);
      final (lineStart, lineEnd) = offsets.lineRangeOf(start, end);
      regions.add(
        _Region(
          start: start,
          end: end,
          replacement: _textOf(line.substring(lineStart, range.$1))
              .copyAndAppend(
                AttributedText("").insertPlaceholder(
                  0,
                  OcptFountainNote.create(line.substring(range.$1 + 2, range.$2 - 2)),
                ),
              )
              .copyAndAppend(_textOf(line.substring(range.$2, lineEnd))),
        ),
      );
    }
    final indices = offsets.noteIndices;
    for (var index = 0; index < indices.length; index++) {
      final isDissolved = !desired.contains(current[index]);
      final isInRegion = regions.any(
        (region) => region.start <= indices[index] && indices[index] < region.end,
      );
      if (isDissolved && !isInRegion) {
        regions.add(
          _Region(
            start: indices[index],
            end: indices[index] + 1,
            replacement: _textOf(offsets.noteExpansions[index]),
          ),
        );
      }
    }
    regions.sort((a, b) => a.start.compareTo(b.start));

    var result = AttributedText("");
    var cursor = 0;
    final applied = <_Region>[];
    for (final region in regions) {
      if (region.start < cursor) {
        continue;
      }
      if (region.start > cursor) {
        result = result.copyAndAppend(text.copyText(cursor, region.start));
      }
      result = result.copyAndAppend(region.replacement);
      cursor = region.end;
      applied.add(region);
    }
    if (cursor < text.length) {
      result = result.copyAndAppend(text.copyText(cursor));
    }
    return (text: result, mapOffset: (offset) => _mapped(offset, applied));
  }

  /// Get [node] with the text of [edit], or [node] itself when [edit] is null.
  static ParagraphNode _withEdit(ParagraphNode node, OcptWysiwygNoteEdit? edit) =>
      edit == null ? node : node.copyParagraphWith(text: edit.text);

  /// Get [source] as an attributed text with no attribution.
  static AttributedText _textOf(String source) => AttributedText(source);

  /// Tell whether [noteText] holds the marker of a boneyard.
  static bool _holdsBoneyardMarker(String noteText) => _boneyardMarkers.any(noteText.contains);

  /// Get [offset], an offset of a node's former text, moved through [regions] (ascending, apart):
  /// an offset past a region shifts by the length the region gained, one inside it falls after the
  /// text that replaced it.
  static int _mapped(int offset, List<_Region> regions) {
    var shift = 0;
    for (final region in regions) {
      if (offset <= region.start) {
        break;
      }
      if (offset < region.end) {
        return region.start + shift + region.replacement.length;
      }
      shift += region.replacement.length - (region.end - region.start);
    }
    return offset + shift;
  }
}

/// A stretch of a node's text a note edit replaces.
final class _Region {
  /// The offset where the stretch starts.
  final int start;

  /// The offset where the stretch ends, exclusive.
  final int end;

  /// What takes its place.
  final AttributedText replacement;

  /// Class constructor.
  const _Region({required this.start, required this.end, required this.replacement});
}
