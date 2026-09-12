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
    String? inKindResourceId,
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
    inKindResourceId: inKindResourceId,
    provisionKey: null,
    provisionDigest: null,
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
    estimateToCompleteCents: null,
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
        ocptBudgetRemainingCents(
          quotedAmountCents: 10000,
          paidCents: 3000,
          committedCents: 2000,
          inKindCoveredCents: 0,
        ),
        5000,
      );
      expect(
        ocptBudgetVarianceCents(
          quotedAmountCents: 10000,
          paidCents: 3000,
          committedCents: 2000,
          inKindCoveredCents: 0,
        ),
        -5000,
      );
    });

    test("remaining goes negative once a poste is over its quote", () {
      expect(
        ocptBudgetRemainingCents(
          quotedAmountCents: 10000,
          paidCents: 9000,
          committedCents: 3000,
          inKindCoveredCents: 0,
        ),
        -2000,
      );
      expect(
        ocptBudgetVarianceCents(
          quotedAmountCents: 10000,
          paidCents: 9000,
          committedCents: 3000,
          inKindCoveredCents: 0,
        ),
        2000,
      );
    });

    test("the consumed ratio is null rather than a division by zero", () {
      expect(
        ocptBudgetConsumedRatioOf(
          quotedAmountCents: 0,
          paidCents: 0,
          committedCents: 0,
          inKindCoveredCents: 0,
        ),
        isNull,
      );
    });

    test("the consumed ratio reads exactly on quote as 1.0", () {
      expect(
        ocptBudgetConsumedRatioOf(
          quotedAmountCents: 10000,
          paidCents: 6000,
          committedCents: 4000,
          inKindCoveredCents: 0,
        ),
        1.0,
      );
    });

    test("an in-kind-only poste nets to no remainder and no variance", () {
      // A poste quoted at exactly its own counterpart line's value, nothing paid or committed.
      expect(
        ocptBudgetRemainingCents(
          quotedAmountCents: 5000,
          paidCents: 0,
          committedCents: 0,
          inKindCoveredCents: 5000,
        ),
        0,
      );
      expect(
        ocptBudgetVarianceCents(
          quotedAmountCents: 5000,
          paidCents: 0,
          committedCents: 0,
          inKindCoveredCents: 5000,
        ),
        0,
      );
      expect(
        ocptBudgetConsumedRatioOf(
          quotedAmountCents: 5000,
          paidCents: 0,
          committedCents: 0,
          inKindCoveredCents: 5000,
        ),
        1.0,
      );
    });

    test("a poste mixing a paid cash line and an in-kind line also nets to zero", () {
      // Quoted 8000 (3000 cash line + 5000 counterpart line), the cash line already paid in full.
      expect(
        ocptBudgetRemainingCents(
          quotedAmountCents: 8000,
          paidCents: 3000,
          committedCents: 0,
          inKindCoveredCents: 5000,
        ),
        0,
      );
      expect(
        ocptBudgetVarianceCents(
          quotedAmountCents: 8000,
          paidCents: 3000,
          committedCents: 0,
          inKindCoveredCents: 5000,
        ),
        0,
      );
    });
  });

  group("ocptBudgetInKindCoveredCentsByPosteId", () {
    test("sums a poste's own counterpart lines, an ordinary line contributing nothing", () {
      final postes = [
        buildPoste(
          id: "p1",
          lines: [
            buildLine(id: "l1", amountCents: 3000),
            buildLine(id: "l2", amountCents: 5000, inKindResourceId: "resource-1"),
          ],
        ),
      ];

      expect(ocptBudgetInKindCoveredCentsByPosteId(postes), {"p1": 5000});
    });

    test("a poste with no counterpart line has no key at all", () {
      final postes = [
        buildPoste(id: "p1", lines: [buildLine(id: "l1", amountCents: 3000)]),
      ];

      expect(ocptBudgetInKindCoveredCentsByPosteId(postes), isEmpty);
    });

    test("sums more than one counterpart line under the same poste", () {
      final postes = [
        buildPoste(
          id: "p1",
          lines: [
            buildLine(id: "l1", amountCents: 5000, inKindResourceId: "resource-1"),
            buildLine(id: "l2", amountCents: 2000, inKindResourceId: "resource-2"),
          ],
        ),
      ];

      expect(ocptBudgetInKindCoveredCentsByPosteId(postes), {"p1": 7000});
    });
  });

  group("ocptBudgetPosteStrainOf", () {
    test("within quote", () {
      expect(
        ocptBudgetPosteStrainOf(
          quotedAmountCents: 10000,
          paidCents: 5000,
          committedCents: 0,
          inKindCoveredCents: 0,
        ),
        OcptBudgetPosteStrain.within,
      );
    });

    test("near quote, above 90 %", () {
      expect(
        ocptBudgetPosteStrainOf(
          quotedAmountCents: 10000,
          paidCents: 9500,
          committedCents: 0,
          inKindCoveredCents: 0,
        ),
        OcptBudgetPosteStrain.near,
      );
    });

    test("over quote", () {
      expect(
        ocptBudgetPosteStrainOf(
          quotedAmountCents: 10000,
          paidCents: 9000,
          committedCents: 2000,
          inKindCoveredCents: 0,
        ),
        OcptBudgetPosteStrain.over,
      );
    });

    test("a poste with no quote at all and nothing moved reads within", () {
      expect(
        ocptBudgetPosteStrainOf(
          quotedAmountCents: 0,
          paidCents: 0,
          committedCents: 0,
          inKindCoveredCents: 0,
        ),
        OcptBudgetPosteStrain.within,
      );
    });

    test("a poste with no quote at all but something already moved reads over", () {
      expect(
        ocptBudgetPosteStrainOf(
          quotedAmountCents: 0,
          paidCents: 500,
          committedCents: 0,
          inKindCoveredCents: 0,
        ),
        OcptBudgetPosteStrain.over,
      );
    });

    test("an in-kind-only poste never reads over — it nets exactly to its own quote", () {
      // Consumed equals the quote exactly (100 %), which is the pre-existing "near" reading above
      // the 90 % threshold (see "near quote, above 90 %" above) — not a fact about in-kind
      // covering, but proof the counterpart line's own contribution never tips a poste over on its
      // own, since it moves the quote and the consumed side by the very same amount.
      expect(
        ocptBudgetPosteStrainOf(
          quotedAmountCents: 5000,
          paidCents: 0,
          committedCents: 0,
          inKindCoveredCents: 5000,
        ),
        OcptBudgetPosteStrain.near,
      );
    });

    test("a poste mixing a paid cash line and an in-kind line stays comfortably within", () {
      // Quoted 9000 (3000 cash line + 5000 counterpart line + headroom), only the cash line and the
      // counterpart line's own settlement have moved: 8000 of 9000, under the 90 % threshold.
      expect(
        ocptBudgetPosteStrainOf(
          quotedAmountCents: 9000,
          paidCents: 3000,
          committedCents: 0,
          inKindCoveredCents: 5000,
        ),
        OcptBudgetPosteStrain.within,
      );
    });
  });

  group(
    "ocptBudgetEstimateToCompleteCents / ocptBudgetFinalCostCents / "
    "ocptBudgetFinalCostVarianceCents",
    () {
      test("a typed estimate wins over the derived one", () {
        expect(
          ocptBudgetEstimateToCompleteCents(
            quotedAmountCents: 10000,
            paidCents: 3000,
            committedCents: 0,
            inKindCoveredCents: 0,
            typedEstimateToCompleteCents: 9000,
          ),
          9000,
        );
      });

      test("a typed zero is a value, not an absence — a poste declared finished", () {
        expect(
          ocptBudgetEstimateToCompleteCents(
            quotedAmountCents: 10000,
            paidCents: 3000,
            committedCents: 0,
            inKindCoveredCents: 0,
            typedEstimateToCompleteCents: 0,
          ),
          0,
        );
      });

      test("the derived estimate under quote is exactly what is left", () {
        expect(
          ocptBudgetEstimateToCompleteCents(
            quotedAmountCents: 10000,
            paidCents: 3000,
            committedCents: 2000,
            inKindCoveredCents: 0,
            typedEstimateToCompleteCents: null,
          ),
          5000,
        );
      });

      test("the derived estimate exactly on quote is zero", () {
        expect(
          ocptBudgetEstimateToCompleteCents(
            quotedAmountCents: 10000,
            paidCents: 6000,
            committedCents: 4000,
            inKindCoveredCents: 0,
            typedEstimateToCompleteCents: null,
          ),
          0,
        );
      });

      test("the derived estimate over quote clamps to zero rather than going negative", () {
        expect(
          ocptBudgetEstimateToCompleteCents(
            quotedAmountCents: 10000,
            paidCents: 9000,
            committedCents: 3000,
            inKindCoveredCents: 0,
            typedEstimateToCompleteCents: null,
          ),
          0,
        );
      });

      test("a poste with no quote at all and nothing moved derives to zero", () {
        expect(
          ocptBudgetEstimateToCompleteCents(
            quotedAmountCents: 0,
            paidCents: 0,
            committedCents: 0,
            inKindCoveredCents: 0,
            typedEstimateToCompleteCents: null,
          ),
          0,
        );
      });

      test("the final cost equals the quote when the estimate is derived and not over", () {
        const quotedAmountCents = 10000;
        const paidCents = 3000;
        const committedCents = 2000;
        final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
          quotedAmountCents: quotedAmountCents,
          paidCents: paidCents,
          committedCents: committedCents,
          inKindCoveredCents: 0,
          typedEstimateToCompleteCents: null,
        );

        final finalCostCents = ocptBudgetFinalCostCents(
          paidCents: paidCents,
          committedCents: committedCents,
          estimateToCompleteCents: estimateToCompleteCents,
        );

        expect(finalCostCents, quotedAmountCents);
        expect(
          ocptBudgetFinalCostVarianceCents(
            quotedAmountCents: quotedAmountCents,
            finalCostCents: finalCostCents,
          ),
          0,
        );
      });

      test("the final-cost variance disagrees with ocptBudgetVarianceCents once typed", () {
        const quotedAmountCents = 10000;
        const paidCents = 3000;
        const committedCents = 2000;

        // A human types a much larger estimate to complete than the derived 5000 would be.
        final finalCostCents = ocptBudgetFinalCostCents(
          paidCents: paidCents,
          committedCents: committedCents,
          estimateToCompleteCents: 9000,
        );

        final finalCostVarianceCents = ocptBudgetFinalCostVarianceCents(
          quotedAmountCents: quotedAmountCents,
          finalCostCents: finalCostCents,
        );
        final varianceCents = ocptBudgetVarianceCents(
          quotedAmountCents: quotedAmountCents,
          paidCents: paidCents,
          committedCents: committedCents,
          inKindCoveredCents: 0,
        );

        // The plain variance still reads the poste as under quote by 5000; the final-cost variance,
        // fed by the typed estimate, reads it as heading 4000 over.
        expect(varianceCents, -5000);
        expect(finalCostVarianceCents, 4000);
        expect(finalCostVarianceCents, isNot(varianceCents));
      });
    },
  );

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
