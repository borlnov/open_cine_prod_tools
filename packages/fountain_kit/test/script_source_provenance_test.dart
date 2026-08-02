// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_script_composer.dart';
import 'package:fountain_kit/src/models/fountain_block.dart';
import 'package:fountain_kit/src/models/fountain_document.dart';
import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:test/test.dart';

/// Builds a [FountainElementLayout] with only the measurements this suite
/// exercises left to specify, so a test can size an element box precisely
/// instead of depending on a real page preset's numbers.
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
/// per-element column widths, so a test can control exactly where the
/// composer wraps a line and where it breaks a page.
FountainLayoutMetrics _metrics({
  int linesPerPage = 100,
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

const FountainParser _parser = FountainParser();
const FountainScriptComposer _composer = FountainScriptComposer();

/// A screenplay parsed and composed in one step, kept together with its
/// source text so a test can quote what a line's range points at instead of
/// asserting on raw offsets.
class _Composed {
  /// Parses and composes [source].
  _Composed(this.source, {FountainLayoutMetrics? metrics})
    : layout = _composer.compose(
        document: _parser.parse(source),
        metrics: metrics ?? _metrics(),
      );

  /// The screenplay source, exactly as parsed.
  final String source;

  /// The composed pages.
  final FountainScriptLayout layout;

  /// Every line of every page, in reading order.
  List<FountainScriptLine> get lines => [
    for (final page in layout.pages) ...page.lines,
  ];

  /// The source text [line]'s range points at, or `null` when it has none.
  String? covered(FountainScriptLine line) {
    final range = line.sourceRange;
    return range == null
        ? null
        : source.substring(range.startOffset, range.endOffset);
  }

  /// The source text every line of [layout] points at, `null` for the lines
  /// with no range of their own, in reading order.
  List<String?> get coveredTexts => lines.map(covered).toList();
}

/// A source range every hand-built block in this file shares: a document
/// assembled by hand carries no source text for a range to address.
const FountainSourceRange _range = FountainSourceRange(
  startLine: 0,
  endLine: 0,
  startOffset: 0,
  endOffset: 0,
);

void main() {
  group('single-line elements', () {
    test('a scene heading points at its own text', () {
      final composed = _Composed('INT. KITCHEN - DAY\n');
      expect(composed.covered(composed.lines.single), 'INT. KITCHEN - DAY');
    });

    test('a scene number is left out of the heading line range', () {
      // The number is printed in the margins, not in the line's text, so it
      // must not be part of what the line claims to cover either.
      final composed = _Composed('INT. KITCHEN - DAY #4A#\n');
      expect(composed.covered(composed.lines.single), 'INT. KITCHEN - DAY');
    });

    test("a forced heading's leading dot is left out of the range", () {
      final composed = _Composed('.BLACK SCREEN\n');
      expect(composed.covered(composed.lines.single), 'BLACK SCREEN');
    });

    test('a transition already printed in upper case is exact', () {
      final composed = _Composed('INT. KITCHEN - DAY\n\nCUT TO:\n');
      expect(composed.coveredTexts, [
        'INT. KITCHEN - DAY',
        null, // the blank spacer between the two blocks
        'CUT TO:',
      ]);
    });

    test('a centered line points past its own markers', () {
      final composed = _Composed('> THE END <\n');
      expect(composed.covered(composed.lines.single), 'THE END');
    });

    test('a character cue and its dialogue each point at their own line', () {
      final composed = _Composed('SARAH\nI am right here.\n');
      expect(composed.coveredTexts, ['SARAH', 'I am right here.']);
    });

    test('a parenthetical points past the whitespace around it', () {
      final composed = _Composed('SARAH\n  (beat)  \nStill here.\n');
      expect(composed.coveredTexts, ['SARAH', '(beat)', 'Still here.']);
    });

    test('an element the parser upper-cased falls back to its own line, never '
        'to a wrong one', () {
      // "> fade out:" prints as "FADE OUT:", which appears nowhere in the
      // source: the anchor degrades to the block's own start offset, so
      // the range still names this line and no other.
      final composed = _Composed('INT. KITCHEN - DAY\n\n> fade out:\n');
      final transition = composed.lines.last;
      expect(transition.plainText, 'FADE OUT:');
      expect(transition.sourceRange!.startLine, 2);
      expect(
        transition.sourceRange!.startOffset,
        composed.source.indexOf('> fade out:'),
      );
    });

    test('a lower-case forced cue stays within its own source line', () {
      // Same fallback as the transition above: "@sarah" prints as "SARAH",
      // so the anchor lands on the `@` rather than on the name. The range is
      // off by the forcing marker's one character and no more — enough to
      // place the cue on the right printed row, which is all a margin
      // annotation needs.
      final composed = _Composed('@sarah\nHello.\n');
      final cue = composed.lines.first;
      expect(cue.plainText, 'SARAH');
      expect(cue.sourceRange!.startLine, 0);
      expect(cue.sourceRange!.startOffset, 0);
      expect(cue.sourceRange!.endOffset, lessThanOrEqualTo('@sarah'.length));
    });
  });

  group('multi-line elements', () {
    test('each action line points at its own source line', () {
      final composed = _Composed(
        'Sarah walks in.\nThe door slams.\nSilence.\n',
      );
      expect(composed.coveredTexts, [
        'Sarah walks in.',
        'The door slams.',
        'Silence.',
      ]);
    });

    test("a forced action block's leading bang is left out of the range", () {
      final composed = _Composed('!INT. NOT A HEADING\nSecond line.\n');
      expect(composed.coveredTexts, ['INT. NOT A HEADING', 'Second line.']);
    });

    test('a lyrics line points past its tilde', () {
      final composed = _Composed('~One more time\n~And again\n');
      expect(composed.coveredTexts, ['One more time', 'And again']);
    });

    test('two identical action lines each point at their own occurrence', () {
      // The scan for one line's text is confined to the source line it
      // belongs to, so the second occurrence can never be anchored onto the
      // first.
      final composed = _Composed('Silence.\nSilence.\n');
      final offsets = composed.lines
          .map((line) => line.sourceRange!.startOffset)
          .toList();
      expect(offsets, [0, 'Silence.\n'.length]);
      expect(composed.lines.map((line) => line.sourceRange!.startLine), [0, 1]);
    });
  });

  group('wrapped lines', () {
    test('each printed row points at the words it alone prints', () {
      final composed = _Composed(
        'Sarah walks in slowly and looks around the empty room.\n',
        metrics: _metrics(actionCols: 20),
      );
      expect(composed.coveredTexts, [
        'Sarah walks in',
        'slowly and looks',
        'around the empty',
        'room.',
      ]);
    });

    test('consecutive rows never overlap, and skip the break space', () {
      final composed = _Composed(
        'Sarah walks in slowly and looks around the empty room.\n',
        metrics: _metrics(actionCols: 20),
      );
      final ranges = composed.lines
          .map((line) => line.sourceRange!)
          .toList(growable: false);
      for (var index = 1; index < ranges.length; index++) {
        // One space between the two rows: the one the wrap broke at, which
        // belongs to neither of them.
        expect(
          ranges[index].startOffset,
          ranges[index - 1].endOffset + 1,
          reason: 'row $index should start just past row ${index - 1}',
        );
      }
    });

    test('a wrapped dialogue line stays anchored on its own source line', () {
      final composed = _Composed(
        'SARAH\nI am telling you.\nThey are already here.\n',
        metrics: _metrics(dialogueCols: 10),
      );
      expect(composed.coveredTexts, [
        'SARAH',
        'I am',
        'telling',
        'you.',
        'They are',
        'already',
        'here.',
      ]);
      expect(composed.lines.map((line) => line.sourceRange!.startLine), [
        0,
        1,
        1,
        1,
        2,
        2,
        2,
      ]);
    });
  });

  group('inline styling', () {
    test('a line covers its emphasis markers as well as its text', () {
      const source = 'He said **hello** loudly.\n';
      final composed = _Composed(source);
      final line = composed.lines.single;
      expect(line.plainText, 'He said hello loudly.');
      expect(composed.covered(line), 'He said **hello** loudly.');
    });

    test('the emphasised run itself covers only what it renders', () {
      const source = 'He said **hello** loudly.\n';
      final composed = _Composed(source);
      final bold = composed.lines.single.runs.firstWhere((run) => run.isBold);
      expect(
        source.substring(
          bold.sourceRange!.startOffset,
          bold.sourceRange!.endOffset,
        ),
        'hello',
      );
    });

    test('an emphasis marker never counts towards the wrap width', () {
      // "**one**" prints as three columns, so the marked-up line wraps
      // exactly where the plain one does.
      final composed = _Composed(
        '**one** two three four five\n',
        metrics: _metrics(actionCols: 11),
      );
      expect(composed.lines.map((line) => line.plainText), [
        'one two',
        'three four',
        'five',
      ]);
      // A line's range is the union of its runs' own ranges, and a run's
      // range never includes its own markers: the `**` between "one" and
      // " two" is covered because it sits between two runs, the opening one
      // is not because nothing on this line renders it.
      expect(composed.coveredTexts, ['one** two', 'three four', 'five']);
    });

    test('an escaped character leaves the range longer than the text', () {
      const source =
          r'A \*star\* here.'
          '\n';
      final composed = _Composed(source);
      final line = composed.lines.single;
      expect(line.plainText, 'A *star* here.');
      expect(composed.covered(line), r'A \*star\* here.');
    });
  });

  group('lines with no source of their own', () {
    test('a blank spacer line has no range and is not synthetic', () {
      final composed = _Composed('First block.\n\nSecond block.\n');
      final spacer = composed.lines[1];
      expect(spacer.lineType, FountainLineType.blank);
      expect(spacer.sourceRange, isNull);
      expect(spacer.isSynthetic, isFalse);
    });

    test('a preserved blank dialogue line has no range either', () {
      // A dialogue line kept blank by trailing whitespace prints as a real
      // row with nothing in it, so there is nothing for it to point at.
      final composed = _Composed('SARAH\nFirst.\n   \nSecond.\n');
      expect(composed.coveredTexts, ['SARAH', 'First.', null, 'Second.']);
      expect(composed.lines[2].isSynthetic, isFalse);
    });

    test('every line of a document with no source text goes unanchored', () {
      // A document assembled by hand (as much of this package's own test
      // material is) has no source for a range to address: the composer
      // must leave every line unanchored rather than invent offsets.
      final layout = _composer.compose(
        document: const FountainDocument(
          titlePage: null,
          blocks: [
            FountainSceneHeading(
              sourceRange: _range,
              rawText: 'INT. KITCHEN - DAY',
              headingText: 'INT. KITCHEN - DAY',
              forcedMarker: false,
            ),
            FountainActionBlock(
              sourceRange: _range,
              lines: ['Sarah walks in.'],
              forced: false,
            ),
          ],
          sourceText: '',
        ),
        metrics: _metrics(),
      );
      expect(
        [
          for (final page in layout.pages) ...page.lines,
        ].map((line) => line.sourceRange),
        everyElement(isNull),
      );
    });
  });

  group('page-split dialogue', () {
    /// A three-line dialogue group that only fits two lines on a page,
    /// forcing the composer to split it with a `(MORE)` token.
    _Composed splitGroup() => _Composed(
      'SARAH\nFirst line.\nSecond line.\nThird line.\n',
      metrics: _metrics(linesPerPage: 3),
    );

    test('the (MORE) token is synthetic and points at nothing', () {
      final composed = splitGroup();
      final more = composed.layout.pages.first.lines.last;
      expect(more.plainText, '(MORE)');
      expect(more.isSynthetic, isTrue);
      expect(more.sourceRange, isNull);
    });

    test("the repeated CONT'D cue is synthetic and points at nothing", () {
      final composed = splitGroup();
      final contd = composed.layout.pages[1].lines.first;
      expect(contd.plainText, "SARAH (CONT'D)");
      expect(contd.isSynthetic, isTrue);
      expect(contd.sourceRange, isNull);
    });

    test('the original cue is not synthetic', () {
      final composed = splitGroup();
      final cue = composed.layout.pages.first.lines.first;
      expect(cue.plainText, 'SARAH');
      expect(cue.isSynthetic, isFalse);
      expect(composed.covered(cue), 'SARAH');
    });

    test('the dialogue continuing on the next page stays anchored', () {
      final composed = splitGroup();
      expect(composed.layout.pages, hasLength(2));
      expect(composed.coveredTexts, [
        'SARAH',
        'First line.',
        null, // (MORE)
        null, // SARAH (CONT'D)
        'Second line.',
        'Third line.',
      ]);
    });

    test('a paragraph split by a page break keeps every row anchored', () {
      final composed = _Composed(
        'One.\nTwo.\nThree.\nFour.\n',
        metrics: _metrics(linesPerPage: 2),
      );
      expect(composed.layout.pages, hasLength(2));
      expect(composed.coveredTexts, ['One.', 'Two.', 'Three.', 'Four.']);
    });
  });

  group('a whole screenplay', () {
    test('every anchored line quotes source text it really came from', () {
      const source = '''
Title: Le cadeau
Author: Benoit

INT. KITCHEN - DAY

Sarah walks in and looks around the room, which is *completely* empty.

SARAH
(beat)
Is anybody there at all?

CUT TO:

EXT. GARDEN - NIGHT

Nothing moves.
''';
      final composed = _Composed(source, metrics: _metrics(actionCols: 30));
      for (final line in composed.lines) {
        final range = line.sourceRange;
        if (range == null) {
          continue;
        }
        expect(
          range.endOffset,
          lessThanOrEqualTo(source.length),
          reason: 'a range must stay inside the source it points into',
        );
        expect(
          source.substring(range.startOffset, range.endOffset),
          contains(line.runs.first.text),
          reason: 'line "${line.plainText}" should quote its own source',
        );
      }
    });

    test('the title page is never mistaken for body text', () {
      const source = 'Title: Le cadeau\n\nINT. KITCHEN - DAY\n';
      final composed = _Composed(source);
      // The composer lays out the body only; the one line it emits is the
      // heading, and it points past the title page's own lines.
      final heading = composed.lines.single;
      expect(composed.covered(heading), 'INT. KITCHEN - DAY');
      expect(heading.sourceRange!.startLine, 2);
    });
  });
}
