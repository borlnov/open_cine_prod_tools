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
  keeps the same type). `OcptStyledEditorController extends ChangeNotifier`
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
