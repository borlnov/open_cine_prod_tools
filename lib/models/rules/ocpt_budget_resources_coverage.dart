// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_needs_resources_balance.dart';

/// The resources document's own coverage band: does the financing plan — together with the
/// takings the resources document now also holds — cover the quote, and how much of that cover
/// has really arrived rather than merely been promised.
///
/// **A different question from [OcptBudgetNeedsResourcesBalance], which stays exactly as it is**:
/// the financing-plan and financial-report PDFs still read that one, comparing the quote against
/// the financing plan's own resources alone, as a single total. This one adds the takings the
/// resources document now holds too, and splits what has really come in from what is only
/// promised — a split
/// [OcptBudgetNeedsResourcesBalance]'s own single [OcptBudgetNeedsResourcesBalance.resourcesCents]
/// cannot state.
class OcptBudgetResourcesCoverage extends Equatable {
  /// The quote's own total, and how much of it is actually known — the same reason
  /// [OcptBudgetNeedsResourcesBalance.needs] is carried whole rather than as a plain amount: the
  /// band can say the needs side is still incomplete through [OcptBudgetCoveredTotal.isComplete]
  /// rather than inventing a second way to say it.
  ///
  /// **Handed in tax-inclusive, and read as such.** Money coming in is always read tax-inclusive
  /// — the tax-basis switch lives on the expenses document alone
  /// (`docs/architecture/budget.md`'s "Money that has moved is read tax-inclusive, always") — so
  /// [ocptBudgetResourcesCoverageOf] never sees a basis and never applies one: [needs] is resolved
  /// by the caller, the same tax-inclusive reading [OcptBudgetNeedsResourcesBalance] already uses.
  final OcptBudgetCoveredTotal needs;

  /// What has really come in, folded row by row out of every resource's and every revenue's own
  /// received total: a credit whose tax-inclusive reading is unknown is *not covered*, exactly as
  /// [ocptBudgetReceivedByResourceId] already reports per resource, so the receipts side keeps its
  /// own coverage too.
  final OcptBudgetCoveredTotal received;

  /// What is promised and has not come in yet — the per-row shortfall of every resource and every
  /// revenue, summed. See [ocptBudgetResourcesCoverageOf]'s own doc comment for why an in-kind
  /// contribution needs no branch here.
  final int promisedCents;

  /// [received]'s own amount plus [promisedCents] — the plan as it stands, arrived or not.
  int get plannedCents => received.amountCents + promisedCents;

  /// How far [plannedCents] still falls short of [needs]' own amount, floored at zero.
  final int missingCents;

  /// Whether the plan, arrived or promised, covers the quote — [plannedCents] at or above
  /// [needs]' own amount. Over-financing is still a plan that holds; a shortfall alone reads as
  /// uncovered, the same register [OcptBudgetNeedsResourcesBalance.isBalanced] already reads in.
  bool get isCovered => plannedCents >= needs.amountCents;

  /// Class constructor
  const OcptBudgetResourcesCoverage({
    required this.needs,
    required this.received,
    required this.promisedCents,
    required this.missingCents,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetResourcesCoverage(needs: $needs, received: $received, "
      "promisedCents: $promisedCents, missingCents: $missingCents)";

  /// Object properties
  @override
  List<Object?> get props => [needs, received, promisedCents, missingCents];
}
