<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0010 - Sync-ready data model prerequisites

## Status

Proposed

## Context

ADR 0009 chose how projects are shared but deliberately left the data model alone. Three
properties of the current schema make a row unsafe to merge. None of them depends on which
transport wins, and each gets more expensive every week the app ships without it, so they are
worth settling before any sync code exists.

- **Deletes are hard.** `OcptShotListService`, `OcptScreenplayService`, `OcptSceneIndexService`
  and `OcptShotCoverageService` all issue plain `delete()` statements. A replica that was offline
  when a row was deleted has no way to learn it happened, and re-inserts the row on the next
  merge.
- **`position` is renumbered densely.** `OcptShotListService._renumberGroup` writes `0, 1, 2, …`
  over a whole group of shots, and the character reordering paths do the same inline, skipping only
  rows already correct. Inserting a shot at the head of a twenty-shot scene therefore writes twenty
  rows, turning one user action into twenty candidate conflicts, and two concurrent insertions at
  the same index collide instead of coexisting.
- **Row-level granularity would lose work.** `shootingDay` is a column of `shots`, so the director
  editing `framing` and the assistant director setting the shooting day touch the same row. A
  last-writer-wins merge over whole rows drops one of the two edits.

ADR 0007 keeps every schema change additive-only and sends any in-place reshape to an ADR of its
own.

## Decision

Three additive changes, schema v3, plus one preference:

- **`isDeleted`**, a boolean defaulting to false, on every synchronised table. Deletions become
  updates, reads filter tombstones out, and a tombstone is only purged once every replica has
  provably seen it.
- **`sortKey`**, a text column beside `position` on the ordered tables, holding a fractional index
  — a string ordered strictly between its two neighbours — so an insertion or a move writes
  exactly one row. `position` is neither retyped nor dropped: ADR 0007 forbids the first, and the
  second waits for a deliberate breaking version. It is backfilled at migration and stops driving
  ordering.
- **`row_field_versions(tableName, rowId, columnName, version, deviceId)`**, one new table holding
  per-column version stamps. It carries the entire merge granularity, so **no existing table gains
  a version column**. `version` is a device-local Lamport counter, never a relay sequence number,
  and `(version, deviceId)` orders two writes to the same column: a relay's counter cannot play
  that role once a set relay and a prep relay both exist in one day (ADR 0009).
- **`deviceId`**, a UUID generated on first launch and kept in `OcptPropertiesManager`, identifying
  a replica and its pending queue.

Applying a changeset runs inside a transaction with `PRAGMA defer_foreign_keys = ON`, because ADR
0007 turned foreign keys on and a changeset can legitimately arrive in an order that violates one
part way through.

Two tables stay out of the merge. `scenes` is never synchronised at all: it is derived from the
screenplay text and is recomputed locally after every merge. `screenplays.fountainText` is not
merged column-wise either — it is a whole document, reconciled by a three-way line merge against
the nearest common `screenplay_snapshots` row, which is what that table already holds.

## Consequences

Every read path in every service has to learn to filter tombstones. That is the bulk of the work
here, it touches roughly a dozen call sites today, and it only grows with each feature written
against hard deletes — which is the argument for doing it now rather than alongside the sync
engine.

The sidecar version table grows with fields rather than rows: a feature-length shot list of some
two thousand shots across twenty or so editable fields is around forty thousand stamps, which
SQLite handles without trouble. It must be written in the same transaction as the row it stamps,
or the two drift apart silently.

`position` and `sortKey` coexist as a duplicated concept until a breaking version retires the
first, and code touching order has to be unambiguous about which one it reads.

All four changes pay off even if sync is never built: tombstones are what a trash or an undo needs,
fractional keys make drag-and-drop reordering a single write instead of a group rewrite, and a
device id is needed by any future diagnostics.

## Alternatives considered

- **Waiting until sync is built**: the same work, done against more call sites and against
  `.ocpt` files already in users' hands, with no way to reconstruct deletions that were never
  recorded.
- **Retyping `position` to text in place**: forbidden by ADR 0007, and it would break every
  existing `.ocpt` opened by an older build.
- **One version column per data column**: no sidecar table to join, but it doubles the width of
  every synchronised table and every new field has to remember to add its twin.
- **Row-level rather than column-level versioning**: markedly simpler, but it loses the shot list
  and shooting schedule case outright, which is the collaboration the feature exists for.
- **Hybrid logical clocks instead of a plain Lamport counter**: they add a wall-clock component so
  a winner matches human intuition about which edit came last, at the price of clock-skew handling.
  A bare counter converges just as surely, and the case it reads oddly — an edit made earlier
  winning because its device had counted further — is rare enough to leave to a later ADR.
- **Event sourcing the whole model**: a replay engine and log compaction, where per-column stamps
  on the existing tables buy the same convergence for a fraction of the code.
