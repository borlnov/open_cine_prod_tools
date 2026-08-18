// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The 11 assignable [FountainLineType]s (every value except [FountainLineType.blank], which has
/// no manual-choice meaning), in the order both the styled editor toolbar's block-type dropdown
/// (`OcptEditorBlockTypeDropdown`) and the styled editor's right-click context menu
/// (`OcptEditorContextMenu`) list them: the 6 Tab-cycle types in their cycle order first, then the
/// remaining 5.
const List<FountainLineType> ocptAssignableFountainLineTypes = [
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

/// The localized label of the Fountain line type [type], read from [tr].
///
/// Shared by the screenplay editor's block-type dropdown (`OcptEditorBlockTypeDropdown`, which
/// never offers [FountainLineType.blank] as a manual choice) and the shot list's scenario coverage
/// editor (`OcptShotCoverageEditor`, whose blocks are always non-blank source lines by
/// construction — a blank line contributes no `OcptScriptWordBlock` of its own, see that class's
/// doc comment), so the two could never end up labelling the same type differently.
///
/// [FountainLineType.blank] is nonetheless given its own explicit (empty) branch rather than a
/// `default`/wildcard arm: neither call site can ever reach it with that value, and a future
/// addition to [FountainLineType] should fail to compile here rather than silently falling back to
/// blank's placeholder.
String ocptFountainLineTypeLabel(Tr tr, FountainLineType type) => switch (type) {
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
