// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// The horizontal padding of every segmented switch's own segments, in logical pixels — mirrors
/// `OcptBreakdownHeader`'s own `_ocptBreakdownSegmentPadding`.
const double _ocptBudgetSegmentPadding = 12;

/// The narrowest the header is drawn with its title and subtitle at all, in logical pixels. Under
/// this, only the three controls are left — they are the only way to change what the centre shows,
/// exactly the reasoning `OcptBreakdownHeader`'s own doc comment gives for shedding its own hint
/// and progress bar first.
///
/// **Raised from `980` to `1120` once the view switch grew a third segment** (`cashJournal`), from
/// `1120` to `1260` once it grew a fourth (`committed`), from `1260` to `1400` once it grew a fifth
/// (`financing`), from `1400` to `1540` once it grew a sixth (`regie`), and from `1540` to `1680`
/// once it grew a seventh and last (`sharing`, `OcptBudgetCentreView`'s own doc comment): each new
/// chip widens that one switch by roughly a segment's own width, and letting the title claim the
/// space that segment now needs would have squeezed the controls together right at the edge this
/// constant is meant to guarantee they never reach — so the threshold moves out by the same margin
/// every time, keeping the controls exactly as comfortable against a real font as they were with
/// fewer views.
///
/// Raised again, from `1680` to `1860`, once the header grew a **fourth control**: the poste
/// filter, whose chip is the only one of them sized by free text (a poste's own label, capped at
/// 160 px) rather than by a fixed word. The rule is the same one, applied to a control instead of
/// a segment.
const double _ocptBudgetHeaderTitleMinWidth = 1860;

/// The budget mode's own header band, sitting above the centre: the mode's own title and a muted
/// subtitle, the `Dashboard`/`Cost tracking` view chips, the simplified/detailed switch and the
/// excluding/including-tax switch.
///
/// Purely presentational: it renders and reports every click upward, reading nothing off a
/// manager. **Nothing here writes to the project** — the view, the simplified/detailed reading and
/// the tax basis are all display preferences the mode itself holds in memory, never a project
/// column — so, like `OcptBreakdownHeader`, this widget needs no `isReadOnly` flag: a previewed
/// version withholds nothing this header offers.
///
/// **Both toggles are always offered.** Neither is ever withheld or disabled according to what the
/// project currently holds (`docs/architecture/budget.md`): there is no conditional branch here,
/// only a value that may turn out empty once the centre reads it. The three controls (the view
/// chips and the two switches) are never dropped even on a narrow window — see
/// [_ocptBudgetHeaderTitleMinWidth] — since, exactly as `OcptBreakdownHeader` argues for its own
/// switch and search field, they are the only way to change what the centre shows.
class OcptBudgetHeader extends StatelessWidget {
  /// Which of the two centre views is currently active.
  final OcptBudgetCentreView centreView;

  /// Called with the view just picked, when a chip is clicked.
  final ValueChanged<OcptBudgetCentreView> onCentreViewSelected;

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

  /// Class constructor
  const OcptBudgetHeader({
    super.key,
    required this.centreView,
    required this.onCentreViewSelected,
    required this.isSimplified,
    required this.onSimplifiedChanged,
    required this.taxBasis,
    required this.onTaxBasisChanged,
    required this.postes,
    required this.filterPosteId,
    required this.onPosteFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTitleShown = constraints.maxWidth >= _ocptBudgetHeaderTitleMinWidth;

          final controls = [
            _OcptBudgetCentreViewSwitch(value: centreView, onChanged: onCentreViewSelected),
            _OcptBudgetSimplifiedSwitch(value: isSimplified, onChanged: onSimplifiedChanged),
            _OcptBudgetTaxBasisSwitch(value: taxBasis, onChanged: onTaxBasisChanged),
            _OcptBudgetPosteFilter(
              postes: postes,
              filterPosteId: filterPosteId,
              isSimplified: isSimplified,
              isHonouredHere: ocptBudgetCentreViewHonoursPosteFilter(centreView),
              onChanged: onPosteFilterSelected,
            ),
          ];

          // Under the title's own threshold the three controls **wrap onto a second line** rather
          // than sitting in a `Row` that runs off the edge, exactly as `OcptScheduleHeader` already
          // lays its own out. Dropping the title is not enough on its own: the centre pane narrows
          // for a reason the header cannot see — the right dock opening takes roughly 580 px of it
          // — and a plain `Row` then clips silently, taking the tax-basis switch off the screen
          // altogether. A control that has scrolled out of a clipped row is worse than a disabled
          // one, since nothing on screen says it exists at all.
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
              if (isTitleShown) ...[
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
              ],
              for (final control in controls) ...[
                if (control != controls.first) const SizedBox(width: 12),
                control,
              ],
            ],
          );
        },
      ),
    );
  }

  /// The band's own title, naming **the view currently on screen** rather than the mode.
  ///
  /// At M1 this was the single word `Quote`, which was true of both views the mode then had. It
  /// stopped being true the moment the cash journal and the committed spending joined them: a band
  /// announcing the CNC nomenclature over a list of bank movements states something the screen
  /// plainly contradicts, and a reader trusts the band before they trust their own reading of the
  /// table.
  ///
  /// **No view is re-worded under the simplified reading any more.** The two that were — the cash
  /// journal and the committed spending — each said one word as a chip and another as a title, and
  /// the reader had to hold both. `Cash flow` needs no plainer synonym, and the committed spending
  /// is now reached through the `Planned` chip's own sub-switch, which words itself.
  ///
  /// The two halves of `Planned` are titled by that chip and that sub-switch **joined**, so the
  /// band, the chip and the sub-switch never say three different things about one screen.
  String _titleOf(Tr tr) => switch (centreView) {
    OcptBudgetCentreView.dashboard => tr.budgetHeaderDashboardTitle,
    OcptBudgetCentreView.costTracking => tr.budgetHeaderTitle,
    OcptBudgetCentreView.cashJournal => tr.budgetHeaderCashJournalTitle,
    OcptBudgetCentreView.committed => tr.budgetHeaderPlannedTitle(
      tr.budgetPlannedOutgoingSegmentLabel,
    ),
    OcptBudgetCentreView.financing => tr.budgetHeaderPlannedTitle(
      tr.budgetPlannedIncomingSegmentLabel,
    ),
    OcptBudgetCentreView.regie => tr.budgetHeaderRegieTitle,
    OcptBudgetCentreView.sharing => tr.budgetHeaderSharingTitle,
  };

  /// The band's own subtitle, following [_titleOf]'s own view — see its doc comment.
  ///
  /// `costTracking` keeps the pair the band has always carried: that view really is the CNC
  /// nomenclature, and its wording was never the thing that went wrong.
  String _subtitleOf(Tr tr) => switch (centreView) {
    OcptBudgetCentreView.dashboard => tr.budgetHeaderDashboardSubtitle,
    OcptBudgetCentreView.costTracking => tr.budgetHeaderSubtitle,
    OcptBudgetCentreView.cashJournal => tr.budgetHeaderCashJournalSubtitle,
    OcptBudgetCentreView.committed => tr.budgetHeaderCommittedSubtitle,
    OcptBudgetCentreView.financing => tr.budgetHeaderFinancingSubtitle,
    OcptBudgetCentreView.regie => tr.budgetHeaderRegieSubtitle,
    OcptBudgetCentreView.sharing => tr.budgetHeaderSharingSubtitle,
  };
}

/// One segment of any of this header's three switches — a small bordered rounded container, the
/// active segment filled `primary` and bolder, mirroring `OcptBreakdownHeader`'s own
/// `_OcptBreakdownViewSwitch._buildSegment`.
class _OcptBudgetSwitchSegment<T> extends StatelessWidget {
  /// This segment's own value.
  final T value;

  /// The switch's current value.
  final T current;

  /// The values **other than [value]** that also light this segment.
  ///
  /// Empty for every switch whose segments map one-to-one onto their values, which is all of them
  /// but one: the `Planned` chip stands for two centre views — the financing plan and the
  /// committed spending — and has to read active for either, the sub-switch inside the view being
  /// what moves between them. Clicking a segment that is already active does nothing, so a reader
  /// on one half never falls back onto the other by clicking the chip they are already on.
  final Set<T> alsoActiveFor;

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
    this.alsoActiveFor = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = value == current || alsoActiveFor.contains(current);

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
/// **The mode's only filter control, and its only filter indicator.** Both jobs used to live
/// inside the cash journal's own top band, which was the single place in the mode that admitted a
/// filter existed at all — so a filter set by clicking a row in the quote was invisible until the
/// reader happened to open the journal, and its off switch sat unlabelled in a row of figures.
/// Sitting in the header, it is on screen whatever view is.
///
/// **It states when it is not being honoured** rather than going quiet: on the three views with no
/// poste dimension (`ocptBudgetCentreViewHonoursPosteFilter`), the chip keeps the poste's name —
/// the filter really is still set, and leaving would bring it back — and adds `Not applied here`
/// under it. Hiding the chip there would have been calmer and dishonest: a reader would take an
/// unfiltered view for a filtered one.
///
/// Writes nothing to the project, exactly as this header's three switches do not, so it needs no
/// read-only handling: a previewed version filters as freely as a live one.
class _OcptBudgetPosteFilter extends StatelessWidget {
  /// Every live poste of the project.
  final List<OcptBudgetPoste> postes;

  /// The poste currently filtered, or null for the whole project.
  final String? filterPosteId;

  /// Whether the header's simplified/detailed switch currently reads simplified — a poste's own
  /// displayed name follows it, exactly as it does everywhere else in the mode.
  final bool isSimplified;

  /// Whether the view currently on screen narrows itself to [filterPosteId] at all.
  final bool isHonouredHere;

  /// Called with the poste just picked, or null to go back to the whole project.
  final ValueChanged<String?> onChanged;

  /// Class constructor
  const _OcptBudgetPosteFilter({
    required this.postes,
    required this.filterPosteId,
    required this.isSimplified,
    required this.isHonouredHere,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final filtered = postes.where((poste) => poste.id == filterPosteId).firstOrNull;
    final isFiltering = filtered != null;
    final color = isFiltering && isHonouredHere
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                    if (isFiltering && !isHonouredHere)
                      Text(
                        tr.budgetHeaderPosteFilterNotHereCaption,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
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

/// The bordered rounded shell every one of this header's three switches shares, mirroring
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
    // A `Wrap` rather than a `Row`, so the seven view chips flow onto a second line inside their
    // own border when the centre is too narrow to hold them side by side — the right dock opening
    // on a 1280 px window is enough to cause it. Handed an unbounded width, as the wide branch's
    // own `Row` hands it, a `Wrap` lays everything out on one line, so the comfortable case is
    // untouched. These segments are `InkWell`s, not `MenuItemButton`s, so `AGENTS.md`'s standing
    // pitfall about a menu item inside a `Wrap` does not apply here.
    child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: children),
  );
}

/// The six view chips, in the order the money itself runs.
///
/// **No chip is worded by the simplified reading any more.** Two were: `Cash journal` and
/// `Committed` are trade words, and the switch handed a five-person crew `Spending` and `To pay`
/// instead. Both re-wordings have since lost their reason. The journal's chip now says
/// `Cash flow`, which needs no plainer synonym and is what the band and the help panel say too;
/// and the committed spending is no longer a chip at all — it is one half of `Planned`, reached
/// through a sub-switch that words itself in either reading.
///
/// What is left is a bar that reads as a sentence: `Dashboard`, then `Quote`, `Planned` and
/// `Cash flow` — what the film should cost, what is promised in either direction, what has
/// actually moved — then `Régie` (the French reading of the catering-and-travel view, kept as the
/// trade word, `docs/architecture/budget.md`) and `Revenue sharing`.
class _OcptBudgetCentreViewSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBudgetCentreView value;

  /// Called with the view just clicked.
  final ValueChanged<OcptBudgetCentreView> onChanged;

  /// Class constructor
  const _OcptBudgetCentreViewSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.dashboard,
          current: value,
          label: tr.budgetHeaderDashboardSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.costTracking,
          current: value,
          label: tr.budgetHeaderCostTrackingSegmentLabel,
          onChanged: onChanged,
        ),
        // `Planned` is **one chip standing for two views**: what is promised to the production and
        // what the production has promised are the same kind of money — nothing has moved for
        // either — read in two directions, and a bar of seven chips was asking a reader to hold
        // that distinction as two separate places. `OcptBudgetPlannedSubSwitch`, drawn inside the
        // view itself, is what moves between the two halves; this chip only says which of them is
        // being looked at, and lands on the financing plan when it is reached from elsewhere.
        //
        // Neither value leaves `OcptBudgetCentreView`, so the stored preference still points at
        // the exact half a reader left the mode on, and reopening the app puts them back there.
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.financing,
          current: value,
          alsoActiveFor: const {OcptBudgetCentreView.committed},
          label: tr.budgetHeaderPlannedSegmentLabel,
          onChanged: onChanged,
        ),
        // Cash flow sits **after** Planned rather than ahead of it. It used to come first, on the
        // ground that a production keeping a cash flow and doing no planning at all should not
        // have to walk past two forecasting views to reach the one it opens daily. That reasoning
        // undervalued what the three chips say when read in a row: `Quote`, `Planned`, `Cash flow`
        // is the money's own life — what the film should cost, what is promised in either
        // direction, what has actually moved — and a reader who has that order once needs no
        // explanation of any single view again. Reaching a daily view one chip further along is a
        // cost paid once per session; misreading the mode's shape is paid every time.
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.cashJournal,
          current: value,
          label: tr.budgetHeaderCashJournalSegmentLabel,
          onChanged: onChanged,
        ),
        // Régie and Revenue sharing sit last, in that order — see the class doc comment for why
        // these two segments do follow OcptBudgetCentreView's own order.
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.regie,
          current: value,
          label: tr.budgetHeaderRegieSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.sharing,
          current: value,
          label: tr.budgetHeaderSharingSegmentLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The `Planned` view's own sub-switch: `Coming in` (the financing plan) against `Going out` (the
/// committed spending), drawn **inside the view** rather than in the header band.
///
/// The header's own chip bar says which of the mode's six places a reader is in; this says which
/// half of one of them. Putting both questions in the same bar was what made it seven chips wide,
/// and it asked a reader to tell two views apart that are the same reading in two directions —
/// money promised, in one sense or the other, none of it moved.
///
/// **The two words deliberately echo the help panel's own map**, whose rows already read
/// `Coming in` and `Going out` against a `Promised`/`Has moved` split: this view *is* that map's
/// promised column, and naming it in the map's own words is what lets the help explain the mode
/// once instead of twice. They keep separate ARB keys all the same, being two different surfaces.
///
/// **Neither label is re-worded under the simplified reading**, unlike the chip the committed
/// spending used to have: `Coming in` and `Going out` carry no trade word for the switch to spare
/// a crew.
class OcptBudgetPlannedSubSwitch extends StatelessWidget {
  /// The centre view currently on screen — always one of `OcptBudgetCentreView.financing` and
  /// `.committed`, this widget being drawn for no other.
  final OcptBudgetCentreView value;

  /// Called with the half just clicked.
  final ValueChanged<OcptBudgetCentreView> onChanged;

  /// Class constructor
  const OcptBudgetPlannedSubSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return _OcptBudgetSwitchShell(
      children: [
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.financing,
          current: value,
          label: tr.budgetPlannedIncomingSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.committed,
          current: value,
          label: tr.budgetPlannedOutgoingSegmentLabel,
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
