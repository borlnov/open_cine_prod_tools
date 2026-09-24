<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Storyboard and floor plans inside the shot list

Two new **centre views** join the shot list mode's table, closing
[issue #85](https://github.com/borlnov/open_cine_prod_tools/issues/85): the **Board** (each shot's
imported frames, annotated, read against its découpage) and the **Floor plans** (a top-down
symbol-placing editor of every décor a sequence spans, with one camera position per shot). Neither
is a new production mode and neither reaches the bottom mode switcher: a segmented control in the
centre header switches `Table · Board · Floor plans`, the sequence tree on the left and the dock on
the right stay in all three, and the one selected shot is shared by all three. The mock-up every
decision below was validated against is
[the concept page](https://claude.ai/artifact/XUpngamSjJJbw3wLQBdBwt); its "Decided with Benoit"
list is restated in *Goal & scope*, and nothing here deviates from it without saying so.

**Read first**, and reading them is part of the job, not background: `AGENTS.md`,
[`../architecture/foundations.md`](../architecture/foundations.md) (the schema, the sync-ready
data model, binary assets, the portable package, the read-only preview),
[`../architecture/exports.md`](../architecture/exports.md),
[`../architecture/breakdown.md`](../architecture/breakdown.md) (the model for a mode with a centre
view switch), [`../adr/0007`](../adr/0007-schema-migration-policy.md),
[`../adr/0010`](../adr/0010-sync-ready-data-model-prerequisites.md),
[`../adr/0013`](../adr/0013-binary-assets-referenced-by-path.md) and
[`../adr/0029`](../adr/0029-schema-versions-frozen-at-stable-releases.md), then the shot list mode
itself (`lib/ui/pages/workspace/modes/shot_list/`), `OcptShotListService`, `OcptAssetsService`,
`OcptProjectVersionCodec`, `OcptProjectVersionsService` and `OcptExportManager`.

The work is delegated to Sonnet 5 agents, one milestone at a time, reviewed by the main session,
with a checkpoint with Benoit between milestones. The order is deliberate: the store and its
plumbing first (the risk every other milestone stands on), the services and the pure rules next,
the two views, then the exports, then the record. This file is deleted once the work ships and its
outcome is folded into `docs/architecture/`.

## 1. Goal & scope

What ships, all validated:

- **The view switcher.** `Table · Board · Floor plans` in the centre header, persisted like the
  right dock's last tab. Left tree, right dock, status bar and toolbar are unchanged; the dock's
  inspector gains a group at its top naming what the active view adds, and keeps the whole
  découpage under it. One selected shot across the three views; a view may refine it (a panel, a
  camera) without changing it.
- **Board.** A shot holds **0..N ordered panels** — a deliberate divergence from the issue's "one
  frame per shot". A panel is an imported image **referenced by path** (ADR 0013, through the
  `assets` table; a missing file is a normal state), a **light annotation layer** of a fixed
  vocabulary (movement arrow, camera-move arrow, short text label — the only in-app drawing there
  is; no freehand), and a **free comment** (no start/end captions). Panels share one height, so the
  **aspect ratio derived from the shot's `recordingFormat`** sets each frame's width and the board
  is heterogeneous on purpose. A **shot leader card** (code, status, size, framing, move, lens,
  format, cast, difficulty) leads every row; a shot with no panel shows one dashed placeholder at
  its own ratio.
- **Floor plans.** Per sequence, **several cases** (one per décor), as tabs in the centre header.
  **Two layer scopes**: *sequence* layers (décor, furniture, fixed props, the underlay) drawn once,
  and *shot* layers (cameras, characters, lights, hand props) holding one position per shot. A
  **layer tray inside the canvas** (not the dock) with per-layer visibility and, under the sequence
  focus, per-camera visibility. A **focus strip** at the bottom: a shot chip makes its shot layers
  editable, **locks (never hides)** the sequence layers and ghosts the previous/next shot (onion
  skin, one opacity); the `Sequence` chip flips it and shows every camera of the sequence numbered.
  **The chip selection is the mode's shot selection.** Symbols: camera, character, light, set
  element; **movement arrows between symbols**; a **text label on any symbol**. **Several cameras
  per shot** on a case, sharing the shot's number plus a letter (`3A`, `3B`); the number is the
  shot's rank in its sequence, **derived, never stored, never renumbered per case** — a missing
  number on the plan is a shot still to place. Deleting a shot drops its placements. **Characters
  on the plan are independent** of the shot's characters field: placing one never edits the shot.
  An **underlay** (photo or plan, path-referenced) per case, freely movable and resizable.
  **Geometry is stored in metres**; the **default character footprint (0.5 m) is the implicit
  ruler**, an always-visible reference silhouette and scale bar at the bottom reflecting the
  current **zoom, which is a view concern and never synchronised**. A **metrics toggle** reveals
  inter-object distances. No grid is enforced.
- **Exports.** A **storyboard PDF** (the frames with their annotations and each shot's key
  information) and a **floor plans PDF** (one floor plan per shot: the case drawn in that shot's
  focus, no ghosts, repeated per shot), both reached from the toolbar's `Export` control and written
  through the native save dialog like every other export.

Explicitly deferred to v2: a per-symbol size override, object sizes in the metrics overlay,
freehand drawing of any kind, and a structured recording-format field (the ratio stays derived from
today's free text, see §2 and §8).

## 2. Data model

Five new **synchronised** tables, all `id` UUID primary key, `isDeleted` tombstone, `references()`
foreign keys and — where ordered — a `sortKey` fractional index (`lib/utils/ocpt_fractional_key.dart`).
**None of them carries a `position` column**: that column survives on the older tables only because
ADR 0007 forbids dropping it, and nothing reads it. Table classes take the `Ocpt…Table` name, row
classes the `Ocpt…Row` name, under `lib/models/database/tables/`.

Everything below is a **proposal** unless it quotes an existing rule; the marks say which.

### `storyboard_panels` — `OcptStoryboardPanelsTable` / `OcptStoryboardPanelRow`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `shotId` | text → `shots.id` | the shot this panel belongs to |
| `sortKey` | text | order within the shot; a reorder writes one row |
| `imageAssetId` | text → `assets.id`, nullable | the frame; see *images* below |
| `comment` | text, default `''` | the free comment shown under the frame |
| `isDeleted` | bool | tombstone |

`imageAssetId` is nullable so a panel **outlives its image**: `Replace image` tombstones the old
`assets` row, mints a new one and re-points the panel, and the panel's own id — what its annotations,
its stamps and a version payload refer to — never changes. The panel's rank (`1/2`, `2/2`) is a
read-time count off `sortKey`, exactly as a shot's code is.

### `storyboard_annotations` — `OcptStoryboardAnnotationsTable` / `OcptStoryboardAnnotationRow`

One row per mark on a panel, rather than one JSON column on the panel: ADR 0010's per-column stamps
are what merge two replicas, and a JSON blob would make two people annotating one panel a
last-writer-wins on the whole layer (flagged in §8).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `panelId` | text → `storyboard_panels.id` | |
| `kind` | text (`OcptStoryboardAnnotationKind`) | `movementArrow`, `cameraMoveArrow`, `label` |
| `sortKey` | text | draw order |
| `x1`, `y1`, `x2`, `y2` | real | **normalised 0..1 to the frame**, so a replaced image of another size keeps the marks where they were; a label uses `x1`/`y1` only |
| `text` | text, default `''` | the label's text, or an arrow's optional caption (`dolly in`) |
| `isDeleted` | bool | |

### `floor_plan_cases` — `OcptFloorPlanCasesTable` / `OcptFloorPlanCaseRow`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `sceneId` | text → `scenes.id` | the sequence; a case is per sequence, so per episode (ADR 0019) for free |
| `name` | text | `Kitchen`, `Hallway` |
| `sortKey` | text | tab order |
| `underlayAssetId` | text → `assets.id`, nullable | the imported photo or plan |
| `underlayXM`, `underlayYM`, `underlayWidthM`, `underlayHeightM`, `underlayRotationDeg` | real, nullable | the underlay's frame **in metres**, null until placed |
| `isDeleted` | bool | |

A case follows its scene and nothing else. `scenes` rows are tombstoned, never dropped, and their ids
are stable, so a case whose scene vanished from the screenplay is simply unreachable from the tree
(the orphan group has no scene and no plan) and comes back with the scene if the scene index matches
it again. No orphan handling, no cascade — the shots of that scene are orphaned by
`OcptShotListService.detachShotsFromDeletedScenes` today and their cameras stay on the unreachable
case (flagged in §8).

### `floor_plan_symbols` — `OcptFloorPlanSymbolsTable` / `OcptFloorPlanSymbolRow`

One table for both scopes: the **layer decides the scope**, and `shotId` is null exactly when the
layer is a sequence layer. That is the invariant `OcptFloorPlanService` enforces at every write.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `caseId` | text → `floor_plan_cases.id` | |
| `shotId` | text → `shots.id`, nullable | null on a sequence layer, set on a shot layer |
| `layer` | text (`OcptFloorPlanLayer`) | `decor`, `furniture`, `fixedProps` (sequence) · `cameras`, `characters`, `lights`, `handProps` (shot) |
| `sortKey` | text | draw order, and the order a shot's cameras take their letter from |
| `xM`, `yM` | real | centre, **metres** |
| `rotationDeg` | real, default 0 | a camera's heading, a wall's angle |
| `widthM`, `heightM` | real, nullable | a set element's footprint; **null on every other layer in v1** — the v2 per-symbol size override reuses these two columns with no migration |
| `fovDeg` | real, nullable | a camera's field-of-view wedge; null = the drawing default |
| `label` | text, default `''` | the text label any symbol may carry (`key · 1.2k`, `SAM · stand-in`, `85mm · reverse on Sam`) |
| `isDeleted` | bool | |

A camera's **letter is derived at read time** from its rank among the same shot's live cameras on the
same case, in `sortKey` order — the house rule the shot code already follows (never stored, always
in step). Its **number is the shot's rank** in the sequence, read off the loaded `OcptShotSequence`.
A character symbol carries a free `label` and **no `roleId`**: the mock-up's "the shot's characters
are offered first only as a convenience" is a picker pre-fill, not a link.

### `floor_plan_arrows` — `OcptFloorPlanArrowsTable` / `OcptFloorPlanArrowRow`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `caseId` | text → `floor_plan_cases.id` | |
| `shotId` | text → `shots.id` | **always set**: an arrow is a movement, and a movement belongs to a shot |
| `kind` | text (`OcptFloorPlanArrowKind`) | `movement` (between two symbols), `cameraMove` (from a camera to what it pans or dollies to) |
| `fromSymbolId`, `toSymbolId` | text → `floor_plan_symbols.id` | either end may be a sequence-scoped symbol (an actor walks to the door) |
| `label` | text, default `''` | |
| `isDeleted` | bool | |

Removing a symbol tombstones every arrow touching it, in the same transaction.

### Images: the `assets` pattern (ADR 0013)

A frame and an underlay are `assets` rows — the table that already holds a path, a kind, a label and
a timestamp, and that **the portable package walks generically** (`OcptProjectPackageService` reads
`id`, `path`, `label` and `is_deleted` off every live row, so a frame travels inside a `.ocptz` and
is re-pointed on import with nothing to add there). Proposed:

- two new `OcptAssetKind` values, `storyboardPanelImage` and `floorPlanUnderlay`;
- **no new owner column on `assets`**: the panel's `imageAssetId` and the case's `underlayAssetId`
  are the link, the way `people.photoAssetId` is, and a kind whose owner points at it has nothing
  to list from the asset's side. The table's doc comment ("exactly one of the four owner columns
  is set") is amended to say these two kinds set none, and `OcptAssetsService.insertAsset` accepts
  a call with no subject for them. The alternative — two nullable owner columns, mirroring the
  person/location/element trio and adding to the foreign-key cycle `build_runner` already warns
  about — is one `addColumn` each and is flagged in §8 for Benoit to pick.

`OcptAssetsService` stays the one place a row is minted or tombstoned; the two new services take
one, as the resources services do, and nothing outside it reads `assets.path`. What a reference
looks like on screen is `OcptReferencedImage`'s job already (the image draws, or the caller's
placeholder does): it moves from `modes/resources/widgets/` to `lib/ui/widgets/` now that two modes
use it.

### Types and pure rules

New enums under `lib/types/`: `OcptShotListCentreView { table, board, floorPlans }` (mirrors
`OcptBreakdownCentreView`), `OcptStoryboardAnnotationKind`, `OcptFloorPlanLayer` (with an
`isSequenceScoped` getter), `OcptFloorPlanArrowKind`, `OcptFloorPlanTool { select, camera,
character, light, setElement, arrow, label }`, and `OcptShotListExportDocument` gains `storyboard`
and `floorPlans`.

Pure rules under `lib/utils/`, each with its own test file, read by the widgets and the PDF services
alike so screen and paper can never disagree:

- `ocpt_storyboard_aspect_ratio.dart` — `ocptAspectRatioOf(String recordingFormat)`: finds a ratio
  in the free text (`2.39:1`, `1.85`, `16:9`, `4/3`, `4:3`) and falls back to **16:9** when it finds
  none (`4K · 25 fps`). Deriving from free text is the validated choice; the fallback is flagged.
- `ocpt_floor_plan_geometry.dart` — the default footprints per layer (a character **0.5 m**, a
  camera body, a light), metres ↔ logical pixels at a zoom, the scale bar's rounded length for a
  zoom (`1 m`, `2 m`, `5 m`), and the inter-object distances the metrics toggle prints.
- `ocpt_floor_plan_camera_label.dart` — `ocptFloorPlanCameraLabelOf(shotRank, cameraRank)` →
  `3`, `3A`, `3B`.
- `lib/models/ocpt_floor_plan_sheet.dart` — `OcptFloorPlanSheet.of(case, focus, ...)`: the
  **drawing as data** (every shape to draw, in metres, colours as ARGB ints, ghosts marked as such),
  pure Dart with no Flutter and no `pdf`, the sibling of `OcptScenarioCoverageLayout`. The Flutter
  `CustomPainter` and the PDF service both only draw what it says.

## 3. Sync plumbing

The checklist a new synchronised table owes, every line of it in **M1**:

- **Schema.** `currentSchemaVersion == lastStableSchemaVersion == 3` (0.2.2 froze it), so this
  work **creates** `lib/models/database/migrations/ocpt_migration_v4.dart` and bumps
  `OcptProjectDatabase.currentSchemaVersion` to 4 (ADR 0029). The step is additive only:
  `createTable` for the five tables; nothing else changes. Should another branch open the v4 cycle
  first, this branch **overwrites** that file in place at merge instead — the two constants say
  which (ADR 0007's merge-time rule as amended). Add the five tables to `@DriftDatabase`, extend
  the database's doc comment and its `migration` doc comment, regenerate.
- **The registry sweeps them in on its own**: `ocptSynchronisedTables` is a rule over `is_deleted`,
  so the changeset and merge services need nothing — but
  `test/utils/ocpt_synchronised_tables_test.dart` pins the expected list and gains five names.
- **Version codec.** `currentPayloadFormat == lastStablePayloadFormat == 3`, so bump
  `currentPayloadFormat` to 4: five keys, a `_…ToJson`/`_…FromJson` pair per table, the five lists
  in `encode`/`decode`, the five `_canonicalRows` entries in `contentDigest`, and five fields on
  `OcptProjectVersionPayload`. The change is additive, so a format-3 payload decodes with the new
  lists empty — confirm `_rows(json, key)` tolerates a missing key, and if it does not, the format-4
  `decode` step is the one-line default. Pin the retired format-3 shape as a fixture in the codec
  test, as the class's own doc comment requires, and add the round-trip test for every column of
  the five tables (enums, nulls, tombstones, sort keys).
- **Versions service.** Five names in `_payloadTableNames` (so their stamps travel), five reads in
  `_capturePayload`, five `_restoreTable` calls in `_applyPayload` **after** `shots` and `assets`
  (a panel points at both) and, for arrows, after symbols — the deferred foreign keys cover the
  `assets` cycle as they already do. The erasure scrub is untouched: none of the five holds
  anything about a person.
- **Assets.** The two `OcptAssetKind` values, the codec's asset kind round trip, and one package
  test asserting a `storyboardPanelImage` row is packaged, skipped when missing and re-pointed on
  import — the service is generic, the test is what proves the new kind rides it.
- **Migration test.** Pin the v3 DDL as `_v3Ddl` (a real 0.2.2 file's shape, assembled from
  `_v2Ddl` plus the v3 reshape, exactly as `_v2Ddl` was from `_v1Ddl`), and add the "onCreate
  reproduces exactly what migrating the verbatim v3 fixture forward produces" test beside its two
  siblings.
- **Cascades.** `OcptShotListService.deleteShot` tombstones the shot's panels (and their
  annotations and asset rows), its symbols and its arrows in its own transaction, and
  `tombstoneShotsOfScreenplay` (an episode's deletion) does the same per shot. The two new services
  expose unguarded `tombstone…OfShot(database:, shotId:, stamps:)` for it, the way
  `OcptAssetsService.tombstoneAsset` is unguarded for its callers; `OcptShotListService` takes them
  as it takes `roleIndexService`, in every place `OcptProjectsManager` constructs one.

## 4. UI

Every widget below is presentational, reports upward through nullable `on…` callbacks, and is built
by the mode; the mode opens every `OcptConfirmDialog`; the bloc resolves no `Tr`. Every new string is
a key in both ARB files (`shotListBoard…`, `shotListFloorPlan…`), French keeping « séquence » and
using « case » and « plan au sol » as Benoit does.

### 4.1 The view switcher and the shared chrome

- `OcptShotListCentreHeader` replaces today's `_SequenceHeader` row: the segmented switch on the
  left, then what the active view needs — the table keeps its `Columns ▾` and `Export XLSX`, the
  board shows `Sequence 12 · 5 shots · 6 panels` and a `Panel size ▾` (three common heights, a view
  preference), the floor plans show the **case tabs** and the focus pill. Lift the breakdown
  header's private `_OcptBreakdownViewSwitch` into a generic `OcptViewSwitch<T>` under
  `lib/ui/widgets/` and let the breakdown header adopt it, so the two modes' switches cannot drift.
- `OcptShotListState.centreView`, persisted through a new
  `OcptPropertiesManager.shotListLastCentreView` (a `SharedPrefsItemWithParser`, like the last
  right dock tab); `OcptShotListCentreViewSelectedEvent`. Switching keeps `selectedShotId` and
  `selectedSequenceId`; the board scrolls to the selected shot, the floor plans focus it.
- **One selection.** `selectedShotId` stays the single truth. New: `selectedPanelId` (board),
  `selectedCaseId` and `selectedSymbolId` (floor plans), each cleared when the shot or sequence
  changes; and an `OcptShotListShotDeselectedEvent`, which the focus strip's `Sequence` chip and a
  click on empty canvas send — the table never needed one.
- **The inspector follows the view.** `OcptShotInspectorPanel` gains a `Widget? leadingGroup`
  slot drawn under its header and before the character chips; the mode hands it
  `OcptStoryboardPanelsGroup` on the board and `OcptFloorPlanPlacementsGroup` on the plans, and
  null on the table. The panel's `isReadOnly` keeps gating everything under the slot; the two
  groups take their own `isReadOnly`.
- `OcptShotListStatusBar` takes a nullable trailing `hint` the mode words per view (`Panel 2 of
  12/3 selected · drag to reorder`, `Kitchen · 5 cameras on 4 shots · 12/5 has no camera yet`).

### 4.2 Board

- `OcptStoryboardBoard` lists the selected sequence's shots as `OcptStoryboardShotRow`s (the row
  is the shot; selecting highlights the row): `OcptStoryboardShotLeaderCard` on the left — the
  découpage read-outs the mock-up lists, using the same pills, chips and difficulty dots the table
  and inspector already render — and `OcptStoryboardPanelStrip` on the right: one
  `OcptStoryboardPanelFrame` per panel (image through `OcptReferencedImage` at the derived ratio
  and the common height, the placeholder at that ratio when the file is missing, the `1/2` badge,
  the annotation overlay, the comment and the ratio under it) and a trailing dashed
  `+ Import frame` slot. A shot with no panel shows the slot alone, labelled `no panel yet`.
- **Importing a frame** dispatches `OcptShotListPanelImportRequestedEvent(shotId)`; the bloc picks
  the file through `FileSelectorManager` **filtered to JPEG and PNG** (decided with the maintainer,
  so what draws on screen always prints: the `pdf` package embeds only those two — see §8), as
  `OcptResourcesBloc` does for a photo — a pick is not an import, so it goes to the manager
  directly — then `OcptStoryboardService.addPanel`, appended
  with `ocptFractionalKeyBetween(before: last)`. `Replace image` is the same pick onto
  `replacePanelImage`. Drag to reorder within the strip writes one row (`reorderPanel`).
- **The comment** is typed in the inspector's Panels group and rides the mode's existing 2 s
  autosave debounce: generalise `pendingFieldEdits`' key from `(shotId, field)` to a small sealed
  `OcptShotListPendingEditKey` (`shotField`, `panelComment`, `symbolLabel`, `caseName`), flushed on
  the same triggers (selection change, `deactivate`, every export, leaving the workspace).
- **Deleting a panel** is irreversible: the group's `Delete panel` only asks
  (`onDeleteRequested`), the mode opens `OcptConfirmDialog` with `isDestructive`, then
  `OcptShotListPanelDeletionRequestedEvent`.
- **Annotations** (a milestone of their own): the inspector's `Annotate` toggles an
  `OcptStoryboardAnnotationTool` (movement arrow, camera-move arrow, label) on the selected panel;
  a drag on the frame draws an arrow, a click places a label and opens its text inline, a click on
  a mark selects it, `Delete` removes it. The overlay is one `CustomPainter` over normalised
  coordinates; the group lists the panel's marks with a remove action each. Removing a mark is
  confirmed like every other irreversible action.

### 4.3 Floor plans

- `OcptFloorPlanView` fills the centre: the **layer tray** (`OcptFloorPlanLayerTray`) down the
  left of the canvas, the **tool bar** across the top, the **canvas** in the middle, the **focus
  strip** along the bottom. The case tabs sit in the centre header (§4.1); `+ Case` creates one
  named after the scene's heading place (`ocptSceneHeadingPlaceOf`, the breakdown's own rule) and
  the name is edited in place in the tab; deleting a case goes through the confirm dialog.
- **Tray.** Two groups, `Sequence layers` and `Shot layers`, a visibility eye per layer, the
  underlay as a sequence row with its own eye, the lock icon on whichever group the focus froze
  (a read-out, never a setting), the cameras layer expandable to one row per camera of the sequence
  under the `Sequence` focus with a per-camera eye, and the `Onion skin` block (previous, next, one
  opacity). Visibility, onion skin, opacity, zoom, the metrics toggle and the panel size are
  **view state**: held in the bloc's state for the session, never written to the project.
- **Canvas.** `OcptFloorPlanCanvas` is a `CustomPaint` of the `OcptFloorPlanSheet` the state
  builds, under a `GestureDetector`. Zoom and pan live in a small `OcptFloorPlanViewportController`
  owned by the view's `State` (the RFL1 exception the dock layout controller already documents:
  per-frame mutation during a drag, no bloc emission per frame), the way `_ShotListViewState` owns
  its dock controller; only the settled zoom reaches the state, for the scale bar. Placing a
  symbol: pick a tool, click; a tool that would draw into the frozen scope is **dimmed with a
  one-line hint** in the bar (`Set elements go to a sequence layer — pick "Sequence" below`), never
  hidden. Dragging moves a symbol (one row on drag end), dragging a handle rotates a camera or
  resizes a set element or the underlay. Double-clicking a ghost focuses its shot.
  **Every write is withheld** under `isReadOnly` (a null `onSymbolPlaced` closes the whole
  placing gesture, as the breakdown's null word click does); the tray's toggles, zoom and metrics
  stay, since they only read.
- **Focus strip.** `OcptFloorPlanFocusStrip`: the `Sequence` chip, then one chip per shot of the
  sequence with a filled dot when the shot has a camera on this case and a hollow one when it has
  none; `prev`/`next` tags on the ghosted neighbours; `←`/`→` walk the shots. A shot chip
  dispatches the very `OcptShotListShotSelectedEvent` the table's rows do; `Sequence` dispatches
  the deselection. The focus **is** `selectedShotId == null ? sequence : shot`, derived in the
  state, never a second field.
- **Cameras.** Placing a camera under focus `12/3` inserts a `cameras` symbol with `shotId` and the
  next `sortKey`; its label reads `3`, `3A`, `3B` off the pure rule. Under the `Sequence` focus
  every live camera of every shot draws, numbered, each hideable. A gap in the numbers is a shot
  with no camera, and the strip's hollow dot says which.
- **Scale.** The reference silhouette (the 0.5 m character at the current zoom) and the scale bar
  sit bottom-right of the canvas, always drawn, both from `ocpt_floor_plan_geometry.dart`. There is
  no calibration dialog: the room is sized against the silhouette, and the underlay is dragged and
  resized until its own doors and tables match it. The **metrics toggle** overlays the distance from
  the selected symbol to every other visible symbol of the case (and camera-to-subject for a
  selected camera), from the same rule.
- **Arrows and labels.** The arrow tool takes two clicks on two symbols (a pending anchor in the
  state, cancelled by `Escape` or a click on empty canvas, exactly like the coverage dialog's
  pending anchor); the label tool edits the selected symbol's `label` inline. Removing a symbol or
  an arrow asks through the confirm dialog; a symbol with arrows says how many go with it.
- **Placements group** in the inspector: `On this plan · Kitchen` — the shot's cameras on the
  selected case with their labels, the characters, lights and props placed for it, its arrows, and
  one line per **other** case of the sequence (`Hallway · no camera for this shot`), so the dock
  says where the shot stands across the décors.
- **Compact width.** On a phone (`ocptIsCompactWidth`) the switcher offers **the table only**: the
  board and the floor plans are large-screen views (decided with the maintainer; desktop-first, the
  phone question reopens when mobile becomes a real target). No compact layout of either view ships
  in v1.

## 5. Export

Follow the scenario coverage wiring line for line:

- `OcptShotListExportDocument.storyboard` and `.floorPlans`, two cards in `_buildExportEntries`
  (`PDF`), each with its own `unavailableReason`: no panel in the whole shot list, no case holding
  a camera anywhere. Reword the enum's doc comment, which today says both values share one reason.
- `OcptStoryboardExportDialog` (page format prefilled from `pageSetup`, shots per page, an
  `Include the floor plans after each sequence` toggle that reuses the floor-plan sheets below —
  the "printed alongside" reading), opened from the mode's own context; the floor plans card goes
  **straight to the save dialog** like the workbook, the format coming from `pageSetup`.
- `OcptShotListStoryboardExportRequestedEvent` and `…FloorPlansExportRequestedEvent`, carrying an
  `OcptStoryboardLabels` / `OcptFloorPlanLabels` (`lib/models/`, pure) built by
  `ocptStoryboardLabelsOf(tr, sequences)` / `ocptFloorPlanLabelsOf(tr, sequences)` in
  `lib/ui/utils/ocpt_shot_list_labels.dart`, the `fileTypeLabel`, the `episodeTag` and the
  `shareAnchor`; two bloc handlers flushing pending edits first, then calling the manager, then
  emitting an `OcptShotListIoNotice` — four new `OcptShotListIoNoticeKind` values and their
  messages in `_ioNoticeMessage`.
- `OcptExportManager.exportStoryboard(...)` / `.exportFloorPlans(...)` → `_writeToPickedLocation`
  (so mobile shares instead of saving, for free), with two new services constructed with the
  shared `fontsLoader`: `OcptStoryboardPdfService` and `OcptFloorPlanPdfService` under
  `lib/managers/export/services/`, file names through `ocptExportFileNameOf` with the labels' own
  suffix.
- **Storyboard PDF.** Per sequence a header band, then per shot a row: the key information block
  (code, size, framing, move, lens, format, cast, status) and its frames at a common row height and
  their derived ratios, each frame's annotations drawn over it from the same normalised geometry,
  its comment under it. Image bytes are read **at render time** off the asset's path
  (`pw.MemoryImage`, JPEG and PNG); a missing or undecodable file prints the placeholder frame with
  the label's `file not found` text — the ADR 0013 state, on paper.
- **Floor plans PDF.** Per sequence, per case, **one page per shot that has a camera on it**, the
  `OcptFloorPlanSheet` built in that shot's focus with **no ghosts**, the scale bar printed, the
  shot's code and key information in the page header; a case with sequence layers and no camera
  prints once as the bare décor. Courier Prime everywhere, as in every other document.
- Tests: the two services against a small in-memory snapshot (page count, a missing file's
  placeholder, the annotation geometry), the bloc handlers with a stubbed manager, the dialog.

## 6. Docs

- **A new `docs/architecture/shot-list.md`.** The mode has no file of its own today (the README
  table lists none for `modes/shot_list/`, the schedule file only cross-references it). It records
  the whole mode — the table and the inspector in a short paragraph pointing at what
  `foundations.md` and `exports.md` already say, then the three views, the one-selection rule, the
  two layer scopes and the focus, cameras numbered by shot rank, the metres-and-silhouette scale,
  the images through `assets`, and the two documents. A row in `docs/architecture/README.md` and a
  row in `AGENTS.md`'s "Read this | Before touching" table (`shot-list.md` before touching
  `lib/ui/pages/workspace/modes/shot_list/`, `lib/utils/ocpt_floor_plan_*.dart`,
  `lib/utils/ocpt_storyboard_*.dart`).
- **`foundations.md`**: the schema paragraph gains the v4 step, the binary assets paragraph the two
  kinds and the "owner points at the asset" reading, and the read-only paragraph the canvas as one
  more composite taking `isReadOnly`.
- **`exports.md`**: two more services (the counts of "twenty services" and "twelve PDF services"
  move), one bullet per document modelled on the scenario coverage bullet, and the
  render-time-image rule.
- **One ADR**, `0031`, arguing the two structural choices the code cannot explain on its own: a
  storyboard as ordered panels under a shot, and floor-plan geometry stored in metres against a
  default-character reference with zoom as a view concern. Proposed *before* M1, so the tables are
  written against an argued record (§8 asks whether Benoit wants it).
- **The filmmaker guide** (`docs-site/docs/modes/shot-list.md`) gains the two views with
  screenshots from `tool/screenshot-app.sh` over a seeded demo project (`test/seed_demo_project.dart`
  gains a few panels and a case).

## 7. Milestones

Each milestone is one delegated task, independently verifiable, and ends on the gates (§7.1); the
commit boundary is the milestone unless a step is called out. Checkpoint with Benoit between each.

- **M0 — ADR 0031** (docs only). The two arguments above, status Proposed; the plan's §2 is its
  "Decision" in prose. Gate 9. Commit `docs: ADR for the storyboard and floor plans`.
- **M1 — The store.** The five tables, the two asset kinds, `ocpt_migration_v4.dart` and the bump
  to 4, `@DriftDatabase` and its doc comments, payload format 4 across codec, payload class and
  versions service (restore order included), the synchronised-tables list, the v3 DDL fixture and
  its `onCreate` test, the codec round-trip and retired-format-3 fixture, the package test.
  Behaviour-preserving: nothing above the store changes. Commit
  `storyboard: add the panel and floor plan tables`.
- **M2 — Services and pure rules.** `OcptStoryboardService`, `OcptFloorPlanService` (loaders per
  screenplay, guarded writes in transactions with stamps, the scope invariant, the arrow cascade),
  the models, the four pure rules and `OcptFloorPlanSheet`, the `deleteShot` /
  `tombstoneShotsOfScreenplay` cascades, `OcptProjectsManager` wiring, `OcptReferencedImage` moved
  to `lib/ui/widgets/`. Tests per service and per rule. Commit
  `storyboard: services and the floor plan geometry`.
- **M3 — The switcher and the board.** `OcptShotListCentreView` and its persistence,
  `OcptViewSwitch<T>` (breakdown adopting it), the centre header, the board widgets, panel import,
  reorder, replace, comment (the generalised pending-edit key), delete through the dialog, the
  inspector's `leadingGroup` and Panels group, the status bar hint, read-only. Widget and bloc tests
  with an explicit surface width past the 800 px breakpoint. Commit
  `shot list: the board view`.
- **M4 — Board annotations.** The tool, the overlay painter, the inline label, selection and
  removal, the group's list. Commit `storyboard: the annotation layer`.
- **M5 — Floor plans, the sequence half.** The view's frame (tray, tool bar, canvas, viewport
  controller, focus strip drawn but sequence-only), case tabs (create, rename, reorder, delete),
  sequence layers (place, move, rotate, resize set elements), the underlay (import, frame), the
  scale reference and bar, zoom, layer visibility, read-only. Commit
  `shot list: the floor plans view`.
- **M6 — Floor plans, the shot half.** Shot layers under a shot focus, cameras and their derived
  labels, per-camera visibility under the sequence focus, onion skin, arrows and labels, the
  metrics overlay, the inspector's Placements group, the status bar hint, `←`/`→`, double-click on
  a ghost. Commit `floor plans: cameras, focus and onion skin`.
- **M7 — Exports.** Enum values, cards, dialog, events, handlers, notices, the two manager methods,
  the two services, the labels. Commit `shot list: storyboard and floor plan PDFs`.
- **M8 — The record.** `shot-list.md`, the README and `AGENTS.md` rows, `foundations.md`,
  `exports.md`, ADR 0031 to Accepted, the guide and its screenshots, this plan deleted. Commit
  `docs: record the storyboard and the floor plans`.

### 7.1 Verification

The nine gates in `AGENTS.md` before each commit (`flutter pub get`, `intl_utils:generate`,
`build_runner build`, `flutter analyze`, `flutter test`, `flutter build linux --debug`,
`reuse lint`, the `allcircuits.com` grep, `dart run tool/check_markdown.dart` whenever a `.md` file
moved). Wait for CI before opening the PR: M1 touches the migration path CI exercises across the
released schema versions, and the local gates do not run everything CI does.

## 8. Decisions taken and remaining notes

The choices §2–§7 rest on, settled with the maintainer:

1. **Images link forward, no owner column on `assets`.** The panel's `imageAssetId` and the case's
   `underlayAssetId` are the only link; the two new kinds set none of the owner columns, and the
   table's "exactly one owner" doc comment is amended to say so (§2).
2. **Annotations are rows**, one per mark, for per-mark merge across replicas — the fifth table is
   the accepted cost (§2).
3. **The frame ratio is parsed from the free-text format**, falling back to **16:9** when no ratio
   is found (`4K · 25 fps`, `anamorphic`). A structured format field is a possible v2 that would
   remove the guessing; not in scope here (§2, §1).
4. **A camera's letter is derived** from its rank among the shot's live cameras, so removing `3A`
   turns `3B` into `3A` — no gaps, in step with the shot-code rule; the letter is never stored (§2).
5. **The import picker is filtered to JPEG and PNG**, so what draws on screen always prints (the
   `pdf` package embeds only those two); other formats are converted before import (§4.2, §5).
6. **The phone gets the table only.** Board and floor plans are large-screen views in v1; the phone
   question reopens when mobile becomes a real target (§4.3).
7. **ADR 0031 is written** (M0): a storyboard as ordered panels under a shot, and floor-plan
   geometry in metres against a default-character reference with zoom as a view concern (§6).
8. **"Printed alongside" is two documents plus a toggle**: a Storyboard PDF and a Floor plans PDF as
   separate export cards, and an `Include the floor plans after each sequence` toggle on the
   storyboard dialog so the two can also travel together (§5).

Remaining notes (no decision needed, recorded so M1's agent does not rediscover them):

- **Cases of a vanished scene** stay attached to the tombstoned scene and are unreachable until it
  comes back, while the scene's shots go to the orphan group — the same shape as an orphaned shot,
  accepted as the default (no orphan plans).
- **Confirmation friction on the canvas.** The rule confirms every irreversible action, so `Delete`
  on a lone symbol opens a dialog. The plan follows the rule; if it proves heavy in practice, the
  answer is an undo feature of its own, not an exception here.
- **The v4 cycle.** If another schema change merges first, this branch overwrites the v4 step in
  place rather than creating v5 (ADR 0029); the M1 agent reads `currentSchemaVersion` /
  `currentPayloadFormat` against their stable twins at rebase time.

## 9. Floor-plan redesign (validated 2026-09-20)

M0–M8 shipped the whole feature, then a refinement wave (A store columns `setElementShape` +
`ctrlXM/ctrlYM`, B the glyph rendering, C1 the drag-offset fix + board image delete) landed. After
using the app the maintainer found the floor-plan **interaction model** confusing and asked for a
Fable pass against market tools (Shot Designer, Celtx, StudioBinder, Sweet Home 3D, Figma). The
resulting redesign is **validated** (mockup `https://claude.ai/artifact/ScomXNRpiY1ZVLPrMYRG4H`). It
**supersedes the floor-plan model of §2 (`floor_plan_cases`, the seven-value layer enum) and §4.3**;
the storyboard/board half is untouched.

### 9.1 The new model — three nouns, no "case"

- **Set** (FR « Décor ») — the room. What does not move between shots: walls, doors, furniture,
  placed props, the imported underlay. One or more per sequence = the tabs. Name = the scene
  heading's place. Replaces "case" in the UI **and** the code (`floor_plan_cases → floor_plan_sets`,
  `OcptFloorPlanSet…`).
- **Current shot** — there is **always one**. Everything "live" (cameras, characters, lights, props,
  arrows) lands on the current shot and only it; the set is **always editable**. The old sequence
  focus / tool-dimming is gone; "All cameras" becomes a **view toggle**, never a state that gates a
  tool.
- **Palette** — a left column whose group headers say **where things land** (`Set · Kitchen —
  shared` and `Shot 12/3 — this shot only`) plus a `View` group (the old tray). **No tool is ever
  dimmed.** Placement is drag-from-palette or click-to-arm (one shot, then back to select; `Shift`
  keeps it armed); a placed element is **selected at once**; a character **asks its name on the
  spot**.
- **One set layer.** `decor/furniture/fixedProps` merge into one `set`; `handProps → props`. The
  enum is `{set, cameras, characters, lights, props}`, `isSequenceScoped == layer == set`; the
  **shape** (`setElementShape`: wall/door/furniture/freeform) carries the décor type.

### 9.2 Decisions taken (with the maintainer)

Rename `cases → sets` in code too (**yes**, v4 unreleased); one set layer (**yes**); always a
current shot + "All cameras" as display only (**yes**); duplicate a set to another sequence is a
**copy, not a link**; the character name picker opens **on placement**; the palette holds the
`View` group (tray removed). Bugs to fix in the redesign: the character glyph (colour/arms/notch,
screen == paper — **done in R1**), the missing camera label on the canvas (**done in R1**), the
rotation handle reading the handle's own local position instead of the canvas (→ `globalToLocal` +
an aim handle), and immediate selection after placement.

### 9.3 Data-model delta (v4 unreleased → reshape in place, no v5, no ADR crossed)

`floor_plan_cases → floor_plan_sets` (same columns); `OcptFloorPlanLayer → {set, cameras,
characters, lights, props}` with a one-cycle back-compat name map in the converter; `setElementShape`
and `ctrlXM/ctrlYM` kept; `fovDeg` finally written; two new `OcptFloorPlanService` methods
`duplicateSet` and `copyShotBlocking` (+ symbol duplicate via `placeSymbol`). Both codec write paths
(`_applyPayload` **and** `hydratePreview`) carry every rename. `OcptFloorPlanSheet`/geometry (unit B)
and the store (unit A) are otherwise reused; the glyph fixes live in the painter and the PDF, not the
sheet. ADR 0031 (metres, 0.5 m reference, zoom out of the model, derived letters/numbers) still holds
— its one "case" mention is swapped at M8.

### 9.4 Redesign milestones (R-series), each a delegated task with the §7.1 gates

- **R0 — Store reshape** — DONE, commit `708cb6c0`: `cases → sets` rename + the layer-enum merge,
  build/tests green, behaviour otherwise preserved.
- **R1 — Rendering fixes** — DONE, commit `0da330ad`: the character glyph (own colour, forward arms,
  short notch) and the camera label pill, in the canvas painter **and** the PDF, from the sheet.
- **R2 — Canvas interaction** — always-a-current-shot in the mode/bloc; **rotation fix** via
  `globalToLocal` + an **aim handle** (`Shift` = 15° snap); **FOV edge handles** writing `fovDeg`;
  the **name popover on placement**; `Ctrl+D`/`Alt`-drag duplicate; **arrow selection + bend**
  salvaged from the C2 stash. Works on a minimally-adjusted current toolbar.
- **R3 — Chrome & duplication** — the two-tier **palette** (replaces the tray) with drag-from-palette
  placement; **set tabs** with placed-shot counts, double-click rename, a filled `＋ Set` button + its
  menu; the **"All cameras"** strip toggle + single-click on a ghost; **`duplicateSet` /
  `copyShotBlocking`** menus; the inspector groups (selection / on this set / set).
- **R4 → folds into M8** — the record.

### 9.5 The C2 stash (`git stash@{0}`) — salvage vs redo

Held (not committed) because its décor sub-tools and tap-to-name are superseded. **Salvage** (read
with `git stash show -p stash@{0}`, reimplement against the renamed code — do **not** `git stash
apply`, it predates R0): the arrow select/bend/straighten code + events/state, the FOV toggle +
per-camera stepper, the character name-picker dialog (re-triggered from placement). **Drop**: the
active-layer picker, the tool dimming, the tray edits, tap-to-name on a plain click.

### 9.6 Naming note

`OcptFloorPlanSet` (this feature) and `OcptSet` / `OcptSetsTable` (the Resources décor/location
catalogue) now both read as "Set"; the `FloorPlan` prefix keeps the classes distinct and there is no
functional conflict, but the vocabulary overlap is deliberate (the maintainer's chosen word) and
worth knowing.

## 10. Floor plans belong to the Resources set (validated 2026-09-24)

After R3 the maintainer found that a floor-plan "Set" per sequence collides with the Resources
sets and asked for a second Fable pass. It **supersedes the ownership part of §9** (a plan hanging
off a scene); the rendering, interaction and chrome of R1–R3 stay.

### 10.1 The model — three scopes

```text
Set · Kitchen — shared by every sequence   (walls, doors, furniture, underlay)
Sequence 7 — this sequence only            (breakdown props, re-dressed furniture)
Shot 7/3 — this shot only                  (cameras, characters, lights, arrows)
```

- A floor plan **is the plan of a Resources set** (`sets`), one per set, created on the first
  write. A sequence's tabs are **its `scene_sets` links**, nothing else, so the breakdown and the
  shot list always say the same thing. A Resources set is one drawable, single-level space; the
  maintainer picks the granularity per project (kitchen + hallway as one set if they are always
  played as one space).
- Link where it is **the same room**, copy where it is **another room laid out the same**:
  duplicating a set creates a new Resources set in the same location, copying its set scope only.
  `copyShotBlocking` is unchanged.

### 10.2 Decisions (with the maintainer)

Plan owned by the Resources set (**yes**); a **Sequence** scope between set and shot, holding the
props and the re-dressed furniture (**yes**); moving a set element inside a sequence asks
**"every sequence / only this one"**, the second answer writing a sequence-scope override that
replaces the original there while later set corrections still flow (**yes**); editing stays in the
shot list, the Resources set card shows an indicator and an "Open in shot list" reveal, a
Resources-side editor is a later optional step (**yes**). Defaults taken unless the maintainer
objects: props are labels prefilled from the sequence's `scene_elements` (no `elementId` yet); the
sequence ↔ set link stays manual with the heading suggestion one click away (never auto-applied);
unlinking a set from a sequence is allowed and the dialog says how many placements it carries;
deleting a Resources set tombstones its plan, and the dialog says so; dev `.ocpt` files at the
current v4 shape are recreated.

Small points: a lone camera reads `3`, and as soon as a shot has two every camera is lettered
(`3A`, `3B`); the field-of-view reach is per camera and persisted (`fovReachM`, a tip handle); the
props layer reads "Props" (not "hand props"); every leftover "case" string goes; the metrics mode
gets a small help button (not only a tooltip, which needs a long press on touch).

### 10.3 Milestones

- **R3b — Quick fixes**, independent of the reshape: the typed set tools (wall, door, furniture,
  freeform) back in the palette (salvaged from the C2 stash by reading it, never applying it), the
  camera letters, `fovReachM` + its handle, the metrics help, the strings.
- **R4 — Store reshape** (v4 in place): `floor_plan_sets.sceneId → setId` (drop `name`/`sortKey`),
  `floor_plan_symbols` gains `sceneId`, `overridesSymbolId`; the scope matrix in
  `_checkScopeInvariant`; load through `scene_sets`; `OcptLocationsService.deleteSet` cascades;
  codec, digest, `_applyPayload` **and** `hydratePreview`; the seed script.
- **R5 — Shot-list chrome**: tabs = linked sets, `＋ Set` reusing the breakdown picker and
  `createSetLinkedToScene`, the empty state with the suggestion, the three-group palette with the
  props chips, the "every sequence / only this one" move, the unlink dialog, the Resources set card
  indicator and reveal.
- **R6 (optional)** — a set-only editor in the Resources location sheet (design questions first).
- **M8** — the record, with a new **ADR 0032** (a plan belongs to the Resources set, three scopes,
  link vs copy); ADR 0031 still holds.
