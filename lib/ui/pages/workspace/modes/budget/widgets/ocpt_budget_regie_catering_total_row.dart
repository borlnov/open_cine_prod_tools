// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie_totals.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The catering table's own total row: the summed meals (every day's own sittings folded together,
/// [OcptBudgetRegieDay.mealCount]'s own sum), buffet servings and money over every printed day —
/// the coverage read-out in place of the plain amount for as long as the project has not recorded
/// both prices, mirroring `OcptBudgetCostTracking`'s own total row.
class OcptBudgetRegieCateringTotalRow extends StatelessWidget {
  /// [OcptBudgetRegie.days] folded into one total.
  final OcptBudgetRegieTotals totals;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetRegieCateringTotalRow({
    super.key,
    required this.totals,
    required this.currencyCode,
  });

  /// Build the budget regie catering total row as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final amountText = ocptBudgetAmountLabel(totals.cost.amountCents, currencyCode);
    final costText = totals.cost.isComplete
        ? amountText
        : tr.budgetRegieCateringCoverageReadOut(
            amountText,
            totals.cost.coveredLineCount,
            totals.cost.lineCount,
          );

    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    // Mirrors `OcptBudgetRegieCateringHeaderRow`'s own column structure exactly (the `Day` column
    // blank, the label sitting in the `Decor` column's own flexible slot, then a blank `Crew`,
    // `Cast` and `Extras` cell before the two summed counts), so this row's own cells line up
    // under the header that names them rather than drifting once the `Decor` column happens to
    // grow or shrink.
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: ocptBudgetRegieDayColumnWidth),
          Expanded(child: Text(tr.budgetCostTrackingTotalRowLabel, style: boldStyle)),
          const SizedBox(width: ocptBudgetRegieCountColumnWidth),
          const SizedBox(width: ocptBudgetRegieCountColumnWidth),
          const SizedBox(width: ocptBudgetRegieCountColumnWidth),
          SizedBox(
            width: ocptBudgetRegieWideCountColumnWidth,
            child: Text("${totals.mealCount}", textAlign: TextAlign.right, style: boldStyle),
          ),
          SizedBox(
            width: ocptBudgetRegieWideCountColumnWidth,
            child: Text("${totals.buffetCount}", textAlign: TextAlign.right, style: boldStyle),
          ),
          SizedBox(
            width: ocptBudgetRegieCateringTotalColumnWidth,
            child: Text(
              costText,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: boldStyle,
            ),
          ),
        ],
      ),
    );
  }
}
