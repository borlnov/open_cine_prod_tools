// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie_day.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_regie_totals.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_catering_header_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_catering_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_catering_total_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_table_pane.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_horizontal_scroll_view.dart';

/// The left column: the heading band with its two captions, then the catering table.
class OcptBudgetRegieCateringColumn extends StatelessWidget {
  /// See [OcptBudgetRegie.days].
  final List<OcptBudgetRegieDay> days;

  /// See [OcptBudgetRegie.cateringTotals].
  final OcptBudgetRegieTotals totals;

  /// See [OcptBudgetRegie.decorNameByDayId].
  final Map<String, String> decorNameByDayId;

  /// See [OcptBudgetRegie.mealPriceCents].
  final int? mealPriceCents;

  /// See [OcptBudgetRegie.buffetPriceCents].
  final int? buffetPriceCents;

  /// See [OcptBudgetRegie.currencyCode].
  final String currencyCode;

  /// See [OcptBudgetRegie.onScheduleOpenRequested].
  final VoidCallback onScheduleOpenRequested;

  /// See [OcptBudgetRegie.onProjectSettingsRequested].
  final VoidCallback onProjectSettingsRequested;

  /// The height the table card is drawn at, or null while the panes sit side by side and the card
  /// takes whatever height the heading band leaves it — see [ocptBudgetRegieStackedMinRowCount].
  final double? tableHeight;

  /// Class constructor
  const OcptBudgetRegieCateringColumn({
    super.key,
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
      // and the view scrolls instead — see [ocptBudgetRegieStackedMinRowCount].
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: onScheduleOpenRequested,
              child: Text(tr.budgetRegieOpenScheduleAction),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OcptBudgetRegieTablePane(
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
                    width: math.max(constraints.maxWidth, ocptBudgetRegieCateringMinTableWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const OcptBudgetRegieCateringHeaderRow(),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: days.length,
                            itemBuilder: (context, index) => OcptBudgetRegieCateringRow(
                              day: days[index],
                              decorName: decorNameByDayId[days[index].dayId],
                              currencyCode: currencyCode,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        OcptBudgetRegieCateringTotalRow(totals: totals, currencyCode: currencyCode),
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
