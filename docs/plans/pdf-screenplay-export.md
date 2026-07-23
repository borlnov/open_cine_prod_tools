<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Step 12 — PDF screenplay export

This document is the implementation strategy for step 12. It is written for the Sonnet 5 agents
that will build the feature, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. Read the repository `CLAUDE.md` first — this plan assumes its
architecture, ways of working, coding standards, and verification gates.

## Context

Open Cine Prod Tools is a Fountain screenplay editor. Steps 0–11 are done; **step 12 adds PDF
export** of the screenplay. The editor already anticipates it: `OcptExportManager`'s doc comment
says *"the PDF export will hang its PDF method off this same manager"*, the layout engine
(`FountainLayoutMetrics`) and the Fountain model are Flutter-free and pure, and Courier Prime
(4 styles) is already bundled and OFL-licensed. This step turns the on-screen page simulation
into a real, printable PDF, and adds a title-page editor so the work's metadata can be set before
exporting.

**Decisions locked with Benoit:**

1. **Pagination fidelity: full professional US conventions** — long blocks are split across the
   page boundary; dialogue split across a page repeats the character cue with `(MORE)` at the
   bottom and `CHARACTER (CONT'D)` at the top; a scene heading is never left orphaned as the last
   line of a page; a character cue is never the last line of a page.
2. **Numbering: standard US** — page number top-right (`2.`) from the 2nd script page onward
   (title page and 1st script page unnumbered); scene numbers in **both** left and right margins
   opposite each scene heading, rendered only when the "scene numbers" option is checked.
3. **Title page is configurable before export** — a dedicated **"Title page…"** dialog in the
   editor `⋮` menu, whose fields are written **into the Fountain source** title-page section (the
   source of truth), so they round-trip through `.fountain` and PDF export alike. Fields: **Title,
   Credit, Author, Draft date, Contact, Source**.
4. The PDF title page is generated from that title-page metadata, with a minimal fallback to the
   project name when absent. Inclusion is toggleable from the export dialog (default on).

---

## Architecture & reuse map (consume these, do not reinvent)

| Concern | Existing asset to reuse | Path |
| --- | --- | --- |
| Layout geometry (page size, margins, per-element indent/width/alignment, `linesPerPage`) | `FountainLayoutMetrics` (pure); get it via `OcptPageSetup.toMetrics()` — the app's single `switch(format)` | `packages/fountain_kit/lib/src/layout/`, `lib/models/ocpt_page_setup.dart` |
| Parsed screenplay model | `FountainDocument` (`blocks`, `titlePage`, `scenes`), sealed `FountainBlock` subclasses, `FountainLineType` | `packages/fountain_kit/lib/src/models/`, `.../parser/` |
| Inline bold/italic/underline | `FountainInlineParser().parseRuns(text)` → `FountainStyledRun{isBold,isItalic,isUnderline}` | `packages/fountain_kit/lib/src/parser/fountain_inline_parser.dart` |
| Title-page fields | `FountainTitlePage` getters (`title`, `credit`, `authors`, `source`, `draftDate`, `contact`) + `entries`/`entry(key)`; splice via `sourceRange.startOffset/endOffset` | `packages/fountain_kit/lib/src/models/fountain_title_page.dart` |
| Non-printing block filter | `OcptEditorPreviewLayout.printableBlocks(document)` (drops section/synopsis/note/boneyard) | `lib/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart` |
| Existing block-level paginator (reference algorithm, NOT reused as-is — we go line-level) | `_refreshPaginatedCaches` running-sum-vs-`linesPerPage` rule | `lib/ui/pages/editor/widgets/ocpt_editor_preview.dart` |
| Native save dialog (bytes → file) | `OcptExportManager.exportFountain` → `FileSaverManager.saveFileFromBytes(fileName, bytes)`; filename helper `fountainIoService.fountainFileName` | `lib/managers/export/ocpt_export_manager.dart` |
| Suggested project/file name from title page | `OcptFountainIoService.suggestedProjectName` / `_sanitize` | `lib/managers/export/services/ocpt_fountain_io_service.dart` |
| Options dialog template (prefilled dropdown + validated fields + router-manager pop) | `OcptEditorPageSetupDialog` | `lib/ui/pages/editor/widgets/ocpt_editor_page_setup_dialog.dart` |
| Menu item + dialog-first wiring template | `⋮` `PopupMenuButton` + `_requestPageSetup` | `lib/ui/pages/editor/widgets/ocpt_editor_toolbar.dart`, `lib/ui/pages/editor/editor_page.dart` |
| Bloc export handler template (flush dirty → call manager → IoNotice) | `_onExportRequested`, `OcptEditorIoNotice`/`OcptEditorIoNoticeKind` | `lib/ui/pages/editor/editor_bloc.dart`, `editor_state.dart` |
| Screenplay read/write | `OcptScreenplayService.loadScreenplayText/saveScreenplayText` (with `OcptSnapshotReason`) | `lib/managers/projects/services/ocpt_screenplay_service.dart` |

**Hard constraints:** `actlibs/` is an untouchable submodule; `packages/fountain_kit` must stay
**Flutter-free** (pure Dart, `test` package); `lib/generated/` is generated. The `pdf` package's
widgets work in **points (1 in = 72 pt)** — convert every inch measurement from the metrics by
×72. Courier is 10 cpi / 6 lpi → 12 pt glyph advance, 12 pt line height. `(MORE)`/`(CONT'D)` are
screenplay content tokens, kept as English constants (**not** localized through `Tr`).

---

## Milestones (one Sonnet 5 agent per milestone, checkpoint between each)

### M1 — Pure pagination engine (fountain_kit, no UI, no `pdf`)

Build the pure-Dart engine that turns a `FountainDocument` + `FountainLayoutMetrics` into a
positioned, paginated page model implementing the pro conventions. Lives in `fountain_kit`
(reusable, Flutter-free, unit-testable in the pure suite).

- New module, e.g. `packages/fountain_kit/lib/src/layout/fountain_script_composer.dart`,
  exporting:
  - a **line-wrapper** that turns each printable block's text into the exact wrapped Courier lines
    for its element's `maxWidthColumns` (mirror the greedy word-wrap of
    `OcptEditorPreviewLayout.wrappedLineCount`, but **emit the strings**, carrying each line's
    `FountainStyledRun`s and its element type + left-indent / alignment).
  - a **page composer** packing those lines into pages of `metrics.linesPerPage`, applying:
    `FountainPageBreak` → fresh page; **dialogue split** → repeat cue + `(MORE)` /
    `CHARACTER (CONT'D)`; **no orphan scene heading / character cue** as a page's last line (push
    the whole group to the next page); blank-line spacing between blocks matching the preview.
  - output data model: `FountainScriptLayout` = `List<FountainScriptPage>`; each page a list of
    positioned lines (`leftIndentInches`, `alignment`, styled runs, `isSceneHeading` + optional
    `sceneNumber` so M2 can place both-margin numbers).
- Unit tests next to `layout_metrics_test.dart` (pure `package:test`): wrapping widths per
  element, page break honoured, dialogue `(MORE)`/`(CONT'D)`, orphan-heading push, `linesPerPage`
  boundary, dual-dialogue adjacency preserved.
- Export the new symbols from `packages/fountain_kit/lib/fountain_kit.dart`.

### M2 — PDF rendering service + font embedding + manager save

- Add `pdf: ^3.x` to `pubspec.yaml`; list `assets/fonts/courier_prime/` under `flutter: assets:`
  (defensive, for `rootBundle.load`). Run the generators / gates.
- New `lib/managers/export/services/ocpt_pdf_export_service.dart`, owned by `OcptExportManager`
  (RFL18, like `fountainIoService`). Responsibilities:
  - Lazy-load & cache the 4 Courier Prime TTFs via `rootBundle.load(...)` → `pw.Font`
    (regular / bold / italic / boldItalic).
  - **Title page** `pw.Page` from `document.titlePage` getters (Title centered; Credit + Author
    below; Contact bottom-left; Draft date bottom-right), fallback to project name; skipped when
    the option is off.
  - **Body**: consume `FountainScriptLayout` from M1; render each `FountainScriptPage` as one
    `pw.Page` sized from metrics (inches × 72), each line a `pw.RichText` / `pw.TextSpan` in 12 pt
    Courier at its indent, 12 pt line height, runs mapped to bold / italic / underline.
  - **Page number** top-right from the 2nd script page; **scene numbers** in both margins when
    `includeSceneNumbers` is on.
  - Return `Uint8List`.
- Add `exportPdf({required FountainDocument document, required OcptPageSetup pageSetup, required
  OcptPdfExportOptions options, required String projectName})` on `OcptExportManager`: generate
  bytes via the service, save via `_fileSaverManager.saveFileFromBytes(fileName: "$projectName.pdf",
  bytes: ...)`, return the path. Add a `pdfFileName` helper mirroring `fountainFileName`.
- Tests: service test (bundle assets available in `unit_test_assets`) asserting `%PDF` magic,
  non-empty output, page count == paginator page count (+1 when title page on), determinism.

### M3 — Export options dialog + menu + bloc + snackbar (end-to-end usable)

- New `OcptPdfExportOptions` model (`format`, `margins`, `includeSceneNumbers`,
  `includeTitlePage`).
- New `lib/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart`, a near-copy of
  `OcptEditorPageSetupDialog`: format dropdown **prefilled from `state.pageSetup`**, a
  `CheckboxListTile` "Include scene numbers" and one "Include title page" (both default on);
  `static show(...)` returning `OcptPdfExportOptions?`, popped through the router manager.
- Toolbar: add `final VoidCallback onExportPdf` + a `PopupMenuItem` "Export to PDF…" in the `⋮`
  menu (`ocpt_editor_toolbar.dart`); wire `_requestExportPdf(context)` in `editor_page.dart`
  (dialog-first, exactly like `_requestPageSetup`).
- Bloc: `OcptEditorExportPdfRequestedEvent(options)`; handler mirrors `_onExportRequested` —
  cancel debounces, flush dirty text (`OcptSnapshotReason.export`), parse current `state.text`,
  call `exportManager.exportPdf(...)`, emit success / failure via new `OcptEditorIoNoticeKind`
  values (`pdfExportSucceeded` / `pdfExportFailed`) surfaced in `_ioNoticeMessage`.
- l10n: `editorExportPdfAction`, dialog title / labels / checkboxes / actions, success (`{path}`)
  and error messages, in **both** `intl_en_GB.arb` and `intl_fr.arb`; regenerate `Tr`.

### M4 — Title-page editor dialog + source splice

- Pure helper in fountain_kit, e.g. `packages/fountain_kit/lib/src/serializer/
  fountain_title_page_writer.dart`: `apply({required String source, FountainSourceRange?
  existingRange, required List<FountainTitlePageEntry> entries})` → new source by **offset splice**
  (`source.substring(0, startOffset) + block + source.substring(endOffset)`; prepend block + blank
  line when no existing title page; drop the section when all fields are empty). Never
  full-serializes the document (that would re-normalize the body). Unit-tested in the pure suite
  (insert / replace / remove, body left byte-identical).
- New `lib/ui/pages/editor/widgets/ocpt_editor_title_page_dialog.dart` (page-setup dialog pattern):
  fields Title, Credit, Author, Draft date, Contact, Source, prefilled from the parsed
  `document.titlePage`; `static show(...)` returns the field values; popped via router manager.
  **Benoit shapes the field layout / labels** — mirror the existing dialog unless he refines it.
- Menu item "Title page…" in the `⋮` menu; `_requestTitlePage(context)` in `editor_page.dart`;
  bloc `OcptEditorTitlePageChangedEvent` → build new source via the helper → `saveScreenplayText`
  (`OcptSnapshotReason.manual`) → refresh `state.text` / `document`.
- l10n keys for the dialog + menu, both ARBs; regenerate `Tr`.

---

## Verification (every milestone, inside the devcontainer)

Run the `CLAUDE.md` gates before each commit:
`flutter pub get` → `dart run intl_utils:generate` → `dart run build_runner build
--delete-conflicting-outputs` → `flutter analyze` (0) → `flutter test` (green) → `flutter build
linux --debug` → `reuse lint` (compliant) → `git grep -l 'allcircuits.com' -- ':!actlibs'` empty.

**End-to-end manual check** (after M3): open a project, `⋮ → Export to PDF…`, pick format +
options, save, open the PDF and verify: title page, both-margin scene numbers, page numbers from
page 2, a dialogue block split across a page shows `(MORE)`/`(CONT'D)`, bold / italic / underline
render, Courier Prime embedded. After M4: `⋮ → Title page…`, edit fields, confirm they persist in
the `.fountain` source and appear on the next PDF / `.fountain` export.

**Per-commit trailer** for Sonnet agents: `Co-Authored-By: Claude Sonnet 5
<noreply@anthropic.com>`. New Dart files get the 3-line Apache-2.0 SPDX header; ARB keys are
covered by the blanket `REUSE.toml`.
