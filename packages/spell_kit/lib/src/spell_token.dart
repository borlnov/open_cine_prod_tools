// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';
import 'package:spell_kit/src/spell_range.dart';
import 'package:spell_kit/src/spell_tokenizer.dart';

/// One word-shaped run of text found by [spellTokensIn].
@immutable
class SpellToken {
  /// The token's text, already trimmed of leading/trailing apostrophes and
  /// hyphens.
  final String text;

  /// The token's span in the text it was found in, in UTF-16 code units.
  final SpellRange range;

  /// Hash [text] and [range].
  @override
  int get hashCode => Object.hash(text, range);

  /// Creates a [SpellToken].
  const SpellToken(this.text, this.range);

  /// Compare by [text] and [range].
  @override
  bool operator ==(Object other) =>
      other is SpellToken && other.text == text && other.range == range;

  /// Describe this [SpellToken] for debugging and logging.
  @override
  String toString() => 'SpellToken($text, $range)';
}
