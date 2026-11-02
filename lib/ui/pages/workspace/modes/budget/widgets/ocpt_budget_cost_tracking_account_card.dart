// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_account_figures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_card_proportion_bar.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One account's own card, drawn in place of its row pair at a compact width — see
/// [OcptBudgetCostTracking]'s own class doc comment. Its own name, a proportion bar and its
/// `Engagé`/`Payé`/`Reste`/`Écart` figures, tapping it selecting the account exactly as tapping
/// either half of its desktop row does.
class OcptBudgetCostTrackingAccountCard extends StatelessWidget {
  /// The account this card shows.
  final OcptBudgetAccount account;

  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// Whether this account is the currently selected one.
  final bool isSelected;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// This account's own paid total, in cents.
  final int paidCents;

  /// This account's own committed total, in cents.
  final int committedCents;

  /// This account's own in-kind covered total, in cents.
  final int inKindCoveredCents;

  /// Called when this card is tapped — never withheld under a read-only preview, selecting an
  /// account being a read, not a write ([OcptBudgetCostTracking.onAccountSelected] is never gated
  /// on `isReadOnly` for the very same reason on the desktop row).
  final VoidCallback onTap;

  /// Class constructor
  const OcptBudgetCostTrackingAccountCard({
    super.key,
    required this.account,
    required this.isSimplified,
    required this.isSelected,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidCents,
    required this.committedCents,
    required this.inKindCoveredCents,
    required this.onTap,
  });

  /// Build the budget cost tracking account card as a [Card].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final label = ocptBudgetAccountDisplayLabel(account, isSimplified: isSimplified);
    final figures = OcptBudgetCostTrackingAccountFigures.of(
      account: account,
      taxBasis: taxBasis,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: inKindCoveredCents,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: ocpt_theme.ocptClickableCursor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!isSimplified) ...[
                      Text(
                        account.code,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label.isEmpty ? tr.budgetAccountUnnamed : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontStyle: label.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ocptBudgetAmountLabel(figures.quotedAmountCents, currencyCode),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OcptBudgetCostTrackingCardProportionBar(
                  quotedAmountCents: figures.quotedAmountCents,
                  paidCents: paidCents,
                  committedCents: committedCents,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _OcptCostTrackingCardFigure(
                      currencyCode: currencyCode,
                      label: tr.budgetCostTrackingColumnCommitted,
                      amountCents: committedCents,
                    ),
                    _OcptCostTrackingCardFigure(
                      currencyCode: currencyCode,
                      label: tr.budgetCostTrackingColumnPaid,
                      amountCents: paidCents,
                    ),
                    _OcptCostTrackingCardFigure(
                      currencyCode: currencyCode,
                      label: tr.budgetCostTrackingColumnRemaining,
                      amountCents: figures.remainingCents,
                    ),
                    _OcptCostTrackingCardFigure(
                      currencyCode: currencyCode,
                      label: tr.budgetCostTrackingColumnVariance,
                      amountCents: figures.varianceCents,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One `label` above `amountCents`, formatted like every other figure the cost tracking table
/// prints.
class _OcptCostTrackingCardFigure extends StatelessWidget {
  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The label printed above the figure.
  final String label;

  /// The amount, in cents.
  final int amountCents;

  /// Class constructor
  const _OcptCostTrackingCardFigure({
    required this.currencyCode,
    required this.label,
    required this.amountCents,
  });

  /// Build the cost tracking card figure as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(ocptBudgetAmountLabel(amountCents, currencyCode), style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
