// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:super_editor/super_editor.dart';

/// [EditCommand] applying an [OcptReplaceNodeTextRequest]: replaces the target `ParagraphNode` with
/// a copy carrying the new text (metadata untouched), via `ParagraphNode.copyTextNodeWith`,
/// mirroring [OcptChangeNodeMetadataCommand]'s own pattern. A selection end that the shorter text
/// leaves past its end is brought back to it, so a caret is never left outside the text.
class OcptReplaceNodeTextCommand extends EditCommand {
  /// The id of the `ParagraphNode` whose text is being replaced.
  final String nodeId;

  /// The new text for the node.
  final AttributedText text;

  /// Get this command's undo/redo behavior: grouped with other undoable edits, matching
  /// [OcptChangeNodeMetadataCommand].
  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  /// Create an [OcptReplaceNodeTextCommand].
  const OcptReplaceNodeTextCommand({required this.nodeId, required this.text});

  /// Apply the text replacement to the document.
  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final existingNode = document.getNodeById(nodeId)! as ParagraphNode;
    document.replaceNodeById(existingNode.id, existingNode.copyTextNodeWith(text: text));

    executor.logChanges([DocumentEdit(NodeChangeEvent(nodeId))]);

    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    final selection = composer.selection;
    final clamped = selection == null ? null : _clamped(selection);
    if (clamped != null && clamped != selection) {
      executor.executeCommand(
        ChangeSelectionCommand(
          clamped,
          SelectionChangeType.deleteContent,
          SelectionReason.contentChange,
        ),
      );
    }
  }

  /// Get [selection] with its ends in the replaced node brought back inside the new text, so a
  /// shorter text never leaves a caret past its end.
  DocumentSelection _clamped(DocumentSelection selection) => DocumentSelection(
    base: _clampedPosition(selection.base),
    extent: _clampedPosition(selection.extent),
  );

  /// Get [position] brought back inside the new text when it lies in the replaced node.
  DocumentPosition _clampedPosition(DocumentPosition position) {
    final nodePosition = position.nodePosition;
    if (position.nodeId != nodeId || nodePosition is! TextNodePosition) {
      return position;
    }
    final length = text.length;
    return nodePosition.offset <= length
        ? position
        : DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: length),
          );
  }
}

/// Get the [EditRequestHandler] for [OcptReplaceNodeTextRequest], appended to the styled editor's
/// `Editor.requestHandlers` list wherever its `Editor` is constructed (see
/// `_OcptStyledScreenplayEditorState._rebuildEditorFrom`).
EditCommand? ocptReplaceNodeTextRequestHandler(Editor editor, EditRequest request) =>
    request is OcptReplaceNodeTextRequest
    ? OcptReplaceNodeTextCommand(nodeId: request.nodeId, text: request.text)
    : null;
