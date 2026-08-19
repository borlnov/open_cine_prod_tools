<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# A project travels — the portable package, and opening a foreign file

This document is the implementation strategy for [issue #59][issue]. It is written for the Sonnet 5
agents that will build it, orchestrated and reviewed by the main session, with a user checkpoint
between each milestone. **Read the repository `CLAUDE.md` first** — this plan assumes its
architecture, ways of working, coding standards, licensing rules and verification gates, and does
not repeat them.

It sits on top of three decisions already argued elsewhere, and when this plan and one of them
disagree, the ADR wins: [ADR 0013][adr13] (a binary asset is referenced by path, never embedded),
[ADR 0007][adr7] (what a schema number means and when it is allocated) and [ADR 0010][adr10] (no
service deletes a synchronised row).

[issue]: https://github.com/borlnov/open_cine_prod_tools/issues/59
[adr7]: ../adr/0007-schema-migration-policy.md
[adr10]: ../adr/0010-sync-ready-data-model-prerequisites.md
[adr13]: ../adr/0013-binary-assets-referenced-by-path.md

---

## 1. Why this step exists

Three things work by accident today.

**Handing a project to somebody else.** The `.ocpt` holds no bytes — a headshot, a scouting photo,
a filming permit and a signed release are `assets` rows holding an **absolute path on the machine
that recorded them** (ADR 0013). Copying the file to a colleague therefore delivers a project whose
every reference dangles. The app draws that honestly ("file not found"), which is the right
behaviour for a moved file and the wrong one for a project that was *sent*.

**Reopening a file made by an older build.** It already works: drift's `onUpgrade` migrates it on
the way in. But it happens silently, with no copy taken and nothing said, and the reverse case is
worse — a file written by a **newer** build than the one running is a case drift cannot handle.
`onUpgrade(m, from, to)` is called with `from > to`, every `if (from < N)` guard declines to run,
and drift then stamps `PRAGMA user_version` **back down** to the running build's number. The file
still holds the newer build's tables and columns while claiming to be old, and the next upgrade
runs its steps a second time. Verified against the shipped stack, not assumed.

**Saying so.** Importing a project and exporting one do not exist. Opening a path is not importing
a project, and it is all the app offers.

## 2. What travels, and what does not

| Content | Travels | Why |
| --- | --- | --- |
| The `.ocpt` itself | yes | it *is* the project |
| Every referenced file that still exists | yes, copied into the package | the point of the exercise |
| A referenced file that no longer exists | no, reported before and after | see below |
| `project_versions` | yes, **scrubbed** | the sealed history is part of the project |
| `screenplay_snapshots` | yes | ordinary rows of the copied database |
| `local_erasures` | **no** | see below |
| The recent-projects list, the theme, the margins | no | app preferences, never in the file |

**A missing referenced file is reported, then skipped.** The export runs a pre-flight pass over the
`assets` rows, and when any of them names a file that is gone, it asks through `OcptConfirmDialog` —
naming the count and listing the labels — before writing anything. Continuing is the ordinary
answer; the export then records those rows in the package manifest as *skipped*, and the **import
reports them again** as it lands. Blocking instead would make one photo moved six months ago enough
to prevent sending the project, with no repair path in the app to offer. A silent short package is
the call-sheet folder problem and is not on the table.

**No erased person may travel.** Erasing a person blanks their personal columns and records their id
in `local_erasures`; a version payload sealed *before* that erasure still holds the full row, and
`OcptProjectVersionsService._scrubErasedPeople` is what keeps a restore from resurrecting them —
it reads the table fresh at decode time. Shipping the payloads without the table would hand a
colleague a project whose history restores a phone number, a home address and an allergy for
somebody who asked to be removed, and no amount of care on their machine could know it. So the
export **bakes the scrub in**: on the copy it is about to package, and only there, it rewrites every
stored payload with the erased people scrubbed out, empties `local_erasures`, and packages that. The
"a version payload is never rewritten once captured" rule is not bent — the live file is not
touched, and the copy is a new artifact whose history is the truth minus what was erased.

The same copy is where the **asset paths are rewritten**: a path travelling verbatim would leak the
exporter's home directory layout, so a packaged asset's row is rewritten to its entry inside the
package and the import turns it back into an absolute path. A **skipped** asset keeps its original
path — the recipient's report has to be able to name what is missing, and the row is already drawn
as a dangling reference either way.

## 3. The package format

One zip, extension **`.ocptz`**, built with `package:archive` — today a transitive dependency
through `excel_community`, promoted to a direct one. It is streamed to disk
(`ZipFileEncoder` / `InputFileStream`), never assembled in memory: a project carrying two hundred
scouting photos is an ordinary case.

```text
<name>.ocptz
├── manifest.json
├── project.ocpt          ← fixed name; the display name lives in the manifest
└── assets/
    └── <assetId>/<original file name>
```

`manifest.json` is the package's own contract, and it is versioned **independently of the schema**,
exactly as `OcptProjectVersionCodec`'s `payloadFormat` is — that contract is the model for this one,
including its two directions: an older `packageFormat` is upgraded on read, a newer one is refused
with a message rather than a crash.

```jsonc
{
  "packageFormat": 1,
  "appVersion": "0.1.0",
  "schemaVersion": 19,          // the .ocpt's own PRAGMA user_version
  "projectName": "Les Vagues",
  "exportedAt": "2026-08-19T14:00:00.000",
  "assets": [{ "assetId": "…", "entry": "assets/…/photo.jpg", "originalPath": "/home/…" }],
  "skippedAssets": [{ "assetId": "…", "label": "Autorisation mairie", "originalPath": "/home/…" }]
}
```

The `.ocpt` inside is produced by SQLite's own **`VACUUM INTO`** rather than a file copy: it yields
one consistent single file from a database that is open, with whatever the WAL still holds folded
in, and it preserves `user_version`. Verified on the bundled SQLite 3.46.1 before this plan was
written. Copying the file bytes under the running app would have been the bug that only appears on
somebody else's machine.

**The whole export works from a file path, never from an open database.** That is what lets the same
service serve the two doors of §5 — a project open in the workspace and a project card on the home
page — and it costs nothing: the export reads and writes copies, and the only thing the open case
adds is flushing the mode's pending writes into the working copy first.

## 4. Opening a file from another build

The migration becomes a **stated step**, and the refusal a real one. Nothing may reach drift before
the file has been read:

1. **Probe.** `sqlite3.open(path, mode: OpenMode.readOnly)` reads `PRAGMA user_version` and, when
   the table is there, `project_info.appVersionAtCreation`. No drift, so no migration and no
   `user_version` write can happen as a side effect of looking.
2. **Newer than this build** → refused, with a dialog naming both numbers and the app version the
   file was created with. The file is not opened, not touched and not added to the recent list.
3. **Older than this build** → `OcptConfirmDialog` states which format the file is in, which one it
   is being brought to, that the change cannot be undone, and **where the copy will be kept**. On
   confirmation the manager writes that copy — `<name>.backup-v<n>.ocpt` beside the original, a
   counter appended if it exists — and only then hands the file to drift, whose `onUpgrade` runs as
   it does today.
4. **Same** → opened exactly as today, no dialog, no copy.

The backup keeps the original extension on purpose: it is a file the older build can still open,
which is the whole reason for taking it.

Every path that *opens* a project file goes through this gate — the home page's `Open…`, a recent
project card, and the import of a package built by an older build. **Exporting does not**: a package
carries the file at whatever format it is in (`VACUUM INTO` preserves `user_version`), and the
recipient's own gate is what states the migration. Exporting a project must not silently rewrite it.
The version *preview* and the *restore* are untouched too: they hydrate an in-memory database from a
payload the codec already version-checks.

## 5. Where the user finds this

Two gestures, and both reuse a control that already exists rather than adding a fourth kind of
button.

### 5.1 Export — the toolbar's own `Export` panel

`OcptWorkspaceExportDialog` is already the single answer to "what can I get out of this?": a grid of
cards, one per document, generic over the active mode's own export enum. **The project package
becomes a card in it**, in every mode, and the dialog itself owns that card rather than each mode
declaring it — the same reasoning that makes the end of the toolbar the shell's own chrome. Five
modes each adding a `projectPackage` value to their enum would let its wording, its position and its
availability drift apart mode by mode.

Mechanically the dialog stops returning a bare `T?` and returns a sealed
`OcptWorkspaceExportPick<T>` — `document(T)` or `projectPackage` — so the five call sites, which all
already `switch` on what was picked, gain one branch each. The card sits below the documents grid,
behind a divider and its own short heading, because it is not a document: nobody reads it, it is the
project itself.

Under a **version preview** the card is drawn **unavailable with a reason** rather than withheld —
arbitrated, and the one place the app's "withhold, don't disable" rule yields. The panel's own doc
comment is the argument: a card that disappears makes the panel lie about what exists, and this
panel is a statement of what the app knows how to produce. What the card would export is the working
copy on disk, which is not what the user is looking at; every other export under a preview writes
what *is* on screen, so leaving it clickable with a caveat would make it the odd one out in the one
way that matters. The reason on the greyed card says all of it. The ADR of M5 records this as an
exception with its argument, so it is not read later as a slip.

The handler lives in a new `MixinOcptProjectPackageBloc` / `MixinOcptProjectPackageState`, mixed into
the five mode blocs beside `MixinOcptProjectVersionsBloc` and declaring the **same
`flushPendingProjectWrites` hook** they already implement — a debounced field edit must reach the
working copy before it is packaged, exactly as it must before a version preview swaps the database
out. The mode opens `OcptConfirmDialog` when the pre-flight found missing files, and reports the
written path in a SnackBar, the way every other export outcome is reported; no bloc holds a `Tr`.

The **budget mode has no `Export` control and keeps none** — arbitrated, not an oversight. It has no
bloc by design, and neither of the two ways of giving it one was worth it: a bloc created for a mode
whose whole content is "coming in a future version" would be rewritten the day that mode arrives,
and routing its pick to `OcptWorkspaceBloc` instead would have the same action handled by two
different blocs depending on which mode the user is standing in. The stated cost is that the budget
mode is the one place in the app where the project package is one click further away.

### 5.2 Import — one `Import…` button on the home page, one modal

The home header's `Import a screenplay…` becomes a single **`Import…`** button opening a modal of
the same shape as the export panel: two cards, `A project` (`.ocptz`) and `A screenplay`
(`.fountain`), each with its own one-line description. The two gestures are named side by side where
somebody compares them, and the header keeps four controls instead of growing to five, two of which
would have started with the same word.

That means extracting the card grid: `OcptWorkspaceExportDialog`'s body moves to a generic
`OcptCardChoiceDialog` (+ `OcptCardChoiceEntry`) under `lib/ui/widgets/`, and the export panel
becomes its export-flavoured caller — keeping its title, its message, its unavailability semantics
and the standing project card of §5.1. Mechanical, and covered by the panel's existing widget tests.

Picking `A project` runs: pick the `.ocptz`, pick a **parent folder**, and the import creates
`<project name>/` inside it holding `<name>.ocpt` and `assets/`. A folder of that name already there
is a clear refusal, never an overwrite. The project then opens through the gate of §4 and the
workspace is pushed, exactly as the screenplay import already does, with the skipped files of §2
reported on landing.

### 5.3 Export — a project card's `⋮`, for a project that is not open

The home page's project cards already carry a `⋮` holding one entry (`Remove from list`); it gains
`Export…`, **with the same behaviour as inside the project** — the same pre-flight, the same confirm
dialog when files are missing, the same save dialog, the same report. Nothing has to be open for it,
which is the point: sending a project should not require opening it first, and it is the only way to
export a project whose file is at an older format without migrating it (§4).

The card's entry is disabled for an entry whose file is gone, like the card itself already is.

## 6. Code layout

Nothing here is a new manager. `OcptProjectsManager` already owns the lifecycle of the project file
— create, open, close — and both halves of this work are exactly that; it gains two services
(fifteen in all) and keeps its rule of handing them what only it holds.

New, under `lib/managers/projects/services/`:

- **`ocpt_project_package_service.dart`** — `OcptProjectPackageService`. Writes a package
  (`VACUUM INTO`, scrub, rewrite, stream the zip) and reads one back (unpack, rewrite paths through
  raw `sqlite3` keyed off the manifest, so no drift schema is assumed of a foreign package). Owns
  the manifest's encode/decode and its `packageFormat` upgrade map. Takes paths, never a database.
- **`ocpt_project_file_compatibility_service.dart`** — `OcptProjectFileCompatibilityService`. The
  read-only probe of §4 and the backup copy. Flutter-free and pure enough to be tested against files
  a test builds itself.

New models and types:

- `lib/models/ocpt_project_package_manifest.dart` — the manifest and its two asset entry kinds.
- `lib/models/ocpt_project_file_compatibility.dart` — `{ fileSchemaVersion, appSchemaVersion,
  appVersionAtCreation, suggestedBackupPath, verdict }`, the verdict being
  `current | older | newer | unreadable`. The dialog of §4 names the backup path from here, and the
  open then writes exactly there, so the promise and the write cannot drift apart.
- `lib/models/ocpt_card_choice_entry.dart` — the extracted card model of §5.2, which
  `OcptWorkspaceExportEntry` is then expressed in terms of.
- `lib/types/ocpt_project_package_status.dart` —
  `ok | cancelled | unreadableArchive | unsupportedPackageFormat | destinationExists | ioError`.
- `OcptProjectStatus` gains `migrationRequired` and `newerFormat`.

Manager surface:

```dart
Future<OcptProjectFileCompatibility> probeProjectFile({required String filePath});
Future<ResultWithStatus<OcptProjectStatus, OcptOpenProjectModel>> openProject({
  required String filePath,
  bool allowMigration = false, // false ⇒ an older file returns `migrationRequired`, unopened
});
Future<OcptProjectExportPreflight> scanProjectPackageAssets({required String projectFilePath});
Future<ResultWithStatus<OcptProjectPackageStatus, OcptProjectExportReport>> exportProjectPackage(…);
Future<ResultWithStatus<OcptProjectPackageStatus, OcptProjectImportReport>> importProjectPackage(…);
```

The native dialogs stay where the app already puts them: the save location through
`OcptSaveLocationService` (`pickSaveLocation` for the `.ocptz`, `pickDirectory` for the import's
parent folder), the open dialog through `FileSelectorManager`, both called from the bloc layer.

## 7. Milestones

Each ends on green gates (analyze, test, build, `reuse lint`, and `check_markdown` for the doc
ones) and a user checkpoint.

### M1 — The package, written

`OcptProjectPackageService`'s write half: pre-flight scan, `VACUUM INTO`, the scrub, the path
rewrite, the manifest, the streamed zip. Tests build a project database with assets pointing at real
temp files, export it, and read the archive back: the manifest is right, the missing file is in
`skippedAssets` and nowhere else, `local_erasures` is empty in the packaged database, a version
payload sealed before an erasure comes out scrubbed, and the source `.ocpt` is byte-identical
afterwards. No UI yet.

### M2 — The export card, in the project

The `OcptCardChoiceDialog` extraction, `OcptWorkspaceExportPick<T>`, the standing project card and
its preview-time unavailability, the five modes' one new branch each, the
`MixinOcptProjectPackageBloc` handler with its flush, the confirm dialog and the SnackBar, and the
l10n keys in both ARB files. Widget tests: the card is present in every mode's panel, greyed with
its reason under a preview, and a missing file is what produces the confirm dialog.

### M3 — The compatibility gate

`OcptProjectFileCompatibilityService`, `probeProjectFile`, `openProject`'s `allowMigration`, the two
dialogs, and the wiring of **every** path that opens a file. Tests: a file stamped at a lower
`user_version` migrates once, leaves the backup where the probe said it would, and keeps its rows; a
file stamped higher is refused and comes back byte-identical, `user_version` included.

### M4 — The home page's two doors

`OcptProjectPackageService`'s read half and `importProjectPackage`; the header's single `Import…`
button and its modal; the destination folder gesture and the skipped-files report on landing; the
project card's `Export…` entry reusing M2's flow with no project open. Tests: a package exported in
M1 imports into an empty parent and every asset row points at a file that exists, an existing folder
of the same name is refused, a package whose `packageFormat` is newer is refused with its own status
rather than an exception, and the card's entry is inert for a file that is gone.

### M5 — The record

Two ADRs — one for the portable package (what travels, the missing-file policy, the erasure scrub,
why a zip rather than a single-file container), one for opening a foreign file (the probe before
drift, the stated migration, the backup, the refusal) — plus a `foundations.md` section covering
both, the `exports.md` note that the `Export` panel now offers the project itself, and this plan
deleted.

## 8. Decisions taken here, for the review to overturn

- **`.ocptz`** as the extension and a plain zip as the container. A tar would stream as well and
  read worse on Windows; a bespoke container would buy nothing.
- **`project.ocpt`** as the fixed name inside, the display name living in the manifest — a package
  renamed on the way through an email stays readable.
- **`<name>.backup-v18.ocpt`** as the backup's name, beside the original.
- The whole version history travels, scrubbed. A project with forty sealed versions makes a large
  package, and the alternative was handing a colleague a project that cannot go back.
- The import does **not** re-identify anything: no new project id, no new `deviceId` in the file
  (the device id is a property of the replica, not of the project). Two people importing the same
  package hold two independent projects, which is exactly what today's storage model says. Sync is
  what will make this question real, and it has its own plan.

## 9. Out of scope

- Repairing a dangling asset path from inside the app ("find this file again"). It is the natural
  next issue and this one only reports.
- Merging an imported project into an open one. An import creates a project; it never touches one.
- Exporting a single episode as a package. The unit here is the project (ADR 0019).
- Anything a relay will do (`docs/plans/collaboration-and-sync.md`). A package is a file somebody
  carries, and it stays that.
