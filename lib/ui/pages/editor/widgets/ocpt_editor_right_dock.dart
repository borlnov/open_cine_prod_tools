// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_syntax_guide_panel.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_frame.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_tab_label.dart';

/// The chrome of the editor's right dock: a compact tab row naming the tabs available in the
/// current editing mode (the active one tinted `primary` with a 2 px underline, the others
/// `onSurfaceVariant`), a trailing × close button, and the active tab's body below.
///
/// The tab row itself is clickable: tapping a label dispatches [onTabSelected] with that tab,
/// toggling it exactly like the workspace toolbar's own preview/syntax buttons do (selecting the
/// tab already active closes the dock). Preview and syntax are also reachable from those toolbar
/// buttons, which additionally double as a way to open a closed dock; inspector, metadata and
/// versions have no toolbar button of their own and are reachable from this row only. Only the ×
/// here acts on the dock directly, via [onClose]. In styled mode the preview tab doesn't exist at
/// all (its own layout already is the formatted screenplay), so the row skips it then.
class OcptEditorRightDock extends StatelessWidget {
  /// The currently active tab, whose body is shown below the tab row.
  final OcptEditorRightDockTab activeTab;

  /// Whether the preview tab exists in the current editing mode (raw mode only).
  final bool isPreviewTabAvailable;

  /// The built preview widget, shown when [activeTab] is [OcptEditorRightDockTab.preview]; null
  /// whenever it isn't (another tab's body is shown instead), so the caller never has to build it
  /// needlessly.
  final Widget? previewChild;

  /// The built inspector panel, shown when [activeTab] is [OcptEditorRightDockTab.inspector].
  final Widget inspectorChild;

  /// The built metadata panel, shown when [activeTab] is [OcptEditorRightDockTab.metadata].
  final Widget metadataChild;

  /// The built project versions panel, shown when [activeTab] is
  /// [OcptEditorRightDockTab.versions]. The very same widget the shot list's own dock hosts: a
  /// version covers the whole project, not the screenplay alone.
  final Widget versionsChild;

  /// Called with a tab when its label in the tab row is clicked.
  final ValueChanged<OcptEditorRightDockTab> onTabSelected;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const OcptEditorRightDock({
    super.key,
    required this.activeTab,
    required this.isPreviewTabAvailable,
    required this.previewChild,
    required this.inspectorChild,
    required this.metadataChild,
    required this.versionsChild,
    required this.onTabSelected,
    required this.onClose,
  });

  /// Build the editor right dock as a [Column].
  /// Build the editor right dock as an [OcptRightDockFrame].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptRightDockFrame(
      tabs: [
        if (isPreviewTabAvailable)
          OcptRightDockTabLabel(
            label: tr.editorRightDockPreviewTabLabel,
            isActive: activeTab == OcptEditorRightDockTab.preview,
            onTap: () => onTabSelected(OcptEditorRightDockTab.preview),
          ),
        OcptRightDockTabLabel(
          label: tr.editorRightDockSyntaxTabLabel,
          isActive: activeTab == OcptEditorRightDockTab.syntax,
          onTap: () => onTabSelected(OcptEditorRightDockTab.syntax),
        ),
        OcptRightDockTabLabel(
          label: tr.editorRightDockInspectorTabLabel,
          isActive: activeTab == OcptEditorRightDockTab.inspector,
          onTap: () => onTabSelected(OcptEditorRightDockTab.inspector),
        ),
        OcptRightDockTabLabel(
          label: tr.editorRightDockMetadataTabLabel,
          isActive: activeTab == OcptEditorRightDockTab.metadata,
          onTap: () => onTabSelected(OcptEditorRightDockTab.metadata),
        ),
        OcptRightDockTabLabel(
          label: tr.editorRightDockVersionsTabLabel,
          isActive: activeTab == OcptEditorRightDockTab.versions,
          onTap: () => onTabSelected(OcptEditorRightDockTab.versions),
        ),
      ],
      closeTooltip: tr.editorRightDockCloseTooltip,
      onClose: onClose,
      body: switch (activeTab) {
        OcptEditorRightDockTab.preview => previewChild ?? const SizedBox.shrink(),
        OcptEditorRightDockTab.syntax => const OcptEditorSyntaxGuidePanel(),
        OcptEditorRightDockTab.inspector => inspectorChild,
        OcptEditorRightDockTab.metadata => metadataChild,
        OcptEditorRightDockTab.versions => versionsChild,
      },
    );
  }
}
