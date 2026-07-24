// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_block_type_dropdown.dart';

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

  /// Whether the "Word-like" page simulation is currently enabled, shown as a checked state on
  /// its overflow menu entry.
  final bool isPageSimulationEnabled;

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

  /// Called when "Export…" is chosen from the overflow menu.
  final VoidCallback onExport;

  /// Called when "Export to PDF…" is chosen from the overflow menu.
  final VoidCallback onExportPdf;

  /// Called when "Import and replace…" is chosen from the overflow menu.
  final VoidCallback onImportAndReplace;

  /// Called when "Page simulation" is toggled from the overflow menu.
  final VoidCallback onTogglePageSimulation;

  /// Called when "Page setup…" is chosen from the overflow menu.
  final VoidCallback onPageSetup;

  /// Called when "Title page…" is chosen from the overflow menu.
  final VoidCallback onTitlePage;

  /// Called when "Reset panel layout" is chosen from the overflow menu.
  final VoidCallback onResetPanelLayout;

  /// The controller bridging this toolbar to the live styled editor's block-type dropdown and
  /// B/I/U toggles, or null when there is none to wire up. The format controls only render while
  /// this is non-null AND `OcptStyledEditorController.isAttached` (raw mode leaves it detached),
  /// which is what makes them disappear outside styled mode.
  final OcptStyledEditorController? styledController;

  /// Class constructor
  const OcptEditorToolbar({
    super.key,
    required this.title,
    required this.isDirty,
    required this.isSaving,
    required this.isScenePanelVisible,
    required this.isPreviewVisible,
    required this.isPageSimulationEnabled,
    required this.mode,
    required this.onBack,
    required this.onSave,
    required this.onToggleScenePanel,
    required this.onTogglePreview,
    required this.onToggleMode,
    required this.onExport,
    required this.onExportPdf,
    required this.onImportAndReplace,
    required this.onTogglePageSimulation,
    required this.onPageSetup,
    required this.onTitlePage,
    required this.onResetPanelLayout,
    this.styledController,
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
            if (styledController != null) _OcptFormatControls(controller: styledController!),
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
                mode == OcptEditorMode.styled ? Icons.code : Icons.style,
                size: 20,
              ),
              tooltip: mode == OcptEditorMode.styled
                  ? tr.editorSwitchToRawModeTooltip
                  : tr.editorSwitchToStyledModeTooltip,
              onPressed: onToggleMode,
            ),
            PopupMenuButton<void>(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              itemBuilder: (context) => [
                PopupMenuItem<void>(onTap: onExport, child: Text(tr.editorExportAction)),
                PopupMenuItem<void>(onTap: onExportPdf, child: Text(tr.editorExportPdfAction)),
                PopupMenuItem<void>(
                  onTap: onImportAndReplace,
                  child: Text(tr.editorImportAndReplaceAction),
                ),
                CheckedPopupMenuItem<void>(
                  checked: isPageSimulationEnabled,
                  onTap: onTogglePageSimulation,
                  child: Text(tr.editorTogglePageSimulationAction),
                ),
                PopupMenuItem<void>(onTap: onPageSetup, child: Text(tr.editorPageSetupAction)),
                PopupMenuItem<void>(onTap: onTitlePage, child: Text(tr.editorTitlePageAction)),
                PopupMenuItem<void>(
                  onTap: onResetPanelLayout,
                  child: Text(tr.editorResetPanelLayoutAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The toolbar's block-type dropdown and B/I/U toggles, rendered only while [controller] is
/// attached to a live styled editor (`SizedBox.shrink()` otherwise: raw mode, or the very first
/// frame before the styled editor attaches).
///
/// Wrapped in `Focus(canRequestFocus: false)`, on top of [OcptEditorBlockTypeDropdown]'s own
/// wrapper, so none of these controls ever steal keyboard focus from the styled editor; the
/// styled editor's own state explicitly refocuses itself after applying any change these controls
/// request.
class _OcptFormatControls extends StatelessWidget {
  /// The controller read for the current block type / active inline styles, and written to when a
  /// control is used.
  final OcptStyledEditorController controller;

  /// Class constructor
  const _OcptFormatControls({required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (!controller.isAttached) {
        return const SizedBox.shrink();
      }

      final tr = Tr.of(context);
      final activeStyles = controller.activeInlineStyles;

      return Focus(
        canRequestFocus: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OcptEditorBlockTypeDropdown(
              currentType: controller.currentBlockType,
              onTypeSelected: controller.setBlockType,
            ),
            IconButton(
              icon: const Icon(Icons.format_bold, size: 20),
              tooltip: tr.editorToggleBoldTooltip,
              isSelected: activeStyles.contains(OcptInlineStyle.bold),
              onPressed: () => controller.toggleInlineStyle(OcptInlineStyle.bold),
            ),
            IconButton(
              icon: const Icon(Icons.format_italic, size: 20),
              tooltip: tr.editorToggleItalicTooltip,
              isSelected: activeStyles.contains(OcptInlineStyle.italic),
              onPressed: () => controller.toggleInlineStyle(OcptInlineStyle.italic),
            ),
            IconButton(
              icon: const Icon(Icons.format_underlined, size: 20),
              tooltip: tr.editorToggleUnderlineTooltip,
              isSelected: activeStyles.contains(OcptInlineStyle.underline),
              onPressed: () => controller.toggleInlineStyle(OcptInlineStyle.underline),
            ),
          ],
        ),
      );
    },
  );
}
