// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

void main() {
  OcptBudgetLine buildLine({
    String id = "line-1",
    String posteId = "poste-1",
    int quantityMilli = 1000,
    int amountCents = 0,
    bool isTaxInclusive = true,
    int? vatRateBasisPoints,
  }) => OcptBudgetLine(
    id: id,
    posteId: posteId,
    label: "A line",
    quantityMilli: quantityMilli,
    unit: "unit",
    unitPrice: OcptMoney(
      amountCents: amountCents,
      isTaxInclusive: isTaxInclusive,
      vatRateBasisPoints: vatRateBasisPoints,
    ),
    elementId: null,
    notes: "",
    sortKey: "V",
  );

  OcptBudgetPoste buildPoste({
    String id = "poste-1",
    String code = "2",
    List<OcptBudgetLine> lines = const [],
  }) => OcptBudgetPoste(
    id: id,
    code: code,
    label: "A poste",
    simpleLabel: null,
    sortKey: "V",
    lines: lines,
  );

  group("ocptBudgetLineTotalCents", () {
    test("multiplies the quantity by the unit price", () {
      expect(
        ocptBudgetLineTotalCents(buildLine(quantityMilli: 3000, amountCents: 1500)),
        4500,
      );
    });

    test("reads a fractional quantity, 1.5 day at 100 €", () {
      expect(
        ocptBudgetLineTotalCents(buildLine(quantityMilli: 1500, amountCents: 10000)),
        15000,
      );
    });

    test("rounds to the nearest cent", () {
      // 3 units of a third-of-a-cent price: 1000 * 3333 / 1000 rounds to 3333, but a genuinely
      // fractional case (1333 milli-units at 7 cents) proves the rounding rather than the identity.
      expect(ocptBudgetLineTotalCents(buildLine(quantityMilli: 1333, amountCents: 7)), 9);
    });
  });

  group("ocptBudgetPosteQuotedTotalCents / ocptBudgetProjectQuotedTotalCents", () {
    test("sums a poste's lines row by row", () {
      final poste = buildPoste(
        lines: [
          buildLine(id: "l1", amountCents: 10000),
          buildLine(id: "l2", quantityMilli: 2000, amountCents: 500),
        ],
      );

      expect(ocptBudgetPosteQuotedTotalCents(poste), 11000);
    });

    test("an empty poste totals zero", () {
      expect(ocptBudgetPosteQuotedTotalCents(buildPoste()), 0);
    });

    test("sums every poste of the project", () {
      final postes = [
        buildPoste(
          id: "p1",
          lines: [buildLine(id: "l1", amountCents: 10000)],
        ),
        buildPoste(
          id: "p2",
          lines: [buildLine(id: "l2", amountCents: 5000)],
        ),
      ];

      expect(ocptBudgetProjectQuotedTotalCents(postes), 15000);
    });
  });

  group("ocptBudgetExcludingTaxTotalOf", () {
    test("a table mixing tax-inclusive and tax-exclusive lines totals correctly", () {
      final lines = [
        // 105.50 € including 5.5 %: 100 € excluding tax.
        buildLine(id: "l1", amountCents: 10550, vatRateBasisPoints: 550),
        // 200 € already excluding tax.
        buildLine(id: "l2", amountCents: 20000, isTaxInclusive: false, vatRateBasisPoints: 550),
      ];

      final total = ocptBudgetExcludingTaxTotalOf(lines, projectVatRateBasisPoints: 2000);

      expect(total.amountCents, 30000);
      expect(total.coveredLineCount, 2);
      expect(total.lineCount, 2);
      expect(total.isComplete, isTrue);
    });

    test("a silent line among known ones is left out, and coverage says so", () {
      final lines = [
        buildLine(id: "l1", amountCents: 10000, vatRateBasisPoints: 2000),
        buildLine(id: "l2", amountCents: 5000),
      ];

      // No project rate either, so the second line's rate is genuinely unknown.
      final total = ocptBudgetExcludingTaxTotalOf(lines, projectVatRateBasisPoints: null);

      expect(total.coveredLineCount, 1);
      expect(total.lineCount, 2);
      expect(total.isComplete, isFalse);
      // Only the covered line's own excluding-tax figure is counted: 10000 at 20 % excludes to
      // 8333.33..., rounded to 8333.
      expect(total.amountCents, 8333);
    });

    test("becomes complete once every line has declared a rate, 0 % included", () {
      final lines = [
        buildLine(id: "l1", amountCents: 10000, vatRateBasisPoints: 0),
        buildLine(id: "l2", amountCents: 5000, vatRateBasisPoints: 2000),
      ];

      final total = ocptBudgetExcludingTaxTotalOf(lines, projectVatRateBasisPoints: null);

      expect(total.isComplete, isTrue);
      expect(total.coveredLineCount, 2);
    });

    test("no lines at all totals zero and reads complete", () {
      final total = ocptBudgetExcludingTaxTotalOf(const [], projectVatRateBasisPoints: null);
      expect(total.amountCents, 0);
      expect(total.isComplete, isTrue);
    });
  });

  group("ocptBudgetRemainingCents / ocptBudgetVarianceCents / ocptBudgetConsumedRatioOf", () {
    test("remaining and variance are mirror figures", () {
      expect(
        ocptBudgetRemainingCents(quotedAmountCents: 10000, paidCents: 3000, committedCents: 2000),
        5000,
      );
      expect(
        ocptBudgetVarianceCents(quotedAmountCents: 10000, paidCents: 3000, committedCents: 2000),
        -5000,
      );
    });

    test("remaining goes negative once a poste is over its quote", () {
      expect(
        ocptBudgetRemainingCents(quotedAmountCents: 10000, paidCents: 9000, committedCents: 3000),
        -2000,
      );
      expect(
        ocptBudgetVarianceCents(quotedAmountCents: 10000, paidCents: 9000, committedCents: 3000),
        2000,
      );
    });

    test("the consumed ratio is null rather than a division by zero", () {
      expect(
        ocptBudgetConsumedRatioOf(quotedAmountCents: 0, paidCents: 0, committedCents: 0),
        isNull,
      );
    });

    test("the consumed ratio reads exactly on quote as 1.0", () {
      expect(
        ocptBudgetConsumedRatioOf(quotedAmountCents: 10000, paidCents: 6000, committedCents: 4000),
        1.0,
      );
    });
  });

  group("ocptBudgetPosteStrainOf", () {
    test("within quote", () {
      expect(
        ocptBudgetPosteStrainOf(quotedAmountCents: 10000, paidCents: 5000, committedCents: 0),
        OcptBudgetPosteStrain.within,
      );
    });

    test("near quote, above 90 %", () {
      expect(
        ocptBudgetPosteStrainOf(quotedAmountCents: 10000, paidCents: 9500, committedCents: 0),
        OcptBudgetPosteStrain.near,
      );
    });

    test("over quote", () {
      expect(
        ocptBudgetPosteStrainOf(quotedAmountCents: 10000, paidCents: 9000, committedCents: 2000),
        OcptBudgetPosteStrain.over,
      );
    });

    test("a poste with no quote at all and nothing moved reads within", () {
      expect(
        ocptBudgetPosteStrainOf(quotedAmountCents: 0, paidCents: 0, committedCents: 0),
        OcptBudgetPosteStrain.within,
      );
    });

    test("a poste with no quote at all but something already moved reads over", () {
      expect(
        ocptBudgetPosteStrainOf(quotedAmountCents: 0, paidCents: 500, committedCents: 0),
        OcptBudgetPosteStrain.over,
      );
    });
  });

  group("ocptBudgetTotalOf", () {
    test("reads a tax-inclusive line under either basis, given a rate", () {
      final lines = [buildLine(amountCents: 1200, vatRateBasisPoints: 2000)];

      expect(
        ocptBudgetTotalOf(
          lines,
          basis: OcptBudgetTaxBasis.includingTax,
          projectVatRateBasisPoints: null,
        ).amountCents,
        1200,
      );
      expect(
        ocptBudgetTotalOf(
          lines,
          basis: OcptBudgetTaxBasis.excludingTax,
          projectVatRateBasisPoints: null,
        ).amountCents,
        1000,
      );
    });

    test("a line already typed in the basis asked for needs no rate at all", () {
      final lines = [buildLine(amountCents: 1250)];

      final total = ocptBudgetTotalOf(
        lines,
        basis: OcptBudgetTaxBasis.includingTax,
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 1250);
      expect(total.isComplete, isTrue);
    });

    test("a line typed in the other basis with no known rate is covered by neither figure", () {
      final lines = [buildLine(amountCents: 1000, isTaxInclusive: false)];

      final total = ocptBudgetTotalOf(
        lines,
        basis: OcptBudgetTaxBasis.includingTax,
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 0);
      expect(total.coveredLineCount, 0);
      expect(total.lineCount, 1);
      expect(total.isComplete, isFalse);
    });

    test("sums a table mixing the two bases row by row", () {
      final lines = [
        buildLine(id: "a", amountCents: 1200, vatRateBasisPoints: 2000),
        buildLine(id: "b", amountCents: 1000, isTaxInclusive: false, vatRateBasisPoints: 550),
      ];

      // 1200 TTC at 20 % is 1000 HT; 1000 HT at 5.5 % is 1055 TTC. Converting the summed figure by
      // either single rate would land somewhere else entirely.
      expect(
        ocptBudgetTotalOf(
          lines,
          basis: OcptBudgetTaxBasis.excludingTax,
          projectVatRateBasisPoints: null,
        ).amountCents,
        2000,
      );
      expect(
        ocptBudgetTotalOf(
          lines,
          basis: OcptBudgetTaxBasis.includingTax,
          projectVatRateBasisPoints: null,
        ).amountCents,
        2255,
      );
    });

    test("an explicit 0 % counts, and counts as covered", () {
      final lines = [buildLine(amountCents: 1250, vatRateBasisPoints: 0)];

      final total = ocptBudgetTotalOf(
        lines,
        basis: OcptBudgetTaxBasis.excludingTax,
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 1250);
      expect(total.isComplete, isTrue);
    });
  });
}
