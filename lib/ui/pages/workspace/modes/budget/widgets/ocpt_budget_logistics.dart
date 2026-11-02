// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_allowances.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_totals.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_feed_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_allowance_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_catering_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_cells.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_provision_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_vertical_scroller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The budget mode's catering-and-defrayals view: what each shooting day costs in meals and at the
/// buffet, next to every defrayal the production owes somebody — the layout the validated mockup
/// lays this view out as, **two columns side by side, the catering table taking roughly two thirds
/// and the defrayals one third, wrapping onto one another once the centre narrows past
/// [ocptBudgetLogisticsWrapWidth]** rather than crushing either column unreadable — and, underneath
/// both, the band that provisions the whole thing into the quote.
///
/// **The two halves are read in opposite directions, and that is the point of the view.** The
/// catering is *computed*: it is read off the schedule and the project's own two unit prices, and
/// nothing about it is typed here. The defrayals are *typed*: `budget_allowances` holds one row per
/// thing actually owed, because what a production pays somebody back is not derivable from their
/// presence on a day — see `OcptBudgetAllowancesTable`'s own doc comment for the shoot this view
/// used to get wrong.
///
/// **The defrayal table is a tree grouped by person, mirroring `OcptBudgetFinancing`'s own
/// resources tree exactly** (`OcptBudgetLogisticsAllowanceColumn._rowsOf`'s own doc comment): a
/// person group row carries the logistics's own running account for them — `ADVANCED`,
/// `REIMBURSED`, `OWED` — mirroring the resources tree's `Promis`/`Rentré`/`Reste à venir`,
/// expanding onto their own defrayals then their own reimbursements. A defrayal naming nobody stays
/// its own group of one, counting against the quote and this view's own total but against no
/// running account — see `OcptBudgetLogisticsAllowanceNoPersonGroupRow`'s own doc comment.
///
/// **This view therefore writes, and carries [isReadOnly] like every other writing view of this
/// mode**: under a previewed version the `Defrayal` button, the row menus and the provisioning
/// gesture are **withheld, never disabled**, expressed as null callbacks.
///
/// **A meal is read off the day's own timetable, one sitting per meal block.**
/// [ocptBudgetLogisticsDaysOf] (`lib/models/rules/ocpt_budget_logistics.dart`) reads every
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
/// Empty state: a project holding no shooting day **and** no defrayal shows
/// [OcptWorkspaceEmptyMode] in place of the two columns. A project with defrayals but no schedule
/// keeps the full layout, since there is now a `+` action of this view's own to keep a heading band
/// drawn for.
///
/// **[OcptBudgetFeedCard] sits at the very top, above the two columns, in both readings** — the
/// empty one included, since a project with nothing here yet is exactly when a way through to the
/// schedule is most useful. Its own catering row is withheld (`onCateringFeedRequested` passed
/// null): it would name this very page, and a link to the page the reader is already standing on is
/// not a link at all.
class OcptBudgetLogistics extends StatelessWidget {
  /// Every live shooting day's own catering reading, in the schedule's own day-number order.
  final List<OcptBudgetLogisticsDay> days;

  /// Every day's own figures folded together.
  final OcptBudgetLogisticsTotals cateringTotals;

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
  /// tax-inclusive sum of every `budget_entries` debit naming them,
  /// `ocptBudgetReimbursedByPersonId` (`lib/models/rules/ocpt_budget_reimbursements.dart`). A
  /// person with no key here has been reimbursed nothing at all.
  final Map<String, OcptBudgetCoveredTotal> reimbursedByPersonId;

  /// The project's default VAT rate, in basis points, or null while nobody has recorded one — what
  /// a reimbursement sub-row's own debit is grossed up against.
  final int? defaultVatRateBasisPoints;

  /// Every live account of the quote, offered by the provisioning band's own account picker.
  final List<OcptBudgetAccount> accounts;

  /// The account the provisioning would write into, or null while this project holds no account.
  final String? provisionAccountId;

  /// What the provisioning band's own `Quoted on this poste` figure reads: the summed amount of
  /// the lines the provisioning itself wrote onto [provisionAccountId], in cents.
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
  /// what is currently owed them, exactly as `OcptBudgetFinancing`'s own `Record a receipt`
  /// prefills what is still outstanding.
  final ValueChanged<String>? onPersonReimburseRequested;

  /// Called with the id of the account the reader picks to provision into.
  final ValueChanged<String>? onProvisionAccountSelected;

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
  const OcptBudgetLogistics({
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
    required this.accounts,
    required this.provisionAccountId,
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
    required this.onProvisionAccountSelected,
    required this.onProvisionRequested,
    required this.provisionNote,
  });

  /// Build the budget logistics as a [Column].
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
              message: Tr.of(context).budgetLogisticsEmptyHint,
            ),
          ),
        ],
      );
    }

    Widget cateringColumn({double? tableHeight}) => OcptBudgetLogisticsCateringColumn(
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
    Widget allowanceColumn({double? tableHeight}) => OcptBudgetLogisticsAllowanceColumn(
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
              if (constraints.maxWidth >= ocptBudgetLogisticsWrapWidth) {
                // Three fifths to the catering, two to the defrayals — not the two-to-one the
                // old travel table was sized for, which left this one under its own floor and
                // scrolling at any ordinary window width. The catering's own widest column is a
                // decor name, which gives room up more gracefully than six narrow ones do.
                //
                // Side by side, both panes take the whole height, floored at
                // [ocptBudgetLogisticsPaneMinHeight].
                return OcptBudgetLogisticsVerticalScroller(
                  height: math.max(constraints.maxHeight, ocptBudgetLogisticsPaneMinHeight),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: cateringColumn()),
                      const SizedBox(width: ocptBudgetLogisticsStackGap),
                      Expanded(flex: 2, child: allowanceColumn()),
                    ],
                  ),
                );
              }

              // Stacked, each pane takes the height its own heading band and rows need, and the
              // view scrolls when the two together are taller than it — see
              // [ocptBudgetLogisticsStackedMinRowCount] for why a share of the height cannot be
              // used here.
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cateringColumn(
                      tableHeight: ocptBudgetLogisticsStackedCardHeight(
                        days.length,
                        ocptBudgetLogisticsCateringRowHeight,
                      ),
                    ),
                    const SizedBox(height: ocptBudgetLogisticsStackGap),
                    allowanceColumn(
                      tableHeight: ocptBudgetLogisticsStackedCardHeight(
                        ocptBudgetLogisticsAllowanceGroupCountOf(allowances),
                        ocptBudgetLogisticsAllowanceRowHeight,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        OcptBudgetLogisticsProvisionBand(
          computedTotalCents:
              cateringTotals.cost.amountCents + ocptBudgetAllowancesTotalCents(allowances),
          provisionedTotalCents: provisionedTotalCents,
          accounts: accounts,
          provisionAccountId: provisionAccountId,
          currencyCode: currencyCode,
          // Withheld under a previewed version, never disabled — the same reading the defrayal
          // column applies to its own `Defrayal` button and row menus.
          onAccountSelected: isReadOnly ? null : onProvisionAccountSelected,
          onProvisionRequested: isReadOnly ? null : onProvisionRequested,
          note: provisionNote,
        ),
      ],
    );
  }
}
