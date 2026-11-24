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
  /// The lines [OcptWysiwygCommentLayout.of] answered last: the passes of a settle and every build
  /// ask for the layout of the very same lines, which is then computed once.
  static List<String>? _lastLines;

  /// Whether the last layout was built honouring escapes.
  static bool _lastHonoursEscapes = true;

  /// The layout of [_lastLines].
  static OcptWysiwygCommentLayout? _lastLayout;

  /// Whether each line is inert: it has text, and all of it lies inside a commented span.
  final List<bool> isInertByLine;

  /// Each line as the parser's classifier reads it: the boneyards and the standalone notes blanked
  /// out, same length as the line.
  final List<String> classificationLines;

  /// The commented ranges (start, exclusive end) of each line, relative to the line, ascending.
  final List<List<(int, int)>> commentRangesByLine;

  /// The offsets, relative to each line, of the `*` of the boneyard delimiters (`/*` and `*/`) the
  /// line holds, ascending: the stars no emphasis marker may be made of. A `/*` with no closing
  /// `*/` is no boneyard and has none.
  final List<List<int>> boneyardStarsByLine;

  /// The offset, in the joined text of the lines, where each line starts.
  final List<int> lineStarts;

  /// The offset, in the joined text of the lines, where each line ends (its newline excluded).
  final List<int> lineEnds;

  /// The commented spans of the joined text of the lines, as `FountainCommentSpans.of` reads them
  /// (offsets in that text), ascending and apart.
  final List<FountainCommentSpan> spans;

  /// Whether each line has a character that is not whitespace.
  final List<bool> hasTextByLine;

  /// Whether each line has a character that is not whitespace and lies outside every commented
  /// span.
  final List<bool> hasUncoveredTextByLine;

  /// The index, in [spans], of the first span ending after each line starts: the spans before it
  /// touch neither that line nor a later one.
  final List<int> _firstSpanByLine;

  /// Class constructor.
  const OcptWysiwygCommentLayout._({
    required this.isInertByLine,
    required this.classificationLines,
    required this.commentRangesByLine,
    required this.boneyardStarsByLine,
    required this.lineStarts,
    required this.lineEnds,
    required this.spans,
    required this.hasTextByLine,
    required this.hasUncoveredTextByLine,
    required List<int> firstSpanByLine,
  }) : _firstSpanByLine = firstSpanByLine;

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

    final stars = [
      for (final span in spans)
        if (span.isBoneyard) ...[span.start + 1, span.end - 2],
    ];
    var nextStar = 0;
    final boneyardStarsByLine = <List<int>>[];
    final isInertByLine = <bool>[];
    final commentRangesByLine = <List<(int, int)>>[];
    final lineStarts = <int>[];
    final lineEnds = <int>[];
    final hasTextByLine = <bool>[];
    final hasUncoveredTextByLine = <bool>[];
    final firstSpanByLine = <int>[];
    var lineStart = 0;
    // The first span ending after the current line starts: the ones before it touch no later line.
    var firstSpan = 0;
    for (final line in lines) {
      final lineEnd = lineStart + line.length;
      while (firstSpan < spans.length && spans[firstSpan].end <= lineStart) {
        firstSpan++;
      }
      firstSpanByLine.add(firstSpan);
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
      final lineStars = <int>[];
      while (nextStar < stars.length && stars[nextStar] <= lineEnd) {
        if (stars[nextStar] >= lineStart && stars[nextStar] < lineEnd) {
          lineStars.add(stars[nextStar] - lineStart);
        }
        nextStar++;
      }
      boneyardStarsByLine.add(lineStars);
      commentRangesByLine.add(ranges);
      final (hasText, hasUncoveredText) = _coverageOf(line, ranges);
      hasTextByLine.add(hasText);
      hasUncoveredTextByLine.add(hasUncoveredText);
      isInertByLine.add(hasText && !hasUncoveredText);
      lineStarts.add(lineStart);
      lineEnds.add(lineEnd);
      lineStart = lineEnd + 1;
    }

    return OcptWysiwygCommentLayout._(
      isInertByLine: isInertByLine,
      classificationLines: classificationLines,
      commentRangesByLine: commentRangesByLine,
      boneyardStarsByLine: boneyardStarsByLine,
      lineStarts: lineStarts,
      lineEnds: lineEnds,
      spans: spans,
      hasTextByLine: hasTextByLine,
      hasUncoveredTextByLine: hasUncoveredTextByLine,
      firstSpanByLine: firstSpanByLine,
    );
  }

  /// Tell whether the [count] lines from line [start] are inert as one node: none of them has text
  /// outside a commented span, and at least one has text. A line of whitespace in the middle does
  /// not stop it, which a line of its own would not be inert for.
  bool isInertOfNode(int start, int count) {
    var hasText = false;
    for (var line = start; line < start + count; line++) {
      if (hasUncoveredTextByLine[line]) {
        return false;
      }
      hasText = hasText || hasTextByLine[line];
    }
    return hasText;
  }

  /// Get the lines the parser's classifier reads of the [count] lines from line [start].
  List<String> classificationLinesOfNode(int start, int count) =>
      classificationLines.sublist(start, start + count);

  /// Get the index of the first of the [count] lines from line [start] whose classification line
  /// is not blank, or [start] when all of them are.
  int firstClassifiedLineOfNode(int start, int count) {
    for (var line = start; line < start + count; line++) {
      if (classificationLines[line].trim().isNotEmpty) {
        return line;
      }
    }
    return start;
  }

  /// Get the commented ranges (start, exclusive end) of the [count] lines from line [start],
  /// relative to the text of those lines joined by newlines, ascending.
  List<(int, int)> commentRangesOfNode(int start, int count) {
    if (count == 1) {
      return commentRangesByLine[start];
    }
    final nodeStart = lineStarts[start];
    final nodeEnd = lineEnds[start + count - 1];
    return [
      for (final span in _spansFrom(start, nodeEnd))
        if (span.end > nodeStart)
          (
            span.start > nodeStart ? span.start - nodeStart : 0,
            span.end < nodeEnd ? span.end - nodeStart : nodeEnd - nodeStart,
          ),
    ];
  }

  /// Get the offsets of the `*` of the boneyard delimiters of the [count] lines from line
  /// [start], relative to the text of those lines joined by newlines, ascending.
  List<int> boneyardStarsOfNode(int start, int count) {
    if (count == 1) {
      return boneyardStarsByLine[start];
    }
    return [
      for (var line = start; line < start + count; line++)
        for (final star in boneyardStarsByLine[line]) star + lineStarts[line] - lineStarts[start],
    ];
  }

  /// Get the notes, as (start, exclusive end) ranges, that open and close within the [count] lines
  /// from line [start] and lie outside every boneyard, relative to the text of those lines joined
  /// by newlines, ascending: the notes the styled editor holds as inline placeholders. A note
  /// running past those lines is left out.
  List<(int, int)> noteRangesOfNode(int start, int count) {
    final nodeStart = lineStarts[start];
    final nodeEnd = lineEnds[start + count - 1];
    return [
      for (final span in _spansFrom(start, nodeEnd))
        if (!span.isBoneyard && span.start >= nodeStart && span.end <= nodeEnd)
          (span.start - nodeStart, span.end - nodeStart),
    ];
  }

  /// Get the spans that start before [end], from the first one reaching line [line].
  Iterable<FountainCommentSpan> _spansFrom(int line, int end) sync* {
    for (var index = _firstSpanByLine[line]; index < spans.length; index++) {
      if (spans[index].start >= end) {
        return;
      }
      yield spans[index];
    }
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

  /// Tell, of [line], whether it has a character that is not whitespace and whether one of them
  /// lies outside every one of [ranges].
  static (bool, bool) _coverageOf(String line, List<(int, int)> ranges) {
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
        return (true, true);
      }
    }
    return (hasText, false);
  }
}
