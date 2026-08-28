<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the foundations

The layers every task crosses: the managers, the routing, the BLoC pattern, the workspace
shell and the episode it shows, the app-wide look, the spell-checking, the packaging, how a project
file travels and how one from another build is opened, and the four things every mode inherits —
the persistence, the project versions, the sync-ready data model and the read-only preview.

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
  state is `{ OcptWorkspaceMode mode, bool isLoading, OcptWorkspaceRevealRequest? revealRequest,
  List<OcptEpisode> episodes, String? selectedEpisodeId }` — it owns *which* production mode is
  active and *which episode* it shows, nothing about that mode's own content.
  `OcptWorkspaceMode { screenplay, breakdown, shotList, resources, schedule, budget }` is ordered by
  the order the work happens in (write, break down, shoot-list, resource, schedule) with `budget`
  last since it is the one mode that reads every other mode's own figures rather than one anybody
  starts from, and is persisted through `OcptPropertiesManager.workspaceMode` by **name** rather
  than by index (modelled on `editorMode`), so opening a project restores the last mode used and
  reordering the enum is safe. The modes are `EditorPage` (screenplay, under `lib/ui/pages/editor/`),
  `OcptBreakdownMode`, `OcptShotListMode`, `OcptResourcesMode`, `OcptScheduleMode` and
  `OcptBudgetMode` (each under `lib/ui/pages/workspace/modes/<mode>/`, each owning its own bloc) —
  `OcptWorkspaceMode.isImplemented` is true of all six today, kept as an explicit list rather than a
  bare `true` so a mode shipped ahead of its own content (the way `budget` itself once sat here,
  rendering the shared "coming in a future version" empty state) has a single, obvious place to be
  left out of again.
  `OcptWorkspaceShell` is a stateless slot widget (title, toolbar actions, overflow entries, left
  panel, right panel, centre, status bar, dock controller) built by whichever mode is active. The
  end of the toolbar is the shell's own chrome rather than a mode's actions, so its order can't
  drift from one mode to the next: the mode label, the `Export` control (`onExportRequested`), the
  two dock toggles (`isLeftDockOpen`/`onToggleLeftDock`, same pair for the right), the save control
  (`onSave`/`isSaving`, spinner while in flight), the project settings action
  (`onProjectSettingsRequested`), the `Help` action (`onHelpRequested`), then the `⋮` menu — each
  rendered only when the mode wired it, so a mode with no dock, nothing to save, nothing to open
  there, or no help panel of its own simply shows fewer of them. `onHelpRequested` is never withheld
  under a version preview the way `onProjectSettingsRequested` is: only the budget mode wires it in
  today, opening its own right dock onto a `Help` tab that only ever reads (`budget.md`), so a
  preview has nothing about it to protect. A mode's own
  `toolbarActions` sit before that group, and the **episode selector** is the shell's own chrome at
  the *other* end, right after the project title, for the same reason (below). Two further slots
  serve the read-only preview of a project version: `isReadOnly`, which swaps the unsaved-changes
  dot for the `Read only` pill, and `banner`, a full-width widget between the toolbar and the docks
  row (`OcptWorkspaceReadOnlyBanner` fills
  it) — everything else a preview withholds is each mode's own job, since only a mode knows what its
  affordances are. `OcptWorkspaceDock`/`OcptWorkspaceDockDivider`/
  `OcptWorkspaceDockLayoutController` (`lib/ui/pages/workspace/widgets/`) are the dock geometry
  primitives every mode's shell reuses; `OcptWorkspaceModeSwitcher` is the bottom band that selects
  the mode (all entries always selectable, unimplemented ones only discreetly marked). See
  `docs/adr/` for why this is a slot widget plus a mode-only bloc rather than a mode-aware god-bloc.

- One project, several episodes (ADR 0019): a series, a mini-series and a feature shot in two parts
  are one production with several screenplays — one crew, one address book, one set of locations,
  one schedule. **A `screenplays` row *is* an episode**: it gains `number` (an ordinary integer, the
  one that prints, with no uniqueness constraint — two episodes numbered 4 is a state the user
  reaches and repairs by hand) and `sortKey` (what actually orders them, as everywhere else). There
  is no `episodes` table, which would be a 1:1 indirection nothing reads. `OcptEpisode`
  (`lib/models/`, pure: `id`, `number`, `title`) is how the UI reads one, an **untitled** episode
  being ordinary — a series is numbered long before it is titled, and `ocptWorkspaceEpisodeLabelOf`
  (`lib/ui/utils/`) is the single place `Episode 3` is worded from. `OcptScreenplayService` owns the
  CRUD (`loadEpisodes`, `createEpisode`, `updateEpisode`, `reorderEpisode`, `deleteEpisode`): a
  screenplay *is* an episode, so no service of its own was added for one.
  The **selector** is built by `OcptWorkspaceShell` itself from `episodes`/`selectedEpisodeId`/
  `onEpisodeSelected`, so the gesture cannot drift from one mode to the next, and its nullable
  callback is the whole of its conditional behaviour: **no control is drawn at all** — never a
  disabled one, the very idiom the toolbar's own slots already carry (`onExportRequested`, the two
  dock toggles, each rendered only when the mode wired it, above) — for a project with a single
  episode, and for the **schedule** mode, which reads every episode at once and would otherwise show
  a selector that either does nothing or lies, and the **budget** mode, whose catalogue names no
  episode at all (`budget.md`) and would show one filtering a read that was never split by episode
  to begin with. The menu only ever *chooses*; its last entry, `Manage episodes…`, lands on
  `OcptProjectSettingsPage`.
  That one toolbar slot holds **either** the selector **or**, for a project with a single episode,
  the screenplay mode's `Add an episode…` button (`onAddEpisodeRequested`, wired by that mode alone)
  — the only thing naming an episode on a project that has one, and the answer to a feature nobody
  could find: the settings page's `Episodes` card was reachable only by someone already looking for
  it. It is the screenplay mode's because that is where an episode is written, one button in the
  whole app being a discovery rather than a recurring offer, and it is withheld under a version
  preview like every other way into the settings. It leads there rather than creating anything: the
  number and the title are set in the same gesture, and a misclick writes nothing.
  **The selection is not persisted**:
  opening a project lands on the first episode, a reading preference costing nothing to lose where a
  per-project key would have to live either in `OcptPropertiesManager` (keyed by a path that moves)
  or in `project_info` (which versions capture and hash).
  **Switching episode remounts the mode**: the selection lives in `OcptWorkspaceBloc` and
  `WorkspacePage` keys the mode widget on it, so a fresh mode bloc loads from scratch. This is
  deliberate — a mode's state is full of things scoped to what it was showing (a selected shot, an
  open tag anchor, a scroll position, a debounced field edit), and it reuses unchanged the
  flush-on-leaving-the-tree path each mode already has for the version preview, so a pending write
  reaches the working copy before the new episode is read. The stated cost is that **the current
  selection is lost on every switch**.
  The screenplay, breakdown, shot list and resources modes read the selected episode where they read
  `primaryScreenplayId` before; that field survives as what its name says — the first episode's
  screenplay, which the home page's "import a screenplay" path needs when it creates a project — and
  is no longer what a mode reaches for. The schedule reads them all.
  **The sequence prefix is one rule with one implementation**: `ocptSceneDisplayNumberOf`
  (`lib/utils/`, pure and tested) renders `<episode>.<scene>` as soon as the project holds more than
  one episode, and a **null `episodeNumber` means "this project has one episode"**, returning
  `sceneNumber ?? "${position + 1}"` verbatim. Every reader calls it rather than restating it
  (`OcptSceneRef`, `OcptBreakdownScene`, `OcptShotListService` and
  `OcptSchedulePlanSnapshot.sceneNumberBySceneId`), and a shot's `<sceneNumber>/<rank>` code follows
  without `OcptShot` changing at all — `ocptShotSceneNumberOf`/`ocptShotRankOf` split on the last
  `/`, so `2.12/3` still gives `2.12` and `3`. **The screenplay itself is never prefixed** — not the
  styled editor's computed numbers, not the raw preview, not the screenplay PDF, not the coverage
  export, not the sides: the `#N#` numbers are the author's, and rewriting them at print time would
  print something other than the screenplay. The episode is named beside the page instead.
  Episodes are managed from the project settings page's own `Episodes` card
  (`OcptProjectSettingsEpisodesSection`) — the list, an add action, inline rename, `▲`/`▼` reorder,
  and a delete going through `OcptConfirmDialog` like every irreversible action. A caller that sent
  the user there **for that card** says so through the route's `extra`
  (`OcptProjectSettingsReveal`), and the page scrolls to it once its settings have loaded — landing
  at the top of four stacked cards would break the promise the button that led there just made; a
  page opened plainly passes null and scrolls nowhere. That dialog says
  what it takes (the screenplay, its snapshots, its scenes, its shots and coverages, its breakdown,
  and the `role_episodes` links naming it) and what it leaves: the people, the locations, the
  elements and **the shooting days**, which were never that episode's — a block that placed one of
  its shots is tombstoned with the shot, the day it sat on is not.
  A project's episode count is also read outside the workspace: `OcptRecentProjectModel.episodeCount`
  is recorded by `OcptProjectsManager` as it changes and on leaving a project, and
  `OcptProjectCard` wears a `⟨N episodes⟩` pill for it — **null** (an entry written before the app
  recorded it) and **1** both draw nothing.
  **A single-episode project is exactly what it was before**: one screenplay numbered 1, no
  selector, no prefix, nothing anywhere reading as an episode of something. That is a standing
  constraint on every surface this feature touches, not a transitional state. Its one deliberate
  exception is the screenplay toolbar's `Add an episode…` button above, which names no episode —
  it offers to *make* the project a series, and is the only door to a feature that otherwise
  advertises itself nowhere.

- Cross-mode navigation: a mode sending the user to another one *for a reason* (the breakdown's
  `Open in Resources`, meaning "this very element, over there") attaches an
  `OcptWorkspaceRevealRequest` (`lib/models/`, sealed, today `OcptResourcesRevealRequest { tab,
  recordId? }`) to `OcptWorkspaceModeSelectedEvent`; the workspace bloc transports it and **never
  reads inside it**, `WorkspacePage` hands it to the mode that recognizes its own subtype and to no
  other, and the opened mode reports back with `OcptWorkspaceRevealRequestConsumedEvent`. It is
  **one-shot** by construction: the destination bloc takes it as a *constructor* argument (an event
  would race the load, which clears every selection) and nulls it in that first load, so entering or
  leaving a version preview — which reloads through the same handler — doesn't yank the user back; a
  plain switch from the mode switcher carries none and clears whatever an earlier one left. A
  `recordId` that is null, or that names a row tombstoned since, only opens the tab. A set is
  revealed as **its location** (`OcptSet.locationId`, resolved by the asking mode), a set having no
  sheet of its own.

- Config: `OcptConfigManager` (yaml assets in `assets/config/`), properties persisted through
  `OcptPropertiesManager` (recent projects capped at 10, locale, theme, editor mode, page
  margins, spell-check visibility).

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

- Spell-checking (ADR 0020, and `screenplay.md` for what the editor does with it):
  `OcptSpellCheckManager` (`lib/managers/`) owns **one worker isolate for the whole app**, holding
  a `spell_kit` `SpellChecker` over whichever language's bundled dictionary was last loaded, plus
  the session's ignored words and the open project's learned ones. One isolate rather than one per
  editor mount: parsing a dictionary costs ~250-350 ms and ~14 MB retained, and the editor is
  remounted by an episode switch, a mode toggle, an import and a version restore, none of which
  changes the language. It is spawned lazily on the first `useLanguage`, killed by
  `disposeLifeCycle` and by `useLanguage(null)`. The two asset files are read on the **main**
  isolate (`rootBundle.loadString`, ~1.8 MB) and only their text is sent across, which avoids the
  `BackgroundIsolateBinaryMessenger` dance entirely; the worker never touches Flutter. Every
  request carries a **generation**, bumped by `useLanguage`, `ignoreWord(s)` and `setLearnedWords`,
  and an answer from a stale one is dropped here rather than painted over fresh text. The manager
  sees no `Tr` and no project row: the bloc resolves both.
- The language a project is written in is `project_info.screenplayLanguage`
  (`OcptScreenplayLanguage { fr, enGb }`, stored through a `TypeConverter` like `OcptPageFormat`),
  beside the page format and the currency and for the same reason: a screenplay written in French
  stays French on a colleague's machine running the app in English, so the fact travels inside the
  `.ocpt` file. It is **nullable** — null means "nobody has said", and nothing is checked — seeded
  at project creation from the **app's own UI language** (`LocalesManager.currentLocale`, behind an
  injectable seam, not the platform locale the page format and the currency read: a paper size
  belongs to where the production is, a screenplay language to whoever is typing), and **left null
  when no dictionary is bundled for that language** — no underlines rather than every word
  underlined against the wrong language. That is a guess made once at the only moment where a
  wrong guess costs a dropdown pick, and picked afterwards in the project settings page
  (`OcptProjectSettingsScreenplayLanguageSection`, whose `None` entry is the honest off switch for
  a project). It is not per episode: a series is written in one language, and a bilingual one would
  be an additive nullable column on `screenplays` overriding this one.
- The project's own dictionary is `project_dictionary_words` (`id`, `word`, `isDeleted`), a
  **synchronised** table written by `OcptProjectDictionaryService` — a table rather than a key in
  `project_info.settingsJson` because that is the difference, once sync lands, between two writers
  merging the two names they each taught the checker and one of them overwriting the other's list.
  A word is stored **as typed** and matched **case-insensitively**, so re-learning it in another
  case revives its row instead of adding a second one, and un-learning it is a tombstone like every
  other delete here. `spell_kit` applies the casing rule that makes that useful: a word with no
  interior capital (`Marie`) covers every casing, one with an interior capital (`MacGuffin`) covers
  only itself. The words are read, filtered, added and removed in `OcptProjectDictionaryDialog`,
  opened from the project settings page's own `OcptProjectSettingsDictionarySection` — the section
  states the count and carries an `Edit…` button, and the **dialog reports rather than writes**
  (it returns what was added and removed; the *page* applies it through the service), the same
  shape the title-page dialog already has. Its per-row `✕` is answered **inside the row itself**
  (`Remove?` / `Yes` / `No`), which is the **second holder** of the standing exception to the
  confirm-dialog rule — the `Versions` dock panel below is the first — and for the same reason: a
  list of rows has no other way of saying *which* row is being talked about, and stacking a modal
  question on an already-modal dialog to un-learn ten names in a row would be a punishment.

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

- Persistence: drift schema v29 (`project_info`, `screenplays`, `screenplay_snapshots`, `scenes`,
  the three shot list tables, the fifteen resources tables (`role_candidates`, `role_elements` and
  `role_episodes` among them), `breakdown_tags`, `scene_breakdowns`, the eight schedule tables, the
  eight budget tables (`budget_postes`, `budget_lines`, `budget_entries`, `budget_commitments`,
  `budget_resources`, `budget_mileage_rates`, `budget_revenues`, `budget_shares`),
  `project_dictionary_words`, `row_field_versions`, `project_versions`),
  `storeDateTimeAsText: true`, scene reconciliation in 3 passes (explicit scene number → exact
  heading → relative order). v25 to v28 are the budget mode's own four steps, every one of them
  additive — `budget.md` for what they hold. v24 creates `shooting_block_candidates`, the
  candidacies an audition
  block sees (ADR 0024), and v20 created `role_candidates`, who was seen for a part — both additive
  with nothing to backfill. v23 and v24 also **drop** four things no released build ever wrote, all
  of them written by intermediate versions of the branch that landed them: `shooting_days.kind`,
  `shooting_day_blocks.roleCandidateId`, `shooting_day_blocks.roleId` and the whole
  `shooting_slot_candidates` table. They are dropped **defensively**, through
  `_dropColumnIfPresent`/`_dropTableIfPresent` — the two helpers in this file that **ask the file
  what it holds** rather than deducing it from the version it states, because a version number says
  nothing about whether a file was made against an unmerged build — and nothing is carried over: a
  slot-wide convocation names no hour, so there is no block to attach it to. **The budget's own
  four steps deliberately do not do the same**, and the asymmetry is a decision rather than an
  oversight: renumbering v20-v23 to v25-v28 made the number 23 mean two different things — the
  casting step to a released file, the whole budget mode to a file written by this branch before it
  merged — and such a file now dies on `duplicate column name: default_vat_rate_basis_points`
  rather than opening. Defensive `if absent` guards on all four steps would have saved those files,
  and they were weighed and refused: no released build ever wrote one, only the two machines this
  mode was developed on hold any, and four permanently non-standard migration steps are a poor
  price for files their own authors can recreate. v19 adds
  `project_info.screenplayLanguage` (nullable, no backfill: "nobody has said" is as true after the
  migration as before it) and creates `project_dictionary_words`, both additive. v18 is the
  multi-episode migration: `screenplays` gains `number` and `sortKey`, `role_episodes` is added, and
  `roles.screenplayId` and `shooting_days.screenplayId` are **dropped** — the fifth time ADR 0007's
  additive-only rule is set aside for a column drop, through drift's own
  `Migrator.alterTable`/`TableMigration` recipe. It reconstructs nothing: the single screenplay a
  file holds is numbered 1 and given a key, every live `roles` row gets the `role_episodes` row its
  own `screenplayId` already stated (**minted with the role's own id**, so two replicas migrating
  the same file produce the same rows), and a shooting day is not given an episode on the way out —
  it simply stops having one. `**/*.g.dart` is git-ignored (documented deviation); CI regenerates
  with build_runner. A schema number is allocated **at merge time, not at branch time** (ADR 0007):
  of two branches in flight, whichever merges second renumbers, and the migration test pins what
  `onCreate` produces against what every upgrade path produces, so a table declared and forgotten in
  `onUpgrade` fails there rather than on a user's file. The budget mode is what proved that rule:
  it was built against v20 to v23 and payload formats 16 to 19, found the casting work already
  merged onto both ranges, and renumbered to v25 to v28 and formats 21 to 24 on its way in.

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
  thirty-one captured tables verbatim (primary keys, tombstones and `row_field_versions` stamps
  included) plus the page setup, the currency and the minimum rest, in a JSON format versioned by
  `payloadFormat` — independent of the schema version, upgraded on decode when older, refused when
  newer. It is **a hand-written mirror of the schema**, and a new synchronised table has to be added
  to all three of it, `contentDigest` and `_applyPayload`: leave it out of the payload and a restore
  rewinds half the project, out of the digest and the working copy claims not to have drifted, out
  of `_applyPayload` and it is never written back.
  The `_payloadUpgrades` map brings an older payload onto the current shape, and every entry is one
  of **four kinds**, each argued in its own doc comment — read them before writing a fifth. A
  **materialised** value states what was true at capture: an empty list for a table that did not
  exist yet, or a column's own default — `budgetPostes` and `budgetLines` join that kind at payload
  format 16, materialising as empty lists for every version sealed before this milestone existed
  (`budget.md`). Restoring such a version therefore tombstones every row added since, which is the
  truthful reading of "this project had none" — an edit like any other restore, not a no-op that
  leaves that half of the project alone. A **null** says nobody had
  recorded that figure, and is written back like any other changed column; the currency is the one
  exception, its column having never been nullable, so *its* null alone means "leave the live value
  untouched". A **removal** drops a list or a column the project has no concept for any more: unlike
  an empty list it makes no claim about the moment of capture, and unlike the currency's null it
  leaves no live value alone. A **derived** value is format 13's own, and the **only lossless step
  in the codec**: `role_episodes` is rewritten out of the `roles.screenplayId` that same step
  removes, the payload already carrying, on every role row, exactly the fact the new table records.
  It is allowed there and nowhere else — only because the column being dropped and the table being
  added say the same thing — and it mints each link with the role's own id, deterministically, so
  restoring one version twice writes one set of links rather than two for a later merge to
  reconcile. Across all four, **nothing is ever reconstructed** — a dropped lead time does not
  become a preparation slot nobody asked for. Counters shown on a card
  (`OcptProjectVersionSummary`) are measured once, at creation. Restoring a format-12 version into a
  multi-episode project therefore **tombstones every episode but the first**, with its scenes, its
  shots and its breakdown, that being the truthful reading of "this project had one episode when
  this version was sealed"; **no role loses its casting** on the way through, a role no longer being
  a script's.
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
  screenplay whose text it changes (`OcptSnapshotReason.restore` — the merge base a three-way
  screenplay merge looks for), then inserts/updates/**tombstones** row by row and stamps, in
  `row_field_versions`, every column whose value actually changed, at a version strictly above what
  that column held and under the local `deviceId`. A hard delete would be re-inserted by an offline
  replica, and an unstamped rewrite would be undone by the next merge; a column already matching the
  payload is left unstamped, so a restore never stomps a concurrent edit that agreed with it.
  `scenes` is the exception that carries no stamp (never merged) but still goes back verbatim, ids
  included. There is no fork operation: starting from an older state *is* restoring it, after which
  the working copy descends from it and the user names their branch when they seal it — a dedicated
  fork only ever added a card whose content duplicated the version it branched from. The margins
  half of the restored page setup is written by `OcptProjectsManager` **after** the transaction
  commits, since a preference can't be rolled back with it.

- Sync-ready data model (ADR 0010): **no service ever deletes a synchronised row** (the two local
  tables are the exceptions: `project_versions` above, and `local_erasures` below). Every
  synchronised table carries `isDeleted`, a "delete" is an update to it, and every read filters
  tombstones back out — including `scenes`, which is never synchronised but whose rows are
  referenced by two tables that are. Ordering is `sortKey`, a fractional index
  (`lib/utils/ocpt_fractional_key.dart`, base-62 strings, never ending on the lowest digit so two
  keys always have room for a third): `ocptFractionalKeyBetween` allocates one,
  `ocptFractionalKeySequence` backfills a whole group, `ocptFractionalKeyRekeyPlan` gives the
  minimal set of writes a reorder needs, so an insertion or a move writes exactly one row.
  `position` survives as a legacy column stamped once at insertion and never renumbered — nothing
  reads it, and `OcptShot.position` is a read-time rank the loading service counts off, not that
  column. `row_field_versions` holds the per-column version stamps a merge resolves conflicts with;
  the only writer so far is a version restore (above), and M3 of the collaboration plan is what will
  stamp every other edit — a composite primary key is rendered into `rowId` through
  `ocptCompositeRowStampKey` (`lib/utils/ocpt_row_stamp_key.dart`), the app's single encoding of
  one. `OcptPropertiesManager.loadOrCreateDeviceId()` mints and keeps this replica's UUID.

- Binary assets (ADR 0013): a photo or a signed document is **referenced, never embedded**. The
  `assets` table holds a path, a kind and its subject's id; no bytes ever enter the `.ocpt`, so
  megabytes never reach a changeset sync designed around small per-column edits. A missing file is
  a normal state rather than an error — the UI shows the reference with a "file not found" marker —
  and it is the honest cost of the choice: a `.ocpt` sent to a colleague arrives without its
  photos, and a restored version restores a reference that may now dangle. **`OcptAssetsService`
  is the one place a row of that table is minted or tombstoned** (`insertAsset`/`tombstoneAsset`,
  unguarded because their callers already refused the write and are already inside their own
  transaction; `removeAsset` and `updateAssetValidity`, guarded, are the user's own gestures). A row
  also carries `validFrom`/`validUntil`, the window a **document** is valid over — a filming permit
  runs from a date to a date — never anything read off the file, which the app never opens; **null
  means "nobody has recorded dates", never "valid forever"**, which is why
  `OcptSchedulePermitNotValidAlert` stays silent rather than advancing a claim nobody entered. The
  pair is typed on the location sheet's own permit card, under the referenced document and **only
  once one is referenced** — there being nothing to date otherwise. The four services that reference
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
  `OcptAssetsService.erasePersonAssets`) implement the same erasure from two starting points and
  must be kept in step by hand**: a column blanked by one but not the other reopens the leak.
  **`role_candidates` joins that rule**, being the first *link* table to hold something about a
  person rather than only ids: its `notes` is what somebody wrote about them at an audition, so
  erasing a person blanks it and tombstones the row, in all three implementations
  (`eraseCandidaciesOfPerson`, `_scrubErasedPeople`, `ocptScrubErasedPeopleFromPayload`) — and the
  test walking every key the codec writes for a person is what catches a miss.
  `shooting_block_candidates` does **not** join it: the link carries no `personId`, pointing at a
  candidacy rather than at a person, and it drops out on its own once that candidacy is tombstoned.
  A row belonging to a location or an element is nobody's personal data and is left alone by both.
  That list is a table for the same reason `project_versions` is one: parked in
  `project_info.settingsJson` it would be captured, hashed and written back by any restore, which
  would forget the erasure and resurrect the person in one transaction. `local_erasures` is
  therefore local — no tombstone, no `sortKey`, no stamps, never captured, never hashed, never
  restored.

- The portable project package (ADR 0021): a `.ocpt` holds no bytes of what it references (ADR
  0013), so a project *sent* to somebody arrives with every reference dangling. A **package** is
  what travels instead: one zip, extension **`.ocptz`**, holding `manifest.json`, `project.ocpt`
  (fixed name, the display name living in the manifest) and `assets/<assetId>/<file name>`, written
  and read by `OcptProjectPackageService` (`lib/managers/projects/services/`) through
  `package:archive`, streamed to disk (`ZipFileEncoder`/`InputFileStream`) and never assembled in
  memory. The manifest is versioned by **`packageFormat`** independently of the schema, exactly as
  `OcptProjectVersionCodec`'s `payloadFormat` is — older upgraded on read
  (`_packageManifestUpgrades`, empty at format 1), newer refused
  (`OcptProjectPackageStatus.unsupportedPackageFormat`).
  **Everything on this path works from a file path and never from an open database**, and nothing in
  the service imports drift: one code path therefore serves a project open in a mode and a project
  card on the home page, and a package built from an older file does not migrate it on the way out.
  The `.ocpt` inside is produced by **`VACUUM INTO`** from a **read-only** connection — one
  consistent file out of an open database, the WAL folded in, `user_version` preserved — so an
  export never writes the user's own file, not even to checkpoint it.
  A referenced file that is **gone** never blocks anything: `scanAssets` stats every live `assets`
  row first, the caller asks through `OcptConfirmDialog` with the count and the labels, and
  continuing records those rows in the manifest's `skippedAssets`, which the **import reports
  again** as the project lands. A packaged row is rewritten to its entry inside the archive and back
  to an absolute path on import; a skipped one keeps the path it always had, so either end can name
  what is missing. `project_versions` travel **scrubbed**: on the staged copy alone, every stored
  payload is rewritten with the erased people taken back out
  (`ocptScrubErasedPeopleFromPayload`, `lib/utils/`, the third implementation of the erasure rule
  after `OcptPeopleService.deletePerson` and `OcptProjectVersionsService._scrubErasedPeople`, and
  the only untyped one — a package may be built from a file at any schema version, so it reads the
  payload's own keys; a test walks every key the codec writes for a person and fails unless this one
  classifies it), `content_digest` nulled on the rows actually touched, and `local_erasures` emptied.
  Everything the mode side needs is `MixinOcptProjectPackageBloc`/`MixinOcptProjectPackageState`
  (`lib/ui/pages/workspace/blocs/`), mixed in beside `MixinOcptProjectVersionsBloc` and declaring
  the **same `flushPendingProjectWrites` hook**, for the same reason: the package is built from the
  file on disk, so a debounced field edit has to reach it first. `OcptHomeBloc` mixes it in too, for
  a project card's `Export…` with nothing open. See `exports.md` for where the two gestures sit in
  the UI.

- Opening a project file from another build (ADR 0022): **no `.ocpt` reaches drift before it has
  been read.** `OcptProjectFileCompatibilityService` (`lib/managers/projects/services/`) probes it
  through raw `sqlite3` opened **read-only** — `PRAGMA user_version`, plus
  `project_info.app_version_at_creation` when `sqlite_master` says that table is there — and answers
  an `OcptProjectFileCompatibility` (`lib/models/`) whose `verdict` is
  `current | older | newer | unreadable`. `OcptProjectsManager.probeProjectFile` is that probe and
  `openProject`'s `_gateOnFileFormat` is what acts on it, **before** the currently open project is
  closed, so a refusal never costs the user the project they already had: a **newer** file is
  refused with `OcptProjectStatus.newerFormat` — not opened, not touched, not added to the recent
  list, since handing it to drift stamps its `user_version` back *down* while leaving the newer
  build's tables in place — an **older** one returns `OcptProjectStatus.migrationRequired` unless
  the caller passes `allowMigration: true`, and `current`/`unreadable` open exactly as they did
  before the gate existed. The default of `false` is deliberate: forgetting the gate fails as a
  refusal, never as a silent migration.
  The migration is confirmed by `OcptConfirmDialog` like every other irreversible action, worded by
  the *page* (`OcptHomePage._stateFileCompatibility`) and never by the bloc, and it names the two
  format numbers and **where the copy will be kept**; the refusal is `OcptProjectFileNewerDialog`.
  The copy is `<name>.backup-v<n>.ocpt` beside the original (a counter appended rather than an
  existing backup overwritten), taken with `VACUUM INTO` from a read-only connection, at the very
  path `OcptProjectFileCompatibility.suggestedBackupPath` named — the promise and the write cannot
  drift apart — and **no copy means no migration**: a backup that fails to write turns the open into
  an `ioError`. The extension is kept on purpose, a backup being a file the older build can still
  open. Every door into a project file goes through this gate — the home page's `Open…`, a recent
  project card, and the landing of an imported package — and **exporting deliberately does not**: a
  package carries the file at whatever format it is in, and the recipient's own gate is what states
  the migration. The version *preview* and the *restore* are untouched too, hydrating an in-memory
  database from a payload the codec already version-checks.

- The `Versions` dock tab (`OcptProjectVersionsPanel`/`OcptProjectWorkingCopyCard`/
  `OcptProjectVersionCard`/`OcptProjectVersionCreateDialog`, `lib/ui/pages/workspace/widgets/`) is
  the one panel of the dock that is about the **project** rather than the mode showing it, so it is
  hosted by every mode's dock (each mode's own `…RightDockTab.versions`) and built from
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
  worth re-reading, by dispatching `OcptProjectWorkingCopyRefreshRequestedEvent` — the modes do it
  on opening the `Versions` tab and on a save landing while it is already open, and the mixin
  throttles that path to one capture every 2 s, since it reads the whole project; the captures that
  follow an operation which just changed the project are never throttled.
  The panel reads top-down as **the present, then the sealed history**: `OcptProjectWorkingCopyCard`
  is the first entry and is not a `project_versions` row at all — the live counters, whether the
  content still matches the base version, and `Create a version`, which is the working copy's own
  action rather than the panel's. It is absent while a preview is up (`workingCopy` is null then,
  and a capture is refused: it would read the project file, i.e. a state the user isn't looking at).
  Underneath, a version card is clicked to enter a version's read-only preview and clicked again to
  leave it. The three answers a card can ask for — `Delete`, `Restore this version` and `Rename` —
  are given **inline inside the card** rather than through a dialog, one at a time (the first of
  the two holders of that standing exception to the confirm-dialog rule — the project dictionary
  dialog's own per-row removal above is the second)
  (`versionPendingDeletionId`, `versionPendingRestoreId`, `versionPendingRenameId`); the restore's
  question is the one place saying the page setup comes back too and the replaced state is kept. The
  previewed version's card may be restored (the obvious next move after reading it) but not deleted
  (the preview reads a database hydrated out of that very row). Restoring flushes the mode's pending
  writes first, then reloads the mode *and* the list, since a restore changes both. The one name it
  mints (`Before restoring <name>`) is localized by the page and travels on the event: no bloc or
  manager here has a `Tr`.

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
  existing auto-close/restore dock transition follows it.
  **Every affordance that writes is withheld rather than disabled**, everywhere in the app: a
  creation footer, a picker, a field, a delete action, a menu entry that rewrites. What only reads
  stays — the exports, every panel and statistic, the searches, the agendas, the computed times, a
  click that merely selects — and a panel that is **entirely computed needs no handling at all**:
  `Convocations`, the positions matrix, the presence grid and the `Alerts` panel offer nothing to
  withhold, so they draw identically either way.
  Widgets express it as a **null callback** (`onChanged`/`onToggled`/`onSelectRequested`… nullable,
  Flutter's own "no callback, no affordance" idiom), which is often enough to withhold a whole path
  at once — nulling the breakdown's word click closes the entire tagging gesture, no anchor being
  able to open. A composite panel (`OcptShotInspectorPanel`, `OcptShotListRemovedCharacterBanner`,
  each of the resources mode's four sheets, the breakdown's two inspectors) takes an `isReadOnly`
  flag instead and hands its own parts the null callbacks, so a control added later can't be gated
  in one place and forgotten in the other. A control that would otherwise vanish into nothing is
  rendered as **plain text** instead (the schedule's minute fields and anchor menu), and a band
  whose contents are withheld keeps its title so a previewed slot with nothing in it still reads as
  the empty band it is. Entering a preview additionally clears every *pending* write state a mode
  holds — the breakdown's open tag anchor, its popover range, every debounced field edit — so no
  half-started gesture survives into a version's read.
  `OcptWorkspaceReadOnlyBanner` carries the two ways out of a preview: `Start from this version` (a
  plain restore of the version being read, which asks nothing further — the banner is that question,
  and `OcptProjectsManager.restoreProjectVersion` leaves the preview on its own before writing
  anything) and the filled `Back to the current version`.
