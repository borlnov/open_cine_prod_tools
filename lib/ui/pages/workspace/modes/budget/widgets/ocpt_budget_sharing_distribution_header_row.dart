// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing_metrics.dart';

/// The `Distribution` table's own header row: `Participant`, `Share`, `Due`, `Paid`, `Reinvested`.
class OcptBudgetSharingDistributionHeaderRow extends StatelessWidget {
  /// Class constructor
  const OcptBudgetSharingDistributionHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

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
            child: Text(tr.budgetSharingParticipantColumnLabel.toUpperCase(), style: labelStyle),
          ),
          SizedBox(
            width: ocptBudgetSharingPercentColumnWidth,
            child: Text(
              tr.budgetSharingShareColumnLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingAmountColumnWidth,
            child: Text(
              tr.budgetSharingDueColumnLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingAmountColumnWidth,
            child: Text(
              tr.budgetSharingPaidColumnLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: ocptBudgetSharingAmountColumnWidth,
            child: Text(
              tr.budgetSharingReinvestedColumnLabel.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: ocptBudgetSharingMenuColumnWidth),
        ],
      ),
    );
  }
}
