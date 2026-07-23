<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Development guide for AI agents

This file gives any Claude session or subagent working in this repository the full context:
what the project is, where the development plan stands, and every norm that the code, commits
and workflow must follow. Read it entirely before writing anything.

## Project overview

Open Cine Prod Tools is an **open-source suite of film-production tools** (Apache-2.0,
github.com/borlnov/open_cine_prod_tools). The MVP is a **Fountain screenplay editor**; the
long-term roadmap adds, in priority order: découpage technique (shot lists), scenario coverage
per shot, shooting schedule, call sheets, budget, script supervisor reports, storyboard,
breakdown, and a casting tracker.

- Target platforms: **Linux + Windows first**, then Android, iOS, macOS.
- Storage: **local only** for now — one SQLite file per project (`.ocpt`, via drift), with the
  Fountain text as the source of truth plus a stable-UUID scene index. Google Drive sync later,
  dedicated server last.
- Every document must stay exportable to human-readable formats (PDF, `.fountain`, and open
  docx/xlsx equivalents later).
- UI languages: English (`en_GB`, main) and French.

### Validated UI design (do not deviate without asking Benoit)

- Theme follows the system, **through the ACT themes manager** (`ActThemesManager`).
- Visual style: "creative studio" (DaVinci Resolve / Frame.io spirit) — near-black neutral
  surfaces, one vivid blue-violet accent (`0xFF6C5CE7`), calm in light mode.
- Home: grid of project cards (poster-ready), New / Open actions on top.
- Editor: centered text zone, collapsible scene-list side panel (left), discreet toolbar.
  Default mode: styled block editor (super_editor) with the real screenplay layout. Alternate
  mode: raw Fountain text with a side-by-side paper-simulated preview (white page even in dark
  theme). Courier Prime everywhere (source, preview, PDF).
- **Before creating any new view/screen, ask Benoit design questions first** (layout, style,
  references). He shapes the UI himself.

## Development plan & status

| Step  | Content                                                                                                                                                                                                  | Status                              |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| 0     | Devcontainer (Debian trixie, Flutter 3.41.9, git from source, reuse)                                                                                                                                     | ✅                                   |
| 1     | Repo reset (purge legacy code, `flutter create`, Apache-2.0/REUSE)                                                                                                                                       | ✅                                   |
| 2     | `actlibs/` submodule + global/config/logger managers                                                                                                                                                     | ✅                                   |
| 3     | Routing, theming, l10n (en_GB + fr)                                                                                                                                                                      | ✅                                   |
| 4     | Properties manager (recent projects, locale, theme, editor mode)                                                                                                                                         | ✅                                   |
| 5     | `packages/fountain_kit` (parser, serializer, layout metrics, tests)                                                                                                                                      | ✅                                   |
| 6     | drift database + projects manager + home page                                                                                                                                                            | ✅                                   |
| 7     | Editor raw mode + side-by-side screenplay preview                                                                                                                                                        | ✅                                   |
| 8     | Editor styled block mode (super_editor, real page layout)                                                                                                                                                | ✅                                   |
| R1-R3 | Review fixes: `OcptSpecificColors` file, SPDX email, dialogs via router manager                                                                                                                          | ✅ (`411d9b1`, `4d6835d`, `59e52e1`) |
| R4    | Review fix: editor toolbar back navigation (flush save → close project → pop)                                                                                                                            | ✅ (`a788bdf`)                       |
| 8b    | Styled mode rework: true WYSIWYG editor (hidden Fountain markers, block-type dropdown + Tab cycle + smart Enter, B/I/U, sticky manual types) — milestones M1-M6 in `docs/plans/wysiwyg-styled-editor.md` | ✅                                   |
| 9     | `.fountain` import/export (export manager + fountain IO service, home "Import a screenplay…" action, editor `⋮` menu with export / import-and-replace, pre-import snapshot)                              | ✅                                   |
| 9b    | Editor polish & page simulation (styled widths/Tab/dropdown/uppercase, preview fit-to-width, toggle icons, Word-like page mode — milestones M1-M7 in `docs/plans/editor-polish-and-page-simulation.md`)  | ✅                                   |
| 10    | Settings page (language system/en/fr via act_intl_ui, theme system/light/dark via `ActThemesManager`, page-setup settings (page size + margins), about section)                                          | ✅                                   |
| 11    | CI build & release: `.github/actions/*` + `build.yml` (Linux `.deb` + Windows Inno Setup installer, git-describe versioning, GitHub Release on `v*`), SHA-pinning + least-privilege on existing workflows, `dependabot.yml`, `.github/ci-doc.md` — milestones M1-M4 in `docs/plans/ci-build-linux-windows.md`                    | ✅                                   |
| 12    | PDF screenplay export (`pdf` package, line-level paginator, options dialog: page format pre-filled from project + scene-numbers checkbox, Courier Prime embedded, pagination via `FountainLayoutMetrics`, title-page editor splicing the Fountain source) — milestones M1-M4 in `docs/plans/pdf-screenplay-export.md` | ✅                                   |
| 13    | CI matrix {`.`, `packages/fountain_kit`}, README rewrite, `docs/adr/` (drift, fountain_kit, super_editor, generated-files deviation)                                                                     | ⬜                                   |
| 14    | Editor statistics (page count, character count, last autosave time)                                                                                                                                      | ⬜                                   |
| 15    | Fountain syntax user guide (raw mode help: tags/elements to create blocks)                                                                                                                               | ⬜                                   |

## Ways of working

- Benoit communicates in French; **all code, comments, commits, branches and GitHub content
  are in English**.
- Work happens on branch `13-rework-the-project-with-claude`.
- Sizeable work: plan first, reviewed by Benoit, then implementation **delegated to Sonnet 5
  agents** orchestrated and reviewed by the main session. User checkpoints between milestones.
- One commit per logical change. Never reference the plan, steps, or these instructions in
  code or commit messages (issue numbers are allowed in commits/PRs).
- Dependencies never reference their dependents.

## Toolchain

The host has **no usable Flutter SDK**. Run ALL Flutter/Dart/reuse commands inside the
devcontainer (Flutter 3.41.9, the version pinned by `actlibs/tool/.flutter_version`):

```bash
cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
```

Git commands run on the host, from the repo root. The devcontainer persists the pub cache and
Claude config in named volumes; X11 is forwarded so `flutter run -d linux` can open a window.

## Architecture

Built 100% on the **ACT Flutter packages** (git submodule `actlibs/`, consumed as plain
`path: actlibs/<pkg>` dependencies):

- `OcptGlobalManager extends AbsUiGlobalManager` owns every manager; managers are
  `AbsWithLifeCycle` classes registered with builder factories (`dependsOn` ordering) and
  resolved via `globalGetIt()`.
- Routes: `enum OcptRoute with MixinRoute { home, editor, settings, licenses }` +
  `OcptRouterManager extends AbstractRouterManager<OcptRoute>` (go_router underneath).
  **Never use `Navigator` directly** — all navigation, including closing dialogs, goes through
  `globalGetIt().get<OcptRouterManager>()` (`push`, `pop`, `pop<T>(result)`…). The editor
  route is guarded: it redirects to home when no project is open.
- BLoC: ACT pattern (`BlocForMixin`, `BlocStateForMixin`, sealed events registered with
  `registerMixinEvents()` / `on<>`), one bloc per page, pages split UI/bloc/state/event files.
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
  `lib/constants/ocpt_theme.dart`, `OcptSpecificColors` in `lib/models/`.
- `packages/fountain_kit`: pure-Dart Fountain parser/serializer with round-trip guarantee and
  `FountainLayoutMetrics` (US Letter/A4 Courier columns). Keep it free of Flutter imports.
- Persistence: drift schema v1 (`project_info`, `screenplays`, `screenplay_snapshots`,
  `scenes`), `storeDateTimeAsText: true`, scene reconciliation in 3 passes (explicit scene
  number → exact heading → relative order). `**/*.g.dart` is git-ignored (documented
  deviation); CI regenerates with build_runner.
- `OcptExportManager` (`lib/managers/export/`) owns getting a screenplay in and out of the app as
  a plain `.fountain` file: the native save/open dialogs, and `OcptFountainIoService` (the service
  it owns, RFL18) for the pure bytes/text conversion and the suggested project/file names. The
  home page's "Import a screenplay…" action and the editor's `⋮` export / import-and-replace menu
  both go through it; the screenplay text itself is always written through
  `OcptScreenplayService.saveScreenplayText`, never by hand.
- Editor: super_editor styled mode keeps **one `ParagraphNode` per non-blank Fountain source
  line**; a blank source line carries no node of its own, folded into the following node's
  `ocptBlankLinesBefore` metadata instead. Other node metadata: `blockType` (the line's
  `FountainLineType` as a `NamedAttribution`, stylesheet-only styling), `ocptTypeLocked` (a
  manual type override — dropdown or Tab — sticky until the block's text is emptied),
  `ocptHadForcingMarker` (the source line used an explicit forcing marker, re-emitted on encode
  even when auto-detection alone would already suffice). `OcptWysiwygCodec`
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
3. `dart run build_runner build --delete-conflicting-outputs`
4. `flutter analyze` → 0 issues
5. `flutter test` → all green
6. `flutter build linux --debug`
7. `reuse lint` → compliant
8. `git grep -l 'allcircuits.com' -- ':!actlibs'` → empty

## Known pitfalls

- **super_editor is pinned to `0.3.0-dev.50` exactly** — dev.51+ does not compile with
  Flutter 3.41.9. `super_text_layout` is pinned alongside it for `BlinkController` in tests.
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
