// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:fountain_kit/src/serializer/fountain_serializer.dart';
import 'package:test/test.dart';

const FountainParser _parser = FountainParser();
const FountainSerializer _serializer = FountainSerializer();

/// Asserts that parsing [source], writing it back out, and parsing that
/// output again yields a document equal to the first parse: the round-trip
/// contract [FountainSerializer] promises.
void _expectRoundTrips(String source) {
  final original = _parser.parse(source);
  final rewritten = _serializer.write(original);
  final reparsed = _parser.parse(rewritten);
  expect(reparsed.blocks, original.blocks);
  expect(reparsed.titlePage, original.titlePage);
}

void main() {
  group('individual elements round-trip', () {
    test('scene heading', () {
      _expectRoundTrips('INT. KITCHEN - DAY\n\nSome action.\n');
    });

    test('forced scene heading', () {
      _expectRoundTrips('.THE VOID\n\nSome action.\n');
    });

    test('scene heading with a scene number', () {
      _expectRoundTrips('INT. KITCHEN - DAY #4A#\n\nSome action.\n');
    });

    test('forced action', () {
      _expectRoundTrips('!INT. NOT REALLY A HEADING\n');
    });

    test('multi-line action', () {
      _expectRoundTrips('Line one.\nLine two.\nLine three.\n');
    });

    test('dialogue with a parenthetical', () {
      _expectRoundTrips('SARAH\n(beat)\nHello there.\n');
    });

    test('character with an extension', () {
      _expectRoundTrips('SARAH (V.O.)\nHello there.\n');
    });

    test('forced, lowercase character', () {
      _expectRoundTrips('@McCLANE\nYippee-ki-yay.\n');
    });

    test('dual dialogue', () {
      _expectRoundTrips('ROSS\nFirst.\n\nKIM^\nSecond.\n');
    });

    test('preserved blank dialogue line', () {
      _expectRoundTrips('SARAH\nHello.\n  \nStill here.\n');
    });

    test('transition', () {
      _expectRoundTrips('CUT TO:\n\nINT. HOUSE - DAY\n\nAction.\n');
    });

    test('forced transition', () {
      _expectRoundTrips('>Burn to white.\n\nINT. HOUSE - DAY\n\nAction.\n');
    });

    test('centered text', () {
      _expectRoundTrips('> THE END <\n');
    });

    test('lyrics', () {
      _expectRoundTrips('~Line one\n~Line two\n');
    });

    test('section', () {
      _expectRoundTrips('## Sequence B\n');
    });

    test('synopsis', () {
      _expectRoundTrips('= A short summary.\n');
    });

    test('standalone note', () {
      _expectRoundTrips('Action before.\n\n[[a note]]\n\nAction after.\n');
    });

    test('boneyard comment', () {
      _expectRoundTrips(
        'Action before.\n\n/* cut for pacing */\n\nAction after.\n',
      );
    });

    test('page break', () {
      _expectRoundTrips('Action before.\n\n===\n\nAction after.\n');
    });
  });

  group('title page round-trips', () {
    test('single-line values', () {
      _expectRoundTrips(
        'Title: My Screenplay\nCredit: written by\n\nINT. HOUSE - DAY\n',
      );
    });

    test('multi-line values', () {
      _expectRoundTrips(
        'Contact:\n    Open Cine Prod Tools\n    123 Reel Street\n\nINT. HOUSE - DAY\n',
      );
    });
  });

  group('writer output shape', () {
    test(
      'produces text a scene heading is recognizable from without forcing',
      () {
        final document = _parser.parse('INT. KITCHEN - DAY\n\nAction.\n');
        final written = _serializer.write(document);
        final heading = document.blocks.first as FountainSceneHeading;
        expect(heading.forcedMarker, isFalse);
        expect(written, contains('INT. KITCHEN - DAY'));
        expect(written, isNot(contains('.INT. KITCHEN - DAY')));
      },
    );

    test('re-forces a character cue whose name is not all uppercase', () {
      final document = _parser.parse('@McCLANE\nYippee-ki-yay.\n');
      final written = _serializer.write(document);
      expect(written, startsWith('@McCLANE'));
    });
  });

  group('empty document', () {
    test('an empty source round-trips to an empty document', () {
      _expectRoundTrips('');
    });
  });
}
