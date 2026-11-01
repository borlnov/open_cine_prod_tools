// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_history.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_title_page_guard_requests.dart';
import 'package:super_editor/super_editor.dart';

/// Build the super_editor [Editor] of the styled screenplay editor over [document] and [composer]:
/// super_editor's default request handlers, the title-page guard in front of them and the app's own
/// metadata and text-replacement handlers after them, recording its undo history through
/// [history].
Editor ocptStyledEditorFor({
  required MutableDocument document,
  required MutableDocumentComposer composer,
  required OcptStyledHistory history,
}) => Editor(
  editables: {Editor.documentKey: document, Editor.composerKey: composer},
  requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
    ..insert(0, ocptTitlePageGuardRequestHandler)
    ..add(ocptChangeNodeMetadataRequestHandler)
    ..add(ocptReplaceNodeTextRequestHandler),
  // `isHistoryEnabled` defaults to false, which is what used to make every command's own
  // `HistoryBehavior.undoable` moot: `undo()`/`redo()` returned immediately and `history`/
  // `future` never grew. `historyGroupingPolicy` defaults to `neverMergePolicy`, which groups
  // nothing at all, and super_editor's own `defaultMergePolicy` groups a typing run only
  // within 100 ms — see [OcptSettleMergePolicy] for what this one groups instead.
  isHistoryEnabled: true,
  historyGroupingPolicy: history.mergePolicy,
);
