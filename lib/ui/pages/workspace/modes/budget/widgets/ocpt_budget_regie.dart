// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_allowances.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_reimbursements.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// The width, in logical pixels, under which the two columns stack instead of sitting side by
/// side — see "A stacked pane states its height" in `docs/architecture/budget.md`, raised a
/// little for the catering table's own eight columns.
const double _ocptRegieWrapWidth = 1000;

/// The catering table's own `Day` column width, in logical pixels.
const double _ocptRegieDayColumnWidth = 56;

/// The catering table's own `Crew`/`Cast`/`Extras` column width, in logical pixels — three narrow,
/// numeric columns.
const double _ocptRegieCountColumnWidth = 64;

/// The catering table's own `Total` column width, in logical pixels — mirrors
/// `OcptBudgetCostTracking`'s own amount columns.
const double _ocptRegieCateringTotalColumnWidth = 108;

/// The catering table's own `Meals`/`Craft services` column width, in logical pixels — wider than
/// [_ocptRegieCountColumnWidth]: the `Meals` cell can read several sittings joined together
/// (`12 + 8`) and the `Craft services` header is two words.
const double _ocptRegieWideCountColumnWidth = 96;

/// The defrayal table's own `Advanced`/`Reimbursed`/`Owed` column width, in logical pixels — mirrors
/// `OcptBudgetFinancing`'s own `_ocptResourcesAmountColumnWidth`, the three money columns this
/// table's own person tree mirrors exactly.
const double _ocptRegieAllowanceAmountColumnWidth = 108;

/// The defrayal table's own trailing `⋮` menu column width, in logical pixels.
const double _ocptRegieAllowanceMenuColumnWidth = 36;

/// The twisty every person group row draws, in logical pixels — mirrors `OcptBudgetFinancing`'s own
/// `_ocptResourcesTwistyWidth` exactly: 28, the theme's own floor for an icon button's own tap
/// target, its own tap target running the full height of the row it sits on
/// (`_OcptRegieAllowanceTwisty`'s own doc comment).
const double _ocptRegieAllowanceTwistyWidth = 28;

/// How far a sub-row indents under its own person group, in logical pixels — mirrors
/// `OcptBudgetFinancing`'s own `_ocptResourcesIndentStep`: a defrayal or a reimbursement sits one
/// step in from the person it names.
const double _ocptRegieAllowanceIndentStep = 16;

/// A defrayal or a reimbursement sub-row's own fixed height, in logical pixels — one step shorter
/// than [_ocptRegieAllowanceRowHeight], mirroring `OcptBudgetFinancing`'s own
/// `_ocptResourcesReceiptRowHeight`.
const double _ocptRegieAllowanceSubRowHeight = 32;

/// The narrowest the `Person`/detail column is ever drawn, in logical pixels — past this, the table
/// scrolls sideways inside its own frame rather than crushing a person's own name or a sub-row's own
/// wording, mirroring `OcptBudgetFinancing`'s own `_ocptResourcesRessourceColumnMinWidth`.
const double _ocptRegieAllowanceDetailColumnMinWidth = 220;

/// A reimbursement sub-row's own leading dot, in logical pixels — mirrors `OcptBudgetFinancing`'s
/// own `_ocptResourcesDotDiameter`.
const double _ocptRegieAllowanceDotDiameter = 8;

/// Either table's own header row height, in logical pixels.
const double _ocptRegieHeaderRowHeight = 36;

/// A catering row's own fixed height, in logical pixels — one line for the day tag, one for the
/// decor's own date underneath it.
const double _ocptRegieCateringRowHeight = 52;

/// A defrayal row's own fixed height, in logical pixels — mirrors [_ocptRegieCateringRowHeight] for
/// the person's own name-and-role pair.
const double _ocptRegieAllowanceRowHeight = 52;

/// The narrowest the catering table is drawn at before it starts scrolling sideways, in logical
/// pixels: its seven fixed columns (548) plus a floor of 220 for the decor's own wording, the one
/// column sized by nothing but an `Expanded`.
///
/// The defrayal table beside it already had [_ocptRegieAllowanceMinTableWidth] for this; the
/// catering table went without one and lost its decor column outright the moment the right dock
/// opened, exactly as the cash journal did.
const double _ocptRegieCateringMinTableWidth = 768;

/// The narrowest the defrayal table is ever drawn at, in logical pixels: its three money columns
/// and its menu column — 3 × 108 + 36 = 360 — plus [_ocptRegieAllowanceDetailColumnMinWidth], **no**
/// extra row inset added, unlike `OcptBudgetFinancing`'s own `_ocptResourcesMinTableWidth`: this
/// table's own rows carry no `ocptTableRowHorizontalPadding` of their own, the Card's own `all(12)`
/// padding already framing the whole table once, header, rows and total alike.
///
/// Below it the table **scrolls sideways inside its own frame**, exactly as the cash journal's own
/// does and for the same reason: the `Person`/detail column is the only flexible one, and this
/// table lives in the narrower third of a two-column view, so a modest centre used to drive it to
/// nothing.
const double _ocptRegieAllowanceMinTableWidth =
    3 * _ocptRegieAllowanceAmountColumnWidth +
    _ocptRegieAllowanceMenuColumnWidth +
    _ocptRegieAllowanceDetailColumnMinWidth;

/// The gap between the two panes once they stack, in logical pixels.
const double _ocptRegieStackGap = 24;

/// A table card's own chrome, in logical pixels: its padding, its header row, the two dividers
/// framing the rows and the total row under them — everything it draws before a single day or
/// defrayal is.
const double _ocptRegieCardChromeHeight = 110;

/// The fewest and the most rows a table card is ever sized for once the panes stack.
///
/// **Stacked, a card is sized by its own content rather than by a share of the height.** Both panes
/// used to take an `Expanded` share of whatever the view had, which works while the view is tall
/// and fails silently once it is not: a share smaller than the heading band and
/// [_ocptRegieCardChromeHeight] leaves the `ListView` nothing at all, so the table prints its header
/// and its total with no day between them, and the pane then spills over the defrayals underneath.
/// Sized by its rows instead, a card always shows them, the heading band always takes the height it
/// needs, and **the view scrolls** when the two together are taller than it — the same answer
/// [_ocptRegieCateringMinTableWidth] gives sideways.
const int _ocptRegieStackedMinRowCount = 2;

const int _ocptRegieStackedMaxRowCount = 8;

/// The shortest either pane is drawn at while they sit side by side, in logical pixels — under it
/// the pair scrolls rather than being crushed, exactly as it does stacked.
const double _ocptRegiePaneMinHeight = 320;

/// The height a table card holding [rowCount] rows of [rowHeight] is drawn at once the panes stack.
double _ocptRegieStackedCardHeight(int rowCount, double rowHeight) =>
    _ocptRegieCardChromeHeight +
    rowHeight * rowCount.clamp(_ocptRegieStackedMinRowCount, _ocptRegieStackedMaxRowCount);

/// How many top-level rows [allowances] draws in the stacked layout's own height guess: one per
/// distinct person named, plus one for every defrayal naming nobody, each its own group of one —
/// never the sub-rows a group's own twisty later reveals, since [_ocptRegieStackedCardHeight]'s own
/// clamp already floors and ceilings this into a reasonable card height either way.
int _ocptRegieAllowanceGroupCountOf(List<OcptBudgetAllowance> allowances) {
  final personIds = <String>{};
  var noPersonCount = 0;
  for (final allowance in allowances) {
    final personId = allowance.personId;
    if (personId == null) {
      noPersonCount++;
    } else {
      personIds.add(personId);
    }
  }

  return personIds.length + noPersonCount;
}

/// The budget mode's catering-and-defrayals view: what each shooting day costs in meals and at the
/// buffet, next to every defrayal the production owes somebody — the layout the validated mockup
/// lays this view out as, **two columns side by side, the catering table taking roughly two thirds
/// and the defrayals one third, wrapping onto one another once the centre narrows past
/// [_ocptRegieWrapWidth]** rather than crushing either column unreadable — and, underneath both, the
/// band that provisions the whole thing into the quote.
///
/// **The two halves are read in opposite directions, and that is the point of the view.** The
/// catering is *computed*: it is read off the schedule and the project's own two unit prices, and
/// nothing about it is typed here. The defrayals are *typed*: `budget_allowances` holds one row per
/// thing actually owed, because what a production pays somebody back is not derivable from their
/// presence on a day — see `OcptBudgetAllowancesTable`'s own doc comment for the shoot this view
/// used to get wrong.
///
/// **The defrayal table is a tree grouped by person, mirroring `OcptBudgetFinancing`'s own resources
/// tree exactly** (`_OcptRegieAllowanceColumn._buildRows`'s own doc comment): a person group row
/// carries the régie's own running account for them — `ADVANCED`, `REIMBURSED`, `OWED` — mirroring
/// the resources tree's `Promis`/`Rentré`/`Reste à venir`, expanding onto their own defrayals then
/// their own reimbursements. A defrayal naming nobody stays its own group of one, counting against
/// the quote and this view's own total but against no running account — see
/// `_OcptRegieAllowanceNoPersonGroupRow`'s own doc comment.
///
/// **This view therefore writes, and carries [isReadOnly] like every other writing view of this
/// mode**: under a previewed version the `Defrayal` button, the row menus and the provisioning
/// gesture are **withheld, never disabled**, expressed as null callbacks.
///
/// **A meal is read off the day's own timetable, one sitting per meal block.**
/// [ocptBudgetRegieDaysOf] (`lib/utils/ocpt_budget_regie.dart`) reads every
/// [OcptShootingBlockKind.meal] block of a day, over that block's own slot alone — a day with a
/// lunch and a dinner block feeds its heads twice, and a day whose timetable holds no meal block at
/// all feeds nobody. That absence prints as [ocptBudgetEmptyValue] in the `Meals` column rather
/// than a `0` that would read as a confirmed "nobody eats today" — the catering column's own
/// caption states the whole rule, so nobody has to read the arithmetic to know what it assumes.
/// **Craft services (the buffet) is unaffected**: it is still one per head, per shooting day,
/// deduplicated exactly as before.
///
/// **Every figure the catering reads is typed somewhere else**, so each of its sources gets a way
/// back to it, reported upward through a callback rather than navigated here: the head counts point
/// at the schedule ([onScheduleOpenRequested]) and the two unit prices at the project settings
/// ([onProjectSettingsRequested]). A defrayal's own person points at their sheet in the resources
/// mode ([onPersonOpenRequested]). `OcptBudgetMode` is what turns each of those into a real
/// dispatch, exactly as it already does for the header's own alert actions.
///
/// Empty state: a project holding no shooting day **and** no defrayal shows [OcptWorkspaceEmptyMode]
/// in place of the two columns. A project with defrayals but no schedule keeps the full layout,
/// since there is now a `+` action of this view's own to keep a heading band drawn for.
///
/// **[OcptBudgetFeedCard] sits at the very top, above the two columns, in both readings** — the
/// empty one included, since a project with nothing here yet is exactly when a way through to the
/// schedule is most useful. Its own catering row is withheld (`onCateringFeedRequested` passed
/// null): it would name this very page, and a link to the page the reader is already standing on is
/// not a link at all.
class OcptBudgetRegie extends StatelessWidget {
  /// Every live shooting day's own catering reading, in the schedule's own day-number order.
  final List<OcptBudgetRegieDay> days;

  /// Every day's own figures folded together.
  final OcptBudgetRegieTotals cateringTotals;

  /// The decor name each day is shot at, keyed by day id — drawn under the day tag.
  final Map<String, String> decorNameByDayId;

  /// The project's own meal price, in cents, or null while nobody has recorded one.
  final int? mealPriceCents;

  /// The project's own craft-services price, in cents, or null while nobody has recorded one.
  final int? buffetPriceCents;

  /// Every live defrayal, in the list's own `sortKey` order.
  final List<OcptBudgetAllowance> allowances;

  /// Every live journal entry of the project, in chronological order — narrowed, row by row, to the
  /// live debits naming the one person each reimbursement sub-row of the defrayal tree draws.
  final List<OcptBudgetEntry> entries;

  /// What has actually been reimbursed against each defrayed person, keyed by their own id — the
  /// tax-inclusive sum of every `budget_entries` debit naming them, `ocptBudgetReimbursedByPersonId`
  /// (`lib/utils/ocpt_budget_reimbursements.dart`). A person with no key here has been reimbursed
  /// nothing at all.
  final Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one — what a
  /// reimbursement sub-row's own debit is grossed up against.
  final int? defaultVatRateBasisPoints;

  /// Every live poste of the quote, offered by the provisioning band's own poste picker.
  final List<OcptBudgetPoste> postes;

  /// The poste the provisioning would write into, or null while this project holds no poste.
  final String? provisionPosteId;

  /// What the provisioning band's own `Quoted on this poste` figure reads: the summed amount of
  /// the lines the provisioning itself wrote onto [provisionPosteId], in cents.
  final int provisionedTotalCents;

  /// Every live role of the project, used to say what a defrayed person is on the shoot.
  final List<OcptRole> roles;

  /// Every live person of the project's address book.
  final List<OcptPerson> people;

  /// How many live elements a live quote line already prices — [OcptBudgetFeedCard]'s own
  /// breakdown row.
  final int breakdownPricedElementCount;

  /// How many live elements no live line prices yet — [OcptBudgetFeedCard]'s own breakdown row,
  /// beside [breakdownPricedElementCount].
  final int breakdownUnpricedElementCount;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the project on screen is a version being previewed, in which case every writing
  /// affordance is withheld rather than disabled.
  final bool isReadOnly;

  /// Which nodes of the defrayal tree are currently expanded — a person's own id, see
  /// `OcptBudgetState.expandedNodeIds`'s own doc comment. A defrayal naming nobody mints no id of
  /// its own here: it draws as its own group of one, with no twisty to expand.
  final Set<String> expandedNodeIds;

  /// Called with a person's own node id when their group row's own twisty is clicked.
  final ValueChanged<String> onNodeExpansionToggled;

  /// Called when the reader asks to go and look at the schedule the head counts are read from —
  /// the catering column's own caption link and [OcptBudgetFeedCard]'s own schedule row alike, the
  /// two gestures being the same request made from two places.
  final VoidCallback onScheduleOpenRequested;

  /// Called when [OcptBudgetFeedCard]'s own breakdown row is clicked.
  final VoidCallback onBreakdownFeedRequested;

  /// Called when the reader asks to go and edit the project's own unit prices.
  final VoidCallback onProjectSettingsRequested;

  /// Called with the id of the person whose own sheet the reader asks to open.
  final ValueChanged<String> onPersonOpenRequested;

  /// Called with the id of the defrayal the reader asks to edit, or null while withheld.
  final ValueChanged<String>? onAllowanceEditRequested;

  /// Called with the id of the defrayal the reader asks to delete, or null while withheld.
  ///
  /// **Asks, it never deletes**: the mode is what opens `OcptConfirmDialog` over it.
  final ValueChanged<String>? onAllowanceDeletionRequested;

  /// Called with the id of the person a person group row's own `⋮` menu asks to reimburse, or null
  /// while withheld — opens the capture wizard's own `reimbursePerson` gesture, pre-filled with
  /// what is currently owed them, exactly as `OcptBudgetFinancing`'s own `Record a receipt` prefills
  /// what is still outstanding.
  final ValueChanged<String>? onPersonReimburseRequested;

  /// Called with the id of the poste the reader picks to provision into.
  final ValueChanged<String>? onProvisionPosteSelected;

  /// Called when the reader asks to provision what this view computes into the quote, or null while
  /// withheld.
  ///
  /// **Asks, it never writes**: the mode is what puts the plan's own counts in front of the reader
  /// and carries it out only if they agree.
  final VoidCallback? onProvisionRequested;

  /// Why there is nothing to provision, or null while there is.
  ///
  /// **The reason sits beside the figures rather than behind a click**: a gesture that would do
  /// nothing is withheld, and what a reader needs then is to know *why* — the quote already holds
  /// everything, or every line it would touch has been edited by hand and is left alone. Saying so
  /// where the button would have been is what keeps this view from answering a click with a dialog
  /// that only says "no".
  final String? provisionNote;

  /// Class constructor
  const OcptBudgetRegie({
    super.key,
    required this.days,
    required this.cateringTotals,
    required this.decorNameByDayId,
    required this.mealPriceCents,
    required this.buffetPriceCents,
    required this.allowances,
    required this.entries,
    required this.reimbursedByPersonId,
    required this.defaultVatRateBasisPoints,
    required this.postes,
    required this.provisionPosteId,
    required this.provisionedTotalCents,
    required this.roles,
    required this.people,
    required this.breakdownPricedElementCount,
    required this.breakdownUnpricedElementCount,
    required this.currencyCode,
    required this.isReadOnly,
    required this.expandedNodeIds,
    required this.onNodeExpansionToggled,
    required this.onScheduleOpenRequested,
    required this.onBreakdownFeedRequested,
    required this.onProjectSettingsRequested,
    required this.onPersonOpenRequested,
    required this.onAllowanceEditRequested,
    required this.onAllowanceDeletionRequested,
    required this.onPersonReimburseRequested,
    required this.onProvisionPosteSelected,
    required this.onProvisionRequested,
    required this.provisionNote,
  });

  @override
  Widget build(BuildContext context) {
    final feedCard = Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OcptBudgetFeedCard(
        breakdownPricedElementCount: breakdownPricedElementCount,
        breakdownUnpricedElementCount: breakdownUnpricedElementCount,
        shootingDayCount: days.length,
        mealCount: cateringTotals.mealCount,
        buffetCount: cateringTotals.buffetCount,
        onBreakdownFeedRequested: onBreakdownFeedRequested,
        onScheduleFeedRequested: onScheduleOpenRequested,
        // Withheld: this is the page it would have named — see the class doc comment.
        onCateringFeedRequested: null,
      ),
    );

    if (days.isEmpty && allowances.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          feedCard,
          Expanded(
            child: OcptWorkspaceEmptyMode(
              icon: Icons.restaurant_outlined,
              message: Tr.of(context).budgetRegieEmptyHint,
            ),
          ),
        ],
      );
    }

    Widget cateringColumn({double? tableHeight}) => _OcptRegieCateringColumn(
      days: days,
      totals: cateringTotals,
      decorNameByDayId: decorNameByDayId,
      mealPriceCents: mealPriceCents,
      buffetPriceCents: buffetPriceCents,
      currencyCode: currencyCode,
      tableHeight: tableHeight,
      onScheduleOpenRequested: onScheduleOpenRequested,
      onProjectSettingsRequested: onProjectSettingsRequested,
    );
    Widget allowanceColumn({double? tableHeight}) => _OcptRegieAllowanceColumn(
      allowances: allowances,
      entries: entries,
      reimbursedByPersonId: reimbursedByPersonId,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      roles: roles,
      people: people,
      currencyCode: currencyCode,
      isReadOnly: isReadOnly,
      expandedNodeIds: expandedNodeIds,
      tableHeight: tableHeight,
      onNodeExpansionToggled: onNodeExpansionToggled,
      onPersonOpenRequested: onPersonOpenRequested,
      onEditRequested: onAllowanceEditRequested,
      onDeletionRequested: onAllowanceDeletionRequested,
      onReimburseRequested: onPersonReimburseRequested,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        feedCard,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= _ocptRegieWrapWidth) {
                // Three fifths to the catering, two to the defrayals — not the two-to-one the
                // old travel table was sized for, which left this one under its own floor and
                // scrolling at any ordinary window width. The catering's own widest column is a
                // decor name, which gives room up more gracefully than six narrow ones do.
                //
                // Side by side, both panes take the whole height, floored at
                // [_ocptRegiePaneMinHeight].
                return _OcptRegieVerticalScroller(
                  height: math.max(constraints.maxHeight, _ocptRegiePaneMinHeight),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: cateringColumn()),
                      const SizedBox(width: _ocptRegieStackGap),
                      Expanded(flex: 2, child: allowanceColumn()),
                    ],
                  ),
                );
              }

              // Stacked, each pane takes the height its own heading band and rows need, and the
              // view scrolls when the two together are taller than it — see
              // [_ocptRegieStackedMinRowCount] for why a share of the height cannot be used here.
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cateringColumn(
                      tableHeight: _ocptRegieStackedCardHeight(
                        days.length,
                        _ocptRegieCateringRowHeight,
                      ),
                    ),
                    const SizedBox(height: _ocptRegieStackGap),
                    allowanceColumn(
                      tableHeight: _ocptRegieStackedCardHeight(
                        _ocptRegieAllowanceGroupCountOf(allowances),
                        _ocptRegieAllowanceRowHeight,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _OcptRegieProvisionBand(
          computedTotalCents: cateringTotals.cost.amountCents + ocptBudgetAllowancesTotalCents(allowances),
          provisionedTotalCents: provisionedTotalCents,
          postes: postes,
          provisionPosteId: provisionPosteId,
          currencyCode: currencyCode,
          // Withheld under a previewed version, never disabled — the same reading the defrayal
          // column applies to its own `Defrayal` button and row menus.
          onPosteSelected: isReadOnly ? null : onProvisionPosteSelected,
          onProvisionRequested: isReadOnly ? null : onProvisionRequested,
          note: provisionNote,
        ),
      ],
    );
  }
}

/// The frame the two panes are drawn in: [child] at exactly [height], scrolling vertically as soon
/// as that is taller than the view.
///
/// **The height is always stated, never left to the panes.** Side by side, both of them size their
/// own table with an `Expanded`, which needs a bounded height to mean anything, so this hands them
/// the view's own — floored at [_ocptRegiePaneMinHeight], under which the pair scrolls rather than
/// being crushed out of its rows.
class _OcptRegieVerticalScroller extends StatelessWidget {
  /// The height the child is drawn at.
  final double height;

  /// The pane, or the pair of panes, being framed.
  final Widget child;

  /// Class constructor
  const _OcptRegieVerticalScroller({required this.height, required this.child});

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(child: SizedBox(height: height, child: child));
}

/// A table card inside its own pane: drawn at exactly [height] once the panes stack, and taking
/// whatever the heading band leaves it while they sit side by side.
///
/// See [_ocptRegieStackedMinRowCount] for why the stacked reading states a height rather than
/// taking a share of one.
class _OcptRegieTablePane extends StatelessWidget {
  /// The height the card is drawn at, or null while it takes what is left.
  final double? height;

  /// The card being framed.
  final Widget child;

  /// Class constructor
  const _OcptRegieTablePane({required this.height, required this.child});

  @override
  Widget build(BuildContext context) => height == null
      ? Expanded(child: child)
      : SizedBox(height: height, child: child);
}

/// The left column: the heading band with its two captions, then the catering table.
class _OcptRegieCateringColumn extends StatelessWidget {
  /// See [OcptBudgetRegie]'s own fields of the same name.
  final List<OcptBudgetRegieDay> days;
  final OcptBudgetRegieTotals totals;
  final Map<String, String> decorNameByDayId;
  final int? mealPriceCents;
  final int? buffetPriceCents;
  final String currencyCode;
  final VoidCallback onScheduleOpenRequested;
  final VoidCallback onProjectSettingsRequested;

  /// The height the table card is drawn at, or null while the panes sit side by side and the card
  /// takes whatever height the heading band leaves it — see [_ocptRegieStackedMinRowCount].
  final double? tableHeight;

  /// Class constructor
  const _OcptRegieCateringColumn({
    required this.days,
    required this.totals,
    required this.decorNameByDayId,
    required this.mealPriceCents,
    required this.buffetPriceCents,
    required this.currencyCode,
    required this.tableHeight,
    required this.onScheduleOpenRequested,
    required this.onProjectSettingsRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // Stated by its own rows once it is stacked, so the pane takes no more room than it needs
      // and the view scrolls instead — see [_ocptRegieStackedMinRowCount].
      mainAxisSize: tableHeight == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(tr.budgetRegieCateringSectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                tr.budgetRegieCateringPriceCaption(
                  mealPriceCents == null
                      ? ocptBudgetEmptyValue
                      : ocptBudgetAmountLabel(mealPriceCents!, currencyCode),
                  buffetPriceCents == null
                      ? ocptBudgetEmptyValue
                      : ocptBudgetAmountLabel(buffetPriceCents!, currencyCode),
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(onPressed: onProjectSettingsRequested, child: Text(tr.budgetRegiePricesEditAction)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                tr.budgetRegieCateringScheduleHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(onPressed: onScheduleOpenRequested, child: Text(tr.budgetRegieOpenScheduleAction)),
          ],
        ),
        const SizedBox(height: 8),
        _OcptRegieTablePane(
          height: tableHeight,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  // Header, rows and total scroll **together**, inside one frame, for the reason
                  // `OcptBudgetCashJournal` gives: they share one set of fixed column widths.
                  child: SizedBox(
                    width: math.max(constraints.maxWidth, _ocptRegieCateringMinTableWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _OcptRegieCateringHeaderRow(),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: days.length,
                            itemBuilder: (context, index) => _OcptRegieCateringRow(
                              day: days[index],
                              decorName: decorNameByDayId[days[index].dayId],
                              currencyCode: currencyCode,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        _OcptRegieCateringTotalRow(totals: totals, currencyCode: currencyCode),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The catering table's own header row: `Day`, `Decor`, `Crew`, `Cast`, `Extras`, `Meals`,
/// `Craft services`, `Total`.
class _OcptRegieCateringHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptRegieCateringHeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: _ocptRegieHeaderRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: _ocptRegieDayColumnWidth,
            child: Text(tr.budgetRegieColumnDay.toUpperCase(), style: labelStyle),
          ),
          Expanded(child: Text(tr.budgetRegieColumnDecor.toUpperCase(), style: labelStyle)),
          SizedBox(
            width: _ocptRegieCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnCrew.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptRegieCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnCast.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptRegieCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnExtras.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptRegieWideCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnMeals.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptRegieWideCountColumnWidth,
            child: Text(
              tr.budgetRegieColumnBuffet.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptRegieCateringTotalColumnWidth,
            child: Text(
              tr.budgetRegieColumnTotal.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// One shooting day's own catering row: its day tag in the accent colour, [decorName] with the
/// day's own date underneath in small muted type, the three crew/cast/extras head counts, the
/// `Meals` cell (see below), the buffet's own head count, then the day's own money —
/// [ocptBudgetEmptyValue] rather than a claimed zero the moment neither the meal nor the buffet
/// price is known (`OcptBudgetRegieDay.cost.coveredLineCount == 0`), mirroring
/// `OcptBudgetCostTracking`'s own secondary-basis cell.
///
/// **The `Meals` cell reads [OcptBudgetRegieDay.mealSittings] itself, not the plain
/// [OcptBudgetRegieDay.mealCount].** A day with no meal block in its own timetable prints
/// [ocptBudgetEmptyValue] — a stated absence, never a `0` that would look exactly like a day whose
/// timetable does hold a meal block feeding nobody. A day with more than one sitting (a lunch and a
/// dinner block, say) joins every sitting's own head count with `+` rather than folding them into
/// one number, so a reader sees that two feedings happened rather than reading a total that could
/// just as well be one big one.
class _OcptRegieCateringRow extends StatelessWidget {
  /// The day this row draws.
  final OcptBudgetRegieDay day;

  /// The decor name to print under the day tag, or null while none of the day's own slots name one.
  final String? decorName;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptRegieCateringRow({required this.day, required this.decorName, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final decorName = this.decorName;
    final costText = day.cost.coveredLineCount == 0
        ? ocptBudgetEmptyValue
        : ocptBudgetAmountLabel(day.cost.amountCents, currencyCode);

    return SizedBox(
      height: _ocptRegieCateringRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: _ocptRegieDayColumnWidth,
            child: Text(
              ocptScheduleDayTagLabel(tr, day.dayNumber),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (decorName != null)
                    Text(
                      decorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(
                    DateFormat.yMMMd(locale).format(day.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          _countCell(context, day.crewCount),
          _countCell(context, day.castCount),
          _countCell(context, day.extraCount),
          _mealsCell(context),
          _wideCountCell(context, day.buffetCount),
          SizedBox(
            width: _ocptRegieCateringTotalColumnWidth,
            child: Text(
              costText,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// One of the three narrow, right-aligned head-count cells (`Crew`, `Cast`, `Extras`).
  Widget _countCell(BuildContext context, int count) => SizedBox(
    width: _ocptRegieCountColumnWidth,
    child: Text("$count", textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall),
  );

  /// The `Craft services` cell — a plain head count, at the wider column width the `Meals` cell
  /// beside it also needs.
  Widget _wideCountCell(BuildContext context, int count) => SizedBox(
    width: _ocptRegieWideCountColumnWidth,
    child: Text("$count", textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall),
  );

  /// The `Meals` cell — see the class doc comment for the dash-versus-joined-sittings reading.
  Widget _mealsCell(BuildContext context) {
    final sittings = day.mealSittings;
    final text = sittings.isEmpty
        ? ocptBudgetEmptyValue
        : sittings.map((sitting) => "${sitting.headCount}").join(" + ");

    return SizedBox(
      width: _ocptRegieWideCountColumnWidth,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// The catering table's own total row: the summed meals (every day's own sittings folded together,
/// [OcptBudgetRegieDay.mealCount]'s own sum), buffet servings and money over every printed day — the
/// coverage read-out in place of the plain amount for as long as the project has not recorded both
/// prices, mirroring `OcptBudgetCostTracking`'s own total row.
class _OcptRegieCateringTotalRow extends StatelessWidget {
  /// [OcptBudgetRegie.days] folded into one total.
  final OcptBudgetRegieTotals totals;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptRegieCateringTotalRow({required this.totals, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final amountText = ocptBudgetAmountLabel(totals.cost.amountCents, currencyCode);
    final costText = totals.cost.isComplete
        ? amountText
        : tr.budgetRegieCateringCoverageReadOut(
            amountText,
            totals.cost.coveredLineCount,
            totals.cost.lineCount,
          );

    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    // Mirrors `_OcptRegieCateringHeaderRow`'s own column structure exactly (the `Day` column
    // blank, the label sitting in the `Decor` column's own flexible slot, then a blank `Crew`,
    // `Cast` and `Extras` cell before the two summed counts), so this row's own cells line up
    // under the header that names them rather than drifting once the `Decor` column happens to
    // grow or shrink.
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: _ocptRegieDayColumnWidth),
          Expanded(child: Text(tr.budgetCostTrackingTotalRowLabel, style: boldStyle)),
          const SizedBox(width: _ocptRegieCountColumnWidth),
          const SizedBox(width: _ocptRegieCountColumnWidth),
          const SizedBox(width: _ocptRegieCountColumnWidth),
          SizedBox(
            width: _ocptRegieWideCountColumnWidth,
            child: Text("${totals.mealCount}", textAlign: TextAlign.right, style: boldStyle),
          ),
          SizedBox(
            width: _ocptRegieWideCountColumnWidth,
            child: Text("${totals.buffetCount}", textAlign: TextAlign.right, style: boldStyle),
          ),
          SizedBox(
            width: _ocptRegieCateringTotalColumnWidth,
            child: Text(
              costText,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: boldStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// The right column: the heading band with its caption, then the defrayal tree — its own creation
/// gesture removed, every defrayal now typed through the capture wizard's own `defrayPerson`
/// gesture instead.
///
/// **A tree grouped by person, mirroring `OcptBudgetFinancing`'s own resources tree exactly**: a
/// person group row carries the régie's own running account for them — `ADVANCED`, `REIMBURSED`,
/// `OWED` — mirroring the resources tree's `Promis`/`Rentré`/`Reste à venir`, expanding onto their
/// own defrayals then their own reimbursements. See the class doc comment above for the money rules
/// and [_buildRows] for how the tree is flattened.
class _OcptRegieAllowanceColumn extends StatelessWidget {
  /// See [OcptBudgetRegie]'s own fields of the same name.
  final List<OcptBudgetAllowance> allowances;
  final List<OcptBudgetEntry> entries;
  final Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId;
  final int? defaultVatRateBasisPoints;
  final List<OcptRole> roles;
  final List<OcptPerson> people;
  final String currencyCode;
  final bool isReadOnly;
  final Set<String> expandedNodeIds;
  final ValueChanged<String> onNodeExpansionToggled;
  final ValueChanged<String> onPersonOpenRequested;
  final ValueChanged<String>? onEditRequested;
  final ValueChanged<String>? onDeletionRequested;
  final ValueChanged<String>? onReimburseRequested;

  /// The height the table card is drawn at, or null while the panes sit side by side and the card
  /// takes whatever height the heading band leaves it — see [_ocptRegieStackedMinRowCount].
  final double? tableHeight;

  /// Class constructor
  const _OcptRegieAllowanceColumn({
    required this.allowances,
    required this.entries,
    required this.reimbursedByPersonId,
    required this.defaultVatRateBasisPoints,
    required this.roles,
    required this.people,
    required this.currencyCode,
    required this.isReadOnly,
    required this.expandedNodeIds,
    required this.tableHeight,
    required this.onNodeExpansionToggled,
    required this.onPersonOpenRequested,
    required this.onEditRequested,
    required this.onDeletionRequested,
    required this.onReimburseRequested,
  });

  /// [people], keyed by their own id.
  Map<String, OcptPerson> get _personById => {for (final person in people) person.id: person};

  /// [roles], keyed by the person each one is played by — a role naming no person carries no key.
  Map<String, OcptRole> get _roleByPersonId => {
    for (final role in roles)
      if (role.personId != null) role.personId!: role,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final rows = _buildRows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // Stated by its own rows once it is stacked — see the catering column's own reading.
      mainAxisSize: tableHeight == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(tr.budgetRegieAllowancesSectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          tr.budgetRegieAllowancesHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _OcptRegieTablePane(
          height: tableHeight,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: allowances.isEmpty
                  ? Center(
                      child: Text(
                        tr.budgetRegieAllowancesEmptyHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: math.max(constraints.maxWidth, _ocptRegieAllowanceMinTableWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _OcptRegieAllowanceHeaderRow(),
                              const Divider(height: 1),
                              Expanded(child: ListView(children: [for (final row in rows) _rowOf(row)])),
                              const Divider(height: 1),
                              _OcptRegieAllowanceTotalRow(
                                allowances: allowances,
                                entries: entries,
                                defaultVatRateBasisPoints: defaultVatRateBasisPoints,
                                currencyCode: currencyCode,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// The whole tree, flattened top to bottom into one list — mirrors
  /// `OcptBudgetFinancing._buildRows`'s own reading exactly: a person group row draws whenever a
  /// live defrayal or a live reimbursement names them, its own sub-rows draw only while their own
  /// id sits in [expandedNodeIds]. A defrayal naming nobody draws as its own group of one, in the
  /// list's own `sortKey` order, right where [allowances] would have put it — see
  /// `_OcptRegieAllowanceNoPersonGroupRow`'s own doc comment.
  ///
  /// **A person is named twice over: by their own defrayals and by their own reimbursements**, and
  /// either alone is enough to draw their group — a person reimbursed against a défraiement since
  /// deleted still has a running account worth reading. Every person a live defrayal names is added
  /// first, in [allowances]' own order; a person reimbursed but never defrayed is appended after,
  /// in [entries]' own order, since nothing in [allowances] ever named them.
  List<_OcptRegieAllowanceTreeRow> _buildRows() {
    final rows = <_OcptRegieAllowanceTreeRow>[];
    final seenPersonIds = <String>{};

    void addPersonGroup(String personId) {
      if (!seenPersonIds.add(personId)) {
        return;
      }

      final advancedCents = ocptBudgetPersonAdvancedCents(personId, allowances);
      final reimbursedCents = ocptBudgetPersonReimbursedCentsOf(
        personId,
        entries,
        projectVatRateBasisPoints: defaultVatRateBasisPoints,
      ).amountCents;
      final isExpanded = expandedNodeIds.contains(personId);

      rows.add(
        _OcptRegieAllowancePersonGroupRow(
          personId: personId,
          person: _personById[personId],
          role: _roleByPersonId[personId],
          advancedCents: advancedCents,
          reimbursedCents: reimbursedCents,
          outstandingCents: ocptBudgetPersonOutstandingCents(
            advancedCents: advancedCents,
            reimbursedCents: reimbursedCents,
          ),
          isExpanded: isExpanded,
        ),
      );
      if (!isExpanded) {
        return;
      }

      for (final allowance in allowances) {
        if (allowance.personId == personId) {
          rows.add(_OcptRegieAllowanceDefrayalSubRow(allowance: allowance));
        }
      }
      for (final entry in entries) {
        if (entry.personId == personId) {
          rows.add(_OcptRegieAllowanceReimbursementSubRow(entry: entry));
        }
      }
    }

    for (final allowance in allowances) {
      final personId = allowance.personId;
      if (personId == null) {
        rows.add(_OcptRegieAllowanceNoPersonGroupRow(allowance: allowance));
        continue;
      }

      addPersonGroup(personId);
    }
    for (final entry in entries) {
      final personId = entry.personId;
      if (personId != null) {
        addPersonGroup(personId);
      }
    }

    return rows;
  }

  /// Builds the widget for one flattened [row].
  Widget _rowOf(_OcptRegieAllowanceTreeRow row) => switch (row) {
    _OcptRegieAllowancePersonGroupRow() => _OcptRegieAllowancePersonRow(
      person: row.person,
      role: row.role,
      advancedCents: row.advancedCents,
      reimbursedCents: row.reimbursedCents,
      outstandingCents: row.outstandingCents,
      currencyCode: currencyCode,
      isExpanded: row.isExpanded,
      onTwistyTap: () => onNodeExpansionToggled(row.personId),
      // Navigation, not a write: never withheld under [isReadOnly] — mirrors the very same reading
      // this menu entry already followed on the flat table.
      onPersonOpenRequested: () => onPersonOpenRequested(row.personId),
      onReimburseRequested: isReadOnly || onReimburseRequested == null
          ? null
          : () => onReimburseRequested?.call(row.personId),
    ),
    _OcptRegieAllowanceNoPersonGroupRow() => _OcptRegieAllowanceNoPersonRow(
      allowance: row.allowance,
      currencyCode: currencyCode,
      onTap: isReadOnly || onEditRequested == null
          ? null
          : () => onEditRequested?.call(row.allowance.id),
      onDeletionRequested: isReadOnly || onDeletionRequested == null
          ? null
          : () => onDeletionRequested?.call(row.allowance.id),
    ),
    _OcptRegieAllowanceDefrayalSubRow() => _OcptRegieAllowanceDefrayalRow(
      allowance: row.allowance,
      currencyCode: currencyCode,
      onTap: isReadOnly || onEditRequested == null
          ? null
          : () => onEditRequested?.call(row.allowance.id),
      onPersonOpenRequested: () => onPersonOpenRequested(row.allowance.personId!),
      onDeletionRequested: isReadOnly || onDeletionRequested == null
          ? null
          : () => onDeletionRequested?.call(row.allowance.id),
    ),
    _OcptRegieAllowanceReimbursementSubRow() => _OcptRegieAllowanceReimbursementRow(
      entry: row.entry,
      defaultVatRateBasisPoints: defaultVatRateBasisPoints,
      currencyCode: currencyCode,
    ),
  };
}

/// One flattened row of the defrayal tree — see
/// `_OcptRegieAllowanceColumn._buildRows`'s own doc comment.
sealed class _OcptRegieAllowanceTreeRow {
  const _OcptRegieAllowanceTreeRow();
}

/// A person group row — the tree's own top level, carrying that person's own running account.
class _OcptRegieAllowancePersonGroupRow extends _OcptRegieAllowanceTreeRow {
  /// The person's own id — every sub-row under this group names it too.
  final String personId;

  /// The person this row names, or null while [personId] names nobody the address book still
  /// holds — drawn with [OcptBudgetRegie]'s own `Nobody in particular`-style fallback rather than
  /// crashing on a stale reference.
  final OcptPerson? person;

  /// What that person is on the shoot, or null.
  final OcptRole? role;

  /// What this person has advanced — `ocptBudgetPersonAdvancedCents`.
  final int advancedCents;

  /// What this person has actually been reimbursed — `ocptBudgetPersonReimbursedCentsOf`'s own
  /// `.amountCents`.
  final int reimbursedCents;

  /// What is still owed them — `ocptBudgetPersonOutstandingCents`, not clamped at zero.
  final int outstandingCents;

  /// Whether this group is currently expanded.
  final bool isExpanded;

  /// Class constructor
  const _OcptRegieAllowancePersonGroupRow({
    required this.personId,
    required this.person,
    required this.role,
    required this.advancedCents,
    required this.reimbursedCents,
    required this.outstandingCents,
    required this.isExpanded,
  });
}

/// A defrayal naming nobody — its own group of one, no twisty since there is nothing to expand onto
/// and no running account to page through: a défraiement that belongs to the production rather than
/// to one person counts against the quote and this table's own total, but against nobody's own
/// `ADVANCED`/`REIMBURSED`/`OWED` — `OcptBudgetAllowancesTable`'s own doc comment.
class _OcptRegieAllowanceNoPersonGroupRow extends _OcptRegieAllowanceTreeRow {
  /// The defrayal this row draws.
  final OcptBudgetAllowance allowance;

  /// Class constructor
  const _OcptRegieAllowanceNoPersonGroupRow({required this.allowance});
}

/// A defrayal sub-row — one step under the person it names, drawn only while their group is
/// expanded.
class _OcptRegieAllowanceDefrayalSubRow extends _OcptRegieAllowanceTreeRow {
  /// The defrayal this row draws.
  final OcptBudgetAllowance allowance;

  /// Class constructor
  const _OcptRegieAllowanceDefrayalSubRow({required this.allowance});
}

/// A reimbursement sub-row — one step under the person it names, drawn right after that person's
/// own defrayals, only while their group is expanded.
class _OcptRegieAllowanceReimbursementSubRow extends _OcptRegieAllowanceTreeRow {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// Class constructor
  const _OcptRegieAllowanceReimbursementSubRow({required this.entry});
}

/// The twisty a person group row draws — mirrors `OcptBudgetFinancing`'s own `_OcptResourcesTwisty`
/// exactly: an arrow while [isExpandable], nothing but its own reserved width otherwise, its own tap
/// target running the full height of the row it sits on.
class _OcptRegieAllowanceTwisty extends StatelessWidget {
  /// Whether this row has anything at all to expand onto.
  final bool isExpandable;

  /// Whether this row is currently expanded.
  final bool isExpanded;

  /// Called when this twisty is clicked, or null while [isExpandable] is false.
  final VoidCallback? onTap;

  /// The row this twisty sits on own fixed height, in logical pixels.
  final double rowHeight;

  /// Class constructor
  const _OcptRegieAllowanceTwisty({
    required this.isExpandable,
    required this.isExpanded,
    this.onTap,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpandable) {
      return const SizedBox(width: _ocptRegieAllowanceTwistyWidth);
    }

    return SizedBox(
      width: _ocptRegieAllowanceTwistyWidth,
      height: rowHeight,
      child: InkWell(
        onTap: onTap,
        mouseCursor: ocptClickableCursor,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
        child: Icon(
          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One amount cell, right-aligned, reading [ocptBudgetEmptyValue] while [cents] is null, blank
/// while [showBlank] (a sub-row's own untouched columns), and the given amount otherwise — mirrors
/// `OcptBudgetFinancing`'s own `_ocptResourcesAmountCell`.
Widget _ocptRegieAllowanceAmountCell(
  BuildContext context,
  int? cents,
  String currencyCode, {
  bool showBlank = false,
  TextStyle? style,
}) {
  final theme = Theme.of(context);
  final isNegative = cents != null && cents < 0;
  final baseStyle = style ?? theme.textTheme.bodySmall;

  return SizedBox(
    width: _ocptRegieAllowanceAmountColumnWidth,
    child: Text(
      showBlank ? "" : (cents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(cents, currencyCode)),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: baseStyle?.copyWith(
        color: isNegative ? theme.colorScheme.error : null,
        fontWeight: isNegative ? FontWeight.w600 : null,
      ),
    ),
  );
}

/// One person group row: a twisty, the person's own name with their role underneath in small muted
/// type, the three running-account figures, then their own `⋮` menu.
class _OcptRegieAllowancePersonRow extends StatelessWidget {
  /// The person this row names, or null — see [_OcptRegieAllowancePersonGroupRow.person]'s own doc
  /// comment.
  final OcptPerson? person;

  /// What that person is on the shoot, or null.
  final OcptRole? role;

  /// What this person has advanced.
  final int advancedCents;

  /// What this person has actually been reimbursed.
  final int reimbursedCents;

  /// What is still owed them.
  final int outstandingCents;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether this group is currently expanded.
  final bool isExpanded;

  /// Called when this row's own twisty is clicked.
  final VoidCallback onTwistyTap;

  /// Called when this row's own `⋮` menu asks to open the person's own sheet.
  final VoidCallback onPersonOpenRequested;

  /// Called when this row's own `⋮` menu asks to reimburse this person, or null while withheld.
  final VoidCallback? onReimburseRequested;

  /// Class constructor
  const _OcptRegieAllowancePersonRow({
    required this.person,
    required this.role,
    required this.advancedCents,
    required this.reimbursedCents,
    required this.outstandingCents,
    required this.currencyCode,
    required this.isExpanded,
    required this.onTwistyTap,
    required this.onPersonOpenRequested,
    required this.onReimburseRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final person = this.person;
    final role = this.role;

    return SizedBox(
      height: _ocptRegieAllowanceRowHeight,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _OcptRegieAllowanceTwisty(
                  isExpandable: true,
                  isExpanded: isExpanded,
                  onTap: onTwistyTap,
                  rowHeight: _ocptRegieAllowanceRowHeight,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        person?.displayName ?? tr.budgetPosteUnnamed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (role != null && role.name.isNotEmpty)
                        Text(
                          role.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _ocptRegieAllowanceAmountCell(context, advancedCents, currencyCode),
          _ocptRegieAllowanceAmountCell(context, reimbursedCents, currencyCode),
          _ocptRegieAllowanceAmountCell(context, outstandingCents, currencyCode),
          SizedBox(
            width: _ocptRegieAllowanceMenuColumnWidth,
            child: PopupMenuButton<String>(
              tooltip: "",
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) => switch (value) {
                "person" => onPersonOpenRequested(),
                "reimburse" => onReimburseRequested?.call(),
                _ => null,
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(value: "person", child: Text(tr.budgetRegieAllowanceOpenPersonAction)),
                if (onReimburseRequested != null)
                  PopupMenuItem<String>(value: "reimburse", child: Text(tr.budgetRegieReimburseAction)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One defrayal naming nobody, drawn as its own top-level row: the wording that has always said so,
/// in italics, its own amount under `ADVANCED` **and** `OWED` — it is owed in full, never paid back
/// through a running account — with `REIMBURSED` left blank. `OWED` reads its amount rather than a
/// blank precisely because the total row counts this defrayal in: a figure that is summed has to be
/// legible on the line it is summed from. No twisty: there is nothing to expand onto.
class _OcptRegieAllowanceNoPersonRow extends StatelessWidget {
  /// The defrayal this row draws.
  final OcptBudgetAllowance allowance;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptRegieAllowanceNoPersonRow({
    required this.allowance,
    required this.currencyCode,
    required this.onTap,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocptClickableCursor,
      child: SizedBox(
        height: _ocptRegieAllowanceRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const _OcptRegieAllowanceTwisty(
                    isExpandable: false,
                    isExpanded: false,
                    rowHeight: _ocptRegieAllowanceRowHeight,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tr.budgetRegieAllowanceNoPerson,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (allowance.label.isNotEmpty)
                          Text(
                            allowance.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _ocptRegieAllowanceAmountCell(context, ocptBudgetAllowanceCentsOf(allowance), currencyCode),
            _ocptRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
            _ocptRegieAllowanceAmountCell(context, ocptBudgetAllowanceCentsOf(allowance), currencyCode),
            SizedBox(
              width: _ocptRegieAllowanceMenuColumnWidth,
              child: onDeletionRequested == null
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: "",
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (_) => onDeletionRequested?.call(),
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(value: "delete", child: Text(tr.budgetCommittedDeleteAction)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One defrayal sub-row: its own wording — nature, when, and how many, joined by `·` — in the
/// detail column, its own amount under `ADVANCED`, `REIMBURSED`/`OWED` left blank since a single
/// défraiement carries no running account of its own, only the person above it does. Then its own
/// `⋮` menu — see `OcptBudgetRegie`'s own class doc comment for the menu's own withholding rules.
class _OcptRegieAllowanceDefrayalRow extends StatelessWidget {
  /// The defrayal this row draws.
  final OcptBudgetAllowance allowance;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Called when the reader asks to open the person's own sheet.
  final VoidCallback onPersonOpenRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptRegieAllowanceDefrayalRow({
    required this.allowance,
    required this.currencyCode,
    required this.onTap,
    required this.onPersonOpenRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocptClickableCursor,
      child: SizedBox(
        height: _ocptRegieAllowanceSubRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: _ocptRegieAllowanceTwistyWidth + _ocptRegieAllowanceIndentStep,
                  right: 8,
                ),
                child: Text(
                  _detailTextOf(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            _ocptRegieAllowanceAmountCell(context, ocptBudgetAllowanceCentsOf(allowance), currencyCode),
            _ocptRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
            _ocptRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
            SizedBox(
              width: _ocptRegieAllowanceMenuColumnWidth,
              child: PopupMenuButton<String>(
                tooltip: "",
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) => switch (value) {
                  "person" => onPersonOpenRequested(),
                  _ => onDeletionRequested?.call(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: "person",
                    child: Text(tr.budgetRegieAllowanceOpenPersonAction),
                  ),
                  if (onDeletionRequested != null)
                    PopupMenuItem<String>(value: "delete", child: Text(tr.budgetCommittedDeleteAction)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `nature · when · ×quantity` — see the class doc comment.
  String _detailTextOf(BuildContext context) {
    final tr = Tr.of(context);
    final nature = ocptBudgetAllowanceKindLabel(tr, allowance.kind);
    final when = _whenLabel(context);
    final quantity = ocptBudgetQuantityLabel(allowance.quantityMilli);

    return "$nature · $when · ×$quantity";
  }

  /// A single date, a span for a stay, or [ocptBudgetEmptyValue] while nobody has said — a defrayal
  /// with no date is a real, ordinary state, not an unfinished row.
  String _whenLabel(BuildContext context) {
    final date = allowance.date;
    if (date == null) {
      return ocptBudgetEmptyValue;
    }

    final format = DateFormat.Md(Localizations.localeOf(context).toLanguageTag());
    final endDate = allowance.endDate;

    return endDate == null ? format.format(date) : "${format.format(date)} – ${format.format(endDate)}";
  }
}

/// One reimbursement sub-row: a dot, a `REIMBURSED` badge, the entry's own date and wording, its
/// debit printed in the `REIMBURSED` column alone — the other money cells left blank, no menu: the
/// entry itself belongs to the cash journal, not to this tree.
class _OcptRegieAllowanceReimbursementRow extends StatelessWidget {
  /// The journal entry this row draws.
  final OcptBudgetEntry entry;

  /// The project's own default VAT rate, in basis points, or null while it declares none — what
  /// [entry]'s own debit is read tax-inclusive against.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptRegieAllowanceReimbursementRow({
    required this.entry,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final dateText = DateFormat.yMd().format(entry.date);
    final label = entry.label.isEmpty ? dateText : "$dateText · ${entry.label}";
    // Read exactly the way the `REIMBURSED` column above it is — tax-inclusive, through the
    // journal's own reading rather than off `debitCents` raw — mirrors
    // `OcptBudgetFinancing`'s own receipt sub-row.
    final debitCents = ocptBudgetEntryDebitCentsOf(entry, projectVatRateBasisPoints: defaultVatRateBasisPoints);

    return SizedBox(
      height: _ocptRegieAllowanceSubRowHeight,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: _ocptRegieAllowanceTwistyWidth + _ocptRegieAllowanceIndentStep,
                right: 8,
              ),
              child: Row(
                children: [
                  Container(
                    width: _ocptRegieAllowanceDotDiameter,
                    height: _ocptRegieAllowanceDotDiameter,
                    decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(ocptRadiusSmall),
                    ),
                    child: Text(
                      tr.budgetRegieColumnReimbursed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ocptRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
          SizedBox(
            width: _ocptRegieAllowanceAmountColumnWidth,
            child: Text(
              debitCents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(debitCents, currencyCode),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          _ocptRegieAllowanceAmountCell(context, null, currencyCode, showBlank: true),
          const SizedBox(width: _ocptRegieAllowanceMenuColumnWidth),
        ],
      ),
    );
  }
}

/// The defrayal table's own header row: `Person`, `Advanced`, `Reimbursed`, `Owed`.
class _OcptRegieAllowanceHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptRegieAllowanceHeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: _ocptRegieHeaderRowHeight,
      child: Row(
        children: [
          Expanded(child: Text(tr.budgetRegieColumnPerson.toUpperCase(), style: labelStyle)),
          _amountHeaderCell(tr.budgetRegieColumnAdvanced, labelStyle),
          _amountHeaderCell(tr.budgetRegieColumnReimbursed, labelStyle),
          _amountHeaderCell(tr.budgetRegieColumnOwed, labelStyle),
          const SizedBox(width: _ocptRegieAllowanceMenuColumnWidth),
        ],
      ),
    );
  }

  /// One amount column's own header cell, right-aligned like the figures underneath it.
  Widget _amountHeaderCell(String label, TextStyle? style) => SizedBox(
    width: _ocptRegieAllowanceAmountColumnWidth,
    child: Text(
      label.toUpperCase(),
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}

/// The defrayal table's own total row: what every live defrayal comes to under `ADVANCED`, what has
/// actually been reimbursed under `REIMBURSED`, and what remains owed under `OWED` — mirrors
/// `OcptBudgetFinancing`'s own `_OcptResourcesTotalRow`.
class _OcptRegieAllowanceTotalRow extends StatelessWidget {
  /// Every live defrayal.
  final List<OcptBudgetAllowance> allowances;

  /// Every live journal entry, narrowed here to the debits naming a person.
  final List<OcptBudgetEntry> entries;

  /// The project's default VAT rate, in basis points, or null.
  final int? defaultVatRateBasisPoints;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptRegieAllowanceTotalRow({
    required this.allowances,
    required this.entries,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);

    final advancedCents = ocptBudgetAllowancesTotalCents(allowances);
    final reimbursedCents = _reimbursedTotalCentsOf();
    final outstandingCents = ocptBudgetPersonOutstandingCents(
      advancedCents: advancedCents,
      reimbursedCents: reimbursedCents,
    );

    return SizedBox(
      height: _ocptRegieHeaderRowHeight,
      child: Row(
        children: [
          Expanded(child: Text(tr.budgetRegieTotalLabel.toUpperCase(), style: labelStyle)),
          _ocptRegieAllowanceAmountCell(context, advancedCents, currencyCode, style: boldStyle),
          _ocptRegieAllowanceAmountCell(context, reimbursedCents, currencyCode, style: boldStyle),
          _ocptRegieAllowanceAmountCell(context, outstandingCents, currencyCode, style: boldStyle),
          const SizedBox(width: _ocptRegieAllowanceMenuColumnWidth),
        ],
      ),
    );
  }

  /// The tax-inclusive sum of every person's own reimbursed total, across [entries] —
  /// `ocptBudgetReimbursedByPersonId`, folded into one figure for the whole table rather than kept
  /// per person, since the total row answers for every running account at once.
  int _reimbursedTotalCentsOf() => ocptBudgetReimbursedByPersonId(
    entries,
    projectVatRateBasisPoints: defaultVatRateBasisPoints,
  ).values.fold(0, (sum, total) => sum + total.amountCents);
}

/// The band under both columns: what this view computes, what the quote already carries for it, the
/// gap between the two, and the gesture that closes it.
///
/// **The gap is the whole reason this band exists.** The view used to compute figures and write
/// them nowhere, which the product owner named exactly: *"il fait des calculs mais ces calculs, où
/// sont-ils enregistrés ou provisionnés ?"* — they were nowhere. The `Quoted on this poste` figure
/// reads back the lines the provisioning itself wrote, so a reader can see at a glance whether what
/// the schedule and the defrayals imply has actually reached the budget.
///
/// A project holding no poste at all shows the reason instead of an inert picker: there is nowhere
/// to provision into until the quote has a poste.
class _OcptRegieProvisionBand extends StatelessWidget {
  /// What the catering and the defrayals come to together, in cents.
  final int computedTotalCents;

  /// What the provisioned lines of the target poste currently hold, in cents.
  final int provisionedTotalCents;

  /// Every live poste of the quote.
  final List<OcptBudgetPoste> postes;

  /// The poste the provisioning would write into, or null.
  final String? provisionPosteId;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called with the id of the poste just picked, or null while withheld.
  final ValueChanged<String>? onPosteSelected;

  /// Called when the reader asks to provision, or null while withheld.
  final VoidCallback? onProvisionRequested;

  /// Why there is nothing to provision, or null while there is.
  final String? note;

  /// Class constructor
  const _OcptRegieProvisionBand({
    required this.computedTotalCents,
    required this.provisionedTotalCents,
    required this.postes,
    required this.provisionPosteId,
    required this.currencyCode,
    required this.onPosteSelected,
    required this.onProvisionRequested,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final note = this.note;
    final gapCents = computedTotalCents - provisionedTotalCents;
    final selectedPoste = postes.where((poste) => poste.id == provisionPosteId).firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 32,
          runSpacing: 12,
          children: [
            _OcptRegieProvisionFigure(
              label: tr.budgetRegieProvisionComputedLabel,
              value: ocptBudgetAmountLabel(computedTotalCents, currencyCode),
            ),
            _OcptRegieProvisionFigure(
              label: tr.budgetRegieProvisionQuotedLabel,
              value: ocptBudgetAmountLabel(provisionedTotalCents, currencyCode),
            ),
            _OcptRegieProvisionFigure(
              label: tr.budgetRegieProvisionGapLabel,
              value: ocptBudgetAmountLabel(gapCents, currencyCode),
              valueColor: gapCents == 0 ? null : ocptWarningColor(context),
            ),
            if (postes.isEmpty)
              Text(
                tr.budgetRegieProvisionNoPosteHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else ...[
              if (onPosteSelected != null)
                DropdownButton<String>(
                  value: selectedPoste?.id,
                  hint: Text(tr.budgetRegieProvisionPosteLabel),
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final poste in postes)
                      DropdownMenuItem<String>(
                        value: poste.id,
                        child: Text(ocptBudgetPosteDisplayLabel(poste, isSimplified: false)),
                      ),
                  ],
                  onChanged: (value) => value == null ? null : onPosteSelected?.call(value),
                ),
              if (note != null)
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (onProvisionRequested != null)
                FilledButton.icon(
                  onPressed: provisionPosteId == null ? null : onProvisionRequested,
                  icon: const Icon(Icons.playlist_add_check, size: 16),
                  label: Text(tr.budgetRegieProvisionAction),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One figure of the provisioning band: its caption over its value.
class _OcptRegieProvisionFigure extends StatelessWidget {
  /// The figure's own caption.
  final String label;

  /// The figure itself, already formatted.
  final String value;

  /// The colour the value reads in, or null for the ordinary one.
  final Color? valueColor;

  /// Class constructor
  const _OcptRegieProvisionFigure({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(color: valueColor)),
      ],
    );
  }
}
