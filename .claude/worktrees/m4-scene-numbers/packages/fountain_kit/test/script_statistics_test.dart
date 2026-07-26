// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_script_composer.dart';
import 'package:fountain_kit/src/layout/fountain_script_statistics.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_title_page.dart';
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
/// texts wrap, so word/sign counts are unaffected by pagination, with
/// [linesPerPage] left small enough to force multi-page corpora to actually
/// split.
FountainLayoutMetrics _metrics({int linesPerPage = 5}) => FountainLayoutMetrics(
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

FountainTransition _transition(String text) =>
    FountainTransition(sourceRange: _range, text: text, forced: false);

FountainCenteredText _centeredText(String text) =>
    FountainCenteredText(sourceRange: _range, text: text);

FountainLyrics _lyrics(List<String> lines) =>
    FountainLyrics(sourceRange: _range, lines: lines);

FountainSection _section(String text) =>
    FountainSection(sourceRange: _range, level: 1, text: text);

FountainSynopsis _synopsis(String text) =>
    FountainSynopsis(sourceRange: _range, text: text);

FountainNoteBlock _note(String text) =>
    FountainNoteBlock(sourceRange: _range, text: text);

FountainBoneyard _boneyard(String text) =>
    FountainBoneyard(sourceRange: _range, text: text);

const FountainPageBreak _pageBreak = FountainPageBreak(sourceRange: _range);

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

FountainDocument _document(
  List<FountainBlock> blocks, {
  FountainTitlePage? titlePage,
}) => FountainDocument(titlePage: titlePage, blocks: blocks, sourceText: '');

void main() {
  group('FountainScriptStatistics.of', () {
    test('an empty document is all zero', () {
      final stats = FountainScriptStatistics.of(_document(const []), _metrics());

      expect(stats, FountainScriptStatistics.empty);
      expect(stats.pageCount, 0);
      expect(stats.sceneCount, 0);
      expect(stats.speakingCharacterCount, 0);
      expect(stats.wordCount, 0);
      expect(stats.signCount, 0);
    });

    test('counts scenes, words and signs of a short corpus', () {
      final document = _document([
        _sceneHeading('INT. KITCHEN - DAY'),
        _action(['Sarah stirs the soup.']),
        _sceneHeading('EXT. GARDEN - NIGHT'),
        _dialogueGroup('SARAH', [_dialogueLine('It needs more salt.')]),
      ]);

      final stats = FountainScriptStatistics.of(document, _metrics());

      expect(stats.sceneCount, 2);
      // "INT. KITCHEN - DAY" (4) + "Sarah stirs the soup." (4) +
      // "EXT. GARDEN - NIGHT" (4) + "SARAH" (1) + "It needs more salt." (4).
      expect(stats.wordCount, 4 + 4 + 4 + 1 + 4);
      expect(
        stats.signCount,
        'INT.KITCHEN-DAY'.length +
            'Sarahstirsthesoup.'.length +
            'EXT.GARDEN-NIGHT'.length +
            'SARAH'.length +
            'Itneedsmoresalt.'.length,
      );
    });

    test('deduplicates a role cued with and without its extension', () {
      final document = _document([
        _dialogueGroup('SARAH', [_dialogueLine('Hello.')]),
        _dialogueGroup(
          'SARAH',
          [_dialogueLine('Still there?')],
          extension: 'V.O.',
        ),
      ]);

      expect(FountainScriptStatistics.of(document, _metrics()).speakingCharacterCount, 1);
    });

    test('normalizes case and internal whitespace before deduplicating', () {
      final document = _document([
        _dialogueGroup('SARAH   CONNOR', [_dialogueLine('Hi.')]),
        _dialogueGroup('sarah connor', [_dialogueLine('Hi again.')]),
      ]);

      expect(FountainScriptStatistics.of(document, _metrics()).speakingCharacterCount, 1);
    });

    test('dual dialogue counts both characters', () {
      final document = _document([
        _dialogueGroup('SARAH', [_dialogueLine('Now!')]),
        _dialogueGroup(
          'JOHN',
          [_dialogueLine('Go!')],
          isDualDialogue: true,
        ),
      ]);

      expect(FountainScriptStatistics.of(document, _metrics()).speakingCharacterCount, 2);
    });

    test(
      'word and sign counts exclude notes, boneyard, synopsis, section '
      'and the title page',
      () {
        final document = _document(
          [
            _section('Act one'),
            _synopsis('Sarah discovers the truth.'),
            _note('remember to foreshadow this'),
            _boneyard('cut this whole scene maybe'),
            _action(['Only this counts.']),
          ],
          titlePage: const FountainTitlePage(
            entries: [
              FountainTitlePageEntry(
                key: 'Title',
                values: ['A Very Long Screenplay Title'],
                sourceRange: _range,
              ),
            ],
            sourceRange: _range,
          ),
        );

        final stats = FountainScriptStatistics.of(document, _metrics());

        expect(stats.wordCount, 3); // "Only this counts."
        expect(stats.signCount, 'Onlythiscounts.'.length);
      },
    );

    test(
      'pageCount matches FountainScriptComposer().compose(...).pages.length '
      'on a multi-page corpus with a forced page break',
      () {
        final metrics = _metrics(linesPerPage: 3);
        final document = _document([
          _action(['First page.']),
          _pageBreak,
          _transition('CUT TO:'),
          _centeredText('THE END'),
          _lyrics(['La la la']),
        ]);

        final stats = FountainScriptStatistics.of(document, metrics);
        final composed = const FountainScriptComposer().compose(
          document: document,
          metrics: metrics,
        );

        expect(stats.pageCount, composed.pages.length);
        expect(stats.pageCount, greaterThan(1));
      },
    );

    test('parentheticals contribute to word and sign counts', () {
      final document = _document([
        _dialogueGroup('SARAH', [
          _parenthetical('beat'),
          _dialogueLine('Fine.'),
        ]),
      ]);

      final stats = FountainScriptStatistics.of(document, _metrics());

      // "SARAH" (1) + "(beat)" (1) + "Fine." (1).
      expect(stats.wordCount, 3);
      expect(
        stats.signCount,
        'SARAH'.length + '(beat)'.length + 'Fine.'.length,
      );
    });
  });
}
