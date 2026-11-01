// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';

/// The catering table's own header row: `Day`, `Decor`, `Crew`, `Cast`, `Extras`, `Meals`,
/// `Craft services`, `Total`.
class OcptBudgetRegieCateringHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetRegieCateringHeaderRow({super.key});

  /// Build the budget regie catering header row as a [SizedBox].
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
          SizedBox(
            width: ocptBudgetRegieDayColumnWidth,
            child: Text(tr.budgetRegieColumnDay.toUpperCase(), style: labelStyle),
          ),
          Expanded(child: Text(tr.budgetRegieColumnDecor.toUpperCase(), style: labelStyle)),
          SizedBox(
            width: ocptBudgetRegieCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnCrew.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetRegieCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnCast.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetRegieCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnExtras.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetRegieWideCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnMeals.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetRegieWideCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnBuffet.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetRegieCateringTotalColumnWidth,
            child: Text(
              tr.budgetRegieColumnTotal.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}
