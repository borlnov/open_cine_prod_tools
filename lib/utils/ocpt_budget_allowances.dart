// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';

/// What one defrayal comes to, in whole cents: [quantityMilli] thousandths of a unit at
/// [unitAmountMilliCents] thousandths of a cent each.
///
/// **Rounded half-up at the very last step, never before**, exactly as the mileage arithmetic this
/// replaces already did: 168 km at 0.529 €/km is `168000 × 52900 = 8_887_200_000` millionths of a
/// cent, which is 8 887 cents — 88,87 €. Rounding the rate to whole cents first would have said
/// 88,90 € or 88,04 €, neither of which is what the scale states.
///
/// Never clamped and never floored: a negative quantity or a negative unit price is a figure
/// somebody typed, and this answers what it comes to rather than what it ought to have been.
int ocptBudgetAllowanceAmountCents({
  required int quantityMilli,
  required int unitAmountMilliCents,
}) {
  final millionths = quantityMilli * unitAmountMilliCents;
  return millionths.isNegative
      ? -((-millionths + 500000) ~/ 1000000)
      : (millionths + 500000) ~/ 1000000;
}

/// What [allowance] comes to, in whole cents — [ocptBudgetAllowanceAmountCents] read off the row
/// itself.
int ocptBudgetAllowanceCentsOf(OcptBudgetAllowance allowance) => ocptBudgetAllowanceAmountCents(
  quantityMilli: allowance.quantityMilli,
  unitAmountMilliCents: allowance.unitAmountMilliCents,
);

/// What every one of [allowances] comes to, summed.
///
/// **Each row is rounded before the sum, not after it**, because each row is a figure somebody is
/// actually owed: rounding the total instead would leave the sum of what the app prints per person
/// disagreeing with the total it prints underneath, by a cent nobody could account for.
int ocptBudgetAllowancesTotalCents(List<OcptBudgetAllowance> allowances) =>
    allowances.fold(0, (sum, allowance) => sum + ocptBudgetAllowanceCentsOf(allowance));

/// [allowances]' own totals, grouped by [OcptBudgetAllowance.kind] — one figure per nature, which
/// is what the provisioning writes one quote line each from.
///
/// **A kind with no defrayal of its own has no key at all**, the discipline every grouping of this
/// mode keeps (`ocptBudgetResourcesTotalByGroupKind`): a caller can tell "nobody is defrayed for a
/// stay" apart from "somebody is, at nothing", which folding the two into a zero-valued key would
/// lose — and the provisioning would then write a quote line for a nature the production never
/// used.
Map<OcptBudgetAllowanceKind, int> ocptBudgetAllowancesTotalByKind(
  List<OcptBudgetAllowance> allowances,
) {
  final totals = <OcptBudgetAllowanceKind, int>{};
  for (final allowance in allowances) {
    totals[allowance.kind] = (totals[allowance.kind] ?? 0) + ocptBudgetAllowanceCentsOf(allowance);
  }

  return totals;
}
