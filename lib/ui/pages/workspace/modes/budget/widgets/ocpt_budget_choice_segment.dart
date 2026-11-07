// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// One segment of a choice of the budget mode's forms: a small bordered, clickable label, filled in
/// its accent colour and bolder while it is the active one.
///
/// The status pickers of the commitment, the resource, the revenue and the allowance forms and the
/// two-way `OcptBudgetBinaryChoice` draw their segments through it, so every choice of the mode
/// reads the same.
class OcptBudgetChoiceSegment extends StatelessWidget {
  /// The text of the segment.
  final String label;

  /// Whether the segment is the chosen one.
  final bool isActive;

  /// The colour the active segment is drawn in, or null for the theme's primary colour.
  final Color? accent;

  /// Whether the active segment's border takes [accent] too, rather than staying the outline
  /// colour.
  final bool hasAccentBorder;

  /// Whether [label] is cut with an ellipsis on a single line when the segment is too narrow for
  /// it, rather than wrapping.
  final bool isEllipsized;

  /// Called when the segment is clicked, or null while it may not be (the active one, or a choice
  /// that may not be changed).
  final VoidCallback? onTap;

  /// Class constructor
  const OcptBudgetChoiceSegment({
    super.key,
    required this.label,
    required this.isActive,
    required this.accent,
    required this.onTap,
    this.hasAccentBorder = true,
    this.isEllipsized = false,
  });

  /// Build the budget choice segment as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
              : Colors.transparent,
          border: Border.all(
            color: isActive && hasAccentBorder ? color : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
        ),
        child: Text(
          label,
          maxLines: isEllipsized ? 1 : null,
          overflow: isEllipsized ? TextOverflow.ellipsis : null,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isActive ? color : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
