// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:spell_kit/spell_kit.dart';
import 'package:test/test.dart';

/// Loads the real bundled `.aff`/`.dic` pair for [language] (`fr` or
/// `en_GB`) and builds a [SpellChecker] over it. The dictionaries live in
/// the repository's `assets/dictionaries/`, two levels up from this
/// package.
SpellChecker _checkerFor(String language) {
  final affix = File(
    '../../assets/dictionaries/$language/index.aff',
  ).readAsStringSync();
  final dictionary = File(
    '../../assets/dictionaries/$language/index.dic',
  ).readAsStringSync();
  return SpellChecker(
    SpellDictionary.parse(affix: affix, dictionary: dictionary),
  );
}

void main() {
  group('French (real dictionary)', () {
    late SpellChecker checker;

    setUpAll(() => checker = _checkerFor('fr'));

    test('30 correct words raise no false alarm', () {
      // Conjugations (chuchotèrent, aperçoive, irions, eussent), elisions
      // written as one token (l'homme, aujourd'hui, qu'elle, presqu'île,
      // s'approche), hyphenated compounds (arrière-plan, contre-jour,
      // peut-être) and screenplay vocabulary (crépuscule, fondu,
      // travelling) are the hard cases this engine exists for.
      const words = [
        'crépuscule', 'fondu', 'travelling', 'silhouette', 'ruelle',
        'pluie', 'murmure', 'escalier', 'fenêtre', 'cigarette',
        'chuchotèrent', 'aperçoive', 'irions', 'eussent', "l'homme",
        "aujourd'hui", "qu'elle", "presqu'île", "s'approche",
        'arrière-plan', 'contre-jour', 'peut-être', 'regarde', 'lentement',
        'tourne', 'obscurité', 'visage', 'comptoir', 'trottoir', 'réveille',
      ];
      for (final word in words) {
        expect(checker.isKnown(word), isTrue, reason: '"$word" should be known');
      }
    });

    test('7 misspellings are reported unknown', () {
      const words = [
        'crepuscul', 'silouhette', 'frenetre', 'obscurté', 'trotoir',
        'murmurre', "qu'ellle",
      ];
      for (final word in words) {
        expect(
          checker.isKnown(word),
          isFalse,
          reason: '"$word" should be unknown',
        );
      }
    });
  });

  group('English (real dictionary)', () {
    late SpellChecker checker;

    setUpAll(() => checker = _checkerFor('en_GB'));

    test('20 correct words raise no false alarm', () {
      const words = [
        'dusk', 'silhouette', 'alley', 'rain', 'whisper', 'staircase',
        'window', 'cigarette', 'close-up', 'doorway', 'flickering',
        'hallway', 'footsteps', 'streetlight', 'shoulder', 'briefcase',
        'corridor', 'rooftop', 'headlights', 'unlocks',
      ];
      for (final word in words) {
        expect(checker.isKnown(word), isTrue, reason: '"$word" should be known');
      }
    });

    test('"close-up" is known only through the declared-none BREAK default', () {
      // en_GB declares no BREAK directive at all, so hunspell's default
      // (-, ^-, -$) applies and "close-up" is checked as "close" + "up",
      // both of which the dictionary has on their own. Every hyphenated
      // English compound in the probe list above depends on this.
      expect(checker.dictionary.affixFile.breakPatterns, isNotEmpty);
      expect(checker.isKnown('close-up'), isTrue);
    });

    test('6 misspellings are reported unknown', () {
      const words = [
        'dusck', 'silouette', 'allley', 'whipser', 'stairkase', 'corrider',
      ];
      for (final word in words) {
        expect(
          checker.isKnown(word),
          isFalse,
          reason: '"$word" should be unknown',
        );
      }
    });

    test('"backlit" is unknown: the dictionary\'s own gap, not the engine\'s', () {
      // This is the SCOWL size-60 dictionary's own gap, not a defect in
      // the engine — the argument for M4's "add to the project's
      // dictionary" feature, not something this package can fix.
      expect(checker.isKnown('backlit'), isFalse);
    });
  });
}
