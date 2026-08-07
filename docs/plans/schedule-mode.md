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

Three rounds of work have shipped on the branch. None of them is a milestone of this plan any more.

| Shipped | What it left behind |
| --- | --- |
| **Planning** | Schema v11's six tables, `OcptScheduleService`, the chained-block timeline (ADR 0015), the offline sun times (ADR 0016), the mode with its three agenda presentations and its day view, and the shot list's shooting day turned into a read-out of the placement. |
| **Per-slot timetables and computed convocations** | Schema v12 (a block belongs to exactly one slot, a slot keeps one typed clock, a `hold` names its sequence, groups and lead times added), ADR 0015 amended per slot, ADR 0017, payload format 7. |
| **The day view** | A timetable on every slot card, blocks dragged or moved between slots, the hold sequence picker, the groups band, the lead and group controls, the placement rework (a shot may be placed as many times as the plan needs), the review pass, and a slot's own note and `▲`/`▼` reorder. |

What is left is three milestones, in the order below: **M1 rewrites where a convocation comes
from**, **M2 prints the paperwork**, **M3 shows what the plan is about to break**. M2 and M3 are
downstream of M1 — a call sheet prints exactly the figures M1 changes the origin of, and printing
them twice from two different rules is the one mistake worth avoiding here.

## 2. What the reference documents demand

Four real production documents were read before any of this was written; they are still what M2 is
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

Answered by Benoit; settled, not open questions. Two of the original answers have since been
replaced, and are listed as such rather than quietly dropped.

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
| ~~An actor has three times: arrival and a PAT band~~ | Replaced by §4: **four** figures, all computed, for crew and cast alike — arrival, PAT band, departure. |
| ~~A convocation is a band minus a typed lead time~~ | Replaced by §4: a convocation is the slot you are linked to. |

## 4. M1 — convocations read off the slots alone

**Goal: the app never asks for a clock it can read off the plan, and what a user types instead says
*why*.**

### 4.1 What is wrong today

A convocation is computed from a **lead time** — minutes before the moment someone is needed —
carried by the crew or cast row itself or by a `shooting_day_groups` row it points at.

A lead time says *how long*, never *what for*. Nothing in the file distinguishes forty-five minutes
of prosthetics from twenty minutes of rigging or from an hour of driving, and those are three
different facts a production has to plan, argue about and print. Worse, they are facts with a
**duration and a place** — a make-up truck, a set to light — which is precisely what a slot already
is. The model was expressing as an anonymous offset something it already had a first-class way to
say.

### 4.2 The rule, from here on

**Nothing is offset from anything.** A person is convoked by being linked to a slot, and every
figure about them is read off the slots they are linked to and the blocks in them. A production
that wants somebody there at 06:00 for make-up creates a 06:00 slot and links them to it — its
label ("HMC", "Installation") is what says why, its blocks are what say how long, and the day view
already draws slots as parallel lanes.

For a person **P** on a day **D**, over `S(P)` = the live slots of D that P is linked to (a
`shooting_slot_crew` row by person, a `shooting_slot_cast` row by role, both kinds counting):

| Figure | Definition |
| --- | --- |
| Arrival | the **earliest** `startMinute` over `S(P)` |
| PAT start | the start of the **earliest shooting block** over `S(P)`, or null when there is none |
| PAT end | the end of the **latest shooting block** over `S(P)`, or null when there is none |
| Departure | the **latest** slot end over `S(P)` — that slot's own last block end |

Consequences to hold on to while building this:

- **A slot with no shooting block gives no PAT.** A person convoked only on preparation slots has
  an arrival and a departure and no PAT band at all, which is the truthful reading: they are there,
  they are not waiting to shoot.
- The PAT band is **not** clipped to one slot. Someone on a morning slot and an evening slot has
  one band running from the first shot of the morning to the last shot of the evening, gaps
  included; the day view's lanes are where the gaps are read.
- Nothing depends on a block **naming** the person any more. `shot_characters`, the roles the
  breakdown tagged in a hold's sequence, `OcptScheduleState.roleIdsBySceneId` — none of it takes
  part in a convocation. Whoever is linked to the slot is convoked by the slot.
- A **shooting block** means `shot` **and** `hold`: a hold reserves the time of a sequence not yet
  shot-listed, and a production that has scheduled a whole week ahead of its découpage must still
  see a PAT band. Every other kind (`preparation`, `hairMakeUp`, `meal`, `pause`, `travel`, `wrap`)
  is not shooting time and never opens or closes a band.
- A slot carrying no block at all ends at its own `startMinute`: it is a convocation with no
  content yet, not a zero-length error.

### 4.3 What goes away

- `shooting_slot_crew.leadMinutes`, `shooting_slot_cast.leadMinutes`, and the `groupId` on both.
- The `shooting_day_groups` table, and with it the day view's `People groups` band, its `ⓘ`, its
  creation/rename/retime/delete flow and the group pickers on every crew and cast card.
- `OcptScheduleService`'s group operations, its seeding of a lead time and a group from the most
  recent day that convoked the person, and the copying of groups by `createDay`/`duplicateDay`.
- The arrival and PAT read-outs **on the crew and cast cards** of a slot card: a card there goes
  back to saying who is convoked and in what function, nothing about clocks. The times move to the
  new panel of §4.5.
- `OcptScheduleLeadField` and `OcptScheduleGroupsBand`, and their tests.

Nothing is guessed on the way out: a lead time and a group are dropped, not converted into a
preparation slot the user never asked for — the same rule the v11→v12 migration followed when it
dropped typed clocks.

### 4.4 Data model

**Schema v13** (allocated at merge time, ADR 0007 — renumber if another branch lands first):

- `m.deleteTable('shooting_day_groups')`.
- One `TableMigration` per convocation table, recreating `shooting_slot_crew` and
  `shooting_slot_cast` without `group_id` and `lead_minutes` — the `_alterScheduleTablesToV12`
  idiom, `// ignore: experimental_member_use` included.
- The migration test pins what `onCreate` produces against every upgrade path, as always.

**Payload format 8**: the `_payloadUpgrades` entry from 7 drops the `shooting_day_groups` list and
the two keys on every crew and cast row. This is the first entry that removes rather than
materialises, and it means what it says — a version captured while groups existed comes back with
none, because the concept no longer exists in the project it is being restored into.
`contentDigest` and `_applyPayload` follow the same removal.

`OcptShootingDayGroup` (model), `OcptScheduleSnapshot`'s groups, and the group and lead fields of
`OcptShootingSlotCrewMember`/`OcptShootingSlotCastMember` go with them.

### 4.5 The convocations panel

A **third right-dock tab**, `OcptScheduleRightDockTab.convocations`, between `inspector` and
`versions`: the day's whole call, one row per person, which is the reading nobody could get from
the slot cards once a person may sit on three of them.

- Scope: the **selected day**. No day selected, no rows — the panel says so, as the inspector does.
- One row per **person**, crew and cast folded together (an actor read through `roles.personId`),
  since the question is "when does this human arrive". A **role with nobody cast** is its own row,
  named by the role: it is a convocation the production still has to honour.
- Columns: arrival, PAT band (or an em dash when there is none), departure, and the slots the
  person is on, by label.
- Sorted by arrival, then by name, so the panel reads as the order people walk in.
- Read-only: everything on it is computed, and the way to change any of it is to move a block or a
  slot. It is therefore identical under a version preview, and needs no `isReadOnly` handling
  beyond not offering anything in the first place.

### 4.6 Pure code and the ADR

`lib/utils/ocpt_shooting_convocations.dart` is rewritten: `ocptComputeSlotConvocations` (per slot,
per lead time) gives way to `ocptComputeDayConvocations`, which takes a day's slots — each with its
own already-computed `OcptShootingSlotTimeline` (`ocpt_shooting_day_timeline.dart` is untouched)
and its own linked person and role ids — and answers one `OcptDayConvocation` per person and per
uncast role. It stays **pure**: no drift row, no Flutter, resolving who a role's actor is remains
the caller's job.

`docs/adr/0017-convocations-computed-from-the-slot-chain.md` is **superseded** by a new
`docs/adr/0018-…`, rather than amended a second time: the decision it records (a convocation is a
band minus a lead time) is not being refined, it is being replaced by "a convocation is the slot
you are linked to". 0017 gets the standard superseded header pointing at 0018.

### 4.7 Steps

Each one ends on the full verification gates and one commit per logical change.

1. **The model.** Schema v13, payload format 8, the models and the snapshot, the service cleanup
   (group operations, seeding, `createDay`/`duplicateDay`). Tests: migration, codec, versions
   service, schedule service.
2. **The rule.** `ocptComputeDayConvocations` and its tests; ADR 0018 and 0017's superseded header.
3. **The day view.** The groups band and lead field deleted, the crew and cast cards slimmed to who
   and what function, the bloc/state/events cleaned of groups and leads, `dayArrivalMinute` reduced
   to the earliest slot start, the day inspector and the strip agenda following.
4. **The panel.** The new tab, `OcptScheduleConvocationsPanel`, its l10n and its tests.
5. **The documentation.** `AGENTS.md`'s schedule section and its status table.

Steps 1 and 2 are independent of one another and may run in parallel; step 3 needs both; step 4
needs step 2.

**Checkpoint with Benoit** before M2.

## 5. M2 — the three PDF exports

**Goal: the paperwork a shoot actually runs on.**

Two new services under `lib/managers/export/services/`, both owned by `OcptExportManager`, both
sharing the existing `OcptCourierPrimeFontsLoader`, both taking a labels object so no manager or
service ever sees a `Tr` — the pattern `OcptScenarioCoverageLabels` established. Every convocation
figure they print comes from `ocptComputeDayConvocations` (§4.6) and is never re-derived.

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

**Checkpoint with Benoit** before M3.

## 6. M3 — grids and alerts

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
  - a minor's day exceeding what `people.minorNotes` records — soft.
- The alerts panel in the mode, and the alert count in the status bar. The mode header's own
  `Couleur par` control belongs to this milestone too.

## 7. What this mode does not do

- No spreadsheet export (decided; may follow later).
- No weather feed, no map tiles, no geocoding: the app stays offline-only.
- No automatic scheduling or optimisation. The app tells the user what conflicts; it never decides
  the order of a shoot for them.
- **No actual times.** The schedule says what is planned; when a day slips, blocks are moved and
  the estimate recomputes. Logging when each take really started is the script supervisor's report
  — already on the roadmap — and doing half of it here would produce a document nobody can rely on.
- No budget or day-rate arithmetic — that is the budget mode's.
- No per-slot working-time law enforcement beyond the minor's soft alert.

## 8. Definition of done, per milestone

The eight verification gates of `CLAUDE.md` pass at every commit, plus the ninth for any `.md`
touched. In addition:

- **M1**: a project created under schema v12 opens under v13 with every convocation still linked to
  its slot and no group anywhere; the migration parity test is green; a version captured before M1
  restores with no group and no lead time rather than half of either; a person convoked on a
  preparation slot and a shooting slot reads one arrival, one PAT band spanning both, and one
  departure; a person convoked only on a preparation slot reads no PAT at all; moving a block
  changes every figure that depended on it, in the panel and nowhere else; no slot card shows a
  clock other than the slot's own start.
- **M2**: the three PDFs are generated from the reference project and read against the documents
  in `debug/plan/`; a day with two slots and two crews prints both; a night slot crossing midnight
  prints the right hours; a person's arrival, PAT band and departure print as distinct figures; the
  named sheets land in the chosen folder, one file per person, none of them carrying the full
  directory.
- **M3**: every alert has a test with a case that fires it and a case that does not; the presence
  grid's overrides survive a save, a reload and a version round trip.
