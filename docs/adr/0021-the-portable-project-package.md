<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0021 - The portable project package

## Status

Accepted

## Context

A project is one SQLite file (ADR 0001) the user handles as a document, and a `.ocpt` holds **no
bytes of anything it references**: a headshot, a scouting photo, a filming permit and a signed
release are `assets` rows carrying an absolute path on the machine that recorded them (ADR 0013).
Copying that file to a colleague therefore delivers a project whose every reference dangles. The app
draws that honestly — a missing file is a first-class state, not an error — which is the right
behaviour for a photo somebody moved and the wrong one for a project that was *sent*. ADR 0013 said
so itself and deferred the question: "sharing a project at all is a later feature which will have to
answer what travels with a project anyway". This is that answer for the case that exists today, a
file somebody carries; the relay of ADR 0009 is a different question with a plan of its own.

Three properties of the file constrain how it can be packaged:

- **It is open.** Packaging a project from inside the workspace means reading a database another
  connection holds, with a write-ahead log that may still carry the last few seconds of work.
  Copying the file bytes underneath the running app is the bug that only ever appears on somebody
  else's machine.
- **It may be at another schema version.** Sending a project must not be what migrates it, so
  nothing on this path may hand the file to drift — `onUpgrade` would run as a side effect of an
  export (ADR 0007, and ADR 0022 for what opening one properly looks like).
- **It carries erasures.** Erasing a person blanks their personal columns and records their id in
  `local_erasures`; a version payload sealed *before* that erasure still holds the full row, and
  `OcptProjectVersionsService._scrubErasedPeople` reading that table at decode time is the only
  thing keeping a restore from resurrecting them.

## Decision

A project travels as a **portable project package**: one zip, extension **`.ocptz`**, written and
read by `OcptProjectPackageService` (`lib/managers/projects/services/`) through
`package:archive` — promoted from a transitive dependency to a direct one — streamed to disk with
`ZipFileEncoder`/`InputFileStream` and never assembled in memory.

```text
<name>.ocptz
├── manifest.json         ← packageFormat, appVersion, schemaVersion, projectName, exportedAt,
├── project.ocpt          ← fixed name; the display name lives in the manifest
└── assets/<assetId>/<original file name>
```

- `manifest.json` is versioned by **`packageFormat`**, independently of the database schema and on
  the model of `OcptProjectVersionCodec`'s `payloadFormat`: an older format is upgraded on read
  (`_packageManifestUpgrades`, empty at format 1), a newer one is refused with
  `OcptProjectPackageStatus.unsupportedPackageFormat` rather than half-read.
- The `.ocpt` inside is produced by SQLite's own **`VACUUM INTO`**, not a file copy: one consistent
  single file out of an open database, whatever the WAL still holds folded in, and `user_version`
  preserved. The source is opened **read-only** — an export never writes the user's project file,
  not even to checkpoint it.
- **Everything works from a file path, never from an open database**, and nothing in the service
  imports drift. That is what lets one code path serve a project open in a mode and a project card
  on the home page, and what keeps a package built from an older file from migrating it.
- **A missing referenced file is reported, then skipped.** `scanAssets` stats every live `assets`
  row before a byte is written; when some are gone the caller asks through `OcptConfirmDialog`,
  naming the count and the labels. Continuing is the ordinary answer: those rows are recorded in the
  manifest as `skippedAssets`, and the **import reports them again** as the project lands.
- A packaged asset's row is rewritten to its entry inside the archive, and the import rewrites it
  onto where the file now sits. A **skipped** one keeps its original path, which is what lets either
  end name what is missing.
- **`project_versions` travel, scrubbed.** On the staged copy and only there, every stored payload
  is rewritten with the erased people taken back out (`ocptScrubErasedPeopleFromPayload`,
  `lib/utils/`), `content_digest` nulled on the rows actually touched, and `local_erasures` emptied.
- An import creates `<project name>/` inside a parent folder the user picks, holding the `.ocpt` and
  its `assets/`. A folder of that name already there is **refused**, never merged or overwritten.

## Consequences

The rule that a version payload is never rewritten once captured still holds: it is about the
project file, and the live file is not touched — the copy is a new artifact whose history is the
truth minus what was erased. Shipping the payloads with the table instead of applying it would have
left a phone number, an address and an allergy for somebody who asked to be removed one `sqlite3`
prompt away on the recipient's machine, which is not erasure.

The costs are real. A scrubbed version row travels **without its `contentDigest`**: recomputing one
would mean restating the codec's canonicalisation in a file that deliberately knows nothing about
the schema, so it is nulled, and null reads as "unknown", which the app treats as *modified* — the
fail-safe direction, at the price of a restored-from version looking drifted on the recipient's
machine. The whole history travels, so a project with forty sealed versions and two hundred scouting
photos makes a large package; the alternative was handing a colleague a project that cannot go back.
And the erasure rule now has a **third implementation** — the live row, the decoded payload, the
stored JSON — kept in step by a test that walks every key the codec writes for a person and fails
unless this file classifies it, rather than by hand.

Two constraints follow for future changes. Nothing on the package path may reach for drift, or the
"an export never migrates what it sends" property is lost silently. And a new synchronised table
carrying personal data has to be considered by the scrub as well as by the codec: the test catches a
new `people` column, not a new table.

The import does **not** re-identify anything: no new project id, no new `deviceId` (the device id is
a property of the replica, not of the project). Two people importing the same package hold two
independent projects, which is what today's storage model says. Sync is what will make that question
real, and it has a plan of its own.

## Alternatives considered

- **A single-file container** (the assets folded into the `.ocpt` as blobs on the way out): would
  make the package one file rather than an archive, at the cost of a bespoke format only this app
  reads, and of writing the very megabyte columns ADR 0013 kept out of the schema.
- **A tar**: streams as well and reads worse on Windows, where a recipient double-clicking the file
  is the ordinary case.
- **Blocking an export until every referenced file is found**: one photo moved six months ago would
  be enough to stop a project being sent, with no repair path in the app to offer instead.
- **Copying the `.ocpt` bytes** rather than `VACUUM INTO`: cheaper, and wrong for an open database
  whose WAL holds writes the copy would not carry.
- **Shipping `local_erasures` with the package** and letting the recipient's build apply it: it
  would work exactly until somebody read the file with anything that is not this app.
- **Overwriting an existing destination folder on import**: the one destructive act this feature
  could have had, over what is somebody's project, to save picking another folder.
