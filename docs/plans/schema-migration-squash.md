<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Schema migrations frozen at stable releases (issue #60)

This document is the implementation strategy for issue #60: stop carrying a pre-release cycle's
schema-migration churn forever, and turn the migration history into one frozen step per stable
release. **Read the repository `CLAUDE.md` first**, and `docs/architecture/foundations.md`'s drift
and "opening a project file from another build" sections — this plan assumes them and does not
repeat them. The rule this plan implements is recorded in `docs/adr/0029`; once the work ships and
its outcome is folded into `docs/architecture/foundations.md`, this plan is deleted.

## The problem

The schema is at `currentSchemaVersion = 35` after four alpha tags, and most of those steps exist
only because a column was added, renamed and dropped again while a feature was being designed
(v12/v13's typed clocks and groups; v23/v24's never-merged columns). Every one of them is an
`onUpgrade` step carried forever, a `payloadFormat` the codec upgrades through (now at 31), and a
row in the migration test. No stable release has ever shipped, so the whole `v1 -> v35` chain is
workshop churn that never reached a user's disk.

## The model

Two dimensions describe a file, compared **before** drift touches it:

- **Stable schema version** = drift's `user_version`. It advances **only** at a stable release.
  Inside a dev cycle the pending schema is a single step that is *rewritten in place*, never a new
  numbered step per PR.
- **Writer identity** = the app version stamped on the file at each real write (create + migrate),
  read as a semver: pre-release iff it carries a `-alpha/-beta/-rc` (or any) suffix, its stable
  line is `major.minor.patch`. The running build's own version is tag-derived by CI
  (`git describe`), so a build off a stable tag `vX.Y.Z` is stable and any other build carries a
  `-N-g<sha>` suffix and is a pre-release, with no `pubspec` edit needed.

### The two constants that drive overwrite-vs-create

```text
currentSchemaVersion      the schema this build writes; fixed for a whole dev cycle
lastStableSchemaVersion   the highest schema a stable release froze; changed only at release prep
```

Their relation tells any session touching the schema what to do, and there are only two cases:

| State | Meaning | Action on a schema change |
| --- | --- | --- |
| `current == lastStable` | no cycle open; the top migration file is frozen | bump `current` to `lastStable + 1` and **create** `ocpt_migration_v<new>.dart` |
| `current == lastStable + 1` | a cycle is open; the top file is the pending one | **overwrite** `ocpt_migration_v<current>.dart`; do not bump |

`current` is always `lastStable` or `lastStable + 1` — never `+2`, since a cycle rewrites in place.
Freezing a stable release is the single line `lastStableSchemaVersion = currentSchemaVersion`.

The same pair exists for the version codec (`currentPayloadFormat` / `lastStablePayloadFormat`).

### Why a forgotten freeze cannot ship

A stable tag build (`v[0-9]+.[0-9]+.[0-9]+`, no suffix) runs a **fail-closed CI guard** asserting
`lastStableSchemaVersion == currentSchemaVersion` (and the payload equivalent). If the freeze was
forgotten, `lastStable == current - 1` at the tag, the guard fails, and nothing is released — the
guard is a check that refuses, never a commit. Because every shipped stable necessarily froze,
`lastStable` is always honest at the start of the next cycle, which is exactly what keeps the
overwrite-vs-create rule from ever touching a frozen file.

### The gate's verdict

`myStable`/`myVersion` are the running build's schema and app version.

| File vs build | Verdict |
| --- | --- |
| `fileStable > myStable` | `newer` -> refuse (unchanged) |
| `fileStable < myStable` | `older` -> migrate; wording says "development build, at your own risk" when `myVersion` is a pre-release, else the current wording |
| `fileStable == myStable`, writer == me | `current` -> open |
| `fileStable == myStable`, me and writer both stable | `current` -> open (freeze guarantee: same number, same shape) |
| `fileStable == myStable`, a pre-release involved, writer != me | **refuse**, naming the build to use |

## Work, by logical commit

- **A — ADR 0029 + amend 0007.** State the rule: the two dimensions, what "born inside a cycle"
  means, what a squash may and may not touch, the refuse-a-dev-build rule, the pre-release migration
  warning, and the fail-closed release guard. Note atop ADR 0007 that its "allocate at merge time"
  clause is amended (a cycle no longer allocates a number per merge).
- **B — semver util.** `lib/utils/ocpt_app_version.dart` (pure): parse, `isPreRelease`,
  `stableLine`, compare. Read by the compatibility service and the tests. Unit-tested.
- **C — stamp the writer + wire the real version.** Add `project_info.migratedByAppVersion`,
  written by `OcptProjectsManager` on create and after a real migration, never on a no-migration
  open. Fix `_appVersion` to carry the true semver (suffix included) via
  `String.fromEnvironment('APP_VERSION', defaultValue: <literal>)`, and pass
  `--dart-define=APP_VERSION=<tag-derived version>` from every CI `flutter build`.
- **D — the one-time squash.** `currentSchemaVersion = 1`, `lastStableSchemaVersion = 0`,
  `onUpgrade` emptied and every `_backfill*/_alter*/_drop*/_erase*/_derive*/_number*` helper
  removed; `onCreate` (the current shape) stays byte-identical. The codec resets to
  `currentPayloadFormat = 1`, `lastStablePayloadFormat = 0`, its `_payloadUpgrades` ladder removed,
  its current serialization unchanged. Existing alpha `.ocpt` files become `newer` and are refused —
  accepted (issue #60): an alpha capture is owed nothing.
- **E — the compatibility gate.** `OcptProjectFileCompatibilityService.probe` also reads
  `migratedByAppVersion` and computes the verdict over the pair, plus a "running build is a
  pre-release" flag. Extend `OcptProjectFileVerdict` with the "same schema, foreign dev build ->
  refuse" case. The service returns facts; the page words them (no `Tr` in a service).
- **F — the UI.** Pre-release wording on the migration `OcptConfirmDialog`; a refusal message for
  the dev-build case (reusing the `OcptProjectFileNewerDialog` pattern). ARB strings in `en_GB`
  and `fr`.
- **G — the migrations directory + tests.** Extract the migration into
  `lib/models/database/migrations/`, one `ocpt_migration_v<n>.dart` per stable version (no `pending`
  suffix), with the overwrite-vs-create rule in a header doc comment. The migration test keeps a
  verbatim DDL fixture per **frozen stable** version (making an accidental overwrite of a frozen
  step fail CI), asserts `current in {lastStable, lastStable + 1}`, and stays the harness that will
  pin the next stable's upgrade path. Codec test in mirror.
- **H — the release guard + docs.** A CI job on stable tags asserting the freeze happened;
  `docs/RELEASING.md` gaining the freeze step; `foundations.md`'s migration narrative shortened and
  its "another build" section extended with the two dimensions and the dev-build refusal/warning.

## Verification

- Gates 1–9 at each commit (analyze + test at minimum). The delicate proof: the final schema does
  not move — capture the generated `onCreate` DDL before and after commit D and diff it.
- The stamp must never be rewritten on a no-migration open (else the freeze guarantee's refusal is
  lost) — pinned by a test.
- Commits D and G are large but mechanical; they may be delegated to Sonnet 5 agents under the main
  session's review.
