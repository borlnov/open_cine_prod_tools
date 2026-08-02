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
découpage technique (shot lists) and the scenario coverage per shot ship alongside it, and the
long-term roadmap adds, in priority order: shooting schedule, call sheets, budget, script
supervisor reports, storyboard, breakdown, and a casting tracker.

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
| 23 | Project versions (issue #20): schema v4 (`project_versions`, `project_info.currentVersionId`), `OcptProjectVersionCodec` and its versioned payload, the `Versions` dock tab shared by every mode, the read-only preview swapping an in-memory database in, and restore/fork (safety version, tombstones and version stamps, post-commit margins) | ✅ |
| 23b | Project versions rework: the working copy as the list's first entry (`OcptProjectWorkingCopyCard`, live counters, drift from its base), `currentVersionId` read as the **base** and its card no longer inert, inline rename, schema v5's `contentDigest` deduplicating the restore's safety version, and the fork dropped in favour of a plain restore | ✅ |
| 22b | Collaboration & sync M2-M6: the app on a tablet, the changeset engine, the domain-blind relay, live push and presence, the portable on-set server (`docs/adr/0009`, `docs/plans/collaboration-and-sync.md`) | 📝 planned |
| 23 | macOS build (issue #40): the bundle named "Open Cine Prod Tools", the App Sandbox dropped from both entitlements files (ADR 0011), the SDK's `Podfile` tracked, a `macos-dmg` composite action building a drag-to-`Applications` disk image with `hdiutil`, and a `build-macos` job gated like the Windows one, signing and notarization wired but dormant | ✅ (untested on a real Mac) |
| 24 | Scenario coverage PDF export (issue #42): source provenance in the paginator (ADR 0012), schema v4 (`shots.abbreviation`, deduced from the shot size), `OcptScenarioCoverageLayout` (bars, lanes, ticks, uncovered washes, legend and summary), the coverage PDF service over a shared `OcptScriptPagePainter`, the shot list `⋮` entry and its options dialog | ✅ |

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

The host has **no usable Flutter SDK**. Run ALL Flutter/Dart/reuse commands inside the
devcontainer (Flutter 3.44.6, the version pinned by `actlibs/tool/.flutter_version`):

```bash
cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
```

Git commands run on the host, from the repo root. The devcontainer persists the pub cache and
Claude config in named volumes; X11 is forwarded so `flutter run -d linux` can open a window.

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
  only state is `{ OcptWorkspaceMode mode, bool isLoading }` — it owns *which* production mode is
  active, nothing about that mode's own content. `OcptWorkspaceMode { screenplay, budget,
  schedule, shotList }` is persisted through `OcptPropertiesManager.workspaceMode` (modelled on
  `editorMode`) so opening a project restores the last mode used. `OcptWorkspaceShell` is a
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
  (`lib/ui/pages/workspace/modes/shot_list/`, owning `OcptShotListBloc`), and the two remaining
  ones are stateless `OcptBudgetMode`/`OcptScheduleMode` widgets rendering a shared empty state —
  no bloc, no data, "coming in a future version". `OcptWorkspaceDock`/`OcptWorkspaceDockDivider`/
  `OcptWorkspaceDockLayoutController` (`lib/ui/pages/workspace/widgets/`) are the dock geometry
  primitives every mode's shell reuses; `OcptWorkspaceModeSwitcher` is the bottom band that
  selects the mode (all four entries always selectable, unimplemented ones only discreetly
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
- Persistence: drift schema v5 (`project_info`, `screenplays`, `screenplay_snapshots`, `scenes`,
  the three shot list tables, `row_field_versions`, `project_versions`), `storeDateTimeAsText:
  true`, scene reconciliation in 3 passes (explicit scene number → exact heading → relative order).
  `**/*.g.dart` is git-ignored (documented deviation); CI regenerates with build_runner.
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
  `OcptProjectVersionCodec` is the only thing that knows the payload's shape: every row of the five
  synchronised tables verbatim (primary keys, tombstones and `row_field_versions` stamps included)
  plus the page setup, in a JSON format versioned by `payloadFormat` — independent of the schema
  version, upgraded on decode when older, refused when newer. Counters shown on a card
  (`OcptProjectVersionSummary`) are measured once, at creation.
  The codec also owns `contentDigest`, the SHA-256 of a payload's canonical *content* — rows sorted
  by primary key and each row's JSON keys sorted, `row_field_versions` and the page margins left
  out, since the stamps change on every restore and the margins are an app-wide preference. It is
  stored beside the payload (`project_versions.contentDigest`, nullable: versions written before
  schema v5 have none, and a null digest reads as "unknown", i.e. *modified*, which is the
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
- Sync-ready data model (ADR 0010): **no service ever deletes a synchronised row** (the local
  `project_versions` above is the single exception). Every synchronised table
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
  app: the native open dialog, and five services it owns (RFL18) — `OcptFountainIoService`
  (bytes ↔ text, suggested file names), `OcptPdfExportService` (the screenplay PDF),
  `OcptShotListXlsxExportService` (the shot list workbook), `OcptScenarioCoveragePdfService` (the
  annotated coverage PDF) and `OcptSaveLocationService` (wraps `file_selector`'s `getSaveLocation`,
  a **direct** dependency kept in sync with the version `act_file_transfer_manager` already resolves
  transitively, for the native "save as" dialog every export goes through — no export ever writes
  to a default location silently). The two PDF services share one `OcptCourierPrimeFontsLoader`
  (handed to both by the manager, so the 4 embedded TTFs are decoded once) and one
  `OcptScriptPagePainter`, which owns the positioned line drawing both of them start from. The home
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
  dock (`OcptEditorRightDockTab.versions` and `OcptShotListRightDockTab.versions`) and built from
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
  worth re-reading, by dispatching `OcptProjectWorkingCopyRefreshRequestedEvent` — both modes do it
  on opening the `Versions` tab and on a save landing while it is already open, and the mixin
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
  components — would have to be maintained forever), so the right dock's preview tab doesn't exist then either — `OcptEditorState
  .isPreviewTabAvailable` is the single predicate for "the centre already is the formatted
  screenplay", true of the styled mode and of a preview alike, and the existing auto-close/restore
  dock transition follows it. Every affordance that writes is withheld rather than disabled where it
  can be: the save control, the format controls, the `⋮` entries that rewrite (import & replace,
  page setup, title page), the metadata panel's "Edit…", the shot list's `+ Shot`, its orphan delete
  buttons, its inspector controls and its deleted-character banner actions. What only reads stays:
  the exports, the scene/sequence panels, the statistics, and the app-wide display preferences.
  Widgets express it as a **null callback** (`onChanged`/`onToggled`/`onSelectRequested`… nullable,
  Flutter's own "no callback, no affordance" idiom); the two composite panels
  (`OcptShotInspectorPanel`, `OcptShotListRemovedCharacterBanner`) take an `isReadOnly` flag instead
  and hand their own parts the null callbacks, so a control added later can't be gated in one place
  and forgotten in the other. `OcptWorkspaceReadOnlyBanner` carries the two ways out of a preview:
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

## Known pitfalls

- **super_editor is pinned to `0.3.0-dev.52` exactly** — dev.50 and below do not compile with
  Flutter 3.44.6 (`DocumentImeInputClient` misses the now-abstract
  `TextInputConnection.updateStyle(TextInputStyle)`). dev.52 re-exports `BlinkController`, so
  tests get it from `package:super_editor/super_editor.dart` with no direct `super_text_layout`
  dependency.
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
