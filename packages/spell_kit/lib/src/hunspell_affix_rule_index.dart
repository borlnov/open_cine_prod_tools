// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:spell_kit/src/hunspell_affix_file.dart';

/// An index over a [HunspellAffixFile]'s rules, narrowing the set a lookup
/// has to try.
///
/// Affix stripping only ever considers a rule whose `append` text the typed
/// word actually carries, so suffix rules are bucketed by the **last**
/// character of their `append` and prefix rules by the **first**, with the
/// empty-`append` rules — which apply to any word at all — kept in a bucket
/// of their own and added to every answer.
///
/// How much this narrows is the dictionary's business, not the index's, and
/// the French file is the honest measure of it: of its 5 184 suffix rules, a
/// word ending in `g` weighs 23 and one ending in `e` weighs 538, but one
/// ending in `s` still weighs 2 018 — thousands of conjugation suffixes
/// genuinely share that ending, and no single-character index can do better.
/// Indexing on the last *two* characters was measured and only halves that
/// worst case (2 018 to 1 027) for real added complexity, so it was not
/// taken: what makes typing cheap in the steady state is the checker's memo,
/// and this index is what keeps the first, uncached look at a word from
/// touching every rule in the file.
class HunspellAffixRuleIndex {
  /// Builds a [HunspellAffixRuleIndex] over [affixFile]'s rules.
  HunspellAffixRuleIndex(HunspellAffixFile affixFile) {
    for (final rule in affixFile.suffixRules) {
      final key = rule.append.isEmpty
          ? ''
          : rule.append[rule.append.length - 1];
      (_suffixByTail[key] ??= []).add(rule);
    }
    for (final rule in affixFile.prefixRules) {
      final key = rule.append.isEmpty ? '' : rule.append[0];
      (_prefixByHead[key] ??= []).add(rule);
    }
  }

  /// Suffix rules bucketed by the last character of their `append`, with
  /// the empty-`append` rules filed under the empty string key.
  final Map<String, List<HunspellAffixRule>> _suffixByTail = {};

  /// Prefix rules bucketed by the first character of their `append`, with
  /// the empty-`append` rules filed under the empty string key.
  final Map<String, List<HunspellAffixRule>> _prefixByHead = {};

  /// The suffix rules worth trying against [form]: those whose `append`
  /// ends in [form]'s last character, plus every empty-`append` rule.
  Iterable<HunspellAffixRule> suffixRulesFor(String form) sync* {
    final tailKey = form.isEmpty ? '' : form[form.length - 1];
    yield* _suffixByTail[tailKey] ?? const [];
    if (tailKey.isNotEmpty) {
      yield* _suffixByTail[''] ?? const [];
    }
  }

  /// The prefix rules worth trying against [form]: those whose `append`
  /// starts with [form]'s first character, plus every empty-`append` rule.
  Iterable<HunspellAffixRule> prefixRulesFor(String form) sync* {
    final headKey = form.isEmpty ? '' : form[0];
    yield* _prefixByHead[headKey] ?? const [];
    if (headKey.isNotEmpty) {
      yield* _prefixByHead[''] ?? const [];
    }
  }
}
