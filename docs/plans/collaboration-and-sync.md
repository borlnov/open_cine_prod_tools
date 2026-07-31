<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Collaboration and sync — shared projects, in prep and on set

This document is the implementation strategy for making a project shareable and collaborative. It
is written for the Sonnet 5 agents that will build it, orchestrated and reviewed by the main
session, with a user checkpoint between each milestone. **Read the repository `CLAUDE.md` first** —
this plan assumes its architecture, ways of working, coding standards, licensing rules and
verification gates, and does not repeat them.

The decisions this plan implements are recorded in
[ADR 0009](../adr/0009-offline-first-sync-through-a-domain-blind-relay.md) (how projects are
shared) and [ADR 0010](../adr/0010-sync-ready-data-model-prerequisites.md) (what the schema needs
first). When this plan and an ADR disagree, the ADR wins.

---

## 1. Why this step exists

Today a project is one local SQLite file opened by one person on one machine. The shoot itself is
what breaks that:

- On an exterior location the director works from a **tablet**, not a laptop: reading the shot
  list, and adding a shot when the day demands it.
- The **assistant directors change the shooting schedule at the same time**, from their own
  machines.
- Roles own different documents, but **every document is readable by everyone**.
- Connectivity on location is unreliable or absent, so nothing may depend on reaching the
  internet.

Before the shoot, the same project has to be shareable between people who are not in the same
room — the director at home, the production office, the first assistant director.

## 2. The strategy in one page

Restated from the ADRs so an agent has it in front of them.

**A domain-blind relay.** One self-hostable, single-tenant server per person or per production,
written in Dart, exposing five routes over one bearer token per project: append a changeset, read
changesets since a sequence number, upload a snapshot, fetch the latest snapshot, and a WebSocket
announcing new work. It never parses a changeset and never learns a table name, so the domain
model evolves without ever redeploying it.

**Offline-first, always.** Every device holds a full replica of the project. The app is fully
usable with no network; changes queue locally and merge on reconnect. This is not a degraded mode,
it is the normal one.

**Merge is client-side and per column.** The director editing a shot's `framing` and the assistant
director setting that same shot's `shootingDay` must both survive. Whole-row resolution would drop
one of them.

**The server is portable.** On set it runs on a laptop at the video village or on a Pi in the
truck, with tablets reaching it over a travel router; in prep it runs on a small VPS. Same binary,
same client code path, a different address. Because there is always exactly one authority
reachable, there is never any peer-to-peer merge to write.

**Two documents are special.** `scenes` is derived from the screenplay text and is never
synchronised, only recomputed. `screenplays.fountainText` is a whole document, reconciled by a
three-way line merge against the nearest common `screenplay_snapshots` row rather than field by
field.

## 3. Architecture

### 3.1 New packages

Two pure-Dart packages beside `packages/fountain_kit`, both free of any Flutter import, keeping the
existing rule that dependencies never reference their dependents:

- **`packages/ocpt_sync_protocol`** — the wire format alone: the changeset envelope, the snapshot
  descriptor, sequence numbers, error shapes, and their JSON codecs. Depended on by both the app
  and the relay, and by nothing else. It deliberately contains no table names and no domain types.
- **`packages/ocpt_sync_relay`** — the server: `shelf`, a SQLite file, the five routes, token
  checking, snapshot pruning. It depends on `ocpt_sync_protocol`; the app never depends on it.

The CI matrix, currently `{ ., packages/fountain_kit }`, gains both. The relay is a plain Dart
package, so its gate is `dart analyze` and `dart test`, not the Flutter ones.

### 3.2 New manager and services

`OcptSyncManager extends AbsWithLifeCycle`, registered with a builder factory and `dependsOn` the
projects manager, resolved through `globalGetIt()` like every other manager. It owns, following
the same one-service-per-responsibility split as `OcptExportManager`:

- `OcptChangesetService` — turns local writes into changesets, and applies incoming ones. Applying
  runs in a transaction with `PRAGMA defer_foreign_keys = ON`, since foreign keys are on since ADR
  0007 and a changeset can violate one part way through.
- `OcptMergeService` — per-column resolution against `row_field_versions`, plus tombstone
  handling.
- `OcptScreenplayMergeService` — the three-way line merge for `fountainText`, and the only place
  that can surface a conflict to the user.
- `OcptRemoteStorage` — the transport interface, with two implementations:
  `OcptFolderRemoteStorage` (a directory, used to exercise the engine with no network at all, and
  usable on desktop over any file-sync client) and `OcptRelayRemoteStorage` (HTTP plus WebSocket).

The screenplay text is still written only through `OcptScreenplayService.saveScreenplayText`, never
by hand, so scene reconciliation keeps running after a merge exactly as it does after an edit.

### 3.3 Schema v3

Per ADR 0010: `isDeleted` on every synchronised table, `sortKey` beside `position` on the ordered
ones, the `row_field_versions` sidecar table, and a `deviceId` in `OcptPropertiesManager`. The
migration is additive, as ADR 0007 requires, and backfills `sortKey` from the existing `position`
ordering.

### 3.4 What the user sees

Sync is meant to be invisible when it works. The visible surface is deliberately small: a status
indicator in the workspace status bar (in sync, syncing, offline with a pending count, or an error),
a project-level pairing screen taking a relay address and token — by QR code on a tablet — and the
screenplay conflict view, which is the only conflict a user is ever asked to resolve.

## 4. Milestones

Each milestone ends with the full verification gate of `CLAUDE.md` §*Verification gates*, one
commit per logical change, and a user checkpoint before the next one starts.

**M1 and M2 are independent of each other** and can run in parallel; everything after depends on
M1.

### M1 — Sync-ready data model

Schema v3 and its `MigrationStrategy`: `isDeleted` on the synchronised tables, `sortKey` beside
`position` with its backfill, `row_field_versions`, `deviceId` in `OcptPropertiesManager`. Every
hard `delete()` in `OcptShotListService`, `OcptScreenplayService`, `OcptSceneIndexService` and
`OcptShotCoverageService` becomes a tombstone, and every read path in those services learns to
filter tombstones out. `_renumberGroup` and the inline character renumbering in
`OcptShotListService` are replaced by fractional key allocation, so an insertion or a move writes
one row.

Tests: migration from a v2 database preserving every existing row and producing a strictly ordered
`sortKey` backfill; a deleted row staying invisible to every reader; fractional key allocation at
the head, between two neighbours, at the tail, and after repeated insertions between the same pair;
a reorder writing exactly one row.

No sync, no network, no UI. This milestone is worth shipping on its own even if nothing after it
is ever built.

### M2 — The app on a tablet

Android build wired into `build.yml`, and the shot list made usable with a finger on a tablet:
touch-sized targets, a readable table at tablet width, and an add-shot flow that does not assume a
keyboard or a right dock. Exports go through the system share sheet, since `file_selector`'s
`getSaveLocation` has no Android implementation — check the iOS side at the same time and report
what it needs. The screenplay editor is **read-only** on small screens; the styled editor is not
part of this milestone.

Report at the checkpoint what the workspace shell and the mode switcher needed to work at tablet
width — the answer shapes M5's presence UI.

### M3 — The changeset engine, over a folder

`packages/ocpt_sync_protocol`, `OcptSyncManager`, `OcptChangesetService`, `OcptMergeService`,
`OcptScreenplayMergeService`, and `OcptFolderRemoteStorage` as the only transport. Two app
instances pointed at the same directory must converge.

Tests: two replicas editing different columns of the same shot row, both surviving; a delete on one
side and an edit on the other; a replica offline across several changesets catching up in one go;
concurrent insertions at the same index coexisting; screenplay three-way merge on a clean case and
on a genuine conflict; `scenes` recomputed rather than merged.

No server yet. The folder transport exists to prove the engine without any network code, and it
stays afterwards as the desktop fallback.

### M4 — The relay

`packages/ocpt_sync_relay`: the five routes, one bearer token per project, snapshot upload and
pruning below it, a SQLite store, and a Dockerfile. `OcptRelayRemoteStorage` on the client, plus
the pairing screen and the status indicator described in §3.4.

Tests on the server side are plain Dart: route behaviour, sequence monotonicity, rejection of a
bad or missing token, pruning not losing a changeset a replica has not yet read.

The server must stay domain-blind — if a reviewer finds a table name or a domain type anywhere in
this package, the design has drifted.

### M5 — Live push and presence

The WebSocket route driving the client instead of polling, and a presence indicator showing who
else has the project open and which mode they are in. This is what makes the set feel collaborative
rather than eventually consistent.

### M6 — The portable on-set server

Running the relay on a laptop or a Pi on set: discovery by QR code carrying the local address and
token, and upstream reconciliation where the set relay acts as a **client** of the prep relay at
the end of the day, reusing the M3 merge rather than a second implementation.

Document the set-up in `docs/` as an operator guide, not just as code: this is the milestone a
production actually has to follow on the ground.

---

## 5. Out of scope

Stated so no agent drifts into them:

- Real-time co-editing of the screenplay text with multiple cursors. The three-way merge is the
  answer, and screenplays are single-owner in practice.
- Per-document access control. Whoever holds the project token holds the whole project; keeping a
  document away from the crew means a separate project file (ADR 0009).
- User accounts, passwords, password recovery, and anything that would store personal data.
- A multi-tenant hosted service, and Google Drive or any other cloud provider's API.
- The budget and shooting schedule modes' own content — this plan syncs what exists, it does not
  build new modes.
- Retiring the `position` column, which waits for a deliberate breaking version (ADR 0010).
