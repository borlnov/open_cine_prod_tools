// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// One line of the `Repaying the contributions` card: a muted label, a value — the last one
/// ([isEmphasized]) bolder and in the accent colour, the point of the card being to make it stand
/// out from the three that lead up to it.
class OcptBudgetSharingPotLine extends StatelessWidget {
  /// The line's own label.
  final String label;

  /// The line's own value.
  final String valueText;

  /// Whether this is the card's own final, emphasized line.
  final bool isEmphasized;

  /// Class constructor
  const OcptBudgetSharingPotLine({
    super.key,
    required this.label,
    required this.valueText,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: ocpt_theme.ocptTableRowHorizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: isEmphasized
                  ? theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)
                  : theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            valueText,
            style: isEmphasized
                ? theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
