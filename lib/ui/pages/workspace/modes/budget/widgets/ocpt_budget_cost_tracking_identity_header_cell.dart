// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';

/// The pinned pane's own header cell: the `N°` and `Poste` column headings.
class OcptBudgetCostTrackingIdentityHeaderCell extends StatelessWidget {
  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Class constructor
  const OcptBudgetCostTrackingIdentityHeaderCell({
    super.key,
    required this.isSimplified,
    required this.posteWidth,
  });

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
            if (!isSimplified)
              SizedBox(
                width: ocptBudgetCostTrackingNumberColumnWidth,
                child: Text(
                  tr.budgetCostTrackingColumnNumber.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
            SizedBox(
              width: posteWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(tr.budgetCostTrackingColumnPoste.toUpperCase(), style: labelStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
