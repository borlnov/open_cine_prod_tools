// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:test/test.dart';

/// The parser the tests read lines with.
const FountainInlineParser _parser = FountainInlineParser();

/// The serializer the tests write runs back with.
const FountainInlineSerializer _serializer = FountainInlineSerializer();

/// Get the offsets of the `*` of the boneyard delimiters of [line], the way a caller knows them.
Set<int> _starsOf(String line) => {
  for (final span in FountainCommentSpans.of(line))
    if (span.isBoneyard) ...[span.start + 1, span.end - 2],
};

/// Parse [line] into runs and write them back, boneyard delimiters read as plain text.
String _roundTrip(String line) {
  final runs = _parser.parseRuns(line, literalStars: _starsOf(line));
  // The serializer reads the delimiters in the plain text of the runs.
  final plainText = runs.map((run) => run.text).join();
  return _serializer.write(runs, literalStars: _starsOf(plainText));
}

/// Run the tests of the boneyard delimiters and the escaped notes in inline text.
void main() {
  group('a boneyard delimiter handed to the parser is never emphasis', () {
    test('a closed boneyard on a line is plain text', () {
      const line = 'He /* x */ runs.';
      final runs = _parser.parseRuns(line, literalStars: _starsOf(line));

      expect(runs.single.text, line);
      expect(runs.single.isItalic, isFalse);
    });

    test('emphasis inside a boneyard is still read', () {
      const line = '/* *a* */';
      final runs = _parser.parseRuns(line, literalStars: _starsOf(line));

      expect(runs.map((run) => (run.text, run.isItalic)), [
        ('/* ', false),
        ('a', true),
        (' */', false),
      ]);
    });

    test('a boneyard inside an emphasis span stays in it', () {
      const line = 'He **runs /* x */ fast**.';
      final runs = _parser.parseRuns(line, literalStars: _starsOf(line));

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

  group('without boneyard delimiters the parser reads a * beside a / as ever', () {
    test('emphasis touching a slash keeps its emphasis', () {
      expect(_parser.parseRuns('He said *yes*/no.').map((run) => (run.text, run.isItalic)), [
        ('He said ', false),
        ('yes', true),
        ('/no.', false),
      ]);
      expect(_parser.parseRuns('his/*her* car').map((run) => (run.text, run.isItalic)), [
        ('his/', false),
        ('her', true),
        (' car', false),
      ]);
      expect(_parser.parseRuns('*and*/or').map((run) => (run.text, run.isItalic)), [
        ('and', true),
        ('/or', false),
      ]);
      expect(_parser.parseRuns('**A**/**B**').map((run) => (run.text, run.isBold)), [
        ('A', true),
        ('/', false),
        ('B', true),
      ]);
      expect(_parser.parseRuns('**bold**/').map((run) => (run.text, run.isBold)), [
        ('bold', true),
        ('/', false),
      ]);
    });

    test('an unclosed /* is no boneyard, its star stays an ordinary character', () {
      const line = 'a /* b *c* d';
      expect(_starsOf(line), isEmpty);
      expect(_roundTrip(line), line);
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
