// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_schedule_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_frame.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_tab_label.dart';

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

  /// The built alerts panel, shown when [activeTab] is [OcptScheduleRightDockTab.alerts].
  final Widget alertsChild;

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
    required this.alertsChild,
    required this.versionsChild,
    required this.onTabSelected,
    required this.onClose,
  });

  /// Build the schedule right dock as a [Column].
  /// Build the schedule right dock as an [OcptRightDockFrame].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptRightDockFrame(
      tabs: [
        for (final tab in OcptScheduleRightDockTab.values)
          OcptRightDockTabLabel(
            label: switch (tab) {
              OcptScheduleRightDockTab.inspector => tr.scheduleRightDockInspectorTabLabel,
              OcptScheduleRightDockTab.convocations => tr.scheduleRightDockConvocationsTabLabel,
              OcptScheduleRightDockTab.alerts => tr.scheduleRightDockAlertsTabLabel,
              OcptScheduleRightDockTab.versions => tr.scheduleRightDockVersionsTabLabel,
            },
            isActive: activeTab == tab,
            onTap: () => onTabSelected(tab),
          ),
      ],
      closeTooltip: tr.scheduleRightDockCloseTooltip,
      onClose: onClose,
      body: switch (activeTab) {
        OcptScheduleRightDockTab.inspector => inspectorChild,
        OcptScheduleRightDockTab.convocations => convocationsChild,
        OcptScheduleRightDockTab.alerts => alertsChild,
        OcptScheduleRightDockTab.versions => versionsChild,
      },
    );
  }
}
