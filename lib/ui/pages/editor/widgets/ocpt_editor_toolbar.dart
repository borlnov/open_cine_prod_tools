// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';

/// The editor's thin, discreet toolbar: the back action leading to the projects list, the
/// screenplay title (with a dot marking unsaved changes), then the save action (spinning while a
/// save is in flight), the styled/raw mode toggle, and the scene panel / preview visibility
/// toggles.
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
  ///
  /// The preview toggle is only shown in [OcptEditorMode.raw]: the styled mode has no separate
  /// preview panel, since its own layout already is the formatted screenplay.
  final bool isPreviewVisible;

  /// The current editing mode: the styled block editor or the raw text source.
  final OcptEditorMode mode;

  /// Called when the back action is clicked.
  final VoidCallback onBack;

  /// Called when the save action is clicked.
  final VoidCallback onSave;

  /// Called when the scene panel toggle is clicked.
  final VoidCallback onToggleScenePanel;

  /// Called when the preview toggle is clicked.
  final VoidCallback onTogglePreview;

  /// Called when the styled/raw mode toggle is clicked.
  final VoidCallback onToggleMode;

  /// Class constructor
  const OcptEditorToolbar({
    super.key,
    required this.title,
    required this.isDirty,
    required this.isSaving,
    required this.isScenePanelVisible,
    required this.isPreviewVisible,
    required this.mode,
    required this.onBack,
    required this.onSave,
    required this.onToggleScenePanel,
    required this.onTogglePreview,
    required this.onToggleMode,
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
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: tr.editorBackToProjectsTooltip,
              onPressed: onBack,
            ),
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
            if (mode == OcptEditorMode.raw)
              IconButton(
                icon: Icon(isPreviewVisible ? Icons.article : Icons.article_outlined, size: 20),
                tooltip: tr.editorTogglePreviewTooltip,
                onPressed: onTogglePreview,
              ),
            IconButton(
              icon: Icon(
                mode == OcptEditorMode.styled ? Icons.style : Icons.code,
                size: 20,
              ),
              tooltip: mode == OcptEditorMode.styled
                  ? tr.editorSwitchToRawModeTooltip
                  : tr.editorSwitchToStyledModeTooltip,
              onPressed: onToggleMode,
            ),
          ],
        ),
      ),
    );
  }
}
