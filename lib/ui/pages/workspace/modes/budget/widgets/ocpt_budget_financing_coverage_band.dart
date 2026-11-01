// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_resources_coverage.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The coverage band, under everything: `Le film coûte` and the quote's own total on the left, a
/// two-tone bar and a sentence in the middle, and an action back to the expenses document on the
/// right.
///
/// **Draws only while [OcptBudgetResourcesCoverage.needs] holds something** — `OcptBudgetFinancing`
/// itself withholds this widget entirely while the quote is empty, the same reading the cash
/// projection card already follows.
class OcptBudgetFinancingCoverageBand extends StatelessWidget {
  /// What the band reads — never computed here, always `ocptBudgetResourcesCoverageOf`'s own
  /// answer.
  final OcptBudgetResourcesCoverage coverage;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the band's own action is clicked.
  final VoidCallback onExpensesRequested;

  /// Class constructor
  const OcptBudgetFinancingCoverageBand({
    super.key,
    required this.coverage,
    required this.currencyCode,
    required this.onExpensesRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final needs = coverage.needs;
    final needsAmount = ocptBudgetAmountLabel(needs.amountCents, currencyCode);
    final needsText = needs.isComplete
        ? needsAmount
        : tr.budgetDashboardBalanceCoverageReadOut(
            needsAmount,
            needs.coveredLineCount,
            needs.lineCount,
          );

    final receivedFraction = needs.amountCents <= 0
        ? (coverage.received.amountCents > 0 ? 1.0 : 0.0)
        : (coverage.received.amountCents / needs.amountCents).clamp(0.0, 1.0);
    final plannedFraction = needs.amountCents <= 0
        ? (coverage.plannedCents > 0 ? 1.0 : 0.0)
        : (coverage.plannedCents / needs.amountCents).clamp(0.0, 1.0);

    final receivedAmount = ocptBudgetAmountLabel(coverage.received.amountCents, currencyCode);
    final promisedAmount = ocptBudgetAmountLabel(coverage.promisedCents, currencyCode);
    final suffixColor = coverage.isCovered
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.error;
    final suffixText = coverage.isCovered
        ? tr.budgetFinancingCoverageCoveredReadOut
        : tr.budgetFinancingCoverageMissingReadOut(
            ocptBudgetAmountLabel(coverage.missingCents, currencyCode),
          );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: ocptBudgetFinancingCoverageNeedsColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr.budgetFinancingCoverageTitle.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(needsText, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          ocptBudgetFinancingCoverageBarHeight / 2,
                        ),
                        child: SizedBox(
                          height: ocptBudgetFinancingCoverageBarHeight,
                          child: ColoredBox(color: theme.colorScheme.surfaceContainerHigh),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          ocptBudgetFinancingCoverageBarHeight / 2,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: plannedFraction,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: ocptBudgetFinancingCoverageBarHeight,
                            child: ColoredBox(
                              color: theme.colorScheme.primary.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          ocptBudgetFinancingCoverageBarHeight / 2,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: receivedFraction,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: ocptBudgetFinancingCoverageBarHeight,
                            child: ColoredBox(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: tr.budgetFinancingCoverageReadOut(receivedAmount, promisedAmount),
                        ),
                        const TextSpan(text: " · "),
                        TextSpan(
                          text: suffixText,
                          style: TextStyle(
                            color: suffixColor,
                            fontWeight: coverage.isCovered ? null : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            OutlinedButton(
              onPressed: onExpensesRequested,
              child: Text(tr.budgetFinancingCoverageExpensesAction),
            ),
          ],
        ),
      ),
    );
  }
}
