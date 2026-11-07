// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_metrics.dart';

/// The entry table's own header row: `Date`, `Voucher`, `Poste`, `Label`, `Debit`, `Credit`,
/// `Balance`, then a blank cell over the `⋮` menu column — `Poste` ahead of `Label`, mirroring
/// `OcptBudgetCostTracking`'s own pinned `Poste` column, since both readings of the very same
/// expenses document now lead with the same identifying column.
class OcptBudgetCashJournalHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetCashJournalHeaderRow({super.key});

  /// Build the budget cash journal header row as a [DecoratedBox].
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
        height: ocptBudgetCashJournalHeaderRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: ocptBudgetCashJournalDateColumnWidth,
              child: Text(tr.budgetCashJournalColumnDate.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: ocptBudgetCashJournalVoucherColumnWidth,
              child: Text(tr.budgetCashJournalColumnVoucher.toUpperCase(), style: labelStyle),
            ),
            SizedBox(
              width: ocptBudgetCashJournalAccountColumnWidth,
              child: Text(tr.budgetCostTrackingColumnAccount.toUpperCase(), style: labelStyle),
            ),
            Expanded(child: Text(tr.budgetCashJournalColumnLabel.toUpperCase(), style: labelStyle)),
            SizedBox(
              width: ocptBudgetCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnDebit.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            SizedBox(
              width: ocptBudgetCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnCredit.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            SizedBox(
              width: ocptBudgetCashJournalAmountColumnWidth,
              child: Text(
                tr.budgetCashJournalColumnBalance.toUpperCase(),
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: ocptBudgetCashJournalMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}
