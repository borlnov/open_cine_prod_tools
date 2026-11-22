// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';

/// Where the commented spans (boneyards and notes, `FountainCommentSpans`) fall in a list of
/// source lines, computed document-wide so a span running over several lines reaches every one of
/// them.
///
/// It is the editor's counterpart of what `FountainParser` does before classifying: the parser
/// blanks the commented spans out and classifies the lines left, so a line wholly inside a
/// commented span is no screenplay element at all. This class answers the same questions for the
/// styled editor, from the nodes' texts, recomputed whenever asked, never stored: which lines are
/// inert (wholly commented), what the classifier must read of each line, and which character
/// ranges of each line are commented.
final class OcptWysiwygCommentLayout {
  /// Whether each line is inert: it has text, and all of it lies inside a commented span.
  final List<bool> isInertByLine;

  /// Each line as the parser's classifier reads it: the boneyards and the standalone notes blanked
  /// out, same length as the line.
  final List<String> classificationLines;

  /// The commented ranges (start, exclusive end) of each line, relative to the line, ascending.
  final List<List<(int, int)>> commentRangesByLine;

  /// Class constructor.
  const OcptWysiwygCommentLayout._({
    required this.isInertByLine,
    required this.classificationLines,
    required this.commentRangesByLine,
  });

  /// The lines [OcptWysiwygCommentLayout.of] answered last: the passes of a settle and every build
  /// ask for the layout of the very same lines, which is then computed once.
  static List<String>? _lastLines;

  /// Whether the last layout was built honouring escapes.
  static bool _lastHonoursEscapes = true;

  /// The layout of [_lastLines].
  static OcptWysiwygCommentLayout? _lastLayout;

  /// Get the layout of [lines], the one already computed when the lines are the same as the last
  /// call's.
  factory OcptWysiwygCommentLayout.of(List<String> lines, {bool honoursEscapes = true}) {
    final last = _lastLayout;
    final lastLines = _lastLines;
    if (last != null &&
        lastLines != null &&
        _lastHonoursEscapes == honoursEscapes &&
        _sameLines(lastLines, lines)) {
      return last;
    }
    final layout = OcptWysiwygCommentLayout.fromLines(lines, honoursEscapes: honoursEscapes);
    _lastHonoursEscapes = honoursEscapes;
    _lastLines = List<String>.of(lines);
    _lastLayout = layout;
    return layout;
  }

  /// Build the layout of [lines], one source line each (a blank line is an empty string).
  ///
  /// Linear in the text and the number of spans: the spans are walked once, with a cursor.
  ///
  /// [honoursEscapes] is false for lines of plain text, where an escaped `[[` has lost its
  /// backslash (see `FountainCommentSpans.notes`).
  factory OcptWysiwygCommentLayout.fromLines(List<String> lines, {bool honoursEscapes = true}) {
    final text = lines.join("\n");
    final spans = FountainCommentSpans.of(text, honoursEscapes: honoursEscapes);
    final classificationLines = FountainCommentSpans.scrubForClassification(
      text,
      honoursEscapes: honoursEscapes,
    ).split("\n");

    final isInertByLine = <bool>[];
    final commentRangesByLine = <List<(int, int)>>[];
    var lineStart = 0;
    // The first span ending after the current line starts: the ones before it touch no later line.
    var firstSpan = 0;
    for (final line in lines) {
      final lineEnd = lineStart + line.length;
      while (firstSpan < spans.length && spans[firstSpan].end <= lineStart) {
        firstSpan++;
      }
      final ranges = <(int, int)>[];
      for (var index = firstSpan; index < spans.length && spans[index].start < lineEnd; index++) {
        final span = spans[index];
        if (span.end > lineStart) {
          ranges.add((
            span.start > lineStart ? span.start - lineStart : 0,
            span.end < lineEnd ? span.end - lineStart : line.length,
          ));
        }
      }
      commentRangesByLine.add(ranges);
      isInertByLine.add(_isWhollyCovered(line, ranges));
      lineStart = lineEnd + 1;
    }

    return OcptWysiwygCommentLayout._(
      isInertByLine: isInertByLine,
      classificationLines: classificationLines,
      commentRangesByLine: commentRangesByLine,
    );
  }

  /// Tell whether [a] and [b] hold the same lines.
  static bool _sameLines(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  /// Tell whether [line] has text and every one of its non-whitespace characters lies inside one of
  /// [ranges].
  static bool _isWhollyCovered(String line, List<(int, int)> ranges) {
    var hasText = false;
    var rangeIndex = 0;
    for (var index = 0; index < line.length; index++) {
      if (line[index].trim().isEmpty) {
        continue;
      }
      hasText = true;
      while (rangeIndex < ranges.length && ranges[rangeIndex].$2 <= index) {
        rangeIndex++;
      }
      if (rangeIndex >= ranges.length || ranges[rangeIndex].$1 > index) {
        return false;
      }
    }
    return hasText;
  }
}
