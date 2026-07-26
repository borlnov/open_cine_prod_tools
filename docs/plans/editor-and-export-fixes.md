<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Issue #15 — Editor & export fixes

This document is the implementation strategy for
[issue #15](https://github.com/borlnov/open_cine_prod_tools/issues/15). It is written for the
Sonnet 5 agents that will build it, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone.

**Read the repository `CLAUDE.md` first.** This plan assumes its architecture, ways of working,
coding standards, licensing rules and verification gates, and never repeats them except where a
milestone needs a specific reminder. Work happens on branch `15-editor-and-export-fixes`.

## Context

Open Cine Prod Tools is a Fountain screenplay editor (Flutter, Linux + Windows first, local-only
SQLite `.ocpt` projects). Steps 0–15 of the development plan are done: the editor already has a raw
Fountain mode with a paper-simulated preview, a WYSIWYG styled block mode built on `super_editor`,
resizable docks, a Fountain syntax guide, `.fountain` import/export, PDF export, page setup and a
title-page dialog.

Issue #15 is the first batch of defects found by **using** the app to write, plus the two small
features they imply. Nine points, all independent except where noted:

| #   | Symptom (user words, translated)                                              | Milestone |
| --- | ----------------------------------------------------------------------------- | --------- |
| 2   | Export does not ask where to save the file (`.fountain` and PDF alike)        | M1        |
| 3   | The PDF export dialog's confirm button reads "Apply" instead of "Export"      | M1        |
| 5   | Typing in a "Character" block switches it back to "Action"                    | M2        |
| 7   | The scroll bar is drawn on top of the white page in styled mode               | M2        |
| 6   | Copy/paste loses the block types in styled mode                               | M3        |
| 8   | `#1#` scene numbers do not work; add auto-numbering + syntax-guide entry      | M4        |
| 9   | The exported PDF loses bold/italic/underline                                  | M5        |
| 1   | In dark theme the raw-mode preview is all dark, nothing is white              | M6        |
| 4   | The styled view must show the title page as it is exported, fillable in place | M7        |

Ordering rationale: M1–M3 are small, well-diagnosed and touch disjoint files; M4–M5 need a
reproduction test before any behaviour change; M6 needs a visual reproduction; M7 is the largest
piece and the only one that changes the styled editor's document model, so it comes last.

### Decisions locked with Benoit (do not revisit without asking)

1. **`actlibs/` stays untouched.** The missing "save as" dialog is implemented **app-side** with
   `file_selector`, not by extending `act_file_transfer_manager` (point 2).
2. **Styled-mode scene numbering is display-only** (point 8). The option computes and *displays*
   numbers; it never writes `#N#` into the Fountain source. A hand-written `#N#` always wins over
   the computed number. The option is **on by default**.
3. **The styled view's title page is editable in place** (point 4): a real first sheet, laid out
   exactly as the PDF prints it, every field editable directly in the editor, empty fields shown as
   fill-in placeholders. Not a read-only rendering, not a dialog-only flow.
4. **In dark theme the raw-mode preview must read as paper** (point 1): white sheet *and* white
   panel backdrop, black text. Light theme is unchanged.
5. Every user-visible string goes through `Tr.of(context)` and lands in **both** `intl_en_GB.arb`
   and `intl_fr.arb`.

### Working rules for each agent

- Every Flutter/Dart/`reuse` command runs **inside the devcontainer**; the host has no usable SDK:

  ```bash
  cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
  ```

- Run the `CLAUDE.md` verification gates before each commit (see [Verification](#verification)).
- One commit per logical change, Conventional Commits, English, subject ≤ 50 characters. Issue
  numbers are allowed; **never** mention this plan, its milestones, or the agent instructions in
  code, comments or commit messages.
- Every commit produced by a Sonnet 5 agent ends with:
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`
- New Dart files get the 3-line Apache-2.0 SPDX header; ARB keys are covered by the blanket
  `REUSE.toml`.
- Doc comment on **every** declaration, `Ocpt` prefix on app classes, match the surrounding files'
  idioms exactly. Do not touch `actlibs/` or `lib/generated/`.
- Tests use inline private test doubles (no shared helpers directory) and set
  `BlinkController.indeterminateAnimationsEnabled = false` before pumping anything containing the
  styled editor. There are **no** full-app-boot widget tests (`PackageInfo.fromPlatform()` hangs on
  unmocked platform channels): pump pages and widgets directly.
- When a milestone's investigation contradicts the diagnosis written here, **report it instead of
  silently redesigning**: the diagnoses below were made by reading the code, not by running the app.

## Architecture & reuse map (consume these, do not reinvent)

Files this issue touches, and what they already own:

**Export**

- `lib/managers/export/ocpt_export_manager.dart` — `OcptExportManager extends AbsWithLifeCycle`,
  registered by `OcptGlobalManager`. Owns the native dialogs and two services (RFL18):
  `OcptFountainIoService` (bytes ↔ text, suggested file names) and `OcptPdfExportService`. Public
  API: `exportFountain`, `exportPdf`, `pickAndReadFountain`. Returns `null` on cancel; the bloc
  already treats `null` as "the user cancelled" and shows nothing.
- `lib/managers/export/services/ocpt_pdf_export_service.dart` — the whole PDF renderer: embedded
  Courier Prime (4 variants, `_CourierPrimeFonts`), title page, absolutely positioned body lines,
  page numbers and both-margin scene numbers. Consumes `FountainScriptComposer` for pagination.
- `lib/ui/pages/editor/editor_bloc.dart` — `_onExportRequested` / `_onExportPdfRequested` flush a
  dirty screenplay, call the manager, then emit an `OcptEditorIoNotice` (SnackBar).
- `lib/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart` — the PDF options
  dialog (page format dropdown + "Include scene numbers" + "Include title page"). Pops through
  `globalGetIt().get<OcptRouterManager>().pop<T>(result)`; **never** `Navigator`.

**Styled (WYSIWYG) editor** — `lib/ui/pages/editor/super_editor/`, the only directory besides
`packages/fountain_kit` that knows the document format:

- `ocpt_wysiwyg_codec.dart` — `OcptWysiwygCodec`: Fountain text ↔ `MutableDocument`, on the
  invariant **one `ParagraphNode` per non-blank Fountain source line**. Blank lines are folded into
  the next node's `ocptBlankLinesBefore` metadata. Other metadata: `blockType` (a
  `NamedAttribution` for the line's `FountainLineType`), `ocptTypeLocked` (manual type override),
  `ocptHadForcingMarker`. Static pure helpers only: `decode`, `encode`, `reclassifyRequests`,
  `uppercaseRequests`, `noteAttributionRequests`. Also owns `OcptWysiwygLineMapping` (node ↔ source
  line).
- `ocpt_styled_screenplay_editor.dart` — `OcptStyledScreenplayEditor`: owns the `MutableDocument`,
  `MutableDocumentComposer`, `Editor`, the 120 ms reclassify/encode debounce (flushed in
  `deactivate()`), the page-simulation sheet painter (`_OcptPageSheetsPainter`) and
  `_pageScrollController`.
- `ocpt_fountain_keyboard_actions.dart` — `ocptFountainKeyboardActions` = this app's Tab cycle,
  smart Enter and Ctrl+U, then `defaultImeKeyboardActions` minus `_ocptExcludedDefaultActions`.
  Also `ocptManualBlockTypeRequests` (the two requests every manual type change applies) and
  `ocptCycleBlockTypeAtSelection`.
- `ocpt_fountain_ime_overrides.dart` — `OcptFountainTabInterceptor`: catches a plain Tab at the IME
  delta boundary (on desktop a plain Tab never arrives as a hardware key event).
- `ocpt_fountain_editor_stylesheet.dart` — one mutually exclusive `StyleRule` per
  `FountainLineType` (never a `BlockSelector.all` baseline: only `Styles.textStyle` and
  `Styles.padding` merge across rules). Fixed paper colours while page simulation is on, themed
  colours otherwise.
- `ocpt_wysiwyg_edit_requests.dart` — `OcptChangeNodeMetadataRequest` (merge app metadata) and
  `OcptReplaceNodeTextRequest` (replace a node's `AttributedText`), with their commands and request
  handlers. **Use these for any new metadata or in-place text change**; do not add a third pattern.
- `ocpt_styled_page_pagination.dart` — `computeOcptStyledPagination`: which node starts a page, its
  exact top padding, the page count and the trailing bottom padding.
- `lib/ui/pages/editor/ocpt_styled_editor_controller.dart` — the app-level bridge between the
  toolbar (block-type dropdown, B/I/U) and the live editor, with no `package:super_editor` import.

**Preview & layout**

- `lib/ui/pages/editor/widgets/ocpt_editor_preview.dart` — the raw mode's paper preview: white
  `Material` sheet(s), lazy block list, fit-to-width scaling, caret scroll sync.
- `ocpt_editor_preview_block.dart` — one printable block typeset at its true position, always black
  on white, inline emphasis via `FountainInlineParser`.
- `ocpt_editor_preview_layout.dart` — `OcptEditorPreviewLayout`: the single inches → pixels
  converter (`pageWidth`, `pageHeight`, `marginTop/Left/Right/Bottom`, `lineHeight`,
  `indentOf`, `widthOf`, `pageGap`, `estimateBlockHeight`, `wrappedLineCount`). **Both** the preview
  and the styled editor derive every measurement from it; keep it that way.

**`packages/fountain_kit`** (pure Dart, no Flutter imports, round-trip guaranteed)

- `FountainLineClassifier` (line → `FountainLineType`, context-aware), `FountainLineWriter`
  (display text + type + context → raw source line, adding a forcing marker only when needed),
  `FountainInlineParser`/`FountainInlineSerializer` (emphasis and `[[notes]]` ↔ styled runs),
  `FountainBlockBuilder` (blocks, including `_sceneNumber = RegExp(r'#([A-Za-z0-9.\-]+)#\s*$')`),
  `FountainScriptComposer` (line-level pagination + per-line styled runs, used by the PDF),
  `FountainLayoutMetrics`, `FountainTitlePage`/`FountainTitlePageEntry`
  (`entry(key)`, `joinedValue`, `title`, `credit`, `authors`, `contact`, `draftDate`, `source`,
  `sourceRange`) and `FountainTitlePageWriter.apply({source, entries, existingRange})` (splices the
  title-page span only, never reformats the body).

**Other**

- `lib/managers/ocpt_properties_manager.dart` — app-wide persisted preferences
  (`SharedPreferencesItem<T>` / `SharedPrefsItemWithParser`), e.g. `isPageSimulationEnabled`,
  `editorLeftDockFraction`, `pageMargins`. `null` means "never stored, use the default, applied at
  the call site".
- `lib/models/ocpt_fountain_syntax_entry.dart` + `lib/types/ocpt_fountain_syntax_topic.dart` — the
  `const ocptFountainSyntaxEntries` table behind the syntax guide, verified against the real parser
  by `test/models/ocpt_fountain_syntax_entry_test.dart`.
- `lib/ui/pages/editor/widgets/ocpt_editor_toolbar.dart` — the `⋮` menu (`PopupMenuItem` /
  `CheckedPopupMenuItem`) holding Export, Export to PDF, page simulation, page setup, title page,
  reset panel layout.
- Existing tests to extend rather than duplicate: `test/ui/pages/editor/super_editor/
  ocpt_wysiwyg_codec_test.dart`, `ocpt_styled_screenplay_editor_test.dart`,
  `ocpt_styled_screenplay_editor_corpus_test.dart`, `test/ui/pages/editor/widgets/*_test.dart`,
  `test/managers/export/services/*_test.dart`, `test/ui/pages/editor/editor_bloc_test.dart`,
  `editor_page_test.dart`.

---

## Milestones (one Sonnet 5 agent per milestone, checkpoint between each)

### M1 — Native save dialogs and the "Export" button (points 2 and 3)

**Root cause of point 2.** `OcptExportManager.exportFountain`/`exportPdf` both call
`FileSaverManager.saveFileFromBytes`, which is `FileSaver.instance.saveFile(...)` — the
`file_saver` API that writes straight to a default directory **without** any dialog. Nothing in the
app ever offers the user a location. `act_file_transfer_manager` exposes no "save as" method, and
`actlibs/` must stay untouched (decision 1).

**Root cause of point 3.** `ocpt_editor_export_pdf_options_dialog.dart` reuses the ARB key
`editorPageSetupApplyAction` ("Apply" / "Appliquer") for its confirm button.

**Work.**

- `pubspec.yaml`: add `file_selector` as a **direct** dependency (it is currently only a transitive
  one, through `act_file_transfer_manager`), with a one-line comment explaining why, in the style of
  its neighbours. Pin with a caret; check the version already resolved in `pubspec.lock` and use a
  constraint compatible with it so the resolution does not move.
- New `lib/managers/export/services/ocpt_save_location_service.dart`:
  `OcptSaveLocationService` with a single method
  `Future<String?> pickSaveLocation({required String suggestedFileName, required String fileTypeLabel, required List<String> extensions})`,
  wrapping `getSaveLocation(...)` from `package:file_selector/file_selector.dart` and returning the
  chosen path, or `null` when the user cancelled. It must:
  - build one `XTypeGroup(label: fileTypeLabel, extensions: extensions)`;
  - pass `suggestedName` so the dialog pre-fills the project's file name;
  - **append the extension when the returned path has none** (the GTK dialog does not add it), and
    log-and-return-null on error, exactly like the manager's existing soft-failure style.
  Keep it `const`-constructible and Flutter-plugin-thin so it can be replaced by a test double.
- `OcptExportManager`: own the new service as a public final field (RFL18, like `fountainIoService`
  and `pdfExportService`), add an optional constructor parameter for the test double, and route both
  exports through `pickSaveLocation` + `File(path).writeAsBytes(bytes, flush: true)`. Keep the
  "returns the written path, or null when the user cancelled or it failed" contract: the bloc and
  its tests already rely on it.
  - The `FileSaverManager` field then becomes unused. Grep the whole repo
    (`git grep -n FileSaverManager -- ':!actlibs'`): if nothing else uses it, drop the field, its
    constructor parameter and its entry in `OcptExportManagerBuilder.dependsOn()`, and remove its
    registration from `OcptGlobalManager` — but **only** if truly unused, and mention the removal in
    the commit body.
  - The file-type labels are user-visible: reuse `editorImportFileTypeLabel` if it fits, otherwise
    add ARB keys and pass the label down from the page/bloc (managers never call `Tr`).
- New ARB key `editorExportPdfExportAction` — `"Export"` / `"Exporter"`, with the `@` description
  block the neighbouring keys carry — used by the PDF dialog's `FilledButton`. Leave
  `editorPageSetupApplyAction` alone: the page-setup dialog still uses it.
- Tests:
  - new `test/managers/export/ocpt_export_manager_test.dart`: with a fake save-location service,
    assert that a cancelled dialog returns `null` and writes nothing, that a chosen path receives
    the expected bytes, and that the suggested file name is the one `OcptFountainIoService`
    /`OcptPdfExportService` computes;
  - extend `test/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog_test.dart`: the
    confirm button reads the new key and still returns the expected `OcptPdfExportOptions`.

**Done when** both exports open the platform save dialog, cancelling shows no SnackBar, the written
file lands where the user asked with the right extension, and the PDF dialog's button reads
"Exporter" in French.

### M2 — Sticky character block, and the scroll bar off the page (points 5 and 7)

**Root cause of point 5.** `OcptWysiwygCodec.reclassifyRequests` clears `ocptTypeLocked` as soon as
a node's text is empty ("architecturally a manual type choice only makes sense while the block
still has content"). But a manual choice is *always* made on an empty block: the user picks
"Character" in the dropdown (or Tabs to it), the 120 ms debounce fires while the block is still
empty, the lock is dropped — and the first characters typed are then reclassified. `JOHN` alone,
with no following dialogue line, does not auto-detect as a character cue, so the block becomes
action, and the uppercase pass (which keys off `blockType`) stops applying too.

**Fix.** A manual type choice becomes sticky for the node's whole lifetime: **delete the
lock-clearing branch**. An empty node still keeps its `blockType` untouched (no classification
signal), it simply also keeps its lock. New nodes created by Enter/Shift+Enter are already
unlocked (`ocptEnterToSmartSplit` sets `ocptTypeLocked: false`), so a locked type never leaks into
the next block, and a user who wants a different type on an emptied block Tabs or uses the dropdown
— the same gesture they used to lock it.

- Update the doc comments that state the old behaviour: `ocptTypeLockedMetadataKey`'s
  ("sticky until the block's text is emptied") and `reclassifyRequests`'s, in
  `ocpt_wysiwyg_codec.dart`.
- Update the existing tests in `ocpt_wysiwyg_codec_test.dart` that assert the clearing.
- New tests:
  - codec: a locked character node whose text is emptied keeps its lock and its `blockType`;
  - codec round trip: a **locked** character node holding `JOHN`, last in the document, encodes to
    `@JOHN` (`FountainLineWriter` adds the forcing marker because auto-detection alone would not
    classify it) and decodes back to a character node — this is what makes the fix survive a save
    and reload;
  - widget (`ocpt_styled_screenplay_editor_test.dart`): apply `FountainLineType.character` through
    `OcptStyledEditorController` on an empty block, pump past the 120 ms debounce, type lowercase
    text, pump again, and assert the node is still a character node and its text is uppercased.

**Root cause of point 7.** In `_OcptStyledScreenplayEditorState.build`, `SuperEditor`'s internal
`Scrollable` sits **inside** `SizedBox(width: layout.pageWidth …)`. On desktop, Material's
`ScrollBehavior` automatically wraps vertical scrollables in a `Scrollbar`, so the thumb is painted
at the right edge of that box — i.e. on top of the white sheet.

**Fix.** Move the scroll bar out of the page box, in **both** branches of `build` (page simulation
on and off, so the behaviour is identical):

- wrap the editor subtree in
  `ScrollConfiguration(behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false), …)`
  so super_editor's own scrollable no longer gets an implicit one;
- wrap the outermost `ColoredBox` in an explicit `Scrollbar(controller: _pageScrollController, …)`,
  which paints at the **panel's** right edge while still receiving the descendant scrollable's
  notifications;
- keep `_pageScrollController` as the single scroll controller: `_OcptPageSheetsPainter` reads its
  offset and must stay in sync.
- Test: a widget test asserting exactly one `Scrollbar` in the styled editor's tree and that the
  `SuperEditor` is one of its descendants (so the bar can never come back inside the page box), plus
  a visual check in the manual pass.

**Done when** typing lowercase in a block just set to "Character" keeps it a character cue in
uppercase, and the scroll bar sits in the panel's gutter, never over the sheet.

### M3 — Copy/paste that keeps the block types (point 6)

**Root cause.** `ocptFountainKeyboardActions` inherits super_editor's default clipboard actions,
which put/read **plain text** and, on paste, create nodes with no `blockType`, no
`ocptBlankLinesBefore` and no lock. Every pasted line therefore falls back to auto-detection with a
broken context, i.e. mostly action.

**Design.** The clipboard payload stays **plain Fountain text**: pasting into another editor (or
back into this one after a mode switch) then yields valid Fountain, and text coming from outside the
app keeps working exactly as today (it is decoded as Fountain, so auto-detection applies). The
formatting survives because both ends go through `OcptWysiwygCodec`, not because of a private
clipboard format.

**Work.**

- Codec additions (pure, unit-testable, no live `Editor`):
  - `OcptWysiwygCodec.encodeSelectionToFountain(Document document, DocumentSelection selection)` →
    the Fountain source text of the selected range. Reuse `encode`: build the list of selected
    nodes (clipping the first and last node's text to the selection offsets, attributions
    preserved), and encode that list with `trailingBlankLines: 0`. The first node's
    `ocptBlankLinesBefore` must be forced to 0 so a copied fragment never starts with blank lines.
  - `OcptWysiwygCodec.decodeNodesFromFountain(String text)` → `List<ParagraphNode>` carrying the
    full metadata set, by reusing `decode`'s per-line loop (extract it into a private helper both
    entry points share; do not copy it).
- New `lib/ui/pages/editor/super_editor/ocpt_fountain_clipboard_actions.dart` holding the three
  keyboard actions (`ocptCopyToFountainClipboard`, `ocptCutToFountainClipboard`,
  `ocptPasteFromFountainClipboard`), each guarding on `isPrimaryShortcutKeyPressed` +
  `LogicalKeyboardKey.keyC/keyX/keyV` and returning `ExecutionInstruction.haltExecution` when it
  handled the event, mirroring `ocptCmdUToToggleUnderline`'s shape exactly. Register them at the
  head of `ocptFountainKeyboardActions` and add the superseded defaults to
  `_ocptExcludedDefaultActions`.
  - **Verify the default action names in the installed `super_editor` 0.3.0-dev.52** before writing
    the exclusion set (`grep` the package source in the devcontainer's pub cache); the expected
    names are `copyWhenCmdCIsPressed`, `cutWhenCmdXIsPressed`, `pasteWhenCmdVIsPressed`, but the
    pinned dev release is the source of truth.
  - Paste rules: delete an expanded selection first (`DeleteSelectionRequest`), then, if the
    decoded fragment is a single node, insert its `AttributedText` at the caret (so pasting a few
    words inside a dialogue line does not split it); otherwise split the caret's node and insert the
    decoded nodes between the two halves, merging the fragment's first node into the caret's node
    when that node is not empty. Place the caret at the end of the pasted content. Use the request
    types the pinned dev release actually offers, plus the app's own
    `OcptChangeNodeMetadataRequest`/`OcptReplaceNodeTextRequest`; do not add new command patterns.
  - A plain Tab is not the only gesture that bypasses hardware key events on desktop: **check
    whether Ctrl+V also arrives as an IME delta** (the reason `OcptFountainTabInterceptor` exists).
    If it does, handle it there too, reusing the same shared function the keyboard action calls, and
    document it like the Tab case.
- Tests: codec unit tests (a selection spanning a scene heading + character + dialogue round-trips
  through `encodeSelectionToFountain`/`decodeNodesFromFountain` with types and blank lines intact; a
  partial single-node selection yields just its text) and a widget test in
  `ocpt_styled_screenplay_editor_test.dart` (copy two typed blocks, place the caret elsewhere,
  paste, assert the resulting node types and the encoded source text).

**Done when** copying a character cue + its dialogue and pasting them elsewhere reproduces both
blocks with their types and spacing, and pasting text copied from outside the app still behaves as
before.

### M4 — Scene numbers (point 8)

Three deliverables: the `#N#` syntax works end to end, the styled view can display computed numbers
(option on by default), and the syntax guide documents it.

**Step 1 — reproduce before changing anything.** What the code says today:

- the parser handles it: `FountainBlockBuilder._buildSceneHeading` strips a trailing `#…#` into
  `FountainSceneHeading.sceneNumber` (covered by `packages/fountain_kit/test/block_builder_test.dart`);
- the raw preview renders `"$sceneNumber. $headingText"` (`ocpt_editor_preview_block.dart`), and so
  does `FountainScriptComposer._sceneHeadingLines`;
- the PDF prints the number in **both** margins when the "Include scene numbers" checkbox is on
  (`OcptPdfExportService._buildScriptPage`);
- the **styled editor does nothing with it**: `OcptWysiwygCodec._stripDisplayText` keeps `#1#` in
  the scene heading's display text, so the markup stays visible in a WYSIWYG view and no number is
  rendered anywhere. This is the most likely thing Benoit hit, but it is a deduction — confirm it,
  and check the raw preview and the PDF for yourself, before deciding what to fix. Report what you
  actually observe.

**Step 2 — make `#N#` a first-class WYSIWYG citizen.**

- Add a metadata key `ocptSceneNumberMetadataKey` ("ocptSceneNumber", a `String?`) next to
  `ocptHadForcingMarkerMetadataKey`, documented the same way. `decode` strips a trailing `#N#` from
  a scene heading's **display text** into it; `encode` re-appends `#N#` to the written line when it
  is set, so the round trip stays byte-stable. Extend the existing round-trip and corpus tests.
- The number must not be lost when the user edits the heading's text, and typing `#2#` at the end of
  a heading must be absorbed into the metadata on the next reclassify pass (a new
  `sceneNumberRequests(document)` pass, alongside `uppercaseRequests`, keeps the display text and
  the metadata in sync using `OcptReplaceNodeTextRequest` + `OcptChangeNodeMetadataRequest`).

**Step 3 — the display option.**

- `OcptPropertiesManager`: new `styledSceneNumbersVisible = SharedPreferencesItem<bool>("STYLED_SCENE_NUMBERS_VISIBLE")`,
  documented like `isPageSimulationEnabled`, `null` ⇒ `true`.
- Bloc/state/event: a `areStyledSceneNumbersVisible` field on `OcptEditorState` loaded in
  `_onLoadRequested` next to `isPageSimulationEnabled`, threaded through `copyWith`/`props`, and one
  `OcptEditorStyledSceneNumbersToggledEvent` whose handler emits and persists.
- Toolbar: a `CheckedPopupMenuItem` in the `⋮` menu next to the page-simulation entry, with new ARB
  keys in both languages.
- Numbering rule (put it in one documented pure function, unit-tested on its own): walk the
  document's scene headings in source order; a heading with an explicit `#N#` keeps it and **does
  not** consume a computed number; every other heading takes the next integer starting at 1.
- Rendering, styled mode only: the number appears in the sheet's **left margin**, right-aligned
  close to the heading, and must **not** change the heading's wrap width (it has to keep matching
  the raw preview's typesetting, which `ocpt_styled_screenplay_editor_corpus_test.dart` guards).
  Two acceptable implementations — pick one, document why, and keep it inside
  `lib/ui/pages/editor/super_editor/`:
  1. a `ComponentBuilder` for scene-heading nodes wrapping super_editor's default paragraph
     component and drawing the number into the block's own left padding with a non-clipping
     `Stack`/`Positioned`; or
  2. a gutter overlay in `OcptStyledScreenplayEditor.build`, positioned from the document layout's
     rectangles (`DocumentLayout.getRectForPosition`) like the existing sheet painter.
  Note that `ocpt_fountain_editor_stylesheet.dart`'s class doc currently claims no custom
  `ComponentBuilder` is needed; update it if option 1 is chosen.
- Out of scope, on purpose: the raw preview and the PDF keep printing **explicit** numbers only
  (the PDF already has its own checkbox). Do not wire the new option into them.

**Step 4 — syntax guide.** New `OcptFountainSyntaxTopic.sceneNumber` in the `structure` section,
entry `snippetLines: ["INT. KITCHEN - DAY #1#"]`, `lineType: FountainLineType.sceneHeading`, title
and description keys in both ARB files, and update
`test/models/ocpt_fountain_syntax_entry_test.dart` (it verifies every snippet against the real
parser, so it will also prove the parser accepts the snippet).

**Done when** `#1#` typed in either mode is understood, hidden from the styled display and printed
by the PDF; the styled view numbers every scene by default; unchecking the option removes the
numbers without touching the source; and the guide documents the syntax in both languages.

### M5 — The exported PDF keeps bold/italic/underline (point 9)

**Status: diagnosed — and half of it is already committed.** The three candidate causes this
section originally listed were all investigated by running the real code, and **none of them is
the bug**; do not spend time on them again. What follows replaces that guesswork.

#### What was actually broken, and what fixed it

Point 9's symptom ("bold, italic and underline runs are printed as plain regular text") came from
the **block-level** print style, not from the inline runs. Until 26 July the PDF had no notion of
an element's base typesetting: it printed a scene heading in regular weight and lyrics upright,
while the raw preview *and* the styled editor both showed them bold/italic. Exporting therefore
visibly "lost the bold" of every scene heading.

Four commits, made after this plan was written and **not** reflected above, already fixed that:

| Commit    | What it does                                                                     |
| --------- | -------------------------------------------------------------------------------- |
| `3cc21c9` | `FountainPrintStyle`: the shared base weight/slope/case table, in `fountain_kit` |
| `aef65f5` | `OcptPdfExportService._spansFor` composes the block style with each run's flags  |
| `6feb3bc` | Preview + styled stylesheet re-derived from the same table                       |
| `5b47dcf` | Preview's scene-heading/lyrics branches read the table instead of hardcoding     |

**Do not redo, revert or "improve" any of this.** Read those four commits first.

#### What is verified working today (evidence, not deduction)

Every layer was exercised on HEAD, in the devcontainer:

- `FountainScriptComposer` emits runs carrying `isBold`/`isItalic`/`isUnderline` correctly, and
  `_sliceRuns` keeps them intact across a wrap boundary.
- The generated PDF embeds `CourierPrime-Bold`, `-Italic` and `-BoldItalic` and its content stream
  references the right font resource per run; `_underline_` produces a real stroke path under the
  right character range. Checked for action, dialogue, parenthetical, transition, centred text,
  lyrics, scene heading, dual dialogue, emphasis at line start, and emphasis spanning a wrap.
- The styled editor's B/I/U (both the collapsed-caret `ComposerPreferences` path and the expanded
  selection `ToggleTextAttributionsRequest` path) reaches `onTextChanged` as `**`/`*`/`_` markup,
  and `OcptWysiwygCodec` round-trips all four combinations byte-for-byte.
- `flutter test` is green in both packages (353 + 292 tests).

**The inline-emphasis path is therefore not broken and, per `aef65f5`'s diff, never was.**

#### What M5 still owes

1. **The regression tests that would have caught it, which nobody has written.** `aef65f5`'s new
   test group deliberately restricts each document to a single element type *with no inline
   emphasis of its own* (its own comment says so), precisely so it measures the block style. The
   consequence is that **no test anywhere asserts that an inline emphasis run reaches the PDF at
   all** — the very thing point 9 is about is unprotected, in both packages. Write:
   - in `packages/fountain_kit/test/script_composer_test.dart`: a composed line whose runs carry
     the expected flags for `**bold**`, `*italic*`, `***bold italic***` and `_underline_`, inside
     an action block **and** inside a dialogue line, plus one case where the emphasis spans a wrap
     boundary (both output lines must keep the flag) — so a future failure is attributable to a
     layer;
   - in `test/managers/export/services/ocpt_pdf_export_service_test.dart`: a **new** group,
     alongside (not inside) the existing block-level one, asserting that a document whose *only*
     emphasis is inline embeds the matching variant. Keep the same one-element-per-document
     discipline the existing group established, and say in a comment why: a document-wide
     `contains('CourierPrime-Bold')` is satisfied by any bold anywhere, including a scene
     heading's base weight, which is exactly the gap being closed. For underline (no font of its
     own), compare `_contentStreams` of an underlined document against the same text unemphasised
     and assert they differ — the existing `_contentStreams` helper already does this job for the
     uppercasing group.
2. **The manual end-to-end pass**, which is the only step that can still contradict the above:
   export a PDF containing all four emphasis kinds and open it in a viewer. If Benoit still sees a
   loss there, the `.fountain` source he exported is the missing evidence — capture it verbatim and
   **report instead of guessing**, since every layer above it is now proven in isolation.
3. **One open question for Benoit, which the main session must ask before the agent touches it**
   (it is a UX decision, not a defect to fix silently):

   > In the styled (WYSIWYG) view, typing `**bold**` literally produces no emphasis. The markers
   > stay ordinary characters, and `FountainInlineSerializer` escapes them on encode
   > (`A \*\*bold\*\* word`), so the PDF prints the asterisks. Emphasis in that view is only
   > reachable through the toolbar's B/I/U or Ctrl+B/I/U. That is coherent for a WYSIWYG surface —
   > markers are markup, and markup is hidden there — but it is a trap for a Fountain author with
   > the habit. Should the styled view auto-convert a typed marker pair into real emphasis (the way
   > a `#N#` scene number is absorbed in M4), or stay as it is?

   Answer "stay as it is" ⇒ M5 needs nothing more than points 1 and 2. Answer "auto-convert" ⇒ that
   is a new pass next to `sceneNumberRequests` in `ocpt_wysiwyg_codec.dart`, built the same way
   (`OcptReplaceNodeTextRequest` + the attribution spans), and it deserves its own milestone rather
   than being smuggled into M5.

**Optional cleanup, only if touching those files anyway:** `_baseTextStyle`
(`ocpt_fountain_editor_stylesheet.dart`) and `_baseTextStyleFor`
(`ocpt_editor_preview_block.dart`) both pass `fontWeight: printStyle.isBold ? FontWeight.bold :
null`. `TextStyle.copyWith(fontWeight: null)` keeps the existing value rather than clearing it, so
the `null` branch means "inherit", not "no base weight". Harmless today (the base style carries no
weight of its own), but the code reads as if it asserted the opposite — a one-line doc comment is
enough.

**Done when** the two new test groups fail against a deliberately reverted `_spansFor` and pass on
HEAD, and a manually exported PDF opened in a viewer shows bold, italic, bold-italic and underline.

### M6 — The raw preview reads as paper in dark theme (point 1)

**Status: reproduced and diagnosed — the sheet is genuinely not rendering.** This section replaces
the "needs a visual reproduction first" guesswork that was written here before: the reproduction has
been done, and the cause is a layout bug, not a colour one. Do not re-investigate the surroundings.

#### Evidence (measured, not deduced)

A throwaway widget test pumped `OcptEditorPreview` under `ocptTheme.darkThemeData` and rendered the
panel's `RepaintBoundary` to an image (`toImage()` inside `tester.runAsync`, US Letter metrics, a
panel 40 px wider than `layout.pageWidth`, a five-block screenplay):

| `isPageSimulationEnabled` | Sheet `Material` rect               | Sampled pixels                     |
| ------------------------- | ----------------------------------- | ---------------------------------- |
| `false`                   | `Rect.fromLTRB(20, 0, 1125, 700)`   | `#ffffff`, alpha `ff`, everywhere  |
| `true`                    | `Rect.fromLTRB(20, 0, **20**, 1430)` | fully transparent (alpha `00`) everywhere |

So with page simulation on the white sheet is laid out **zero pixels wide** and paints nothing at
all. Page simulation is on by default (`editor_bloc.dart`: `isPageSimulationEnabled.load() ?? true`),
which is why this is what Benoit sees.

#### Root cause

In `_paginatedPages` (`ocpt_editor_preview.dart`) each page is:

```dart
Stack(
  children: [
    SizedBox(height: layout.pageHeight, child: Material(color: Colors.white, elevation: 2, …)),
    Padding(… child: Column(…blocks…)),
  ],
)
```

Two facts combine:

- that white `Material` is **childless**, and a childless `Material` bottoms out in a
  `RenderProxyBox` with no child, which sizes itself to `constraints.smallest`;
- a `Stack` defaults to `StackFit.loose`, so it lays its non-positioned children out with
  `constraints.loosen()`. The `SizedBox` only tightens the *height*, so what reaches the `Material`
  is `0 ≤ width ≤ pageWidth`, height `= pageHeight`. `constraints.smallest` is therefore
  `Size(0, pageHeight)`.

The sheet collapses to a 0 px-wide sliver. What is left on screen is the second `Stack` child — the
blocks — painting their forced `Colors.black` text straight onto the dock's own themed backdrop
(`OcptEditorDock`'s `ColoredBox(color: colorScheme.surfaceContainerLow)`). In light theme that
backdrop is near-white, so black-on-it still reads correctly and nobody ever noticed; in dark theme
it is `#17161A`, so the text is black on near-black: "everything is dark, nothing is white".

`_paperPage` (page simulation off) is unaffected only because its `Material` *has* a child (the
`ListView`), which gives it a size. The styled editor is unaffected too: it paints its sheets with a
`CustomPainter` (`_OcptPageSheetsPainter`), not with a `Material` — do not touch it.

#### Work

1. **Fix the sheet's width.** Give the childless `Material` an explicit width:
   `SizedBox(width: layout.pageWidth, height: layout.pageHeight, child: Material(…))`. Do **not**
   reach for `Positioned.fill` instead: the `Stack` is sized by its non-positioned `Column`, so a
   filled sheet would take the column's height and lose the simulated page height. Add a short doc
   comment saying why the width is explicit (childless `Material` + `StackFit.loose`), so nobody
   "simplifies" it back.
   - This alone fixes point 1 in both themes. Commit it on its own, before step 2.
2. **Then** make the whole preview panel read as paper in dark theme (decision 4): sheet white,
   panel backdrop white as well, black text, light theme unchanged.
   - The backdrop must be painted by `OcptEditorPreview` itself, **not** by `OcptEditorDock` —
     that dock's colour is shared with the scene panel and the syntax-guide tab, which stay themed.
     Wrap both branches of `OcptEditorPreview.build`, the `_blocks.isEmpty` hint included, so an
     empty screenplay reads as paper too.
   - Carry the colour as a new field on `OcptSpecificColors` (`lib/models/`), given its light and
     dark values in `lib/constants/ocpt_theme.dart` — light keeps today's `surfaceContainerLow`
     value so light mode is byte-identical, dark gets the paper backdrop. That is the class's whole
     purpose and it avoids a `brightness ==` test at the call site; both its own doc comment and
     `ocpt_theme.dart`'s ("no application-specific color … carries no field") then become false and
     must be rewritten, as must the matching `CLAUDE.md` architecture bullet (M8 already lists this).
   - Page boundaries must survive a white backdrop. `Material`'s M3 `shadowColor` resolves to
     `colorScheme.shadow` (opaque black), so the existing `elevation: 2` should still read; **check
     it visually** and, only if it does not, add a hairline `Border.all(color: Colors.black12)`
     through the `Material`'s `shape` rather than deepening the elevation.
3. **Tests** in `test/ui/pages/editor/widgets/ocpt_editor_preview_test.dart`:
   - the regression test that would have caught this and that nobody wrote: every existing test in
     that file pumps with `isPageSimulationEnabled: false`. Add a page-simulation case asserting the
     sheet `Material`'s rect is `layout.pageWidth` wide and `layout.pageHeight` tall — it fails with
     a 0-width rect against today's code, which is the proof the test is worth having;
   - a dark-theme case (`MaterialApp(theme: ocptTheme.darkThemeData, …)`) asserting the resolved
     backdrop colour behind the sheets, and one light-theme case pinning that light mode did not
     move.
   - Mind the finders: the file's existing tests use `find.byType(Material)` unqualified, which
     works today only because `_wrap` has no `Scaffold`. If step 2 adds another `Material`, qualify
     them rather than letting them match ambiguously.
4. Update the doc comments that state the old behaviour: `_paginatedPages`'s ("the panel's own
   (themed) background shows through the gap"), the `OcptEditorPreview` class doc ("a themed gap
   between sheets") and `_paperPage`'s.

**Done when** the raw mode in dark theme, with page simulation both on and off, shows a white
preview panel with black Courier text and visible page boundaries; light mode is untouched; and the
new page-simulation test fails against the un-widened `SizedBox`.

### M7 — The title page, editable in place in the styled view (point 4)

The largest milestone, and the only one that extends the styled editor's document model. **Do not
start coding it before the main session has asked Benoit the design questions below**: `CLAUDE.md`
requires design questions to be answered before building any new view, and he shapes the UI himself.

**Questions for Benoit (main session asks, before the agent starts).**

1. Field order and placement on the sheet — the PDF currently centres title/credit/authors in the
   upper-middle area, and puts contact bottom-left, draft date bottom-right. Same layout in the
   editor?
2. Exact placeholder wording for the empty fields, in both languages (e.g. "Title", "Based on…").
3. Is the title sheet shown when page simulation is **off** (the fluid, theme-following surface), or
   only in page mode?
4. Do `Source` and `Contact` (multi-line) appear on the sheet, and can new author/contact lines be
   added inline?
5. Does the `⋮ ▸ Title page…` dialog stay as a second way in, and does the raw mode's preview get
   the same title sheet?

**Architecture sketch (to be refined once the answers land).**

- `OcptWysiwygCodec` learns the title page. Today its invariant is "one `ParagraphNode` per
  non-blank source line", and `Title:`/`Credit:`/… lines are decoded as ordinary body lines.
  Extend it: the leading title-page span becomes **one node per field**, carrying
  `blockType: <a new title-page-field attribution>` and metadata `ocptTitlePageKey`
  (`Title`, `Credit`, `Author`, `Draft date`, `Contact`, `Source`), with the display text holding
  the **value only** (the `Key: ` part is markup and must be hidden, exactly as forcing markers
  are). Synthesize **all** fields, including the absent ones, as empty nodes so the sheet is always
  complete and fillable; on encode, drop the empty ones.
- Encoding must go through `FountainTitlePageWriter.apply(source:, entries:, existingRange:)` —
  never hand-written `Key: value` lines — so the body is never reformatted, and so the `⋮` dialog
  and the inline editing stay two front-ends over one writer. Mind the interaction with
  `encode`'s blank-line handling: the writer already owns the blank line separating the title page
  from the body.
- `computeOcptStyledPagination` must treat the title page as page 1 and start the body on page 2,
  matching the PDF, and `_OcptPageSheetsPainter` must paint the extra sheet.
- Rendering: new stylesheet rules for the field type (large centred title, centred credit/authors,
  bottom-left contact, bottom-right draft date) and placeholder hints for empty fields — check what
  super_editor 0.3.0-dev.52 offers for hint text on an empty node before writing a custom
  `ComponentBuilder`.
- Non-regressions to keep in mind: `FountainScriptComposer` and the PDF exporter must be untouched;
  `FountainParser`'s title-page pre-pass stays the only parser; the raw mode keeps working on the
  same source text; a screenplay with **no** title page must still open (and then show an empty,
  fillable sheet).
- Tests: codec round trips (no title page → six empty fields → filling one produces
  `Title: …` at the top of the source and nothing else changes), pagination (body starts on page 2),
  and a widget test typing into a placeholder and asserting the encoded source.

Given its size, split M7 into sub-milestones with their own checkpoints (codec + tests first, then
rendering, then the placeholder/editing polish) rather than one long agent run.

### M8 — Documentation & closure

- Add a row to the `CLAUDE.md` development-plan table for issue #15 (one line, same style as the
  existing rows, pointing at this document), and update the `## Architecture` bullets that this
  issue makes stale — at minimum: the export manager's dialogs (M1), the `ocptTypeLocked` stickiness
  rule (M2), the clipboard actions (M3), the new metadata key and scene-number option (M4), the
  preview's colour rule (M6) and the codec's title-page nodes (M7).
- Tick the nine checkboxes of issue #15, then open the pull request from
  `15-editor-and-export-fixes`.

---

## Verification

Run the `CLAUDE.md` gates inside the devcontainer before **every** commit (analyze + test at
minimum, the full list before finishing a milestone):

1. `flutter pub get`
2. `dart run intl_utils:generate`
3. `dart run build_runner build --delete-conflicting-outputs`
4. `flutter analyze` → 0 issues
5. `flutter test` → all green (plus `flutter test` in `packages/fountain_kit` when it changed)
6. `flutter build linux --debug`
7. `reuse lint` → compliant
8. `git grep -l 'allcircuits.com' -- ':!actlibs' ':!CLAUDE.md' ':!docs/plans'` → empty

**Manual end-to-end pass** (after M1–M3, then again after M4–M6, then after M7): export a
screenplay to `.fountain` and to PDF and check the dialog offers a location, the file lands there
and the PDF button reads "Exporter"; set a block to "Character", type lowercase, confirm it stays a
cue in uppercase; scroll the styled editor and confirm the bar stays out of the page; copy a
cue + dialogue and paste them further down; type `#12#` on a heading and confirm the styled view
shows the number and the source keeps it; toggle the scene-number option off and on; export a PDF
containing bold/italic/underline and open it; switch to the dark theme and check the raw preview is
white paper; and, after M7, fill the title page from the styled view and confirm the exported PDF
and the `⋮` dialog agree with it.

Test in **both** light and dark themes, and in **both** English and French, for every milestone that
adds UI or strings.
