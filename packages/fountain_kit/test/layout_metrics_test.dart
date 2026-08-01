// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
import 'package:fountain_kit/src/layout/fountain_page_margins.dart';
import 'package:test/test.dart';

/// Asserts that [value] is within a very small tolerance of [expected],
/// which absorbs floating point rounding without hiding a real mistake.
void _expectClose(double value, double expected) {
  expect(value, closeTo(expected, 0.0001));
}

void main() {
  group('US Letter preset', () {
    final metrics = FountainLayoutMetrics.usLetter();

    test('page size and margins are the standard US screenplay values', () {
      _expectClose(metrics.pageWidthInches, 8.5);
      _expectClose(metrics.pageHeightInches, 11);
      _expectClose(metrics.marginLeftInches, 1.5);
      _expectClose(metrics.marginRightInches, 1);
      _expectClose(metrics.marginTopInches, 1);
      _expectClose(metrics.marginBottomInches, 1);
    });

    test('font pitch is 12-point Courier: 10 chars/inch, 6 lines/inch', () {
      _expectClose(metrics.charsPerInch, 10);
      _expectClose(metrics.linesPerInch, 6);
    });

    test('printable area is 6 by 9 inches', () {
      _expectClose(metrics.printableWidthInches, 6);
      _expectClose(metrics.printableHeightInches, 9);
    });

    test('54 lines fit on one page (9in * 6 lines/in)', () {
      expect(metrics.linesPerPage, 54);
    });

    test(
      'scene heading and action start at the 1.5in left margin, full width',
      () {
        _expectClose(metrics.sceneHeading.leftIndentInches, 1.5);
        _expectClose(metrics.action.leftIndentInches, 1.5);
        _expectClose(metrics.sceneHeading.maxWidthInches, 6);
        _expectClose(metrics.action.maxWidthInches, 6);
        expect(metrics.sceneHeading.alignment, FountainLayoutAlignment.left);
      },
    );

    test('character cues start 3.7in from the page edge', () {
      _expectClose(metrics.character.leftIndentInches, 3.7);
      expect(metrics.character.leftIndentColumns, 37);
    });

    test('parentheticals start 3.1in from the page edge', () {
      _expectClose(metrics.parenthetical.leftIndentInches, 3.1);
      expect(metrics.parenthetical.leftIndentColumns, 31);
    });

    test('dialogue starts 2.5in from the page edge and is 3.5in wide', () {
      _expectClose(metrics.dialogue.leftIndentInches, 2.5);
      _expectClose(metrics.dialogue.maxWidthInches, 3.5);
      expect(metrics.dialogue.leftIndentColumns, 25);
      expect(metrics.dialogue.maxWidthColumns, 35);
    });

    test('lyrics share the dialogue column', () {
      expect(metrics.lyrics, metrics.dialogue);
    });

    test('transitions are right-aligned', () {
      expect(metrics.transition.alignment, FountainLayoutAlignment.right);
    });

    test('centered text is center-aligned across the full printable width', () {
      expect(metrics.centeredText.alignment, FountainLayoutAlignment.center);
      _expectClose(metrics.centeredText.maxWidthInches, 6);
    });
  });

  group('A4 preset', () {
    final metrics = FountainLayoutMetrics.a4();

    test('page size is 210mm by 297mm, in inches', () {
      _expectClose(metrics.pageWidthInches, 210 / 25.4);
      _expectClose(metrics.pageHeightInches, 297 / 25.4);
    });

    test('margins and font pitch match the US Letter preset', () {
      final usLetter = FountainLayoutMetrics.usLetter();
      _expectClose(metrics.marginLeftInches, usLetter.marginLeftInches);
      _expectClose(metrics.marginRightInches, usLetter.marginRightInches);
      _expectClose(metrics.marginTopInches, usLetter.marginTopInches);
      _expectClose(metrics.marginBottomInches, usLetter.marginBottomInches);
      _expectClose(metrics.charsPerInch, usLetter.charsPerInch);
      _expectClose(metrics.linesPerInch, usLetter.linesPerInch);
    });

    test('a taller page fits more lines than US Letter', () {
      expect(
        metrics.linesPerPage,
        greaterThan(FountainLayoutMetrics.usLetter().linesPerPage),
      );
      expect(metrics.linesPerPage, 58);
    });

    test('a narrower page narrows the full-width elements', () {
      final usLetter = FountainLayoutMetrics.usLetter();
      expect(
        metrics.action.maxWidthInches,
        lessThan(usLetter.action.maxWidthInches),
      );
    });

    test('dialogue keeps its fixed 3.5in width regardless of page size', () {
      _expectClose(metrics.dialogue.maxWidthInches, 3.5);
      _expectClose(metrics.dialogue.leftIndentInches, 2.5);
    });

    test('character cues still start 3.7in from the page edge', () {
      _expectClose(metrics.character.leftIndentInches, 3.7);
    });

    test('a width that is not a whole number of columns truncates', () {
      // 8.2677in wide, minus a 1.5in left and a 1in right margin, leaves
      // 5.7677in: 57 whole columns, plus 0.68 of a 58th that must not be
      // handed out.
      expect(metrics.action.maxWidthColumns, 57);
      expect(metrics.sceneHeading.maxWidthColumns, 57);
      expect(metrics.parenthetical.maxWidthColumns, 41);
      expect(metrics.character.maxWidthColumns, 35);
    });
  });

  group('column widths never exceed their inch widths', () {
    // The invariant behind the truncation: a line wrapped at
    // maxWidthColumns must physically fit in maxWidthInches, or a renderer
    // sizing the line's box from the inches will re-wrap it and, since every
    // line is positioned at its own row, draw the overflow on top of the
    // next line.
    for (final entry in {
      'US Letter': FountainLayoutMetrics.usLetter(),
      'A4': FountainLayoutMetrics.a4(),
      'A4 with wide margins': FountainLayoutMetrics.a4(
        margins: const FountainPageMargins.standard().copyWith(
          rightInches: 1.35,
        ),
      ),
    }.entries) {
      test('${entry.key} keeps every element within its own width', () {
        final metrics = entry.value;
        for (final element in [
          metrics.sceneHeading,
          metrics.action,
          metrics.character,
          metrics.parenthetical,
          metrics.dialogue,
          metrics.transition,
          metrics.centeredText,
          metrics.lyrics,
        ]) {
          final columnsWidthInches =
              element.maxWidthColumns / metrics.charsPerInch;
          expect(
            columnsWidthInches,
            lessThanOrEqualTo(element.maxWidthInches),
            reason: '$element overflows its own box',
          );
          // And no more than a single column is given up, so truncating
          // never quietly narrows a page beyond what it must.
          expect(
            columnsWidthInches,
            greaterThan(element.maxWidthInches - 1 / metrics.charsPerInch),
            reason: '$element gives up more than one column',
          );
        }
      });
    }
  });

  group('equality', () {
    test('two US Letter presets are equal', () {
      expect(
        FountainLayoutMetrics.usLetter(),
        FountainLayoutMetrics.usLetter(),
      );
    });

    test('US Letter and A4 are not equal', () {
      expect(
        FountainLayoutMetrics.usLetter(),
        isNot(equals(FountainLayoutMetrics.a4())),
      );
    });
  });

  group('FountainPageMargins', () {
    test('standard() carries the documented values', () {
      const margins = FountainPageMargins.standard();
      _expectClose(margins.leftInches, 1.5);
      _expectClose(margins.rightInches, 1);
      _expectClose(margins.topInches, 1);
      _expectClose(margins.bottomInches, 1);
    });

    test('copyWith overrides only the given fields', () {
      const margins = FountainPageMargins.standard();
      final wider = margins.copyWith(leftInches: 2);
      _expectClose(wider.leftInches, 2);
      _expectClose(wider.rightInches, margins.rightInches);
      _expectClose(wider.topInches, margins.topInches);
      _expectClose(wider.bottomInches, margins.bottomInches);
    });

    test('equal margins compare equal', () {
      expect(
        const FountainPageMargins.standard(),
        const FountainPageMargins(
          leftInches: 1.5,
          rightInches: 1,
          topInches: 1,
          bottomInches: 1,
        ),
      );
    });

    test('different margins are not equal', () {
      const margins = FountainPageMargins.standard();
      expect(margins, isNot(equals(margins.copyWith(leftInches: 2))));
    });
  });

  group('non-standard margins', () {
    const margins = FountainPageMargins(
      leftInches: 2,
      rightInches: 0.5,
      topInches: 2,
      bottomInches: 0.5,
    );
    final metrics = FountainLayoutMetrics.usLetter(margins: margins);
    final standardMetrics = FountainLayoutMetrics.usLetter();

    test('printable width and height reflect the new margins', () {
      // 8.5 - 2 - 0.5 = 6, 11 - 2 - 0.5 = 8.5
      _expectClose(metrics.printableWidthInches, 6);
      _expectClose(metrics.printableHeightInches, 8.5);
    });

    test('linesPerPage shifts with the new printable height', () {
      expect(metrics.linesPerPage, 51);
      expect(metrics.linesPerPage, isNot(equals(standardMetrics.linesPerPage)));
    });

    test('scene heading, action and transition move with the left margin', () {
      _expectClose(metrics.sceneHeading.leftIndentInches, 2);
      _expectClose(metrics.action.leftIndentInches, 2);
      _expectClose(metrics.transition.leftIndentInches, 2);
      _expectClose(metrics.sceneHeading.maxWidthInches, 6);
      _expectClose(metrics.action.maxWidthInches, 6);
      _expectClose(metrics.transition.maxWidthInches, 6);
    });

    test('centered text keeps the new printable width', () {
      _expectClose(metrics.centeredText.maxWidthInches, 6);
    });

    test(
      'character, parenthetical and dialogue indents stay fixed from the '
      'page edge regardless of margins',
      () {
        _expectClose(metrics.character.leftIndentInches, 3.7);
        _expectClose(metrics.parenthetical.leftIndentInches, 3.1);
        _expectClose(metrics.dialogue.leftIndentInches, 2.5);
        _expectClose(metrics.dialogue.maxWidthInches, 3.5);

        _expectClose(
          metrics.character.leftIndentInches,
          standardMetrics.character.leftIndentInches,
        );
        _expectClose(
          metrics.parenthetical.leftIndentInches,
          standardMetrics.parenthetical.leftIndentInches,
        );
        _expectClose(
          metrics.dialogue.leftIndentInches,
          standardMetrics.dialogue.leftIndentInches,
        );
        _expectClose(
          metrics.dialogue.maxWidthInches,
          standardMetrics.dialogue.maxWidthInches,
        );
      },
    );

    test('a4() also accepts non-standard margins', () {
      final a4Metrics = FountainLayoutMetrics.a4(margins: margins);
      _expectClose(a4Metrics.marginLeftInches, 2);
      _expectClose(a4Metrics.marginRightInches, 0.5);
      _expectClose(a4Metrics.marginTopInches, 2);
      _expectClose(a4Metrics.marginBottomInches, 0.5);
      _expectClose(a4Metrics.character.leftIndentInches, 3.7);
    });
  });
}
