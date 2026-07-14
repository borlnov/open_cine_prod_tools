// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_ime_overrides.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_keyboard_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_inline_style_attributions.dart';
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

  /// The app-level controller bridging this editor to the toolbar's block-type dropdown and B/I/U
  /// toggles, or null when this widget is used without one (for example some tests, and any future
  /// caller that doesn't need toolbar wiring): a null controller simply means the toolbar has
  /// nothing to attach to, exactly like being in raw mode.
  final OcptStyledEditorController? styledController;

  /// Class constructor
  const OcptStyledScreenplayEditor({
    super.key,
    required this.text,
    required this.pageFormat,
    required this.onTextChanged,
    required this.onCaretLineChanged,
    required this.jumpRequest,
    this.styledController,
  });

  @override
  State<OcptStyledScreenplayEditor> createState() => _OcptStyledScreenplayEditorState();
}

/// The state of [OcptStyledScreenplayEditor]: owns the super_editor `MutableDocument`, composer
/// and `Editor`, keeps their content in sync with [OcptStyledScreenplayEditor.text] in both
/// directions, and re-classifies every line into its `blockType` metadata after a short debounce
/// on every edit.
class _OcptStyledScreenplayEditorState extends State<OcptStyledScreenplayEditor>
    implements OcptStyledEditorControllerDelegate {
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

  /// The IME-delta interceptor that catches a plain Tab keystroke before it can insert a literal
  /// `\t` character (see `OcptFountainTabInterceptor`'s own doc comment for why this is needed).
  /// Built once, not on every [build] — `SuperEditorImeInteractorState` compares `imeOverrides` by
  /// identity across widget updates and re-wires its IME client whenever it changes, so a fresh
  /// instance every build would needlessly reconnect the IME on every rebuild. Its callback reads
  /// [_editor]/[_document]/[_composer] at call time through an instance method, rather than closing
  /// over them as local variables, so it keeps working correctly across [_rebuildEditorFrom]
  /// reassigning all three (a captured local would keep pointing at the stale, disposed instances).
  late final OcptFountainTabInterceptor _imeOverrides = OcptFountainTabInterceptor(
    onTabPressed: _cycleBlockTypeForwardFromTab,
  );

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
    widget.styledController?.attach(this);
    _reportReadStateToController();
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
      _reportReadStateToController();
    }

    if (widget.styledController != oldWidget.styledController) {
      oldWidget.styledController?.detach(this);
      widget.styledController?.attach(this);
      _reportReadStateToController();
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
  void deactivate() {
    // `deactivate()` runs before `dispose()` for every removal from the tree (including the
    // conditional-widget swap a mode toggle or the editor route's back navigation triggers), so
    // flushing here, rather than in `dispose()`, is what guarantees the last <120 ms of edits
    // (still only sitting in `_document`, not yet reported through `onTextChanged`) survive it:
    // by the time `dispose()` tears the editor down, there is nothing left to flush.
    _flushPendingSync();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.styledController?.detach(this);
    _syncTimer?.cancel();
    _disposeEditor();
    _focusNode.dispose();
    super.dispose();
  }

  /// Runs the encode-and-report half of a pending debounced sync immediately, instead of waiting
  /// for [_syncTimer] to fire on its own — deliberately skipping the other half, the
  /// [OcptWysiwygCodec.reclassifyRequests]/[OcptWysiwygCodec.noteAttributionRequests] pass
  /// [_syncAfterEdit] also runs, which needs to execute requests against [_editor] to apply.
  ///
  /// Executing requests against [_editor] from here would be unsafe: [deactivate] (this method's
  /// only caller) can fire while this exact subtree is itself mid-teardown (a mode toggle or
  /// route change both remove this widget as part of an ancestor's own rebuild), and executing an
  /// edit at that point can reach a document-layout component that Flutter has already
  /// deactivated, crashing with "setState() called during build". None of that matters for a
  /// flush: the classification/note spans it would have produced are purely cosmetic and get
  /// recomputed from scratch the next time this text is decoded anyway (mode toggle back, or a
  /// fresh load); only the actual text edit needs to survive, which encoding alone already
  /// guarantees.
  void _flushPendingSync() {
    if (_syncTimer == null || !_syncTimer!.isActive) {
      return;
    }
    _syncTimer!.cancel();
    _encodeAndReportIfChanged();
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
        keyboardActions: ocptFountainKeyboardActions,
        imeOverrides: _imeOverrides,
        // Both default policies clear the selection the moment this editor loses focus to any
        // other widget, including a momentary focus steal by the toolbar's block-type dropdown
        // opening its own overlay route: the focus loss directly clears the selection
        // (`clearSelectionWhenEditorLosesFocus`), AND separately closes this editor's IME
        // connection, which clears it a second way (`clearSelectionWhenImeConnectionCloses`).
        // `applyBlockType`/`applyToggleInlineStyle` need that exact selection to still be there
        // once the dropdown/toggle's own callback runs, so this editor keeps its selection through
        // any such round trip instead (the toolbar's own explicit `_focusNode.requestFocus()`
        // afterwards brings real keyboard focus, and with it a fresh IME connection, straight back
        // anyway).
        selectionPolicies: const SuperEditorSelectionPolicies(
          clearSelectionWhenEditorLosesFocus: false,
          clearSelectionWhenImeConnectionCloses: false,
        ),
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
    _composer.preferences.addListener(_onComposerPreferencesChanged);
  }

  /// Stops listening to [_document] and [_composer] and disposes them, before they're replaced or
  /// this widget is disposed.
  void _disposeEditor() {
    _document.removeListener(_onDocumentChanged);
    _composer.selectionNotifier.removeListener(_onSelectionChanged);
    _composer.preferences.removeListener(_onComposerPreferencesChanged);
    _composer.dispose();
    _editor.dispose();
  }

  /// Restarts the sync debounce on every document change (a text edit, a line split/merge...), and
  /// immediately refreshes the toolbar's read state: a metadata-only change like the Tab cycle
  /// (see `ocptManualBlockTypeRequests`) moves no selection, so without this the dropdown would
  /// otherwise only catch up 120 ms later, at the next debounced sync.
  void _onDocumentChanged(DocumentChangeLog changeLog) {
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDebounce, _syncAfterEdit);
    _reportReadStateToController();
  }

  /// Rejoins the document into flat text (reporting it upstream if it changed), refreshes
  /// [_mapping] for that freshly encoded text, and re-classifies every line plus every note's
  /// attribution span, only touching the metadata of the nodes that actually need it.
  void _syncAfterEdit() {
    if (!mounted) {
      return;
    }

    _encodeAndReportIfChanged();

    final requests = [
      ...OcptWysiwygCodec.reclassifyRequests(_document),
      ...OcptWysiwygCodec.noteAttributionRequests(_document),
    ];
    if (requests.isNotEmpty) {
      _editor.execute(requests);
    }
  }

  /// Encodes [_document] back to text, refreshes [_mapping] for it, and reports the new text
  /// upstream if it actually changed — the pure, editor-mutation-free half of [_syncAfterEdit],
  /// reused by [_flushPendingSync] so a flush never has to run [_editor] commands (see its own
  /// doc comment for why that matters).
  void _encodeAndReportIfChanged() {
    final encoded = OcptWysiwygCodec.encode(_document, trailingBlankLines: _trailingBlankLines);
    _mapping = encoded.mapping;
    if (encoded.text != _lastSyncedText) {
      _lastSyncedText = encoded.text;
      widget.onTextChanged(encoded.text);
    }
  }

  /// Reports the source line the caret moved to, whenever the composer's selection changes to a
  /// different node, resolved through [_mapping] (a node's index is no longer always its source
  /// line, now that blank source lines are folded into metadata instead of being their own node).
  void _onSelectionChanged() {
    final nodeId = _composer.selection?.extent.nodeId;
    if (nodeId != null) {
      final nodeIndex = _document.getNodeIndexById(nodeId);
      if (nodeIndex >= 0) {
        final line = _mapping.lineOfNodeIndex(nodeIndex);
        if (line != _lastReportedLine) {
          _lastReportedLine = line;
          widget.onCaretLineChanged(line);
        }
      }
    }

    _reportReadStateToController();
  }

  /// Refreshes [OcptStyledEditorController]'s read side (the toolbar's dropdown/B-I-U state) from
  /// the caret's current node type and active inline styles, called after every attach, every
  /// document rebuild, every selection change and every composer-preferences change (bold/italic/
  /// underline toggled for the next typed character while the caret is collapsed).
  void _reportReadStateToController() {
    final controller = widget.styledController;
    if (controller == null) {
      return;
    }

    final selection = _composer.selection;
    final node = selection == null ? null : _document.getNodeById(selection.extent.nodeId);
    final currentBlockType = node is ParagraphNode
        ? OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"))
        : FountainLineType.action;

    controller.updateReadState(
      currentBlockType: currentBlockType,
      activeInlineStyles: {
        for (final style in OcptInlineStyle.values)
          if (_doesSelectionHaveStyle(style)) style,
      },
    );
  }

  /// Whether [style]'s attribution is active over the current selection: for a collapsed caret,
  /// the composer's pending style preferences (what the next typed character will carry); for an
  /// expanded selection, whether every character of it already carries the attribution.
  ///
  /// Mirrors the pattern super_editor's own mobile toolbar
  /// (`KeyboardEditingToolbarOperations._doesSelectionHaveAttributions`) uses for the same check.
  bool _doesSelectionHaveStyle(OcptInlineStyle style) {
    final selection = _composer.selection;
    if (selection == null) {
      return false;
    }

    final attribution = OcptInlineStyleAttributions.attributionOf(style);
    if (selection.isCollapsed) {
      return _composer.preferences.currentAttributions.contains(attribution);
    }
    return _document.doesSelectedTextContainAttributions(selection, {attribution});
  }

  /// Refreshes the controller's read side whenever the composer's collapsed-caret style
  /// preferences change (a B/I/U toggle applied via keyboard shortcut or the toolbar, while the
  /// caret has no selection): [_onSelectionChanged] alone would miss this, since the selection
  /// itself doesn't move.
  void _onComposerPreferencesChanged() {
    _reportReadStateToController();
  }

  /// Applies a manual block-type change to the current selection's extent node: bails out silently
  /// if there is no selection, or its node isn't a `ParagraphNode` (mirroring
  /// `ocptTabToCycleBlockType`'s own guard), otherwise sets the type and locks the block exactly
  /// like the Tab-cycle gesture does, then reports the fresh read state and hands focus straight
  /// back to the editor — the toolbar's dropdown must never keep the keyboard focus it briefly took
  /// to open.
  @override
  void applyBlockType(FountainLineType type) {
    final selection = _composer.selection;
    if (selection == null) {
      return;
    }

    final node = _document.getNodeById(selection.extent.nodeId);
    if (node is! ParagraphNode) {
      return;
    }

    _editor.execute(ocptManualBlockTypeRequests(nodeId: node.id, type: type));
    _reportReadStateToController();
    _focusNode.requestFocus();
  }

  /// Toggles [style] on the current selection: the composer's pending style preferences when
  /// collapsed (so the next typed character carries it), or a `ToggleTextAttributionsRequest` over
  /// the expanded selection otherwise. Bails out silently if there is no selection. Reports the
  /// fresh read state and hands focus back to the editor afterwards, same as [applyBlockType].
  @override
  void applyToggleInlineStyle(OcptInlineStyle style) {
    final selection = _composer.selection;
    if (selection == null) {
      return;
    }

    final attribution = OcptInlineStyleAttributions.attributionOf(style);
    if (selection.isCollapsed) {
      _composer.preferences.toggleStyle(attribution);
    } else {
      _editor.execute([
        ToggleTextAttributionsRequest(documentRange: selection, attributions: {attribution}),
      ]);
    }

    _reportReadStateToController();
    _focusNode.requestFocus();
  }

  /// [_imeOverrides]'s callback: applies the same manual block-type cycle a hardware Tab keystroke
  /// would (`ocptTabToCycleBlockType`), always forward — Shift+Tab never travels through the IME
  /// delta channel [_imeOverrides] intercepts, only a plain Tab does, so there is no reversed case
  /// to handle here.
  void _cycleBlockTypeForwardFromTab() {
    ocptCycleBlockTypeAtSelection(editor: _editor, document: _document, composer: _composer, reversed: false);
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
