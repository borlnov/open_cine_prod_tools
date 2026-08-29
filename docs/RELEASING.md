<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Releasing

This is how a build's version is decided and how a stable release is cut. The schema-freeze rule it
enforces is recorded in
[`docs/adr/0029`](adr/0029-schema-versions-frozen-at-stable-releases.md); read that for the *why*.

## The version is the git tag

The app's version is **derived from the git tag**, not from `pubspec.yaml`. CI's `get-version` job
runs `git describe --tags --match 'v[0-9]*'`:

- a build sitting exactly on a tag `vX.Y.Z` reports `X.Y.Z`;
- any other build reports `X.Y.Z-N-g<sha>`, which a semver reader treats as a **pre-release**.

That version is passed into the app at build time as `--dart-define=APP_VERSION=...`, so
`OcptProjectsManager._appVersion` reflects it. Under `flutter test` and a local `flutter build` with
no such define, the compile-time default is used instead — keep that default in sync with
`pubspec.yaml`'s `version`.

**Stability is read from the suffix, nothing else.** A version with no pre-release suffix (`0.2.0`,
`0.2.1`) is stable; one with any suffix (`0.2.0-alpha.1`, `0.2.0-3-gabc123`) is a pre-release. The
only build that is ever stable is the one built on a suffix-less `vX.Y.Z` tag. There is no "is
stable" flag to maintain anywhere.

## During a development cycle

You never touch anything here by hand. When a change needs the schema, the developer (or an agent)
reads the two constants and follows the ADR 0029 rule:

- `currentSchemaVersion == lastStableSchemaVersion` — the top migration file is a frozen stable
  release, so the change **creates** a new one and bumps `currentSchemaVersion`;
- `currentSchemaVersion == lastStableSchemaVersion + 1` — a cycle is already open, so the change
  **overwrites** the top migration file in place.

The same holds for `OcptProjectVersionCodec`'s `currentPayloadFormat` / `lastStablePayloadFormat`.
Because the pending step is rewritten rather than appended to, it stays a single clean step for the
whole cycle — there is nothing to squash at release time, only to freeze.

## Cutting a stable release

1. **Freeze the schema.** Set `lastStableSchemaVersion = currentSchemaVersion` in
   `lib/models/database/ocpt_project_database.dart`, and
   `lastStablePayloadFormat = currentPayloadFormat` in
   `lib/managers/projects/services/ocpt_project_version_codec.dart`. If the cycle changed the
   schema, add a verbatim DDL fixture for the schema this release freezes to
   `test/models/database/ocpt_project_database_migration_test.dart`, pinning that
   `onCreate` reproduces the result of migrating that fixture forward — this is what proves the
   frozen step is never silently altered later.
2. **Run the gates** (`flutter analyze`, `flutter test`, `flutter build linux --debug`,
   `reuse lint`, and `dart run tool/check_markdown.dart` if any `.md` changed).
3. **Merge** the freeze to `main` through a pull request, as any change.
4. **Tag** the merge commit `vX.Y.Z` (no suffix) and push the tag. CI derives the stable version,
   builds, and publishes the release.

You only ever run `git tag`. Preparing the freeze commit is ordinary reviewed work done before the
tag.

## The guard that makes forgetting safe

If you tag a stable `vX.Y.Z` without having frozen, the `verify-stable-schema-frozen` CI job fails:
it asserts `lastStableSchemaVersion == currentSchemaVersion` and the payload-format equivalent on a
suffix-less tag, and `create-release` depends on it, so **nothing is published**. The job's error
message points back here. Fix the freeze, merge, and re-tag. A forgotten freeze is therefore a
blocked release, never a corrupted one — and an *incorrect* freeze is caught by the migration test
before it ever reaches a tag.
