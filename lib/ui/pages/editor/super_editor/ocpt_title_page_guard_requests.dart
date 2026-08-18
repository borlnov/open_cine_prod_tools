// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// [EditCommand] that deliberately does nothing: [ocptTitlePageGuardRequestHandler] returns this,
/// instead of `null`, for a request it must block outright.
///
/// Returning `null` from an [EditRequestHandler] means "I don't recognise this request", which
/// makes `Editor._findCommandForRequest` hand it to the next handler in line — here, the default
/// handler for whichever request is at hand, exactly the outcome the guard exists to prevent.
/// Returning this command instead makes the guard's handler win outright (per `Editor.execute`'s
/// "first handler that recognises the request wins" rule) while the request itself is dropped: no
/// node is merged, deleted or otherwise touched, no changes are logged.
class OcptNoOpCommand extends EditCommand {
  /// Creates an [OcptNoOpCommand].
  const OcptNoOpCommand();

  /// Not `HistoryBehavior.undoable`, on purpose: `Editor.endTransaction` decides whether a
  /// transaction joins history by checking `_transaction!.commands.isNotEmpty`, never by whether
  /// any of those commands actually changed anything. A refused title-page edit — Backspace at the
  /// start of `Credit`, for example — still runs exactly one command, this one, so an `undoable`
  /// [OcptNoOpCommand] would still push an empty transaction onto history. The writer's very next
  /// Ctrl+Z would then pop that transaction, replay nothing, and visibly do nothing at all, one
  /// keystroke away from the edit they actually meant to undo.
  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.nonHistorical;

  /// Does nothing: the request is deliberately dropped.
  @override
  void execute(EditContext context, CommandExecutor executor) {}
}

/// Whether [node] is one of [OcptWysiwygCodec.decodeWithTitlePage]'s synthesized title-page field
/// nodes, guarded against a non-[ParagraphNode] since [OcptWysiwygCodec.isTitlePageNode] only
/// accepts one (every node in this app's document is one by construction, but a request guard must
/// never assume that about an arbitrary [DocumentNode]).
bool _isTitlePageNode(DocumentNode? node) => node is ParagraphNode && OcptWysiwygCodec.isTitlePageNode(node);

/// The title-page field key [node] carries ([ocptTitlePageKeyMetadataKey]), or `null` for a node
/// that isn't one (an ordinary body line, or no node at all).
Object? _titlePageKeyOf(DocumentNode? node) => node?.getMetadataValue(ocptTitlePageKeyMetadataKey);

/// The [EditRequestHandler] protecting the title-page sheet against every request shape that could
/// remove one of its fields, merge one away, or bleed body content into it, prepended to the styled
/// editor's `Editor.requestHandlers` list wherever its `Editor` is constructed
/// (`OcptStyledScreenplayEditor._rebuildEditorFrom` and `_flushPendingSync`), so it runs before —
/// and overrides — the default handler for every request type it recognises, on every path that can
/// produce one: the IME delta channel Backspace/Delete actually travel through on desktop, a
/// hardware key event, select-all + Delete, a future toolbar button, or a test.
///
/// Deliberately **not** guarded here: ordinary text editing *inside* a single field (typing,
/// Backspace, Delete, replacing a selection) — a `DeleteSelectionRequest`/`DeleteContentRequest`
/// contained in one node is let through untouched below, which is the actual F6 fix. Every
/// title-page node used to additionally carry `NodeMetadata.isDeletable: false`
/// (`OcptWysiwygCodec._titlePageNodesFrom`), which also blocked that ordinary in-field editing —
/// `DeleteSelectionCommand`/`DeleteContentCommand` abort *any* deletion, however small, contained in
/// a single non-deletable node (`multi_node_editing.dart:1428-1449, 798-822` of the pinned
/// super_editor release). Removing the flag and moving every rule below into this handler is what
/// tells those two paths apart: "delete text inside a field" (allowed) from "delete the field"
/// (blocked).
EditCommand? ocptTitlePageGuardRequestHandler(Editor editor, EditRequest request) {
  if (request is CombineParagraphsRequest) {
    return _guardCombineParagraphs(editor, request);
  }
  if (request is DeleteUpstreamAtBeginningOfNodeRequest) {
    return _guardDeleteUpstreamAtBeginningOfNode(editor, request);
  }
  if (request is DeleteNodeRequest) {
    return _guardDeleteNode(editor, request);
  }
  if (request is DeleteSelectionRequest) {
    return _guardDeleteSelection(editor);
  }
  if (request is DeleteContentRequest) {
    return _guardDeleteContent(editor, request);
  }
  return null;
}

/// A `CombineParagraphsRequest` merges its `secondNodeId` node into its `firstNodeId` node,
/// deleting the second (`CombineParagraphsCommand`,
/// `package:super_editor/src/default_editor/paragraph.dart:721-813`). This handler drops the
/// request (see [OcptNoOpCommand]) whenever the two nodes are not two nodes of the *same*
/// title-page field — i.e. whenever exactly one of them carries [ocptTitlePageKeyMetadataKey], or
/// both do but with different values. Two nodes that both lack the metadata (an ordinary body
/// merge) are untouched, and so are two nodes of the *same* field (for example two `Contact`
/// lines): that merge is the exact undo of the Enter gesture `_splitTitlePageField`
/// (`ocpt_fountain_keyboard_actions.dart`) provides for a multi-line field, and must keep working.
///
/// This is the hardware-Backspace path's own merge attempt
/// (`CommonEditorOperations.mergeTextNodeWithUpstreamTextNode`, `common_editor_operations.dart`),
/// which issues this request directly — unlike the IME delta channel's offset-0 Backspace, guarded
/// separately below (see [_guardDeleteUpstreamAtBeginningOfNode]'s own doc comment for why the two
/// need their own rule each).
EditCommand? _guardCombineParagraphs(Editor editor, CombineParagraphsRequest request) {
  final firstKey = _titlePageKeyOf(editor.document.getNodeById(request.firstNodeId));
  final secondKey = _titlePageKeyOf(editor.document.getNodeById(request.secondNodeId));

  return firstKey == secondKey ? null : const OcptNoOpCommand();
}

/// The request the IME delta channel actually sends when Backspace is pressed at offset 0 of a node
/// (`document_ime/document_delta_editing.dart`'s `delete()`): its default command
/// (`DeleteUpstreamAtBeginningOfParagraphCommand`, `paragraph.dart`) calls
/// `mergeTextNodeWithUpstreamTextNode`, which executes `CombineParagraphsCommand` **directly on the
/// executor** — never as a `CombineParagraphsRequest` — so [_guardCombineParagraphs] never sees it.
///
/// Mirrors that handler's own same-field/different-field split exactly (see its doc comment):
/// drops the request when [request]'s node and the node immediately above it are not two nodes of
/// the same title-page field — covering both directions at once, a title-page node with nothing
/// (or a different field) above it, *and* an ordinary body node with a title-page node above it
/// (the "first body line merged into `Source`" case) — and lets two lines of the same field through
/// untouched, exactly like the hardware path.
EditCommand? _guardDeleteUpstreamAtBeginningOfNode(Editor editor, DeleteUpstreamAtBeginningOfNodeRequest request) {
  final node = request.node;
  if (node is! ParagraphNode) {
    return null;
  }

  final nodeKey = _titlePageKeyOf(node);
  final aboveKey = _titlePageKeyOf(editor.document.getNodeBeforeById(node.id));

  return nodeKey == aboveKey ? null : const OcptNoOpCommand();
}

/// `DeleteNodeRequest` deletes exactly the node it names, unconditionally
/// (`DeleteNodeCommand`, `multi_node_editing.dart`), independent of `NodeMetadata.isDeletable` —
/// the programmatic path that flag used to cover on its own. Dropped outright for a title-page
/// node; every other node is untouched.
EditCommand? _guardDeleteNode(Editor editor, DeleteNodeRequest request) =>
    _isTitlePageNode(editor.document.getNodeById(request.nodeId)) ? const OcptNoOpCommand() : null;

/// `DeleteSelectionRequest`'s default command (`DeleteSelectionCommand`) deletes whatever the
/// composer's current selection spans — there is no explicit range on the request itself, unlike
/// [DeleteContentRequest].
EditCommand? _guardDeleteSelection(Editor editor) {
  final selection = editor.composer.selection;
  if (selection == null) {
    return null;
  }

  return _guardRangeDeletion(editor.document, selection.normalize(editor.document), updateSelection: true);
}

/// `DeleteContentRequest` carries its own [DeleteContentRequest.documentRange] explicitly.
EditCommand? _guardDeleteContent(Editor editor, DeleteContentRequest request) =>
    _guardRangeDeletion(editor.document, request.documentRange.normalize(editor.document), updateSelection: false);

/// The shared rule behind [_guardDeleteSelection] and [_guardDeleteContent]: a deletion contained
/// within a single node — title-page or not — is ordinary editing (typing, Backspace, Delete,
/// replacing a selection) and is let through completely untouched; this is the actual F6 fix, and
/// the reason every other rule in this file only ever needs to consider a *multi*-node range.
///
/// A multi-node [normalizedRange] that touches no title-page node at all (an ordinary body-only
/// deletion, including the app's own select-all-then-Delete with no title page present) is likewise
/// untouched. A multi-node range that does touch at least one title-page node is replaced with an
/// equivalent [DeleteContentCommand] clamped to the range's own body-only portion (its start moved
/// to the first non-title-page node's own beginning), so the app's select-all + Delete still clears
/// the screenplay body while leaving the six fields standing; a range with no body part left at all
/// (every node it spans is a title-page field, for example a selection dragged across only the
/// sheet) is dropped entirely instead ([OcptNoOpCommand]).
EditCommand? _guardRangeDeletion(Document document, DocumentRange normalizedRange, {required bool updateSelection}) {
  if (normalizedRange.start.nodeId == normalizedRange.end.nodeId) {
    return null;
  }

  final nodesInRange = document.getNodesInside(normalizedRange.start, normalizedRange.end);
  if (!nodesInRange.any(_isTitlePageNode)) {
    // An ordinary, title-page-free multi-node range: untouched.
    return null;
  }

  final bodyNodesInRange = nodesInRange.where((node) => !_isTitlePageNode(node));
  if (bodyNodesInRange.isEmpty) {
    // Every node spanned by the range is a title-page field: nothing left to legitimately delete.
    return const OcptNoOpCommand();
  }

  final firstBodyNode = bodyNodesInRange.first;
  final clampedStart = DocumentPosition(nodeId: firstBodyNode.id, nodePosition: firstBodyNode.beginningPosition);

  return DeleteContentCommand(
    documentRange: DocumentRange(start: clampedStart, end: normalizedRange.end),
    updateSelection: updateSelection,
  );
}
