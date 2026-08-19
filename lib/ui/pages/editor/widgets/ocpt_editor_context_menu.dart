// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_fountain_line_type_labels.dart';

/// The right-click context menu of the styled screenplay editor: up to five spelling suggestions,
/// `Ignore this word` and `Add to the project's dictionary`, Cut, Copy, Paste, Select all, and the
/// block type as a submenu — [child]'s own popover, opened and positioned by whichever gesture
/// handler owns [controller] (a right-click today), never by this widget itself.
///
/// This file stays free of `package:super_editor`, like every other file outside
/// `lib/ui/pages/editor/super_editor/`: the caller resolves every super_editor concept (the caret's
/// block type, what the current selection allows, which word under the pointer is misspelled) into
/// plain callbacks, plain strings and a plain [FountainLineType] before handing them in here.
///
/// Every action callback is nullable, and a null one **removes its entry from the menu entirely**
/// rather than showing it disabled — the repository-wide rule for withholding a write affordance.
/// This is what makes Cut/Copy disappear over a collapsed selection (there is nothing to cut or
/// copy), the block-type submenu disappear when the caret sits on no retypeable block, and the
/// whole spelling group — suggestions and both actions alike — disappear when [misspelledWord] is
/// null: the right-click didn't land on a flagged word, or spell-checking is off altogether
/// (`docs/architecture/screenplay.md`). [misspelledWord] itself gates the whole group
/// rather than each entry gating on its own callback, since a caller offering suggestions/ignore/
/// learn for one word but not another inside the same menu isn't a state this app ever has.
class OcptEditorContextMenu extends StatelessWidget {
  /// The controller opening and closing this menu; owned by the caller, which also decides where it
  /// opens.
  final MenuController controller;

  /// The focus node of [child] (the editor's own), so keyboard focus returns to it once the menu
  /// closes.
  final FocusNode childFocusNode;

  /// The misspelled word the right-click landed on, or null when it didn't land on one (or
  /// spell-checking is off) — the gate for the whole spelling group, see the class doc comment.
  final String? misspelledWord;

  /// Up to five spelling suggestions for [misspelledWord], already capped by the caller; ignored
  /// while [misspelledWord] is null.
  final List<String> suggestions;

  /// Called with the suggestion picked to replace [misspelledWord], or null while [misspelledWord]
  /// is null.
  final ValueChanged<String>? onSuggestionSelected;

  /// Called to ignore [misspelledWord] for the rest of this session, or null while
  /// [misspelledWord] is null.
  final VoidCallback? onIgnoreWord;

  /// Called to add [misspelledWord] to the open project's own dictionary, or null while
  /// [misspelledWord] is null.
  final VoidCallback? onLearnWord;

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
    this.misspelledWord,
    this.suggestions = const [],
    this.onSuggestionSelected,
    this.onIgnoreWord,
    this.onLearnWord,
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
    final onSuggestionSelected = this.onSuggestionSelected;
    final onIgnoreWord = this.onIgnoreWord;
    final onLearnWord = this.onLearnWord;

    // The whole spelling group is gated on `misspelledWord`, per the class doc comment; a
    // suggestion entry additionally needs somewhere to report the pick to, and each action needs
    // its own callback, exactly like every other entry in this menu.
    final suggestionEntries = misspelledWord == null || onSuggestionSelected == null
        ? const <String>[]
        : suggestions.take(5).toList(growable: false);
    final showIgnoreWord = misspelledWord != null && onIgnoreWord != null;
    final showLearnWord = misspelledWord != null && onLearnWord != null;
    final hasSpellingActions = showIgnoreWord || showLearnWord;
    final hasSpellingGroup = suggestionEntries.isNotEmpty || hasSpellingActions;

    return MenuAnchor(
      controller: controller,
      childFocusNode: childFocusNode,
      menuChildren: [
        for (final suggestion in suggestionEntries)
          MenuItemButton(
            onPressed: () => onSuggestionSelected!(suggestion),
            child: Text(suggestion),
          ),
        // Only drawn between the suggestions and the two spelling actions when both halves are
        // actually there — the same "never a rule hanging under or over nothing" guard every other
        // divider in this menu follows.
        if (suggestionEntries.isNotEmpty && hasSpellingActions) const Divider(height: 1),
        if (showIgnoreWord)
          MenuItemButton(
            leadingIcon: const Icon(Icons.block, size: 16),
            onPressed: onIgnoreWord,
            child: Text(tr.editorContextMenuIgnoreWordAction),
          ),
        if (showLearnWord)
          MenuItemButton(
            leadingIcon: const Icon(Icons.library_add, size: 16),
            onPressed: onLearnWord,
            child: Text(tr.editorContextMenuAddToDictionaryAction),
          ),
        // Separates the spelling group from the clipboard/block-type half below, only drawn when
        // both halves are actually there.
        if (hasSpellingGroup &&
            (onCut != null ||
                onCopy != null ||
                onPaste != null ||
                onSelectAll != null ||
                (onTypeSelected != null && currentType != null)))
          const Divider(height: 1),
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
