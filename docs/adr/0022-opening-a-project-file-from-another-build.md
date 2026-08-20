<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0022 - Opening a project file from another build

## Status

Accepted

## Context

A project file is a document the user carries: onto a USB key, into a backup, and — since ADR 0021 —
into a package sent to somebody else. So the build that opens a `.ocpt` is regularly **not** the
build that wrote it, in both directions, and until this record neither direction was handled.

**A file from an older build** already worked, by accident of drift doing its job: `onUpgrade`
migrated it on the way in. But it happened **silently**, with nothing kept. A migration is
irreversible and the schema policy (ADR 0007) allows a column drop when the alternative is worse —
v18 dropped two — so an upgrade the user never asked for can leave them with a file their previous
build no longer opens, and no copy of what it was.

**A file from a newer build** was worse than unhandled. `onUpgrade(m, from, to)` is called with
`from > to`, every `if (from < N)` guard declines to run, and drift then stamps `PRAGMA user_version`
**back down** to the running build's number. The file still holds the newer build's tables and
columns while claiming to be old, and the next upgrade runs its steps a second time over them. This
was verified against the shipped stack, not assumed.

Anything that inspects the file to decide has to do so **without drift**, since opening a drift
database is itself what migrates and what writes `user_version`. Looking cannot be allowed to
change what is being looked at.

## Decision

**No project file reaches drift before it has been read.** `OcptProjectFileCompatibilityService`
(`lib/managers/projects/services/`) probes it through raw `sqlite3` opened
`OpenMode.readOnly` — `PRAGMA user_version`, and `project_info.app_version_at_creation` when that
table is there — and answers an `OcptProjectFileCompatibility`
(`{ filePath, fileSchemaVersion, appSchemaVersion, appVersionAtCreation, suggestedBackupPath,
verdict }`). The verdict drives `OcptProjectsManager.openProject`:

- **newer** → refused with `OcptProjectStatus.newerFormat`. The file is not opened, not touched and
  not added to the recent projects list; a dialog names both format numbers and the app version the
  file was created with. Nothing this build can do makes it work — the answer is the newer build.
- **older** → `OcptProjectStatus.migrationRequired` unless the caller passes `allowMigration: true`,
  which is the caller saying the user has been told. The question is `OcptConfirmDialog` like every
  other irreversible action, worded by the page and not by the bloc, stating which format the file
  is in, which one it is being brought to, that the change cannot be undone, and **where the copy
  will be kept**. On confirmation the manager writes that copy and only then hands the file to
  drift.
- **current** → opened exactly as before this gate existed, no dialog and no copy.
- **unreadable** (`user_version` at 0, an unreadable file, something that is not a project) → the
  gate has nothing to state and stands aside, leaving the open to report whatever it finds, as it
  did before.

The copy is `<name>.backup-v<n>.ocpt` beside the original, a counter appended rather than an
existing backup overwritten, and it is taken with `VACUUM INTO` from a **read-only** connection: the
backup exists because the original is about to change, and taking it must not be what changes it.
The path comes from `OcptProjectFileCompatibility.suggestedBackupPath`, so the promise the dialog
makes and the write that follows cannot drift apart. **No copy, no migration** — a backup that fails
to write turns the open into an `ioError` rather than going ahead.

The gate is the single door: the home page's `Open…`, a recent project card, and the landing of an
imported package (ADR 0021) all go through it. **Exporting deliberately does not** — a package
carries the file at whatever format it is in.

## Consequences

Opening a project someone sent is now a conversation rather than a side effect, and the two failures
that had no name have one: `OcptProjectStatus.migrationRequired` and `OcptProjectStatus.newerFormat`.

What it costs: **every open pays a probe** — one read-only `sqlite3` connection and two statements
before drift is handed anything. Cheap, and on the path of every project the user ever opens. A
migration now also writes a **full second copy** of the project file beside the original, which the
app never cleans up: a project migrated across several releases leaves several backups, and telling
them apart is the user's job, helped only by the format number in the name.

The backup keeps the `.ocpt` extension on purpose — it is a file the older build can still open,
which is the entire reason for taking it — so a folder holding one has two files a file picker
offers, and only their names say which is which.

Two constraints on future changes. The probe reads columns from a file at **any** format, including
one written before those columns existed, so it asks `sqlite_master` before it selects and must keep
doing so. And a caller that opens a project file without going through `probeProjectFile` reopens
both holes at once: `allowMigration` defaults to `false` precisely so forgetting the gate fails as a
refusal to open rather than as a silent migration.

## Alternatives considered

- **Letting drift decide**: it is what happened before, and for a newer file it silently corrupts
  the very thing it was asked to open.
- **Refusing an older file outright**: honest, and it would strand every project made by a previous
  release with no way forward inside the app.
- **Migrating an older file with no copy** (a dialog and nothing else): the confirmation would be
  asking the user to accept a loss the app could just as easily have prevented.
- **Backing up as `<name>.ocpt.bak`**: the older build would not list it in its open dialog, making
  the copy useless to the one build that could still read it.
- **A `project_info` column stating a minimum readable format**, so a newer file could declare
  itself readable: real value the day the schema stops changing shape, and unfalsifiable before
  then — the build writing it cannot know what a later one will break.
