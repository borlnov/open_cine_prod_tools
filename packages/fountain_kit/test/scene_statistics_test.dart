// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_scene_statistics.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:test/test.dart';

/// A source range every hand-built block in this file shares: neither block
/// equality nor the statistics computation looks at it.
const FountainSourceRange _range = FountainSourceRange(
  startLine: 0,
  endLine: 0,
  startOffset: 0,
  endOffset: 0,
);

/// A [FountainElementLayout] with only the measurement this suite exercises
/// (column width) left to specify.
FountainElementLayout _box(int maxWidthColumns) => FountainElementLayout(
  leftIndentInches: 0,
  leftIndentColumns: 0,
  maxWidthInches: maxWidthColumns / 10,
  maxWidthColumns: maxWidthColumns,
  alignment: FountainLayoutAlignment.left,
);

/// A [FountainLayoutMetrics] wide enough that none of this suite's short
/// texts wrap, so line counts are driven only by [linesPerPage] and the
/// composer's own placement rules (spacers, dialogue splitting), not by
/// word wrap.
FountainLayoutMetrics _metrics({required int linesPerPage}) => FountainLayoutMetrics(
  pageWidthInches: 8.5,
  pageHeightInches: 11,
  marginLeftInches: 1.5,
  marginRightInches: 1,
  marginTopInches: 1,
  marginBottomInches: 1,
  charsPerInch: 10,
  linesPerInch: 6,
  linesPerPage: linesPerPage,
  sceneHeading: _box(60),
  action: _box(60),
  character: _box(30),
  parenthetical: _box(30),
  dialogue: _box(30),
  transition: _box(60),
  centeredText: _box(60),
  lyrics: _box(30),
);

FountainSceneHeading _sceneHeading(String headingText) => FountainSceneHeading(
  sourceRange: _range,
  rawText: headingText,
  headingText: headingText,
  forcedMarker: false,
);

FountainActionBlock _action(List<String> lines) =>
    FountainActionBlock(sourceRange: _range, lines: lines, forced: false);

FountainCharacter _character(String name, {bool isDualDialogue = false}) =>
    FountainCharacter(sourceRange: _range, name: name, isDualDialogue: isDualDialogue);

FountainDialogueLine _dialogueLine(String text) => FountainDialogueLine(sourceRange: _range, text: text);

FountainDialogueGroup _dialogueGroup(
  String name,
  List<FountainBlock> children, {
  bool isDualDialogue = false,
}) => FountainDialogueGroup(
  sourceRange: _range,
  character: _character(name, isDualDialogue: isDualDialogue),
  children: children,
  isDualDialogue: isDualDialogue,
);

FountainDocument _document(List<FountainBlock> blocks) =>
    FountainDocument(titlePage: null, blocks: blocks, sourceText: '');

void main() {
  group('FountainSceneStatistics.of', () {
    test('no scene: an out-of-range index is rejected', () {
      final document = _document(const []);

      expect(
        () => FountainSceneStatistics.of(document, _metrics(linesPerPage: 48), 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('one scene: covers the whole document', () {
      final document = _document([
        _sceneHeading('INT. KITCHEN - DAY'),
        _action(['Sarah stirs the soup.']),
        _dialogueGroup('SARAH', [_dialogueLine('It needs more salt.')]),
      ]);

      final stats = FountainSceneStatistics.of(document, _metrics(linesPerPage: 48), 0);

      expect(stats.speakingCharacters, ['SARAH']);
      // "INT. KITCHEN - DAY" (4) + "Sarah stirs the soup." (4) + "SARAH" (1)
      // + "It needs more salt." (4).
      expect(stats.wordCount, 4 + 4 + 1 + 4);
      // Composed as heading, spacer, action, spacer, cue, dialogue: 6 lines
      // on a 48-line page is exactly 1 eighth.
      expect(stats.pageEighths, 1);
    });

    test('several scenes: each keeps only its own content', () {
      final document = _document([
        _sceneHeading('INT. KITCHEN - DAY'),
        _action(['Sarah stirs the soup.']),
        _sceneHeading('EXT. GARDEN - NIGHT'),
        _action(['The soup is ready.']),
      ]);
      final metrics = _metrics(linesPerPage: 8);

      final first = FountainSceneStatistics.of(document, metrics, 0);
      final second = FountainSceneStatistics.of(document, metrics, 1);

      // "INT. KITCHEN - DAY" (4) + "Sarah stirs the soup." (4).
      expect(first.wordCount, 4 + 4);
      expect(first.speakingCharacters, isEmpty);
      // Composed as heading, spacer, action, spacer (before the next
      // heading): 4 lines on an 8-line page is exactly 4 eighths.
      expect(first.pageEighths, 4);

      // "EXT. GARDEN - NIGHT" (4) + "The soup is ready." (4).
      expect(second.wordCount, 4 + 4);
      expect(second.speakingCharacters, isEmpty);
      // Composed as heading, spacer, action: 3 lines on an 8-line page is
      // exactly 3 eighths.
      expect(second.pageEighths, 3);
    });

    test('a scene with dual dialogue: both cues are kept, in order', () {
      final document = _document([
        _sceneHeading('INT. KITCHEN - DAY'),
        _dialogueGroup('SARAH', [_dialogueLine('Now!')]),
        _dialogueGroup('JOHN', [_dialogueLine('Go!')], isDualDialogue: true),
      ]);

      final stats = FountainSceneStatistics.of(document, _metrics(linesPerPage: 48), 0);

      expect(stats.speakingCharacters, ['SARAH', 'JOHN']);
      // "INT. KITCHEN - DAY" (4) + "SARAH" (1) + "Now!" (1) + "JOHN" (1) +
      // "Go!" (1).
      expect(stats.wordCount, 4 + 1 + 1 + 1 + 1);
    });

    test('the last scene of the script runs to the end, nothing truncated', () {
      final document = _document([
        _sceneHeading('INT. KITCHEN - DAY'),
        _action(['Sarah stirs the soup.']),
        _sceneHeading('EXT. GARDEN - NIGHT'),
        _action(['The soup is ready.']),
        _action(['She carries it outside.']),
      ]);
      final metrics = _metrics(linesPerPage: 48);

      final stats = FountainSceneStatistics.of(document, metrics, document.scenes.length - 1);

      // "EXT. GARDEN - NIGHT" (4) + "The soup is ready." (4) +
      // "She carries it outside." (4).
      expect(stats.wordCount, 4 + 4 + 4);
      expect(stats.speakingCharacters, isEmpty);
      expect(stats.pageEighths, greaterThan(0));
    });
  });
}
