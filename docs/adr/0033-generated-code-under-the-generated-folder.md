<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0033 - Generated code lives under `lib/generated/`, outside version control

## Status

Accepted. Supersedes [ADR-0004](0004-generated-code-is-not-committed.md).

## Context

Two generators run on this repository: `dart run intl_utils:generate` (localization, from
`lib/l10n/*.arb`) and `dart run build_runner build` (drift's database codegen). ADR 0004 recorded
that neither output is committed, and described that as a deviation from the ACT Flutter
guidelines, on the belief that they expect generated code to be committed. That belief was wrong:
the ACT Flutter standards ask for exactly what this repository does about version control —
generated code is excluded from it — and add one more requirement: all of it is emitted under a
dedicated `generated/` folder. Only the second half was missing here. The localization output was
already in `lib/generated/`, but drift's file, `ocpt_project_database.g.dart`, sat beside the
source that declares it, and its `.gitignore` and `REUSE.toml` entries were a repository-wide
`**/*.g.dart` glob rather than a folder.

The generators allow the move. `build_runner` takes its output location from the
`source_gen:combining_builder`'s `build_extensions` option, which can map `lib/<path>.dart` to
`lib/generated/<path>.g.dart`, and the only `part` directive in the repository is the one drift's
file needs. It was checked with the versions pinned in `pubspec.lock` (drift_dev 2.31, build_runner
2.15, source_gen 4.2) on a scratch package, then on this repository.

## Decision

A root `build.yaml` sets the `build_extensions` option above, so drift's file is written to
`lib/generated/models/database/ocpt_project_database.g.dart`, and the `part` directive of
`lib/models/database/ocpt_project_database.dart` points at it. `source_gen` becomes a direct
`dev_dependency`, since it is that package's builder whose options the repository now sets.
The commands are unchanged: `dart run build_runner build` remains the way to generate.

`lib/generated/` stays git-ignored (`lib/generated/.gitignore`), so the repository-wide
`**/*.g.dart` entry in `.gitignore` is removed, and so is its annotation in `REUSE.toml`:
`lib/generated/**` is already annotated. Generated code is therefore the one folder, and a
`.g.dart` found anywhere else is no longer silently ignored but shows up in `git status`, which is
what a misplaced generator output should do. `analysis_options.yaml` already excludes
`lib/generated/**` from analysis; the analyzer still resolves the `part` through the main library.

## Consequences

A fresh checkout still does not compile until `flutter pub get`, `intl_utils:generate` and
`build_runner build` have run, and CI still runs that chain first; that cost, accepted in ADR 0004,
is unchanged. What changes is that "generated code" now has one location, one ignore rule and one
licensing annotation.

Both generators write into `lib/generated/`; neither empties it, so they can run in either order.
A migration to a newer `source_gen` has to keep the `build_extensions` option working, and a new
file declaring a `part` for generated code has to point at `lib/generated/`, mirroring its own
path under `lib/`.

## Alternatives considered

- Keep drift's file beside its source and keep ADR 0004 as it stood: leaves a generator output
  outside the dedicated folder, and a record that states a guideline the wrong way round.
- Commit generated code: contradicts the guidelines, adds review noise on every schema or
  translation change, and lets committed output drift from what the generators would produce.
- Move the database declaration itself under `lib/generated/`: it is hand-written code, and the
  folder is for output only.
