<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0001 - Per-project SQLite file with drift

## Status

Accepted

## Context

Open Cine Prod Tools stores each project as a single file a user can copy, back up or share, with
no server involved. The project needs typed, reactive, queryable storage for more than the
screenplay text itself: project metadata, one or more screenplays, safety snapshots of their
text, and an index of scenes that other features (shot lists, coverage) can reference by a stable
id.

## Decision

Each project is one `.ocpt` file: a SQLite database opened through
[drift](https://drift.simonbinder.eu/), `OcptProjectDatabase` (`lib/models/database/`).
Schema v1 has four tables: `project_info` (one row, page format and other project-level
settings), `screenplays`, `screenplay_snapshots` (safety copies, pruned to the most recent few)
and `scenes` (the reconciled scene index). `DriftDatabaseOptions.storeDateTimeAsText` is turned
on so timestamp columns keep sub-second precision - several snapshots can land in the same
second, and whole-second timestamps would tie when ordered for pruning.

The Fountain text in `screenplays` is the source of truth; `scenes` is a derived index, rebuilt by
`OcptSceneIndexService.reconcile` after every parse. Reconciliation runs in three passes, each
only considering rows/headings the previous pass left unmatched: by explicit scene number, then
by exact heading text, then by relative order (i-th unmatched row with i-th unmatched heading).
This keeps a scene's UUID stable across an edit - a rename with no number involved is treated as
an edit of the scene at that position, not a delete followed by an insert - so other features can
hold onto a scene id.

Storage is local-only for now. Google Drive sync and a dedicated server are later options, not
built yet.

## Consequences

No server to run or pay for; a project is trivially backed up, copied or shared as one file.
Snapshots make destructive operations (e.g. an import that replaces the screenplay) reversible.
The derived scene index adds a reconciliation step after every parse, and any future schema
change is a drift migration that has to run against files already in the wild. Local-only storage
means no cross-device sync today - a user working from two machines has to move the file
themselves.

## Alternatives considered

- Plain `.fountain` files on disk, with no database: no query surface for a scene index or
  snapshots, and no natural place to store project-level settings.
- A document database (e.g. embedded NoSQL): drift's typed, generated query API and migration
  story fit a relational, evolving schema better than a schemaless store would.
- A remote-first backend: rejected for now to keep the app fully offline-capable and avoid
  operating a server before there are users to justify it.
