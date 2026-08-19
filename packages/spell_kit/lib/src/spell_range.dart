// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';

/// A half-open span of UTF-16 code unit offsets into a checked text.
///
/// This is what a spell checker's misspelling search returns and what a
/// tokenizer's word token carries: the offsets it holds are UTF-16 code
/// units, the unit `TextRange`, `AttributedText` and `TextEditingValue`
/// all count in, so a caller can feed one straight into any of those with
/// no conversion. The package has no `equatable` dependency, so
/// `==`/`hashCode` are written by hand here, the way `fountain_kit` writes
/// them for its own non-`Equatable` types.
@immutable
class SpellRange {
  /// Creates a [SpellRange] covering `[start, end)`.
  const SpellRange(this.start, this.end)
    : assert(start >= 0, 'start must not be negative'),
      assert(end >= start, 'end must not precede start');

  /// The offset of the first UTF-16 code unit covered by this range.
  final int start;

  /// The offset one past the last UTF-16 code unit covered by this range.
  final int end;

  @override
  bool operator ==(Object other) =>
      other is SpellRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SpellRange($start, $end)';
}
