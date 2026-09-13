// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_fountain_line_type_labels.dart';

/// The compact-width toolbar's stand-in for `OcptEditorFormatControls`: the exact same block-type
/// choice and Bold/Italic/Underline toggles, folded behind a single `⋮` button instead of laid out
/// inline, for the width range too narrow for the fixed-width dropdown and the three icon buttons
/// to fit beside everything else the toolbar already carries there
/// (`ocptCompactWidthBreakpoint`/`docs/architecture/foundations.md`).
///
/// Wired to the very same [controller] `OcptEditorFormatControls` reads, so this is never a second
/// flow — only how the same choice is presented changes; rendered only while [controller] is
/// attached to a live styled editor (`SizedBox.shrink()` otherwise: raw mode, or the very first
/// frame before the styled editor attaches), exactly like the inline controls.
class OcptEditorFormatOverflowMenu extends StatelessWidget {
  /// The controller read for the current block type / active inline styles, and written to when an
  /// entry is picked.
  final OcptStyledEditorController controller;

  /// Class constructor
  const OcptEditorFormatOverflowMenu({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (!controller.isAttached) {
        return const SizedBox.shrink();
      }

      final tr = Tr.of(context);
      final activeStyles = controller.activeInlineStyles;
      final currentType = controller.currentBlockType;

      return MenuAnchor(
        menuChildren: [
          SubmenuButton(
            menuChildren: [
              for (final type in ocptAssignableFountainLineTypes)
                MenuItemButton(
                  trailingIcon: type == currentType ? const Icon(Icons.check, size: 16) : null,
                  onPressed: () => controller.setBlockType(type),
                  child: Text(ocptFountainLineTypeLabel(tr, type)),
                ),
            ],
            child: Text(tr.editorContextMenuBlockTypeSubmenu),
          ),
          const Divider(height: 1),
          MenuItemButton(
            trailingIcon: activeStyles.contains(OcptInlineStyle.bold)
                ? const Icon(Icons.check, size: 16)
                : null,
            leadingIcon: const Icon(Icons.format_bold, size: 18),
            onPressed: () => controller.toggleInlineStyle(OcptInlineStyle.bold),
            child: Text(tr.editorToggleBoldTooltip),
          ),
          MenuItemButton(
            trailingIcon: activeStyles.contains(OcptInlineStyle.italic)
                ? const Icon(Icons.check, size: 16)
                : null,
            leadingIcon: const Icon(Icons.format_italic, size: 18),
            onPressed: () => controller.toggleInlineStyle(OcptInlineStyle.italic),
            child: Text(tr.editorToggleItalicTooltip),
          ),
          MenuItemButton(
            trailingIcon: activeStyles.contains(OcptInlineStyle.underline)
                ? const Icon(Icons.check, size: 16)
                : null,
            leadingIcon: const Icon(Icons.format_underlined, size: 18),
            onPressed: () => controller.toggleInlineStyle(OcptInlineStyle.underline),
            child: Text(tr.editorToggleUnderlineTooltip),
          ),
        ],
        builder: (context, menuController, child) => IconButton(
          // The canonical "format text" glyph (an A with a baseline bar) — reads as text styling,
          // and no longer collides with the mode overflow's own `⋮`.
          icon: const Icon(Icons.text_format, size: 22),
          tooltip: tr.editorFormatMenuTooltip,
          onPressed: () =>
              menuController.isOpen ? menuController.close() : menuController.open(),
        ),
      );
    },
  );
}
