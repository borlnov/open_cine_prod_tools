// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_edit_requests.dart';
import 'package:super_editor/super_editor.dart';

/// The styled block editing mode of the screenplay editor: the user still types raw Fountain
/// syntax, but every line is laid out at its true screenplay position as they type (scene
/// headings bold at the margin, character cues and dialogue indented at their column, etc.),
/// through a super_editor document with **one `ParagraphNode` per non-blank Fountain source
/// line** (see `OcptWysiwygCodec`).
///
/// This is the only widget in the app that touches `package:super_editor` directly (together
/// with the other files of this `super_editor/` directory): every other part of the editor page
/// only knows this widget's plain, app-level API (raw [text] in, changed text and caret line out),
/// so a future change of rich-text editing engine would only touch this directory.
///
/// The single source of truth for the document's content is [text] (ultimately, the bloc's
/// state): this widget only ever rebuilds its internal super_editor document from [text] on the
/// very first build and whenever [text] changes for a reason other than this widget's own last
/// edit (a mode switch back from raw editing, or a different project being loaded). On every
/// other rebuild, the super_editor document is left alone so it keeps owning the caret, exactly
/// as it does while the user is actively typing.
class OcptStyledScreenplayEditor extends StatefulWidget {
  /// The full Fountain source text to edit.
  final String text;

  /// The page format driving the styled editor's layout metrics.
  final OcptPageFormat pageFormat;

  /// Called with the new full source text whenever the user edits the document.
  final ValueChanged<String> onTextChanged;

  /// Called with the 0-based source line the caret moved to.
  final ValueChanged<int> onCaretLineChanged;

  /// The pending caret jump request (from the scene panel), or null if none was ever made.
  final OcptEditorJumpRequest? jumpRequest;

  /// Class constructor
  const OcptStyledScreenplayEditor({
    super.key,
    required this.text,
    required this.pageFormat,
    required this.onTextChanged,
    required this.onCaretLineChanged,
    required this.jumpRequest,
  });

  @override
  State<OcptStyledScreenplayEditor> createState() => _OcptStyledScreenplayEditorState();
}

/// The state of [OcptStyledScreenplayEditor]: owns the super_editor `MutableDocument`, composer
/// and `Editor`, keeps their content in sync with [OcptStyledScreenplayEditor.text] in both
/// directions, and re-classifies every line into its `blockType` metadata after a short debounce
/// on every edit.
class _OcptStyledScreenplayEditorState extends State<OcptStyledScreenplayEditor> {
  /// The delay between the last document edit and the classification/text-sync pass.
  static const _syncDebounce = Duration(milliseconds: 120);

  /// The document backing the styled editor, rebuilt from [OcptStyledScreenplayEditor.text] only
  /// on an external change (see [_rebuildEditorFrom]).
  late MutableDocument _document;

  /// The node-index ↔ source-line mapping for the text [_document] currently represents: refreshed
  /// by [_rebuildEditorFrom] (decode) and by every [_syncAfterEdit] pass (encode), so caret-line
  /// reporting and scene jumps always resolve against the same text version the mapping was built
  /// from.
  late OcptWysiwygLineMapping _mapping;

  /// The number of blank source lines trailing the last node, carried forward from the last
  /// [OcptWysiwygCodec.decode] across every subsequent [OcptWysiwygCodec.encode] call in this
  /// session (nothing in the document's node structure tracks it, since it has no node to attach
  /// to).
  int _trailingBlankLines = 0;

  /// The composer holding the styled editor's selection.
  late MutableDocumentComposer _composer;

  /// The editor executing every change made to [_document] and [_composer].
  ///
  /// Its `reactionPipeline` is intentionally left empty: super_editor's default reactions (header,
  /// list, blockquote, dash and link conversions) rewrite the very raw text this editor must
  /// preserve untouched, so none of them can run here.
  late Editor _editor;

  /// The key bound to the document layout, used to resolve a node's on-screen component when
  /// applying a scene jump.
  final GlobalKey _documentLayoutKey = GlobalKey();

  /// The focus node of the styled editor, focused back when applying a scene jump.
  final FocusNode _focusNode = FocusNode();

  /// The last text synced with [OcptStyledScreenplayEditor.onTextChanged] (or the text the
  /// document was last (re)built from), used to tell this widget's own edits apart from an
  /// external change to [OcptStyledScreenplayEditor.text].
  String _lastSyncedText = "";

  /// The last source line reported through [OcptStyledScreenplayEditor.onCaretLineChanged].
  int _lastReportedLine = 0;

  /// The id of the last [OcptEditorJumpRequest] applied, to apply each request exactly once.
  int? _lastAppliedJumpRequestId;

  /// The running debounce timer restarted on every document change.
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _rebuildEditorFrom(widget.text);
    _maybeApplyPendingJumpRequest();
  }

  @override
  void didUpdateWidget(covariant OcptStyledScreenplayEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text && widget.text != _lastSyncedText) {
      setState(() {
        _disposeEditor();
        _rebuildEditorFrom(widget.text);
      });
    }

    _maybeApplyPendingJumpRequest();
  }

  /// Applies [OcptStyledScreenplayEditor.jumpRequest] if it wasn't already applied by this widget
  /// (whether it arrived through a rebuild, or was already pending the very first time this
  /// widget was built, e.g. right after switching from raw to styled mode).
  void _maybeApplyPendingJumpRequest() {
    final jumpRequest = widget.jumpRequest;
    if (jumpRequest != null && jumpRequest.id != _lastAppliedJumpRequestId) {
      _lastAppliedJumpRequestId = jumpRequest.id;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyJumpRequest(jumpRequest.charOffset),
      );
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _disposeEditor();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = switch (widget.pageFormat) {
      OcptPageFormat.usLetter => FountainLayoutMetrics.usLetter(),
      OcptPageFormat.a4 => FountainLayoutMetrics.a4(),
    };

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SuperEditor(
        editor: _editor,
        focusNode: _focusNode,
        documentLayoutKey: _documentLayoutKey,
        stylesheet: OcptFountainEditorStylesheet.build(
          metrics: metrics,
          colorScheme: theme.colorScheme,
        ),
      ),
    );
  }

  /// Builds [_document], [_composer] and [_editor] from [text], and starts listening to document
  /// and selection changes.
  ///
  /// [_lastSyncedText] is set to [text] so this rebuild is never mistaken, on the very next
  /// widget update, for an external change to `widget.text`.
  void _rebuildEditorFrom(String text) {
    _lastSyncedText = text;
    _lastReportedLine = 0;

    final decoded = OcptWysiwygCodec.decode(text);
    _document = decoded.document;
    _mapping = decoded.mapping;
    _trailingBlankLines = decoded.trailingBlankLines;
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: _composer},
      requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
        ..add(ocptChangeNodeMetadataRequestHandler),
    );

    _document.addListener(_onDocumentChanged);
    _composer.selectionNotifier.addListener(_onSelectionChanged);
  }

  /// Stops listening to [_document] and [_composer] and disposes them, before they're replaced or
  /// this widget is disposed.
  void _disposeEditor() {
    _document.removeListener(_onDocumentChanged);
    _composer.selectionNotifier.removeListener(_onSelectionChanged);
    _composer.dispose();
    _editor.dispose();
  }

  /// Restarts the sync debounce on every document change (a text edit, a line split/merge...).
  void _onDocumentChanged(DocumentChangeLog changeLog) {
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDebounce, _syncAfterEdit);
  }

  /// Rejoins the document into flat text (reporting it upstream if it changed), refreshes
  /// [_mapping] for that freshly encoded text, and re-classifies every line plus every note's
  /// attribution span, only touching the metadata of the nodes that actually need it.
  void _syncAfterEdit() {
    if (!mounted) {
      return;
    }

    final encoded = OcptWysiwygCodec.encode(_document, trailingBlankLines: _trailingBlankLines);
    _mapping = encoded.mapping;
    if (encoded.text != _lastSyncedText) {
      _lastSyncedText = encoded.text;
      widget.onTextChanged(encoded.text);
    }

    final requests = [
      ...OcptWysiwygCodec.reclassifyRequests(_document),
      ...OcptWysiwygCodec.noteAttributionRequests(_document),
    ];
    if (requests.isNotEmpty) {
      _editor.execute(requests);
    }
  }

  /// Reports the source line the caret moved to, whenever the composer's selection changes to a
  /// different node, resolved through [_mapping] (a node's index is no longer always its source
  /// line, now that blank source lines are folded into metadata instead of being their own node).
  void _onSelectionChanged() {
    final nodeId = _composer.selection?.extent.nodeId;
    if (nodeId == null) {
      return;
    }

    final nodeIndex = _document.getNodeIndexById(nodeId);
    if (nodeIndex < 0) {
      return;
    }

    final line = _mapping.lineOfNodeIndex(nodeIndex);
    if (line != _lastReportedLine) {
      _lastReportedLine = line;
      widget.onCaretLineChanged(line);
    }
  }

  /// Moves the styled editor's selection to the start of the node containing [charOffset] of
  /// [_mapping]'s own source text, focuses the editor, and scrolls the target node's component
  /// into view.
  void _applyJumpRequest(int charOffset) {
    if (!mounted || _document.nodeCount == 0) {
      return;
    }

    final nodeIndex = _mapping.nodeIndexOfCharOffset(charOffset);
    final node = _document.getNodeAt(nodeIndex);
    if (node == null) {
      return;
    }

    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: node.id, nodePosition: const TextNodePosition(offset: 0)),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
    _focusNode.requestFocus();

    final component = (_documentLayoutKey.currentState as DocumentLayout?)?.getComponentByNodeId(node.id);
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
