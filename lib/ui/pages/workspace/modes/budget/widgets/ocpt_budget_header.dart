// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_view.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// The horizontal padding of every segmented switch's own segments, in logical pixels — mirrors
/// `OcptBreakdownHeader`'s own `_ocptBreakdownSegmentPadding`.
const double _ocptBudgetSegmentPadding = 12;

/// The budget mode's own header band: the four-chip view switch, the tools drawer's own second
/// switch while it is open, the poste filter tag, and whichever of the simplified/detailed and
/// tax-basis switches the current route honours.
///
/// Purely presentational: it renders and reports every click upward, reading nothing off a
/// manager. **Nothing here writes to the project** — the view, the tools page, the
/// simplified/detailed reading and the tax basis are all display preferences the mode itself
/// holds in memory, never a project column — so, like `OcptBreakdownHeader`, this widget needs no
/// `isReadOnly` flag: a previewed version withholds nothing this header offers.
///
/// **No title, no subtitle, no breadcrumb.** The band used to open on the current view's own name
/// and one-line description — "the fil d'Ariane du bandeau, qui ne sélectionnait rien" the
/// mockup's own `t4` retires — repeating what the view switch's own active chip already says. The
/// band is now nothing but the controls, laid out in a [Wrap] so they flow onto a second line
/// rather than clipping once the centre narrows (the right dock opening takes roughly 580 px of
/// it, a plain [Row] then clipping silently in release).
///
/// **Controls are contextual, not global.** The tools drawer's own segmented switch draws only
/// while [view] is [OcptBudgetView.tools], immediately after the four-chip switch, in the very
/// same shell and segment widgets — never a chevron, never a menu, mockup `4c`'s own label saying
/// so. The poste filter tag draws nothing at all while [filterPosteId] is null, becoming a small
/// removable tag the moment one is set (mockup `4d`) — a control announcing "every poste" all day
/// is the very thing the retired breadcrumb was faulted for. The simplified/detailed switch is
/// offered where [ocptBudgetViewHonoursPosteFilter] is true — [OcptBudgetView.expenses] alone —
/// and the tax-basis switch on [OcptBudgetView.dashboard], [OcptBudgetView.expenses] and
/// [OcptBudgetView.tools] while [toolsView] reads [OcptBudgetToolsView.cashFlow], and nowhere
/// else: every other route either has no second tax basis to offer or reads no amount at all.
///
/// **The mode's own standing alerts are drawn on the dashboard alone.** This header carries only
/// [alertCount], a count badge on the view switch's own `Tableau de bord` segment, so the news
/// stays reachable from every other view without repeating the alert cards themselves in two
/// places.
class OcptBudgetHeader extends StatelessWidget {
  /// Which of the mode's four chips is currently shown.
  final OcptBudgetView view;

  /// Called with the view just picked, when a chip is clicked.
  final ValueChanged<OcptBudgetView> onViewSelected;

  /// Which of the tools drawer's own three pages is currently shown — read even while [view] is
  /// not [OcptBudgetView.tools], so the drawer's own switch draws whichever one was last picked
  /// the moment the drawer opens again.
  final OcptBudgetToolsView toolsView;

  /// Called with the tools page just picked, when a segment of the drawer's own switch is
  /// clicked.
  final ValueChanged<OcptBudgetToolsView> onToolsViewSelected;

  /// Whether the simplified/detailed switch currently reads simplified.
  final bool isSimplified;

  /// Called with the switch's new value, when a segment is clicked.
  final ValueChanged<bool> onSimplifiedChanged;

  /// Which basis the excluding/including-tax switch currently reads every amount in.
  final OcptBudgetTaxBasis taxBasis;

  /// Called with the basis just picked, when a segment is clicked.
  final ValueChanged<OcptBudgetTaxBasis> onTaxBasisChanged;

  /// Every live poste of the project, offered by the poste filter tag to resolve its own label.
  final List<OcptBudgetPoste> postes;

  /// The poste every view is currently narrowed to, or null for the whole project.
  final String? filterPosteId;

  /// Called when the poste filter tag's own `✕` is clicked.
  final VoidCallback onPosteFilterCleared;

  /// How many standing alerts the project currently raises (`ocptComputeBudgetAlerts`) — drawn as a
  /// count badge on the view switch's own `Tableau de bord` segment, and withheld outright, never
  /// drawn as an empty pill, while it is zero.
  final int alertCount;

  /// Class constructor
  const OcptBudgetHeader({
    super.key,
    required this.view,
    required this.onViewSelected,
    required this.toolsView,
    required this.onToolsViewSelected,
    required this.isSimplified,
    required this.onSimplifiedChanged,
    required this.taxBasis,
    required this.onTaxBasisChanged,
    required this.postes,
    required this.filterPosteId,
    required this.onPosteFilterCleared,
    required this.alertCount,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = postes.where((poste) => poste.id == filterPosteId).firstOrNull;

    final controls = <Widget>[
      _OcptBudgetViewSwitch(value: view, onChanged: onViewSelected, alertCount: alertCount),
      if (view == OcptBudgetView.tools)
        _OcptBudgetToolsViewSwitch(value: toolsView, onChanged: onToolsViewSelected),
      if (filtered != null)
        _OcptBudgetPosteFilterTag(
          poste: filtered,
          isSimplified: isSimplified,
          onCleared: onPosteFilterCleared,
        ),
      if (_honoursPosteKeyedControls)
        _OcptBudgetSimplifiedSwitch(value: isSimplified, onChanged: onSimplifiedChanged),
      if (_showsTaxBasisSwitch)
        _OcptBudgetTaxBasisSwitch(value: taxBasis, onChanged: onTaxBasisChanged),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: controls,
      ),
    );
  }

  /// Whether the tax-basis switch draws at all: the dashboard's own KPI tiles, the expenses table
  /// and the tools drawer's own cash-flow page are the three routes whose amounts follow it —
  /// every other route either reads no second basis or no amount at all.
  bool get _showsTaxBasisSwitch =>
      view == OcptBudgetView.dashboard ||
      view == OcptBudgetView.expenses ||
      (view == OcptBudgetView.tools && toolsView == OcptBudgetToolsView.cashFlow);

  /// Whether the current view honours the simplified/detailed switch — `ocptBudgetViewHonoursPosteFilter`'s
  /// own reading, true for [OcptBudgetView.expenses] alone.
  bool get _honoursPosteKeyedControls => ocptBudgetViewHonoursPosteFilter(view);
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

/// The header's own poste filter tag — mockup `4d`. Draws **nothing at all** while [poste] is
/// null (the header simply does not build it, see [OcptBudgetHeader.build]); once one is set it
/// reads that poste's own display label with a small `✕` clearing the filter.
///
/// **This is the tag, not a picker.** Picking a poste to filter by moved to the `⋮` menu of its
/// own row in the expenses table — the very gesture the retired left dock's own card carried —
/// so this widget only ever reports the one thing it can: clearing the filter.
class _OcptBudgetPosteFilterTag extends StatelessWidget {
  /// The poste currently filtered.
  final OcptBudgetPoste poste;

  /// Whether the header's simplified/detailed switch currently reads simplified — the tag's own
  /// label follows it, exactly as every other poste name in this mode does.
  final bool isSimplified;

  /// Called when the tag's own `✕` is clicked.
  final VoidCallback onCleared;

  /// Class constructor
  const _OcptBudgetPosteFilterTag({
    required this.poste,
    required this.isSimplified,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final label = ocptBudgetPosteDisplayLabel(poste, isSimplified: isSimplified);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label.isEmpty ? tr.budgetPosteUnnamed : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
          Tooltip(
            message: tr.budgetHeaderPosteFilterClearTooltip,
            child: InkWell(
              onTap: onCleared,
              mouseCursor: ocptClickableCursor,
              borderRadius: BorderRadius.circular(ocptRadiusSmall),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ),
        ],
      ),
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
    // own border when the centre is too narrow to hold them side by side. These segments are
    // `InkWell`s, not `MenuItemButton`s, so `AGENTS.md`'s standing pitfall about a menu item
    // inside a `Wrap` does not apply here.
    child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: children),
  );
}

/// The four view chips, left to right: the dashboard, the expenses table, the resources tree, the
/// tools drawer — mockup `4a`–`4d`'s own band.
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
          value: OcptBudgetView.expenses,
          current: value,
          label: tr.budgetHeaderExpensesSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.resources,
          current: value,
          label: tr.budgetHeaderResourcesSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetView.tools,
          current: value,
          label: tr.budgetHeaderToolsSegmentLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The tools drawer's own second switch, drawn immediately after the four-chip switch while
/// [OcptBudgetHeader.view] is [OcptBudgetView.tools] — the very same shell and segment widgets as
/// every other switch of this header, **never a chevron, never a menu**: mockup `4c`'s own label
/// says the reader has to see at a glance what the drawer contains and which of it is on screen.
class _OcptBudgetToolsViewSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBudgetToolsView value;

  /// Called with the tools page just clicked.
  final ValueChanged<OcptBudgetToolsView> onChanged;

  /// Class constructor
  const _OcptBudgetToolsViewSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: OcptBudgetToolsView.cashFlow,
          current: value,
          label: tr.budgetHeaderCashFlowSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetToolsView.regie,
          current: value,
          label: tr.budgetHeaderRegieSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetToolsView.sharing,
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
