// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/utils/ocpt_spell_checked_lines.dart';
import 'package:spell_kit/spell_kit.dart';

/// A placeholder [FountainSourceRange]: none of these tests care where in a source string a block
/// was parsed from, only what [FountainBlock] subclass it is.
const _placeholderRange = FountainSourceRange(startLine: 0, endLine: 0, startOffset: 0, endOffset: 0);

void main() {
  group('ocptLineTypeOfBlock', () {
    test("maps each of the screenplay's own prose blocks to its line type", () {
      expect(
        ocptLineTypeOfBlock(
          const FountainActionBlock(sourceRange: _placeholderRange, lines: ['She walks in.'], forced: false),
        ),
        FountainLineType.action,
      );
      expect(
        ocptLineTypeOfBlock(
          const FountainDialogueLine(sourceRange: _placeholderRange, text: 'Hello.'),
        ),
        FountainLineType.dialogue,
      );
      expect(
        ocptLineTypeOfBlock(
          const FountainParenthetical(sourceRange: _placeholderRange, text: 'beat'),
        ),
        FountainLineType.parenthetical,
      );
      expect(
        ocptLineTypeOfBlock(
          const FountainCenteredText(sourceRange: _placeholderRange, text: 'THE END'),
        ),
        FountainLineType.centeredText,
      );
    });

    test('maps each scaffolding and fixed-vocabulary block to its line type', () {
      expect(
        ocptLineTypeOfBlock(
          const FountainSceneHeading(
            sourceRange: _placeholderRange,
            rawText: 'INT. KITCHEN - DAY',
            headingText: 'INT. KITCHEN - DAY',
            forcedMarker: false,
          ),
        ),
        FountainLineType.sceneHeading,
      );
      expect(
        ocptLineTypeOfBlock(
          const FountainCharacter(sourceRange: _placeholderRange, name: 'MARIE', isDualDialogue: false),
        ),
        FountainLineType.character,
      );
      expect(
        ocptLineTypeOfBlock(
          const FountainTransition(sourceRange: _placeholderRange, text: 'CUT TO:', forced: false),
        ),
        FountainLineType.transition,
      );
      expect(
        ocptLineTypeOfBlock(const FountainLyrics(sourceRange: _placeholderRange, lines: ['La la la'])),
        FountainLineType.lyrics,
      );
      expect(
        ocptLineTypeOfBlock(const FountainSection(sourceRange: _placeholderRange, level: 1, text: 'Act one')),
        FountainLineType.section,
      );
      expect(
        ocptLineTypeOfBlock(const FountainSynopsis(sourceRange: _placeholderRange, text: 'She arrives.')),
        FountainLineType.synopsis,
      );
      expect(
        ocptLineTypeOfBlock(const FountainPageBreak(sourceRange: _placeholderRange)),
        FountainLineType.pageBreak,
      );
    });

    test('returns null for the block kinds with no line type of their own', () {
      expect(
        ocptLineTypeOfBlock(const FountainNoteBlock(sourceRange: _placeholderRange, text: 'maybe cut')),
        isNull,
      );
      expect(
        ocptLineTypeOfBlock(const FountainBoneyard(sourceRange: _placeholderRange, text: 'old draft')),
        isNull,
      );
      expect(
        ocptLineTypeOfBlock(
          const FountainDialogueGroup(
            sourceRange: _placeholderRange,
            character: FountainCharacter(
              sourceRange: _placeholderRange,
              name: 'MARIE',
              isDualDialogue: false,
            ),
            children: [FountainDialogueLine(sourceRange: _placeholderRange, text: 'Hello.')],
            isDualDialogue: false,
          ),
        ),
        isNull,
      );
    });
  });

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
