<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# macOS build — an installable app, built by the CI

This document is the implementation strategy for shipping a macOS build of the application.
**Read the repository `CLAUDE.md` first** — this plan assumes its architecture, ways of working,
coding standards, licensing rules and verification gates, and does not repeat them.

---

## 1. Goal and non-goals

**Goal.** A `.dmg` a person can download from a GitHub Release, mount, and drag into
`/Applications`, built by `build.yml` on the same triggers as the Windows installer, and attached
to a `v*` release next to the `.deb` and the `.exe`.

**Non-goals**, explicitly out of scope for this step:

- The Mac App Store, and therefore the App Sandbox (see §3.1 — the current data model is
  incompatible with it, and making it compatible is its own step).
- Notarization *today*: the signing step is written and wired, but stays inactive until the Apple
  secrets exist (§3.2).
- Associating the `.ocpt` extension with the app (`CFBundleDocumentTypes`, "Open with"). Worth
  doing on every desktop platform at once, not here.
- iOS and Android, which stay scaffolded.

## 2. What exists today

Verified in the repository, so no step below rediscovers it:

- `macos/` is the untouched `flutter create` scaffold: `Runner.xcodeproj`, `AppDelegate.swift`,
  `MainFlutterWindow.swift`, `Info.plist`, the four `Configs/*.xcconfig`, both entitlements files,
  and `RunnerTests/`.
- `PRODUCT_NAME = open_cine_prod_tools`, `PRODUCT_BUNDLE_IDENTIFIER =
  com.borlnov.openCineProdTools`, `MACOSX_DEPLOYMENT_TARGET = 10.15`, `CODE_SIGN_IDENTITY = "-"`
  (ad-hoc) already set.
- `Runner/Assets.xcassets/AppIcon.appiconset/` already holds the seven PNG sizes, generated and
  committed by `icons_launcher` (its pubspec block has `macos: enable: true`), so **the icon needs
  no work**.
- **There is no `macos/Podfile`** — the scaffold predates any macOS build, and Flutter only writes
  one on the first build that needs pods.
- Every plugin the app resolves has a macOS implementation: `sqlite3_flutter_libs`,
  `path_provider_foundation`, `shared_preferences_foundation`, `file_selector_macos`,
  `url_launcher_macos`, `package_info_plus`, `device_info_plus`, `connectivity_plus`, `file_saver`,
  `flutter_secure_storage_macos`. Nothing has to be replaced or shimmed.
- `Info.plist` is the stock one, every value coming from a build setting — nothing hardcoded.
- `MainMenu.xib` carries six literal `APP_NAME` occurrences (Flutter's template).
- CI: `get-version` (git describe) feeds `build-linux` (always) and `build-windows` (gated to
  `main`, `v*` tags and `workflow_dispatch`); `create-release` runs on `v*` only. The reusable
  composite actions are `flutter-setup`, `flutter-build`, `flutter-debian`, `windows-installer`.

## 3. Decisions

Recorded in a new ADR, `docs/adr/0011-macos-distribution-outside-the-app-store.md`, written as
part of the first commit below. The plan states them; the ADR argues them.

### 3.1 The App Sandbox is turned off

`Release.entitlements` and `DebugProfile.entitlements` currently declare
`com.apple.security.app-sandbox = true`, which the app cannot work under as designed:

- A project is a file the user puts wherever they want, and the home page reopens it **by absolute
  path** from the recent-projects list (`OcptProjectsManager.openProject` → `File(filePath)` →
  `OcptProjectDatabase`). A sandboxed app loses access to a picked path the moment the process
  ends; getting it back requires security-scoped bookmarks, i.e. persisting a bookmark blob per
  recent project and resolving it before every open — new persisted state, new failure modes, in
  a manager shared by every platform.
- `getApplicationDocumentsDirectory()` — the default projects home — would resolve inside
  `~/Library/Containers/com.borlnov.openCineProdTools/Data/Documents`, so projects created with the
  default path would be invisible in the user's real `Documents` folder.
- SQLite needs to create `-wal` and `-shm` siblings next to the project file, and drift opens it
  through the native library rather than through the sandbox's file dialogs.

Distributing outside the App Store makes the sandbox optional, so both entitlements files drop it.
`com.apple.security.cs.allow-jit` stays in the debug one (the Dart VM needs it under the hardened
runtime); the release one keeps nothing.

### 3.2 Ad-hoc signature now, notarization wired but dormant

The `.app` is ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`, already the scaffold's value): no Apple
account, no secret, and the binary runs. Gatekeeper still quarantines a downloaded app, so the
README documents the two ways through it (right-click → **Open**, or
`xattr -dr com.apple.quarantine`) — exactly as it already documents the Windows SmartScreen
warning.

`build.yml` gets two steps that do the real thing when the secrets exist and are skipped when they
do not, keyed on `if: env.APPLE_CERTIFICATE != ''` (a secret cannot be read in an `if:` directly,
so it is mapped to an env var first):

1. before the DMG: import `APPLE_CERTIFICATE` / `APPLE_CERTIFICATE_PASSWORD` into a temporary
   keychain, `codesign --deep --force --options runtime --sign "$APPLE_SIGNING_IDENTITY"` the
   `.app`;
2. after the DMG: `xcrun notarytool submit --wait` with `APPLE_ID` / `APPLE_APP_PASSWORD` /
   `APPLE_TEAM_ID`, then `xcrun stapler staple` the DMG.

Both live in the workflow, not in the packaging action, so the action stays a packager.

### 3.3 The macOS app is named "Open Cine Prod Tools"

`PRODUCT_NAME` becomes `Open Cine Prod Tools`: macOS shows it in the menu bar, in the Finder and in
the About window, and `open_cine_prod_tools` there would be read as a bug. The bundle becomes
`Open Cine Prod Tools.app` — the CI scripts quote the path.

### 3.4 The DMG is built with `hdiutil`, by a composite action

`.github/actions/macos-dmg/` mirrors `windows-installer/` and `flutter-debian/`: a composite action
taking the build directory and the version, returning the file it produced. It stages the `.app`
plus an `/Applications` symlink in a temporary directory and calls
`hdiutil create -format UDZO`. No third-party packager is installed on the runner, and nothing is
added to the repository's toolchain.

### 3.5 The job is gated like the Windows one

`build-macos` runs on `main`, on `v*` tags and on `workflow_dispatch`, not on every pull request —
same condition as `build-windows`, same reason.

## 4. The work, commit by commit

One commit per entry, in this order.

### C1 — the macOS bundle identity

- `macos/Runner/Configs/AppInfo.xcconfig`: `PRODUCT_NAME = Open Cine Prod Tools`, and
  `PRODUCT_COPYRIGHT` reworded to `Copyright © 2026 Benoit Rolandeau. All rights reserved.` (the
  scaffold's `com.borlnov` reads as a leftover identifier).
- `macos/Runner.xcodeproj/project.pbxproj`: the product name is hardcoded in four places that must
  follow — the `PBXFileReference` for `open_cine_prod_tools.app`, and `TEST_HOST` in the three
  `RunnerTests` build configurations. Nothing else in the project file mentions it (the embed
  script already uses `$PRODUCT_NAME`).
- Verify `Info.plist` needs no change: every key already reads a build setting.

### C2 — entitlements and the ADR

- Drop `com.apple.security.app-sandbox` from `macos/Runner/Release.entitlements` and
  `macos/Runner/DebugProfile.entitlements`, keeping `allow-jit` and `network.server` in the debug
  one, with a comment in the ADR (not in the plist, which has no comment idiom worth abusing).
- Write `docs/adr/0011-macos-distribution-outside-the-app-store.md`: sandbox off, ad-hoc now /
  notarization later, DMG over a third-party packager, and what the Mac App Store would cost
  (bookmarks per recent project, a container-relative projects home) so the door is documented
  rather than closed.

### C3 — the Podfile

Flutter writes `macos/Podfile` itself on the first build, but it is a project file that belongs in
the repository: without it, every macOS checkout shows an untracked file after its first build, and
the CI silently depends on the SDK's template. Copy it **verbatim** from the pinned SDK
(`$FLUTTER_ROOT/packages/flutter_tools/templates/app_shared/macos.tmpl/Podfile`, Flutter 3.44.6,
available in the devcontainer) and add the SPDX header as a Ruby comment.

`macos/Podfile.lock` cannot be produced without a Mac (`pod install` is macOS-only): it stays
untracked for now, and `.github/ci-doc.md` says so. It is not gitignored — the first person to
build on a Mac commits it.

### C4 — the `macos-dmg` composite action

`.github/actions/macos-dmg/action.yml`, modelled on `windows-installer/action.yml` down to the
input/output naming:

- inputs: `version`, `app-name` (the `.app` base name, `Open Cine Prod Tools`),
  `app-build-directory` (`build/macos/Build/Products/Release`), `output-name`
  (`OpenCineProdTools`), `volume-name` (defaulting to `app-name`);
- outputs: `dmg-path`, `dmg-file` (`<output-name>_<version>_macos.dmg`);
- body: `mkdir` a staging directory, `ditto` the `.app` into it (never `cp`, which mangles bundle
  metadata), `ln -s /Applications` beside it, then
  `hdiutil create -volname … -srcfolder … -ov -format UDZO`, and fail loudly if the expected output
  is missing — the same tail the Windows action already has.

### C5 — the `build-macos` job

In `.github/workflows/build.yml`, after `build-windows`:

- `runs-on: macos-latest`, `timeout-minutes: 45`, `needs: get-version`, the `if:` of §3.5.
- Checkout with `submodules: recursive`, `./.github/actions/flutter-setup`, then the same
  `flutter pub get` / `intl_utils:generate` / `build_runner build` step the other jobs run.
- `./.github/actions/flutter-build` with `target-platform: macos` and `build-args:
  --build-name=… --build-number=…`. **The version needs mangling**, like the `.deb`'s already does:
  `CFBundleShortVersionString` must be dotted numbers, and `git describe` yields
  `0.1.0-1-g87a9b8d`. Pass the numeric prefix as `--build-name` and the commit distance as
  `--build-number`, and keep the full descriptive version for the DMG's file name. The
  `flutter-build` action itself only needs its `target-platform` description updated to mention
  macOS.
- The dormant signing step (§3.2), then `./.github/actions/macos-dmg`, then the dormant
  notarization step.
- A structural verification step, in this job rather than a second macOS runner (they are the
  scarcest and the checks need no fresh machine): `lipo -archs` on the executable,
  `codesign -dv --verbose=2` on the `.app`, `plutil -lint` on the built `Info.plist`,
  `hdiutil attach -readonly -nobrowse` the DMG and check `Open Cine Prod Tools.app` and the
  `Applications` symlink are on the mounted volume, then detach.
- Upload the artifact as `OpenCineProdTools_<version>_macos_dmg`, with the shared retention.
- `create-release`: add `build-macos` to `needs`, and a fourth `download-artifact` step into
  `release-assets/` so the DMG lands in the release and in `SHA256SUMS.txt`.

Universal binary: `ONLY_ACTIVE_ARCH = YES` sits in the Debug configuration only, so the Release
build should produce `arm64 x86_64` and run on Intel Macs. The `lipo -archs` check is what proves
it. If it reports `arm64` alone, add `ARCHS = "$(ARCHS_STANDARD)"` / `ONLY_ACTIVE_ARCH = NO` to the
Release configuration and re-verify; if it still cannot be universal, ship arm64-only and say so in
the README's platform table rather than pretend otherwise.

### C6 — documentation

- `README.md`: the platform table's macOS row becomes `✅ Build available (unsigned)`; the
  Installation section gains a macOS paragraph — mount the DMG, drag to Applications, and the
  Gatekeeper bypass of §3.2 — beside the existing SmartScreen note.
- `.github/ci-doc.md`: `build-macos` in the workflow list, `macos-dmg/` in the structure tree, a
  "Building the DMG locally" section (requires a Mac with Flutter 3.44.6: the generation chain,
  `flutter build macos --release`, then the `hdiutil` invocation), the untracked `Podfile.lock`
  note of C3, and the release section mentioning the DMG among the published assets.
- `AGENTS.md`: a new row in the development plan table, and the macOS specifics folded into the
  existing prose (entitlements, the ad-hoc signature, the DMG action) — no new section.
- Delete this plan file, per the repository's convention.

## 5. Risks, and what to do about each

Nothing in this step can be built or run here: the devcontainer is Debian and there is no Mac. The
first `workflow_dispatch` run on the branch is the compiler, and it will take more than one round.
The known candidates for those rounds:

- **The pods' platform floor.** Some plugin may require more than macOS 10.15, which surfaces as a
  `pod install` error naming the pod and the version. Fix by raising `MACOSX_DEPLOYMENT_TARGET` in
  all three `Configs/*.xcconfig`-driven configurations *and* the Podfile's `platform :osx` line to
  the highest floor demanded, then noting it in the README's platform row.
- **`MainMenu.xib`'s six `APP_NAME` placeholders.** If the built app's menu bar reads
  `About APP_NAME`, replace them with the display name in the xib. It cannot be checked without
  running the app, so it is listed as an open item rather than silently assumed fine.
- **The sandbox removal is not verifiable here either.** Turning an entitlement off cannot break
  more than it allows, but the first person to run the app should walk the paths the sandbox would
  have broken: create a project in the default location, close and reopen it from the recent list,
  export a PDF through the native save dialog, and confirm the settings survive a restart.
- **Ad-hoc signing plus the hardened runtime.** They are exclusive in practice: the dormant signing
  step is what adds `--options runtime`, so the unsigned path must not.

## 6. Verification gates

The repository's gates (§ *Verification gates* of `CLAUDE.md`) all still run in the devcontainer and
all must pass — the Dart code is untouched, so they should be unaffected, and any drift they show is
a real regression. `reuse lint` covers the new files (the action's `action.yml`, the ADR, the
Podfile's Ruby header), and `markdownlint` the new documentation.

The macOS-specific gate is the CI itself: `build-macos` green on the branch through
`workflow_dispatch`, its structural checks included, with the artifact downloadable from the run.
