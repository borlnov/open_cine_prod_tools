// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_account_amounts_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_account_card.dart';

/// One account's own quote/remaining/final-cost/variance figures, computed exactly as
/// [OcptBudgetCostTrackingAccountAmountsRow.build] computes them for the desktop table's own row —
/// pulled out into a pure holder so [OcptBudgetCostTrackingAccountCard] reads the very same
/// readings rather than a second calculation that could quietly disagree with the table over the
/// same account.
class OcptBudgetCostTrackingAccountFigures {
  /// The account's own quoted total, in cents, under the reading basis.
  final int quotedAmountCents;

  /// `Reste` — [ocptBudgetRemainingCents] over the very same three amounts.
  final int remainingCents;

  /// `Écart` — [ocptBudgetVarianceCents], never [ocptBudgetFinalCostVarianceCents] (see the mode's
  /// own architecture doc for why this table always prints the former).
  final int varianceCents;

  /// Class constructor
  const OcptBudgetCostTrackingAccountFigures({
    required this.quotedAmountCents,
    required this.remainingCents,
    required this.varianceCents,
  });

  /// Build [account]'s own figures under [taxBasis], given its own [paidCents], [committedCents]
  /// and [inKindCoveredCents] — the very same
  /// [ocptBudgetTotalOf]/[ocptBudgetRemainingCents]/[ocptBudgetVarianceCents] calls
  /// [OcptBudgetCostTrackingAccountAmountsRow.build] makes for the desktop row.
  factory OcptBudgetCostTrackingAccountFigures.of({
    required OcptBudgetAccount account,
    required OcptBudgetTaxBasis taxBasis,
    required int? defaultVatRateBasisPoints,
    required int paidCents,
    required int committedCents,
    required int inKindCoveredCents,
  }) {
    final quoted = ocptBudgetTotalOf(
      account.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    return OcptBudgetCostTrackingAccountFigures(
      quotedAmountCents: quoted.amountCents,
      remainingCents: ocptBudgetRemainingCents(
        quotedAmountCents: quoted.amountCents,
        paidCents: paidCents,
        committedCents: committedCents,
        inKindCoveredCents: inKindCoveredCents,
      ),
      varianceCents: ocptBudgetVarianceCents(
        quotedAmountCents: quoted.amountCents,
        paidCents: paidCents,
        committedCents: committedCents,
        inKindCoveredCents: inKindCoveredCents,
      ),
    );
  }
}
