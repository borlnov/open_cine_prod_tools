<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the screenplay

`fountain_kit` and the screenplay mode: the parser and what it guarantees, the styled
editor's document model, the title page, the docks and the syntax guide.

- `packages/fountain_kit`: pure-Dart Fountain parser/serializer with round-trip guarantee and
  `FountainLayoutMetrics` (US Letter/A4 Courier columns). Keep it free of Flutter imports.

- One screenplay at a time, and it is **the episode the workspace has selected** (ADR 0019): the
  mode reads and writes that screenplay where it reached for `primaryScreenplayId` before, and
  switching episode remounts it wholesale (see `foundations.md`). Nothing else about the mode
  changes, an episode being one screenplay — and **the script is never prefixed**: the computed
  scene numbers, the raw preview and the screenplay PDF all print the author's own `#N#`, where the
  shot list, the breakdown and the schedule read `<episode>.<scene>`. The mode's two exports name
  the episode in their **suggested file name** instead, so two episodes saved into one folder cannot
  overwrite each other. This mode is also the only one offering `Add an episode…` — the button the
  workspace toolbar draws in the episode selector's own place while the project holds a single
  episode, opening the project settings on their card (see `foundations.md`).

- Source provenance (ADR 0012): every printed line `FountainScriptComposer` emits carries a nullable
  `FountainScriptLine.sourceRange` — the union of its runs' own `FountainStyledRun.sourceRange`s,
  anchored into `FountainDocument.sourceText` — plus `isSynthetic` for the `(MORE)` token and the
  repeated `NAME (CONT'D)` cue. It is what maps a stored source offset onto a printed row, and it is
  **best effort**: a line the composer cannot anchor verbatim gets no range rather than a wrong one,
  so every consumer bridges over an unanchored line instead of assuming one. A position *inside* a
  run is interpolated, never counted (`toUpperCase()` and `\`-escapes are not length-preserving).

- `FountainScriptStatistics` (`fountain_kit`): pure page/scene/speaking-character/word/sign
  counters over the printable body, page count via `FountainScriptComposer`, surfaced by the
  editor's status bar.

- Editor: super_editor styled mode keeps **one `ParagraphNode` per non-blank Fountain source
  line**; a blank source line carries no node of its own, folded into the following node's
  `ocptBlankLinesBefore` metadata instead. Other node metadata: `blockType` (the line's
  `FountainLineType` as a `NamedAttribution`, stylesheet-only styling), `ocptTypeLocked` (a
  manual type override — dropdown or Tab — sticky for the node's **whole lifetime**, including
  while its text is empty: only a new node created by Enter/Shift+Enter starts unlocked),
  `ocptHadForcingMarker` (the source line used an explicit forcing marker, re-emitted on encode
  even when auto-detection alone would already suffice), `ocptSceneNumberMetadataKey` (a scene
  heading's `#N#`, stripped out of the display text on decode and re-appended on encode) and
  `ocptTitlePageKeyMetadataKey` (which of `ocptTitlePageFieldKeys` a title-page field node is, see
  below). `OcptWysiwygCodec`
  (`lib/ui/pages/editor/super_editor/`, the only directory besides `fountain_kit` that knows
  about this format) is the Fountain ↔ document (de)serializer, built on `fountain_kit`'s
  `FountainLineClassifier`/`FountainLineWriter`/`FountainInlineParser`/`FountainInlineSerializer`.
  `ocpt_fountain_keyboard_actions.dart` handles Tab/Shift+Tab (cycles 6 common types, locks the
  block) and Enter (splits into the type's usual screenplay successor, unlocked; Shift+Enter
  keeps the same type). Whichever gesture sets a block to `parenthetical` opens it on `()` with the
  caret between them (`ocptParentheticalTemplateRequests`, shared by the Tab cycle, smart Enter and
  the toolbar dropdown), but **only while the block's text is empty**: Tab cycles *through* the type
  on its way elsewhere, so an unguarded template would inject a pair per pass.
  `OcptStyledEditorController extends ChangeNotifier`
  (`lib/ui/pages/editor/ocpt_styled_editor_controller.dart`) bridges the toolbar's block-type
  dropdown and B/I/U toggles to the live editor without a `package:super_editor` import; it is
  attached only while a styled editor is mounted (detached in raw mode). Debounces: parse
  150 ms, autosave 2 s, styled reclassify 120 ms (flushed synchronously on `deactivate()` so a
  pending edit survives a mode toggle or back navigation). Ctrl+S saves, Ctrl+Shift+M toggles
  mode, both left unclaimed by the styled editor's `keyboardActions` and bubbling to the page.
  Ctrl+C/X/V (`ocpt_fountain_clipboard_actions.dart`) replace super_editor's defaults: the
  clipboard payload is always plain Fountain source text
  (`OcptWysiwygCodec.encodeSelectionToFountain`/`decodeNodesFromFountain`), so block types and
  spacing survive a copy/paste round trip inside the app while text to and from outside the app
  still decodes through ordinary auto-detection.

- Right-click menu: the styled mode alone carries one (`OcptEditorContextMenu`,
  `lib/ui/pages/editor/widgets/`, a `MenuAnchor` free of any `package:super_editor` import — the raw
  mode is a plain `TextField` and gets Flutter's native menu for free). Cut, Copy, Paste, Select all
  and the block type as a submenu; the clipboard entries call the very helpers the Ctrl+C/X/V
  handlers do, and the submenu the same `applyBlockType` the toolbar dropdown does, so no gesture
  can behave differently from its keyboard or toolbar twin. The list of assignable types lives once,
  as `ocptAssignableFountainLineTypes` (`lib/ui/utils/ocpt_fountain_line_type_labels.dart`). An
  entry with nothing to act on is **withheld, not disabled** (a null callback), which is what hides
  Cut/Copy over a collapsed caret. The secondary tap resolves the document position under the
  pointer and places the caret there, unless it lands inside an expanded selection, which it never
  destroys. Nothing is withheld for a read-only preview: the styled editor is not mounted under one
  at all, `editor_page.dart` substituting the read-only preview for both editing modes.

- Scene numbers: a heading's `#N#` is a first-class WYSIWYG field
  (`ocptSceneNumberMetadataKey`), kept in sync with the display text by
  `OcptWysiwygCodec.sceneNumberRequests` on every reclassify pass. Styled mode can additionally
  *display* a computed number for every heading that has none of its own
  (`ocpt_styled_scene_numbers.dart`), gated by `OcptPropertiesManager.styledSceneNumbersVisible`
  (`⋮` menu, on by default) — display-only, it never writes into the Fountain source, and an
  explicit `#N#` always wins over a computed number. The raw preview and the PDF are unaffected:
  they only ever print an explicit number.

- Title page: the styled editor renders it as an editable first sheet, not a dialog-only flow.
  `OcptWysiwygCodec` synthesizes one `ParagraphNode` per `ocptTitlePageFieldKeys` entry (`Title`,
  `Credit`, `Author`, `Draft date`, `Contact`, `Source`, always all six, empty ones included),
  tagged with the `ocptTitlePageFieldAttribution` `blockType` and `ocptTitlePageKeyMetadataKey`;
  encoding always goes through `FountainTitlePageWriter.apply`, never a hand-written `Key: value`
  line, so a title page with no entries at all is dropped. `OcptTitlePageComponentBuilder`
  (`ocpt_title_page_component_builder.dart`) paints the field layout (large centred title,
  centred credit/author, bottom-left contact, bottom-right draft date) and each empty field's
  placeholder hint, and `ocptTitlePageGuardRequestHandler`
  (`ocpt_title_page_guard_requests.dart`) is the single place that keeps the six field nodes from
  being merged into the body or deleted as nodes, while still allowing ordinary text editing
  (typing, Backspace, Delete, replace) inside a field — do not reach for
  `NodeMetadata.isDeletable`, which blocks both. `computeOcptStyledPagination` always reserves the
  whole of page 1 for the title page when one is present, matching the PDF exporter, and reports
  that as `titlePageSheetCount` — the offset between a painted sheet's index and its 1-based
  **script** page number.

- Page numbers: every simulated sheet carries the number the printed screenplay would show on it,
  painted by the same `_OcptPageSheetsPainter` that paints the sheets themselves and gated on page
  simulation (there is nothing to number on the fluid surface). The rule itself lives once, in
  `lib/utils/ocpt_script_page_number.dart`: `N.` at the top right,
  `ocptScriptPageNumberTopInches` (0.5") below the sheet's top edge whatever the configured margin,
  the title page never counted and the first script page never numbered. `OcptScriptPagePainter`
  prints that same rule on paper — a number on screen disagreeing with the number on the PDF would
  be worse than no number at all. Fixed paper colours, like the rest of the page-simulation
  styling, and a sheet scrolled out of view is skipped rather than laid out on every scroll frame.

- Find and replace: one search, over **the episode the workspace has selected**, in both editing
  modes. `Ctrl+F` opens the bar on find, `Ctrl+H` on replace, `Escape` closes it — page-level
  `Shortcuts` in `editor_page.dart`, beside `Ctrl+S`/`Ctrl+Shift+M`, none of the three claimed by
  `ocptFountainKeyboardActions` or by super_editor's defaults — and the `⋮` menu reaches it without
  the keyboard, through **two entries rather than one**, `Find…` and `Find and replace…`, each
  opening the bar the way its own shortcut does and stating that shortcut on the right
  (`OcptToolbarMenuItemLabel`, the platform's modifier resolved by `ocptPrimaryShortcutLabel`).
  `OcptEditorFindBar`
  (`lib/ui/pages/editor/widgets/`) is a docked band at the top of the **centre column only**, two
  stacked rows whose replace row folds behind a chevron, the match-case and whole-word toggles
  living inside the find field itself. The search *state* is `OcptEditorSearchState`, in the bloc,
  which is what makes it survive a raw ⇄ styled toggle; the bar and both surfaces only ever report
  into it.
- **Each mode matches what it shows**, and the counter says so: raw mode searches the Fountain
  source, the very characters its field displays, where the styled mode searches each node's
  *display* text — no forcing marker, no `#N#`, no `*`/`_` emphasis, and the six title-page fields
  included, so its count moves with the page-simulation toggle that creates them. The two counts
  can therefore differ for a query holding markup, which is the rule rather than a defect. The bloc
  holds the query, the two options and the current index; the **count is reported up by whichever
  surface is mounted**, which is what keeps `Replace all` consistent with the number the bar just
  showed. The matcher itself is `ocptFindTextMatches` (`lib/utils/ocpt_text_search.dart`), shared by
  both: literal — a query is never compiled into a `RegExp`, since `(`, `.` and `*` are ordinary
  characters to a screenwriter — and its whole-word test counts accented letters as word characters,
  a screenplay being written in French too.
- The highlight is painted by each surface in its own way, from the same two fixed colours
  (`lib/ui/pages/editor/ocpt_editor_search.dart`): fixed, not theme-derived, for the reason the rest
  of the page-simulation styling already is. Raw mode overrides `buildTextSpan`
  (`OcptEditorSearchTextController`). Styled mode uses `OcptSearchMatchStyler`, a
  `SingleColumnLayoutStylePhase` handed to `SuperEditor`'s `customStylePhases`, which adds its two
  attributions to the **copied** component view model and wraps that copy's `textStyleBuilder` —
  never the document, where they would be encoded straight back into the Fountain source. Its
  `markDirty()` is **deferred to a post-frame callback** when it comes from the document-change
  listener: firing it inside the still-open `Editor.execute` transaction reaches super_editor's own
  selection styler before the composer's selection has been reconciled, and crashes on any
  delete or cut.
- Navigating to a match places the selection **without taking keyboard focus** — the find field is
  what must keep it — which the styled editor's existing `clearSelectionWhenEditorLosesFocus: false`
  already allows. `Replace` moves on to the first match starting at or past the end of what it just
  wrote (wrapping), never simply to whatever now sits at the same index: renaming `MARIE` into
  `MARIE-JEANNE` writes text that still matches, and keeping the index would compound it on every
  further press. `Replace all` goes through `OcptConfirmDialog`, opened by the page with the same
  words in both modes. The whole bar is withheld under a read-only preview, shortcuts included:
  there is no editing surface to search there at all.
- Editor docks: `OcptWorkspaceDock`/`OcptWorkspaceDockDivider`
  (`lib/ui/pages/workspace/widgets/ocpt_workspace_dock.dart`) give the scene panel and the right
  dock draggable-divider resizing with a 320 px centre floor (right dock yields width first);
  widths are fractions of the editing row, persisted through
  `OcptPropertiesManager.editorLeftDockFraction`/`editorRightDockFraction`.
  `OcptWorkspaceDockLayoutController extends ChangeNotifier` holds the live fractions during a
  drag so it never emits a bloc state per frame; the bloc only sees one
  `OcptEditorDockFractionsChangedEvent` on `onHorizontalDragEnd`. The right dock
  (`OcptEditorRightDock`, under `lib/ui/pages/editor/widgets/`) is tabbed
  (`OcptEditorRightDockTab { preview, syntax, inspector, metadata, versions }`); its tab row is
  itself clickable (`onTabSelected`), while the toolbar's preview/syntax buttons — **raw mode
  only**, the styled mode reaches every tab through the tab row alone — additionally *open* a closed
  dock on their tab (inspector/metadata/versions have no toolbar button in either mode). The shell's
  own right-dock toggle closes the dock whichever tab it shows, and reopens it on
  `lastRightDockTab` (the last tab explicitly selected, never null, `preview` by default), falling
  back to `syntax` when that tab is `preview` and the styled mode is active. Switching to styled
  mode auto-closes an open preview tab and remembers it (`autoClosedRightDockTab`, a separate
  memory) for the next switch back to raw, unless the user explicitly closed the dock themselves.

- Right dock content: `OcptEditorInspectorPanel` shows the scene under the caret (heading, speaking
  characters, estimated duration, page-eighths) from `FountainSceneStatistics.of` (`fountain_kit`,
  the scene-scoped sibling of `FountainScriptStatistics`, exposing `pageEighths` — never a minutes
  field, duration is derived at the call site on the one-page-per-minute convention).
  `OcptEditorMetadataPanel` shows the title-page fields and the script-wide statistics, read-only,
  with an "Edit…" button opening the existing title-page dialog through `OcptRouterManager`. Both
  are recomputed on the editor's existing 150 ms parse debounce, never per keystroke.

- The Fountain syntax guide (`OcptEditorSyntaxGuidePanel`) renders the `const`
  `ocptFountainSyntaxEntries` table (`lib/models/ocpt_fountain_syntax_entry.dart`, one entry per
  `OcptFountainSyntaxTopic`) as read-only snippets in both editing modes (the *panel* is
  mode-agnostic; only the toolbar shortcut opening it is raw-mode only); its titles reuse the 11
  existing `editorBlockType*` ARB keys where a topic already had one.
