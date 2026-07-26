// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';

/// The persistent application chrome around a production mode's own content: a toolbar, an
/// optional pair of resizable side docks around a centre area, and an optional status bar.
///
/// A mode contributes its own [toolbarActions]/[overflowEntries] (mode-specific controls) and its
/// [leftPanel]/[centre]/[rightPanel]/[statusBar] content; this widget only assembles the layout
/// and the dock-resizing mechanics shared by every mode. It knows nothing about any specific mode
/// (the screenplay editor included) beyond the moved [OcptWorkspaceDock]/[OcptWorkspaceDockDivider]
/// /[OcptWorkspaceDockLayoutController] primitives.
///
/// The docks row reuses the drag-doesn't-rebuild-the-centre pattern the screenplay editor
/// pioneered: [leftPanel], [centre] and [rightPanel] are built once by the caller and handed in as
/// fixed widget instances, then referenced unchanged from inside the [ListenableBuilder] that
/// listens to [dockLayoutController]. A divider drag only ever calls
/// [OcptWorkspaceDockLayoutController.setLeftFraction]/`setRightFraction`, which notifies that
/// builder alone; since it references the very same widget instances on every rebuild, Flutter's
/// `Element.update` short-circuits on their identity and only re-lays-out the resolved widths —
/// the content underneath never rebuilds mid-drag.
class OcptWorkspaceShell extends StatelessWidget {
  /// The open project's name, shown in the toolbar.
  final String title;

  /// Whether there are unsaved changes, shown as a dot next to the title.
  final bool isDirty;

  /// The back action; the mode decides what flushing it implies.
  final VoidCallback onBack;

  /// The active mode's own toolbar controls, right-aligned before the overflow menu.
  final List<Widget> toolbarActions;

  /// The `⋮` overflow menu's entries. An empty list renders no `⋮` button at all.
  final List<PopupMenuEntry<void>> overflowEntries;

  /// The left dock's content, or null when the mode has no left dock (no divider is shown either).
  final Widget? leftPanel;

  /// The right dock's content, or null when the mode has no right dock.
  final Widget? rightPanel;

  /// The mode's own main area.
  final Widget centre;

  /// The status band shown under the docks row, or null for no status band.
  final Widget? statusBar;

  /// The live dock fractions while a divider is being dragged, or null when the mode has no dock
  /// at all (in which case [leftPanel] and [rightPanel] must both be null too).
  final OcptWorkspaceDockLayoutController? dockLayoutController;

  /// Called once a drag gesture ends, reporting whichever side's fraction just changed. Only one
  /// of the record's fields is non-null per call, mirroring how the screenplay editor's own
  /// `OcptEditorDockFractionsChangedEvent` is shaped.
  final ValueChanged<({double? left, double? right})>? onDockFractionsChanged;

  /// Class constructor
  ///
  /// [dockLayoutController] must be given whenever [leftPanel] or [rightPanel] is, since resolving
  /// their widths needs the live drag fractions.
  const OcptWorkspaceShell({
    super.key,
    required this.title,
    required this.isDirty,
    required this.onBack,
    this.toolbarActions = const [],
    this.overflowEntries = const [],
    this.leftPanel,
    this.rightPanel,
    required this.centre,
    this.statusBar,
    this.dockLayoutController,
    this.onDockFractionsChanged,
  }) : assert(
         (leftPanel == null && rightPanel == null) || dockLayoutController != null,
         "dockLayoutController must be given when leftPanel or rightPanel is",
       );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      OcptWorkspaceToolbar(
        title: title,
        isDirty: isDirty,
        onBack: onBack,
        actions: toolbarActions,
        overflowEntries: overflowEntries,
      ),
      Expanded(child: _buildDocksRow()),
      if (statusBar != null) statusBar!,
    ],
  );

  /// Builds the left dock / centre / right dock row, wiring the dividers to
  /// [dockLayoutController] and reporting drag ends through [onDockFractionsChanged].
  ///
  /// Skips the [LayoutBuilder]/[ListenableBuilder]/dock-width machinery entirely when
  /// [dockLayoutController] is null (a mode with no dock at all): [centre] then simply fills the
  /// row.
  Widget _buildDocksRow() {
    final controller = dockLayoutController;
    if (controller == null) {
      return centre;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;

        return ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final widths = OcptWorkspaceDock.resolveDockWidths(
              rowWidth: rowWidth,
              leftFraction: controller.leftFraction,
              rightFraction: controller.rightFraction,
              isLeftDockVisible: leftPanel != null,
              isRightDockVisible: rightPanel != null,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leftPanel != null) ...[
                  OcptWorkspaceDock(width: widths.left, child: leftPanel!),
                  OcptWorkspaceDockDivider(
                    onDragUpdate: (deltaX) => controller.setLeftFraction(
                      OcptWorkspaceDock.clampLeftFraction(
                        controller.leftFraction + deltaX / rowWidth,
                        rowWidth,
                      ),
                    ),
                    onDragEnd: () =>
                        onDockFractionsChanged?.call((left: controller.leftFraction, right: null)),
                  ),
                ],
                Expanded(child: centre),
                if (rightPanel != null) ...[
                  OcptWorkspaceDockDivider(
                    onDragUpdate: (deltaX) => controller.setRightFraction(
                      OcptWorkspaceDock.clampRightFraction(
                        controller.rightFraction - deltaX / rowWidth,
                        rowWidth,
                      ),
                    ),
                    onDragEnd: () => onDockFractionsChanged?.call((
                      left: null,
                      right: controller.rightFraction,
                    )),
                  ),
                  OcptWorkspaceDock(width: widths.right, child: rightPanel!),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
