// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
import 'package:super_editor/super_editor.dart';

/// [EditCommand] applying an [OcptChangeNodeMetadataRequest]: replaces the target `ParagraphNode`
/// with a copy carrying the merged metadata, via `ParagraphNode.copyWithAddedMetadata`, and logs a
/// `NodeChangeEvent` so the document layout re-renders the node (the same pattern
/// `ChangeParagraphBlockTypeCommand` uses for `blockType` changes).
class OcptChangeNodeMetadataCommand extends EditCommand {
  /// The id of the `ParagraphNode` whose metadata is being updated.
  final String nodeId;

  /// The metadata entries to merge into the node's existing metadata.
  final Map<String, dynamic> metadata;

  /// {@macro open_cine_prod_tools.OcptChangeNodeMetadataRequest.isHistorical}
  final bool isHistorical;

  /// This command's undo/redo behavior: grouped with other undoable edits, matching
  /// `ChangeParagraphBlockTypeCommand`, unless [isHistorical] says this change happened before
  /// the writer could have anything to undo.
  @override
  HistoryBehavior get historyBehavior =>
      isHistorical ? HistoryBehavior.undoable : HistoryBehavior.nonHistorical;

  /// Creates an [OcptChangeNodeMetadataCommand].
  const OcptChangeNodeMetadataCommand({
    required this.nodeId,
    required this.metadata,
    this.isHistorical = true,
  });

  /// Applies the metadata merge to the document.
  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final existingNode = document.getNodeById(nodeId)! as ParagraphNode;
    document.replaceNodeById(existingNode.id, existingNode.copyWithAddedMetadata(metadata));

    executor.logChanges([DocumentEdit(NodeChangeEvent(nodeId))]);
  }
}

/// The [EditRequestHandler] for [OcptChangeNodeMetadataRequest], appended to the styled editor's
/// `Editor.requestHandlers` list wherever its `Editor` is constructed (see
/// `_OcptStyledScreenplayEditorState._rebuildEditorFrom`).
EditCommand? ocptChangeNodeMetadataRequestHandler(Editor editor, EditRequest request) =>
    request is OcptChangeNodeMetadataRequest
    ? OcptChangeNodeMetadataCommand(
        nodeId: request.nodeId,
        metadata: request.metadata,
        isHistorical: request.isHistorical,
      )
    : null;
