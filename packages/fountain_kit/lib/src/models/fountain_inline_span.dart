// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';

/// The inline emphasis style carried by a [FountainInlineSpan].
enum FountainInlineStyle {
  /// Unstyled text, not wrapped in any emphasis marker.
  plain,

  /// Text wrapped in single asterisks, `*like this*`.
  italic,

  /// Text wrapped in double asterisks, `**like this**`.
  bold,

  /// Text wrapped in triple asterisks, `***like this***`.
  boldItalic,

  /// Text wrapped in underscores, `_like this_`.
  underline,

  /// Text wrapped in double square brackets, `[[like this]]`, an inline
  /// authoring note that is not part of the printed screenplay.
  note,
}

/// A single run of inline-styled text produced by parsing Fountain emphasis
/// markers.
///
/// Emphasis in Fountain never spans a line break, so a [FountainInlineSpan]
/// always covers text from a single source line.
class FountainInlineSpan extends Equatable {
  /// Creates a [FountainInlineSpan].
  const FountainInlineSpan({
    required this.text,
    required this.style,
    required this.sourceRange,
  });

  /// The rendered text of this span, with any emphasis or note markers
  /// already stripped and escape sequences already resolved.
  final String text;

  /// The emphasis style applied to [text].
  final FountainInlineStyle style;

  /// The location, in the original source, of the raw text this span was
  /// parsed from (including its emphasis/note markers).
  final FountainSourceRange sourceRange;

  @override
  List<Object?> get props => [text, style, sourceRange];

  @override
  String toString() => 'FountainInlineSpan($style, ${_quote(text)})';

  /// Wraps [value] in double quotes for use in [toString] output.
  static String _quote(String value) => '"$value"';
}
