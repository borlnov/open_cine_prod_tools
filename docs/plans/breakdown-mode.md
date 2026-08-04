<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Breakdown mode — reading the script once and tagging what the shoot must provide

This document is the implementation strategy for the breakdown production mode
(*dépouillement du scénario*), issue #47. It is written for the Sonnet 5 agents that will build it,
orchestrated and reviewed by the main session, with a user checkpoint between each milestone.
**Read the repository `AGENTS.md` first** — this plan assumes its architecture, ways of working,
coding standards, licensing rules and verification gates, and does not repeat them.

The mode's screen design is validated: it is the `Dépouillement` mode of the
`OpenCineProdTools App Design` Claude Design project. Where this plan and that mock-up disagree on
layout, the mock-up wins; where they disagree on data, this plan wins, because the mock-up invents
its own flat data model and the repository already holds most of what it needs.

---

## 1. Why this step exists

Breaking down the script is the hinge of preparation. It is the pass where one person reads the
screenplay line by line and writes down every thing the shoot will have to provide: a prop, a
costume, a vehicle, an animal, a special effect, a character, a block of extras, the set itself.
Everything downstream reads the result — the schedule groups scenes by what they need on the same
day, the call sheet prints who and what has to be there, the budget costs what the breakdown found,
and the first assistant director answers "can we still shoot scene 12 on Thursday?" from it.

Step 26 (issue #45) built the catalogues this pass fills — `elements`, `roles`, `sets` — and the
links it produces — `scene_elements`, `scene_sets`. It deliberately left the breakdown *view* out
of scope. So today a user has to type an element into the resources mode from memory and then link
it back to a scene by hand, with nothing to tell them which passages of the script have been read
and which have not.

This step is that view, plus the two facts the catalogues cannot hold on their own:

- **where in the text** a thing is called for — the passage, not just the scene;
- **how far the breakdown has got** — per scene, held by hand.

## 2. What ships

A new `OcptWorkspaceMode.breakdown`, the third implemented mode, placed **after `screenplay` and
before `shotList`**: write, break down, then shoot-list, which is the order the work happens in.

- **Script view** (centre, default): the screenplay typeset on a simulated paper sheet in Courier
  Prime at its true screenplay indents, every word clickable. A tagged passage is highlighted in
  its category's colour. A first click opens a range, a second closes it, and a popover offers to
  link the passage to an existing element, role or set — or to create one on the spot, in one of
  the categories, without leaving the script.
- **Recap view** (centre, toggled): the cross-table of the design — one row per tagged target, one
  column per scene, grouped by category, carrying status, owner and occurrence count.
- **Left dock**: the scene list, each row showing its breakdown status, a colour bar per category
  present and its element count; underneath, the category legend, whose entries toggle the
  highlighting of their category in the script view.
- **Right dock**: `Inspector` and the shared `Versions` tab. The inspector shows the selected tag
  target (status chips, category chips, details, its occurrences in the script with a jump), or —
  when nothing is selected — the current scene's own breakdown sheet: counts, an alert naming the
  elements still to find, and the scene's elements grouped by category.
- **Status bar**: total tagged targets, categories used, and the count still to find.
- **Export**: the breakdown sheets as a PDF, one sheet per scene, through `OcptExportManager` like
  every other export.

Schema **v9**, project-version payload **format 5**.

### 2.1 The nominal gesture, end to end

Everything else in this plan serves this sequence. An agent that has to choose between two readings
of a requirement picks the one that keeps this gesture short.

The user is reading scene 1: *"A room lit by the desk lamp alone."*

1. They click **desk**. The range opens and the word is marked pending.
2. They click **lamp**. The range closes on `desk lamp` and the popover anchors under it.
3. The popover holds a search field **pre-filled with the passage**, the matching targets grouped
   `Roles` / `Sets` / `Elements` underneath, and the category chips at the bottom.
4. **The thing already exists** — the same lamp was broken down in scene 8. It is in the list, with
   the scenes it already appears in beside its name. One click: the tag is written, the
   `scene_elements` link is ensured, the popover closes, the inspector shows the element. The user
   reads on.
5. **It does not exist.** The user corrects the name in the field if they want to
   (`Desk lamp, 1960s`), then clicks the **`Prop`** chip. That single click creates the element in
   that category with status *to find*, writes the tag, closes the popover and opens the inspector
   on the new element — where the rest of the sheet is (sub-category, quantity, owner, who brings
   it, notes). Filling it is optional: the breakdown pass can carry straight on and the sheets be
   completed later.

The two paths are one keystroke apart and neither ever leaves the script. That is the whole point:
a breakdown pass is a hundred of these in an afternoon, and anything that costs a dialog, a mode
change or a second decision is what makes people do it in a spreadsheet instead.

Clicking an already-tagged word is not step 1 of a new range — it selects that tag's target in the
inspector (§3.9).

## 3. Decisions

These were settled with Benoit before this plan was written. An agent does not revisit them.

### 3.1 A tag points at an element, a role **or** a set

The mock-up's flat "element" list mixes `Personnages` and `Figuration` in with the object
categories. The repository already answers those two from `roles`, reconciled from the screenplay
by `OcptRoleIndexService`, and the set of a scene from `sets` / `scene_sets`. Creating parallel
`elements` rows for characters would duplicate the cast and let the two drift apart.

So a breakdown tag carries a **target kind** and points at exactly one of the three tables. Tagging
`LÉA` in the script attaches the passage to the role already reconciled from the cue; tagging
`la cuisine` attaches it to a set; everything else is an element.

### 3.2 `elements` gains a `status` column

The mock-up gives every element one status among *to find / reserved / being made / confirmed*, and
leans on it heavily: the chips, the "unsecured elements" alert on a scene, the "to find" counter in
the status bar. The three existing booleans (`isSecured`, `isReadyForShoot`, `isReturned`) cannot
express *reserved* or *being made*, and they answer a different question anyway — on the truck? given
back? So `elements.status` is a new column and the three booleans stay untouched. This is an
additive migration, as ADR 0007 requires.

### 3.3 The passage is designated by clicking words, not by selecting text

The mock-up uses the browser's own text selection. The app already has this interaction, built for
the scenario coverage: `OcptShotCoverageDialog` lays a scene out into blocks of clickable words and
takes a first click as the start of a range and a second as its end. Reusing it keeps one gesture in
the app for one meaning, and `OcptShotCoverageLayout` — whose `of({sceneId, sceneText})` factory is
already free of anything shot-specific — is reusable as it stands.

### 3.4 A repeated occurrence is offered, never applied

Once `la lettre manuscrite` is tagged in scene 1, the same words elsewhere in the script are
*suggested*, and the user confirms each one. This is the principle `ocptSceneSetSuggestionOf`
already follows for scene ↔ set: `la clé` in scene 3 is not necessarily the key of scene 1, and a
breakdown that quietly invents links is worse than one that asks.

### 3.5 A scene's breakdown status is held by hand

*To do / in progress / done*, marked by the person doing the work. It cannot be deduced from the
element count: a scene may legitimately need nothing at all and still have been read and broken
down, and a scene with three elements may be half-read. The progress bar in the mock-up's header
counts scenes marked done.

### 3.6 The right dock has two tabs

`Inspector` and `Versions`. No metadata tab: the screenplay's statistics and title page belong to
the screenplay mode, and this mode's inspector already carries everything about what is selected.

### 3.7 A tag stores the tagged text verbatim, not a digest

`shot_coverages` stores only `coveredTextDigest`, deliberately — a coverage range can be a whole
page and there is no point duplicating it. A breakdown tag is a few words, capped well under a
line. Storing the text itself costs nothing and buys two things a digest cannot give:

- **relocation**: when an edit inside a scene shifts a tag's offsets, the service can search the
  scene for the stored text and re-anchor the tag instead of only flagging it;
- **suggestions** (§3.4): finding the other occurrences of a tag needs the words, not their hash.

This is a departure from the neighbouring table and must be recorded as such — see §8, ADR 0014.

### 3.8 The popover links, the category chip creates, the inspector completes

The mock-up's popover matches existing elements on the clicked words alone. That works for a demo
and fails on a real film: by scene 20 there are a hundred and fifty elements, and the one being
looked for is found by typing `peu`, not by having clicked exactly the words its name was built
from. So the popover carries **a search field**, pre-filled with the passage, filtering the three
catalogues live and grouping its results by kind.

Creating stays where the mock-up put it — **on the category chips**. Clicking `Prop` creates the
element in that category, named from the field, and writes the tag. There is no separate "Create…"
button: picking the category *is* the creation, which is what keeps step 5 of §2.1 to one click.

What the chip cannot ask for — sub-category, quantity, owner, who brings it, notes — is filled in
the **inspector**, which opens on the new element. The popover is where a thing is named and
classified; the sheet is where it is described.

Only **elements** can be created this way. A speaking role is reconciled from the screenplay, and
creating one by hand yields a silent role or an extra — a decision that belongs to the resources
mode's role sheet. A set belongs to a location, which the popover has no room to ask for. Both are
therefore linkable but not creatable here, and the popover offers `Open in Resources` when the
search comes back empty for them.

The element is written to the database **the moment the chip is clicked**, not held as a draft: the
tag needs a target that exists, and "everything writes the moment it changes" is the invariant every
other mode of this app already keeps.

### 3.9 Tags never overlap, and a click on a tagged word selects it

A range may not be opened inside an existing tag, and a tag may not be extended over one. The
highlighting then carries exactly one colour per passage, and the recap's counts have one reading.

A click on an already-tagged word therefore cannot mean "start a range", and it means **select this
tag's target in the inspector**. Note that this is deliberately *not* what the same click does in
`OcptShotCoverageDialog`, where clicking covered text removes the range: there, removing is the only
thing a click could usefully mean, because a coverage range has no sheet to inspect. Here a tag has
a target with a whole sheet behind it, and removal is one line further down in that sheet. Losing a
tag by mis-clicking while reading would be the worse failure.

### 3.10 The search lives in the mode's header and filters the recap's rows

One field, in the header band beside the `Script` / `Recap` switch, visible in both views. Typing
into it from the script view **switches to the recap** carrying the text: the script view is a
reading surface, and the answer to "where is the Peugeot?" is a table, not a highlight.

It filters the recap's **rows** — name, category, sub-category, owner, notes — and never its
columns: keeping every scene column is what lets the user see, in one line, where the thing they
just found falls across the film. Folding is diacritic- and case-insensitive, reusing
`ocpt_resources_search.dart`, so `lea` finds `Léa`.

## 4. Data model — schema v9

Three changes. Follow the sync-ready rules of ADR 0010 throughout: every new table carries
`isDeleted`, every read filters tombstones out, no service ever hard-deletes a row, and a table
whose rows the user reorders carries `sortKey` (neither of these two does — see below).

The schema number is allocated **at merge time, not now** (ADR 0007). If another branch merges
first, renumber, and keep `_migrationSteps` and the migration test in step.

### 4.1 `breakdown_tags` — the new anchor between the script and the catalogues

`lib/models/database/tables/ocpt_breakdown_tags_table.dart`, `@DataClassName('OcptBreakdownTagRow')`.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, PK | UUID |
| `sceneId` | text → `scenes.id` | the scene the passage is in |
| `targetKind` | text, converter | `OcptBreakdownTargetKind`: `element`, `role`, `set` |
| `elementId` | text?, → `elements.id` | non-null iff `targetKind == element` |
| `roleId` | text?, → `roles.id` | non-null iff `targetKind == role` |
| `setId` | text?, → `sets.id` | non-null iff `targetKind == set` |
| `startOffset` | int | **scene-relative**, exactly as `shot_coverages` |
| `endOffset` | int | exclusive |
| `taggedText` | text | the passage verbatim, §3.7 |
| `needsCheck` | bool | the passage no longer matches and could not be re-anchored |
| `isDeleted` | bool | tombstone |

Three nullable foreign keys plus a discriminator, rather than one untyped `targetId`: the schema
declares `PRAGMA foreign_keys` and enforces it, so a real column per target keeps referential
integrity and lets a tombstoned target keep its tags pointing somewhere valid. `elements` already
does exactly this with `ownerPersonId` / `broughtByPersonId`.

Offsets are relative to the scene's `charStart` for the reason `shot_coverages` gives: a scene that
moves because a scene above it grew keeps every tag it had, with no rewriting at all.

No `sortKey`: a scene's tags are ordered by `startOffset`, which is the order they are read in.

### 4.2 `scene_breakdowns` — how far the breakdown has got, per scene

`lib/models/database/tables/ocpt_scene_breakdowns_table.dart`,
`@DataClassName('OcptSceneBreakdownRow')`.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, PK | UUID |
| `sceneId` | text → `scenes.id` | one live row per scene, enforced by the service |
| `status` | text, converter | `OcptBreakdownSceneStatus`: `toDo`, `inProgress`, `done` |
| `notes` | text | the scene's breakdown notes, free text |
| `isDeleted` | bool | tombstone |

A UUID primary key with `sceneId` beside it rather than `sceneId` as the key, because the sync model
stamps rows by primary key (`row_field_versions`) and every other synchronised table in the schema
follows that shape. A scene with no row reads as `toDo`; the service creates the row on the first
write, never eagerly for every scene.

### 4.3 `elements.status`

New column, `OcptElementStatusConverter`, default `toFind`, on the existing
`ocpt_elements_table.dart`. New type `lib/types/ocpt_element_status.dart`:

```dart
enum OcptElementStatus { toFind, reserved, beingMade, confirmed }
```

The resources mode's element sheet gains the same control, so the two modes never disagree about
what an element's status is.

### 4.4 Project versions — payload format 5

`OcptProjectVersionCodec` is a hand-written mirror of the schema and this step touches it in three
places, all of which must be done together or a restore will silently rewind half a project:

1. the two new tables are captured verbatim, added to the payload, to `contentDigest` and to
   `_applyPayload`;
2. a `_payloadUpgrades` entry for format 5 materialises them as **empty lists** when an older
   payload is decoded — the truthful reading of "this project had no breakdown";
3. that same entry fills `status` on every `elements` row of an older payload with `toFind`. Unlike
   the currency (format 4, which upgrades to null and means "leave it alone"), an element captured
   before the column existed genuinely had no recorded status, so the column's own default is the
   honest value.

The two new tables are ordinary synchronised tables: they are captured, hashed, restored and
stamped like the rest. Neither is local, so neither joins `project_versions` / `local_erasures` in
the exception list.

`_scrubErasedPeople` needs no change: a tag never names a person, only an element, a role or a set.

## 5. Services

### 5.1 `OcptBreakdownService`

`lib/managers/projects/services/ocpt_breakdown_service.dart`, owned by `OcptProjectsManager` beside
the resources services. It owns:

- reading a project's tags and scene breakdown rows, tombstones filtered out;
- creating a tag from a scene id, an offset range and a target — and, in the same transaction,
  **ensuring the link the tag implies**: a `scene_elements` row for an element target, a
  `scene_sets` row for a set target. A role target creates no link row: there is no `scene_roles`
  table, and the tag itself is that link;
- creating an element **and** its first tag in one transaction, from a name, a category and a
  range (§3.8) — the one write the popover's category chips perform. It goes through
  `OcptElementsService` for the element itself rather than reaching into `elements` on its own, so
  the two modes mint an element exactly the same way;
- refusing a range that overlaps a live tag of the same scene (§3.9). The mode also greys the
  affordance out, but the service is what guarantees it: a suggestion accepted in bulk must not be
  able to create an overlap either;
- deleting a tag (tombstone). It **never** removes the `scene_elements` / `scene_sets` row it once
  ensured: the resources mode lets a user link an element to a scene by hand with no tag at all, so
  removing the link silently would destroy work the breakdown never created. The inspector offers
  the removal as a separate question when the last tag of a target in a scene goes;
- setting a scene's breakdown status and notes;
- **reconciliation**, §5.2.

### 5.2 Tag reconciliation, on the screenplay save path

`OcptSceneIndexService` and `OcptRoleIndexService` already run on `OcptScreenplayService`'s save
path. `OcptBreakdownService.reconcileTags` joins them, after the scene index has been rebuilt (it
needs the new `charStart`/`charEnd`), and for each live tag:

1. slice the scene text at `[startOffset, endOffset)`. If it equals `taggedText`, nothing to do —
   and clear `needsCheck` if it was set;
2. otherwise search the scene's text for `taggedText`. **Exactly one** occurrence → re-anchor the
   tag to it, silently, and clear `needsCheck`. This is the common case: a word added earlier in the
   scene shifted everything after it;
3. zero, or more than one, occurrence → set `needsCheck` and leave the offsets alone. The mode shows
   these tags as needing attention, exactly as the shot list shows `shots.needsCheck`;
4. a tag whose scene disappeared is tombstoned along with the scene, as the foreign key requires.

Write nothing when nothing changed: this runs on every save.

### 5.3 Searching the catalogues and the recap

`lib/utils/ocpt_breakdown_search.dart`, pure and unit-tested. Two entry points over the same
diacritic- and case-folding as `ocpt_resources_search.dart`, which it reuses rather than
re-implements:

- the popover's search (§3.8) — given a query and the three catalogues, the matching roles, sets and
  elements, each kind capped so the popover keeps its height, ranked with prefix matches first and
  already-tagged targets before never-used ones;
- the recap's row filter (§3.10) — a predicate over an `OcptBreakdownTarget` covering its name,
  category label, sub-category, owner and notes.

The category *labels* are localized, so — exactly as the resources mode's lists already do — the
matching happens where the labels are known and the widget filters itself; the util takes the
resolved label strings, never a `Tr`.

### 5.4 Occurrence suggestions

`lib/utils/ocpt_breakdown_suggestions.dart`, pure and unit-tested, no Flutter import — the sibling of
`ocpt_scene_set_suggestion.dart`. Given a screenplay's scenes and the live tags, it returns, per
target, the passages that match a tag's `taggedText` and are not themselves tagged. Matching is
diacritic- and case-folded, reusing the folding of `ocpt_resources_search.dart`, and bounded to
whole words so `clé` does not match `clés de bras`. The mode *offers* these; it never applies them.

## 6. The mode

`lib/ui/pages/workspace/modes/breakdown/`, laid out exactly like the shot list and resources modes:
`breakdown_bloc.dart`, `breakdown_event.dart`, `breakdown_state.dart`, `breakdown_mode.dart` and a
`widgets/` directory.

`OcptBreakdownBloc` mixes in `MixinOcptProjectVersionsBloc` and `MixinOcptProjectVersionsState` and
answers the two hooks: `flushPendingProjectWrites` (the debounced free-text fields — the scene
notes and the inspector's notes) and `reloadFromProjectDatabase`, which **must** emit
`previewedVersionId` in the same state as the data it just read.

It joins its reads into one `OcptBreakdownSnapshot` (`lib/models/`), the way `OcptResourcesBloc`
builds `OcptResourcesSnapshot`: the scenes with their breakdown rows, the tags, and the three
target catalogues resolved into one `OcptBreakdownTarget` view model per tagged thing, so the recap
table and the inspector never branch on the target kind at the widget level.

### 6.1 Widgets

All presentational, all in `widgets/`, all reporting upward — no widget reads a manager.

| Widget | What it is |
| --- | --- |
| `ocpt_breakdown_header.dart` | the `Script` / `Recap` switch, the search field, hint, progress bar |
| `ocpt_breakdown_script_view.dart` | the paper sheet, its scene headings and its clickable words |
| `ocpt_breakdown_tag_popover.dart` | search field, results grouped by kind, category chips |
| `ocpt_breakdown_recap_table.dart` | the target × scene cross-table, grouped by category |
| `ocpt_breakdown_scene_panel.dart` | the left dock's scene list with status, bars and counts |
| `ocpt_breakdown_category_legend.dart` | the left dock's legend, each entry toggling its colour |
| `ocpt_breakdown_target_inspector.dart` | the selected target: status, category, details, occurrences |
| `ocpt_breakdown_scene_inspector.dart` | the scene sheet: counts, alert, elements by category |
| `ocpt_breakdown_right_dock.dart` | the two-tab dock |
| `ocpt_breakdown_status_bar.dart` | the shell's status bar for this mode |
| `ocpt_breakdown_sheets_export_dialog.dart` | the export options |

The script view is built on `OcptShotCoverageLayout` (§3.3). That class is now shared by two
features and its name no longer describes it, so **rename it** — and `OcptShotCoverageBlock` /
`OcptShotCoverageWord` with it — to `OcptScriptWordLayout` / `OcptScriptWordBlock` /
`OcptScriptWord`, in a commit of its own that changes nothing else. `OcptShotCoverageRange` keeps
its name: it really is shot-specific.

### 6.2 Colours

`lib/constants/ocpt_breakdown_palette.dart`: one ARGB colour per `OcptElementCategory`, plus one for
roles and one for sets. Sixteen entries, in the spirit of `ocptCoveragePalette` — deterministic, no
two adjacent categories confusable, and readable over the paper sheet in both themes. The mapping is
by category, not by rank: unlike a shot's coverage colour, a category's colour must be the same in
every project and every export.

### 6.3 Read-only preview

Every affordance that writes is **withheld, not disabled**, as a null callback — the word click that
opens a range, the popover in full, the status and category chips, the scene status control, every
notes field, the suggestion acceptance and the tag removal. What only reads stays: both views, the
scene panel, the legend filtering, **the header's search**, the inspector's occurrence jumps, the
statistics and the export. A click on a tagged word still selects its target, since selecting writes
nothing. The composite
panels (`ocpt_breakdown_target_inspector.dart`, `ocpt_breakdown_scene_inspector.dart`) take an
`isReadOnly` flag and hand their own parts null callbacks, so a control added later cannot be gated
in one place and forgotten in the other.

## 7. The breakdown sheets export

`OcptBreakdownSheetsPdfService`, `lib/managers/export/services/`, owned by `OcptExportManager`,
which becomes the owner of seven services. It takes the fonts loader the manager already hands to
the two other PDF services, so the four Courier Prime TTFs are still decoded once.

One sheet per scene: the scene number and heading, its status and page count, its breakdown notes,
then its targets grouped by category with their status and owner, and finally the list of what is
still to find. This is the document that goes to the department heads, so it prints per scene rather
than per element — the recap view is what answers the per-element question, and the workbook the
resources mode already exports is what carries it out of the app.

Every heading it prints comes in as an `OcptBreakdownSheetsLabels` (`lib/models/`), exactly as
`OcptScenarioCoverageLabels` does: the manager and its services never see a `Tr`.

The `⋮` entry opens `OcptBreakdownSheetsExportDialog` through `OcptRouterManager` — page format
pre-filled from the project, which scenes (all, or only those marked done), include notes, include
the to-find list — and the event flushes pending edits before handing the snapshot to the manager.
The save goes through `OcptSaveLocationService` like every other export: nothing is ever written to
a default location silently.

## 8. Documentation

- **ADR 0014**, `docs/adr/0014-breakdown-tags-as-the-script-to-catalogue-anchor.md`: why a tag is one
  row with a discriminator and three nullable foreign keys rather than a table per target kind; why
  it stores its text verbatim where `shot_coverages` stores a digest (§3.7); and why creating a tag
  ensures a link but removing one never removes it (§5.1). Follow `0000-template.md`.
- `AGENTS.md`: a new row in the development-plan table, the mode described in the Architecture
  section beside the resources mode, `breakdown_tags` / `scene_breakdowns` / `elements.status` folded
  into the persistence and project-versions paragraphs, and the export listed with the others. Never
  reference this plan or its milestones from the file.
- This plan is **deleted** once the step ships and `AGENTS.md` carries its outcome.

## 9. Milestones

One commit per logical change. A milestone ends on the full verification gate of `AGENTS.md` and a
user checkpoint before the next one starts.

| # | Content | Ends on |
| --- | --- | --- |
| M1 | Schema v9: the two tables, `elements.status`, the migration step and its test, `OcptBreakdownService`, the codec's format 5, unit tests for all of it. No UI. | A restore round-trip test proving a version taken before and after a breakdown restores correctly |
| M2 | The rename of §6.1, then the mode's shell: the enum entry and its placement, the bloc and its versions mixin, the left dock scene panel, the right dock with `Versions` only, the status bar. The centre shows an empty script sheet. | The mode is reachable, remembered across launches, and previews a version |
| M3 | The script view and tagging: clickable words, the range interaction, the non-overlap rule, the popover with its search and its category chips, creation and its hand-off to the inspector, category highlighting, the legend and its filtering, the target and scene inspectors. | §2.1 plays end to end, both paths |
| M4 | The recap view, the header's search field and its filtering, and the scene breakdown status and notes. | Both views agree on every count |
| M5 | Reconciliation on the save path, `needsCheck` surfacing, and the occurrence suggestions. | Editing a scene above and inside a tagged one leaves the tags right |
| M6 | The breakdown sheets PDF, its service, its labels, its dialog and its `⋮` entry. | A sheet prints for every scene of a real project |
| M7 | Read-only preview gating swept end to end, l10n complete in both ARB files, ADR 0014, `AGENTS.md`, this plan deleted. | `dart run tool/check_markdown.dart` and the full gate |

## 10. What is out of scope

- The schedule and the call sheet that will read this data. The breakdown produces the links; the
  day-by-day reading of them is the schedule mode's own step.
- Any automatic tagging (§3.4).
- Photographs of a tagged element. `assets` already holds an element's photo and the resources mode
  already writes it; this mode links to it and never adds its own.
