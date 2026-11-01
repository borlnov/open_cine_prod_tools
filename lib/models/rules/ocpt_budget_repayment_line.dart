// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_sharing_pot.dart';

/// One lender's own line in the `Repaying the contributions` card: what they have contributed in
/// total across every reimbursable resource grouped under them, what has already gone back and
/// what is still owed — [ocptBudgetRepaymentLinesOf]'s own reading.
///
/// A synthetic grouping, never a stored row: several `budget_resources` rows may collapse into one
/// line here, which is the whole point (the product owner's own words motivate this: three loans of
/// 100 € from the same person are one debt of 300 €, not three separate figures a reader has to add
/// up by hand).
class OcptBudgetRepaymentLine extends Equatable {
  /// The person this line groups by, or null when it groups by [label] instead — see
  /// [ocptBudgetRepaymentLinesOf]'s own doc comment for the grouping rule.
  final String? personId;

  /// The label this line prints when [personId] is null — every resource grouped into this line
  /// then shares this exact label, which is the grouping key itself. When [personId] is not null
  /// this is simply the **first** grouped resource's own label, carried through as a fallback the
  /// view may print if it cannot resolve [personId] into a person any more.
  final String label;

  /// What this contributor has put in **in total**, in cents — the plain sum of every resource
  /// grouped under this line, reimbursable or not, in cash or in kind.
  ///
  /// **Not the same figure as [reimbursableCents], and deliberately.** This card used to read only
  /// the reimbursable ones, which meant a production that had marked nothing reimbursable — the
  /// ordinary state of a project the day it is created — saw an empty card and no way to tell that
  /// anybody had contributed anything. What a person put in is worth stating whether or not it
  /// comes back: it is how a production knows who it owes its film to, which is a different debt
  /// from the one it owes their bank account.
  final int contributedCents;

  /// How much of [contributedCents] has to come back out of the takings before anything is shared
  /// — the sum of the **reimbursable** resources alone, read exactly as
  /// [ocptBudgetReimbursableTotalCents] reads it for the whole plan.
  ///
  /// Zero for a contributor whose whole contribution is a gift or an unrecouped valuation, which
  /// is a perfectly ordinary line rather than a missing one.
  final int reimbursableCents;

  /// What has already gone back to this lender — the tax-inclusive sum of every `budget_entries`
  /// debit naming one of this line's own resources through `budget_entries.resourceId`, read
  /// exactly as [ocptBudgetRepaidContributionsTotalOf] reads it for the whole plan.
  final OcptBudgetCoveredTotal repaid;

  /// What is still owed to this contributor: [reimbursableCents] less [repaid]'s own amount,
  /// floored at zero — [OcptBudgetSharingPot.outstandingRepaymentCents]'s own reading, read per
  /// contributor rather than for the whole plan.
  ///
  /// **Reads [reimbursableCents], never [contributedCents]**: nothing is owed against a gift, so a
  /// contributor who gave without expecting it back is owed zero however much they gave.
  int get outstandingCents {
    final outstanding = reimbursableCents - repaid.amountCents;
    return outstanding < 0 ? 0 : outstanding;
  }

  /// Class constructor
  const OcptBudgetRepaymentLine({
    required this.personId,
    required this.label,
    required this.contributedCents,
    required this.reimbursableCents,
    required this.repaid,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetRepaymentLine(personId: $personId, label: $label, "
      "contributedCents: $contributedCents, reimbursableCents: $reimbursableCents, "
      "repaid: $repaid)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [personId, label, contributedCents, reimbursableCents, repaid];
}
