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
  Tagging is a two-click range: a first click opens an anchor, a second closes it and opens
  `OcptBreakdownTagPopover`, whose search field is **pre-filled with the passage** and whose results
  are grouped by kind; clicking a result links, clicking a **category chip** creates the element in
  that category and tags it in one write, then hands off to the inspector where the rest of the
  sheet is. Elements and **sets** are the two things creatable here — a role's existence belongs to
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
  (`lib/utils/ocpt_breakdown_suggestions.dart`, whole-word and diacritic-folded), the principle
  `ocptSceneSetSuggestionOf` already follows. The header's search filters the recap's **rows** and
  never its columns, and typing into it from the script view switches to the recap carrying the
  text: the script is a reading surface, and the answer to "where is this?" is a table.
  The scene inspector's own **sets row** is the one part of the mode that is not about tags: it
  reads and writes `scene_sets` directly (`OcptBreakdownSceneSetLinkedEvent`/`…UnlinkedEvent` onto
  `OcptLocationsService`), so a link made by hand in the resources mode shows here and one made here
  shows there — no tag is created, nothing is highlighted, and unlinking leaves every tag pointing
  at that set exactly where it is. It sits at the top of the sheet because that is where a
  breakdown sheet names its décor, and its picker offers `ocptSceneSetSuggestionOf`'s answer first,
  marked as a suggestion and never applied. Beside that picker it **creates** one
  (`OcptLocationsService.createSetLinkedToScene`, the tagless sibling of `createSetAndTag`, minting
  the location too when the menu's own "in a new location" entry is picked): a scene whose place
  the project has never heard of is the ordinary case at the start of a pass, and the name is not
  asked for — it is `ocptSceneHeadingPlaceOf`'s reading of the heading, resolved by the mode so the
  menu and the event can never derive it differently. Every entry of a set-creation menu carries a
  **non-null** value (`ocptNewLocationMenuValue`): `PopupMenuButton` reads a null result as "the
  menu was dismissed" and never calls `onSelected` for it, so an entry valued null silently does
  nothing. A set is shown as `<set> · <location>` everywhere outside the location sheet holding it
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
