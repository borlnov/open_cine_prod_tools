// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_mileage_rate_amount.dart';

void main() {
  group("ocptMileageRateMilliCentsOf", () {
    test("reads a rate typed to three decimals", () {
      expect(ocptMileageRateMilliCentsOf("0.529"), 52900);
      expect(ocptMileageRateMilliCentsOf("0.601"), 60100);
      expect(ocptMileageRateMilliCentsOf("1"), 100000);
    });

    test("reads the comma a French keyboard produces", () {
      expect(ocptMileageRateMilliCentsOf("0,395"), 39500);
    });

    test("drops the spaces a grouped or pasted rate carries", () {
      expect(ocptMileageRateMilliCentsOf("  0.529  "), 52900);
      expect(ocptMileageRateMilliCentsOf("1 200,50"), 120050000);
    });

    test("reads nothing at all as no rate rather than as zero", () {
      expect(ocptMileageRateMilliCentsOf(""), isNull);
      expect(ocptMileageRateMilliCentsOf("   "), isNull);
    });

    test("reads what is not a number as no rate rather than as zero", () {
      expect(ocptMileageRateMilliCentsOf("gratuit"), isNull);
      expect(ocptMileageRateMilliCentsOf("0.529 €/km"), isNull);
      expect(ocptMileageRateMilliCentsOf("0,5,2"), isNull);
    });

    test("reads a negative rate as no rate", () {
      expect(ocptMileageRateMilliCentsOf("-0.529"), isNull);
    });

    test("rounds a fourth decimal to the nearest thousandth of a cent", () {
      expect(ocptMileageRateMilliCentsOf("0.5296"), 52960);
      expect(ocptMileageRateMilliCentsOf("0.5294"), 52940);
    });
  });

  group("ocptMileageRateTextOf", () {
    test("writes a rate the parser reads back unchanged, at three decimals", () {
      expect(ocptMileageRateTextOf(52900), "0.529");
      expect(ocptMileageRateMilliCentsOf(ocptMileageRateTextOf(52900)), 52900);
      expect(ocptMileageRateTextOf(60100), "0.601");
      expect(ocptMileageRateTextOf(0), "0.000");
    });

    test("writes no rate as an empty field", () {
      expect(ocptMileageRateTextOf(null), "");
    });
  });
}
