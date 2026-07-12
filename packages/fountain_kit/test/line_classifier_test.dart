// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
import 'package:test/test.dart';

/// Classifies [lines] with a fresh [FountainLineClassifier].
List<FountainLineType> _classify(List<String> lines) =>
    const FountainLineClassifier().classify(lines);

void main() {
  group('blank lines', () {
    test('a truly empty line is blank', () {
      expect(_classify(['']), [FountainLineType.blank]);
    });

    test('a whitespace-only line outside a dialogue block is blank', () {
      expect(_classify(['Some action.', '  ', 'More action.']), [
        FountainLineType.action,
        FountainLineType.blank,
        FountainLineType.action,
      ]);
    });

    test('a whitespace-only line inside a dialogue block is a preserved '
        'dialogue line, not blank', () {
      final types = _classify(['SARAH', 'Hello there.', '  ', 'Still here.']);
      expect(types, [
        FountainLineType.character,
        FountainLineType.dialogue,
        FountainLineType.dialogue,
        FountainLineType.dialogue,
      ]);
    });
  });

  group('scene headings', () {
    for (final prefix in [
      'INT.',
      'EXT.',
      'EST.',
      'INT./EXT.',
      'INT/EXT.',
      'EXT./INT.',
      'EXT/INT.',
      'I/E.',
      'INT ',
      'EXT ',
    ]) {
      test('"$prefix" starts a scene heading', () {
        final line = '${prefix}SOMEWHERE - DAY';
        expect(_classify(['', line, '']), [
          FountainLineType.blank,
          FountainLineType.sceneHeading,
          FountainLineType.blank,
        ]);
      });
    }

    test('scene headings are case-insensitive', () {
      expect(_classify(['', 'int. kitchen - day', '']), [
        FountainLineType.blank,
        FountainLineType.sceneHeading,
        FountainLineType.blank,
      ]);
    });

    test('a scene heading needs a blank line before it', () {
      expect(_classify(['Some action.', 'INT. KITCHEN - DAY', '']), [
        FountainLineType.action,
        FountainLineType.action,
        FountainLineType.blank,
      ]);
    });

    test('a scene heading needs a blank line after it', () {
      // "INT. Kitchen" is deliberately not all-caps here so the failed
      // scene heading also fails the (independent) all-caps character-cue
      // check below, and unambiguously falls back to action.
      expect(_classify(['', 'INT. Kitchen - Day', 'Some action.']), [
        FountainLineType.blank,
        FountainLineType.action,
        FountainLineType.action,
      ]);
    });

    test('a scene-heading-shaped line with no trailing blank line, but that is '
        'also all-caps and followed by text, reads as a character cue instead: '
        'scene-heading and character-cue detection are independent structural '
        'checks, not keyword-exclusive', () {
      expect(_classify(['', 'INT. KITCHEN - DAY', 'Some action.']), [
        FountainLineType.blank,
        FountainLineType.character,
        FountainLineType.dialogue,
      ]);
    });

    test('a scene heading at the very start of the document is valid', () {
      expect(_classify(['INT. KITCHEN - DAY', '']), [
        FountainLineType.sceneHeading,
        FountainLineType.blank,
      ]);
    });

    test('a leading "." forces a scene heading regardless of context', () {
      expect(_classify(['.THE VOID', 'No blank line follows.']), [
        FountainLineType.sceneHeading,
        FountainLineType.action,
      ]);
    });

    test('a leading ".." does not force a scene heading', () {
      expect(_classify(['..an ellipsis opens this line']), [
        FountainLineType.action,
      ]);
    });
  });

  group('action', () {
    test('is the default classification', () {
      expect(_classify(['Just a regular sentence.']), [
        FountainLineType.action,
      ]);
    });

    test('a leading "!" forces action', () {
      expect(_classify(['!INT. THIS LOOKS LIKE A HEADING']), [
        FountainLineType.action,
      ]);
    });
  });

  group('character cues', () {
    test(
      'all-caps text preceded by blank and followed by dialogue is a character cue',
      () {
        expect(_classify(['', 'SARAH', 'Hello.']), [
          FountainLineType.blank,
          FountainLineType.character,
          FountainLineType.dialogue,
        ]);
      },
    );

    test('needs a blank line before it', () {
      expect(_classify(['Some action.', 'SARAH', 'Hello.']), [
        FountainLineType.action,
        FountainLineType.action,
        FountainLineType.action,
      ]);
    });

    test('needs a non-blank line after it, or it is action', () {
      expect(_classify(['', 'SARAH', '']), [
        FountainLineType.blank,
        FountainLineType.action,
        FountainLineType.blank,
      ]);
    });

    test('a character cue may end in a parenthetical extension', () {
      expect(_classify(['', 'SARAH (V.O.)', 'Hello.']), [
        FountainLineType.blank,
        FountainLineType.character,
        FountainLineType.dialogue,
      ]);
    });

    test('a leading "@" forces a character cue, allowing lowercase', () {
      expect(_classify(['', '@McCLANE', 'Yippee-ki-yay.']), [
        FountainLineType.blank,
        FountainLineType.character,
        FountainLineType.dialogue,
      ]);
    });

    test('a trailing "^" still reads as a character cue', () {
      expect(_classify(['', 'SARAH^', 'Hello.']), [
        FountainLineType.blank,
        FountainLineType.character,
        FountainLineType.dialogue,
      ]);
    });
  });

  group('parentheticals and dialogue', () {
    test('a parenthesized line inside a dialogue block is a parenthetical', () {
      expect(_classify(['', 'SARAH', '(beat)', 'Hello.']), [
        FountainLineType.blank,
        FountainLineType.character,
        FountainLineType.parenthetical,
        FountainLineType.dialogue,
      ]);
    });

    test('a parenthesized line outside a dialogue block is action', () {
      expect(_classify(['(A lone bird crosses the sky.)']), [
        FountainLineType.action,
      ]);
    });

    test('a blank line ends the dialogue block', () {
      expect(_classify(['', 'SARAH', 'Hello.', '', 'More action.']), [
        FountainLineType.blank,
        FountainLineType.character,
        FountainLineType.dialogue,
        FountainLineType.blank,
        FountainLineType.action,
      ]);
    });
  });

  group('transitions', () {
    test(
      'all-caps text ending in "TO:" surrounded by blanks is a transition',
      () {
        expect(_classify(['', 'CUT TO:', '']), [
          FountainLineType.blank,
          FountainLineType.transition,
          FountainLineType.blank,
        ]);
      },
    );

    test('needs blank lines on both sides, or it is action', () {
      expect(_classify(['Some action.', 'CUT TO:', '']), [
        FountainLineType.action,
        FountainLineType.action,
        FountainLineType.blank,
      ]);
    });

    test('a leading ">" forces a transition', () {
      expect(_classify(['>Burn to white.']), [FountainLineType.transition]);
    });
  });

  group('centered text', () {
    test('"> text <" is centered text, not a transition', () {
      expect(_classify(['> THE END <']), [FountainLineType.centeredText]);
    });
  });

  group('lyrics', () {
    test('a leading "~" marks a lyrics line', () {
      expect(
        _classify([
          '~Half a mile from the county fair',
          '~Not one soul around',
        ]),
        [FountainLineType.lyrics, FountainLineType.lyrics],
      );
    });
  });

  group('sections', () {
    test('one to six leading "#" characters mark section levels', () {
      for (var level = 1; level <= 6; level++) {
        expect(_classify(['${'#' * level} Heading']), [
          FountainLineType.section,
        ]);
      }
    });
  });

  group('synopses', () {
    test('a single leading "=" marks a synopsis', () {
      expect(_classify(['= A short summary.']), [FountainLineType.synopsis]);
    });
  });

  group('page breaks', () {
    test('three or more "=" characters alone on a line is a page break', () {
      expect(_classify(['===']), [FountainLineType.pageBreak]);
      expect(_classify(['======']), [FountainLineType.pageBreak]);
    });

    test('fewer than three "=" characters is a synopsis, not a page break', () {
      expect(_classify(['==']), [FountainLineType.synopsis]);
    });
  });
}
