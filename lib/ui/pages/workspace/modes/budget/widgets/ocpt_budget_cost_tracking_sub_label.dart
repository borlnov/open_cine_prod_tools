// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_metrics.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cost_tracking_sub_identity_row.dart';

/// One line of a sub-row's own identity label: an optional coloured dot, the label itself, and an
/// optional trailing badge pill — [OcptBudgetCostTrackingSubIdentityRow]'s own `builder` hands one of
/// these back for every sub-row kind.
class OcptBudgetCostTrackingSubLabel extends StatelessWidget {
  /// The text shown.
  final String label;

  /// Whether [label] prints in the muted, one-step-smaller ink the mockup draws every sub-row in.
  final bool isMuted;

  /// Whether [label] prints in italics — an unnamed line, or the "no entry" hint.
  final bool isItalic;

  /// The colour of the leading dot, or null while this row draws none.
  final Color? dotColor;

  /// The trailing badge's own text, or null while this row draws none.
  final String? badgeText;

  /// The trailing badge's own colour, read together with [badgeText].
  final Color? badgeColor;

  /// Class constructor
  const OcptBudgetCostTrackingSubLabel({
    super.key,
    required this.label,
    this.isMuted = false,
    this.isItalic = false,
    this.dotColor,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: isMuted ? theme.colorScheme.onSurfaceVariant : null,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
    );
    final dotColor = this.dotColor;
    final badgeText = this.badgeText;

    return Row(
      children: [
        if (dotColor != null) ...[
          Container(
            width: ocptBudgetCostTrackingDotDiameter,
            height: ocptBudgetCostTrackingDotDiameter,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
        if (badgeText != null && badgeText.isNotEmpty) ...[
          const SizedBox(width: 6),
          // Capped, never left to its own natural width: at the pinned pane's own narrowest
          // ([ocptBudgetCostTrackingPosteColumnMinWidth]), a long status word ("Quote accepted") would
          // otherwise overflow the row outright rather than sharing the little room there is with
          // the label beside it.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ocptBudgetCostTrackingBadgeMaxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: (badgeColor ?? theme.colorScheme.onSurfaceVariant).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: badgeColor ?? theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
