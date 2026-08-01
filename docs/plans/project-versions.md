<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Step 20 — Project versions

This document is the implementation strategy for issue
[#20](https://github.com/borlnov/open_cine_prod_tools/issues/20). It is written for the Sonnet 5
agents that will build the feature, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. **Read the repository `CLAUDE.md` first** — this plan assumes
its architecture, ways of working, coding standards, licensing rules and verification gates, and
does not repeat them.

**This step comes after the shot list mode
([#19](https://github.com/borlnov/open_cine_prod_tools/issues/19))** and completes the mock-up that
step implemented: the `Versions` right-dock tab and the read-only preview banner were deliberately
carved out of it because they are a cross-cutting concern, not a mode. Nothing here is
screenplay-specific or shot-list-specific: versions are a property of the **project**.

## 0. Prerequisite — the sync-ready data model

**M1 of `docs/plans/collaboration-and-sync.md` ships before this step starts.** That milestone
([ADR 0010](../adr/0010-sync-ready-data-model-prerequisites.md)) turns every hard `delete()` into an
`isDeleted` tombstone, adds `sortKey` beside `position` as the real ordering key, and adds the
`row_field_versions` sidecar holding per-column version stamps. It takes schema **v3**; this step is
therefore schema **v4**.

That ordering is not a preference, it is what keeps this step from being written twice. Two things
here are new call sites against exactly the three properties ADR 0010 fixes:

- the payload codec (§4.2.1) freezes a column list in a format that is then stored inside users'
  `.ocpt` files, so a column added afterwards means a payload format migration;
- `restoreVersion` (§4.5) rewrites most of the project at once, and the obvious way to write it is
  a bulk delete-and-reinsert — which would be the single largest hard delete in the app.

Built before ADR 0010, both would have to be rewritten against it, and the versions already created
in users' files would need migrating. Built after, they are written once, correctly.

The rest of the collaboration plan (the changeset engine, M3 onwards) is **not** a prerequisite, but
this plan is written so that nothing in it has to be redesigned when that engine lands: §4.3 and
§4.5 call out where sync will attach.

---

## 1. Application context

### 1.1 What the app is

Open Cine Prod Tools is an open-source (Apache-2.0) suite of film-production tools: a Fountain
screenplay editor and a shot list, inside a workspace shell that hosts four production modes.
Storage is local only — one SQLite file per project (`.ocpt`, via drift). There are no accounts and
no network yet: everything in this step happens inside a single file on the user's disk. Sharing
that file between machines is the collaboration plan's job, not this one's — but the schema this
step builds on is already the sync-ready one, and §0 explains why that matters here.

### 1.2 Structure that matters here

- **`OcptProjectsManager`** owns the one project open at a time as an `OcptOpenProjectModel`
  (`path`, `name`, `primaryScreenplayId`, `database`), held in a
  `ValueKeeperWithStream<OcptOpenProjectModel?>` and exposed through `currentProject` /
  `currentProjectStream`. It also owns `OcptScreenplayService` and `OcptSceneIndexService` (and,
  after step 19, `OcptShotListService` and `OcptShotCoverageService`).
- **Every read and every write *the user drives* goes through `currentProject.database`.** Grep
  `editor_bloc.dart` for `project.database`: the bloc never holds a connection of its own. This
  single fact is what makes §4.3 possible, and it is the most important thing to know before
  reading this plan. Note the qualifier, added when this plan was reconciled with the sync
  strategy: once `OcptSyncManager` exists it applies incoming changesets to the project **file**
  whether or not the user is previewing a version, so it is the one component that must not read
  its database off the open-project model's active slot. §4.3 gives it a slot of its own rather
  than leaving it to find out the hard way.
- **`OcptProjectDatabase`** already has a `.memory()` constructor (used by tests) alongside its
  file-backed one.
- **`project_info`** is a single-row header table (`id` always 1) carrying `name`, `createdAt`,
  `appVersionAtCreation`, `pageFormat` and a free-form `settingsJson`.
- **Snapshots.** `screenplay_snapshots` already exists and is **not** what this step is about; see
  §3.1.
- **Workspace shell.** `OcptWorkspaceShell` is a stateless slot widget; the end of its toolbar is
  shell-owned chrome (mode label, dock toggles, save, `⋮`). `WorkspacePage` builds the active mode
  and hosts the bottom mode switcher outside every mode's shell.
- **BLoC.** ACT pattern, one bloc per page. Modes own their own bloc (`OcptEditorBloc`,
  `OcptShotListBloc`) and react to `OcptProjectsManager.currentProjectStream`.

### 1.3 Toolchain reminder

The host has **no usable Flutter SDK**. Every Flutter/Dart/`reuse` command runs in the
devcontainer:

```bash
cd .devcontainer && docker compose run --rm dev bash -lc 'cd /workspaces/open_cine_prod_tools && <command>'
```

Git commands run on the host, from the repo root.

---

## 2. Why this step exists

A director rewrites. A production asks for "the version we read in July". An AD wants to know what
the shot list looked like before the rewrite that invalidated half of it. Today the app can answer
none of that: the only history it keeps is a rolling, invisible, screenplay-only safety net capped
at 30 entries.

This step adds **named, permanent, project-wide checkpoints** the user creates on purpose, can
browse read-only without disturbing the working copy, and can come back to.

---

## 3. The design being implemented

The reference is the *OpenCineProdTools App Design* mock-up in the Claude Design project
`5bc089e5-85ae-42c2-b8c4-445abc90ecf4`. Where this plan and the mock-up differ, **this plan wins**
— the differences are recorded in §3.5.

### 3.1 Versions are not snapshots

These two coexist and must not be conflated. State the difference in the doc comments of both.

| | `screenplay_snapshots` (exists) | `project_versions` (this step) |
| - | - | - |
| Created by | the app, automatically | the user, explicitly |
| Trigger | project open, save, before export, before import | a button |
| Scope | one screenplay's Fountain text | the whole project: screenplays, scene index, shot list, coverage |
| Named | no, just an `OcptSnapshotReason` | yes, plus a free-text note |
| Lifetime | rolling, pruned past 30 | permanent until the user deletes it |
| Visible | no | yes, its own dock tab |
| Purpose | crash/mistake recovery | production history |

Snapshots are untouched by this step.

### 3.2 The `Versions` tab

A third tab in the right dock, available in **every** mode (the mock-up shows it next to
`Inspector` and `Metadata`). Header `Project versions`, and under it the line that explains the
whole feature: **"A version covers the screenplay and the shot list together."**

Then a `Create a version` button, and the list of version cards, newest first. Each card:

- a status dot, the version name, and a badge — `Current` for the one the working copy descends
  from, `Preview` for the one being previewed;
- the creation date and the free-text note;
- for the current one: `State loaded in the editor`;
- for any other: `Click the card to view this version read-only`, plus a `Restore this version`
  button and a `Delete` button;
- `Delete` opens an inline confirmation inside the card — `Permanently delete this version? This
  cannot be undone.` with `Delete` / `Cancel` — rather than a dialog.

### 3.3 Preview mode

Clicking a non-current card enters preview. Then:

- a `Read only` pill appears in the toolbar next to the project name, and the unsaved-changes dot
  disappears;
- a full-width warning-coloured banner sits between the toolbar and the docks row:
  `Read only — v3 — Before the seq. 1 rewrite`, and under it
  `Yesterday, 18:42 · 41 pages · 3 sequence(s) broken down`, with two buttons —
  `Start from this version` (fork) and `Back to the current version` (exit);
- every editing affordance in every mode is gone: the save control, the format controls, the
  `⋮` entries that mutate (import & replace, page setup, title page), the shot list's `+ Shot`,
  its character chips, its coverage editing, its deleted-character banner actions.

Preview survives switching modes: it is a property of the project, not of the page.

### 3.4 Version cards' summary line

The mock-up shows `41 pages · 3 sequence(s) broken down` in the preview banner. Those counters are
computed **once, when the version is created**, and stored with it — never recomputed by
deserializing every payload to draw a list.

### 3.5 Decisions

Decisions 1 to 9 were settled with Benoit before this plan was finalised; 10 to 13 were added when
the plan was reconciled with the collaboration strategy. They are not open questions.

| # | Decision |
| - | -------- |
| 1 | **A version stores a full payload copy, not a diff and not shadow tables.** One row, one serialized snapshot of the whole project state. See §4.2. |
| 2 | **The payload includes the `scenes` rows verbatim, ids and all.** Restoring must never re-derive the scene index from the restored text: that would mint fresh UUIDs and silently break every `shots.sceneId` and `shot_coverages.sceneId` reference in the same payload. This is the single subtlest constraint in this step. |
| 3 | **Previewing never touches the project file.** The payload is hydrated into an in-memory `OcptProjectDatabase` and the manager hands *that* to the modes. See §4.3. |
| 4 | **Snapshots are not part of a version's payload.** They are a rolling safety net, not history, and copying 30 full screenplay texts into every version would multiply the file size for nothing. |
| 5 | **Versions are never pruned automatically.** Unlike snapshots, only the user deletes them. |
| 6 | **Restoring first auto-creates a safety version of the working copy**, named `Before restoring <name>`, so a restore can itself be undone. It appears in the list like any other version. |
| 7 | **In preview, the screenplay mode renders the read-only formatted preview, not an editor.** Reusing `OcptEditorPreview` costs nothing; making the styled editor read-only would mean a second super_editor rendering path (`SuperReader`, its own stylesheet, its own title-page components) to maintain forever. |
| 8 | **There is no author field, but the row records `createdByDeviceId`.** The app has no accounts and no identities, and a version must not pretend otherwise: nothing in the UI names a person. Decision 8's original revisit condition — "if the project ever becomes multi-user" — is however already met by the collaboration strategy, and ADR 0010 mints a `deviceId` at first launch anyway, so the column is added now, unused by the UI. Adding it later would cost a payload format instead. |
| 9 | **The payload carries the full page setup — page format *and* margins.** Restoring a version restores the pagination it was written against, so the page count shown on its card stays true. See §4.2.2 for the consequence this has, since the margins are an app-wide preference rather than project data. |
| 10 | **`project_versions` is a local table and is never synchronised.** Versions are one person's working history of their own replica, payloads are hundreds of kilobytes each, and pushing them through a changeset log would dominate the sync traffic for no collaborative gain. `project_info.currentVersionId` is local for the same reason: a restore on one machine must not silently move another machine's pointer. Sharing a version between people is what exporting a project file is for, and it is out of scope (§6). |
| 11 | **Restoring writes tombstones and version stamps like any other edit — it never hard-deletes.** ADR 0010 forbids the hard delete, and a restore that skipped the per-column stamps would be undone at the next merge by a replica whose stamps are higher. See §4.5.1: this is the single subtlest consequence of combining the two features, and it applies from the moment the schema has tombstones, long before any sync engine exists. |
| 12 | **The payload carries `row_field_versions` for the rows it carries.** Restoring rewinds the data, so it must rewind the stamps with it; leaving the stamps at their working-copy values would let a merge treat restored columns as older than an edit the restore was meant to supersede. They are cheap — the payload already carries every row those stamps describe. |
| 13 | **The payload codec migrates old formats, it does not only reject unknown ones.** A payload lives inside a user's `.ocpt` for as long as the version does, so the format outlives the app build that wrote it. The codec upgrades any format it knows to the current one on decode, and rejects only formats from the *future*. See §4.2.3. |

---

## 4. Architecture

### 4.1 Overview

```text
lib/models/database/tables/     ocpt_project_versions_table.dart
lib/models/database/            ocpt_project_database.dart          (schema v3 + migration)
                                ocpt_project_info_table.dart        (+ currentVersionId)
lib/models/                     ocpt_project_version.dart
                                ocpt_project_version_payload.dart
                                ocpt_project_version_summary.dart
                                ocpt_open_project_model.dart        (+ isReadOnly, previewedVersion)
lib/managers/projects/services/ ocpt_project_versions_service.dart
                                ocpt_project_version_codec.dart
lib/managers/projects/          ocpt_projects_manager.dart          (+ preview state)
lib/ui/pages/workspace/widgets/ ocpt_project_versions_panel.dart
                                ocpt_project_version_card.dart
                                ocpt_workspace_read_only_banner.dart
                                ocpt_workspace_shell.dart           (+ banner slot, read-only pill)
```

### 4.2 Database — schema v4

**`project_versions`** (`@DataClassName('OcptProjectVersionRow')`)

| Column | Type | Notes |
| ------ | ---- | ----- |
| `id` | text, PK | UUID |
| `name` | text | user-facing, e.g. `v4 — Shot list seq. 1 to 3` |
| `note` | text | free description, may be empty |
| `createdAt` | dateTime | `storeDateTimeAsText` is on project-wide, so sub-second precision is kept and two versions created in the same second still order correctly |
| `appVersion` | text | the app version that created it |
| `payloadFormat` | int | the payload's own format version, **independent of the drift schema version** |
| `payload` | text | the serialized project state, §4.2.1 |
| `summaryJson` | text | the counters of §3.4 |
| `createdByDeviceId` | text | the `OcptPropertiesManager.deviceId` of the replica that created it, decision 8 — recorded, never shown |

The table is **local**: no `isDeleted`, no `sortKey`, no `row_field_versions` stamps, and it is
absent from the synchronised set (decision 10). Say so in its doc comment, next to the sentence
distinguishing it from `screenplay_snapshots`, so the next person adding a table does not copy the
wrong precedent.

**`project_info`** gains `currentVersionId` (text?, nullable, references `project_versions.id`):
which version the working copy descends from. Null in a project that has never had one. Local as
well, for the reason decision 10 gives.

**Migration.** `schemaVersion` goes from 3 (the sync-ready data model, §0) to 4: `onUpgrade` creates
`project_versions` and adds the `currentVersionId` column. Additive only, like the two before it.
Its test starts from a **v3** database, and — since drift replays migrations in order — from a v1
and a v2 one as well, checking each lands on the same v4 shape with every pre-existing row intact.

#### 4.2.1 The payload

`OcptProjectVersionCodec` (`lib/managers/projects/services/`) is the **only** place that knows the
payload's shape. It encodes to and decodes from a plain JSON object:

```text
{
  "payloadFormat": 1,
  "screenplays":      [ { id, title, fountainText, updatedAt }, … ],
  "scenes":           [ { id, screenplayId, position, heading, sceneNumber,
                          charStart, charEnd, isDeleted }, … ],
  "shots":            [ … every column of the shots table, isDeleted and
                          sortKey included … ],
  "shotCharacters":   [ { shotId, characterName, position, sortKey,
                          isDeleted }, … ],
  "shotCoverages":    [ { id, shotId, sceneId, startOffset, endOffset,
                          coveredTextDigest, isDeleted }, … ],
  "rowFieldVersions": [ { tableName, rowId, columnName, version,
                          deviceId }, … ],
  "projectSettings":  { pageFormat, settingsJson },
  "pageMargins":      { … the OcptPropertiesManager.pageMargins value … }
}
```

Rows are stored **verbatim, with their primary keys** — see decision 2. Encoding is one query per
table; decoding is one bulk insert per table inside a single transaction.

Three of those fields exist because of ADR 0010, and each is load-bearing:

- **`isDeleted`** — tombstones are rows, so a version that carried only the live rows would
  resurrect, on restore, everything the user had deleted since. The payload carries the tombstones
  and the restore reinstates them as tombstones.
- **`sortKey`** — after ADR 0010 this, not `position`, is what orders a group. A payload that
  carried `position` alone would restore a shot list in an undefined order. `position` stays in the
  payload only because it is still a column; `sortKey` is what the restored rows are ordered by.
- **`rowFieldVersions`** — decision 12. Scoped to the rows the payload carries, so it is encoded by
  joining on those ids rather than dumping the whole sidecar table.

The codec must round-trip: `decode(encode(state))` equals `state`, tested directly — including the
stamps, which is the test that catches a codec silently dropping the sidecar.

Payloads are stored as plain JSON text. A 120-page screenplay is roughly 150 KB, so fifty versions
of a finished feature land in single-digit megabytes — acceptable for a local file. Compression is
a later optimisation, and the `payloadFormat` field is what would allow it without breaking old
files.

#### 4.2.2 The page setup, which is not entirely project data

Decision 9 puts the whole page setup in the payload, and that crosses a boundary worth naming
rather than glossing over. `OcptPageSetup` pairs two things of different natures: the page format,
which is project data (`project_info.pageFormat`), and the margins, which are an **app-wide
rendering preference** (`OcptPropertiesManager.pageMargins`) shared by every project on the
machine.

So restoring a version writes a preference that has nothing to do with this project file. That is
the accepted cost of having a version's page count stay true, and it must be handled deliberately:

- **On preview, nothing is written.** The previewed payload's page setup travels on the preview
  state and is used for rendering only. A preview never touches the user's preferences, exactly as
  it never touches the project file — and a crash mid-preview therefore cannot leave the app
  paginating against a version's margins.
- **On restore, the margins are written through `OcptPropertiesManager` only after the database
  transaction has committed.** They are not part of the transaction and cannot be rolled back with
  it, so writing them first would leave the app's margins pointing at a restore that failed.
- The restore confirmation says so plainly: restoring also restores the page setup.

Every call site keeps going through `OcptPageSetup.toMetrics()`; what changes is where the
`OcptPageSetup` being rendered comes from when a version is previewed.

#### 4.2.3 Payload formats outlive app builds

A payload sits in a user's `.ocpt` for as long as the version does, so the build that reads it is
rarely the build that wrote it. `payloadFormat` therefore has to be a **migration path, not just a
guard** (decision 13):

- decoding a format **older** than the current one upgrades it in memory, field by field, and the
  upgraded payload is what gets restored — a stored payload is never rewritten in place, so a
  version stays byte-identical to what was captured;
- decoding a format **newer** than the current one — a file touched by a later build — fails with a
  clear localised error naming the app version, rather than half-restoring a project;
- every upgrade step is a named function with its own test, and the fixtures of retired formats are
  kept: the point of the field is lost if nothing ever exercises the old branch.

Format 1 is the shape of §4.2.1, which already contains the ADR 0010 columns. The first upgrade step
this will need in practice is the next column any synchronised table gains — the codec's column list
is a hand-written mirror of the schema, and reviewers should treat "a table gained a column" as "the
codec and its payload format need looking at".

### 4.3 Preview — the in-memory database swap

This is the core of the step, and it is small because of §1.2's second bullet.

Everything in the app reads and writes through `currentProject.database`. So previewing a version
does **not** need any mode to learn a second data path. Instead:

1. `OcptProjectsManager.previewVersion(id)` loads the row, decodes its payload, opens an
   `OcptProjectDatabase.memory()`, and hydrates it from the payload.
2. It then emits a **new `OcptOpenProjectModel`** on `_currentProject` — same `path`, same `name`,
   same `primaryScreenplayId`, but whose `database` is the in-memory one and whose new
   `isReadOnly` flag is true, carrying the previewed `OcptProjectVersion` alongside.
3. Every mode's bloc already reacts to `currentProjectStream`: they reload and render the version.
   No mode learns anything new about versions to display one.
4. `exitPreview()` closes the in-memory database and re-emits the real, file-backed model.

The project file is never opened for writing during a preview, and a crash mid-preview leaves it
exactly as it was.

#### 4.3.1 The model carries two databases, not one

The swap above works because the app has exactly one writer. `OcptSyncManager` will be a second
one, and it writes to the **project file** on its own schedule — a changeset arriving while the user
is reading a version has nothing to do with that version and must land in the working copy.

So `OcptOpenProjectModel` gets two slots rather than one substituted:

- **`database`** — what the modes read and what the user's edits go through. The memory database
  while previewing, the file one otherwise. Every existing call site keeps compiling and keeps
  meaning what it meant.
- **`fileDatabase`** — always the file-backed connection, never swapped, never closed by
  `previewVersion`. Outside a preview the two are the same instance.

Nothing in this step reads `fileDatabase` except `OcptProjectVersionsService` itself, which must
create, list, delete and restore versions against the real file even while a preview is on screen
(deleting a version you are not previewing is legitimate mid-preview). It exists mainly so that the
sync engine has a correct slot to attach to instead of forcing this design open later — a two-field
model now costs one field and a doc comment; retrofitting it after three modes and a sync manager
read `database` costs an audit of every call site.

`previewVersion` therefore opens the memory database **in addition to** the file one, and
`exitPreview` closes only the memory one.

Two further consequences to handle explicitly:

- **`OcptOpenProjectModel.props`** currently excludes `database` from equality. `isReadOnly` and
  the previewed version's id **must** be part of it, or entering preview would emit a model that
  compares equal to the previous one and no bloc would rebuild.
- **A pending autosave must be flushed before entering preview**, exactly as the editor already
  flushes on `deactivate()`. Entering preview while a 2 s debounce is in flight would otherwise
  write the working copy's text into… the memory database, and lose it. `previewVersion` therefore
  refuses to run while any mode reports itself dirty, and the UI saves first.

### 4.4 Read-only propagation

`OcptOpenProjectModel.isReadOnly` is the single source of truth. It reaches the UI through the
stream each mode's bloc already listens to, so each mode's state gains an `isReadOnly` field and
gates its own affordances — no new cross-widget plumbing, no `InheritedWidget`, no global.

The service layer defends itself too: every mutating method of `OcptScreenplayService`,
`OcptShotListService` and `OcptShotCoverageService` is a no-op that logs a warning when handed a
read-only project. A UI bug must not be able to corrupt a preview into the working copy.

**What `isReadOnly` means, precisely: the user may not edit what is on screen.** It is not a global
write lock on the project, and the difference matters the moment sync exists. A merge applying an
incoming changeset is not a user edit, it targets `fileDatabase` (§4.3.1), and it must go through
whether or not a preview is up — a read-only gate that swallowed it would drop another person's
work silently, which is the worst failure mode this design has. The gate is therefore expressed as
"this call was handed the preview database", not "this project is currently read-only", and
`OcptChangesetService` never passes through it. State this in the doc comment of every guard, or
someone will eventually reuse the flag for the wrong thing.

`OcptWorkspaceShell` gains exactly two things — the only changes this step makes to it:

- an optional `banner` slot rendered between the toolbar and the docks row, and
- a `isReadOnly` flag that makes the toolbar show the `Read only` pill instead of the dirty dot.

Modes pass both from their own state. `OcptWorkspaceReadOnlyBanner` is built once, under
`workspace/widgets/`, and used by every mode.

### 4.5 Service and operations

`OcptProjectVersionsService`, owned by `OcptProjectsManager` alongside its existing services:

| Operation | Behaviour |
| --------- | --------- |
| `listVersions` | newest first, **without** deserializing payloads — cards render from `summaryJson` |
| `createVersion(name, note)` | encodes the working copy, computes the summary, inserts, sets `project_info.currentVersionId` |
| `restoreVersion(id)` | auto-creates the safety version of decision 6, then applies the payload in one transaction as §4.5.1 describes — tombstones and version stamps, never a hard delete — and sets `currentVersionId`; once that has committed, and only then, writes the payload's margins through `OcptPropertiesManager` (§4.2.2) |
| `forkFromVersion(id)` | `restoreVersion` followed by `createVersion`, so the new branch point is itself a named entry |
| `deleteVersion(id)` | refuses to delete the version currently being previewed; clears `currentVersionId` if it pointed there |

Preview and exit-preview live on `OcptProjectsManager` rather than the service, because they mutate
the manager's open-project state rather than the database.

`restoreVersion` is the one destructive operation in the app that is not a file deletion. It must
be transactional, tested against a project that has diverged substantially from the version being
restored, and it must leave the app on a consistent state even if the modes were showing stale
data: after it completes, the manager re-emits the project model so every mode reloads.

#### 4.5.1 A restore is an edit, not a reset

The obvious implementation — delete every row of the payload's tables, bulk-insert the decoded ones
— is wrong twice over once ADR 0010 has landed, and both failures are silent.

**It hard-deletes.** ADR 0010 turned deletion into an `isDeleted` update precisely so a replica that
was offline can learn a row is gone. A row hard-deleted by a restore leaves no trace to merge, so a
replica that still has it re-inserts it.

**It leaves the version stamps behind.** `row_field_versions` is what decides, per column, whose
value wins. Rewriting a column's value without bumping its stamp means the restored value carries an
older version than the edit it was meant to supersede — so the next merge cheerfully replaces the
restored project with the state the user had just deliberately abandoned. The restore appears to
work, and is undone minutes later by a device nobody touched.

The restore therefore expresses itself in the same vocabulary as any other write, inside one
transaction, with `PRAGMA defer_foreign_keys = ON` (ADR 0010 — the payload's rows legitimately
arrive in an order that violates a foreign key part way through):

1. **Rows in the payload, absent from the working copy** — insert, and stamp every column.
2. **Rows in both** — update, column by column, and bump the stamp of each column whose value
   actually changes. A column that already matches the payload is not touched and not stamped:
   this is what keeps a restore from stomping an unrelated concurrent edit that happened to agree.
3. **Rows in the working copy, absent from the payload** — set `isDeleted`, and stamp it. Not
   deleted.
4. **Rows the payload carries as tombstones** — reinstated as tombstones, same as any other row.

Stamps are written with the local `deviceId` and a version strictly above the highest the row's
column currently holds, so a restore reads to every other replica as what it is: a deliberate, most
recent edit.

`scenes` is the one exception, and it needs none of this: ADR 0010 keeps it out of the merge
entirely, so its rows are replaced outright — verbatim, ids included, per decision 2, which is
exactly what stops the restored `shots.sceneId` references from dangling.

Two more obligations, both easy to miss:

- **Snapshot the screenplay at the restore point.** `screenplays.fountainText` is not merged
  column-wise: ADR 0010 reconciles it by a three-way line merge against the nearest common
  `screenplay_snapshots` row. A restore replaces the whole text in one write, so without a snapshot
  taken at that moment the merge base skips the discontinuity and the three-way merge reconciles
  against text that never existed on this replica. `restoreVersion` writes a snapshot before
  applying the payload, with a reason of its own added to `OcptSnapshotReason`. Note this is
  unrelated to decision 6's safety *version* — different table, different purpose, both needed.
- **Publishing the restore.** Once the relay exists (M4 of the collaboration plan), a restore is
  also the ideal moment to use its *upload a snapshot* route: it is by definition a complete,
  self-consistent project state, and it lets the relay prune the changesets below it. That wiring
  belongs to the collaboration plan, not here; what this step owes it is that steps 1-4 above leave
  the database in a state that is already correct without it.

### 4.6 UI

- `OcptProjectVersionsPanel` + `OcptProjectVersionCard` under `workspace/widgets/`, shared by every
  mode's right dock.
- `OcptEditorRightDockTab` and `OcptShotListRightDockTab` each gain a `versions` case; the panel
  itself is mode-agnostic.
- Create opens a small dialog (name + note) through `OcptRouterManager` — **never** `Navigator`.
- Delete confirms inline inside the card, as §3.2 describes, with the confirming card's id held in
  the mode's state.

Colours come from the `ColorScheme`; the warning-coloured banner and `Preview` badge reuse the
same tokens the shot list's `Needs checking` callout already uses.

---

## 5. Milestones

Each ends with the full verification gate of `CLAUDE.md`, one commit per logical change, and a user
checkpoint.

### M1 — Schema, payload codec, service

`project_versions` (with `createdByDeviceId`), the `currentVersionId` column, schema v4 and its
migration, `OcptProjectVersionCodec`, `OcptProjectVersionsService` with list/create/delete. No UI.

Tests: migration from a v3 database preserving everything, and from v1 and v2 through the replayed
chain; codec round-trip **including `isDeleted`, `sortKey` and the `rowFieldVersions` stamps**;
codec upgrading a format older than the current one; codec rejecting a format newer than it knows;
scene ids surviving encode/decode identically; create/list/delete.

### M2 — Preview infrastructure

`isReadOnly` on `OcptOpenProjectModel` (equality included), the `fileDatabase` slot of §4.3.1,
`previewVersion` / `exitPreview` on `OcptProjectsManager`, the memory-database hydration, the
dirty-refusal of §4.3, the read-only no-ops in the three mutating services, and the previewed page
setup travelling on the preview state without ever being written (§4.2.2).

Tests: entering preview emits a model that is not equal to the previous one; the file database is
untouched after a preview cycle; `fileDatabase` stays the same open connection across a full
preview cycle and is still usable for writing during the preview; a mutating service call on a
read-only project changes nothing; a full preview cycle leaves `OcptPropertiesManager.pageMargins`
exactly as it was.

### M3 — The versions panel

The `versions` tab in both modes, `OcptProjectVersionsPanel`, `OcptProjectVersionCard`, the create
dialog, the inline delete confirmation. Preview is enterable and exitable from the cards.

### M4 — Read-only across the app

The shell's banner slot and `Read only` pill, `OcptWorkspaceReadOnlyBanner`, and the gating of
every affordance listed in §3.3, in both the screenplay and shot list modes. Decision 7 is
implemented here.

### M5 — Restore and fork

`restoreVersion`, the safety version, `forkFromVersion`, the post-commit margins write of §4.2.2,
the two banner buttons, and the card's `Restore this version`.

The most dangerous milestone: it is where the tests matter most. Restore against a project that has
diverged substantially from the version; restore leaving the working copy internally consistent
(no `shots.sceneId` pointing at a scene the payload did not carry); a failed transaction leaving
both the database *and* the margins untouched; the safety version being restorable in turn.

The §4.5.1 obligations get their own tests, because every one of them fails silently:

- a row present in the working copy but not in the payload ends up **tombstoned, not deleted**, and
  its `isDeleted` stamp is bumped;
- every column whose value the restore changed comes out with a stamp strictly above what it held
  before, carrying the local `deviceId`;
- a column whose value already matched the payload is left unstamped;
- a restore writes a `screenplay_snapshots` row before touching `screenplays.fountainText`;
- `scenes` rows come back with the payload's ids, and no `shots.sceneId` dangles afterwards.

---

## 6. Out of scope

Multiple named branches, or any tree-shaped history: versions are a flat, chronological list with a
`current` pointer. Diffing two versions. Merging. Any per-mode version (a version is always the
whole project). Exporting or importing a version as a file.

Anything that puts a version on a network: sharing the version list between replicas, publishing a
payload through the relay, or naming the person who created one in the UI — decisions 8 and 10.
What this step *does* owe the collaboration plan is a working copy that is correct to merge after a
restore (§4.5.1); what it does not owe it is a single line of sync code.
