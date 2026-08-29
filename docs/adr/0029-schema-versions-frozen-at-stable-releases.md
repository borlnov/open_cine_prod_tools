<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0029 - Schema versions frozen at stable releases

## Status

Accepted

## Context

The schema reached `schemaVersion => 35` across four alpha tags, and most of those steps exist only
because a column was added, renamed and dropped again while a feature was being designed — v12's
typed clocks and groups, which v13 removed, are the clearest case. Every one is an `onUpgrade` step
carried forever, a `payloadFormat` the version codec upgrades through, and a row in the migration
test. None of it ever reached a user's disk: no stable release has shipped, so the whole `1 -> 35`
chain is workshop churn between developer machines.

ADR 0007 said a migration must be additive and that a version number is claimed at merge time. It
did not say **when a number is owed forever**. A file written by a *released* build is a promise:
it must still open, losing nothing, in every later build. A shape a build produced only while a
feature was mid-design is not a promise to anybody — but the code treats the two identically, so
every dev iteration is preserved as if a user depended on it.

This project is also built entirely by an agent working from a tag: the developer tags a commit and
CI builds and releases it. Any rule added here has to survive that — a step that depends on a human
remembering to do something before tagging would eventually be forgotten, and the failure has to be
a refused release, never a silently broken one.

## Decision

A file carries **two dimensions**, compared before drift ever opens it.

- **The stable schema version** is drift's `user_version`. It advances **only** when a stable
  release ships. Inside a development cycle the pending schema is a single migration step that is
  *rewritten in place* as features land, never a fresh numbered step per pull request.
- **The writer identity** is the app version stamped on the file at each real write, in
  `project_info.migratedByAppVersion`, read as a semver. A version is **stable** iff it carries no
  pre-release suffix (`0.1.0`, `0.2.1`); anything with one (`0.2.0-alpha.3`, `0.2.0-3-g87a9b8d`) is
  a **pre-release**. The running build's own version is tag-derived by CI (`git describe`), so a
  build sitting on a stable tag `vX.Y.Z` is stable and every other build carries a `-N-g<sha>`
  suffix, with nothing to edit by hand.

"Born inside a cycle" is precisely this: a schema version, or a `payloadFormat`, that **no stable
tag ever shipped**. Such a version may be folded away — its step merged into the next one, its
number reused — when the cycle it belonged to ships stable. A version a stable release put on a
user's disk may never be: going `0.1.0 -> 0.2.0`, no data is lost and no path is dropped.

Two constants govern which file to touch, and the migration lives in one
`lib/models/database/migrations/ocpt_migration_v<n>.dart` per version:

```text
currentSchemaVersion      the schema this build writes; fixed for a whole cycle
lastStableSchemaVersion   the highest schema a stable release froze; changed only at release prep
```

When `current == lastStable` the top file is frozen, so a schema change bumps `current` and
**creates** a new file; when `current == lastStable + 1` a cycle is open, so a change **overwrites**
the top file. `current` is therefore always `lastStable` or `lastStable + 1`. Freezing is the one
line `lastStableSchemaVersion = currentSchemaVersion`, done at release prep. The version codec
carries the same pair (`currentPayloadFormat` / `lastStablePayloadFormat`), because a payload format
is a version of its own that a stable build owes exactly the same promise about.

**A squash merges steps; it never changes what the final schema is.** The migration test is what
proves that: it keeps a verbatim DDL fixture per frozen stable version and pins that `onCreate`
reproduces the result of every stable upgrade path, so a fold that altered the final shape — or an
overwrite of a frozen step — fails there rather than on a user's file.

Two rules protect the promise at runtime, in `OcptProjectFileCompatibilityService`. A file at the
build's own stable schema but last written by a **pre-release build that is not this exact build**
is **refused**, not migrated: its shape may differ from the frozen release, and taking a workshop
shape for the stable one is the one corruption this whole record exists to prevent. And an older
file opened by a **pre-release** build is still migrated, but behind a "development build, at your
own risk" warning rather than the stable wording.

The freeze cannot be forgotten into a release: a stable tag build runs a **fail-closed CI guard**
asserting `lastStableSchemaVersion == currentSchemaVersion` (and the payload equivalent). A
forgotten freeze leaves `lastStable == current - 1`, the guard fails, and nothing ships. The guard
refuses; it never commits.

## Consequences

The one-time cost is paid now: the `1 -> 35` chain and the `payloadFormat` ladder collapse to a
single fresh schema, and every existing alpha `.ocpt` becomes `newer` and is refused. That is the
intended reading — an alpha capture is owed nothing — and the two development machines that hold any
can recreate them.

From here the migration history stays one frozen step per stable release. A developer touching the
schema reads the two constants and knows whether to overwrite or create; they never judge it. The
release guard keeps `lastStableSchemaVersion` honest, which is what keeps that reading safe cycle
after cycle. The developer's only recurring gesture at release time is still `git tag`: the freeze
is a reviewed two-line commit prepared before the tag, and forgetting it blocks the release instead
of corrupting a file.

This amends ADR 0007: within a cycle a number is no longer allocated per merge — the cycle's changes
accumulate into the one pending step. The additive-only guidance and the merge-time reasoning for
two branches in flight still hold for how a single step is written.

## Alternatives considered

- **Keep every step forever (the status quo).** Simplest, but carries a permanent tax — a step, a
  payload upgrade and a test row — for shapes no user ever saw, growing without bound.
- **Squash by tooling.** A script that guessed which steps "never left the workshop" would
  eventually fold away one a stable release had shipped. The fold is a judgement about what was
  promised, made by hand and proven by the test.
- **A stored "is stable" flag on the file.** A second source of truth to keep in sync with the tag.
  Stability is read from the writer's semver instead, whose suffix the CI already sets.
- **A hand-maintained integer for the dev iteration.** Someone must bump and reset it. The app
  version string already distinguishes builds, so the iteration is read from it for free.
- **A CI job that commits the freeze.** Needs write permissions, races other merges and mutates
  history around a tag. A guard that refuses gives the same safety with none of that, leaving the
  two-line freeze a reviewed change.
