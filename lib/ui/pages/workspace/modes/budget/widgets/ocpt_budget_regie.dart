// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
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

/// The travel table's own `Return trips`/`Distance` column width, in logical pixels.
const double _ocptRegieTravelNumberColumnWidth = 96;

/// The travel table's own `Amount` column width, in logical pixels — mirrors
/// `OcptBudgetCommittedSpending`'s own amount column.
const double _ocptRegieTravelAmountColumnWidth = 108;

/// Either table's own header row height, in logical pixels.
const double _ocptRegieHeaderRowHeight = 36;

/// A catering row's own fixed height, in logical pixels — one line for the day tag, one for the
/// decor's own date underneath it.
const double _ocptRegieCateringRowHeight = 52;

/// A travel row's own fixed height, in logical pixels — mirrors [_ocptRegieCateringRowHeight] for
/// the traveller's own name-and-role pair.
const double _ocptRegieTravelRowHeight = 52;

/// The budget mode's catering-and-travel view: what each shooting day costs in meals and at the
/// buffet, next to what each traveller's own commute costs the production in mileage — the layout the
/// validated mockup lays this view out as, **two columns side by side, the catering table taking
/// roughly two thirds and the mileage table one third, wrapping onto one another once the centre
/// narrows past [_ocptRegieWrapWidth]** rather than crushing either column unreadable.
///
/// **This view writes nothing, and therefore carries no `isReadOnly` flag at all.** Every figure it
/// shows is read off the schedule, the project's own settings and each person's own sheet — there
/// is no create, no edit, no delete and no dialog here, so a previewed version withholds nothing
/// this view offers, exactly the argument `OcptBudgetDashboard`'s own class doc comment already
/// makes for itself.
///
/// **A meal is read off the day's own timetable, one sitting per meal block.** [ocptBudgetRegieDaysOf]
/// (`lib/utils/ocpt_budget_regie.dart`) reads every [OcptShootingBlockKind.meal] block of a day, over
/// that block's own slot alone — a day with a lunch and a dinner block feeds its heads twice, and a
/// day whose timetable holds no meal block at all feeds nobody. That absence prints as
/// [ocptBudgetEmptyValue] in the `Meals` column rather than a `0` that would read as a confirmed
/// "nobody eats today" — the catering column's own caption states the whole rule, so nobody has to
/// read the arithmetic to know what it assumes. **Craft services (the buffet) is unaffected**: it is
/// still one per head, per shooting day, deduplicated exactly as before.
///
/// **Every figure here is typed somewhere else**, so every one of the three sources this view reads
/// gets a way back to it, reported upward through a callback rather than navigated here: the head
/// counts point at the schedule ([onScheduleOpenRequested]), the two unit prices point at the
/// project settings ([onProjectSettingsRequested]), and a traveller's own distance and rate point at
/// their own sheet in the resources mode ([onPersonOpenRequested]). `OcptBudgetMode` is what turns
/// each of those into a real dispatch, exactly as it already does for the dashboard's own alert
/// actions.
///
/// Empty state: a project holding no shooting day at all shows [OcptWorkspaceEmptyMode] over the
/// whole view — unlike `OcptBudgetFinancing`'s own reading, there is no `+` action of this view's
/// own to keep a heading band drawn for, this view being read-only start to finish.
class OcptBudgetRegie extends StatelessWidget {
  /// Every live shooting day's own catering reading, in the schedule's own day-number order.
  final List<OcptBudgetRegieDay> days;

  /// [days] folded into one total.
  final OcptBudgetRegieTotals cateringTotals;

  /// The decor name printed under each day, keyed by the day's own id — a day with no key here
  /// names neither a set nor a location in any of its slots.
  final Map<String, String> decorNameByDayId;

  /// The project's own meal price, in cents, or null while nobody has recorded one.
  final int? mealPriceCents;

  /// The project's own buffet (craft services) price, in cents, or null while nobody has recorded
  /// one.
  final int? buffetPriceCents;

  /// Every traveller the schedule names, each with their own return-trip count and mileage
  /// reimbursement.
  final List<OcptBudgetTravelRow> travelRows;

  /// [travelRows] folded into one total.
  final OcptBudgetTravelTotals travelTotals;

  /// Every live role of the project — resolves a traveller's own convocation: cast through
  /// [OcptRole.name], crew through nothing here at all (see [people]).
  final List<OcptRole> roles;

  /// Every live person of the project's address book — resolves a traveller's own display name and
  /// declared crew position.
  final List<OcptPerson> people;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when the catering caption's own `Open the schedule` action is clicked.
  final VoidCallback onScheduleOpenRequested;

  /// Called when either caption's own `Edit prices`/rate action is clicked — opens the project
  /// settings, where the meal and buffet prices are typed.
  final VoidCallback onProjectSettingsRequested;

  /// Called with a traveller's own person id when their row is clicked — opens their sheet in the
  /// resources mode.
  final ValueChanged<String> onPersonOpenRequested;

  /// Class constructor
  const OcptBudgetRegie({
    super.key,
    required this.days,
    required this.cateringTotals,
    required this.decorNameByDayId,
    required this.mealPriceCents,
    required this.buffetPriceCents,
    required this.travelRows,
    required this.travelTotals,
    required this.roles,
    required this.people,
    required this.currencyCode,
    required this.onScheduleOpenRequested,
    required this.onProjectSettingsRequested,
    required this.onPersonOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
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
    final travelColumn = _OcptRegieTravelColumn(
      rows: travelRows,
      totals: travelTotals,
      roles: roles,
      people: people,
      currencyCode: currencyCode,
      onProjectSettingsRequested: onProjectSettingsRequested,
      onPersonOpenRequested: onPersonOpenRequested,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _ocptRegieWrapWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: cateringColumn),
              const SizedBox(width: 24),
              Expanded(child: travelColumn),
            ],
          );
        }

        // Mirrors `OcptBudgetCommittedSpending`'s own narrow reading: still two `Expanded`
        // panes, stacked rather than side by side, each scrolling its own table internally
        // rather than the whole view scrolling as one.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: cateringColumn),
            const SizedBox(height: 24),
            Expanded(child: travelColumn),
          ],
        );
      },
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
            TextButton(
              onPressed: onProjectSettingsRequested,
              child: Text(tr.budgetRegiePricesEditAction),
            ),
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
            TextButton(
              onPressed: onScheduleOpenRequested,
              child: Text(tr.budgetRegieOpenScheduleAction),
            ),
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
          SizedBox(width: _ocptRegieDayColumnWidth, child: Text(tr.budgetRegieColumnDay.toUpperCase(), style: labelStyle)),
          Expanded(child: Text(tr.budgetRegieColumnDecor.toUpperCase(), style: labelStyle)),
          SizedBox(
            width: _ocptRegieCountColumnWidth,
            child: Text(tr.budgetRegieColumnCrew.toUpperCase(), textAlign: TextAlign.right, style: labelStyle),
          ),
          SizedBox(
            width: _ocptRegieCountColumnWidth,
            child: Text(tr.budgetRegieColumnCast.toUpperCase(), textAlign: TextAlign.right, style: labelStyle),
          ),
          SizedBox(
            width: _ocptRegieCountColumnWidth,
            child: Text(tr.budgetRegieColumnExtras.toUpperCase(), textAlign: TextAlign.right, style: labelStyle),
          ),
          SizedBox(
            width: _ocptRegieWideCountColumnWidth,
            child: Text(tr.budgetRegieColumnMeals.toUpperCase(), textAlign: TextAlign.right, style: labelStyle),
          ),
          SizedBox(
            width: _ocptRegieWideCountColumnWidth,
            child: Text(tr.budgetRegieColumnBuffet.toUpperCase(), textAlign: TextAlign.right, style: labelStyle),
          ),
          SizedBox(
            width: _ocptRegieCateringTotalColumnWidth,
            child: Text(tr.budgetRegieColumnTotal.toUpperCase(), textAlign: TextAlign.right, style: labelStyle),
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
                    Text(decorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
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
    child: Text(
      "$count",
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

  /// The `Craft services` cell — a plain head count, at the wider column width the `Meals` cell
  /// beside it also needs.
  Widget _wideCountCell(BuildContext context, int count) => SizedBox(
    width: _ocptRegieWideCountColumnWidth,
    child: Text(
      "$count",
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodySmall,
    ),
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

/// The right column: the heading band with its caption, then the mileage table.
class _OcptRegieTravelColumn extends StatelessWidget {
  /// See [OcptBudgetRegie]'s own fields of the same name.
  final List<OcptBudgetTravelRow> rows;
  final OcptBudgetTravelTotals totals;
  final List<OcptRole> roles;
  final List<OcptPerson> people;
  final String currencyCode;
  final VoidCallback onProjectSettingsRequested;
  final ValueChanged<String> onPersonOpenRequested;

  /// Class constructor
  const _OcptRegieTravelColumn({
    required this.rows,
    required this.totals,
    required this.roles,
    required this.people,
    required this.currencyCode,
    required this.onProjectSettingsRequested,
    required this.onPersonOpenRequested,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.budgetRegieTravelSectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                tr.budgetRegieTravelHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: onProjectSettingsRequested,
              child: Text(tr.budgetRegiePricesEditAction),
            ),
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
                  const _OcptRegieTravelHeaderRow(),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) => _OcptRegieTravelRow(
                        row: rows[index],
                        person: personById[rows[index].personId],
                        role: roleByPersonId[rows[index].personId],
                        currencyCode: currencyCode,
                        onTap: () => onPersonOpenRequested(rows[index].personId),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _OcptRegieTravelTotalRow(totals: totals, currencyCode: currencyCode),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The travel table's own header row: `Traveller`, `Return trips`, `Distance`, `Amount`.
class _OcptRegieTravelHeaderRow extends StatelessWidget {
  /// Class constructor
  const _OcptRegieTravelHeaderRow();

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
          Expanded(child: Text(tr.budgetRegieColumnTraveller.toUpperCase(), style: labelStyle)),
          SizedBox(
            width: _ocptRegieTravelNumberColumnWidth,
            child: Text(
              tr.budgetRegieColumnReturnTrips.toUpperCase(),
              textAlign: TextAlign.right,
              style: labelStyle,
            ),
          ),
          SizedBox(
            width: _ocptRegieTravelNumberColumnWidth,
            child: Text(tr.budgetRegieColumnDistance.toUpperCase(), textAlign: TextAlign.right, style: labelStyle),
          ),
          SizedBox(
            width: _ocptRegieTravelAmountColumnWidth,
            child: Text(tr.budgetCommittedColumnAmount.toUpperCase(), textAlign: TextAlign.right, style: labelStyle),
          ),
        ],
      ),
    );
  }
}

/// One traveller's own row: their display name with what they are on the shoot underneath in small
/// muted type, their return-trip count, their own distance and their own reimbursement —
/// [ocptBudgetEmptyValue] rather than a claimed zero wherever [OcptBudgetTravelRow.totalKmMilli] or
/// [OcptBudgetTravelRow.amountCents] is null, the trip count printing regardless: a traveller who
/// claims nothing is still listed, which is how somebody discovers a distance nobody has filled in.
class _OcptRegieTravelRow extends StatelessWidget {
  /// The row this widget draws.
  final OcptBudgetTravelRow row;

  /// The person [row] is for, or null while the address book carries no live entry for them
  /// (should not happen: [row] is only ever built for a person the schedule actually names).
  final OcptPerson? person;

  /// The role this person is cast in, if any — read ahead of any declared crew position, since a
  /// role played is a more specific answer to "what are they on the shoot" than a department is.
  final OcptRole? role;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Called when this row is clicked — opens this traveller's own sheet in the resources mode.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptRegieTravelRow({
    required this.row,
    required this.person,
    required this.role,
    required this.currencyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final person = this.person;
    final distanceText = row.totalKmMilli == null
        ? ocptBudgetEmptyValue
        : tr.budgetRegieDistanceLabel(ocptBudgetQuantityLabel(row.totalKmMilli!));
    final amountText = row.amountCents == null
        ? ocptBudgetEmptyValue
        : ocptBudgetAmountLabel(row.amountCents!, currencyCode);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: SizedBox(
        height: _ocptRegieTravelRowHeight,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person?.displayName ?? tr.budgetRegieUnknownPersonLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_roleOrPositionLabelOf(tr) case final label?)
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _ocptRegieTravelNumberColumnWidth,
              child: Text(
                "${row.returnTripCount}",
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptRegieTravelNumberColumnWidth,
              child: Text(
                distanceText,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _ocptRegieTravelAmountColumnWidth,
              child: Text(
                amountText,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What this traveller is on the shoot: the role they are cast in when [role] names one, failing
  /// that their first declared crew position, failing that null — the view then printing nothing
  /// rather than inventing a placeholder for a person on neither list.
  String? _roleOrPositionLabelOf(Tr tr) {
    final role = this.role;
    if (role != null) {
      return role.name;
    }

    final positions = person?.positions ?? const [];
    if (positions.isEmpty) {
      return null;
    }
    final position = positions.first;

    return position.positionId.isNotEmpty
        ? ocptCrewPositionLabel(tr, position.positionId)
        : position.customLabel;
  }
}

/// The travel table's own total row: the summed distance and money over every traveller — the
/// coverage read-out in place of the plain amount for as long as any traveller's own reimbursement
/// is unknown, mirroring [_OcptRegieCateringTotalRow].
class _OcptRegieTravelTotalRow extends StatelessWidget {
  /// [OcptBudgetRegie.travelRows] folded into one total.
  final OcptBudgetTravelTotals totals;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptRegieTravelTotalRow({required this.totals, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final amountText = ocptBudgetAmountLabel(totals.cost.amountCents, currencyCode);
    final costText = totals.cost.isComplete
        ? amountText
        : tr.budgetRegieTravelCoverageReadOut(amountText, totals.cost.coveredLineCount, totals.cost.lineCount);

    // Mirrors `_OcptRegieTravelHeaderRow`'s own column structure exactly (the label sitting in the
    // `Traveller` column's own flexible slot, then a blank `Return trips` cell before the summed
    // distance), so this row's own cells line up under the header that names them.
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr.budgetCostTrackingTotalRowLabel,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: _ocptRegieTravelNumberColumnWidth),
          SizedBox(
            width: _ocptRegieTravelNumberColumnWidth,
            child: Text(
              tr.budgetRegieDistanceLabel(ocptBudgetQuantityLabel(totals.totalKmMilli)),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: _ocptRegieTravelAmountColumnWidth,
            child: Text(
              costText,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
