// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_allowances.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_reimbursements.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_cells.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';

/// The defrayal table's own total row: what every live defrayal comes to under `ADVANCED`, what has
/// actually been reimbursed under `REIMBURSED`, and what remains owed under `OWED` — mirrors
/// `OcptBudgetFinancing`'s own `_OcptResourcesTotalRow`.
class OcptBudgetRegieAllowanceTotalRow extends StatelessWidget {
  /// Every live defrayal.
  final List<OcptBudgetAllowance> allowances;

  /// Every live journal entry, narrowed here to the debits naming a person.
  final List<OcptBudgetEntry> entries;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetRegieAllowanceTotalRow({
    super.key,
    required this.allowances,
    required this.entries,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

  /// Build the budget regie allowance total row as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);

    final advancedCents = ocptBudgetAllowancesTotalCents(allowances);
    final reimbursedCents = _reimbursedTotalCentsOf();
    final outstandingCents = ocptBudgetPersonOutstandingCents(
      advancedCents: advancedCents,
      reimbursedCents: reimbursedCents,
    );

    return SizedBox(
      height: ocptBudgetRegieHeaderRowHeight,
      child: Row(
        children: [
          Expanded(child: Text(tr.budgetRegieTotalLabel.toUpperCase(), style: labelStyle)),
          ocptBudgetRegieAllowanceAmountCell(
            context,
            advancedCents,
            currencyCode,
            style: boldStyle,
          ),
          ocptBudgetRegieAllowanceAmountCell(
            context,
            reimbursedCents,
            currencyCode,
            style: boldStyle,
          ),
          ocptBudgetRegieAllowanceAmountCell(
            context,
            outstandingCents,
            currencyCode,
            style: boldStyle,
          ),
          const SizedBox(width: ocptBudgetRegieAllowanceMenuColumnWidth),
        ],
      ),
    );
  }

  /// Get the tax-inclusive sum of every person's own reimbursed total, across [entries] —
  /// `ocptBudgetReimbursedByPersonId`, folded into one figure for the whole table rather than kept
  /// per person, since the total row answers for every running account at once.
  int _reimbursedTotalCentsOf() => ocptBudgetReimbursedByPersonId(
    entries,
    projectVatRateBasisPoints: defaultVatRateBasisPoints,
  ).values.fold(0, (sum, total) => sum + total.amountCents);
}
