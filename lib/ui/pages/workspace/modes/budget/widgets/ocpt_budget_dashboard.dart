// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The height of a poste's own share bar, in logical pixels.
const double _ocptDashboardBarHeight = 6;

/// The budget mode's own dashboard: its own two alerts above the KPI row, then the quote read
/// poste by poste, each with its own share of the total.
///
/// **Nothing here may claim a figure the data cannot support** (`docs/plans/budget-mode.md` §5):
/// no needs/resources balance bar (M3), no "what feeds this budget" card (M3) — those arrive with
/// the milestones that give them content, exactly as this view itself becomes the mockup's full
/// dashboard once they do. Purely computed, like `OcptBreakdownRecapTable`: a poste's click only
/// selects it, which writes nothing, so this needs no `isReadOnly` flag at all.
///
/// [alerts] — [ocptComputeBudgetAlerts]'s own answer, carried by the state rather than recomputed
/// here — draws **no empty section at all** while it is empty: a project raising neither alert
/// shows nothing above its KPI row, exactly as a project with no poste shows no dashboard at all.
class OcptBudgetDashboard extends StatelessWidget {
  /// Every live poste, in display order.
  final List<OcptBudgetPoste> postes;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The cash journal's own debit, credit and balance — the `Cash balance` KPI's own figure.
  final OcptBudgetCashTotals cashTotals;

  /// What has actually been paid against each poste, keyed by its own id — the `Paid` KPI's own
  /// figure, summed across every poste rather than recomputed.
  final Map<String, OcptBudgetCoveredTotal> paidByPosteId;

  /// What is committed against each poste, keyed by its own id — the `Committed` KPI's own
  /// figure, summed across every poste rather than recomputed.
  final Map<String, OcptBudgetCoveredTotal> committedByPosteId;

  /// The dashboard's own two alerts, computed once by [ocptComputeBudgetAlerts] and carried here
  /// by the state — see the class doc comment.
  final List<OcptBudgetAlert> alerts;

  /// Called with a poste's id when its own row is clicked, opening the `Inspector` tab on it.
  final ValueChanged<String> onPosteSelected;

  /// Called with a poste's id when an [OcptBudgetPosteOverQuoteAlert]'s own action is clicked —
  /// selects the poste **and** switches to the cost-tracking view, unlike [onPosteSelected] alone.
  final ValueChanged<String> onPosteAlertActionRequested;

  /// Called when the [OcptBudgetCashProjectionNegativeAlert]'s own action is clicked, switching to
  /// the committed view.
  final VoidCallback onCashAlertActionRequested;

  /// Class constructor
  const OcptBudgetDashboard({
    super.key,
    required this.postes,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.cashTotals,
    required this.paidByPosteId,
    required this.committedByPosteId,
    required this.alerts,
    required this.onPosteSelected,
    required this.onPosteAlertActionRequested,
    required this.onCashAlertActionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    if (postes.isEmpty) {
      return OcptWorkspaceEmptyMode(icon: Icons.payments_outlined, message: tr.budgetDashboardEmptyHint);
    }

    final allLines = [for (final poste in postes) ...poste.lines];
    final quotedTotal = ocptBudgetTotalOf(
      allLines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final excludingTaxTotal = ocptBudgetExcludingTaxTotalOf(
      allLines,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final lineCount = allLines.length;
    final paidTotal = _ocptFoldCoveredTotals(paidByPosteId.values);
    final committedTotal = _ocptFoldCoveredTotals(committedByPosteId.values);

    final posteAmounts = {
      for (final poste in postes)
        poste.id: ocptBudgetTotalOf(
          poste.lines,
          basis: taxBasis,
          projectVatRateBasisPoints: defaultVatRateBasisPoints,
        ).amountCents,
    };
    final maxPosteAmount = posteAmounts.values.fold(0, (a, b) => a > b ? a : b);
    final orderedPostes = [...postes]
      ..sort((a, b) => (posteAmounts[b.id] ?? 0).compareTo(posteAmounts[a.id] ?? 0));
    final posteLabelById = {for (final poste in postes) poste.id: poste.label};

    return ListView(
      children: [
        for (final alert in alerts) ...[
          _buildAlertCard(context, tr, alert, posteLabelById),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _OcptDashboardKpi(
                label: tr.budgetDashboardQuotedTotalLabel,
                value: ocptBudgetAmountLabel(quotedTotal.amountCents, currencyCode),
              ),
              _OcptDashboardKpi(
                label: tr.budgetDashboardExcludingTaxTotalLabel,
                value: ocptBudgetAmountLabel(excludingTaxTotal.amountCents, currencyCode),
                caption: excludingTaxTotal.isComplete
                    ? null
                    : tr.budgetDashboardCoverageCaption(
                        excludingTaxTotal.coveredLineCount,
                        excludingTaxTotal.lineCount,
                      ),
              ),
              _OcptDashboardKpi(
                label: tr.budgetDashboardCashBalanceLabel,
                value: ocptBudgetAmountLabel(cashTotals.balanceCents, currencyCode),
                caption: cashTotals.isComplete
                    ? null
                    : tr.budgetDashboardCoverageCaption(
                        cashTotals.coveredEntryCount,
                        cashTotals.entryCount,
                      ),
              ),
              _OcptDashboardKpi(
                label: tr.budgetDashboardPaidLabel,
                value: ocptBudgetAmountLabel(paidTotal.amountCents, currencyCode),
                caption: paidTotal.isComplete
                    ? null
                    : tr.budgetDashboardCoverageCaption(paidTotal.coveredLineCount, paidTotal.lineCount),
              ),
              _OcptDashboardKpi(
                label: tr.budgetDashboardCommittedLabel,
                value: ocptBudgetAmountLabel(committedTotal.amountCents, currencyCode),
                caption: committedTotal.isComplete
                    ? null
                    : tr.budgetDashboardCoverageCaption(
                        committedTotal.coveredLineCount,
                        committedTotal.lineCount,
                      ),
              ),
              _OcptDashboardKpi(
                label: tr.budgetDashboardPosteCountLabel,
                value: "${postes.length}",
              ),
              _OcptDashboardKpi(label: tr.budgetDashboardLineCountLabel, value: "$lineCount"),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr.budgetDashboardPostesSectionTitle,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final poste in orderedPostes)
          _OcptDashboardPosteRow(
            poste: poste,
            amountCents: posteAmounts[poste.id] ?? 0,
            shareOfMax: maxPosteAmount <= 0 ? 0 : (posteAmounts[poste.id] ?? 0) / maxPosteAmount,
            currencyCode: currencyCode,
            onTap: () => onPosteSelected(poste.id),
          ),
      ],
    );
  }

  /// One alert card, switching over [alert]'s own subclass exhaustively — a poste over its quote
  /// names it through [posteLabelById] (falling back to `tr.budgetPosteUnnamed`, exactly as
  /// [_OcptDashboardPosteRow] does, for a poste that carries no label of its own), the cash
  /// projection going negative words its own undated reading differently from a recorded date, per
  /// [OcptBudgetCashProjectionNegativeAlert]'s own doc comment.
  Widget _buildAlertCard(
    BuildContext context,
    Tr tr,
    OcptBudgetAlert alert,
    Map<String, String> posteLabelById,
  ) => switch (alert) {
    OcptBudgetPosteOverQuoteAlert() => _OcptBudgetDashboardAlertCard(
      color: Theme.of(context).colorScheme.error,
      icon: Icons.trending_up,
      title: tr.budgetDashboardPosteOverQuoteAlertTitle,
      message: tr.budgetDashboardPosteOverQuoteAlertMessage(
        _posteLabelOf(tr, posteLabelById, alert.posteId),
        ocptBudgetAmountLabel(alert.paidCents + alert.committedCents, currencyCode),
        ocptBudgetAmountLabel(alert.quotedAmountCents, currencyCode),
        ocptBudgetAmountLabel(alert.varianceCents, currencyCode),
      ),
      actionLabel: tr.budgetDashboardPosteOverQuoteAlertAction,
      onActionPressed: () => onPosteAlertActionRequested(alert.posteId),
    ),
    OcptBudgetCashProjectionNegativeAlert() => _OcptBudgetDashboardAlertCard(
      color: ocptWarningColor(context),
      icon: Icons.trending_down,
      title: tr.budgetDashboardCashNegativeAlertTitle,
      message: alert.dueDate == null
          ? tr.budgetDashboardCashNegativeAlertMessageUndated(
              ocptBudgetAmountLabel(alert.balanceCents, currencyCode),
              ocptBudgetAmountLabel(alert.fallingDueCents, currencyCode),
            )
          : tr.budgetDashboardCashNegativeAlertMessageDated(
              ocptBudgetAmountLabel(alert.balanceCents, currencyCode),
              DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(alert.dueDate!),
              ocptBudgetAmountLabel(alert.fallingDueCents, currencyCode),
            ),
      actionLabel: tr.budgetDashboardCashNegativeAlertAction,
      onActionPressed: onCashAlertActionRequested,
    ),
  };

  /// [posteId]'s own label out of [posteLabelById], or `tr.budgetPosteUnnamed` while it is empty —
  /// never absent, since an alert's own poste always comes straight out of this very dashboard's
  /// [postes].
  String _posteLabelOf(Tr tr, Map<String, String> posteLabelById, String posteId) {
    final label = posteLabelById[posteId];
    return (label == null || label.isEmpty) ? tr.budgetPosteUnnamed : label;
  }
}

/// [totals]' own combined figure — the sum of every [OcptBudgetCoveredTotal.amountCents], paired
/// with how many of the underlying rows actually carried a known rate — folded the same way
/// `ocptBudgetPaidCentsByPosteId`'s own per-poste totals are summed, row by row, then summed: a
/// plain reduction over already-computed pure structures, not a rule of its own.
OcptBudgetCoveredTotal _ocptFoldCoveredTotals(Iterable<OcptBudgetCoveredTotal> totals) {
  var amountCents = 0;
  var coveredLineCount = 0;
  var lineCount = 0;

  for (final total in totals) {
    amountCents += total.amountCents;
    coveredLineCount += total.coveredLineCount;
    lineCount += total.lineCount;
  }

  return OcptBudgetCoveredTotal(
    amountCents: amountCents,
    coveredLineCount: coveredLineCount,
    lineCount: lineCount,
  );
}

/// One KPI of the dashboard's own top row: a muted label, a bold value, and an optional muted
/// caption underneath (the excluding-tax total's own coverage read-out).
class _OcptDashboardKpi extends StatelessWidget {
  /// The KPI's own label.
  final String label;

  /// The KPI's own value.
  final String value;

  /// A muted caption under [value], or null for a KPI with nothing further to say.
  final String? caption;

  /// Class constructor
  const _OcptDashboardKpi({required this.label, required this.value, this.caption});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = this.caption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
        if (caption != null)
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// One poste of the dashboard's own read, poste by poste: its label, its amount and a small bar
/// for its own share of the largest poste's amount.
class _OcptDashboardPosteRow extends StatelessWidget {
  /// The poste this row shows.
  final OcptBudgetPoste poste;

  /// This poste's own amount, in the header's own selected basis, in cents.
  final int amountCents;

  /// This poste's own share of the largest poste's amount, in `[0, 1]`.
  final double shareOfMax;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptDashboardPosteRow({
    required this.poste,
    required this.amountCents,
    required this.shareOfMax,
    required this.currencyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final label = poste.label.isEmpty ? tr.budgetPosteUnnamed : poste.label;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_ocptDashboardBarHeight / 2),
                child: LinearProgressIndicator(
                  value: shareOfMax.clamp(0.0, 1.0),
                  minHeight: _ocptDashboardBarHeight,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: Text(
                ocptBudgetAmountLabel(amountCents, currencyCode),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the dashboard's own two alerts, in the mock-up's own card shape: a tinted, bordered
/// block, [color] naming both — a title, a message and a single action.
class _OcptBudgetDashboardAlertCard extends StatelessWidget {
  /// The colour this alert reads in, both its icon/title and its tint/border.
  final Color color;

  /// The icon shown beside the title.
  final IconData icon;

  /// The card's own title.
  final String title;

  /// The card's own message — already resolved, plain text, no further formatting done here.
  final String message;

  /// The label of the card's own single action.
  final String actionLabel;

  /// Called when the action is clicked.
  final VoidCallback onActionPressed;

  /// Class constructor
  const _OcptBudgetDashboardAlertCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(color: color)),
                const SizedBox(height: 2),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onActionPressed,
            style: TextButton.styleFrom(foregroundColor: color),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
