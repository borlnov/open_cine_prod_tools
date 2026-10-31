// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_inline_span.dart';

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
