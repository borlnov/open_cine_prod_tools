// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_sub_page.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_alerts.dart';

/// The horizontal padding of every segmented switch's own segments, in logical pixels — mirrors
/// `OcptBreakdownHeader`'s own `_ocptBreakdownSegmentPadding`.
const double _ocptBudgetSegmentPadding = 12;

/// The narrowest the header is drawn with its title and subtitle at all, in logical pixels. Under
/// this, only the controls are left — they are the only way to change what the centre shows,
/// exactly the reasoning `OcptBreakdownHeader`'s own doc comment gives for shedding its own hint
/// and progress bar first.
///
/// **Recomputed from scratch for this milestone's three-chip header**, rather than continuing the
/// incremental history the seven-chip one carried: the control *set* changed shape, not merely its
/// count, so the old running total (`1860`, for a seven-segment switch plus three other controls)
/// is no longer a base worth growing from. The document switch alone costs roughly `140` px per
/// segment, mirroring the seven-chip switch's own per-segment cost, and its three segments (`420`)
/// replace what used to be seven (`980`) — a saving of `560`. Against that, this header can now
/// show a **fifth** control the old one never had at once: the reading switch, two segments wide
/// (`280`) plus its own shell chrome (`~40`, matching a switch's average overhead the poste filter's
/// own `+180` already measured). Net of the two: `1860 − 560 + 280 + 40 = 1620`, rounded down to a
/// clean `1600` — the widest a route ever draws its controls (`OcptBudgetDocument.expenses` at its
/// own top level: the document switch, the reading switch, the simplified/detailed switch, the
/// tax-basis switch and the poste filter, all five at once).
const double _ocptBudgetHeaderTitleMinWidth = 1600;

/// The budget mode's own header band: the current route's own title and subtitle, a breadcrumb
/// naming where the reader stands, whichever of the mode's controls the route honours, and, below
/// all of it, a band for the project's own standing alerts.
///
/// Purely presentational: it renders and reports every click upward, reading nothing off a
/// manager. **Nothing here writes to the project** — the document, the reading, the sub-page, the
/// simplified/detailed reading and the tax basis are all display preferences the mode itself holds
/// in memory, never a project column — so, like `OcptBreakdownHeader`, this widget needs no
/// `isReadOnly` flag: a previewed version withholds nothing this header offers.
///
/// **Controls are contextual, not global — the milestone's own departure from the seven-chip
/// header's "always offered" rule.** The reading switch and the tax-basis switch are offered on
/// [OcptBudgetDocument.expenses] alone: money coming in is always read tax-inclusive, and
/// [OcptBudgetDocument.resources]/[OcptBudgetDocument.sharing] have no [OcptBudgetDocumentReading
/// .byDate] reading yet to switch to (`OcptBudgetDocumentReading`'s own doc comment). The
/// simplified/detailed switch and the poste filter are offered exactly where they are honoured
/// today — the cost-tracking table, the cash journal and the committed spending, the only three
/// places that read a poste-keyed row at all — and **withheld**, never disabled or captioned,
/// everywhere else: the standing rule for an affordance without a subject
/// (`docs/architecture/budget.md`).
class OcptBudgetHeader extends StatelessWidget {
  /// Which of the mode's three documents is currently shown.
  final OcptBudgetDocument document;

  /// Called with the document just picked, when a chip is clicked — and by the breadcrumb's own
  /// ancestor, naming the document already on screen to return to its own top level.
  final ValueChanged<OcptBudgetDocument> onDocumentSelected;

  /// Which order [document]'s own rows are currently read in.
  final OcptBudgetDocumentReading reading;

  /// Called with the reading just picked, when a segment is clicked.
  final ValueChanged<OcptBudgetDocumentReading> onReadingSelected;

  /// The sub-page of [document] currently shown, or null while at its own top level.
  final OcptBudgetSubPage? subPage;

  /// Called with a sub-page of `OcptBudgetDocument.expenses` when the breadcrumb's own menu offers
  /// it and it is picked — the way *in* to a sub-page, mirrored by [onDocumentSelected]'s own way
  /// *out* (`_OcptBudgetBreadcrumb`'s own class doc comment).
  final ValueChanged<OcptBudgetSubPage> onSubPageSelected;

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

  /// The project's own standing alerts, drawn as a band under the controls — the very reading
  /// `OcptBudgetDashboard` still carries its own copy of, `docs/plans/budget-mode-ux.md` M7 owning
  /// the day it dissolves that copy in favour of this one. Empty draws nothing.
  final List<OcptBudgetAlert> alerts;

  /// The project's currency, an ISO 4217 code — the alert band's own amounts.
  final String currencyCode;

  /// Called with a poste id when the corresponding alert's own action is clicked.
  final ValueChanged<String> onAlertPosteActionRequested;

  /// Called when the cash-projection alert's own action is clicked.
  final VoidCallback onCashProjectionAlertActionRequested;

  /// Class constructor
  const OcptBudgetHeader({
    super.key,
    required this.document,
    required this.onDocumentSelected,
    required this.reading,
    required this.onReadingSelected,
    required this.subPage,
    required this.onSubPageSelected,
    required this.isSimplified,
    required this.onSimplifiedChanged,
    required this.taxBasis,
    required this.onTaxBasisChanged,
    required this.postes,
    required this.filterPosteId,
    required this.onPosteFilterSelected,
    required this.alerts,
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
                _OcptBudgetDocumentSwitch(value: document, onChanged: onDocumentSelected),
                if (document == OcptBudgetDocument.expenses)
                  _OcptBudgetReadingSwitch(
                    value: reading,
                    subPage: subPage,
                    onChanged: onReadingSelected,
                  ),
                if (_honoursPosteKeyedControls)
                  _OcptBudgetSimplifiedSwitch(value: isSimplified, onChanged: onSimplifiedChanged),
                if (document == OcptBudgetDocument.expenses)
                  _OcptBudgetTaxBasisSwitch(value: taxBasis, onChanged: onTaxBasisChanged),
                if (_honoursPosteKeyedControls)
                  _OcptBudgetPosteFilter(
                    postes: postes,
                    filterPosteId: filterPosteId,
                    isSimplified: isSimplified,
                    onChanged: onPosteFilterSelected,
                  ),
                // The narrow layout draws no breadcrumb at all (below), so its own sub-page menu
                // rides along as a control instead — otherwise a sub-page reached by a business
                // gesture (the dashboard's own catering row) would become the only way to any of
                // its siblings the moment the window narrows.
                if (!isTitleShown && document == OcptBudgetDocument.expenses)
                  _OcptBudgetSubPageMenu(current: subPage, onSelected: onSubPageSelected),
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
                        _OcptBudgetBreadcrumb(
                          document: document,
                          subPage: subPage,
                          onDocumentSelected: onDocumentSelected,
                          onSubPageSelected: onSubPageSelected,
                        ),
                        const SizedBox(height: 2),
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
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final alert in alerts) ...[
              _buildAlertCard(context, tr, alert),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  /// Whether the current route honours the simplified/detailed switch and the poste filter —
  /// [OcptBudgetDocument.expenses] read at its own top level in either reading, or its own
  /// [OcptBudgetSubPage.committedSpending]: the only three places a poste-keyed row is drawn at
  /// all, `ocptBudgetHonoursPosteFilter`'s own reading applied to the switch too, since a project
  /// with no poste to filter by has none to read simplified either.
  bool get _honoursPosteKeyedControls => ocptBudgetHonoursPosteFilter(
    document: document,
    subPage: subPage,
  );

  /// The band's own title, naming **the route currently on screen** rather than the mode — mirrors
  /// the retired `OcptBudgetCentreView`'s own seven-way `_titleOf`, resolved off the new three-part
  /// route instead: a sub-page's own title wins outright, and at a document's own top level the
  /// reading picks between [OcptBudgetDocument.expenses]'s own two.
  String _titleOf(Tr tr) => switch (subPage) {
    OcptBudgetSubPage.dashboard => tr.budgetHeaderDashboardTitle,
    OcptBudgetSubPage.committedSpending => tr.budgetCommittedSectionTitle,
    OcptBudgetSubPage.regie => tr.budgetHeaderRegieTitle,
    null => switch (document) {
      OcptBudgetDocument.expenses => reading == OcptBudgetDocumentReading.byDate
          ? tr.budgetHeaderCashJournalTitle
          : tr.budgetHeaderTitle,
      OcptBudgetDocument.resources => tr.budgetHeaderResourcesTitle,
      OcptBudgetDocument.sharing => tr.budgetHeaderSharingTitle,
    },
  };

  /// The band's own subtitle, following [_titleOf]'s own route.
  String _subtitleOf(Tr tr) => switch (subPage) {
    OcptBudgetSubPage.dashboard => tr.budgetHeaderDashboardSubtitle,
    OcptBudgetSubPage.committedSpending => tr.budgetHeaderCommittedSubtitle,
    OcptBudgetSubPage.regie => tr.budgetHeaderRegieSubtitle,
    null => switch (document) {
      OcptBudgetDocument.expenses => reading == OcptBudgetDocumentReading.byDate
          ? tr.budgetHeaderCashJournalSubtitle
          : tr.budgetHeaderSubtitle,
      OcptBudgetDocument.resources => tr.budgetHeaderFinancingSubtitle,
      OcptBudgetDocument.sharing => tr.budgetHeaderSharingSubtitle,
    },
  };

  /// One alert card of the band — **a duplicate of `OcptBudgetDashboard`'s own `_buildAlertCard`,
  /// deliberately**: the dashboard keeps drawing its own copy until `docs/plans/budget-mode-ux.md`
  /// M7 dissolves it, so the app stays fully usable through this milestone, and touching that
  /// widget's own body for any reason other than callback plumbing is exactly what this milestone
  /// was told not to do. The price of that is one alert card rendered from two places for a few
  /// milestones — not an oversight.
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
  /// poste has since disappeared — mirrors `OcptBudgetDashboard._posteLabelOf`.
  String _posteLabelOf(Tr tr, String posteId) {
    final label = postes.where((poste) => poste.id == posteId).firstOrNull?.label;
    return (label == null || label.isEmpty) ? tr.budgetPosteUnnamed : label;
  }
}

/// One card of [OcptBudgetHeader]'s own alert band — a compact duplicate of
/// `OcptBudgetDashboard`'s own `_OcptBudgetDashboardAlertCard`, kept as its own private widget here
/// rather than shared, for the very reason [OcptBudgetHeader._buildAlertCard]'s own doc comment
/// gives.
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

/// The header's own breadcrumb: `Expenses` alone at [document]'s own top level, `Expenses ›
/// Catering & travel` (or another sub-page) inside one — the control that makes a sub-page
/// reachable in both directions.
///
/// Clicking the document ancestor is [onDocumentSelected] naming the document already on screen,
/// which the bloc reads as "return to its own top level" (`OcptBudgetDocumentSelectedEvent`'s own
/// doc comment) — the way *out*. The way *in*, for `OcptBudgetDocument.expenses`, is the small menu
/// beside it ([_OcptBudgetSubPageMenu]): every sub-page but the one already on screen, so a reader
/// standing on the committed spending can jump straight to the catering-and-travel pass without
/// walking back through the dashboard first — the very reachability this control exists to give
/// every sub-page, not only the one a business gesture happened to open first.
class _OcptBudgetBreadcrumb extends StatelessWidget {
  /// The document currently on screen.
  final OcptBudgetDocument document;

  /// The sub-page of [document] currently shown, or null at its own top level — nothing is drawn
  /// past the document's own name while this is null.
  final OcptBudgetSubPage? subPage;

  /// Called with [document] when the document ancestor is clicked.
  final ValueChanged<OcptBudgetDocument> onDocumentSelected;

  /// Called with a sub-page when the menu offers it and it is picked.
  final ValueChanged<OcptBudgetSubPage> onSubPageSelected;

  /// Class constructor
  const _OcptBudgetBreadcrumb({
    required this.document,
    required this.subPage,
    required this.onDocumentSelected,
    required this.onSubPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final subPage = this.subPage;
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subPage == null)
          Text(_documentLabelOf(tr, document), style: mutedStyle)
        else ...[
          InkWell(
            key: const Key("ocptBudgetBreadcrumbAncestor"),
            onTap: () => onDocumentSelected(document),
            mouseCursor: ocptClickableCursor,
            borderRadius: BorderRadius.circular(ocptRadiusSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(
                _documentLabelOf(tr, document),
                style: mutedStyle?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text("›", style: mutedStyle),
          ),
          Text(_subPageLabelOf(tr, subPage), style: mutedStyle),
        ],
        if (document == OcptBudgetDocument.expenses)
          _OcptBudgetSubPageMenu(current: subPage, onSelected: onSubPageSelected),
      ],
    );
  }

  /// [document]'s own name, exactly as its chip in [_OcptBudgetDocumentSwitch] reads it.
  String _documentLabelOf(Tr tr, OcptBudgetDocument document) => switch (document) {
    OcptBudgetDocument.expenses => tr.budgetHeaderDocumentExpensesSegmentLabel,
    OcptBudgetDocument.resources => tr.budgetHeaderDocumentResourcesSegmentLabel,
    OcptBudgetDocument.sharing => tr.budgetHeaderDocumentSharingSegmentLabel,
  };

  /// [subPage]'s own name — see [_ocptBudgetSubPageLabel]'s own doc comment.
  String _subPageLabelOf(Tr tr, OcptBudgetSubPage subPage) => _ocptBudgetSubPageLabel(tr, subPage);
}

/// [subPage]'s own name, worded exactly as its page's own title already reads elsewhere in the
/// mode, so neither the breadcrumb nor [_OcptBudgetSubPageMenu] ever says a second thing about the
/// very page it names.
String _ocptBudgetSubPageLabel(Tr tr, OcptBudgetSubPage subPage) => switch (subPage) {
  OcptBudgetSubPage.committedSpending => tr.budgetCommittedSectionTitle,
  OcptBudgetSubPage.regie => tr.budgetHeaderRegieSegmentLabel,
  OcptBudgetSubPage.dashboard => tr.budgetHeaderDashboardSegmentLabel,
};

/// The small menu that opens any of `OcptBudgetDocument.expenses`'s own three sub-pages —
/// [_OcptBudgetBreadcrumb]'s own "way in", offered whatever sub-page (if any) is already on
/// screen, so a reader never has to walk back through one to reach another.
class _OcptBudgetSubPageMenu extends StatelessWidget {
  /// The sub-page currently on screen, or null at the document's own top level — offered like
  /// every other entry, since jumping from one sub-page's own menu to the top-level table is not a
  /// gesture this menu offers (the reading switch already is).
  final OcptBudgetSubPage? current;

  /// Called with the sub-page just picked.
  final ValueChanged<OcptBudgetSubPage> onSelected;

  /// Class constructor
  const _OcptBudgetSubPageMenu({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return MenuAnchor(
      menuChildren: [
        for (final subPage in OcptBudgetSubPage.values)
          MenuItemButton(
            onPressed: subPage == current ? null : () => onSelected(subPage),
            child: Text(_ocptBudgetSubPageLabel(tr, subPage)),
          ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: tr.budgetHeaderSubPageMenuTooltip,
        child: InkWell(
          key: const Key("ocptBudgetSubPageMenuButton"),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          mouseCursor: ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Icon(Icons.expand_more, size: 16),
          ),
        ),
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

  /// Whether this segment reads as the active one — [value] equal to [current] by default, but
  /// overridable: [_OcptBudgetReadingSwitch] reads neither of its own two segments as active while
  /// a sub-page is on screen, so either stays clickable and is the way back to the top level even
  /// when it already names the very reading the state still carries from before the sub-page was
  /// opened.
  final bool? isActiveOverride;

  /// Class constructor
  const _OcptBudgetSwitchSegment({
    required this.value,
    required this.current,
    required this.label,
    required this.onChanged,
    this.isActiveOverride,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = isActiveOverride ?? (value == current);

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
/// here" — the moment the current route has no poste dimension to honour it with**
/// (`OcptBudgetHeader._honoursPosteKeyedControls`): the milestone's own move from the seven-chip
/// header's "state it, don't hide it" reading to the standing "withheld, not disabled" rule every
/// other subject-less affordance in this app already follows, now that the mode's own documents
/// each own a clear poste dimension of their own rather than sharing one bar of seven views only
/// three of which had one.
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

/// The three document chips: `Expenses`, `Resources`, `Sharing`, in the order the money itself
/// runs — what the film costs, what pays for it, what it earns back.
class _OcptBudgetDocumentSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBudgetDocument value;

  /// Called with the document just clicked.
  final ValueChanged<OcptBudgetDocument> onChanged;

  /// Class constructor
  const _OcptBudgetDocumentSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: OcptBudgetDocument.expenses,
          current: value,
          label: tr.budgetHeaderDocumentExpensesSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetDocument.resources,
          current: value,
          label: tr.budgetHeaderDocumentResourcesSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetDocument.sharing,
          current: value,
          label: tr.budgetHeaderDocumentSharingSegmentLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The current document's own reading switch: `By poste` (`OcptBudgetDocumentReading.byTree`)
/// against `By date` (`.byDate`) — offered on `OcptBudgetDocument.expenses` alone, the only
/// document with a second reading to switch to yet.
///
/// **Also the way back to a document's own top level from inside a sub-page.** Picking either
/// segment is `OcptBudgetDocumentReadingSelectedEvent`, which clears the sub-page along with
/// setting the reading — so this switch stays visible and tappable whichever of expenses's own
/// sub-pages the reader is standing on, and using it is one of the two ways out.
///
/// **Neither segment reads as active while a sub-page is on screen**,
/// `_OcptBudgetSwitchSegment.isActiveOverride` false for both regardless of [value]: a sub-page is
/// not a reading of the poste tree or the journal, so
/// nothing here should claim to be the current one — and, just as importantly, a segment that
/// merely repeats the very [value] the state still carries from before the sub-page opened must
/// stay clickable, or the reader would have no way back to it at all
/// (`_OcptBudgetSwitchSegment.isActiveOverride`'s own doc comment).
class _OcptBudgetReadingSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBudgetDocumentReading value;

  /// The sub-page currently on screen, or null at the document's own top level.
  final OcptBudgetSubPage? subPage;

  /// Called with the reading just clicked.
  final ValueChanged<OcptBudgetDocumentReading> onChanged;

  /// Class constructor
  const _OcptBudgetReadingSwitch({required this.value, required this.subPage, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final isActiveOverride = subPage == null ? null : false;

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: OcptBudgetDocumentReading.byTree,
          current: value,
          label: tr.budgetHeaderReadingByTreeSegmentLabel,
          onChanged: onChanged,
          isActiveOverride: isActiveOverride,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetDocumentReading.byDate,
          current: value,
          label: tr.budgetHeaderReadingByDateSegmentLabel,
          onChanged: onChanged,
          isActiveOverride: isActiveOverride,
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
