// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_allowances.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_regie.dart';

/// The width, in logical pixels, under which the two columns stack instead of sitting side by
/// side — mirrors `OcptBudgetCommittedSpending`'s own reading, raised a little for the catering
/// table's own eight columns.
const double _ocptRegieWrapWidth = 1000;

/// The catering table's own `Day` column width, in logical pixels.
const double _ocptRegieDayColumnWidth = 56;

/// The catering table's own `Crew`/`Cast`/`Extras` column width, in logical pixels — three narrow,
/// numeric columns.
const double _ocptRegieCountColumnWidth = 64;

/// The catering table's own `Total` column width, in logical pixels — mirrors
/// `OcptBudgetCommittedSpending`'s own amount column.
const double _ocptRegieCateringTotalColumnWidth = 108;

/// The catering table's own `Meals`/`Craft services` column width, in logical pixels — wider than
/// [_ocptRegieCountColumnWidth]: the `Meals` cell can read several sittings joined together
/// (`12 + 8`) and the `Craft services` header is two words.
const double _ocptRegieWideCountColumnWidth = 96;

/// The defrayal table's own `Nature` and `When` column width, in logical pixels.
const double _ocptRegieAllowanceTextColumnWidth = 96;

/// The defrayal table's own `Quantity` column width, in logical pixels.
const double _ocptRegieAllowanceQuantityColumnWidth = 80;

/// The defrayal table's own `Amount` column width, in logical pixels — mirrors
/// `OcptBudgetCommittedSpending`'s own amount column.
const double _ocptRegieAllowanceAmountColumnWidth = 108;

/// The defrayal table's own trailing `⋮` menu column width, in logical pixels.
const double _ocptRegieAllowanceMenuColumnWidth = 36;

/// Either table's own header row height, in logical pixels.
const double _ocptRegieHeaderRowHeight = 36;

/// A catering row's own fixed height, in logical pixels — one line for the day tag, one for the
/// decor's own date underneath it.
const double _ocptRegieCateringRowHeight = 52;

/// A defrayal row's own fixed height, in logical pixels — mirrors [_ocptRegieCateringRowHeight] for
/// the person's own name-and-role pair.
const double _ocptRegieAllowanceRowHeight = 52;

/// The narrowest the defrayal table is ever drawn at, in logical pixels: every fixed column's own
/// width — 2 × 96 + 80 + 108 + 36 = 416 — plus 150 for a `Person` column that can still hold a
/// name and a wording under it.
///
/// Below it the table **scrolls sideways inside its own frame**, exactly as the cash journal's own
/// does and for the same reason: `Person` is the only flexible column, and this table lives in the
/// narrower third of a two-column view, so a modest centre used to drive it to nothing.
const double _ocptRegieAllowanceMinTableWidth = 566;

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
/// dispatch, exactly as it already does for the dashboard's own alert actions.
///
/// Empty state: a project holding no shooting day **and** no defrayal shows [OcptWorkspaceEmptyMode]
/// over the whole view. A project with defrayals but no schedule keeps the full layout, since there
/// is now a `+` action of this view's own to keep a heading band drawn for.
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

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Whether the project on screen is a version being previewed, in which case every writing
  /// affordance is withheld rather than disabled.
  final bool isReadOnly;

  /// Called when the reader asks to go and look at the schedule the head counts are read from.
  final VoidCallback onScheduleOpenRequested;

  /// Called when the reader asks to go and edit the project's own unit prices.
  final VoidCallback onProjectSettingsRequested;

  /// Called with the id of the person whose own sheet the reader asks to open.
  final ValueChanged<String> onPersonOpenRequested;

  /// Called when the reader asks to record a new defrayal, or null while withheld.
  final VoidCallback? onAllowanceCreationRequested;

  /// Called with the id of the defrayal the reader asks to edit, or null while withheld.
  final ValueChanged<String>? onAllowanceEditRequested;

  /// Called with the id of the defrayal the reader asks to delete, or null while withheld.
  ///
  /// **Asks, it never deletes**: the mode is what opens `OcptConfirmDialog` over it.
  final ValueChanged<String>? onAllowanceDeletionRequested;

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
    required this.postes,
    required this.provisionPosteId,
    required this.provisionedTotalCents,
    required this.roles,
    required this.people,
    required this.currencyCode,
    required this.isReadOnly,
    required this.onScheduleOpenRequested,
    required this.onProjectSettingsRequested,
    required this.onPersonOpenRequested,
    required this.onAllowanceCreationRequested,
    required this.onAllowanceEditRequested,
    required this.onAllowanceDeletionRequested,
    required this.onProvisionPosteSelected,
    required this.onProvisionRequested,
    required this.provisionNote,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty && allowances.isEmpty) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.restaurant_outlined,
        message: Tr.of(context).budgetRegieEmptyHint,
      );
    }

    final cateringColumn = _OcptRegieCateringColumn(
      days: days,
      totals: cateringTotals,
      decorNameByDayId: decorNameByDayId,
      mealPriceCents: mealPriceCents,
      buffetPriceCents: buffetPriceCents,
      currencyCode: currencyCode,
      onScheduleOpenRequested: onScheduleOpenRequested,
      onProjectSettingsRequested: onProjectSettingsRequested,
    );
    final allowanceColumn = _OcptRegieAllowanceColumn(
      allowances: allowances,
      roles: roles,
      people: people,
      currencyCode: currencyCode,
      isReadOnly: isReadOnly,
      onPersonOpenRequested: onPersonOpenRequested,
      onCreationRequested: onAllowanceCreationRequested,
      onEditRequested: onAllowanceEditRequested,
      onDeletionRequested: onAllowanceDeletionRequested,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= _ocptRegieWrapWidth) {
                // Three fifths to the catering, two to the defrayals — not the two-to-one the
                // old travel table was sized for, which left this one under its own floor and
                // scrolling at any ordinary window width. The catering's own widest column is a
                // decor name, which gives room up more gracefully than six narrow ones do.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: cateringColumn),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: allowanceColumn),
                  ],
                );
              }

              // Mirrors `OcptBudgetCommittedSpending`'s own narrow reading: still two `Expanded`
              // panes, stacked rather than side by side, each scrolling its own table internally
              // rather than the whole view scrolling as one.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: cateringColumn),
                  const SizedBox(height: 24),
                  Expanded(flex: 2, child: allowanceColumn),
                ],
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

  /// Class constructor
  const _OcptRegieCateringColumn({
    required this.days,
    required this.totals,
    required this.decorNameByDayId,
    required this.mealPriceCents,
    required this.buffetPriceCents,
    required this.currencyCode,
    required this.onScheduleOpenRequested,
    required this.onProjectSettingsRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
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

/// The right column: the heading band with its caption and its own `Defrayal` button, then the
/// defrayal table.
class _OcptRegieAllowanceColumn extends StatelessWidget {
  /// See [OcptBudgetRegie]'s own fields of the same name.
  final List<OcptBudgetAllowance> allowances;
  final List<OcptRole> roles;
  final List<OcptPerson> people;
  final String currencyCode;
  final bool isReadOnly;
  final ValueChanged<String> onPersonOpenRequested;
  final VoidCallback? onCreationRequested;
  final ValueChanged<String>? onEditRequested;
  final ValueChanged<String>? onDeletionRequested;

  /// Class constructor
  const _OcptRegieAllowanceColumn({
    required this.allowances,
    required this.roles,
    required this.people,
    required this.currencyCode,
    required this.isReadOnly,
    required this.onPersonOpenRequested,
    required this.onCreationRequested,
    required this.onEditRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final personById = {for (final person in people) person.id: person};
    final roleByPersonId = <String, OcptRole>{
      for (final role in roles)
        if (role.personId != null) role.personId!: role,
    };
    final effectiveOnCreationRequested = isReadOnly ? null : onCreationRequested;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.budgetRegieAllowancesSectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                tr.budgetRegieAllowancesHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (effectiveOnCreationRequested != null)
              FilledButton.icon(
                onPressed: effectiveOnCreationRequested,
                icon: const Icon(Icons.add, size: 16),
                label: Text(tr.budgetRegieAllowanceCreationAction),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
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
                              Expanded(
                                child: ListView.builder(
                                  itemCount: allowances.length,
                                  itemBuilder: (context, index) => _OcptRegieAllowanceRow(
                                    allowance: allowances[index],
                                    person: personById[allowances[index].personId],
                                    role: roleByPersonId[allowances[index].personId],
                                    currencyCode: currencyCode,
                                    onTap: isReadOnly || onEditRequested == null
                                        ? null
                                        : () => onEditRequested?.call(allowances[index].id),
                                    onPersonOpenRequested: allowances[index].personId == null
                                        ? null
                                        : () => onPersonOpenRequested(allowances[index].personId!),
                                    onDeletionRequested: isReadOnly || onDeletionRequested == null
                                        ? null
                                        : () => onDeletionRequested?.call(allowances[index].id),
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              _OcptRegieAllowanceTotalRow(allowances: allowances, currencyCode: currencyCode),
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

/// The defrayal table's own header row: `Person`, `Nature`, `When`, `Quantity`, `Amount`.
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
          SizedBox(
            width: _ocptRegieAllowanceTextColumnWidth,
            child: Text(tr.budgetRegieColumnNature.toUpperCase(), style: labelStyle),
          ),
          SizedBox(
            width: _ocptRegieAllowanceTextColumnWidth,
            child: Text(tr.budgetRegieColumnWhen.toUpperCase(), style: labelStyle),
          ),
          SizedBox(
            width: _ocptRegieAllowanceQuantityColumnWidth,
            child: Text(
              tr.budgetRegieColumnQuantity.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptRegieAllowanceAmountColumnWidth,
            child: Text(
              tr.budgetCommittedColumnAmount.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: _ocptRegieAllowanceMenuColumnWidth),
        ],
      ),
    );
  }
}

/// One defrayal's own row: who it is owed to, with what they are on the shoot underneath in small
/// muted type and the row's own wording beside it, then its nature, its date or span, its quantity
/// and what it comes to.
///
/// A defrayal naming nobody reads its own wording in the `Person` column instead, in italics: it is
/// a real line of a régie budget that belongs to the production rather than to one person, not an
/// unfinished pick — `OcptBudgetAllowancesTable`'s own doc comment.
class _OcptRegieAllowanceRow extends StatelessWidget {
  /// The defrayal this widget draws.
  final OcptBudgetAllowance allowance;

  /// The person it is owed to, or null.
  final OcptPerson? person;

  /// What that person is on the shoot, or null.
  final OcptRole? role;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the row is clicked, or null while withheld.
  final VoidCallback? onTap;

  /// Called when the reader asks to open the person's own sheet, or null while this row names
  /// nobody.
  final VoidCallback? onPersonOpenRequested;

  /// Called when this row's own `⋮` menu asks to delete it, or null while withheld.
  final VoidCallback? onDeletionRequested;

  /// Class constructor
  const _OcptRegieAllowanceRow({
    required this.allowance,
    required this.person,
    required this.role,
    required this.currencyCode,
    required this.onTap,
    required this.onPersonOpenRequested,
    required this.onDeletionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final person = this.person;
    final role = this.role;

    return InkWell(
      onTap: onTap,
      mouseCursor: onTap == null ? null : ocptClickableCursor,
      child: SizedBox(
        height: _ocptRegieAllowanceRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    person == null ? tr.budgetRegieAllowanceNoPerson : person.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: person == null ? FontStyle.italic : null,
                      color: person == null ? theme.colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                  Text(
                    allowance.label.isEmpty ? (role?.name ?? "") : allowance.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _ocptRegieAllowanceTextColumnWidth,
              child: Text(
                ocptBudgetAllowanceKindLabel(tr, allowance.kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptRegieAllowanceTextColumnWidth,
              child: Text(
                _whenLabel(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptRegieAllowanceQuantityColumnWidth,
              child: Text(
                ocptBudgetQuantityLabel(allowance.quantityMilli),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptRegieAllowanceAmountColumnWidth,
              child: Text(
                ocptBudgetAmountLabel(ocptBudgetAllowanceCentsOf(allowance), currencyCode),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptRegieAllowanceMenuColumnWidth,
              child: onDeletionRequested == null && onPersonOpenRequested == null
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: "",
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (value) => switch (value) {
                        "person" => onPersonOpenRequested?.call(),
                        _ => onDeletionRequested?.call(),
                      },
                      itemBuilder: (context) => [
                        if (onPersonOpenRequested != null)
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

  /// The `When` cell: a single date, a span for a stay, or [ocptBudgetEmptyValue] while nobody has
  /// said — a defrayal with no date is a real, ordinary state, not an unfinished row.
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

/// The defrayal table's own total row: what every live defrayal comes to.
class _OcptRegieAllowanceTotalRow extends StatelessWidget {
  /// Every live defrayal.
  final List<OcptBudgetAllowance> allowances;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptRegieAllowanceTotalRow({required this.allowances, required this.currencyCode});

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
          Expanded(child: Text(tr.budgetRegieTotalLabel.toUpperCase(), style: labelStyle)),
          SizedBox(
            width: _ocptRegieAllowanceAmountColumnWidth,
            child: Text(
              ocptBudgetAmountLabel(ocptBudgetAllowancesTotalCents(allowances), currencyCode),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: _ocptRegieAllowanceMenuColumnWidth),
        ],
      ),
    );
  }
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
