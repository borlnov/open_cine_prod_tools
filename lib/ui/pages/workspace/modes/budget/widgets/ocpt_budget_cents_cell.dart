// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_amount_cell.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// One right-aligned amount cell of the financing and logistics tables: [cents] printed as an
/// amount in [currencyCode], [ocptBudgetEmptyValue] while [cents] is null, and blank while
/// [showBlank] (a sub-row's own untouched columns).
///
/// A negative amount is drawn in the error colour and semi-bold.
class OcptBudgetCentsCell extends StatelessWidget {
  /// The width of the column the cell belongs to.
  final double width;

  /// The amount in cents, or null when there is none to print.
  final int? cents;

  /// The ISO currency code [cents] is printed in.
  final String currencyCode;

  /// Whether the cell prints nothing at all, whatever [cents] is.
  final bool showBlank;

  /// The style the amount is printed in, or the theme's small body style when null.
  final TextStyle? style;

  /// Class constructor
  const OcptBudgetCentsCell({
    super.key,
    required this.width,
    required this.cents,
    required this.currencyCode,
    this.showBlank = false,
    this.style,
  });

  /// Build the cents cell as an [OcptBudgetAmountCell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cents = this.cents;
    final isNegative = cents != null && cents < 0;
    final baseStyle = style ?? theme.textTheme.bodySmall;

    return OcptBudgetAmountCell(
      width: width,
      text: showBlank
          ? ""
          : (cents == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(cents, currencyCode)),
      style: baseStyle?.copyWith(
        color: isNegative ? theme.colorScheme.error : null,
        fontWeight: isNegative ? FontWeight.w600 : null,
      ),
    );
  }
}
