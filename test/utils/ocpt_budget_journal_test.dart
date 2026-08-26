// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';

void main() {
  OcptBudgetEntry buildEntry({
    String id = "entry-1",
    DateTime? date,
    String label = "An entry",
    String? posteId,
    int debitCents = 0,
    int creditCents = 0,
    bool isTaxInclusive = true,
    int? vatRateBasisPoints,
    String voucherNumber = "J-001",
    String sortKey = "V",
  }) => OcptBudgetEntry(
    id: id,
    date: date ?? DateTime(2026),
    label: label,
    posteId: posteId,
    debitCents: debitCents,
    creditCents: creditCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
    voucherNumber: voucherNumber,
    sortKey: sortKey,
    resourceId: null,
    revenueId: null,
    shareId: null,
    commitmentId: null,
    personId: null,
  );

  group("ocptBudgetEntryDebitCentsOf / ocptBudgetEntryCreditCentsOf", () {
    test("a tax-inclusive entry reads back to the cent with no rate anywhere", () {
      final entry = buildEntry(debitCents: 1250, creditCents: 300);

      expect(
        ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: null),
        1250,
      );
      expect(
        ocptBudgetEntryCreditCentsOf(entry, projectVatRateBasisPoints: null),
        300,
      );
    });

    test("an entry typed excluding tax at 20 % converts exactly", () {
      final entry = buildEntry(
        debitCents: 1000,
        isTaxInclusive: false,
        vatRateBasisPoints: 2000,
      );

      expect(
        ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: null),
        1200,
      );
    });

    test("an entry typed excluding tax with no rate anywhere reads null on both sides", () {
      final entry = buildEntry(debitCents: 1000, creditCents: 500, isTaxInclusive: false);

      expect(ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: null), isNull);
      expect(ocptBudgetEntryCreditCentsOf(entry, projectVatRateBasisPoints: null), isNull);
    });

    test("an explicit 0 % counts as covered, both bases equal", () {
      final entry = buildEntry(debitCents: 1000, isTaxInclusive: false, vatRateBasisPoints: 0);

      expect(ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: null), 1000);
    });

    test("a line's own override departs from the project's rate", () {
      final entry = buildEntry(
        debitCents: 1000,
        isTaxInclusive: false,
        vatRateBasisPoints: 550,
      );

      expect(
        ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: 2000),
        1055,
      );
    });
  });

  group("ocptBudgetCashTotalsOf", () {
    test("sums covered entries row by row and reads the balance", () {
      final entries = [
        buildEntry(id: "e1", debitCents: 1000),
        buildEntry(id: "e2", creditCents: 400),
      ];

      final totals = ocptBudgetCashTotalsOf(entries, projectVatRateBasisPoints: null);

      expect(totals.debitCents, 1000);
      expect(totals.creditCents, 400);
      expect(totals.balanceCents, -600);
      expect(totals.coveredEntryCount, 2);
      expect(totals.entryCount, 2);
      expect(totals.isComplete, isTrue);
    });

    test("a mix of bases and rates totals correctly", () {
      final entries = [
        // 1055 TTC at 5.5 % is 1000 HT — already tax-inclusive, no rate needed.
        buildEntry(id: "e1", debitCents: 1055),
        // 1000 HT at 20 % (the project's own rate) grosses up to 1200.
        buildEntry(id: "e2", creditCents: 1000, isTaxInclusive: false),
      ];

      final totals = ocptBudgetCashTotalsOf(entries, projectVatRateBasisPoints: 2000);

      expect(totals.debitCents, 1055);
      expect(totals.creditCents, 1200);
      expect(totals.isComplete, isTrue);
    });

    test("an unreadable entry contributes to neither figure nor coverage", () {
      final entries = [
        buildEntry(id: "e1", debitCents: 1000),
        buildEntry(id: "e2", creditCents: 500, isTaxInclusive: false),
      ];

      final totals = ocptBudgetCashTotalsOf(entries, projectVatRateBasisPoints: null);

      expect(totals.debitCents, 1000);
      expect(totals.creditCents, 0);
      expect(totals.coveredEntryCount, 1);
      expect(totals.entryCount, 2);
      expect(totals.isComplete, isFalse);
    });
  });

  group("ocptBudgetJournalRowsOf", () {
    test("the running balance steps in the order the entries are given", () {
      final entries = [
        buildEntry(id: "e1", creditCents: 1000),
        buildEntry(id: "e2", debitCents: 300),
        buildEntry(id: "e3", debitCents: 200),
      ];

      final rows = ocptBudgetJournalRowsOf(entries, projectVatRateBasisPoints: null);

      expect(rows.map((row) => row.balanceAfterCents), [1000, 700, 500]);
    });

    test("an unreadable row leaves the balance where it was, and carries a null of its own", () {
      final entries = [
        buildEntry(id: "e1", creditCents: 1000),
        // Unreadable: excluding tax, no rate anywhere.
        buildEntry(id: "e2", debitCents: 300, isTaxInclusive: false),
        buildEntry(id: "e3", debitCents: 200),
      ];

      final rows = ocptBudgetJournalRowsOf(entries, projectVatRateBasisPoints: null);

      expect(rows[0].balanceAfterCents, 1000);
      expect(rows[1].debitCents, isNull);
      expect(rows[1].creditCents, isNull);
      expect(rows[1].balanceAfterCents, isNull);
      // The next row still counts from the last known balance (1000), not from a poisoned one.
      expect(rows[2].balanceAfterCents, 800);
    });
  });

  group("ocptBudgetPaidCentsByPosteId", () {
    test("a refund credited against a poste reduces what that poste has cost", () {
      final entries = [
        buildEntry(id: "e1", posteId: "poste-1", debitCents: 1000),
        buildEntry(id: "e2", posteId: "poste-1", creditCents: 200),
      ];

      final byPoste = ocptBudgetPaidCentsByPosteId(entries, projectVatRateBasisPoints: null);

      expect(byPoste["poste-1"]!.amountCents, 800);
      expect(byPoste["poste-1"]!.isComplete, isTrue);
    });

    test("an entry naming no poste is not in the map at all", () {
      final entries = [buildEntry(id: "e1", creditCents: 5000)];

      final byPoste = ocptBudgetPaidCentsByPosteId(entries, projectVatRateBasisPoints: null);

      expect(byPoste, isEmpty);
    });

    test("a poste with no entry at all has no key in the map", () {
      final entries = [buildEntry(id: "e1", posteId: "poste-1", debitCents: 1000)];

      final byPoste = ocptBudgetPaidCentsByPosteId(entries, projectVatRateBasisPoints: null);

      expect(byPoste.containsKey("poste-1"), isTrue);
      expect(byPoste.containsKey("poste-2"), isFalse);
    });

    test("an unreadable entry is left out of both the amount and the coverage", () {
      final entries = [
        buildEntry(id: "e1", posteId: "poste-1", debitCents: 1000),
        buildEntry(id: "e2", posteId: "poste-1", debitCents: 500, isTaxInclusive: false),
      ];

      final byPoste = ocptBudgetPaidCentsByPosteId(entries, projectVatRateBasisPoints: null);

      expect(byPoste["poste-1"]!.amountCents, 1000);
      expect(byPoste["poste-1"]!.coveredLineCount, 1);
      expect(byPoste["poste-1"]!.lineCount, 2);
      expect(byPoste["poste-1"]!.isComplete, isFalse);
    });
  });

  group("ocptBudgetOffQuotePaidTotalOf", () {
    test("a debit naming no poste counts", () {
      final entries = [buildEntry(id: "e1", debitCents: 1000)];

      final total = ocptBudgetOffQuotePaidTotalOf(entries, projectVatRateBasisPoints: null);

      expect(total.amountCents, 1000);
      expect(total.coveredLineCount, 1);
      expect(total.lineCount, 1);
      expect(total.isComplete, isTrue);
    });

    test("a debit naming a poste does not count", () {
      final entries = [buildEntry(id: "e1", posteId: "poste-1", debitCents: 1000)];

      final total = ocptBudgetOffQuotePaidTotalOf(entries, projectVatRateBasisPoints: null);

      expect(total.amountCents, 0);
      expect(total.coveredLineCount, 0);
      expect(total.lineCount, 0);
      expect(total.isComplete, isTrue);
    });

    test("a credit naming no poste does not count — it is money coming in, not off-quote spending", () {
      final entries = [buildEntry(id: "e1", creditCents: 5000)];

      final total = ocptBudgetOffQuotePaidTotalOf(entries, projectVatRateBasisPoints: null);

      expect(total.amountCents, 0);
      expect(total.coveredLineCount, 0);
      expect(total.lineCount, 0);
      expect(total.isComplete, isTrue);
    });

    test("an unreadable off-quote debit leaves the total incomplete rather than wrong", () {
      final entries = [
        buildEntry(id: "e1", debitCents: 1000),
        buildEntry(id: "e2", debitCents: 500, isTaxInclusive: false),
      ];

      final total = ocptBudgetOffQuotePaidTotalOf(entries, projectVatRateBasisPoints: null);

      expect(total.amountCents, 1000);
      expect(total.coveredLineCount, 1);
      expect(total.lineCount, 2);
      expect(total.isComplete, isFalse);
    });

    test("no such entry at all gives a complete zero", () {
      final entries = [
        buildEntry(id: "e1", posteId: "poste-1", debitCents: 1000),
        buildEntry(id: "e2", creditCents: 5000),
      ];

      final total = ocptBudgetOffQuotePaidTotalOf(entries, projectVatRateBasisPoints: null);

      expect(total.amountCents, 0);
      expect(total.coveredLineCount, 0);
      expect(total.lineCount, 0);
      expect(total.isComplete, isTrue);
    });
  });
}
