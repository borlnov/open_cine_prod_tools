// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_projection.dart';

/// The height of one projection step's own bar, in logical pixels — mirrors
/// `OcptBudgetDashboard`'s own `_ocptDashboardBarHeight`, the very constant
/// `OcptBudgetCommittedSpending`'s own copy of this widget used to carry.
const double _ocptCashProjectionBarHeight = 6;

/// The `Due date` column's own fixed width, in logical pixels — matches
/// `OcptBudgetCommittedSpending`'s own `Due date` column, the same figure read the same width.
const double _ocptCashProjectionDueDateColumnWidth = 92;

/// The balance column's own fixed width, in logical pixels.
const double _ocptCashProjectionAmountColumnWidth = 108;

/// The budget mode's cash projection: a collapsible card, re-homed here from the committed-spending
/// sub-page (`docs/architecture/budget.md`'s own "What is promised is one place, read in two
/// directions") into `OcptBudgetHeader`'s own alerts band, on `OcptBudgetDocument.expenses` alone
/// and only while the project carries at least one unsettled commitment — the header decides both,
/// this widget only ever draws what it is handed.
///
/// **Reads `ocptBudgetProjectionOf` and every rule it already states**, unchanged: [commitments] is
/// handed in whole, not pre-filtered to the unsettled ones, since a settled commitment is excluded
/// there, not re-excluded here (that function's own doc comment).
///
/// **Starts collapsed**, showing one summary line — the balance the projection opens at and the one
/// it ends on — and reveals its own steps once expanded. Collapsed or expanded is local, transient
/// widget state: it writes nothing to the project and nothing to `OcptBudgetState`, so a
/// [StatefulWidget] with no bloc event behind it is the right tool, exactly as
/// `_OcptCashJournalVoucherMarker`'s own class doc comment argues for asking a question once rather
/// than from every `build`.
///
/// **Writes nothing at all**, so it carries no `isReadOnly` flag and draws identically under a
/// previewed version — the very reading `OcptBudgetHelp` and the alert cards beside it already
/// give: a card that only reads is never withheld.
class OcptBudgetCashProjection extends StatefulWidget {
  /// The cash journal's own balance — `OcptBudgetCashTotals.balanceCents` — the figure the
  /// projection opens at.
  final int openingBalanceCents;

  /// Every live commitment of the project, settled ones included — see the class doc comment for
  /// why this is never pre-filtered.
  final List<OcptBudgetCommitment> commitments;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetCashProjection({
    super.key,
    required this.openingBalanceCents,
    required this.commitments,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

  @override
  State<OcptBudgetCashProjection> createState() => _OcptBudgetCashProjectionState();
}

/// The state of [OcptBudgetCashProjection]: whether the card is currently expanded — see the class
/// doc comment for why this lives here rather than in `OcptBudgetState`.
class _OcptBudgetCashProjectionState extends State<OcptBudgetCashProjection> {
  /// Whether the card currently shows its own steps, past the summary line.
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final projection = ocptBudgetProjectionOf(
      openingBalanceCents: widget.openingBalanceCents,
      commitments: widget.commitments,
      projectVatRateBasisPoints: widget.defaultVatRateBasisPoints,
    );
    final isNegative = projection.finalBalanceCents < 0;
    final isComplete = projection.coveredCommitmentCount == projection.commitmentCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key("ocptBudgetCashProjectionToggle"),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            mouseCursor: ocptClickableCursor,
            borderRadius: BorderRadius.circular(ocptRadiusSmall),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.show_chart, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr.budgetCommittedProjectionTitle,
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        tr.budgetCommittedProjectionCollapsedSummary(
                          ocptBudgetAmountLabel(projection.openingBalanceCents, widget.currencyCode),
                          ocptBudgetAmountLabel(projection.finalBalanceCents, widget.currencyCode),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isNegative ? theme.colorScheme.error : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            Text(
              tr.budgetCommittedProjectionHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (projection.steps.isEmpty)
              Text(
                tr.budgetCommittedProjectionNoStepsHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              _OcptCashProjectionSteps(steps: projection.steps, currencyCode: widget.currencyCode),
            const SizedBox(height: 6),
            Text(
              isComplete
                  ? tr.budgetCommittedProjectionFooterHint
                  : tr.budgetCommittedProjectionCoverageReadOut(
                      projection.coveredCommitmentCount,
                      projection.commitmentCount,
                    ),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// The card's own list of steps, once expanded — `OcptBudgetCommittedSpending`'s own former
/// `_OcptCommittedProjectionSteps`, moved here with it: a plain [Column] rather than a [ListView],
/// since this card sits in an unconstrained alerts band rather than a pane with a height of its own
/// to scroll inside.
class _OcptCashProjectionSteps extends StatelessWidget {
  /// The steps to draw, in [OcptBudgetProjection.steps]' own order.
  final List<OcptBudgetProjectionStep> steps;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCashProjectionSteps({required this.steps, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final maxAbsBalanceCents = steps.fold(0, (max, step) {
      final absValue = step.balanceAfterCents.abs();
      return absValue > max ? absValue : max;
    });

    return Column(
      children: [
        for (final step in steps)
          _OcptCashProjectionStepRow(
            step: step,
            maxAbsBalanceCents: maxAbsBalanceCents,
            currencyCode: currencyCode,
          ),
      ],
    );
  }
}

/// One projection step: its own due date, a bar scaled against [maxAbsBalanceCents], and the
/// balance left once it has fallen due — reading visibly differently, from the theme, the moment
/// that balance goes negative. `OcptBudgetCommittedSpending`'s own former
/// `_OcptCommittedProjectionStepRow`, moved here with it.
class _OcptCashProjectionStepRow extends StatelessWidget {
  /// The step this row draws.
  final OcptBudgetProjectionStep step;

  /// The largest absolute [OcptBudgetProjectionStep.balanceAfterCents] of the whole list this
  /// step's own bar is scaled against.
  final int maxAbsBalanceCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptCashProjectionStepRow({
    required this.step,
    required this.maxAbsBalanceCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dueDate = step.dueDate;
    final isNegative = step.balanceAfterCents < 0;
    final ratio = maxAbsBalanceCents <= 0
        ? 0.0
        : (step.balanceAfterCents.abs() / maxAbsBalanceCents).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: _ocptCashProjectionDueDateColumnWidth,
            child: Text(
              dueDate == null ? tr.budgetCommittedNoDueDateLabel : DateFormat.yMMMd(locale).format(dueDate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: dueDate == null ? theme.colorScheme.onSurfaceVariant : null,
                fontStyle: dueDate == null ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_ocptCashProjectionBarHeight / 2),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: _ocptCashProjectionBarHeight,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  isNegative ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _ocptCashProjectionAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(step.balanceAfterCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isNegative ? theme.colorScheme.error : null,
                fontWeight: isNegative ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
