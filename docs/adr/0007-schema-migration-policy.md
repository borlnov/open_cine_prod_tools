<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0007 - Schema migration policy

## Status

Accepted

## Context

Every project schema version so far shipped as `schemaVersion => 1` with no `MigrationStrategy`
at all: there was nothing to migrate from, since the app had never shipped a schema change. The
shot list feature is the first to add tables to an already-shipped schema, which makes an
`.ocpt` file a *versioned* artifact for the first time: a file created by an older build of the
app must still open correctly in a newer one, without losing anything it already held. `drift`'s
`MigrationStrategy` is the mechanism for that, but it says nothing on its own about what a version
bump is allowed to do to existing data, or whether the foreign keys the tables already declare
(`references()`) are actually enforced by SQLite at runtime - `NativeDatabase` leaves the
`foreign_keys` pragma at SQLite's own default, which is off.

## Decision

`OcptProjectDatabase.schemaVersion` moves to 2, and the database gains its first
`MigrationStrategy`: `onCreate` still creates every table via `m.createAll()` for a brand-new
project, and `onUpgrade` handles a database opened at an older version. From 1 to 2, `onUpgrade`
only creates the three new shot list tables (`shots`, `shot_characters`, `shot_coverages`) -
it does not alter, rename or backfill any existing table. Every schema change from here on is
**additive-only** for as long as this policy holds: a new column is added with a default so
existing rows stay valid, a new table is created, but an existing column is never dropped,
renamed or retyped in place. A change that genuinely needs to reshape existing data (a rename, a
type change, splitting a column) gets its own ADR revisiting this policy rather than being folded
in quietly.

`beforeOpen` also runs `PRAGMA foreign_keys = ON` on every open, old or new database alike: this
was verified empirically (a plain `sqlite3.openInMemory()` reports `foreign_keys = 0` before any
pragma is set) rather than assumed, and the full existing test suite passes unchanged with it
turned on, meaning nothing already relied on inserting orphaned rows.

## Consequences

A user's existing `.ocpt` file always opens, gains the three new empty tables the first time it
is opened by a build that knows about them, and keeps every screenplay, snapshot and scene it had
- there is no destructive path through the migration. The additive-only rule is now a constraint
on every future schema change: a column that turns out to need a different type or a `NOT NULL`
without a sensible default cannot be changed in place under this policy, and must instead be
introduced as a new column with its own migration step, leaving the old one to be cleaned up in a
later, deliberate breaking version. Turning foreign keys on makes a bug that would insert an
orphaned `shot_characters`/`shot_coverages` row fail loudly at the `INSERT` instead of silently
producing a dangling reference, but it also means any future insert order that violates a
declared reference (inserting a shot before its screenplay row exists, for instance) now throws
where it previously would not have.

## Alternatives considered

- Leaving `foreign_keys` off, matching SQLite's own default: avoids ever having to fix an insert
  ordering bug the pragma would newly expose, but defeats the purpose of declaring `references()`
  on these tables at all, and lets a real bug produce silently orphaned rows in a user's project
  file instead of failing at the point it happens.
- A destructive `onUpgrade` that drops and recreates every table: much simpler to write, but loses
  every screenplay, snapshot and scene a user already had the moment their file is opened by a
  build that knows about the shot list - not an acceptable cost for a local-first, single-file
  storage model with no server-side backup.
- Using `drift_dev`'s generated `stepByStep` migration helper (`drift_dev schema generate` plus a
  versioned `schema/` snapshot directory): gives per-step schema verification for free, but
  introduces a whole snapshot workflow the project has not adopted for its one migration so far; a
  plain `onUpgrade(m, from, to)` with an `if (from < 2)` guard is enough for now and revisiting this
  is cheap once there are several versions to step through.
