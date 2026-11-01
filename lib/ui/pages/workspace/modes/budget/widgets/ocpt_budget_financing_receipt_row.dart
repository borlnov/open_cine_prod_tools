// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_cells.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// A receipt sub-row: a dot, a `Rentré` badge, the entry's own date and wording, its amount printed
/// in the `Rentré` column alone — the other money cells left blank, no `Dossier` cell, no menu.
class OcptBudgetFinancingReceiptRow extends StatelessWidget {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// The project's own default VAT rate, in basis points, or null while it declares none — what
  /// [entry]'s own credit is read tax-inclusive against.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this receipt is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const OcptBudgetFinancingReceiptRow({
    super.key,
    required this.entry,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final dateText = DateFormat.yMd().format(entry.date);
    final label = entry.label.isEmpty ? dateText : "$dateText · ${entry.label}";
    // Read exactly the way the `Rentré` column above it is — tax-inclusive, through the journal's
    // own reading rather than off `creditCents` raw — so a sub-row can never disagree with the
    // total it sits under, and an entry whose rate is unknown prints the same em dash everywhere.
    final creditCents = ocptBudgetEntryCreditCentsOf(
      entry,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: ocptBudgetFinancingReceiptRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: ocptBudgetFinancingTwistyWidth + ocptBudgetFinancingIndentStep * 2,
                      right: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: ocptBudgetFinancingDotDiameter,
                          height: ocptBudgetFinancingDotDiameter,
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
                            tr.budgetFinancingColumnReceived,
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
                const SizedBox(width: ocptBudgetFinancingDossierColumnWidth),
                ocptBudgetFinancingAmountCell(context, null, currencyCode, showBlank: true),
                SizedBox(
                  width: ocptBudgetFinancingAmountColumnWidth,
                  child: Text(
                    creditCents == null
                        ? ocptBudgetEmptyValue
                        : ocptBudgetAmountLabel(creditCents, currencyCode),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                ocptBudgetFinancingAmountCell(context, null, currencyCode, showBlank: true),
                const SizedBox(width: ocptBudgetFinancingMenuColumnWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
