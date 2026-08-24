// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_projection.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';

/// The horizontal padding of every segmented switch's own segments, in logical pixels — mirrors
/// `OcptBreakdownHeader`'s own `_ocptBreakdownSegmentPadding`.
const double _ocptBudgetSegmentPadding = 12;

/// The narrowest the header is drawn with its title and subtitle at all, in logical pixels. Under
/// this, the controls are left alone — they are the only way to change what the centre shows. The
/// title and subtitle go first, exactly the reasoning `OcptBreakdownHeader`'s own doc comment gives
/// for shedding its own hint and progress bar first: they name a page the view switch's own active
/// segment has already named.
///
/// **Recomputed from scratch for this milestone's single-switch header**, rather than continuing
/// the incremental history the three-chip-plus-reading one carried: the control *set* changed
/// shape, not merely its count, so the old running total (`1600`, for a three-segment document
/// switch, a two-segment reading switch and three other controls) is no longer a base worth growing
/// from. The document switch and the reading switch together cost `420` (three segments at roughly
/// `140` px each, the seven-chip switch's own per-segment cost) plus `320` (two segments, `280`,
/// plus the reading switch's own shell chrome, `~40`) — `740` in all. The single six-segment view
/// switch that now replaces both costs `880` (six segments at the same `140` px each, plus one
/// shell chrome rather than two). Net of the two: `1600 − 740 + 880 = 1740` — the widest a route
/// ever draws its controls today (`OcptBudgetView.costTracking` or `.cashJournal`: the view switch,
/// the simplified/detailed switch, the tax-basis switch and the poste filter, all four at once). A
/// seventh segment (the dashboard) lands in a later milestone and will have to grow this again.
const double _ocptBudgetHeaderTitleMinWidth = 1740;

/// The budget mode's own header band: the current view's own title and subtitle, whichever of the
/// mode's controls the view honours, and, below all of it, a band for the project's own standing
/// alerts.
///
/// Purely presentational: it renders and reports every click upward, reading nothing off a
/// manager. **Nothing here writes to the project** — the view, the simplified/detailed reading and
/// the tax basis are all display preferences the mode itself holds in memory, never a project
/// column — so, like `OcptBreakdownHeader`, this widget needs no `isReadOnly` flag: a previewed
/// version withholds nothing this header offers.
///
/// **Controls are contextual, not global.** The tax-basis switch is offered on
/// [OcptBudgetView.costTracking] and [OcptBudgetView.cashJournal] alone: money coming in is always
/// read tax-inclusive, and every other view either has no second tax basis to offer or reads no
/// amount at all. The simplified/detailed switch and the poste filter are offered exactly where
/// they are honoured today — the cost-tracking table, the cash journal and the committed spending,
/// the only three views that read a poste-keyed row at all — and **withheld**, never disabled or
/// captioned, everywhere else: the standing rule for an affordance without a subject
/// (`docs/architecture/budget.md`).
///
/// **The alerts band also carries the cash projection**, [OcptBudgetCashProjection]: it draws ahead
/// of every alert, on [OcptBudgetView.costTracking] and [OcptBudgetView.cashJournal] alone — never
/// on any other view — and only while [commitments] carries at least one unsettled one, mirroring
/// an alert card's own standing rule that a card with nothing to say draws nothing at all. Unlike
/// the poste-over-quote and cash-negative alert cards beside it, it is never itself computed from
/// `OcptBudgetState.alerts`: it is a reading, not a standing warning, so it draws whether the
/// balance it projects ever goes negative or not. It reads [commitments] and [cashBalanceCents]
/// **whole, never narrowed by [filterPosteId]** — the very argument "The journal's balance is the
/// whole journal's" already makes for the top band's own figures, applied here to the projection
/// that opens at that very balance.
class OcptBudgetHeader extends StatelessWidget {
  /// Which of the mode's views is currently shown.
  final OcptBudgetView view;

  /// Called with the view just picked, when a chip is clicked.
  final ValueChanged<OcptBudgetView> onViewSelected;

  /// Whether the simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// Called with the switch's new value, when a segment is clicked.
  final ValueChanged<bool> onSimplifiedChanged;

  /// Which basis the excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// Called with the basis just picked, when a segment is clicked.
  final ValueChanged<OcptBudgetTaxBasis> onTaxBasisChanged;

  /// Every live poste of the project, offered by the poste filter.
  final List<OcptBudgetPoste> postes;

  /// The poste every view is currently narrowed to, or null for the whole project.
  final String? filterPosteId;

  /// Called with the poste just picked, or null to go back to the whole project.
  final ValueChanged<String?> onPosteFilterSelected;

  /// The project's own standing alerts, drawn as a band under the controls — this header is the
  /// one place they are drawn. Empty draws nothing.
  final List<OcptBudgetAlert> alerts;

  /// Every live commitment of the project, whole — never narrowed by [filterPosteId] — read by the
  /// alerts band's own [OcptBudgetCashProjection] card: both whether it draws at all (at least one
  /// unsettled commitment) and what it projects.
  final List<OcptBudgetCommitment> commitments;

  /// The cash journal's own balance — the figure [OcptBudgetCashProjection] opens at, whole, for
  /// the very same reason [commitments] is.
  final int cashBalanceCents;

  /// The project's default VAT rate, in basis points, or null — read by
  /// [OcptBudgetCashProjection] exactly as every other reading of money that has moved is.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code — the alert band's own amounts.
  final String currencyCode;

  /// Called with a poste id when the corresponding alert's own action is clicked.
  final ValueChanged<String> onAlertPosteActionRequested;

  /// Called when the cash-projection alert's own action is clicked.
  final VoidCallback onCashProjectionAlertActionRequested;

  /// Class constructor
  const OcptBudgetHeader({
    super.key,
    required this.view,
    required this.onViewSelected,
    required this.isSimplified,
    required this.onSimplifiedChanged,
    required this.taxBasis,
    required this.onTaxBasisChanged,
    required this.postes,
    required this.filterPosteId,
    required this.onPosteFilterSelected,
    required this.alerts,
    required this.commitments,
    required this.cashBalanceCents,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.onAlertPosteActionRequested,
    required this.onCashProjectionAlertActionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isTitleShown = constraints.maxWidth >= _ocptBudgetHeaderTitleMinWidth;

              final controls = <Widget>[
                _OcptBudgetViewSwitch(value: view, onChanged: onViewSelected),
                if (_honoursPosteKeyedControls)
                  _OcptBudgetSimplifiedSwitch(value: isSimplified, onChanged: onSimplifiedChanged),
                if (view == OcptBudgetView.costTracking || view == OcptBudgetView.cashJournal)
                  _OcptBudgetTaxBasisSwitch(value: taxBasis, onChanged: onTaxBasisChanged),
                if (_honoursPosteKeyedControls)
                  _OcptBudgetPosteFilter(
                    postes: postes,
                    filterPosteId: filterPosteId,
                    isSimplified: isSimplified,
                    onChanged: onPosteFilterSelected,
                  ),
              ];

              // Under the title's own threshold the controls **wrap onto a second line** rather
              // than sitting in a `Row` that runs off the edge, exactly as `OcptScheduleHeader`
              // already lays its own out. Dropping the title is not enough on its own: the centre
              // pane narrows for a reason the header cannot see — the right dock opening takes
              // roughly 580 px of it — and a plain `Row` then clips silently, taking a control off
              // the screen altogether. A control that has scrolled out of a clipped row is worse
              // than a disabled one, since nothing on screen says it exists at all.
              if (!isTitleShown) {
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: controls,
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _titleOf(tr),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          _subtitleOf(tr),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  for (final control in controls) ...[
                    if (control != controls.first) const SizedBox(width: 12),
                    control,
                  ],
                ],
              );
            },
          ),
          if (_showsCashProjection || alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (_showsCashProjection) ...[
              OcptBudgetCashProjection(
                openingBalanceCents: cashBalanceCents,
                commitments: commitments,
                defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                currencyCode: currencyCode,
              ),
              const SizedBox(height: 8),
            ],
            for (final alert in alerts) ...[
              _buildAlertCard(context, tr, alert),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  /// Whether [OcptBudgetCashProjection] draws at all — see the class doc comment:
  /// [OcptBudgetView.costTracking] or [OcptBudgetView.cashJournal], and at least one unsettled
  /// commitment to project.
  bool get _showsCashProjection =>
      (view == OcptBudgetView.costTracking || view == OcptBudgetView.cashJournal) &&
      commitments.any((commitment) => !commitment.isSettled);

  /// Whether the current view honours the simplified/detailed switch and the poste filter —
  /// `ocptBudgetViewHonoursPosteFilter`'s own reading applied to the switch too, since a project
  /// with no poste to filter by has none to read simplified either.
  bool get _honoursPosteKeyedControls => ocptBudgetViewHonoursPosteFilter(view);

  /// The band's own title, naming **the view currently on screen** rather than the mode — mirrors
  /// the retired `OcptBudgetCentreView`'s own seven-way `_titleOf`.
  String _titleOf(Tr tr) => switch (view) {
    OcptBudgetView.costTracking => tr.budgetHeaderTitle,
    OcptBudgetView.cashJournal => tr.budgetHeaderCashJournalTitle,
    OcptBudgetView.committed => tr.budgetCommittedSectionTitle,
    OcptBudgetView.financing => tr.budgetHeaderResourcesTitle,
    OcptBudgetView.regie => tr.budgetHeaderRegieTitle,
    OcptBudgetView.sharing => tr.budgetHeaderSharingTitle,
  };

  /// The band's own subtitle, following [_titleOf]'s own view.
  String _subtitleOf(Tr tr) => switch (view) {
    OcptBudgetView.costTracking => tr.budgetHeaderSubtitle,
    OcptBudgetView.cashJournal => tr.budgetHeaderCashJournalSubtitle,
    OcptBudgetView.committed => tr.budgetHeaderCommittedSubtitle,
    OcptBudgetView.financing => tr.budgetHeaderFinancingSubtitle,
    OcptBudgetView.regie => tr.budgetHeaderRegieSubtitle,
    OcptBudgetView.sharing => tr.budgetHeaderSharingSubtitle,
  };

  /// One alert card of the band, switching over [alert]'s own subclass exhaustively: a poste over
  /// its quote names it and reads by how much it is over, the cash projection going negative words
  /// its own undated reading differently from a recorded date. Each carries exactly one action back
  /// into the data it is about.
  Widget _buildAlertCard(BuildContext context, Tr tr, OcptBudgetAlert alert) => switch (alert) {
    OcptBudgetPosteOverQuoteAlert() => _OcptBudgetHeaderAlertBand(
      color: Theme.of(context).colorScheme.error,
      icon: Icons.trending_up,
      title: tr.budgetDashboardPosteOverQuoteAlertTitle,
      message: tr.budgetDashboardPosteOverQuoteAlertMessage(
        _posteLabelOf(tr, alert.posteId),
        ocptBudgetAmountLabel(alert.paidCents + alert.committedCents, currencyCode),
        ocptBudgetAmountLabel(alert.quotedAmountCents, currencyCode),
        ocptBudgetAmountLabel(alert.varianceCents, currencyCode),
      ),
      actionLabel: tr.budgetDashboardPosteOverQuoteAlertAction,
      onActionPressed: () => onAlertPosteActionRequested(alert.posteId),
    ),
    OcptBudgetCashProjectionNegativeAlert() => _OcptBudgetHeaderAlertBand(
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
      onActionPressed: onCashProjectionAlertActionRequested,
    ),
  };

  /// [posteId]'s own label out of [postes], or `tr.budgetPosteUnnamed` while it is empty or the
  /// poste has since disappeared.
  String _posteLabelOf(Tr tr, String posteId) {
    final label = postes.where((poste) => poste.id == posteId).firstOrNull?.label;
    return (label == null || label.isEmpty) ? tr.budgetPosteUnnamed : label;
  }
}

/// One card of [OcptBudgetHeader]'s own alert band: a tinted, bordered block, [color] naming
/// both — a title, a message and a single action.
class _OcptBudgetHeaderAlertBand extends StatelessWidget {
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
  const _OcptBudgetHeaderAlertBand({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(message, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
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

/// One segment of any of this header's switches — a small bordered rounded container, the active
/// segment filled `primary` and bolder, mirroring `OcptBreakdownHeader`'s own
/// `_OcptBreakdownViewSwitch._buildSegment`.
class _OcptBudgetSwitchSegment<T> extends StatelessWidget {
  /// This segment's own value.
  final T value;

  /// The switch's current value.
  final T current;

  /// This segment's label.
  final String label;

  /// Called with [value] when this segment is clicked and isn't already the active one.
  final ValueChanged<T> onChanged;

  /// Class constructor
  const _OcptBudgetSwitchSegment({
    required this.value,
    required this.current,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = value == current;

    return InkWell(
      onTap: isActive ? null : () => onChanged(value),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _ocptBudgetSegmentPadding, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// The header's own poste filter: one chip reading either `Every poste` or the poste every view is
/// currently narrowed to, with a small clear button beside the name.
///
/// **The mode's only filter control, and its only filter indicator.** Sitting in the header, it is
/// on screen wherever it is offered at all. **Withheld outright — never captioned "not applied
/// here" — the moment the current view has no poste dimension to honour it with**
/// (`OcptBudgetHeader._honoursPosteKeyedControls`): the standing "withheld, not disabled" rule
/// every other subject-less affordance in this app already follows.
///
/// Writes nothing to the project, so it needs no read-only handling: a previewed version filters
/// as freely as a live one.
class _OcptBudgetPosteFilter extends StatelessWidget {
  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// The poste currently filtered, or null for the whole project.
  final String? filterPosteId;

  /// Whether the header's simplified/detailed switch currently reads simplified — a poste's own
  /// displayed name follows it, exactly as it does everywhere else in the mode.
  final bool isSimplified;

  /// Called with the poste just picked, or null to go back to the whole project.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptBudgetPosteFilter({
    required this.postes,
    required this.filterPosteId,
    required this.isSimplified,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final filtered = postes.where((poste) => poste.id == filterPosteId).firstOrNull;
    final isFiltering = filtered != null;
    final color = isFiltering ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return _OcptBudgetSwitchShell(
      children: [
        MenuAnchor(
          menuChildren: [
            MenuItemButton(
              onPressed: () => onChanged(null),
              child: Text(tr.budgetHeaderPosteFilterAllLabel),
            ),
            for (final poste in postes)
              MenuItemButton(
                onPressed: () => onChanged(poste.id),
                child: Text(ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified)),
              ),
          ],
          builder: (context, controller, child) => Tooltip(
            message: tr.budgetHeaderPosteFilterTooltip,
            child: InkWell(
              onTap: () => controller.isOpen ? controller.close() : controller.open(),
              mouseCursor: ocptClickableCursor,
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _ocptBudgetSegmentPadding,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_alt_outlined, size: 14, color: color),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        isFiltering
                            ? ocptBudgetPosteDisplayLabel(filtered, isSimplified: isSimplified)
                            : tr.budgetHeaderPosteFilterAllLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: isFiltering ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isFiltering)
          Tooltip(
            message: tr.budgetHeaderPosteFilterClearTooltip,
            child: InkWell(
              onTap: () => onChanged(null),
              mouseCursor: ocptClickableCursor,
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Icon(Icons.close, size: 14, color: color),
              ),
            ),
          ),
      ],
    );
  }
}

/// The bordered rounded shell every one of this header's switches shares, mirroring
/// `OcptBreakdownHeader`'s own `_OcptBreakdownViewSwitch` container.
class _OcptBudgetSwitchShell extends StatelessWidget {
  /// The switch's own segments.
  final List<Widget> children;

  /// Class constructor
  const _OcptBudgetSwitchShell({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(ocptRadiusMedium),
    ),
    // A `Wrap` rather than a `Row`, so a switch's own segments flow onto a second line inside its
    // own border when the centre is too narrow to hold them side by side. Handed an unbounded
    // width, as the wide branch's own `Row` hands it, a `Wrap` lays everything out on one line, so
    // the comfortable case is untouched. These segments are `InkWell`s, not `MenuItemButton`s, so
    // `AGENTS.md`'s standing pitfall about a menu item inside a `Wrap` does not apply here.
    child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: children),
  );
}

/// The six view chips, in the shell design's own order: the cost report, the financing plan, the
/// cash journal, the committed spending, the catering-and-travel pass, the revenue sharing.
class _OcptBudgetViewSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBudgetView value;

  /// Called with the view just clicked.
  final ValueChanged<OcptBudgetView> onChanged;

  /// Class constructor
  const _OcptBudgetViewSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.costTracking,
          current: value,
          label: tr.budgetHeaderCostTrackingSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.financing,
          current: value,
          label: tr.budgetHeaderFinancingSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.cashJournal,
          current: value,
          label: tr.budgetHeaderCashJournalSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.committed,
          current: value,
          label: tr.budgetHeaderCommittedSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.regie,
          current: value,
          label: tr.budgetHeaderRegieSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.sharing,
          current: value,
          label: tr.budgetHeaderSharingSegmentLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The simplified/detailed switch.
class _OcptBudgetSimplifiedSwitch extends StatelessWidget {
  /// The switch's own current value.
  final bool value;

  /// Called with the value just clicked.
  final ValueChanged<bool> onChanged;

  /// Class constructor
  const _OcptBudgetSimplifiedSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: true,
          current: value,
          label: tr.budgetHeaderSimplifiedSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: false,
          current: value,
          label: tr.budgetHeaderDetailedSegmentLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The excluding/including-tax switch.
class _OcptBudgetTaxBasisSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBudgetTaxBasis value;

  /// Called with the basis just clicked.
  final ValueChanged<OcptBudgetTaxBasis> onChanged;

  /// Class constructor
  const _OcptBudgetTaxBasisSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: OcptBudgetTaxBasis.excludingTax,
          current: value,
          label: tr.budgetHeaderExcludingTaxSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetTaxBasis.includingTax,
          current: value,
          label: tr.budgetHeaderIncludingTaxSegmentLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
