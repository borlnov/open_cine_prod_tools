// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_amount_cell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';

/// The scrolling pane's own header row: the six amount column headings, then a blank cell over
/// the `⋮` menu column.
class OcptBudgetCostTrackingAmountsHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetCostTrackingAmountsHeaderRow({super.key});

  /// Build the budget cost tracking amounts header row as a [DecoratedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: ocptBudgetCostTrackingHeaderRowHeight,
        child: Row(
          children: [
            OcptBudgetAmountCell(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              text: tr.budgetCostTrackingColumnQuote.toUpperCase(),
              style: labelStyle,
            ),
            OcptBudgetAmountCell(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              text: tr.budgetCostTrackingColumnCommitted.toUpperCase(),
              style: labelStyle,
            ),
            OcptBudgetAmountCell(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              text: tr.budgetCostTrackingColumnPaid.toUpperCase(),
              style: labelStyle,
            ),
            OcptBudgetAmountCell(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              text: tr.budgetCostTrackingColumnRemaining.toUpperCase(),
              style: labelStyle,
            ),
            OcptBudgetAmountCell(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              text: tr.budgetCostTrackingColumnFinalCost.toUpperCase(),
              style: labelStyle,
            ),
            OcptBudgetAmountCell(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              text: tr.budgetCostTrackingColumnVariance.toUpperCase(),
              style: labelStyle,
            ),
            const SizedBox(width: ocptBudgetCostTrackingMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}
