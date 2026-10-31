// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';

/// One pill of a compact segmented selector: tinted `primary` while selected, clickable while
/// [onPressed] is given.
class OcptSelectablePill extends StatelessWidget {
  /// The pill's label.
  final String label;

  /// Whether this pill is the selected one.
  final bool isSelected;

  /// Called when the pill is clicked, or null while it may not be used.
  final VoidCallback? onPressed;

  /// Class constructor
  const OcptSelectablePill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPressed = this.onPressed;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : null,
        borderRadius: BorderRadius.circular(ocptRadiusSmall),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );

    if (onPressed == null) {
      return pill;
    }

    return InkWell(
      onTap: onPressed,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: pill,
    );
  }
}
