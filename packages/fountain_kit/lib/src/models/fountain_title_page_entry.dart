// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_title_page.dart';

/// A single `key: value` entry of a [FountainTitlePage].
///
/// A title page entry's value can span several lines (indented continuation
/// lines in the source); each line is kept as a separate element of
/// [values], in source order.
///
/// [sourceRange] does not participate in equality, for the same reason it
/// does not on `FountainBlock`: content equality should not depend on where
/// in a source string an entry was parsed from.
class FountainTitlePageEntry extends Equatable {
  /// The entry key, exactly as written in the source (for example `Draft
  /// date`), before the colon.
  final String key;

  /// The entry value lines, in source order. Always has at least one
  /// element; a key with no text after the colon and no continuation lines
  /// yields a single empty string.
  final List<String> values;

  /// The location, in the original source, of this entry (key and all of
  /// its value lines).
  final FountainSourceRange sourceRange;

  /// Get the entry value lines joined with spaces, for callers that only care
  /// about a single-line representation.
  String get joinedValue => values.join(' ');

  /// Create a [FountainTitlePageEntry].
  const FountainTitlePageEntry({
    required this.key,
    required this.values,
    required this.sourceRange,
  });

  /// Describe this [FountainTitlePageEntry] for debugging and logging.
  @override
  String toString() => 'FountainTitlePageEntry($key: $values)';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [key, values];
}
