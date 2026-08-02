// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';

/// The relative luminance of the ARGB [color], on the WCAG scale (0 is black, 1 is white), used
/// to check every palette entry is dark enough to read on white paper.
double _relativeLuminance(int color) {
  double channel(int shift) {
    final value = ((color >> shift) & 0xFF) / 255;
    return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

void main() {
  group("ocptCoveragePalette", () {
    test("holds 16 distinct, fully opaque colours", () {
      expect(ocptCoveragePalette, hasLength(16));
      expect(ocptCoveragePalette.toSet(), hasLength(ocptCoveragePalette.length));
      expect(ocptCoveragePalette.map((color) => (color >> 24) & 0xFF), everyElement(0xFF));
    });

    test("keeps every entry dark enough to read on white paper", () {
      for (final color in ocptCoveragePalette) {
        expect(
          _relativeLuminance(color),
          lessThan(0.5),
          reason: "0x${color.toRadixString(16)} is too light for white paper",
        );
      }
    });
  });

  group("ocptCoverageColorAt", () {
    test("hands the palette out in order for the first shots of a sequence", () {
      for (var rank = 0; rank < ocptCoveragePalette.length; rank++) {
        expect(ocptCoverageColorAt(rank), ocptCoveragePalette[rank]);
      }
    });

    test("rotates the palette rather than repeating it once a sequence exhausts it", () {
      final first = ocptCoverageColorAt(0);
      final second = ocptCoverageColorAt(ocptCoveragePalette.length);
      final third = ocptCoverageColorAt(2 * ocptCoveragePalette.length);

      expect(second, isNot(first));
      expect(third, isNot(first));
      expect(third, isNot(second));
      expect((second >> 24) & 0xFF, 0xFF);
    });

    test("is deterministic, so the same project always exports the same document", () {
      expect(ocptCoverageColorAt(21), ocptCoverageColorAt(21));
    });
  });
}
