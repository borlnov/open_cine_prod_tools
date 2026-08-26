// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';

void main() {
  OcptBudgetCommitment buildCommitment({
    String id = "commitment-1",
    DateTime? dueDate,
    String label = "A commitment",
    String posteId = "poste-1",
    int amountCents = 0,
    bool isTaxInclusive = true,
    int? vatRateBasisPoints,
    OcptBudgetCommitmentStatus status = OcptBudgetCommitmentStatus.quoteAccepted,
    String sortKey = "V",
  }) => OcptBudgetCommitment(
    id: id,
    dueDate: dueDate,
    label: label,
    posteId: posteId,
    amount: OcptMoney(
      amountCents: amountCents,
      isTaxInclusive: isTaxInclusive,
      vatRateBasisPoints: vatRateBasisPoints,
    ),
    status: status,
    lineId: null,
    sortKey: sortKey,
  );

  /// Builds a debit entry naming [commitmentId], everything else neutral.
  OcptBudgetEntry buildEntry({
    required String id,
    String? commitmentId,
    int debitCents = 0,
  }) => OcptBudgetEntry(
    id: id,
    date: DateTime(2026),
    label: "An entry",
    posteId: null,
    debitCents: debitCents,
    creditCents: 0,
    isTaxInclusive: true,
    vatRateBasisPoints: null,
    voucherNumber: "J-001",
    sortKey: "V",
    resourceId: null,
    revenueId: null,
    shareId: null,
    commitmentId: commitmentId,
    personId: null,
  );

  group("ocptBudgetCommitmentCashCentsOf", () {
    test("a tax-inclusive commitment reads back to the cent with no rate anywhere", () {
      final commitment = buildCommitment(amountCents: 1250);

      expect(
        ocptBudgetCommitmentCashCentsOf(commitment, projectVatRateBasisPoints: null),
        1250,
      );
    });

    test("a commitment typed excluding tax at 20 % converts exactly", () {
      final commitment = buildCommitment(
        amountCents: 1000,
        isTaxInclusive: false,
        vatRateBasisPoints: 2000,
      );

      expect(
        ocptBudgetCommitmentCashCentsOf(commitment, projectVatRateBasisPoints: null),
        1200,
      );
    });

    test("a commitment typed excluding tax with no rate anywhere reads null", () {
      final commitment = buildCommitment(amountCents: 1000, isTaxInclusive: false);

      expect(
        ocptBudgetCommitmentCashCentsOf(commitment, projectVatRateBasisPoints: null),
        isNull,
      );
    });
  });

  group("ocptBudgetPaidByCommitmentId / ocptBudgetCommitmentPaidCentsOf", () {
    test("sums every debit naming a commitment, credits and other commitments left out", () {
      final commitment = buildCommitment(id: "c1", amountCents: 1000);
      final entries = [
        buildEntry(id: "e1", commitmentId: "c1", debitCents: 400),
        buildEntry(id: "e2", commitmentId: "c1", debitCents: 300),
        buildEntry(id: "e3", commitmentId: "other", debitCents: 999),
        buildEntry(id: "e4"),
      ];

      final paid = ocptBudgetCommitmentPaidCentsOf(commitment, entries, projectVatRateBasisPoints: null);

      expect(paid.amountCents, 700);
      expect(paid.coveredLineCount, 2);
      expect(paid.lineCount, 2);
    });

    test("a commitment no entry names has no key at all", () {
      final entries = [buildEntry(id: "e1", commitmentId: "other", debitCents: 100)];

      final byCommitment = ocptBudgetPaidByCommitmentId(entries, projectVatRateBasisPoints: null);

      expect(byCommitment.containsKey("c1"), isFalse);
    });
  });

  group("ocptBudgetCommitmentOutstandingCentsOf / ocptBudgetCommitmentIsSettledOf", () {
    test("a commitment with nothing paid against it owes its whole cash figure", () {
      final commitment = buildCommitment(id: "c1", amountCents: 1000);

      expect(
        ocptBudgetCommitmentOutstandingCentsOf(commitment, const [], projectVatRateBasisPoints: null),
        1000,
      );
      expect(
        ocptBudgetCommitmentIsSettledOf(commitment, const [], projectVatRateBasisPoints: null),
        isFalse,
      );
    });

    test("a commitment paid in two instalments totalling its own amount reads settled", () {
      final commitment = buildCommitment(id: "c1", amountCents: 1000);
      final entries = [
        buildEntry(id: "e1", commitmentId: "c1", debitCents: 400),
        buildEntry(id: "e2", commitmentId: "c1", debitCents: 600),
      ];

      expect(
        ocptBudgetCommitmentOutstandingCentsOf(commitment, entries, projectVatRateBasisPoints: null),
        0,
      );
      expect(
        ocptBudgetCommitmentIsSettledOf(commitment, entries, projectVatRateBasisPoints: null),
        isTrue,
      );
    });

    test("a partial payment still reads unsettled, its own outstanding figure the remainder", () {
      final commitment = buildCommitment(id: "c1", amountCents: 1000);
      final entries = [buildEntry(id: "e1", commitmentId: "c1", debitCents: 400)];

      expect(
        ocptBudgetCommitmentOutstandingCentsOf(commitment, entries, projectVatRateBasisPoints: null),
        600,
      );
      expect(
        ocptBudgetCommitmentIsSettledOf(commitment, entries, projectVatRateBasisPoints: null),
        isFalse,
      );
    });

    test("an overpayment reads settled, its own outstanding figure negative rather than clamped", () {
      final commitment = buildCommitment(id: "c1", amountCents: 1000);
      final entries = [buildEntry(id: "e1", commitmentId: "c1", debitCents: 1200)];

      expect(
        ocptBudgetCommitmentOutstandingCentsOf(commitment, entries, projectVatRateBasisPoints: null),
        -200,
      );
      expect(
        ocptBudgetCommitmentIsSettledOf(commitment, entries, projectVatRateBasisPoints: null),
        isTrue,
      );
    });

    test("an unreadable cash figure reads as unsettled, never as settled", () {
      final commitment = buildCommitment(id: "c1", amountCents: 1000, isTaxInclusive: false);
      final entries = [buildEntry(id: "e1", commitmentId: "c1", debitCents: 5000)];

      expect(
        ocptBudgetCommitmentOutstandingCentsOf(commitment, entries, projectVatRateBasisPoints: null),
        isNull,
      );
      expect(
        ocptBudgetCommitmentIsSettledOf(commitment, entries, projectVatRateBasisPoints: null),
        isFalse,
      );
    });
  });

  group("ocptBudgetCommittedCentsByPosteId", () {
    test("a settled commitment is excluded outright, both from the map and its coverage", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000),
        buildCommitment(id: "c2", amountCents: 500),
      ];
      final entries = [buildEntry(id: "e1", commitmentId: "c2", debitCents: 500)];

      final byPoste = ocptBudgetCommittedCentsByPosteId(
        commitments,
        entries: entries,
        projectVatRateBasisPoints: null,
      );

      expect(byPoste["poste-1"]!.amountCents, 1000);
      expect(byPoste["poste-1"]!.lineCount, 1);
      expect(byPoste["poste-1"]!.coveredLineCount, 1);
    });

    test("a poste whose only commitment has settled has no key at all", () {
      final commitments = [buildCommitment(id: "c1", amountCents: 500)];
      final entries = [buildEntry(id: "e1", commitmentId: "c1", debitCents: 500)];

      final byPoste = ocptBudgetCommittedCentsByPosteId(
        commitments,
        entries: entries,
        projectVatRateBasisPoints: null,
      );

      expect(byPoste.containsKey("poste-1"), isFalse);
    });

    test("an unreadable commitment is left out of both the amount and the coverage", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 1000),
        buildCommitment(id: "c2", amountCents: 500, isTaxInclusive: false),
      ];

      final byPoste = ocptBudgetCommittedCentsByPosteId(
        commitments,
        entries: const [],
        projectVatRateBasisPoints: null,
      );

      expect(byPoste["poste-1"]!.amountCents, 1000);
      expect(byPoste["poste-1"]!.coveredLineCount, 1);
      expect(byPoste["poste-1"]!.lineCount, 2);
      expect(byPoste["poste-1"]!.isComplete, isFalse);
    });
  });

  group("ocptBudgetProjectionOf", () {
    test("the balance falls instalment by instalment, in the order given", () {
      final commitments = [
        buildCommitment(id: "c1", dueDate: DateTime(2026, 2), amountCents: 3000),
        buildCommitment(id: "c2", dueDate: DateTime(2026, 3), amountCents: 4000),
      ];

      final projection = ocptBudgetProjectionOf(
        openingBalanceCents: 10000,
        commitments: commitments,
        entries: const [],
        projectVatRateBasisPoints: null,
      );

      expect(projection.steps.map((step) => step.balanceAfterCents), [7000, 3000]);
      expect(projection.finalBalanceCents, 3000);
      expect(projection.commitmentCount, 2);
      expect(projection.coveredCommitmentCount, 2);
    });

    test("a settled commitment is excluded from the projection outright", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 3000),
        buildCommitment(id: "c2", amountCents: 4000),
      ];
      final entries = [buildEntry(id: "entry-1", commitmentId: "c1", debitCents: 3000)];

      final projection = ocptBudgetProjectionOf(
        openingBalanceCents: 10000,
        commitments: commitments,
        entries: entries,
        projectVatRateBasisPoints: null,
      );

      expect(projection.steps, hasLength(1));
      expect(projection.steps.single.commitmentId, "c2");
      expect(projection.commitmentCount, 1);
      expect(projection.finalBalanceCents, 6000);
    });

    test("a partly paid commitment only takes its own outstanding out, not its full amount", () {
      final commitments = [buildCommitment(id: "c1", amountCents: 3000)];
      final entries = [buildEntry(id: "entry-1", commitmentId: "c1", debitCents: 1000)];

      final projection = ocptBudgetProjectionOf(
        openingBalanceCents: 10000,
        commitments: commitments,
        entries: entries,
        projectVatRateBasisPoints: null,
      );

      expect(projection.steps, hasLength(1));
      expect(projection.steps.single.amountCents, 2000);
      expect(projection.finalBalanceCents, 8000);
    });

    test("an unreadable commitment produces no step but still counts", () {
      final commitments = [
        buildCommitment(id: "c1", amountCents: 3000),
        buildCommitment(id: "c2", amountCents: 500, isTaxInclusive: false),
      ];

      final projection = ocptBudgetProjectionOf(
        openingBalanceCents: 10000,
        commitments: commitments,
        entries: const [],
        projectVatRateBasisPoints: null,
      );

      expect(projection.steps, hasLength(1));
      expect(projection.commitmentCount, 2);
      expect(projection.coveredCommitmentCount, 1);
    });

    test("an undated commitment still lands last and lowers the balance", () {
      final commitments = [
        buildCommitment(id: "c1", dueDate: DateTime(2026, 2), amountCents: 3000),
        // loadCommitments has already put the undated ones last; this function must not reorder them.
        buildCommitment(id: "c2", amountCents: 4000),
      ];

      final projection = ocptBudgetProjectionOf(
        openingBalanceCents: 10000,
        commitments: commitments,
        entries: const [],
        projectVatRateBasisPoints: null,
      );

      expect(projection.steps.last.commitmentId, "c2");
      expect(projection.steps.last.dueDate, isNull);
      expect(projection.finalBalanceCents, 3000);
    });

    test("the first negative step is reported, its own date null when unrecorded", () {
      final commitments = [
        buildCommitment(id: "c1", dueDate: DateTime(2026, 2), amountCents: 6000),
        buildCommitment(id: "c2", amountCents: 8000),
      ];

      final projection = ocptBudgetProjectionOf(
        openingBalanceCents: 10000,
        commitments: commitments,
        entries: const [],
        projectVatRateBasisPoints: null,
      );

      expect(projection.goesNegative, isTrue);
      expect(projection.firstNegativeStep!.commitmentId, "c2");
      expect(projection.firstNegativeStep!.dueDate, isNull);
      expect(projection.firstNegativeStep!.balanceAfterCents, -4000);
    });

    test("a projection that never goes negative answers null", () {
      final commitments = [buildCommitment(id: "c1", amountCents: 3000)];

      final projection = ocptBudgetProjectionOf(
        openingBalanceCents: 10000,
        commitments: commitments,
        entries: const [],
        projectVatRateBasisPoints: null,
      );

      expect(projection.goesNegative, isFalse);
      expect(projection.firstNegativeStep, isNull);
    });
  });
}
