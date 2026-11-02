// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_frame.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_tab_label.dart';

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

  /// Build the breakdown right dock as a [Column].
  /// Build the breakdown right dock as an [OcptRightDockFrame].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptRightDockFrame(
      tabs: [
        for (final tab in OcptBreakdownRightDockTab.values)
          OcptRightDockTabLabel(
            label: switch (tab) {
              OcptBreakdownRightDockTab.inspector => tr.breakdownRightDockInspectorTabLabel,
              OcptBreakdownRightDockTab.versions => tr.breakdownRightDockVersionsTabLabel,
            },
            isActive: activeTab == tab,
            onTap: () => onTabSelected(tab),
          ),
      ],
      closeTooltip: tr.breakdownRightDockCloseTooltip,
      onClose: onClose,
      body: switch (activeTab) {
        OcptBreakdownRightDockTab.inspector => inspectorChild,
        OcptBreakdownRightDockTab.versions => versionsChild,
      },
    );
  }
}
