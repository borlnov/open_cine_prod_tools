<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Schedule mode — what is left to build

This document is the **single** implementation plan for the schedule production mode. It merges the
three that preceded it — the original mode plan, the per-slot timetables and computed convocations
rework, and the convocations-from-slots rework — keeping only what is still to do, plus the
reference material that work is measured against. It is written for the Sonnet 5 agents that will
build it, orchestrated and reviewed by the main session, with a user checkpoint between milestones.
**Read the repository `CLAUDE.md` first** — this plan assumes its architecture, ways of working,
coding standards, licensing rules and verification gates, and does not repeat them.

Everything already shipped is described in §1 by pointer only: the code, the ADRs and `AGENTS.md`
are the record from the moment a step lands, and this file never re-describes them.

---

## 1. Where the mode stands

Five rounds of work have shipped on the branch. None of them is a milestone of this plan any
more.

| Shipped | What it left behind |
| --- | --- |
| **Planning** | Schema v11's six tables, `OcptScheduleService`, the chained-block timeline (ADR 0015), the offline sun times (ADR 0016), the mode with its three agenda presentations and its day view, and the shot list's shooting day turned into a read-out of the placement. |
| **Per-slot timetables and computed convocations** | Schema v12 (a block belongs to exactly one slot, a slot keeps one typed clock, a `hold` names its sequence, groups and lead times added), ADR 0015 amended per slot, ADR 0017, payload format 7. |
| **The day view** | A timetable on every slot card, blocks dragged or moved between slots, the hold sequence picker, the groups band, the lead and group controls, the placement rework (a shot may be placed as many times as the plan needs), the review pass, and a slot's own note and `▲`/`▼` reorder. |
| **Convocations read off the slots alone** | ADR 0018 superseding ADR 0017, `ocptComputeDayConvocations`, schema v13 and payload format 8 dropping `shooting_day_groups` and both lead-time columns, the groups band and the card clocks gone, and the `Convocations` dock tab. |
| **A slot anchored by either edge** | ADR 0015 amended a second time, schema v14 and payload format 9 replacing `shooting_slots.startMinute` with the anchor trio, the resolution in `ocptComputeShootingDayTimelines` with its two new records and `ocptSlotAnchorWouldCycle`, `setSlotAnchor` with `duplicateDay`'s remap and `deleteSlot`'s freeze, the slot card's anchor menu, and every reader of a slot's hour moved onto the resolved one. |

What is left is four milestones, in the order below: **M2 pre-fills a convoked person's position
from the address book**, **M2b repairs and finishes two resources sheets**, **M3 prints the
paperwork**, **M4 shows what the plan is about to break**. M2b is the odd one out and says so in
its own section: it is resources work, held by this branch rather than owed to this mode, and
nothing after it depends on it.

M1 came first on purpose, and has shipped: it changed what "the hour of a slot" *is*, and every
reader of that figure — the three agendas, the convocations, the day inspector — followed. Printing
call sheets against a figure that was about to change its definition would have meant writing those
services twice.

## 2. What the reference documents demand

Four real production documents were read before any of this was written; they are still what M3 is
measured against, and they live in `debug/plan/`.

- `20230719-planning tournage.docx` — the shooting plan of *lonelyJourney*. Three summary grids
  (locations, sequences, crew and cast) crossing **days × day-parts**, then one detailed timetable
  per day: the location and its address, the call times per group, the named sub-locations, then
  an hour-by-hour run of shot tables (`Plan / Description / Valeur de plan / Move. / Commentaire /
  Perso.`) interleaved with breaks and moves.
- `20230808-FeuilleDeService-10_août.docx` and `20230811-FeuilleDeService-13_août.docx` — two call
  sheets. Recipients, film title, production/direction contacts, the day's time bands and day
  number, a note to the crew, the location and its map link, sunrise/sunset and twilight, contacts
  by department, the `SEQ / PLANS / EFFET / DÉCORS / RÉSUMÉ / RÔLES` table interleaved with timed
  milestones (preparation, travel, meal, wrap), a cast table (`role, actor, arrival, PAT`), and
  finally the crew list and the cast-and-extras list with phone numbers and e-mails. The second one
  proves a day can hold **two distinct crews with distinct convocations**.
- `Plan de travail et planning.xlsx` — a professional strip board: one column per shooting day
  carrying the week, day number, dates, working hours, day/night, locations, sequences, int/ext,
  effect, the numbered cast with a presence code per day, animals, vehicles, special equipment,
  sunrise/sunset and astronomical twilight — over a **ten-minute-granularity day grid** where each
  person's lane says what they are doing.

The Claude Design mock (`OpenCineProdTools design shell`, planning mode) turns all of that into
four views — agenda, day, positions matrix, presence grid — plus a conflict alert list and a
three-entry export menu. **The mock is authoritative on layout only**; its data model is flat and
invented for the prototype, and the schema wins.

## 3. Decisions that still stand

Answered by Benoit; settled, not open questions. Answers that have since been replaced are listed
as such rather than quietly dropped.

| Question | Decision |
| --- | --- |
| Sun and twilight times | **Computed** from the location's coordinates, offline. |
| Named call sheet | The person's own convocation and the part of the timetable that concerns them. |
| General call sheet | The structure of the reference `.docx`, faithfully. |
| Spreadsheet export | Not now. |
| Presence grid | Computed, overridable by hand. |
| Named call sheets | One folder, **one PDF per person**. |
| Extras | Ordinary `extra` roles; a nameless crowd is said in the crew note. |
| Actual times | **Not recorded** — this mode says what is planned. |
| Cast rows | **Unchanged this round.** The cast picker keeps its casting order and its current behaviour; M2 is about crew positions only. |
| The person sheet's `Portée` column | **Dropped.** When a position is held is the schedule's answer, and writing it on the sheet too would be a second copy of one truth. |
| ~~An actor has three times: arrival and a PAT band~~ | Replaced by ADR 0018: arrival, PAT band and departure, all computed, for crew and cast alike. |
| ~~A convocation is a band minus a typed lead time~~ | Replaced by ADR 0018: a convocation is the slot you are linked to. |
| ~~A slot owns one typed clock and no other, its `startMinute`~~ | Replaced by ADR 0015's second amendment: a slot owns **one anchored edge**, which may be its end, and whose hour may be read off another slot. |

## 4. M2 — a convoked person's position, pre-filled

**Goal: `person_positions` finally feeds the schedule instead of looking like a duplicate of it.**

The two tables answer different questions — the address book says *that* someone is a chief
operator on this film, the slot says *when* and *at which post* on a given day, and one person may
hold two posts in one slot. What made them look redundant is that nothing ever joined them: the
slot's position picker offers the whole `ocptCrewPositions` catalogue without once looking at what
the person declared.

- A pure helper under `lib/utils/`, tested: given a person's declared positions (in their display
  order) and the crew rows that person already has **on that slot**, it answers the position to
  pre-fill and the promoted order for the picker.
- **Adding a crew member pre-fills their first declared position not already taken by them on that
  slot.** Adding the same person again therefore lands on their second, then their third. Nothing
  declared, or everything already taken, pre-fills nothing — exactly today's behaviour.
- A declared position that is a **free label** pre-fills the row's `customLabel`, not only
  catalogue entries: a position's identity, for all of this, is the pair
  (`positionId`, `customLabel`), which is how both tables already model one.
- **The picker never offers a position that person already holds on that slot** — the duplicate is
  refused where it is chosen, rather than the add being blocked. Adding someone twice with nothing
  declared stays possible: two rows the user then fills.
- **Declared positions sit at the top of the picker**, above the catalogue's departments, behind a
  divider. A declared one that is already taken is simply absent rather than greyed — unlike the
  slot menu above, it is visible on the card right beside the picker.
- The pre-fill belongs to `OcptScheduleService.addSlotCrewMember`, not to a bloc: every caller
  should get it, and it needs both the person's positions and the slot's existing rows, which the
  service already has.

Then the column this was blocked on: **the person sheet's `Portée` column is deleted** —
`ocpt_person_sheet_positions_card.dart`, its width constant, and the
`resourcesPositionScopePlaceholder` key in both ARB files. `OcptPersonPositionsTable`'s own doc
comment, which promises the schedule mode will fill it, is rewritten to say what is now true: a
row says *that* a person holds a function, and *when* is the schedule's to answer, on its own
surfaces.

No schema change, no payload change.

## 5. M2b — the resources sheets: a photo, and the things a role wears

**This milestone is not schedule work.** It lands here because it is what the branch is holding,
and because both halves of it were found while using the mode the rest of this plan builds. It
touches the resources mode alone; nothing in M3 or M4 depends on it, and it may be reordered or
split off without disturbing them.

It has three commits, in this order, the first of which is independent of the other two.

### 5.1 A colour swatch is not a menu item

A live crash, on two surfaces. Clicking a person's photo slot (`OcptPersonSheetAvatar`) or a
location's colour bar (`_OcptLocationColorBar`) throws
`RenderFlex children have non-zero flex but incoming width constraints are unbounded` and the
popover never draws.

The cause is one line of Flutter's own layout, and it is worth stating so the third site is never
written: **a `MenuItemButton` never goes inside a `Wrap`.** `_MenuItemLabel` puts the item's child
in an `Expanded`, inside a `Row` sized to the maximum; a `Wrap` hands its children an unbounded
main-axis width, and a flexible child under an unbounded constraint is exactly what that assertion
refuses. It is fine down a menu's single column, which is the only place a menu item is meant to be.

Both popovers hold the same sixteen-swatch grid, duplicated line for line, so the fix is one
extraction rather than two edits: `OcptResourcesColorSwatches`
(`lib/ui/pages/workspace/modes/resources/widgets/`) owns the grid, its sizes and the ring on the
current swatch, and each swatch is a plain `InkWell` closing the popover itself through
`MenuController.maybeOf`, which is the only thing the menu item was ever doing for it.

No schema change, no ARB key, no behaviour change beyond the popover opening at all.

### 5.2 The three orphaned asset columns

`people.photoAssetId`, `elements.photoAssetId` and `people.imageRightsAssetId` have existed since
schema v6 and **none of them has ever had a way to be filled**: the doc comments say a later
milestone would do it, and this is that milestone. There is nothing to design — referencing a file
is already written, three times over, for a location's scouting photos and its permit document.

- **`OcptAssetsService`**, the twelfth service `OcptProjectsManager` owns. `_insertAsset` moves out
  of `OcptLocationsService`, where it hard-codes `locationId`, and becomes generic over the owner
  column; `removeAsset`, already generic, moves with it — the resources bloc today drops *any*
  asset through `_locationsService.removeAsset`, which is the bend this straightens.
  `OcptLocationsService` keeps its public API and delegates.
- **Six writes**, all shaped like `setPermitDocument`: `setPersonPhoto`/`clearPersonPhoto`,
  `setElementPhoto`/`clearElementPhoto`, `setImageRightsDocument`/`clearImageRightsDocument`. Each
  tombstones the row it replaces in the same transaction — a column pointing at one file has no
  history worth keeping, only orphans.
- **The photo slot becomes a menu**: `Reference a photo…`, `Remove the photo` (absent while there
  is none), a divider, then the swatch grid of §5.1. One anchor, both things a slot is about, and
  the header's layout untouched. The element sheet's header gains the same slot and the same menu;
  the image rights card gains the `OcptAssetFileLine` the permit card already uses, and the doc
  comment promising it holds no picker is rewritten.
- **The photo propagates**: `OcptPersonSheetAvatar`, the left dock's own person avatar and
  `OcptRoleAvatar` show the thumbnail when the file resolves and the initials on the colour when it
  does not. That rule is written once, in a shared avatar widget, so the three cannot drift.
  **A missing file stays a state, not an error** (ADR 0013), exactly as a scouting tile reads it.
- **No schema change and no payload change**: the three columns and the `assets` table are already
  captured by the codec.

### 5.3 A role and its things

A role can be linked to the elements it needs — its props, its costumes, its make-up and
prosthetics. Nothing today says this: `breakdown_tags` links a *passage* to a role or to an
element, never a role to an element, and "whose costume is this?" has no answer anywhere in the
app.

- **Schema v15**: `role_elements` (`id`, `roleId`, `elementId`, `notes`, `isDeleted`), modelled on
  `scene_elements` down to its doc comment. **No `sortKey`**: a role's things are a set the user
  adds to and removes from, not a list they reorder. The number is allocated **at merge time**
  (ADR 0007) and the `onUpgrade` 14→15 path is pinned by the existing migration test.
- **Payload format 10**: the list joins the codec's three places — the capture, `contentDigest` and
  `_applyPayload` — and the upgrade entry from format 9 materialises it **empty**. That is the
  plain-empty-list kind (format 6's), not the currency's null: a version captured before the table
  existed genuinely held no link, so restoring one tombstones every link made since, which is the
  truthful reading.
- **The links go on `OcptElementsService`**, beside `addSceneElement`: the row is an element link,
  and the role side of it is a read. `deleteElement` tombstones them as it already tombstones its
  `scene_elements`; deleting a role does the same. **`local_erasures` is untouched** — the table
  names a role, never a person.
- **The role sheet's own card**, after the casting card and before the notes: one row per link —
  the element with its code, a free note on the local debounce `OcptElementSheetScenesCard` already
  uses, and the control that unlinks — **grouped by category**, under a picker offering the whole
  catalogue grouped the way the elements list is. The table knows nothing of categories on purpose:
  a character's car, dog or stunt harness is a fact about them exactly as their coat is, and a
  restriction written into the schema would be paid for with a migration the day it gets in the way.
- **The element sheet reads it back**: a `Roles concerned` row of read-only chips, each selecting
  that role in the roles tab. It is a plain tab-and-selection change inside one mode, not an
  `OcptWorkspaceRevealRequest` — the user is already in Resources.
- **Read-only**: null callbacks throughout, as every other sheet does it.
- The card's title and the reverse row are new ARB keys in both files — « Ses affaires » and
  « Rôles concernés » in French. Nothing here names a scene, so the *séquence* rule does not come
  into it.

## 6. M3 — the three PDF exports

**Goal: the paperwork a shoot actually runs on.**

Two new services under `lib/managers/export/services/`, both owned by `OcptExportManager`, both
sharing the existing `OcptCourierPrimeFontsLoader`, both taking a labels object so no manager or
service ever sees a `Tr` — the pattern `OcptScenarioCoverageLabels` established. Every convocation
figure they print comes from `ocptComputeDayConvocations` (ADR 0018) and is never re-derived, and
every hour comes from the resolved timelines (M1) rather than from a column.

1. **`OcptCallSheetPdfService`** — one day, two audiences from one composition:
   - *General call sheet*, following the reference `.docx` section by section: recipients, film
     title and director, production and direction contacts, the day's time bands and day number,
     the crew note, the location(s) with address and map link, the sun block, contacts by
     department, the `SEQ / PLANS / EFFET / DÉCORS / RÉSUMÉ / RÔLES` table interleaved with the
     timed milestones (preparation, travel, meal, pause, wrap), the cast table, then the crew list
     and the cast-and-extras list with telephone and e-mail. `EFFET` and `DÉCORS` are read from the
     scene heading and the linked set — the breakdown mode already owns both links.
   - *Named call sheets*, **one PDF per convoked person, written into a folder the user picks**
     (`FDS-J2-Elisa-Mabit.pdf`, …): the same day header, **their** arrival, PAT band and departure,
     their positions or roles that day, only the slots and blocks they are expected on, the crew
     note, and the key contacts. Not the directory — a call sheet sent to one person should not
     carry everyone else's telephone number. This is the one export that does not write a single
     file, so `OcptSaveLocationService` gains a directory-picking entry point beside its save
     dialog.
2. **`OcptShootingPlanPdfService`** — the whole shoot, following the `planning tournage.docx`: the
   three summary grids (days × day-parts, by location, by sequence, by person) and then one
   detailed day agenda per day, hour by hour, with its shot tables.

Each is reached from the mode's `⋮` menu through an options dialog opened by `OcptRouterManager`
(which days, which people, title page, page format pre-filled from the project), and each writes
through `OcptSaveLocationService` — no export ever picks a path silently.

## 7. M4 — grids and alerts

**Goal: seeing what the plan is about to break before it breaks.**

- **Positions matrix**: positions × slots, who holds what, with the mock's orange cell for a
  position that disappears mid-day (held in the morning slot, unfilled in the afternoon one).
- **Presence grid**: people × days, cells computed from the assignments and from
  `person_unavailabilities`, a click cycling an override written to `shooting_presences` — the
  table declared since schema v11 and still unwritten — and a per-person day count.
- **`lib/utils/ocpt_schedule_alerts.dart`**, pure and tested, producing the alert list the mock
  shows, each pointing at the day it concerns:
  - a person assigned on a day they are unavailable (`person_unavailabilities`, honouring the
    day-part slot) — hard;
  - **a person linked to two slots of one day whose timetables overlap in wall-clock time** —
    hard. Two *slots* overlapping is legal and ordinary, that being what splitting a day into
    slots is for; one *person* being in both at once is not, and it is only answerable now that
    each slot chains on its own;
  - a slot whose location has no `location_availabilities` window covering it — hard;
  - a key position unfilled in a slot — hard;
  - a position lost between two slots of one day — soft;
  - a role appearing in a placed shot but convoked in no slot that day — soft;
  - a role with no actor — soft;
  - a timeline over-run against a pinned anchor (ADR 0015) — soft;
  - **a slot whose fixed end its own blocks over-run** (M1's rule 4) — soft;
  - a minor's day exceeding what `people.minorNotes` records — soft.
- The alerts panel in the mode, and the alert count in the status bar. The mode header's own
  `Couleur par` control belongs to this milestone too.

## 8. What this mode does not do

- No spreadsheet export (decided; may follow later).
- No weather feed, no map tiles, no geocoding: the app stays offline-only.
- No automatic scheduling or optimisation. The app tells the user what conflicts; it never decides
  the order of a shoot for them.
- **No actual times.** The schedule says what is planned; when a day slips, blocks are moved and
  the estimate recomputes. Logging when each take really started is the script supervisor's report
  — already on the roadmap — and doing half of it here would produce a document nobody can rely on.
- No budget or day-rate arithmetic — that is the budget mode's.
- No per-slot working-time law enforcement beyond the minor's soft alert.
- **No slot link across two days**, and none between two same-side edges. Both are stated in ADR
  0015's second amendment.

## 9. Definition of done, per milestone

The eight verification gates of `CLAUDE.md` pass at every commit, plus the ninth for any `.md`
touched. In addition:

- **M2**: a person with two declared positions convoked twice on one slot lands on both, in order;
  a third convocation pre-fills nothing. A person with a free-label position pre-fills that label.
  The picker never offers a position that person already holds on that slot. The `Portée` column is
  gone from the sheet and its ARB key from both files.
- **M2b**: the colour popover opens without throwing, on a person **and** on a location, and a
  swatch picked is reported and closes it. A referenced photo shows on the person sheet, in the
  left dock's list and on the role avatar; a file moved since reads as missing without raising
  anything; removing a reference leaves the person alone. An element's photo and a signed image
  rights release reference the same way. A role linked to three elements of three categories reads
  them grouped, and each of the three names the role back. Deleting an element or a role carries
  its links away with it. A version round trip keeps the links, and restoring one captured before
  the table erases them.
- **M3**: the three PDFs are generated from the reference project and read against the documents
  in `debug/plan/`; a day with two slots and two crews prints both; a night slot crossing midnight
  prints the right hours; an `end`-anchored slot prints the hours the day view shows; a person's
  arrival, PAT band and departure print as distinct figures; the named sheets land in the chosen
  folder, one file per person, none of them carrying the full directory.
- **M4**: every alert has a test with a case that fires it and a case that does not; the presence
  grid's overrides survive a save, a reload and a version round trip.
