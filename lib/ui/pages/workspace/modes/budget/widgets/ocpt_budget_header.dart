// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

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
/// switch that then replaced both cost `880` (six segments at the same `140` px each, plus one
/// shell chrome rather than two). Net of the two: `1600 − 740 + 880 = 1740` — the widest a route
/// drew its controls at (`OcptBudgetView.costTracking` or `.cashJournal`: the view switch, the
/// simplified/detailed switch, the tax-basis switch and the poste filter, all four at once). The
/// dashboard segment landed after that, at the same `140` px per-segment cost: `1740 + 140 = 1880`.
const double _ocptBudgetHeaderTitleMinWidth = 1880;

/// The budget mode's own header band: the current view's own title and subtitle, and whichever of
/// the mode's controls the view honours.
///
/// Purely presentational: it renders and reports every click upward, reading nothing off a
/// manager. **Nothing here writes to the project** — the view, the simplified/detailed reading and
/// the tax basis are all display preferences the mode itself holds in memory, never a project
/// column — so, like `OcptBreakdownHeader`, this widget needs no `isReadOnly` flag: a previewed
/// version withholds nothing this header offers.
///
/// **Controls are contextual, not global.** The tax-basis switch is offered on
/// [OcptBudgetView.dashboard], [OcptBudgetView.costTracking] and [OcptBudgetView.cashJournal]: the
/// dashboard's own KPI tiles read [taxBasis] exactly as the cost-tracking table does, so the switch
/// has to be reachable there too, or the reading it changes could never be changed from that view —
/// every other view either has no second tax basis to offer or reads no amount at all. The
/// simplified/detailed switch and the poste filter are offered exactly where they are honoured
/// today — the cost-tracking table, the cash journal and the committed spending, the only three
/// views that read a poste-keyed row at all — and **withheld**, never disabled or captioned,
/// everywhere else: the standing rule for an affordance without a subject
/// (`docs/architecture/budget.md`), which is also why the dashboard, a whole-project reading with
/// no poste dimension of its own, never gets either.
///
/// **The mode's own standing alerts are drawn on the dashboard alone now**, not here: this header
/// carries only [alertCount], a count badge on the view switch's own `Tableau de bord` segment, so
/// the news stays reachable from every other view without repeating the alert cards themselves in
/// two places.
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

  /// How many standing alerts the project currently raises (`ocptComputeBudgetAlerts`) — drawn as a
  /// count badge on the view switch's own `Tableau de bord` segment, and withheld outright, never
  /// drawn as an empty pill, while it is zero.
  final int alertCount;

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
    required this.alertCount,
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
                _OcptBudgetViewSwitch(value: view, onChanged: onViewSelected, alertCount: alertCount),
                if (_honoursPosteKeyedControls)
                  _OcptBudgetSimplifiedSwitch(value: isSimplified, onChanged: onSimplifiedChanged),
                if (_showsTaxBasisSwitch)
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
        ],
      ),
    );
  }

  /// Whether the tax-basis switch draws at all: the dashboard's own KPI tiles and the cost-tracking
  /// table and cash journal are the three views whose amounts follow it — every other view either
  /// reads no second basis or no amount at all.
  bool get _showsTaxBasisSwitch =>
      view == OcptBudgetView.dashboard ||
      view == OcptBudgetView.costTracking ||
      view == OcptBudgetView.cashJournal;

  /// Whether the current view honours the simplified/detailed switch and the poste filter —
  /// `ocptBudgetViewHonoursPosteFilter`'s own reading applied to the switch too, since a project
  /// with no poste to filter by has none to read simplified either.
  bool get _honoursPosteKeyedControls => ocptBudgetViewHonoursPosteFilter(view);

  /// The band's own title, naming **the view currently on screen** rather than the mode — mirrors
  /// the retired `OcptBudgetCentreView`'s own seven-way `_titleOf`.
  String _titleOf(Tr tr) => switch (view) {
    OcptBudgetView.dashboard => tr.budgetHeaderDashboardTitle,
    OcptBudgetView.costTracking => tr.budgetHeaderTitle,
    OcptBudgetView.cashJournal => tr.budgetHeaderCashJournalTitle,
    OcptBudgetView.committed => tr.budgetCommittedSectionTitle,
    OcptBudgetView.financing => tr.budgetHeaderResourcesTitle,
    OcptBudgetView.regie => tr.budgetHeaderRegieTitle,
    OcptBudgetView.sharing => tr.budgetHeaderSharingTitle,
  };

  /// The band's own subtitle, following [_titleOf]'s own view.
  String _subtitleOf(Tr tr) => switch (view) {
    OcptBudgetView.dashboard => tr.budgetHeaderDashboardSubtitle,
    OcptBudgetView.costTracking => tr.budgetHeaderSubtitle,
    OcptBudgetView.cashJournal => tr.budgetHeaderCashJournalSubtitle,
    OcptBudgetView.committed => tr.budgetHeaderCommittedSubtitle,
    OcptBudgetView.financing => tr.budgetHeaderFinancingSubtitle,
    OcptBudgetView.regie => tr.budgetHeaderRegieSubtitle,
    OcptBudgetView.sharing => tr.budgetHeaderSharingSubtitle,
  };
}

/// One segment of any of this header's switches — a small bordered rounded container, the active
/// segment filled `primary` and bolder, mirroring `OcptBreakdownHeader`'s own
/// `_OcptBreakdownViewSwitch._buildSegment`.
///
/// **[badgeCount], nullable and null on every switch but the view switch's own `Tableau de bord`
/// segment**, draws a small pill after the label rather than forking this class in two: the
/// standing alerts are a fact about one segment, not about switches in general, and every other
/// caller simply never passes it.
class _OcptBudgetSwitchSegment<T> extends StatelessWidget {
  /// This segment's own value.
  final T value;

  /// The switch's current value.
  final T current;

  /// This segment's label.
  final String label;

  /// How many standing alerts to badge this segment with, or null to draw no badge at all — never
  /// drawn empty, the moment there is nothing to count.
  final int? badgeCount;

  /// Called with [value] when this segment is clicked and isn't already the active one.
  final ValueChanged<T> onChanged;

  /// Class constructor
  const _OcptBudgetSwitchSegment({
    required this.value,
    required this.current,
    required this.label,
    this.badgeCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = value == current;
    final badgeCount = this.badgeCount;

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Semantics(
                label: Tr.of(context).budgetHeaderAlertCountSemanticsLabel(badgeCount),
                child: ExcludeSemantics(
                  child: Container(
                    key: const Key("ocptBudgetAlertCountBadge"),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(ocptRadiusLarge),
                    ),
                    child: Text(
                      "$badgeCount",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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

/// The seven view chips, in the shell design's own order: the dashboard, the cost report, the
/// financing plan, the cash journal, the committed spending, the catering-and-travel pass, the
/// revenue sharing.
class _OcptBudgetViewSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBudgetView value;

  /// Called with the view just clicked.
  final ValueChanged<OcptBudgetView> onChanged;

  /// How many standing alerts to badge the `Tableau de bord` segment with — see
  /// `_OcptBudgetSwitchSegment.badgeCount`'s own doc comment.
  final int alertCount;

  /// Class constructor
  const _OcptBudgetViewSwitch({required this.value, required this.onChanged, required this.alertCount});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.dashboard,
          current: value,
          label: tr.budgetHeaderDashboardSegmentLabel,
          badgeCount: alertCount,
          onChanged: onChanged,
        ),
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
