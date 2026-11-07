// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_amounts_total_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';

/// The pinned pane's own total row: just the `Total` label, spanning the `N°`/`Poste` cells' own
/// width so it lines up with [OcptBudgetCostTrackingAmountsTotalRow], the other half of the very
/// same row, in the scrolling pane.
class OcptBudgetCostTrackingIdentityTotalRow extends StatelessWidget {
  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double accountWidth;

  /// Class constructor
  const OcptBudgetCostTrackingIdentityTotalRow({
    super.key,
    required this.isSimplified,
    required this.accountWidth,
  });

  /// Build the budget cost tracking identity total row as a [DecoratedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: ocptBudgetCostTrackingTotalRowHeight,
        child: Row(
          children: [
            if (!isSimplified) const SizedBox(width: ocptBudgetCostTrackingNumberColumnWidth),
            SizedBox(
              width: accountWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  tr.budgetCostTrackingTotalRowLabel,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
