// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_edit_requests.dart';
import 'package:super_editor/super_editor.dart';

/// The 6 common [FountainLineType]s cycled by [ocptTabToCycleBlockType], in cycle order (Tab
/// advances, Shift+Tab reverses, wrapping at both ends).
const List<FountainLineType> _ocptTabCycleTypes = [
  FountainLineType.sceneHeading,
  FountainLineType.action,
  FountainLineType.character,
  FountainLineType.parenthetical,
  FountainLineType.dialogue,
  FountainLineType.transition,
];

/// The `keyboardActions` list for the styled screenplay editor's `SuperEditor`: this app's own
/// Tab-cycle, smart-Enter and Ctrl+U handlers first (each halts, so none of the corresponding
/// default behaviors ever run), then every [defaultImeKeyboardActions] entry except the ones that
/// would fight this editor's model (see [_ocptExcludedDefaultActions]).
///
/// Ctrl+B/I are deliberately left to the inherited `cmdBToToggleBold`/`cmdIToToggleItalics`
/// defaults (still present below): they already toggle the right attribution, whether the
/// selection is collapsed (via `ComposerPreferences`, applied to the next typed character) or
/// expanded. Ctrl+S / Ctrl+Shift+M match none of these actions, so both bubble up, unhandled, to
/// the page-level `Shortcuts` in `editor_page.dart`, exactly as before this file existed.
final List<SuperEditorKeyboardAction> ocptFountainKeyboardActions = [
  ocptTabToCycleBlockType,
  ocptEnterToSmartSplit,
  ocptCmdUToToggleUnderline,
  ...defaultImeKeyboardActions.where((action) => !_ocptExcludedDefaultActions.contains(action)),
];

/// The [defaultImeKeyboardActions] entries excluded from [ocptFountainKeyboardActions]:
///
/// - `tabToIndentParagraph`/`shiftTabToUnIndentParagraph`,
///   `tabToIndentTask`/`shiftTabToUnIndentTask`: Tab/Shift+Tab is this editor's block-type cycle,
///   never paragraph/task indentation (this model has no indentation concept at all).
/// - `enterToUnIndentParagraph`: pointless once Tab never indents a paragraph.
/// - `backspaceToClearParagraphBlockType`: would silently strip this editor's `blockType`
///   metadata back to a plain paragraph; auto-detection/[OcptWysiwygCodec.reclassifyRequests]
///   already owns that decision.
/// - `shiftEnterToInsertNewlineInBlock`: would insert a literal `\n` inside a node's text, breaking
///   the one-node-per-source-line invariant; [ocptEnterToSmartSplit] handles Shift+Enter itself.
final Set<SuperEditorKeyboardAction> _ocptExcludedDefaultActions = {
  tabToIndentParagraph,
  shiftTabToUnIndentParagraph,
  tabToIndentTask,
  shiftTabToUnIndentTask,
  enterToUnIndentParagraph,
  backspaceToClearParagraphBlockType,
  shiftEnterToInsertNewlineInBlock,
};

/// Tab/Shift+Tab: cycles the current block's stored `blockType` through
/// [_ocptTabCycleTypes] (Tab forward, Shift+Tab backward, wrapping at both ends), or, when the
/// current type isn't one of the six, enters the cycle at [FountainLineType.sceneHeading] (Tab) or
/// [FountainLineType.transition] (Shift+Tab). Always locks the block (see
/// [ocptTypeLockedMetadataKey]) and clears any forcing-marker flag, since this is a manual type
/// choice.
///
/// This is the hardware-`KeyEvent` path: it only ever fires for Shift+Tab and any hardware-sourced
/// plain Tab. On desktop, `SuperEditor` runs on [TextInputSource.ime], and a *plain* Tab is
/// normally committed by the platform IME as a text-insertion delta before Flutter ever
/// synthesizes a hardware event for it — that case is intercepted separately, at the IME boundary,
/// by `OcptFountainTabInterceptor` (`ocpt_fountain_ime_overrides.dart`), which calls
/// [ocptCycleBlockTypeAtSelection] directly (always forward, since Shift+Tab never travels through
/// the IME delta channel).
ExecutionInstruction ocptTabToCycleBlockType({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }
  if (keyEvent.logicalKey != LogicalKeyboardKey.tab) {
    return ExecutionInstruction.continueExecution;
  }

  final handled = ocptCycleBlockTypeAtSelection(
    editor: editContext.editor,
    document: editContext.document,
    composer: editContext.composer,
    reversed: HardwareKeyboard.instance.isShiftPressed,
  );

  return handled ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

/// The manual block-type cycle itself: resolves the node at [composer]'s selection extent, moves
/// its stored `blockType` one step through [_ocptTabCycleTypes] ([reversed] or not, wrapping at
/// both ends, entering at [FountainLineType.sceneHeading]/[FountainLineType.transition] from
/// outside the cycle), and executes the change through [editor] via [ocptManualBlockTypeRequests]
/// (locking the block and clearing any forcing-marker flag, since this is always a manual type
/// choice). Returns whether it actually applied a change — false when there's no selection, or the
/// selected node isn't a [ParagraphNode].
///
/// Shared by [ocptTabToCycleBlockType] (the hardware-`KeyEvent` path) and
/// `OcptFountainTabInterceptor` (the IME-delta path a plain Tab actually travels through on
/// desktop): both are the exact same gesture, so neither may duplicate the cycle logic.
bool ocptCycleBlockTypeAtSelection({
  required Editor editor,
  required Document document,
  required DocumentComposer composer,
  required bool reversed,
}) {
  final selection = composer.selection;
  if (selection == null) {
    return false;
  }

  final node = document.getNodeById(selection.extent.nodeId);
  if (node is! ParagraphNode) {
    return false;
  }

  final currentType = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
  final nextType = _ocptCycleType(currentType, reversed: reversed);

  editor.execute(ocptManualBlockTypeRequests(nodeId: node.id, type: nextType));
  return true;
}

/// The two-request sequence a manual block-type change always applies: the
/// `ChangeParagraphBlockTypeRequest` itself, plus locking the block ([ocptTypeLockedMetadataKey])
/// and clearing any forcing-marker flag ([ocptHadForcingMarkerMetadataKey]), since a manual choice
/// always overrides whatever forcing marker the line used to have.
///
/// Shared by [ocptTabToCycleBlockType] and the toolbar's block-type dropdown
/// (`OcptStyledEditorControllerDelegate.applyBlockType`): both are the same "manual override"
/// gesture (Goal 2 of the plan), so both must produce the exact same requests.
List<EditRequest> ocptManualBlockTypeRequests({required String nodeId, required FountainLineType type}) => [
  ChangeParagraphBlockTypeRequest(nodeId: nodeId, blockType: OcptFountainLineAttributions.attributionOf(type)),
  OcptChangeNodeMetadataRequest(
    nodeId: nodeId,
    metadata: {ocptTypeLockedMetadataKey: true, ocptHadForcingMarkerMetadataKey: false},
  ),
];

/// The next (or, when [reversed], previous) type in [_ocptTabCycleTypes] after [current], wrapping
/// at both ends; entry from a type outside the cycle goes to [FountainLineType.sceneHeading]
/// (forward) or [FountainLineType.transition] (reversed).
FountainLineType _ocptCycleType(FountainLineType current, {required bool reversed}) {
  final index = _ocptTabCycleTypes.indexOf(current);
  if (index == -1) {
    return reversed ? FountainLineType.transition : FountainLineType.sceneHeading;
  }

  final cycleLength = _ocptTabCycleTypes.length;
  final nextIndex = (index + (reversed ? -1 : 1) + cycleLength) % cycleLength;
  return _ocptTabCycleTypes[nextIndex];
}

/// Enter/numpad Enter and Shift+Enter: splits the current block at the caret into two nodes
/// (`SplitParagraphRequest(replicateExistingMetadata: false)`, so the new node starts with no
/// metadata of its own), places the caret at the start of the new node, then classifies it:
///
/// - **Enter** ("smart Enter"): the new node's type follows [_ocptSmartEnterNextType] (the
///   current type's usual successor in a screenplay), unlocked (auto-detection must keep working
///   on it) and with `blankLinesBefore` 0 for a dialogue/parenthetical continuation, 1 otherwise
///   (matching the blank line Fountain needs to auto-detect most other types).
/// - **Shift+Enter**: the new node keeps the SAME type as the block it was split from, with
///   `blankLinesBefore: 0` (a same-block continuation line, e.g. a second action paragraph
///   without a scene break).
///
/// Both cases clear any forcing-marker flag on the new node: it was never decoded from source
/// text, so it never "had" one.
ExecutionInstruction ocptEnterToSmartSplit({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return ExecutionInstruction.continueExecution;
  }

  final selection = editContext.composer.selection;
  if (selection == null || !selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(selection.extent.nodeId);
  final splitPosition = selection.extent.nodePosition;
  if (node is! ParagraphNode || splitPosition is! TextNodePosition) {
    return ExecutionInstruction.continueExecution;
  }

  final currentType = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
  final isShiftEnter = HardwareKeyboard.instance.isShiftPressed;
  final newType = isShiftEnter ? currentType : _ocptSmartEnterNextType(currentType);
  final blankLinesBefore = isShiftEnter || _ocptIsDialogueGroupMember(newType) ? 0 : 1;

  final newNodeId = Editor.createNodeId();
  editContext.editor.execute([
    SplitParagraphRequest(
      nodeId: node.id,
      splitPosition: splitPosition,
      newNodeId: newNodeId,
      replicateExistingMetadata: false,
    ),
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: newNodeId, nodePosition: const TextNodePosition(offset: 0)),
      ),
      SelectionChangeType.insertContent,
      SelectionReason.userInteraction,
    ),
    ChangeParagraphBlockTypeRequest(nodeId: newNodeId, blockType: OcptFountainLineAttributions.attributionOf(newType)),
    OcptChangeNodeMetadataRequest(
      nodeId: newNodeId,
      metadata: {
        ocptBlankLinesBeforeMetadataKey: blankLinesBefore,
        ocptTypeLockedMetadataKey: false,
        ocptHadForcingMarkerMetadataKey: false,
      },
    ),
  ]);

  return ExecutionInstruction.haltExecution;
}

/// "Smart Enter"'s next-block-type map (Goal 4): every [FountainLineType] not listed here (the
/// non-dialogue-scene types: action, centered text, lyrics, section, synopsis, page break) maps to
/// [FountainLineType.action], the plain default for "just keep writing".
FountainLineType _ocptSmartEnterNextType(FountainLineType current) => switch (current) {
  FountainLineType.sceneHeading => FountainLineType.action,
  FountainLineType.character => FountainLineType.dialogue,
  FountainLineType.parenthetical => FountainLineType.dialogue,
  FountainLineType.dialogue => FountainLineType.action,
  FountainLineType.transition => FountainLineType.sceneHeading,
  _ => FountainLineType.action,
};

/// Whether [type] is a dialogue-block element, mirroring [OcptWysiwygCodec]'s own equivalent
/// private rule: a smart-Enter continuation into one of these types needs no blank line to
/// auto-detect (dialogue/parenthetical are purely contextual).
bool _ocptIsDialogueGroupMember(FountainLineType type) =>
    type == FountainLineType.character || type == FountainLineType.parenthetical || type == FountainLineType.dialogue;

/// Ctrl+U / Cmd+U: toggles [underlineAttribution] on the current selection (or, when collapsed, on
/// the composer's pending style preferences for the next typed character), mirroring the
/// inherited `cmdBToToggleBold`/`cmdIToToggleItalics` defaults exactly, just for underline (which
/// super_editor has no built-in shortcut for).
ExecutionInstruction ocptCmdUToToggleUnderline({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyU) {
    return ExecutionInstruction.continueExecution;
  }

  if (editContext.composer.selection!.isCollapsed) {
    editContext.commonOps.toggleComposerAttributions({underlineAttribution});
  } else {
    editContext.commonOps.toggleAttributionsOnSelection({underlineAttribution});
  }

  return ExecutionInstruction.haltExecution;
}
