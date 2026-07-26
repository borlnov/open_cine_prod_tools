// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_block_type_dropdown.dart';

/// The screenplay's block-type dropdown and B/I/U toggles, one of the workspace toolbar's
/// `toolbarActions` while the editor mode is active; rendered only while [controller] is attached
/// to a live styled editor (`SizedBox.shrink()` otherwise: raw mode, or the very first frame
/// before the styled editor attaches).
///
/// Wrapped in `Focus(canRequestFocus: false)`, on top of [OcptEditorBlockTypeDropdown]'s own
/// wrapper, so none of these controls ever steal keyboard focus from the styled editor; the
/// styled editor's own state explicitly refocuses itself after applying any change these controls
/// request.
class OcptEditorFormatControls extends StatelessWidget {
  /// The controller read for the current block type / active inline styles, and written to when a
  /// control is used.
  final OcptStyledEditorController controller;

  /// Class constructor
  const OcptEditorFormatControls({super.key, required this.controller});

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
