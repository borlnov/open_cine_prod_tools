<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Development guide for AI agents

This file gives any agent session or subagent working in this repository the full context:
what the project is, where the development plan stands, and every norm that the code, commits
and workflow must follow. Read it entirely before writing anything.

`CLAUDE.md` is a symlink to this file, so Claude Code and any agent that looks for `AGENTS.md`
read the same guide. Edit `AGENTS.md`; never replace the symlink with a copy.

## Project overview

Open Cine Prod Tools is an **open-source suite of film-production tools** (Apache-2.0,
github.com/borlnov/open_cine_prod_tools). The MVP is a **Fountain screenplay editor**; the
découpage technique (shot lists), the scenario coverage per shot, the resources catalogue (the
people, the cast, the locations and the physical elements), the script breakdown (*dépouillement*)
and the shooting schedule ship alongside it, and the long-term roadmap adds, in priority order:
call sheets, budget, script supervisor reports, storyboard, and a casting tracker.

- Target platforms: **Linux + Windows first**, then macOS, Android, iOS. macOS is built and
  released by the CI (see the Architecture section) but has never been run on a Mac — there is
  none available to this project, so nothing about it can be verified here beyond what the CI
  checks structurally. Say so rather than implying it works.
- Storage: **local only** for now — one SQLite file per project (`.ocpt`, via drift), with the
  Fountain text as the source of truth plus a stable-UUID scene index. Sharing and collaboration
  come next, through an offline-first replica synced by a self-hostable, domain-blind relay
  server — see `docs/adr/0009`, `docs/adr/0010` and `docs/plans/collaboration-and-sync.md`. Google
  Drive was evaluated and rejected as a transport.
- Every document must stay exportable to human-readable formats (PDF, `.fountain`, and open
  docx/xlsx equivalents later).
- UI languages: English (`en_GB`, main) and French.

### Validated UI design (do not deviate without asking Benoit)

- Theme follows the system, **through the ACT themes manager** (`ActThemesManager`). Density,
  shapes and the UI type scale live once in `lib/constants/ocpt_theme.dart`'s component themes
  (card, buttons, icon buttons, inputs, menus, divider, scrollbar, tooltip) and its dense
  `TextTheme`, not in each widget — a new screen inherits the studio look for free and must not
  redeclare its own radius, padding or font size where a component theme already says it.
- Visual style: "creative studio" (DaVinci Resolve / Frame.io spirit) — near-black neutral
  surfaces, one vivid blue-violet accent (`0xFF6C5CE7`), calm in light mode.
- Workspace: a persistent shell (top toolbar, resizable side docks, status bar) around whichever
  production mode is active, chosen through a bottom mode switcher (Resolve's page bar is the
  reference) — see the Architecture section below.
- Home: grid of project cards (poster-ready, each tinted from a small per-project palette), New /
  Open actions on top.
- Screenplay mode: centered text zone, collapsible scene-list side panel (left), discreet toolbar.
  Default mode: styled block editor (super_editor) with the real screenplay layout. Alternate
  mode: raw Fountain text with a side-by-side paper-simulated preview (white page even in dark
  theme). Courier Prime everywhere (source, preview, PDF).
- **An irreversible action is always confirmed by a dialog**, never by an inline yes/no: deleting a
  record, removing a breakdown tag, replacing the screenplay with an imported file all go through
  `OcptConfirmDialog` (`lib/ui/widgets/`), which the *page or mode* opens — a widget only ever asks
  (a nullable `on…Requested` callback), it never carries the question itself. The caller owns every
  word of it and `isDestructive`. A new action that cannot be undone reuses this dialog; a second
  confirmation widget must not appear. The one standing exception is the `Versions` dock panel,
  whose `Delete`/`Restore`/`Rename` are answered **inside the card they belong to**, a list of
  cards having no other way to say *which* one is being talked about.
- **Before creating any new view/screen, ask Benoit design questions first** (layout, style,
  references). He shapes the UI himself.

## Development plan & status

| Step | Content | Status |
| --- | --- | --- |
| 0 | Devcontainer (Debian trixie, Flutter 3.44.6, git from source, reuse) | ✅ |
| 1 | Repo reset (purge legacy code, `flutter create`, Apache-2.0/REUSE) | ✅ |
| 2 | `actlibs/` submodule + global/config/logger managers | ✅ |
| 3 | Routing, theming, l10n (en_GB + fr) | ✅ |
| 4 | Properties manager (recent projects, locale, theme, editor mode) | ✅ |
| 5 | `packages/fountain_kit` (parser, serializer, layout metrics, tests) | ✅ |
| 6 | drift database + projects manager + home page | ✅ |
| 7 | Editor raw mode + side-by-side screenplay preview | ✅ |
| 8 | Editor styled block mode (super_editor, real page layout) | ✅ |
| R1-R3 | Review fixes: `OcptSpecificColors` file, SPDX email, dialogs via router manager | ✅ (`411d9b1`, `4d6835d`, `59e52e1`) |
| R4 | Review fix: editor toolbar back navigation (flush save → close project → pop) | ✅ (`a788bdf`) |
| 8b | Styled mode rework: true WYSIWYG editor (hidden Fountain markers, block-type dropdown + Tab cycle + smart Enter, B/I/U, sticky manual types) | ✅ |
| 9 | `.fountain` import/export (export manager + fountain IO service, home "Import a screenplay…" action, editor `⋮` menu with export / import-and-replace, pre-import snapshot) | ✅ |
| 9b | Editor polish & page simulation (styled widths/Tab/dropdown/uppercase, preview fit-to-width, toggle icons, Word-like page mode) | ✅ |
| 10 | Settings page (language system/en/fr via act_intl_ui, theme system/light/dark via `ActThemesManager`, page-setup settings (page size + margins), about section) | ✅ |
| 11 | CI build & release: `.github/actions/*` + `build.yml` (Linux `.deb` + Windows Inno Setup installer, git-describe versioning, GitHub Release on `v*`), SHA-pinning + least-privilege on existing workflows, `dependabot.yml`, `.github/ci-doc.md` | ✅ |
| 12 | PDF screenplay export (`pdf` package, line-level paginator, options dialog: page format pre-filled from project + scene-numbers checkbox, Courier Prime embedded, pagination via `FountainLayoutMetrics`, title-page editor splicing the Fountain source) | ✅ |
| 13 | CI matrix {`.`, `packages/fountain_kit`}, README rewrite, `docs/adr/` (drift, fountain_kit, super_editor, generated-files deviation) | ✅ |
| 14 | Editor statistics (page count, character count, last autosave time) | ✅ |
| 15 | Editor docks & Fountain syntax guide (resizable/persisted left+right docks, right dock tabbed preview/syntax, read-only syntax guide panel) | ✅ |
| 16 | Issue #15 fixes: native save dialogs + "Export" PDF button, sticky character blocks, scroll bar off the page, copy/paste keeping block types, `#N#` scene numbers with a styled display option, PDF bold/italic/underline regression coverage, dark-theme raw preview reading as paper, title page editable in place in styled mode | ✅ |
| 17 | Workspace shell refactor: studio design system (density/shapes/type scale as component themes), the shell extracted from the editor (`OcptWorkspaceShell`/toolbar/status bar/docks), four production modes behind a bottom mode switcher (screenplay implemented, budget/schedule/shot list as empty states, last mode persisted), inspector and metadata right-dock tabs, project poster tints | ✅ |
| 18 | Workspace toolbar alignment on the mock-up: accent-filled back badge, filled dirty dot, muted mode label, the dock toggles / save / `⋮` owned and ordered by the shell, a right-dock toggle reopening the last tab used, raw-only tab shortcuts | ✅ |
| 19 | Application logo (issue #24): the mark as SVG variants in `assets/branding/`, `OcptLogo`/`OcptLogoGlyph` shown in the home header, the settings "About" card and the workspace back badge, launcher icons for every platform through `icons_launcher`, Linux desktop entry and hicolor icon in the `.deb` | ✅ |
| 20 | Devcontainer & tooling modernization: no devcontainer features (gh from GitHub's apt repo, Claude Code from its native installer, no Node runtime), gh login persisted in a named volume, arb-editor schema fix on attach, worktrees moved inside the clone (`worktrees/`, the `.env` mount mode dropped), `tool/prune-gone-branches.sh` + `tool/install-ocpt.sh`, path-filtered lint workflows, `AGENTS.md` with `CLAUDE.md` as a symlink | ✅ |
| 21 | Shot list mode (découpage technique, issue #19): schema v2 (`shots`, `shot_characters`, `shot_coverages`) with the first `MigrationStrategy` and the `foreign_keys` pragma, sequence panel + shot table + shot inspector, scenario coverage per shot with staleness detection (`coveredTextDigest` / `needsCheck`), XLSX export through `excel_community` | ✅ |
| 22 | Collaboration & sync M1 — sync-ready data model (ADR 0010): schema v3 (`isDeleted` tombstones on every synchronised table, `sortKey` fractional indexes beside `position` with their backfill, the `row_field_versions` sidecar), every hard `delete()` turned into a tombstone and every read filtering them out, `deviceId` in `OcptPropertiesManager` | ✅ |
| 22b | Collaboration & sync M2-M6: the app on a tablet, the changeset engine, the domain-blind relay, live push and presence, the portable on-set server (`docs/adr/0009`, `docs/plans/collaboration-and-sync.md`) | 📝 planned |
| 23 | macOS build (issue #40): the bundle named "Open Cine Prod Tools", the App Sandbox dropped from both entitlements files (ADR 0011), the SDK's `Podfile` tracked, a `macos-dmg` composite action building a drag-to-`Applications` disk image with `hdiutil`, and a `build-macos` job gated like the Windows one, signing and notarization wired but dormant | ✅ (untested on a real Mac) |
| 24 | Scenario coverage PDF export (issue #42): source provenance in the paginator (ADR 0012), schema v4 (`shots.abbreviation`, deduced from the shot size), `OcptScenarioCoverageLayout` (bars, lanes, ticks, uncovered washes, legend and summary), the coverage PDF service over a shared `OcptScriptPagePainter`, the shot list `⋮` entry and its options dialog | ✅ |
| 25 | Project versions (issue #20): schema v5 (`project_versions` with its `contentDigest`, `project_info.currentVersionId`), `OcptProjectVersionCodec` and its versioned payload, the `Versions` dock tab shared by every mode, the read-only preview swapping an in-memory database in, and the restore (safety version, tombstones and version stamps, post-commit margins) | ✅ |
| 25b | Project versions rework: the working copy as the list's first entry (`OcptProjectWorkingCopyCard`, live counters, drift from its base), `currentVersionId` read as the **base** and its card no longer inert, inline rename, `contentDigest` deduplicating the restore's safety version, and the fork dropped in favour of a plain restore | ✅ |
| 26 | Resources mode (issue #45): schema v6 (the address book, the cast, locations with their sets, the elements catalogue, referenced assets and the local `local_erasures`) then v7 (`location_availabilities`), payload format 2 carrying the schema v6 tables then format 3 carrying `location_availabilities`, the four-tab mode (people, roles, locations, elements) with its sheets, roles reconciled from the screenplay, scene ↔ set and scene ↔ element links, search across the four tabs, and the four-sheet XLSX export; then schema v8 adding `project_info.currencyCode` (payload format 4, a version predating it leaving the project's currency untouched on restore rather than guessing one), `OcptProjectSettingsPage` reached from a dedicated action in every mode's toolbar, and the currency shown as the element sheet's cost suffix and named in the exported workbook's cost column | ✅ |
| 26b | Resources sheets — a photo, and the things a role wears: the colour palette pulled out of its `MenuItemButton`s (`OcptResourcesColorSwatches`, the crash a `Wrap` caused), `OcptAssetsService` owning the `assets` rows every service used to mint through the locations one, the three orphaned asset columns wired up (`people.photoAssetId`, `elements.photoAssetId`, `people.imageRightsAssetId`) behind one `OcptResourcesPhotoSlot` menu, an erased person's asset paths blanked on both erasure paths, then schema v15 and payload format 10 adding `role_elements` — the role sheet's `Their things` card grouped by category and the element sheet's read-only `Roles concerned` chips | ✅ |
| 27 | Breakdown mode (issue #47): schema v9 (`breakdown_tags` anchoring a passage to an element, a role or a set — ADR 0014 —, `scene_breakdowns` holding the pass's per-scene progress, `elements.status`) then v10 (a code backfilled onto every set), payload format 5, `OcptBreakdownService` with tag reconciliation on the screenplay save path, the script view with its two-click tagging gesture and its popover that links or creates in one click, the recap cross-table and its search, the scene and target inspectors, the occurrence suggestions, the per-category palette, and the breakdown sheets PDF export | ✅ |
| 28 | Schedule mode M1 — planning (issue #49): schema v11 (the six schedule tables, and the legacy `shots.shootingDay` erased by the migration), `ocpt_shooting_day_timeline.dart` (ADR 0015) and `ocpt_sun_times.dart` (ADR 0016), both pure, `OcptScheduleService` with its day duplication and its one-placement-per-shot rule (dropped in 28c), payload format 6, `OcptScheduleMode` with its agenda in three presentations and its day view, and the shot list's shooting day turned into a read-out of the placement | ✅ |
| 28b | Schedule mode M1' — per-slot timetables and computed convocations: schema v12 (`shooting_day_blocks.slotId` made required and a `sceneId` given to the `hold` that names a sequence, a slot's typed clocks reduced to its `startMinute`, `shooting_day_groups` added, the crew and cast convocations trading their typed times for a group and a lead), `ocpt_shooting_day_timeline.dart` amended per slot (ADR 0015 amended) and `ocpt_shooting_convocations.dart` (ADR 0017), both pure, `OcptScheduleService` seeding a convocation from the day that last carried it, payload format 7, and the mode reading its call times out rather than asking for them | ✅ |
| 28c | Schedule mode M2' — the day view: a timetable on each slot card (the day's own gone), blocks dragged between slots or moved through their row's `Move to…`, a hold's sequence picker and the roles the breakdown tagged in it, the lead times and group pickers on every crew and cast row, the groups band, and the agendas drawing a day's slots as parallel lanes; then the placement rework — the one-placement-per-shot rule dropped, a shot placed from a slot's own `+ Block` menu through `OcptScheduleShotPickerDialog`, the left dock's click turned into a plain selection read out by the inspector, and the strip agenda made informative; then the review pass — a PAT band for the crew (ADR 0017 amended), a `pause` block, the days ranked and renumbered by date with a `Change the date…` action, the day tag localized (`D3`/`J3`), the crew rows rebuilt as cards wrapping in a foldable half-width column, `Groupes de personnes` and its `ⓘ`, the `±` snapped to five minutes against a typed duration in the inspector, a day's band read arrival → end, and a slot card given its own note and its `▲`/`▼` reorder | ✅ |
| 28d | Schedule mode — convocations read off the slots alone (ADR 0018 superseding ADR 0017): the lead times and the `shooting_day_groups` that carried them dropped (schema v13, payload format 8, the first payload upgrade that *removes*), `ocptComputeDayConvocations` reading a person's arrival, PAT band and departure off every slot they are linked to across the whole day, the groups band and the lead fields gone with the clocks on the crew and cast cards, `dayArrivalMinute` reduced to the day's earliest slot start, and the `Convocations` dock tab where those times now live | ✅ |
| 28e | Schedule mode — a slot anchored by either edge (ADR 0015 amended a second time): schema v14 and payload format 9 replacing `shooting_slots.startMinute` with `anchorEdge`/`anchorMinute`/`anchorSlotId`, the dependency-ordered resolution in `ocptComputeShootingDayTimelines` with its missed-fixed-end and cycle records, `ocptSlotAnchorWouldCycle`, `OcptScheduleService.setSlotAnchor` with `duplicateDay`'s link remap and `deleteSlot`'s dependent freeze, the slot card's flat anchor menu, and every reader of a slot's hour moved onto the resolved one | ✅ |
| 28f | Schedule mode — a convoked person's position pre-filled from the address book: `ocptCrewPositionPrefillOf` (`lib/utils/`, pure) joining a person's declared `person_positions` with what they already hold on that slot, `OcptScheduleService.addSlotCrewMember` pre-filling a fresh crew row with it, the slot card's position picker promoting the declared ones and refusing the taken ones, and the person sheet's `Portée` column deleted | ✅ |
| 28g | Schedule mode M3 — the paperwork a shoot runs on: `OcptSchedulePlanSnapshot` owning the day-level joins both the mode and the manager layer read, `OcptCallSheetPdfService` (the general sheet and the named ones from one composition), `OcptShootingPlanPdfService` (three landscape summary grids over slot columns, then a detailed agenda per day), `ocpt_schedule_pdf_shared.dart` between them, a directory picker on `OcptSaveLocationService`, and the mode's three `⋮` entries with their options dialogs and their three-outcome notice | ✅ |
| 28h | Schedule mode M4 — seeing what the plan is about to break: schema v16 and payload format 11 adding `people.maxDailyPresenceMinutes`, `ocpt_schedule_alerts.dart` (pure, nine sealed alert kinds, the tenth deliberately absent) joined by `OcptSchedulePlanSnapshot.alerts`, the positions matrix and the presence grid as the third and fourth centre views (`shooting_presences` written at last, a click cycling an override back round to the computed value), the `Alerts` dock tab and the count in the status bar, and the agenda's `Colour by` control over `ocptSceneEffectOf`, shared with the call sheet's own `EFFET` column | ✅ |
| 29 | Schedule review M1 — the whole data model of the review pass in one migration: schema v17 and payload format 12 adding `shooting_slot_guests` (a guest convoked by a slot, named by a person **or** a free name) and `shooting_day_events` (what the day does not control, at an absolute hour, outside every chain), then `shooting_day_blocks.crewNote` (the note that prints, beside the `notes` that never does), `assets.validFrom`/`validUntil` and `project_info.minimumRestMinutes`, and **dropping** `shooting_presences` with the click that wrote it — the presence grid reduced to its computed reading, `OcptPresenceCode` to `working`/`unavailable`, and format 12 doing all three kinds of payload upgrade at once | ✅ |
| 29b | Schedule review M2-M3 — the reading fixes, then what v17 held but nothing drew: the presence grid reduced to its computed reading, the positions matrix grouped under a day band with each column's resolved hours, the day view's alert badge opening the `Alerts` tab, a slot's and a block's `notes` named `Private notes`; then guests as a third kind of convocation link (an arrival and a departure, never a PAT band), the slot card's guest band picking from the address book alone under one foldable `Assigner des personnes` section holding the crew, the cast and the guests, the `Convocations` panel's trailing guest group, a day's events in one widget shown by the day view and the day inspector alike with a full-width marker in the week grid, and a block's own `crewNote` typed in the inspector | ✅ |
| 29c | Schedule review M4 — the two crossings v17 made possible: `OcptScheduleRestTimeAlert` (a person's departure against their arrival on the next day they are actually convoked on, raised on the second of the two) and `OcptSchedulePermitNotValidAlert` (the plan's `…Missing` renamed for what it says, a location filing no permit raising nothing), both soft and both silent while the figure they measure against was never recorded, `ocptComputeScheduleAlerts` taking the project's minimum and a location's permit windows, `OcptSchedulePlanSnapshot.minimumRestMinutes` joining them, the two sentences in the `Alerts` panel, the permit's `validFrom`/`validUntil` typed under the location sheet's document line, and the project's minimum rest typed on `OcptProjectSettingsPage` | ✅ |
| 29d | Schedule review M5 — the stamp that tells two issues of one document apart: `ocptScheduleGeneratedAtStamp` in `ocpt_schedule_pdf_shared.dart` (date **and** time, deliberately not locale-formatted), an `exportDate` on both call sheet generators beside the shooting plan's own — resolved once per document, and once per run by `OcptExportManager` for the two exports that write a folder — the shooting plan's version line repeated in every page's running head, and the call sheets' own in the title block | ✅ |

## Ways of working

- Benoit communicates in French; **all code, comments, commits, branches and GitHub content
  are in English**.
- Work happens on an issue-named branch (`<issue-number>-<slug>`), merged into `main` through a
  pull request.
- A session that needs a checkout of its own puts it under `worktrees/`
  (`git worktree add worktrees/<name> -b <branch>`), never in the `.claude/worktrees/` directory
  Claude Code's own worktree feature defaults to: create it with git first, then enter it by path.
  A fresh worktree is not usable until the bring-up in `worktrees/README.md` has run.
- A plan in `docs/plans/` describes work not yet done. Once its step ships and its outcome is
  folded into this file, the plan is deleted — the code and the ADRs are the record from then on.
- Sizeable work: plan first, reviewed by Benoit, then implementation **delegated to Sonnet 5
  agents** orchestrated and reviewed by the main session. User checkpoints between milestones.
- One commit per logical change. Never reference the plan, steps, or these instructions in
  code or commit messages (issue numbers are allowed in commits/PRs).
- Dependencies never reference their dependents.

## Toolchain

The Flutter SDK (3.44.6, the version pinned by `actlibs/tool/.flutter_version`) lives in the
devcontainer; the developer's host has **no usable one**. An agent session normally starts
**inside that container already** — cwd `/workspaces/open_cine_prod_tools`, `flutter` on the
`PATH`, and no `docker` binary at all — so run `flutter analyze`, `flutter test`,
`flutter build linux --debug`, `dart run …` and `reuse lint` directly, from the repo root. There is
no container to start, and starting one is not possible from there. Check with `flutter --version`
if in doubt: only a session running on the host itself needs the wrapper, which is what the
verification gates below assume otherwise.

```bash
cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
```

Git commands run from the repo root, in the container like everything else. The container carries
no SSH key, so `origin`'s `git@github.com:` URL cannot authenticate: push over HTTPS with the `gh`
credentials the named volume persists, and use `gh` itself for everything else on GitHub (pull
requests, issues, the API).

```bash
git -c credential.helper='!gh auth git-credential' \
  push https://github.com/borlnov/open_cine_prod_tools.git <branch>
```

`git fetch` cannot run against `origin` there either, so a branch pushed that way has no
remote-tracking ref until the developer fetches it from their host.

The devcontainer persists the pub cache and Claude config in named volumes; X11 is forwarded so
`flutter run -d linux` can open a window.

Screenshots of the running app come from `tool/screenshot-app.sh`, which starts it on a private
Xvfb display and exposes `shot` / `click` / `type` / `key` / `scroll` between invocations. Capture
through that script rather than launching the app by hand: the container advertises the developer's
WSLg compositor, GTK prefers Wayland when it sees one, and the window opens on their desktop
instead of off screen - and the home screen lists recent projects by full path, which the script's
isolated `HOME` keeps out of the images. Run it with no arguments for the command list.

## Architecture

See `docs/adr/` for the rationale behind the structural choices below (drift storage,
`fountain_kit` as a standalone package, `super_editor`, generated code not committed).

Built 100% on the **ACT Flutter packages** (git submodule `actlibs/`, consumed as plain
`path: actlibs/<pkg>` dependencies):

- `OcptGlobalManager extends AbsUiGlobalManager` owns every manager; managers are
  `AbsWithLifeCycle` classes registered with builder factories (`dependsOn` ordering) and
  resolved via `globalGetIt()`.
- Routes: `enum OcptRoute with MixinRoute { home, workspace, settings, licenses }` +
  `OcptRouterManager extends AbstractRouterManager<OcptRoute>` (go_router underneath).
  **Never use `Navigator` directly** — all navigation, including closing dialogs, goes through
  `globalGetIt().get<OcptRouterManager>()` (`push`, `pop`, `pop<T>(result)`…). The workspace
  route is guarded: it redirects to home when no project is open.
- BLoC: ACT pattern (`BlocForMixin`, `BlocStateForMixin`, sealed events registered with
  `registerMixinEvents()` / `on<>`), one bloc per page, pages split UI/bloc/state/event files.
- Workspace shell (`lib/ui/pages/workspace/`): `WorkspacePage` mounts `OcptWorkspaceBloc`, whose
  state is `{ OcptWorkspaceMode mode, bool isLoading, OcptWorkspaceRevealRequest? revealRequest }` —
  it owns *which* production mode is active, nothing about that mode's own content. The reveal
  request is the one exception that proves the rule, and the bloc **never reads inside it**: a mode
  sending the user to another one *for a reason* (the breakdown's `Open in Resources`, meaning "this
  very element, over there") attaches an `OcptWorkspaceRevealRequest` (`lib/models/`, sealed, today
  `OcptResourcesRevealRequest { tab, recordId? }`) to `OcptWorkspaceModeSelectedEvent`; the bloc
  transports it, `WorkspacePage` hands it to the mode that recognizes its own subtype and to no
  other, and the opened mode reports back with `OcptWorkspaceRevealRequestConsumedEvent`. It is
  **one-shot** by construction: the destination bloc takes it as a *constructor* argument (an event
  would race the load, which clears every selection) and nulls it in that first load, so entering or
  leaving a version preview — which reloads through the same handler — doesn't yank the user back;
  a plain switch from the mode switcher carries none and clears whatever an earlier one left. A
  `recordId` that is null, or that names a row tombstoned since, only opens the tab. A set is
  revealed as **its location** (`OcptSet.locationId`, resolved by the asking mode), a set having no
  sheet of its own. `OcptWorkspaceMode { screenplay, breakdown,
  shotList, resources, schedule, budget }` — the five implemented modes first, in the order the work
  happens in (write, break down, shoot-list, resource, schedule), the one empty one last — is
  persisted through `OcptPropertiesManager.workspaceMode` by **name** rather than by index (modelled
  on `editorMode`), so opening a project restores the last mode used and reordering the enum is
  safe. `OcptWorkspaceShell` is a
  stateless slot widget (title, toolbar actions, overflow entries, left panel, right panel,
  centre, status bar, dock controller) built by whichever mode is active. The end of the toolbar
  is the shell's own chrome rather than a mode's actions, so its order can't drift from one mode
  to the next: the mode label, the two dock toggles
  (`isLeftDockOpen`/`onToggleLeftDock`, same pair for the right), the save control
  (`onSave`/`isSaving`, spinner while in flight), then the `⋮` menu — each rendered only when the
  mode wired it, so a mode with no dock or nothing to save simply shows fewer of them. A mode's
  own `toolbarActions` sit before that group. Two further slots serve the read-only preview of a
  project version: `isReadOnly`, which swaps the unsaved-changes dot for the `Read only` pill, and
  `banner`, a full-width widget between the toolbar and the docks row (`OcptWorkspaceReadOnlyBanner`
  fills it) — everything else a preview withholds is each mode's own job, since only a mode knows
  what its affordances are. The screenplay mode is
  `EditorPage` (still under `lib/ui/pages/editor/`, unmoved, owning `OcptEditorBloc` exactly as
  before this refactor), the shot list mode is `OcptShotListMode`
  (`lib/ui/pages/workspace/modes/shot_list/`, owning `OcptShotListBloc`), the resources mode is
  `OcptResourcesMode` (`lib/ui/pages/workspace/modes/resources/`, owning `OcptResourcesBloc`), the
  breakdown mode is `OcptBreakdownMode` (`lib/ui/pages/workspace/modes/breakdown/`, owning
  `OcptBreakdownBloc`), the schedule mode is `OcptScheduleMode`
  (`lib/ui/pages/workspace/modes/schedule/`, owning `OcptScheduleBloc`), and the one remaining
  one is a stateless `OcptBudgetMode` widget rendering the shared empty state —
  no bloc, no data, "coming in a future version". `OcptWorkspaceDock`/`OcptWorkspaceDockDivider`/
  `OcptWorkspaceDockLayoutController` (`lib/ui/pages/workspace/widgets/`) are the dock geometry
  primitives every mode's shell reuses; `OcptWorkspaceModeSwitcher` is the bottom band that
  selects the mode (all five entries always selectable, unimplemented ones only discreetly
  marked). See `docs/adr/` for why this is a slot widget plus a mode-only bloc rather than a
  mode-aware god-bloc.
- Config: `OcptConfigManager` (yaml assets in `assets/config/`), properties persisted through
  `OcptPropertiesManager` (recent projects capped at 10, locale, theme, editor mode, page
  margins).
- Licenses: `ActLicensesManager` (`actlibs/act_licenses_manager`) is registered via
  `registerManagerAsync<ActLicensesManager>(ActLicensesBuilder<OcptConfigManager>())` right
  after `LoggerManager`; `OcptConfigManager` mixes in `MixinLicensesConfig`, sourced from the
  `licenses:` block of `assets/config/default.yaml`. It feeds Flutter's `LicenseRegistry`,
  shown through the stock `LicensePage` mounted on `OcptRoute.licenses` (never
  `showLicensePage()`, which uses `Navigator` directly).
- Page setup: `OcptPageSetup` (`lib/models/ocpt_page_setup.dart`) pairs the page format (a
  property of the project, `project_info.pageFormat`, written through
  `OcptProjectsManager.saveCurrentProjectPageFormat`) with the margins (an app-wide rendering
  preference, `OcptPropertiesManager.pageMargins`). `OcptPageSetup.toMetrics()` is the single
  switch-over-format entry point every call site uses to get a `FountainLayoutMetrics`.
- Theme: `ActThemesManager` with `OcptAppTheme.standard`; theme constants in
  `lib/constants/ocpt_theme.dart`, `OcptSpecificColors` in `lib/models/` — two fields:
  `previewBackdrop` (light keeps `surfaceContainerLow`, dark is white), the raw-mode preview
  panel's own backdrop painted by `OcptEditorPreview` itself so its white sheet reads as paper in
  dark theme too, regardless of the surrounding themed docks; and `projectPosterTints`, the small
  per-brightness colour family `OcptProjectCard` indexes into by a stable hash of the project
  path, so a project keeps the same poster tint across launches and machines. The same file owns
  `ocptClickableCursor`, the hand cursor every clickable control shows: Material's own default
  (`WidgetStateMouseCursor.adaptiveClickable`) only resolves to the hand on the web, so the
  component themes hand this one to every control that reads a cursor from the theme, and the
  widgets with no theme hook (`DropdownButton`, every `InkWell` the app builds itself) pass it at
  their call site — a new clickable surface must do the same.
- Branding: the app mark lives in `assets/branding/` as three SVGs — `ocpt_logo_light.svg`
  (accent-filled square), `ocpt_logo_dark.svg` (the same drawing hollow, for near-black surfaces)
  and `ocpt_logo_glyph.svg` (the perforations and page alone, monochrome, **always tinted by its
  call site**, for a surface that already carries the accent). The UI never reaches for those paths
  itself: `OcptLogo` / `OcptLogoGlyph` (`lib/ui/widgets/ocpt_logo.dart`, built on
  `act_flutter_utility`'s `SvgAsset`, so `flutter_svg` stays an indirect dependency) are the only
  way it draws the mark, `OcptLogo` picking its variant from the ambient
  `Theme.of(context).brightness`. It is shown in the home header, the settings "About" card and the
  workspace toolbar's back badge. `assets/branding/icons/` holds the PNG masters (not bundled:
  the branding assets are declared file by file in the pubspec), rasterized from that same geometry
  by `dart run tool/generate_branding_icons.dart`, and consumed by
  `dart run icons_launcher:create` — configured by the pubspec's `icons_launcher` block, which
  generates the committed Android/iOS/macOS/Windows launcher icons — and by
  `.github/actions/flutter-debian`, which installs the 512 px and scalable icons plus a `.desktop`
  entry named after the package (the icon name `linux/runner/my_application.cc` asks the window to
  wear).
- Desktop packaging: `build.yml` builds the three desktop targets and one composite action per
  format packages each — `flutter-debian` (`.deb`), `windows-installer` (Inno Setup),
  `macos-dmg` (`hdiutil create -format UDZO` over a staging directory holding the `.app` copied
  with `ditto` and an `/Applications` symlink). The macOS bundle's `PRODUCT_NAME` is the display
  name `Open Cine Prod Tools`, so every script path quotes it; its version is split before the
  build (`--build-name` = the dotted numeric prefix, `--build-number` = the commit distance)
  because `CFBundleShortVersionString` rejects `git describe`'s output. The app is distributed
  outside the Mac App Store (`docs/adr/0011`): **the App Sandbox is off** in both entitlements
  files — the recent-projects list reopens a project by absolute path, which a sandboxed app
  cannot do without security-scoped bookmarks — and the `.app` carries only the scaffold's ad-hoc
  signature, so the README documents the Gatekeeper bypass beside the SmartScreen note. Real
  signing and notarization are written into `build.yml` and dormant, guarded by
  `if: env.APPLE_CERTIFICATE != ''`; `--options runtime` belongs to that path alone, never to the
  unsigned one. `macos/Podfile` is tracked (copied verbatim from the pinned SDK's template),
  `macos/Podfile.lock` deliberately is not — `pod install` needs a Mac, so the first person to
  build on one commits it. See `.github/ci-doc.md` for the local recipes.
- `packages/fountain_kit`: pure-Dart Fountain parser/serializer with round-trip guarantee and
  `FountainLayoutMetrics` (US Letter/A4 Courier columns). Keep it free of Flutter imports.
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
- Persistence: drift schema v17 (`project_info`, `screenplays`, `screenplay_snapshots`, `scenes`,
  the three shot list tables, the fourteen resources tables (`role_elements` among them),
  `breakdown_tags`, `scene_breakdowns`,
  the seven schedule tables, `row_field_versions`,
  `project_versions`), `storeDateTimeAsText:
  true`, scene reconciliation in 3 passes (explicit scene number → exact heading → relative order).
  `**/*.g.dart` is git-ignored (documented deviation); CI regenerates with build_runner.
  A schema number is allocated **at merge time, not at branch time**
  (ADR 0007): of two branches in flight, whichever
  merges second renumbers, and the migration test pins what `onCreate` produces against what every
  upgrade path produces, so a table declared and forgotten in `onUpgrade` fails there rather than
  on a user's file.
- Project versions (`project_versions` + `project_info.currentVersionId`, schema v5): the user's
  named, permanent checkpoints of the **whole** project, not to be confused with
  `screenplay_snapshots` (automatic, screenplay-only, pruned past 30). The table is **local and
  never synchronised** — no tombstone, no `sortKey`, no stamps, and `OcptProjectVersionsService`
  deletes a row for real, the one place in the app that may.
  `project_info.currentVersionId` is the **base**: the version the working copy descends from, not
  a version that is somehow "current" — the working copy itself is never a row of this table, and
  the moment the user types, it has drifted from its base. `OcptProjectVersion.isBase` is that
  pointer seen from a card, and the base's card is an ordinary one in every other respect
  (previewable, restorable, deletable).
  `OcptProjectVersionCodec` is the only thing that knows the payload's shape: every row of the
  twenty-seven captured tables verbatim (primary keys, tombstones and `row_field_versions` stamps
  included)
  plus the page setup, the currency and the minimum rest, in a JSON format versioned by
  `payloadFormat` —
  independent of the schema
  version, upgraded on decode when older, refused when newer. It is **a hand-written mirror of the
  schema**, and a new synchronised table has to be added to all three of it, `contentDigest` and
  `_applyPayload`: leave it out of the payload and a restore rewinds half the project, out of the
  digest and the working copy claims not to have drifted, out of `_applyPayload` and it is never
  written back. Payload format 2 (the resources mode's eleven tables) and format 3
  (`location_availabilities`) are what the `_payloadUpgrades` map's first two entries materialise,
  as empty lists, when an older payload is decoded — restoring a version captured before those
  tables existed therefore tombstones every resource row, which is the truthful reading of "this
  project had no people". Format 4 (the currency) upgrades to **null** instead, the one entry that
  doesn't mean "there was none": the column has never been nullable, so a version that predates it
  did have a currency, it simply never recorded which one, and
  `OcptProjectVersionsService.restoreVersion` reads that null as "leave the project's currency
  untouched" — the opposite of what the empty-list entries mean. Format 5 (the breakdown) does both
  at once: `breakdown_tags` and `scene_breakdowns` materialise as empty lists, while `elements`
  gains `status` filled with `toFind` — not a "leave it alone" null, because a version captured
  before that column existed has no live value anywhere to leave alone, so the column's own default
  is the honest reading. Format 6 (the schedule's six tables) is back to plain empty lists, and it
  is the entry whose consequence is worth stating out loud: restoring a version captured before the
  schedule mode **tombstones every shooting day planned since**, which is what "this project had not
  been scheduled" means — it is an edit like any other restore, not a no-op that leaves the plan
  alone. Format 7 is the payload's own half of the schema's v11-to-v12 migration, and does all three
  kinds of thing at once: `shooting_day_groups` materialises empty, a slot's `startMinute` is read
  out of the `crewCallMinute` it was renamed from, and a crew or cast row's dropped clocks give way
  to a **null** group and a **null** lead — null here meaning "nobody has said", not "leave a live
  value alone", since nothing may be reconstructed from a timetable that has since moved. A block
  that names no live slot is put on its day's **first** one, and a block whose day has no slot at
  all is dropped from the payload, exactly as the migration drops it from the file. Format 8 is the
  payload's half of v12-to-v13, and it is the **first entry that removes rather than materialises**
  — a third kind alongside the other two, and the one worth reading the doc comment of before
  adding a fourth. It drops the `shooting_day_groups` list and the `groupId`/`leadMinutes` pair on
  every crew
  and cast row: unlike an empty list it makes no claim about the moment of capture (a format-7
  version genuinely *did* carry groups and lead times), and unlike the currency's null it leaves no
  live value alone (there is none to leave). A version captured then comes back with every crew and
  cast row it held, simply carrying no group and no lead any more, because the project being restored
  into has no concept for either to mean anything — and, as everywhere else, **nothing is
  reconstructed**: a lead time does not become a preparation slot nobody asked for. Format 9 is the
  payload's half of v13-to-v14, and it is a plain **rename**, the kind format 7 already shows for
  `crewCallMinute`: every slot's `startMinute` becomes an `anchorEdge` of `start`, an `anchorMinute`
  holding the very hour it had, and a null `anchorSlotId` — which is exactly what a format-8 payload
  meant, so restoring one draws the day it drew when it was captured, and nothing is guessed the
  other way round (no slot becomes end-anchored because its blocks happened to land on a round hour,
  and no link is invented between two slots that merely met). Format 10 is `role_elements`, and it
  is back to the plainest kind, format 6's **empty list**: a version captured in format 9 was taken
  when nothing in the app could say a role wore a coat, so "this role had no things" is a truthful
  statement about that moment — and restoring one therefore drops every link made since, which is
  the reading, not a bug. Format 11 is `people.maxDailyPresenceMinutes`, and it is format 7's
  **null** rather than format 4's: the column is nullable by design, so a version captured before it
  existed truthfully recorded no maximum for anybody, and that null is written back onto the working
  copy like any other changed column — where the currency's null means "leave the live value alone",
  a column that has never been nullable having always held one. Format 12 is the first entry to do
  **all three kinds at once**, and it is the one to read before writing a fourth: `shooting_slot_guests`
  and `shooting_day_events` materialise as empty lists (format 6's kind), `shooting_day_blocks.crewNote`
  as the empty string and `assets.validFrom`/`validUntil` plus `project_info.minimumRestMinutes` as
  null (format 11's kind, a truthful "nobody recorded one" written back like any other column), and
  the `shooting_presences` list is **dropped** (format 8's kind, the second entry in the codec that
  removes rather than materialises) — a version captured in format 11 genuinely did carry presence
  overrides, the project being restored into has no concept for them any more, so they come back as
  nothing at all and, as everywhere else, **nothing is reconstructed**: an override that said
  `travelling` does not become a slot nobody asked for. Counters shown
  on a card
  (`OcptProjectVersionSummary`) are measured once, at creation.
  The codec also owns `contentDigest`, the SHA-256 of a payload's canonical *content* — rows sorted
  by primary key and each row's JSON keys sorted, `row_field_versions` and the page margins left
  out, since the stamps change on every restore and the margins are an app-wide preference. It is
  stored beside the payload (`project_versions.contentDigest`, nullable so a version whose digest
  was never computed stays readable: a null digest reads as "unknown", i.e. *modified*, which is the
  fail-safe direction) and it answers the app's one recurring question about a version — is this
  the same project state as that one? `OcptProjectVersionsService.captureWorkingCopyState` reads
  the working copy once and answers both users of it: the counters the working-copy card shows, and
  whether the working copy has drifted from its base.
  `restoreVersion` is the app's one destructive operation that isn't a file deletion, and it is an
  **edit, not a reset** (`OcptProjectRestoreStatus`): in a single transaction opened with
  `PRAGMA defer_foreign_keys = ON`, it captures the state it is about to replace as a version of its
  own (`Before restoring <name>`, so a restore can be undone) — but **only when that state has
  drifted from its base**, compared by content digest, since restoring an untouched working copy
  would otherwise mint a byte-for-byte duplicate of the base's card; the promise holds either way,
  the state replaced then being exactly the base version's, still in the list. It snapshots every
  screenplay whose text
  it changes (`OcptSnapshotReason.restore` — the merge base a three-way screenplay merge looks for),
  then inserts/updates/**tombstones** row by row and stamps, in `row_field_versions`, every column
  whose value actually changed, at a version strictly above what that column held and under the
  local `deviceId`. A hard delete would be re-inserted by an offline replica, and an unstamped
  rewrite would be undone by the next merge; a column already matching the payload is left
  unstamped, so a restore never stomps a concurrent edit that agreed with it. `scenes` is the
  exception that carries no stamp (never merged) but still goes back verbatim, ids included.
  There is no fork operation: starting from an older state *is* restoring it, after which the
  working copy descends from it and the user names their branch when they seal it — a dedicated
  fork only ever added a card whose content duplicated the version it branched from. The margins
  half of the restored page setup is written by `OcptProjectsManager` **after** the transaction
  commits, since a preference can't be rolled back with it.
- Sync-ready data model (ADR 0010): **no service ever deletes a synchronised row** (the two local
  tables are the exceptions: `project_versions` above, and `local_erasures` below). Every
  synchronised table
  carries `isDeleted`, a "delete" is an update to it, and every read filters tombstones back out —
  including `scenes`, which is never synchronised but whose rows are referenced by two tables that
  are. Ordering is `sortKey`, a fractional index (`lib/utils/ocpt_fractional_key.dart`,
  base-62 strings, never ending on the lowest digit so two keys always have room for a third):
  `ocptFractionalKeyBetween` allocates one, `ocptFractionalKeySequence` backfills a whole group,
  `ocptFractionalKeyRekeyPlan` gives the minimal set of writes a reorder needs, so an insertion or
  a move writes exactly one row. `position` survives as a legacy column stamped once at insertion
  and never renumbered — nothing reads it, and `OcptShot.position` is a read-time rank the loading
  service counts off, not that column. `row_field_versions` holds the per-column version stamps a
  merge resolves conflicts with; the only writer so far is a version restore (above), and M3 of the
  collaboration plan is what will stamp every other edit — a composite primary key is rendered into
  `rowId` through `ocptCompositeRowStampKey` (`lib/utils/ocpt_row_stamp_key.dart`), the app's single
  encoding of one.
  `OcptPropertiesManager.loadOrCreateDeviceId()` mints and keeps this replica's UUID.
- `OcptExportManager` (`lib/managers/export/`) owns getting a project's documents in and out of the
  app: the native open dialog, and nine services it owns (RFL18) — `OcptFountainIoService`
  (bytes ↔ text, suggested file names), `OcptPdfExportService` (the screenplay PDF),
  `OcptShotListXlsxExportService` (the shot list workbook), `OcptScenarioCoveragePdfService` (the
  annotated coverage PDF), `OcptResourcesXlsxExportService` (the resources workbook),
  `OcptBreakdownSheetsPdfService` (the breakdown sheets PDF, one sheet per scene),
  `OcptCallSheetPdfService` and `OcptShootingPlanPdfService` (the schedule's own paperwork, below)
  and `OcptSaveLocationService` (wraps `file_selector`'s `getSaveLocation`,
  a **direct** dependency kept in sync with the version `act_file_transfer_manager` already resolves
  transitively, for the native "save as" dialog every export goes through — no export ever writes
  to a default location silently; its `pickDirectory` is the same promise for the one export that
  writes **several** files, the named call sheets). The five PDF services share one
  `OcptCourierPrimeFontsLoader`
  (handed to each by the manager, so the 4 embedded TTFs are decoded once) and one
  `OcptScriptPagePainter` — the two script exports for the positioned line drawing they both start
  from, the breakdown sheets and the two schedule documents for its metrics and fonts alone, their
  pages flowing rather than
  typeset. An export writing into a folder reports an `OcptCallSheetExportResult` rather than a
  path: some files landing and others not is a third outcome, and it must never read as success —
  somebody would go unwarned about a day they are called on. The home
  page's "Import a screenplay…" action and the editor's `⋮` export / export-to-PDF /
  import-and-replace menu all go through the manager; the screenplay text itself is always written
  through `OcptScreenplayService.saveScreenplayText`, never by hand.
- Scenario coverage export: the screenplay printed as usual, with a coloured bar in the margin
  alongside every passage a shot covers. `OcptScenarioCoverageLayout.of(...)`
  (`lib/models/ocpt_scenario_coverage_layout.dart`, pure Dart, no `pdf` and no Flutter) holds every
  rule and every test — resolving each range's source offsets onto rows through the paginator's
  provenance, bridging unanchored lines, emitting one `OcptCoverageBarSegment` per (range × page it
  appears on), assigning lanes by a greedy interval colouring that fills the left margin then the
  right and shrinks its pitch before it lets bars share the outermost lane, ticking a boundary that
  falls mid-line, washing the passages no shot covers (`OcptCoverageGap`), and building the legend
  and summary rows. A shot's colour is `ocptCoverageColorAt(rank)` over the 16-entry
  `ocptCoveragePalette` (`lib/constants/`, ARGB ints so the palette stays usable on screen later),
  ranked **within its sequence**, so an export is deterministic and no two shots of one sequence
  share a colour. `OcptScenarioCoveragePdfService` only draws. Bar labels are
  `<abbreviation><code>`, the abbreviation being `shots.abbreviation` — deduced from the initials
  of the shot size's words the first time a shot size is committed while it is still empty, never
  overwritten afterwards. The `⋮` entry opens `OcptScenarioCoverageExportDialog` (page format,
  title page, scene numbers, legend page, summary page) through `OcptRouterManager`, and
  `OcptShotListScenarioCoverageExportRequestedEvent` flushes pending edits before handing the
  snapshot and the parsed document to the manager. Every heading the two extra pages print comes in
  as an `OcptScenarioCoverageLabels`, exactly as `OcptShotListXlsxLabels` does for the workbook —
  the manager and its services never see a `Tr`.
- Resources mode (`lib/ui/pages/workspace/modes/resources/`): who shoots the film, where, and with
  what. Four tabs in the left dock — people, roles, locations, elements — the selected record's
  editable sheet in the centre, and the shared `Versions` tab as the right dock's only tab (the
  sheet *is* the inspector). Its four services are `OcptPeopleService`, `OcptRoleIndexService`,
  `OcptLocationsService` and `OcptElementsService`, owned by `OcptProjectsManager` beside the shot
  list's own, and `OcptResourcesBloc` joins their four reads into one `OcptResourcesSnapshot` the
  way `OcptShotListBloc` builds its own.
  **A person is one row, whatever they do on the film**: `people` is the address book, and both the
  cast (`roles.personId`) and the crew positions (`person_positions`) are links onto it, never
  copies of a name — so the same person can be a role, a position and a location's owner at once. A
  `person_positions` row says only *that* someone holds a function; **when** they hold it is a
  per-slot fact the schedule mode owns, which is why no scope column exists here and why the sheet
  shows none — the two tables are joined the one way that says something (`ocptCrewPositionPrefillOf`,
  below), never by a second copy of one truth.
  **An element is anything that must be present on a day and is not a person** — one `elements`
  table with a category and a free sub-category rather than one table per department, because the
  tracking columns (owner, who brings it, secured, ready, returned, where) are the same whatever
  the item is.
  **What a role wears, carries and is made up with** is `role_elements`, `scene_elements`' sibling
  on the other side of the production: the same catalogue, linked from a role, with the same kind of
  per-link note and no quantity (a role wears the coat or they do not). It is **written from
  `OcptElementsService`** although the role sheet is where the user adds to it — the row is a link
  onto an element, it is loaded with the element it names on `OcptElement.roleLinks`, and the role
  sheet's own card scans the catalogue for the links naming its role rather than carrying a copy, so
  that card and the element sheet's reverse read-out cannot disagree. `OcptRoleIndexService.deleteRole`
  reaches for the one cascade it needs (`tombstoneRoleLinksOfRole`); neither deletion ever touches
  the **element**, a coat outliving the character who wore it. **No category restriction, and
  deliberately none**: a character's car, their dog and their stunt harness are facts about them
  exactly as their coat is, so the grouping by category is read-time work in the card (and the
  breakdown mode's own per-category colour heads it), never a rule in the schema that a migration
  would have to undo the day it gets in the way. The element sheet reads it back as
  `Roles concerned` — read-only chips landing on that role's sheet, a plain tab-and-selection change
  inside one mode rather than an `OcptWorkspaceRevealRequest`, and **rendered identically under a
  version preview**, selecting a role writing nothing. A role's things are added and removed from
  the role's sheet alone: offering the same edit from both ends would only invite the two to
  disagree.
  **A photo is a slot, not a field**: `OcptResourcesPhotoSlot` is the person sheet's header avatar
  and the element sheet's alike, and it is **one menu** — reference a photo, drop it, then the
  palette — because "what does this record look like?" is one question and the colour is the
  photo's *fallback* rather than a competing setting. A record with no colour of its own passes a
  null `currentColorIndex` and gets the photo entries alone: `elements` carries no `colorIndex`, an
  element being read by its category's colour. A person's photo is resolved once, by
  `OcptPersonAvatar`, so referencing one on the sheet shows it in the address book's list and on the
  role avatar too.
  Roles are **reconciled from the screenplay**, not typed from nothing: `OcptRoleIndexService`
  mirrors `OcptSceneIndexService` on the same save path — a speaking character with no row gets a
  `speaking` role, a role whose character disappeared keeps its casting and its notes and gains an
  `orphanedName` (`OcptRemovedRoleAlert`, the sibling of `OcptShotRemovedCharacterAlert`), and a
  hand-added `silent`/`extra` role is never touched. A rename reads as one disappearance and one
  appearance, repaired through the banner, exactly as a heading with no scene number is.
  A scene is linked to a **set** (`scene_sets`, many-to-many — a continuous action is regularly
  covered in two) and to an **element** (`scene_elements`, the *dépouillement* link, carrying the
  quantity and the note that belong to that scene alone). `ocptSceneSetSuggestionOf`
  (`lib/utils/`, pure and tested) reduces a heading to the place it names and *offers* the best set
  at the top of the picker — never applied, since `INT. CUISINE` in two houses is two sets. A set's
  **location is not one of its fields**: it is what the set belongs to, chosen when it is created
  and changed only by moving the whole set (`OcptLocationsService.moveSetToLocation`, the sets
  card's own move control, which re-allocates the `sortKey` in the destination), so a set filed
  under the wrong house is repaired rather than deleted and retyped.
  A **code is the app's own**, never typed: `OcptElementsService.createElement` mints an element's
  (`ocptElementCodeOf`, `PRP-3`, numbered within its category) and `OcptLocationsService.createSet`
  mints a set's (`ocptSetCodeOf`, `A`, `B`, … `AA`, numbered across the whole project — a set has
  no category, so a constant prefix would say nothing, and the two shapes can never be confused for
  one another). Neither is among `OcptElementField`/`OcptSetField`'s entries and neither has a field
  on a sheet: `OcptResourcesCodeReadOut` reads it out. The one thing that ever rewrites one is a
  category change, and `updateElement` owns that rule rather than a bloc, so the breakdown's own
  category chips get it without knowing it exists — a prefix that stopped saying which department
  an item comes from could not be corrected by hand. Schema v10 is the same rule applied backwards:
  it adds no column and fills the `sets.code` an older project left empty, numbering around
  anything it does not recognise rather than over it.
  Everything writes the moment it changes, except the sheets' typed free-text fields: those ride
  one 2 s debounce shared by the five `pending…FieldEdits` maps, flushed together on a selection
  change, a tab change, a version preview and the mode leaving the tree. A field may **flag** what
  it holds without refusing it (`ocptEmailFormatError`, `ocptCostCentsOf`, the coordinates): the
  sheets autosave as they are typed, so a field that refused an incomplete value would refuse
  nearly every keystroke.
  Each sheet ends on its own `Delete this …` action (`OcptResourcesDeleteAction`, which only asks),
  and the four of them are answered by one `OcptConfirmDialog` opened by the mode, as in the shot
  list and the breakdown; only the wording differs, and it is the caller's. The removed-role
  banner is the one exception: it deletes straight away, being that question itself.
  The toolbar's search toggle filters the active tab's list (`lib/utils/ocpt_resources_search.dart`,
  diacritic-folded so `lea` finds `Léa`), each list filtering itself because matching includes the
  localized labels a row shows; the header count then reports what is on screen while the status
  bar keeps counting the whole catalogue. The `⋮` menu exports the four-sheet workbook (above).
- Breakdown mode (`lib/ui/pages/workspace/modes/breakdown/`): the *dépouillement* — reading the
  script once and tagging what the shoot must provide. It is the pass that fills the catalogues the
  resources mode holds, so it sits between the screenplay and the shot list in the mode switcher.
  A **tag** (`breakdown_tags`, ADR 0014) is the anchor between a passage of the screenplay and the
  catalogue row it calls for: a discriminator (`OcptBreakdownTargetKind { element, role, set }`)
  plus three nullable foreign keys, exactly one non-null. A character is never an `elements` row —
  it is the `roles` row `OcptRoleIndexService` already reconciled from the cue — and a place is a
  `sets` row, which is why a tag points at one of three tables rather than one.
  Offsets are **scene-relative**, as `shot_coverages` are, and the tag stores its passage
  **verbatim** (`taggedText`) where `shot_coverages` stores only a digest: the text is what lets a
  shifted tag be re-anchored rather than merely flagged, and what the occurrence suggestions match.
  `OcptBreakdownService` (owned by `OcptProjectsManager` beside the resources services) writes them,
  and creating a tag **ensures the link it implies** in the same transaction — a `scene_elements`
  row for an element, a `scene_sets` row for a set, nothing for a role, the tag being that link
  itself. Removing a tag **never** removes that link row: the resources mode lets a user link an
  element to a scene by hand with no tag at all, and the breakdown cannot tell its link from that
  one, so the inspector asks about the removal as a separate question.
  `reconcileTags` joins `OcptSceneIndexService`/`OcptRoleIndexService` on the screenplay save path,
  **after** the scene index is rebuilt since it needs the new `charStart`: a tag whose slice still
  matches is left alone, one whose stored text is found **exactly once** in the scene is re-anchored
  silently, and only zero or several matches raise `needsCheck` — surfaced the way
  `shots.needsCheck` is. It writes nothing when nothing changed, running as it does on every save.
  `scene_breakdowns` holds how far the pass has got per scene (`OcptBreakdownSceneStatus { toDo,
  inProgress, done }`, **held by hand** — a scene may legitimately need nothing and still have been
  read), one live row per scene created on the first write, never eagerly; a scene with no row reads
  as `toDo`. `elements.status` (`OcptElementStatus { toFind, reserved, beingMade, confirmed }`) is
  the column the mode's chips and the "to find" counters read, and the resources mode's element
  sheet carries the same control; the three existing booleans answer a different question (on the
  truck? given back?) and stay untouched.
  The centre is either the **script view** — the whole screenplay typeset as a paper sheet, every
  word clickable, tagged passages highlighted in their category's colour — or the **recap**
  cross-table (one row per target, one column per scene), switched from the mode's own header band.
  Tagging is a two-click range: a first click opens an anchor, a second closes it and opens
  `OcptBreakdownTagPopover`, whose search field is **pre-filled with the passage** and whose results
  are grouped by kind; clicking a result links, clicking a **category chip** creates the element in
  that category and tags it in one write, then hands off to the inspector where the rest of the
  sheet is. Elements and **sets** are the two things creatable here — a role's existence belongs to
  the screenplay, `OcptRoleIndexService` reconciling it from the cue, so inventing one would be
  inventing a character. A set has no such source: the script names the place and the project has
  never heard of it, so the popover's own `Create a set` control picks the location holding it out
  of the ones the project has, or mints one named after it (`OcptBreakdownService.createSetAndTag`,
  the sibling of `createElementAndTag`, rolling *every* write back when the tag half is refused).
  `Open in Resources` is offered beside them for everything else. Tags never overlap
  (the mode greys the affordance, `OcptBreakdownService` guarantees it), and a click on an
  already-tagged word therefore **selects its target** rather than starting a range — deliberately
  *not* what the same click does in `OcptShotCoverageDialog`, where it removes the range: here a tag
  has a sheet worth inspecting, and losing one by mis-clicking while reading is the worse failure.
  A repeated occurrence elsewhere in the script is **offered, never applied**
  (`lib/utils/ocpt_breakdown_suggestions.dart`, whole-word and diacritic-folded), the principle
  `ocptSceneSetSuggestionOf` already follows. The header's search filters the recap's **rows** and
  never its columns, and typing into it from the script view switches to the recap carrying the
  text: the script is a reading surface, and the answer to "where is this?" is a table.
  The scene inspector's own **sets row** is the one part of the mode that is not about tags: it
  reads and writes `scene_sets` directly (`OcptBreakdownSceneSetLinkedEvent`/`…UnlinkedEvent` onto
  `OcptLocationsService`), so a link made by hand in the resources mode shows here and one made here
  shows there — no tag is created, nothing is highlighted, and unlinking leaves every tag pointing
  at that set exactly where it is. It sits at the top of the sheet because that is where a
  breakdown sheet names its décor, and its picker offers `ocptSceneSetSuggestionOf`'s answer first,
  marked as a suggestion and never applied. Beside that picker it **creates** one
  (`OcptLocationsService.createSetLinkedToScene`, the tagless sibling of `createSetAndTag`, minting
  the location too when the menu's own "in a new location" entry is picked): a scene whose place
  the project has never heard of is the ordinary case at the start of a pass, and the name is not
  asked for — it is `ocptSceneHeadingPlaceOf`'s reading of the heading, resolved by the mode so the
  menu and the event can never derive it differently. Every entry of a set-creation menu carries a
  **non-null** value (`ocptNewLocationMenuValue`): `PopupMenuButton` reads a null result as "the
  menu was dismissed" and never calls `onSelected` for it, so an entry valued null silently does
  nothing. A set is shown as `<set> · <location>` everywhere
  outside the location sheet holding it (`ocptBreakdownSetLabel`), which is why
  `OcptBreakdownSnapshot` carries the whole `locations` catalogue and derives `locationNameById`
  from it.
  The target inspector's **title is its name field**: an element or a set created from the popover
  carries the passage's own wording, and the moment to correct that is while reading it, not after
  scrolling past a status grid to a field repeating it. Renaming there renames the catalogue row
  itself, so the script's tooltips, the legend, the recap and the resources mode all follow — a set
  riding `pendingSetNameEdits` on the same debounce an element's fields do. A **role** is the one
  kind read out rather than typed into, its name being the screenplay's.
  The left dock is the scene list (status, a colour bar per category present, counts) over the
  category legend, whose entries toggle their category's highlighting; the right dock is
  `Inspector` + the shared `Versions` tab, the inspector showing the selected target's sheet or —
  with nothing selected — the selected scene's own breakdown sheet. `lib/constants/
  ocpt_breakdown_palette.dart` maps a colour **per category** rather than per rank (unlike a shot's
  coverage colour): a category must read the same in every project and every export. The `⋮` menu
  exports the breakdown sheets PDF (above).
  The target inspector's `Open in Resources` is the app's one cross-mode navigation: it switches to
  the resources mode **and lands on the record's own sheet**, through the reveal request the
  workspace shell carries (above) — an element on the elements tab, a role on the roles tab, and a
  set as the location that holds it. The popover's own `Open in Resources` deliberately carries
  none: it is only ever shown when the search names no role and no set, so there is no sheet to land
  on — the user is going there to create one.
- Schedule mode (`lib/ui/pages/workspace/modes/schedule/`): **when** the film is shot. It sits after
  the shot list, since what is placed on a day is a shot.
  A **shooting day** (`shooting_days`) is **always dated** — the week and month views, the sun times
  and every availability crossing depend on it — and its number, the `J3` a call sheet prints, is a
  **read-time rank** over the live days **in date order**, never a column, exactly as
  `OcptShot.position` is. `J1`/`J2` are a **chronological label, not an id**: re-dating a day (its
  card's own `⋮` menu, `Change the date…`) renumbers the schedule around it, a day moved before the
  first one becoming the first one, and `sortKey` survives only as the tiebreaker between two days
  sharing one date. `ocptScheduleDayTagLabel` renders it **through `Tr`**
  (`scheduleDayTagPrefix`, `D3` in English and `J3` in French): the paperwork a crew reads is
  printed in the language the app is set to, so the letter follows it. The workbook export, having
  no `Tr` of its own, takes that letter as `OcptShotListXlsxLabels.dayTagPrefix`.
  A day holds one or more **slots** (`shooting_slots`), the *créneaux* — a working unit with its own
  location, set, crew and hours; a real call sheet regularly has two, with different crews and
  different call times, which is why they are rows rather than columns. A slot owns **one anchored
  edge and no other clock** (ADR 0015, amended a second time): `anchorEdge` says whether its start or
  its **end** is the pinned one, and that edge's hour comes from exactly one of a typed
  `anchorMinute` and the **opposite** edge of another slot of the same day (`anchorSlotId`) — the
  discriminator idiom `breakdown_tags` already uses. A production books a studio until 22:00, or
  plans backwards from a sunset, as often as it plans forwards; where the slot actually starts and
  ends is computed from that one hour and its own blocks, never read off a column. A link never
  crosses two days and never joins two same-side edges ("these two start together" is said by typing
  the same hour twice). Who is convoked is
  `shooting_slot_crew` (a person and a position, two rows for one person holding two functions) and
  `shooting_slot_cast` (**the role, not the person** — the actor is read through `roles.personId`, so
  recasting never rewrites the schedule). A convoked person — technician as much as actor — has
  **three** times, not two: an arrival, then the PAT band, the gap between them being the make-up
  chair (for an actor) or simply getting there and rigged (for a technician) — and all three are
  **computed**, as every convocation time in this mode is.
  Every minute in this mode is an **offset from the day's own midnight and may exceed 1440**: a night
  slot running 19:00 → 03:00 stores 1140 → 1620, nothing is ever taken modulo anything, and
  `ocptFormatDayMinute` (`lib/utils/ocpt_day_minute.dart`) is the single formatter that reads one as
  a clock face. Getting this wrong only shows up on the one night shoot of a production.
  A timetable is `shooting_day_blocks`, and **every block belongs to exactly one slot**: a day is a
  set of **parallel chains**, one per slot, not one chain shared by all of them. **How a chain
  becomes clock times is stated once and implemented once**, in `ocptComputeSlotTimeline`
  (`lib/utils/ocpt_shooting_day_timeline.dart`, ADR 0015 as amended twice): durations chaining from
  that slot's own resolved start, a block with an `anchorMinute` starting exactly there, and an
  anchor the chain has already run past reported as an `OcptTimelineOverrun` rather than silently
  pushed.
  `ocptComputeShootingDayTimelines` is what **resolves the anchors** before that loop runs, and the
  amendment is deliberately made around `ocptComputeSlotTimeline` rather than inside it: slots are
  resolved in **dependency order**, an `end`-anchored one starts at `end − Σ durations` and then
  chains forward unchanged (so adding a block pulls its start earlier and leaves its end where it
  was), a pinned block that makes such a slot finish elsewhere is an `OcptTimelineFixedEndMiss` —
  **reported, never absorbed**, the fixed end winning — and a circle of anchors is an
  `OcptTimelineAnchorCycle` whose slots are placed at the day's earliest already-resolved start
  rather than hung on. That circle is defence against a file, not a state a user can reach: the
  anchor menu greys out an entry that would close one (`ocptSlotAnchorWouldCycle`) and
  `OcptScheduleService.setSlotAnchor` refuses to write one. `OcptShootingSlotTimeline.startMinute` is
  the **resolved** start every reader of "the hour of this slot" reads; `dayStartMinute` is the
  minimum over them and `dayEndMinute` the **maximum** over their ends — a day ends when its last
  unit wraps. Two slots overlapping in wall-clock
  time is **legal, not a conflict**: that is what splitting a day into slots is for, and one *person*
  convoked in both at once is M3's alert, a different question. No computed time is ever stored —
  that is what makes a day cheap to rework between takes — so everything downstream reads those
  functions and nothing re-derives them. A `hold` block reserves time for a sequence not yet
  shot-listed, which is how a production schedules ahead of its own découpage; a `pause` block is
  the break that is not a meal, and like every milestone kind it names no role.
  **A convocation is the slot you are linked to** (`ocptComputeDayConvocations`,
  `lib/utils/ocpt_shooting_convocations.dart`, ADR 0018 superseding ADR 0017): nobody types a call
  time, and **nothing is offset from anything**. A person is convoked by being **linked to a
  slot** — a `shooting_slot_crew` row by person, a `shooting_slot_cast` row by role, a
  `shooting_slot_guests` row by either half of its own discriminator, all three kinds counting — and
  every figure about them is read off the slots they are linked to and the blocks in them, joined
  across the **whole day**: their **arrival** is the earliest `startMinute` over those slots, their
  **PAT band** runs from the earliest shooting block to the latest, and their **departure** is the
  latest slot end. A production that wants somebody there at 06:00 for make-up creates a 06:00 slot
  and links them to it — its label (`HMC`, `Installation`) is what says why, its blocks are what say
  how long, and the day view already draws slots as parallel lanes. That is the trade ADR 0018
  accepts: convoking one actor earlier now costs a **slot** rather than a number typed in place, and
  the resulting file says what is actually happening, and prints.
  A **shooting block** means `shot` **and** `hold` — a production scheduling ahead of its own
  découpage still owes its cast a band — while every other kind (`preparation`, `hairMakeUp`, `meal`,
  `pause`, `travel`, `wrap`) is not shooting time and never opens or closes one. **A slot with no
  shooting block therefore gives no PAT at all**: somebody convoked only on preparation slots has an
  arrival and a departure and no band, which is the truthful reading — they are there, they are not
  waiting to shoot — and a slot carrying no block whatsoever ends at its own `startMinute`, a
  convocation with no content yet rather than a zero-length error. The band is **not clipped to one
  slot**: someone on a morning slot and an evening slot reads one band spanning both, gaps included,
  and the day view's lanes are where those gaps are read. **Nothing depends on a block naming the
  person**: `shot_characters` and the roles the breakdown tagged in a hold's sequence take no part in
  a convocation — whoever is linked to the slot is convoked by the slot, for the whole of it. **A
  guest is the one kind that never gets a band at all**, whatever shooting blocks their slots carry:
  they have an arrival and a departure and an em dash between them, a guest not being there to
  shoot, and `ocptComputeDayConvocations` therefore never computes one for them rather than
  computing and discarding it. A guest is also the one kind that may double: somebody convoked as
  crew or cast **and** attending the same day as a guest reads as **two** convocations, deliberately
  — a guest link says nothing about work, and folding the two would put a PAT band on a visit. It
  follows that a guest is never `working` in the presence grid either, that grid reading
  `OcptDayConvocation.personId` alone, and that guests take part in **no alert** (they hold no
  position to lose, have no daily maximum and are not cast). There
  is no after-offset anywhere, finishing later being said with a `wrap` block, which moves
  everybody's departure at once, and **nothing computed is overridable by hand**: a typed clock is a
  claim nothing keeps true once a block moves. A **hold** names its sequence through
  `shooting_day_blocks.sceneId` rather than through its free-text label, free text answering nobody;
  the column is nullable (a production blocks time out before settling which sequence goes there) and
  is filled in by the timetable row's own sequence picker.
  Sunrise, sunset and the three twilights are **computed offline** from the day's first slot's
  location (`ocptSunTimesOf`, `lib/utils/ocpt_sun_times.dart`, ADR 0016), each figure independently
  nullable — no coordinates, or a phase that never happens at that latitude, prints nothing rather
  than a plausible wrong time. The time zone is the **device's own** for that date, which the day
  inspector says rather than hides.
  `OcptScheduleService` is the eleventh service `OcptProjectsManager` owns. **A shot may be placed as
  many times as the plan needs**: a shot interrupted by the meal break and resumed after it is two
  blocks on that day, not one, so `placeShot` only ever creates — a placement is moved like any other
  block and removed like any other block, and there is no operation keyed by shot any more.
  `loadShotPlacements` therefore answers with a **list** per shot, which the shot list's `Jour de
  tournage` reads out as the day tag and its date while every placement lands on one day (the
  meal-break case included) and as the day tags alone, joined, once they don't
  (`ocptShotPlacementLabel`, mirrored cell for cell by the workbook's own `_placementCellOf`).
  Deleting a day cascades onto everything hanging off
  it; deleting a **slot** carries its blocks over to the day's first remaining slot, and tombstones
  them with it only when it was the day's last one — nothing can hold a block any more then.
  `duplicateDay` copies the slots, their crew and their cast, and
  deliberately **neither the placed shots nor the crew note**: a stable crew is entered once for a
  whole shoot, and a day lost to rain is re-planned at another date in one gesture. Convoking
  somebody **seeds nothing**: a convocation is the link and only the link, so there is no figure left
  to carry over from the day that last convoked them.
  The centre is one of **four views** (`OcptScheduleCentreView`, whose declaration order is the
  header switch's own): the day view, the agenda, the positions matrix and the presence grid — the
  working surface first, the three readings of it after. It is either the **agenda** — strip, week
  (an hour grid shaded by the sun times, stretched
  to whatever the timeline returns so a night shoot draws where it belongs, a day's own column split
  into **one lane per slot** since two chains may overlap, the hour rules and the sun shading staying
  column-wide because they are facts about the day rather than about a unit) or month (a cell reading
  the **earliest** of its slots' starts, the first in `sortKey` order not being the earliest once
  slots run in parallel, and saying how many units the day carries) — or the **day view**, the
  working surface: the slot cards, each carrying its own **private note** under its
  location and set (what that unit alone needs saying — the parking, the key holder —, the day's
  own note to the crew being a different thing) and a `▲`/`▼` pair moving it in the day's list (the
  pair is drawn as soon as one of the two leads anywhere, the other reading as disabled rather than
  disappearing, and it writes the same `sortKey` `OcptScheduleService.reorderSlot` already stated),
  each entering its own crew and cast on
  itself. A convoked person is **one card**, crew and cast alike — the position picker or the role
  name, then who that is, and **no clock at all**: a card there says who is convoked and in what
  function, nothing more, because a convocation is a fact about a person on a **day**, joined across
  every slot they sit on, and cannot honestly be read from one slot's card in isolation. The times
  live in the `Convocations` dock tab instead.
  **A crew row's position is pre-filled from the address book, and the picker is the same join read
  the other way** (`ocptCrewPositionPrefillOf`, `lib/utils/ocpt_crew_position_prefill.dart`, pure and
  tested): a position's identity is the pair (`positionId`, `customLabel`) both tables already model
  one with, and the function answers, out of a person's declared `person_positions` and what they
  already hold **on that slot**, which position to pre-fill and which to promote. `addSlotCrewMember`
  lands a fresh row on their first declared position not already taken there — so convoking the same
  person twice lands on their second, then their third, and a free-label declaration pre-fills the
  row's `customLabel` — and only ever fills a blank, a caller passing a position keeping it. The
  row's own picker shows those declared positions above the catalogue's departments, behind a
  divider, and **never offers a position that person already holds on that slot**, this row's own
  included: the duplicate is refused where it is chosen rather than the add being blocked, and the
  taken one is absent rather than greyed, being visible on the card right beside the picker. It is a
  **pre-fill, not a rule**: nothing keeps the two tables in step once the user has corrected it.
  The two kinds share one shell rather than each
  drawing its own; the two lists sit side by side, **at most half the card's width each**, and their
  cards **wrap** into as many columns as that half affords rather than stacking in a single file.
  A **guest** gets a third band, full width **under** those two halves, and it is **always drawn**,
  empty hint and all, exactly as they are: a slot's guests are one of the three answers to "who is on
  this unit", and a band that had to be revealed from the `⋮` menu before it could be filled hid the
  very affordance somebody looking for it was after.
  The three of them sit under **one foldable section**, `Assigner des personnes`, and **only that
  section's own title folds** — expanded by default, its count being the three kinds together while
  each kind's own title is a plain read-out saying how many it holds: a settled crew, cast and guest
  list are entered once and then read past for the rest of the shoot, and the point of the fold is to
  get to the timetable — so one gesture answers for the three rather than each needing its own, and
  a title that also folded its own kind would be a second, narrower question asked in the same place
  as the first. That
  fold is local widget state — a reading preference costs nothing to lose.
  A guest card carries the
  person's name, a reason, a note and **no clock at all**, like every other convocation card. Its
  picker offers **the address book and nothing else**: nobody is created from the schedule mode, so
  the `freeName` half of `shooting_slot_guests`' own discriminator has **no writer in the app** —
  it is read back defensively (a row carrying one still draws, and its convocation still computes)
  and never minted, which is the deliberate reading of "a guest is somebody the production already
  knows how to reach". On the card itself sits
  **that slot's own
  timetable**: a day carries no timetable of its own, every block belonging to exactly one slot. Its
  blocks are dragged into place, nudged by `±` — which **snaps to the nearest five minutes**, so a
  duration of 12 steps up to 15 and down to 10, the odd figure being deliberately lost — pinned by
  an anchor whose minute is typed in the same
  `OcptScheduleMinuteField` every other time uses (rendered without a callback, that field is also
  how a computed time is read out), and shown in the error colour when their anchor over-ran. A block
  leaves its slot either by being **dragged onto another card's timetable** — the drag handle keeps
  the in-slot reorder and the row body carries the cross-slot drag, so the two never meet in the
  gesture arena — or through its row's own `Move to…` entry, the pointerless path. A shot
  block carries a **status control writing `shots.status`**, the same column the shot list edits —
  one truth, two places to change it — so a day reads as a checklist on set.
  **A shot is placed from the slot it is shot in**: the timetable's own `+ Block` menu opens on
  `Shot`, which opens `OcptScheduleShotPickerDialog` — the whole shot list, searched
  (`ocptResourcesSearchMatches`, the fold the resources mode already uses) and grouped by sequence
  the way the left dock heads it, every row selectable including a shot already placed, which merely
  carries the day tags it sits on so a second placement reads as a choice rather than an accident.
  The picker is the mode's to open, never the timetable's: the widget only asks
  (`onShotBlockRequested`), as every other question in this app is asked.
  The left dock is the day list over the shots still to place, and a click on one of those
  **selects** it — the inspector then reads that shot out (its sequence, its characters, its
  estimated duration, where it is already placed, and the same status control a shot block carries),
  which is all a click there does: the *placing* gesture it used to start, answered by a click on a
  day, is gone. The right dock is `Inspector` + `Convocations` + `Alerts` + the shared `Versions`
  tab, the
  inspector reading block, then shot, then day, the block and shot selections being mutually
  exclusive by construction. **`Convocations` is the day's whole call** — one card per person, crew
  and cast folded together (an actor read through `roles.personId`), plus one per **uncast role**,
  which is a convocation the production still has to honour and is named by the role; each card
  reads arrival → PAT band → departure, an **em dash** where there is no band, over the slots it is
  linked to by label. It is scoped to the **selected day**, sorted by arrival then by name (the order
  people walk in — `ocptComputeDayConvocations` itself can only tie on id, knowing no names, so the
  panel does that last sort), and it is the reading no slot card can give once a person sits on
  several slots of one day. **Guests form their own trailing group**, after the crew and cast cards
  and under their own heading: they are on the day and are owed an hour, but they are not the call
  the assistant director reads down. Being **entirely computed it is entirely read-only**, offers no
  callback
  at all, and is therefore the one panel of the app needing no `isReadOnly` handling: it draws
  identically under a version preview because it has nothing to withhold.
  A block's own **duration is typed in the inspector** — any figure, 12 included, against the
  `±` stepper's five-minute grid — the two writing the same column from the two places a duration is
  thought about, and its **crew note** is typed right under it: `notes` is the private one that never
  prints, `crewNote` the one that does (the call sheet and the shooting plan pick it up once they
  print it).
  A day's **events** — what it does not control, at an absolute hour — are drawn by **one widget
  shown twice** (`OcptScheduleDayEventsList`): the day view frames it in its own band under the slot
  cards, the day inspector in a section of its own, both editable, so the two surfaces cannot read a
  day's events apart. A row is its hour (the same `OcptScheduleMinuteField` every other time uses),
  its label, its note and a remove control that only **asks** — an event is a typed row like a block,
  so deleting one goes through `OcptConfirmDialog` as every irreversible action here does. A fresh
  event lands on the day's own earliest resolved slot start (09:00 with no slot yet), **a starting
  point the row's own field immediately corrects rather than a claim about when anything happens**.
  The **week grid** draws an event as a full-width marker across every lane — it belongs to the day,
  not to a unit — and stretches its own hour range to show one pinned outside every block's span;
  the **day view draws no marker of its own**, having no time canvas to mark, so its band is its only
  representation, and the strip and month agendas draw none either.
  The strip agenda is **informative**: it shows what each day carries and **opens**
  one (a click on its header switches to the day view, exactly as the week and month grids do),
  and nothing is placed or unplaced from it — a block lives in a slot, so it is made and unmade
  where the slot is.
  A day's own band is read **arrival → end**, on the strip card as in the day inspector and the day
  view's summary: `OcptScheduleState.dayArrivalMinute` is the **earliest resolved start over the
  day's live slots** (`OcptShootingDayTimelines.dayStartMinute`), never a stored column — an
  end-anchored slot's own start being a fact about its blocks. It used to be the minimum arrival
  over every convocation, which was a different
  figure only while a lead time could pull somebody in ahead of their slot; nothing does that any
  more (ADR 0018), so the day's earliest slot start already *is* its earliest arrival. The week and
  month grids read the same figure and mean something narrower by it on purpose: a cell there answers
  "when does this day shoot", not "when is the call".
  The **positions matrix** is the third view: positions × slots, one column per slot grouped under
  its day and one row per position **somebody actually holds somewhere** (a position's identity being
  the pair `positionId`/`customLabel` `ocptCrewPositionPrefillOf` already models one with, free
  labels grouped last, having no department). The grouping is drawn as a **day band** over the slot
  headers — the day tag and the date once, spanning that day's own columns, the shape
  `OcptShootingPlanPdfService`'s landscape grids already use — so a column header carries the slot's
  label and its **resolved hours, start over end** alone: a day tag repeated on every column said
  nothing about which columns belonged together, and a slot's end is what a reader of this matrix is
  after when they ask whether a position is covered until the wrap. A position **lost mid-day** is
  marked **nowhere here**: it is `OcptSchedulePositionLostAlert`'s own sentence, read in the `Alerts`
  panel, and a coloured cell only ever restated it in a place with no room to say why. Every cell is
  therefore a holder or an em dash, the matrix writes nothing, and like the `Convocations` panel it
  carries no `isReadOnly` flag at all.
  The **presence grid** is the fourth: people × days, a trailing count of each person's working
  days, and cells that are **computed** — `working` when that person is convoked that day,
  `unavailable` when they are not but a `person_unavailabilities` window covers the date, and
  **blank** otherwise, blank being absence of information rather than a claim about it. **All three
  are computed and nothing there is clickable**: schema v11 declared a `shooting_presences` table
  for a by-hand override of that reading, and schema v17 drops it again — its `available`/
  `unavailable` restated, from a second source of truth, what `person_unavailabilities` already
  records in the resources mode, and `OcptPresenceCode` keeps only the two values a computation can
  actually give. `travelling` goes with it, and that is a **real loss** rather than an oversight: it
  is the one presence fact nothing computes, and it comes back, if it ever does, as a typed fact with
  a table of its own — not as a resurrected override on a computed grid. The reading lives in
  `OcptSchedulePlanSnapshot.presenceCellOf` (a plain `OcptPresenceCode?`, null being the blank cell),
  and a cell whose person is convoked on a day they are unavailable is marked from
  `OcptSchedulePersonUnavailableAlert`, not from a second reading of that rule. Having nothing to
  withhold, the grid joins `Convocations`, the positions matrix and the `Alerts` panel as a view that
  carries no `isReadOnly` handling at all.
  **`lib/utils/ocpt_schedule_alerts.dart`** (pure, no Flutter, no drift, no `Tr`) is what the mode
  says about a plan before the plan breaks: a sealed `OcptScheduleAlert` per kind, each carrying
  **ids and figures alone** — resolving a name and writing the sentence is the panel's job — and a
  severity that is a property of the *kind* rather than of an occurrence. Eleven kinds: a person
  convoked on a day they are unavailable (honouring the day-part window), a person on two slots of
  one day whose bands overlap, and a slot outside every window its location declares are **hard**;
  a position lost between two consecutive slots, a role in a placed shot convoked on no slot that
  day, a role with no actor (only among the roles the schedule actually uses), a timeline over-run
  against a pinned anchor, a slot whose fixed end its own blocks over-run, a person's day past
  the maximum recorded for them, a person's rest short of the project's own minimum, and a slot
  booked at a location whose recorded permit does not cover that date are **soft**.
  `OcptScheduleRestTimeAlert` compares a person's departure with their arrival on the **next day
  they are actually convoked on** — never merely the next calendar date, which is why the rule sorts
  the days by date itself where the position-lost one reads the caller's own order — and the gap
  crosses midnights honestly, a night ending at 1620 followed by a 07:00 call the next date reading
  as four hours. It is raised on the **second** of the two days, the one whose call is too early and
  the day a production would move. `OcptSchedulePermitNotValidAlert` is named for what it says: it
  never fires on a **missing** permit, only on a recorded window that fails to cover the date, which
  is why the plan's own `…PermitMissingAlert` was not the name kept. Three absences are deliberate
  and each is argued in
  the file's own doc comment: **a location declaring no window at all raises nothing** (absence of
  data is not a refusal, and a project that never entered availabilities must not be drowned — the
  same argument silences the permit crossing on a location that files none, and on a permit whose
  two dates were never recorded), an
  **anchor cycle** is not an alert (the anchor menu already refuses to close one, so it is defence
  against a hand-edited file rather than a state a user can reach), and there is **no "key position
  unfilled" alert** — nothing in this app says which position on a film is key, and a list invented
  for the occasion would read as the app's own opinion rather than the production's.
  The maximum a day is measured against is `people.maxDailyPresenceMinutes` (schema v16, nullable):
  **null means "nobody has recorded one", never "no limit"**, so the alert stays silent rather than
  advancing a legal maximum nobody here validated — which is why the column exists at all instead of
  a constant. It is not restricted to minors (an adult under a medical restriction is the same fact)
  but sits beside `minorNotes` on the person sheet, where that constraint is thought about, and it is
  blanked by **both** erasure paths alongside it. `project_info.minimumRestMinutes` (schema v17,
  nullable) is that same argument at the project's own level — the rest a production says it owes
  between two days — and it is **deliberately not defaulted to 660**: eleven hours is French law,
  this app ships in more than one country, and a default would be the app advancing a legal figure
  nobody here validated, which is the whole reason it is a column rather than a constant. It is
  typed on `OcptProjectSettingsPage`, in minutes, read back as a formatted duration and **left empty
  by default**, an empty field writing null rather than a figure nobody chose.
  The alerts live in the `Alerts` **dock tab** rather than above the agenda the mock puts them over:
  a plan is broken whichever view is being read, and the count in the status bar is what says so from
  the other three. Each entry names what it concerns and offers the day it concerns — a selection,
  so the panel writes nothing and needs no `isReadOnly` handling either.
  **Which day is broken is said on the day itself**, by `OcptScheduleDayAlertBadge`: the left dock's
  day cards, the three agenda presentations (compact — the mark alone — in the week header and the
  month cell) and the day view's own summary band all wear it, over
  `ocptGroupScheduleAlertsByDay` (pure, in the alerts file) as `OcptSchedulePlanSnapshot
  .alertsByDayId` and `OcptScheduleState.alertsOfDay`. A day raising nothing draws **nothing at all**
  rather than a zero, the mark is the graver of the two severities among that day's own alerts (one
  hard alert makes the day read as blocked), and it is **read off the alerts, never a second reading
  of the nine rules** — the rule the presence grid already follows. Its
  tooltip names how many and of which kinds, each kind once however often it was raised. Its `onTap`
  is **nullable and wired in exactly one place**, the day view's own summary band, where it opens the
  `Alerts` dock tab: everywhere else it is left null, every one of those surfaces being clickable
  already — a day card selects its day, an agenda cell opens it — and a badge swallowing that tap
  would make selecting a day depend on hitting a 16-pixel square. The summary band is the one surface
  that is not a selection target, the day it describes being selected already, so there is nothing
  there for the badge to steal. Opening a dock tab writes nothing, so — like the panel itself — it
  withholds nothing under a version preview. `OcptScheduleRoleUncastAlert` marks no day,
  carrying none: a role's casting is not a fact about any one day of the shoot.
  The agenda's own **`Colour by`** control tints its three presentations by **location** (the tint
  they already painted) or by **effect**, INT/EXT crossed with day/night read off the headings of the
  shots placed on that day through `ocptSceneEffectOf` (`lib/utils/ocpt_scene_effect.dart`, pure and
  shared with `OcptCallSheetPdfService`'s own `EFFET` column, so a printed call sheet and the agenda
  cannot disagree about what a heading says). It classifies `DAY`/`NIGHT`/`JOUR`/`NUIT` and **nothing
  else** — widening that set is a decision about a language, not a bug fix — and a day mixing two
  effects reads as an explicit **mixed** tint (`lib/constants/ocpt_schedule_effect_palette.dart`,
  fixed ARGB like every other palette that must read the same in every project) rather than as a
  dominance nobody computed, while a day with nothing placed or nothing classifiable keeps the
  theme's neutral: information and its absence never wear the same colour. The choice is state beside
  `agendaMode`, not persisted between sessions.
  **`OcptSchedulePlanSnapshot`** (`lib/models/`) is where the mode's five reads — the schedule, the
  shot list, the locations, the cast and the address book — are joined into the day-level facts
  everything else asks for: `timelinesOfDay`, `convocationsOfDay`, `sunTimesOfDay`,
  `dayArrivalMinute`, `firstLocationOfDay`, `presenceCellOf`, and `alerts` — the whole-shoot walk,
  computed **once** per snapshot rather than per read, which is what made this class stop being
  `const` exactly as `OcptScheduleState` did before it. It exists because those joins have **two**
  callers now,
  `OcptScheduleState` and the manager layer's two PDF services, and a second implementation over
  there is exactly how a printed call sheet and the day view would come to disagree about what hour
  a slot starts at. The state builds one **per state instance**, not per read: a state is immutable,
  so the join cannot go stale inside one, and `timelinesOfDay` is handed to the three agendas as a
  function reference and called once per day cell.
  The `⋮` menu prints the three documents the reference production paperwork is modelled on, each
  through its own options dialog and each offered **under a version preview too**, an export only
  reading. `OcptCallSheetPdfService` renders the **general** call sheet and the **named** ones from
  one composition, section for section against the reference `.docx`: recipients, the title block,
  the day's per-slot time bands, the crew note, the location(s) with a map link built from the
  coordinates alone (**never a network call**), the sun block, the contacts by department, the
  `SEQ / PLANS / EFFET / DÉCORS / RÔLES` table interleaved with the non-shooting blocks as full-width
  milestone rows, then the cast table and the two directories. That table carries **five columns, not
  the reference's six**: no field of this app says what happens in a sequence, so `RÉSUMÉ` could only
  ever have printed an em dash on every row, and a heading that promises what it never delivers is
  worse than one column fewer. The **cast table lists every role the day calls for**, not only the
  convoked ones (`_castRowsOfDay`): a role a placed shot plays but nobody linked to a slot is printed
  too, with em dashes for its arrival and its PAT band — the `RÔLES` column prints role *numbers*,
  and a reader looking `3` up has nowhere else on the sheet to find out who that is. Nothing is
  guessed from the shot's own hours (a convocation is the slot you are linked to, ADR 0018), so those
  em dashes say exactly what `OcptScheduleRoleNotConvokedAlert` raises in the app; the cast-and-extras
  directory follows the table row for row, the actor nobody called being precisely the one an
  assistant director has to phone. A **hair-and-make-up block additionally names the numbers of the
  roles its slot convokes** (`ocptScheduleBlockRoleNumbersOf` for the figures,
  `ocptScheduleBlockRoleNumbersLine` for the line both documents print them as), on a **line of its
  own under the caption, behind the `RÔLES` label** rather than in brackets after it — a slot
  convoking forty roles is exactly the band whose make-up department needs them most, and forty
  bracketed numbers are unreadable where a labelled line still scans. They are printed whatever the
  caption itself turned out to be — a production's own free text for that band says what it is, not
  who is expected in it — and come off `slot.cast` alone: a chair is a fact about the **unit**, not
  about whichever shot happens to be running. Every other block kind is left alone, and a slot
  convoking nobody prints no line at all. What a **named** sheet narrows is the **timetable, and only
  the timetable**: it keeps the
  day's header, prints the rows its recipient's own slots carry — and then the day's own cast table
  and both directories, exactly as the general sheet does, those answering "who else is on this day
  and how do I reach them", which is a question about the day rather than about the reader. Both
  write **one PDF per file into a
  folder the user picks**, and two recipients whose names collide each keep a file of their own
  (`-2`, `-3`), an overwrite being somebody never told to turn up.
  `OcptShootingPlanPdfService` prints the whole shoot: three **landscape** summary grids (locations,
  sequences, crew and cast) whose columns are **one per slot grouped under its day** — the
  reference's day-parts being exactly what a slot is here — chunked across pages when a shoot runs
  wide, then one portrait agenda per day with its hours, its sets and its shot tables. Its
  `Description` column is dropped for the same reason `RÉSUMÉ` is.
  `ocpt_schedule_pdf_shared.dart` holds what the two documents must not read differently: the walk
  that puts a day's parallel slot chains back into a single clock order, a block's caption, the HMC
  role numbers and the line they print as (so both documents say them identically, each handing in
  its own already-localized `RÔLES` label), a location's address line, and
  `ocptScheduleGeneratedAtStamp` — **the moment a document was produced**, `yyyy-MM-dd HH:mm`,
  deliberately carrying the **time** (a call sheet is regularly reissued the afternoon of the day it
  first went out, and two sheets stamped with the date alone cannot be told apart in the hand of
  somebody holding both) and deliberately **not** locale-formatted, that stamp being read as an
  identifier rather than as a sentence. Both services take a nullable `exportDate` defaulting to
  `DateTime.now()`, resolved **once per document** — so a plan whose rendering straddles a minute
  boundary still names one issue of itself on every page — and `OcptExportManager` resolves it once
  per **run** for the two exports that write a folder of files, a batch that read the clock per file
  reading as several issues of one day's paperwork. The shooting plan prints it on its title page and
  in the running head of **every** page (a day agenda torn out of it, or a grid pinned on a
  wall, has nowhere else to say which issue it is); the call sheets print it in the **title block**,
  general and named alike, a call sheet being one sheet handed over whole. Both read the same
  `versionLabel` word out of their own labels object. **Every
  hour on either page is the resolved one** and every convocation figure comes from
  `ocptComputeDayConvocations`; nothing is re-derived and nothing is invented.
  Neither document prints a guest, an event or a block's crew note yet, and the named call sheets
  therefore **filter guest convocations out** of their recipient list — the dialog's own selection
  keys and every reader behind them assume a convocation names a person or a role. A guest becomes a
  recipient the day the call sheet prints one, not before.
  Schema v17's own two tables are drawn by the mode as of M3. A **guest**
  (`shooting_slot_guests`) is somebody neither crew nor cast — a mayor lending a square, a
  journalist, an owner's cousin — convoked **by a slot** exactly as everybody else is, named by
  either a `people` row or a free name (the discriminator idiom, kept in the schema although the UI
  only ever writes its address-book half — see the slot card's own guest band above);
  `duplicateDay` copies guests with the crew and the cast, a location owner attending every day
  being entered once. An **event** (`shooting_day_events`) is the opposite kind of fact: what the day
  does **not** control, at an absolute hour — the village fireworks at 17:00 — belonging to the day
  rather than to a unit, taking part in **no chain** (a block kind for it would let it push a shot
  back) and deliberately **not** copied by `duplicateDay`, since an event happens on a date. A block
  additionally carries a **crew note** beside its `notes`: `notes` is private and never prints,
  `crewNote` is the one that does, and until v17 nothing said which was which. The UI says it now:
  a slot's and a block's `notes` are labelled **`Private notes`** (`Notes privées`) — an ARB change
  alone, the columns keeping their names — so a note that never leaves the office cannot be mistaken
  for one the crew will read.
- Binary assets (ADR 0013): a photo or a signed document is **referenced, never embedded**. The
  `assets` table holds a path, a kind and its subject's id; no bytes ever enter the `.ocpt`, so
  megabytes never reach a changeset sync designed around small per-column edits. A missing file is
  a normal state rather than an error — the UI shows the reference with a "file not found" marker —
  and it is the honest cost of the choice: a `.ocpt` sent to a colleague arrives without its
  photos, and a restored version restores a reference that may now dangle. **`OcptAssetsService`
  is the one place a row of that table is minted or tombstoned** (`insertAsset`/`tombstoneAsset`,
  unguarded because their callers already refused the write and are already inside their own
  transaction; `removeAsset` and `updateAssetValidity`, guarded, are the user's own gestures): from
  schema v17 a row also carries `validFrom`/`validUntil`, the window a **document** is valid over —
  a filming permit runs from a date to a date — never anything read off the file, which the app
  never opens; **null means "nobody has recorded dates", never "valid forever"**, which is why
  `OcptSchedulePermitNotValidAlert` stays silent rather than advancing a claim nobody entered. The
  pair is typed on the location sheet's own permit card, under the referenced document and **only
  once one is referenced** — there being nothing to date otherwise — through the same date field the
  permit date itself uses, and withheld under a version preview like every other field there. The
  four services that reference
  a file hold it rather than each writing the table their own way, so a photo, a scouting photo, a
  permit and a signed release are all created and dropped alike. What a reference **looks like** is
  decided once too, by `OcptReferencedImage` (the image draws, or the caller's fallback does, a
  missing file being a state) and by `OcptAssetFileLine` (a document, read by its name, saying so
  out loud) — a photo silently falling back to initials and a list silently one item short are not
  the same failure.
- Erasing a person (`local_erasures`): deleting a person writes the tombstone **and blanks their
  personal columns**, so the file stops holding a phone number, a home address and an allergy for
  someone who asked to be removed. Versions cut across that — a payload captured earlier still
  holds a full copy — so the erased ids are kept in `local_erasures` and the **restore path scrubs
  on decode** (`OcptProjectVersionsService._scrubErasedPeople`, reading the list fresh from the
  database so an erasure recorded *after* a version was taken still binds): versions stay
  byte-identical (the codec never rewrites a stored payload), and the working copy never
  resurrects an erased person. The scrubbed row is blanked and tombstoned rather than dropped —
  `roles.personId`, `elements.ownerPersonId`, `assets.personId` and `locations.contactPersonId` may
  still point at it. **Their `assets` rows are blanked too, path and label**: an absolute path
  routinely names the person (`…/cession-droits-Jean-Dupont.pdf`) and always says where a
  photograph of them sits, so tombstoning the row without emptying it would leave the leak open.
  **`_scrubErasedPeople` and `OcptPeopleService.deletePerson` (with
  `OcptAssetsService.erasePersonAssets`) implement the same
  erasure from two starting points and must be kept in step by hand**: a column blanked by one but
  not the other reopens the leak. A row belonging to a location or an element is nobody's personal
  data and is left alone by both. That list is a table for the same reason
  `project_versions` is one: parked in `project_info.settingsJson` it would be captured, hashed and
  written back by any restore, which would forget the erasure and resurrect the person in one
  transaction. `local_erasures` is therefore local — no tombstone, no `sortKey`, no stamps, never
  captured, never hashed, never restored.
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
  whole of page 1 for the title page when one is present, matching the PDF exporter.
- Editor docks: `OcptWorkspaceDock`/`OcptWorkspaceDockDivider`
  (`lib/ui/pages/workspace/widgets/ocpt_workspace_dock.dart`) give the scene panel and the right
  dock draggable-divider resizing with a 320 px centre floor (right dock yields width first);
  widths are fractions of the editing row, persisted through
  `OcptPropertiesManager.editorLeftDockFraction`/`editorRightDockFraction`.
  `OcptWorkspaceDockLayoutController extends ChangeNotifier` holds the live fractions during a
  drag so it never emits a bloc state per frame; the bloc only sees one
  `OcptEditorDockFractionsChangedEvent` on `onHorizontalDragEnd`. The right dock
  (`OcptEditorRightDock`, still under `lib/ui/pages/editor/widgets/`) is tabbed
  (`OcptEditorRightDockTab { preview, syntax, inspector, metadata, versions }`); its tab row is
  itself clickable (`onTabSelected`), while the toolbar's preview/syntax buttons — **raw mode
  only**, the styled mode reaches every tab through the tab row alone — additionally *open* a closed
  dock on their tab (inspector/metadata/versions have no toolbar button in either mode). The shell's
  own right-dock
  toggle closes the dock whichever tab it shows, and reopens it on `lastRightDockTab` (the last
  tab explicitly selected, never null, `preview` by default), falling back to `syntax` when that
  tab is `preview` and the styled mode is active. Switching to styled mode auto-closes an open
  preview tab and remembers it (`autoClosedRightDockTab`, a separate memory) for the next switch
  back to raw, unless the user explicitly closed the dock themselves.
- Right dock content: `OcptEditorInspectorPanel` shows the scene under the caret (heading, speaking
  characters, estimated duration, page-eighths) from `FountainSceneStatistics.of` (`fountain_kit`,
  the scene-scoped sibling of `FountainScriptStatistics`, exposing `pageEighths` — never a minutes
  field, duration is derived at the call site on the one-page-per-minute convention).
  `OcptEditorMetadataPanel` shows the title-page fields and the script-wide statistics, read-only,
  with an "Edit…" button opening the existing title-page dialog through `OcptRouterManager`. Both
  are recomputed on the editor's existing 150 ms parse debounce, never per keystroke.
- The `Versions` dock tab (`OcptProjectVersionsPanel`/`OcptProjectWorkingCopyCard`/
  `OcptProjectVersionCard`/
  `OcptProjectVersionCreateDialog`, `lib/ui/pages/workspace/widgets/`) is the one panel of the dock
  that is about the **project** rather than the mode showing it, so it is hosted by every mode's
  dock (`OcptEditorRightDockTab.versions`, `OcptShotListRightDockTab.versions`,
  `OcptResourcesRightDockTab.versions` — the resources dock's only tab —,
  `OcptBreakdownRightDockTab.versions` and `OcptScheduleRightDockTab.versions`) and built from
  `MixinOcptProjectVersionsState` alone. That state, the events and the handlers all live in
  `lib/ui/pages/workspace/blocs/` as `MixinOcptProjectVersionsBloc` +
  `MixinOcptProjectVersionsState` (the `MixinActThemesBloc` idiom): a new production mode gets the
  tab by mixing both in and answering the two hooks the mixin can't know —
  `flushPendingProjectWrites` (a pending autosave/field edit must reach the working copy *before* a
  preview swaps the database out, or it would land in the previewed version's in-memory one) and
  `reloadFromProjectDatabase` (entering or leaving a preview replaces
  `OcptOpenProjectModel.database`, so whatever the mode shows is read again from it — and that
  reload **must** emit `previewedVersionId`, read from `OcptProjectsManager.currentProject`, in the
  same state as the data it just read, or the mode draws one frame of a version's content with the
  working copy's editing affordances still on it). A mode also decides *when* the working copy is
  worth re-reading, by dispatching `OcptProjectWorkingCopyRefreshRequestedEvent` — the four modes
  do it on opening the `Versions` tab and on a save landing while it is already open, and the mixin
  throttles that path to one capture every 2 s, since it reads the whole project; the captures that
  follow an operation which just changed the project are never throttled.
  The panel reads top-down as **the present, then the sealed history**: `OcptProjectWorkingCopyCard`
  is the first entry and is not a `project_versions` row at all — the live counters, whether the
  content still matches the base version, and `Create a version`, which is the working copy's own
  action rather than the panel's. It is absent while a preview is up (`workingCopy` is null then,
  and a capture is refused: it would read the project file, i.e. a state the user isn't looking at).
  Underneath, a version card is
  clicked to enter a version's read-only preview and clicked again to leave it. The three answers a
  card can ask for — `Delete`, `Restore this version` and `Rename` —
  are given **inline inside the card** rather than through a dialog, one at a time
  (`versionPendingDeletionId`, `versionPendingRestoreId`, `versionPendingRenameId`); the restore's
  question is the one place
  saying the page setup comes back too and the replaced state is kept. The previewed version's card
  may be restored (the obvious next move after reading it) but not deleted (the preview reads a
  database hydrated out of that very row). Restoring flushes the mode's pending writes first, then
  reloads the mode *and* the list, since a restore changes both. The one name it mints
  (`Before restoring <name>`) is
  localized by the page and travels on the event: no bloc or manager here has a `Tr`.
- Read-only preview across the app: `OcptOpenProjectModel.isReadOnly` is the source of truth, and
  `MixinOcptProjectVersionsState.isPreviewingVersion` is the copy of it every mode's widgets are
  built from (`previewedVersion` resolves the row itself out of the list already in state, so the
  banner names it without a second copy). A previewed version is laid out with
  `OcptOpenProjectModel.previewedPageSetup` — the setup it was captured against, rendered with and
  **never written**, since the margins half of it is an app-wide preference. The screenplay mode
  renders `OcptEditorPreview` in the centre in *both* editing modes rather than a read-only editor
  (a second super_editor rendering path — `SuperReader`, its own stylesheet, its own title-page
  components — would have to be maintained forever), so the right dock's preview tab doesn't exist
  then either — `OcptEditorState.isPreviewTabAvailable` is the single predicate for "the centre
  already is the formatted screenplay", true of the styled mode and of a preview alike, and the
  existing auto-close/restore dock transition follows it. Every affordance that writes is withheld
  rather than disabled where it can be: the save control, the format controls, the `⋮` entries
  that rewrite (import & replace, page setup, title page), the metadata panel's "Edit…", the shot
  list's `+ Shot`, its orphan delete buttons, its inspector controls and its deleted-character
  banner actions, every one of the resources mode's `+ Add …` footers, sheet fields, pickers,
  sub-list rows and delete actions — including the photo slot, which loses its menu altogether and
  becomes a plain unclickable picture, and the role sheet's things card, which keeps its links and
  their notes readable while withholding the picker and the unlink control (its `Roles concerned`
  counterpart withholding nothing, having nothing to withhold) —, and — in the breakdown mode —
  the word click that opens a range
  (nulling that one callback withholds the whole tagging path, since no anchor can open and no
  popover ever has a range to show), the status and category chips, the scene status control, its
  sets row's picker and chip dismissals, every
  notes field, the suggestion acceptances and the tag removal; and — in the schedule mode — the day
  creation and its card's `⋮`, the `+ Block` menu and the shot picker it opens, every slot, crew,
  cast, guest and block control — the guest band keeping its title and its cards while losing its
  `+ Guest` footer, its remove controls and its reason/notes fields, so a previewed slot with no
  guest reads as the empty band it is — the day's own events band and its inspector
  section, which withhold their `+ Event` footer, their remove controls and all three of a row's
  fields (a previewed day with no event drawing nothing), the slot's own anchor menu (rendered as
  plain text, with no menu at
  all), the minute fields (which render as plain text with no callback), the inspector's own
  duration field and its crew-note field,
  and the block anchor pin and the shot status. The `Convocations` panel is the exception that
  needs no handling at all: it offers nothing to withhold, so it draws identically either way, and
  the positions matrix, the `Alerts` panel and the presence grid are its three siblings in that —
  all of them only read (the grid since schema v17 dropped the override its cell click used to
  write), and the day each of them opens is a selection.
  What only reads stays: the exports,
  the scene/sequence panels, the statistics, the resources search, the breakdown's own two views,
  scene panel, legend filtering, header search and occurrence jumps — and a click on a tagged word
  still selects its target, since selecting writes nothing — the schedule's three agenda
  presentations and their tint, its day view, its positions matrix, its alerts, its computed times
  and its sun bands, and the left dock's own click
  on a shot, which now only selects one, plus the app-wide display
  preferences.
  Widgets express it as a **null callback** (`onChanged`/`onToggled`/`onSelectRequested`… nullable,
  Flutter's own "no callback, no affordance" idiom); a composite panel
  (`OcptShotInspectorPanel`, `OcptShotListRemovedCharacterBanner`, each of the resources mode's
  four sheets, and the breakdown's `OcptBreakdownTargetInspector`/`OcptBreakdownSceneInspector`)
  takes an `isReadOnly` flag instead and hands its own parts the null callbacks, so a
  control added later can't be gated in one place and forgotten in the other. Entering a preview
  additionally clears every *pending* write state a mode holds — the breakdown's open tag anchor,
  its popover range and its debounced field edits — so no half-started gesture survives into a
  version's read.
  `OcptWorkspaceReadOnlyBanner` carries the two ways out of a preview:
  `Start from this version` (a plain restore of the version being read, which asks nothing further —
  the banner is that question, and `OcptProjectsManager.restoreProjectVersion` leaves the preview on
  its own before writing anything) and the filled `Back to the current version`.
- The Fountain syntax guide (`OcptEditorSyntaxGuidePanel`) renders the `const`
  `ocptFountainSyntaxEntries` table (`lib/models/ocpt_fountain_syntax_entry.dart`, one entry per
  `OcptFountainSyntaxTopic`) as read-only snippets in both editing modes (the *panel* is
  mode-agnostic; only the toolbar shortcut opening it is raw-mode only); its titles reuse the 11
  existing `editorBlockType*` ARB keys where a topic already had one.

## Coding standards

Follow the ACT company guidelines (read them when in doubt):

- `~/projects/desvac-needleless-apps/bg-dev/docs/flutter-coding-guidelines.md` (RD/RFL rules)
- `~/projects/desvac-needleless-apps/bg-dev/docs/coding-guidelines.md` (durability rules)
- `~/projects/desvac-needleless-apps/bg-dev/docs/flutter-project-setup.md` (project setup/l10n)

House style: `Ocpt` prefix on app classes, doc comments on every declaration, match the
existing files' idioms exactly. Tests use inline private test doubles (no shared helpers
directory) and set `BlinkController.indeterminateAnimationsEnabled = false` when pumping
super_editor widgets. Do not touch `actlibs/` (submodule) or `lib/generated/`.

## Licensing / REUSE

Every file needs SPDX info. Header (comment for code, HTML comment for markdown, `.license`
sidecar for uncommentable files, `REUSE.toml` annotations for blanket cases):

```text
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
```

`reuse lint` must stay 100% compliant. Licenses live in `LICENSES/` (Apache-2.0, CC0-1.0,
LicenseRef-ALLCircuits-ACT-1.1, OFL-1.1 for Courier Prime).

## Commits

Conventional Commits, English, subject ≤50 characters, meaningful body when useful. Work done
by a Sonnet 5 subagent ends the message with the trailer:

```text
Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
```

## Localization

ARB files: `lib/l10n/intl_en_GB.arb` (main) + `lib/l10n/intl_fr.arb`; generated `Tr` class via
`dart run intl_utils:generate`. Every user-visible string goes through `Tr.of(context)`, added
to both ARB files.

**In French, a screenplay's scene is « une séquence »** — never « une scène », which in this trade
names something else. The one fixed idiom that keeps the word is « mise en scène » (the shot
inspector's directing notes). English is untouched: the code, the ARB keys, the models and the
tables all say `scene`, and so does the English UI. This is a naming rule about the French UI
alone, and a new key must not reintroduce the other word.

## Verification gates

All inside the devcontainer; all must pass before finishing any step (analyze + test at
minimum before each commit):

1. `flutter pub get`
2. `dart run intl_utils:generate`
3. `dart run build_runner build`
4. `flutter analyze` → 0 issues
5. `flutter test` → all green
6. `flutter build linux --debug`
7. `reuse lint` → compliant
8. `git grep -l 'allcircuits.com' -- ':!actlibs' ':!AGENTS.md' ':!docs/plans'` → empty
   (the two extra exclusions are the files that *describe* this gate, which would otherwise
   always match their own search string)
9. `dart run tool/check_markdown.dart` → no violation, whenever a `.md` file was touched. This
   gate is about the documentation rather than the code, so it is the one to run before pushing
   a docs-only change, which the other eight would say nothing about. The `markdown_lint`
   workflow runs the real `markdownlint-cli2`, which needs a Node runtime the devcontainer does
   not carry; the script re-implements the rules that need no markdown parsing (line length,
   trailing spaces, hard tabs, final newline), so an over-long paragraph is caught here instead
   of by a red build. It is a pre-flight, not a replacement: passing it does not prove the
   workflow will pass, but a failure it reports is always real.

## Known pitfalls

- **super_editor is pinned to `0.3.0-dev.52` exactly** — dev.50 and below do not compile with
  Flutter 3.44.6 (`DocumentImeInputClient` misses the now-abstract
  `TextInputConnection.updateStyle(TextInputStyle)`). dev.52 re-exports `BlinkController`, so
  tests get it from `package:super_editor/super_editor.dart` with no direct `super_text_layout`
  dependency.
- **A `MenuItemButton` may not go inside a `Wrap`**, and the failure is a thrown
  `RenderFlex children have non-zero flex but incoming width constraints are unbounded`, not a
  layout that merely looks wrong. A menu item lays its child out inside an `Expanded`, itself inside
  a `Row` sized to the maximum, which is fine down a menu's single column and throws the moment a
  `Wrap` hands it the unbounded width a wrap always gives its children. A grid inside a
  `MenuAnchor`'s `menuChildren` therefore uses plain `InkWell`s and closes the menu itself
  (`MenuController.maybeOf(context)?.close()`, before reporting the pick, since reporting it
  rebuilds the tree the anchor lives in) — which is what `OcptResourcesColorSwatches` does.
- super_editor stylesheets: only TextStyle/padding merge across rules — use one mutually
  exclusive `StyleRule` per Fountain line type (no `BlockSelector.all` baseline), or
  maxWidth/textAlign silently drop.
- `flutter test` runs on the plain Dart VM: it needs the system `libsqlite3` (already in the
  devcontainer image — do not remove it from the Dockerfile).
- No full-app-boot widget tests: `PackageInfo.fromPlatform()` hangs on unmocked platform
  channels. Test pages/widgets directly instead.
- reuse 6.2.0 misdetects some git-ignored directories; blanket `REUSE.toml` annotations cover
  `lib/generated/**`.
- `staging.yaml` config is never loaded (the ACT `Environment` enum has no staging value);
  documented inline, kept intentionally.
- ACT manager streams (`ActThemesManager`, `LocalesManager`) emit on change and never replay their
  current value to a new listener, and `MixinActThemesBloc` does not seed itself: a bloc mixing it
  in must build its initial state from the manager's getters (`OcptSettingsBloc`/`OcptMainAppBloc`
  do), otherwise the stored preference is neither shown nor applied, and picking the value already
  stored emits nothing at all.
