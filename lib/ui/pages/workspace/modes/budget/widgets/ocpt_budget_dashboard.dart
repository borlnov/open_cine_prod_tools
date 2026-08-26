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

/// The height of the balance bar, in logical pixels.
const double _ocptDashboardBarHeight = 6;

/// The budget mode's own dashboard: **the summary of the other pages, and nothing else** — the
/// mockup's own words. Four tiles, the needs/resources balance band, then the standing alerts, in
/// that order, drawn once every live poste holds real data for them to read.
///
/// **It types nothing of its own.** Every figure is read off the quote, the cash journal, the
/// financing plan and [ocptComputeBudgetAlerts]'s own answer — never recomputed here, never
/// captured here. A poste's click only selects it and hands the reader off to `Dépenses`, which
/// writes nothing either, so this whole page needs no `isReadOnly` flag: it is the one page of the
/// mode a reader always leaves having changed nothing.
///
/// **What used to live here and no longer does.** The poste-by-poste list is gone — the mockup
/// draws none, and the four tiles plus the balance band already carry the whole-project reading it
/// used to add up to one row at a time. The "what feeds this budget" card is gone too, for the
/// plan's own reason: it navigates, it does not summarise. `OcptBudgetFeedCard` itself is
/// unaffected — the cost-tracking table and the régie both draw it at their own top and keep every
/// one of its rows.
///
/// [alerts] — [ocptComputeBudgetAlerts]'s own answer, carried by the state rather than recomputed
/// here — draws **no card at all** while it is empty: a project raising no alert shows nothing
/// under its balance band.
///
/// The page itself gives way to [OcptWorkspaceEmptyMode] only for a project holding **nothing this
/// page reads** — no poste, no financing resource and no journal entry. See the comment on that
/// test in [build] for why the quote alone is not the question.
class OcptBudgetDashboard extends StatelessWidget {
  /// Every live poste, in display order.
  final List<OcptBudgetPoste> postes;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The cash journal's own debit, credit and balance — the `Solde en banque` tile's own figure.
  final OcptBudgetCashTotals cashTotals;

  /// What has actually been paid against each poste, keyed by its own id — folded with
  /// [offQuotePaidTotal] into the `Dépensé` tile's own figure.
  final Map<String, OcptBudgetCoveredTotal> paidByPosteId;

  /// The total of every debit that names no poste at all — spending outside the quote
  /// (`ocptBudgetOffQuotePaidTotalOf`, `lib/utils/ocpt_budget_journal.dart`), folded into the
  /// `Dépensé` tile alongside [paidByPosteId] so that figure agrees with the cash journal: what has
  /// actually gone out, off-quote spending included, rather than only what priced a poste.
  final OcptBudgetCoveredTotal offQuotePaidTotal;

  /// What is committed against each poste, keyed by its own id — the `Solde en banque` tile's own
  /// hint, once the tile's own value carries no coverage read-out of its own.
  final Map<String, OcptBudgetCoveredTotal> committedByPosteId;

  /// The dashboard's own standing alerts, computed once by [ocptComputeBudgetAlerts] and carried
  /// here by the state — see the class doc comment.
  final List<OcptBudgetAlert> alerts;

  /// Every live financing resource — the `Financement` tile reads it through
  /// [ocptBudgetResourcesTotalCents]/[ocptBudgetResourcesTotalByGroupKind], and the balance band
  /// reads it through [ocptBudgetNeedsResourcesBalanceOf].
  final List<OcptBudgetResource> resources;

  /// Called with a poste's id when its own over-quote alert row is clicked: **selects the poste and
  /// opens the quote on it**.
  ///
  /// A dashboard row is a **link to where the thing is worked on**, which is `Dépenses` — selecting
  /// alone would leave the reader on a read-only summary with nothing on it to do about what they
  /// had just picked.
  final ValueChanged<String> onPosteOpened;

  /// Called when the cash-projection alert's own row is clicked, opening the tools drawer's own
  /// `Flux de trésorerie` page — the statement is what answers a cash question.
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
    required this.offQuotePaidTotal,
    required this.committedByPosteId,
    required this.alerts,
    required this.resources,
    required this.onPosteOpened,
    required this.onCashAlertActionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    // **The empty state answers "this project holds nothing at all", never "it holds no poste".**
    // A production records its financing before it writes a quote as often as the other way round,
    // and gating this page on the quote alone hid every figure it had already typed behind an
    // invitation to start a different document — while leaving the balance band's own "no quote to
    // measure the financing plan against yet" branch, which exists for exactly that production,
    // almost unreachable. Every reading below stands on nothing: a quote with no poste totals zero
    // over zero lines, and the tiles say so rather than guessing.
    if (postes.isEmpty && resources.isEmpty && cashTotals.entryCount == 0) {
      return OcptWorkspaceEmptyMode(icon: Icons.payments_outlined, message: tr.budgetDashboardEmptyHint);
    }

    final allLines = [for (final poste in postes) ...poste.lines];
    final quotedTotal = ocptBudgetTotalOf(
      allLines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidTotal = ocptBudgetCoveredTotalsFoldOf([...paidByPosteId.values, offQuotePaidTotal]);
    final committedTotal = ocptBudgetCoveredTotalsFoldOf(committedByPosteId.values);

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

    final posteLabelById = {for (final poste in postes) poste.id: poste.label};

    // The `Dépensé` tile's own hint: the coverage read-out wins, exactly as the other two tiles
    // built on an `OcptBudgetCoveredTotal` — losing "30 %" for a partial reading is acceptable,
    // losing the honesty read-out is not. Once [paidTotal] is complete, a zero-total quote is
    // withheld rather than divided by: printing "0 %" or an infinite share would both state a
    // figure the data does not support, so the tile falls back to no hint at all, the same silence
    // the off-quote row keeps for a poste it cannot measure against a quote nobody has begun.
    final String? spentHint;
    if (!paidTotal.isComplete) {
      spentHint = tr.budgetDashboardCoverageCaption(paidTotal.coveredLineCount, paidTotal.lineCount);
    } else if (quotedTotal.amountCents <= 0) {
      spentHint = null;
    } else {
      final percent = ((paidTotal.amountCents / quotedTotal.amountCents) * 100).round();
      spentHint = tr.budgetDashboardSpentShareCaption(percent);
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _OcptDashboardTile(
                label: tr.budgetDashboardQuotedTotalLabel,
                value: ocptBudgetAmountLabel(quotedTotal.amountCents, currencyCode),
                hint: quotedTotal.isComplete
                    ? tr.budgetStatsPostes(postes.length)
                    : tr.budgetDashboardCoverageCaption(
                        quotedTotal.coveredLineCount,
                        quotedTotal.lineCount,
                      ),
              ),
              _OcptDashboardTile(
                label: tr.budgetDashboardFinancingLabel,
                value: ocptBudgetAmountLabel(resourcesTotalCents, currencyCode),
                hint: tr.budgetDashboardResourcesInKindCaption(
                  ocptBudgetAmountLabel(resourcesInKindCents, currencyCode),
                ),
              ),
              _OcptDashboardTile(
                label: tr.budgetDashboardSpentLabel,
                value: ocptBudgetAmountLabel(paidTotal.amountCents, currencyCode),
                hint: spentHint,
              ),
              _OcptDashboardTile(
                label: tr.budgetDashboardCashBalanceLabel,
                value: ocptBudgetAmountLabel(cashTotals.balanceCents, currencyCode),
                hint: cashTotals.isComplete
                    ? tr.budgetDashboardCommittedCaption(
                        ocptBudgetAmountLabel(committedTotal.amountCents, currencyCode),
                      )
                    : tr.budgetDashboardCoverageCaption(
                        cashTotals.coveredEntryCount,
                        cashTotals.entryCount,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _OcptDashboardBalanceBar(balance: balance, currencyCode: currencyCode),
        if (alerts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _OcptDashboardAlertsCard(
            alerts: alerts,
            posteLabelById: posteLabelById,
            currencyCode: currencyCode,
            onPosteOpened: onPosteOpened,
            onCashAlertActionRequested: onCashAlertActionRequested,
          ),
        ],
      ],
    );
  }
}

/// One of the dashboard's own four tiles: a muted, uppercased label, a large bold value and one
/// muted hint underneath — [hint] null draws no third line at all, exactly as a coverage read-out
/// that has nothing left to cover.
class _OcptDashboardTile extends StatelessWidget {
  /// The tile's own label.
  final String label;

  /// The tile's own value, already formatted.
  final String value;

  /// A muted hint under [value], or null for a tile with nothing further to say.
  final String? hint;

  /// Class constructor
  const _OcptDashboardTile({required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = this.hint;

    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall),
            if (hint != null)
              Text(
                hint,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
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
///
/// **The card's own title and verdict share one line**, the mockup's own arrangement — the title on
/// the left, `Manque {amount}`/`Short by {amount}` in the error colour on the right the moment the
/// plan falls short. `Ressources {amount}`/`Besoins {amount}` stay small and muted underneath the
/// bar, mirroring the balance bar the mode drew before this milestone, only turned the other way
/// up.
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
    final hasQuote = needs.lineCount > 0;
    final verdictColor = hasQuote && !balance.isBalanced
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final barColor = !hasQuote || balance.isBalanced
        ? theme.colorScheme.primary
        : ocptWarningColor(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    tr.budgetDashboardBalanceTitle.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasQuote && !balance.isBalanced)
                  Text(
                    tr.budgetDashboardBalanceShortfallMessage(
                      ocptBudgetAmountLabel(-balance.differenceCents, currencyCode),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: verdictColor,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    hasQuote
                        ? tr.budgetDashboardBalanceBalancedMessage
                        : tr.budgetDashboardBalanceNoQuoteMessage,
                    style: theme.textTheme.bodySmall?.copyWith(color: verdictColor),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${tr.budgetDashboardBalanceResourcesLabel} $resourcesText",
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  "${tr.budgetDashboardBalanceNeedsLabel} $needsText",
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The alerts card, `Ce qui demande une décision`: one row per [OcptBudgetAlert], a coloured badge,
/// the message and an amount right-aligned. **No buttons — the row itself is the click target**,
/// exactly as a poste row already was before this milestone, each one going where its own alert
/// already goes.
class _OcptDashboardAlertsCard extends StatelessWidget {
  /// The alerts this card draws, one row each, in [ocptComputeBudgetAlerts]'s own order.
  final List<OcptBudgetAlert> alerts;

  /// Every live poste's own label, keyed by its id, so an over-quote alert can name its poste.
  final Map<String, String> posteLabelById;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called with a poste's id when its own over-quote row is clicked.
  final ValueChanged<String> onPosteOpened;

  /// Called when the cash-projection row is clicked.
  final VoidCallback onCashAlertActionRequested;

  /// Class constructor
  const _OcptDashboardAlertsCard({
    required this.alerts,
    required this.posteLabelById,
    required this.currencyCode,
    required this.onPosteOpened,
    required this.onCashAlertActionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr.budgetDashboardAlertsSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final alert in alerts) _buildRow(context, tr, alert),
          ],
        ),
      ),
    );
  }

  /// One alert's own row, switching over [alert]'s own subclass exhaustively — a poste over its
  /// quote names it through [posteLabelById] (falling back to `tr.budgetPosteUnnamed`, exactly as
  /// the retired poste-by-poste list once did, for a poste that carries no label of its own), the
  /// cash projection going negative words its own undated reading differently from a recorded date,
  /// per [OcptBudgetCashProjectionNegativeAlert]'s own doc comment.
  Widget _buildRow(BuildContext context, Tr tr, OcptBudgetAlert alert) => switch (alert) {
    OcptBudgetPosteOverQuoteAlert() => _OcptDashboardAlertRow(
      badge: tr.budgetDashboardOverrunBadge,
      color: Theme.of(context).colorScheme.error,
      message: tr.budgetDashboardPosteOverQuoteAlertMessage(
        _posteLabelOf(tr, alert.posteId),
        ocptBudgetAmountLabel(alert.paidCents + alert.committedCents, currencyCode),
        ocptBudgetAmountLabel(alert.quotedAmountCents, currencyCode),
        ocptBudgetAmountLabel(alert.varianceCents, currencyCode),
      ),
      amount: ocptBudgetAmountLabel(-alert.varianceCents, currencyCode),
      onTap: () => onPosteOpened(alert.posteId),
    ),
    OcptBudgetCashProjectionNegativeAlert() => _OcptDashboardAlertRow(
      badge: tr.budgetDashboardCashAlertBadge,
      color: ocptWarningColor(context),
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
      amount: ocptBudgetAmountLabel(alert.balanceAfterCents, currencyCode),
      onTap: onCashAlertActionRequested,
    ),
  };

  /// [posteId]'s own label out of [posteLabelById], or `tr.budgetPosteUnnamed` while it is empty —
  /// never absent, since an alert's own poste always comes straight out of the very dashboard that
  /// built [posteLabelById].
  String _posteLabelOf(Tr tr, String posteId) {
    final label = posteLabelById[posteId];
    return (label == null || label.isEmpty) ? tr.budgetPosteUnnamed : label;
  }
}

/// One row of [_OcptDashboardAlertsCard]: a coloured badge, the message and an amount right-aligned
/// — the whole row is the click target, [ocptClickableCursor] hinting it exactly as a table row
/// already does everywhere else in this mode. The message wraps rather than clipping; see the
/// comment on the row's own `Row` for why this one cell breaks the mode's own habit.
class _OcptDashboardAlertRow extends StatelessWidget {
  /// The row's own badge text.
  final String badge;

  /// The row's own accent colour, carried by both the badge and the amount.
  final Color color;

  /// The row's own message — already resolved, plain text.
  final String message;

  /// The row's own amount, already formatted.
  final String amount;

  /// Called when this row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptDashboardAlertRow({
    required this.badge,
    required this.color,
    required this.message,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: ocptTableRowHorizontalPadding,
        ),
        child: Row(
          // **The message wraps rather than truncating**, and the badge and the amount align to its
          // first line. Every other row in this mode clips a cell to one line because the reader can
          // widen the column or open the fiche to see the rest; an alert has neither, and its
          // sentence *is* the whole of what it says — an ellipsis in the middle of "6 840,00 paid or
          // committed against a 6 200,00 quote" would leave exactly the figure that raised the alert
          // off screen, on a page built to be read at a glance.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OcptDashboardAlertBadge(text: badge, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
            const SizedBox(width: 12),
            Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small coloured badge, the alert row's own kind — mirrors `_OcptBudgetFicheBadge`
/// (`ocpt_budget_fiche.dart`), a private class of that file this one cannot import.
class _OcptDashboardAlertBadge extends StatelessWidget {
  /// The badge's own text.
  final String text;

  /// The badge's own accent colour.
  final Color color;

  /// Class constructor
  const _OcptDashboardAlertBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
    ),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}
