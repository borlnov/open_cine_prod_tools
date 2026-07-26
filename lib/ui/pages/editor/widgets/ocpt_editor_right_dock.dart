// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_syntax_guide_panel.dart';

/// The chrome of the editor's right dock: a compact tab row naming the tabs available in the
/// current editing mode (the active one tinted `primary` with a 2 px underline, the others
/// `onSurfaceVariant`), a trailing × close button, and the active tab's body below.
///
/// The row is purely informational, not itself clickable: switching tabs is done through the
/// workspace toolbar's own preview/syntax buttons (`EditorPage`'s own toolbar actions), which
/// decision 3 of the design calls the tab selectors. Only the × here acts on the dock, via
/// [onClose]. In styled mode the preview tab doesn't exist at all (its own layout already is the
/// formatted screenplay), so the row only ever shows the syntax tab then — it still renders, it
/// just offers no choice.
class OcptEditorRightDock extends StatelessWidget {
  /// The currently active tab, whose body is shown below the tab row.
  final OcptEditorRightDockTab activeTab;

  /// Whether the preview tab exists in the current editing mode (raw mode only).
  final bool isPreviewTabAvailable;

  /// The built preview widget, shown when [activeTab] is [OcptEditorRightDockTab.preview]; null
  /// whenever it isn't (the syntax tab's placeholder is shown instead), so the caller never has to
  /// build it needlessly.
  final Widget? previewChild;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const OcptEditorRightDock({
    super.key,
    required this.activeTab,
    required this.isPreviewTabAvailable,
    required this.previewChild,
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
                    if (isPreviewTabAvailable)
                      _OcptRightDockTabLabel(
                        label: tr.editorRightDockPreviewTabLabel,
                        isActive: activeTab == OcptEditorRightDockTab.preview,
                      ),
                    _OcptRightDockTabLabel(
                      label: tr.editorRightDockSyntaxTabLabel,
                      isActive: activeTab == OcptEditorRightDockTab.syntax,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: tr.editorRightDockCloseTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ],
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: activeTab == OcptEditorRightDockTab.preview
              ? (previewChild ?? const SizedBox.shrink())
              : const OcptEditorSyntaxGuidePanel(),
        ),
      ],
    );
  }
}

/// One label of the tab row: the active tab tinted `primary` with a 2 px underline below it, the
/// others `onSurfaceVariant` with no underline.
class _OcptRightDockTabLabel extends StatelessWidget {
  /// The tab's display name.
  final String label;

  /// Whether this is the currently active tab.
  final bool isActive;

  /// Class constructor
  const _OcptRightDockTabLabel({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return Padding(
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
    );
  }
}
