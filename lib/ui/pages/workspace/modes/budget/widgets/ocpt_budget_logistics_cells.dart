// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_logistics_metrics.dart';

/// Get the height a table card holding [rowCount] rows of [rowHeight] is drawn at once the panes
/// stack.
double ocptBudgetLogisticsStackedCardHeight(int rowCount, double rowHeight) =>
    ocptBudgetLogisticsCardChromeHeight +
    rowHeight *
        rowCount.clamp(
          ocptBudgetLogisticsStackedMinRowCount,
          ocptBudgetLogisticsStackedMaxRowCount,
        );

/// Count how many top-level rows [allowances] draws in the stacked layout's own height guess: one
/// per
/// distinct person named, plus one for every defrayal naming nobody, each its own group of one —
/// never the sub-rows a group's own twisty later reveals, since
/// [ocptBudgetLogisticsStackedCardHeight]'s own clamp already floors and ceilings this into a
/// reasonable card height either way.
int ocptBudgetLogisticsAllowanceGroupCountOf(List<OcptBudgetAllowance> allowances) {
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
