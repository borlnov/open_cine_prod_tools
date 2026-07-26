// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/parser/fountain_block_builder.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:test/test.dart';

/// Classifies and builds [source] (a body with no title page) with fresh
/// [FountainLineClassifier] and [FountainBlockBuilder] instances, mirroring
/// how [FountainParser] drives them internally.
List<FountainBlock> _build(String source) {
  final lines = source.split('\n');
  final types = const FountainLineClassifier().classify(lines);
  final lineStartOffsets = <int>[0];
  for (var index = 0; index < source.length; index++) {
    if (source[index] == '\n') {
      lineStartOffsets.add(index + 1);
    }
  }
  return const FountainBlockBuilder().build(
    lines: lines,
    types: types,
    lineStartOffsets: lineStartOffsets,
    bodyStartLine: 0,
  );
}

void main() {
  group('dialogue grouping', () {
    test('a character cue and its dialogue line form one group', () {
      final blocks = _build('\nSARAH\nHello there.\n');
      expect(blocks, hasLength(1));
      final group = blocks.single as FountainDialogueGroup;
      expect(group.character.name, 'SARAH');
      expect(group.children, [
        isA<FountainDialogueLine>().having(
          (line) => line.text,
          'text',
          'Hello there.',
        ),
      ]);
    });

    test('a parenthetical inside a dialogue block is kept as a child', () {
      final blocks = _build('\nSARAH\n(beat)\nHello there.\n');
      final group = blocks.single as FountainDialogueGroup;
      expect(group.children, [
        isA<FountainParenthetical>().having(
          (paren) => paren.text,
          'text',
          'beat',
        ),
        isA<FountainDialogueLine>().having(
          (line) => line.text,
          'text',
          'Hello there.',
        ),
      ]);
    });

    test('a character extension in parentheses is parsed separately', () {
      final blocks = _build('\nSARAH (V.O.)\nHello there.\n');
      final group = blocks.single as FountainDialogueGroup;
      expect(group.character.name, 'SARAH');
      expect(group.character.extension, 'V.O.');
    });

    test('a blank line ends a dialogue group', () {
      final blocks = _build('\nSARAH\nHello there.\n\nMore action.\n');
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<FountainDialogueGroup>());
      expect(blocks[1], isA<FountainActionBlock>());
    });
  });

  group('dual dialogue', () {
    test('a "^" suffixed character cue marks its group as dual dialogue, '
        'adjacent to the group it answers', () {
      final blocks = _build('\nROSS\nFirst.\n\nKIM^\nSecond.\n');
      expect(blocks, hasLength(2));
      final first = blocks[0] as FountainDialogueGroup;
      final second = blocks[1] as FountainDialogueGroup;
      expect(first.isDualDialogue, isFalse);
      expect(second.isDualDialogue, isTrue);
      expect(second.character.name, 'KIM');
      expect(second.character.isDualDialogue, isTrue);
    });
  });

  group('sections', () {
    test('one to six leading "#" characters set the section level', () {
      for (var level = 1; level <= 6; level++) {
        final blocks = _build('${'#' * level} Heading $level');
        final section = blocks.single as FountainSection;
        expect(section.level, level);
        expect(section.text, 'Heading $level');
      }
    });
  });

  group('page breaks', () {
    test('"===" becomes a FountainPageBreak', () {
      final blocks = _build('===');
      expect(blocks.single, isA<FountainPageBreak>());
    });
  });

  group('scene numbers', () {
    test('a trailing "#4A#" tag is parsed as the scene number', () {
      final blocks = _build('\nINT. HOUSE #4A#\n\n');
      final heading = blocks.single as FountainSceneHeading;
      expect(heading.sceneNumber, '4A');
      expect(heading.headingText, 'INT. HOUSE');
      expect(heading.rawText, 'INT. HOUSE #4A#');
    });

    test('a scene heading without a tag has no scene number', () {
      final blocks = _build('\nINT. HOUSE\n\n');
      final heading = blocks.single as FountainSceneHeading;
      expect(heading.sceneNumber, isNull);
    });
  });

  // Standalone notes and boneyard comments are extracted by FountainParser's
  // pre-passes (they must be found and blanked out before line
  // classification runs), so they are exercised here through the full
  // parser rather than through FountainBlockBuilder in isolation.
  group('notes', () {
    test(
      'a "[[note]]" alone on its own line becomes a standalone note block',
      () {
        final document = const FountainParser().parse(
          'Some action.\n\n[[a standalone note]]\n\nMore action.\n',
        );
        expect(document.blocks, [
          isA<FountainActionBlock>(),
          isA<FountainNoteBlock>().having(
            (note) => note.text,
            'text',
            'a standalone note',
          ),
          isA<FountainActionBlock>(),
        ]);
      },
    );

    test('a "[[note]]" sharing a line with other text stays inline', () {
      final document = const FountainParser().parse(
        'Some action [[an inline note]] continues here.',
      );
      expect(document.blocks, hasLength(1));
      final action = document.blocks.single as FountainActionBlock;
      expect(action.lines.single, contains('[[an inline note]]'));
    });
  });

  group('boneyard', () {
    test(
      'a "/* */" comment spanning several lines becomes one boneyard block',
      () {
        final document = const FountainParser().parse(
          'Some action.\n\n/*\ncut for pacing\nkeep for reference\n*/\n\nMore action.\n',
        );
        expect(document.blocks, [
          isA<FountainActionBlock>(),
          isA<FountainBoneyard>().having(
            (boneyard) => boneyard.text.trim(),
            'text',
            'cut for pacing\nkeep for reference',
          ),
          isA<FountainActionBlock>(),
        ]);
      },
    );

    test('a boneyard comment sits between the blocks it separated', () {
      final document = const FountainParser().parse(
        'INT. HOUSE - DAY\n\n/* remove before shooting */\n\nSARAH\nHello.\n',
      );
      expect(document.blocks, [
        isA<FountainSceneHeading>(),
        isA<FountainBoneyard>(),
        isA<FountainDialogueGroup>(),
      ]);
    });
  });
}
