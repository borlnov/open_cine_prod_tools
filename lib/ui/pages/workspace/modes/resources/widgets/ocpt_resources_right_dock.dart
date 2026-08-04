// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_right_dock_tab.dart';

/// The chrome of the resources mode's right dock: the shot list's own tab row chrome reduced to
/// its single tab, since `OcptResourcesRightDockTab` has only one entry
/// ([OcptResourcesRightDockTab.versions] — see its own doc comment for why the dock exists at all
/// with no inspector), plus a trailing × close button, and the versions panel underneath.
class OcptResourcesRightDock extends StatelessWidget {
  /// The built project versions panel.
  final Widget versionsChild;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const OcptResourcesRightDock({super.key, required this.versionsChild, required this.onClose});

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
                      tr.resourcesRightDockVersionsTabLabel,
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
              tooltip: tr.resourcesRightDockCloseTooltip,
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
