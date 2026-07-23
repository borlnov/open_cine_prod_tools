<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# CI: build and release for Linux and Windows

This plan is executed by Sonnet agents. It adds a GitHub Actions pipeline that compiles Open
Cine Prod Tools for its two priority platforms (Linux and Windows), packages the results
(Debian `.deb` and an Inno Setup installer), and publishes them to a GitHub Release on version
tags. It also hardens the existing workflows, which currently pin third-party actions to
mutable tags: a supply-chain risk for a public repository.

Read `CLAUDE.md` in full before writing anything. Follow every norm there: English everywhere
on GitHub, SPDX headers on every file, `reuse lint` stays compliant, Conventional Commits with
subject <= 50 chars, one commit per logical change, and the Sonnet 5 co-author trailer. Never
reference this plan, its milestones, or step numbers in code, workflow files, or commit
messages. All Flutter/Dart commands run inside the devcontainer.

## Reference implementation

The private `needleless` repository already has an equivalent pipeline. Read it and adapt it;
do not copy blindly, because OCPT is a single-app repo with no C++ runtime:
`~/projects/desvac-needleless-apps/needleless/.github/`

- `workflows/build.yml` - job graph, `concurrency`, `paths-ignore`, `timeout-minutes`,
  git-describe versioning, artifact upload, release job.
- `actions/flutter-setup/action.yml` - Flutter setup plus pub cache.
- `actions/flutter-build/action.yml` - build cache plus `flutter build <platform> --release`.
- `actions/flutter-debian/action.yml` and `debian-templates/`.
- `actions/windows-installer/action.yml` and `inno-setup/installer.iss.template`.

Every third-party action in `needleless` is pinned to a full commit SHA. Reuse those exact
SHAs so we do not have to rediscover them.

## Project facts to respect

- Single Flutter app at the repo root (not a monorepo). `pubspec.yaml`:
  `name: open_cine_prod_tools`, `version: 0.1.0`. Binary name `open_cine_prod_tools` on both
  Linux and Windows (`linux/CMakeLists.txt`, `windows/CMakeLists.txt`). Application id
  `com.borlnov.open_cine_prod_tools`.
- Flutter is pinned to **3.41.9** (`actlibs/tool/.flutter_version`). Use 3.41.9 in CI, not the
  3.41.4 that `needleless` uses.
- Public submodule `actlibs` (`.gitmodules`). Always check out with `submodules: recursive`.
  The gitlink pins an exact commit, so builds are reproducible.
- Pure-Dart package `packages/fountain_kit` is a `path:` dependency resolved by
  `flutter pub get` at the root. It needs no separate build.
- Mandatory generation chain before any build (see the CLAUDE.md verification gates):
  `flutter pub get` -> `dart run intl_utils:generate` ->
  `dart run build_runner build --delete-conflicting-outputs`. This generates `lib/generated/**`
  (l10n) and the drift `*.g.dart` companion code, both git-ignored.
- Runtime `.deb` dependencies stay minimal: `libgtk-3-0, libc6`. drift bundles sqlite through
  `sqlite3_flutter_libs`, so no libsqlite3 runtime dependency and no libsecret (unlike
  `needleless`).
- Native Linux build dependencies: `clang cmake ninja-build pkg-config libgtk-3-dev
  liblzma-dev`.
- Windows needs no vcpkg, protobuf, or ffigen (those are `needleless` C++ specifics). Only Inno
  Setup (`choco install innosetup`) plus `flutter build windows`.
- No application icon asset yet (`assets/` holds config and fonts). Build the installer and
  `.deb` without an icon for now; leave a TODO comment to wire one later.
- SPDX header on every new file (comment for YAML, HTML comment for markdown, `.license`
  sidecar for any uncommentable file). Add `REUSE.toml` annotations if a template file cannot
  carry a header. `reuse lint` must stay compliant.

## Milestone M1 - Composite actions and shared templates

Create these by adapting the `needleless` equivalents. Change every SPDX header to
`Benoit Rolandeau <borlnov.obsessio@gmail.com>` / `Apache-2.0`.

- `.github/actions/flutter-setup/action.yml`: uses `subosito/flutter-action` (SHA-pinned),
  channel `stable`, `flutter-version: 3.41.9`, `cache: true`. Add the pub-cache step keyed on
  `hashFiles('**/pubspec.lock')`.
- `.github/actions/flutter-build/action.yml`: build cache (disabled on tag refs so tagged
  artifacts come from a clean build) plus `flutter build ${target-platform} --release
  ${build-args}`. Inputs: `app-directory` (default `.`), `target-platform`, `build-args`.
- `.github/actions/flutter-debian/action.yml` plus `.github/debian-templates/`
  (`control.template`, `launcher.sh.template`, `postinst`, `postrm`). Keep the templating
  logic; only the SPDX headers change.
- `.github/actions/windows-installer/action.yml` plus
  `.github/inno-setup/installer.iss.template`. Set the default `app-publisher` to
  `Benoit Rolandeau`. Generate one fresh `AppId` GUID for OCPT (`uuidgen`) and hard-code it in
  the `build.yml` matrix/input (it must stay stable across releases so Windows recognises
  upgrades).

## Milestone M2 - Main workflow `.github/workflows/build.yml`

Single-app adaptation of the `needleless` `build.yml`:

- Triggers: `push` to `main` and tags `v*`; `pull_request` to `main`; `workflow_dispatch`. Add
  `paths-ignore: [docs/**, "*.md", LICENSES/**, REUSE.toml]`.
- `concurrency` group with `cancel-in-progress: true`.
- Top-level `permissions: contents: read`.
- `env.ARTIFACT_RETENTION_DAYS: 10`.
- Job `get-version`: checkout with `fetch-depth: 0` and `filter: tree:0`, then
  `git describe --tags --always --match 'v[0-9]*'` normalised to a `version` output (fallback
  `0.0.0-<sha>`). Reuse the `needleless` sed expression.
- Job `build-linux` (`ubuntu-latest`, `timeout-minutes: 30`, `needs: get-version`): checkout
  `submodules: recursive` -> `apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
  liblzma-dev` -> `flutter-setup` -> generation (`flutter pub get`,
  `dart run intl_utils:generate`, `dart run build_runner build --delete-conflicting-outputs`)
  -> `flutter-build` (linux) -> `flutter-debian` (`package-name: open-cine-prod-tools`,
  `executable-name: open_cine_prod_tools`, bundle `build/linux/x64/release/bundle`,
  `dependencies: "libgtk-3-0, libc6"`, maintainer set to Benoit) -> `upload-artifact`.
- Job `build-windows` (`windows-latest`, `timeout-minutes: 60`, `needs: get-version`) gated by
  `if: startsWith(github.ref, 'refs/tags/v') || github.ref == 'refs/heads/main' ||
  github.event_name == 'workflow_dispatch'`: checkout `submodules: recursive` -> install Inno
  Setup via choco (idempotent guard) -> `flutter-setup` -> generation (same three commands,
  `shell: bash`) -> `flutter-build` (windows) -> `windows-installer`
  (bundle `build/windows/x64/runner`, OCPT `app-id`) -> `upload-artifact`.
- Job `test-deb` (`needs: [get-version, build-linux]`): download the `.deb`,
  `sudo apt install ./...deb`, assert `test -x /usr/bin/open-cine-prod-tools` and the bundled
  executable, then `sudo apt-get remove`.
- Job `create-release` gated by `if: startsWith(github.ref, 'refs/tags/v')`, with
  `permissions: contents: write`, `needs: [get-version, build-linux, build-windows]`: download
  all artifacts, compute SHA256 checksums for each binary (write a `SHA256SUMS.txt`), then
  `softprops/action-gh-release` (SHA-pinned) with `generate_release_notes: true` and
  `files: release-assets/**`.
- Pin every action by full commit SHA: `actions/checkout`, `actions/cache`,
  `actions/upload-artifact`, `actions/download-artifact`, `subosito/flutter-action`,
  `softprops/action-gh-release`. Reuse the SHAs already present in `needleless`.

## Milestone M3 - Harden existing workflows and add Dependabot

- Rewrite `flutter_lint.yml`, `markdown_lint.yml`, and `reuse_compliance.yml`:
  - Pin `actions/checkout` and `subosito/flutter-action` by SHA (drop the mutable `@v2` / `@v1`
    / `@v4` / `@v5`).
  - Add `permissions: contents: read` (add `pull-requests: write` only on a job that keeps an
    analysis commenter).
  - Add a `concurrency` group and `timeout-minutes` to each job.
  - Keep the existing behaviour (submodule checkout, generation, analyze). Do not fold in the
    lint matrix, README rewrite, or ADRs: those stay a separate development-plan step.
- Create `.github/dependabot.yml`: `github-actions` ecosystem, weekly schedule, so the pinned
  SHAs get bumped through reviewable bot PRs. Add the SPDX header.

## Milestone M4 - CI documentation, REUSE, and CLAUDE.md step

- Create `.github/ci-doc.md` (OCPT counterpart of the `needleless` `ci-doc.md`): describe the
  jobs, how to build a `.deb` and an installer locally, and how to cut a release
  (`git tag vX.Y.Z && git push --tags`). SPDX header, ASCII-only typography, lines <= 100.
- Run `reuse lint` and fix any gap (SPDX headers on all new `.github/**` files; add `REUSE.toml`
  annotations only if a file genuinely cannot carry a header).
- Update the "Development plan & status" table in `CLAUDE.md`: the new CI build/release step is
  already inserted as step 11 (with the following steps renumbered). Flip its status to done
  once every milestone here is verified and committed.

## Security notes for a public repository

Applied in the workflow YAML by this plan:

- Every third-party action is pinned to a full 40-char commit SHA, never a mutable tag, so a
  repointed tag cannot inject code into our builds.
- `permissions` are least-privilege: `contents: read` at the top level, raised to
  `contents: write` only on `create-release`.
- Use `pull_request`, never `pull_request_target`. Fork PRs then run with a read-only token and
  no access to secrets, which is safe because the build needs no secrets.
- `concurrency` with `cancel-in-progress` and a `timeout-minutes` on every job limit runaway
  runs and runner abuse from fork PRs.
- No build or PR job references a secret. If code signing is added later, gate its certificate
  secret to `push`/tag events on the base repo, never to fork PRs.

To be applied manually by Benoit in the GitHub repository settings (outside this plan):

- Settings > Actions > General: set Workflow permissions to read-only by default, and uncheck
  "Allow GitHub Actions to create and approve pull requests".
- Settings > Actions > General: require maintainer approval before workflows run on pull
  requests from outside collaborators.
- Settings > Branches: protect `main`, require the build checks to pass before merge, and
  forbid force-pushes.
- Enable Dependabot security updates (the `dependabot.yml` here covers version updates).
- Optional for an OSS project: enable CodeQL and/or OpenSSF Scorecard.
- Releases attach SHA256 checksums; document that the binaries are unsigned, so Windows
  SmartScreen will warn on first run.

## Verification

Everything except the CI trigger runs inside the devcontainer:

- `reuse lint` -> compliant, including the new `.github/**` files.
- `flutter analyze` -> 0 issues; `flutter test` -> all green (existing gates unchanged).
- Local Linux build: `flutter build linux --release`, then confirm
  `build/linux/x64/release/bundle/open_cine_prod_tools` exists and is executable.
- No mutable action tags remain:
  `grep -rE '@v[0-9]' .github/workflows .github/actions` -> empty.
- On GitHub: `workflow_dispatch` of `build.yml` -> `build-linux` and `build-windows` both
  green, with the `.deb` and `_win64_setup.exe` artifacts uploaded.
- Release smoke test: push a throwaway `vX.Y.Z` tag -> `create-release` produces a Release with
  the `.deb`, the installer, and `SHA256SUMS.txt`. Delete the test tag and Release afterwards.
- Benoit has applied the manual repository settings above.
