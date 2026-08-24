// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

void main() {
  OcptBudgetEntry buildEntry({
    String id = "entry-1",
    DateTime? date,
    String label = "An entry",
    String? posteId,
    String? resourceId,
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
    revenueId: null,
    shareId: null,
  );

  OcptBudgetResource buildResource({
    String id = "resource-1",
    OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.subsidy,
    String label = "A resource",
    int amountCents = 0,
    OcptBudgetResourceStatus status = OcptBudgetResourceStatus.pending,
    bool isReimbursable = false,
    String notes = "",
    String sortKey = "V",
  }) => OcptBudgetResource(
    id: id,
    groupKind: groupKind,
    personId: null,
    label: label,
    amountCents: amountCents,
    status: status,
    isReimbursable: isReimbursable,
    notes: notes,
    sortKey: sortKey,
  );

  OcptBudgetRevenue buildRevenue({
    String id = "revenue-1",
    DateTime? date,
    String label = "A revenue",
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

  group("ocptBudgetReceivedByResourceId", () {
    test("sums credits only, off the journal", () {
      final entries = [
        buildEntry(id: "e1", resourceId: "r1", creditCents: 5000),
        buildEntry(id: "e2", resourceId: "r1", creditCents: 2000),
      ];

      final byResource = ocptBudgetReceivedByResourceId(entries, projectVatRateBasisPoints: null);

      expect(byResource["r1"]!.amountCents, 7000);
      expect(byResource["r1"]!.isComplete, isTrue);
    });

    test("a debit naming a resource is not subtracted", () {
      final entries = [
        buildEntry(id: "e1", resourceId: "r1", creditCents: 5000),
        // A repayment against the very same resource: it does not un-receive the 5000 above.
        buildEntry(id: "e2", resourceId: "r1", debitCents: 2000),
      ];

      final byResource = ocptBudgetReceivedByResourceId(entries, projectVatRateBasisPoints: null);

      expect(byResource["r1"]!.amountCents, 5000);
    });

    test("an entry with no rate leaves the total covered but incomplete", () {
      final entries = [
        buildEntry(id: "e1", resourceId: "r1", creditCents: 5000),
        // Excluding tax, no rate anywhere: unreadable.
        buildEntry(id: "e2", resourceId: "r1", creditCents: 1000, isTaxInclusive: false),
      ];

      final byResource = ocptBudgetReceivedByResourceId(entries, projectVatRateBasisPoints: null);

      expect(byResource["r1"]!.amountCents, 5000);
      expect(byResource["r1"]!.coveredLineCount, 1);
      expect(byResource["r1"]!.lineCount, 2);
      expect(byResource["r1"]!.isComplete, isFalse);
    });

    test("a resource with no entry naming it has no key at all", () {
      final entries = [buildEntry(id: "e1", resourceId: "r1", creditCents: 1000)];

      final byResource = ocptBudgetReceivedByResourceId(entries, projectVatRateBasisPoints: null);

      expect(byResource.containsKey("r1"), isTrue);
      expect(byResource.containsKey("r2"), isFalse);
    });

    test("an entry naming no resource is not in the map at all", () {
      final entries = [buildEntry(id: "e1", creditCents: 1000)];

      final byResource = ocptBudgetReceivedByResourceId(entries, projectVatRateBasisPoints: null);

      expect(byResource, isEmpty);
    });
  });

  group("ocptBudgetResourcesTotalCents / by group kind / by status", () {
    test("sums the plain amounts, no tax basis involved", () {
      final resources = [
        buildResource(id: "r1", amountCents: 10000),
        buildResource(id: "r2", amountCents: 5000),
      ];

      expect(ocptBudgetResourcesTotalCents(resources), 15000);
    });

    test("groups by group kind, a kind with no resource getting no key", () {
      final resources = [
        buildResource(id: "r1", amountCents: 10000),
        buildResource(id: "r2", groupKind: OcptBudgetResourceGroupKind.cash, amountCents: 3000),
        buildResource(id: "r3", groupKind: OcptBudgetResourceGroupKind.cash, amountCents: 2000),
      ];

      final byKind = ocptBudgetResourcesTotalByGroupKind(resources);

      expect(byKind[OcptBudgetResourceGroupKind.subsidy], 10000);
      expect(byKind[OcptBudgetResourceGroupKind.cash], 5000);
      expect(byKind.containsKey(OcptBudgetResourceGroupKind.inKind), isFalse);
    });

    test("groups by status, a status with no resource getting no key", () {
      final resources = [
        buildResource(id: "r1", amountCents: 10000),
        buildResource(id: "r2", status: OcptBudgetResourceStatus.confirmed, amountCents: 4000),
      ];

      final byStatus = ocptBudgetResourcesTotalByStatus(resources);

      expect(byStatus[OcptBudgetResourceStatus.pending], 10000);
      expect(byStatus[OcptBudgetResourceStatus.confirmed], 4000);
      expect(byStatus.containsKey(OcptBudgetResourceStatus.agreed), isFalse);
    });
  });

  group("ocptBudgetResourceOutstandingCents", () {
    test("is the plain difference", () {
      expect(
        ocptBudgetResourceOutstandingCents(amountCents: 10000, receivedCents: 4000),
        6000,
      );
    });

    test("reads negative, never clamped, once a resource is over-received", () {
      expect(
        ocptBudgetResourceOutstandingCents(amountCents: 10000, receivedCents: 15000),
        -5000,
      );
    });
  });

  group("ocptBudgetNeedsResourcesBalanceOf", () {
    test("a complete needs figure balanced by the resources", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 2, lineCount: 2);

      final balance = ocptBudgetNeedsResourcesBalanceOf(needs: needs, resourcesCents: 10000);

      expect(balance.differenceCents, 0);
      expect(balance.isBalanced, isTrue);
      expect(balance.needs.isComplete, isTrue);
    });

    test("a shortfall reads as not balanced", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 2, lineCount: 2);

      final balance = ocptBudgetNeedsResourcesBalanceOf(needs: needs, resourcesCents: 6000);

      expect(balance.differenceCents, -4000);
      expect(balance.isBalanced, isFalse);
    });

    test("an incomplete needs figure still reports its own coverage", () {
      // Only 1 of 3 postes carries a known rate.
      const needs = OcptBudgetCoveredTotal(amountCents: 4000, coveredLineCount: 1, lineCount: 3);

      final balance = ocptBudgetNeedsResourcesBalanceOf(needs: needs, resourcesCents: 4000);

      expect(balance.needs.isComplete, isFalse);
      expect(balance.needs.coveredLineCount, 1);
      expect(balance.needs.lineCount, 3);
      // The balance itself is still readable off whatever the needs side currently states.
      expect(balance.differenceCents, 0);
      expect(balance.isBalanced, isTrue);
    });
  });

  group("ocptBudgetResourcesCoverageOf", () {
    test("a plan that covers the quote", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1);
      final resources = [buildResource(id: "r1", amountCents: 10000)];
      final receivedByResourceId = {
        "r1": const OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1),
      };

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: resources,
        revenues: const [],
        receivedByResourceId: receivedByResourceId,
        receivedByRevenueId: const {},
      );

      expect(coverage.received.amountCents, 10000);
      expect(coverage.promisedCents, 0);
      expect(coverage.plannedCents, 10000);
      expect(coverage.missingCents, 0);
      expect(coverage.isCovered, isTrue);
    });

    test("a plan that falls short of the quote", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1);
      final resources = [buildResource(id: "r1", amountCents: 6000)];

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: resources,
        revenues: const [],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
      );

      expect(coverage.received.amountCents, 0);
      expect(coverage.promisedCents, 6000);
      expect(coverage.plannedCents, 6000);
      expect(coverage.missingCents, 4000);
      expect(coverage.isCovered, isFalse);
    });

    test("a resource received in part splits between received and promised", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1);
      final resources = [buildResource(id: "r1", amountCents: 10000)];
      final receivedByResourceId = {
        "r1": const OcptBudgetCoveredTotal(amountCents: 4000, coveredLineCount: 1, lineCount: 1),
      };

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: resources,
        revenues: const [],
        receivedByResourceId: receivedByResourceId,
        receivedByRevenueId: const {},
      );

      expect(coverage.received.amountCents, 4000);
      expect(coverage.promisedCents, 6000);
      expect(coverage.plannedCents, 10000);
    });

    test("an in-kind resource no entry names counts wholly as promised", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1);
      final resources = [
        buildResource(id: "r1", groupKind: OcptBudgetResourceGroupKind.inKind, amountCents: 3000),
      ];

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: resources,
        revenues: const [],
        // No key for r1 at all: no credit will ever name an in-kind contribution.
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
      );

      expect(coverage.received.amountCents, 0);
      expect(coverage.promisedCents, 3000);
    });

    test("an in-kind resource an entry does name is read like any other row", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1);
      final resources = [
        buildResource(id: "r1", groupKind: OcptBudgetResourceGroupKind.inKind, amountCents: 3000),
      ];
      final receivedByResourceId = {
        "r1": const OcptBudgetCoveredTotal(amountCents: 3000, coveredLineCount: 1, lineCount: 1),
      };

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: resources,
        revenues: const [],
        receivedByResourceId: receivedByResourceId,
        receivedByRevenueId: const {},
      );

      expect(coverage.received.amountCents, 3000);
      expect(coverage.promisedCents, 0);
    });

    test("an over-received row does not lend its excess to another row's promise", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 20000, coveredLineCount: 1, lineCount: 1);
      final resources = [
        buildResource(id: "r1", amountCents: 5000),
        buildResource(id: "r2", amountCents: 5000),
      ];
      final receivedByResourceId = {
        // Over-received by 5000, which must not offset r2's own shortfall.
        "r1": const OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1),
      };

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: resources,
        revenues: const [],
        receivedByResourceId: receivedByResourceId,
        receivedByRevenueId: const {},
      );

      expect(coverage.received.amountCents, 10000);
      // r1 promises 0 (already over-received), r2 still promises its whole 5000.
      expect(coverage.promisedCents, 5000);
      expect(coverage.plannedCents, 15000);
    });

    test("revenues are counted on both the received and the promised side", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 20000, coveredLineCount: 1, lineCount: 1);
      final resources = [buildResource(id: "r1", amountCents: 5000)];
      final revenues = [buildRevenue(id: "v1", amountCents: 15000)];
      final receivedByResourceId = {
        "r1": const OcptBudgetCoveredTotal(amountCents: 5000, coveredLineCount: 1, lineCount: 1),
      };
      final receivedByRevenueId = {
        "v1": const OcptBudgetCoveredTotal(amountCents: 6000, coveredLineCount: 1, lineCount: 1),
      };

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: resources,
        revenues: revenues,
        receivedByResourceId: receivedByResourceId,
        receivedByRevenueId: receivedByRevenueId,
      );

      expect(coverage.received.amountCents, 11000);
      expect(coverage.promisedCents, 9000);
      expect(coverage.plannedCents, 20000);
      expect(coverage.isCovered, isTrue);
    });

    test("an incomplete receipt leaves the received side's own coverage false", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1);
      final resources = [buildResource(id: "r1", amountCents: 5000)];
      final receivedByResourceId = {
        // Only 1 of 2 credits naming r1 carried a known rate.
        "r1": const OcptBudgetCoveredTotal(amountCents: 3000, coveredLineCount: 1, lineCount: 2),
      };

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: resources,
        revenues: const [],
        receivedByResourceId: receivedByResourceId,
        receivedByRevenueId: const {},
      );

      expect(coverage.received.isComplete, isFalse);
      expect(coverage.received.coveredLineCount, 1);
      expect(coverage.received.lineCount, 2);
    });

    test("an empty plan is wholly promised and never covers a non-zero quote", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1);

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: const [],
        revenues: const [],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
      );

      expect(coverage.received.amountCents, 0);
      expect(coverage.received.lineCount, 0);
      expect(coverage.promisedCents, 0);
      expect(coverage.plannedCents, 0);
      expect(coverage.missingCents, 10000);
      expect(coverage.isCovered, isFalse);
    });

    test("a quote with no needs at all reads as covered by an empty plan", () {
      const needs = OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0);

      final coverage = ocptBudgetResourcesCoverageOf(
        needs: needs,
        resources: const [],
        revenues: const [],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
      );

      expect(coverage.missingCents, 0);
      expect(coverage.isCovered, isTrue);
    });
  });
}
