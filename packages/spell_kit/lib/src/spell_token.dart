// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';
import 'package:spell_kit/src/spell_range.dart';
import 'package:spell_kit/src/spell_tokenizer.dart';

/// One word-shaped run of text found by [spellTokensIn].
@immutable
class SpellToken {
  /// Creates a [SpellToken].
  const SpellToken(this.text, this.range);

  /// The token's text, already trimmed of leading/trailing apostrophes and
  /// hyphens.
  final String text;

  /// The token's span in the text it was found in, in UTF-16 code units.
  final SpellRange range;

  @override
  bool operator ==(Object other) =>
      other is SpellToken && other.text == text && other.range == range;

  @override
  int get hashCode => Object.hash(text, range);

  @override
  String toString() => 'SpellToken($text, $range)';
}
