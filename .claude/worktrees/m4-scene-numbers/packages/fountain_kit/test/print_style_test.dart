// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/layout/fountain_print_style.dart';
import 'package:fountain_kit/src/parser/fountain_line_classifier.dart';
import 'package:test/test.dart';

void main() {
  group('FountainPrintStyle.of', () {
    test('scene heading prints bold and upper-cased', () {
      final style = FountainPrintStyle.of(FountainLineType.sceneHeading);
      expect(style.isBold, isTrue);
      expect(style.isItalic, isFalse);
      expect(style.isUppercase, isTrue);
    });

    test('character cue prints upper-cased only', () {
      final style = FountainPrintStyle.of(FountainLineType.character);
      expect(style.isBold, isFalse);
      expect(style.isItalic, isFalse);
      expect(style.isUppercase, isTrue);
    });

    test('transition prints upper-cased only', () {
      final style = FountainPrintStyle.of(FountainLineType.transition);
      expect(style.isBold, isFalse);
      expect(style.isItalic, isFalse);
      expect(style.isUppercase, isTrue);
    });

    test('lyrics print italic only', () {
      final style = FountainPrintStyle.of(FountainLineType.lyrics);
      expect(style.isBold, isFalse);
      expect(style.isItalic, isTrue);
      expect(style.isUppercase, isFalse);
    });

    test('every other line type prints plain (no bold, no italic, no '
        'uppercase)', () {
      const plainTypes = [
        FountainLineType.blank,
        FountainLineType.pageBreak,
        FountainLineType.section,
        FountainLineType.synopsis,
        FountainLineType.centeredText,
        FountainLineType.parenthetical,
        FountainLineType.dialogue,
        FountainLineType.action,
      ];

      for (final type in plainTypes) {
        expect(
          FountainPrintStyle.of(type),
          FountainPrintStyle.plain,
          reason: '$type should print plain',
        );
      }
    });

    test('covers every FountainLineType value (exhaustiveness guard)', () {
      // If a new FountainLineType value is ever added without updating
      // FountainPrintStyle.of's switch, this call fails to compile (the
      // switch has no default/catch-all), which is the whole point: a new
      // line type forces a deliberate print-style decision.
      for (final type in FountainLineType.values) {
        expect(() => FountainPrintStyle.of(type), returnsNormally);
      }
    });
  });

  group('FountainPrintStyle equality', () {
    test('two instances with the same flags are equal', () {
      expect(
        const FountainPrintStyle(isBold: true, isUppercase: true),
        const FountainPrintStyle(isBold: true, isUppercase: true),
      );
    });

    test('instances with different flags are not equal', () {
      expect(
        const FountainPrintStyle(isBold: true),
        isNot(const FountainPrintStyle(isItalic: true)),
      );
    });
  });
}
