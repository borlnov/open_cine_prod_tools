// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:super_editor/super_editor.dart';

/// [EditCommand] applying an [OcptReplaceNodeTextRequest]: replaces the target `ParagraphNode` with
/// a copy carrying the new text (metadata untouched), via `ParagraphNode.copyTextNodeWith`,
/// mirroring [OcptChangeNodeMetadataCommand]'s own pattern.
class OcptReplaceNodeTextCommand extends EditCommand {
  /// Creates an [OcptReplaceNodeTextCommand].
  const OcptReplaceNodeTextCommand({required this.nodeId, required this.text});

  /// The id of the `ParagraphNode` whose text is being replaced.
  final String nodeId;

  /// The new text for the node.
  final AttributedText text;

  /// This command's undo/redo behavior: grouped with other undoable edits, matching
  /// [OcptChangeNodeMetadataCommand].
  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  /// Applies the text replacement to the document.
  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final existingNode = document.getNodeById(nodeId)! as ParagraphNode;
    document.replaceNodeById(existingNode.id, existingNode.copyTextNodeWith(text: text));

    executor.logChanges([DocumentEdit(NodeChangeEvent(nodeId))]);
  }
}

/// The [EditRequestHandler] for [OcptReplaceNodeTextRequest], appended to the styled editor's
/// `Editor.requestHandlers` list wherever its `Editor` is constructed (see
/// `_OcptStyledScreenplayEditorState._rebuildEditorFrom`).
EditCommand? ocptReplaceNodeTextRequestHandler(Editor editor, EditRequest request) =>
    request is OcptReplaceNodeTextRequest
    ? OcptReplaceNodeTextCommand(nodeId: request.nodeId, text: request.text)
    : null;
