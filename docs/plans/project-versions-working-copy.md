<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Project versions: the working copy joins the list

Step 23 shipped project versions (issue #20) on a model that reads well from the database side and
badly from the user's side. This plan fixes the model itself. It is a follow-up on the same
feature, not a new one.

## What is wrong today

1. **The `Current` badge names a state nobody is looking at.** `createVersion` captures the working
   copy *and* points `project_info.currentVersionId` at the new row, so the badge means "the working
   copy descends from this". The card says something else (`projectVersionCurrentHint`: this is what
   is on screen), and that stops being true at the first keystroke.
2. **That card is inert.** `OcptProjectVersionsPanel` passes a null `onTap`, `onRestoreRequested`
   and `onDeleteRequested` for it. So after creating `v1` and working for an hour, the user cannot
   preview `v1`, cannot restore it, cannot delete it — the one version they would most want to come
   back to is the one the panel locks.
3. **Nothing represents the work in progress.** The list only holds sealed states, while pretending
   its newest entry is the present one.
4. **Two ways to mint a duplicate.** `restoreVersion` always captures `Before restoring <name>`,
   which is a byte-for-byte duplicate of the base version whenever the working copy has not drifted
   from it. `forkFromVersion` adds `From <name>`, whose content is identical to the version just
   restored — so a fork leaves two new cards, one of them redundant with a card already in the list.

## The model this plan installs

The list becomes: **the present at the top, the sealed history underneath.**

- A first entry, `Work in progress`, is not a `project_versions` row: it is the working copy, built
  on the fly from the project file. It carries the counters of the live state, says whether it
  differs from the version it descends from, and owns the `Create a version` action.
- `project_info.currentVersionId` keeps its meaning and finally gets the name it always had: the
  **base** — the version the working copy descends from. Badge `Base`, and the card is otherwise an
  ordinary one: previewable, restorable, deletable.
- Every version can be **renamed** (name and note), inline in its card.
- A restore captures its safety version **only when the working copy actually differs from its
  base**. Restoring from a clean working copy adds nothing to the list.
- The fork disappears. `Start from this version` in the read-only banner restores the previewed
  version and leaves the preview; the working copy then descends from it, and the user names their
  branch when they seal it. No `From <name>` card.

Automatic versions (sealing a version on project close, before an import, once a day) were
considered and left out: `screenplay_snapshots` already covers the screenplay text automatically,
and a full-project payload per event would grow the file and the list for little gain. Nothing here
forecloses adding them later.

## Content digest

Both new behaviours — "modified since `<base>`" on the card, and the deduplicated safety version —
need one primitive: is the working copy the same *content* as a stored version?

`OcptProjectVersionCodec` gains `contentDigest(OcptProjectVersionPayload)`, a SHA-256 hex string
(`crypto` is already a direct dependency) over a canonical JSON form of the payload:

- **in**: `screenplays`, `scenes`, `shots`, `shotCharacters`, `shotCoverages`, `pageSetup.format`,
  `settingsJson`;
- **out**: `rowFieldVersions` — the per-column stamps change on every restore without the content
  changing, so including them would report a difference where the user sees none — and
  `pageSetup.margins`, which is an app-wide preference rather than project state;
- **canonical**: rows sorted by primary key and each row's JSON keys sorted, inside the digest
  function itself. `_capturePayload` issues its `select`s with no `orderBy`, so SQLite's row order
  is not something to rely on; sorting in the digest rather than in the capture also leaves the
  stored payload bytes untouched.

The digest is stored on the row (`project_versions.contentDigest`, nullable). A null digest — every
version created before this change — reads as "unknown", which resolves to *modified* everywhere:
the card says the working copy has drifted, and a restore takes its safety version. That is the
fail-safe direction, and it costs one redundant version at most, once, per pre-existing project.
Same reasoning if the canonical form is ever changed in a later build: stale digests compare
unequal, and the worst outcome is a safety version nobody needed.

## Steps

Each step is one commit, each passes the full verification gates.

### 1. Schema v5 and the digest

- `OcptProjectVersionsTable.contentDigest`: `text().nullable()`, documented as above.
- `OcptProjectDatabase.schemaVersion` → 5, `onUpgrade` gains the `from < 5` branch with the single
  `addColumn`. No backfill.
- `OcptProjectVersionCodec.contentDigest`, as specified above. `currentPayloadFormat` is **not**
  bumped: the payload's shape does not change.
- `OcptProjectVersionsService.createVersion` writes the digest of the payload it just captured.
- Tests: digest stability across two captures of the same state; digest insensitivity to
  `rowFieldVersions` and to the margins; digest sensitivity to a tombstone, to a text edit and to
  the page format; migration v4 → v5 on a file holding versions.

### 2. Service and manager

- `renameVersion({database, id, name, note})` — a plain update, allowed while a preview is up
  (it reads nothing from the project's data).
- `restoreVersion` takes the safety version only when the working copy's digest differs from the
  base version's, or when either digest is unknown / there is no base. The `safetyVersionName` stays
  a parameter (the page localizes it); the decision belongs here.
- `captureWorkingCopyState({database, pageMargins})` → `OcptProjectWorkingCopyState`
  (`lib/models/`): the live `OcptProjectVersionSummary`, its digest, the base version's id, and
  `isModifiedSinceBase`. One capture answers the card and the dedupe with the same read.
- `forkFromVersion` is deleted, along with `OcptProjectsManager.forkProjectVersion`.
- `OcptProjectsManager` exposes `renameProjectVersion` and `captureWorkingCopyState`; the latter
  refuses (returns null) while a preview is up, since it would read the working copy the user is not
  looking at — the same rule `createProjectVersion` already follows.
- `OcptProjectVersion.isCurrent` → `isBase`, everywhere.
- Tests: rename; restore from a clean working copy adds no version; restore from a dirty one adds
  exactly one; restore with a null base digest adds one; the working copy state on a clean and on a
  dirty project.

### 3. State, events, bloc mixin

- `MixinOcptProjectVersionsState` gains `workingCopy` (nullable — null while previewing, which is
  exactly when the card is not shown) and `versionPendingRenameId`, a third inline mode alongside
  the two existing pending ids, all three mutually exclusive.
- Events: `OcptProjectVersionRenameRequestedEvent` / `Cancelled` / `ConfirmedEvent(id, name, note)`,
  and `OcptProjectWorkingCopyRefreshRequestedEvent`. `OcptProjectVersionForkRequestedEvent` goes.
- `_emitVersions` captures the working copy state along with the list.
- The working copy capture reads the whole project, so it is **not** free: the mixin throttles it to
  one capture every 2 s, and modes dispatch `OcptProjectWorkingCopyRefreshRequestedEvent` when the
  `Versions` tab becomes selected and after a save *while that tab is selected*. This is the one
  performance-sensitive point of the plan; if profiling on a large project shows it, the fallback is
  to widen the throttle rather than to drop the freshness.
- Tests: the rename round trip, the three inline modes excluding each other, the throttle, the
  working copy state emitted with the list, no capture while previewing.

### 4. UI and l10n

- `OcptProjectWorkingCopyCard` (`lib/ui/pages/workspace/widgets/`): same gabarit as a version card,
  status dot, `Work in progress`, the summary line, the state line (`Identical to "<base>"` /
  `Modified since "<base>"` / `Not based on any version`) and the `Create a version` button. It is
  the panel's first child and replaces the panel-header `Create a version` button; it is hidden
  while a version is previewed.
- `OcptProjectVersionCard`: `Base` badge instead of `Current`, the base card wired like any other
  (tap → preview, restore, delete), a third inline mode `rename` (name field, note field, Cancel /
  Save) beside the two confirmations, and a `Rename` action in the footer.
- `OcptWorkspaceReadOnlyBanner`: `Start from this version` now dispatches the restore of the
  previewed version.
- ARB `en_GB` + `fr`: the working copy card's strings, `Base`, the rename action and its fields;
  removal of the fork's strings and of `projectVersionCurrentHint`/`projectVersionCurrentBadge`.
- Tests: the new card in its three states, the base card now offering its three actions, the inline
  rename, the panel's ordering.

### 5. Documentation

`AGENTS.md`'s project-versions paragraphs and the `Versions` dock tab paragraph, the table's doc
comment (the `contentDigest` column, the base semantics), and the step table's line 23 extended
with this rework. This plan file is deleted with that commit.

## Decisions already taken

- Model B (the working copy in the list), over a minimal fix or automatic versions — validated.
- The working copy as a card at the top of the list, over a fixed header above it — validated.
- `Start from this version` = a plain restore, over keeping a renamable branch marker or asking for
  a name up front — validated.
