// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// One pill of a choice-chip row: filled with [color] while [isSelected], otherwise a plain
/// outline.
///
/// Shared by `OcptBreakdownTargetInspector`'s own status chips and
/// `OcptBreakdownSceneInspector`'s scene status chips — the two are the same pill over two
/// different enums, so it is factored out here rather than duplicated.
class OcptBreakdownChoiceChip extends StatelessWidget {
  /// The chip's own label.
  final String label;

  /// The chip's own colour, its fill while selected and its text colour either way.
  final Color color;

  /// Whether this is the currently selected value.
  final bool isSelected;

  /// Called when the chip is clicked, or null while it may not be picked.
  final VoidCallback? onTap;

  /// Class constructor
  const OcptBreakdownChoiceChip({
    super.key,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusLarge),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: ocptSelectedStateAlpha) : Colors.transparent,
          borderRadius: BorderRadius.circular(ocptRadiusLarge),
          border: Border.all(color: isSelected ? color : theme.colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
