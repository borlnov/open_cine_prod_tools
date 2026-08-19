// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/utils/ocpt_spell_checked_lines.dart';
import 'package:spell_kit/spell_kit.dart';

void main() {
  group('ocptIsSpellCheckedLineType', () {
    test("is true for the screenplay's own prose", () {
      expect(ocptIsSpellCheckedLineType(FountainLineType.action), isTrue);
      expect(ocptIsSpellCheckedLineType(FountainLineType.dialogue), isTrue);
      expect(ocptIsSpellCheckedLineType(FountainLineType.parenthetical), isTrue);
      expect(ocptIsSpellCheckedLineType(FountainLineType.centeredText), isTrue);
    });

    test('is false for scaffolding and fixed-vocabulary line types', () {
      expect(ocptIsSpellCheckedLineType(FountainLineType.blank), isFalse);
      expect(ocptIsSpellCheckedLineType(FountainLineType.pageBreak), isFalse);
      expect(ocptIsSpellCheckedLineType(FountainLineType.section), isFalse);
      expect(ocptIsSpellCheckedLineType(FountainLineType.synopsis), isFalse);
      expect(ocptIsSpellCheckedLineType(FountainLineType.sceneHeading), isFalse);
      expect(ocptIsSpellCheckedLineType(FountainLineType.transition), isFalse);
      expect(ocptIsSpellCheckedLineType(FountainLineType.lyrics), isFalse);
      expect(ocptIsSpellCheckedLineType(FountainLineType.character), isFalse);
    });
  });

  group('ocptScreenplaySpellTokenizerOptions', () {
    test('turns the all-caps and digit skip rules on', () {
      expect(ocptScreenplaySpellTokenizerOptions.skipAllCapsTokens, isTrue);
      expect(ocptScreenplaySpellTokenizerOptions.skipTokensWithDigits, isTrue);
    });
  });

  group('ocptSpellCheckSkipSpansIn', () {
    test('returns no span for a text with no note or boneyard comment', () {
      expect(ocptSpellCheckSkipSpansIn('She walks into the kitchen.'), isEmpty);
    });

    test('finds a standalone note span', () {
      const source = 'She walks in. [[maybe cut this]] She sits.';
      final noteStart = source.indexOf('[[');
      final noteEnd = source.indexOf(']]') + 2;

      expect(ocptSpellCheckSkipSpansIn(source), [SpellRange(noteStart, noteEnd)]);
    });

    test('finds a boneyard comment span', () {
      const source = 'She walks in. /* cut this later */ She sits.';
      final boneyardStart = source.indexOf('/*');
      final boneyardEnd = source.indexOf('*/') + 2;

      expect(ocptSpellCheckSkipSpansIn(source), [SpellRange(boneyardStart, boneyardEnd)]);
    });

    test('returns both spans in ascending order, whichever comes first in the source', () {
      const source = '/* early boneyard */ then [[a note]] at the end.';
      final boneyardStart = source.indexOf('/*');
      final boneyardEnd = source.indexOf('*/') + 2;
      final noteStart = source.indexOf('[[');
      final noteEnd = source.indexOf(']]') + 2;

      expect(ocptSpellCheckSkipSpansIn(source), [
        SpellRange(boneyardStart, boneyardEnd),
        SpellRange(noteStart, noteEnd),
      ]);
    });

    test('sorts a note that comes before a boneyard comment into ascending order too', () {
      const source = '[[a note]] then /* a boneyard */ at the end.';
      final noteStart = source.indexOf('[[');
      final noteEnd = source.indexOf(']]') + 2;
      final boneyardStart = source.indexOf('/*');
      final boneyardEnd = source.indexOf('*/') + 2;

      expect(ocptSpellCheckSkipSpansIn(source), [
        SpellRange(noteStart, noteEnd),
        SpellRange(boneyardStart, boneyardEnd),
      ]);
    });
  });
}
