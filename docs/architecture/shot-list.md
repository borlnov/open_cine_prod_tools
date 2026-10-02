<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the shot list mode

The découpage: the shot table and its inspector, the storyboard's ordered panels, the floor plan a
Resources set carries across its three scopes, and the mode's two newest documents.

## The table and the inspector

- The mode lives in `lib/ui/pages/workspace/modes/shot_list/` and reads the **selected episode**
  (ADR 0019): `OcptShotListService` owns the three shot list tables — `shots`, `shot_characters`
  (keyed to `roleId`, not a free name, since ADR 0030: a shot's characters are the production's own
  roles) and `shot_coverages` (the scenario-coverage ranges `OcptShotCoverageDialog` draws and
  `exports.md`'s scenario coverage PDF prints). A shot's code is `<sceneNumber>/<rank>`, split and
  joined by `lib/utils/ocpt_shot_code.dart` (`schedule.md`), and its `position` is a read-time rank,
  never a stored order of its own. The **table** view lists every shot grouped under its sequence,
  the shot list's own status pill, size, framing, camera move, lens, recording format and a
  difficulty dot per axis as its own columns (`Columns ▾` picks which show), each cell writing
  straight through except the free-text fields, which ride the sheets' own 2 s autosave debounce.
  The **inspector** (`OcptShotInspectorPanel`) is the sheet for the selected shot: the same
  free-text fields as read-write inputs, the cast chips reading the production's whole cast rather
  than the screenplay alone (`OcptShotCharacterChips`, ADR 0030), the coverage ranges and the
  difficulty rating control (`OcptShotDifficultyRating`, four axes — set, camera move, acting,
  sound). The mode's own workbook (`OcptShotListXlsxExportService`, ADR 0008) and the scenario
  coverage PDF are described in `exports.md`; nothing about either changes here. What follows is
  what the table never showed: the two other centre views this file exists to record.

## The three centre views and their shared chrome

- A segmented switch in the centre header (`OcptShotListCentreHeader`, built on the generic
  `OcptViewSwitch<T>` the breakdown mode's own header switch shares) picks one of
  `OcptShotListCentreView { table, board, floorPlans }`, persisted through
  `OcptPropertiesManager.shotListLastCentreView`. The left dock's sequence tree and the right dock's
  shared `Inspector`/`Versions` tabs are unchanged across the three — only the centre, the header's
  own trailing controls (`Columns ▾`/`Export XLSX` on the table, `Panel size ▾` on the board, the
  set tabs on the floor plans) and the inspector's own `leadingGroup` slot change: null on the
  table, `OcptStoryboardPanelsGroup` on the board, `OcptFloorPlanPlacementsGroup` on the floor
  plans, drawn under the panel's header and above the shared découpage every view keeps underneath.
  A **compact width offers the table alone** — the board and the floor plans stay large-screen
  views, the switch dropping their two segments rather than drawing them disabled.
  **One selection is shared by all three.** `selectedShotId` is the single truth every view reads
  and writes; the board layers `selectedPanelId` on top of it and the floor plans layer
  `selectedSetId`, `selectedFloorPlanSymbolId` and `selectedFloorPlanArrowId`, each cleared the
  moment the shot or the sequence it belongs to changes — a panel, a symbol or an arrow only ever
  belongs to the shot currently shown. Switching view keeps the shot and sequence selections exactly
  as they stood: the board scrolls its strip to the selected shot, the floor plans focus it.

## The storyboard

- **A shot holds 0..N ordered panels**, `storyboard_panels` (`shotId`, `sortKey`, a nullable
  `imageAssetId` and a free `comment`) — a shot's action rarely fits one drawing, and a panel
  **outlives its image**: replacing it tombstones the old `assets` row and mints a fresh one
  (`OcptStoryboardService.replacePanelImage`), re-pointing `imageAssetId` while the panel's own id —
  what its annotations and its stamps refer to — never changes. A panel's rank (`1/2`, `2/2`) is a
  read-time count off `sortKey`, exactly as a shot's own code is. `storyboard_annotations` is a
  second table, **one row per mark** rather than one JSON column on the panel: ADR 0010's per-column
  stamps are what merge two replicas, and a JSON blob would turn two people annotating one panel
  into a last-writer-wins over the whole layer (ADR 0031). A mark's `kind` is one of a fixed
  vocabulary — `movementArrow`, `cameraMoveArrow`, `label` — no freehand drawing of any kind, and
  its `x1`/`y1`/`x2`/`y2` are **normalised 0..1 to the frame**, so a replaced image of another size
  keeps the marks where they were. `ocptStoryboardAnnotationPointOf`
  (`lib/utils/ocpt_storyboard_annotation_geometry.dart`) is the one function that turns a normalised
  coordinate into a drawn point, read alike by the board's own overlay painter and the storyboard
  PDF, so a mark can never draw at two different places between screen and paper. `OcptStoryboardService`
  owns the CRUD (`addPanel`, `reorderPanel` writing exactly one `sortKey`, `replacePanelImage`,
  `updatePanelComment`, `deletePanel` — its annotations and its image asset tombstoned with it —
  `addAnnotation`/`updateAnnotation`/`deleteAnnotation`, and the unguarded `tombstonePanelsOfShot`
  a shot's own deletion cascades through). Importing a frame is **filtered to JPEG and PNG**, so
  what draws on screen always prints — the `pdf` package embeds only those two formats.
  **The board** (`OcptStoryboardBoard`) lists the selected sequence's shots as rows: an
  `OcptStoryboardShotLeaderCard` on the left (code, status, size, framing, camera move, lens,
  recording format, cast, the same four difficulty axes the inspector shows, every field read-only)
  and an `OcptStoryboardPanelStrip` on the right — one frame per panel at a shared row height (the
  header's own `Panel size ▾`, a **view preference for the session alone**, never persisted to the
  project) and each frame's own **derived aspect ratio** (`ocptAspectRatioOf`,
  `lib/utils/ocpt_storyboard_aspect_ratio.dart`: a `width:height`/`width/height` pair or a bare
  decimal read out of the shot's free-text `recordingFormat`, falling back to **16:9** when neither
  is found), the board heterogeneous on purpose. A shot with no panel shows a dashed
  `+ Import frame` slot alone. Reordering a panel is a drag inside the strip; drawing an annotation
  suspends it for the length of the gesture, the two sharing one drag arena. Deleting a panel is
  irreversible and only ever **asked** for, the mode opening `OcptConfirmDialog`. The inspector's
  own `OcptStoryboardPanelsGroup` mirrors the strip — thumbnail, comment, reorder, delete — and,
  while a panel is selected, its own annotations section: the `Annotate` tool picker (movement
  arrow, camera-move arrow, label) and the panel's marks, each with an editable text field and its
  own remove action.

## The floor plans

- **A floor plan is the plan of a Resources set**, not of a sequence (ADR 0032). `floor_plan_sets.id`
  **is `sets.id`** — no fresh id of its own — created lazily on the first symbol placed or underlay
  imported (each writing method of `OcptFloorPlanService` ensures the row first): two replicas that
  each draw the first mark on the very same set while offline converge onto **one** row through the
  sync merge, which is exactly why the id is a pure function of the set's rather than a freshly
  minted UUID. The sequence's own tabs — the sets shown in the centre header — are its **live
  `scene_sets` links**, the very fact the breakdown mode's own sets row reads and writes
  (`breakdown.md`): the two modes can never disagree
  about which sets a sequence is shot in, and unlinking one there is what the shot list's own tab
  close action offers back. A sequence with **no linked set** shows an empty-state gallery instead
  of a canvas (`OcptFloorPlanSetGallery`): one card per live Resources set of the whole project, its
  own thumbnail (the set's own set-scope symbols alone, drawn through the very same
  `OcptFloorPlanCanvasPainter` the real canvas uses, fitted to the card — the underlay is left out,
  too costly to decode per card of a project-wide gallery), the heading's own suggested set starred
  and listed first (`ocptSceneSetSuggestionOf`, never applied on its own), a click linking it, and a
  `Create a set…` action under the grid. Whether the gallery is showing or a set is already linked,
  the filled **`＋ Set`** button opens the breakdown's own kind of menu: the suggestion first
  (starred), `Link an existing set ▸` (grouped by location, only the sets not already linked),
  `Create a set ▸` (per existing location, then `New location…`), a divider, `Duplicate this set`
  and `Copy blocking from a shot…` — `OcptLocationsService.duplicateSetForScene` runs the first as
  one atomic transaction (mint a sibling set in the same location, copy its set-scope symbols,
  link it to the sequence), so no half-finished duplicate can be left behind. A tab's name is edited
  in place while it is selected, writing the Resources set's own `name` straight through; its close
  action only **unlinks** the set from this sequence — the plan is kept, and the unlink dialog names
  how many cameras, characters and props of this sequence's own placements stop showing until it is
  linked again (`ocptFloorPlanUnlinkCountsOf`).

  **Three scopes**, derived from a symbol's own `sceneId`/`shotId` nullness rather than stored as a
  column of their own (`ocptFloorPlanScopeOf`): **set** scope (both null) is the room itself — walls,
  doors, fixed furniture, the underlay — shared by every sequence the set is linked to; **sequence**
  scope (`sceneId` set) is what one sequence re-dresses for its own coverage, a moved chair or a
  breakdown prop, without touching the set for anyone else; **shot** scope (`shotId` set) is one
  shot's own blocking — cameras, characters, lights, arrows. The scope matrix
  `OcptFloorPlanService` enforces at every write (`_checkScopeInvariant`) is per layer: the merged
  `set` layer lands at set or sequence scope, `cameras`/`characters`/`lights` at shot scope only,
  `props` at sequence scope only — a breakdown prop is placed for one sequence's own coverage, never
  for a single shot's blocking alone, though a shot-scope **override** of one is legal (below). The
  canvas's own **palette**, down its left edge, groups every placeable entry by where it lands
  rather than by layer: `Set · <name> — shared` (the four typed décor tools — wall, door, furniture,
  freeform — at set scope), `Sequence <n> — this sequence only` (furniture and freeform again, at
  sequence scope, plus one chip per the sequence's own breakdown props — read off `scene_elements`,
  a placed prop's label filled from the chip's name but carrying no stored link back to it — and an
  `Other…` chip for a free-typed one, placed at once, selected, rather than merely arming a tool),
  and, only while a shot is focused, `Shot <code> — this shot only` (camera, character, light).
  **No entry is ever dimmed**: every one is both a click-to-arm control and a drag source, and only
  the write itself is withheld under a read-only preview. A character symbol asks its name the
  moment it is placed, offering the shot's own characters field as a convenience only — it carries
  no link back to a role. **There is always a focused shot** on the floor plans view: every "live"
  placement lands on it and only it, while the set stays editable regardless — the strip along the
  canvas's bottom edge picks which (`OcptFloorPlanFocusStrip`, one chip per shot of the sequence, a
  filled dot when it already carries a camera on the shown set, a hollow one when it does not,
  `←`/`→` walking it, the neighbours it tags `prev`/`next`). Those same two neighbours draw on the
  canvas itself as faint, non-interactive **onion-skin** ghosts at reduced opacity — the palette's
  own `Onion skin` block toggling each side and their shared opacity — and double-clicking one on
  the canvas refocuses the strip onto its shot.

  **The override rule** is the same mechanism run twice, one scope down each time. A sequence-scope
  symbol may **override** a live set-scope symbol of the same set (`overridesSymbolId`): moving,
  rotating or resizing a set-scope element used by two or more sequences asks, in a small bubble at
  the element, `Only sequence n` (writes a sequence-scope override replacing it for this sequence
  alone) or `Every sequence (n)` (writes the set-scope original directly, reaching every sequence at
  once) — a set used by one sequence alone moves without asking. A shot-scope symbol may in turn
  override a live **sequence-effective** one (a plain prop or re-dressed furniture, or itself
  already a sequence-scope override) the very same way, one level further down: `Only shot n` or
  `The whole sequence`, gated on the sequence carrying two or more shots. Either override may be
  **hidden** rather than moved (`isHidden`): masking the original for that one sequence or shot
  without deleting anything, drawn as a faint but still **selectable** ghost the inspector's own
  `Restore` action brings back. A **live, visible** override draws with a dashed outline and a pin
  badge, still fully editable, its own replaced original drawn as a faint, non-interactive ghost
  beside it. Deleting a shared element goes through `OcptConfirmDialog.showWithAlternative`, the
  three-button extension of the app's one confirmation widget: `Cancel` / `Remove from sequence n`
  (or `…shot n`, a **hidden** override) / `Delete everywhere` (destructive, resolving to the
  set-scope original through its own `overridesSymbolId` and tombstoning every override of it too);
  an element used by only one sequence or shot skips straight to the plain two-button dialog.
  `OcptFloorPlanSheet.of` — the pure model both the canvas and the PDF draw from, below — is what
  resolves set → sequence, then, under a shot focus, sequence → shot, replacing an overridden
  original with its live visible override or masking it entirely under a hidden one, the same rule
  run twice.

  **Cameras are numbered by shot rank**, never stored: a camera symbol's label is the shot's own
  1-based rank in its sequence alone (`3`) while the shot carries only one camera on this set, and
  the moment it carries a second, **every** camera of that shot is lettered from the first
  (`3A`, `3B`, …, skipping `I`/`O`, the slate convention, and rolling into `AA` past `Z`) — removing
  a camera therefore shifts every later one's own letter down at the next read, never a gap closed
  by hand. A camera also carries a **field of view**: an angle (`fovDeg`, a `−`/`+` stepper in the
  inspector or a drag on the canvas's own edge handles) and a **reach** — `fovReachM`, the wedge's
  own **axial height** from the lens to its far chord, never the length of either angled edge —
  drawn as a wedge from the symbol, toggled as a whole from the palette's `View` group. The same
  group holds a visibility eye per layer (a count beside each, from what the sheet currently draws
  before the eye's own filter), the underlay's own eye and `Clear underlay`, and the cameras row
  expanded into one sub-row per live camera of the sequence with its own eye — the empty numbers a
  hidden camera leaves are exactly what the focus strip's hollow dots already say.

  **Framing.** Opening a set — from the Resources reveal below or by switching tab — fits the view
  to the plan's own content once, and a toolbar `Recenter` control repeats that fit on demand
  (`ocptFloorPlanFitOf`, `lib/utils/ocpt_floor_plan_fit.dart`: the sheet's own tight, rotated
  bounding box over every symbol, arrow and the underlay, centred in the viewport with a margin,
  never zooming in past a ceiling for a very small room). **Drawing is data**: `OcptFloorPlanSheet`
  (`lib/models/ocpt_floor_plan_sheet.dart`, pure Dart, no Flutter and no `pdf` import, the sibling of
  `OcptScenarioCoverageLayout`) freezes a set's own live rows, for one focus, into a list of shapes
  already in metres and already carrying an ARGB colour — a character's facing disc (colour derived
  from its own label, `ocptFloorPlanCharacterColourOf`, a stable hash so the same name always reads
  the same colour with no palette stored anywhere), a camera's body and its field-of-view wedge, a
  light's body and beam, and a décor primitive for a set element (wall, door, furniture or freeform,
  `OcptFloorPlanSetElementShape`) — plus every movement and camera-move arrow, straight or, once
  bent at its own handle, a quadratic bezier. `OcptFloorPlanCanvasPainter` (the screen) and
  `OcptFloorPlanPdfService` (the floor plans PDF) both only draw what the sheet says, so screen and
  paper can never disagree about what a plan looks like. **Geometry is stored in metres**
  (ADR 0031): every symbol's position, footprint and the underlay's own frame are real numbers of
  metres, and the **default character footprint, 0.5 m, is the implicit ruler** — an always-visible
  reference silhouette and a scale bar (`ocptFloorPlanScaleBarLengthM`, rounded to a "nice" `1 m`,
  `2 m`, `5 m` and their decades) sit at the canvas's own corner, both reflecting the current zoom —
  a **view concern kept out of the synchronised model entirely**: two replicas at different zooms
  never generate a conflict over it. There is no calibration dialog: a room is sized against the
  silhouette, and an imported underlay is dragged and resized until its own doors and tables match
  it. A **metrics toggle** overlays the distance from the selected symbol to every other visible one
  of the set (and camera-to-subject for a selected camera), from the very same pure rule
  (`ocptFloorPlanDistanceM`), with its own inline help paragraph behind a real button rather than a
  tooltip — a tooltip's tap trigger needs a long press once it sits behind a checkbox row, which
  never reaches a touch device.

  **The Resources set line and the reveal.** A set's own sheet, in the resources mode's location
  card (`resources.md`), shows `Floor plan · N sequences` (or `No floor plan yet`) and, while it is
  linked to at least one live sequence, an `Open in shot list` action — `OcptShotListRevealRequest`,
  the cross-mode reveal that switches to the shot list, its floor plans view, on the set's first
  linked sequence, the plan already showing. **Deleting a Resources set or its whole location
  cascades into the plan**: `OcptLocationsService.deleteSet`/`.deleteLocation` tombstone every
  `floor_plan_sets`/`floor_plan_symbols`/`floor_plan_arrows` row of the set through
  `OcptFloorPlanService.tombstoneFloorPlanRowsOfSet` — a plan drawn against a décor the production
  no longer has is not a fact worth keeping. Deleting a **shot** tombstones its own shot-layer
  symbols and every arrow it carries the same way, through `OcptShotListService.deleteShot`'s own
  cascade. Every write across the floor plans view is a **null callback** under a read-only
  preview — the canvas's own `onSymbolPlaced` closing the whole placing gesture at once, the
  palette's drag sources withdrawn, the set tabs' own edits withheld — while the palette's own
  visibility eyes, the zoom and the metrics overlay stay, since they only ever read.

## Sync, versions and the read-only preview

- The five tables above — `storyboard_panels`, `storyboard_annotations`, `floor_plan_sets`,
  `floor_plan_symbols` and `floor_plan_arrows` — are schema v4 (`foundations.md`, ADR 0029), created
  additively by `ocpt_migration_v4.dart`, and travel in payload format 4, added to
  `OcptProjectVersionCodec`'s `encode`/`decode`/`contentDigest` and to both of
  `OcptProjectVersionsService`'s hand-written table lists: `_capturePayload`/`_applyPayload` (a
  restore rewriting the same database) **and** `hydratePreview` (a preview hydrating a fresh
  in-memory one) — the second being the one a table can be added to and still pass every capture and
  codec test, its omission only ever showing up as a table silently empty in a **previewed**
  version. Restore order matters: `floor_plan_sets` and `storyboard_panels` after `shots` and
  `assets` (a panel and a set's own underlay both point at one), `storyboard_annotations` after its
  panel, `floor_plan_symbols` after its set — an override's own self-reference onto another symbol
  row already covered by the deferred foreign keys every restore opens under — `floor_plan_arrows`
  last, after the two symbols it connects. None of the five holds anything about a person, so the
  erasure scrub leaves all five untouched. The canvas, the palette and the set tabs are one more
  composite taking `isReadOnly` (`foundations.md`), each null callback withholding one write while
  everything that only reads — the layer eyes, the zoom, the metrics overlay, a click that merely
  selects — stays exactly as it is outside a preview.

## The paperwork

- The export panel's storyboard and floor plans cards each print one of the two documents this
  feature adds, both PDFs, each greyed with its own reason when there is nothing to print — no
  panel anywhere for the storyboard, no placed camera anywhere for the floor plans — rather than
  hidden. `OcptStoryboardPdfService` prints, per sequence, one row per shot: the leader card's own
  key information beside its panels at a shared height and their derived aspect ratios, their
  annotations drawn from the very same normalised geometry the board's own overlay reads, a missing
  or undecodable frame printing the placeholder and its `file not found` label rather than failing
  (ADR 0013, on paper). `OcptFloorPlanPdfService` draws the very same `OcptFloorPlanSheet` the
  canvas draws, **never ghosted**: one page per shot that carries a live camera on a given set, or
  one bare page for a set that carries none, the scale bar and the reference silhouette printed on
  every page exactly as they draw on screen, the underlay printed as the real referenced image and
  falling back to a schematic frame under the very same missing-file rule. The storyboard dialog's
  own `Include the floor plans after each sequence` toggle reuses the floor plans service's own
  page-building method rather than drawing a second copy of them, so the two documents can travel
  together without ever disagreeing about what a plan looks like. Both share the app's other PDF
  services' own `OcptCourierPrimeFontsLoader` — fourteen services in all now (`exports.md`).
