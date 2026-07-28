// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The workspace's shared empty state: an icon in `outline`, one centred, localized line, no
/// actions. Reuses `OcptHomeEmptyState`'s proportions.
///
/// Used both for a production mode not implemented yet, filling its whole centre area, and for
/// any area of an implemented mode with nothing to show yet (a panel awaiting a selection).
class OcptWorkspaceEmptyMode extends StatelessWidget {
  /// The icon summarising what the empty area would hold; for a whole mode, the one shown for it
  /// in the mode switcher.
  final IconData icon;

  /// The localized line explaining why the area is empty.
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
