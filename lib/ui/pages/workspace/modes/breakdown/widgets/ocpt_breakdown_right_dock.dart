// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';

/// The chrome of the breakdown mode's right dock: a compact tab row (the active tab tinted
/// `primary` with a 2 px underline, the other `onSurfaceVariant`), a trailing × close button, and
/// the active tab's body below — mirrors `OcptShotListRightDock` exactly, reduced to the two tabs
/// [OcptBreakdownRightDockTab] carries.
class OcptBreakdownRightDock extends StatelessWidget {
  /// The currently active tab, whose body is shown below the tab row.
  final OcptBreakdownRightDockTab activeTab;

  /// The built inspector — the selected target's sheet, or the selected scene's own breakdown
  /// sheet while nothing is selected — shown when [activeTab] is
  /// [OcptBreakdownRightDockTab.inspector].
  final Widget inspectorChild;

  /// The built project versions panel, shown when [activeTab] is
  /// [OcptBreakdownRightDockTab.versions]. The very same widget every other mode's dock hosts: a
  /// version covers the whole project, not the breakdown mode alone.
  final Widget versionsChild;

  /// Called with a tab when its label in the tab row is clicked.
  final ValueChanged<OcptBreakdownRightDockTab> onTabSelected;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const OcptBreakdownRightDock({
    super.key,
    required this.activeTab,
    required this.inspectorChild,
    required this.versionsChild,
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
            // The tab cluster scrolls horizontally rather than overflowing, mirroring
            // `OcptShotListRightDock`: the dock can be resized (and squeezed by the centre floor,
            // see `OcptWorkspaceDock.resolveDockWidths`) down to a width narrower than both tab
            // labels plus the close button combined.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in OcptBreakdownRightDockTab.values)
                      _OcptBreakdownRightDockTabLabel(
                        label: switch (tab) {
                          OcptBreakdownRightDockTab.inspector =>
                            tr.breakdownRightDockInspectorTabLabel,
                          OcptBreakdownRightDockTab.versions => tr.breakdownRightDockVersionsTabLabel,
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
              tooltip: tr.breakdownRightDockCloseTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ],
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: switch (activeTab) {
            OcptBreakdownRightDockTab.inspector => inspectorChild,
            OcptBreakdownRightDockTab.versions => versionsChild,
          },
        ),
      ],
    );
  }
}

/// One clickable label of the tab row: the active tab tinted `primary` with a 2 px underline
/// below it, the other `onSurfaceVariant` with no underline. Mirrors
/// `OcptShotListRightDock`'s own private tab label widget.
class _OcptBreakdownRightDockTabLabel extends StatelessWidget {
  /// The tab's display name.
  final String label;

  /// Whether this is the currently active tab.
  final bool isActive;

  /// Called when this label is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptBreakdownRightDockTabLabel({
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
      mouseCursor: ocptClickableCursor,
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
