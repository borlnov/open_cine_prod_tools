// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_tree.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// A quote line's own six amount cells — [OcptBudgetCostTracking]'s own class doc comment argues
/// why `Engagé`/`Payé` are read through
/// [ocptBudgetLineCommittedTotalOf]/[ocptBudgetLinePaidTotalOf] and why the estimate to complete
/// behind `Coût final` is always derived here.
///
/// **A counterpart line** (`OcptBudgetLine.inKindResourceId` not null) **reads its own `Engagé`
/// and `Payé` as [ocptBudgetEmptyValue], never the real (and always zero) totals those two
/// functions would otherwise answer** — a valuation is neither committed nor paid, so the em dash
/// is what tells the reader it is covered in kind rather than merely untouched. `Reste` still
/// reads a real zero, folding the line's own quoted total in as its own in-kind covered figure.
class OcptBudgetCostTrackingLineAmountsRow extends StatelessWidget {
  /// The line this row shows.
  final OcptBudgetLine line;

  /// This line's own commitments, settled or not.
  final List<OcptBudgetCommitment> lineCommitments;

  /// Every live entry of the project — searched for the one settling each of [lineCommitments]'
  /// own settled commitments.
  final List<OcptBudgetEntry> entries;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this line is the currently selected one.
  final bool isSelected;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const OcptBudgetCostTrackingLineAmountsRow({
    super.key,
    required this.line,
    required this.lineCommitments,
    required this.entries,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.isSelected,
    required this.onTap,
  });

  /// Build the budget cost tracking line amounts row as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quoted = ocptBudgetTotalOf(
      [line],
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final committed = ocptBudgetLineCommittedTotalOf(
      lineCommitments,
      entries: entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paid = ocptBudgetLinePaidTotalOf(
      lineCommitments,
      entries: entries,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    // This line's own in-kind covered figure: its own quoted total while it is itself a
    // counterpart line ([OcptBudgetLine.inKindResourceId] not null), zero otherwise. A counterpart
    // line is never paid or committed, so without this it would read as its own full quoted amount
    // still outstanding — [quoted.amountCents] is safe to reuse verbatim here rather than reaching
    // for `ocptBudgetLineTotalCents` again, since a counterpart line is frozen at 0 % VAT and so
    // reads the same figure whichever basis [quoted] itself was resolved in.
    final isInKindCounterpart = line.inKindResourceId != null;
    final inKindCoveredCents = isInKindCounterpart ? quoted.amountCents : 0;
    // A line carries no estimate to complete of its own — always derived, never typed
    // (`docs/architecture/budget.md`).
    final estimateToCompleteCents = ocptBudgetEstimateToCompleteCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paid.amountCents,
      committedCents: committed.amountCents,
      inKindCoveredCents: inKindCoveredCents,
      typedEstimateToCompleteCents: null,
    );
    final finalCostCents = ocptBudgetFinalCostCents(
      paidCents: paid.amountCents,
      committedCents: committed.amountCents,
      estimateToCompleteCents: estimateToCompleteCents,
    );
    final remainingCents = ocptBudgetRemainingCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paid.amountCents,
      committedCents: committed.amountCents,
      inKindCoveredCents: inKindCoveredCents,
    );
    final varianceCents = ocptBudgetVarianceCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paid.amountCents,
      committedCents: committed.amountCents,
      inKindCoveredCents: inKindCoveredCents,
    );

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
            : Colors.transparent,
        child: SizedBox(
          // A quote line is a full-height row, not a sub-row: the pinned pane draws its own half
          // at [ocptBudgetCostTrackingRowHeight] (`isSmall: false`), and the two panes have to
          // agree row for row or every row below an expanded account drifts out of step with its
          // own figures — see this widget's own class doc comment.
          height: ocptBudgetCostTrackingRowHeight,
          child: Row(
            children: [
              _cell(context, ocptBudgetAmountLabel(quoted.amountCents, currencyCode)),
              // A counterpart line is never committed nor paid — the em dash, rather than the
              // real (and always zero) `committed`/`paid` totals, is what reads it as covered
              // in kind instead of merely untouched (`docs/architecture/budget.md`).
              _cell(
                context,
                isInKindCounterpart
                    ? ocptBudgetEmptyValue
                    : ocptBudgetAmountLabel(committed.amountCents, currencyCode),
              ),
              _cell(
                context,
                isInKindCounterpart
                    ? ocptBudgetEmptyValue
                    : ocptBudgetAmountLabel(paid.amountCents, currencyCode),
              ),
              _cell(context, ocptBudgetAmountLabel(remainingCents, currencyCode)),
              _cell(context, ocptBudgetAmountLabel(finalCostCents, currencyCode)),
              _cell(context, ocptBudgetAmountLabel(varianceCents, currencyCode)),
              const SizedBox(width: ocptBudgetCostTrackingMenuColumnWidth),
            ],
          ),
        ),
      ),
    );
  }

  /// Build one amount cell, right-aligned, one step smaller than an account row's own.
  Widget _cell(BuildContext context, String text) => SizedBox(
    width: ocptBudgetCostTrackingAmountColumnWidth,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall,
    ),
  );
}
