<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture decision records

An architecture decision record (ADR) captures a structural choice made in this project: what was
decided, why, what it costs, and what alternatives were rejected. It exists so a future
contributor - human or agent - can find the reasoning behind a choice already baked into the code,
instead of having to reconstruct it from commit history.

`docs/architecture/` is the other half of the record, and the two are not interchangeable. **A
record here is dated and frozen** — never rewritten, only amended or superseded, so a superseded
one deliberately keeps describing a model the code has left behind. **A file in
`docs/architecture/` is always current** — rewritten with every change, describing the whole system
as it stands today, including everything that never warranted a record of its own. Read an ADR to
learn why something is the way it is and what was turned down; read `docs/architecture/` to learn
what the code does and what must not be broken. When a record restates a rule that directory also
states, that repetition is deliberate: an ADR that only pointed at a living document would stop
being evidence of what was decided at the time.

## When to write one

Write an ADR for a decision that is expensive to reverse, that shapes how other code is written
(a dependency, a storage format, a package boundary), or that a future contributor is likely to
question without knowing the constraints that led to it. Do not write one for an implementation
detail that a future change can freely revisit; those belong in code comments, not here.

## Format

Every record uses [`0000-template.md`](0000-template.md): `Status`, `Context`, `Decision`,
`Consequences`, `Alternatives considered`. Keep a record short, roughly 40 to 80 lines - long
enough to be useful, short enough to stay read.

## Naming and numbering

Files are named `NNNN-title-in-kebab-case.md`, the number zero-padded to four digits. Numbers are
assigned in sequence and are never reused or renumbered, even if a record is later superseded: the
number is a stable identifier other documents and commits can reference.

## Status

- **Proposed** - written, not yet acted on.
- **Accepted** - the decision is in effect.
- **Superseded by ADR-NNNN** - replaced by a later record; keep the original file, it still
  explains the reasoning for the period it applied.

## Adding a record

1. Copy `0000-template.md` to `NNNN-title-in-kebab-case.md`, using the next unused number.
2. Fill in every section; do not invent history the repository does not support.
3. Add a row to the index below.

## Index

| Number | Title | Status |
| --- | --- | --- |
| [0001](0001-per-project-sqlite-file-with-drift.md) | Per-project SQLite file with drift | Accepted |
| [0002](0002-fountain-kit-as-a-standalone-dart-package.md) | fountain_kit as a standalone Dart package | Accepted |
| [0003](0003-super-editor-for-the-styled-editor.md) | super_editor for the styled editor | Accepted |
| [0004](0004-generated-code-is-not-committed.md) | Generated code is not committed | Accepted |
| [0005](0005-resizable-editor-docks.md) | Resizable editor docks | Accepted |
| [0006](0006-workspace-shell-as-a-slot-widget.md) | Workspace shell as a slot widget | Accepted |
| [0007](0007-schema-migration-policy.md) | Schema migration policy | Accepted |
| [0008](0008-excel-community-for-the-shot-list-export.md) | excel_community for the shot list export | Accepted |
| [0009](0009-offline-first-sync-through-a-domain-blind-relay.md) | Offline-first sync through a domain-blind relay | Proposed |
| [0010](0010-sync-ready-data-model-prerequisites.md) | Sync-ready data model prerequisites | Proposed |
| [0011](0011-macos-distribution-outside-the-app-store.md) | macOS distribution outside the App Store | Accepted |
| [0012](0012-source-provenance-in-the-paginator.md) | Source provenance in the paginator | Accepted |
| [0013](0013-binary-assets-referenced-by-path.md) | Binary assets referenced by path | Accepted |
| [0014](0014-breakdown-tags-as-the-script-to-catalogue-anchor.md) | Breakdown tags as the script-to-catalogue anchor | Accepted |
| [0015](0015-shooting-days-as-chained-blocks-with-pinned-anchors.md) | Shooting days as chained blocks with pinned anchors | Accepted |
| [0016](0016-sun-times-computed-offline-from-the-locations-coordinates.md) | Sun times computed offline from the location's coordinates | Accepted |
| [0017](0017-convocations-computed-from-the-slot-chain.md) | Convocations computed from the slot chain | Superseded by ADR-0018 |
| [0018](0018-a-convocation-is-the-slot-you-are-linked-to.md) | A convocation is the slot you are linked to | Accepted |
| [0019](0019-one-project-several-episodes.md) | One project, several episodes | Accepted |
| [0020](0020-bundled-hunspell-dictionaries-and-our-own-checker.md) | Bundled hunspell dictionaries and our own checker | Accepted |

## Candidates

Decisions worth recording once there is time to write them up properly:

- The ACT Flutter packages (`actlibs/`) as the application foundation.
- Routing exclusively through `OcptRouterManager`, never `Navigator` directly.
