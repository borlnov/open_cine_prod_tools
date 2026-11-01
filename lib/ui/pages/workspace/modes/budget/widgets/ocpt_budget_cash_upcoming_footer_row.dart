// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_projection_step.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The `À venir` section's own footer, in the mockup's own tinted style: [totalDueCents] under the
/// `Debit` column, past a label spanning the leading ones, and [projectedBalanceCents]
/// ([OcptBudgetProjection.finalBalanceCents]) under `Balance`, printing in [ColorScheme.error] once
/// it goes negative — the one figure of this page that reads the account's future rather than its
/// past, which is exactly why it is worth a tint of its own.
class OcptBudgetCashUpcomingFooterRow extends StatelessWidget {
  /// The sum of every step's own [OcptBudgetProjectionStep.amountCents] — what falls due once
  /// every `À venir` row has.
  final int totalDueCents;

  /// The balance the account would hold once every `À venir` row has fallen due —
  /// [OcptBudgetProjection.finalBalanceCents].
  final int projectedBalanceCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetCashUpcomingFooterRow({
    super.key,
    required this.totalDueCents,
    required this.projectedBalanceCents,
    required this.currencyCode,
  });

  /// Build the budget cash upcoming footer row as a [DecoratedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isNegative = projectedBalanceCents < 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: ocptBudgetCashJournalRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr.budgetCashUpcomingProjectedBalanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: ocptBudgetCashJournalAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(totalDueCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: ocptBudgetCashJournalAmountColumnWidth),
            SizedBox(
              width: ocptBudgetCashJournalAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(projectedBalanceCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isNegative ? theme.colorScheme.error : null,
                ),
              ),
            ),
            const SizedBox(width: ocptBudgetCashJournalMenuColumnWidth),
          ],
        ),
      ),
    );
  }
}
