<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0011 - macOS distribution outside the App Store

## Status

Accepted

## Context

The macOS target has to become a downloadable, installable build, produced by the same workflow
that already ships the Linux `.deb` and the Windows installer. Three constraints shape how.

**The App Sandbox and this application's data model are incompatible as designed.** A project is a
plain file the user puts wherever they want, and the home page reopens it by absolute path from the
recent-projects list: `OcptProjectsManager.openProject` goes straight to `File(filePath)` and hands
it to `OcptProjectDatabase`. A sandboxed app loses access to a picked path as soon as the process
ends; regaining it means security-scoped bookmarks — a bookmark blob persisted per recent project
and resolved before every open, i.e. new persisted state and new failure modes in a manager every
platform shares. On top of that, `getApplicationDocumentsDirectory()` — the default projects home,
`OcptProjectsManager` line 117 — would resolve inside
`~/Library/Containers/com.borlnov.openCineProdTools/Data/Documents`, so a project created with the
default path would not be in the user's real `Documents` folder. And SQLite creates `-wal` and
`-shm` siblings next to the project file through the native library, not through the sandbox's file
dialogs.

**There is no Apple Developer account behind this project today.** Signing with a Developer ID and
notarizing both require a paid membership and secrets the repository does not have.

**Nothing macOS-specific can be built or verified in this repository's environment.** The
devcontainer is Debian; the only Mac that touches this code is the GitHub-hosted runner. Whatever is
chosen has to work with what that runner already carries.

## Decision

The application is distributed **outside the Mac App Store**, as a `.dmg` attached to the GitHub
Release, and therefore:

- **The App Sandbox is off.** `com.apple.security.app-sandbox` is dropped from both
  `macos/Runner/Release.entitlements` (which is now empty) and
  `macos/Runner/DebugProfile.entitlements`. The debug file keeps
  `com.apple.security.cs.allow-jit`, which the Dart VM needs under the hardened runtime, and
  `com.apple.security.network.server`, which the Flutter tool needs to talk to the running debug
  app. The release file grants nothing at all. The entitlement plists carry no comment idiom worth
  abusing, so this paragraph is the explanation for their contents.
- **The `.app` is ad-hoc signed** — `CODE_SIGN_IDENTITY = "-"`, already the scaffold's value. The
  binary runs; Gatekeeper quarantines it as a downloaded app, and the README documents the two ways
  through that (right-click → **Open**, or `xattr -dr com.apple.quarantine`), beside the
  SmartScreen note the Windows installer already has.
- **Real signing and notarization are written and dormant.** `build.yml` carries a `codesign` step
  before the DMG and an `xcrun notarytool submit --wait` plus `xcrun stapler staple` step after it,
  both guarded by `if: env.APPLE_CERTIFICATE != ''` (a secret cannot be read in an `if:` directly,
  so it is mapped to an env var first). The day the Apple secrets exist, they start running with no
  further change. They live in the workflow rather than in the packaging action, so the action stays
  a packager. Ad-hoc signing and the hardened runtime are exclusive in practice: `--options runtime`
  belongs to the dormant signing step and must not appear on the unsigned path.
- **The DMG is built with `hdiutil`**, by `.github/actions/macos-dmg/`, a composite action modelled
  on `windows-installer/` and `flutter-debian/`. It stages the `.app` and an `/Applications` symlink
  in a temporary directory and calls `hdiutil create -format UDZO`.

## Consequences

The app works the way it is written on macOS: projects live where the user put them, the default
projects home is the real `~/Documents`, and drift opens a project file with its `-wal`/`-shm`
siblings like it does everywhere else. No bookmark plumbing enters `OcptProjectsManager`.

In exchange, the App Store door is closed until someone reopens it deliberately. Reopening it costs,
at minimum: a security-scoped bookmark persisted per recent project and resolved before every open,
a projects home that is container-relative rather than `~/Documents`, a re-audit of every direct
`File` access, plus the account, the review and the sandbox entitlements themselves. That is its own
step, not a flag to flip.

The download experience is worse than a notarized app's: the first launch needs a deliberate user
gesture, and a user who does not read the README will conclude the app is broken. This lasts exactly
as long as the Apple secrets are missing.

The DMG is a plain compressed image with a symlink, not a designed installer window (no background
picture, no icon placement). `hdiutil` alone cannot do more without an AppleScript pass over the
mounted volume; that is a cosmetic follow-up, not a blocker.

Finally, none of this is verifiable in the devcontainer. The CI run is the compiler for this part of
the repository, and the first person to run the built app should walk the paths the sandbox would
have broken — create a project in the default location, close and reopen it from the recent list,
export a PDF through the native save dialog, and confirm the settings survive a restart.

## Alternatives considered

- **Ship for the Mac App Store, sandbox on**: the best distribution story on macOS, and it prices
  itself out here — the bookmark and container work above, a paid account, and a review cycle, all
  before the first download.
- **Keep the sandbox on but distribute outside the store**: all of the cost, none of the benefit —
  the sandbox buys nothing for a directly downloaded app, and would break project reopening just the
  same.
- **`create-dmg` or another third-party packager**: prettier output, at the price of a
  `brew install` on every CI run and a tool the repository's toolchain does not otherwise know.
  `hdiutil` is on every Mac.
- **Ship a `.zip` of the `.app` instead of a DMG**: simpler still, but it drops the drag-to-
  `/Applications` gesture every Mac user expects, and a `.app` unzipped into `~/Downloads` is a
  common way to end up running the app from the wrong place.
- **Wait for an Apple Developer account before shipping anything**: leaves macOS with no build at
  all for an unbounded time, when an ad-hoc signed DMG plus a documented Gatekeeper bypass is
  already usable.
