// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:spell_kit/src/hunspell_compound_rule.dart';
import 'package:spell_kit/src/hunspell_compound_rule_quantifier.dart';

/// One element of a [HunspellCompoundRule]'s pattern: a flag a compound
/// piece must carry, and how many consecutive pieces may carry it.
class HunspellCompoundRuleElement {
  /// The flag a compound piece must carry to satisfy this element.
  final String flag;

  /// How many consecutive pieces this element accepts.
  final HunspellCompoundRuleQuantifier quantifier;

  /// Create a [HunspellCompoundRuleElement].
  const HunspellCompoundRuleElement({required this.flag, required this.quantifier});
}
