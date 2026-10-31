// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A parsed `REP` line: a substitution the suggester tries when a word is
/// unknown, in the language's own idiom of common typos.
class HunspellRepRule {
  /// Creates a [HunspellRepRule].
  const HunspellRepRule({
    required this.from,
    required this.to,
    required this.anchoredStart,
    required this.anchoredEnd,
  });

  /// The text to replace (hunspell's `_` already translated to a space,
  /// and its `^`/`$` anchor, if any, already stripped off).
  final String from;

  /// The replacement text (hunspell's `_` already translated to a space).
  final String to;

  /// Whether the rule only applies at the start of the word (hunspell's
  /// `^from`).
  final bool anchoredStart;

  /// Whether the rule only applies at the end of the word (hunspell's
  /// `from$`).
  final bool anchoredEnd;
}
