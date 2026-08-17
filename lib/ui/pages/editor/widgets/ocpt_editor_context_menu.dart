// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_fountain_line_type_labels.dart';

/// The right-click context menu of the styled screenplay editor: Cut, Copy, Paste, Select all, and
/// the block type as a submenu — [child]'s own popover, opened and positioned by whichever gesture
/// handler owns [controller] (a right-click today), never by this widget itself.
///
/// This file stays free of `package:super_editor`, like every other file outside
/// `lib/ui/pages/editor/super_editor/`: the caller resolves every super_editor concept (the caret's
/// block type, what the current selection allows) into plain callbacks and a plain
/// [FountainLineType] before handing them in here.
///
/// Every action callback is nullable, and a null one **removes its entry from the menu entirely**
/// rather than showing it disabled — the repository-wide rule for withholding a write affordance.
/// This is what makes Cut/Copy disappear over a collapsed selection (there is nothing to cut or
/// copy) and the block-type submenu disappear when the caret sits on no retypeable block.
class OcptEditorContextMenu extends StatelessWidget {
  /// The controller opening and closing this menu; owned by the caller, which also decides where it
  /// opens.
  final MenuController controller;

  /// The focus node of [child] (the editor's own), so keyboard focus returns to it once the menu
  /// closes.
  final FocusNode childFocusNode;

  /// The block type shown as the submenu's current selection, or null when the caret sits on no
  /// block that can be retyped (no selection, or a title-page field) — in which case
  /// [onTypeSelected] is also null and the submenu doesn't appear at all.
  final FountainLineType? currentType;

  /// Called to cut the current selection, or null while there is nothing expanded to cut.
  final VoidCallback? onCut;

  /// Called to copy the current selection, or null while there is nothing expanded to copy.
  final VoidCallback? onCopy;

  /// Called to paste the clipboard's content at the current selection, or null while there is no
  /// selection to paste into.
  final VoidCallback? onPaste;

  /// Called to select the whole document, or null while there is no selection to expand from.
  final VoidCallback? onSelectAll;

  /// Called with the picked block type, or null while the caret sits on no retypeable block.
  final ValueChanged<FountainLineType>? onTypeSelected;

  /// The widget this context menu is anchored on (the editor's own gesture-detecting surface).
  final Widget child;

  /// Class constructor
  const OcptEditorContextMenu({
    super.key,
    required this.controller,
    required this.childFocusNode,
    required this.currentType,
    required this.onCut,
    required this.onCopy,
    required this.onPaste,
    required this.onSelectAll,
    required this.onTypeSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onCut = this.onCut;
    final onCopy = this.onCopy;
    final onPaste = this.onPaste;
    final onSelectAll = this.onSelectAll;
    final onTypeSelected = this.onTypeSelected;
    final currentType = this.currentType;

    return MenuAnchor(
      controller: controller,
      childFocusNode: childFocusNode,
      menuChildren: [
        if (onCut != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.content_cut, size: 16),
            onPressed: onCut,
            child: Text(tr.editorContextMenuCutAction),
          ),
        if (onCopy != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.content_copy, size: 16),
            onPressed: onCopy,
            child: Text(tr.editorContextMenuCopyAction),
          ),
        if (onPaste != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.content_paste, size: 16),
            onPressed: onPaste,
            child: Text(tr.editorContextMenuPasteAction),
          ),
        if (onSelectAll != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.select_all, size: 16),
            onPressed: onSelectAll,
            child: Text(tr.editorContextMenuSelectAllAction),
          ),
        // Only drawn when both halves of the menu are actually there: the clipboard entries above
        // are all withheld over a collapsed selection but Paste and Select all, and a rule hanging
        // under nothing (or over nothing) would read as a missing entry rather than as a grouping.
        if (onTypeSelected != null &&
            currentType != null &&
            (onCut != null || onCopy != null || onPaste != null || onSelectAll != null))
          const Divider(height: 1),
        if (onTypeSelected != null && currentType != null)
          SubmenuButton(
            menuChildren: [
              for (final type in ocptAssignableFountainLineTypes)
                MenuItemButton(
                  trailingIcon: type == currentType ? const Icon(Icons.check, size: 16) : null,
                  onPressed: () => onTypeSelected(type),
                  child: Text(ocptFountainLineTypeLabel(tr, type)),
                ),
            ],
            child: Text(tr.editorContextMenuBlockTypeSubmenu),
          ),
      ],
      child: child,
    );
  }
}
