// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

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
    sortKey: "V",
  );

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

  OcptBudgetAllowance buildAllowance({
    String id = "allowance-1",
    String? personId,
    OcptBudgetAllowanceKind kind = OcptBudgetAllowanceKind.other,
    String label = "A defrayal",
    DateTime? date,
    int quantityMilli = 1000,
    int unitAmountMilliCents = 0,
  }) => OcptBudgetAllowance(
    id: id,
    personId: personId,
    kind: kind,
    label: label,
    date: date,
    endDate: null,
    quantityMilli: quantityMilli,
    unitAmountMilliCents: unitAmountMilliCents,
    notes: "",
    sortKey: "V",
  );

  OcptBudgetResource buildResource({
    String id = "resource-1",
    OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.subsidy,
    String label = "A resource",
    int amountCents = 0,
  }) => OcptBudgetResource(
    id: id,
    groupKind: groupKind,
    personId: null,
    label: label,
    amountCents: amountCents,
    status: OcptBudgetResourceStatus.pending,
    isReimbursable: false,
    notes: "",
    sortKey: "V",
  );

  OcptBudgetRevenue buildRevenue({
    String id = "revenue-1",
    DateTime? date,
    String label = "A revenue",
    int amountCents = 0,
  }) => OcptBudgetRevenue(
    id: id,
    date: date ?? DateTime(2026),
    label: label,
    amountCents: amountCents,
    status: OcptBudgetRevenueStatus.expected,
    notes: "",
    sortKey: "V",
  );

  final draftDate = DateTime(2026, 3, 10);

  group("direction", () {
    test("a debit offers only commitments and defrayals", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: true,
        draftAmountCents: 25000,
        draftDate: draftDate,
        draftWording: "Couronne",
        commitments: [buildCommitment(id: "c1", label: "Couronne", amountCents: 25000, dueDate: draftDate)],
        entries: const [],
        allowances: [buildAllowance(id: "a1", label: "Couronne", unitAmountMilliCents: 25000000)],
        resources: [buildResource(id: "r1", label: "Couronne", amountCents: 25000)],
        revenues: [buildRevenue(id: "v1", label: "Couronne", amountCents: 25000)],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions.map((s) => s.kind).toSet(), {
        OcptBudgetMatchCandidateKind.commitment,
        OcptBudgetMatchCandidateKind.defrayal,
      });
    });

    test("a credit offers only resources and revenues", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: false,
        draftAmountCents: 25000,
        draftDate: draftDate,
        draftWording: "Couronne",
        commitments: [buildCommitment(id: "c1", label: "Couronne", amountCents: 25000, dueDate: draftDate)],
        entries: const [],
        allowances: [buildAllowance(id: "a1", label: "Couronne", unitAmountMilliCents: 25000000)],
        resources: [buildResource(id: "r1", label: "Couronne", amountCents: 25000)],
        revenues: [buildRevenue(id: "v1", label: "Couronne", amountCents: 25000)],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions.map((s) => s.kind).toSet(), {
        OcptBudgetMatchCandidateKind.resource,
        OcptBudgetMatchCandidateKind.revenue,
      });
    });
  });

  group("ranking", () {
    test("exact amount outranks a nearer date", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: true,
        draftAmountCents: 25000,
        draftDate: draftDate,
        draftWording: "unrelated wording",
        commitments: [
          // Due the very same day, but the wrong amount.
          buildCommitment(id: "near-date", label: "Other", amountCents: 9900, dueDate: draftDate),
          // A month away, but the exact amount.
          buildCommitment(
            id: "exact-amount",
            label: "Other",
            amountCents: 25000,
            dueDate: draftDate.add(const Duration(days: 30)),
          ),
        ],
        entries: const [],
        allowances: const [],
        resources: const [],
        revenues: const [],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions.first.candidateId, "exact-amount");
    });

    test("a dateless candidate sorts after a dated one, all else equal", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: false,
        draftAmountCents: 10000,
        draftDate: draftDate,
        draftWording: "unrelated",
        commitments: const [],
        entries: const [],
        allowances: const [],
        resources: [buildResource(id: "no-date", label: "Other", amountCents: 10000)],
        revenues: [
          buildRevenue(
            id: "far-date",
            label: "Other",
            amountCents: 10000,
            date: draftDate.add(const Duration(days: 400)),
          ),
        ],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      // Both match on amount alone, so the tie is broken by date proximity: the revenue carries a
      // date, however distant, and the resource carries none at all.
      expect(suggestions.map((s) => s.candidateId).toList(), ["far-date", "no-date"]);
    });

    test("wording is found across accents and case", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: true,
        draftAmountCents: 999,
        draftDate: draftDate.add(const Duration(days: 400)),
        draftWording: "loc. caméra couronne",
        commitments: [buildCommitment(id: "c1", label: "COURONNE SARL", amountCents: 1)],
        entries: const [],
        allowances: const [],
        resources: const [],
        revenues: const [],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.matchesWording, isTrue);
      expect(suggestions.single.matchesAmount, isFalse);
      expect(suggestions.single.matchesDate, isFalse);
    });

    test("the outstanding amount, not the full amount, is what is matched", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: false,
        draftAmountCents: 3000,
        draftDate: draftDate,
        draftWording: "unrelated",
        commitments: const [],
        entries: const [],
        allowances: const [],
        resources: [buildResource(id: "r1", label: "Camera", amountCents: 10000)],
        revenues: const [],
        receivedByResourceId: {
          "r1": const OcptBudgetCoveredTotal(amountCents: 7000, coveredLineCount: 1, lineCount: 1),
        },
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.outstandingCents, 3000);
      expect(suggestions.single.matchesAmount, isTrue);
    });
  });

  group("eligibility", () {
    test("a settled commitment is excluded", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: true,
        draftAmountCents: 25000,
        draftDate: draftDate,
        draftWording: "unrelated",
        commitments: [
          buildCommitment(id: "c1", label: "unrelated", amountCents: 25000, dueDate: draftDate),
        ],
        entries: [buildEntry(id: "entry-1", commitmentId: "c1", debitCents: 25000)],
        allowances: const [],
        resources: const [],
        revenues: const [],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions, isEmpty);
    });

    test("a fully received resource is excluded", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: false,
        draftAmountCents: 10000,
        draftDate: draftDate,
        draftWording: "unrelated",
        commitments: const [],
        entries: const [],
        allowances: const [],
        resources: [buildResource(id: "r1", label: "unrelated", amountCents: 10000)],
        revenues: const [],
        receivedByResourceId: {
          "r1": const OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1),
        },
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions, isEmpty);
    });

    test("nothing matching on amount, date or wording returns empty", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: true,
        draftAmountCents: 500,
        draftDate: draftDate,
        draftWording: "totally different",
        commitments: [
          buildCommitment(
            id: "c1",
            label: "Unmatched supplier",
            amountCents: 999999,
            dueDate: draftDate.add(const Duration(days: 400)),
          ),
        ],
        entries: const [],
        allowances: const [],
        resources: const [],
        revenues: const [],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions, isEmpty);
    });

    test("the result is capped at three even when more candidates match", () {
      final suggestions = ocptBudgetMatchSuggestionsOf(
        isDebit: true,
        draftAmountCents: 5000,
        draftDate: draftDate,
        draftWording: "unrelated",
        commitments: List.generate(
          5,
          (i) => buildCommitment(id: "c$i", label: "unrelated", amountCents: 5000, dueDate: draftDate),
        ),
        entries: const [],
        allowances: const [],
        resources: const [],
        revenues: const [],
        receivedByResourceId: const {},
        receivedByRevenueId: const {},
        projectVatRateBasisPoints: null,
      );

      expect(suggestions, hasLength(3));
    });
  });
}
