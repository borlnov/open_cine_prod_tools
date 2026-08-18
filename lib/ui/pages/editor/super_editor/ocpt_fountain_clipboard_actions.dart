// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_edit_requests.dart';
import 'package:super_editor/super_editor.dart';

/// Ctrl+C / Cmd+C: copies the current selection to the system clipboard as plain Fountain source
/// text (through [OcptWysiwygCodec.encodeSelectionToFountain]) instead of super_editor's default
/// `copyWhenCmdCIsPressed`, which serializes to plain text with no notion of block types at all.
/// Mirrors that default's own shape exactly (including "a collapsed selection has nothing to
/// copy, but the keystroke is still handled").
///
/// The clipboard payload staying **plain Fountain text**, rather than a private clipboard format,
/// is deliberate: pasting into another editor (or back into this one after a mode switch) yields
/// valid Fountain, and text copied from outside the app keeps decoding through the normal
/// Fountain auto-detection path on paste. The formatting survives the round trip because both
/// ends go through [OcptWysiwygCodec], not because of anything clipboard-format-specific.
ExecutionInstruction ocptCopyToFountainClipboard({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyC) {
    return ExecutionInstruction.continueExecution;
  }

  final selection = editContext.composer.selection;
  if (selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (selection.isCollapsed) {
    return ExecutionInstruction.haltExecution;
  }

  ocptCopySelectionToClipboard(document: editContext.document, selection: selection);
  return ExecutionInstruction.haltExecution;
}

/// Ctrl+X / Cmd+X: the same Fountain-aware copy as [ocptCopyToFountainClipboard], followed by
/// deleting the selection, replacing super_editor's default `cutWhenCmdXIsPressed` for the same
/// reason.
ExecutionInstruction ocptCutToFountainClipboard({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyX) {
    return ExecutionInstruction.continueExecution;
  }

  final selection = editContext.composer.selection;
  if (selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (selection.isCollapsed) {
    return ExecutionInstruction.haltExecution;
  }

  ocptCopySelectionToClipboard(document: editContext.document, selection: selection);
  editContext.editor.execute(const [DeleteSelectionRequest(TextAffinity.downstream)]);
  return ExecutionInstruction.haltExecution;
}

/// Ctrl+V / Cmd+V: replaces super_editor's default `pasteWhenCmdVIsPressed` (plain-text paste,
/// no block types) with [ocptPasteFountainClipboardContent].
///
/// **Why this doesn't need an IME-delta interceptor.** `OcptFountainTabInterceptor` exists
/// because a *plain* Tab (an insertable character, U+0009) is committed by the platform's text
/// input framework as a text-editing delta before Flutter ever synthesizes a hardware `KeyEvent`
/// for it. A Ctrl+V chord is not an insertable character at all — every desktop text-input
/// framework (this app targets Linux/Windows first) treats a modifier-plus-letter combination as
/// an editing shortcut delivered through the ordinary hardware key-event channel, never as a
/// commit-string delta, which is exactly why super_editor's own `copyWhenCmdCIsPressed`/
/// `cutWhenCmdXIsPressed`/`pasteWhenCmdVIsPressed` — and this editor's own pre-existing
/// `cmdBToToggleBold`/`cmdIToToggleItalics`/`ocptCmdUToToggleUnderline` — are themselves plain
/// hardware-`KeyEvent` handlers with no IME involvement. No interception is added here.
ExecutionInstruction ocptPasteFromFountainClipboard({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }
  if (!keyEvent.isPrimaryShortcutKeyPressed || keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  unawaited(
    ocptPasteFountainClipboardContent(
      editor: editContext.editor,
      document: editContext.document,
      composer: editContext.composer,
    ),
  );
  return ExecutionInstruction.haltExecution;
}

/// Copies the Fountain source text of [selection] (via
/// [OcptWysiwygCodec.encodeSelectionToFountain]) to the system clipboard as plain text, shared by
/// the Ctrl+C/Ctrl+X key handlers ([ocptCopyToFountainClipboard], [ocptCutToFountainClipboard]) and
/// the styled editor's right-click context menu's Cut/Copy entries — one clipboard path however the
/// gesture is made.
void ocptCopySelectionToClipboard({required Document document, required DocumentSelection selection}) {
  final fountainText = OcptWysiwygCodec.encodeSelectionToFountain(document, selection);
  unawaited(Clipboard.setData(ClipboardData(text: fountainText)));
}

/// The paste logic behind [ocptPasteFromFountainClipboard], factored out as a standalone function
/// (rather than inlined in the keyboard action) so it can be reused verbatim by any other gesture
/// that ends up needing the same "paste Fountain text at the caret" behavior.
///
/// Reads the clipboard as plain text, decodes it into nodes through
/// [OcptWysiwygCodec.decodeNodesFromFountain] (so a fragment copied from this editor keeps its
/// block types, and plain text from outside the app still goes through normal Fountain
/// auto-detection), deletes an expanded selection first, then either:
///
/// - inserts the fragment's [AttributedText] straight into the caret's node, when the fragment
///   decoded to a single node — pasting a few words inside a dialogue line must not split it into
///   a separate block, so the caret's own node always keeps its own type in this case; or
/// - splits the caret's node into a "before" and "after" half at the caret. If the caret's node
///   has no text at all (a fresh blank line — the common "paste elsewhere" case), there is
///   nothing of its own worth keeping, so the fragment's first node fully takes over: the
///   caret's node keeps its id, but adopts the fragment's decoded type and text. Otherwise the
///   fragment's first node's text is appended onto the "before" half in place, keeping the
///   caret's own node — and its own type — untouched. Either way, every other fragment node is
///   then inserted as its own new node with its own decoded type, and a final new node combines
///   the fragment's last node's text with the "after" half, under *that* node's own decoded type.
///
/// Either way the caret ends up collapsed at the end of the pasted content, right before whatever
/// text used to follow the original caret position.
Future<void> ocptPasteFountainClipboardContent({
  required Editor editor,
  required Document document,
  required DocumentComposer composer,
}) async {
  final clipboardText = (await Clipboard.getData('text/plain'))?.text;
  if (clipboardText == null || clipboardText.isEmpty) {
    return;
  }

  final fragmentNodes = OcptWysiwygCodec.decodeNodesFromFountain(clipboardText);
  if (fragmentNodes.isEmpty) {
    return;
  }

  editor.startTransaction();

  var pasteSelection = composer.selection;
  if (pasteSelection == null) {
    editor.endTransaction();
    return;
  }

  if (!pasteSelection.isCollapsed) {
    editor.execute(const [DeleteSelectionRequest(TextAffinity.downstream)]);
    pasteSelection = composer.selection;
  }
  if (pasteSelection == null) {
    editor.endTransaction();
    return;
  }

  final targetNode = document.getNodeById(pasteSelection.extent.nodeId);
  final targetPosition = pasteSelection.extent.nodePosition;
  if (targetNode is! ParagraphNode || targetPosition is! TextNodePosition) {
    editor.endTransaction();
    return;
  }

  editor.execute(
    fragmentNodes.length == 1
        ? _singleNodePasteRequests(targetNode: targetNode, offset: targetPosition.offset, fragment: fragmentNodes.single)
        : _multiNodePasteRequests(targetNode: targetNode, offset: targetPosition.offset, fragmentNodes: fragmentNodes),
  );

  editor.endTransaction();
}

/// The requests pasting a single-node [fragment] at [offset] of [targetNode] applies: the
/// fragment's text is inserted in place, so [targetNode] keeps its own type — matching how typing
/// a few characters never changes the block's classification either.
List<EditRequest> _singleNodePasteRequests({
  required ParagraphNode targetNode,
  required int offset,
  required ParagraphNode fragment,
}) {
  final insertedLength = fragment.text.toPlainText().length;
  return [
    InsertAttributedTextRequest(
      DocumentPosition(nodeId: targetNode.id, nodePosition: TextNodePosition(offset: offset)),
      fragment.text,
    ),
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: targetNode.id, nodePosition: TextNodePosition(offset: offset + insertedLength)),
      ),
      SelectionChangeType.insertContent,
      SelectionReason.userInteraction,
    ),
  ];
}

/// The requests pasting a multi-node [fragmentNodes] at [offset] of [targetNode] applies: splits
/// [targetNode]'s text into a "before" and "after" half at [offset]. When [targetNode] has text of
/// its own, `fragmentNodes.first`'s text is appended onto the "before" half in place, keeping
/// [targetNode]'s id and every metadata entry — including its own type — untouched (see
/// [ocptPasteFountainClipboardContent]'s doc comment); when [targetNode] is empty, it instead
/// adopts `fragmentNodes.first`'s own decoded type, forcing-marker flag and text outright, unlocked
/// (nothing of the target's own was worth keeping, and a fresh blank line is the common "paste
/// elsewhere" target — this is what makes the *first* pasted block's type survive that case, not
/// just the ones after it). Every node strictly between the fragment's first and last is then
/// inserted as its own new node with its own decoded type, and a final new node combines
/// `fragmentNodes.last`'s text with the "after" half, under `fragmentNodes.last`'s own decoded type
/// and metadata. The caret ends up collapsed right after the pasted content, at the boundary with
/// the "after" half.
List<EditRequest> _multiNodePasteRequests({
  required ParagraphNode targetNode,
  required int offset,
  required List<ParagraphNode> fragmentNodes,
}) {
  final beforeText = targetNode.text.copyText(0, offset);
  final afterText = targetNode.text.copyText(offset);
  final firstFragment = fragmentNodes.first;

  final requests = <EditRequest>[
    if (targetNode.text.isEmpty) ...[
      ChangeParagraphBlockTypeRequest(nodeId: targetNode.id, blockType: firstFragment.getMetadataValue("blockType") as NamedAttribution),
      OcptChangeNodeMetadataRequest(
        nodeId: targetNode.id,
        metadata: {
          ocptTypeLockedMetadataKey: false,
          ocptHadForcingMarkerMetadataKey: firstFragment.getMetadataValue(ocptHadForcingMarkerMetadataKey) == true,
        },
      ),
      OcptReplaceNodeTextRequest(nodeId: targetNode.id, text: firstFragment.text),
    ] else
      OcptReplaceNodeTextRequest(nodeId: targetNode.id, text: beforeText.copyAndAppend(firstFragment.text)),
  ];

  var insertAfterNodeId = targetNode.id;
  for (var index = 1; index < fragmentNodes.length - 1; index++) {
    final middleNode = fragmentNodes[index];
    requests.add(InsertNodeAfterNodeRequest(existingNodeId: insertAfterNodeId, newNode: middleNode));
    insertAfterNodeId = middleNode.id;
  }

  final lastFragment = fragmentNodes.last;
  final pastedLastLength = lastFragment.text.toPlainText().length;
  final mergedLastNode = lastFragment.copyParagraphWith(text: lastFragment.text.copyAndAppend(afterText));
  requests.add(InsertNodeAfterNodeRequest(existingNodeId: insertAfterNodeId, newNode: mergedLastNode));

  requests.add(
    ChangeSelectionRequest(
      DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: mergedLastNode.id, nodePosition: TextNodePosition(offset: pastedLastLength)),
      ),
      SelectionChangeType.insertContent,
      SelectionReason.userInteraction,
    ),
  );

  return requests;
}
