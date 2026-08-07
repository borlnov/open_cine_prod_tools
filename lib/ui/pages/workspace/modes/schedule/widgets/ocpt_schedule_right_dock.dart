// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';

/// The chrome of the schedule mode's right dock: a compact tab row, a trailing × close button, and
/// the active tab's body below — the exact mirror of `OcptBreakdownRightDock`, reduced to the
/// three tabs [OcptScheduleRightDockTab] carries.
class OcptScheduleRightDock extends StatelessWidget {
  /// The currently active tab, whose body is shown below the tab row.
  final OcptScheduleRightDockTab activeTab;

  /// The built inspector — the selected block's own read-out, or the selected day's own — shown
  /// when [activeTab] is [OcptScheduleRightDockTab.inspector].
  final Widget inspectorChild;

  /// The built convocations panel, shown when [activeTab] is
  /// [OcptScheduleRightDockTab.convocations].
  final Widget convocationsChild;

  /// The built project versions panel, shown when [activeTab] is
  /// [OcptScheduleRightDockTab.versions].
  final Widget versionsChild;

  /// Called with a tab when its label in the tab row is clicked.
  final ValueChanged<OcptScheduleRightDockTab> onTabSelected;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const OcptScheduleRightDock({
    super.key,
    required this.activeTab,
    required this.inspectorChild,
    required this.convocationsChild,
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
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in OcptScheduleRightDockTab.values)
                      _OcptScheduleRightDockTabLabel(
                        label: switch (tab) {
                          OcptScheduleRightDockTab.inspector => tr.scheduleRightDockInspectorTabLabel,
                          OcptScheduleRightDockTab.convocations =>
                            tr.scheduleRightDockConvocationsTabLabel,
                          OcptScheduleRightDockTab.versions => tr.scheduleRightDockVersionsTabLabel,
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
              tooltip: tr.scheduleRightDockCloseTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ],
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: switch (activeTab) {
            OcptScheduleRightDockTab.inspector => inspectorChild,
            OcptScheduleRightDockTab.convocations => convocationsChild,
            OcptScheduleRightDockTab.versions => versionsChild,
          },
        ),
      ],
    );
  }
}

/// One clickable label of the tab row, mirroring `OcptBreakdownRightDock`'s own private label.
class _OcptScheduleRightDockTabLabel extends StatelessWidget {
  /// The tab's display name.
  final String label;

  /// Whether this is the currently active tab.
  final bool isActive;

  /// Called when this label is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptScheduleRightDockTabLabel({
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
