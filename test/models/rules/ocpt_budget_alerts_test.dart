// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_cash_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';

/// Builds a quote line quoted at [amountCents] (a single unit at that price), everything else
/// neutral.
OcptBudgetLine _buildLine({
  required String id,
  required String accountId,
  required int amountCents,
}) => OcptBudgetLine(
  id: id,
  accountId: accountId,
  label: "Line $id",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  elementId: null,
  inKindResourceId: null,
  provisionKey: null,
  provisionDigest: null,
  notes: "",
  sortKey: "a0",
);

/// Builds an account quoted at [quotedAmountCents] (a single line carrying that whole amount),
/// everything else neutral.
OcptBudgetAccount _buildAccount({required String id, required int quotedAmountCents}) =>
    OcptBudgetAccount(
      id: id,
      code: "1",
      label: "Poste $id",
      simpleLabel: null,
      estimateToCompleteCents: null,
      sortKey: "a0",
      lines: [_buildLine(id: "$id-line", accountId: id, amountCents: quotedAmountCents)],
    );

/// Builds a commitment against [accountId], everything else neutral — settlement is read off
/// whichever entries a test hands alongside it, never a field of the commitment itself any more.
OcptBudgetCommitment _buildCommitment({
  required String id,
  required String accountId,
  DateTime? dueDate,
  int amountCents = 0,
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: "Commitment $id",
  accountId: accountId,
  amount: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  status: OcptBudgetCommitmentStatus.quoteAccepted,
  lineId: null,
  sortKey: "a0",
);

/// Builds a debit entry naming [commitmentId], everything else neutral.
OcptBudgetEntry _buildEntry({required String id, String? commitmentId, int debitCents = 0}) =>
    OcptBudgetEntry(
      id: id,
      date: DateTime(2026),
      label: "Entry $id",
      accountId: null,
      debitCents: debitCents,
      creditCents: 0,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: "J-001",
      sortKey: "a0",
      resourceId: null,
      revenueId: null,
      shareId: null,
      commitmentId: commitmentId,
      personId: null,
    );

/// The zero-everything cash totals every test not concerned with the balance itself starts from.
const _zeroCashTotals = OcptBudgetCashTotals(
  debitCents: 0,
  creditCents: 0,
  coveredEntryCount: 0,
  entryCount: 0,
);

/// Wraps [ocptComputeBudgetAlerts] with the neutral defaults most tests want: nothing paid,
/// committed or settled in kind against any account, no commitment at all, an empty account.
List<OcptBudgetAlert> _computeAlerts({
  required List<OcptBudgetAccount> accounts,
  int Function(String accountId)? paidCentsOf,
  int Function(String accountId)? committedCentsOf,
  int Function(String accountId)? inKindCoveredCentsOf,
  List<OcptBudgetCommitment> commitments = const [],
  List<OcptBudgetEntry> entries = const [],
  OcptBudgetCashTotals cashTotals = _zeroCashTotals,
  int? projectVatRateBasisPoints,
}) => ocptComputeBudgetAlerts(
  accounts: accounts,
  paidCentsOf: paidCentsOf ?? (accountId) => 0,
  committedCentsOf: committedCentsOf ?? (accountId) => 0,
  inKindCoveredCentsOf: inKindCoveredCentsOf ?? (accountId) => 0,
  commitments: commitments,
  entries: entries,
  cashTotals: cashTotals,
  projectVatRateBasisPoints: projectVatRateBasisPoints,
);

/// Run the tests of the budget alerts.
void main() {
  group("a project with no alert at all", () {
    test("answers an empty list", () {
      final alerts = _computeAlerts(
        accounts: [_buildAccount(id: "poste-1", quotedAmountCents: 10000)],
        paidCentsOf: (accountId) => 5000,
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 5000,
          creditCents: 20000,
          coveredEntryCount: 2,
          entryCount: 2,
        ),
      );

      expect(alerts, isEmpty);
    });
  });

  group("a poste over its quote", () {
    test("raises one alert, naming the poste and by how much it is over", () {
      final account = _buildAccount(id: "poste-1", quotedAmountCents: 10000);

      final alerts = _computeAlerts(
        accounts: [account],
        paidCentsOf: (accountId) => 7000,
        committedCentsOf: (accountId) => 5000,
      );

      expect(alerts, hasLength(1));
      final alert = alerts.single as OcptBudgetAccountOverQuoteAlert;
      expect(alert.accountId, "poste-1");
      expect(alert.quotedAmountCents, 10000);
      expect(alert.paidCents, 7000);
      expect(alert.committedCents, 5000);
      // Paid (7000) + committed (5000) = 12000, 2000 over the 10000 quote.
      expect(alert.varianceCents, 2000);
    });

    test("a poste within its quote raises nothing", () {
      final account = _buildAccount(id: "poste-1", quotedAmountCents: 10000);

      final alerts = _computeAlerts(accounts: [account], paidCentsOf: (accountId) => 5000);

      expect(alerts, isEmpty);
    });

    test("a poste near, but not over, its quote raises nothing either", () {
      final account = _buildAccount(id: "poste-1", quotedAmountCents: 10000);

      // 95 % consumed: near the strain threshold, still not over it.
      final alerts = _computeAlerts(accounts: [account], paidCentsOf: (accountId) => 9500);

      expect(alerts, isEmpty);
    });

    test("a poste with no quote at all raises nothing while nothing has moved against it", () {
      final account = _buildAccount(id: "poste-1", quotedAmountCents: 0);

      final alerts = _computeAlerts(accounts: [account]);

      expect(alerts, isEmpty);
    });

    test("a poste with no quote at all raises the alert the moment anything moves against it", () {
      final account = _buildAccount(id: "poste-1", quotedAmountCents: 0);

      final alerts = _computeAlerts(accounts: [account], paidCentsOf: (accountId) => 100);

      expect(alerts, hasLength(1));
      final alert = alerts.single as OcptBudgetAccountOverQuoteAlert;
      expect(alert.quotedAmountCents, 0);
      expect(alert.varianceCents, 100);
    });

    test("an in-kind-only poste raises nothing — it never reads as a strain", () {
      final account = _buildAccount(id: "poste-1", quotedAmountCents: 5000);

      final alerts = _computeAlerts(accounts: [account], inKindCoveredCentsOf: (accountId) => 5000);

      expect(alerts, isEmpty);
    });

    test("raises one alert per poste over its quote, in the order the postes were given", () {
      final accountOver1 = _buildAccount(id: "poste-1", quotedAmountCents: 1000);
      final accountWithin = _buildAccount(id: "poste-2", quotedAmountCents: 1000);
      final accountOver2 = _buildAccount(id: "poste-3", quotedAmountCents: 1000);

      final alerts = _computeAlerts(
        accounts: [accountOver1, accountWithin, accountOver2],
        paidCentsOf: (accountId) => accountId == "poste-2" ? 500 : 2000,
      );

      expect(alerts, hasLength(2));
      expect(alerts.map((alert) => (alert as OcptBudgetAccountOverQuoteAlert).accountId), [
        "poste-1",
        "poste-3",
      ]);
    });
  });

  group("the cash projection going negative", () {
    test("raises nothing while it never goes under", () {
      final commitments = [
        _buildCommitment(
          id: "c1",
          accountId: "poste-1",
          dueDate: DateTime(2026, 2),
          amountCents: 3000,
        ),
      ];

      final alerts = _computeAlerts(
        accounts: const [],
        commitments: commitments,
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 0,
          creditCents: 10000,
          coveredEntryCount: 1,
          entryCount: 1,
        ),
      );

      expect(alerts, isEmpty);
    });

    test("raises one alert naming the balance today, the falling-due amount and the date", () {
      final commitments = [
        _buildCommitment(
          id: "c1",
          accountId: "poste-1",
          dueDate: DateTime(2026, 3, 15),
          amountCents: 8000,
        ),
      ];

      final alerts = _computeAlerts(
        accounts: const [],
        commitments: commitments,
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 0,
          creditCents: 5000,
          coveredEntryCount: 1,
          entryCount: 1,
        ),
      );

      expect(alerts, hasLength(1));
      final alert = alerts.single as OcptBudgetCashProjectionNegativeAlert;
      expect(alert.balanceCents, 5000);
      expect(alert.dueDate, DateTime(2026, 3, 15));
      expect(alert.fallingDueCents, 8000);
      expect(alert.balanceAfterCents, -3000);
    });

    test("an undated commitment that tips the balance under still raises the alert, with a null "
        "date rather than no alert at all", () {
      final commitments = [_buildCommitment(id: "c1", accountId: "poste-1", amountCents: 6000)];

      final alerts = _computeAlerts(
        accounts: const [],
        commitments: commitments,
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 0,
          creditCents: 1000,
          coveredEntryCount: 1,
          entryCount: 1,
        ),
      );

      expect(alerts, hasLength(1));
      final alert = alerts.single as OcptBudgetCashProjectionNegativeAlert;
      // Null is a different fact from no alert at all: the projection does go under, but on no
      // date anybody has recorded.
      expect(alert.dueDate, isNull);
      expect(alert.balanceAfterCents, -5000);
    });

    test("a settled commitment is never counted against the balance", () {
      final commitments = [
        _buildCommitment(
          id: "c1",
          accountId: "poste-1",
          dueDate: DateTime(2026, 3),
          amountCents: 9000,
        ),
      ];
      final entries = [_buildEntry(id: "entry-already-paid", commitmentId: "c1", debitCents: 9000)];

      final alerts = _computeAlerts(
        accounts: const [],
        commitments: commitments,
        entries: entries,
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 0,
          creditCents: 1000,
          coveredEntryCount: 1,
          entryCount: 1,
        ),
      );

      expect(alerts, isEmpty);
    });

    test("at most one cash alert, the first instalment that tips the balance under", () {
      final commitments = [
        _buildCommitment(
          id: "c1",
          accountId: "poste-1",
          dueDate: DateTime(2026),
          amountCents: 2000,
        ),
        _buildCommitment(
          id: "c2",
          accountId: "poste-1",
          dueDate: DateTime(2026, 2),
          amountCents: 5000,
        ),
      ];

      final alerts = _computeAlerts(
        accounts: const [],
        commitments: commitments,
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 0,
          creditCents: 3000,
          coveredEntryCount: 1,
          entryCount: 1,
        ),
      );

      final cashAlerts = alerts.whereType<OcptBudgetCashProjectionNegativeAlert>();
      expect(cashAlerts, hasLength(1));
      // The first instalment (2026-01, 2000) already tips 3000 to 1000, which is not yet
      // negative — the second (2026-02, 5000) is the one that actually does.
      expect(cashAlerts.single.dueDate, DateTime(2026, 2));
      expect(cashAlerts.single.balanceAfterCents, -4000);
    });
  });

  group("both alerts at once", () {
    test("a poste over its quote and the cash going negative both raise, independently", () {
      final account = _buildAccount(id: "poste-1", quotedAmountCents: 1000);
      final commitments = [
        _buildCommitment(
          id: "c1",
          accountId: "poste-1",
          dueDate: DateTime(2026, 5),
          amountCents: 4000,
        ),
      ];

      final alerts = _computeAlerts(
        accounts: [account],
        paidCentsOf: (accountId) => 2000,
        commitments: commitments,
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 0,
          creditCents: 1000,
          coveredEntryCount: 1,
          entryCount: 1,
        ),
      );

      expect(alerts, hasLength(2));
      expect(alerts.whereType<OcptBudgetAccountOverQuoteAlert>(), hasLength(1));
      expect(alerts.whereType<OcptBudgetCashProjectionNegativeAlert>(), hasLength(1));
    });
  });
}
