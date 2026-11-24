// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_note.dart';
import 'package:super_editor/super_editor.dart';

/// The correspondence between the offsets of a node's text and those of its line of Fountain
/// source, which differ as soon as the node holds a note: the node counts a note as one position
/// (an inline placeholder), the line writes it as its `[[text]]`.
///
/// Every consumer of the document layout, which reads lines, goes through this class to bring a
/// range of a line back to the node it came from, and nothing else does the arithmetic. A range
/// covering part of a note's expansion covers the whole note: a placeholder is never cut in two.
final class OcptWysiwygNoteOffsets {
  /// The offsets, in the node's text, of the notes it holds, ascending.
  final List<int> _indices;

  /// The Fountain source of each note of [_indices].
  final List<String> _expansions;

  /// Tell whether the node holds no note, a line then being its text offset for offset.
  bool get isIdentity => _indices.isEmpty;

  /// Get the offsets, in the node's text, of the notes it holds, ascending.
  List<int> get noteIndices => List.unmodifiable(_indices);

  /// Get the Fountain source of each note of [noteIndices], in the same order.
  List<String> get noteExpansions => List.unmodifiable(_expansions);

  /// Get the (start, exclusive end) range in the line of each note of [noteIndices], in the same
  /// order.
  List<(int, int)> get noteLineRanges {
    final ranges = <(int, int)>[];
    var shift = 0;
    for (var index = 0; index < _indices.length; index++) {
      final start = _indices[index] + shift;
      ranges.add((start, start + _expansions[index].length));
      shift += _expansions[index].length - 1;
    }
    return ranges;
  }

  /// Class constructor.
  const OcptWysiwygNoteOffsets._(this._indices, this._expansions);

  /// Create the offsets of the notes [expansions] gives, keyed by their offset in the node's text.
  factory OcptWysiwygNoteOffsets.fromExpansions(Map<int, String> expansions) {
    final indices = expansions.keys.toList()..sort();
    return OcptWysiwygNoteOffsets._(indices, [for (final index in indices) expansions[index]!]);
  }

  /// Read the offsets of the notes [text] holds, any other placeholder being left out as the one
  /// character it already is in a line.
  factory OcptWysiwygNoteOffsets.of(AttributedText text) {
    if (text.placeholders.isEmpty) {
      return const OcptWysiwygNoteOffsets._([], []);
    }
    return OcptWysiwygNoteOffsets.fromExpansions({
      for (final entry in text.placeholders.entries)
        if (entry.value is OcptFountainNote) entry.key: (entry.value as OcptFountainNote).expansion,
    });
  }

  /// Get [nodeText], the plain text of a node with a replacement character standing for each of its
  /// notes, written as its line: every note put back in its Fountain form.
  String expand(String nodeText) {
    if (isIdentity) {
      return nodeText;
    }
    final buffer = StringBuffer();
    var cursor = 0;
    for (var index = 0; index < _indices.length; index++) {
      buffer.write(nodeText.substring(cursor, _indices[index]));
      buffer.write(_expansions[index]);
      cursor = _indices[index] + 1;
    }
    buffer.write(nodeText.substring(cursor));
    return buffer.toString();
  }

  /// Get the offset in the line of the boundary [nodeOffset] of the node's text.
  int lineOffsetOf(int nodeOffset) {
    var shift = 0;
    for (var index = 0; index < _indices.length && _indices[index] < nodeOffset; index++) {
      shift += _expansions[index].length - 1;
    }
    return nodeOffset + shift;
  }

  /// Get the range of the line, (start, exclusive end), covering the range of the node's text
  /// ([nodeStart], [nodeEnd]).
  (int, int) lineRangeOf(int nodeStart, int nodeEnd) =>
      (lineOffsetOf(nodeStart), lineOffsetOf(nodeEnd));

  /// Get the offset in the node's text of the line offset [lineOffset], taken as the start of a
  /// range: inside a note, the offset of the note itself, so the range covers it.
  int nodeStartOf(int lineOffset) => _nodeOffsetOf(lineOffset, roundsUp: false);

  /// Get the offset in the node's text of the line offset [lineOffset], taken as the exclusive end
  /// of a range: inside a note, the offset right after the note itself, so the range covers it.
  int nodeEndOf(int lineOffset) => _nodeOffsetOf(lineOffset, roundsUp: true);

  /// Get the range of the node's text, (start, exclusive end), covering the range of the line
  /// ([lineStart], [lineEnd]), every note it touches covered whole.
  (int, int) nodeRangeOf(int lineStart, int lineEnd) =>
      (nodeStartOf(lineStart), nodeEndOf(lineEnd));

  /// Get [lineRanges], (start, exclusive end) ranges of the line, as ranges of the node's text.
  List<(int, int)> nodeRangesOf(List<(int, int)> lineRanges) =>
      isIdentity ? lineRanges : [for (final (start, end) in lineRanges) nodeRangeOf(start, end)];

  /// Get the offset in the node's text of [lineOffset], a position inside a note being brought to
  /// the note's offset or to the one after it according to [roundsUp].
  int _nodeOffsetOf(int lineOffset, {required bool roundsUp}) {
    var shift = 0;
    for (var index = 0; index < _indices.length; index++) {
      final noteStart = _indices[index] + shift;
      final noteEnd = noteStart + _expansions[index].length;
      if (lineOffset <= noteStart) {
        break;
      }
      if (lineOffset < noteEnd) {
        return roundsUp ? _indices[index] + 1 : _indices[index];
      }
      shift += _expansions[index].length - 1;
    }
    return lineOffset - shift;
  }
}
