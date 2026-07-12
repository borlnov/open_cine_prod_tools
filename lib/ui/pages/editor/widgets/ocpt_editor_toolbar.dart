// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The editor's thin, discreet toolbar: the screenplay title (with a dot marking unsaved
/// changes), then the save action (spinning while a save is in flight) and the scene panel /
/// preview visibility toggles.
class OcptEditorToolbar extends StatelessWidget {
  /// The title shown at the left of the toolbar (the open project's name).
  final String title;

  /// Whether there are unsaved changes, shown as a dot next to the title.
  final bool isDirty;

  /// Whether a save is in flight, replacing the save icon with a small spinner.
  final bool isSaving;

  /// Whether the scene panel is currently visible.
  final bool isScenePanelVisible;

  /// Whether the preview panel is currently visible.
  final bool isPreviewVisible;

  /// Called when the save action is clicked.
  final VoidCallback onSave;

  /// Called when the scene panel toggle is clicked.
  final VoidCallback onToggleScenePanel;

  /// Called when the preview toggle is clicked.
  final VoidCallback onTogglePreview;

  /// Class constructor
  const OcptEditorToolbar({
    super.key,
    required this.title,
    required this.isDirty,
    required this.isSaving,
    required this.isScenePanelVisible,
    required this.isPreviewVisible,
    required this.onSave,
    required this.onToggleScenePanel,
    required this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (isDirty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: tr.editorUnsavedChangesTooltip,
                  child: Text(
                    "●",
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            const Spacer(),
            if (isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save_outlined, size: 20),
                tooltip: tr.editorSaveTooltip,
                onPressed: onSave,
              ),
            IconButton(
              icon: Icon(
                isScenePanelVisible ? Icons.view_sidebar : Icons.view_sidebar_outlined,
                size: 20,
              ),
              tooltip: tr.editorToggleScenePanelTooltip,
              onPressed: onToggleScenePanel,
            ),
            IconButton(
              icon: Icon(isPreviewVisible ? Icons.article : Icons.article_outlined, size: 20),
              tooltip: tr.editorTogglePreviewTooltip,
              onPressed: onTogglePreview,
            ),
          ],
        ),
      ),
    );
  }
}
