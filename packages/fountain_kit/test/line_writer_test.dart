// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
import 'package:fountain_kit/src/serializer/fountain_line_writer.dart';
import 'package:test/test.dart';

/// Writes [text] as [type] with a fresh [FountainLineWriter].
String _write(
  String text,
  FountainLineType type, {
  bool hadForcingMarker = false,
  FountainLineType? previousType,
  String? nextRawLine,
  int sectionLevel = 1,
}) => const FountainLineWriter().writeLine(
  text: text,
  type: type,
  hadForcingMarker: hadForcingMarker,
  previousType: previousType,
  nextRawLine: nextRawLine,
  sectionLevel: sectionLevel,
);

void main() {
  group('scene heading', () {
    test('auto-detectable in context needs no marker', () {
      expect(
        _write('INT. KITCHEN - DAY', FountainLineType.sceneHeading),
        'INT. KITCHEN - DAY',
      );
    });

    test('not surrounded by blank lines gets the "." marker', () {
      expect(
        _write(
          'INT. KITCHEN - DAY',
          FountainLineType.sceneHeading,
          nextRawLine: 'Some action.',
        ),
        '.INT. KITCHEN - DAY',
      );
    });

    test('an explicit marker is preserved even though the text would '
        'auto-detect on its own', () {
      expect(
        _write(
          'INT. KITCHEN - DAY',
          FountainLineType.sceneHeading,
          hadForcingMarker: true,
        ),
        '.INT. KITCHEN - DAY',
      );
    });
  });

  group('action', () {
    test('auto-detectable (the fallback type) needs no marker', () {
      expect(
        _write('Just a regular sentence.', FountainLineType.action),
        'Just a regular sentence.',
      );
    });

    test('text that would otherwise read as a transition gets the "!" '
        'marker', () {
      expect(_write('CUT TO:', FountainLineType.action), '!CUT TO:');
    });

    test('an explicit marker is preserved even though the text would '
        'auto-detect on its own', () {
      expect(
        _write(
          'Just a regular sentence.',
          FountainLineType.action,
          hadForcingMarker: true,
        ),
        '!Just a regular sentence.',
      );
    });
  });

  group('character', () {
    test('auto-detectable in context needs no marker', () {
      expect(
        _write('SARAH', FountainLineType.character, nextRawLine: 'Hello.'),
        'SARAH',
      );
    });

    test('lowercase text gets the "@" marker', () {
      expect(
        _write('sarah', FountainLineType.character, nextRawLine: 'Hello.'),
        '@sarah',
      );
    });

    test('an explicit marker is preserved even though the text would '
        'auto-detect on its own', () {
      expect(
        _write(
          'SARAH',
          FountainLineType.character,
          nextRawLine: 'Hello.',
          hadForcingMarker: true,
        ),
        '@SARAH',
      );
    });
  });

  group('transition', () {
    test('auto-detectable in context needs no marker', () {
      expect(_write('CUT TO:', FountainLineType.transition), 'CUT TO:');
    });

    test('not surrounded by blank lines gets the ">" marker', () {
      expect(
        _write(
          'CUT TO:',
          FountainLineType.transition,
          nextRawLine: 'Some action.',
        ),
        '>CUT TO:',
      );
    });

    test('an explicit marker is preserved even though the text would '
        'auto-detect on its own', () {
      expect(
        _write('CUT TO:', FountainLineType.transition, hadForcingMarker: true),
        '>CUT TO:',
      );
    });
  });

  group('centered text', () {
    test('is always wrapped in ">…<", there is no plain form', () {
      expect(
        _write('THE END', FountainLineType.centeredText),
        '> THE END <',
      );
    });
  });

  group('lyrics', () {
    test('always gets the "~" marker, there is no auto-detection rule', () {
      expect(
        _write('Half a mile from the county fair', FountainLineType.lyrics),
        '~Half a mile from the county fair',
      );
    });

    test('the marker is emitted the same way whether or not '
        'hadForcingMarker is set, since it is never optional', () {
      expect(
        _write(
          'Half a mile from the county fair',
          FountainLineType.lyrics,
          hadForcingMarker: true,
        ),
        '~Half a mile from the county fair',
      );
    });
  });

  group('section', () {
    test('always gets a leading "#", there is no auto-detection rule', () {
      expect(_write('Act One', FountainLineType.section), '# Act One');
    });

    test('sectionLevel controls the number of leading "#" characters', () {
      expect(
        _write('Act One', FountainLineType.section, sectionLevel: 3),
        '### Act One',
      );
    });
  });

  group('synopsis', () {
    test('always gets the "=" marker, there is no auto-detection rule', () {
      expect(
        _write('A short summary.', FountainLineType.synopsis),
        '= A short summary.',
      );
    });
  });

  group('page break', () {
    test('is always the literal "===", the text is ignored', () {
      expect(_write('', FountainLineType.pageBreak), '===');
      expect(_write('ignored', FountainLineType.pageBreak), '===');
    });
  });

  group('dialogue', () {
    test('has no forcing marker: the text is emitted verbatim', () {
      expect(
        _write(
          'Hello there.',
          FountainLineType.dialogue,
          previousType: FountainLineType.character,
        ),
        'Hello there.',
      );
    });

    test('is emitted verbatim even when the context means it will not '
        'round-trip back to dialogue (no marker exists to prevent that)', () {
      expect(
        _write(
          'Hello there.',
          FountainLineType.dialogue,
          previousType: FountainLineType.action,
        ),
        'Hello there.',
      );
    });
  });

  group('parenthetical', () {
    test('has no forcing marker: the text is emitted verbatim', () {
      expect(
        _write(
          '(beat)',
          FountainLineType.parenthetical,
          previousType: FountainLineType.character,
        ),
        '(beat)',
      );
    });
  });

  group('blank', () {
    test('is never written: blank lines are metadata, not written lines', () {
      expect(
        () => _write('', FountainLineType.blank),
        throwsArgumentError,
      );
    });
  });
}
