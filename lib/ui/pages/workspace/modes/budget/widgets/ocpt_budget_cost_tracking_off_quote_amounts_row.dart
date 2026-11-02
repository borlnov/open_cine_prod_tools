// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The scrolling pane's own off-quote row: only the `Payé` cell carries a figure —
/// [offQuoteTotal]'s own tax-inclusive amount, plain, exactly as an ordinary account row's own
/// `Payé` cell is. `Devis`, `Engagé`, `Reste`, `Coût final` and `Écart` all print
/// [ocptBudgetEmptyValue]: there is no quote behind this row to measure any of them against, the
/// same silence `docs/architecture/budget.md` already keeps for a figure with nothing to divide by.
///
/// **No `⋮` menu column, unlike an ordinary account's own amounts row.** Every one of that menu's
/// entries — rename, move, delete — acts on an account, and this row is not one: it is a reading
/// over the journal's own account-less debits, with no record of its own to rename, reorder or
/// delete.
class OcptBudgetCostTrackingOffQuoteAmountsRow extends StatelessWidget {
  /// The total of every debit naming no account at all — this row's own `Payé` figure.
  final OcptBudgetCoveredTotal offQuoteTotal;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetCostTrackingOffQuoteAmountsRow({
    super.key,
    required this.offQuoteTotal,
    required this.currencyCode,
  });

  /// Build the budget cost tracking off quote amounts row as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: ocptBudgetCostTrackingRowHeight,
      child: Row(
        children: [
          _emptyCell(theme), // Devis
          _emptyCell(theme), // Engagé
          _amountCell(
            theme,
            ocptBudgetAmountLabel(offQuoteTotal.amountCents, currencyCode),
          ), // Payé
          _emptyCell(theme), // Reste
          _emptyCell(theme), // Coût final
          _emptyCell(theme), // Écart
          const SizedBox(width: ocptBudgetCostTrackingMenuColumnWidth), // no ⋮ menu at all
        ],
      ),
    );
  }

  /// Build one amount cell, right-aligned, printing [text] as typed.
  Widget _amountCell(ThemeData theme, String text) => SizedBox(
    width: ocptBudgetCostTrackingAmountColumnWidth,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall,
    ),
  );

  /// Build one amount cell reading [ocptBudgetEmptyValue] — every column this row has no reading
  /// for.
  Widget _emptyCell(ThemeData theme) => SizedBox(
    width: ocptBudgetCostTrackingAmountColumnWidth,
    child: Text(ocptBudgetEmptyValue, textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
  );
}
