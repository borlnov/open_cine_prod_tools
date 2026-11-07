// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_logistics_totals.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_catering_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_catering_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_catering_total_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_table_pane.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';

/// The left column: the heading band with its two captions, then the catering table.
class OcptBudgetLogisticsCateringColumn extends StatelessWidget {
  /// See [OcptBudgetLogistics.days].
  final List<OcptBudgetLogisticsDay> days;

  /// See [OcptBudgetLogistics.cateringTotals].
  final OcptBudgetLogisticsTotals totals;

  /// See [OcptBudgetLogistics.setNameByDayId].
  final Map<String, String> setNameByDayId;

  /// See [OcptBudgetLogistics.mealPriceCents].
  final int? mealPriceCents;

  /// See [OcptBudgetLogistics.buffetPriceCents].
  final int? buffetPriceCents;

  /// See [OcptBudgetLogistics.currencyCode].
  final String currencyCode;

  /// See [OcptBudgetLogistics.onScheduleOpenRequested].
  final VoidCallback onScheduleOpenRequested;

  /// See [OcptBudgetLogistics.onProjectSettingsRequested].
  final VoidCallback onProjectSettingsRequested;

  /// The height the table card is drawn at, or null while the panes sit side by side and the card
  /// takes whatever height the heading band leaves it — see
  /// [ocptBudgetLogisticsStackedMinRowCount].
  final double? tableHeight;

  /// Class constructor
  const OcptBudgetLogisticsCateringColumn({
    super.key,
    required this.days,
    required this.totals,
    required this.setNameByDayId,
    required this.mealPriceCents,
    required this.buffetPriceCents,
    required this.currencyCode,
    required this.tableHeight,
    required this.onScheduleOpenRequested,
    required this.onProjectSettingsRequested,
  });

  /// Build the budget logistics catering column as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      // Stated by its own rows once it is stacked, so the pane takes no more room than it needs
      // and the view scrolls instead — see [ocptBudgetLogisticsStackedMinRowCount].
      mainAxisSize: tableHeight == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(tr.budgetLogisticsCateringSectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                tr.budgetLogisticsCateringPriceCaption(
                  mealPriceCents == null
                      ? ocptBudgetEmptyValue
                      : ocptBudgetAmountLabel(mealPriceCents!, currencyCode),
                  buffetPriceCents == null
                      ? ocptBudgetEmptyValue
                      : ocptBudgetAmountLabel(buffetPriceCents!, currencyCode),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: onProjectSettingsRequested,
              child: Text(tr.budgetLogisticsPricesEditAction),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                tr.budgetLogisticsCateringScheduleHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: onScheduleOpenRequested,
              child: Text(tr.budgetLogisticsOpenScheduleAction),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OcptBudgetLogisticsTablePane(
          height: tableHeight,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) => OcptHorizontalScrollView(
                  // Header, rows and total scroll **together**, inside one frame, for the reason
                  // `OcptBudgetCashJournal` gives: they share one set of fixed column widths.
                  child: SizedBox(
                    width: math.max(constraints.maxWidth, ocptBudgetLogisticsCateringMinTableWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const OcptBudgetLogisticsCateringHeaderRow(),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: days.length,
                            itemBuilder: (context, index) => OcptBudgetLogisticsCateringRow(
                              day: days[index],
                              setName: setNameByDayId[days[index].dayId],
                              currencyCode: currencyCode,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        OcptBudgetLogisticsCateringTotalRow(
                          totals: totals,
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
}
