// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_minimum_rest.dart';

void main() {
  group("ocptMinimumRestMinutesOf", () {
    test("reads a whole number of hours as minutes", () {
      expect(ocptMinimumRestMinutesOf("11"), 660);
      expect(ocptMinimumRestMinutesOf("1"), 60);
    });

    test("reads both decimal separators", () {
      expect(ocptMinimumRestMinutesOf("11.5"), 690);
      expect(ocptMinimumRestMinutesOf("11,5"), 690);
      expect(ocptMinimumRestMinutesOf("11,25"), 675);
    });

    test("drops the spaces a typed or pasted figure may carry", () {
      expect(ocptMinimumRestMinutesOf("  11,5  "), 690);
      expect(ocptMinimumRestMinutesOf("11 , 5"), 690);
    });

    test("rounds to the nearest minute", () {
      expect(ocptMinimumRestMinutesOf("11.01"), 661);
      expect(ocptMinimumRestMinutesOf("11.004"), 660);
    });

    test("reads nothing at all as no figure", () {
      expect(ocptMinimumRestMinutesOf(""), isNull);
      expect(ocptMinimumRestMinutesOf("   "), isNull);
    });

    test("reads what is not a number as no figure", () {
      expect(ocptMinimumRestMinutesOf("onze heures"), isNull);
      expect(ocptMinimumRestMinutesOf("11 h"), isNull);
    });

    test("refuses a figure that is not a positive length of time", () {
      expect(ocptMinimumRestMinutesOf("0"), isNull);
      expect(ocptMinimumRestMinutesOf("-11"), isNull);
      expect(ocptMinimumRestMinutesOf("0.001"), isNull);
    });
  });

  group("ocptMinimumRestHoursTextOf", () {
    test("writes a whole number of hours bare", () {
      expect(ocptMinimumRestHoursTextOf(660), "11");
      expect(ocptMinimumRestHoursTextOf(60), "1");
    });

    test("writes a fraction of an hour with no trailing zero", () {
      expect(ocptMinimumRestHoursTextOf(690), "11.5");
      expect(ocptMinimumRestHoursTextOf(675), "11.25");
      expect(ocptMinimumRestHoursTextOf(90), "1.5");
    });

    test("writes what the parser reads back unchanged", () {
      for (final minutes in [60, 90, 660, 675, 690]) {
        expect(ocptMinimumRestMinutesOf(ocptMinimumRestHoursTextOf(minutes)), minutes);
      }
    });

    test("writes no figure as an empty field", () {
      expect(ocptMinimumRestHoursTextOf(null), "");
    });
  });
}
