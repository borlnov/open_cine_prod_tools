// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_allowance.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_regie_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// Get the height a table card holding [rowCount] rows of [rowHeight] is drawn at once the panes
/// stack.
double ocptBudgetRegieStackedCardHeight(int rowCount, double rowHeight) =>
    ocptBudgetRegieCardChromeHeight +
    rowHeight *
        rowCount.clamp(ocptBudgetRegieStackedMinRowCount, ocptBudgetRegieStackedMaxRowCount);

/// Count how many top-level rows [allowances] draws in the stacked layout's own height guess: one
/// per
/// distinct person named, plus one for every defrayal naming nobody, each its own group of one —
/// never the sub-rows a group's own twisty later reveals, since
/// [ocptBudgetRegieStackedCardHeight]'s own clamp already floors and ceilings this into a
/// reasonable card height either way.
int ocptBudgetRegieAllowanceGroupCountOf(List<OcptBudgetAllowance> allowances) {
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

/// Build one amount cell, right-aligned, reading [ocptBudgetEmptyValue] while [cents] is null,
/// blank
/// while [showBlank] (a sub-row's own untouched columns), and the given amount otherwise — mirrors
/// `OcptBudgetFinancing`'s own `_ocptResourcesAmountCell`.
Widget ocptBudgetRegieAllowanceAmountCell(
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
    width: ocptBudgetRegieAllowanceAmountColumnWidth,
    child: Text(
      showBlank
          ? ""
          : (cents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(cents, currencyCode)),
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
