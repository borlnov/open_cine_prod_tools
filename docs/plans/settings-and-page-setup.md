<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Settings page & editor page setup

Implementation brief for the Sonnet 5 agents taking on this work. Read `CLAUDE.md` first (project
overview, architecture, coding standards, verification gates); this document only adds what is
specific to this batch. Everything here has been reviewed and validated with Benoit: implement it
as described, and ask before deviating.

## Goal

Expose the settings the app already has plumbing for but never surfaces (language, theme), add the
page setup (page size + margins) and an about section. Benoit validated a split across **two
surfaces**, by nature of the setting:

- **App settings** — a full page on the existing `/settings` route, reached from a new gear icon in
  the home header: language, theme, about. These are settings of the *application*.
- **Editor page setup** — a modal dialog opened from the editor's existing `⋮` menu: page size and
  page margins, applied live to the preview and to the styled page mode. These are settings of the
  *editor / the document being written*.

| Milestone | Summary | Status |
| --- | --- | --- |
| M1 | `fountain_kit`: configurable page margins (`FountainPageMargins`) | ⬜ |
| M2 | App plumbing: `OcptPageSetup`, margins property, page-format write path, licenses manager, `url_launcher` | ⬜ |
| M3 | App settings page (theme, language, about) + home gear + licenses route | ⬜ |
| M4 | Editor page-setup dialog + live re-layout | ⬜ |
| M5 | Wrap-up: verification gates, `CLAUDE.md` update | ⬜ |

Each milestone = one Sonnet 5 agent run = one commit, reviewed by the orchestrating session, with a
checkpoint by Benoit after each one (M3 and M4 are visual; GUI E2E automation is not feasible in the
devcontainer, so those two need a manual look). Do not start a milestone before the previous one is
committed and checked.

## Validated decisions (do not re-litigate)

- **Page size is a property of the open project.** The `project_info.pageFormat` column already
  exists and is written once at creation; the dialog must **update it for the open project**. No
  drift migration — the column is there, only a write path is missing.
- **Page margins are an app-wide preference**, stored in `OcptPropertiesManager`. They are not
  per-project, on purpose: they are a rendering preference, and a per-project page setup screen may
  come later.
- **The version string comes from the ACT global manager** (`AbsGlobalManager.packageInfo`, which is
  populated with `PackageInfo.fromPlatform()` once every manager is ready). Do **not** add
  `package_info_plus` as a direct dependency, and do not read the platform channel from a bloc under
  test (see the pitfall in `CLAUDE.md`): inject the version into the settings bloc.
- **Third-party licenses go through `act_licenses_manager`** (`actlibs/act_licenses_manager`), which
  loads the license texts from the `LICENSES/` folders and registers them into Flutter's
  `LicenseRegistry`. The UI is Flutter's `LicensePage`, mounted on a **new `OcptRoute.licenses`
  route** — do not call `showLicensePage()`, it pushes through `Navigator` (RFL31).
- **The GitHub repository link opens with `url_launcher`** (new direct dependency; already present
  transitively at 6.3.2).

## What already exists — reuse it, do not reinvent it

- **The `settings` route is already declared and wired**: `OcptRoute.settings`
  (`lib/types/ocpt_route.dart`) and `_createSettingsPage` in `lib/managers/ocpt_routes_helper.dart`.
  The page (`lib/ui/pages/settings/settings_page.dart`) is a placeholder `Scaffold` with a centered
  `Text` — replace its body. **Nothing navigates to it yet**: that entry point is part of M3.
- **Theme switching** — `ActThemesManager` (`actlibs/act_themes_manager`) already exposes
  `setBrightness({required Brightness? newBrightness})` (`null` = follow the system) and
  `brightnessStream`. Its bloc mixins do the whole job: `MixinActThemesBloc<ActThemesManager, S>` +
  `MixinActThemesState<S>` subscribe to the streams and handle
  `AskToUpdateBrightnessEvent(newBrightness: …)`. The app has a single theme
  (`OcptAppTheme.standard`), so the settings page only needs a **brightness** selector
  (System / Light / Dark) — no theme picker.
- **Language switching** — `LocalesManager` (`actlibs/act_intl`) exposes
  `set wantedLocale(Locale?)` (`null` = follow the system; it validates against the supported
  locales, emits and persists). The write-side bloc mixins are `MixinSetWantedLocaleBloc<S>` +
  `MixinSetWantedLocaleState<S>` (`actlibs/act_intl_ui`), driven by
  `NewLocaleWantedByUserEvent(wantedLocale: …)`. They have **zero usage in `lib/` today** — this is
  their first use. Supported locales: `Tr.delegate.supportedLocales` (`en_GB`, `fr`).
- **How to compose those mixins** — `lib/ui/main_app/main_app_bloc.dart` and
  `lib/ui/main_app/main_app_state.dart` already do it with the *read-only* variants
  (`MixinGetWantedLocaleBloc` + `MixinActThemesBloc`), including how `copyWith`,
  `copyGetWantedLocaleState` and `copyActThemesState` fit together. Mirror that file pair exactly;
  the settings bloc simply swaps `MixinGetWantedLocaleBloc` for `MixinSetWantedLocaleBloc`.
  `MainAppUi` already applies the result (`MaterialApp.router(locale: …, themeMode: …)`), so both
  settings apply **live**, app-wide, with no extra work.
- **Page/element metrics** — `FountainLayoutMetrics`
  (`packages/fountain_kit/lib/src/layout/fountain_layout_metrics.dart`): page size, margins,
  per-element boxes (inches + Courier columns), `usLetter()` / `a4()` presets, `linesPerPage`,
  `printableWidthInches` / `printableHeightInches`. It already has a **public const constructor
  taking every measurement explicitly**; only the presets bake the margins in.
- **Dialog pattern** — `lib/ui/pages/editor/widgets/ocpt_editor_import_confirm_dialog.dart` (and
  `lib/ui/pages/home/widgets/ocpt_new_project_name_dialog.dart` for the `Form` + validator variant):
  a `static Future<T?> show(BuildContext)` that calls `showDialog`, and a close that goes
  **only** through `globalGetIt().get<OcptRouterManager>().pop<T>(result)` — never `Navigator`.
  The caller (`editor_page.dart:231`) captures the bloc *before* the `await` and re-checks
  `context.mounted` after it.
- **Properties** — `OcptPropertiesManager` (`lib/managers/ocpt_properties_manager.dart`):
  `SharedPreferencesItem<T>` / `SharedPrefsItemWithParser<T, String>` items, all future-based
  (`await item.load()` → nullable, `await item.store(value)`), with the default applied **at the call
  site** (see `isPageSimulationEnabled` in the editor bloc). `editorMode` is the closest template for
  a parsed item.
- **The editor `⋮` menu** — `PopupMenuButton<void>` at the end of
  `lib/ui/pages/editor/widgets/ocpt_editor_toolbar.dart` (export, import-and-replace, page-simulation
  toggle). `OcptEditorToolbar` holds no bloc reference: it takes `VoidCallback`s, and
  `editor_page.dart` (~lines 136-163) dispatches to the bloc.
- House rules reminders: never use `Navigator` directly; no `package:super_editor` import outside
  `lib/ui/pages/editor/super_editor/`; every user-visible string via `Tr.of(context)`, added to
  **both** ARB files; blocs never touch `Tr` (the widget resolves the string and passes it in the
  event when needed); doc comments on every declaration; tests use inline private doubles.

---

## M1 — `fountain_kit`: configurable page margins

Margins are hardcoded today: `_standardMarginLeftInches = 1.5` and `_standardMarginInches = 1`
(top/right/bottom), baked into the private `FountainLayoutMetrics._standard()` factory that both
presets go through.

**Add** a `FountainPageMargins` Equatable value class (its own file under
`packages/fountain_kit/lib/src/layout/`, exported from the package barrel like the other layout
types): `leftInches`, `rightInches`, `topInches`, `bottomInches`, a `const
FountainPageMargins.standard()` named constructor carrying today's values (left 1.5", the rest 1"),
and a `copyWith`.

**Change** `FountainLayoutMetrics.usLetter()` / `.a4()` to take an optional
`FountainPageMargins margins = const FountainPageMargins.standard()` and pass it down to
`_standard()`, which already derives `printableWidth`, `printableHeight`, `linesPerPage`,
`rightEdge` and the margin-anchored boxes from those values.

**Do not move the element indents**: character cues (3.7"), parentheticals (3.1") and dialogue
(2.5", 3.5" wide) are measured from the *page's left edge* and stay standard regardless of the
margins. Only the margin-derived boxes move (scene heading, action, transition, centered text — plus
`linesPerPage` and the printable area).

Guard the degenerate case: `assert` (or `ArgumentError`) that the margins leave a strictly positive
printable width and height. The UI validates before calling, so the assert is a safety net, not a
UX path.

Keep the package **Flutter-free** and keep the round-trip guarantee intact.

**Tests** (`packages/fountain_kit/test/`): standard margins reproduce today's values byte for byte
(regression); non-standard margins shift `printableWidthInches`, `linesPerPage` and the action /
scene-heading / transition boxes as expected, while character / parenthetical / dialogue indents
stay put.

**Commit**: `feat(fountain_kit): make page margins configurable`

---

## M2 — App plumbing

Everything the two UI surfaces need, with no UI yet.

1. **`OcptPageSetup` model** (`lib/models/ocpt_page_setup.dart`): an Equatable pairing
   `OcptPageFormat format` + `FountainPageMargins margins`, a `const OcptPageSetup.standard()`
   (US Letter + standard margins), a `copyWith`, and a **`FountainLayoutMetrics toMetrics()`**
   method holding the single `switch (format)` of the app. It replaces the three duplicated
   `switch (pageFormat) { usLetter => FountainLayoutMetrics.usLetter(), a4 => … }` blocks in
   `lib/ui/pages/editor/widgets/ocpt_editor_preview.dart:232`,
   `lib/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart:261` and `:475` (those call
   sites are switched over in M4).
2. **Margins property** — in `OcptPropertiesManager`, add
   `pageMargins`, a `SharedPrefsItemWithParser<FountainPageMargins, String>` serialised as JSON
   (mirror `recentProjects`' parser/castTo pair). `null` = standard margins, applied at the call
   site.
3. **Page-format write path** — in `OcptProjectsManager`
   (`lib/managers/projects/ocpt_projects_manager.dart`), add
   `Future<void> saveCurrentProjectPageFormat(OcptPageFormat format)` right next to the existing
   `loadCurrentProjectPageFormat()` (~line 259): same `currentProject == null` guard, then drift's
   update API:
   ```dart
   await project.database
       .update(project.database.ocptProjectInfoTable)
       .write(OcptProjectInfoTableCompanion(pageFormat: Value(format)));
   ```
   This is the **first write to `project_info` after creation**. Keep DB access in the manager layer
   (the class doc says so explicitly).
4. **Licenses manager**:
   - `OcptConfigManager` (`lib/managers/ocpt_config_manager.dart`) gains `with MixinLicensesConfig`
     (from `act_licenses_manager`).
   - `OcptGlobalManager.registerManagers()` registers
     `registerManagerAsync<ActLicensesManager>(ActLicensesBuilder<OcptConfigManager>())` — it
     depends on `LoggerManager` + the config manager, so register it after them.
   - `assets/config/default.yaml` gains a `licenses:` block. Read
     `actlibs/act_licenses_manager/README.md` for the exact schema; the shape is:
     ```yaml
     licenses:
       extraElements:
         Open Cine Prod Tools:
           - Apache-2.0
           - CC0-1.0
         ACT packages:
           - LicenseRef-ALLCircuits-ACT-1.1
           - CC0-1.0
           - MIT
           - LicenseRef-DartProjectAuthors
         Courier Prime:
           - OFL-1.1
       assetsFolders:
         - LICENSES
         - actlibs/LICENSES
     ```
     Cross-check the keys against the actual files in `LICENSES/` (Apache-2.0, CC0-1.0,
     LicenseRef-ALLCircuits-ACT-1.1, OFL-1.1) and `actlibs/LICENSES/` (CC0-1.0,
     LicenseRef-ALLCircuits-ACT-1.1, LicenseRef-DartProjectAuthors, MIT) — a key with no matching
     `<key>.txt` is skipped with a warning.
   - `pubspec.yaml`: declare `LICENSES/` and `actlibs/LICENSES/` as asset folders (the manager reads
     them through the asset bundle), add the `act_licenses_manager` path dependency next to the
     other ACT ones, and add `url_launcher`.
   - `reuse lint` must stay compliant after the pubspec/asset changes.

**Tests**: the `pageMargins` property round-trips through its parser (including the `null` default);
`saveCurrentProjectPageFormat` writes and `loadCurrentProjectPageFormat` reads it back on an
in-memory project database, and the no-open-project case is a no-op. Follow the existing projects-
manager test setup.

**Commit**: `feat: add page setup storage and licenses manager`

---

## M3 — App settings page

**Layout validated by Benoit** — full page, `AppBar` with a back arrow (pop through the router
manager) and the page title, body centered with a max width of ~720 px, content = stacked section
cards:

```text
┌─ ←  Settings ──────────────────┐
│    ┌──────────────────────────┐│
│    │ Appearance               ││
│    │   Theme    [System ▾]    ││
│    ├──────────────────────────┤│
│    │ Language                 ││
│    │   Language [System ▾]    ││
│    ├──────────────────────────┤│
│    │ About                    ││
│    │   Open Cine Prod Tools   ││
│    │   Version 0.1.0          ││
│    │   Apache-2.0             ││
│    │   → GitHub repository    ││
│    │   → Third-party licenses ││
│    └──────────────────────────┘│
└────────────────────────────────┘
```

Keep the validated "creative studio" style (theme colours, no new accent). Ask Benoit before
deviating from this layout.

**Files** (`lib/ui/pages/settings/`, mirroring the home page's UI/bloc/state/event split, with the
public `SettingsPage` only wiring the `BlocProvider` and a private `_SettingsView` holding the UI):

- `settings_bloc.dart` — `OcptSettingsBloc extends BlocForMixin<OcptSettingsState>` with
  `MixinSetWantedLocaleBloc<OcptSettingsState>` and
  `MixinActThemesBloc<ActThemesManager, OcptSettingsState>`. Both mixins bring their own events and
  keep the state in sync with the managers' streams, so the bloc's own code is nearly empty: it just
  carries the injected app version. Constructor:
  `OcptSettingsBloc({String? appVersion}) : _appVersion = appVersion ?? OcptGlobalManager.instance.packageInfo.version`
  — the parameter exists so tests never hit the platform channel.
- `settings_state.dart` — mixes `MixinSetWantedLocaleState` + `MixinActThemesState`; mirror
  `lib/ui/main_app/main_app_state.dart` (same `copyWith` / `copyGetWantedLocaleState` /
  `copyActThemesState` triple, plus the version field).
- `settings_event.dart` — only if the page needs an event of its own (opening the repository URL can
  live in the widget). The theme/language events come from the ACT mixins.
- `settings_page.dart` — replaces the placeholder.
- `widgets/` — one small widget per section (`ocpt_settings_appearance_section.dart`,
  `…_language_section.dart`, `…_about_section.dart`), each a `StatelessWidget` taking its values and
  callbacks as constructor params, like `OcptHomeHeader` and `OcptEditorToolbar` do.

**Behaviour**:

- Theme dropdown: System / Light / Dark → `AskToUpdateBrightnessEvent(newBrightness: null |
  Brightness.light | Brightness.dark)`. The current value comes from `state.brightness`.
- Language dropdown: System / English / Français → `NewLocaleWantedByUserEvent(wantedLocale: null |
  const Locale("en", "GB") | const Locale("fr"))`. Current value: `state.wantedLocale`. Build the
  entries from `Tr.delegate.supportedLocales` rather than hardcoding a list, and label each locale in
  **its own language** (English, Français), which is the usual convention for a language picker.
- Both apply live: `MainAppUi` is already listening.
- About: app name (`Tr` string, not the package name), version from the state, `Apache-2.0`, a
  GitHub row opening `https://github.com/borlnov/open_cine_prod_tools` with
  `launchUrl(uri, mode: LaunchMode.externalApplication)`, and a "Third-party licenses" row doing
  `globalGetIt().get<OcptRouterManager>().push(OcptRoute.licenses)`.

**New licenses route**: add `licenses` to `OcptRoute` (`lib/types/ocpt_route.dart`) and a
`_createLicensesPage` builder in `lib/managers/ocpt_routes_helper.dart` returning
`RoutePageDetails(widget: LicensePage(applicationName: …, applicationVersion: …, applicationLegalese: …))`.
The path is derived from the enum name automatically. `ActLicensesManager` has already fed
`LicenseRegistry` by then, so the page lists the ACT packages, the app and Courier Prime alongside
the pub dependencies.

**Entry point**: a gear `IconButton` in `lib/ui/pages/home/widgets/ocpt_home_header.dart` (new
`onOpenSettings` callback, placed left of the "Import a screenplay…" button), wired in
`home_page.dart` like the other actions and pushing `OcptRoute.settings` through the router manager.

**Strings**: add every new label to `lib/l10n/intl_en_GB.arb` (with its `@key` description) and
`lib/l10n/intl_fr.arb`, then `dart run intl_utils:generate`. `settingsPageTitle` already exists.

**Tests**: a bloc test with injected fake managers covering the brightness and locale events; a
widget test pumping `_SettingsView` (not the whole app) and checking the three sections render and
dispatch. Do **not** write a full-app-boot widget test.

**Commit**: `feat(settings): add app settings page`

---

## M4 — Editor page-setup dialog

**Dialog** — `lib/ui/pages/editor/widgets/ocpt_editor_page_setup_dialog.dart`, a `StatefulWidget`
following `ocpt_new_project_name_dialog.dart` (it needs a `Form` + validators):

```text
┌ Page setup ──────────────────────┐
│  Page size   [ A4            ▾ ] │
│                                  │
│  Margins (inches)                │
│   Left  [1.5]      Right  [1.0]  │
│   Top   [1.0]      Bottom [1.0]  │
│                                  │
│              [Reset to standard] │
│             [Cancel]     [Apply] │
└──────────────────────────────────┘
```

- `static Future<OcptPageSetup?> show(BuildContext context, {required OcptPageSetup current})` →
  `showDialog<OcptPageSetup>`; returns `null` on cancel.
- Four **always-visible** numeric fields (left / right / top / bottom, in inches), pre-filled from
  the current setup. Validators reject a non-number, a negative value, and any combination leaving a
  non-positive printable width or height for the selected page size (that check must use the
  selected size, so it re-runs when the dropdown changes).
- "Reset to standard margins" refills the four fields with `FountainPageMargins.standard()`.
- Close **only** via `globalGetIt().get<OcptRouterManager>().pop<OcptPageSetup>(setup)` / bare
  `pop()` on cancel.

**Toolbar** — `ocpt_editor_toolbar.dart`: add an `onPageSetup` `VoidCallback` field and a
`PopupMenuItem` in the existing `⋮` `PopupMenuButton`, after the page-simulation toggle.

**Page** — `editor_page.dart`: a private `Future<void> _requestPageSetup(BuildContext context)` on
the page State, mirroring `_requestImportAndReplace` (read the bloc **before** the `await`, check
`context.mounted` after), dispatching `OcptEditorPageSetupChangedEvent(pageSetup: setup)`.

**State / bloc**:

- `editor_state.dart`: replace `final OcptPageFormat pageFormat` with
  `final OcptPageSetup pageSetup` (init = `OcptPageSetup.standard()`), and update `copyWith` / `props`.
- `editor_bloc.dart`: in `_onLoadRequested` (~line 150), build the setup from
  `loadCurrentProjectPageFormat()` (default `OcptPageFormat.usLetter`) and
  `propertiesManager.pageMargins.load()` (default `FountainPageMargins.standard()`).
- New handler for `OcptEditorPageSetupChangedEvent`: persist the format through
  `projectsManager.saveCurrentProjectPageFormat(...)` **and** the margins through
  `propertiesManager.pageMargins.store(...)`, then `emitter(state.copyWith(pageSetup: setup))`.
- The three metric call sites (`ocpt_editor_preview.dart:232`,
  `ocpt_styled_screenplay_editor.dart:261` and `:475`) take the `OcptPageSetup` instead of the
  `OcptPageFormat` and call `pageSetup.toMetrics()`. `OcptStyledScreenplayEditor` already rebuilds
  its stylesheet when the page format changes in `didUpdateWidget` (~line 189) — extend that
  comparison to the whole setup so a margin change re-lays out live too.

**Tests**: a dialog widget test (edit a margin → the returned setup carries it; invalid input →
validator blocks); an editor bloc test on the new event (both persistence calls happen and the state
re-emits). Set `BlinkController.indeterminateAnimationsEnabled = false` if a super_editor widget is
pumped.

**Commit**: `feat(editor): add a page setup dialog`

---

## M5 — Wrap-up

- Run every verification gate (below) from a clean state.
- `CLAUDE.md`: step 10 → ✅ in the status table; add to the architecture section the licenses manager
  registration, and the page-setup storage split (page size per project in `project_info`, margins
  app-wide in the properties manager, `OcptPageSetup.toMetrics()` as the single metrics entry point).

**Commit**: `docs: update the development guide`

---

## Verification gates

All inside the devcontainer (the host has no usable Flutter SDK):

```bash
cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
```

1. `flutter pub get`
2. `dart run intl_utils:generate`
3. `dart run build_runner build --delete-conflicting-outputs`
4. `flutter analyze` → 0 issue
5. `flutter test` → green, at the root **and** in `packages/fountain_kit`
6. `flutter build linux --debug` → also proves the `url_launcher_linux` native plugin builds
7. `reuse lint` → compliant
8. `git grep -l 'allcircuits.com' -- ':!actlibs'` → empty

Manual pass (`flutter run -d linux`, X11 is forwarded), for Benoit's checkpoints:

- Home gear → settings; theme and language switch **live** (the whole app follows, including the
  home page behind).
- About shows the real version, opens the GitHub repository in the system browser, and the licenses
  page lists the app, the ACT packages, Courier Prime and the pub dependencies.
- Editor `⋮` → page setup: changing the size and the margins re-lays out the preview and the styled
  page mode immediately; the size survives closing and reopening the project; the margins survive an
  app restart.

## Ways of working for this batch

- Benoit communicates in French; **all code, comments, commits and GitHub content are in English**.
- One commit per milestone, Conventional Commits, subject ≤ 50 characters, ending with the trailer:

  ```text
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  ```

- Never reference this plan, its milestones or the agent instructions in code or commit messages.
- `flutter analyze` + `flutter test` must pass **before every commit**.
- Ask Benoit before any UI deviation, and before adding any dependency beyond `url_launcher` and
  `act_licenses_manager`.
