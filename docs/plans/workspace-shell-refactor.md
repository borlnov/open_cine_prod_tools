<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Step 16 — Workspace shell refactor

This document is the implementation strategy for issue
[#16](https://github.com/borlnov/open_cine_prod_tools/issues/16). It is written for the Sonnet 5
agents that will build the feature, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. **Read the repository `CLAUDE.md` first** — this plan assumes
its architecture, ways of working, coding standards, licensing rules and verification gates, and
does not repeat them.

---

## 1. Application context

Everything below is what an agent needs to know about the product before touching a view. It
summarises `CLAUDE.md`; when the two disagree, `CLAUDE.md` wins.

### 1.1 What the app is

Open Cine Prod Tools is an open-source (Apache-2.0) suite of film-production tools. The shipped
MVP is a **Fountain screenplay editor**. The roadmap adds, in priority order: shot list (découpage
technique), scenario coverage per shot, shooting schedule, call sheets, budget, script supervisor
reports, storyboard, breakdown, casting tracker. Targets are Linux and Windows first. Storage is
local only: one SQLite file per project (`.ocpt`, via drift), the Fountain text being the source of
truth alongside a stable-UUID scene index. UI languages are English (`en_GB`, main) and French.

### 1.2 Structure that matters here

- **Managers.** `OcptGlobalManager extends AbsUiGlobalManager` owns every manager; they are
  `AbsWithLifeCycle` classes resolved through `globalGetIt()`. The ones this step touches:
  `OcptPropertiesManager` (shared-preferences-backed app preferences),
  `OcptRouterManager` (go_router; **never use `Navigator` directly**, dialogs included),
  `OcptProjectsManager` (open project, screenplay service, scene index).
- **Routing.** `enum OcptRoute with MixinRoute { home, editor, settings, licenses }`. The `editor`
  route is guarded: it redirects to `home` when no project is open.
- **BLoC.** ACT pattern: `BlocForMixin`, `BlocStateForMixin`, sealed events registered with
  `registerMixinEvents()` / `on<>`, one bloc per page, split across `*_page.dart` / `*_bloc.dart` /
  `*_state.dart` / `*_event.dart`.
- **Theme.** `ActThemesManager` with `OcptAppTheme.standard`; the light and dark `ColorScheme`s are
  built in `lib/constants/ocpt_theme.dart` from the seed `0xFF6C5CE7`, the dark one overriding its
  neutral surfaces down to near-black. `OcptSpecificColors` (`lib/models/`) is the
  `ThemeExtension` for colours that do not fit a Material `ColorScheme` — it is **currently empty**,
  and this step is the first to give it a field.
- **`packages/fountain_kit`.** Pure-Dart parser / serializer / layout metrics with a round-trip
  guarantee. Keep it free of any Flutter import. Relevant API:
  `FountainDocument` (`titlePage`, `blocks`, `sourceText`, `scenes`), `FountainSceneHeading`
  (`headingText`, `sceneNumber`, `sourceRange`), `FountainTitlePage` (`entries`, typed getters),
  `FountainLayoutMetrics` (`linesPerPage`, per-element layouts), `FountainScriptComposer.compose()`
  → `FountainScriptLayout.pages` → `FountainScriptPage.lines` (each `FountainScriptLine` carries
  `isSceneHeading` and `sceneNumber`), and `FountainScriptStatistics.of(document, metrics)`.
- **Editor internals.** super_editor styled mode keeps one `ParagraphNode` per non-blank Fountain
  source line; `OcptWysiwygCodec` is the only Fountain ↔ document (de)serializer. Debounces: parse
  150 ms, autosave 2 s, styled reclassify 120 ms, the last one **flushed synchronously on
  `deactivate()`** so a pending edit survives a mode toggle or a back navigation. Ctrl+S saves,
  Ctrl+Shift+M toggles the editing mode.
- **Editor docks.** `OcptEditorDock` / `OcptDockDivider` give the left scene panel and the right
  dock draggable-divider resizing with a 320 px centre floor; widths are fractions of the editing
  row, persisted through `OcptPropertiesManager.editorLeftDockFraction` /
  `editorRightDockFraction`. `OcptEditorDockLayoutController extends ChangeNotifier` holds the live
  fractions during a drag so no bloc state is emitted per frame; one
  `OcptEditorDockFractionsChangedEvent` is dispatched on `onHorizontalDragEnd`. The right dock
  (`OcptEditorRightDock`) is tabbed (`OcptEditorRightDockTab { preview, syntax }`).
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

Today `EditorPage` owns the entire application chrome: the toolbar, the left scene dock, the right
tabbed dock, the status bar, and the dock geometry that ties them together (`editor_page.dart`,
536 lines; `editor_bloc.dart`, 827 lines). All of it is screenplay-specific. Every future
production tool of the roadmap — shot list first — would have to rebuild that chrome or graft
itself into a bloc that already juggles the Fountain source, two editing engines, autosave, import,
export and pagination.

The validated Claude Design mock-up (*OpenCineProdTools design shell*,
`https://claude.ai/design/p/5bc089e5-85ae-42c2-b8c4-445abc90ecf4`) answers this with a **DaVinci
Resolve-style workspace**: one persistent shell around an open project — top toolbar, resizable
side docks, status bar — and a **bottom mode switcher** choosing which production tool fills it.
Resolve's Media / Cut / Edit / Fusion / Color / Fairlight / Deliver page bar is the exact reference,
and it is already the visual reference `CLAUDE.md` names for the whole application.

This step builds that shell and re-parents the screenplay editor into it. The other modes ship as
empty states: the point is the structure, not new features.

### What the mock-up changes, concretely

Comparing the mock-up to the current build, screen by screen:

| Area | Verdict |
| --- | --- |
| Home (project grid, header actions, card layout) | Already conformant. Only the per-project poster tint differs (the mock-up shows four different tints, the app paints every card `primaryContainer`). |
| Settings (appearance / language / about cards) | Already conformant. No work. |
| Editor toolbar, docks, dividers, status bar, right-dock tabs | Already conformant in *look*. The gap is *ownership*: they belong to the editor, not to a shell. |
| Bottom mode switcher | **Missing entirely.** |
| Right dock: Inspector and Metadata tabs | **Missing entirely.** |
| Right dock: History tab | Missing, and **out of scope** (see §3, decision 6). |
| Budget / Schedule / Shot list content | Mock-up content is illustrative fiction. **Out of scope** (see §3, decision 2). |

---

## 3. Decisions locked with Benoit

1. **The shell is a layout widget, not a god-bloc.** `OcptWorkspaceShell` is a stateless widget
   taking slots (title, toolbar actions, overflow entries, left panel, right dock, centre, status
   bar, back action). The only new bloc, `OcptWorkspaceBloc`, owns **one** thing: which production
   mode is active. Each mode keeps its own bloc and its own state, including its dock geometry.
   This is what keeps `OcptEditorBloc` — the largest and most delicate file in the repo —
   untouched in substance.
2. **Budget, Schedule and Shot list ship as empty states.** "Coming in a future version", nothing
   else. No new drift table, no schema migration, no placeholder data, no fake numbers in the UI.
   The mock-up's budget tables and shooting-day rows are illustrative only.
3. **The active mode is persisted app-wide**, through a new `OcptPropertiesManager` item, exactly
   like `editorMode` (styled/raw) is today. Opening any project restores the last mode used.
4. **The right dock gains an Inspector tab and a Metadata tab**, both fed by real data computed
   from `fountain_kit`. No mock content.
5. **The dock's tab row becomes clickable.** Step 15's decision 3 made the toolbar buttons the only
   tab selectors, which worked for two tabs and does not scale to four. The mock-up shows the tab
   row itself as the selector. The toolbar keeps its preview and syntax buttons (they also *open* a
   closed dock); Inspector and Metadata are reachable from the tab row only, so the toolbar does not
   grow two more icons.
6. **No History tab.** `screenplay_snapshots` rows exist, but listing and restoring a snapshot is a
   feature of its own — it needs a restore flow, a confirmation, and a story for what happens to
   unsaved work. Deliberately deferred.
7. **Both brightnesses stay supported.** The mock-up only shows dark. Every new surface reads its
   colours from `Theme.of(context).colorScheme` (or `OcptSpecificColors`), never from the mock-up's
   hex literals. The mock-up's hex values are already the dark `ColorScheme`'s values — verify
   against `lib/constants/ocpt_theme.dart` rather than hard-coding.
8. **`lib/ui/pages/editor/` does not move on disk.** The screenplay mode keeps living there. A
   directory rename would touch every import and every test file for no behavioural gain; it can be
   a separate rename-only commit later if wanted.

### Target layout

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ ▣  Les Sentiers de Verre ●        [Action ▾] B I U   Screenplay  ▤ ▥ 💾 ⋮ │  ← shell toolbar
├──────────────┊─────────────────────────────────┊─────────────────────────┤
│ Scenes    10 ┊                                 ┊ Preview │Syntax│Insp.│… │
│              ┊   1  INT. LÉA'S FLAT - NIGHT    ┊─────────────────────────│
│ 1  INT. LÉA  ┊                                 ┊ Scene 1                 │
│ 2  EXT. STA  ┊   A room lit by one desk lamp.  ┊  LOCATION / TIME        │
│ 3  INT. CAF  ┊                                 ┊  INT. LÉA'S FLAT-NIGHT  │
│              ┊              LÉA                ┊  CHARACTERS             │
│  ← mode-provided left panel                    ┊  LÉA, MARC              │
├──────────────┴─────────────────────────────────┴─────────────────────────┤
│ 42 pages · 10 scenes · 6 characters · 8 640 words      Saved 2 min ago    │  ← shell status bar
├──────────────────────────────────────────────────────────────────────────┤
│        ▤ Screenplay      ⊙ Budget      ▦ Schedule      ▥ Shot list        │  ← mode switcher
└──────────────────────────────────────────────────────────────────────────┘
   ┊ = draggable divider (unchanged from step 15)
```

The mode switcher is the only new horizontal band. Everything above it keeps the geometry step 15
established.

---

## 4. Architecture & reuse map (consume these, do not reinvent)

| Concern | Existing asset to reuse | Path |
| --- | --- | --- |
| Toolbar idiom (`IconButton` `size: 20`, localized tooltip, `PopupMenuButton` overflow, dirty dot) | `OcptEditorToolbar` | `lib/ui/pages/editor/widgets/ocpt_editor_toolbar.dart` |
| Status bar idiom (`labelSmall`, ` · ` joins, width-driven degradation, self-refreshing saved time) | `OcptEditorStatusBar` | `lib/ui/pages/editor/widgets/ocpt_editor_status_bar.dart` |
| Dock geometry, dividers, centre floor, persisted fractions | `OcptEditorDock`, `OcptDockDivider`, `OcptEditorDockLayoutController` | `lib/ui/pages/editor/widgets/ocpt_editor_dock.dart`, `lib/ui/pages/editor/ocpt_editor_dock_layout_controller.dart` |
| Tabbed dock chrome (tab row, active underline, `×`) | `OcptEditorRightDock` | `lib/ui/pages/editor/widgets/ocpt_editor_right_dock.dart` |
| Where the chrome is assembled today (the `Column` → toolbar / `Row` / status bar) | `_EditorViewState.build` | `lib/ui/pages/editor/editor_page.dart` |
| Persisted app preference template (`SharedPrefsItemWithParser`, enum by `name`) | `editorMode` | `lib/managers/ocpt_properties_manager.dart` |
| Bloc + state + sealed events template for a small page | `OcptSettingsBloc` and friends | `lib/ui/pages/settings/` |
| Empty-state idiom (icon, message, actions, centred) | `OcptHomeEmptyState` | `lib/ui/pages/home/widgets/ocpt_home_empty_state.dart` |
| App-level enum convention | `ocpt_editor_mode.dart`, `ocpt_editor_right_dock_tab.dart` | `lib/types/` |
| Scene list, current-scene highlight | `OcptEditorScenePanel` | `lib/ui/pages/editor/widgets/ocpt_editor_scene_panel.dart` |
| Script-wide counters, and the shape a new statistics type should take | `FountainScriptStatistics` | `packages/fountain_kit/lib/src/layout/fountain_script_statistics.dart` |
| Title-page field reading | `FountainTitlePage`, `OcptEditorTitlePageDialog` | `packages/fountain_kit/…/fountain_title_page.dart`, `lib/ui/pages/editor/widgets/ocpt_editor_title_page_dialog.dart` |
| Theme extension mechanics | `OcptSpecificColors` | `lib/models/ocpt_specific_colors.dart` |

### Hard constraints

- `actlibs/` is an untouchable submodule; `lib/generated/` is generated; `**/*.g.dart` is
  git-ignored and regenerated by `build_runner`.
- `packages/fountain_kit` stays **Flutter-free**. M3 adds one pure-Dart type to it; if a Flutter
  import feels necessary, the code belongs in `lib/` instead.
- Every new Dart file gets the 3-line Apache-2.0 SPDX header; every declaration gets a doc comment.
- Every user-visible string goes through `Tr.of(context)` and exists in **both**
  `lib/l10n/intl_en_GB.arb` and `lib/l10n/intl_fr.arb`. Regenerate with
  `dart run intl_utils:generate`.
- All navigation and dialogs go through `globalGetIt().get<OcptRouterManager>()`.
- Tests use inline private test doubles (no shared helpers directory) and set
  `BlinkController.indeterminateAnimationsEnabled = false` when pumping super_editor widgets.
- Never reference this plan, its milestones, or the agent instructions in code or commit messages.
  Issue numbers are allowed in commits and PRs.

### Known pitfalls (from `CLAUDE.md`, still true)

- super_editor is pinned to `0.3.0-dev.52` exactly.
- super_editor stylesheets only merge `TextStyle`/padding: one mutually exclusive `StyleRule` per
  Fountain line type, no `BlockSelector.all` baseline.
- No full-app-boot widget tests: `PackageInfo.fromPlatform()` hangs on unmocked platform channels.
  Pump pages and widgets directly.
- `flutter test` runs on the plain Dart VM and needs the system `libsqlite3`.

---

## 5. Milestones

One Sonnet 5 agent per milestone. A checkpoint with Benoit closes each one. The verification gates
of `CLAUDE.md` (analyze + test at minimum, the full list before finishing the step) must pass
before every commit.

---

### M1 — Extract the shell from the editor

**Goal: a pure refactor. At the end of M1 the app looks and behaves exactly as it does today**, and
every existing test still passes without being rewritten to match a new structure. No mode
switcher yet, no new mode, no route change.

**Work.**

- New directory `lib/ui/pages/workspace/widgets/`, holding:
  - `ocpt_workspace_shell.dart` — `OcptWorkspaceShell`, a `StatelessWidget` assembling, top to
    bottom: the toolbar, the docks row, the status bar. Its slots:

    | Slot | Type | Meaning |
    | --- | --- | --- |
    | `title` | `String` | The open project's name. |
    | `isDirty` | `bool` | Drives the dot next to the title. |
    | `onBack` | `VoidCallback` | The back action; the mode decides what flushing it implies. |
    | `toolbarActions` | `List<Widget>` | Mode-specific controls, right-aligned before the overflow. |
    | `overflowEntries` | `List<PopupMenuEntry<void>>` | The `⋮` menu; empty means no `⋮` button. |
    | `leftPanel` | `Widget?` | Null means the mode has no left dock (no divider either). |
    | `rightPanel` | `Widget?` | Null means the mode has no right dock. |
    | `centre` | `Widget` | The mode's main area. |
    | `statusBar` | `Widget?` | Null means no status band. |
    | `dockLayoutController` | `OcptEditorDockLayoutController?` | Null when the mode has no dock. |
    | `onDockFractionsChanged` | `ValueChanged<…>?` | Dispatched once on drag end. |

    The shell **must not** import anything from `lib/ui/pages/editor/` except the dock widgets and
    the dock layout controller, which move under `lib/ui/pages/workspace/widgets/` as part of this
    milestone (`OcptEditorDock` → `OcptWorkspaceDock`, `OcptDockDivider` → `OcptWorkspaceDockDivider`,
    `OcptEditorDockLayoutController` → `OcptWorkspaceDockLayoutController`). Update the editor's
    imports, `editor_bloc.dart`'s references to the default fractions, and
    `test/ui/pages/editor/widgets/ocpt_editor_dock_test.dart` (move it to the matching new path).
  - `ocpt_workspace_toolbar.dart` — the toolbar extracted from `OcptEditorToolbar`, keeping only
    what is mode-agnostic: back button, title, dirty dot, a trailing slot for the mode's actions,
    and the overflow menu. Everything screenplay-specific (save, editing-mode toggle, format
    controls, preview/syntax buttons, export entries) stays in the editor and is passed in as
    `toolbarActions` / `overflowEntries`.
  - `ocpt_workspace_status_bar.dart` — the status bar generalised: a `summary` string on the left
    and a `trailing` widget on the right. The width-driven degradation and the self-refreshing
    relative time stay where they belong: the *degradation* moves here (it is generic), the
    *saved-time* segment stays a screenplay concern passed as `trailing`.

    Preserve the existing degradation order — sign count drops first, then word count — by having
    the mode pass its counters as an ordered `List<String>` plus a count of how many are
    non-droppable.
- `editor_page.dart`: `_EditorViewState.build` now returns `OcptWorkspaceShell(...)` instead of
  hand-assembling `Column`/`Row`. `EditorPage` keeps its name, its route and its `Scaffold`.
- Delete nothing that still has a caller. `OcptEditorToolbar` and `OcptEditorStatusBar` are
  **replaced**, not kept as dead code: their screenplay-specific parts become the editor's
  contribution to the shell slots (put the format controls in
  `lib/ui/pages/editor/widgets/ocpt_editor_format_controls.dart`, extracted verbatim from the
  private `_OcptFormatControls`).

**Tests.**

- Move and adapt `ocpt_editor_dock_test.dart` to the new path and names; its assertions do not
  change.
- New `test/ui/pages/workspace/widgets/ocpt_workspace_shell_test.dart`: a null `leftPanel` renders
  neither dock nor divider; an empty `overflowEntries` renders no `⋮`; the drag-end callback fires
  exactly once per drag.
- New `test/ui/pages/workspace/widgets/ocpt_workspace_status_bar_test.dart`: the degradation order
  and the non-droppable floor.
- `editor_page_test.dart` and `editor_bloc_test.dart` must pass **unchanged**, apart from imports.
  If an assertion has to change, the refactor changed behaviour — fix the refactor, not the test.

**Commit.** `refactor(editor): extract the workspace shell`

---

### M2 — Production modes and the bottom mode switcher

**Goal: the shell hosts four modes; the screenplay is one of them; the last used mode is
remembered.** This is the milestone that changes what Benoit sees, so it ends with a visual
checkpoint.

**Work.**

- New `lib/types/ocpt_workspace_mode.dart`:

  ```dart
  enum OcptWorkspaceMode { screenplay, budget, schedule, shotList }
  ```

  Order matters: it is the display order of the switcher. Document each value with what the mode
  is *for*, and mark the three unimplemented ones as such.
- `OcptPropertiesManager`: a new `workspaceMode` item, a `SharedPrefsItemWithParser` storing
  `value.name` and parsing back to the enum, modelled **exactly** on `editorMode` — including the
  private top-level parser function and the doc comment stating that null means
  `OcptWorkspaceMode.screenplay`. Add the matching case to
  `test/managers/ocpt_properties_manager_test.dart`.
- `OcptRoute`: rename `editor` → `workspace`, and update `OcptRoutesHelper`, the route guard (the
  "no project open → home" redirect keeps the same behaviour), `OcptRouterManager`, and every call
  site. This is mechanical; do it in its own commit so the review is trivial.
- New `lib/ui/pages/workspace/`:
  - `workspace_page.dart` — `WorkspacePage`, the route page: `BlocProvider(create: OcptWorkspaceBloc)`
    over a `_WorkspaceView` that dispatches the load event and switches on the active mode:

    ```text
    WorkspacePage
      └ BlocProvider<OcptWorkspaceBloc>
         └ BlocBuilder → switch (state.mode)
              screenplay → EditorPage()            // owns OcptEditorBloc, returns OcptWorkspaceShell
              budget     → OcptBudgetMode()        // returns OcptWorkspaceShell with an empty centre
              schedule   → OcptScheduleMode()
              shotList   → OcptShotListMode()
    ```

    Each mode builds its own `OcptWorkspaceShell`. The shell reads `OcptWorkspaceBloc` from the
    context for the switcher's active value and its selection callback, so a mode never has to
    thread them through.
  - `workspace_bloc.dart` / `workspace_state.dart` / `workspace_event.dart` — a small ACT bloc:
    state is `{ OcptWorkspaceMode mode, bool isLoading }`; events are
    `OcptWorkspaceLoadRequestedEvent` (reads the persisted mode) and
    `OcptWorkspaceModeSelectedEvent({ required mode })` (emits and persists). Nothing else lives
    here.
  - `widgets/ocpt_workspace_mode_switcher.dart` — the bottom band: one 110 px column per mode,
    icon over label, the active one tinted `primary` over a `primary.withValues(alpha: 0.16)`
    rounded background, the others `onSurfaceVariant` over transparent. Sits on
    `surfaceContainerLowest` with an `outlineVariant` top border. Unimplemented modes are
    **selectable** (they show their empty state) but carry a discreet marker — do not disable them,
    a disabled bar reads as a bug.
  - `widgets/ocpt_workspace_empty_mode.dart` — the shared empty state for the three unimplemented
    modes: the mode's icon in `outline`, one localized line, centred. Reuse `OcptHomeEmptyState`'s
    proportions.
  - `modes/ocpt_budget_mode.dart`, `modes/ocpt_schedule_mode.dart`, `modes/ocpt_shot_list_mode.dart`
    — each a `StatelessWidget` returning `OcptWorkspaceShell` with the project title, a back action
    that closes the project and pops, `centre: OcptWorkspaceEmptyMode(...)`, and every other slot
    null. No bloc: they have no state.
- **Unsaved work when switching mode.** Leaving the screenplay mode unmounts `EditorPage` and
  closes `OcptEditorBloc`. The 120 ms styled reclassify flush and the 2 s autosave debounce must
  both be flushed **synchronously** on that path, exactly as they are on a back navigation today.
  Verify by test: edit, switch mode, switch back, assert the edit is still there and was persisted.
  If `deactivate()` does not already cover it, extend the existing flush rather than adding a
  second mechanism.
- l10n: mode names (`workspaceModeScreenplay`, `workspaceModeBudget`, `workspaceModeSchedule`,
  `workspaceModeShotList`), the empty-state line, and the switcher tooltips, in both ARB files.

**Tests.**

- `test/ui/pages/workspace/workspace_bloc_test.dart`: the persisted mode is loaded, selecting a
  mode emits and persists it, the default is `screenplay`.
- `test/ui/pages/workspace/widgets/ocpt_workspace_mode_switcher_test.dart`: four entries, the
  active one highlighted, tapping dispatches the selection.
- `test/ui/pages/workspace/workspace_page_test.dart`: switching to Budget shows the empty state and
  no dock; switching back shows the editor. Mount with an injected bloc, never through a full app
  boot.
- The flush test described above, in `editor_bloc_test.dart` or `workspace_page_test.dart`,
  whichever can express it without mocking half the app.

**Commits.** `refactor(router): rename the editor route to workspace`, then
`feat(workspace): add the production mode switcher`.

---

### M3 — Right dock: Inspector and Metadata tabs

**Goal: two new tabs on the screenplay's right dock, both fed by real data.**

**Work.**

- `packages/fountain_kit`: new `lib/src/layout/fountain_scene_statistics.dart`, exported from
  `fountain_kit.dart`. `FountainSceneStatistics` is the scene-scoped sibling of
  `FountainScriptStatistics`:

  ```dart
  factory FountainSceneStatistics.of(
    FountainDocument document,
    FountainLayoutMetrics metrics,
    int sceneIndex,
  )
  ```

  It exposes the scene's `speakingCharacters` (ordered, de-duplicated with the same normalisation
  `FountainScriptStatistics._normalizeCharacterName` uses — extract that into a shared private
  helper rather than copying it), its `wordCount`, and its `pageEighths`: the composed line count
  from this scene's heading up to the next one, expressed in eighths of a page
  (`metrics.linesPerPage`), which is the unit assistant directors actually use. Derive the
  estimated duration from it at the call site, on the industry rule of one page ≈ one minute —
  **do not** put a minutes field in `fountain_kit`; it is a presentation convention, not a layout
  fact.

  Pure Dart, `Equatable`, doc comments on everything, and a unit test file covering: no scene, one
  scene, several scenes, a scene with dual dialogue, and the last scene of the script.
- `lib/types/ocpt_editor_right_dock_tab.dart`: add `inspector` and `metadata`. Both are available
  in **both** editing modes (unlike `preview`, which stays raw-only).
- `OcptEditorRightDock`: the tab row becomes clickable (decision 5). Add an `onTabSelected`
  callback, wire each label through an `InkWell`, and keep the active-tab styling as it is. Update
  the class doc comment — it currently states the row is *not* clickable, and that sentence must
  not survive.
- New `lib/ui/pages/editor/widgets/ocpt_editor_inspector_panel.dart` — the scene under the caret:
  its heading, its number when it has one, its speaking characters, its estimated duration and its
  page-eighths. Empty state when the caret precedes every scene. Field rows follow the mock-up:
  an uppercase `labelSmall` `onSurfaceVariant` label over a `surfaceContainer` rounded value box.
- New `lib/ui/pages/editor/widgets/ocpt_editor_metadata_panel.dart` — the title-page fields
  (title, credit, author, source, draft date, contact) read from `FountainDocument.titlePage`, then
  the script statistics already computed for the status bar. A missing field shows a dash, not an
  empty row. This panel is **read-only**; editing stays in the existing title-page dialog, and a
  discreet "Edit…" button at the bottom opens it through `OcptRouterManager`.
- `OcptEditorState` / `OcptEditorBloc`: expose the current scene index (the state already tracks
  the caret line and the scene list — reuse `OcptEditorScenePanel`'s `_currentSceneIndex` logic by
  extracting it, do not duplicate it) and the `FountainSceneStatistics` of that scene, recomputed
  on the existing 150 ms parse debounce, never per keystroke.
- l10n: tab labels, the field labels of both panels, the duration and page-eighths formats
  (plural-aware), and the empty states, in both ARB files.

**Tests.**

- `packages/fountain_kit/test/layout/fountain_scene_statistics_test.dart` as described above.
- `test/ui/pages/editor/widgets/ocpt_editor_inspector_panel_test.dart` and
  `…_metadata_panel_test.dart`: rendering with data, rendering the empty states, no overflow at the
  dock's minimum width.
- `ocpt_editor_right_dock_test.dart`: tapping a tab label dispatches the selection.
- `editor_bloc_test.dart`: the current scene index tracks the caret; the scene statistics are
  recomputed on the parse debounce.

**Commit.** `feat(editor): add inspector and metadata dock tabs`

---

### M4 — Design alignment pass and documentation

**Goal: close the remaining visual gaps, then leave the repo's documentation truthful.**

**Work.**

- **Project poster tints.** `OcptSpecificColors` gains its first real field: a
  `List<Color> projectPosterTints`, defined per brightness in `lib/constants/ocpt_theme.dart` — the
  mock-up's violet / blue / pink / green / amber family for dark, a lighter, less saturated set for
  light. Implement `copyWith` and `lerp` properly (`lerp` must interpolate the list element-wise
  and handle differing lengths defensively). `OcptProjectCard` picks its tint by a stable hash of
  the project path, so a project keeps its colour across launches and across machines — do **not**
  use `Object.hashCode`, which is not stable across runs; hash the path string explicitly. The
  initial letter's colour must keep a readable contrast on every tint.
- **Toolbar and status-bar density.** Compare the running app against the mock-up at 1440×900 and
  correct only what is genuinely off (heights, paddings, icon sizes). Do not repaint anything that
  already matches; this is a correction pass, not a redesign.
- **Documentation.**
  - `CLAUDE.md`: add step 16 to the development-plan table; rewrite the *Architecture* bullets that
    this step invalidated — the editor no longer owns the chrome, the route is `workspace`, the
    dock widgets moved, `OcptSpecificColors` is no longer empty. Leave the rest alone.
  - `docs/adr/`: one new ADR recording *why the workspace shell is a slot widget plus a
    mode-only bloc, rather than a mode-aware god-bloc or an inheritance hierarchy*, and what that
    costs (each future mode owns its own dock persistence). Follow `docs/adr/0000-template.md` and
    add it to `docs/adr/README.md`.
  - `README.md`: mention the workspace and its modes in the feature list, marking the three
    unimplemented ones as planned.

**Tests.** `ocpt_project_card_test.dart` (new): the same path always yields the same tint,
different paths spread across the palette.

**Commits.** `feat(home): tint project cards per project`, then `docs: record the workspace shell`.

---

## 6. Definition of done

The step is done when, in the devcontainer, in order:

1. `flutter pub get`
2. `dart run intl_utils:generate`
3. `dart run build_runner build`
4. `flutter analyze` → 0 issues
5. `flutter test` → all green (root **and** `packages/fountain_kit`)
6. `flutter build linux --debug`
7. `reuse lint` → compliant
8. `git grep -l 'allcircuits.com' -- ':!actlibs' ':!CLAUDE.md' ':!docs/plans'` → empty

…all pass, **and**:

- Opening a project lands on the mode last used, and the switcher moves between the four modes
  without losing unsaved screenplay work.
- The screenplay mode behaves exactly as before this step: styled/raw toggle, Tab cycling, sticky
  manual types, autosave, import, export, PDF export, page simulation, dock resizing and its
  persistence, Ctrl+S and Ctrl+Shift+M.
- Both brightnesses look right; nothing hard-codes a mock-up hex value.
- Every new string exists in both ARB files, in both locales.
