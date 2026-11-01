// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';

/// The needs/resources balance the financing-plan and financial-report PDFs print: the quote's own
/// [needs] against the financing plan's own [resourcesCents].
///
/// [needs] is carried as a whole [OcptBudgetCoveredTotal] rather than a plain `int` **on purpose**,
/// so the bar can expose whether the needs side is complete — `docs/architecture/budget.md`'s own
/// `tr.budgetCostTrackingCoverageReadOut` reading, "for as long as any line lacks a rate" — through
/// [OcptBudgetCoveredTotal.isComplete], rather than this class inventing a second way to say the
/// same thing.
class OcptBudgetNeedsResourcesBalance extends Equatable {
  /// The quote's own total, and how much of it is actually known — see the class doc comment for
  /// why this is a whole [OcptBudgetCoveredTotal] rather than a plain amount.
  final OcptBudgetCoveredTotal needs;

  /// The financing plan's own total, in cents — [ocptBudgetResourcesTotalCents]'s own figure,
  /// carrying no coverage of its own since it needs no rate to be complete (see that function's own
  /// doc comment).
  final int resourcesCents;

  /// [resourcesCents] minus [needs]' own [OcptBudgetCoveredTotal.amountCents] — positive once the
  /// plan raises more than the quote asks for, negative while it still falls short.
  final int differenceCents;

  /// Tell whether the financing plan covers the quote — [differenceCents] at or above zero. A real
  /// financing plan rarely lands on exactly zero, and over-financing is still a plan that holds: it
  /// is a shortfall alone that this reads as unbalanced.
  bool get isBalanced => differenceCents >= 0;

  /// Class constructor
  const OcptBudgetNeedsResourcesBalance({
    required this.needs,
    required this.resourcesCents,
    required this.differenceCents,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetNeedsResourcesBalance(needs: $needs, resourcesCents: $resourcesCents, "
      "differenceCents: $differenceCents)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [needs, resourcesCents, differenceCents];
}
