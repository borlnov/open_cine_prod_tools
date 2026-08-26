// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

void main() {
  OcptBudgetEntry buildEntry({
    String id = "entry-1",
    DateTime? date,
    String label = "An entry",
    String? posteId,
    String? resourceId,
    String? revenueId,
    String? shareId,
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
    resourceId: resourceId,
    revenueId: revenueId,
    shareId: shareId,
    commitmentId: null,
    personId: null,
  );

  OcptBudgetRevenue buildRevenue({
    String id = "revenue-1",
    DateTime? date,
    String label = "A taking",
    int amountCents = 0,
    OcptBudgetRevenueStatus status = OcptBudgetRevenueStatus.expected,
    String notes = "",
    String sortKey = "V",
  }) => OcptBudgetRevenue(
    id: id,
    date: date ?? DateTime(2026),
    label: label,
    amountCents: amountCents,
    status: status,
    notes: notes,
    sortKey: sortKey,
  );

  OcptBudgetResource buildResource({
    String id = "resource-1",
    OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.cash,
    String? personId,
    String label = "A contribution",
    int amountCents = 0,
    OcptBudgetResourceStatus status = OcptBudgetResourceStatus.confirmed,
    bool isReimbursable = false,
    String notes = "",
    String sortKey = "V",
  }) => OcptBudgetResource(
    id: id,
    groupKind: groupKind,
    personId: personId,
    label: label,
    amountCents: amountCents,
    status: status,
    isReimbursable: isReimbursable,
    notes: notes,
    sortKey: sortKey,
  );

  OcptBudgetShare buildShare({
    String id = "share-1",
    String? personId,
    String label = "A participant",
    int sharePermille = 0,
    int reinvestPermille = 0,
    String notes = "",
    String sortKey = "V",
  }) => OcptBudgetShare(
    id: id,
    personId: personId,
    label: label,
    sharePermille: sharePermille,
    reinvestPermille: reinvestPermille,
    notes: notes,
    sortKey: sortKey,
  );

  OcptBudgetSharingPot potOf({
    int receivedCents = 0,
    int reimbursableCents = 0,
    int repaidCents = 0,
  }) => ocptBudgetSharingPotOf(
    received: OcptBudgetCoveredTotal(
      amountCents: receivedCents,
      coveredLineCount: 1,
      lineCount: 1,
    ),
    reimbursableCents: reimbursableCents,
    repaid: OcptBudgetCoveredTotal(amountCents: repaidCents, coveredLineCount: 1, lineCount: 1),
  );

  group("ocptBudgetReceivedByRevenueId", () {
    test("sums the credits naming each taking, and keys nothing else", () {
      final received = ocptBudgetReceivedByRevenueId([
        buildEntry(id: "e1", revenueId: "r1", creditCents: 300000),
        buildEntry(id: "e2", revenueId: "r1", creditCents: 100000),
        buildEntry(id: "e3", revenueId: "r2", creditCents: 220000),
        buildEntry(id: "e4", creditCents: 999999),
      ], projectVatRateBasisPoints: null);

      expect(received.keys, unorderedEquals(["r1", "r2"]));
      expect(received["r1"]!.amountCents, 400000);
      expect(received["r2"]!.amountCents, 220000);
    });

    test("a taking nobody has been paid for gets no key at all", () {
      final received = ocptBudgetReceivedByRevenueId([
        buildEntry(revenueId: "r1", creditCents: 100),
      ], projectVatRateBasisPoints: null);

      expect(received.containsKey("r2"), isFalse);
    });

    test("a debit naming a taking is not subtracted", () {
      final received = ocptBudgetReceivedByRevenueId([
        buildEntry(id: "e1", revenueId: "r1", creditCents: 300000),
        buildEntry(id: "e2", revenueId: "r1", debitCents: 50000),
      ], projectVatRateBasisPoints: null);

      // The refund is a movement of its own; it does not claim the money never came in.
      expect(received["r1"]!.amountCents, 300000);
    });

    test("an entry with no rate to gross it up is uncovered, never zero", () {
      final received = ocptBudgetReceivedByRevenueId([
        buildEntry(id: "e1", revenueId: "r1", creditCents: 120000),
        buildEntry(id: "e2", revenueId: "r1", creditCents: 60000, isTaxInclusive: false),
      ], projectVatRateBasisPoints: null);

      expect(received["r1"]!.amountCents, 120000);
      expect(received["r1"]!.coveredLineCount, 1);
      expect(received["r1"]!.lineCount, 2);
      expect(received["r1"]!.isComplete, isFalse);
    });
  });

  group("ocptBudgetPaidByShareId", () {
    test("sums the debits naming each participant", () {
      final paid = ocptBudgetPaidByShareId([
        buildEntry(id: "e1", shareId: "s1", debitCents: 40000),
        buildEntry(id: "e2", shareId: "s1", debitCents: 10000),
        buildEntry(id: "e3", shareId: "s2", debitCents: 25000),
      ], projectVatRateBasisPoints: null);

      expect(paid["s1"]!.amountCents, 50000);
      expect(paid["s2"]!.amountCents, 25000);
    });

    test("a credit naming a participant is not subtracted", () {
      final paid = ocptBudgetPaidByShareId([
        buildEntry(id: "e1", shareId: "s1", debitCents: 40000),
        buildEntry(id: "e2", shareId: "s1", creditCents: 40000),
      ], projectVatRateBasisPoints: null);

      expect(paid["s1"]!.amountCents, 40000);
    });
  });

  group("ocptBudgetRevenuesReceivedTotalOf", () {
    test("sums only the takings the journal actually names", () {
      final revenues = [
        buildRevenue(id: "r1", amountCents: 300000),
        buildRevenue(id: "r2", amountCents: 500000),
      ];

      final total = ocptBudgetRevenuesReceivedTotalOf(
        revenues: revenues,
        receivedByRevenueId: const {
          "r1": OcptBudgetCoveredTotal(amountCents: 300000, coveredLineCount: 1, lineCount: 1),
        },
      );

      // The 5,000 € still only announced is not money the film has earned.
      expect(total.amountCents, 300000);
      expect(total.isComplete, isTrue);
    });

    test("a taking with no entry claims no uncovered line either", () {
      final total = ocptBudgetRevenuesReceivedTotalOf(
        revenues: [buildRevenue(id: "r1"), buildRevenue(id: "r2")],
        receivedByRevenueId: const {},
      );

      expect(total.lineCount, 0);
      expect(total.isComplete, isTrue);
    });

    test("an unreadable entry is carried through as an uncovered line", () {
      final total = ocptBudgetRevenuesReceivedTotalOf(
        revenues: [buildRevenue(id: "r1")],
        receivedByRevenueId: const {
          "r1": OcptBudgetCoveredTotal(amountCents: 120000, coveredLineCount: 1, lineCount: 2),
        },
      );

      expect(total.amountCents, 120000);
      expect(total.isComplete, isFalse);
    });
  });

  group("ocptBudgetReimbursableTotalCents", () {
    test("counts the reimbursable contributions and only those", () {
      final total = ocptBudgetReimbursableTotalCents([
        buildResource(id: "c1", amountCents: 350000, isReimbursable: true),
        buildResource(id: "c2", amountCents: 200000),
        buildResource(id: "c3", amountCents: 50000, isReimbursable: true),
      ]);

      expect(total, 400000);
    });

    test("an in-kind contribution counts when the user marked it reimbursable", () {
      final total = ocptBudgetReimbursableTotalCents([
        buildResource(
          amountCents: 90000,
          groupKind: OcptBudgetResourceGroupKind.inKind,
          isReimbursable: true,
        ),
      ]);

      // Nothing here branches on the group kind — it is the user who says so, not the code.
      expect(total, 90000);
    });
  });

  group("ocptBudgetRepaidContributionsTotalOf", () {
    test("counts the debits naming a reimbursable contribution", () {
      final resources = [
        buildResource(id: "c1", amountCents: 350000, isReimbursable: true),
        buildResource(id: "c2", amountCents: 200000),
      ];

      final repaid = ocptBudgetRepaidContributionsTotalOf(
        [
          buildEntry(id: "e1", resourceId: "c1", debitCents: 150000),
          buildEntry(id: "e2", resourceId: "c2", debitCents: 20000),
          buildEntry(id: "e3", resourceId: "c1", creditCents: 350000),
        ],
        resources: resources,
        projectVatRateBasisPoints: null,
      );

      // Only the debit against the reimbursable contribution counts towards the amount: the debit
      // against the subsidy is a correction, not a repayment. The credit against the same
      // contribution is still one of the entries the total was asked about, so it is one of its
      // lines — reading zero out of it, exactly as the journal's own per-poste paid total does.
      expect(repaid.amountCents, 150000);
      expect(repaid.lineCount, 2);
      expect(repaid.isComplete, isTrue);
    });
  });

  group("ocptBudgetRepaymentLinesOf", () {
    test("several resources naming one person group into one line", () {
      final resources = [
        buildResource(id: "c1", personId: "p1", amountCents: 10000, isReimbursable: true),
        buildResource(id: "c2", personId: "p1", amountCents: 20000, isReimbursable: true),
      ];

      final lines = ocptBudgetRepaymentLinesOf(resources, const [], projectVatRateBasisPoints: null);

      expect(lines, hasLength(1));
      expect(lines.single.personId, "p1");
      expect(lines.single.contributedCents, 30000);
    });

    test("a resource naming nobody stands alone", () {
      final resources = [
        buildResource(id: "c1", label: "Région Île-de-France", amountCents: 10000, isReimbursable: true),
        buildResource(id: "c2", personId: "p1", amountCents: 20000, isReimbursable: true),
      ];

      final lines = ocptBudgetRepaymentLinesOf(resources, const [], projectVatRateBasisPoints: null);

      expect(lines, hasLength(2));
      final unnamed = lines.firstWhere((line) => line.personId == null);
      expect(unnamed.label, "Région Île-de-France");
      expect(unnamed.contributedCents, 10000);
    });

    test("two resources with the same label and no person group together", () {
      final resources = [
        buildResource(id: "c1", label: "Espèces", amountCents: 5000, isReimbursable: true),
        buildResource(id: "c2", label: "Espèces", amountCents: 7000, isReimbursable: true),
      ];

      final lines = ocptBudgetRepaymentLinesOf(resources, const [], projectVatRateBasisPoints: null);

      expect(lines, hasLength(1));
      expect(lines.single.label, "Espèces");
      expect(lines.single.contributedCents, 12000);
    });

    test("the repayments follow their own resource into the right line", () {
      final resources = [
        buildResource(id: "c1", personId: "p1", amountCents: 30000, isReimbursable: true),
        buildResource(id: "c2", personId: "p2", amountCents: 30000, isReimbursable: true),
      ];
      final entries = [
        buildEntry(id: "e1", resourceId: "c1", debitCents: 10000),
        buildEntry(id: "e2", resourceId: "c2", debitCents: 5000),
      ];

      final lines = ocptBudgetRepaymentLinesOf(resources, entries, projectVatRateBasisPoints: null);

      final line1 = lines.firstWhere((line) => line.personId == "p1");
      final line2 = lines.firstWhere((line) => line.personId == "p2");
      expect(line1.repaid.amountCents, 10000);
      expect(line1.outstandingCents, 20000);
      expect(line2.repaid.amountCents, 5000);
      expect(line2.outstandingCents, 25000);
    });

    test("a contribution nobody has to give back still earns its line", () {
      // This used to answer an empty list, so a production that had marked nothing reimbursable —
      // the ordinary state of a project the day it is created — could not tell from this card
      // that anybody had contributed at all.
      final resources = [
        buildResource(id: "c1", personId: "p1", amountCents: 30000),
      ];

      final lines = ocptBudgetRepaymentLinesOf(resources, const [], projectVatRateBasisPoints: null);

      expect(lines, hasLength(1));
      expect(lines.single.contributedCents, 30000);
      // Nothing is owed against a gift, however much it was worth.
      expect(lines.single.reimbursableCents, 0);
      expect(lines.single.outstandingCents, 0);
    });

    test("what was put in and what has to come back are two figures", () {
      final resources = [
        buildResource(id: "c1", personId: "p1", amountCents: 30000, isReimbursable: true),
        buildResource(id: "c2", personId: "p1", amountCents: 20000),
      ];

      final lines = ocptBudgetRepaymentLinesOf(resources, const [], projectVatRateBasisPoints: null);

      expect(lines.single.contributedCents, 50000);
      expect(lines.single.reimbursableCents, 30000);
      expect(lines.single.outstandingCents, 30000);
    });
  });

  group("OcptBudgetSharingPot", () {
    test("the whole reimbursable total comes off the top, not merely what is outstanding", () {
      final pot = potOf(receivedCents: 400000, reimbursableCents: 350000);

      expect(pot.shareableCents, 50000);
      expect(pot.outstandingRepaymentCents, 350000);
      expect(pot.hasSomethingToShare, isTrue);
    });

    test("delaying a repayment does not enlarge the pot", () {
      final repaid = potOf(receivedCents: 400000, reimbursableCents: 350000, repaidCents: 350000);
      final unpaid = potOf(receivedCents: 400000, reimbursableCents: 350000);

      expect(repaid.shareableCents, unpaid.shareableCents);
      expect(repaid.outstandingRepaymentCents, 0);
    });

    test("takings short of the contributions leave nothing to share", () {
      final pot = potOf(receivedCents: 100000, reimbursableCents: 350000);

      expect(pot.shareableCents, 0);
      expect(pot.hasSomethingToShare, isFalse);
    });

    test("repaying more than was owed finishes the repayment rather than owing the difference", () {
      final pot = potOf(receivedCents: 400000, reimbursableCents: 350000, repaidCents: 400000);

      expect(pot.outstandingRepaymentCents, 0);
    });
  });

  group("ocptBudgetShareSplitsOf", () {
    test("each participant is due their per mille of the pot, and reinvests out of their own due", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [
          buildShare(id: "s1", label: "Director", sharePermille: 400, reinvestPermille: 1000),
          buildShare(id: "s2", label: "Production", sharePermille: 250),
          buildShare(id: "s3", label: "Editor", sharePermille: 100, reinvestPermille: 500),
        ],
        pot: potOf(receivedCents: 620000, reimbursableCents: 350000),
        paidByShareId: const {},
      );

      // 6,200 € of takings less 3,500 € of reimbursable contributions leaves 2,700 € to share.
      expect(splits[0].dueCents, 108000);
      expect(splits[0].reinvestedCents, 108000);
      expect(splits[0].takeHomeCents, 0);
      expect(splits[1].dueCents, 67500);
      expect(splits[1].reinvestedCents, 0);
      expect(splits[2].dueCents, 27000);
      expect(splits[2].reinvestedCents, 13500);
    });

    test("keeps the order it was handed, and never reorders by share", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [
          buildShare(id: "s1", sharePermille: 100),
          buildShare(id: "s2", sharePermille: 900),
        ],
        pot: potOf(receivedCents: 100000),
        paidByShareId: const {},
      );

      expect([for (final split in splits) split.share.id], ["s1", "s2"]);
    });

    test("no remainder is redistributed onto the last participant", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [
          buildShare(id: "s1", sharePermille: 333),
          buildShare(id: "s2", sharePermille: 333),
          buildShare(id: "s3", sharePermille: 334),
        ],
        pot: potOf(receivedCents: 1000),
        paidByShareId: const {},
      );

      expect([for (final split in splits) split.dueCents], [333, 333, 334]);
      expect(ocptBudgetDueTotalCents(splits), 1000);
    });

    test("a pot that does not divide leaves the gap visible rather than absorbing it", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [
          buildShare(id: "s1", sharePermille: 333),
          buildShare(id: "s2", sharePermille: 333),
          buildShare(id: "s3", sharePermille: 333),
        ],
        pot: potOf(receivedCents: 1000),
        paidByShareId: const {},
      );

      // The shares themselves sum to 999 ‰, and the app says so rather than rounding it away.
      expect(ocptBudgetDueTotalCents(splits), 999);
      expect(ocptBudgetSharesPermilleTotal([
        buildShare(id: "s1", sharePermille: 333),
        buildShare(id: "s2", sharePermille: 333),
        buildShare(id: "s3", sharePermille: 333),
      ]), 999);
    });

    test("a participant nobody has paid carries a zero total covering nothing", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [buildShare(id: "s1", sharePermille: 500)],
        pot: potOf(receivedCents: 100000),
        paidByShareId: const {},
      );

      expect(splits.single.paid.amountCents, 0);
      expect(splits.single.paid.lineCount, 0);
      expect(splits.single.paid.isComplete, isTrue);
    });

    test("what has been paid comes straight off the journal's own map", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [buildShare(id: "s1", sharePermille: 500)],
        pot: potOf(receivedCents: 100000),
        paidByShareId: const {
          "s1": OcptBudgetCoveredTotal(amountCents: 30000, coveredLineCount: 1, lineCount: 1),
        },
      );

      expect(splits.single.dueCents, 50000);
      expect(splits.single.paid.amountCents, 30000);
    });

    test("nothing to share means every due is honestly zero", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [buildShare(id: "s1", sharePermille: 400)],
        pot: potOf(receivedCents: 100000, reimbursableCents: 350000),
        paidByShareId: const {},
      );

      expect(splits.single.dueCents, 0);
      expect(splits.single.reinvestedCents, 0);
    });

    test("rounds a half cent away from zero", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [buildShare(id: "s1", sharePermille: 5)],
        pot: potOf(receivedCents: 301),
        paidByShareId: const {},
      );

      // 301 × 5 ÷ 1000 is 1.505 cents.
      expect(splits.single.dueCents, 2);
    });
  });

  group("the sharing table's own totals", () {
    test("the reinvested total is summed row by row, off each already-rounded line", () {
      final splits = ocptBudgetShareSplitsOf(
        shares: [
          buildShare(id: "s1", sharePermille: 333, reinvestPermille: 333),
          buildShare(id: "s2", sharePermille: 333, reinvestPermille: 333),
        ],
        pot: potOf(receivedCents: 100000),
        paidByShareId: const {},
      );

      expect(
        ocptBudgetReinvestedTotalCents(splits),
        splits[0].reinvestedCents + splits[1].reinvestedCents,
      );
    });

    test("the due total is not the pot while the shares do not add up", () {
      final pot = potOf(receivedCents: 100000);
      final splits = ocptBudgetShareSplitsOf(
        shares: [buildShare(id: "s1", sharePermille: 400)],
        pot: pot,
        paidByShareId: const {},
      );

      expect(ocptBudgetDueTotalCents(splits), 40000);
      expect(pot.shareableCents, 100000);
    });

    test("shares summing over a thousand claim more than the pot, and say so", () {
      final shares = [
        buildShare(id: "s1", sharePermille: 700),
        buildShare(id: "s2", sharePermille: 600),
      ];

      final pot = potOf(receivedCents: 100000);
      final splits = ocptBudgetShareSplitsOf(shares: shares, pot: pot, paidByShareId: const {});

      expect(ocptBudgetSharesPermilleTotal(shares), 1300);
      expect(ocptBudgetDueTotalCents(splits), 130000);
      expect(pot.shareableCents, 100000);
    });
  });
}
