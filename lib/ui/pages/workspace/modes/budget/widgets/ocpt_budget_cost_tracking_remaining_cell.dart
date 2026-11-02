// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_quote_cell.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The `Reste` column's own cell: the remaining figure, then, in small muted type, how much of it
/// an in-kind contribution already covers — [Tr.budgetCostTrackingInKindCoveredHint] — while the
/// poste this cell belongs to carries any in-kind coverage at all
/// ([OcptBudgetCostTracking.inKindCoveredCentsOf] positive for it). Mirrors
/// [OcptBudgetCostTrackingQuoteCell]'s own two-line layout, so the extra line never drifts the row
/// out of [ocptBudgetCostTrackingRowHeight].
class OcptBudgetCostTrackingRemainingCell extends StatelessWidget {
  /// The poste's own `Reste` figure, in cents, under the reading basis.
  final int remainingCents;

  /// The poste's own in-kind covered total, in cents — the hint draws only while this is
  /// positive.
  final int inKindCoveredCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetCostTrackingRemainingCell({
    super.key,
    required this.remainingCents,
    required this.inKindCoveredCents,
    required this.currencyCode,
  });

  /// Build the budget cost tracking remaining cell as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ocptBudgetAmountLabel(remainingCents, currencyCode),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        if (inKindCoveredCents > 0)
          Text(
            tr.budgetCostTrackingInKindCoveredHint(
              ocptBudgetAmountLabel(inKindCoveredCents, currencyCode),
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
