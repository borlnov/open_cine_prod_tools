// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A parsed `ICONV`/`OCONV` line: a character (or short sequence)
/// substitution applied wholesale, not anchored to a position.
class HunspellConvRule {
  /// The text to replace.
  final String from;

  /// The replacement text.
  final String to;

  /// Create a [HunspellConvRule].
  const HunspellConvRule({required this.from, required this.to});
}
