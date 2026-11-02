// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_day.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';

/// One shooting day's own catering row: its day tag in the accent colour, [setName] with the
/// day's own date underneath in small muted type, the three crew/cast/extras head counts, the
/// `Meals` cell (see below), the buffet's own head count, then the day's own money —
/// [ocptBudgetEmptyValue] rather than a claimed zero the moment neither the meal nor the buffet
/// price is known (`OcptBudgetLogisticsDay.cost.coveredLineCount == 0`), mirroring
/// `OcptBudgetCostTracking`'s own secondary-basis cell.
///
/// **The `Meals` cell reads [OcptBudgetLogisticsDay.mealSittings] itself, not the plain
/// [OcptBudgetLogisticsDay.mealCount].** A day with no meal block in its own timetable prints
/// [ocptBudgetEmptyValue] — a stated absence, never a `0` that would look exactly like a day whose
/// timetable does hold a meal block feeding nobody. A day with more than one sitting (a lunch and a
/// dinner block, say) joins every sitting's own head count with `+` rather than folding them into
/// one number, so a reader sees that two feedings happened rather than reading a total that could
/// just as well be one big one.
class OcptBudgetLogisticsCateringRow extends StatelessWidget {
  /// The day this row draws.
  final OcptBudgetLogisticsDay day;

  /// The set name to print under the day tag, or null while none of the day's own slots name one.
  final String? setName;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetLogisticsCateringRow({
    super.key,
    required this.day,
    required this.setName,
    required this.currencyCode,
  });

  /// Build the budget logistics catering row as a [SizedBox].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final locale = Localizations.localeOf(context).toString();
    final setName = this.setName;
    final costText = day.cost.coveredLineCount == 0
        ? ocptBudgetEmptyValue
        : ocptBudgetAmountLabel(day.cost.amountCents, currencyCode);

    return SizedBox(
      height: ocptBudgetLogisticsCateringRowHeight,
      child: Row(
        children: [
          SizedBox(
            width: ocptBudgetLogisticsDayColumnWidth,
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
                  if (setName != null)
                    Text(
                      setName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(
                    DateFormat.yMMMd(locale).format(day.date),
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
          _countCell(context, day.crewCount),
          _countCell(context, day.castCount),
          _countCell(context, day.extraCount),
          _mealsCell(context),
          _wideCountCell(context, day.buffetCount),
          SizedBox(
            width: ocptBudgetLogisticsCateringTotalColumnWidth,
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

  /// Build one of the three narrow, right-aligned head-count cells (`Crew`, `Cast`, `Extras`).
  Widget _countCell(BuildContext context, int count) => SizedBox(
    width: ocptBudgetLogisticsCountColumnWidth,
    child: Text("$count", textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall),
  );

  /// Build the `Craft services` cell — a plain head count, at the wider column width the `Meals`
  /// cell
  /// beside it also needs.
  Widget _wideCountCell(BuildContext context, int count) => SizedBox(
    width: ocptBudgetLogisticsWideCountColumnWidth,
    child: Text("$count", textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall),
  );

  /// Build the `Meals` cell — see the class doc comment for the dash-versus-joined-sittings
  /// reading.
  Widget _mealsCell(BuildContext context) {
    final sittings = day.mealSittings;
    final text = sittings.isEmpty
        ? ocptBudgetEmptyValue
        : sittings.map((sitting) => "${sitting.headCount}").join(" + ");

    return SizedBox(
      width: ocptBudgetLogisticsWideCountColumnWidth,
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
