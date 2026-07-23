<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Step 14 — Editor statistics

This document is the implementation strategy for step 14. It is written for the Sonnet 5 agents
that will build the feature, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. Read the repository `CLAUDE.md` first — this plan assumes its
architecture, ways of working, coding standards, and verification gates.

## Context

Open Cine Prod Tools is a Fountain screenplay editor. Steps 0–13 are done; **step 14 adds an
editor statistics bar** so the writer sees, at a glance and while typing, how long and how dense
the screenplay is and when it was last saved. Everything this step needs already exists and is
only being read, not reinvented: the paginator that the PDF export prints from
(`FountainScriptComposer`), the parsed `FountainDocument` (scenes, character cues, printable
blocks), and the `lastSavedAt` field the bloc already keeps — it is simply never shown anywhere
yet.

The one genuinely new piece is a pure-Dart statistics computer in `fountain_kit`; the rest is
wiring it into the bloc and rendering a thin status bar under the editing area.

**Decisions locked with Benoit:**

1. **Metrics shown: page count, scene count, speaking-character count, word count, sign
   (character) count, last-saved time.** All five counters are shown; "characters" in the UI
   means **speaking roles**, and the raw glyph count is labelled **"signs"** to avoid the
   character/character ambiguity.
2. **Location: a status bar at the bottom of the editor**, a thin discreet band under the editing
   area, `surfaceContainerLow` like the toolbar, visible in **both** styled and raw modes. On a
   narrow window it degrades from the right: the least structural counters drop first (signs,
   then words), and the saved-state segment is never dropped.
3. **Last-saved time: relative and self-refreshing** — "Saved 2 minutes ago", reusing the home
   page's relative-time formatter, refreshed by a 30 s timer owned by a small stateful widget.
4. **Counting is done over printable content only** (the body the writer sees on the page): notes,
   boneyard, synopses, sections and the title page are excluded from word/sign counts, exactly
   like `OcptEditorPreviewLayout.printableBlocks` already filters them for the preview and the PDF.

---

## Architecture & reuse map (consume these, do not reinvent)

| Concern | Existing asset to reuse | Path |
| --- | --- | --- |
| Printed page count (same number the PDF prints) | `FountainScriptComposer.compose(document, metrics).pages.length` | `packages/fountain_kit/lib/src/layout/fountain_script_composer.dart` |
| Layout geometry driving pagination | `FountainLayoutMetrics`; get it via `OcptPageSetup.toMetrics()` (the app's single `switch(format)`) | `packages/fountain_kit/lib/src/layout/`, `lib/models/ocpt_page_setup.dart` |
| Parsed screenplay model (scenes, character cues, blocks) | `FountainDocument.scenes`, sealed `FountainBlock` subclasses (`FountainCharacter.name`/`extension`, `FountainDialogueGroup`), `FountainLineType` | `packages/fountain_kit/lib/src/models/` |
| Non-printing block filter (drop section/synopsis/note/boneyard) | `OcptEditorPreviewLayout.printableBlocks(document)` — **reference the same filtering rule**; if the statistics computer needs it Flutter-free, replicate the rule in `fountain_kit`, do not import the UI layer | `lib/ui/pages/editor/widgets/ocpt_editor_preview_layout.dart` |
| Relative-time formatter ("2 minutes ago" / "il y a 2 minutes") | `formatHomeRelativeTime(context, dateTime, {now})` — to be generalized out of the home widgets | `lib/ui/pages/home/widgets/ocpt_home_relative_time.dart` |
| Last-save timestamp (already tracked, never displayed) | `OcptEditorState.lastSavedAt`, set in `_saveCurrentText` | `lib/ui/pages/editor/editor_bloc.dart`, `editor_state.dart` |
| State field plumbing template (`copyWith` + `props`, never-null-back fields) | `OcptEditorState` (`document`, `pageSetup`) | `lib/ui/pages/editor/editor_state.dart` |
| Where the document is (re)computed and would drive a recompute | `_onLoadRequested`, `_onParseRequested`, `_onImportRequested`, `_onTitlePageChanged` | `lib/ui/pages/editor/editor_bloc.dart` |
| Page layout the status bar slots into (Column under the toolbar / editing Row) | `_EditorViewState.build` | `lib/ui/pages/editor/editor_page.dart` |
| Discreet toolbar styling to mirror (`surfaceContainerLow`, `labelSmall`) | `OcptEditorToolbar` | `lib/ui/pages/editor/widgets/ocpt_editor_toolbar.dart` |

**Hard constraints:** `actlibs/` is an untouchable submodule; `packages/fountain_kit` must stay
**Flutter-free** (pure Dart, `test` package — no `flutter/*` import, so the printable-block filter
is replicated there, not imported from `lib/`); `lib/generated/` is generated. Every new Dart file
gets the 3-line Apache-2.0 SPDX header; ARB keys are covered by the blanket `REUSE.toml`. All
navigation and dialogs go through `OcptRouterManager` (this step adds no dialog, but the rule
stands). Never reference the plan, step numbers, or these instructions in code or commit messages.

**Performance note carried into M2:** `FountainScriptComposer.compose` is a full line-level
pagination pass — materially heavier than `FountainParser.parse`. It must **not** be assumed cheap
enough to run on the 150 ms parse debounce; M2 measures it before choosing where the recompute
lives (see M2).

---

## Milestones (one Sonnet 5 agent per milestone, checkpoint between each)

### M1 — Pure statistics computer (fountain_kit, no UI)

Build the pure-Dart value that turns a `FountainDocument` + `FountainLayoutMetrics` into the six
counters. Lives in `fountain_kit` (reusable, Flutter-free, unit-testable in the pure suite).

- New module `packages/fountain_kit/lib/src/layout/fountain_script_statistics.dart`, exporting an
  immutable `FountainScriptStatistics` (Equatable) with:
  - `pageCount` — `FountainScriptComposer().compose(document, metrics).pages.length` (the same
    paginator the PDF prints from, so the on-screen number matches the exported PDF exactly; `0`
    for an empty document).
  - `sceneCount` — `document.scenes.length`.
  - `speakingCharacterCount` — the number of **distinct** speaking roles: collect every
    `FountainCharacter.name` (dual-dialogue counts both), normalize each (trim, collapse inner
    whitespace, upper-case), and drop the parenthetical extension (`(V.O.)`, `(O.S.)`, `(CONT'D)`)
    so the same role spoken with and without an extension counts once.
  - `wordCount` / `signCount` — over **printable blocks only** (replicate
    `OcptEditorPreviewLayout.printableBlocks`' rule: keep scene heading, action, character,
    parenthetical, dialogue, lyrics, transition, centered text; drop section, synopsis, note,
    boneyard, page break, and the title page). `wordCount` splits each block's rendered text on
    whitespace runs; `signCount` counts characters of that same text (define precisely in the doc
    comment whether spaces are included — count **non-whitespace** signs, matching what a writer
    means by "signs", and state it).
  - A factory `FountainScriptStatistics.of(document, metrics)` doing the computation, plus a
    `FountainScriptStatistics.empty` const for the no-document state.
- Keep it Flutter-free: pure `import 'package:fountain_kit/...'`, no `flutter/*`. If the printable
  filter is only in the UI layer today, replicate the block-type rule here (single source of truth
  is fine to duplicate across the package boundary, since `fountain_kit` cannot depend on `lib/`).
- Export the new symbol from `packages/fountain_kit/lib/fountain_kit.dart`.
- Unit tests next to the other layout tests (pure `package:test`): empty document (all zero);
  a short corpus asserting each counter; distinct-character normalization (same name with/without
  `(V.O.)` counts once; dual dialogue counts two); word/sign counts exclude notes/boneyard/
  synopsis/section and the title page; `pageCount` matches `compose(...).pages.length` on a
  multi-page corpus with a forced page break.

### M2 — Bloc & state wiring (recompute cadence measured, not assumed)

- Add `final FountainScriptStatistics statistics` to `OcptEditorState`: initialise it to
  `FountainScriptStatistics.empty` in `OcptEditorState.init`, thread it through `copyWith`
  (never-null-back, like `document`) and `props`.
- Recompute it wherever the document is (re)built: `_onLoadRequested`, `_onParseRequested`,
  `_onImportRequested` (after its inline parse), `_onTitlePageChanged` (after its re-parse). The
  metrics come from `state.pageSetup.toMetrics()`; recompute on `_onPageSetupChanged` too, since
  `pageCount` depends on the page format.
- **Measure the compose cost first.** Time `FountainScriptComposer().compose` on a long script
  (≈100+ pages — reuse or extend a corpus fixture) inside the devcontainer. Then choose:
  - if it is cheap (well under one frame, ≲ a few ms), fold the recompute into the existing parse
    path (`_onParseRequested`) — no new timer;
  - if it is not, give statistics their **own debounce** (a separate `Timer`, ≈ 500 ms, cancelled
    in `close`/`disposeLifeCycle` alongside the existing timers) so heavy pagination never runs on
    every 150 ms parse tick and never blocks typing.

  Record the measured figure and the resulting choice in the M2 commit body (not in code).
- Do **not** touch the save path: `lastSavedAt` is already set correctly in `_saveCurrentText`.
- Tests (`editor_bloc_test.dart` idioms): statistics populate after load; update after an edit is
  parsed; survive an import; reflect a page-format change. Keep debounces overridable by the test
  constructor as the parse/autosave ones already are (add a `statisticsDebounce` parameter only if
  M2 introduces a separate timer).

### M3 — Status bar widget + l10n + page wiring

- Generalize the relative-time formatter: move `formatHomeRelativeTime` out of
  `lib/ui/pages/home/widgets/ocpt_home_relative_time.dart` into a shared location
  (`lib/ui/widgets/` or `lib/ui/utils/`), renamed without the `home` prefix (e.g.
  `formatRelativeTime`); update the home page's single call site and its test. Keep the existing
  `homeRelativeTime*` ARB keys (they are generic wording) — only the Dart symbol moves.
- New `lib/ui/pages/editor/widgets/ocpt_editor_status_bar.dart`:
  - A `StatelessWidget` taking the six pieces of data (`statistics` + `lastSavedAt`), rendering a
    thin `surfaceContainerLow` band, `labelSmall`, segments joined by `·`:
    `12 pages · 34 scenes · 8 characters · 9 412 words · 52 108 signs · Saved 2 minutes ago`.
  - Right-to-left degradation on width: wrap the counter row so that, when horizontal space is
    tight, the signs segment drops first, then words; **the saved-state segment is always kept**.
    (A `LayoutBuilder` choosing which segments to include by measured width is enough; do not let
    the row overflow or ellipsize the whole line.)
  - The saved-state segment is the only stateful part: a small private stateful widget holding a
    `Timer.periodic(Duration(seconds: 30))` that calls `setState` to re-run `formatRelativeTime`,
    cancelled in `dispose`. When `lastSavedAt` is null, show a "not saved yet" wording instead of
    a relative time.
- Wire it into `editor_page.dart`: add the status bar as the last child of the main `Column`
  (below the editing `Expanded`), fed from `state.statistics` and `state.lastSavedAt`, shown in
  both modes. It renders under the loading guard (only once `state.isLoading` is false).
- l10n — **both** `intl_en_GB.arb` and `intl_fr.arb`, ICU plurals for each counter:
  `editorStatsPages`, `editorStatsScenes`, `editorStatsCharacters`, `editorStatsWords`,
  `editorStatsSigns` (each `{count, plural, ...}`), `editorStatsSavedRelative` (takes the already
  formatted relative string, e.g. "Saved {time}"), `editorStatsNeverSaved` ("Not saved yet").
  Regenerate `Tr`.
- Tests (`ocpt_editor_status_bar` widget test + `editor_page_test.dart` touch-up): all counters
  render; empty-document / never-saved states; the narrow-width degradation keeps the saved
  segment and drops signs/words. For the relative-time refresh, pump with a controllable clock or
  assert the formatted string rather than waiting on the real 30 s timer.

### M4 — Documentation & closure

- This file is the plan; no code milestone. On completion of M1–M3:
  - Flip step 14 to ✅ in the `CLAUDE.md` development-plan table.
  - Add one line to the `CLAUDE.md` "Architecture" section for `FountainScriptStatistics` (pure
    `fountain_kit` statistics over the printable body, page count via `FountainScriptComposer`,
    surfaced by the editor status bar).
  - No new ADR is needed (this step introduces no structural decision beyond the existing ones).

---

## Verification (every milestone, inside the devcontainer)

Run the `CLAUDE.md` gates before each commit:
`flutter pub get` → `dart run intl_utils:generate` → `dart run build_runner build
--delete-conflicting-outputs` → `flutter analyze` (0) → `flutter test` (green) → `flutter build
linux --debug` → `reuse lint` (compliant) → `git grep -l 'allcircuits.com' -- ':!actlibs'` empty.

**End-to-end manual check** (after M3): open a project, confirm the status bar shows plausible
page / scene / character / word / sign counts in **both** styled and raw modes; type and watch the
counts follow (after the debounce) and the page count match a subsequent PDF export; save and
watch "Saved just now" appear, then relax into "Saved a minute ago"; narrow the window and confirm
signs → words drop while the saved segment stays; open an empty project and confirm the zero /
"Not saved yet" state.

**Per-commit trailer** for Sonnet agents: `Co-Authored-By: Claude Sonnet 5
<noreply@anthropic.com>`. New Dart files get the 3-line Apache-2.0 SPDX header; ARB keys are
covered by the blanket `REUSE.toml`.
