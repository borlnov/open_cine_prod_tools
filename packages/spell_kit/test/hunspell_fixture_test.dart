// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:spell_kit/spell_kit.dart';
import 'package:test/test.dart';

/// Loads the `.aff`/`.dic` fixture pair under `test/fixtures/[name]` and
/// builds a [SpellChecker] over it.
SpellChecker _checkerFor(String name) {
  final affix = File('test/fixtures/$name/index.aff').readAsStringSync();
  final dictionary = File(
    'test/fixtures/$name/index.dic',
  ).readAsStringSync();
  return SpellChecker(
    SpellDictionary.parse(affix: affix, dictionary: dictionary),
  );
}

void main() {
  group('flag width', () {
    test('the default (single-character) width is parsed', () {
      final checker = _checkerFor('basic');
      expect(checker.dictionary.affixFile.flagLong, isFalse);
      expect(checker.isKnown('happy'), isTrue);
    });

    test('FLAG long (two-character flags) is parsed', () {
      final checker = _checkerFor('long_flags');
      expect(checker.dictionary.affixFile.flagLong, isTrue);
      expect(checker.isKnown('word'), isTrue);
    });
  });

  group('basic fixture (single-character flags)', () {
    late SpellChecker checker;

    setUp(() => checker = _checkerFor('basic'));

    test('a suffix rule is applied', () {
      expect(checker.isKnown('happys'), isTrue);
    });

    test('a prefix rule is applied', () {
      expect(checker.isKnown('unhappy'), isTrue);
    });

    test('the prefix+suffix cross product is applied', () {
      // "happy" carries both the prefix's flag (U) and the suffix's flag
      // (S) directly in the dictionary, so both may combine.
      expect(checker.isKnown('unhappys'), isTrue);
    });

    test('a continuation class supplies a flag the stem lacks directly', () {
      // "do" only carries flag X. SFX X appends nothing (strip 0, append
      // 0) but grants continuation flag R, which is what lets PFX R apply
      // even though "do" itself never carries R.
      expect(checker.isKnown('redo'), isTrue);
    });

    test('NEEDAFFIX blocks the bare word but not an affixed one', () {
      expect(checker.isKnown('stem'), isFalse);
      expect(checker.isKnown('stems'), isTrue);
    });

    test('FORBIDDENWORD is never known, however it is typed', () {
      expect(checker.isKnown('badword'), isFalse);
      expect(checker.isKnown('Badword'), isFalse);
      expect(checker.isKnown('BADWORD'), isFalse);
    });

    test('BREAK falls back to the hunspell default when none is declared', () {
      // This fixture declares no BREAK directive at all, so hunspell's
      // documented default (-, ^-, -$) must be in force: "cat-up" is
      // known only because it splits into the two known pieces "cat" and
      // "up" on the unanchored "-" pattern.
      expect(checker.isKnown('cat-up'), isTrue);
      // A hyphenated word is not a blanket pass: one unknown piece still
      // fails the whole word.
      expect(checker.isKnown('cat-nonword'), isFalse);
    });
  });

  group('misspellingsIn', () {
    late SpellChecker checker;

    setUp(() => checker = _checkerFor('basic'));

    test('it reports the range of every unknown token, and only those', () {
      // "happy" and "cat" are known, "flurg" is not; the offsets are the
      // ones the caller paints an underline at.
      expect(checker.misspellingsIn('happy cat flurg'), const [
        SpellRange(10, 15),
      ]);
    });

    test('a token the tokenizer skips is never reported', () {
      // An all-caps token and a token holding a digit are both dropped
      // before the checker ever sees them, however unknown they are.
      expect(checker.misspellingsIn('FLURG cat flurg2'), isEmpty);
    });
  });

  group('extra words', () {
    late SpellChecker checker;

    setUp(() => checker = _checkerFor('basic'));

    test('a word with no interior capital matches case-insensitively', () {
      checker.setExtraWords({'Marie'});
      expect(checker.isKnown('Marie'), isTrue);
      expect(checker.isKnown('marie'), isTrue);
      expect(checker.isKnown('MARIE'), isTrue);
    });

    test('a word with an interior capital matches only that casing', () {
      checker.setExtraWords({'MacGuffin'});
      expect(checker.isKnown('MacGuffin'), isTrue);
      expect(checker.isKnown('macguffin'), isFalse);
    });

    test('setting them again drops a word that is no longer there', () {
      checker.setExtraWords({'flurg'});
      expect(checker.isKnown('flurg'), isTrue);
      // The memo must not keep answering "known" for a word the caller has
      // just un-learned: this is the round trip M5's dialog depends on.
      checker.setExtraWords(const {});
      expect(checker.isKnown('flurg'), isFalse);
    });
  });

  group('long_flags fixture (FLAG long)', () {
    late SpellChecker checker;

    setUp(() => checker = _checkerFor('long_flags'));

    test('KEEPCASE matches only the exact typed casing', () {
      expect(checker.isKnown('Nato'), isTrue);
      expect(checker.isKnown('NATO'), isFalse);
      expect(checker.isKnown('nato'), isFalse);
    });

    test('FULLSTRIP allows a suffix to consume the whole stem', () {
      // The dictionary form is "a" (flag F1); SFX F1 replaces it wholesale
      // with "an", leaving nothing of the original word before the
      // append. Without FULLSTRIP declared this would be rejected.
      expect(checker.isKnown('an'), isTrue);
    });

    test('CIRCUMFIX requires both halves together, never alone', () {
      expect(checker.isKnown('preword'), isFalse);
      expect(checker.isKnown('wordfix'), isFalse);
      expect(checker.isKnown('prewordfix'), isTrue);
    });
  });

  group('compound fixture (COMPOUNDRULE)', () {
    late SpellChecker checker;

    setUp(() => checker = _checkerFor('compound'));

    test('a word matching the compound pattern is known', () {
      // "un" (flag n) + "do" (flag o) + "teen" (flag t) matches n*ot.
      expect(checker.isKnown('undoteen'), isTrue);
    });

    test('ONLYINCOMPOUND blocks the bare word', () {
      expect(checker.isKnown('do'), isFalse);
    });

    test('COMPOUNDMIN rejects a piece shorter than the minimum', () {
      // "a" (flag n, 1 character) is too short for COMPOUNDMIN 2, so it
      // cannot stand in for the leading n* piece the way "un" does.
      expect(checker.isKnown('adoteen'), isFalse);
    });
  });

  group('break_explicit fixture (explicit BREAK patterns)', () {
    late SpellChecker checker;

    setUp(() => checker = _checkerFor('break_explicit'));

    test('an anchored-start pattern strips a leading occurrence', () {
      expect(checker.isKnown('xbox'), isTrue);
    });

    test('an anchored-end pattern strips a trailing occurrence', () {
      expect(checker.isKnown('boxx'), isTrue);
    });

    test('an anchored pattern never yields an empty remainder', () {
      expect(checker.isKnown('x'), isFalse);
    });
  });
}
