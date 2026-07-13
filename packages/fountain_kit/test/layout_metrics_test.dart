// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_layout_metrics.dart';
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
}
