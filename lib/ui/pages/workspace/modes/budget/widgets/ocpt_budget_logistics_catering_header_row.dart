// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_metrics.dart';

/// The catering table's own header row: `Day`, `Decor`, `Crew`, `Cast`, `Extras`, `Meals`,
/// `Craft services`, `Total`.
class OcptBudgetLogisticsCateringHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetLogisticsCateringHeaderRow({super.key});

  /// Build the budget logistics catering header row as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: ocptBudgetLogisticsHeaderRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: ocptBudgetLogisticsDayColumnWidth,
            child: Text(tr.budgetLogisticsColumnDay.toUpperCase(), style: labelStyle),
          ),
          Expanded(child: Text(tr.budgetLogisticsColumnDecor.toUpperCase(), style: labelStyle)),
          SizedBox(
            width: ocptBudgetLogisticsCountColumnWidth,
            child: Text(
              tr.budgetLogisticsColumnCrew.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetLogisticsCountColumnWidth,
            child: Text(
              tr.budgetLogisticsColumnCast.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetLogisticsCountColumnWidth,
            child: Text(
              tr.budgetLogisticsColumnExtras.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetLogisticsWideCountColumnWidth,
            child: Text(
              tr.budgetLogisticsColumnMeals.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetLogisticsWideCountColumnWidth,
            child: Text(
              tr.budgetLogisticsColumnBuffet.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetLogisticsCateringTotalColumnWidth,
            child: Text(
              tr.budgetLogisticsColumnTotal.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}
