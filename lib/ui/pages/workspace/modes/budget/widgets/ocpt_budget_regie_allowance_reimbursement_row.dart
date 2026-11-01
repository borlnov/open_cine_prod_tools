// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_cells.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One reimbursement sub-row: a dot, a `REIMBURSED` badge, the entry's own date and wording, its
/// debit printed in the `REIMBURSED` column alone — the other money cells left blank, no menu: the
/// entry itself belongs to the cash journal, not to this tree.
class OcptBudgetRegieAllowanceReimbursementRow extends StatelessWidget {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// The project's own default VAT rate, in basis points, or null while it declares none — what
  /// [entry]'s own debit is read tax-inclusive against.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetRegieAllowanceReimbursementRow({
    super.key,
    required this.entry,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

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
      height: ocptBudgetRegieAllowanceSubRowHeight,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: ocptBudgetRegieAllowanceTwistyWidth + ocptBudgetRegieAllowanceIndentStep,
                right: 8,
              ),
              child: Row(
                children: [
                  Container(
                    width: ocptBudgetRegieAllowanceDotDiameter,
                    height: ocptBudgetRegieAllowanceDotDiameter,
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
                      borderRadius: BorderRadius.circular(ocptRadiusSmall),
                    ),
                    child: Text(
                      tr.budgetRegieColumnReimbursed,
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
          ocptBudgetRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
          SizedBox(
            width: ocptBudgetRegieAllowanceAmountColumnWidth,
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
          ocptBudgetRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
          const SizedBox(width: ocptBudgetRegieAllowanceMenuColumnWidth),
        ],
      ),
    );
  }
}
