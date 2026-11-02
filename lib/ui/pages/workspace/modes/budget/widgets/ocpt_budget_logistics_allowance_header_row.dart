// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_amount_cell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_metrics.dart';

/// The defrayal table's own header row: `Person`, `Advanced`, `Reimbursed`, `Owed`.
class OcptBudgetLogisticsAllowanceHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetLogisticsAllowanceHeaderRow({super.key});

  /// Build the budget logistics allowance header row as a [SizedBox].
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
          Expanded(child: Text(tr.budgetLogisticsColumnPerson.toUpperCase(), style: labelStyle)),
          OcptBudgetAmountCell(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            text: tr.budgetLogisticsColumnAdvanced.toUpperCase(),
            style: labelStyle,
          ),
          OcptBudgetAmountCell(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            text: tr.budgetLogisticsColumnReimbursed.toUpperCase(),
            style: labelStyle,
          ),
          OcptBudgetAmountCell(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            text: tr.budgetLogisticsColumnOwed.toUpperCase(),
            style: labelStyle,
          ),
          const SizedBox(width: ocptBudgetLogisticsAllowanceMenuColumnWidth),
        ],
      ),
    );
  }
}
