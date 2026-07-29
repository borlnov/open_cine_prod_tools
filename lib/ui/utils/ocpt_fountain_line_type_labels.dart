// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The localized label of the Fountain line type [type], read from [tr].
///
/// Shared by the screenplay editor's block-type dropdown (`OcptEditorBlockTypeDropdown`, which
/// never offers [FountainLineType.blank] as a manual choice) and the shot list's scenario coverage
/// editor (`OcptShotCoverageEditor`, whose blocks are always non-blank source lines by
/// construction — a blank line contributes no `OcptShotCoverageBlock` of its own, see that class's
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
