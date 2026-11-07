// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_frame.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_tab_label.dart';

/// The chrome of the shot list's right dock: a compact tab row (the active tab tinted `primary`
/// with a 2 px underline, the others `onSurfaceVariant`), a trailing × close button, and the
/// active tab's body below.
///
/// Modelled on the screenplay editor's own right dock: both draw their chrome through
/// [OcptRightDockFrame], and each resolves its own labels, so that no tab enum is shared between
/// the two docks, which host different sets of tabs.
class OcptShotListRightDock extends StatelessWidget {
  /// The currently active tab, whose body is shown below the tab row.
  final OcptShotListRightDockTab activeTab;

  /// The built shot inspector, shown when [activeTab] is [OcptShotListRightDockTab.inspector].
  final Widget inspectorChild;

  /// The built metadata panel, shown when [activeTab] is [OcptShotListRightDockTab.metadata].
  final Widget metadataChild;

  /// The built project versions panel, shown when [activeTab] is
  /// [OcptShotListRightDockTab.versions]. The very same widget the screenplay editor's own dock
  /// hosts: a version covers the whole project, not the shot list alone.
  final Widget versionsChild;

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
    required this.versionsChild,
    required this.onTabSelected,
    required this.onClose,
  });

  /// Build the shot list right dock as a [Column].
  /// Build the shot list right dock as an [OcptRightDockFrame].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptRightDockFrame(
      tabs: [
        for (final tab in OcptShotListRightDockTab.values)
          OcptRightDockTabLabel(
            label: switch (tab) {
              OcptShotListRightDockTab.inspector => tr.shotListRightDockInspectorTabLabel,
              OcptShotListRightDockTab.metadata => tr.shotListRightDockMetadataTabLabel,
              OcptShotListRightDockTab.versions => tr.shotListRightDockVersionsTabLabel,
            },
            isActive: activeTab == tab,
            onTap: () => onTabSelected(tab),
          ),
      ],
      closeTooltip: tr.shotListRightDockCloseTooltip,
      onClose: onClose,
      body: switch (activeTab) {
        OcptShotListRightDockTab.inspector => inspectorChild,
        OcptShotListRightDockTab.metadata => metadataChild,
        OcptShotListRightDockTab.versions => versionsChild,
      },
    );
  }
}
