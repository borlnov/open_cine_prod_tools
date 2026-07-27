// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The shared empty state for a production mode not implemented yet: its icon in `outline`, one
/// centred, localized line, no actions. Reuses `OcptHomeEmptyState`'s proportions.
class OcptWorkspaceEmptyMode extends StatelessWidget {
  /// The mode's icon, matching the one shown for it in the mode switcher.
  final IconData icon;

  /// The localized "coming in a future version" message for this mode.
  final String message;

  /// Class constructor
  const OcptWorkspaceEmptyMode({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
