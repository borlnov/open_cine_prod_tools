// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_speaking_characters.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:test/test.dart';

/// A source range every hand-built block in this file shares: neither block
/// equality nor [speakingCharactersOf] looks at it.
const FountainSourceRange _range = FountainSourceRange(
  startLine: 0,
  endLine: 0,
  startOffset: 0,
  endOffset: 0,
);

FountainActionBlock _action(List<String> lines) =>
    FountainActionBlock(sourceRange: _range, lines: lines, forced: false);

FountainCharacter _character(
  String name, {
  String? extension,
  bool isDualDialogue = false,
}) => FountainCharacter(
  sourceRange: _range,
  name: name,
  extension: extension,
  isDualDialogue: isDualDialogue,
);

FountainDialogueLine _dialogueLine(String text) => FountainDialogueLine(sourceRange: _range, text: text);

FountainDialogueGroup _dialogueGroup(
  String name, {
  String? extension,
  bool isDualDialogue = false,
}) => FountainDialogueGroup(
  sourceRange: _range,
  character: _character(name, extension: extension, isDualDialogue: isDualDialogue),
  children: [_dialogueLine('Hello.')],
  isDualDialogue: isDualDialogue,
);

void main() {
  group('speakingCharactersOf', () {
    test('a document with no dialogue has no speaking characters', () {
      expect(speakingCharactersOf([_action(['Nothing happens.'])]), isEmpty);
    });

    test('the same role cued twice is deduplicated', () {
      final blocks = [_dialogueGroup('SARAH'), _dialogueGroup('SARAH')];

      expect(speakingCharactersOf(blocks), ['SARAH']);
    });

    test('roles are ordered by first appearance', () {
      final blocks = [
        _dialogueGroup('JOHN'),
        _dialogueGroup('SARAH'),
        _dialogueGroup('JOHN'),
      ];

      expect(speakingCharactersOf(blocks), ['JOHN', 'SARAH']);
    });

    test('names are normalized before deduplicating', () {
      final blocks = [
        _dialogueGroup('sarah   connor'),
        _dialogueGroup('SARAH CONNOR'),
        _dialogueGroup('Sarah Connor', extension: 'V.O.'),
      ];

      expect(speakingCharactersOf(blocks), ['SARAH CONNOR']);
    });

    test('a dual-dialogue pair contributes both of its cues', () {
      final blocks = [
        _dialogueGroup('SARAH'),
        _dialogueGroup('JOHN', isDualDialogue: true),
      ];

      expect(speakingCharactersOf(blocks), ['SARAH', 'JOHN']);
    });
  });
}
