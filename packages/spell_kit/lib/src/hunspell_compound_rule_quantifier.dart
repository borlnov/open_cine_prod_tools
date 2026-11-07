// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:spell_kit/src/hunspell_compound_rule_element.dart';

/// The quantifier a [HunspellCompoundRuleElement] carries, mirroring a
/// (tiny) regular-expression alphabet over dictionary-entry flags.
enum HunspellCompoundRuleQuantifier {
  /// The element must be matched by exactly one compound piece.
  one,

  /// The element may be matched by zero or more compound pieces, each
  /// carrying the element's flag (hunspell's `*`).
  zeroOrMore,

  /// The element may be matched by zero or one compound piece carrying the
  /// element's flag (hunspell's `?`).
  zeroOrOne,
}
