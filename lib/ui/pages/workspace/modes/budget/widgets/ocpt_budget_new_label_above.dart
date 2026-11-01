// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// A field's own label above it, dense — the one idiom every field of step 3 shares
/// (`docs/architecture/budget.md`).
class OcptBudgetNewLabelAbove extends StatelessWidget {
  /// The label, drawn upper-cased above [child].
  final String label;

  /// The field the label belongs to.
  final Widget child;

  /// Class constructor
  const OcptBudgetNewLabelAbove({super.key, required this.label, required this.child});

  /// Build the budget new label above as a [Column].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
