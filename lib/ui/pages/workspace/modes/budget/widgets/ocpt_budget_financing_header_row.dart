// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_amount_cell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';

/// The column header row: `Ressource` · `Dossier` · `Promis` · `Rentré` · `Reste à venir`, then a
/// blank cell over the `⋮` menu column.
class OcptBudgetFinancingHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetFinancingHeaderRow({super.key});

  /// Build the budget financing header row as a [DecoratedBox].
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
        height: ocptBudgetFinancingHeaderRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ocpt_theme.ocptTableRowHorizontalPadding),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(tr.budgetFinancingColumnResource.toUpperCase(), style: labelStyle),
                ),
              ),
              SizedBox(
                width: ocptBudgetFinancingDossierColumnWidth,
                child: Text(tr.budgetFinancingColumnDossier.toUpperCase(), style: labelStyle),
              ),
              OcptBudgetAmountCell(
                width: ocptBudgetFinancingAmountColumnWidth,
                text: tr.budgetFinancingColumnAmount.toUpperCase(),
                style: labelStyle,
              ),
              OcptBudgetAmountCell(
                width: ocptBudgetFinancingAmountColumnWidth,
                text: tr.budgetFinancingColumnReceived.toUpperCase(),
                style: labelStyle,
              ),
              OcptBudgetAmountCell(
                width: ocptBudgetFinancingAmountColumnWidth,
                text: tr.budgetFinancingColumnOutstanding.toUpperCase(),
                style: labelStyle,
              ),
              const SizedBox(width: ocptBudgetFinancingMenuColumnWidth),
            ],
          ),
        ),
      ),
    );
  }
}
