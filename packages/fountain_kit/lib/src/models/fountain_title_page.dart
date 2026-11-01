// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_title_page_entry.dart';

/// The title page of a Fountain document: an ordered list of `key: value`
/// entries that appear before the first blank line of the source.
class FountainTitlePage extends Equatable {
  /// The title page entries, in source order.
  final List<FountainTitlePageEntry> entries;

  /// The location, in the original source, of the whole title page block.
  final FountainSourceRange sourceRange;

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

  /// Creates a [FountainTitlePage].
  const FountainTitlePage({required this.entries, required this.sourceRange});

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

  @override
  String toString() => 'FountainTitlePage($entries)';

  @override
  List<Object?> get props => [entries];
}
