// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// One bold total row, right-aligned — the `Distribution` table's own `Reinvested` footer.
class OcptBudgetSharingTotalRow extends StatelessWidget {
  /// The row's own label.
  final String label;

  /// The row's own value.
  final String valueText;

  /// Class constructor
  const OcptBudgetSharingTotalRow({super.key, required this.label, required this.valueText});

  /// Build the budget sharing total row as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boldStyle = theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: ocpt_theme.ocptTableRowHorizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: boldStyle)),
          Text(valueText, style: boldStyle),
        ],
      ),
    );
  }
}
