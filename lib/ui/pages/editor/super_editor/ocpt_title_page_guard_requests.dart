// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// [EditCommand] that deliberately does nothing: [ocptTitlePageGuardRequestHandler] returns this,
/// instead of `null`, for a `CombineParagraphsRequest` it must block.
///
/// Returning `null` from an [EditRequestHandler] means "I don't recognise this request", which
/// makes `Editor._findCommandForRequest` hand it to the next handler in line — here, the default
/// `CombineParagraphsCommand` handler, exactly the outcome the guard exists to prevent. Returning
/// this command instead makes the guard's handler win outright (per `Editor.execute`'s "first
/// handler that recognises the request wins" rule) while the request itself is dropped: no node is
/// merged, no changes are logged.
class OcptNoOpCommand extends EditCommand {
  /// Creates an [OcptNoOpCommand].
  const OcptNoOpCommand();

  /// Grouped with other undoable edits, matching every other command in this app; since this
  /// command never logs a change, a dropped merge attempt never becomes its own undo step either
  /// way.
  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  /// Does nothing: the request is deliberately dropped.
  @override
  void execute(EditContext context, CommandExecutor executor) {}
}

/// The [EditRequestHandler] guarding every title-page field node against being merged away by a
/// `CombineParagraphsRequest`, prepended to the styled editor's `Editor.requestHandlers` list
/// wherever its `Editor` is constructed (`OcptStyledScreenplayEditor._rebuildEditorFrom` and
/// `_flushPendingSync`), so it runs before — and overrides — the default handler for every path
/// that can produce that request: the IME delta channel Backspace actually travels through on
/// desktop, a hardware key event, a future toolbar button, or a test.
///
/// A `CombineParagraphsRequest` merges its `secondNodeId` node into its `firstNodeId` node,
/// deleting the second (`CombineParagraphsCommand`,
/// `package:super_editor/src/default_editor/paragraph.dart:721-813`). This handler drops the
/// request (see [OcptNoOpCommand]) whenever the two nodes are not two nodes of the *same*
/// title-page field — i.e. whenever exactly one of them carries [ocptTitlePageKeyMetadataKey], or
/// both do but with different values. Two nodes that both lack the metadata (an ordinary body
/// merge) are untouched, and so are two nodes of the *same* field (for example two `Contact`
/// lines): that merge is the exact undo of the Enter gesture `_splitTitlePageField`
/// (`ocpt_fountain_keyboard_actions.dart`) provides for a multi-line field, and must keep working.
EditCommand? ocptTitlePageGuardRequestHandler(Editor editor, EditRequest request) {
  if (request is! CombineParagraphsRequest) {
    return null;
  }

  final firstKey = editor.document.getNodeById(request.firstNodeId)?.getMetadataValue(ocptTitlePageKeyMetadataKey);
  final secondKey = editor.document.getNodeById(request.secondNodeId)?.getMetadataValue(ocptTitlePageKeyMetadataKey);

  return firstKey == secondKey ? null : const OcptNoOpCommand();
}
