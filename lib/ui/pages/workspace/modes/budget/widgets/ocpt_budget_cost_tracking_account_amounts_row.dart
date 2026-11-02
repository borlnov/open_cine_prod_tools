// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_account_identity_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_quote_cell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_remaining_cell.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The scrolling pane's own row: one poste's six amount cells and its own `⋮` menu — see
/// [OcptBudgetCostTrackingPosteIdentityRow]'s own doc comment for why it shares [isSelected] and
/// [onTap] with the pinned half of the very same row.
class OcptBudgetCostTrackingPosteAmountsRow extends StatelessWidget {
  /// The poste this row shows.
  final OcptBudgetPoste poste;

  /// Whether this poste is the currently selected one.
  final bool isSelected;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// This poste's own paid total, in cents.
  final int paidCents;

  /// This poste's own committed total, in cents.
  final int committedCents;

  /// This poste's own in-kind covered total, in cents.
  final int inKindCoveredCents;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Called when the row's own `⋮` menu asks to rename this poste, or null while withheld.
  final VoidCallback? onRenameRequested;

  /// Called when the row's own `⋮` menu asks to move this poste up, or null while withheld.
  final VoidCallback? onMoveUpRequested;

  /// Called when the row's own `⋮` menu asks to move this poste down, or null while withheld.
  final VoidCallback? onMoveDownRequested;

  /// Called when the row's own `⋮` menu asks to delete this poste, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Called when the row's own `⋮` menu asks to narrow the mode to this poste, or null while
  /// withheld — never gated on a read-only preview, unlike every other callback here (see
  /// `OcptBudgetCostTracking.onPosteFilterRequested`'s own doc comment).
  final VoidCallback? onFilterRequested;

  /// Class constructor
  const OcptBudgetCostTrackingPosteAmountsRow({
    super.key,
    required this.poste,
    required this.isSelected,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.paidCents,
    required this.committedCents,
    required this.inKindCoveredCents,
    required this.onTap,
    required this.onRenameRequested,
    required this.onMoveUpRequested,
    required this.onMoveDownRequested,
    required this.onDeletionRequested,
    required this.onFilterRequested,
  });

  /// Build the budget cost tracking poste amounts row as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final secondaryBasis = taxBasis == OcptBudgetTaxBasis.includingTax
        ? OcptBudgetTaxBasis.excludingTax
        : OcptBudgetTaxBasis.includingTax;
    final secondary = ocptBudgetTotalOf(
      poste.lines,
      basis: secondaryBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final uniformRate = ocptBudgetPosteUniformVatRateOf(
      poste.lines,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    // Resolved once per row, not once per cell, so no two cells reading the resolved estimate to
    // complete can ever disagree about which figure — derived or typed — they are both reading.
    final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
      inKindCoveredCents: inKindCoveredCents,
      typedEstimateToCompleteCents: poste.estimateToCompleteCents,
    );
    final finalCostCents = ocptBudgetFinalCostCents(
      paidCents: paidCents,
      committedCents: committedCents,
      estimateToCompleteCents: estimateToCompleteCents,
    );

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          height: ocptBudgetCostTrackingRowHeight,
          child: Row(
            children: [
              SizedBox(
                width: ocptBudgetCostTrackingAmountColumnWidth,
                child: OcptBudgetCostTrackingQuoteCell(
                  primaryCents: quoted.amountCents,
                  secondaryCents: secondary.coveredLineCount == 0 ? null : secondary.amountCents,
                  uniformRate: uniformRate,
                  currencyCode: currencyCode,
                ),
              ),
              _amountCell(context, ocptBudgetAmountLabel(committedCents, currencyCode)),
              _amountCell(context, ocptBudgetAmountLabel(paidCents, currencyCode)),
              SizedBox(
                width: ocptBudgetCostTrackingAmountColumnWidth,
                child: OcptBudgetCostTrackingRemainingCell(
                  remainingCents: ocptBudgetRemainingCents(
                    quotedAmountCents: quoted.amountCents,
                    paidCents: paidCents,
                    committedCents: committedCents,
                    inKindCoveredCents: inKindCoveredCents,
                  ),
                  inKindCoveredCents: inKindCoveredCents,
                  currencyCode: currencyCode,
                ),
              ),
              _amountCell(context, ocptBudgetAmountLabel(finalCostCents, currencyCode)),
              _amountCell(
                context,
                ocptBudgetAmountLabel(
                  ocptBudgetVarianceCents(
                    quotedAmountCents: quoted.amountCents,
                    paidCents: paidCents,
                    committedCents: committedCents,
                    inKindCoveredCents: inKindCoveredCents,
                  ),
                  currencyCode,
                ),
              ),
              SizedBox(
                width: ocptBudgetCostTrackingMenuColumnWidth,
                child:
                    (onRenameRequested == null &&
                        onMoveUpRequested == null &&
                        onMoveDownRequested == null &&
                        onDeletionRequested == null &&
                        onFilterRequested == null)
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: "",
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (value) => switch (value) {
                          "rename" => onRenameRequested?.call(),
                          "up" => onMoveUpRequested?.call(),
                          "down" => onMoveDownRequested?.call(),
                          "delete" => onDeletionRequested?.call(),
                          "filter" => onFilterRequested?.call(),
                          _ => null,
                        },
                        itemBuilder: (context) => [
                          if (onRenameRequested != null)
                            PopupMenuItem<String>(
                              value: "rename",
                              child: Text(tr.budgetPosteRenameAction),
                            ),
                          if (onMoveUpRequested != null)
                            PopupMenuItem<String>(
                              value: "up",
                              child: Text(tr.budgetPosteMoveUpAction),
                            ),
                          if (onMoveDownRequested != null)
                            PopupMenuItem<String>(
                              value: "down",
                              child: Text(tr.budgetPosteMoveDownAction),
                            ),
                          if (onFilterRequested != null)
                            PopupMenuItem<String>(
                              value: "filter",
                              child: Text(tr.budgetCostTrackingFilterOnlyAction),
                            ),
                          if (onDeletionRequested != null)
                            PopupMenuItem<String>(
                              value: "delete",
                              child: Text(tr.budgetPosteDeleteAction),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build one amount cell, right-aligned.
  Widget _amountCell(BuildContext context, String text) => SizedBox(
    width: ocptBudgetCostTrackingAmountColumnWidth,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}
