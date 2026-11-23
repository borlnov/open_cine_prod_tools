// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:fountain_kit/src/layout/fountain_dual_dialogue_layout.dart';
import 'package:fountain_kit/src/layout/fountain_element_layout.dart';
import 'package:fountain_kit/src/layout/fountain_layout_alignment.dart';
import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_scene_statistics.dart';
import 'package:fountain_kit/src/layout/fountain_script_composer.dart';
import 'package:fountain_kit/src/layout/fountain_script_layout.dart';
import 'package:fountain_kit/src/layout/fountain_script_line.dart';
import 'package:fountain_kit/src/layout/fountain_script_statistics.dart';
import 'package:fountain_kit/src/parser/fountain_line_type.dart';
import 'package:fountain_kit/src/parser/fountain_parser.dart';
import 'package:test/test.dart';

/// The parser turning the test sources into documents.
const FountainParser _parser = FountainParser();

/// Build a [FountainElementLayout] [maxWidthColumns] columns wide, starting [leftIndentInches] in.
FountainElementLayout _box(int maxWidthColumns, double leftIndentInches) => FountainElementLayout(
  leftIndentInches: leftIndentInches,
  leftIndentColumns: (leftIndentInches * 10).round(),
  maxWidthInches: maxWidthColumns / 10,
  maxWidthColumns: maxWidthColumns,
  alignment: FountainLayoutAlignment.left,
);

/// Build metrics of [linesPerPage] lines whose dual-dialogue columns are 10 columns wide, the left
/// one starting at 1 inch and the right one at 4 inches, or without columns when [hasColumns] is
/// `false`. Ordinary dialogue is 30 columns wide starting at 2.5 inches.
FountainLayoutMetrics _metrics({required int linesPerPage, bool hasColumns = true}) =>
    FountainLayoutMetrics(
      pageWidthInches: 8.5,
      pageHeightInches: 11,
      marginLeftInches: 1.5,
      marginRightInches: 1,
      marginTopInches: 1,
      marginBottomInches: 1,
      charsPerInch: 10,
      linesPerInch: 6,
      linesPerPage: linesPerPage,
      sceneHeading: _box(60, 1.5),
      action: _box(60, 1.5),
      character: _box(30, 3.7),
      parenthetical: _box(30, 3.1),
      dialogue: _box(30, 2.5),
      transition: _box(60, 1.5),
      centeredText: _box(60, 1.5),
      lyrics: _box(30, 2.5),
      dualDialogue: hasColumns
          ? FountainDualDialogueLayout(
              leftCharacter: _box(10, 1.2),
              leftParenthetical: _box(10, 1.1),
              leftDialogue: _box(10, 1),
              rightCharacter: _box(10, 4.2),
              rightParenthetical: _box(10, 4.1),
              rightDialogue: _box(10, 4),
            )
          : null,
    );

/// A source and its composed pages, to quote what a cell's range points at.
class _Composed {
  /// The screenplay source, exactly as parsed.
  final String source;

  /// The composed pages.
  final FountainScriptLayout layout;

  /// Every row of every page, in reading order.
  List<FountainScriptLine> get rows => [for (final page in layout.pages) ...page.lines];

  /// Parse and compose [source].
  _Composed(this.source, FountainLayoutMetrics metrics)
    : layout = const FountainScriptComposer().compose(
        document: _parser.parse(source),
        metrics: metrics,
      );

  /// Get the source text [line]'s range points at, or null when it has none.
  String? covered(FountainScriptLine line) {
    final range = line.sourceRange;
    return range == null ? null : source.substring(range.startOffset, range.endOffset);
  }
}

/// Get the printed text of each row's [side] cell, with an empty string where the row has none.
List<String> _column(_Composed composed, FountainDualDialogueSide side) => [
  for (final row in composed.rows) row.cellOf(side)?.plainText ?? '',
];

/// Run the tests of the dual dialogue composition.
void main() {
  group('shared rows', () {
    test('a pair prints one row per line of its taller column, a cell of each in a row', () {
      final composed = _Composed('ROSS\nOne.\n\nKIM^\nTwo.\n', _metrics(linesPerPage: 20));

      expect(composed.layout.pages, hasLength(1));
      expect(composed.rows, hasLength(2));
      expect(_column(composed, FountainDualDialogueSide.left), ['ROSS', 'One.']);
      expect(_column(composed, FountainDualDialogueSide.right), ['KIM', 'Two.']);
      final cue = composed.rows.first;
      expect(cue.dualSide, FountainDualDialogueSide.left);
      expect(cue.lineType, FountainLineType.character);
      expect(cue.leftIndentInches, 1.2);
      expect(cue.cells, hasLength(2));
      expect(cue.dualCompanion!.dualSide, FountainDualDialogueSide.right);
      expect(cue.dualCompanion!.dualCompanion, isNull);
      expect(cue.dualCompanion!.leftIndentInches, 4.2);
      expect(composed.rows.last.leftIndentInches, 1);
      expect(composed.rows.last.dualCompanion!.leftIndentInches, 4);
    });

    test('a line that is no part of a pair has no side and only itself as a cell', () {
      final composed = _Composed('ROSS\nOne.\n', _metrics(linesPerPage: 20));

      final line = composed.rows.first;
      expect(line.dualSide, isNull);
      expect(line.cells, [line]);
      expect(line.cellOf(FountainDualDialogueSide.left), isNull);
    });

    test('the spacer before a pair is an ordinary blank line', () {
      final composed = _Composed(
        'Action.\n\nROSS\nOne.\n\nKIM^\nTwo.\n',
        _metrics(linesPerPage: 20),
      );

      expect(composed.rows, hasLength(4));
      expect(composed.rows[1].lineType, FountainLineType.blank);
      expect(composed.rows[1].dualSide, isNull);
      expect(composed.rows[2].dualSide, FountainDualDialogueSide.left);
    });
  });

  group('unequal columns', () {
    test('a taller left column leaves the right cells out of the last rows', () {
      final composed = _Composed(
        'ROSS\nalpha beta gamma delta\n\nKIM^\nShort.\n',
        _metrics(linesPerPage: 20),
      );

      expect(composed.rows, hasLength(4));
      expect(_column(composed, FountainDualDialogueSide.left), [
        'ROSS',
        'alpha beta',
        'gamma',
        'delta',
      ]);
      expect(_column(composed, FountainDualDialogueSide.right), ['KIM', 'Short.', '', '']);
      expect(composed.rows[2].dualCompanion, isNull);
      expect(composed.rows[3].dualCompanion, isNull);
      expect(composed.rows[3].dualSide, FountainDualDialogueSide.left);
    });

    test('a taller right column gives blank left cells that still carry the right ones', () {
      final composed = _Composed(
        'ROSS\nShort.\n\nKIM^\nalpha beta gamma delta\n',
        _metrics(linesPerPage: 20),
      );

      expect(composed.rows, hasLength(4));
      final blank = composed.rows[3];
      expect(blank.lineType, FountainLineType.blank);
      expect(blank.runs, isEmpty);
      expect(blank.dualSide, FountainDualDialogueSide.left);
      expect(blank.sourceRange, isNull);
      expect(blank.dualCompanion!.plainText, 'delta');
      expect(composed.rows[2].dualCompanion!.plainText, 'gamma');
    });
  });

  group('page breaks', () {
    test('a pair that does not fit at the bottom of a page moves whole to the next one', () {
      final composed = _Composed(
        'One.\nTwo.\nThree.\n\nROSS\nOne.\n\nKIM^\nTwo.\n',
        _metrics(linesPerPage: 5),
      );

      expect(composed.layout.pages, hasLength(2));
      expect(composed.layout.pages[0].lines, hasLength(3));
      final second = composed.layout.pages[1].lines;
      expect(second, hasLength(2));
      expect(second.first.dualSide, FountainDualDialogueSide.left);
      expect(second.first.plainText, 'ROSS');
    });

    test('a pair that fits with its spacer stays on the page', () {
      final composed = _Composed(
        'One.\nTwo.\nThree.\n\nROSS\nOne.\n\nKIM^\nTwo.\n',
        _metrics(linesPerPage: 6),
      );

      expect(composed.layout.pages, hasLength(1));
      expect(composed.rows, hasLength(6));
    });

    test('a pair taller than a page is set stacked and split with (MORE)', () {
      final composed = _Composed(
        'ROSS\nalpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron\n\n'
        'KIM^\nShort.\n',
        _metrics(linesPerPage: 3),
      );

      expect(composed.layout.pages.length, greaterThan(1));
      expect(composed.rows.every((row) => row.dualSide == null), isTrue);
      expect(composed.rows.every((row) => row.dualCompanion == null), isTrue);
      expect(composed.rows.map((row) => row.plainText), contains('(MORE)'));
      final cues = composed.rows.where((row) => row.lineType == FountainLineType.character);
      expect(cues.map((row) => row.plainText), contains("ROSS (CONT'D)"));
      expect(cues.every((row) => row.leftIndentInches == 3.7), isTrue);
    });

    test('a pair of exactly a page opens a page of its own', () {
      final composed = _Composed(
        'Action.\n\nROSS\nOne.\n\nKIM^\nTwo.\n',
        _metrics(linesPerPage: 2),
      );

      expect(composed.layout.pages, hasLength(2));
      expect(composed.layout.pages[1].lines, hasLength(2));
      expect(composed.layout.pages[1].lines.first.dualSide, FountainDualDialogueSide.left);
    });
  });

  group('orphans and fallback', () {
    test('a ^ group with no group before it prints as an ordinary dialogue', () {
      final composed = _Composed('Action.\n\nKIM^\nTwo.\n', _metrics(linesPerPage: 20));

      expect(composed.rows.every((row) => row.dualSide == null), isTrue);
      final cue = composed.rows.firstWhere((row) => row.lineType == FountainLineType.character);
      expect(cue.leftIndentInches, 3.7);
    });

    test('a third group of a chain prints as an ordinary dialogue', () {
      final composed = _Composed('ROSS\nA.\n\nKIM^\nB.\n\nROSS^\nC.\n', _metrics(linesPerPage: 20));

      expect(composed.rows, hasLength(5));
      expect(composed.rows.take(2).every((row) => row.dualSide != null), isTrue);
      expect(composed.rows[2].lineType, FountainLineType.blank);
      expect(composed.rows[3].dualSide, isNull);
      expect(composed.rows[3].plainText, 'ROSS');
      expect(composed.rows[3].leftIndentInches, 3.7);
    });

    test('without dual-dialogue metrics a pair prints stacked', () {
      final composed = _Composed(
        'ROSS\nOne.\n\nKIM^\nTwo.\n',
        _metrics(linesPerPage: 20, hasColumns: false),
      );

      expect(composed.rows.map((row) => row.plainText), ['ROSS', 'One.', '', 'KIM', 'Two.']);
      expect(composed.rows.every((row) => row.dualSide == null), isTrue);
      expect(composed.rows.every((row) => row.dualCompanion == null), isTrue);
    });
  });

  group('source ranges', () {
    test('each cell points at its own source, never at the union of both', () {
      final composed = _Composed('ROSS\nOne.\n\nKIM^\nTwo.\n', _metrics(linesPerPage: 20));

      final cue = composed.rows.first;
      expect(composed.covered(cue), 'ROSS');
      expect(composed.covered(cue.dualCompanion!), 'KIM');
      final dialogue = composed.rows.last;
      expect(composed.covered(dialogue), 'One.');
      expect(composed.covered(dialogue.dualCompanion!), 'Two.');
    });

    test('a wrapped column keeps adjacent ranges per cell', () {
      final composed = _Composed(
        'ROSS\nalpha beta gamma\n\nKIM^\none two three\n',
        _metrics(linesPerPage: 20),
      );

      expect(composed.rows.map(composed.covered), ['ROSS', 'alpha beta', 'gamma']);
      expect(composed.rows.map((row) => composed.covered(row.dualCompanion!)), [
        'KIM',
        'one two',
        'three',
      ]);
    });
  });

  group('statistics', () {
    const source = 'INT. ROOM - DAY\n\nROSS\nOne.\n\nKIM^\nTwo.\n';

    test('a pair counts its rows, not its lines, in a page count', () {
      final document = _parser.parse(source);

      // Heading, spacer and two shared rows make 4 rows, so two pages of 3 rows.
      expect(FountainScriptStatistics.of(document, _metrics(linesPerPage: 3)).pageCount, 2);
      expect(FountainScriptStatistics.of(document, _metrics(linesPerPage: 4)).pageCount, 1);
      // Stacked, the same screenplay takes 7 rows.
      final stacked = _metrics(linesPerPage: 4, hasColumns: false);
      expect(FountainScriptStatistics.of(document, stacked).pageCount, 2);
    });

    test('a pair counts its rows in the eighths of its scene', () {
      final document = _parser.parse(source);

      expect(FountainSceneStatistics.of(document, _metrics(linesPerPage: 16), 0).pageEighths, 2);
      final stacked = _metrics(linesPerPage: 16, hasColumns: false);
      expect(FountainSceneStatistics.of(document, stacked, 0).pageEighths, 4);
    });
  });

  group('corpus', () {
    test('dual_dialogue.fountain composes with its pairs on shared rows', () {
      final source = File('test/corpus/dual_dialogue.fountain').readAsStringSync();
      final composed = _Composed(source, FountainLayoutMetrics.usLetter());

      final paired = composed.rows.where((row) => row.dualSide != null).toList();
      expect(paired, isNotEmpty);
      final rights = paired
          .expand((row) => row.cells)
          .where((cell) => cell.dualSide == FountainDualDialogueSide.right);
      expect(rights.map((cell) => cell.plainText), contains('KIM'));
      expect(rights.map((cell) => cell.plainText), contains('ASSISTANT'));
      // The third ROSS of the first chain is an orphan, set as an ordinary dialogue.
      final orphans = composed.rows.where((row) => row.dualSide == null && row.plainText == 'ROSS');
      expect(orphans, isNotEmpty);
    });
  });
}
