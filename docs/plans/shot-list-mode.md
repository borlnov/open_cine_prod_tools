<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Step 19 — Shot list mode (découpage technique)

This document is the implementation strategy for issue
[#19](https://github.com/borlnov/open_cine_prod_tools/issues/19). It is written for the Sonnet 5
agents that will build the feature, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. **Read the repository `CLAUDE.md` first** — this plan assumes
its architecture, ways of working, coding standards, licensing rules and verification gates, and
does not repeat them.

---

## 1. Application context

Everything below is what an agent needs to know before touching a file. It summarises `CLAUDE.md`;
when the two disagree, `CLAUDE.md` wins.

### 1.1 What the app is

Open Cine Prod Tools is an open-source (Apache-2.0) suite of film-production tools. The shipped
feature set is a Fountain screenplay editor inside a workspace shell that already hosts four
production modes, three of which are empty states. This step fills the fourth one in: the **shot
list** (*découpage technique*), the roadmap's next priority after the screenplay editor, together
with the **scenario coverage per shot** that the roadmap lists right behind it — the two are one
feature in practice, since coverage is what ties a shot back to the text it films.

Storage is local only: one SQLite file per project (`.ocpt`, via drift), the Fountain text being
the source of truth alongside a stable-UUID scene index. UI languages are English (`en_GB`, main)
and French.

### 1.2 Structure that matters here

- **Managers.** `OcptGlobalManager extends AbsUiGlobalManager` owns every manager; they are
  `AbsWithLifeCycle` classes resolved through `globalGetIt()`. The ones this step touches:
  `OcptProjectsManager` (owns the open project, its database and the services below),
  `OcptPropertiesManager` (shared-preferences-backed app preferences), `OcptExportManager` (owns
  the export services and the native save dialog), `OcptRouterManager` (go_router; **never use
  `Navigator` directly**, dialogs included).
- **Workspace shell.** `WorkspacePage` mounts `OcptWorkspaceBloc`, whose only state is
  `{ OcptWorkspaceMode mode, bool isLoading }`. `OcptWorkspaceShell` is a stateless slot widget
  (title, toolbar actions, overflow entries, left panel, right panel, centre, status bar, dock
  controller); the end of its toolbar is shell-owned chrome (mode label, dock toggles, save, `⋮`)
  that a mode opts into rather than builds. `OcptWorkspaceDock` /
  `OcptWorkspaceDockDivider` / `OcptWorkspaceDockLayoutController`
  (`lib/ui/pages/workspace/widgets/`) are the dock geometry primitives every mode reuses: a
  draggable divider per side, a 320 px centre floor, and live fractions held in a `ChangeNotifier`
  so a drag never emits one bloc state per frame.
- **BLoC.** ACT pattern: `BlocForMixin`, `BlocStateForMixin`, sealed events registered with
  `registerMixinEvents()` / `on<>`, one bloc per page, split across `*_page.dart` / `*_bloc.dart` /
  `*_state.dart` / `*_event.dart`. `EditorPage` is the reference implementation of a mode that owns
  a bloc.
- **Scene index.** `OcptSceneIndexService.reconcile` runs on **every save** (from
  `OcptScreenplayService.saveScreenplayText`, not on the 150 ms parse debounce) and keeps the
  `scenes` table in step with the parsed document. A scene's id is a **stable UUID**, reused across
  reconciliations through three matching passes (explicit scene number → exact heading → relative
  order). Its doc comment already names shot lists as the intended consumer: this step is what
  that stability was built for.
- **Theme.** Density, shapes and the UI type scale live once in `lib/constants/ocpt_theme.dart`'s
  component themes and its dense `TextTheme`. A new screen inherits the studio look for free and
  **must not** redeclare its own radius, padding or font size where a component theme already says
  it. `OcptSpecificColors` (`lib/models/`) is the `ThemeExtension` for colours that do not fit a
  Material `ColorScheme`; it has two fields today (`previewBackdrop`, `projectPosterTints`).
- **`packages/fountain_kit`.** Pure-Dart parser / serializer / layout metrics with a round-trip
  guarantee. Keep it free of any Flutter import. Relevant API here: `FountainDocument` (`blocks`,
  `sourceText`, `scenes`), `FountainSceneHeading` (`headingText`, `sceneNumber`, `sourceRange`),
  `FountainSceneStatistics.of(document, metrics, sceneIndex)` (`speakingCharacters`, `wordCount`,
  `pageEighths`), `FountainScriptStatistics.of(document, metrics)`, and `normalizeCharacterName`.
- **Page setup.** `OcptPageSetup` pairs the per-project page format with the app-wide margins;
  `OcptPageSetup.toMetrics()` is the single entry point producing a `FountainLayoutMetrics`.

### 1.3 Toolchain reminder

The host has **no usable Flutter SDK**. Every Flutter/Dart/`reuse` command runs in the
devcontainer:

```bash
cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
```

Git commands run on the host, from the repo root.

---

## 2. Why this step exists

`OcptShotListMode` is 43 lines of empty state today. The shot list is the document a director and
a first AD actually work from on set, and it is the first mode that is **not** the screenplay: it
is therefore also the first real test of the workspace shell extracted in step 17. If the shell,
the dock primitives and the toolbar chrome were factored correctly, this mode should need **no
change to any of them**. Any pressure to modify `OcptWorkspaceShell` while building this mode is a
signal worth reporting rather than a change to make quietly.

The step also introduces two firsts for the project:

- the **first drift schema migration** (v1 → v2), and
- the **first per-project data that is authored in the app rather than derived from the Fountain
  text**, which is what makes the coverage/staleness machinery in §4.4 necessary.

---

## 3. The design being implemented

The reference is the *OpenCineProdTools App Design* mock-up in the Claude Design project
`5bc089e5-85ae-42c2-b8c4-445abc90ecf4` (its `decoupage` mode), itself derived from a real
`Découpage technique.xlsx` shot list. What follows is that mock-up restated as a specification;
where this plan and the mock-up differ, **this plan wins** — the differences are the decisions
recorded in §3.5.

### 3.1 Left dock — sequences and shots

A tree. Header `Séquences` / `Sequences` with the total shot count on the right. One entry per
**sequence**, which in this app *is* a screenplay scene: its scene number in accent, its heading,
and a muted second line `N shots · avg. difficulty 1,8`. The selected sequence expands to list its
shots, indented: the shot code in Courier Prime, a ⚠ when the shot needs checking, the shot size
ellipsised, and a status dot at the end. A single `+ Shot` button in the footer (the mock-up's
`+ Séquence` button is dropped, see §3.5).

### 3.2 Centre — the shot table

Top to bottom:

1. **Deleted-character banner(s)**, one per character the screenplay no longer names anywhere
   (neither cued nor written in capitals in an action) but that is still attached to shots:
   `CLARA was removed from the screenplay but still appears in 3 shots: 1/4 · 3/1 · 3/2.`, with a
   `Remove from every shot` button and a row of replacement chips for the remaining characters.
2. **Sequence header**: `Sequence 1 — INT. LÉA'S FLAT - NIGHT`, and under it
   `4 shots · avg. difficulty 1,8 · 3 left to shoot`.
3. **`Columns ▾` menu** and an **`Export XLSX`** button, right-aligned on the same row.
4. **The table.** A leading 14 px gutter carrying the ⚠, then the columns.

   *Always shown:* Shot, Characters, Shot size, Framing & composition, Camera move, Diff.
   *Optional, toggled from the menu and persisted:* Set, Lens, Format, Duration, Takes, Sound,
   Shooting day, Status. The mock-up's defaults are Duration, Shooting day and Status on, the rest
   off.

   Shot size, framing, camera move and set wrap onto several lines; every other column is a single
   ellipsised line. The shot code is Courier Prime and semi-bold; `Diff.` is semi-bold and turns
   warning-coloured at ≥ 2,5; the status cell takes its status colour. The selected row gets a
   2 px accent bar on its left edge and an accent wash. Clicking a row selects the shot **and**
   opens the right dock on its inspector tab.

### 3.3 Right dock — the shot inspector

Tabbed, like the screenplay's. Tabs: `Inspector`, `Metadata`. The inspector shows, in order:

- `Shot 1/3` in Courier Prime with a read-only status pill next to it (decision 10), and the
  sequence heading under it.
- A **`Needs checking`** callout when the shot is stale: the reason, and a `Mark as checked`
  button.
- **Characters in shot** — chips, click to toggle. A character removed from the screenplay but
  still attached shows struck through in the error colour with a `(removed)` suffix, and stays
  listed until it is untoggled.
- **Scenario coverage** — the heart of the panel, see §4.4 for the model. In the dock it is
  **read-only**: a `Select…` button, then one entry per range in the order they read in the
  sequence — the Fountain line types the range runs through (`ACTION → DIALOGUE`), the covered
  extract quoted with its line breaks, a `modified` badge when the text changed since it was
  recorded, and `Also covered by 1/2 · 1/4` when other shots cover the same extract. Footer: `N words covered of M · P range(s)` and a `Clear all` action.
  The selecting itself happens in the dialog `Select…` opens (see §3.3.1): the dock is too narrow
  to click words in comfortably, and a shot's coverage is read far more often than authored.
- **Image** — Shot size, Framing & composition, Camera move, Lens, Format. Framing & composition
  and Camera move are written as several lines, like the director's notes are.
- **Difficulty — avg. 1,8** — four labelled bars (Set, Camera move, Acting, Sound) on 0-5, the bar
  warning-coloured at ≥ 3 and error-coloured at ≥ 4.
- **Production** — Estimated duration, Sound (several lines too), Sequence. No shooting day and no
  planned takes: see decision 10.
- **Director's notes** — free multi-line text.
- **Location scouting** — a free multi-line list of labels (see §3.5).

### 3.3.1 The scenario coverage dialog

The sequence typeset on a **simulated paper sheet** — white page, Courier Prime, the true
screenplay indents/widths/alignments of the project's own page setup, exactly as the screenplay
mode's raw preview renders the same text (`OcptEditorPreviewLayout` is shared between the two).

The text is **printed, not raw**: emphasis markers, a forced line's leading character, a heading's
trailing `#N#` and inline notes are resolved away exactly as the paper preview resolves them
(`ocptFountainWordDisplayRuns`), and a blank line of vertical space is left only where the source
has one, so an action paragraph's lines and a cue/parenthetical/dialogue block read as one
paragraph. The words' own **source** offsets are untouched by any of that: a range still covers the
source text, markers included.

Every word is a click target whose box carries the whitespace that follows it plus a little
vertical padding, so the whole band around a word is clickable rather than its glyphs alone, and a
recorded range reads as **one continuous highlight** rather than a row of word-sized patches. A
click starts a range, a second click closes it **wherever it lands** — a range may run from one
block into the next, and clicking the same word twice records a one-word range — and a click on
already-covered text removes the range covering it. A shot may record as many ranges as it needs.
The first clicked word is painted in the accent itself while the range is open, so what the next
click will close is never in doubt. Another shot's coverage stays a faint wash, with
`Also covered by 1/2 · 1/4` under the block. Footer: the same counters, the `Clear all` action, and
a one-line hint describing the current interaction state.

### 3.4 Status bar

`3 sequences · 9 shots · 2 shot · 2 to check`.

### 3.5 Decisions taken against the mock-up

These were settled with Benoit before this plan was written. They are not open questions.

| # | Decision |
| - | -------- |
| 1 | **A sequence is strictly a screenplay scene.** No free-standing sequences, no `shot_sequences` table, no `+ Sequence` button: a shot references a `scenes` row directly, and its sequence number and set are *read from* the scene index, never duplicated into the shot list. |
| 2 | **A scene deleted from the screenplay never destroys its shots.** They are detached and grouped at the end of the left dock under an `Orphaned shots` entry, carrying the heading the scene had when it disappeared, with an explicit delete action. See §4.3. |
| 3 | **The table is read-only; all editing happens in the inspector.** The table stays a dense, legible synthesis. No inline cell editing, no keyboard grid navigation. |
| 4 | **A shot's characters come from the screenplay's whole cast, plus free additions** for extras. The cast is the dialogue cues *and* the names written in capitals in the action, the convention a screenplay introduces a character with — a role that never speaks is named nowhere else. This is what makes the deleted-character banner meaningful. |
| 5 | **Shot codes are fully automatic**: `<scene number>/<1-based rank in the scene>`, recomputed on every insertion, deletion and reorder. No manual override, no `bis`. |
| 6 | **The image and sound fields are free text with project-wide suggestions**, not enums: the shot-list vocabulary varies too much between crews to close it. Suggestions are the distinct values already entered elsewhere in the same project. |
| 7 | **The mock-up's `Versions` tab is out of scope.** Project versioning (read-only preview, fork, restore, its `canEdit` flag threaded through every mode) is its own future step. Nothing in this step should anticipate it beyond not making it harder. |
| 8 | **Location scouting is a plain multi-line text field** for now, a deliberate placeholder for the future locations module rather than a modelled relation. |
| 9 | **XLSX export is in scope**, as the last milestone. PDF export of the shot list is not. |
| 10 | **Everything a shot's scheduling decides stays out of this mode.** The status, the shooting day and the planned takes are read-only here — the status pill is a read-out, the other two are absent from the inspector and only read out by the metadata tab. They keep their columns (the table can show them, the XLSX export writes them) and become editable in the shooting schedule mode, which is what owns them. |
| 11 | **The fields written as a sentence are multi-line**, as tall as the director's notes: Framing & composition, Camera move and Sound. They keep their project-wide suggestions all the same. |

---

## 4. Architecture

### 4.1 Overview

```text
lib/models/database/tables/     ocpt_shots_table.dart
                                ocpt_shot_characters_table.dart
                                ocpt_shot_coverages_table.dart
lib/models/database/            ocpt_project_database.dart      (schema v2 + migration)
lib/models/                     ocpt_shot.dart, ocpt_shot_sequence.dart,
                                ocpt_shot_coverage_range.dart, ocpt_shot_list_snapshot.dart
lib/types/                      ocpt_shot_status.dart, ocpt_shot_difficulty_axis.dart,
                                ocpt_shot_list_column.dart, ocpt_shot_list_right_dock_tab.dart
lib/managers/projects/services/ ocpt_shot_list_service.dart
                                ocpt_shot_coverage_service.dart
lib/managers/export/services/   ocpt_shot_list_xlsx_export_service.dart
lib/ui/pages/workspace/modes/shot_list/
                                shot_list_mode.dart / _bloc.dart / _state.dart / _event.dart
                                widgets/…
```

Nothing under `lib/ui/pages/editor/` or `lib/ui/pages/workspace/widgets/` is expected to change.

### 4.2 Database — schema v2

Three new tables. Every id is a UUID generated with the `uuid` package, exactly as screenplays,
snapshots and scenes already are.

**`shots`** (`@DataClassName('OcptShotRow')`)

| Column | Type | Notes |
| ------ | ---- | ----- |
| `id` | text, PK | stable UUID |
| `screenplayId` | text → `screenplays.id` | the shot list is per screenplay, like the scene index |
| `sceneId` | text? → `scenes.id` | **nullable**: null means orphaned (§4.3) |
| `orphanedHeading` | text? | the scene's heading at the moment it was deleted; null while `sceneId` is set |
| `position` | int | 0-based rank within its scene (or within the orphan group) |
| `shotSize` | text | "Shot size" — the mock-up's *valeur de plan* |
| `framing` | text | "Framing & composition" — *angle et composition du cadre* |
| `cameraMove` | text | *mouvement d'appareil* |
| `lens` | text | *focale / objectif* |
| `recordingFormat` | text | *format / cadence*, e.g. `4K · 25 fps` |
| `estimatedDurationMs` | int? | rendered `m:ss` |
| `shootingDay` | text? | free text until the schedule mode exists |
| `plannedTakes` | int? | |
| `sound` | text | |
| `status` | text, converter | `OcptShotStatus`, via a `TypeConverter` modelled on `OcptSnapshotReasonConverter` |
| `difficultySet` / `difficultyCamera` / `difficultyActing` / `difficultySound` | int | 0-5, default 1 |
| `notes` | text | director's notes |
| `locationNotes` | text | §3.5 decision 8 |
| `needsCheck` | bool | default false |
| `checkReason` | text? | |

The shot **code is never stored**: it is derived at read time from the scene's number and the
shot's `position` (decision 5). A scene with no explicit `#N#` uses its 1-based index among the
screenplay's scenes, matching what styled mode already displays.

**`shot_characters`** — `shotId` → `shots.id`, `characterName` (normalised through
`normalizeCharacterName`, the same normalisation `FountainSceneStatistics.speakingCharacters`
uses, so comparisons against the screenplay are exact), `position`. PK `{shotId, characterName}`.

**`shot_coverages`** — `id` (UUID, PK), `shotId` → `shots.id`, `sceneId` → `scenes.id`,
`startOffset`, `endOffset`, `coveredTextDigest` (text). See §4.4.

**Migration.** `schemaVersion` goes to 2 and `OcptProjectDatabase` gains its first
`MigrationStrategy`: `onCreate` creates everything, `onUpgrade` from 1 to 2 creates the three new
tables and nothing else. An existing `.ocpt` file must open, migrate silently and keep every
screenplay, snapshot and scene it had. `beforeOpen` should enable `PRAGMA foreign_keys` so the
references above are actually enforced — verify whether it is already on before assuming either
way, and if turning it on breaks an existing test, report it rather than dropping the FKs.

Add a short ADR under `docs/adr/` for the migration policy: what schema versions mean for a user's
existing project files, and that migrations are additive-only for now.

### 4.3 Sequences, and what happens when a scene disappears

A sequence is not a stored row. `OcptShotListService` builds `OcptShotSequence` objects in memory
by joining the `scenes` rows (already ordered by `position`) with the shots that reference them,
then appends one synthetic "orphans" sequence holding every shot whose `sceneId` is null, grouped
by `orphanedHeading`.

The detaching itself has an ordering problem worth stating plainly: `OcptSceneIndexService
.reconcile` deletes unmatched `scenes` rows inside its own transaction, and by then it is too late
to copy their headings anywhere. **Dependencies never reference their dependents**, so the scene
index service cannot call into the shot list service.

The resolution: `reconcile` gains an optional
`Future<void> Function(List<OcptSceneRow> scenesAboutToBeDeleted)? onScenesDeleted` parameter,
invoked inside its existing transaction immediately **before** the deletions. `OcptScreenplayService`
— which already owns the call — passes `OcptShotListService.detachShotsFromDeletedScenes`. The
scene index service still knows nothing about shots; it just offers a hook at the one moment where
the information exists. Its doc comment must be updated to say so.

The reverse case matters too: a scene that comes *back* (an undo, a re-import) gets a fresh UUID
and will not re-adopt its orphans automatically. That is accepted — the orphan group is visible and
its shots can be moved back by hand. Do not build heuristic re-adoption.

### 4.4 Scenario coverage — the model

This is the part to get right; everything else in this step is CRUD.

**What is stored.** A coverage range is `(sceneId, startOffset, endOffset)` where the offsets are
character offsets **relative to the scene's `charStart`**, not to the document. A scene that moves
because a scene above it grew therefore keeps every range it had, with no rewriting at all: only
edits *inside* the scene disturb it.

**Why not word indices.** The mock-up manipulates `(blockIndex, startWord, endWord)`. That is the
right shape for the *interaction* but the wrong shape for *storage*: a block inserted above shifts
every index below it, and block indices mean nothing across a reparse. The UI converts between the
two at the edges — words are laid out from the scene's text, and a click resolves to the character
offsets of the first and last word of the range.

**Staleness.** `coveredTextDigest` is a digest of the exact substring the range covered when it was
recorded. After `OcptSceneIndexService.reconcile` has refreshed the scenes' `charStart`/`charEnd`,
`OcptShotCoverageService.refreshStaleness` re-reads each range's substring from the new text and
compares digests. Any mismatch — including a range that no longer fits inside its scene, which is
clamped and counted as changed — sets `needsCheck` on the owning shot with a localised
`checkReason`, and marks the block as `modified` in the inspector. `Mark as checked` clears
`needsCheck` **and** re-stamps the digests to the current text, so the shot goes quiet until the
next real change.

This runs on save, in the same pass as the scene reconciliation — never on the 150 ms parse
debounce. A director does not want a shot flagged mid-keystroke.

**A range may span several blocks.** The interaction closes a range wherever the second click
lands, so a range legitimately runs from an action paragraph into the dialogue below it; nothing
constrains it beyond being non-empty and staying inside its own scene, which is what its offsets
are relative to. The inspector labels such a range with every block type it runs through.

**Ranges of one shot merge as soon as they join.** `addRange` absorbs every range of the same shot
and scene that overlaps the new one, touches it, or is separated from it by whitespace alone —
repeatedly, so a range bridging two existing ones absorbs both — and stores the whole span as a
single row, digest restamped. Whitespace counts as joined because the sheet paints each word's
trailing whitespace with it: two ranges one space apart already read as one continuous highlight,
so keeping them as two rows would be a distinction the user cannot see. Two different shots, or two
different scenes, never merge.

### 4.5 Services

- **`OcptShotListService`** — CRUD over shots and their characters; loads the whole
  `OcptShotListSnapshot` for a screenplay in one go (shots + characters + coverage, three queries,
  joined in memory — a shot list is hundreds of rows, not millions); renumbers positions on insert,
  delete and reorder; `detachShotsFromDeletedScenes`; collects the distinct values of each free-text
  field for the suggestion lists of decision 6.
- **`OcptShotCoverageService`** — adds, removes and clears ranges; computes digests;
  `refreshStaleness`; computes the per-block "also covered by" sets the inspector renders.

Both are owned by `OcptProjectsManager` and constructed alongside `OcptScreenplayService` and
`OcptSceneIndexService`, following RFL18 exactly as `OcptExportManager` owns its three services.

### 4.6 UI

`OcptShotListMode` becomes a stateful page mounting `OcptShotListBloc`, structured exactly like
`EditorPage` / `OcptEditorBloc`. Its state carries the loaded snapshot, the selected sequence and
shot, the dock open/closed flags and fractions, the visible columns, the active right-dock tab, and
the derived deleted-character alerts. Editing a shot goes through events; the bloc writes through
the services and re-emits.

**Autosave.** Reuse the editor's convention: a 2 s debounce on field edits, flushed synchronously
on `deactivate()` so switching mode or navigating back never loses a pending edit. Toggles that are
not typing (status, a character chip, a coverage range) write immediately.

Widgets, all under `modes/shot_list/widgets/`:

| Widget | Role |
| ------ | ---- |
| `OcptShotListSequencePanel` | left dock tree, §3.1 |
| `OcptShotListTable` + `OcptShotListRow` | centre table, §3.2 |
| `OcptShotListColumnsMenu` | the `Columns ▾` popup |
| `OcptShotListRemovedCharacterBanner` | the alert of §3.2.1 |
| `OcptShotListRightDock` | the tab row + body, modelled on `OcptEditorRightDock` |
| `OcptShotInspectorPanel` | §3.3, minus the coverage block |
| `OcptShotCoverageSummary` | the inspector's read-only list of covered extracts |
| `OcptShotCoverageDialog` | the paper sheet the coverage is selected on, §3.3.1 |
| `OcptShotDifficultyBars` | the four bars |
| `OcptShotListStatusBar` | §3.4 |

Take the colours from the `ColorScheme` and the metrics from the component themes. The mock-up's
literal hex values are the dark theme's existing tokens and must **not** be re-hardcoded; the two
status colours that have no `ColorScheme` equivalent (the "shot" green and the "retake" amber) go
into `OcptSpecificColors` as a per-brightness family, like `projectPosterTints` already does.

The table's horizontal overflow scrolls inside its own scroll view; the page itself never scrolls
horizontally.

### 4.7 Types and preferences

`OcptShotStatus { toShoot, shot, retake }`, `OcptShotDifficultyAxis { set, camera, acting, sound }`,
`OcptShotListColumn` (one value per optional column, with an `isDefaultVisible` getter matching the
mock-up's defaults), `OcptShotListRightDockTab { inspector, metadata }`.

New `OcptPropertiesManager` items, modelled on the editor's: `shotListLeftDockFraction`,
`shotListRightDockFraction`, `shotListVisibleColumns` (the column enum names, joined), and
`shotListLastRightDockTab`. Reuse `SharedPrefsItemWithParser` as `workspaceMode` does for the enum
cases.

`OcptWorkspaceMode.isImplemented` stops being `== screenplay` and returns true for `shotList` too.

### 4.8 XLSX export

`OcptShotListXlsxExportService`, owned by `OcptExportManager`, writing through the existing
`OcptSaveLocationService` so the export goes through the native save dialog like every other one —
no export ever writes to a default location silently. One sheet, one header row, one row per shot,
grouped by sequence with the sequence heading as a separator row; the columns are **every** column,
not only the visible ones, since the spreadsheet is what leaves the app.

New direct dependency: `excel`. Add it to `pubspec.yaml` with a comment saying what it is for, as
every other dependency there does, and record the choice in `docs/adr/`.

---

## 5. Milestones

Each milestone ends with the full verification gate of `CLAUDE.md` §*Verification gates*, one
commit per logical change, and a user checkpoint before the next one starts.

### M1 — Schema, migration, services

Tables, `OcptShotStatus` + its converter, schema v2 with its `MigrationStrategy`, the FK pragma,
`OcptShotListService`, `OcptShotCoverageService`, the `onScenesDeleted` hook on
`OcptSceneIndexService.reconcile` and its wiring in `OcptScreenplayService`. The ADR on migration
policy.

Tests: migration from a v1 database preserving all existing data; shot CRUD and renumbering;
detaching on scene deletion, including the heading being preserved; coverage ranges surviving a
scene that moves; staleness firing on an edit inside a covered range and staying quiet on an edit
outside it; `Mark as checked` re-stamping digests.

No UI at all in this milestone.

### M2 — The mode, its left dock, its table

`OcptShotListBloc` + state + events, `OcptShotListMode` mounting the shell with its two docks,
`OcptShotListSequencePanel`, `OcptShotListTable`, `OcptShotListColumnsMenu`, the dock fraction and
column preferences, `isImplemented`. Shots are selectable and creatable; the inspector is still a
placeholder. `OcptSpecificColors` gains the status colour family.

Report at the checkpoint whether `OcptWorkspaceShell` needed any change — it should not.

### M3 — The shot inspector

`OcptShotListRightDock`, `OcptShotInspectorPanel`, `OcptShotDifficultyBars`, every field editable
with the 2 s debounce and the `deactivate()` flush, the free-text suggestions, the character chips,
the read-only status pill, the metadata tab. Coverage is still absent from the panel.

### M4 — Scenario coverage

`OcptShotCoverageSummary` and `OcptShotCoverageDialog`: the read-only extract list, the paper
sheet, word ranges, the three-state click interaction, the "also covered by" wash, the `modified`
badges, the counters, `Clear all`, the `Needs checking` callout and `Mark as checked`, the ⚠ in the
table gutter and the left dock.

This is the milestone with the most interaction surface. Test the offset ↔ word-index conversion
directly, at the service and model level, rather than only through the widget.

### M5 — Alerts and status bar

The deleted-character banner with its remove-all and replace actions, the orphaned-shots group in
the left dock with its explicit delete, `OcptShotListStatusBar`.

### M6 — XLSX export

The `excel` dependency and its ADR, `OcptShotListXlsxExportService`, the `Export XLSX` button, the
`⋮` entry, tests on the produced workbook's shape.

---

## 6. Out of scope

Stated so no agent drifts into them: project versioning and the mock-up's `Versions` tab; any link
between a shot and the shooting schedule beyond the free-text `shootingDay`; a locations/scouting
module; storyboard thumbnails on shots; PDF export of the shot list; importing an existing
`Découpage technique.xlsx`; and any change to the screenplay editor's own behaviour.
