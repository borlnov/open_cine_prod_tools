// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_clipboard_actions.dart';
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
/// Tab-cycle, smart-Enter, clipboard and Ctrl+U handlers first (each halts, so none of the
/// corresponding default behaviors ever run), then every [defaultImeKeyboardActions] entry except
/// the ones that would fight this editor's model (see [_ocptExcludedDefaultActions]).
///
/// Ctrl+B/I are deliberately left to the inherited `cmdBToToggleBold`/`cmdIToToggleItalics`
/// defaults (still present below): they already toggle the right attribution, whether the
/// selection is collapsed (via `ComposerPreferences`, applied to the next typed character) or
/// expanded. Ctrl+S / Ctrl+Shift+M match none of these actions, so both bubble up, unhandled, to
/// the page-level `Shortcuts` in `editor_page.dart`, exactly as before this file existed.
final List<SuperEditorKeyboardAction> ocptFountainKeyboardActions = [
  ocptTabToCycleBlockType,
  ocptEnterToSmartSplit,
  ocptCopyToFountainClipboard,
  ocptCutToFountainClipboard,
  ocptPasteFromFountainClipboard,
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
/// - `copyWhenCmdCIsPressed`/`cutWhenCmdXIsPressed`/`pasteWhenCmdVIsPressed`: plain-text clipboard
///   actions with no notion of block types; [ocptCopyToFountainClipboard]/
///   [ocptCutToFountainClipboard]/[ocptPasteFromFountainClipboard] replace them.
final Set<SuperEditorKeyboardAction> _ocptExcludedDefaultActions = {
  tabToIndentParagraph,
  shiftTabToUnIndentParagraph,
  tabToIndentTask,
  shiftTabToUnIndentTask,
  enterToUnIndentParagraph,
  backspaceToClearParagraphBlockType,
  shiftEnterToInsertNewlineInBlock,
  copyWhenCmdCIsPressed,
  cutWhenCmdXIsPressed,
  pasteWhenCmdVIsPressed,
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
/// choice), followed by [ocptParentheticalTemplateRequests] (inserts `()` and places the caret
/// between them, but only when the cycle just landed on `parenthetical` and the node's text was
/// still empty). Returns whether it actually applied a change — false when there's no selection, or
/// the selected node isn't a [ParagraphNode].
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
  if (node is! ParagraphNode || OcptWysiwygCodec.isTitlePageNode(node)) {
    return false;
  }

  final currentType = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
  final nextType = _ocptCycleType(currentType, reversed: reversed);

  editor.execute([
    ...ocptManualBlockTypeRequests(nodeId: node.id, type: nextType),
    ...ocptParentheticalTemplateRequests(nodeId: node.id, type: nextType, isNodeEmpty: node.text.isEmpty),
  ]);
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

/// The `()` template a manual switch to [FountainLineType.parenthetical] inserts, but only while
/// the block being switched is genuinely empty ([isNodeEmpty]): returns `const []` for every other
/// [type], and for [FountainLineType.parenthetical] itself when [isNodeEmpty] is false, so this is
/// safe to append unconditionally after the type change itself.
///
/// The empty-text guard matters because [type] is not necessarily a one-time switch onto
/// `parenthetical` — Tab cycles through six types (see [_ocptTabCycleTypes]), so a block can pass
/// through `parenthetical` repeatedly on the way to somewhere else. Without the guard, every one of
/// those passes would insert another `()` pair into text a previous pass (or the user) already
/// filled in, instead of only the first, genuinely-empty one.
///
/// When it does apply, returns, in order: [OcptReplaceNodeTextRequest] inserting `"()"` as the
/// node's whole text, then a `ChangeSelectionRequest` collapsing the caret between the two
/// parentheses (`TextNodePosition(offset: 1)`). `()` is exactly what an empty parenthetical's
/// Fountain source already looks like, so this needs no support from [OcptWysiwygCodec] on either
/// side of the round trip.
///
/// Shared by every gesture that sets a block's type — [ocptCycleBlockTypeAtSelection]
/// (Tab/Shift+Tab, and therefore `OcptFountainTabInterceptor`'s IME-delta plain-Tab path),
/// [ocptEnterToSmartSplit] (the node an Enter split creates, see its own call site for why that one
/// can't reach `parenthetical` today), and the toolbar dropdown's
/// `_OcptStyledScreenplayEditorState.applyBlockType` — each appends this helper's requests to the
/// end of the request list it already executes, after the type change itself, so all three behave
/// identically instead of three separate, inevitably-drifting copies of this guard.
List<EditRequest> ocptParentheticalTemplateRequests({
  required String nodeId,
  required FountainLineType type,
  required bool isNodeEmpty,
}) {
  if (type != FountainLineType.parenthetical || !isNodeEmpty) {
    return const [];
  }

  return [
    OcptReplaceNodeTextRequest(nodeId: nodeId, text: AttributedText("()")),
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: nodeId, nodePosition: const TextNodePosition(offset: 1)),
      ),
      SelectionChangeType.insertContent,
      SelectionReason.userInteraction,
    ),
  ];
}

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
/// - **Enter** ("smart Enter"), when the caret sat at the very end of the block's text (so the
///   new node starts genuinely empty): the new node's type follows [_ocptSmartEnterNextType] (the
///   current type's usual successor in a screenplay), unlocked (auto-detection must keep working
///   on it) and with `blankLinesBefore` 0 for a dialogue/parenthetical continuation, 1 otherwise
///   (matching the blank line Fountain needs to auto-detect most other types).
/// - **Shift+Enter, or Enter anywhere before the end of the text**: the new node keeps the SAME
///   type as the block it was split from, with `blankLinesBefore: 0` for Shift+Enter (a same-block
///   continuation line, e.g. a second action paragraph without a scene break) or `1` otherwise. A
///   non-end Enter split carries the block's own trailing text into the new node — still a
///   continuation of that same original line, not the start of a fresh one — so it is deliberately
///   left to the very next (debounced) reclassify pass (`OcptWysiwygCodec.reclassifyRequests`) to
///   settle on whatever type that trailing text, on its own, actually auto-detects as: forcing the
///   smart successor on it here instead would risk momentarily storing text under a type it does
///   not auto-detect as (e.g. a scene heading's `INT./EXT.` prefix staying behind in the original
///   node leaves a tail with no such prefix), which `FountainLineWriter` can only resolve by
///   forcing a marker onto it (`!` for `action`) on encode — and, worse, would desynchronize scene
///   numbering for every heading after it, however briefly, were that momentary state ever read
///   before the reclassify pass corrects it.
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

  if (OcptWysiwygCodec.isTitlePageNode(node)) {
    return _splitTitlePageField(editContext: editContext, node: node, splitPosition: splitPosition);
  }

  final currentType = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
  final isShiftEnter = HardwareKeyboard.instance.isShiftPressed;
  final splitsAtEnd = splitPosition.offset == node.text.toPlainText().length;
  final newType = isShiftEnter || !splitsAtEnd ? currentType : _ocptSmartEnterNextType(currentType);
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
    // `_ocptSmartEnterNextType` maps nothing to `parenthetical` today, so `splitsAtEnd` alone can
    // never actually make `newType` land on it — this call is currently inert. It stays here (with
    // `isNodeEmpty: splitsAtEnd`, never true for a mid-text split, which carries the tail text into
    // the new node and must never be prefixed with `()`) so the three gestures that can set a
    // block's type can never drift apart if that map ever changes to add such a mapping later. Do
    // not "simplify" this away, and do not change `_ocptSmartEnterNextType` to fill that gap here.
    ...ocptParentheticalTemplateRequests(nodeId: newNodeId, type: newType, isNodeEmpty: splitsAtEnd),
  ]);

  return ExecutionInstruction.haltExecution;
}

/// Enter inside a title-page field node ([OcptWysiwygCodec.isTitlePageNode]): splits it at the
/// caret exactly like [ocptEnterToSmartSplit] would, but the new node always keeps the *same*
/// [ocptTitlePageKeyMetadataKey] as the node it split from — a title-page field has no "usual
/// screenplay successor" the way a Fountain line type does, so this is how a multi-line field
/// (`Author`, `Contact`…) gets an extra line, the same gesture Shift+Enter is for a same-type body
/// continuation.
ExecutionInstruction _splitTitlePageField({
  required SuperEditorContext editContext,
  required ParagraphNode node,
  required TextNodePosition splitPosition,
}) {
  final key = node.getMetadataValue(ocptTitlePageKeyMetadataKey);
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
    ChangeParagraphBlockTypeRequest(nodeId: newNodeId, blockType: ocptTitlePageFieldAttribution),
    OcptChangeNodeMetadataRequest(nodeId: newNodeId, metadata: {ocptTitlePageKeyMetadataKey: key}),
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
