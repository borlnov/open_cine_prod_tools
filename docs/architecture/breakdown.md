<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the breakdown mode

The *dépouillement*: tagging the script with what the shoot must provide, the pass's own
progress per scene, and the two documents it prints.

- Breakdown mode (`lib/ui/pages/workspace/modes/breakdown/`): the *dépouillement* — reading the
  script once and tagging what the shoot must provide. It is the pass that fills the catalogues the
  resources mode holds, so it sits between the screenplay and the shot list in the mode switcher.
  It reads **the episode the workspace has selected** (ADR 0019) — its scenes, its tags and its
  breakdown sheets — while the catalogues it fills stay the production's; `OcptBreakdownScene`'s
  own `displayNumber` is `ocptSceneDisplayNumberOf`'s answer, so a sequence reads `2.12` in every
  surface of the mode and in both its documents as soon as the project holds more than one episode.
  A **tag** (`breakdown_tags`, ADR 0014) is the anchor between a passage of the screenplay and the
  catalogue row it calls for: a discriminator (`OcptBreakdownTargetKind { element, role, set }`)
  plus three nullable foreign keys, exactly one non-null. A character is never an `elements` row —
  it is the `roles` row `OcptRoleIndexService` already reconciled from the cue — and a place is a
  `sets` row, which is why a tag points at one of three tables rather than one.
  Offsets are **scene-relative**, as `shot_coverages` are, and the tag stores its passage
  **verbatim** (`taggedText`) where `shot_coverages` stores only a digest: the text is what lets a
  shifted tag be re-anchored rather than merely flagged, and what the occurrence suggestions match.
  `OcptBreakdownService` (owned by `OcptProjectsManager` beside the resources services) writes them,
  and creating a tag **ensures the link it implies** in the same transaction — a `scene_elements`
  row for an element, a `scene_sets` row for a set, nothing for a role, the tag being that link
  itself. Removing a tag **never** removes that link row: the resources mode lets a user link an
  element to a scene by hand with no tag at all, and the breakdown cannot tell its link from that
  one, so the inspector asks about the removal as a separate question.
  `reconcileTags` joins `OcptSceneIndexService`/`OcptRoleIndexService` on the screenplay save path,
  **after** the scene index is rebuilt since it needs the new `charStart`: a tag whose slice still
  matches is left alone, one whose stored text is found **exactly once** in the scene is re-anchored
  silently, and only zero or several matches raise `needsCheck` — surfaced the way
  `shots.needsCheck` is. It writes nothing when nothing changed, running as it does on every save.
  `scene_breakdowns` holds how far the pass has got per scene (`OcptBreakdownSceneStatus { toDo,
  inProgress, done }`, **held by hand** — a scene may legitimately need nothing and still have been
  read), one live row per scene created on the first write, never eagerly; a scene with no row reads
  as `toDo`. `elements.status` (`OcptElementStatus { toFind, reserved, beingMade, confirmed }`) is
  the column the mode's chips and the "to find" counters read, and the resources mode's element
  sheet carries the same control; the three existing booleans answer a different question (on the
  truck? given back?) and stay untouched.
  The centre is either the **script view** — the whole screenplay typeset as a paper sheet, every
  word clickable, tagged passages highlighted in their category's colour — or the **recap**
  cross-table (one row per target, one column per scene), switched from the mode's own header band.
  On a phone the script view drops the fixed page width and fills the row instead, scaling every
  indent and box width down by `OcptEditorPreviewLayout.compactLayoutScale` — the same factor the
  screenplay editor's own compact fluid surface uses (`screenplay.md`) — so the tagging surface reads
  the way the writing one does there rather than spending most of a phone's row on the print margin.
  Tagging is a two-click range: a first click opens an anchor, a second closes it and opens
  `OcptBreakdownTagPopover`, whose search field is **pre-filled with the passage** and whose results
  are grouped by kind; clicking a result links, clicking a **category chip** creates the element in
  that category and tags it in one write, then hands off to the inspector where the rest of the
  sheet is. A clicked word is a whitespace-delimited run of the source, so the passage the two
  clicks designate is narrowed by `ocptBreakdownTaggedSpanOf` before it is recorded: the quotes,
  brackets, commas and full stops hugging either end belong to the sentence rather than to the
  thing being tagged, and so do the emphasis markers Fountain writes around a word — a passage made
  of punctuation alone is kept whole, having no word to narrow down to. Only the ends are touched,
  never what a range spans in between, and this is the breakdown's own rule: a scenario coverage
  range quotes a passage of the script, where the sentence's punctuation belongs.
  Elements and **sets** are the two things creatable here — a role's existence belongs to
  the screenplay, `OcptRoleIndexService` reconciling it from the cue, so inventing one would be
  inventing a character. A set has no such source: the script names the place and the project has
  never heard of it, so the popover's own `Create a set` control picks the location holding it out
  of the ones the project has, or mints one named after it (`OcptBreakdownService.createSetAndTag`,
  the sibling of `createElementAndTag`, rolling *every* write back when the tag half is refused).
  `Open in Resources` is offered beside them for everything else. Tags never overlap
  (the mode greys the affordance, `OcptBreakdownService` guarantees it), and a click on an
  already-tagged word therefore **selects its target** rather than starting a range — deliberately
  *not* what the same click does in `OcptShotCoverageDialog`, where it removes the range: here a tag
  has a sheet worth inspecting, and losing one by mis-clicking while reading is the worse failure.
  A repeated occurrence elsewhere in the script is **offered, never applied**
  (`lib/models/rules/ocpt_breakdown_suggestions.dart`, whole-word and diacritic-folded), the principle
  `ocptSceneSetSuggestionOf` already follows. The header's search filters the recap's **rows** and
  never its columns, and typing into it from the script view switches to the recap carrying the
  text: the script is a reading surface, and the answer to "where is this?" is a table.
  The scene inspector's own **sets row** is the one part of the mode that is not about tags: it
  reads and writes `scene_sets` directly (`OcptBreakdownSceneSetLinkedEvent`/`…UnlinkedEvent` onto
  `OcptLocationsService`), so a link made by hand in the resources mode shows here and one made here
  shows there — no tag is created, nothing is highlighted, and unlinking leaves every tag pointing
  at that set exactly where it is. The very same links are the shot list's own floor-plan tabs
  (`shot-list.md`): a set linked to a sequence here is a set the shot list can draw a plan under, and
  unlinking it there is what the shot list's own `Unlink` offers back. It sits at the top of the sheet
  because that is where a
  breakdown sheet names its décor, and a single `+ Set` control
  (`OcptBreakdownSetPickerPopover`) both links and creates. Its own text field opens pre-filled
  with `ocptSceneHeadingPlaceOf`'s reading of the heading, resolved by the mode so the popover and
  the event can never derive it differently, but is editable before either action: it doubles as
  the filter for the existing sets not already linked (the heading's own suggestion,
  `ocptSceneSetSuggestionOf`, listed first and marked as such) and as the name a creation
  (`OcptLocationsService.createSetLinkedToScene`, the tagless sibling of `createSetAndTag`, minting
  the location too when its own "in a new location" entry is picked) gives the new set: a scene
  whose place the project has never heard of is the ordinary case at the start of a pass, and
  correcting a wrong guess is typing over it rather than renaming the set afterwards. A set is
  shown as `<set> · <location>` everywhere outside the location sheet holding it
  (`ocptBreakdownSetLabel`), which is why `OcptBreakdownSnapshot` carries the whole `locations`
  catalogue and derives `locationNameById` from it.
  The target inspector's **title is its name field**: an element or a set created from the popover
  carries the passage's own wording, and the moment to correct that is while reading it, not after
  scrolling past a status grid to a field repeating it. Renaming there renames the catalogue row
  itself, so the script's tooltips, the legend, the recap and the resources mode all follow — a set
  riding `pendingSetNameEdits` on the same debounce an element's fields do. A **role** is the one
  kind read out rather than typed into, its name being the screenplay's. Its `Open in Resources` is
  the app's one cross-mode navigation: it switches to the resources mode **and lands on the record's
  own sheet**, through the reveal request the workspace shell carries (above) — an element on the
  elements tab, a role on the roles tab, and a set as the location that holds it. The popover's own
  `Open in Resources` deliberately carries none: it is only ever shown when the search names no role
  and no set, so there is no sheet to land on — the user is going there to create one.
  The left dock is the scene list (status, a colour bar per category present, counts) over the
  category legend, whose entries toggle their category's highlighting; the right dock is
  `Inspector` + the shared `Versions` tab, the inspector showing the selected target's sheet or —
  with nothing selected — the selected scene's own breakdown sheet. `lib/constants/
  ocpt_breakdown_palette.dart` maps a colour **per category** rather than per rank (unlike a shot's
  coverage colour): a category must read the same in every project and every export.
  The export panel offers the pass in **two formats**: the breakdown sheets PDF (one printed sheet
  per scene, the document a department head is handed) and `OcptBreakdownXlsxExportService`'s
  two-sheet workbook (the document the production office reworks, which a PDF cannot be) — a
  `Scenes` sheet, one row per scene, and a `Breakdown` sheet in the **long, filterable** form: one
  row per (scene × **distinct** target), its passages joined into one cell. Distinct, and not one row
  per tag, for the reason the whole app already counts them that way
  (`ocptBreakdownSceneTargetsOf`: "a target tagged twice in the same scene counts once here") — the
  `Scenes` sheet writes that very figure in its own count column, and a `COUNTIF` over the other
  sheet disagreeing with it would be the workbook contradicting itself. The workbook asks **no
  options at all**, exactly as the shot list's and the resources' own do: picking its card goes
  straight to the native save dialog.

## The blocs

- **The mode is one mode bloc and three view blocs** (ADR 0034; `foundations.md` states the idiom).
  The mode is not cut by central view: the script and the recap are two renderings of the same
  data, and the recap holds no selection of its own and writes nothing. What carries its own state
  and its own writes is a *function*, so the cut is by function: tagging the script, the inspector
  and the exports. `OcptBreakdownMode` builds `OcptBreakdownBloc` first, then
  `OcptBreakdownExportBloc`, `OcptBreakdownInspectorBloc` and `OcptBreakdownTaggingBloc` with
  `lazy: false`, so each has registered its flusher before a widget reads it. The files sit in
  `lib/ui/pages/workspace/modes/breakdown/`; the events are one sealed hierarchy per domain in
  `events/` (`workspace` for the mode's chrome, the legend, the centre and its search, `selection`,
  `tagging`, `inspector`, `export`), all extending the abstract `OcptBreakdownEvent`, and
  `breakdown_event.dart` only exports them.
  - **The mode bloc** holds the snapshot (the scenes and tags joined with the four catalogues, one
    `OcptBreakdownSnapshot`), the screenplay text and the page setup the script is typeset with,
    the selected scene and the selected target (with the suggested occurrences derived from them),
    the legend's hidden keys, the centre view and the search, the docks, the version and package
    mixins, and the pending-writes contract. `OcptBreakdownReloadScope` has one value, `snapshot`:
    the snapshot is read as a whole, and the screenplay text and the page setup are read by a whole
    load alone, the page setup also by the project settings page, which moves no selection.
  - **The selection is the mode's**, and every way of moving it names itself in
    `OcptBreakdownSelectionCause` and moves `selectionEpoch`, also when the selection ends on the
    very same row. Selecting a scene from the left dock or from a target's occurrences is quiet
    (`scene`: it leaves the selected target and the right dock alone), whereas a click on a script
    heading is loud (`sceneHeading`: it drops the selected target, opens the right dock on the
    `Inspector` tab and returns to it from `Versions`). Selecting a target (`target`) also selects
    the scene the click happened in and opens the `Inspector` tab; clearing it is `targetCleared`.
    A first click of the script that opens an anchor in another scene selects that scene
    (`anchorScene`, `OcptBreakdownAnchorSceneSelectedEvent`), which differs from `scene` in the
    one stale case: a scene that is gone drops the scene selection instead of being ignored. The
    `centreView` cause is not a selection but the centre leaving the script (the header's switch,
    asked for again or not, or a search typed from the script, which switches to the recap), and
    `load` is a whole read, which clears both selections. Every selection first has every view
    write what it holds; the switch of the centre and a whole read do not (the callers of the
    latter flush before they ask). The events a view must
    wait for (`OcptBreakdownTargetSelectedEvent`, `OcptBreakdownAnchorSceneSelectedEvent`) are
    registered with `onAwaited`.
  - **`OcptBreakdownTaggingBloc`** owns the range the script is being tagged with
    (`pendingTagAnchor`, `pendingTagRange`) and the refusal notice (`hasTagWriteError`), and writes
    the three answers of the popover and the suggestions accepted from the target inspector. A
    popover answer is the service, then `await modeBloc.reload({snapshot})`, then the move of the
    mode's selection to the new target on the `Inspector` tab (awaited), and only then the popover
    closes and the anchor clears: a read that fails leaves the range open rather than select a
    target the snapshot may not hold, and a refused write leaves it open with the notice raised. A
    suggestion accepted reads again and leaves the selection where it is. **It reacts to two causes
    and to nothing else**: `load` drops the anchor, the range and the notice (the script they
    belonged to is another one, which is also what a preview does: it keeps the search text and the
    choice of script or recap but drops the selection and the pending anchor), and `centreView`
    drops the anchor and the range. A scene or a target being selected clears nothing, so an anchor
    opened in one scene survives the user browsing the left dock until the next click replaces it.
  - **`OcptBreakdownInspectorBloc`** owns the typed edits of the two sheets
    (`pendingElementFieldEdits`, `pendingSceneNotesEdits`, `pendingSetNameEdits`, one debounce for
    the three) and every write of them: a scene's status and notes, the sets linked to a scene, a
    target's status, category, owner, who brings it, name and fields, the tag removal, the
    `needsCheck` clearing and the removal of a flagged tag. A write is the service, then
    `await modeBloc.reload({snapshot})`. It reacts to `load` alone, by dropping every typed edit
    (the caller flushed first whenever losing one would matter); an ordinary re-read after a write,
    a selection and the project settings page clear nothing, and nothing is pruned for a row that
    disappeared from the snapshot.
  - **`OcptBreakdownExportBloc`** runs the sheets PDF and the workbook and owns the transient
    notice. Each one first has the mode write what is pending (`flushAllPendingWrites`), then reads
    the snapshot, the screenplay text, the page setup and the title the mode holds.
  - **A flush never stops what it was asked for.** The inspector reads its own failure: a write
    that fails is logged by its service, the edits it meant to write are forgotten, the snapshot
    is not read, and the flush answers true, so a selection, a preview, a restore, a saved
    version, a package export and an export all go ahead on the value the database holds, as they
    always did. A read that
    fails after a write that landed forgets what was written all the same. What a flush waits for
    is the mode's own: a selection, a right dock tab change, a word click that closes a range, a
    tag write and every export flush first; switching between the script and the recap, toggling a
    dock and the legend do not.
