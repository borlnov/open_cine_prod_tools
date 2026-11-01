// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// One selectable row of step 2 — a plain list row, tinted `primary` while selected, an optional
/// muted hint underneath.
class OcptBudgetNewChoiceRow extends StatelessWidget {
  /// The row's own bold label.
  final String label;

  /// The muted hint under the label, or null for none.
  final String? hint;

  /// Whether this row is the currently selected answer.
  final bool isSelected;

  /// Whether the row can be picked; a disabled row is greyed and ignores taps.
  final bool isEnabled;

  /// Whether this is the trailing `create…` row, drawn with a leading `+` in the accent colour.
  final bool isCreationRow;

  /// Called when an enabled row is tapped.
  final VoidCallback onTap;

  /// Class constructor
  const OcptBudgetNewChoiceRow({
    super.key,
    required this.label,
    this.hint,
    required this.isSelected,
    this.isEnabled = true,
    this.isCreationRow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = !isEnabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : (isCreationRow ? theme.colorScheme.primary : theme.colorScheme.onSurface);

    return InkWell(
      onTap: isEnabled ? onTap : null,
      mouseCursor: isEnabled ? ocpt_theme.ocptClickableCursor : SystemMouseCursors.forbidden,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
              : null,
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
        ),
        child: Row(
          children: [
            if (isCreationRow) ...[
              Icon(Icons.add, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: isCreationRow || isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  if (hint case final hint?)
                    Text(
                      hint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
