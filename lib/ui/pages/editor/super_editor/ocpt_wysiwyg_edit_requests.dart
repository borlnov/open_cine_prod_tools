// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

/// [EditRequest] to merge [metadata] into the app-specific metadata (`ocptBlankLinesBefore`,
/// `ocptTypeLocked`, `ocptHadForcingMarker`, `ocptSceneNumber`) of the `ParagraphNode` identified
/// by [nodeId], without touching its `blockType` (already covered by super_editor's own
/// `ChangeParagraphBlockTypeRequest`).
///
/// Modeled directly on super_editor's own `ChangeParagraphBlockTypeRequest`/
/// `ChangeParagraphBlockTypeCommand` pair (`package:super_editor/src/default_editor/paragraph.dart`):
/// this class is deliberately generic (it doesn't know the app's specific metadata key names) so it
/// can carry any of them, alone or together, in a single request.
@immutable
class OcptChangeNodeMetadataRequest implements EditRequest {
  /// Creates an [OcptChangeNodeMetadataRequest].
  const OcptChangeNodeMetadataRequest({required this.nodeId, required this.metadata, this.isHistorical = true});

  /// The id of the `ParagraphNode` whose metadata is being updated.
  final String nodeId;

  /// The metadata entries to merge into the node's existing metadata (added or overwritten; every
  /// other existing entry, including `blockType`, is left untouched).
  final Map<String, dynamic> metadata;

  /// {@template open_cine_prod_tools.OcptChangeNodeMetadataRequest.isHistorical}
  /// Whether this change may become (part of) an undo step.
  ///
  /// True for every change a gesture of the writer's caused, directly or through the passes the
  /// editor derives from it. False only for a change made *before the writer has touched
  /// anything* — the scene-number normalization that runs the moment a screenplay is decoded (see
  /// `sceneNumberNormalizationRequests`) — which would otherwise be the first thing Ctrl+Z popped
  /// on a freshly opened screenplay, un-correcting a numbering the writer never asked to change.
  /// `Editor` offers no way to clear history and its `isHistoryEnabled` is final, so the
  /// command's own `historyBehavior` is the only lever there is.
  /// {@endtemplate}
  final bool isHistorical;

  /// Object equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcptChangeNodeMetadataRequest &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          isHistorical == other.isHistorical &&
          _mapsEqual(metadata, other.metadata);

  /// Object hash code
  @override
  int get hashCode =>
      nodeId.hashCode ^
      isHistorical.hashCode ^
      Object.hashAllUnordered(metadata.entries.map((e) => Object.hash(e.key, e.value)));

  /// Whether [a] and [b] hold the same keys mapped to the same values (order-independent).
  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

/// [EditCommand] applying an [OcptChangeNodeMetadataRequest]: replaces the target `ParagraphNode`
/// with a copy carrying the merged metadata, via `ParagraphNode.copyWithAddedMetadata`, and logs a
/// `NodeChangeEvent` so the document layout re-renders the node (the same pattern
/// `ChangeParagraphBlockTypeCommand` uses for `blockType` changes).
class OcptChangeNodeMetadataCommand extends EditCommand {
  /// Creates an [OcptChangeNodeMetadataCommand].
  const OcptChangeNodeMetadataCommand({required this.nodeId, required this.metadata, this.isHistorical = true});

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
  HistoryBehavior get historyBehavior => isHistorical ? HistoryBehavior.undoable : HistoryBehavior.nonHistorical;

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

/// [EditRequest] to replace the entire text of the `ParagraphNode` identified by [nodeId] with
/// [text], leaving its metadata untouched — used by `OcptWysiwygCodec.uppercaseRequests` to rewrite
/// a node's text in place (its length-preserving 1:1 uppercase conversion keeps the composer's
/// current selection offsets valid without a separate `ChangeSelectionRequest`).
@immutable
class OcptReplaceNodeTextRequest implements EditRequest {
  /// Creates an [OcptReplaceNodeTextRequest].
  const OcptReplaceNodeTextRequest({required this.nodeId, required this.text});

  /// The id of the `ParagraphNode` whose text is being replaced.
  final String nodeId;

  /// The new text for the node.
  final AttributedText text;

  /// Object equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcptReplaceNodeTextRequest && runtimeType == other.runtimeType && nodeId == other.nodeId && text == other.text;

  /// Object hash code
  @override
  int get hashCode => nodeId.hashCode ^ text.hashCode;
}

/// [EditCommand] applying an [OcptReplaceNodeTextRequest]: replaces the target `ParagraphNode` with
/// a copy carrying the new text (metadata untouched), via `ParagraphNode.copyTextNodeWith`, mirroring
/// [OcptChangeNodeMetadataCommand]'s own pattern.
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
