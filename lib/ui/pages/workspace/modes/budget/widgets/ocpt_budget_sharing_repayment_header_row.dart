// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_metrics.dart';

/// The column header naming a contributor row's own four amount columns — `Put in`,
/// `Of which owed`, `Repaid`, `Owed` — sitting once above the `What each person put in` card's own
/// list of contributors, `_OcptFinancingColumnHeaderRow`'s own idiom
/// (`ocpt_budget_financing.dart`) read over this card's narrower shape.
///
/// `Put in` and `Of which owed` are two columns rather than one because they answer two different
/// questions: what a person gave to the film, and how much of it the film has to give back.
class OcptBudgetSharingRepaymentHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetSharingRepaymentHeaderRow({super.key});

  /// Build the budget sharing repayment header row as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ocpt_theme.ocptTableRowHorizontalPadding,
        0,
        ocpt_theme.ocptTableRowHorizontalPadding,
        4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(tr.budgetSharingRepaymentColumnLender.toUpperCase(), style: labelStyle),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentAmountColumnWidth,
            child: Text(
              tr.budgetSharingRepaymentColumnContributed.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentAmountColumnWidth,
            child: Text(
              tr.budgetSharingRepaymentColumnReimbursable.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentAmountColumnWidth,
            child: Text(
              tr.budgetSharingRepaymentColumnRepaid.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingRepaymentAmountColumnWidth,
            child: Text(
              tr.budgetSharingRepaymentColumnOutstanding.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: ocptBudgetSharingRepaymentMenuColumnWidth),
        ],
      ),
    );
  }
}
