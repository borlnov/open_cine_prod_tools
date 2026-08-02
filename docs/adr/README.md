<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture decision records

An architecture decision record (ADR) captures a structural choice made in this project: what was
decided, why, what it costs, and what alternatives were rejected. It exists so a future
contributor - human or agent - can find the reasoning behind a choice already baked into the code,
instead of having to reconstruct it from commit history.

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

## Candidates

Decisions worth recording once there is time to write them up properly:

- The ACT Flutter packages (`actlibs/`) as the application foundation.
- Routing exclusively through `OcptRouterManager`, never `Navigator` directly.
