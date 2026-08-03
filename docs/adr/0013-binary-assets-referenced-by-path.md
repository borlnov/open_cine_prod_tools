<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0013 - Binary assets referenced by path

## Status

Accepted

## Context

The resources mode gives a production its address book, its roles, its locations and its physical
elements, and every one of those subjects comes with binary material: a headshot on a person's
sheet, fourteen scouting photos on a location, a photo of a prop, and the signed PDF of an image
rights release. The reference documents this mode is modelled on carry the same material today, as
images pasted into a spreadsheet column.

A project is one SQLite file (ADR 0001) that the user handles as a document — copied to a USB key,
sent to a collaborator, backed up. Three properties of the current design constrain where those
bytes may live:

- **The changeset sync** (ADR 0009, ADR 0010) is built around small per-column edits carried by a
  domain-blind relay. Nothing in that design is sized for a column holding several megabytes, and
  nothing in it distinguishes a column that should be excluded from replication.
- **Project versions** capture the whole project as a JSON payload stored inside the same file, one
  row per version. Anything captured is captured in full, per version.
- **The erasure of a person** (a tombstone plus the blanking of their personal columns) has to be
  able to reach every trace of them the file holds.

The options were: store a path, store the bytes as a blob, or turn the project into a bundle - a
directory holding the `.ocpt` and an assets folder beside it.

## Decision

Binary assets are **referenced, never embedded**: an `assets` table (schema v6) holds a row per
asset with its `kind`, its **absolute path on this machine**, a label, a timestamp and a nullable
owner column per subject (`personId`, `locationId`, `elementId`). No byte of an image or a document
enters the `.ocpt`, and the app never copies, moves or writes the referenced files - it only reads
them to draw a thumbnail.

Everything else about the table is ordinary: it is a synchronised table like the ten others of that
step, it carries `isDeleted` and `sortKey`, and its rows travel inside a version payload as rows.

**A missing file is a normal state, not an error.** The path is machine-local by construction, so a
`.ocpt` opened on another machine - or after the photos folder was moved - resolves nothing. The UI
shows the reference with a "file not found" marker and offers to re-point it, and no code path
treats the absence as a failure to report.

## Consequences

What it buys: the project file stays small and stays the size of its text, the sync design needs no
per-column exclusion rule, a version payload costs the same whether a location has one scouting
photo or forty, and erasing a person really does remove every byte the file held about them - their
photo was never in it.

What it costs, and the cost is real: **a `.ocpt` sent to a colleague arrives without its images.**
That is the honest weakness of this option and it is accepted for this step, on the grounds that
sharing a project at all is a later feature (ADR 0009) which will have to answer the question of
what travels with a project anyway, and will answer it for assets at the same time.

The second cost is that **a restored version can restore a dangling reference.** A version payload
carries the `assets` rows, not the files, so restoring a version from a machine whose photos have
since moved brings back a row pointing nowhere. This is the same "file not found" state, reached a
different way, and it is why that state had to be a first-class one rather than an error dialog.

The follow-up work this creates is bounded on purpose: because the table isolates the question
behind an id, moving to blobs or to a bundle later is a change to the service that resolves an
asset, plus a migration that fills in the new storage - not a rewrite of the eleven tables that
reference assets by id. Nothing outside that service may read `assets.path` directly, or that
property is lost.

Two constraints on future changes follow from it. The app must never assume a referenced file is
still there, at any call site, at any time - the check is per read, not per open. And any feature
that starts writing files of its own beside the project (a generated release document, an export
cache) must not be built on this table without revisiting the decision: `assets` describes files the
app does not own.

## Alternatives considered

- **Blobs inside the `.ocpt`**: the project stays whole when it is sent, which is exactly what the
  reference option loses. Rejected because it puts megabyte columns into a schema whose sync design
  carries per-column edits, would need those columns excluded from replication and from version
  payloads by hand, and would grow the file by every version that captured them.
- **A project bundle** (a directory holding the `.ocpt` plus an assets folder, or the `.ocpt`
  becoming one): the right long-term answer, and the one that would make a project self-contained
  and still small. Rejected for this step because it changes how every project is created, opened,
  saved, imported and exported, on every platform - a step of its own, not a paragraph of the
  resources mode.
- **Copying referenced files into a folder beside the project**, keeping paths relative to it: half
  a bundle, with the same reach into open/save/import/export and none of the guarantees, since
  nothing would keep the folder travelling with the file.
