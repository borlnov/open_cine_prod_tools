// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The table's own `+ Poste` creation footer, drawn below the table rather than as one of its own
/// scrolling rows — left-aligned like the pinned pane above it, and, unlike it, never scrolled
/// away by either the table's own vertical or horizontal scroll.
class OcptBudgetCostTrackingCreationFooter extends StatelessWidget {
  /// Called when this footer is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const OcptBudgetCostTrackingCreationFooter({super.key, required this.onTap});

  /// Build the budget cost tracking creation footer as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              tr.budgetAccountCreationAction,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
