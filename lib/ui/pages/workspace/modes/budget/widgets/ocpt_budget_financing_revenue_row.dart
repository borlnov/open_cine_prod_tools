// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cents_cell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_resource_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_revenue_status_pill.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_row_figures.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_twisty.dart';

/// One revenue row: mirrors [OcptBudgetFinancingResourceRow], its own `⋮` menu offering `Edit` /
/// `Record a receipt` / `Move up` / `Move down` / `Delete` instead.
class OcptBudgetFinancingRevenueRow extends StatelessWidget {
  /// The revenue this row draws.
  final OcptBudgetRevenue revenue;

  /// This revenue's own figures.
  final OcptBudgetFinancingRowFigures figures;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this revenue is the currently selected one.
  final bool isSelected;

  /// Whether this revenue has at least one receipt to expand onto.
  final bool isExpandable;

  /// Whether this revenue is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback? onTwistyTap;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Called when this row's own `⋮` menu asks to edit it, or null while withheld.
  final VoidCallback? onEditRequested;

  /// Called when this row's own `⋮` menu asks to record a receipt against it, or null while
  /// withheld.
  final VoidCallback? onReceiptRequested;

  /// Called when this row's own `⋮` menu asks to move it up, or null while withheld (including
  /// while already first).
  final VoidCallback? onMoveUpRequested;

  /// Called when this row's own `⋮` menu asks to move it down, or null while withheld (including
  /// while already last).
  final VoidCallback? onMoveDownRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const OcptBudgetFinancingRevenueRow({
    super.key,
    required this.revenue,
    required this.figures,
    required this.currencyCode,
    required this.isSelected,
    required this.isExpandable,
    required this.isExpanded,
    required this.onTwistyTap,
    required this.onTap,
    required this.onEditRequested,
    required this.onReceiptRequested,
    required this.onMoveUpRequested,
    required this.onMoveDownRequested,
    required this.onDeletionRequested,
  });

  /// Build the budget financing revenue row as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final hasMenu =
        onEditRequested != null ||
        onReceiptRequested != null ||
        onMoveUpRequested != null ||
        onMoveDownRequested != null ||
        onDeletionRequested != null;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: ocptBudgetFinancingRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ocpt_theme.ocptTableRowHorizontalPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: ocptBudgetFinancingIndentStep, right: 8),
                    child: Row(
                      children: [
                        OcptBudgetTwisty(
                          width: ocptBudgetFinancingTwistyWidth,
                          isExpandable: isExpandable,
                          isExpanded: isExpanded,
                          onTap: onTwistyTap,
                          rowHeight: ocptBudgetFinancingRowHeight,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                revenue.label.isEmpty ? tr.budgetAccountUnnamed : revenue.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (revenue.notes.isNotEmpty)
                                Text(
                                  revenue.notes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: ocptBudgetFinancingDossierColumnWidth,
                  child: OcptBudgetFinancingRevenueStatusPill(status: revenue.status),
                ),
                OcptBudgetCentsCell(
                  width: ocptBudgetFinancingAmountColumnWidth,
                  cents: figures.promisedCents,
                  currencyCode: currencyCode,
                ),
                OcptBudgetCentsCell(
                  width: ocptBudgetFinancingAmountColumnWidth,
                  cents: figures.receivedCents,
                  currencyCode: currencyCode,
                ),
                OcptBudgetCentsCell(
                  width: ocptBudgetFinancingAmountColumnWidth,
                  cents: figures.outstandingCents,
                  currencyCode: currencyCode,
                ),
                SizedBox(
                  width: ocptBudgetFinancingMenuColumnWidth,
                  child: !hasMenu
                      ? null
                      : PopupMenuButton<String>(
                          tooltip: "",
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (value) => switch (value) {
                            "edit" => onEditRequested?.call(),
                            "receipt" => onReceiptRequested?.call(),
                            "up" => onMoveUpRequested?.call(),
                            "down" => onMoveDownRequested?.call(),
                            "delete" => onDeletionRequested?.call(),
                            _ => null,
                          },
                          itemBuilder: (context) => [
                            if (onEditRequested != null)
                              PopupMenuItem<String>(
                                value: "edit",
                                child: Text(tr.budgetFinancingEditAction),
                              ),
                            if (onReceiptRequested != null)
                              PopupMenuItem<String>(
                                value: "receipt",
                                child: Text(tr.budgetFinancingRecordReceiptAction),
                              ),
                            if (onMoveUpRequested != null)
                              PopupMenuItem<String>(
                                value: "up",
                                child: Text(tr.budgetAccountMoveUpAction),
                              ),
                            if (onMoveDownRequested != null)
                              PopupMenuItem<String>(
                                value: "down",
                                child: Text(tr.budgetAccountMoveDownAction),
                              ),
                            if (onDeletionRequested != null)
                              PopupMenuItem<String>(
                                value: "delete",
                                child: Text(tr.budgetCommittedDeleteAction),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
