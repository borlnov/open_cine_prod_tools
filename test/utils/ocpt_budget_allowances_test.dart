// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_allowances.dart';

/// A minimal defrayal, everything but what each test actually varies neutral.
OcptBudgetAllowance _allowance({
  required String id,
  String? personId,
  OcptBudgetAllowanceKind kind = OcptBudgetAllowanceKind.travel,
  int quantityMilli = 0,
  int unitAmountMilliCents = 0,
}) => OcptBudgetAllowance(
  id: id,
  personId: personId,
  kind: kind,
  label: id,
  date: null,
  endDate: null,
  quantityMilli: quantityMilli,
  unitAmountMilliCents: unitAmountMilliCents,
  notes: "",
  sortKey: "a0",
);

void main() {
  group("ocptBudgetAllowanceAmountCents", () {
    test("states a published mileage scale exactly", () {
      // 168 km at 0.529 €/km is 88,87 € — the figure the scale states, which whole cents could
      // not have expressed on either side of the multiplication.
      expect(
        ocptBudgetAllowanceAmountCents(quantityMilli: 168000, unitAmountMilliCents: 52900),
        8887,
      );
    });

    test("rounds half up, once, at the very end", () {
      // 1,5 units at 0.001 € each is 0,15 cents, which rounds to nothing at all rather than to a
      // cent — and 1,5 at 0.01 € is 1,5 cents, which rounds up.
      expect(ocptBudgetAllowanceAmountCents(quantityMilli: 1500, unitAmountMilliCents: 100), 0);
      expect(ocptBudgetAllowanceAmountCents(quantityMilli: 1500, unitAmountMilliCents: 1000), 2);
    });

    test("answers a negative figure rather than correcting it", () {
      // Somebody typed it; this says what it comes to, it does not police it.
      expect(
        ocptBudgetAllowanceAmountCents(quantityMilli: -168000, unitAmountMilliCents: 52900),
        -8887,
      );
    });

    test("a row with no quantity or no price comes to nothing", () {
      expect(ocptBudgetAllowanceAmountCents(quantityMilli: 0, unitAmountMilliCents: 52900), 0);
      expect(ocptBudgetAllowanceAmountCents(quantityMilli: 168000, unitAmountMilliCents: 0), 0);
    });
  });

  group("ocptBudgetAllowancesTotalCents", () {
    test("rounds each row before summing, never the sum", () {
      // Three rows of 0,4 cents each: rounded per row they come to nothing, which is what each
      // person is actually owed. Rounding the sum instead would have said one cent, a cent no row
      // on screen could account for.
      final allowances = [
        for (final id in ["a1", "a2", "a3"])
          _allowance(id: id, quantityMilli: 1000, unitAmountMilliCents: 400),
      ];

      expect(ocptBudgetAllowancesTotalCents(allowances), 0);
    });

    test("sums what the rows come to", () {
      final allowances = [
        _allowance(id: "a1", quantityMilli: 168000, unitAmountMilliCents: 52900),
        _allowance(
          id: "a2",
          kind: OcptBudgetAllowanceKind.accommodation,
          quantityMilli: 13000,
          unitAmountMilliCents: 6000000,
        ),
      ];

      expect(ocptBudgetAllowancesTotalCents(allowances), 8887 + 78000);
    });

    test("no defrayal at all comes to nothing", () {
      expect(ocptBudgetAllowancesTotalCents(const []), 0);
    });
  });

  group("ocptBudgetAllowancesTotalByKind", () {
    test("groups by nature, a nature with no row getting no key", () {
      final allowances = [
        _allowance(id: "a1", quantityMilli: 100000, unitAmountMilliCents: 50000),
        _allowance(id: "a2", quantityMilli: 100000, unitAmountMilliCents: 50000),
        _allowance(
          id: "a3",
          kind: OcptBudgetAllowanceKind.meal,
          quantityMilli: 3000,
          unitAmountMilliCents: 1500000,
        ),
      ];

      final byKind = ocptBudgetAllowancesTotalByKind(allowances);

      expect(byKind[OcptBudgetAllowanceKind.travel], 10000);
      expect(byKind[OcptBudgetAllowanceKind.meal], 4500);
      // Nobody is defrayed for a stay, which is a different fact from being defrayed nothing —
      // and it is what keeps the provisioning from writing a line for a nature never used.
      expect(byKind.containsKey(OcptBudgetAllowanceKind.accommodation), isFalse);
      expect(byKind.containsKey(OcptBudgetAllowanceKind.other), isFalse);
    });
  });

  group("ocptBudgetAllowancesByPersonId", () {
    test("groups by person, keeping each person's own rows in order", () {
      final allowances = [
        _allowance(id: "a1", personId: "p1"),
        _allowance(id: "a2", personId: "p2"),
        _allowance(id: "a3", personId: "p1"),
      ];

      final byPerson = ocptBudgetAllowancesByPersonId(allowances);

      expect(byPerson["p1"]?.map((row) => row.id), ["a1", "a3"]);
      expect(byPerson["p2"]?.map((row) => row.id), ["a2"]);
    });

    test("a defrayal naming nobody lands under its own group, not among a person's", () {
      final allowances = [
        _allowance(id: "a1", personId: "p1"),
        _allowance(id: "a2", kind: OcptBudgetAllowanceKind.other),
      ];

      final byPerson = ocptBudgetAllowancesByPersonId(allowances);

      expect(byPerson[null]?.map((row) => row.id), ["a2"]);
      expect(byPerson["p1"]?.map((row) => row.id), ["a1"]);
    });
  });
}
