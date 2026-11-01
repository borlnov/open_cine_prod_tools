// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A parsed `BREAK` pattern: text that splits a word into parts that must
/// each be independently known, or a leading/trailing occurrence that may
/// simply be stripped off.
class HunspellBreakPattern {
  /// The literal text of the pattern, with its `^`/`$` anchor (if any)
  /// already stripped off.
  final String text;

  /// Whether the pattern is anchored to the start of the word (hunspell's
  /// `^p`), meaning a leading occurrence of [text] may be stripped off.
  final bool anchoredStart;

  /// Whether the pattern is anchored to the end of the word (hunspell's
  /// `p$`), meaning a trailing occurrence of [text] may be stripped off.
  final bool anchoredEnd;

  /// Create a [HunspellBreakPattern].
  const HunspellBreakPattern({
    required this.text,
    required this.anchoredStart,
    required this.anchoredEnd,
  });
}
