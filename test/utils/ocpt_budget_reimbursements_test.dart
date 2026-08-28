// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_reimbursements.dart';

void main() {
  /// Builds a defrayal owed to [personId], priced at [quantityMilli] thousandths of a unit at
  /// [unitAmountMilliCents] thousandths of a cent each — 1000/100000 (one unit at 1.00 €) unless a
  /// test overrides either.
  OcptBudgetAllowance buildAllowance({
    String id = "allowance-1",
    String? personId = "person-1",
    int quantityMilli = 1000,
    int unitAmountMilliCents = 100000,
  }) => OcptBudgetAllowance(
    id: id,
    personId: personId,
    kind: OcptBudgetAllowanceKind.other,
    label: "A defrayal",
    date: null,
    endDate: null,
    quantityMilli: quantityMilli,
    unitAmountMilliCents: unitAmountMilliCents,
    notes: "",
    sortKey: "a0",
  );

  /// Builds a debit entry reimbursing [personId], everything else neutral.
  OcptBudgetEntry buildEntry({
    String id = "entry-1",
    String? personId,
    int debitCents = 0,
    bool isTaxInclusive = true,
  }) => OcptBudgetEntry(
    id: id,
    date: DateTime(2026),
    label: "An entry",
    posteId: null,
    debitCents: debitCents,
    creditCents: 0,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: null,
    voucherNumber: "J-001",
    sortKey: "a0",
    resourceId: null,
    revenueId: null,
    shareId: null,
    commitmentId: null,
    personId: personId,
  );

  group("ocptBudgetPersonAdvancedCents", () {
    test("sums every defrayal naming the person, others left out", () {
      final allowances = [
        buildAllowance(id: "a1"),
        buildAllowance(id: "a2", quantityMilli: 2000, unitAmountMilliCents: 50000),
        buildAllowance(id: "a3", personId: "person-2", unitAmountMilliCents: 999000),
        buildAllowance(id: "a4", personId: null, unitAmountMilliCents: 999000),
      ];

      // a1: 1.00 € × 1 = 100 cents. a2: 0.50 € × 2 = 100 cents.
      expect(ocptBudgetPersonAdvancedCents("person-1", allowances), 200);
    });

    test("a person named by no defrayal has advanced nothing", () {
      expect(ocptBudgetPersonAdvancedCents("person-1", const []), 0);
    });
  });

  group("ocptBudgetReimbursedByPersonId / ocptBudgetPersonReimbursedCentsOf", () {
    test("sums every debit naming a person, credits and other people left out", () {
      final entries = [
        buildEntry(id: "e1", personId: "person-1", debitCents: 400),
        buildEntry(id: "e2", personId: "person-1", debitCents: 300),
        buildEntry(id: "e3", personId: "person-2", debitCents: 999),
        buildEntry(id: "e4"),
      ];

      final reimbursed = ocptBudgetPersonReimbursedCentsOf(
        "person-1",
        entries,
        projectVatRateBasisPoints: null,
      );

      expect(reimbursed.amountCents, 700);
      expect(reimbursed.coveredLineCount, 2);
      expect(reimbursed.lineCount, 2);
    });

    test("a person no entry names has no key at all", () {
      final entries = [buildEntry(id: "e1", personId: "person-2", debitCents: 100)];

      final byPerson = ocptBudgetReimbursedByPersonId(entries, projectVatRateBasisPoints: null);

      expect(byPerson.containsKey("person-1"), isFalse);
    });

    test("an entry whose rate cannot be read leaves the reading covered-but-incomplete", () {
      final entries = [
        buildEntry(id: "e1", personId: "person-1", debitCents: 400),
        buildEntry(id: "e2", personId: "person-1", debitCents: 300),
      ];
      // e2 typed excluding tax with no rate anywhere to gross it back up with.
      final unreadable = [
        entries[0],
        buildEntry(id: "e2", personId: "person-1", debitCents: 300, isTaxInclusive: false),
      ];

      final reimbursed = ocptBudgetPersonReimbursedCentsOf(
        "person-1",
        unreadable,
        projectVatRateBasisPoints: null,
      );

      expect(reimbursed.amountCents, 400);
      expect(reimbursed.coveredLineCount, 1);
      expect(reimbursed.lineCount, 2);
      expect(reimbursed.isComplete, isFalse);
    });
  });

  group("ocptBudgetPersonOutstandingCents", () {
    test("what is left once a person has advanced more than they were reimbursed", () {
      expect(ocptBudgetPersonOutstandingCents(advancedCents: 1000, reimbursedCents: 400), 600);
    });

    test("reads zero once advanced and reimbursed agree exactly", () {
      expect(ocptBudgetPersonOutstandingCents(advancedCents: 1000, reimbursedCents: 1000), 0);
    });

    test("reads negative, not clamped, once reimbursed overshoots what was advanced", () {
      expect(ocptBudgetPersonOutstandingCents(advancedCents: 1000, reimbursedCents: 1200), -200);
    });
  });
}
