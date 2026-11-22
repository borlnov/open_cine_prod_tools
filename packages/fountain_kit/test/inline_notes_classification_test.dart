// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:test/test.dart';

/// Classify [line] alone, between two blank lines, the way a lone line of a body reads.
FountainLineType _alone(String line) => const FountainLineClassifier().classifyLine(
  line,
  previousType: FountainLineType.blank,
  nextRawLine: '',
);

/// Parse [source] and get its top-level blocks.
List<FountainBlock> _parse(String source) => const FountainParser().parse(source).blocks;

/// Run the tests of the classification of lines holding inline notes.
void main() {
  group('a note never changes the type of a line', () {
    test('a note opening or closing a scene heading', () {
      expect(_alone('[[x]]INT. HOUSE - DAY'), FountainLineType.sceneHeading);
      expect(_alone('INT. HOUSE - DAY[[x]]'), FountainLineType.sceneHeading);
      expect(_alone('INT. HOUSE - DAY #4# [[x]]'), FountainLineType.sceneHeading);
      expect(_alone('INT. HOUSE - DAY [[x]] #4#'), FountainLineType.sceneHeading);
    });

    test('a note around a transition', () {
      expect(_alone('CUT TO:[[x]]'), FountainLineType.transition);
      expect(_alone('[[x]]CUT TO:'), FountainLineType.transition);
    });

    test('a note around a parenthetical or a cue', () {
      const classifier = FountainLineClassifier();
      expect(
        classifier.classifyLine(
          '(softly)[[x]]',
          previousType: FountainLineType.character,
          nextRawLine: 'Hello.',
        ),
        FountainLineType.parenthetical,
      );
      expect(
        classifier.classifyLine('SARAH[[x]]', previousType: null, nextRawLine: 'Hello.'),
        FountainLineType.character,
      );
    });

    test('a note before a forcing marker', () {
      expect(_alone('[[x]]!int. house'), FountainLineType.action);
      expect(_alone('[[x]].house'), FountainLineType.sceneHeading);
    });

    test('a line of a note alone is classified as written', () {
      expect(_alone('[[x]]'), FountainLineType.action);
    });

    test('the writer adds no marker the note made useless', () {
      const writer = FountainLineWriter();
      String write(String text, FountainLineType type) => writer.writeLine(
        text: text,
        type: type,
        hadForcingMarker: false,
        previousType: FountainLineType.blank,
        nextRawLine: '',
      );
      expect(
        write('[[x]]INT. HOUSE - DAY', FountainLineType.sceneHeading),
        '[[x]]INT. HOUSE - DAY',
      );
      expect(write('CUT TO:[[x]]', FountainLineType.transition), 'CUT TO:[[x]]');
      expect(write('[[x]]HOUSE', FountainLineType.sceneHeading), '.[[x]]HOUSE');
    });
  });

  group('the parser builds the blocks of lines holding notes', () {
    test('a scene heading with a note before it and a number after', () {
      final heading = _parse('[[x]]int. house - day #4#\n\nHi.')[0] as FountainSceneHeading;
      expect(heading.headingText, 'INT. HOUSE - DAY');
      expect(heading.sceneNumber, '4');
      expect(heading.rawText, '[[x]]int. house - day #4#');
    });

    test('a scene heading with a note between the text and the number', () {
      final heading = _parse('INT. HOUSE - DAY [[x]] #4#\n\nHi.')[0] as FountainSceneHeading;
      expect(heading.headingText, 'INT. HOUSE - DAY');
      expect(heading.sceneNumber, '4');
    });

    test('a scene heading with a note after the number', () {
      final heading = _parse('INT. HOUSE - DAY #4# [[x]]\n\nHi.')[0] as FountainSceneHeading;
      expect(heading.headingText, 'INT. HOUSE - DAY');
      expect(heading.sceneNumber, '4');
    });

    test('a transition and a dialogue group around notes', () {
      final blocks = _parse('He leaves.\n\nCUT TO:[[x]]\n\nSARAH[[y]]\n(softly)[[z]]\nHello.');
      expect(blocks[1], isA<FountainTransition>());
      final group = blocks[2] as FountainDialogueGroup;
      expect(group.character.name, 'SARAH');
      expect((group.children[0] as FountainParenthetical).text, 'softly[[z]]');
    });

    test('the serializer round trips lines holding notes', () {
      const source =
          '[[x]]INT. HOUSE - DAY #4#\n\nCUT TO:[[x]]\n\nSARAH[[y]]\n(softly)[[z]]\nHello.';
      final once = const FountainParser().parse(source);
      final again = const FountainParser().parse(const FountainSerializer().write(once));
      expect(
        again.blocks.map((block) => block.runtimeType),
        once.blocks.map((block) => block.runtimeType),
      );
    });
  });
}
