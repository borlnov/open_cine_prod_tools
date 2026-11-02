// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The small stepper of an object's own states: a dot per step, filled and connected up to
/// `reachedCount`, hollow past it, its own label under each dot — the current (last reached) one
/// bold.
class OcptBudgetDetailStepper extends StatelessWidget {
  /// The stepper's own step labels, two or three words.
  final List<String> stepLabels;

  /// How many of [stepLabels] are reached, from the first.
  final int reachedCount;

  /// Class constructor
  const OcptBudgetDetailStepper({super.key, required this.stepLabels, required this.reachedCount});

  /// Build the budget detail panel stepper as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var index = 0; index < stepLabels.length; index++) ...[
              if (index > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index <= reachedCount - 1 ? colors.primary : colors.outlineVariant,
                  ),
                ),
              Icon(
                index < reachedCount ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: index < reachedCount ? colors.primary : colors.outlineVariant,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var index = 0; index < stepLabels.length; index++)
              Expanded(
                child: Text(
                  stepLabels[index],
                  textAlign: index == 0
                      ? TextAlign.start
                      : (index == stepLabels.length - 1 ? TextAlign.end : TextAlign.center),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: index < reachedCount ? colors.onSurface : colors.onSurfaceVariant,
                    fontWeight: index == reachedCount - 1 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
