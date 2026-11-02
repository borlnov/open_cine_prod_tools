// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_alerts.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_cash_totals.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_needs_resources_balance.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_warning_color.dart';

/// The height of the balance bar, in logical pixels.
const double _ocptDashboardBarHeight = 6;

/// The budget mode's own dashboard: **the summary of the other pages, and nothing else** — the
/// mockup's own words. Four tiles, the needs/resources balance band, then the standing alerts, in
/// that order, drawn once every live account holds real data for them to read.
///
/// **It types nothing of its own.** Every figure is read off the quote, the cash journal, the
/// financing plan and [ocptComputeBudgetAlerts]'s own answer — never recomputed here, never
/// captured here. An account's click only selects it and hands the reader off to `Dépenses`, which
/// writes nothing either, so this whole page needs no `isReadOnly` flag: it is the one page of the
/// mode a reader always leaves having changed nothing.
///
/// **What used to live here and no longer does.** The account-by-account list is gone — the mockup
/// draws none, and the four tiles plus the balance band already carry the whole-project reading it
/// used to add up to one row at a time. The "what feeds this budget" card is gone too, for the
/// plan's own reason: it navigates, it does not summarise. `OcptBudgetFeedCard` itself is
/// unaffected — the cost-tracking table and the logistics both draw it at their own top and keep
/// every one of its rows.
///
/// [alerts] — [ocptComputeBudgetAlerts]'s own answer, carried by the state rather than recomputed
/// here — draws **no card at all** while it is empty: a project raising no alert shows nothing
/// under its balance band.
///
/// The page itself gives way to [OcptWorkspaceEmptyMode] only for a project holding **nothing this
/// page reads** — no account, no financing resource and no journal entry. See the comment on that
/// test in [build] for why the quote alone is not the question.
class OcptBudgetDashboard extends StatelessWidget {
  /// Every live account, in display order.
  final List<OcptBudgetAccount> accounts;

  /// Which basis the header's excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// The cash journal's own debit, credit and balance — the `Solde en banque` tile's own figure.
  final OcptBudgetCashTotals cashTotals;

  /// What has actually been paid against each account, keyed by its own id — folded with
  /// [offQuotePaidTotal] into the `Dépensé` tile's own figure.
  final Map<String, OcptBudgetCoveredTotal> paidByAccountId;

  /// The total of every debit that names no account at all — spending outside the quote
  /// (`ocptBudgetOffQuotePaidTotalOf`, `lib/models/rules/ocpt_budget_journal.dart`), folded into
  /// the `Dépensé` tile alongside [paidByAccountId] so that figure agrees with the cash journal:
  /// what has actually gone out, off-quote spending included, rather than only what priced an
  /// account.
  final OcptBudgetCoveredTotal offQuotePaidTotal;

  /// What is committed against each account, keyed by its own id — the `Solde en banque` tile's own
  /// hint, once the tile's own value carries no coverage read-out of its own.
  final Map<String, OcptBudgetCoveredTotal> committedByAccountId;

  /// The dashboard's own standing alerts, computed once by [ocptComputeBudgetAlerts] and carried
  /// here by the state — see the class doc comment.
  final List<OcptBudgetAlert> alerts;

  /// Every live financing resource — the `Financement` tile reads it through
  /// [ocptBudgetResourcesTotalCents]/[ocptBudgetResourcesTotalByGroupKind], and the balance band
  /// reads it through [ocptBudgetNeedsResourcesBalanceOf].
  final List<OcptBudgetResource> resources;

  /// Called with an account's id when its own over-quote alert row is clicked: **selects the
  /// account and opens the quote on it**.
  ///
  /// A dashboard row is a **link to where the thing is worked on**, which is `Dépenses` — selecting
  /// alone would leave the reader on a read-only summary with nothing on it to do about what they
  /// had just picked.
  final ValueChanged<String> onAccountOpened;

  /// Called when the cash-projection alert's own row is clicked, opening the tools drawer's own
  /// `Flux de trésorerie` page — the statement is what answers a cash question.
  final VoidCallback onCashAlertActionRequested;

  /// Class constructor
  const OcptBudgetDashboard({
    super.key,
    required this.accounts,
    required this.taxBasis,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.cashTotals,
    required this.paidByAccountId,
    required this.offQuotePaidTotal,
    required this.committedByAccountId,
    required this.alerts,
    required this.resources,
    required this.onAccountOpened,
    required this.onCashAlertActionRequested,
  });

  /// Build the budget dashboard as a [ListView].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    // **The empty state answers "this project holds nothing at all", never "it holds no poste".**
    // A production records its financing before it writes a quote as often as the other way round,
    // and gating this page on the quote alone hid every figure it had already typed behind an
    // invitation to start a different document — while leaving the balance band's own "no quote to
    // measure the financing plan against yet" branch, which exists for exactly that production,
    // almost unreachable. Every reading below stands on nothing: a quote with no account totals
    // zero over zero lines, and the tiles say so rather than guessing.
    if (accounts.isEmpty && resources.isEmpty && cashTotals.entryCount == 0) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.payments_outlined,
        message: tr.budgetDashboardEmptyHint,
      );
    }

    final allLines = [for (final account in accounts) ...account.lines];
    final quotedTotal = ocptBudgetTotalOf(
      allLines,
      basis: taxBasis,
      projectVatRateBasisPoints: defaultVatRateBasisPoints,
    );
    final paidTotal = ocptBudgetCoveredTotalsFoldOf([...paidByAccountId.values, offQuotePaidTotal]);
    final committedTotal = ocptBudgetCoveredTotalsFoldOf(committedByAccountId.values);

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

    final accountLabelById = {for (final account in accounts) account.id: account.label};

    // The `Dépensé` tile's own hint: the coverage read-out wins, exactly as the other two tiles
    // built on an `OcptBudgetCoveredTotal` — losing "30 %" for a partial reading is acceptable,
    // losing the honesty read-out is not. Once [paidTotal] is complete, a zero-total quote is
    // withheld rather than divided by: printing "0 %" or an infinite share would both state a
    // figure the data does not support, so the tile falls back to no hint at all, the same silence
    // the off-quote row keeps for an account it cannot measure against a quote nobody has begun.
    final String? spentHint;
    if (!paidTotal.isComplete) {
      spentHint = tr.budgetDashboardCoverageCaption(
        paidTotal.coveredLineCount,
        paidTotal.lineCount,
      );
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
                    ? tr.budgetStatsAccounts(accounts.length)
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
            accountLabelById: accountLabelById,
            currencyCode: currencyCode,
            onAccountOpened: onAccountOpened,
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

  /// Build the dashboard tile as a [Card].
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall),
            if (hint != null)
              Text(
                hint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
/// amount — `tr.budgetDashboardBalanceCoverageReadOut` mirrors
/// `tr.budgetCostTrackingCoverageReadOut` exactly, minted under its own key for the same reason
/// `OcptBudgetLogistics`'s own two coverage read-outs are: this total counts quote *lines*, not
/// accounts, the noun the cost-tracking table's own string names.
///
/// **A quote with no line at all is not a quote this bar can say anything about.** A plain
/// `resources >= needs` reading would answer "balanced" for a project that has recorded nothing,
/// and declare the financing plan sufficient against a quote nobody has begun — which is precisely
/// the sort of claim the data cannot support that this whole mode refuses to make (see the em dash
/// `Consumed` keeps for an account with no quote, `docs/architecture/budget.md`). So the message is
/// three-way rather than two: no quote yet, covered, or short by an amount. The bar itself is drawn
/// either way — nothing disappears from the screen — it simply stops asserting a verdict it has no
/// grounds for.
///
/// **The card's own title and verdict share one line**, the mockup's own arrangement — the title on
/// the left, `Manque {amount}`/`Short by {amount}` in the error colour on the right the moment the
/// plan falls short. `Resources {amount}`/`Besoins {amount}` stay small and muted underneath the
/// bar, turned the other way up from the balance bar the mode drew before.
class _OcptDashboardBalanceBar extends StatelessWidget {
  /// The balance this bar draws — `ocptBudgetNeedsResourcesBalanceOf`'s own answer.
  final OcptBudgetNeedsResourcesBalance balance;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptDashboardBalanceBar({required this.balance, required this.currencyCode});

  /// Build the dashboard balance bar as a [Card].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final needs = balance.needs;
    final needsAmount = ocptBudgetAmountLabel(needs.amountCents, currencyCode);
    final needsText = needs.isComplete
        ? needsAmount
        : tr.budgetDashboardBalanceCoverageReadOut(
            needsAmount,
            needs.coveredLineCount,
            needs.lineCount,
          );
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
                // `Flexible` with a bounded `maxLines` — never a bare `Text` — because the
                // no-quote-yet sentence is long enough in French to overflow horizontally and
                // crush the title `Expanded` beside it at a narrow width; this lets it wrap or
                // ellipsize within its own share of the row instead.
                if (hasQuote && !balance.isBalanced)
                  Flexible(
                    child: Text(
                      tr.budgetDashboardBalanceShortfallMessage(
                        ocptBudgetAmountLabel(-balance.differenceCents, currencyCode),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: verdictColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      hasQuote
                          ? tr.budgetDashboardBalanceBalancedMessage
                          : tr.budgetDashboardBalanceNoQuoteMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(color: verdictColor),
                    ),
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  "${tr.budgetDashboardBalanceNeedsLabel} $needsText",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
/// exactly as an account row is, each one going where its own alert
/// already goes.
class _OcptDashboardAlertsCard extends StatelessWidget {
  /// The alerts this card draws, one row each, in [ocptComputeBudgetAlerts]'s own order.
  final List<OcptBudgetAlert> alerts;

  /// Every live account's own label, keyed by its id, so an over-quote alert can name its account.
  final Map<String, String> accountLabelById;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called with an account's id when its own over-quote row is clicked.
  final ValueChanged<String> onAccountOpened;

  /// Called when the cash-projection row is clicked.
  final VoidCallback onCashAlertActionRequested;

  /// Class constructor
  const _OcptDashboardAlertsCard({
    required this.alerts,
    required this.accountLabelById,
    required this.currencyCode,
    required this.onAccountOpened,
    required this.onCashAlertActionRequested,
  });

  /// Build the dashboard alerts card as a [Card].
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
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final alert in alerts)
              _OcptDashboardAlert(
                alert: alert,
                accountLabelById: accountLabelById,
                currencyCode: currencyCode,
                onAccountOpened: onAccountOpened,
                onCashAlertActionRequested: onCashAlertActionRequested,
              ),
          ],
        ),
      ),
    );
  }
}

/// One alert's own row, switching over [alert]'s own subclass exhaustively — an account over its
/// quote names it through [accountLabelById] (falling back to `tr.budgetAccountUnnamed`, exactly as
/// the retired account-by-account list once did, for an account that carries no label of its own),
/// the cash projection going negative words its own undated reading differently from a recorded
/// date, per [OcptBudgetCashProjectionNegativeAlert]'s own doc comment.
class _OcptDashboardAlert extends StatelessWidget {
  /// The alert this row draws.
  final OcptBudgetAlert alert;

  /// Every live account's own label, keyed by its id, so an over-quote alert can name its account.
  final Map<String, String> accountLabelById;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called with an account's id when its own over-quote row is clicked.
  final ValueChanged<String> onAccountOpened;

  /// Called when the cash-projection row is clicked.
  final VoidCallback onCashAlertActionRequested;

  /// Class constructor
  const _OcptDashboardAlert({
    required this.alert,
    required this.accountLabelById,
    required this.currencyCode,
    required this.onAccountOpened,
    required this.onCashAlertActionRequested,
  });

  /// Build the dashboard alert.
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    // Read into a local so that each case below promotes it to its own subclass.
    final alert = this.alert;

    return switch (alert) {
      OcptBudgetAccountOverQuoteAlert() => _OcptDashboardAlertRow(
        badge: tr.budgetDashboardOverrunBadge,
        color: Theme.of(context).colorScheme.error,
        message: tr.budgetDashboardAccountOverQuoteAlertMessage(
          _accountLabelOf(tr, alert.accountId),
          ocptBudgetAmountLabel(alert.paidCents + alert.committedCents, currencyCode),
          ocptBudgetAmountLabel(alert.quotedAmountCents, currencyCode),
          ocptBudgetAmountLabel(alert.varianceCents, currencyCode),
        ),
        amount: ocptBudgetAmountLabel(-alert.varianceCents, currencyCode),
        onTap: () => onAccountOpened(alert.accountId),
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
  }

  /// Get [accountId]'s own label out of [accountLabelById], or `tr.budgetAccountUnnamed` while it
  /// is empty —
  /// never absent, since an alert's own account always comes straight out of the very dashboard
  /// that built [accountLabelById].
  String _accountLabelOf(Tr tr, String accountId) {
    final label = accountLabelById[accountId];
    return (label == null || label.isEmpty) ? tr.budgetAccountUnnamed : label;
  }
}

/// One row of [_OcptDashboardAlertsCard]: a coloured badge, the message and an amount right-aligned
/// — the whole row is the click target, [ocpt_theme.ocptClickableCursor] hinting it exactly as a
/// table row already does everywhere else in this mode. The message wraps rather than clipping; see
/// the comment on the row's own `Row` for why this one cell breaks the mode's own habit.
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

  /// Build the dashboard alert row as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: ocpt_theme.ocptTableRowHorizontalPadding,
        ),
        child: Row(
          // **The message wraps rather than truncating**, and the badge and the amount align to its
          // first line. Every other row in this mode clips a cell to one line because the reader
          // can widen the column or open the detail panel to see the rest; an alert has neither,
          // and its sentence *is* the whole of what it says — an ellipsis in the middle of "6
          // 840,00 paid or committed against a 6 200,00 quote" would leave exactly the figure that
          // raised the alert off screen, on a page built to be read at a glance.
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

/// A small coloured badge, the alert row's own kind — mirrors `_OcptBudgetDetailBadge`
/// (`ocpt_budget_detail.dart`), a private class of that file this one cannot import.
class _OcptDashboardAlertBadge extends StatelessWidget {
  /// The badge's own text.
  final String text;

  /// The badge's own accent colour.
  final Color color;

  /// Class constructor
  const _OcptDashboardAlertBadge({required this.text, required this.color});

  /// Build the dashboard alert badge as a [Container].
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
    ),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}
