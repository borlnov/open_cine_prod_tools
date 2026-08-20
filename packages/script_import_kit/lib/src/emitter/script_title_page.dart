// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:meta/meta.dart';

/// The title page a reader could make out of a foreign file's own front
/// matter, in the six fields Open Cine Prod Tools writes.
///
/// The six keys and their order mirror the ones the application's own title
/// page editor uses, so a screenplay coming in through this package and one
/// typed in the editor produce the very same block rather than two
/// differently ordered ones. They are repeated here rather than imported:
/// this package knows nothing of the application that consumes it.
@immutable
class ScriptTitlePage {
  /// Creates a [ScriptTitlePage].
  const ScriptTitlePage({
    this.title,
    this.credit,
    this.author,
    this.draftDate,
    this.contact = const [],
    this.source,
  });

  /// A placeholder source range for the entries [toEntries] builds:
  /// [FountainTitlePageWriter] only ever reads an entry's key and values,
  /// never where it came from, and these entries came from no Fountain
  /// source at all.
  static const FountainSourceRange _placeholderRange = FountainSourceRange(
    startLine: 0,
    endLine: 0,
    startOffset: 0,
    endOffset: 0,
  );

  /// The screenplay's title.
  final String? title;

  /// The credit line introducing the author (`Written by`, `Screenplay by`,
  /// `Scénario de`…).
  final String? credit;

  /// The author's name.
  final String? author;

  /// The draft's own designation (`First draft`, `Version 3`…).
  final String? draftDate;

  /// The contact block, one element per line — an address and a phone
  /// number are two lines of one same entry, not two entries.
  final List<String> contact;

  /// The work the screenplay was adapted from.
  final String? source;

  /// Renders the fields that carry something as Fountain title page
  /// entries, in the canonical order, ready for
  /// [FountainTitlePageWriter.apply].
  List<FountainTitlePageEntry> toEntries() => [
    ..._entry('Title', _lines(title)),
    ..._entry('Credit', _lines(credit)),
    ..._entry('Author', _lines(author)),
    ..._entry('Draft date', _lines(draftDate)),
    ..._entry('Contact', contact),
    ..._entry('Source', _lines(source)),
  ];

  /// [value] as the single value line of an entry, or no line at all when
  /// the field was never filled in.
  List<String> _lines(String? value) => value == null ? const [] : [value];

  /// One entry for [key], or nothing at all when [values] holds no line
  /// with any text on it.
  List<FountainTitlePageEntry> _entry(String key, List<String> values) {
    final kept = [
      for (final value in values)
        if (value.trim().isNotEmpty) value.trim(),
    ];
    if (kept.isEmpty) {
      return const [];
    }
    return [
      FountainTitlePageEntry(
        key: key,
        values: kept,
        sourceRange: _placeholderRange,
      ),
    ];
  }
}
