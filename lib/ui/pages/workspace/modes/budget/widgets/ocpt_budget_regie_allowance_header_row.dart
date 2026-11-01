// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';

/// The defrayal table's own header row: `Person`, `Advanced`, `Reimbursed`, `Owed`.
class OcptBudgetRegieAllowanceHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetRegieAllowanceHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: ocptBudgetRegieHeaderRowHeight,
      child: Row(
        children: [
          Expanded(child: Text(tr.budgetRegieColumnPerson.toUpperCase(), style: labelStyle)),
          _amountHeaderCell(tr.budgetRegieColumnAdvanced, labelStyle),
          _amountHeaderCell(tr.budgetRegieColumnReimbursed, labelStyle),
          _amountHeaderCell(tr.budgetRegieColumnOwed, labelStyle),
          const SizedBox(width: ocptBudgetRegieAllowanceMenuColumnWidth),
        ],
      ),
    );
  }

  /// One amount column's own header cell, right-aligned like the figures underneath it.
  Widget _amountHeaderCell(String label, TextStyle? style) => SizedBox(
    width: ocptBudgetRegieAllowanceAmountColumnWidth,
    child: Text(
      label.toUpperCase(),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}
