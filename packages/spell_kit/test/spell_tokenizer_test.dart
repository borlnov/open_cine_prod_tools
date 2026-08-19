// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:spell_kit/spell_kit.dart';
import 'package:test/test.dart';

void main() {
  group('offsets', () {
    test('a token carries its UTF-16 offsets into the source text', () {
      final tokens = spellTokensIn('the cat sat');
      expect(tokens, const [
        SpellToken('the', SpellRange(0, 3)),
        SpellToken('cat', SpellRange(4, 7)),
        SpellToken('sat', SpellRange(8, 11)),
      ]);
    });

    test('offsets stay correct past a multi-code-unit character', () {
      // "é" here is a single UTF-16 code unit (U+00E9), so "après" is 5
      // code units wide; the following word's offset must reflect that.
      final tokens = spellTokensIn('après midi');
      expect(tokens[0], const SpellToken('après', SpellRange(0, 5)));
      expect(tokens[1], const SpellToken('midi', SpellRange(6, 10)));
    });
  });

  group('skip rules', () {
    test('an all-caps token is skipped by default', () {
      final tokens = spellTokensIn('INT. KITCHEN and more');
      expect(tokens.map((t) => t.text), ['and', 'more']);
    });

    test('an all-caps token is kept when the skip is disabled', () {
      final tokens = spellTokensIn(
        'CUT',
        options: const SpellTokenizerOptions(skipAllCapsTokens: false),
      );
      expect(tokens.map((t) => t.text), ['CUT']);
    });

    test('a token holding a digit is skipped by default', () {
      final tokens = spellTokensIn('page2 and page3 fine');
      expect(tokens.map((t) => t.text), ['and', 'fine']);
    });

    test('a token holding a digit is kept when the skip is disabled', () {
      final tokens = spellTokensIn(
        'page2',
        options: const SpellTokenizerOptions(skipTokensWithDigits: false),
      );
      expect(tokens.map((t) => t.text), ['page2']);
    });

    test('a URI chunk is dropped whole', () {
      final tokens = spellTokensIn('see https://example.com/path for more');
      expect(tokens.map((t) => t.text), ['see', 'for', 'more']);
    });

    test('an email chunk is dropped whole', () {
      final tokens = spellTokensIn('mail jane@example.com today');
      expect(tokens.map((t) => t.text), ['mail', 'today']);
    });

    test('a file path chunk is dropped whole', () {
      final tokens = spellTokensIn(r'open C:\Users\jane\script.fountain now');
      expect(tokens.map((t) => t.text), ['open', 'now']);
    });

    test('a www-prefixed chunk is dropped whole', () {
      final tokens = spellTokensIn('visit www.example.com soon');
      expect(tokens.map((t) => t.text), ['visit', 'soon']);
    });
  });

  group('apostrophe and hyphen handling', () {
    test('an interior apostrophe is kept', () {
      final tokens = spellTokensIn("don't");
      expect(tokens.map((t) => t.text), ["don't"]);
    });

    test('an interior hyphen is kept', () {
      final tokens = spellTokensIn('close-up');
      expect(tokens.map((t) => t.text), ['close-up']);
    });

    test('a leading or trailing apostrophe is trimmed off', () {
      final tokens = spellTokensIn("'quoted'");
      expect(tokens.map((t) => t.text), ['quoted']);
    });

    test('a leading or trailing hyphen is trimmed off', () {
      final tokens = spellTokensIn('-- word --');
      expect(tokens.map((t) => t.text), ['word']);
    });
  });

  group('SpellTokenizerOptions.fromAffixFile', () {
    test('drops "." and every digit from WORDCHARS', () {
      final affixFile = HunspellAffixFile.parse(
        "WORDCHARS -'1234567890.\n",
      );
      final options = SpellTokenizerOptions.fromAffixFile(affixFile);
      expect(options.extraWordCharacters, {'-', "'"});
    });
  });
}
