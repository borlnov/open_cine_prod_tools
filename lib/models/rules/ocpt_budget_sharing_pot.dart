// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_shares.dart';

/// What there is to share, and what stands between the takings and it.
///
/// The order this states things in **is** the rule the view exists to make legible: the takings
/// come in, the reimbursable contributions are taken off the top in full, and only what is left is
/// anybody's to split.
class OcptBudgetSharingPot extends Equatable {
  /// What the takings have actually brought in — [ocptBudgetRevenuesReceivedTotalOf]'s own figure,
  /// carried whole so the view can say how much of it the app could read.
  final OcptBudgetCoveredTotal received;

  /// What the reimbursable contributions come to in total, in cents —
  /// [ocptBudgetReimbursableTotalCents].
  final int reimbursableCents;

  /// What has already been paid back against them —
  /// [ocptBudgetRepaidContributionsTotalOf]'s own figure.
  final OcptBudgetCoveredTotal repaid;

  /// What is still owed to the contributors: [reimbursableCents] less what [repaid] says has gone
  /// back, floored at zero — a production that has paid back more than it owed has finished
  /// repaying, not started being owed.
  int get outstandingRepaymentCents {
    final outstanding = reimbursableCents - repaid.amountCents;
    return outstanding < 0 ? 0 : outstanding;
  }

  /// What is left to share, in cents: the takings less the **whole** of [reimbursableCents],
  /// floored at zero.
  ///
  /// **The whole of it, not merely what is still outstanding.** Whether a contribution has been
  /// physically repaid yet is a question about the production's cash, not about what belongs to the
  /// participants: a film that has earned 4,000 € against 3,500 € of reimbursable contributions has
  /// 500 € to share, and it has 500 € to share whether the 3,500 € went back last week or has not
  /// gone back at all. Reading the outstanding figure here instead would let a production enlarge
  /// the pot simply by delaying a repayment.
  int get shareableCents {
    final shareable = received.amountCents - reimbursableCents;
    return shareable < 0 ? 0 : shareable;
  }

  /// Whether there is anything at all to share yet. False while the takings have not yet cleared
  /// the contributions, which is the ordinary state of a film for a long time — and the state in
  /// which every participant's own due is honestly zero rather than unknown.
  bool get hasSomethingToShare => shareableCents > 0;

  /// Class constructor
  const OcptBudgetSharingPot({
    required this.received,
    required this.reimbursableCents,
    required this.repaid,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetSharingPot(received: $received, reimbursableCents: $reimbursableCents, "
      "repaid: $repaid)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [received, reimbursableCents, repaid];
}
