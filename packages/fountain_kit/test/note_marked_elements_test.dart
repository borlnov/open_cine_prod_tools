// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:test/test.dart';

/// Parse [source] and get its top-level blocks, failing the test on a throw.
List<FountainBlock> _parse(String source) => const FountainParser().parse(source).blocks;

/// Run the tests of the elements whose marker sits next to an inline note.
void main() {
  group('a leading or trailing note leaves the element built from its marker', () {
    test('section', () {
      for (final source in ['[[x]]# Act', '# Act[[x]]', '[[x]]## Act [[y]]']) {
        final block = _parse(source).single as FountainSection;
        expect(block.level, source.contains('##') ? 2 : 1, reason: source);
        expect(block.text, contains('Act'), reason: source);
        expect(block.text, isNot(contains('#')), reason: source);
      }
      expect((_parse('[[x]]# Act').single as FountainSection).text, '[[x]] Act');
    });

    test('synopsis', () {
      expect((_parse('[[x]]= syn').single as FountainSynopsis).text, '[[x]] syn');
      expect((_parse('= syn[[x]]').single as FountainSynopsis).text, 'syn[[x]]');
    });

    test('page break', () {
      expect(_parse('[[x]]===').single, isA<FountainPageBreak>());
      expect(_parse('===[[x]]').single, isA<FountainPageBreak>());
    });

    test('scene heading', () {
      expect(
        (_parse('[[x]]INT. HOUSE - DAY').single as FountainSceneHeading).headingText,
        'INT. HOUSE - DAY',
      );
      expect(
        (_parse('INT. HOUSE - DAY[[x]]').single as FountainSceneHeading).headingText,
        'INT. HOUSE - DAY',
      );
    });

    test('forced action', () {
      final leading = _parse('[[x]]!int. house').single as FountainActionBlock;
      expect(leading.forced, isTrue);
      expect(leading.lines, ['[[x]]int. house']);
      final trailing = _parse('!int. house[[x]]').single as FountainActionBlock;
      expect(trailing.lines, ['int. house[[x]]']);
    });

    test('transition', () {
      expect((_parse('[[x]]CUT TO:').single as FountainTransition).text, '[[x]]CUT TO:');
      final forced = _parse('[[x]]>Burn to white.').single as FountainTransition;
      expect(forced.forced, isTrue);
      expect(forced.text, '[[x]]Burn to white.');
      expect((_parse('>Burn[[x]]').single as FountainTransition).text, 'Burn[[x]]');
    });

    test('centered text', () {
      expect((_parse('[[x]]> THE END <').single as FountainCenteredText).text, '[[x]] THE END');
      expect((_parse('> THE END <[[x]]').single as FountainCenteredText).text, 'THE END [[x]]');
    });

    test('lyrics', () {
      expect((_parse('[[x]]~la la').single as FountainLyrics).lines, ['[[x]]la la']);
      expect((_parse('~la la[[x]]').single as FountainLyrics).lines, ['la la[[x]]']);
    });

    test('character, parenthetical and dialogue', () {
      final group = _parse('[[x]]SARAH\n(softly)[[y]]\nHi.[[z]]').single as FountainDialogueGroup;
      expect(group.character.name, 'SARAH');
      expect((group.children.first as FountainParenthetical).text, 'softly[[y]]');
      expect((group.children.last as FountainDialogueLine).text, 'Hi.[[z]]');
      final trailing = _parse('SARAH[[x]]\nHi.').single as FountainDialogueGroup;
      expect(trailing.character.name, 'SARAH');
      expect(trailing.character.rawText, 'SARAH[[x]]');
    });
  });
}
