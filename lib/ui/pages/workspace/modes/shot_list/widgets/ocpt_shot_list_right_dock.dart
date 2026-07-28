// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';

/// The chrome of the shot list's right dock: a compact tab row (the active tab tinted `primary`
/// with a 2 px underline, the others `onSurfaceVariant`), a trailing × close button, and the
/// active tab's body below.
///
/// Modelled on the screenplay editor's own right dock, and deliberately a separate widget rather
/// than a shared one: the two docks host different sets of tabs, and folding both into one widget
/// would mean a tab enum neither mode fully uses.
class OcptShotListRightDock extends StatelessWidget {
  /// The currently active tab, whose body is shown below the tab row.
  final OcptShotListRightDockTab activeTab;

  /// The built shot inspector, shown when [activeTab] is [OcptShotListRightDockTab.inspector].
  final Widget inspectorChild;

  /// The built metadata panel, shown when [activeTab] is [OcptShotListRightDockTab.metadata].
  final Widget metadataChild;

  /// Called with a tab when its label in the tab row is clicked.
  final ValueChanged<OcptShotListRightDockTab> onTabSelected;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const OcptShotListRightDock({
    super.key,
    required this.activeTab,
    required this.inspectorChild,
    required this.metadataChild,
    required this.onTabSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // The tab cluster scrolls horizontally rather than overflowing: the dock can be
            // resized (and squeezed by the centre floor, see
            // `OcptWorkspaceDock.resolveDockWidths`) down to widths narrower than both tab labels
            // plus the close button combined.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in OcptShotListRightDockTab.values)
                      _OcptShotListRightDockTabLabel(
                        label: switch (tab) {
                          OcptShotListRightDockTab.inspector =>
                            tr.shotListRightDockInspectorTabLabel,
                          OcptShotListRightDockTab.metadata =>
                            tr.shotListRightDockMetadataTabLabel,
                        },
                        isActive: activeTab == tab,
                        onTap: () => onTabSelected(tab),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: tr.shotListRightDockCloseTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ],
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: switch (activeTab) {
            OcptShotListRightDockTab.inspector => inspectorChild,
            OcptShotListRightDockTab.metadata => metadataChild,
          },
        ),
      ],
    );
  }
}

/// One clickable label of the tab row: the active tab tinted `primary` with a 2 px underline
/// below it, the others `onSurfaceVariant` with no underline.
class _OcptShotListRightDockTabLabel extends StatelessWidget {
  /// The tab's display name.
  final String label;

  /// Whether this is the currently active tab.
  final bool isActive;

  /// Called when this label is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptShotListRightDockTabLabel({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
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
