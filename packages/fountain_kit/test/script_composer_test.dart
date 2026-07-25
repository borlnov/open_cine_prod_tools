// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_script_composer.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
import 'package:test/test.dart';

/// A source range every hand-built block in this file shares: block
/// equality and this composer's own logic never look at it.
const FountainSourceRange _range = FountainSourceRange(
  startLine: 0,
  endLine: 0,
  startOffset: 0,
  endOffset: 0,
);

/// Builds an [FountainElementLayout] with only the measurements this suite
/// exercises left to specify: a column width and, optionally, a left
/// indent/alignment, so tests can size element boxes precisely instead of
/// depending on a real page preset's numbers.
FountainElementLayout _box(
  int maxWidthColumns, {
  double leftIndentInches = 0,
  FountainLayoutAlignment alignment = FountainLayoutAlignment.left,
}) => FountainElementLayout(
  leftIndentInches: leftIndentInches,
  leftIndentColumns: (leftIndentInches * 10).round(),
  maxWidthInches: maxWidthColumns / 10,
  maxWidthColumns: maxWidthColumns,
  alignment: alignment,
);

/// Builds a [FountainLayoutMetrics] with a custom [linesPerPage] and
/// per-element column widths, so pagination tests can control exactly how
/// many lines fit on a page instead of depending on a real preset's
/// (comparatively large) page.
FountainLayoutMetrics _metrics({
  required int linesPerPage,
  int sceneHeadingCols = 60,
  int actionCols = 60,
  int characterCols = 30,
  int parentheticalCols = 30,
  int dialogueCols = 30,
  int transitionCols = 60,
  int centeredCols = 60,
  int lyricsCols = 30,
}) => FountainLayoutMetrics(
  pageWidthInches: 8.5,
  pageHeightInches: 11,
  marginLeftInches: 1.5,
  marginRightInches: 1,
  marginTopInches: 1,
  marginBottomInches: 1,
  charsPerInch: 10,
  linesPerInch: 6,
  linesPerPage: linesPerPage,
  sceneHeading: _box(sceneHeadingCols, leftIndentInches: 1.5),
  action: _box(actionCols, leftIndentInches: 1.5),
  character: _box(characterCols, leftIndentInches: 3.7),
  parenthetical: _box(parentheticalCols, leftIndentInches: 3.1),
  dialogue: _box(dialogueCols, leftIndentInches: 2.5),
  transition: _box(
    transitionCols,
    leftIndentInches: 1.5,
    alignment: FountainLayoutAlignment.right,
  ),
  centeredText: _box(
    centeredCols,
    leftIndentInches: 1.5,
    alignment: FountainLayoutAlignment.center,
  ),
  lyrics: _box(lyricsCols, leftIndentInches: 2.5),
);

FountainActionBlock _action(List<String> lines) =>
    FountainActionBlock(sourceRange: _range, lines: lines, forced: false);

FountainSceneHeading _sceneHeading(String headingText, {String? sceneNumber}) =>
    FountainSceneHeading(
      sourceRange: _range,
      rawText: headingText,
      headingText: headingText,
      forcedMarker: false,
      sceneNumber: sceneNumber,
    );

FountainTransition _transition(String text) =>
    FountainTransition(sourceRange: _range, text: text, forced: false);

FountainCenteredText _centeredText(String text) =>
    FountainCenteredText(sourceRange: _range, text: text);

FountainLyrics _lyrics(List<String> lines) =>
    FountainLyrics(sourceRange: _range, lines: lines);

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

FountainParenthetical _parenthetical(String text) =>
    FountainParenthetical(sourceRange: _range, text: text);

FountainDialogueLine _dialogueLine(String text) =>
    FountainDialogueLine(sourceRange: _range, text: text);

FountainDialogueGroup _dialogueGroup(
  String name,
  List<FountainBlock> children, {
  bool isDualDialogue = false,
  String? extension,
}) => FountainDialogueGroup(
  sourceRange: _range,
  character: _character(
    name,
    extension: extension,
    isDualDialogue: isDualDialogue,
  ),
  children: children,
  isDualDialogue: isDualDialogue,
);

const FountainPageBreak _pageBreak = FountainPageBreak(sourceRange: _range);

FountainDocument _document(List<FountainBlock> blocks) =>
    FountainDocument(titlePage: null, blocks: blocks, sourceText: '');

/// How many [wordLen]-character words a greedy word wrap fits on one line
/// [cols] columns wide (one space between words).
int _wordsPerLine(int cols, int wordLen) => (cols + 1) ~/ (wordLen + 1);

/// Joins [count] copies of [word] with single spaces, for a text whose
/// wrapped line count is easy to predict by hand.
String _words(String word, int count) => List.filled(count, word).join(' ');

const FountainScriptComposer _composer = FountainScriptComposer();

void main() {
  group('word-wrap widths per element type', () {
    test('scene heading wraps at metrics.sceneHeading.maxWidthColumns', () {
      const cols = 20;
      const wordLen = 4;
      final perLine = _wordsPerLine(cols, wordLen);
      final metrics = _metrics(linesPerPage: 100, sceneHeadingCols: cols);
      final layout = _composer.compose(
        document: _document([_sceneHeading(_words('AAAA', perLine * 3))]),
        metrics: metrics,
      );
      expect(layout.pages.single.lines, hasLength(3));
    });

    test('action wraps at metrics.action.maxWidthColumns', () {
      const cols = 14;
      const wordLen = 4;
      final perLine = _wordsPerLine(cols, wordLen);
      final metrics = _metrics(linesPerPage: 100, actionCols: cols);
      final layout = _composer.compose(
        document: _document([
          _action([_words('AAAA', perLine * 3)]),
        ]),
        metrics: metrics,
      );
      expect(layout.pages.single.lines, hasLength(3));
    });

    test(
      'a long action paragraph wraps at the real US Letter preset '
      'action.maxWidthColumns',
      () {
        final metrics = FountainLayoutMetrics.usLetter();
        final cols = metrics.action.maxWidthColumns;
        const wordLen = 9;
        final perLine = _wordsPerLine(cols, wordLen);
        final layout = _composer.compose(
          document: _document([
            _action([_words('A' * wordLen, perLine * 3)]),
          ]),
          metrics: metrics,
        );
        expect(layout.pages.single.lines, hasLength(3));
      },
    );

    test('character cue wraps at metrics.character.maxWidthColumns', () {
      const cols = 9;
      const wordLen = 3;
      final perLine = _wordsPerLine(cols, wordLen);
      final metrics = _metrics(linesPerPage: 100, characterCols: cols);
      // A character cue never appears at the top level; wrap it through a
      // dialogue group's character name, with a single short dialogue line.
      final layout = _composer.compose(
        document: _document([
          _dialogueGroup(_words('AAA', perLine * 4), [_dialogueLine('Hi.')]),
        ]),
        metrics: metrics,
      );
      final cueLines = layout.pages.single.lines
          .where((line) => line.lineType == FountainLineType.character)
          .toList();
      expect(cueLines, hasLength(4));
    });

    test('parenthetical wraps its parens-included text and hard-wraps a '
        'single overlong word', () {
      final metrics = _metrics(linesPerPage: 100, parentheticalCols: 10);
      final layout = _composer.compose(
        document: _document([
          _dialogueGroup('BOB', [
            _parenthetical('A' * 9),
            _dialogueLine('Hi.'),
          ]),
        ]),
        metrics: metrics,
      );
      final parentheticalLines = layout.pages.single.lines
          .where((line) => line.lineType == FountainLineType.parenthetical)
          .toList();
      expect(parentheticalLines, hasLength(2));
      expect(parentheticalLines[0].plainText, '(AAAAAAAAA');
      expect(parentheticalLines[1].plainText, ')');
    });

    test('dialogue wraps at metrics.dialogue.maxWidthColumns', () {
      const cols = 19;
      const wordLen = 4;
      final perLine = _wordsPerLine(cols, wordLen);
      final metrics = _metrics(linesPerPage: 100, dialogueCols: cols);
      final layout = _composer.compose(
        document: _document([
          _dialogueGroup('BOB', [
            _dialogueLine(_words('AAAA', perLine * 4)),
          ]),
        ]),
        metrics: metrics,
      );
      final dialogueLines = layout.pages.single.lines
          .where((line) => line.lineType == FountainLineType.dialogue)
          .toList();
      expect(dialogueLines, hasLength(4));
    });

    test('transition wraps at metrics.transition.maxWidthColumns', () {
      const cols = 24;
      const wordLen = 4;
      final perLine = _wordsPerLine(cols, wordLen);
      final metrics = _metrics(linesPerPage: 100, transitionCols: cols);
      final layout = _composer.compose(
        document: _document([_transition(_words('AAAA', perLine * 3))]),
        metrics: metrics,
      );
      expect(layout.pages.single.lines, hasLength(3));
    });

    test('lyrics wrap at metrics.lyrics.maxWidthColumns', () {
      const cols = 4;
      const wordLen = 4;
      final perLine = _wordsPerLine(cols, wordLen);
      final metrics = _metrics(linesPerPage: 100, lyricsCols: cols);
      final layout = _composer.compose(
        document: _document([
          _lyrics([_words('AAAA', perLine * 5)]),
        ]),
        metrics: metrics,
      );
      expect(layout.pages.single.lines, hasLength(5));
    });

    test('centered text wraps at metrics.centeredText.maxWidthColumns', () {
      const cols = 29;
      const wordLen = 4;
      final perLine = _wordsPerLine(cols, wordLen);
      final metrics = _metrics(linesPerPage: 100, centeredCols: cols);
      final layout = _composer.compose(
        document: _document([_centeredText(_words('AAAA', perLine * 3))]),
        metrics: metrics,
      );
      expect(layout.pages.single.lines, hasLength(3));
    });
  });

  group('page breaks', () {
    test('a page break forces the next block onto a fresh page', () {
      final metrics = _metrics(linesPerPage: 20);
      final layout = _composer.compose(
        document: _document([
          _action(['First page.']),
          _pageBreak,
          _action(['Second page.']),
        ]),
        metrics: metrics,
      );
      expect(layout.pages, hasLength(2));
      expect(layout.pages[0].lines.single.plainText, 'First page.');
      expect(layout.pages[1].lines.single.plainText, 'Second page.');
    });

    test('two consecutive page breaks do not create a blank page', () {
      final metrics = _metrics(linesPerPage: 20);
      final layout = _composer.compose(
        document: _document([
          _action(['First page.']),
          _pageBreak,
          _pageBreak,
          _action(['Second page.']),
        ]),
        metrics: metrics,
      );
      expect(layout.pages, hasLength(2));
    });

    test('a page break as the very first block does not create a blank '
        'page', () {
      final metrics = _metrics(linesPerPage: 20);
      final layout = _composer.compose(
        document: _document([_pageBreak, _action(['Only page.'])]),
        metrics: metrics,
      );
      expect(layout.pages, hasLength(1));
      expect(layout.pages.single.lines.single.plainText, 'Only page.');
    });
  });

  group('dialogue split across a page boundary', () {
    test(
      '(MORE) closes the page and NAME (CONT\'D) reopens it with the '
      'remaining dialogue lines',
      () {
        final metrics = _metrics(linesPerPage: 5, dialogueCols: 10);
        final layout = _composer.compose(
          document: _document([
            _dialogueGroup('SARAH', [
              _dialogueLine(_words('AAAA', 12)),
            ]),
          ]),
          metrics: metrics,
        );

        expect(layout.pages, hasLength(2));

        final page0 = layout.pages[0].lines;
        expect(page0, hasLength(5));
        expect(page0.first.lineType, FountainLineType.character);
        expect(page0.first.plainText, 'SARAH');
        expect(page0.last.plainText, '(MORE)');
        expect(page0.last.lineType, FountainLineType.parenthetical);
        final page0DialogueLines = page0
            .where((line) => line.lineType == FountainLineType.dialogue)
            .toList();
        expect(page0DialogueLines, hasLength(3));

        final page1 = layout.pages[1].lines;
        expect(page1.first.plainText, "SARAH (CONT'D)");
        expect(page1.first.lineType, FountainLineType.character);
        final page1DialogueLines = page1
            .where((line) => line.lineType == FountainLineType.dialogue)
            .toList();
        expect(page1DialogueLines, hasLength(3));

        // No dialogue content is lost or duplicated across the split.
        expect(page0DialogueLines.length + page1DialogueLines.length, 6);
      },
    );
  });

  group('orphan scene heading', () {
    test(
      'a scene heading that would land as a page\'s last line is pushed '
      'to the next page instead',
      () {
        final metrics = _metrics(linesPerPage: 5);
        final layout = _composer.compose(
          document: _document([
            _action(['One.', 'Two.', 'Three.', 'Four.']),
            _sceneHeading('INT. HOUSE - DAY'),
            _action(['More.', 'Even more.']),
          ]),
          metrics: metrics,
        );

        expect(layout.pages, hasLength(2));
        expect(layout.pages[0].lines, hasLength(4));
        expect(
          layout.pages[0].lines.any((line) => line.isSceneHeading),
          isFalse,
        );

        final page1 = layout.pages[1].lines;
        expect(page1.first.isSceneHeading, isTrue);
        expect(page1.first.plainText, 'INT. HOUSE - DAY');
      },
    );
  });

  group('orphan character cue', () {
    test(
      'a cue that would land as a page\'s last line is pushed, with its '
      'whole group, to the next page',
      () {
        final metrics = _metrics(linesPerPage: 5);
        final layout = _composer.compose(
          document: _document([
            _action(['One.', 'Two.', 'Three.', 'Four.']),
            _dialogueGroup('BOB', [_dialogueLine('Hi there.')]),
          ]),
          metrics: metrics,
        );

        expect(layout.pages, hasLength(2));
        expect(layout.pages[0].lines, hasLength(4));
        expect(
          layout.pages[0].lines.any(
            (line) => line.lineType == FountainLineType.character,
          ),
          isFalse,
        );

        final page1 = layout.pages[1].lines;
        expect(page1, hasLength(2));
        expect(page1[0].lineType, FountainLineType.character);
        expect(page1[0].plainText, 'BOB');
        expect(page1[1].lineType, FountainLineType.dialogue);
      },
    );
  });

  group('linesPerPage boundary', () {
    test(
      'a block that exactly uses the remaining capacity stays on the '
      'same page, filling it to exactly linesPerPage',
      () {
        final metrics = _metrics(linesPerPage: 6);
        final layout = _composer.compose(
          document: _document([
            _action(['1.', '2.', '3.', '4.']),
            _action(['5.']),
            _action(['6.']),
          ]),
          metrics: metrics,
        );

        expect(layout.pages, hasLength(2));
        expect(layout.pages[0].lines, hasLength(6));
        expect(layout.pages[0].lines.last.plainText, '5.');
        expect(layout.pages[1].lines.single.plainText, '6.');
      },
    );

    test(
      'one line less of remaining capacity pushes the next block to a '
      'fresh page instead',
      () {
        final metrics = _metrics(linesPerPage: 6);
        final layout = _composer.compose(
          document: _document([
            _action(['1.', '2.', '3.', '4.', '5.']),
            _action(['6.']),
          ]),
          metrics: metrics,
        );

        expect(layout.pages, hasLength(2));
        expect(layout.pages[0].lines, hasLength(6));
        expect(layout.pages[1].lines.single.plainText, '6.');
      },
    );
  });

  group('dual dialogue adjacency', () {
    test(
      'two adjacent dialogue groups, the second dual, both appear in '
      'order with exactly one spacer between them',
      () {
        final metrics = _metrics(linesPerPage: 20);
        final layout = _composer.compose(
          document: _document([
            _dialogueGroup('ROSS', [_dialogueLine('First.')]),
            _dialogueGroup(
              'KIM',
              [_dialogueLine('Second.')],
              isDualDialogue: true,
            ),
          ]),
          metrics: metrics,
        );

        final lines = layout.pages.single.lines;
        expect(lines, hasLength(5));
        expect(lines[0].plainText, 'ROSS');
        expect(lines[1].plainText, 'First.');
        expect(lines[2].lineType, FountainLineType.blank);
        expect(lines[2].runs, isEmpty);
        expect(lines[3].plainText, 'KIM');
        expect(lines[4].plainText, 'Second.');
      },
    );
  });

  group('inline styled runs survive wrapping', () {
    test(
      'a bold span crossing a wrap boundary is split into two runs, each '
      'keeping isBold, and each line\'s runs join back to its plain text',
      () {
        final metrics = _metrics(linesPerPage: 20, actionCols: 11);
        final layout = _composer.compose(
          document: _document([
            _action(['normal **bold words here** end']),
          ]),
          metrics: metrics,
        );

        final lines = layout.pages.single.lines;
        expect(lines, hasLength(3));

        expect(lines[0].plainText, 'normal bold');
        expect(lines[0].runs, hasLength(2));
        expect(lines[0].runs[0].isBold, isFalse);
        expect(lines[0].runs[0].text, 'normal ');
        expect(lines[0].runs[1].isBold, isTrue);
        expect(lines[0].runs[1].text, 'bold');

        expect(lines[1].plainText, 'words here');
        expect(lines[1].runs, hasLength(1));
        expect(lines[1].runs.single.isBold, isTrue);

        expect(lines[2].plainText, 'end');
        expect(lines[2].runs, hasLength(1));
        expect(lines[2].runs.single.isBold, isFalse);

        for (final line in lines) {
          expect(line.runs.map((run) => run.text).join(), line.plainText);
        }
      },
    );
  });

  group('print-time uppercasing', () {
    test(
      'a character cue prints upper-cased regardless of source casing',
      () {
        final metrics = _metrics(linesPerPage: 20);
        final layout = _composer.compose(
          document: _document([
            _dialogueGroup('bob', [_dialogueLine('Hi there.')]),
          ]),
          metrics: metrics,
        );

        final cueLine = layout.pages.single.lines.firstWhere(
          (line) => line.lineType == FountainLineType.character,
        );
        expect(cueLine.plainText, 'BOB');
      },
    );

    test(
      "a character cue with an extension prints upper-cased, extension "
      'included',
      () {
        final metrics = _metrics(linesPerPage: 20);
        final layout = _composer.compose(
          document: _document([
            _dialogueGroup(
              'bob',
              [_dialogueLine('Hi there.')],
              extension: "cont'd",
            ),
          ]),
          metrics: metrics,
        );

        final cueLine = layout.pages.single.lines.firstWhere(
          (line) => line.lineType == FountainLineType.character,
        );
        expect(cueLine.plainText, "BOB (CONT'D)");
      },
    );

    test(
      'a forced transition prints upper-cased regardless of source casing',
      () {
        final metrics = _metrics(linesPerPage: 20);
        final layout = _composer.compose(
          document: _document([_transition('burn to white.')]),
          metrics: metrics,
        );

        expect(layout.pages.single.lines.single.plainText, 'BURN TO WHITE.');
      },
    );

    test(
      "a continued NAME (CONT'D) cue prints upper-cased even when the "
      'original cue was lower-cased',
      () {
        final metrics = _metrics(linesPerPage: 5, dialogueCols: 10);
        final layout = _composer.compose(
          document: _document([
            _dialogueGroup('sarah', [
              _dialogueLine(_words('AAAA', 12)),
            ]),
          ]),
          metrics: metrics,
        );

        expect(layout.pages, hasLength(2));
        expect(layout.pages[0].lines.first.plainText, 'SARAH');
        expect(layout.pages[1].lines.first.plainText, "SARAH (CONT'D)");
      },
    );
  });

  group('scene heading print text', () {
    test(
      'an explicitly numbered scene heading prints its heading text alone, '
      'never prefixed with the number: the number is only ever carried '
      'separately as FountainScriptLine.sceneNumber',
      () {
        final metrics = _metrics(linesPerPage: 20);
        final layout = _composer.compose(
          document: _document([
            _sceneHeading('INT. HOUSE - DAY', sceneNumber: '12'),
          ]),
          metrics: metrics,
        );

        final headingLine = layout.pages.single.lines.single;
        expect(headingLine.plainText, 'INT. HOUSE - DAY');
        expect(headingLine.sceneNumber, '12');
        expect(headingLine.isSceneHeading, isTrue);
      },
    );

    test(
      'an unnumbered scene heading prints its heading text with no scene '
      'number',
      () {
        final metrics = _metrics(linesPerPage: 20);
        final layout = _composer.compose(
          document: _document([_sceneHeading('INT. HOUSE - DAY')]),
          metrics: metrics,
        );

        final headingLine = layout.pages.single.lines.single;
        expect(headingLine.plainText, 'INT. HOUSE - DAY');
        expect(headingLine.sceneNumber, isNull);
      },
    );
  });

  group('non-printable blocks', () {
    test(
      'sections, synopses, notes and boneyard comments produce no output '
      'lines',
      () {
        final metrics = _metrics(linesPerPage: 20);
        final layout = _composer.compose(
          document: _document([
            const FountainSection(sourceRange: _range, level: 1, text: 'Act'),
            const FountainSynopsis(sourceRange: _range, text: 'Synopsis.'),
            const FountainNoteBlock(sourceRange: _range, text: 'Note.'),
            const FountainBoneyard(sourceRange: _range, text: 'Cut.'),
          ]),
          metrics: metrics,
        );

        expect(layout.pages, isEmpty);
      },
    );
  });
}
