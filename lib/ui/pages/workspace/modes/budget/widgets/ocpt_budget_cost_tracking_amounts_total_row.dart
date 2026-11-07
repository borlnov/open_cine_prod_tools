// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_identity_total_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The scrolling pane's own total row: the grand `Devis` total (with its own coverage read-out) and
/// the grand `Payé` total — [paidTotal], [ocptBudgetCoveredTotalsFoldOf]'s own fold of every
/// account's own paid total and the off-quote total (`OcptBudgetCostTracking`'s own class doc
/// comment), so this column adds up to what has actually left the account, off-quote spending
/// included. `Engagé`, `Reste` and `Écart` are left blank: summing `committedCentsOf` across every
/// account is not a reduction this table has a reading for (a commitment is always against an
/// account, so there is no off-quote committed total to fold in), and `Reste`/`Écart` are each read
/// against an account's own quote, which a grand total has none of.
///
/// `Coût final` is the exception: [finalCostCents] **is** a grand total, computed by
/// `OcptBudgetCostTracking._finalCostTotalOf` account by account and only then summed — a typed
/// estimate to complete on one account is a fact this widget cannot reconstruct from any of the
/// other grand totals it already holds, so the caller resolves it row by row rather than this row
/// re-deriving it from `total`/`paidTotal`. See [OcptBudgetCostTrackingIdentityTotalRow]'s own doc
/// comment for the pinned half of the very same row.
class OcptBudgetCostTrackingAmountsTotalRow extends StatelessWidget {
  /// The grand total, in the header's own selected basis, and how many lines it covers.
  final OcptBudgetCoveredTotal total;

  /// The grand `Payé` total — every account's own paid total folded with the off-quote total.
  final OcptBudgetCoveredTotal paidTotal;

  /// The grand `Coût final` total — see the class doc comment for why this is summed account by
  /// account rather than derived from [total]/[paidTotal].
  final int finalCostCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The total number of live accounts.
  final int accountCount;

  /// How many of them count as covered — every one of their own lines is.
  final int coveredAccountCount;

  /// Class constructor
  const OcptBudgetCostTrackingAmountsTotalRow({
    super.key,
    required this.total,
    required this.paidTotal,
    required this.finalCostCents,
    required this.currencyCode,
    required this.accountCount,
    required this.coveredAccountCount,
  });

  /// Build the budget cost tracking amounts total row as a [DecoratedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final amountText = ocptBudgetAmountLabel(total.amountCents, currencyCode);
    final coverageText = total.isComplete
        ? null
        : tr.budgetCostTrackingCoverageReadOut(amountText, coveredAccountCount, accountCount);
    final paidAmountText = ocptBudgetAmountLabel(paidTotal.amountCents, currencyCode);
    final paidCoverageText = paidTotal.isComplete
        ? null
        : tr.budgetCostTrackingPaidCoverageReadOut(
            paidAmountText,
            paidTotal.coveredLineCount,
            paidTotal.lineCount,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: ocptBudgetCostTrackingTotalRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              child: Text(
                coverageText ?? amountText,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              child: Text(
                ocptBudgetEmptyValue,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ), // Engagé
            SizedBox(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              child: Text(
                paidCoverageText ?? paidAmountText,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              child: Text(
                ocptBudgetEmptyValue,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ), // Reste
            SizedBox(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(finalCostCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: ocptBudgetCostTrackingAmountColumnWidth,
              child: Text(
                ocptBudgetEmptyValue,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ), // Écart
            const SizedBox(width: ocptBudgetCostTrackingMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}
