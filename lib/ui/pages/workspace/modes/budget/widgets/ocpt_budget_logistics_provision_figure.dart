// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One figure of the provisioning band: its caption over its value.
class OcptBudgetLogisticsProvisionFigure extends StatelessWidget {
  /// The figure's own caption.
  final String label;

  /// The figure itself, already formatted.
  final String value;

  /// The colour the value reads in, or null for the ordinary one.
  final Color? valueColor;

  /// Class constructor
  const OcptBudgetLogisticsProvisionFigure({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  /// Build the budget logistics provision figure as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(color: valueColor)),
      ],
    );
  }
}
