// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_centre_view.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';

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
/// here, once it grew a seventh and last (`sharing`, `OcptBudgetCentreView`'s own doc comment):
/// each new chip widens that one switch by roughly a segment's own width, and letting the title
/// claim the space that segment now needs would have squeezed the three controls together right at
/// the edge this constant is meant to guarantee they never reach — so the threshold moves out by
/// the same margin every time, keeping the controls exactly as comfortable against a real font as
/// they were with fewer views.
const double _ocptBudgetHeaderTitleMinWidth = 1680;

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

  /// Class constructor
  const OcptBudgetHeader({
    super.key,
    required this.centreView,
    required this.onCentreViewSelected,
    required this.isSimplified,
    required this.onSimplifiedChanged,
    required this.taxBasis,
    required this.onTaxBasisChanged,
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
            _OcptBudgetCentreViewSwitch(
              value: centreView,
              isSimplified: isSimplified,
              onChanged: onCentreViewSelected,
            ),
            _OcptBudgetSimplifiedSwitch(value: isSimplified, onChanged: onSimplifiedChanged),
            _OcptBudgetTaxBasisSwitch(value: taxBasis, onChanged: onTaxBasisChanged),
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
              controls[0],
              const SizedBox(width: 12),
              controls[1],
              const SizedBox(width: 12),
              controls[2],
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
  /// The two views [_OcptBudgetCentreViewSwitch] re-words under the simplified reading are titled
  /// with **that same word** here: a band announcing `Cash journal` over a chip that says
  /// `Spending` would hand the crew back, in the largest type on the screen, the very trade word
  /// the switch was set to spare them.
  String _titleOf(Tr tr) => switch (centreView) {
    OcptBudgetCentreView.dashboard => tr.budgetHeaderDashboardTitle,
    OcptBudgetCentreView.costTracking => tr.budgetHeaderTitle,
    OcptBudgetCentreView.cashJournal => isSimplified
        ? tr.budgetHeaderCashJournalSimpleSegmentLabel
        : tr.budgetHeaderCashJournalTitle,
    OcptBudgetCentreView.committed => isSimplified
        ? tr.budgetHeaderCommittedSimpleSegmentLabel
        : tr.budgetHeaderCommittedTitle,
    OcptBudgetCentreView.financing => tr.budgetHeaderFinancingTitle,
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

/// The seven view chips.
///
/// **Two of the seven are worded by [isSimplified], and five are not.** `Cash journal` and
/// `Committed` are trade words: they name what an accountant calls those two ledgers, and they are
/// exactly what the simplified reading exists to spare a five-person crew, who know the same two
/// things as `Spending` and `To pay`. `Dashboard`, `Cost tracking`, `Financing`, `Régie` (the
/// French reading of the catering-and-travel view, kept as the trade word exactly as `cashJournal`
/// keeps `Trésorerie` — `docs/architecture/budget.md`) and `Revenue sharing` need no such
/// translation — they already say, in every reading, the plain thing they are — so giving them a
/// second wording would be inventing a difference the words themselves don't carry.
///
/// **`Cash journal` sits third, ahead of `Financing` — not fourth, where `OcptBudgetCentreView`
/// itself places it. `Committed`, `Régie` and `Revenue sharing` sit after it, in that order,
/// matching the enum after all.** The enum's own order is when each view shipped; this row's order
/// is the order most productions actually use the mode in. Most productions using this app do no
/// planning at all: they keep a cash flow, so the view they open every working day cannot sit
/// behind two forecasting views — a quote (`Cost tracking`) and a financing plan (`Financing`)
/// neither of which a five-person crew necessarily builds before the shoot starts. `Cash journal`
/// moving up to third is that reading applied to the chip order itself: the quote, then what has
/// actually moved (`Cash journal`), then what pays for it (`Financing`) and what is still owed
/// (`Committed`), then the catering-and-travel pass read off all of it (`Régie`), then, long after
/// all of it, what the finished film earns (`Revenue sharing`). Listing the segments explicitly,
/// rather than iterating `OcptBudgetCentreView.values`, is what lets the two orders diverge on
/// purpose without one silently following the other.
class _OcptBudgetCentreViewSwitch extends StatelessWidget {
  /// The switch's own current value.
  final OcptBudgetCentreView value;

  /// Whether the header's simplified/detailed switch currently reads simplified — see the class
  /// doc comment for which two segments it re-words, and why only those two.
  final bool isSimplified;

  /// Called with the view just clicked.
  final ValueChanged<OcptBudgetCentreView> onChanged;

  /// Class constructor
  const _OcptBudgetCentreViewSwitch({
    required this.value,
    required this.isSimplified,
    required this.onChanged,
  });

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
        // Cash journal sits third, ahead of Financing and Committed — see the class doc comment
        // for why this deliberately does not follow OcptBudgetCentreView's own, purely historical
        // order: most productions using this app keep a cash flow and do no planning at all, so the
        // view they open every day must not sit behind two forecasting views.
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.cashJournal,
          current: value,
          label: isSimplified
              ? tr.budgetHeaderCashJournalSimpleSegmentLabel
              : tr.budgetHeaderCashJournalSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.financing,
          current: value,
          label: tr.budgetHeaderFinancingSegmentLabel,
          onChanged: onChanged,
        ),
        _OcptBudgetSwitchSegment(
          value: OcptBudgetCentreView.committed,
          current: value,
          label: isSimplified
              ? tr.budgetHeaderCommittedSimpleSegmentLabel
              : tr.budgetHeaderCommittedSegmentLabel,
          onChanged: onChanged,
        ),
        // Régie and Revenue sharing sit last, in that order — see the class doc comment for why
        // these two segments do follow OcptBudgetCentreView's own order, unlike Cash journal above.
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
