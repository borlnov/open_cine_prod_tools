<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0004 - Generated code is not committed

## Status

Accepted

## Context

Two code generators run on this repository: `dart run intl_utils:generate` (localization, from
`lib/l10n/*.arb`) and `dart run build_runner build` (drift's `DriftDatabase` codegen, from the
annotated database classes). Together they produce `lib/generated/**` (the `Tr` class and its
locale delegates) and every `**/*.g.dart` file (drift's tables/DAOs). The ACT Flutter guidelines
that this project otherwise follows expect generated code to be committed.

## Decision

`lib/generated/**` and `**/*.g.dart` are git-ignored (`.gitignore`) rather than committed. This
is a deliberate deviation from the ACT Flutter guidelines, recorded here rather than left
unexplained. Every developer checkout and every CI job runs the generation chain
(`flutter pub get` -> `dart run intl_utils:generate` -> `dart run build_runner build`)
before analyzing, testing or building. Because `reuse` 6.2.0
misdetects some git-ignored directories, `REUSE.toml` carries blanket annotations for
`lib/generated/**` and `**/*.g.dart` so a local build of these files does not fail `reuse lint`
before the ignore rule is picked up.

## Consequences

No generated-code diff noise in reviews, and no merge conflicts inside files nobody hand-edits.
The price: a fresh checkout does not compile until the generation chain has run - there is no way
to open the project and build immediately - and every CI job (not just the release build) must
run that chain first. The `REUSE.toml` blanket annotations need to stay in sync with the two
generated-code globs if either generator's output paths ever change.

## Alternatives considered

- Commit generated code, per the ACT guidelines: would give a checkout that compiles immediately
  and match house style, at the cost of frequent, noisy diffs on every schema or translation
  change, and the risk of committed output drifting from what the generators would currently
  produce.
