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

  /// Build the layout of [lines], one source line each (a blank line is an empty string).
  factory OcptWysiwygCommentLayout.fromLines(List<String> lines) {
    final text = lines.join("\n");
    final spans = FountainCommentSpans.of(text);
    final classificationLines = FountainCommentSpans.scrubForClassification(text).split("\n");

    final isInertByLine = <bool>[];
    final commentRangesByLine = <List<(int, int)>>[];
    var lineStart = 0;
    for (final line in lines) {
      final lineEnd = lineStart + line.length;
      final ranges = <(int, int)>[
        for (final span in spans)
          if (span.start < lineEnd && span.end > lineStart)
            (
              span.start > lineStart ? span.start - lineStart : 0,
              span.end < lineEnd ? span.end - lineStart : line.length,
            ),
      ];
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

  /// Tell whether [line] has text and every one of its non-whitespace characters lies inside one of
  /// [ranges].
  static bool _isWhollyCovered(String line, List<(int, int)> ranges) {
    var hasText = false;
    for (var index = 0; index < line.length; index++) {
      if (line[index].trim().isEmpty) {
        continue;
      }
      hasText = true;
      if (!ranges.any((range) => index >= range.$1 && index < range.$2)) {
        return false;
      }
    }
    return hasText;
  }
}
