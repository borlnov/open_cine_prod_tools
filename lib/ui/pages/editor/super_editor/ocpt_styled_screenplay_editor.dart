// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_script_page_number.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller_delegate.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_editor_stylesheet.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_ime_overrides.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_fountain_keyboard_actions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_inline_style_attributions.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_replace_node_text_command.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_settle_merge_policy.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_context_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_document_settle.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_editor_builder.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_fluid_surface.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_history.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_jump_handler.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_simulation.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_simulation_surface.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_read_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scene_number_metadata.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scene_numbers.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_spell_check_ranges.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_title_page_placeholders.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_title_page_component_builder.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_title_page_guard_requests.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_context_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart';
import 'package:spell_kit/spell_kit.dart';
import 'package:super_editor/super_editor.dart';

export 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_search.dart'
    show ocptProgrammaticNavigationSelectionReason;

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
  /// (`OcptPageSheetsPainter`, [ocptScriptPageNumberLabelOf]). There is nothing to number while
  /// this is off: the fluid surface has no sheets at all.
  final bool isPageSimulationEnabled;

  /// Whether the row this editor is laid out in is narrow enough
  /// (`ocptIsCompactWidth`) that the stylesheet should carry the block
  /// hierarchy by *style* rather than by the real screenplay indents: a phone or a narrow tablet
  /// window has no room for a character cue starting 3.7 inches from the page's left edge. Only
  /// ever acted on while [isPageSimulationEnabled] is off (see
  /// `OcptFountainEditorStylesheet.build`'s own doc comment) — the caller that forces this true is
  /// the same one that forces [isPageSimulationEnabled] false, but this widget does not assume
  /// that pairing itself.
  final bool isCompact;

  /// Whether the fluid surface is painted with the fixed paper colors (white ground, black text)
  /// instead of following the app theme — a phone's own default.
  ///
  /// On a phone page simulation is forced off ([isPageSimulationEnabled]), so this fluid surface is
  /// all a phone screenplay ever shows; on the desktop the same screenplay defaults to white paper
  /// sheets, so a phone in dark mode would otherwise be the one place the screenplay turned dark.
  /// Painting it as paper keeps it reading the way the desktop's simulated page does. Only ever
  /// acted on while [isPageSimulationEnabled] is off — a simulated page already paints paper of its
  /// own — and it changes colors alone, never the compact [isCompact] indents the fluid surface
  /// still carries.
  final bool usesPaperColorsWhileFluid;

  /// Whether every scene heading shows its scene number (explicit or computed, see
  /// `computeOcptStyledSceneNumbers`) in its left gutter.
  final bool areSceneNumbersVisible;

  /// Whether this machine wants the spell-check underlines shown at all — the machine's own on/off
  /// switch (`docs/architecture/screenplay.md`), travelling down the same way
  /// [areSceneNumbersVisible] does rather than through the bloc directly: this widget knows nothing
  /// about `OcptEditorState`. While false, no checkable node texts are ever reported (see the
  /// state's own `_reportSpellCheckTexts`), so nothing is ever requested and nothing is ever
  /// painted.
  final bool isSpellCheckVisible;

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

  /// Awaited by `OcptStyledContextMenu.onSecondaryTapUp` when a right-click lands on a
  /// misspelled word, before the context menu opens (`docs/architecture/screenplay.md`).
  /// Null (in a test with nothing to wire it to, chiefly) simply means no suggestion is ever
  /// fetched, and [OcptEditorContextMenu]'s own nullable-callback rule then withholds the whole
  /// spelling group regardless of whether the tap actually landed on a misspelling.
  final Future<List<String>> Function(String word)? onSpellingSuggestionsRequested;

  /// Called with a misspelled word the context menu's "Ignore this word" entry was picked for;
  /// null withholds that entry. Never touches the document itself — the bloc's own re-check is
  /// what makes the underline disappear.
  final ValueChanged<String>? onWordIgnored;

  /// Called with a misspelled word the context menu's "Add to the project's dictionary" entry was
  /// picked for; null withholds that entry. Never touches the document itself, for the same reason
  /// [onWordIgnored] doesn't.
  final ValueChanged<String>? onWordLearned;

  /// Class constructor
  const OcptStyledScreenplayEditor({
    super.key,
    required this.text,
    required this.pageSetup,
    required this.isPageSimulationEnabled,
    this.isCompact = false,
    this.usesPaperColorsWhileFluid = false,
    required this.areSceneNumbersVisible,
    required this.isSpellCheckVisible,
    required this.onTextChanged,
    required this.onCaretLineChanged,
    required this.jumpRequest,
    this.styledController,
    this.onSpellingSuggestionsRequested,
    this.onWordIgnored,
    this.onWordLearned,
  });

  /// Create the [_OcptStyledScreenplayEditorState] holding the state of the styled screenplay
  /// editor.
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

  /// The undo and redo handling, and the undo-grouping policy every [_editor] this state builds
  /// runs on (see [OcptSettleMergePolicy]).
  late final OcptStyledHistory _history = OcptStyledHistory(
    editorOf: () => _editor,
    syncSceneNumbers: _syncSceneNumbers,
    reportReadState: () => _readState.report(),
  );

  /// The `keyboardActions` handed to every `SuperEditor` this state builds, bound once to [undo]
  /// and [redo] (see `ocptFountainKeyboardActions`).
  ///
  /// Built once, not on every [build], for the same reason [_imeOverrides] is: both tear-offs
  /// resolve [_editor] at call time through an instance method, so this list keeps working across
  /// [_rebuildEditorFrom] replacing the editor it acts on.
  late final List<SuperEditorKeyboardAction> _keyboardActions = ocptFountainKeyboardActions(
    onUndo: undo,
    onRedo: redo,
  );

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
    // Applies the same manual block-type cycle a hardware Tab keystroke would
    // (`ocptTabToCycleBlockType`), always forward: Shift+Tab never travels through the IME delta
    // channel this intercepts, only a plain Tab does, so there is no reversed case to handle.
    onTabPressed: () => ocptCycleBlockTypeAtSelection(
      editor: _editor,
      document: _document,
      composer: _composer,
      reversed: false,
    ),
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

  /// The page simulation bookkeeping: the page count, the title page's share of it and the bottom
  /// padding the stylesheet needs. Resolves the document and the editor at call time, since both
  /// are replaced by [_rebuildEditorFrom].
  late final OcptStyledPageSimulation _pageSimulation = OcptStyledPageSimulation(
    documentOf: () => _document,
    editorOf: () => _editor,
    runDerivedPass: _runDerivedPass,
    isEnabled: () => widget.isPageSimulationEnabled,
    pageSetupOf: () => widget.pageSetup,
  );

  /// The reporter of the toolbar's read state (caret block type, active inline styles, undo/redo
  /// availability).
  late final OcptStyledReadState _readState = OcptStyledReadState(
    controllerOf: () => widget.styledController,
    documentOf: () => _document,
    composerOf: () => _composer,
    canUndoOf: () => canUndo,
    canRedoOf: () => canRedo,
  );

  /// The scene jump handling.
  late final OcptStyledJumpHandler _jumpHandler = OcptStyledJumpHandler(
    documentOf: () => _document,
    editorOf: () => _editor,
    mappingOf: () => _mapping,
    titlePageNodeCountOf: () => _titlePageNodeCount,
    titlePagePrefixLengthOf: () => _titlePagePrefixLength,
    documentLayoutKey: _documentLayoutKey,
    focusNode: _focusNode,
    isMounted: () => mounted,
  );

  /// The find/replace handling: the active query, the current match, and the highlight painted for
  /// them. Resolves the document and the editor at call time, since both are replaced by
  /// [_rebuildEditorFrom].
  late final OcptStyledSearch _search = OcptStyledSearch(
    documentOf: () => _document,
    editorOf: () => _editor,
    documentLayoutKey: _documentLayoutKey,
    isMounted: () => mounted,
    onMatchCountReported: (count) => widget.styledController?.reportSearchMatchCount(count),
  );

  /// The spell-check underline handling: the styler painting the squiggles and the ranges last
  /// applied to it.
  late final OcptStyledSpellCheckRanges _spellCheck = OcptStyledSpellCheckRanges(
    documentOf: () => _document,
  );

  /// The right-click context menu handling, which positions the menu at the tap it resolved.
  late final OcptStyledContextMenu _contextMenu = OcptStyledContextMenu(
    documentOf: () => _document,
    editorOf: () => _editor,
    composerOf: () => _composer,
    documentLayoutKey: _documentLayoutKey,
    focusNode: _focusNode,
    spellCheck: _spellCheck,
    isMounted: () => mounted,
    setState: setState,
    onSpellingSuggestionsRequestedOf: () => widget.onSpellingSuggestionsRequested,
    onWordIgnoredOf: () => widget.onWordIgnored,
    onWordLearnedOf: () => widget.onWordLearned,
  );

  /// Whether there is a gesture of the writer's left to take back, i.e. whether the `⋮` menu's
  /// `Undo` entry has anything to offer.
  @override
  bool get canUndo => _history.canUndo;

  /// Whether the last undone gesture can still be put back (see [OcptStyledHistory.canRedo]).
  @override
  bool get canRedo => _history.canRedo;

  /// Build the editor from the screenplay text, number the scenes, paginate, attach to the
  /// controller and report the first read state and spell-check texts.
  @override
  void initState() {
    super.initState();
    _rebuildEditorFrom(widget.text);
    _syncSceneNumbers();
    _pageSimulation.recompute();
    widget.styledController?.attach(this);
    _readState.report();
    _reportSpellCheckTexts();
    _maybeApplyPendingJumpRequest();
  }

  /// Rebuild the editor when the text or the page simulation changes, repaginate when the page
  /// setup
  /// changes, and move the controller attachment when the controller changes.
  @override
  void didUpdateWidget(covariant OcptStyledScreenplayEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text && widget.text != _lastSyncedText) {
      setState(() {
        _disposeEditor();
        _rebuildEditorFrom(widget.text);
        _pageSimulation.recompute();
      });
      _syncSceneNumbers();
      _readState.report();
      // The document (and every node id it holds) was just rebuilt from scratch: any match this
      // widget computed against the previous one is stale, and must never keep highlighting/
      // navigating against node ids that no longer exist.
      _search.recompute(navigateToCurrent: false);
      // The same is true of every spelling error this widget was holding: none of them addresses a
      // node id the fresh document still has, so they are dropped outright rather than left to
      // linger unreachable in `_spellingAndGrammarStyler`'s own internal map, and a fresh report
      // over the new document's own node ids is sent right away — this is what makes the raw ⇄
      // styled mode switch (and an import, and a version restore) leave the styled surface correct
      // rather than showing stale squiggles or none at all until the next edit.
      _spellCheck.styler.clearAllErrors();
      _reportSpellCheckTexts();
    } else if (widget.isPageSimulationEnabled != oldWidget.isPageSimulationEnabled) {
      // The title sheet's nodes appear/disappear with page simulation itself (see [_decode]'s own
      // doc comment), so toggling it needs a full rebuild from the same text, not just a
      // repagination: unlike the branch above, the text itself hasn't changed at all.
      setState(() {
        _disposeEditor();
        _rebuildEditorFrom(widget.text);
        _pageSimulation.recompute();
      });
      _syncSceneNumbers();
      _readState.report();
      _search.recompute(navigateToCurrent: false);
      // See the identical comment in the branch above: a full rebuild means every node id (and with
      // it, every title-page field's own presence/absence) is fresh.
      _spellCheck.styler.clearAllErrors();
      _reportSpellCheckTexts();
    } else if (widget.pageSetup != oldWidget.pageSetup) {
      setState(_pageSimulation.recompute);
    }

    // The visibility switch itself (`docs/architecture/screenplay.md`) touches no text
    // and rebuilds no document, so it needs its own, independent trigger rather than falling out of
    // one of the branches above: turning it back on must re-report the very same node texts that
    // were last reported (and get a fresh answer under whatever dictionary is now loaded), which
    // `OcptStyledEditorController.reportSpellCheckTexts`'s own dedup would otherwise silently
    // swallow as "nothing changed" — this method's own doc comment on why that dedup exists holds
    // just as true for a false→true flip as it does for the reverse.
    if (widget.isSpellCheckVisible != oldWidget.isSpellCheckVisible) {
      _reportSpellCheckTexts();
    }

    if (widget.styledController != oldWidget.styledController) {
      oldWidget.styledController?.detach(this);
      widget.styledController?.attach(this);
      _readState.report();
    }

    _maybeApplyPendingJumpRequest();
  }

  /// Flush the pending text sync before the editor leaves the tree.
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

  /// Build the styled screenplay editor as an [OcptEditorContextMenu].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = widget.pageSetup.toMetrics();
    final layout = OcptEditorPreviewLayout(metrics: metrics);
    // The fluid surface opts into paper colors on a phone (see [usesPaperColorsWhileFluid]); a
    // simulated page always paints paper regardless.
    final usePaperColors = widget.isPageSimulationEnabled || widget.usesPaperColorsWhileFluid;
    final onSurface = usePaperColors ? Colors.black : theme.colorScheme.onSurface;

    final editor = SuperEditor(
      editor: _editor,
      focusNode: _focusNode,
      documentLayoutKey: _documentLayoutKey,
      keyboardActions: _keyboardActions,
      imeOverrides: _imeOverrides,
      scrollController: _pageScrollController,
      componentBuilders: [
        if (widget.areSceneNumbersVisible)
          OcptSceneNumberGutterComponentBuilder.build(
            sceneNumbers: OcptStyledSceneNumberMetadata.of(_document),
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
            placeholders: OcptStyledTitlePagePlaceholders.of(context),
            hintStyleBuilder: (resolvedStyle) => resolvedStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: resolvedStyle.color?.withValues(alpha: 0.4),
            ),
            metrics: metrics,
          ),
        ...defaultComponentBuilders,
      ],
      customStylePhases: [_search.styler, _spellCheck.styler],
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
        trailingBottomPadding: _pageSimulation.trailingBottomPadding,
        isCompact: widget.isCompact,
        usePaperColors: widget.usesPaperColorsWhileFluid,
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
        ? OcptStyledFluidSurface(
            theme: theme,
            usePaperColors: usePaperColors,
            scrollController: _pageScrollController,
            editor: editorWithoutImplicitScrollbar,
          )
        : OcptStyledPageSimulationSurface(
            theme: theme,
            layout: layout,
            scrollController: _pageScrollController,
            pageCount: _pageSimulation.pageCount,
            titlePageSheetCount: _pageSimulation.titlePageSheetCount,
            editor: editorWithoutImplicitScrollbar,
          );

    // Wrapped once here, rather than once per branch above: a right-click anywhere over the
    // document — fluid surface or simulated page alike — opens the same context menu.
    // super_editor's own desktop gesture interactor handles no secondary mouse button at all
    // (verified against the pinned `0.3.0-dev.52`), so nothing else ever competes for this gesture.
    //
    // The `Listener` above the gesture detector is what dismisses that menu on a left click landing
    // back on the document (see `_onPointerDownOverDocument`): `MenuAnchor` closes itself on a tap
    // outside its own `TapRegion` group, and its anchor child — everything below here — is part of
    // that group, so the whole editing surface would otherwise be the one place where clicking away
    // left the menu standing. It observes rather than competes: a `Listener` never enters the
    // gesture arena, so the click it sees still reaches super_editor and places the caret.
    //
    // No entry is ever withheld for a read-only preview here: `OcptEditorCentre`
    // substitutes the read-only `OcptEditorPreview` for both editing modes while a version is being
    // previewed, so this widget — and the menu it opens — is simply never mounted under one. There
    // is no `isReadOnly` flag to thread through because there is nothing here that would ever need
    // one.
    return OcptEditorContextMenu(
      controller: _contextMenu.controller,
      childFocusNode: _focusNode,
      misspelledWord: _contextMenu.misspelledWord,
      suggestions: _contextMenu.suggestions,
      onSuggestionSelected: _contextMenu.misspelledWord != null
          ? _contextMenu.applySuggestion
          : null,
      // Each of the two actions is additionally gated on the callback that would carry it out: a
      // caller that wired none of them (a test, chiefly) must see the entry withheld rather than
      // shown and inert, the repository-wide rule this menu already follows everywhere else.
      onIgnoreWord: _contextMenu.misspelledWord != null && widget.onWordIgnored != null
          ? _contextMenu.ignoreWord
          : null,
      onLearnWord: _contextMenu.misspelledWord != null && widget.onWordLearned != null
          ? _contextMenu.learnWord
          : null,
      currentType: _contextMenu.blockType,
      onCut: _contextMenu.hasExpandedSelection ? _contextMenu.cutSelection : null,
      onCopy: _contextMenu.hasExpandedSelection ? _contextMenu.copySelection : null,
      onPaste: _composer.selection != null ? _contextMenu.paste : null,
      onSelectAll: _composer.selection != null ? _contextMenu.selectAll : null,
      onTypeSelected: _contextMenu.blockType != null ? applyBlockType : null,
      child: Listener(
        onPointerDown: _contextMenu.onPointerDownOverDocument,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTapUp: _contextMenu.onSecondaryTapUp,
          child: content,
        ),
      ),
    );
  }

  /// Takes back the writer's last gesture, plus everything this widget derived from it.
  @override
  void undo() => _history.undo();

  /// Puts back the last undone gesture, or does nothing at all when [canRedo] refuses.
  @override
  void redo() => _history.redo();

  /// Applies a manual block-type change to the current selection's extent node: bails out silently
  /// if there is no selection, or its node isn't a `ParagraphNode` (mirroring
  /// `ocptTabToCycleBlockType`'s own guard), otherwise sets the type and locks the block exactly
  /// like the Tab-cycle gesture does — plus, when [type] is [FountainLineType.parenthetical] and
  /// the node's text is still empty, inserts `()` and places the caret between the two parentheses
  /// (see `ocptParentheticalTemplateRequests`, the same helper the Tab cycle and smart-Enter use,
  /// so all three gestures behave identically) — then reports the fresh read state and hands focus
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
      ...ocptParentheticalTemplateRequests(
        nodeId: node.id,
        type: type,
        isNodeEmpty: node.text.isEmpty,
      ),
    ]);
    _readState.report();
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

    _readState.report();
    _focusNode.requestFocus();
  }

  /// Replaces the find/replace query and current-match index this widget highlights/navigates to,
  /// then immediately recomputes and (re-)navigates (see [OcptStyledSearch.recompute]).
  @override
  void updateSearch({required OcptEditorSearchQuery? query, required int? currentMatchIndex}) {
    _search.update(query: query, currentMatchIndex: currentMatchIndex);
  }

  /// Replaces the current match with [replacement] and returns the index of the next one to land
  /// on (see [OcptStyledSearch.replaceCurrentMatch]).
  @override
  int? replaceCurrentMatch(String replacement) => _search.replaceCurrentMatch(replacement);

  /// Replaces every current match with [replacement] (see [OcptStyledSearch.replaceAllMatches]).
  @override
  void replaceAllMatches(String replacement) => _search.replaceAllMatches(replacement);

  /// Applies [rangesByNodeId] — the bloc's own answer, keyed by node id — to
  /// `OcptStyledSpellCheckRanges.styler`, replacing whatever it held before: every node this widget could
  /// conceivably report is first cleared (`clearAllErrors`), then a fresh set of `TextError`s is
  /// added only for a node id [rangesByNodeId] actually names.
  ///
  /// Two guards `docs/architecture/screenplay.md` is explicit about, applied to every range
  /// before it becomes a
  /// `TextError`: a node id [_document] no longer holds (a full rebuild since the ranges were
  /// computed — an edit elsewhere, an import, a version restore, a page-simulation toggle) is
  /// ignored outright, and a range that no longer fits that node's own *current* text length is
  /// dropped rather than handed to `TextError.spelling`, which would otherwise build a `TextRange`
  /// past the end of the text it addresses.
  ///
  /// Called both by [OcptStyledEditorController.attach] (a raw → styled mode switch while ranges
  /// are already known) and, reactively, whenever `editor_page.dart` pushes a fresh
  /// `OcptEditorState.styledSpellCheckRanges` down — neither call happens from inside
  /// [_onDocumentChanged]'s own document-change listener, so this never needs the post-frame
  /// deferral [_onDocumentChanged]'s own search recompute does (see that method's long comment):
  /// the crash it guards against is specific to `markDirty()` firing synchronously inside
  /// `Editor.execute()`'s still-open transaction, which is not where this method is ever reached
  /// from.
  @override
  void updateSpellCheckRanges(Map<String, List<SpellRange>> rangesByNodeId) {
    _spellCheck.update(rangesByNodeId);
  }

  /// Applies [OcptStyledScreenplayEditor.jumpRequest] if it wasn't already applied by this widget
  /// (whether it arrived through a rebuild, or was already pending the very first time this
  /// widget was built, e.g. right after switching from raw to styled mode).
  void _maybeApplyPendingJumpRequest() {
    final jumpRequest = widget.jumpRequest;
    if (jumpRequest != null && jumpRequest.id != _lastAppliedJumpRequestId) {
      _lastAppliedJumpRequestId = jumpRequest.id;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpHandler.apply(jumpRequest.charOffset),
      );
    }
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

    // `List<DocumentNode>.of`, never a list narrowed to `ParagraphNode`: see
    // `OcptWysiwygCodec.decode`'s own doc comment for what such a list does to `MutableDocument
    // .reset()`. Moot for this particular document — the `Editor` below keeps history off, so
    // `reset()` is never reached — but a scratch document built differently from every other one
    // in this app is a trap for whoever copies this block next.
    final settledDocument = MutableDocument(nodes: List<DocumentNode>.of(_document));
    final settledComposer = MutableDocumentComposer();
    // History stays off on this one: it exists for a single synchronous settle-then-encode pass
    // and is discarded a few lines below, never reaching a keyboard or a writer's Ctrl+Z. This is
    // not an oversight to align with `_rebuildEditorFrom`'s own `Editor`.
    final settledEditor = Editor(
      editables: {Editor.documentKey: settledDocument, Editor.composerKey: settledComposer},
      requestHandlers: List<EditRequestHandler>.from(defaultRequestHandlers)
        ..insert(0, ocptTitlePageGuardRequestHandler)
        ..add(ocptChangeNodeMetadataRequestHandler)
        ..add(ocptReplaceNodeTextRequestHandler),
    );

    OcptStyledDocumentSettle.settle(settledDocument, settledEditor);
    _encodeAndReportIfChanged(settledDocument);

    settledComposer.dispose();
    settledEditor.dispose();
  }

  /// Builds [_document], [_composer] and [_editor] from [text], and starts listening to document
  /// and selection changes.
  ///
  /// [_lastSyncedText] is set to [text] so this rebuild is never mistaken, on the very next
  /// widget update, for an external change to `widget.text`.
  void _rebuildEditorFrom(String text) {
    _lastSyncedText = text;
    _lastReportedLine = 0;
    // A fresh `Editor` starts with an empty history *and* an empty future, so nothing can be
    // stale about a redo stack that does not exist yet. Resetting this matters because the
    // history belongs to the editing surface: a mode toggle, an episode switch, an import or a
    // version restore all rebuild this editor, and each of them starts a fresh one.
    _history.reset();

    final decoded = _decode(text);
    _document = decoded.document;
    _mapping = decoded.mapping;
    _trailingBlankLines = decoded.trailingBlankLines;
    _titlePageNodeCount = decoded.titlePageNodeCount;
    _titlePagePrefixLength = decoded.titlePagePrefixLength;
    _composer = MutableDocumentComposer();
    _editor = ocptStyledEditorFor(document: _document, composer: _composer, history: _history);

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
    if (!_history.isApplying) {
      // Anything that is not an undo or a redo of ours is an edit the future transactions can no
      // longer be replayed on top of — including a derived pass of this widget's own, which is
      // ordinarily a no-op after an undo (the pass's own commands were merged into the very
      // transaction being restored, so it finds nothing left to derive) and, on the day one of
      // them is not, has genuinely moved the document past what a redo was recorded against.
      _history.markRedoStale();
    }
    _readState.report();

    if (_search.query == null) {
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
      if (mounted && _search.query != null) {
        _search.recompute(navigateToCurrent: false);
      }
    });
  }

  /// Rejoins the document into flat text (reporting it upstream if it changed), refreshes
  /// [_mapping] for that freshly encoded text, and re-classifies every line plus every note's
  /// attribution span, only touching the metadata of the nodes that actually need it.
  ///
  /// Also reports a fresh set of checkable spell-check texts ([_reportSpellCheckTexts]), right here
  /// rather than from [_onDocumentChanged] itself: `OcptStyledDocumentSettle.settle`'s own reclassify pass, just
  /// above, is what makes a node's `blockType` metadata authoritative again after an edit (a line
  /// that just became a scene heading, say), and `OcptStyledSpellCheckRanges.checkableTexts` reads exactly that
  /// metadata — reporting any earlier would report a node still classified under its *previous*
  /// type.
  void _syncAfterEdit() {
    if (!mounted) {
      return;
    }

    _runDerivedPass(() => OcptStyledDocumentSettle.settle(_document, _editor));
    _encodeAndReportIfChanged();
    _reportSpellCheckTexts();

    final previousPageCount = _pageSimulation.pageCount;
    final previousTrailingBottomPadding = _pageSimulation.trailingBottomPadding;
    _pageSimulation.recompute();
    if (_pageSimulation.pageCount != previousPageCount ||
        _pageSimulation.trailingBottomPadding != previousTrailingBottomPadding) {
      setState(() {});
    }
  }

  /// Runs [derivedPass] — any pass that writes back to [_document] what this widget *derived* from
  /// the writer's last gesture — merged onto that gesture (see [OcptStyledHistory.runDerivedPass]).
  void _runDerivedPass(void Function() derivedPass) => _history.runDerivedPass(derivedPass);

  /// Renumbers every scene heading immediately (not debounced) and reports the corrected text
  /// upstream if it changed, right after [_rebuildEditorFrom] rebuilds the document from fresh
  /// text: this is what corrects a badly-ordered `#N#` typed in raw mode (or by any other means)
  /// the moment it's decoded into the styled editor, rather than waiting for the next edit's
  /// [_syncAfterEdit] debounce to happen to touch a scene heading.
  ///
  /// `OcptStyledHistory` calls it again after every undo and every redo, and for the very same
  /// reason: what this pass corrects is part of the document's *base* state rather than of any
  /// gesture, and a restore brings the document back to a snapshot taken before it ran.
  ///
  /// `isHistorical: false`, unlike `OcptStyledDocumentSettle.settle`'s own call to the same function: this pass
  /// runs before the writer has done anything at all, so an undo step here could only ever be a
  /// Ctrl+Z that un-corrects the numbering. It is refused history at the command level rather than
  /// through [OcptStyledHistory.mergePolicy], which cannot help here — a merge onto an empty history is an append
  /// (`Editor.endTransaction`), which is exactly the transaction to avoid. Nothing this executes
  /// therefore ever reaches the policy, which is why this pass is not wrapped in
  /// [_runDerivedPass].
  void _syncSceneNumbers() {
    final requests = sceneNumberNormalizationRequests(_document, isHistorical: false);
    if (requests.isEmpty) {
      return;
    }
    _editor.execute(requests);
    _encodeAndReportIfChanged();
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
  OcptWysiwygDecodeResult _decode(String text) => widget.isPageSimulationEnabled
      ? OcptWysiwygCodec.decodeWithTitlePage(text)
      : OcptWysiwygCodec.decode(text);

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

    _readState.report();
  }

  /// Refreshes the controller's read side whenever the composer's collapsed-caret style
  /// preferences change (a B/I/U toggle applied via keyboard shortcut or the toolbar, while the
  /// caret has no selection): [_onSelectionChanged] alone would miss this, since the selection
  /// itself doesn't move.
  void _onComposerPreferencesChanged() {
    _readState.report();
  }

  /// Reports `OcptStyledSpellCheckRanges.checkableTexts` up through [OcptStyledScreenplayEditor.styledController]
  /// (`OcptStyledEditorController.reportSpellCheckTexts`, which dedupes against what was last
  /// reported on its own — this method itself is called unconditionally, exactly like
  /// `OcptStyledSearch.recompute` reports its own match count every time it runs).
  void _reportSpellCheckTexts() {
    widget.styledController?.reportSpellCheckTexts(
      _spellCheck.checkableTexts(isVisible: widget.isSpellCheckVisible),
    );
  }

  /// Detach from the controller, stop the sync timer, then dispose the editor, [_focusNode] and
  /// [_pageScrollController].
  @override
  void dispose() {
    widget.styledController?.detach(this);
    _syncTimer?.cancel();
    _disposeEditor();
    _focusNode.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }
}
