// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/src/models/fountain_inline_style.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';

/// A single run of inline-styled text produced by parsing Fountain emphasis
/// markers.
///
/// Emphasis in Fountain never spans a line break, so a [FountainInlineSpan]
/// always covers text from a single source line.
class FountainInlineSpan extends Equatable {
  /// The rendered text of this span, with any emphasis or note markers
  /// already stripped and escape sequences already resolved.
  final String text;

  /// The emphasis style applied to [text].
  final FountainInlineStyle style;

  /// The location, in the original source, of the raw text this span was
  /// parsed from (including its emphasis/note markers).
  final FountainSourceRange sourceRange;

  /// Create a [FountainInlineSpan].
  const FountainInlineSpan({required this.text, required this.style, required this.sourceRange});

  /// Describe this [FountainInlineSpan] for debugging and logging.
  @override
  String toString() => 'FountainInlineSpan($style, ${_quote(text)})';

  /// Wrap [value] in double quotes for use in [toString] output.
  static String _quote(String value) => '"$value"';

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [text, style, sourceRange];
}
