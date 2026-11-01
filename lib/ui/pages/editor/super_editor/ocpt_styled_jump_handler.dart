// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// Carries out a scene jump request in a styled editor: moves the selection to the node a source
/// character offset falls in, focuses the editor and scrolls the node into view.
///
/// The document, the editor and the line mapping are resolved through callbacks at call time,
/// since the styled editor replaces all of them whenever its text is rebuilt from outside.
final class OcptStyledJumpHandler {
  /// Resolves the document the jump lands in.
  final MutableDocument Function() _documentOf;

  /// Resolves the editor executing the selection request.
  final Editor Function() _editorOf;

  /// Resolves the node-index to source-line mapping of the text the document represents.
  final OcptWysiwygLineMapping Function() _mappingOf;

  /// Resolves the number of leading title-page nodes the document starts with.
  final int Function() _titlePageNodeCountOf;

  /// Resolves the number of leading characters the title page consumes in the source text.
  final int Function() _titlePagePrefixLengthOf;

  /// The key bound to the document layout, used to resolve a node's on-screen component.
  final GlobalKey _documentLayoutKey;

  /// The focus node of the styled editor, focused when a jump is applied.
  final FocusNode _focusNode;

  /// Whether the owning widget is still mounted.
  final bool Function() _isMounted;

  /// Whether the owning widget is still mounted.
  bool get mounted => _isMounted();

  /// The document the jump lands in.
  MutableDocument get _document => _documentOf();

  /// The editor executing the selection request.
  Editor get _editor => _editorOf();

  /// Creates an [OcptStyledJumpHandler].
  OcptStyledJumpHandler({
    required MutableDocument Function() documentOf,
    required Editor Function() editorOf,
    required OcptWysiwygLineMapping Function() mappingOf,
    required int Function() titlePageNodeCountOf,
    required int Function() titlePagePrefixLengthOf,
    required GlobalKey documentLayoutKey,
    required FocusNode focusNode,
    required bool Function() isMounted,
  }) : _documentOf = documentOf,
       _editorOf = editorOf,
       _mappingOf = mappingOf,
       _titlePageNodeCountOf = titlePageNodeCountOf,
       _titlePagePrefixLengthOf = titlePagePrefixLengthOf,
       _documentLayoutKey = documentLayoutKey,
       _focusNode = focusNode,
       _isMounted = isMounted;

  /// Moves the styled editor's selection to the start of the node containing [charOffset] of
  /// the line mapping's own source text, focuses the editor, and scrolls the target node's component
  /// into view.
  void apply(int charOffset) {
    if (!mounted || _document.nodeCount == 0) {
      return;
    }

    // [charOffset] is always relative to the full source text (scenes only ever exist in the
    // body, so it's always at or past the title page's own prefix, but the subtraction is clamped
    // defensively anyway); `_mapping` itself is body-scoped, so its own resolved node index needs
    // `_titlePageNodeCountOf()` added back before it means anything to `_document`.
    final bodyCharOffset = charOffset <= _titlePagePrefixLengthOf()
        ? 0
        : charOffset - _titlePagePrefixLengthOf();
    final nodeIndex = _mappingOf().nodeIndexOfCharOffset(bodyCharOffset) + _titlePageNodeCountOf();
    final node = _document.getNodeAt(nodeIndex);
    if (node == null) {
      return;
    }

    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: node.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.placeCaret,
        ocptProgrammaticNavigationSelectionReason,
      ),
    ]);
    _focusNode.requestFocus();

    final component = (_documentLayoutKey.currentState as DocumentLayout?)?.getComponentByNodeId(
      node.id,
    );
    if (component == null) {
      return;
    }

    // Every `DocumentComponent` is also a `State` (super_editor's own mixin is declared `on
    // State<...>`), so this cast is safe; it sidesteps this widget's `component` being typed as
    // the narrower `DocumentComponent` interface, which doesn't expose `context`/`mounted`.
    final componentState = component as State;
    if (componentState.mounted) {
      unawaited(
        Scrollable.ensureVisible(
          componentState.context,
          alignment: 0.3,
          duration: const Duration(milliseconds: 200),
        ),
      );
    }
  }
}
