// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// One clickable label of a right dock's tab row: the active tab tinted `primary` with a 2 px
/// underline below it, the others `onSurfaceVariant` with no underline.
class OcptRightDockTabLabel extends StatelessWidget {
  /// The tab's display name.
  final String label;

  /// Whether this is the currently active tab.
  final bool isActive;

  /// Called when this label is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const OcptRightDockTabLabel({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  /// Build the right dock tab label as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
            const SizedBox(height: 4),
            Container(
              height: 2,
              width: 32,
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
