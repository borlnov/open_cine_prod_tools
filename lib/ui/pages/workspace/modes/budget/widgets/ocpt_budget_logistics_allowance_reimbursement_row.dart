// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cents_cell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One reimbursement sub-row: a dot, a `REIMBURSED` badge, the entry's own date and wording, its
/// debit printed in the `REIMBURSED` column alone — the other money cells left blank, no menu: the
/// entry itself belongs to the cash journal, not to this tree.
class OcptBudgetLogisticsAllowanceReimbursementRow extends StatelessWidget {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// The project's own default VAT rate, in basis points, or null while it declares none — what
  /// [entry]'s own debit is read tax-inclusive against.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetLogisticsAllowanceReimbursementRow({
    super.key,
    required this.entry,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

  /// Build the budget logistics allowance reimbursement row as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final dateText = DateFormat.yMd().format(entry.date);
    final label = entry.label.isEmpty ? dateText : "$dateText · ${entry.label}";
    // Read exactly the way the `REIMBURSED` column above it is — tax-inclusive, through the
    // journal's own reading rather than off `debitCents` raw — mirrors
    // `OcptBudgetFinancing`'s own receipt sub-row.
    final debitCents = ocptBudgetEntryDebitCentsOf(
      entry,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    return SizedBox(
      height: ocptBudgetLogisticsAllowanceSubRowHeight,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left:
                    ocptBudgetLogisticsAllowanceTwistyWidth +
                    ocptBudgetLogisticsAllowanceIndentStep,
                right: 8,
              ),
              child: Row(
                children: [
                  Container(
                    width: ocptBudgetLogisticsAllowanceDotDiameter,
                    height: ocptBudgetLogisticsAllowanceDotDiameter,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
                    ),
                    child: Text(
                      tr.budgetLogisticsColumnReimbursed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          OcptBudgetCentsCell(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            cents: null,
            currencyCode: currencyCode,
            showBlank: true,
          ),
          SizedBox(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            child: Text(
              debitCents == null
                  ? ocptBudgetEmptyValue
                  : ocptBudgetAmountLabel(debitCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          OcptBudgetCentsCell(
            width: ocptBudgetLogisticsAllowanceAmountColumnWidth,
            cents: null,
            currencyCode: currencyCode,
            showBlank: true,
          ),
          const SizedBox(width: ocptBudgetLogisticsAllowanceMenuColumnWidth),
        ],
      ),
    );
  }
}
