// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// The figures that make the amount up: a `Wrap` of muted-label-over-value pairs, mirroring
/// `OcptBudgetCostTracking`'s own figure reading.
class OcptBudgetFicheFiguresRow extends StatelessWidget {
  /// The figures to draw: a label paired with an already-formatted value, or null for
  /// [ocptBudgetEmptyValue].
  final List<(String label, String? value)> figures;

  /// Class constructor
  const OcptBudgetFicheFiguresRow({super.key, required this.figures});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        for (final figure in figures)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                figure.$1.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(figure.$2 ?? ocptBudgetEmptyValue, style: theme.textTheme.bodyMedium),
            ],
          ),
      ],
    );
  }
}
