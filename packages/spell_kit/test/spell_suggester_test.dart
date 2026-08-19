// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:spell_kit/spell_kit.dart';
import 'package:test/test.dart';

/// Loads the `test/fixtures/suggestions` fixture and builds a
/// [SpellSuggester] over it.
SpellSuggester _suggesterFor(String name) {
  final affix = File('test/fixtures/$name/index.aff').readAsStringSync();
  final dictionary = File(
    'test/fixtures/$name/index.dic',
  ).readAsStringSync();
  final checker = SpellChecker(
    SpellDictionary.parse(affix: affix, dictionary: dictionary),
  );
  return SpellSuggester(checker);
}

/// Loads the real bundled French dictionary and builds a [SpellSuggester]
/// over it, for the MAP (accent) tier test.
SpellSuggester _frenchSuggester() {
  final affix = File('../../assets/dictionaries/fr/index.aff').readAsStringSync();
  final dictionary = File(
    '../../assets/dictionaries/fr/index.dic',
  ).readAsStringSync();
  final checker = SpellChecker(
    SpellDictionary.parse(affix: affix, dictionary: dictionary),
  );
  return SpellSuggester(checker);
}

void main() {
  group('the suggestions fixture', () {
    late SpellSuggester suggester;

    setUp(() => suggester = _suggesterFor('suggestions'));

    test('the REP tier fires: "ph" -> "f" turns "phone" into "fone"', () {
      // "fone" (4 letters) is not reachable from "phone" (5 letters) by any
      // single deletion/insertion/replacement/transposition, so this
      // result can only come from the REP table.
      expect(suggester.suggestionsFor('phone'), ['fone']);
    });

    test('the one-edit tier fires on a single-character typo', () {
      // "cot" is one replacement away from both "cat" (position 1) and
      // "lot" (position 0); neither is reachable through REP or a split.
      final suggestions = suggester.suggestionsFor('cot');
      expect(suggestions, containsAll(['cat', 'lot']));
      expect(suggestions, hasLength(2));
    });

    test('the split tier fires: "acat" splits into two known words', () {
      expect(suggester.suggestionsFor('acat'), contains('a cat'));
    });

    test('a NOSUGGEST stem is never offered as a suggestion', () {
      // "bam" is one replacement away only from "bad", which is flagged
      // NOSUGGEST: it is a known word (checked elsewhere), but never a
      // suggestion.
      expect(suggester.suggestionsFor('bam'), isEmpty);
    });

    test('the result is capped at the requested limit', () {
      final suggestions = suggester.suggestionsFor('cot', limit: 1);
      expect(suggestions, hasLength(1));
      expect(['cat', 'lot'], contains(suggestions.single));
    });

    test("the typed word's capitalisation is carried onto the suggestion", () {
      expect(suggester.suggestionsFor('Phone'), ['Fone']);
      expect(suggester.suggestionsFor('PHONE'), ['FONE']);
    });
  });

  test('the MAP tier fires: French accent substitution', () {
    // The plan's own example: "sequence" (no accent) becomes "séquence"
    // by substituting one "e" for "é", both members of the same MAP group.
    final suggester = _frenchSuggester();
    expect(suggester.suggestionsFor('sequence'), contains('séquence'));
  });
}
