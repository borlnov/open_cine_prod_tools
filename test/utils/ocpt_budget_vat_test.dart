// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';

void main() {
  group("ocptEffectiveVatRateOf", () {
    test("a line stating no rate follows the project's own", () {
      final rate = ocptEffectiveVatRateOf(
        lineVatRateBasisPoints: null,
        projectVatRateBasisPoints: 2000,
      );
      expect(rate.basisPoints, 2000);
      expect(rate.isOverridden, isFalse);
    });

    test("a line overriding the project's rate wins, whatever it states", () {
      final rate = ocptEffectiveVatRateOf(
        lineVatRateBasisPoints: 550,
        projectVatRateBasisPoints: 2000,
      );
      expect(rate.basisPoints, 550);
      expect(rate.isOverridden, isTrue);
    });

    test("an explicit 0 % override still wins over the project's own rate", () {
      final rate = ocptEffectiveVatRateOf(
        lineVatRateBasisPoints: 0,
        projectVatRateBasisPoints: 2000,
      );
      expect(rate.basisPoints, 0);
      expect(rate.isOverridden, isTrue);
    });

    test("nobody has recorded a rate anywhere: there is none to read", () {
      final rate = ocptEffectiveVatRateOf(
        lineVatRateBasisPoints: null,
        projectVatRateBasisPoints: null,
      );
      expect(rate.basisPoints, isNull);
      expect(rate.isOverridden, isNull);
    });
  });

  group("ocptExcludingTaxAmountCentsOf / ocptIncludingTaxAmountCentsOf / ocptVatAmountCentsOf", () {
    test("a project with no rate leaves a tax-inclusive line's excluding-tax figure empty", () {
      const money = OcptMoney(amountCents: 1250, isTaxInclusive: true, vatRateBasisPoints: null);

      expect(
        ocptExcludingTaxAmountCentsOf(money, projectVatRateBasisPoints: null),
        isNull,
      );
      expect(ocptVatAmountCentsOf(money, projectVatRateBasisPoints: null), isNull);
      // Including tax needs no rate at all: the figure was typed that way.
      expect(ocptIncludingTaxAmountCentsOf(money, projectVatRateBasisPoints: null), 1250);
    });

    test("a line overriding to 5.5 % against a project at 20 % reads its own rate", () {
      const money = OcptMoney(amountCents: 10550, isTaxInclusive: true, vatRateBasisPoints: 550);

      expect(
        ocptExcludingTaxAmountCentsOf(money, projectVatRateBasisPoints: 2000),
        10000,
      );
      expect(ocptIncludingTaxAmountCentsOf(money, projectVatRateBasisPoints: 2000), 10550);
      expect(ocptVatAmountCentsOf(money, projectVatRateBasisPoints: 2000), 550);
    });

    test("a line at 0 % counts its excluding-tax figure equal to its tax-inclusive one", () {
      const taxInclusive = OcptMoney(
        amountCents: 5000,
        isTaxInclusive: true,
        vatRateBasisPoints: 0,
      );
      expect(
        ocptExcludingTaxAmountCentsOf(taxInclusive, projectVatRateBasisPoints: 2000),
        5000,
      );
      expect(ocptVatAmountCentsOf(taxInclusive, projectVatRateBasisPoints: 2000), 0);

      const taxExclusive = OcptMoney(
        amountCents: 5000,
        isTaxInclusive: false,
        vatRateBasisPoints: 0,
      );
      expect(
        ocptIncludingTaxAmountCentsOf(taxExclusive, projectVatRateBasisPoints: 2000),
        5000,
      );
      expect(ocptVatAmountCentsOf(taxExclusive, projectVatRateBasisPoints: 2000), 0);
    });

    test("a silent line at a project with no rate counts for neither figure", () {
      const money = OcptMoney(amountCents: 5000, isTaxInclusive: true, vatRateBasisPoints: null);

      expect(
        ocptExcludingTaxAmountCentsOf(money, projectVatRateBasisPoints: null),
        isNull,
      );
      expect(ocptVatAmountCentsOf(money, projectVatRateBasisPoints: null), isNull);
    });

    test(
      "a tax-exclusive amount is already its own excluding-tax figure, rate or no rate",
      () {
        const money = OcptMoney(
          amountCents: 8000,
          isTaxInclusive: false,
          vatRateBasisPoints: null,
        );

        expect(
          ocptExcludingTaxAmountCentsOf(money, projectVatRateBasisPoints: null),
          8000,
        );
        // But grossing it up to the including-tax figure still needs a known rate.
        expect(ocptIncludingTaxAmountCentsOf(money, projectVatRateBasisPoints: null), isNull);
      },
    );

    test("an amount typed reads back to the cent after a round trip through the display basis", () {
      const money = OcptMoney(amountCents: 1249, isTaxInclusive: true, vatRateBasisPoints: 2000);

      // The stored figure is never reconstructed: converting to excluding tax and back to
      // including tax must land exactly on the cent originally typed, not one cent off.
      final excludingTax = ocptExcludingTaxAmountCentsOf(money, projectVatRateBasisPoints: null)!;
      final roundTripped = ocptIncludingTaxAmountCentsOf(
        OcptMoney(amountCents: excludingTax, isTaxInclusive: false, vatRateBasisPoints: 2000),
        projectVatRateBasisPoints: null,
      );

      expect(roundTripped, 1249);
    });

    test("rounds to the nearest cent", () {
      // 100 cents at 5.5 % including tax excludes to 94.79... cents, rounded to 95.
      const money = OcptMoney(amountCents: 100, isTaxInclusive: true, vatRateBasisPoints: 550);
      expect(ocptExcludingTaxAmountCentsOf(money, projectVatRateBasisPoints: null), 95);
    });
  });

  group("ocptVatRateBasisPointsOf", () {
    test("reads a whole number of per cent as basis points", () {
      expect(ocptVatRateBasisPointsOf("20"), 2000);
    });

    test("accepts both decimal separators, and the spaces a paste carries", () {
      expect(ocptVatRateBasisPointsOf("5,5"), 550);
      expect(ocptVatRateBasisPointsOf("5.5"), 550);
      expect(ocptVatRateBasisPointsOf(" 5,5 "), 550);
    });

    test("reads an explicit zero as the value it is, never as no rate at all", () {
      expect(ocptVatRateBasisPointsOf("0"), 0);
    });

    test("reads an empty, unparseable or negative figure as no rate", () {
      expect(ocptVatRateBasisPointsOf(""), isNull);
      expect(ocptVatRateBasisPointsOf("twenty"), isNull);
      expect(ocptVatRateBasisPointsOf("-3"), isNull);
    });
  });

  group("ocptVatRatePercentTextOf", () {
    test("writes a whole number of per cent bare", () {
      expect(ocptVatRatePercentTextOf(2000), "20");
      expect(ocptVatRatePercentTextOf(0), "0");
    });

    test("writes a fractional rate with its trailing zeroes dropped", () {
      expect(ocptVatRatePercentTextOf(550), "5.5");
    });

    test("writes no rate at all as an empty field", () {
      expect(ocptVatRatePercentTextOf(null), "");
    });

    test("writes what it reads back, to the basis point", () {
      for (final basisPoints in [0, 550, 1000, 2000, 2115]) {
        expect(ocptVatRateBasisPointsOf(ocptVatRatePercentTextOf(basisPoints)), basisPoints);
      }
    });
  });

  group("ocptBudgetPosteUniformVatRateOf", () {
    OcptBudgetLine buildLine({required String id, int? vatRateBasisPoints}) => OcptBudgetLine(
      id: id,
      posteId: "poste-1",
      label: "A line",
      quantityMilli: 1000,
      unit: "unit",
      unitPrice: OcptMoney(
        amountCents: 1000,
        isTaxInclusive: true,
        vatRateBasisPoints: vatRateBasisPoints,
      ),
      elementId: null,
      notes: "",
      sortKey: "a",
    );

    test("answers the rate every line agrees on, and says it was overridden", () {
      final rate = ocptBudgetPosteUniformVatRateOf(
        [
          buildLine(id: "a", vatRateBasisPoints: 550),
          buildLine(id: "b", vatRateBasisPoints: 550),
        ],
        projectVatRateBasisPoints: 2000,
      );

      expect(rate?.basisPoints, 550);
      expect(rate?.isOverridden, isTrue);
    });

    test("answers the project's own rate when every line inherits it", () {
      final rate = ocptBudgetPosteUniformVatRateOf(
        [buildLine(id: "a"), buildLine(id: "b")],
        projectVatRateBasisPoints: 2000,
      );

      expect(rate?.basisPoints, 2000);
      expect(rate?.isOverridden, isFalse);
    });

    test("answers nothing while the lines disagree about the figure", () {
      expect(
        ocptBudgetPosteUniformVatRateOf(
          [
            buildLine(id: "a", vatRateBasisPoints: 550),
            buildLine(id: "b", vatRateBasisPoints: 2000),
          ],
          projectVatRateBasisPoints: null,
        ),
        isNull,
      );
    });

    test("answers nothing when one line overrides what another merely inherits", () {
      // The figure is the same either way; where it comes from is not, and the sub-line would have
      // no one colour to be painted in.
      expect(
        ocptBudgetPosteUniformVatRateOf(
          [buildLine(id: "a", vatRateBasisPoints: 2000), buildLine(id: "b")],
          projectVatRateBasisPoints: 2000,
        ),
        isNull,
      );
    });

    test("answers nothing while no rate is known at all, and for a poste with no line", () {
      expect(
        ocptBudgetPosteUniformVatRateOf([buildLine(id: "a")], projectVatRateBasisPoints: null),
        isNull,
      );
      expect(ocptBudgetPosteUniformVatRateOf(const [], projectVatRateBasisPoints: 2000), isNull);
    });
  });
}
