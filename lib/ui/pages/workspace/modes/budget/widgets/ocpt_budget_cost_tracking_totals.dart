// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';

/// Count how many accounts count as covered under [taxBasis] — "every one of its own lines does"
/// (`docs/architecture/budget.md`) — what the total row's own coverage read-out counts
/// against `accounts.length`.
int ocptBudgetCostTrackingCoveredAccountCountOf(
  List<OcptBudgetAccount> accounts, {
  required OcptBudgetTaxBasis taxBasis,
  required int? defaultVatRateBasisPoints,
}) {
  var count = 0;
  for (final account in accounts) {
    final accountTotal = ocptBudgetTotalOf(
      account.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    if (accountTotal.isComplete) {
      count++;
    }
  }
  return count;
}

/// Get the grand `Coût final` total, summed **account by account** (`ocpt_budget_totals.dart`'s own
/// "row
/// by row, then summed" doctrine) rather than re-derived from the grand `Devis`/`Payé`/`Engagé`
/// totals: a typed estimate to complete on one account cannot be reconstructed from any
/// project-wide figure, and [ocptBudgetEstimateToCompleteCents]'s own `max(0, …)` clamp does not
/// commute with a sum — summing the clamped, per-account figures is not the same amount as clamping
/// the sum.
int ocptBudgetCostTrackingFinalCostTotalOf(
  List<OcptBudgetAccount> accounts, {
  required OcptBudgetTaxBasis taxBasis,
  required int? defaultVatRateBasisPoints,
  required Map<String, OcptBudgetCoveredTotal> paidByAccountId,
  required int Function(String accountId) committedCentsOf,
  required int Function(String accountId) inKindCoveredCentsOf,
}) {
  var finalCostCents = 0;

  for (final account in accounts) {
    final quoted = ocptBudgetTotalOf(
      account.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidCents = paidByAccountId[account.id]?.amountCents ?? 0;
    final committedCents = committedCentsOf(account.id);
    final inKindCoveredCents = inKindCoveredCentsOf(account.id);
    final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: inKindCoveredCents,
      typedEstimateToCompleteCents: account.estimateToCompleteCents,
    );

    finalCostCents += ocptBudgetFinalCostCents(
      paidCents: paidCents,
      committedCents: committedCents,
      estimateToCompleteCents: estimateToCompleteCents,
    );
  }

  return finalCostCents;
}
