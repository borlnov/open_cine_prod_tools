// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The 11 assignable [FountainLineType]s (every value except [FountainLineType.blank], which has
/// no manual-choice meaning), in the order [OcptEditorBlockTypeDropdown] lists them: the 6
/// Tab-cycle types in their cycle order first, then the remaining 5.
const List<FountainLineType> _ocptDropdownTypes = [
  FountainLineType.sceneHeading,
  FountainLineType.action,
  FountainLineType.character,
  FountainLineType.parenthetical,
  FountainLineType.dialogue,
  FountainLineType.transition,
  FountainLineType.centeredText,
  FountainLineType.lyrics,
  FountainLineType.section,
  FountainLineType.synopsis,
  FountainLineType.pageBreak,
];

/// The compact block-type dropdown of the editor toolbar: shows the caret's current
/// [FountainLineType] and lets the user pick any of the 11 assignable types manually (the same
/// "manual override" gesture as the Tab cycle).
///
/// Wrapped in `Focus(canRequestFocus: false)` so opening or choosing an item never steals keyboard
/// focus away from the styled editor; the actual refocus-after-apply happens in the styled
/// editor's own state once the change is applied.
class OcptEditorBlockTypeDropdown extends StatelessWidget {
  /// The block type currently shown as selected (the caret's block type).
  final FountainLineType currentType;

  /// Called with the newly picked block type when the user selects a different item.
  final ValueChanged<FountainLineType> onTypeSelected;

  /// Class constructor
  const OcptEditorBlockTypeDropdown({super.key, required this.currentType, required this.onTypeSelected});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Focus(
      canRequestFocus: false,
      child: Tooltip(
        message: tr.editorBlockTypeDropdownTooltip,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<FountainLineType>(
            value: currentType,
            isDense: true,
            mouseCursor: ocptClickableCursor,
            style: Theme.of(context).textTheme.labelSmall,
            items: [
              for (final type in _ocptDropdownTypes)
                DropdownMenuItem(value: type, child: Text(_labelOf(tr, type))),
            ],
            onChanged: (type) {
              if (type != null) {
                onTypeSelected(type);
              }
            },
          ),
        ),
      ),
    );
  }

  /// The localized label of [type], read from [tr].
  String _labelOf(Tr tr, FountainLineType type) => switch (type) {
    FountainLineType.sceneHeading => tr.editorBlockTypeSceneHeading,
    FountainLineType.action => tr.editorBlockTypeAction,
    FountainLineType.character => tr.editorBlockTypeCharacter,
    FountainLineType.parenthetical => tr.editorBlockTypeParenthetical,
    FountainLineType.dialogue => tr.editorBlockTypeDialogue,
    FountainLineType.transition => tr.editorBlockTypeTransition,
    FountainLineType.centeredText => tr.editorBlockTypeCenteredText,
    FountainLineType.lyrics => tr.editorBlockTypeLyrics,
    FountainLineType.section => tr.editorBlockTypeSection,
    FountainLineType.synopsis => tr.editorBlockTypeSynopsis,
    FountainLineType.pageBreak => tr.editorBlockTypePageBreak,
    FountainLineType.blank => "",
  };
}
