// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';

/// Builds a quote line quoted at [amountCents] (a single unit at that price), everything else
/// neutral.
OcptBudgetLine _buildLine({
  required String id,
  required String posteId,
  required int amountCents,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: "Line $id",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  elementId: null,
  provisionKey: null,
  provisionDigest: null,
  notes: "",
  sortKey: "a0",
);

/// Builds a poste quoted at [quotedAmountCents] (a single line carrying that whole amount),
/// everything else neutral.
OcptBudgetPoste _buildPoste({required String id, required int quotedAmountCents}) => OcptBudgetPoste(
  id: id,
  code: "1",
  label: "Poste $id",
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: [_buildLine(id: "$id-line", posteId: id, amountCents: quotedAmountCents)],
);

/// Builds an unsettled commitment against [posteId], everything else neutral.
OcptBudgetCommitment _buildCommitment({
  required String id,
  required String posteId,
  DateTime? dueDate,
  int amountCents = 0,
  String? settledEntryId,
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: "Commitment $id",
  posteId: posteId,
  amount: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  status: OcptBudgetCommitmentStatus.quoteAccepted,
  settledEntryId: settledEntryId,
  lineId: null,
  sortKey: "a0",
);

/// The zero-everything cash totals every test not concerned with the balance itself starts from.
const _zeroCashTotals = OcptBudgetCashTotals(
  debitCents: 0,
  creditCents: 0,
  coveredEntryCount: 0,
  entryCount: 0,
);

/// Wraps [ocptComputeBudgetAlerts] with the neutral defaults most tests want: nothing paid or
/// committed against any poste, no commitment at all, an empty account.
List<OcptBudgetAlert> _computeAlerts({
  required List<OcptBudgetPoste> postes,
  int Function(String posteId)? paidCentsOf,
  int Function(String posteId)? committedCentsOf,
  List<OcptBudgetCommitment> commitments = const [],
  OcptBudgetCashTotals cashTotals = _zeroCashTotals,
  int? projectVatRateBasisPoints,
}) => ocptComputeBudgetAlerts(
  postes: postes,
  paidCentsOf: paidCentsOf ?? (posteId) => 0,
  committedCentsOf: committedCentsOf ?? (posteId) => 0,
  commitments: commitments,
  cashTotals: cashTotals,
  projectVatRateBasisPoints: projectVatRateBasisPoints,
);

void main() {
  group("a project with no alert at all", () {
    test("answers an empty list", () {
      final alerts = _computeAlerts(
        postes: [_buildPoste(id: "poste-1", quotedAmountCents: 10000)],
        paidCentsOf: (posteId) => 5000,
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
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);

      final alerts = _computeAlerts(
        postes: [poste],
        paidCentsOf: (posteId) => 7000,
        committedCentsOf: (posteId) => 5000,
      );

      expect(alerts, hasLength(1));
      final alert = alerts.single as OcptBudgetPosteOverQuoteAlert;
      expect(alert.posteId, "poste-1");
      expect(alert.quotedAmountCents, 10000);
      expect(alert.paidCents, 7000);
      expect(alert.committedCents, 5000);
      // Paid (7000) + committed (5000) = 12000, 2000 over the 10000 quote.
      expect(alert.varianceCents, 2000);
    });

    test("a poste within its quote raises nothing", () {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);

      final alerts = _computeAlerts(postes: [poste], paidCentsOf: (posteId) => 5000);

      expect(alerts, isEmpty);
    });

    test("a poste near, but not over, its quote raises nothing either", () {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 10000);

      // 95 % consumed: near the strain threshold, still not over it.
      final alerts = _computeAlerts(postes: [poste], paidCentsOf: (posteId) => 9500);

      expect(alerts, isEmpty);
    });

    test("a poste with no quote at all raises nothing while nothing has moved against it", () {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 0);

      final alerts = _computeAlerts(postes: [poste]);

      expect(alerts, isEmpty);
    });

    test("a poste with no quote at all raises the alert the moment anything moves against it", () {
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 0);

      final alerts = _computeAlerts(postes: [poste], paidCentsOf: (posteId) => 100);

      expect(alerts, hasLength(1));
      final alert = alerts.single as OcptBudgetPosteOverQuoteAlert;
      expect(alert.quotedAmountCents, 0);
      expect(alert.varianceCents, 100);
    });

    test("raises one alert per poste over its quote, in the order the postes were given", () {
      final posteOver1 = _buildPoste(id: "poste-1", quotedAmountCents: 1000);
      final posteWithin = _buildPoste(id: "poste-2", quotedAmountCents: 1000);
      final posteOver2 = _buildPoste(id: "poste-3", quotedAmountCents: 1000);

      final alerts = _computeAlerts(
        postes: [posteOver1, posteWithin, posteOver2],
        paidCentsOf: (posteId) => posteId == "poste-2" ? 500 : 2000,
      );

      expect(alerts, hasLength(2));
      expect(
        alerts.map((alert) => (alert as OcptBudgetPosteOverQuoteAlert).posteId),
        ["poste-1", "poste-3"],
      );
    });
  });

  group("the cash projection going negative", () {
    test("raises nothing while it never goes under", () {
      final commitments = [
        _buildCommitment(id: "c1", posteId: "poste-1", dueDate: DateTime(2026, 2), amountCents: 3000),
      ];

      final alerts = _computeAlerts(
        postes: const [],
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
        _buildCommitment(id: "c1", posteId: "poste-1", dueDate: DateTime(2026, 3, 15), amountCents: 8000),
      ];

      final alerts = _computeAlerts(
        postes: const [],
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
      final commitments = [_buildCommitment(id: "c1", posteId: "poste-1", amountCents: 6000)];

      final alerts = _computeAlerts(
        postes: const [],
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
          posteId: "poste-1",
          dueDate: DateTime(2026, 3),
          amountCents: 9000,
          settledEntryId: "entry-already-paid",
        ),
      ];

      final alerts = _computeAlerts(
        postes: const [],
        commitments: commitments,
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
        _buildCommitment(id: "c1", posteId: "poste-1", dueDate: DateTime(2026), amountCents: 2000),
        _buildCommitment(id: "c2", posteId: "poste-1", dueDate: DateTime(2026, 2), amountCents: 5000),
      ];

      final alerts = _computeAlerts(
        postes: const [],
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
      final poste = _buildPoste(id: "poste-1", quotedAmountCents: 1000);
      final commitments = [
        _buildCommitment(id: "c1", posteId: "poste-1", dueDate: DateTime(2026, 5), amountCents: 4000),
      ];

      final alerts = _computeAlerts(
        postes: [poste],
        paidCentsOf: (posteId) => 2000,
        commitments: commitments,
        cashTotals: const OcptBudgetCashTotals(
          debitCents: 0,
          creditCents: 1000,
          coveredEntryCount: 1,
          entryCount: 1,
        ),
      );

      expect(alerts, hasLength(2));
      expect(alerts.whereType<OcptBudgetPosteOverQuoteAlert>(), hasLength(1));
      expect(alerts.whereType<OcptBudgetCashProjectionNegativeAlert>(), hasLength(1));
    });
  });
}
