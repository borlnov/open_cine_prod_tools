// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:test/test.dart';

/// The parser the tests read lines with.
const FountainInlineParser _parser = FountainInlineParser();

/// The serializer the tests write runs back with.
const FountainInlineSerializer _serializer = FountainInlineSerializer();

/// Parse [line] into runs and write them back.
String _roundTrip(String line) => _serializer.write(_parser.parseRuns(line));

/// Run the tests of the boneyard delimiters and the escaped notes in inline text.
void main() {
  group('a boneyard delimiter is never emphasis', () {
    test('a closed boneyard on a line is plain text', () {
      final runs = _parser.parseRuns('He /* x */ runs.');

      expect(runs.single.text, 'He /* x */ runs.');
      expect(runs.single.isItalic, isFalse);
    });

    test('emphasis inside a boneyard is still read', () {
      final runs = _parser.parseRuns('/* *a* */');

      expect(runs.map((run) => (run.text, run.isItalic)), [
        ('/* ', false),
        ('a', true),
        (' */', false),
      ]);
    });

    test('a boneyard inside an emphasis span stays in it', () {
      final runs = _parser.parseRuns('He **runs /* x */ fast**.');

      expect(runs.map((run) => (run.text, run.isBold)), [
        ('He ', false),
        ('runs /* x */ fast', true),
        ('.', false),
      ]);
    });

    test('lines with delimiters are written back identically', () {
      const lines = [
        'He /* x */ runs.',
        '/* *a* */',
        'a /* b */ c *d*',
        'He **runs /* x */ fast**.',
        'He *x /* y* */ z.',
        'He _runs /* x */ fast_.',
        '**bold /* x',
        'y */ z**',
        '/* a * b */',
        '/**/',
      ];
      for (final line in lines) {
        expect(_roundTrip(line), line, reason: line);
      }
    });
  });

  group('an escaped note is printed text', () {
    test('the comment spans open no note on an escaped bracket', () {
      expect(FountainCommentSpans.notes(r'He \[[x]] y.'), isEmpty);
      expect(FountainCommentSpans.notes(r'He \\[[x]] y.'), hasLength(1));
      expect(FountainCommentSpans.notes(r'\[[[x]]'), hasLength(1));
      expect(FountainCommentSpans.notes(r'He \[[x]] y.', honoursEscapes: false), hasLength(1));
    });

    test('the parser prints it, and the line is not classified around it', () {
      final blocks = const FountainParser().parse(r'He \[[x]] y.').blocks;

      expect(blocks.single, isA<FountainActionBlock>());
      expect(
        const FountainParser().parse(r'\[[x]]INT. HOUSE - DAY').blocks.single,
        isA<FountainActionBlock>(),
      );
    });

    test('the inline parser and the serializer agree', () {
      expect(_roundTrip(r'He \[[x]] y.'), r'He \[[x]] y.');
    });
  });
}
