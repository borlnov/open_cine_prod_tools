// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_financing_metrics.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One amount cell, right-aligned, reading [ocptBudgetEmptyValue] while [cents] is null, blank
/// while [showBlank] (a receipt sub-row's own untouched columns), and the given amount otherwise.
Widget ocptBudgetFinancingAmountCell(
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
    width: ocptBudgetFinancingAmountColumnWidth,
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
