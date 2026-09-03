<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Development guide for AI agents

This file gives any agent session or subagent working in this repository what it must know
whatever it is doing: what the project is, where the development plan stands, the architectural
rules that hold everywhere, and every norm the code, commits and workflow must follow. Read it
entirely before writing anything. The architecture is described area by area in
`docs/architecture/`, and reading the file covering the code you are about to change is part of
the job, not optional background.

`CLAUDE.md` is a symlink to this file, so Claude Code and any agent that looks for `AGENTS.md`
read the same guide. Edit `AGENTS.md`; never replace the symlink with a copy.

## Project overview

Open Cine Prod Tools is an **open-source suite of film-production tools** (Apache-2.0,
github.com/borlnov/open_cine_prod_tools). The MVP is a **Fountain screenplay editor**; the
découpage technique (shot lists), the scenario coverage per shot, the resources catalogue (the
people, the cast, the locations and the physical elements), the script breakdown (*dépouillement*),
the casting candidates and the shooting schedule ship alongside it, and the long-term roadmap adds,
in priority order: call sheets, budget, script supervisor reports, and storyboard.

- Target platforms: **Linux + Windows first**, then macOS, Android, iOS. macOS is built and
  released by the CI (see `docs/architecture/foundations.md`) but has never been run on a Mac —
  there is none available to this project, so nothing about it can be verified here beyond what
  the CI checks structurally. Say so rather than implying it works.
- Storage: **local only** for now — one SQLite file per project (`.ocpt`, via drift), with the
  Fountain text as the source of truth plus a stable-UUID scene index. **One project holds one or
  several episodes** (a series is one file, ADR 0019): a screenplay row *is* an episode, the modes
  read the one the workspace selects, and the schedule reads them all. Sharing and collaboration
  ship through an offline-first replica synced by a self-hostable, domain-blind relay server — see
  `docs/adr/0009`, `docs/adr/0010` and `docs/architecture/sync.md`. Google Drive was evaluated and
  rejected as a transport.
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
  reference) — see `docs/architecture/foundations.md`.
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
  confirmation widget must not appear. The standing exception has two holders: the `Versions`
  dock panel, whose `Delete`/`Restore`/`Rename` are answered **inside the card they belong to**,
  and the project dictionary dialog's per-word removal, answered **inside the row it belongs
  to** — in both, a list of rows has no other way to say *which* one is being talked about.
- **Before creating any new view/screen, ask Benoit design questions first** (layout, style,
  references). He shapes the UI himself.

## Development plan & status

Everything that has shipped is recorded by the code itself, by `docs/architecture/` and by
`docs/adr/` — this section lists only what is still ahead, so it stays short enough to be read.
The MVP (Fountain editor, shot list, resources, breakdown, schedule, their exports, project
versions, the sync-ready data model, the portable project package, the desktop packaging) is done;
the budget mode has shipped whole (the quote against the CNC nomenclature, the cash journal it is
measured against, the financing plan and catering pass that say what pays for it, the revenue
sharing that splits what the film earns, and its four documents, `docs/architecture/budget.md`).

| Step | Content | Status |
| --- | --- | --- |
| 22b | Collaboration & sync: the changeset engine, the domain-blind relay, the pairing UI, live push, presence, the portable on-set server and in-app relay hosting have all shipped (`docs/architecture/sync.md`, `docs/on-set-server.md`, `docs/adr/0009`, `docs/adr/0010`) | ✅ done |
| — | The M2–M6 end-user guide for the whole collaboration feature, in `docs-site/` | 📝 planned |
| — | Roadmap after that, in priority order: call sheets beyond what the schedule mode already prints, script supervisor reports, storyboard | 📝 planned |

Step numbers are historical: they were allocated as the work was planned, are referenced by no
file any more, and a new one simply continues the series. What used to be listed here as `0`
through `29k` is in `git log`.

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
  folded into `docs/architecture/`, the plan is deleted — the code, that directory and the ADRs
  are the record from then on.
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

The app is built 100% on the **ACT Flutter packages** (git submodule `actlibs/`, consumed as plain
`path: actlibs/<pkg>` dependencies), stores one SQLite file per project through drift, and puts
every production mode inside one workspace shell.

**The detail lives in `docs/architecture/`, one file per area, and it is not optional reading:**
before changing code, read the file covering it — most of what is written there is a decision
already made and argued, and re-deciding it in code is how two parts of the app come to disagree.
`docs/adr/` is the other half of that record: an ADR argues *why* a structural choice was made, a
file in `docs/architecture/` says what the code does because of it.

| Read this | Before touching |
| --- | --- |
| [`foundations.md`](docs/architecture/foundations.md) | the managers, the routing, the workspace shell, the theme, the packaging, the drift schema, the project versions, the sync-ready data model, the binary assets, the spell-check manager, the project dictionary, the read-only preview, the portable project package, opening a project file from another build |
| [`screenplay.md`](docs/architecture/screenplay.md) | `packages/fountain_kit/`, `packages/spell_kit/`, `lib/ui/pages/editor/` |
| [`exports.md`](docs/architecture/exports.md) | `lib/managers/export/`, the export panel |
| [`resources.md`](docs/architecture/resources.md) | `lib/ui/pages/workspace/modes/resources/` |
| [`breakdown.md`](docs/architecture/breakdown.md) | `lib/ui/pages/workspace/modes/breakdown/` |
| [`schedule.md`](docs/architecture/schedule.md) | `lib/ui/pages/workspace/modes/schedule/` |
| [`budget.md`](docs/architecture/budget.md) | `lib/ui/pages/workspace/modes/budget/`, `lib/utils/ocpt_budget_*.dart` |
| [`sync.md`](docs/architecture/sync.md) | `packages/ocpt_sync_protocol/`, `packages/ocpt_sync_relay/`, `lib/managers/sync/`, `lib/ui/pages/sharing/`, `lib/ui/pages/joining/`, the sync status indicator |

What follows is the short list of rules that hold **everywhere**, and that a file in
`docs/architecture/` only ever refines:

- **Never use `Navigator` directly.** All navigation, including closing a dialog and returning its
  result, goes through `globalGetIt().get<OcptRouterManager>()`.
- Managers are `AbsWithLifeCycle` classes owned by `OcptGlobalManager extends AbsUiGlobalManager`,
  registered with builder factories (`dependsOn` ordering) and resolved via `globalGetIt()`.
- BLoC: the ACT pattern (`BlocForMixin`, `BlocStateForMixin`, sealed events registered with
  `registerMixinEvents()` / `on<>`), one bloc per page, pages split UI/bloc/state/event files. A
  production mode owns its own bloc; the workspace shell is a stateless slot widget and knows
  nothing about a mode's content.
- **No service ever deletes a synchronised row** (ADR 0010): every synchronised table carries
  `isDeleted`, a "delete" is an update to it, and every read filters tombstones back out. The two
  local tables — `project_versions` and `local_erasures` — are the only exceptions.
- Ordering is `sortKey`, a fractional index (`lib/utils/ocpt_fractional_key.dart`), so a move
  writes exactly one row. The legacy `position` column is never renumbered and nothing reads it.
- A schema number is allocated **at merge time, not at branch time** (ADR 0007), and a new
  synchronised table has to reach `OcptProjectVersionCodec`'s payload, its `contentDigest` and its
  `_applyPayload` together.
- **An irreversible action is always confirmed by `OcptConfirmDialog`**, opened by the page or the
  mode: a widget only ever asks, through a nullable `on…Requested` callback.
- Under a **read-only preview**, an affordance that writes is **withheld, not disabled** — widgets
  express it as a null callback, composite panels take an `isReadOnly` flag.
- **No manager or service ever sees a `Tr`**: a mode resolves every word and hands it in as a
  labels object or as plain strings. Every user-visible string in the UI goes through
  `Tr.of(context)`.
- Every export is reached from the toolbar's own `Export` control and writes through a native save
  dialog — no export ever writes to a default location silently.
- Layering: `packages/fountain_kit` stays free of Flutter imports, a `lib/models/` file may not
  import the manager layer, and a pure rule both layers read belongs in `lib/utils/`.
- **Before reaching for a pub.dev package, look in `actlibs/` first.** The app is built on the ACT
  packages, and several needs are already met there — secure storage is
  `act_local_storage_manager`'s `AbstractSecretsManager`, not `flutter_secure_storage` used
  directly. A new pub.dev dependency is the fallback, taken only once no ACT package covers the need.
  When one nearly does but falls short, that is a gap to raise for the submodule (a separate change
  against `actlibs/`, never an edit in place here), not a reason to add the pub.dev package beside it.
  The one exception is a build failure: when an ACT package's transitive dependencies do not compile
  on a platform this app ships (a stale plugin failing the Android or Windows build, say), a
  maintained pub.dev package is used and the ACT gap is raised separately — an unbuildable dependency
  is not a preference to honour. Check the CI build matrix, not just `pub get`, before trusting one.
- A photo or a signed document is **referenced by path, never embedded** (ADR 0013); a missing file
  is a normal state, not an error.
- Generated code (`**/*.g.dart`, `lib/generated/`) is git-ignored and regenerated by CI; never edit
  it, and never touch the `actlibs/` submodule.

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
