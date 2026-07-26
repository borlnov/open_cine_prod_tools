// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';

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
  /// Creates a [FountainTitlePageEntry].
  const FountainTitlePageEntry({
    required this.key,
    required this.values,
    required this.sourceRange,
  });

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

  /// The entry value lines joined with spaces, for callers that only care
  /// about a single-line representation.
  String get joinedValue => values.join(' ');

  @override
  List<Object?> get props => [key, values];

  @override
  String toString() => 'FountainTitlePageEntry($key: $values)';
}

/// The title page of a Fountain document: an ordered list of `key: value`
/// entries that appear before the first blank line of the source.
class FountainTitlePage extends Equatable {
  /// Creates a [FountainTitlePage].
  const FountainTitlePage({required this.entries, required this.sourceRange});

  /// The title page entries, in source order.
  final List<FountainTitlePageEntry> entries;

  /// The location, in the original source, of the whole title page block.
  final FountainSourceRange sourceRange;

  /// Returns the first entry whose [FountainTitlePageEntry.key] matches
  /// [key] case-insensitively, or `null` if there is none.
  FountainTitlePageEntry? entry(String key) {
    for (final candidate in entries) {
      if (candidate.key.toLowerCase() == key.toLowerCase()) {
        return candidate;
      }
    }
    return null;
  }

  /// The `Title` entry's joined value, or `null` if absent.
  String? get title => entry('Title')?.joinedValue;

  /// The `Credit` entry's joined value, or `null` if absent.
  String? get credit => entry('Credit')?.joinedValue;

  /// The `Author` (or `Authors`) entry's value lines, split on commas and
  /// the word "and", or an empty list if absent.
  List<String> get authors {
    final foundEntry = entry('Author') ?? entry('Authors');
    if (foundEntry == null) {
      return const [];
    }
    return foundEntry.joinedValue
        .split(RegExp(r',|\band\b', caseSensitive: false))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  /// The `Source` entry's joined value, or `null` if absent.
  String? get source => entry('Source')?.joinedValue;

  /// The `Draft date` entry's joined value, or `null` if absent.
  String? get draftDate => entry('Draft date')?.joinedValue;

  /// The `Contact` entry's value lines, or an empty list if absent.
  List<String> get contact => entry('Contact')?.values ?? const [];

  @override
  List<Object?> get props => [entries];

  @override
  String toString() => 'FountainTitlePage($entries)';
}
