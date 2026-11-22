// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:fountain_kit/src/layout/fountain_dual_dialogue_pairs.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:test/test.dart';

/// The parser turning the test sources into documents.
const FountainParser _parser = FountainParser();

/// The classifier typing the test sources' lines.
const FountainLineClassifier _classifier = FountainLineClassifier();

/// Get the pairs of [source] found over its blocks, as the source lines of their cues.
List<(int, int)> _blockPairLines(String source) {
  final blocks = _parser.parse(source).blocks;
  return [
    for (final pair in fountainDualDialoguePairs(blocks))
      (blocks[pair.left].sourceRange.startLine, blocks[pair.right].sourceRange.startLine),
  ];
}

/// Get the pairs of [source] found over its lines, as the source lines of their cues.
List<(int, int)> _linePairLines(String source) {
  final lines = source.split('\n');
  return [
    for (final pair in fountainDualDialogueLinePairs(_classifier.classify(lines), lines))
      (pair.left.start, pair.right.start),
  ];
}

/// Assert that both rules find [expected] in [source].
void _expectPairs(String source, List<(int, int)> expected) {
  expect(_blockPairLines(source), expected, reason: 'blocks');
  expect(_linePairLines(source), expected, reason: 'lines');
}

/// Run the tests of the dual dialogue pairing.
void main() {
  group('pairing', () {
    test('two adjacent groups, the second carrying ^, form a pair', () {
      _expectPairs('ROSS\nFirst.\n\nKIM^\nSecond.\n', [(0, 3)]);
    });

    test('a pair keeps its parentheticals and several blank lines', () {
      _expectPairs('ROSS\n(sighs)\nFirst.\n\n\nKIM^\nSecond.\n', [(0, 5)]);
    });

    test('indices are the positions among the blocks', () {
      final blocks = _parser.parse('INT. ROOM - DAY\n\nROSS\nFirst.\n\nKIM^\nSecond.\n').blocks;
      expect(fountainDualDialoguePairs(blocks), [(left: 1, right: 2)]);
    });

    test('the ROSS / KIM^ / ROSS^ chain pairs the first two and leaves the third alone', () {
      _expectPairs('ROSS\nA.\n\nKIM^\nB.\n\nROSS^\nC.\n', [(0, 3)]);
    });

    test('a ^ with no dialogue group before it is an orphan', () {
      _expectPairs('INT. ROOM - DAY\n\nKIM^\nAlone.\n', []);
      _expectPairs('Some action.\n\nKIM^\nAlone.\n', []);
    });

    test('a group without ^ after another is no pair', () {
      _expectPairs('ROSS\nA.\n\nKIM\nB.\n', []);
    });

    test('a note between the groups breaks the pair', () {
      _expectPairs('ROSS\nA.\n\n[[a note]]\n\nKIM^\nB.\n', []);
    });

    test('a section between the groups breaks the pair', () {
      _expectPairs('ROSS\nA.\n\n# Act two\n\nKIM^\nB.\n', []);
    });

    test('a synopsis between the groups breaks the pair', () {
      _expectPairs('ROSS\nA.\n\n= What happens\n\nKIM^\nB.\n', []);
    });

    test('a cue with an inline note, an extension or the @ forcing still pairs', () {
      _expectPairs('ROSS\nA.\n\nKIM [[aside]]^\nB.\n', [(0, 3)]);
      _expectPairs('ROSS\nA.\n\nKIM (V.O.)^\nB.\n', [(0, 3)]);
      _expectPairs('ROSS\nA.\n\n@Mc Kim ^\nB.\n', [(0, 3)]);
    });

    test('a ^ inside dialogue text is not a cue marker', () {
      _expectPairs('ROSS\nA.\n\nKIM\nB^\n', []);
    });
  });

  group('corpus', () {
    final files =
        Directory('test/corpus')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.fountain'))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      test('$name: both rules agree', () {
        final source = file.readAsStringSync();
        expect(_linePairLines(source), _blockPairLines(source));
      });
    }

    String read(String name) => File('test/corpus/$name').readAsStringSync();

    test('dual_dialogue.fountain pairs KIM^ with the ROSS before it, and the last two', () {
      final source = read('dual_dialogue.fountain');
      final lines = source.split('\n');
      final pairs = _blockPairLines(source);
      expect(pairs, hasLength(2));
      expect(lines[pairs[0].$1], 'ROSS');
      expect(lines[pairs[0].$2], 'KIM^');
      expect(lines[pairs[1].$1], 'ROSS');
      expect(lines[pairs[1].$2], 'ASSISTANT^');
    });

    test('kitchen_sink.fountain pairs MARY^', () {
      final source = read('kitchen_sink.fountain');
      final lines = source.split('\n');
      final pairs = _blockPairLines(source);
      expect(pairs.map((pair) => lines[pair.$2]), ['MARY^']);
    });

    test('edge_cases.fountain pairs the forced cue', () {
      final source = read('edge_cases.fountain');
      final lines = source.split('\n');
      final pairs = _blockPairLines(source);
      expect(pairs.map((pair) => lines[pair.$2]), ['@DETECTIVE KAY^']);
    });
  });
}
