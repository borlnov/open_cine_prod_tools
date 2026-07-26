// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// A single run of inline-styled text, carrying independent style booleans
/// rather than the single-value `FountainInlineStyle` enum used by
/// `FountainInlineSpan`.
///
/// Fountain emphasis nests one level deep (for example `_**bold and
/// underlined**_`), which a single-value enum cannot represent. A
/// [FountainStyledRun] instead exposes [isBold], [isItalic] and
/// [isUnderline] as independent flags that a caller (typically a WYSIWYG
/// text editor) can combine freely, plus [isNote] for an inline authoring
/// note. A note run is always atomic: it is never combined with the other
/// three flags, and its [text] already contains its `[[`/`]]` delimiters
/// (unlike emphasis runs, whose [text] never contains their emphasis
/// markers), so that a note reads as plain, dimmed text rather than as
/// hidden markup.
class FountainStyledRun extends Equatable {
  /// Creates a [FountainStyledRun].
  const FountainStyledRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isNote = false,
  });

  /// The run's text.
  ///
  /// For an emphasis run (any combination of [isBold], [isItalic],
  /// [isUnderline]) this is the rendered text with emphasis markers already
  /// stripped. For a note run ([isNote] set) this includes the `[[`/`]]`
  /// delimiters verbatim, since a note's brackets stay visible on screen.
  final String text;

  /// Whether [text] is rendered bold (`**text**`, or the bold half of
  /// `***text***`).
  final bool isBold;

  /// Whether [text] is rendered italic (`*text*`, or the italic half of
  /// `***text***`).
  final bool isItalic;

  /// Whether [text] is rendered underlined (`_text_`).
  final bool isUnderline;

  /// Whether this run is an inline authoring note (`[[text]]`). A note run
  /// never combines with [isBold], [isItalic] or [isUnderline].
  final bool isNote;

  @override
  List<Object?> get props => [text, isBold, isItalic, isUnderline, isNote];

  @override
  String toString() {
    final flags = [
      if (isBold) 'bold',
      if (isItalic) 'italic',
      if (isUnderline) 'underline',
      if (isNote) 'note',
    ];
    final style = flags.isEmpty ? 'plain' : flags.join('+');
    return 'FountainStyledRun($style, "$text")';
  }
}
