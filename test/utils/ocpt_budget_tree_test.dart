// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_tree.dart';

void main() {
  OcptBudgetCommitment buildCommitment({
    String id = "commitment-1",
    String posteId = "poste-1",
    String? lineId = "line-1",
    int amountCents = 0,
    bool isTaxInclusive = true,
    int? vatRateBasisPoints,
    String? settledEntryId,
  }) => OcptBudgetCommitment(
    id: id,
    dueDate: null,
    label: "A commitment",
    posteId: posteId,
    amount: OcptMoney(
      amountCents: amountCents,
      isTaxInclusive: isTaxInclusive,
      vatRateBasisPoints: vatRateBasisPoints,
    ),
    status: OcptBudgetCommitmentStatus.quoteAccepted,
    settledEntryId: settledEntryId,
    lineId: lineId,
    sortKey: "a0",
  );

  OcptBudgetEntry buildEntry({
    String id = "entry-1",
    String? posteId = "poste-1",
    int debitCents = 0,
    int creditCents = 0,
    bool isTaxInclusive = true,
    int? vatRateBasisPoints,
  }) => OcptBudgetEntry(
    id: id,
    date: DateTime(2026),
    label: "An entry",
    posteId: posteId,
    debitCents: debitCents,
    creditCents: creditCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
    voucherNumber: "J-001",
    sortKey: "a0",
    resourceId: null,
    revenueId: null,
    shareId: null,
  );

  group("ocptBudgetLineCommittedTotalOf", () {
    test("sums every unsettled commitment's own tax-inclusive cash, row by row", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000),
        buildCommitment(id: "c2", amountCents: 500),
      ];

      final total = ocptBudgetLineCommittedTotalOf(commitments, projectVatRateBasisPoints: null);

      expect(total.amountCents, 1500);
      expect(total.coveredLineCount, 2);
      expect(total.lineCount, 2);
    });

    test("excludes a settled commitment outright — from the total and from the coverage counts", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000),
        buildCommitment(id: "c2", amountCents: 500, settledEntryId: "entry-1"),
      ];

      final total = ocptBudgetLineCommittedTotalOf(commitments, projectVatRateBasisPoints: null);

      expect(total.amountCents, 1000);
      expect(total.coveredLineCount, 1);
      expect(total.lineCount, 1);
    });

    test("a line with no commitment at all answers a zero, fully covered total", () {
      final total = ocptBudgetLineCommittedTotalOf(const [], projectVatRateBasisPoints: null);

      expect(total.amountCents, 0);
      expect(total.coveredLineCount, 0);
      expect(total.lineCount, 0);
    });

    test("an unsettled commitment with no known rate leaves the total covered-but-incomplete "
        "rather than silently wrong", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000, isTaxInclusive: false),
      ];

      final total = ocptBudgetLineCommittedTotalOf(commitments, projectVatRateBasisPoints: null);

      expect(total.amountCents, 0);
      expect(total.coveredLineCount, 0);
      expect(total.lineCount, 1);
      expect(total.isComplete, isFalse);
    });

    test("reads tax-inclusive even when a commitment is typed excluding tax, given the "
        "project's own rate", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000, isTaxInclusive: false, vatRateBasisPoints: 2000),
      ];

      final total = ocptBudgetLineCommittedTotalOf(commitments, projectVatRateBasisPoints: null);

      expect(total.amountCents, 1200);
      expect(total.isComplete, isTrue);
    });
  });

  group("ocptBudgetLinePaidTotalOf", () {
    test("sums the debit of the entry settling each settled commitment, row by row", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000, settledEntryId: "entry-1"),
        buildCommitment(id: "c2", amountCents: 500, settledEntryId: "entry-2"),
      ];
      final entries = [
        buildEntry(debitCents: 900),
        buildEntry(id: "entry-2", debitCents: 400),
      ];

      final total = ocptBudgetLinePaidTotalOf(
        commitments,
        entries: entries,
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 1300);
      expect(total.coveredLineCount, 2);
      expect(total.lineCount, 2);
    });

    test("excludes an unsettled commitment outright — it has no entry to read at all", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000),
        buildCommitment(id: "c2", amountCents: 500, settledEntryId: "entry-1"),
      ];
      final entries = [buildEntry(debitCents: 500)];

      final total = ocptBudgetLinePaidTotalOf(
        commitments,
        entries: entries,
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 500);
      expect(total.coveredLineCount, 1);
      expect(total.lineCount, 1);
    });

    test("reads the entry's own debit, not the commitment's own amount, once they disagree", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000, settledEntryId: "entry-1"),
      ];
      final entries = [buildEntry(debitCents: 750)];

      final total = ocptBudgetLinePaidTotalOf(
        commitments,
        entries: entries,
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 750);
    });

    test("a settled commitment naming an entry absent from the given list leaves the total "
        "covered-but-incomplete rather than silently wrong", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000, settledEntryId: "entry-missing"),
      ];

      final total = ocptBudgetLinePaidTotalOf(
        commitments,
        entries: const [],
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 0);
      expect(total.coveredLineCount, 0);
      expect(total.lineCount, 1);
      expect(total.isComplete, isFalse);
    });

    test("a line with no commitment at all answers a zero, fully covered total", () {
      final total = ocptBudgetLinePaidTotalOf(
        const [],
        entries: const [],
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 0);
      expect(total.coveredLineCount, 0);
      expect(total.lineCount, 0);
    });

    test("reads the settling entry's own debit tax-inclusive, given the project's own rate", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000, settledEntryId: "entry-1"),
      ];
      final entries = [
        buildEntry(debitCents: 1000, isTaxInclusive: false, vatRateBasisPoints: 2000),
      ];

      final total = ocptBudgetLinePaidTotalOf(
        commitments,
        entries: entries,
        projectVatRateBasisPoints: null,
      );

      expect(total.amountCents, 1200);
      expect(total.isComplete, isTrue);
    });
  });
}
