// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:spell_kit/src/hunspell_compound_rule_element.dart';

/// A parsed `COMPOUNDRULE` pattern: a sequence of
/// [HunspellCompoundRuleElement]s a word must be splittable into, each
/// piece drawn from the dictionary and carrying the matching element's
/// flag.
class HunspellCompoundRule {
  /// The pattern's elements, in the order they must be matched.
  final List<HunspellCompoundRuleElement> elements;

  /// Create a [HunspellCompoundRule].
  const HunspellCompoundRule(this.elements);
}
