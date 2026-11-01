// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_cells.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_row_figures.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The total row: `Total · N familles`, the three totals, and — in the `Dossier` column, while the
/// project holds any in-kind resource at all — the quiet `dont {amount} valorisés` caption.
class OcptBudgetFinancingTotalRow extends StatelessWidget {
  /// How many family rows are actually drawn.
  final int familyCount;

  /// The grand total across every drawn family.
  final OcptBudgetFinancingRowFigures aggregates;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the project holds any in-kind resource at all.
  final bool hasInKind;

  /// The in-kind total, read only while [hasInKind].
  final int valuedCents;

  /// Class constructor
  const OcptBudgetFinancingTotalRow({
    super.key,
    required this.familyCount,
    required this.aggregates,
    required this.currencyCode,
    required this.hasInKind,
    required this.valuedCents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: ocptBudgetFinancingTotalRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ocptTableRowHorizontalPadding),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tr.budgetFinancingTotalRowLabel(familyCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: boldStyle,
                ),
              ),
              SizedBox(
                width: ocptBudgetFinancingDossierColumnWidth,
                child: !hasInKind
                    ? null
                    : Text(
                        tr.budgetFinancingValuedCaption(
                          ocptBudgetAmountLabel(valuedCents, currencyCode),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              ocptBudgetFinancingAmountCell(
                context,
                aggregates.promisedCents,
                currencyCode,
                style: boldStyle,
              ),
              ocptBudgetFinancingAmountCell(
                context,
                aggregates.receivedCents,
                currencyCode,
                style: boldStyle,
              ),
              ocptBudgetFinancingAmountCell(
                context,
                aggregates.outstandingCents,
                currencyCode,
                style: boldStyle,
              ),
              const SizedBox(width: ocptBudgetFinancingMenuColumnWidth),
            ],
          ),
        ),
      ),
    );
  }
}
