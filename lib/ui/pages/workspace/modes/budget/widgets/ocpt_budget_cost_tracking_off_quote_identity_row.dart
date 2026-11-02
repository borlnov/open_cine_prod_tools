// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_off_quote_amounts_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_poste_amounts_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_poste_identity_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_twisty.dart';

/// The pinned pane's own off-quote row: a twisty, then the `Off quote` label, in the `Poste`
/// column's own place — the identity half of the very same row
/// [OcptBudgetCostTrackingOffQuoteAmountsRow] draws the other half of, exactly the way
/// [OcptBudgetCostTrackingPosteIdentityRow] and [OcptBudgetCostTrackingPosteAmountsRow] split an
/// ordinary poste's row.
///
/// **This row is not a poste, and draws nothing else that would let it pass for one**: no `N°`, no
/// selection highlight and — [OcptBudgetCostTrackingOffQuoteAmountsRow]'s own doc comment argues
/// why — no `⋮` menu either. Neither half carries an `onTap` of its own at all: it is a reading
/// over the journal, not a record anybody can rename, reorder or delete, so clicking the label does
/// nothing rather than quietly calling [OcptBudgetCostTracking.onPosteSelected] with nothing to
/// select.
///
/// **The twisty is the one thing this row can do**: `OcptBudgetCostTracking._rowsOf` draws it
/// only while the total holds at least one debit, so it is always expandable the moment it is
/// drawn at all, and opens onto exactly the debits that make the total up — a reader who lands on
/// the aggregate can reach what it sums without knowing another view of the journal exists.
class OcptBudgetCostTrackingOffQuoteIdentityRow extends StatelessWidget {
  /// Whether the header's simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// The `Poste` column's own width, computed by the table.
  final double posteWidth;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked.
  final VoidCallback onTwistyTap;

  /// Class constructor
  const OcptBudgetCostTrackingOffQuoteIdentityRow({
    super.key,
    required this.isSimplified,
    required this.posteWidth,
    required this.isExpanded,
    required this.onTwistyTap,
  });

  /// Build the budget cost tracking off quote identity row as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return SizedBox(
      height: ocptBudgetCostTrackingRowHeight,
      child: Row(
        children: [
          // Never a poste code, whatever the width — this row is not a poste.
          if (!isSimplified) const SizedBox(width: ocptBudgetCostTrackingNumberColumnWidth),
          SizedBox(
            width: posteWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                children: [
                  OcptBudgetCostTrackingTwisty(
                    isExpandable: true,
                    isExpanded: isExpanded,
                    onTap: onTwistyTap,
                    rowHeight: ocptBudgetCostTrackingRowHeight,
                  ),
                  Expanded(
                    child: Text(
                      tr.budgetCostTrackingOffQuoteLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
