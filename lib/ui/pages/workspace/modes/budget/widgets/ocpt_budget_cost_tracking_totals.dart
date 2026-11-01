// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';

/// How many postes count as covered under [taxBasis] — "every one of its own lines does"
/// (`docs/architecture/budget.md`) — what the total row's own coverage read-out counts
/// against `postes.length`.
int ocptBudgetCostTrackingCoveredPosteCountOf(
  List<OcptBudgetPoste> postes, {
  required OcptBudgetTaxBasis taxBasis,
  required int? defaultVatRateBasisPoints,
}) {
  var count = 0;
  for (final poste in postes) {
    final posteTotal = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    if (posteTotal.isComplete) {
      count++;
    }
  }
  return count;
}

/// The grand `Coût final` total, summed **poste by poste** (`ocpt_budget_totals.dart`'s own "row
/// by row, then summed" doctrine) rather than re-derived from the grand `Devis`/`Payé`/`Engagé`
/// totals: a typed estimate to complete on one poste cannot be reconstructed from any
/// project-wide figure, and [ocptBudgetEstimateToCompleteCents]'s own `max(0, …)` clamp does not
/// commute with a sum — summing the clamped, per-poste figures is not the same amount as clamping
/// the sum.
int ocptBudgetCostTrackingFinalCostTotalOf(
  List<OcptBudgetPoste> postes, {
  required OcptBudgetTaxBasis taxBasis,
  required int? defaultVatRateBasisPoints,
  required Map<String, OcptBudgetCoveredTotal> paidByPosteId,
  required int Function(String posteId) committedCentsOf,
  required int Function(String posteId) inKindCoveredCentsOf,
}) {
  var finalCostCents = 0;

  for (final poste in postes) {
    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidCents = paidByPosteId[poste.id]?.amountCents ?? 0;
    final committedCents = committedCentsOf(poste.id);
    final inKindCoveredCents = inKindCoveredCentsOf(poste.id);
    final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: inKindCoveredCents,
      typedEstimateToCompleteCents: poste.estimateToCompleteCents,
    );

    finalCostCents += ocptBudgetFinalCostCents(
      paidCents: paidCents,
      committedCents: committedCents,
      estimateToCompleteCents: estimateToCompleteCents,
    );
  }

  return finalCostCents;
}
