// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_gesture.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_new_gesture_labels.dart';

/// One card of step 1 — a bold answer over its own muted hint, tinted `primary` while selected.
/// Mirrors `_OcptBudgetEntryNatureCard`, one card per [OcptBudgetGesture] rather than per
/// `OcptBudgetEntryNature`.
class OcptBudgetNewGestureCard extends StatelessWidget {
  /// The answer this card stands for.
  final OcptBudgetGesture gesture;

  /// Whether this card is the currently selected answer.
  final bool isSelected;

  /// Called when the card is tapped.
  final VoidCallback onSelected;

  /// Class constructor
  const OcptBudgetNewGestureCard({
    super.key,
    required this.gesture,
    required this.isSelected,
    required this.onSelected,
  });

  /// Build the budget new gesture card as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      key: Key("ocptBudgetNewGestureCard-${gesture.name}"),
      onTap: onSelected,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
              : null,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ocptBudgetGestureAnswerLabel(tr, gesture),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              ocptBudgetGestureHint(tr, gesture),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
