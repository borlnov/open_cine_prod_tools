// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:spell_kit/spell_kit.dart';
import 'package:test/test.dart';

/// Loads the real bundled French dictionary, the slower of the two (5 184
/// suffix rules), so the memo's effect is measurable.
SpellChecker _frenchChecker() {
  final affix = File('../../assets/dictionaries/fr/index.aff').readAsStringSync();
  final dictionary = File(
    '../../assets/dictionaries/fr/index.dic',
  ).readAsStringSync();
  return SpellChecker(
    SpellDictionary.parse(affix: affix, dictionary: dictionary),
  );
}

/// Fifty distinct French words: enough that neither pass is a single
/// sample, and all of them known, so the cold pass pays the full affix
/// lookup rather than failing out early.
List<String> _sampleWords() => const [
  'crépuscule', 'fondu', 'travelling', 'silhouette', 'ruelle', 'pluie',
  'murmure', 'escalier', 'fenêtre', 'cigarette', 'chuchotèrent',
  'aperçoive', 'irions', 'eussent', "l'homme", "aujourd'hui", "qu'elle",
  "presqu'île", "s'approche", 'arrière-plan', 'contre-jour', 'peut-être',
  'regarde', 'lentement', 'tourne', 'obscurité', 'visage', 'comptoir',
  'trottoir', 'réveille', 'maison', 'jardin', 'lumière', 'ombre', 'porte',
  'chemin', 'rivière', 'montagne', 'ciel', 'nuage', 'arbre', 'feuille',
  'pierre', 'sable', 'vague', 'orage', 'tonnerre', 'éclair', 'brouillard',
  'neige',
];

void main() {
  group('the affix rule index', () {
    late SpellChecker checker;

    setUpAll(() => checker = _frenchChecker());

    test('a lookup never weighs the whole affix file', () {
      // The shape the index exists for, asserted as a fraction and never
      // as a count: how far it narrows is the dictionary's business. The
      // French file is the unflattering case — thousands of conjugation
      // suffixes end in "s", so a word ending in "s" still weighs about
      // 2 000 of the 5 184 rules, where one ending in "g" weighs 23.
      final allSuffixRules = checker.dictionary.affixFile.suffixRules;
      expect(allSuffixRules, hasLength(greaterThan(5000)));

      for (final word in _sampleWords()) {
        expect(
          checker.ruleIndex.suffixRulesFor(word).length,
          lessThan(allSuffixRules.length ~/ 2),
          reason: 'the suffix bucket for "$word" is not a narrowing',
        );
        expect(
          checker.ruleIndex.prefixRulesFor(word).length,
          lessThan(checker.dictionary.affixFile.prefixRules.length),
          reason: 'the prefix bucket for "$word" is not a narrowing',
        );
      }
    });

    test('a favourable word ending narrows by two orders of magnitude', () {
      // The other end of the same range, pinned so that a regression
      // turning the index back into "try every rule" cannot hide behind
      // the generous bound of the test above.
      final allSuffixRules = checker.dictionary.affixFile.suffixRules;
      expect(
        checker.ruleIndex.suffixRulesFor('travelling').length,
        lessThan(allSuffixRules.length ~/ 100),
      );
    });

    test('an empty-append rule is offered whatever the word ends in', () {
      // The empty-`append` bucket applies to every word, so it must be
      // added to each answer rather than being reachable only through the
      // (never-matching) empty-string key.
      final emptyAppendSuffixRules = checker.dictionary.affixFile.suffixRules
          .where((rule) => rule.append.isEmpty)
          .toSet();
      expect(emptyAppendSuffixRules, isNotEmpty);
      expect(
        checker.ruleIndex.suffixRulesFor('homme').toSet(),
        containsAll(emptyAppendSuffixRules),
      );
    });
  });

  test(
    'a warm pass is an order of magnitude cheaper than a cold one',
    () {
      final checker = _frenchChecker();
      final words = _sampleWords();

      final cold = Stopwatch()..start();
      for (final word in words) {
        checker.isKnown(word);
      }
      cold.stop();

      final warm = Stopwatch()..start();
      for (final word in words) {
        checker.isKnown(word);
      }
      warm.stop();

      // A shape assertion, never a wall-clock threshold: a CI runner's
      // timing is not a specification, but a memoized pass over words
      // already seen must be dramatically cheaper than the first pass.
      // The order of magnitude §2.3 asks for is asserted literally, at
      // 10x: the warm pass is a map read per word and measures three
      // orders of magnitude cheaper here, so 10x leaves ample room for a
      // slow or loaded runner without weakening into a truism.
      expect(
        warm.elapsedMicroseconds * 10,
        lessThan(cold.elapsedMicroseconds),
        reason:
            'warm=${warm.elapsedMicroseconds}us cold=${cold.elapsedMicroseconds}us',
      );
    },
  );

  test('clearing the extra words drops the memo, making the pass cold again', () {
    final checker = _frenchChecker();
    final words = _sampleWords();

    for (final word in words) {
      checker.isKnown(word);
    }
    final warm = Stopwatch()..start();
    for (final word in words) {
      checker.isKnown(word);
    }
    warm.stop();

    checker.setExtraWords({'un-mot-appris'});

    final afterClear = Stopwatch()..start();
    for (final word in words) {
      checker.isKnown(word);
    }
    afterClear.stop();

    // The same shape assertion, and the same 10x margin, as the test
    // above: what is asserted is that the pass went cold again, not how
    // many microseconds a runner took to notice.
    expect(
      warm.elapsedMicroseconds * 10,
      lessThan(afterClear.elapsedMicroseconds),
      reason:
          'warm=${warm.elapsedMicroseconds}us '
          'afterClear=${afterClear.elapsedMicroseconds}us',
    );
  });
}
