// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A parsed `ICONV`/`OCONV` line: a character (or short sequence)
/// substitution applied wholesale, not anchored to a position.
class HunspellConvRule {
  /// Creates a [HunspellConvRule].
  const HunspellConvRule({required this.from, required this.to});

  /// The text to replace.
  final String from;

  /// The replacement text.
  final String to;
}
