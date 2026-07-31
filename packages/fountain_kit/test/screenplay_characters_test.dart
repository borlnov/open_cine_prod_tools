// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_screenplay_characters.dart';
import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:test/test.dart';

void main() {
  group('charactersIntroducedInActionLine', () {
    test('names a character introduced at the start of the line', () {
      expect(
        charactersIntroducedInActionLine('ELISA entre dans le derrière de scène.'),
        ['ELISA'],
      );
    });

    test('names a character introduced mid-sentence', () {
      expect(
        charactersIntroducedInActionLine("Derrière lui, plus loin, PASCAL s'échauffe."),
        ['PASCAL'],
      );
    });

    test('names nobody in a line written in ordinary case', () {
      expect(
        charactersIntroducedInActionLine('Paul se libère doucement de Juliette.'),
        isEmpty,
      );
    });

    test('keeps the words of a two-word name together', () {
      expect(charactersIntroducedInActionLine('JEAN DUPONT arrive.'), ['JEAN DUPONT']);
    });

    test('names two characters an ordinary-case word separates', () {
      expect(charactersIntroducedInActionLine('PAUL et PASCAL entrent.'), ['PAUL', 'PASCAL']);
    });

    test('strips the punctuation around a name, inner dots kept', () {
      expect(charactersIntroducedInActionLine('(PAUL) regarde "ELISA", puis J.R.'), [
        'PAUL',
        'ELISA',
        'J.R',
      ]);
    });

    test('reads accented capitals as capitals', () {
      expect(charactersIntroducedInActionLine('ÉLISA entre.'), ['ÉLISA']);
    });

    test('names nobody for a whole sentence shouted in capitals', () {
      expect(
        charactersIntroducedInActionLine('TOUT LE MONDE SE MET À COURIR VERS LA SORTIE'),
        isEmpty,
      );
    });

    test('ignores a single letter and a bare dash', () {
      expect(charactersIntroducedInActionLine('A - B'), isEmpty);
    });
  });

  group('over a parsed document', () {
    const screenplay = '''
INT. THEATRE - NIGHT

PAUL est habillé en costume. Il s'échauffe.

ELISA entre dans le derrière de scène. Elle s'approche de Paul.

PAUL
Ils sont là ?

JULIETTE
Oui.
''';

    test('charactersIntroducedInActionOf lists the action names only, deduplicated', () {
      final document = const FountainParser().parse(screenplay);

      expect(charactersIntroducedInActionOf(document.blocks), ['PAUL', 'ELISA']);
    });

    test('screenplayCharactersOf pairs the speaking roles with the action ones', () {
      final document = const FountainParser().parse(screenplay);

      // In first-appearance order, and PAUL is named once although both an action line and a cue
      // introduce him.
      expect(screenplayCharactersOf(document.blocks), ['PAUL', 'ELISA', 'JULIETTE']);
    });

    test('a scene heading or a transition never names anybody', () {
      final document = const FountainParser().parse('INT. HOUSE - DAY\n\nCUT TO:\n');

      expect(screenplayCharactersOf(document.blocks), isEmpty);
    });
  });
}
