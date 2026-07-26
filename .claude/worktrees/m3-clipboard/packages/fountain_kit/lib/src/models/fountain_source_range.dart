// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A span of source text that a parsed Fountain element was built from.
///
/// Every [FountainSourceRange] refers back into the exact [String] that was
/// parsed: [startOffset] and [endOffset] are character offsets into that
/// string, and [startLine] / [endLine] are the corresponding 0-based line
/// numbers. This lets tooling (for example a text editor) map a parsed
/// element back onto the original text without re-scanning it.
class FountainSourceRange extends Equatable {
  /// Creates a [FountainSourceRange].
  ///
  /// [startLine] and [endLine] are 0-based and inclusive. [startOffset] is
  /// the character offset of the first character covered by this range;
  /// [endOffset] is the offset one past the last character covered by this
  /// range (i.e. `source.substring(startOffset, endOffset)` yields the
  /// covered text).
  const FountainSourceRange({
    required this.startLine,
    required this.endLine,
    required this.startOffset,
    required this.endOffset,
  }) : assert(startLine >= 0, 'startLine must not be negative'),
       assert(endLine >= startLine, 'endLine must not precede startLine'),
       assert(startOffset >= 0, 'startOffset must not be negative'),
       assert(
         endOffset >= startOffset,
         'endOffset must not precede startOffset',
       );

  /// The 0-based line number of the first line covered by this range.
  final int startLine;

  /// The 0-based line number of the last line covered by this range.
  final int endLine;

  /// The character offset of the first character covered by this range.
  final int startOffset;

  /// The character offset one past the last character covered by this range.
  final int endOffset;

  /// Returns a new range that covers both this range and [other].
  FountainSourceRange merge(FountainSourceRange other) => FountainSourceRange(
    startLine: startLine < other.startLine ? startLine : other.startLine,
    endLine: endLine > other.endLine ? endLine : other.endLine,
    startOffset: startOffset < other.startOffset
        ? startOffset
        : other.startOffset,
    endOffset: endOffset > other.endOffset ? endOffset : other.endOffset,
  );

  @override
  List<Object?> get props => [startLine, endLine, startOffset, endOffset];

  @override
  String toString() =>
      'FountainSourceRange(lines $startLine-$endLine, '
      'offsets $startOffset-$endOffset)';
}
