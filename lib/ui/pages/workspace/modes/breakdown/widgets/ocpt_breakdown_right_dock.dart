// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The chrome of the breakdown mode's right dock: mirrors `OcptResourcesRightDock`, the shot list's
/// own tab row chrome reduced to its single tab, since `OcptBreakdownRightDockTab` has only one
/// entry (`versions` — the `Inspector` tab is a later milestone's), plus a trailing × close button,
/// and the versions panel underneath.
class OcptBreakdownRightDock extends StatelessWidget {
  /// The built project versions panel.
  final Widget versionsChild;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const OcptBreakdownRightDock({super.key, required this.versionsChild, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.breakdownRightDockVersionsTabLabel,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Container(height: 2, width: 32, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: tr.breakdownRightDockCloseTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ],
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        Expanded(child: versionsChild),
      ],
    );
  }
}
