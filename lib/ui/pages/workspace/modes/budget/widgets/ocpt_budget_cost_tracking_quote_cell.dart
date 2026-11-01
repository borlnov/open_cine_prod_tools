// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The `Devis` column's own cell: the primary figure, then, in small type, the other basis' own
/// figure and — only when the poste's lines all share one — the rate it reads under.
class OcptBudgetCostTrackingQuoteCell extends StatelessWidget {
  /// The amount shown as the headline figure, in the header's own selected basis.
  final int primaryCents;

  /// The amount shown underneath, in the other basis, or null while no line of this poste covers
  /// it at all — "it carries nothing" (`docs/architecture/budget.md`).
  final int? secondaryCents;

  /// The one rate every line of this poste shares, or null while they don't (or none is known) —
  /// see `ocptBudgetPosteUniformVatRateOf`'s own doc comment.
  final OcptBudgetEffectiveVatRate? uniformRate;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetCostTrackingQuoteCell({
    super.key,
    required this.primaryCents,
    required this.secondaryCents,
    required this.uniformRate,
    required this.currencyCode,
  });

  /// Build the budget cost tracking quote cell as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryCents = this.secondaryCents;
    final uniformRate = this.uniformRate;

    final secondaryText = secondaryCents == null
        ? null
        : uniformRate == null
        ? ocptBudgetAmountLabel(secondaryCents, currencyCode)
        : "${ocptBudgetAmountLabel(secondaryCents, currencyCode)} · "
              "${ocptVatRatePercentTextOf(uniformRate.basisPoints)} %";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ocptBudgetAmountLabel(primaryCents, currencyCode),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        if (secondaryText != null)
          Text(
            secondaryText,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: uniformRate?.isOverridden == true
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
