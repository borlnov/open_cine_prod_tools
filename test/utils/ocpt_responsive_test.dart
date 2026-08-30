// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

void main() {
  group("ocptIsCompactWidth", () {
    test("classifies a width just below the breakpoint as compact", () {
      expect(ocptIsCompactWidth(815.9), isTrue);
    });

    test("classifies the breakpoint itself as not compact", () {
      expect(ocptIsCompactWidth(ocptCompactWidthBreakpoint), isFalse);
    });

    test("classifies zero as compact", () {
      expect(ocptIsCompactWidth(0), isTrue);
    });

    test("classifies a wide desktop width as not compact", () {
      expect(ocptIsCompactWidth(2000), isFalse);
    });
  });

  group("ocptCompactDrawerWidthFor", () {
    test("fills the whole row at or below the phone breakpoint", () {
      expect(ocptCompactDrawerWidthFor(390), 390);
      expect(ocptCompactDrawerWidthFor(ocptPhoneWidthBreakpoint), ocptPhoneWidthBreakpoint);
    });

    test("is a fixed edge drawer above the phone breakpoint", () {
      expect(ocptCompactDrawerWidthFor(700), ocptCompactDrawerWidth);
      expect(ocptCompactDrawerWidthFor(815), ocptCompactDrawerWidth);
    });

    test("never exceeds the row width across the compact range", () {
      for (final rowWidth in <double>[320, ocptPhoneWidthBreakpoint, 601, 700, 815]) {
        expect(ocptCompactDrawerWidthFor(rowWidth), lessThanOrEqualTo(rowWidth));
      }
    });
  });
}
