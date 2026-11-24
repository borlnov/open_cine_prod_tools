// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_request.dart';
import 'package:super_editor/super_editor.dart';

/// [EditCommand] applying an [OcptReplaceNodeTextRequest]: replaces the target `ParagraphNode` with
/// a copy carrying the new text (metadata untouched), via `ParagraphNode.copyTextNodeWith`,
/// mirroring [OcptChangeNodeMetadataCommand]'s own pattern. A selection or composing region end
/// that the shorter text leaves past its end is brought back to it, so neither is left outside the
/// text; one the replacement moves (a note absorbed into a placeholder shortens what comes before
/// it) is carried by [mapOffset] to where its character now is.
class OcptReplaceNodeTextCommand extends EditCommand {
  /// The id of the `ParagraphNode` whose text is being replaced.
  final String nodeId;

  /// The new text for the node.
  final AttributedText text;

  /// Brings an offset of the node's former text to the matching offset of [text], or null when the
  /// offsets stay where they were (see `OcptReplaceNodeTextRequest.mapOffset`).
  final int Function(int offset)? mapOffset;

  /// Get this command's undo/redo behavior: grouped with other undoable edits, matching
  /// [OcptChangeNodeMetadataCommand].
  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  /// Create an [OcptReplaceNodeTextCommand].
  const OcptReplaceNodeTextCommand({required this.nodeId, required this.text, this.mapOffset});

  /// Apply the text replacement to the document.
  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final existingNode = document.getNodeById(nodeId)! as ParagraphNode;
    document.replaceNodeById(existingNode.id, existingNode.copyTextNodeWith(text: text));

    executor.logChanges([DocumentEdit(NodeChangeEvent(nodeId))]);

    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    final composing = composer.composingRegion.value;
    if (composing != null) {
      final clampedComposing = _clampedRange(composing);
      if (clampedComposing != composing) {
        composer.setComposingRegion(clampedComposing);
      }
    }
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

  /// Get [range] with its ends in the replaced node brought back inside the new text, or null when
  /// that leaves nothing composed.
  DocumentRange? _clampedRange(DocumentRange range) {
    final start = _clampedPosition(range.start);
    final end = _clampedPosition(range.end);
    return start == end ? null : DocumentRange(start: start, end: end);
  }

  /// Get [selection] with its ends in the replaced node brought back inside the new text, so a
  /// shorter text never leaves a caret past its end.
  DocumentSelection _clamped(DocumentSelection selection) => DocumentSelection(
    base: _clampedPosition(selection.base),
    extent: _clampedPosition(selection.extent),
  );

  /// Get [position] moved through [mapOffset] and brought back inside the new text when it lies in
  /// the replaced node.
  DocumentPosition _clampedPosition(DocumentPosition position) {
    final nodePosition = position.nodePosition;
    if (position.nodeId != nodeId || nodePosition is! TextNodePosition) {
      return position;
    }
    final length = text.length;
    final offset = mapOffset?.call(nodePosition.offset) ?? nodePosition.offset;
    final clamped = offset > length ? length : offset;
    return clamped == nodePosition.offset
        ? position
        : DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: clamped),
          );
  }
}

/// Get the [EditRequestHandler] for [OcptReplaceNodeTextRequest], appended to the styled editor's
/// `Editor.requestHandlers` list wherever its `Editor` is constructed (see
/// `_OcptStyledScreenplayEditorState._rebuildEditorFrom`).
EditCommand? ocptReplaceNodeTextRequestHandler(Editor editor, EditRequest request) =>
    request is OcptReplaceNodeTextRequest
    ? OcptReplaceNodeTextCommand(
        nodeId: request.nodeId,
        text: request.text,
        mapOffset: request.mapOffset,
      )
    : null;
