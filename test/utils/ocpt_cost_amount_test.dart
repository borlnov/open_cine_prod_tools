// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

void main() {
  group("ocptCostCentsOf", () {
    test("reads a whole amount and a decimal one", () {
      expect(ocptCostCentsOf("12"), 1200);
      expect(ocptCostCentsOf("12.50"), 1250);
      expect(ocptCostCentsOf("0.05"), 5);
    });

    test("reads the comma a French keyboard produces", () {
      expect(ocptCostCentsOf("12,50"), 1250);
    });

    test("drops the spaces a grouped or pasted amount carries", () {
      expect(ocptCostCentsOf("1 200"), 120000);
      expect(ocptCostCentsOf("1 200,50"), 120050);
      expect(ocptCostCentsOf("  12.50  "), 1250);
    });

    test("reads nothing at all as no amount rather than as zero", () {
      expect(ocptCostCentsOf(""), isNull);
      expect(ocptCostCentsOf("   "), isNull);
    });

    test("reads what is not a number as no amount rather than as zero", () {
      expect(ocptCostCentsOf("gratuit"), isNull);
      expect(ocptCostCentsOf("12 €"), isNull);
      expect(ocptCostCentsOf("12,5,3"), isNull);
    });

    test("reads a trailing separator as the amount already typed", () {
      // Dart's own `double.tryParse` accepts it, and so does this: `12.` is twelve euros being
      // typed, not a value worth refusing halfway.
      expect(ocptCostCentsOf("12."), 1200);
      expect(ocptCostCentsOf("12,"), 1200);
    });

    test("rounds to the nearest cent", () {
      expect(ocptCostCentsOf("12.005"), 1201);
      expect(ocptCostCentsOf("12.004"), 1200);
    });
  });

  group("ocptCostTextOf", () {
    test("writes an amount the parser reads back unchanged", () {
      expect(ocptCostTextOf(1250), "12.50");
      expect(ocptCostCentsOf(ocptCostTextOf(1250)), 1250);
      expect(ocptCostTextOf(5), "0.05");
      expect(ocptCostTextOf(0), "0.00");
    });

    test("writes no amount as an empty field", () {
      expect(ocptCostTextOf(null), "");
    });
  });
}
