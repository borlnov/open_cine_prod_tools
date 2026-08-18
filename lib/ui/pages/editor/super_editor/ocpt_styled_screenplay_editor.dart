// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_clipboard_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_ime_overrides.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_keyboard_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_line_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_inline_style_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_search_match_styler.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scene_numbers.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_title_page_component_builder.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_title_page_guard_requests.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_edit_requests.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_context_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:open_cine_prod_tools/utils/ocpt_script_page_number.dart';
import 'package:open_cine_prod_tools/utils/ocpt_text_search.dart';
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
///
/// While [isPageSimulationEnabled] is on, the document is preceded by a real, always-complete,
/// editable title sheet — one node per title-page field (`OcptWysiwygCodec.decodeWithTitlePage`),
/// empty fields shown as fill-in placeholders, Contact and Source shifted onto Draft date's own
/// row (both `OcptTitlePageComponentBuilder`), laid out at page 1 by `computeOcptStyledPagination`.
/// It disappears entirely while page simulation is off: the fluid, theme-following surface has no
/// notion of a "first page" to put it on, so it stays exactly what it always was, the body alone.
class OcptStyledScreenplayEditor extends StatefulWidget {
  /// The full Fountain source text to edit.
  final String text;

  /// The page setup driving the styled editor's layout metrics.
  final OcptPageSetup pageSetup;

  /// Whether the document is rendered as distinct, real-size "Word-like" paper sheets (white,
  /// black text, even in dark theme) rather than as a fluid, theme-following editing surface.
  ///
  /// Each of those sheets carries the very page number the printed screenplay would show on it
  /// (`_OcptPageSheetsPainter`, [ocptScriptPageNumberLabelOf]). There is nothing to number while
  /// this is off: the fluid surface has no sheets at all.
  final bool isPageSimulationEnabled;

  /// Whether every scene heading shows its scene number (explicit or computed, see
  /// `computeOcptStyledSceneNumbers`) in its left gutter.
  final bool areSceneNumbersVisible;

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
    required this.pageSetup,
    required this.isPageSimulationEnabled,
    required this.areSceneNumbersVisible,
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

  /// The number of leading title-page field nodes [_document] currently starts with (0 while
  /// [OcptStyledScreenplayEditor.isPageSimulationEnabled] is off, since [_decode]/[_encode] then
  /// never synthesize any): every absolute node index into [_document] must have this subtracted
  /// before it means anything to [_mapping], which stays scoped to the body alone (see
  /// [OcptWysiwygDecodeResult.mapping]'s own doc comment).
  int _titlePageNodeCount = 0;

  /// The number of leading characters of the full source text the title page (and its separating
  /// blank line) consumes, mirroring [_titlePageNodeCount] for character offsets instead of node
  /// indices (see [OcptWysiwygDecodeResult.titlePagePrefixLength]).
  int _titlePagePrefixLength = 0;

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

  /// The controller opening/closing the right-click context menu ([OcptEditorContextMenu]), owned
  /// here since [build] is also what positions it, at the tap [_onSecondaryTapUp] resolved.
  final MenuController _contextMenuController = MenuController();

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

  /// The scroll controller handed to `SuperEditor` for its own internal scrolling, owned here (
  /// rather than left to `SuperEditor`'s own default) so the page-simulation background painter in
  /// [build] can read its live offset and keep the painted sheets in sync with the actual scroll
  /// position.
  final ScrollController _pageScrollController = ScrollController();

  /// The number of simulated pages the document currently spans while
  /// [OcptStyledScreenplayEditor.isPageSimulationEnabled] is on (always 0 while it's off),
  /// recomputed by [_recomputePageSimulation].
  int _pageCount = 0;

  /// How many of those [_pageCount] pages the title page takes up before the script itself starts
  /// (always 0 while page simulation is off), recomputed by [_recomputePageSimulation]: the offset
  /// a painted sheet's index needs before it means a **script** page number (see
  /// [OcptStyledPagination.titlePageSheetCount]).
  int _titlePageSheetCount = 0;

  /// The extra bottom padding the stylesheet's `documentPadding` needs so the document's
  /// scrollable content reaches all the way down to the last simulated page's own bottom margin
  /// (always 0 while page simulation is off), recomputed by [_recomputePageSimulation].
  double _trailingBottomPadding = 0;

  /// This widget's own half of the find/replace bar's highlight (plan §6), handed to `SuperEditor`
  /// as a custom style phase in [build]; never rebuilt, so `markDirty()` calls survive across a
  /// [build] rather than resetting the highlight every frame.
  final OcptSearchMatchStyler _searchMatchStyler = OcptSearchMatchStyler();

  /// The find/replace query [updateSearch] last set, or null while there is no active search —
  /// `editor_page.dart` sets this to null whenever the bar is closed, a different mode is active,
  /// or a version is being previewed.
  OcptEditorSearchQuery? _searchQuery;

  /// The current-match index [updateSearch] last set, among the matches [_orderedSearchMatches]
  /// computes for [_searchQuery]; null while there is none.
  int? _searchCurrentMatchIndex;

  @override
  void initState() {
    super.initState();
    _rebuildEditorFrom(widget.text);
    _syncSceneNumbers();
    _recomputePageSimulation();
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
        _recomputePageSimulation();
      });
      _syncSceneNumbers();
      _reportReadStateToController();
      // The document (and every node id it holds) was just rebuilt from scratch: any match this
      // widget computed against the previous one is stale, and must never keep highlighting/
      // navigating against node ids that no longer exist.
      _recomputeSearchMatches(navigateToCurrent: false);
    } else if (widget.isPageSimulationEnabled != oldWidget.isPageSimulationEnabled) {
      // The title sheet's nodes appear/disappear with page simulation itself (see [_decode]'s own
      // doc comment), so toggling it needs a full rebuild from the same text, not just a
      // repagination: unlike the branch above, the text itself hasn't changed at all.
      setState(() {
        _disposeEditor();
        _rebuildEditorFrom(widget.text);
        _recomputePageSimulation();
      });
      _syncSceneNumbers();
      _reportReadStateToController();
      _recomputeSearchMatches(navigateToCurrent: false);
    } else if (widget.pageSetup != oldWidget.pageSetup) {
      setState(_recomputePageSimulation);
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyJumpRequest(jumpRequest.charOffset));
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
    _pageScrollController.dispose();
    super.dispose();
  }

  /// Runs a full pending debounced sync immediately, instead of waiting for [_syncTimer] to fire
  /// on its own, settling a throwaway copy of the document rather than executing requests against
  /// the live [_editor].
  ///
  /// Executing requests against [_editor] from here would be unsafe: [deactivate] (this method's
  /// only caller) can fire while this exact subtree is itself mid-teardown (a mode toggle or
  /// route change both remove this widget as part of an ancestor's own rebuild), and executing an
  /// edit at that point can reach a document-layout component that Flutter has already
  /// deactivated, crashing with "setState() called during build". A scratch [MutableDocument]/
  /// `Editor`, never attached to any widget, carries none of that risk, and settling it before
  /// encoding matters for more than cosmetics: encoding a node under a stale, not-yet-reclassified
  /// `blockType` forces `FountainLineWriter` to bake a forcing-marker character into the output
  /// text for it, and that character comes back on the very next decode as a genuine, sticky,
  /// user-typed forcing marker — corrupting the node for good, well past this one flush.
  void _flushPendingSync() {
    if (_syncTimer == null || !_syncTimer!.isActive) {
      return;
    }
    _syncTimer!.cancel();

    final settledDocument = MutableDocument(nodes: _document.map((node) => node as ParagraphNode).toList());
    final settledComposer = MutableDocumentComposer();
    final settledEditor = Editor(
      editables: {Editor.documentKey: settledDocument, Editor.composerKey: settledComposer},
      requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
        ..insert(0, ocptTitlePageGuardRequestHandler)
        ..add(ocptChangeNodeMetadataRequestHandler)
        ..add(ocptReplaceNodeTextRequestHandler),
    );

    _settleDocument(settledDocument, settledEditor);
    _encodeAndReportIfChanged(settledDocument);

    settledComposer.dispose();
    settledEditor.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = widget.pageSetup.toMetrics();
    final layout = OcptEditorPreviewLayout(metrics: metrics);
    final onSurface = widget.isPageSimulationEnabled ? Colors.black : theme.colorScheme.onSurface;

    final editor = SuperEditor(
      editor: _editor,
      focusNode: _focusNode,
      documentLayoutKey: _documentLayoutKey,
      keyboardActions: ocptFountainKeyboardActions,
      imeOverrides: _imeOverrides,
      scrollController: _pageScrollController,
      componentBuilders: [
        if (widget.areSceneNumbersVisible)
          OcptSceneNumberGutterComponentBuilder.build(
            sceneNumbers: _sceneNumbersFromMetadata(),
            layout: layout,
            textStyle: TextStyle(
              fontFamily: OcptEditorPreviewLayout.fontFamily,
              fontSize: OcptEditorPreviewLayout.fontSize,
              height: layout.lineHeightFactor,
              color: onSurface,
            ),
          ),
        // Only wired up while page simulation is on: title-page nodes never exist otherwise (see
        // `_decode`), so this builder would never match anything, and resolving its placeholder
        // map would be work with nothing to show it on.
        if (widget.isPageSimulationEnabled)
          OcptTitlePageComponentBuilder(
            placeholders: _titlePagePlaceholders(context),
            hintStyleBuilder: (resolvedStyle) =>
                resolvedStyle.copyWith(fontStyle: FontStyle.italic, color: resolvedStyle.color?.withValues(alpha: 0.4)),
            metrics: metrics,
          ),
        ...defaultComponentBuilders,
      ],
      customStylePhases: [_searchMatchStyler],
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
        isPageSimulationEnabled: widget.isPageSimulationEnabled,
        trailingBottomPadding: _trailingBottomPadding,
      ),
    );

    // Material's `ScrollBehavior` would otherwise wrap `SuperEditor`'s internal `Scrollable` in
    // its own implicit `Scrollbar`, painted at the edge of whichever box happens to contain it —
    // i.e. on top of the white page in the page-simulation branch below. Suppressing it here and
    // painting a single explicit `Scrollbar` around the whole panel instead (both branches, so the
    // behaviour is identical with page simulation on or off) keeps the thumb in the panel's gutter.
    //
    // `withNoTextScaling` pins the page's type size to the page's own: `SuperText` otherwise falls
    // back to `MediaQuery.textScalerOf`, so a desktop font-scaling preference would grow every
    // glyph without growing the page it is typeset on — the lines would wrap early and grow taller
    // than the `OcptEditorPreviewLayout` metrics `computeOcptStyledPagination` sized each simulated
    // sheet with, spilling out under its bottom edge. The raw preview pins it the same way, for the
    // same reason (see `OcptEditorPreviewBlock`).
    final editorWithoutImplicitScrollbar = MediaQuery.withNoTextScaling(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: editor,
      ),
    );

    final content = !widget.isPageSimulationEnabled
        ? _buildFluidSurface(theme: theme, editorWithoutImplicitScrollbar: editorWithoutImplicitScrollbar)
        : _buildPageSimulationSurface(theme: theme, layout: layout, editorWithoutImplicitScrollbar: editorWithoutImplicitScrollbar);

    // Wrapped once here, rather than once per branch above: a right-click anywhere over the
    // document — fluid surface or simulated page alike — opens the same context menu. super_editor's
    // own desktop gesture interactor handles no secondary mouse button at all (verified against the
    // pinned `0.3.0-dev.52`), so nothing else ever competes for this gesture.
    //
    // The `Listener` above the gesture detector is what dismisses that menu on a left click landing
    // back on the document (see `_onPointerDownOverDocument`): `MenuAnchor` closes itself on a tap
    // outside its own `TapRegion` group, and its anchor child — everything below here — is part of
    // that group, so the whole editing surface would otherwise be the one place where clicking away
    // left the menu standing. It observes rather than competes: a `Listener` never enters the
    // gesture arena, so the click it sees still reaches super_editor and places the caret.
    //
    // No entry is ever withheld for a read-only preview here: `editor_page.dart`'s `_buildCentre`
    // substitutes the read-only `OcptEditorPreview` for both editing modes while a version is being
    // previewed, so this widget — and the menu it opens — is simply never mounted under one. There is
    // no `isReadOnly` flag to thread through because there is nothing here that would ever need one.
    return OcptEditorContextMenu(
      controller: _contextMenuController,
      childFocusNode: _focusNode,
      currentType: _contextMenuBlockType,
      onCut: _hasExpandedSelection ? _cutSelectionFromContextMenu : null,
      onCopy: _hasExpandedSelection ? _copySelectionFromContextMenu : null,
      onPaste: _composer.selection != null ? _pasteFromContextMenu : null,
      onSelectAll: _composer.selection != null ? _selectAllFromContextMenu : null,
      onTypeSelected: _contextMenuBlockType != null ? applyBlockType : null,
      child: Listener(
        onPointerDown: _onPointerDownOverDocument,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapUp: _onSecondaryTapUp,
          child: content,
        ),
      ),
    );
  }

  /// The fluid, theme-following editing surface [build] shows while
  /// [OcptStyledScreenplayEditor.isPageSimulationEnabled] is off: no sheets, no page numbers, just
  /// [editorWithoutImplicitScrollbar] on the themed surface colour, scrollable.
  Widget _buildFluidSurface({required ThemeData theme, required Widget editorWithoutImplicitScrollbar}) => Scrollbar(
    controller: _pageScrollController,
    child: ColoredBox(color: theme.colorScheme.surface, child: editorWithoutImplicitScrollbar),
  );

  /// The paper-simulated editing surface [build] shows while
  /// [OcptStyledScreenplayEditor.isPageSimulationEnabled] is on: real-size white sheets behind
  /// [editorWithoutImplicitScrollbar], scaled to fit a panel narrower than [layout]'s own page width.
  /// The inline comments below are the authority on every geometry decision it makes: why the editor
  /// is only as wide as the content area, why it is shifted back by one padding inset, and why the
  /// sheets are painted rather than laid out.
  Widget _buildPageSimulationSurface({
    required ThemeData theme,
    required OcptEditorPreviewLayout layout,
    required Widget editorWithoutImplicitScrollbar,
  }) {
    // Page simulation: the document is centered at the physical page width, with a themed
    // backdrop (matching the app's theme) on either side, and a white sheet painted behind it per
    // simulated page (see `_OcptPageSheetsPainter`); `OcptFountainEditorStylesheet` already
    // switched to fixed paper colors above, since a theme-derived color could otherwise render
    // invisible on that white backdrop.
    //
    // `editor` itself is only as wide as the page's content area (`pageWidth - marginRight`), left
    // -aligned within the full `pageWidth` box, rather than centered at `pageWidth` directly: every
    // "full width" element's `Styles.maxWidth` (see `OcptFountainEditorStylesheet._rule`) already
    // equals that same content-area width by construction, so super_editor's single-column layout,
    // which centers each block's box within its own parent, now has nothing left to center against
    // — the box fills its parent exactly, flush with the page's left edge. Centering `editor` at
    // the full `pageWidth` instead (a prior version of this code did) left it half a right margin's
    // width of that centering slack on the left, and half on the right, visibly swallowing the
    // right margin. The reserved `marginRight`-wide strip on the right stays part of the white
    // sheet (still `pageWidth` wide, painted by `_OcptPageSheetsPainter`), just with no text.
    //
    // The editor's box is additionally widened by the stylesheet's horizontal `documentPadding`
    // inset on each side, and shifted back left by one inset, so that the *content area* left
    // inside that padding — not the box itself — is what lands flush on the page's left edge and
    // spans exactly the content width. Without this compensation the inset would eat into the width
    // available to every block's `Styles.maxWidth`, silently clamping each element one inset
    // narrower on each side, so the styled editor would wrap its text a couple of columns earlier
    // than the raw preview typesets the very same line.
    const inset = OcptFountainEditorStylesheet.horizontalDocumentPaddingInset;
    return Scrollbar(
      controller: _pageScrollController,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: LayoutBuilder(
          builder: (context, constraints) => _scaledToFit(
            constraints: constraints,
            pageWidth: layout.pageWidth,
            page: Stack(
              children: [
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: _pageScrollController,
                    builder: (context, child) => CustomPaint(
                      painter: _OcptPageSheetsPainter(
                        pageCount: _pageCount,
                        titlePageSheetCount: _titlePageSheetCount,
                        pageHeight: layout.pageHeight,
                        pageGap: OcptEditorPreviewLayout.pageGap,
                        pageNumberTop: ocptScriptPageNumberTopInches * layout.pixelsPerInch,
                        pageNumberRight: layout.pageWidth - layout.marginRight,
                        // The sheets are white whatever the app's theme is, so the number is painted
                        // in the same fixed paper colors `OcptFountainEditorStylesheet` switches to
                        // under page simulation — a theme-derived color could render invisible on
                        // that white backdrop — and at the body's own size and family, since that is
                        // what the PDF prints it at.
                        pageNumberStyle: const TextStyle(
                          fontFamily: OcptEditorPreviewLayout.fontFamily,
                          fontSize: OcptEditorPreviewLayout.fontSize,
                          color: Colors.black,
                        ),
                        scrollOffset: _pageScrollController.hasClients ? _pageScrollController.offset : 0,
                      ),
                    ),
                  ),
                ),
                // Deliberately an `Align` (a *non-positioned* Stack child) shifted by a `Transform`,
                // rather than a `Positioned(left: -inset)`: the `Stack` sizes itself to its
                // non-positioned children, so making every child positioned would leave it sizing to
                // its incoming constraints instead, handing `SuperEditor` a differently-constrained
                // viewport — which, in turn, breaks its IME connection (`editor_page_test.dart`'s
                // "an edit made in styled mode survives switching back to raw mode" catches exactly
                // that).
                Align(
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: const Offset(-inset, 0),
                    child: SizedBox(
                      width: layout.pageWidth - layout.marginRight + inset * 2,
                      child: editorWithoutImplicitScrollbar,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Lays [page] out at its true [pageWidth] and, when [constraints] are narrower than that, scales
  /// the whole thing down to fit rather than letting it be squeezed.
  ///
  /// A page whose width is squeezed is not a smaller page: every block's `Styles.maxWidth` is an
  /// absolute pixel width taken from the page metrics, so a narrower box makes each line wrap several
  /// columns early, and those surplus lines make every simulated page render taller than the sheet
  /// `computeOcptStyledPagination` sized for it — the text then runs out under the sheet's bottom
  /// edge, page after page. Scaling instead keeps the page's proportions, its margins and its wrap
  /// points exactly right at any panel width, which is what the raw preview already does
  /// (`OcptEditorPreview`, whose doc comment explains why fitting beats cropping here).
  ///
  /// [BoxConstraints.maxHeight] is divided by the same scale so the scaled-down viewport still fills
  /// the panel vertically, and this must be a [FittedBox] rather than a [Transform.scale] around a
  /// wide [SizedBox]: under the tight width constraint the panel hands down, a plain [SizedBox]
  /// silently clamps back to that width instead of achieving the page's own (see `OcptEditorPreview`
  /// for the same trap).
  Widget _scaledToFit({
    required BoxConstraints constraints,
    required double pageWidth,
    required Widget page,
  }) {
    final sizedPage = SizedBox(width: pageWidth, child: page);
    if (constraints.maxWidth >= pageWidth) {
      return Center(child: sizedPage);
    }

    final scale = constraints.maxWidth / pageWidth;
    return FittedBox(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: pageWidth,
        // Only when the panel actually bounds this editor's height, which is what a workspace dock
        // row does; left to the child otherwise, since dividing an unbounded height by the scale
        // would size the box to infinity.
        height: constraints.hasBoundedHeight ? constraints.maxHeight / scale : null,
        child: sizedPage,
      ),
    );
  }

  /// The scene number to show next to every scene-heading node currently in [_document], keyed
  /// by node id, read straight off each node's [ocptSceneNumberMetadataKey] metadata.
  ///
  /// By the time this is called (every [build]), that metadata is already correct: it was set by
  /// [OcptWysiwygCodec.decode] for an explicit tag, or normalized by [_syncSceneNumbers]/
  /// [_syncAfterEdit]'s own `sceneNumberNormalizationRequests` pass right after every rebuild or
  /// edit, so this is a plain read, not a fresh computation.
  Map<String, String> _sceneNumbersFromMetadata() {
    final numbers = <String, String>{};
    for (final node in _document) {
      if (node is! ParagraphNode) {
        continue;
      }
      final type = OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
      if (type != FountainLineType.sceneHeading) {
        continue;
      }
      final value = node.getMetadataValue(ocptSceneNumberMetadataKey);
      if (value is String) {
        numbers[node.id] = value;
      }
    }
    return numbers;
  }

  /// The placeholder text shown on an empty title-page field, keyed by
  /// [ocptTitlePageFieldKeys]: the field's own label in the `⋮ ▸ Title page…` dialog
  /// (`OcptEditorTitlePageDialog`), so the two front-ends of the same title page never disagree on
  /// what to call a field.
  Map<String, String> _titlePagePlaceholders(BuildContext context) {
    final tr = Tr.of(context);
    return {
      "Title": tr.editorTitlePageTitleLabel,
      "Credit": tr.editorTitlePageCreditLabel,
      "Author": tr.editorTitlePageAuthorLabel,
      "Draft date": tr.editorTitlePageDraftDateLabel,
      "Contact": tr.editorTitlePageContactLabel,
      "Source": tr.editorTitlePageSourceLabel,
    };
  }

  /// Builds [_document], [_composer] and [_editor] from [text], and starts listening to document
  /// and selection changes.
  ///
  /// [_lastSyncedText] is set to [text] so this rebuild is never mistaken, on the very next
  /// widget update, for an external change to `widget.text`.
  void _rebuildEditorFrom(String text) {
    _lastSyncedText = text;
    _lastReportedLine = 0;

    final decoded = _decode(text);
    _document = decoded.document;
    _mapping = decoded.mapping;
    _trailingBlankLines = decoded.trailingBlankLines;
    _titlePageNodeCount = decoded.titlePageNodeCount;
    _titlePagePrefixLength = decoded.titlePagePrefixLength;
    _composer = MutableDocumentComposer();
    _editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: _composer},
      requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
        ..insert(0, ocptTitlePageGuardRequestHandler)
        ..add(ocptChangeNodeMetadataRequestHandler)
        ..add(ocptReplaceNodeTextRequestHandler),
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

    if (_searchQuery == null) {
      return;
    }
    // Live, not debounced, for the same reason the toolbar's read state above isn't either: the
    // raw mode's own highlight tracks every keystroke through its text controller directly (see
    // `OcptEditorSearchTextController`), and the styled mode must not visibly lag behind it.
    // `navigateToCurrent: false` is what keeps typing elsewhere in the document from yanking the
    // caret back onto "the current match" on every keystroke — only an actual navigation
    // ([updateSearch]) does that, mirroring `_syncRawSearch`'s own split between reporting and
    // navigating.
    //
    // Deferred to a post-frame callback rather than run right here: this listener fires
    // synchronously from inside `Editor.execute()`'s own transaction (`document.onTransactionEnd`,
    // called before the composer's selection is necessarily fixed up for a node this same edit
    // just removed), and `_searchMatchStyler.updateMatches`'s `markDirty()` triggers an immediate
    // re-style pass — running it this early crashes deep inside super_editor's own selection
    // styler on a delete/cut whose selection request hasn't landed yet. A post-frame callback runs
    // well after that same transaction (and its selection fix-up) has fully settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchQuery != null) {
        _recomputeSearchMatches(navigateToCurrent: false);
      }
    });
  }

  /// Rejoins the document into flat text (reporting it upstream if it changed), refreshes
  /// [_mapping] for that freshly encoded text, and re-classifies every line plus every note's
  /// attribution span, only touching the metadata of the nodes that actually need it.
  void _syncAfterEdit() {
    if (!mounted) {
      return;
    }

    _settleDocument(_document, _editor);
    _encodeAndReportIfChanged();

    final previousPageCount = _pageCount;
    final previousTrailingBottomPadding = _trailingBottomPadding;
    _recomputePageSimulation();
    if (_pageCount != previousPageCount || _trailingBottomPadding != previousTrailingBottomPadding) {
      setState(() {});
    }
  }

  /// Brings every node of [document] (executed through [editor]) to the same settled state
  /// [_syncAfterEdit] and [_flushPendingSync] both need before their text can be safely encoded:
  /// live `#N#` tags absorbed, every `blockType` reclassified from current text, note/uppercase
  /// spans refreshed, and scene numbers renumbered — in that order, each its own `execute` call so
  /// every later pass only ever sees the previous one's already-settled result.
  static void _settleDocument(MutableDocument document, Editor editor) {
    // Run before every other pass, and in its own `execute` call: a `#N#` tag typed live still
    // sits in the node's plain text at this point, and both this pass and `uppercaseRequests`
    // would otherwise compute their replacement text from that same pre-strip snapshot, so
    // whichever request executed last would silently undo the other's effect on the same node.
    final sceneNumberRequests = OcptWysiwygCodec.sceneNumberRequests(document);
    if (sceneNumberRequests.isNotEmpty) {
      editor.execute(sceneNumberRequests);
    }

    // Reclassifies every node's `blockType` (and refreshes note attributions/uppercasing) BEFORE
    // scene numbers are counted or the text is reported upstream: a node whose type just changed
    // as a side effect of this same edit (e.g. an Enter split leaving a fragment that no longer
    // reads as a scene heading) must never be counted as a scene, or reported in the encoded text
    // as one, even for the single tick before the next debounce would otherwise have caught it —
    // and, critically, must never be encoded under its stale type either: `FountainLineWriter`
    // would then have no choice but to bake a literal forcing-marker character into the output for
    // a node whose stored type doesn't match its own text, and that character comes back on the
    // very next decode as a genuine, sticky, user-typed forcing marker.
    final requests = [
      ...OcptWysiwygCodec.reclassifyRequests(document),
      ...OcptWysiwygCodec.noteAttributionRequests(document),
      ...OcptWysiwygCodec.uppercaseRequests(document),
    ];
    if (requests.isNotEmpty) {
      editor.execute(requests);
    }

    // Renumbers every scene heading (see `sceneNumberNormalizationRequests`'s own doc comment),
    // in its own `execute` call so it always runs against final, already-reclassified block types:
    // inserting, deleting or retyping a heading anywhere can shift every number after it, not just
    // the one being edited.
    final normalizationRequests = sceneNumberNormalizationRequests(document);
    if (normalizationRequests.isNotEmpty) {
      editor.execute(normalizationRequests);
    }
  }

  /// Renumbers every scene heading immediately (not debounced) and reports the corrected text
  /// upstream if it changed, right after [_rebuildEditorFrom] rebuilds the document from fresh
  /// text: this is what corrects a badly-ordered `#N#` typed in raw mode (or by any other means)
  /// the moment it's decoded into the styled editor, rather than waiting for the next edit's
  /// [_syncAfterEdit] debounce to happen to touch a scene heading.
  void _syncSceneNumbers() {
    final requests = sceneNumberNormalizationRequests(_document);
    if (requests.isEmpty) {
      return;
    }
    _editor.execute(requests);
    _encodeAndReportIfChanged();
  }

  /// The exact top padding (in logical pixels) [node] currently carries in
  /// [ocptStartsNewPageMetadataKey] metadata, or 0 if it doesn't start a page.
  static double _pageStartPaddingOf(ParagraphNode node) {
    final value = node.getMetadataValue(ocptStartsNewPageMetadataKey);
    return value is double ? value : 0;
  }

  /// Recomputes which nodes start a fresh simulated page (their exact top padding stored as
  /// [ocptStartsNewPageMetadataKey] metadata, read by `OcptFountainEditorStylesheet`'s
  /// page-boundary spacing), [_pageCount] and [_trailingBottomPadding], for the current document,
  /// [OcptStyledScreenplayEditor.isPageSimulationEnabled] and [OcptStyledScreenplayEditor
  /// .pageSetup].
  ///
  /// While page simulation is off, this only clears any padding left over from before it was
  /// turned off (so turning it back on later starts pagination from a clean slate) and resets
  /// [_pageCount]/[_trailingBottomPadding] to 0. Only mutates those fields and executes editor
  /// requests, neither of which needs `setState` from [initState]; every other caller wraps this
  /// in its own `setState`.
  void _recomputePageSimulation() {
    if (!widget.isPageSimulationEnabled) {
      final clearRequests = <EditRequest>[
        for (final node in _document)
          if (node is ParagraphNode && _pageStartPaddingOf(node) != 0)
            OcptChangeNodeMetadataRequest(nodeId: node.id, metadata: {ocptStartsNewPageMetadataKey: 0.0}),
      ];
      if (clearRequests.isNotEmpty) {
        _editor.execute(clearRequests);
      }
      _pageCount = 0;
      _titlePageSheetCount = 0;
      _trailingBottomPadding = 0;
      return;
    }

    final metrics = widget.pageSetup.toMetrics();
    final pagination = computeOcptStyledPagination(document: _document, metrics: metrics);

    final requests = <EditRequest>[
      for (final node in _document)
        if (node is ParagraphNode)
          if (_pageStartPaddingOf(node) != (pagination.pageStartTopPaddings[node.id] ?? 0.0))
            OcptChangeNodeMetadataRequest(
              nodeId: node.id,
              metadata: {ocptStartsNewPageMetadataKey: pagination.pageStartTopPaddings[node.id] ?? 0.0},
            ),
    ];
    if (requests.isNotEmpty) {
      _editor.execute(requests);
    }
    _pageCount = pagination.pageCount;
    _titlePageSheetCount = pagination.titlePageSheetCount;
    _trailingBottomPadding = pagination.trailingBottomPadding;
  }

  /// Encodes [document] (defaulting to [_document]) back to text, refreshes [_mapping] for it, and
  /// reports the new text upstream if it actually changed. [_flushPendingSync] passes its own
  /// throwaway, already-settled document copy instead of the default, so a flush never has to run
  /// [_editor] commands (see that method's own doc comment for why that matters).
  void _encodeAndReportIfChanged([Document? document]) {
    final encoded = _encode(document ?? _document, trailingBlankLines: _trailingBlankLines);
    _mapping = encoded.mapping;
    _titlePageNodeCount = encoded.titlePageNodeCount;
    _titlePagePrefixLength = encoded.titlePagePrefixLength;
    if (encoded.text != _lastSyncedText) {
      _lastSyncedText = encoded.text;
      widget.onTextChanged(encoded.text);
    }
  }

  /// Decodes [text] through [OcptWysiwygCodec.decodeWithTitlePage] while
  /// [OcptStyledScreenplayEditor.isPageSimulationEnabled] is on (the title sheet is only ever shown
  /// in page mode, matching the raw preview's own paper-only page simulation), or plain
  /// [OcptWysiwygCodec.decode] otherwise, so the fluid, theme-following surface stays exactly what
  /// it always was: the body alone, no title-page nodes at all.
  OcptWysiwygDecodeResult _decode(String text) =>
      widget.isPageSimulationEnabled ? OcptWysiwygCodec.decodeWithTitlePage(text) : OcptWysiwygCodec.decode(text);

  /// The [_decode] counterpart for encoding, switching between
  /// [OcptWysiwygCodec.encodeWithTitlePage] and [OcptWysiwygCodec.encode] the same way.
  OcptWysiwygEncodeResult _encode(Document document, {required int trailingBlankLines}) =>
      widget.isPageSimulationEnabled
      ? OcptWysiwygCodec.encodeWithTitlePage(document, trailingBlankLines: trailingBlankLines)
      : OcptWysiwygCodec.encode(document, trailingBlankLines: trailingBlankLines);

  /// Reports the source line the caret moved to, whenever the composer's selection changes to a
  /// different node, resolved through [_mapping] (a node's index is no longer always its source
  /// line, now that blank source lines are folded into metadata instead of being their own node).
  void _onSelectionChanged() {
    final nodeId = _composer.selection?.extent.nodeId;
    if (nodeId != null) {
      final nodeIndex = _document.getNodeIndexById(nodeId);
      // A negative index means "not found"; an index below `_titlePageNodeCount` means the caret
      // sits in a title-page field, which has no source-line concept `_mapping` (body-scoped, see
      // its own doc comment) can resolve — the raw preview/scene panel simply keep showing
      // whichever body line was last reported, whichever came first.
      if (nodeIndex >= _titlePageNodeCount) {
        final line = _mapping.lineOfNodeIndex(nodeIndex - _titlePageNodeCount);
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
  /// like the Tab-cycle gesture does — plus, when [type] is [FountainLineType.parenthetical] and
  /// the node's text is still empty, inserts `()` and places the caret between the two parentheses
  /// (see `ocptParentheticalTemplateRequests`, the same helper the Tab cycle and smart-Enter use, so
  /// all three gestures behave identically) — then reports the fresh read state and hands focus
  /// straight back to the editor — the toolbar's dropdown must never keep the keyboard focus it
  /// briefly took to open.
  @override
  void applyBlockType(FountainLineType type) {
    final selection = _composer.selection;
    if (selection == null) {
      return;
    }

    final node = _document.getNodeById(selection.extent.nodeId);
    if (node is! ParagraphNode || OcptWysiwygCodec.isTitlePageNode(node)) {
      return;
    }

    _editor.execute([
      ...ocptManualBlockTypeRequests(nodeId: node.id, type: type),
      ...ocptParentheticalTemplateRequests(nodeId: node.id, type: type, isNodeEmpty: node.text.isEmpty),
    ]);
    _reportReadStateToController();
    _focusNode.requestFocus();
  }

  /// Whether [_composer]'s current selection is expanded, i.e. there is something for the
  /// right-click context menu's Cut/Copy entries to act on: read fresh on every [build], so it
  /// always reflects whatever [_onSecondaryTapUp] just resolved before forcing that rebuild (see
  /// that method's own doc comment).
  bool get _hasExpandedSelection {
    final selection = _composer.selection;
    return selection != null && !selection.isCollapsed;
  }

  /// The block type the right-click context menu's submenu should show as selected, or null when
  /// the caret sits on no block that can be retyped — no selection at all, a node that isn't a
  /// `ParagraphNode`, or a title-page field (mirrors [applyBlockType]'s own guard, since picking a
  /// type from the submenu ultimately calls it). [OcptEditorContextMenu] also reads this null-ness
  /// to decide whether the submenu appears at all.
  FountainLineType? get _contextMenuBlockType {
    final selection = _composer.selection;
    if (selection == null) {
      return null;
    }

    final node = _document.getNodeById(selection.extent.nodeId);
    if (node is! ParagraphNode || OcptWysiwygCodec.isTitlePageNode(node)) {
      return null;
    }

    return OcptFountainLineAttributions.typeOfAttributionValue(node.getMetadataValue("blockType"));
  }

  /// Resolves the document position under a right-click and opens [_contextMenuController] there.
  ///
  /// [details]' global position is converted to the document layout's own local coordinates through
  /// [DocumentLayout.getDocumentOffsetFromAncestorOffset] — a thin wrapper, on the pinned
  /// `0.3.0-dev.52`, around that exact layout's own `RenderBox.globalToLocal` — never the gesture
  /// detector's own local offset: that's what keeps this correct under the page-simulation
  /// `FittedBox` scaling, which the raw local offset would otherwise silently ignore. (The layout's
  /// box itself isn't reachable through [_documentLayoutKey] directly: `SuperEditor` wraps it in a
  /// `SliverToBoxAdapter` internally, so walking down from that key's own element lands on the
  /// sliver's render object, not the box.)
  ///
  /// A collapsed caret is placed at that position unless it already sits inside an expanded
  /// selection — right-clicking inside a selection must never destroy it, which is the whole point
  /// of the Cut/Copy entries the menu is about to show. Either way, `setState` runs before the menu
  /// opens: nothing about a selection change (placing this exact caret included) schedules a
  /// rebuild of this widget on its own (see [_onSelectionChanged]'s own doc comment on why a
  /// separate read-state channel exists for the toolbar), so without it [build] would hand
  /// [OcptEditorContextMenu] the *previous* selection's Cut/Copy/submenu availability instead of the
  /// one this tap just settled on.
  void _onSecondaryTapUp(TapUpDetails details) {
    final layout = _documentLayoutKey.currentState as DocumentLayout?;
    if (layout == null) {
      return;
    }

    final documentOffset = layout.getDocumentOffsetFromAncestorOffset(details.globalPosition);
    final position = layout.getDocumentPositionNearestToOffset(documentOffset);
    if (position == null) {
      return;
    }

    final selection = _composer.selection;
    final tapIsInsideSelection =
        selection != null && !selection.isCollapsed && _document.doesSelectionContainPosition(selection, position);
    if (!tapIsInsideSelection) {
      _editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(position: position),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
    }

    setState(() {});
    _contextMenuController.open(position: details.localPosition);
  }

  /// Closes the right-click context menu when a left click lands anywhere on the document while it
  /// is open, the way clicking away from a menu closes it everywhere else in the app.
  ///
  /// Only the primary button does this: the secondary button is what opens the menu in the first
  /// place ([_onSecondaryTapUp] runs on its tap *up*, after this very handler has seen its down),
  /// and closing on it would make a second right-click a toggle rather than a re-position. Clicks
  /// on the menu itself never reach here — it is an overlay painted above this surface, and it
  /// absorbs its own pointers.
  void _onPointerDownOverDocument(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton || !_contextMenuController.isOpen) {
      return;
    }

    _contextMenuController.close();
  }

  /// The right-click context menu's Copy entry: copies the current selection's Fountain source to
  /// the clipboard through [ocptCopySelectionToClipboard], the same helper the Ctrl+C key handler
  /// uses, so the payload is the exact same plain Fountain text whichever gesture asks for it. Hands
  /// focus back to the editor afterwards, same as [applyBlockType].
  void _copySelectionFromContextMenu() {
    final selection = _composer.selection;
    if (selection == null) {
      return;
    }

    ocptCopySelectionToClipboard(document: _document, selection: selection);
    _focusNode.requestFocus();
  }

  /// The right-click context menu's Cut entry: the same copy as [_copySelectionFromContextMenu],
  /// followed by deleting the selection, mirroring the Ctrl+X key handler.
  void _cutSelectionFromContextMenu() {
    final selection = _composer.selection;
    if (selection == null) {
      return;
    }

    ocptCopySelectionToClipboard(document: _document, selection: selection);
    _editor.execute(const [DeleteSelectionRequest(TextAffinity.downstream)]);
    _focusNode.requestFocus();
  }

  /// The right-click context menu's Paste entry: [ocptPasteFountainClipboardContent], the same
  /// Fountain-aware paste the Ctrl+V key handler uses.
  void _pasteFromContextMenu() {
    unawaited(ocptPasteFountainClipboardContent(editor: _editor, document: _document, composer: _composer));
    _focusNode.requestFocus();
  }

  /// The right-click context menu's Select all entry: expands the selection across the whole
  /// document, mirroring super_editor's own `CommonEditorOperations.selectAll`. A no-op on an empty
  /// document (which [_document] never actually is once the menu can open, but this mirrors that
  /// operation's own defensive guard).
  void _selectAllFromContextMenu() {
    if (_document.isEmpty) {
      return;
    }

    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(nodeId: _document.first.id, nodePosition: _document.first.beginningPosition),
          extent: DocumentPosition(nodeId: _document.last.id, nodePosition: _document.last.endPosition),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
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

  /// Every current match of [_searchQuery], in document order (node order, then offset within the
  /// node) — the single computation [_recomputeSearchMatches], [replaceCurrentMatch] and
  /// [replaceAllMatches] all go through, so none of them can drift from what the highlight
  /// actually shows.
  ///
  /// Only [ParagraphNode]s are searched, which title-page field nodes are too (see
  /// `OcptWysiwygCodec`): they sit on screen and are ordinarily editable
  /// (`ocptTitlePageGuardRequestHandler` permits ordinary text edits inside a field, only guarding
  /// against merging or deleting the node itself), so a search that skipped them would miss text
  /// the user can plainly see and type into. This is also why the styled mode's own match count
  /// changes with the page-simulation toggle: the title sheet, and every field on it, only exists
  /// at all while page simulation is on (see [_decode]'s own doc comment).
  List<({String nodeId, OcptTextMatch match})> _orderedSearchMatches(OcptEditorSearchQuery query) {
    final matches = <({String nodeId, OcptTextMatch match})>[];
    for (final node in _document) {
      if (node is! ParagraphNode) {
        continue;
      }
      for (final match in query.matchesIn(node.text.toPlainText())) {
        matches.add((nodeId: node.id, match: match));
      }
    }
    return matches;
  }

  /// Recomputes every match of [_searchQuery] over the live document's own display text, feeds
  /// them to [_searchMatchStyler], reports the total count to
  /// [OcptStyledScreenplayEditor.styledController], and — only when [navigateToCurrent] is true —
  /// places the selection on [_searchCurrentMatchIndex]'s match and scrolls it into view (see
  /// [_navigateToSearchMatch]'s own doc comment on why that never takes keyboard focus).
  void _recomputeSearchMatches({required bool navigateToCurrent}) {
    final query = _searchQuery;
    if (query == null) {
      _searchMatchStyler.updateMatches(matchesByNodeId: const {}, currentMatchNodeId: null, currentMatch: null);
      widget.styledController?.reportSearchMatchCount(0);
      return;
    }

    final orderedMatches = _orderedSearchMatches(query);
    final matchesByNodeId = <String, List<OcptTextMatch>>{};
    for (final entry in orderedMatches) {
      (matchesByNodeId[entry.nodeId] ??= []).add(entry.match);
    }

    widget.styledController?.reportSearchMatchCount(orderedMatches.length);

    final currentIndex = _searchCurrentMatchIndex;
    final current = currentIndex != null && currentIndex >= 0 && currentIndex < orderedMatches.length
        ? orderedMatches[currentIndex]
        : null;

    _searchMatchStyler.updateMatches(
      matchesByNodeId: matchesByNodeId,
      currentMatchNodeId: current?.nodeId,
      currentMatch: current?.match,
    );

    if (navigateToCurrent && current != null) {
      _navigateToSearchMatch(current.nodeId, current.match);
    }
  }

  /// Selects [match] inside the node [nodeId] and scrolls it into view, the styled mode's own
  /// counterpart to [_applyJumpRequest] — **deliberately never calls `_focusNode.requestFocus()`**:
  /// the find field must keep the keyboard focus while the user types a query or presses
  /// Next/Previous. `build`'s `selectionPolicies` already sets
  /// `clearSelectionWhenEditorLosesFocus: false` on this exact editor for that reason, so the
  /// selection placed here survives staying unfocused.
  ///
  /// The scroll itself runs in a post-frame callback, unlike [_applyJumpRequest]'s own synchronous
  /// call: unlike a scene jump (always triggered from an already-built frame), this can run from
  /// [OcptStyledEditorController.attach] inside `initState`, before the document layout — and with
  /// it, [_documentLayoutKey]'s own component lookup — exists for this build at all.
  void _navigateToSearchMatch(String nodeId, OcptTextMatch match) {
    if (!mounted || _document.getNodeById(nodeId) == null) {
      return;
    }

    _editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: match.start)),
          extent: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: match.end)),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final component = (_documentLayoutKey.currentState as DocumentLayout?)?.getComponentByNodeId(nodeId);
      if (component == null) {
        return;
      }
      final componentState = component as State;
      if (componentState.mounted) {
        unawaited(
          Scrollable.ensureVisible(componentState.context, alignment: 0.3, duration: const Duration(milliseconds: 200)),
        );
      }
    });
  }

  /// Replaces the find/replace query and current-match index this widget highlights/navigates to,
  /// then immediately recomputes and (re-)navigates — see [_recomputeSearchMatches]'s own doc
  /// comment on when it does each.
  @override
  void updateSearch({required OcptEditorSearchQuery? query, required int? currentMatchIndex}) {
    _searchQuery = query;
    _searchCurrentMatchIndex = currentMatchIndex;
    _recomputeSearchMatches(navigateToCurrent: true);
  }

  /// Replaces the current match (see `_orderedSearchMatches`) with [replacement] and returns the
  /// index, among the fresh matches left afterwards, of the first one starting at or past the end
  /// of what was just written — never simply the match now sitting at the same index, which a
  /// replacement that itself still matches the query (`MARIE` → `MARIE-JEANNE`) would land back
  /// inside, compounding on every further `Replace` press (see
  /// `OcptStyledEditorControllerDelegate.replaceCurrentMatch`'s own doc comment). Returns null,
  /// doing nothing, while there is no current match, or once none remain after the edit.
  ///
  /// The comparison walks the fresh matches in document order (built once as a node-id → node-index
  /// map, `nodeIndexById`, rather than calling `Document.getNodeIndexById` per candidate): a match
  /// in a node past the edited one always counts as "after", whatever its own offset.
  @override
  int? replaceCurrentMatch(String replacement) {
    final query = _searchQuery;
    final currentIndex = _searchCurrentMatchIndex;
    if (query == null || currentIndex == null) {
      return null;
    }

    final matches = _orderedSearchMatches(query);
    if (currentIndex < 0 || currentIndex >= matches.length) {
      return null;
    }

    final current = matches[currentIndex];
    final node = _document.getNodeById(current.nodeId);
    if (node is! ParagraphNode) {
      return null;
    }

    _editor.execute([
      OcptReplaceNodeTextRequest(
        nodeId: node.id,
        text: _ocptReplaceMatchesInText(node.text, [current.match], replacement),
      ),
    ]);

    final writtenEnd = current.match.start + replacement.length;
    final freshMatches = _orderedSearchMatches(query);
    if (freshMatches.isEmpty) {
      return null;
    }

    final nodeIndexById = <String, int>{
      for (var i = 0; i < _document.nodeCount; i++) _document.getNodeAt(i)!.id: i,
    };
    final currentNodeIndex = nodeIndexById[current.nodeId] ?? 0;
    final nextIndex = freshMatches.indexWhere((entry) {
      final entryNodeIndex = nodeIndexById[entry.nodeId] ?? 0;
      if (entryNodeIndex != currentNodeIndex) {
        return entryNodeIndex > currentNodeIndex;
      }
      return entry.match.start >= writtenEnd;
    });
    return nextIndex == -1 ? 0 : nextIndex;
  }

  /// Replaces every current match of [_searchQuery] with [replacement], one
  /// [OcptReplaceNodeTextRequest] per node carrying at least one match, grouped into a single
  /// [Editor.execute] call. A no-op while there is no active search or it matches nothing.
  @override
  void replaceAllMatches(String replacement) {
    final query = _searchQuery;
    if (query == null) {
      return;
    }

    final matchesByNodeId = <String, List<OcptTextMatch>>{};
    for (final node in _document) {
      if (node is! ParagraphNode) {
        continue;
      }
      final nodeMatches = query.matchesIn(node.text.toPlainText());
      if (nodeMatches.isNotEmpty) {
        matchesByNodeId[node.id] = nodeMatches;
      }
    }
    if (matchesByNodeId.isEmpty) {
      return;
    }

    _editor.execute([
      for (final entry in matchesByNodeId.entries)
        OcptReplaceNodeTextRequest(
          nodeId: entry.key,
          text: _ocptReplaceMatchesInText(
            (_document.getNodeById(entry.key)! as ParagraphNode).text,
            entry.value,
            replacement,
          ),
        ),
    ]);
  }

  /// Returns a copy of [original] with every one of [matches] (assumed non-overlapping and in
  /// left-to-right order, exactly as `OcptEditorSearchQuery.matchesIn` returns them) replaced by
  /// [replacement], every untouched span keeping its original attributions (`copyText` carries
  /// them along; only the freshly-inserted [replacement] text itself carries none).
  static AttributedText _ocptReplaceMatchesInText(
    AttributedText original,
    List<OcptTextMatch> matches,
    String replacement,
  ) {
    var result = original.copyText(0, 0);
    var cursor = 0;
    for (final match in matches) {
      result = result.copyAndAppend(original.copyText(cursor, match.start));
      if (replacement.isNotEmpty) {
        result = result.copyAndAppend(AttributedText(replacement));
      }
      cursor = match.end;
    }
    return result.copyAndAppend(original.copyText(cursor));
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

    // [charOffset] is always relative to the full source text (scenes only ever exist in the
    // body, so it's always at or past the title page's own prefix, but the subtraction is clamped
    // defensively anyway); `_mapping` itself is body-scoped, so its own resolved node index needs
    // `_titlePageNodeCount` added back before it means anything to `_document`.
    final bodyCharOffset = charOffset <= _titlePagePrefixLength ? 0 : charOffset - _titlePagePrefixLength;
    final nodeIndex = _mapping.nodeIndexOfCharOffset(bodyCharOffset) + _titlePageNodeCount;
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
        Scrollable.ensureVisible(componentState.context, alignment: 0.3, duration: const Duration(milliseconds: 200)),
      );
    }
  }
}

/// Paints one white, lightly rounded rectangle per simulated page behind the styled editor's
/// document — and, on every sheet the printed screenplay numbers, that page's own number — with one
/// call site in [_OcptStyledScreenplayEditorState.build].
///
/// Positioned deterministically from [pageCount]/[pageHeight]/[pageGap] alone — page N starts at
/// `N * (pageHeight + pageGap)` — and shifted by [scrollOffset] to stay behind the actually
/// scrolled content. This is an estimate, like the rest of the page-simulation feature: the extra
/// top padding `OcptFountainEditorStylesheet` opens up above a page-starting node doesn't
/// necessarily sum to exactly `pageHeight + pageGap`, so a page boundary may drift a little from
/// the painted sheet as the document grows, which is acceptable since nothing here needs to be
/// pixel-exact (the PDF exporter is the source of truth for print pagination).
///
/// Which sheets show a number, and what it reads, is [ocptScriptPageNumberLabelOf]'s to say — the
/// exact same rule `OcptScriptPagePainter` prints on paper, down to the 0.5" the number sits below
/// the sheet's top edge: a number on screen that disagreed with the number on paper would be worse
/// than no number at all. The only thing this painter adds is the mapping from a *sheet* index to a
/// *script* page number, which is [titlePageSheetCount].
class _OcptPageSheetsPainter extends CustomPainter {
  /// Creates an [_OcptPageSheetsPainter].
  const _OcptPageSheetsPainter({
    required this.pageCount,
    required this.titlePageSheetCount,
    required this.pageHeight,
    required this.pageGap,
    required this.pageNumberTop,
    required this.pageNumberRight,
    required this.pageNumberStyle,
    required this.scrollOffset,
  });

  /// The number of simulated pages to paint.
  final int pageCount;

  /// How many leading sheets the title page occupies, i.e. how many of them are not script pages
  /// at all (see [OcptStyledPagination.titlePageSheetCount]).
  final int titlePageSheetCount;

  /// The height of one simulated page, in logical pixels.
  final double pageHeight;

  /// The themed gap left between two simulated pages, in logical pixels.
  final double pageGap;

  /// The distance from a sheet's top edge to the top of its page number, in logical pixels.
  final double pageNumberTop;

  /// The distance from a sheet's left edge to the right edge of its page number, in logical pixels:
  /// the number is right-aligned there, exactly where the printed page's own right margin starts.
  final double pageNumberRight;

  /// The text style a page number is painted with.
  final TextStyle pageNumberStyle;

  /// The current scroll offset of the document painted in front of this layer, in logical pixels.
  final double scrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    canvas.save();
    // `CustomPaint` does NOT clip its painter to its own bounds. Once the document is scrolled,
    // `translate` below pulls every sheet up by `scrollOffset`, so the sheets above the viewport
    // get a negative top and would be painted *outside* this widget — straight over the editor
    // toolbar sitting above it, which reads exactly like the page scrolling over the toolbar.
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -scrollOffset);
    for (var page = 0; page < pageCount; page++) {
      final top = page * (pageHeight + pageGap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width, pageHeight), const Radius.circular(3)),
        paint,
      );
      _paintPageNumber(canvas: canvas, size: size, page: page, top: top);
    }
    canvas.restore();
  }

  /// Paints the number of the sheet at index [page], whose own top edge sits at [top] in the
  /// canvas' (already scroll-translated) coordinates, or paints nothing when that sheet shows no
  /// number — the title page and the first script page both do not.
  ///
  /// Sheets scrolled out of view are skipped, unlike the sheets themselves: the rectangles above
  /// are a handful of clipped canvas operations whatever the document's length, where laying a
  /// number's text out is CPU work this method would otherwise repeat, for every page of a
  /// hundred-page screenplay, on every single frame of a scroll.
  void _paintPageNumber({
    required Canvas canvas,
    required Size size,
    required int page,
    required double top,
  }) {
    if (top + pageHeight < scrollOffset || top > scrollOffset + size.height) {
      return;
    }

    final label = ocptScriptPageNumberLabelOf(page - titlePageSheetCount + 1);
    if (label == null) {
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: pageNumberStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(pageNumberRight - textPainter.width, top + pageNumberTop));
    textPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _OcptPageSheetsPainter oldDelegate) =>
      oldDelegate.pageCount != pageCount ||
      oldDelegate.titlePageSheetCount != titlePageSheetCount ||
      oldDelegate.pageHeight != pageHeight ||
      oldDelegate.pageGap != pageGap ||
      oldDelegate.pageNumberTop != pageNumberTop ||
      oldDelegate.pageNumberRight != pageNumberRight ||
      oldDelegate.pageNumberStyle != pageNumberStyle ||
      oldDelegate.scrollOffset != scrollOffset;
}
