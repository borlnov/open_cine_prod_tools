// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_provision_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_provision.dart';

/// Every nature's own wording, as a mode would resolve and hand in.
const _labels = <OcptBudgetProvisionKind, String>{
  OcptBudgetProvisionKind.meal: "Meals",
  OcptBudgetProvisionKind.snack: "Craft services",
  OcptBudgetProvisionKind.travelAllowance: "Travel",
  OcptBudgetProvisionKind.accommodationAllowance: "Accommodation",
  OcptBudgetProvisionKind.mealAllowance: "Meals defrayed",
  OcptBudgetProvisionKind.otherAllowance: "Other",
};

/// A minimal defrayal, everything but what each test varies neutral.
OcptBudgetAllowance _allowance({
  required String id,
  OcptBudgetAllowanceKind kind = OcptBudgetAllowanceKind.travel,
  int quantityMilli = 1000,
  int unitAmountMilliCents = 100000,
}) => OcptBudgetAllowance(
  id: id,
  personId: null,
  kind: kind,
  label: id,
  date: null,
  endDate: null,
  quantityMilli: quantityMilli,
  unitAmountMilliCents: unitAmountMilliCents,
  notes: "",
  sortKey: "a0",
);

/// A minimal quote line, everything but what each test varies neutral.
OcptBudgetLine _line({
  required String id,
  required String label,
  required int quantityMilli,
  required int unitAmountCents,
  String? provisionKey,
  String? provisionDigest,
}) => OcptBudgetLine(
  id: id,
  posteId: "poste-1",
  label: label,
  quantityMilli: quantityMilli,
  unit: "",
  unitPrice: OcptMoney(
    amountCents: unitAmountCents,
    isTaxInclusive: true,
    vatRateBasisPoints: null,
  ),
  elementId: null,
  provisionKey: provisionKey,
  provisionDigest: provisionDigest,
  notes: "",
  sortKey: "a0",
);

/// A line the provisioning itself wrote, its digest matching what it holds.
OcptBudgetLine _provisionedLine({
  required String id,
  required OcptBudgetProvisionKind kind,
  required int quantityMilli,
  required int unitAmountCents,
}) => _line(
  id: id,
  label: _labels[kind]!,
  quantityMilli: quantityMilli,
  unitAmountCents: unitAmountCents,
  provisionKey: kind.name,
  provisionDigest: ocptBudgetProvisionDigestOf(
    label: _labels[kind]!,
    quantityMilli: quantityMilli,
    unitAmountCents: unitAmountCents,
  ),
);

void main() {
  group("ocptBudgetProvisionItemsOf", () {
    test("catering carries a real quantity and a real unit price", () {
      final items = ocptBudgetProvisionItemsOf(
        mealCount: 28,
        snackCount: 28,
        mealPriceCents: 1200,
        snackPriceCents: 300,
        allowances: const [],
      );

      expect(items.length, 2);
      expect(items.first.kind, OcptBudgetProvisionKind.meal);
      expect(items.first.quantityMilli, 28000);
      expect(items.first.unitAmountCents, 1200);
    });

    test("no price recorded means no figure at all, never a free meal", () {
      // The mode's standing rule: null and zero are different facts.
      final items = ocptBudgetProvisionItemsOf(
        mealCount: 28,
        snackCount: 28,
        mealPriceCents: null,
        snackPriceCents: null,
        allowances: const [],
      );

      expect(items, isEmpty);
    });

    test("no shooting day means no figure either", () {
      final items = ocptBudgetProvisionItemsOf(
        mealCount: 0,
        snackCount: 0,
        mealPriceCents: 1200,
        snackPriceCents: 300,
        allowances: const [],
      );

      expect(items, isEmpty);
    });

    test("each defrayal nature is one figure of quantity one, summed", () {
      // Aggregating across people, dates and mileage scales leaves no single unit price, so the
      // sum is the unit price and the quantity is one.
      final items = ocptBudgetProvisionItemsOf(
        mealCount: 0,
        snackCount: 0,
        mealPriceCents: null,
        snackPriceCents: null,
        allowances: [
          _allowance(id: "a1", quantityMilli: 168000, unitAmountMilliCents: 52900),
          _allowance(id: "a2", quantityMilli: 168000, unitAmountMilliCents: 52900),
          _allowance(
            id: "a3",
            kind: OcptBudgetAllowanceKind.accommodation,
            quantityMilli: 13000,
            unitAmountMilliCents: 6000000,
          ),
        ],
      );

      expect(items.map((item) => item.kind), [
        OcptBudgetProvisionKind.travelAllowance,
        OcptBudgetProvisionKind.accommodationAllowance,
      ]);
      expect(items.first.quantityMilli, 1000);
      expect(items.first.unitAmountCents, 8887 * 2);
      expect(items.last.unitAmountCents, 78000);
    });

    test("a nature nobody wrote a row for is left out entirely", () {
      final items = ocptBudgetProvisionItemsOf(
        mealCount: 0,
        snackCount: 0,
        mealPriceCents: null,
        snackPriceCents: null,
        allowances: [_allowance(id: "a1")],
      );

      expect(items.map((item) => item.kind), [OcptBudgetProvisionKind.travelAllowance]);
    });
  });

  group("ocptBudgetProvisionPlanOf", () {
    test("a nature with no line yet is created", () {
      final plan = ocptBudgetProvisionPlanOf(
        items: const [
          OcptBudgetProvisionItem(
            kind: OcptBudgetProvisionKind.meal,
            quantityMilli: 28000,
            unitAmountCents: 1200,
          ),
        ],
        posteLines: const [],
        labels: _labels,
      );

      expect(plan.single.outcome, OcptBudgetProvisionOutcome.created);
      expect(plan.single.lineId, isNull);
      expect(plan.single.label, "Meals");
    });

    test("a line the provisioning wrote, still untouched, is updated when the figure moves", () {
      final plan = ocptBudgetProvisionPlanOf(
        items: const [
          OcptBudgetProvisionItem(
            kind: OcptBudgetProvisionKind.meal,
            quantityMilli: 31000,
            unitAmountCents: 1200,
          ),
        ],
        posteLines: [
          _provisionedLine(
            id: "line-1",
            kind: OcptBudgetProvisionKind.meal,
            quantityMilli: 28000,
            unitAmountCents: 1200,
          ),
        ],
        labels: _labels,
      );

      expect(plan.single.outcome, OcptBudgetProvisionOutcome.updated);
      expect(plan.single.lineId, "line-1");
      expect(plan.single.quantityMilli, 31000);
    });

    test("a line already holding the current figure is left unchanged", () {
      final plan = ocptBudgetProvisionPlanOf(
        items: const [
          OcptBudgetProvisionItem(
            kind: OcptBudgetProvisionKind.meal,
            quantityMilli: 28000,
            unitAmountCents: 1200,
          ),
        ],
        posteLines: [
          _provisionedLine(
            id: "line-1",
            kind: OcptBudgetProvisionKind.meal,
            quantityMilli: 28000,
            unitAmountCents: 1200,
          ),
        ],
        labels: _labels,
      );

      expect(plan.single.outcome, OcptBudgetProvisionOutcome.unchanged);
    });

    test("a line somebody has retouched is reported, never overwritten", () {
      // The digest still says 28 meals at 12,00 €; the line now says 30 at 11,00 €, so a human
      // has been in it. The money rule of this mode: a figure somebody typed is never silently
      // corrected.
      final touched = _line(
        id: "line-1",
        label: "Meals",
        quantityMilli: 30000,
        unitAmountCents: 1100,
        provisionKey: OcptBudgetProvisionKind.meal.name,
        provisionDigest: ocptBudgetProvisionDigestOf(
          label: "Meals",
          quantityMilli: 28000,
          unitAmountCents: 1200,
        ),
      );

      final plan = ocptBudgetProvisionPlanOf(
        items: const [
          OcptBudgetProvisionItem(
            kind: OcptBudgetProvisionKind.meal,
            quantityMilli: 31000,
            unitAmountCents: 1200,
          ),
        ],
        posteLines: [touched],
        labels: _labels,
      );

      expect(plan.single.outcome, OcptBudgetProvisionOutcome.skippedEdited);
      expect(plan.single.lineId, "line-1");
    });

    test("a hand-typed line of the same poste is never touched at all", () {
      final plan = ocptBudgetProvisionPlanOf(
        items: const [
          OcptBudgetProvisionItem(
            kind: OcptBudgetProvisionKind.meal,
            quantityMilli: 28000,
            unitAmountCents: 1200,
          ),
        ],
        posteLines: [
          _line(id: "typed", label: "Van hire", quantityMilli: 1000, unitAmountCents: 50000),
        ],
        labels: _labels,
      );

      // One entry, and it creates: the typed line carries no provisioning key, so the plan has
      // nothing to say about it.
      expect(plan.single.outcome, OcptBudgetProvisionOutcome.created);
      expect(plan.map((entry) => entry.lineId), [null]);
    });

    test("a provisioned line whose nature has gone is emptied, not left stale", () {
      // Every travel defrayal has been removed since the last provision. Leaving yesterday's total
      // standing in the quote would be the one dishonest option; deleting the line would take a
      // decision that belongs to the user, who can see the zero.
      final plan = ocptBudgetProvisionPlanOf(
        items: const [],
        posteLines: [
          _provisionedLine(
            id: "line-1",
            kind: OcptBudgetProvisionKind.travelAllowance,
            quantityMilli: 1000,
            unitAmountCents: 17774,
          ),
        ],
        labels: _labels,
      );

      expect(plan.single.outcome, OcptBudgetProvisionOutcome.updated);
      expect(plan.single.quantityMilli, 0);
      expect(plan.single.unitAmountCents, 0);
    });

    test("a provisioned line of an unknown nature is left strictly alone", () {
      // Written by a build that knows a nature this one does not.
      final plan = ocptBudgetProvisionPlanOf(
        items: const [],
        posteLines: [
          _line(
            id: "line-1",
            label: "Something else",
            quantityMilli: 1000,
            unitAmountCents: 100,
            provisionKey: "aNatureFromTheFuture",
            provisionDigest: "[]",
          ),
        ],
        labels: _labels,
      );

      expect(plan, isEmpty);
    });
  });
}
