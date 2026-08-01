// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/parser/fountain_character_cue.dart';
import 'package:test/test.dart';

void main() {
  group('parseFountainCharacterCue', () {
    test('reads a plain cue as its name alone', () {
      final cue = parseFountainCharacterCue('SARAH');

      expect(cue.name, 'SARAH');
      expect(cue.extension, isNull);
      expect(cue.isDualDialogue, isFalse);
    });

    test('splits the parenthetical extension off the name', () {
      final cue = parseFountainCharacterCue('SARAH (V.O.)');

      expect(cue.name, 'SARAH');
      expect(cue.extension, 'V.O.');
    });

    test('drops the forcing @ prefix and the dual-dialogue ^ suffix', () {
      final cue = parseFountainCharacterCue('@McAvoy ^');

      expect(cue.name, 'McAvoy');
      expect(cue.isDualDialogue, isTrue);
    });

    test('drops all three markers at once', () {
      final cue = parseFountainCharacterCue("  @Sarah (CONT'D) ^  ");

      expect(cue.name, 'Sarah');
      expect(cue.extension, "CONT'D");
      expect(cue.isDualDialogue, isTrue);
    });
  });
}
