// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The height of a poste's own share bar, in logical pixels.
const double _ocptDashboardBarHeight = 6;

/// The budget mode's own dashboard, drawn in the mockup's own order: the two alerts, the KPI row,
/// the needs/resources balance, the quote read poste by poste, then the "what feeds this budget"
/// card — the mockup's full reading, now that the financing plan and the breakdown both hold real
/// data for it to draw.
///
/// **The balance bar and the feed card each read a figure this view could not support before.** The
/// balance bar ([_OcptDashboardBalanceBar]) is built on [ocptBudgetNeedsResourcesBalanceOf], over
/// [resources]; the feed card ([_OcptDashboardFeedCard]) reads the breakdown's own link
/// ([breakdownPricedElementCount]/[breakdownUnpricedElementCount]), the schedule's own day count
/// ([shootingDayCount]) and the catering pass's own head counts ([mealCount]/[snackCount]) — see
/// each widget's own doc comment for how it reads what it is handed. Purely computed, like
/// `OcptBreakdownRecapTable`: a poste's click only selects it, which writes nothing, so this needs
/// no `isReadOnly` flag at all — every one of the feed card's own three rows only ever *reports* a
/// click upward, through the callbacks [onBreakdownFeedRequested]/[onScheduleFeedRequested]/
/// [onCateringFeedRequested], `OcptBudgetMode` dispatching each exactly as it already does for the
/// alert cards' own actions.
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

  /// Every live financing resource — the KPI row's own `Total resources` tile reads it through
  /// [ocptBudgetResourcesTotalCents]/[ocptBudgetResourcesTotalByGroupKind], and the balance bar
  /// reads it through [ocptBudgetNeedsResourcesBalanceOf].
  final List<OcptBudgetResource> resources;

  /// How many live elements a live quote line already prices — the feed card's own breakdown row.
  final int breakdownPricedElementCount;

  /// How many live elements no live line prices yet — the feed card's own breakdown row, next to
  /// [breakdownPricedElementCount].
  final int breakdownUnpricedElementCount;

  /// How many shooting days the schedule holds — the feed card's own schedule row.
  final int shootingDayCount;

  /// How many meals the schedule's own presences produce — the feed card's own catering row.
  final int mealCount;

  /// How many snacks the schedule's own presences produce — the feed card's own catering row,
  /// beside [mealCount].
  final int snackCount;

  /// Called with a poste's id when its own row is clicked, opening the `Inspector` tab on it.
  final ValueChanged<String> onPosteSelected;

  /// Called with a poste's id when an [OcptBudgetPosteOverQuoteAlert]'s own action is clicked —
  /// selects the poste **and** switches to the cost-tracking view, unlike [onPosteSelected] alone.
  final ValueChanged<String> onPosteAlertActionRequested;

  /// Called when the [OcptBudgetCashProjectionNegativeAlert]'s own action is clicked, switching to
  /// the committed view.
  final VoidCallback onCashAlertActionRequested;

  /// Called when the feed card's own breakdown row is clicked — see the class doc comment.
  final VoidCallback onBreakdownFeedRequested;

  /// Called when the feed card's own schedule row is clicked — see the class doc comment.
  final VoidCallback onScheduleFeedRequested;

  /// Called when the feed card's own catering row is clicked — see the class doc comment.
  final VoidCallback onCateringFeedRequested;

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
    required this.resources,
    required this.breakdownPricedElementCount,
    required this.breakdownUnpricedElementCount,
    required this.shootingDayCount,
    required this.mealCount,
    required this.snackCount,
    required this.onPosteSelected,
    required this.onPosteAlertActionRequested,
    required this.onCashAlertActionRequested,
    required this.onBreakdownFeedRequested,
    required this.onScheduleFeedRequested,
    required this.onCateringFeedRequested,
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

    // Read tax-inclusive, always — see the balance bar's own doc comment
    // ([_OcptDashboardBalanceBar]) for why this never follows [taxBasis].
    final needsTotal = ocptBudgetTotalOf(
      allLines,
      basis: OcptBudgetTaxBasis.includingTax,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final resourcesTotalCents = ocptBudgetResourcesTotalCents(resources);
    final resourcesInKindCents =
        ocptBudgetResourcesTotalByGroupKind(resources)[OcptBudgetResourceGroupKind.inKind] ?? 0;
    final balance = ocptBudgetNeedsResourcesBalanceOf(
      needs: needsTotal,
      resourcesCents: resourcesTotalCents,
    );

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
              _OcptDashboardKpi(
                label: tr.budgetDashboardResourcesTotalLabel,
                value: ocptBudgetAmountLabel(resourcesTotalCents, currencyCode),
                caption: tr.budgetDashboardResourcesInKindCaption(
                  ocptBudgetAmountLabel(resourcesInKindCents, currencyCode),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _OcptDashboardBalanceBar(balance: balance, currencyCode: currencyCode),
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
        const SizedBox(height: 16),
        _OcptDashboardFeedCard(
          breakdownPricedElementCount: breakdownPricedElementCount,
          breakdownUnpricedElementCount: breakdownUnpricedElementCount,
          shootingDayCount: shootingDayCount,
          mealCount: mealCount,
          snackCount: snackCount,
          onBreakdownFeedRequested: onBreakdownFeedRequested,
          onScheduleFeedRequested: onScheduleFeedRequested,
          onCateringFeedRequested: onCateringFeedRequested,
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

/// The needs/resources balance bar: the quote's own total facing the financing plan's own total,
/// with a share bar between them and, underneath, either that the two balance or by how much the
/// plan still falls short.
///
/// **[balance]'s own `needs` is read tax-inclusive, always — deliberately never through the
/// header's own basis toggle.** A resource is money coming in, and
/// `docs/architecture/budget.md`'s own "Money that has moved is read tax-inclusive, always" already
/// settles there is only one honest basis to read money that will actually move in: comparing an
/// excluding-tax quote against a tax-inclusive resource would compare two different figures while
/// looking like it compared one. `OcptBudgetDashboard.build` is what resolves the tax-inclusive
/// reading, through `ocptBudgetTotalOf(..., basis: OcptBudgetTaxBasis.includingTax, ...)` rather
/// than [OcptBudgetDashboard.taxBasis] — resolved once there, so this widget itself never touches
/// the header's own toggle at all.
///
/// Whenever `balance.needs` is not [OcptBudgetCoveredTotal.isComplete], the needs figure prints the
/// very same idiom `OcptBudgetCostTracking`'s own total row already prints in place of a plain
/// amount — `tr.budgetDashboardBalanceCoverageReadOut` mirrors `tr.budgetCostTrackingCoverageReadOut`
/// exactly, minted under its own key for the same reason `OcptBudgetRegie`'s own two coverage
/// read-outs are: this total counts quote *lines*, not postes, the noun the cost-tracking table's
/// own string names.
///
/// **A quote with no line at all is not a quote this bar can say anything about.** A plain
/// `resources >= needs` reading would answer "balanced" for a project that has recorded nothing,
/// and declare the financing plan sufficient against a quote nobody has begun — which is precisely
/// the sort of claim the data cannot support that this whole mode refuses to make (see the em dash
/// `Consumed` keeps for a poste with no quote, `docs/architecture/budget.md`). So the message is
/// three-way rather than two: no quote yet, covered, or short by an amount. The bar itself is drawn
/// either way — nothing disappears from the screen — it simply stops asserting a verdict it has no
/// grounds for.
class _OcptDashboardBalanceBar extends StatelessWidget {
  /// The balance this bar draws — `ocptBudgetNeedsResourcesBalanceOf`'s own answer.
  final OcptBudgetNeedsResourcesBalance balance;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptDashboardBalanceBar({required this.balance, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final needs = balance.needs;
    final needsAmount = ocptBudgetAmountLabel(needs.amountCents, currencyCode);
    final needsText = needs.isComplete
        ? needsAmount
        : tr.budgetDashboardBalanceCoverageReadOut(needsAmount, needs.coveredLineCount, needs.lineCount);
    final resourcesText = ocptBudgetAmountLabel(balance.resourcesCents, currencyCode);
    final shareOfNeeds = needs.amountCents <= 0
        ? (balance.resourcesCents > 0 ? 1.0 : 0.0)
        : balance.resourcesCents / needs.amountCents;
    final barColor = needs.lineCount == 0 || balance.isBalanced
        ? theme.colorScheme.primary
        : ocptWarningColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr.budgetDashboardBalanceNeedsLabel.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(needsText, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr.budgetDashboardBalanceResourcesLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(resourcesText, style: theme.textTheme.titleMedium),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(_ocptDashboardBarHeight / 2),
          child: LinearProgressIndicator(
            value: shareOfNeeds.clamp(0.0, 1.0),
            minHeight: _ocptDashboardBarHeight,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          switch ((hasQuote: needs.lineCount > 0, isBalanced: balance.isBalanced)) {
            (hasQuote: false, isBalanced: _) => tr.budgetDashboardBalanceNoQuoteMessage,
            (hasQuote: true, isBalanced: true) => tr.budgetDashboardBalanceBalancedMessage,
            (hasQuote: true, isBalanced: false) => tr.budgetDashboardBalanceShortfallMessage(
              ocptBudgetAmountLabel(-balance.differenceCents, currencyCode),
            ),
          },
          style: theme.textTheme.bodySmall?.copyWith(
            color: needs.lineCount > 0 && !balance.isBalanced
                ? barColor
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The "what feeds this budget" card: three rows, each a title, a one-line reading and a click that
/// only ever *reports* upward — see `OcptBudgetDashboard`'s own class doc comment for why none of
/// the three navigates on its own.
///
/// **The unpriced-elements count read by [_OcptDashboardFeedRow]'s own breakdown row is deliberately
/// not a third alert.** `ocptComputeBudgetAlerts`'s own two rules each state a standing fact that
/// something is *wrong*; a dozen elements still waiting to be priced during preparation is the
/// normal state of a production still building its breakdown, true for months on end — the mockup
/// places this reading in this card for that reason, and so does this widget.
class _OcptDashboardFeedCard extends StatelessWidget {
  /// How many live elements a live quote line already prices.
  final int breakdownPricedElementCount;

  /// How many live elements no live line prices yet.
  final int breakdownUnpricedElementCount;

  /// How many shooting days the schedule holds.
  final int shootingDayCount;

  /// How many meals the schedule's own presences produce.
  final int mealCount;

  /// How many snacks the schedule's own presences produce.
  final int snackCount;

  /// Called when the breakdown row is clicked.
  final VoidCallback onBreakdownFeedRequested;

  /// Called when the schedule row is clicked.
  final VoidCallback onScheduleFeedRequested;

  /// Called when the catering row is clicked.
  final VoidCallback onCateringFeedRequested;

  /// Class constructor
  const _OcptDashboardFeedCard({
    required this.breakdownPricedElementCount,
    required this.breakdownUnpricedElementCount,
    required this.shootingDayCount,
    required this.mealCount,
    required this.snackCount,
    required this.onBreakdownFeedRequested,
    required this.onScheduleFeedRequested,
    required this.onCateringFeedRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final elementCount = breakdownPricedElementCount + breakdownUnpricedElementCount;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr.budgetDashboardFeedSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _OcptDashboardFeedRow(
              title: tr.budgetDashboardFeedBreakdownTitle,
              readOut: tr.budgetDashboardFeedBreakdownReadOut(breakdownPricedElementCount, elementCount),
              onTap: onBreakdownFeedRequested,
            ),
            _OcptDashboardFeedRow(
              title: tr.budgetDashboardFeedScheduleTitle,
              readOut: tr.budgetDashboardFeedScheduleReadOut(shootingDayCount),
              onTap: onScheduleFeedRequested,
            ),
            _OcptDashboardFeedRow(
              title: tr.budgetDashboardFeedCateringTitle,
              readOut: tr.budgetDashboardFeedCateringReadOut(mealCount, snackCount),
              onTap: onCateringFeedRequested,
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of [_OcptDashboardFeedCard]: a title, a one-line reading, and a `›` chevron hinting the
/// whole row is a click through to wherever [readOut] was typed.
class _OcptDashboardFeedRow extends StatelessWidget {
  /// The row's own title.
  final String title;

  /// The row's own one-line reading.
  final String readOut;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptDashboardFeedRow({required this.title, required this.readOut, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                readOut,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
