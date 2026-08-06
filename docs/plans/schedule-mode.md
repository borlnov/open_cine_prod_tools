<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Schedule mode — the shooting plan and its call sheets

This document is the implementation strategy for the schedule production mode: planning the shoot
day by day, and printing what each person needs to show up at the right place at the right time.
It is written for the Sonnet 5 agents that will build it, orchestrated and reviewed by the main
session, with a user checkpoint between each milestone. **Read the repository `CLAUDE.md`
first** — this plan assumes its architecture, ways of working, coding standards, licensing rules
and verification gates, and does not repeat them.

---

## 1. Why this step exists

Four production modes exist: the screenplay is written, broken down, shot-listed, and the people,
locations and elements it needs are catalogued. Nothing yet says **when**. The schedule mode is
where a shoot stops being a list of things to do and becomes a set of dated days, each with its
own convocations, its own timetable and its own paperwork.

Two properties shape every decision below.

**The plan changes constantly, including during the shoot.** An actor drops out, it rains, a
location is lost the evening before, a scene overruns by two hours. Reworking a day must take
seconds, not a rebuild: that is why a day's timetable is a chain of durations rather than a set of
typed clock times, and why a shot's placement lives in one row that can be dragged elsewhere.

**The output is paper, handed to people who do not have the app.** A call sheet is read on a
phone in a car park at 6 a.m. Three PDFs are the deliverable, and the reference documents in
`debug/plan/` are what they must look like.

## 2. What the reference documents demand

Four real production documents were read before writing this plan.

- `20230719-planning tournage.docx` — the shooting plan of *lonelyJourney*. Three summary grids
  (locations, sequences, crew and cast) crossing **days × day-parts**, then one detailed timetable
  per day: the location and its address, the call times per group, the named sub-locations, then
  an hour-by-hour run of shot tables (`Plan / Description / Valeur de plan / Move. / Commentaire /
  Perso.`) interleaved with breaks and moves.
- `20230808-FeuilleDeService-10_août.docx` and `20230811-FeuilleDeService-13_août.docx` — two call
  sheets. Recipients, film title, production/direction contacts, the day's time bands and day
  number, a note to the crew, the location and its map link, sunrise/sunset and twilight, contacts
  by department, the `SEQ / PLANS / EFFET / DÉCORS / RÉSUMÉ / RÔLES` table interleaved with timed
  milestones (preparation, travel, meal, wrap), a cast table (`role, actor, sequences, arrival,
  PAT`), and finally the crew list and the cast-and-extras list with phone numbers and e-mails.
  The second one proves a day can hold **two distinct crews with distinct convocations**.
- `Plan de travail et planning.xlsx` — a professional strip board: one column per shooting day
  carrying the week, day number, dates, working hours, day/night, locations, sequences, int/ext,
  effect, the numbered cast with a presence code per day, animals, vehicles, special equipment,
  sunrise/sunset and astronomical twilight — over a **ten-minute-granularity day grid** where each
  person's lane says what they are doing.

The Claude Design mock (`OpenCineProdTools design shell`, planning mode) turns all of that into
four views — agenda (strip / week / month), day, positions matrix, presence grid — plus a conflict
alert list and a three-entry export menu. **The mock is authoritative on layout only**; its data
model is flat and invented for the prototype, and the schema below wins.

## 3. The decisions taken

Answered by Benoit before this plan was written; they are settled, not open questions.

| Question | Decision |
| --- | --- |
| What is placed on a day | **Shots only.** A sequence not yet shot-listed is a reserved *hold* block. |
| How block times are computed | **Chained durations from the call time, with pinned anchors.** |
| Milestones | **M1 planning, M2 exports, M3 grids and alerts.** |
| Sun and twilight times | **Computed** from the location's coordinates, offline. |
| Named call sheet | Convocation and the part of the timetable that concerns that person. |
| General call sheet | The structure of the reference `.docx`, faithfully. |
| Spreadsheet export | Not now. |
| A shooting day's date | **Always dated.** |
| `shots.shootingDay` | Becomes a read-out of the schedule; the legacy free text is **erased** at migration. |
| Agenda views in M1 | All three (strip, week, month). |
| Presence grid | Computed, overridable by hand. |
| An actor's times | **Three**: arrival, then the PAT band (ready-to-shoot start and end). |
| Named call sheets | One folder, **one PDF per person**. |
| Extras | Ordinary `extra` roles; a nameless crowd is said in the crew note. |
| Duplicating a day | **In M1** — a new day started from an existing one. |
| Marking a shot as shot | **In M1**, from the day view, writing the existing `shots.status`. |
| Actual times | **Not recorded** — this mode says what is planned. |

## 4. The data model — schema v11

Six new tables, every one synchronised (ADR 0010): `isDeleted` tombstones, `sortKey` fractional
indexes where the rows are ordered, no hard delete anywhere. The schema number is allocated **at
merge time** (ADR 0007) — if another branch takes v11 first, this one renumbers.

All six are declared in **one** migration, in M1, even though `shooting_presences` is only filled
in M3: a second migration for one table would be a schema bump a user has to live through for
nothing.

### `shooting_days`

One row per day of shooting.

| Column | Notes |
| --- | --- |
| `id` | UUID |
| `screenplayId` | the project's screenplay, as `shots` and `roles` do |
| `date` | `DateTime`, **never null** — the week and month views, the sun times and every availability crossing depend on it |
| `sortKey` | ordering; the *day number* printed as `J3` is a read-time rank, never a column, exactly as `OcptShot.position` is |
| `status` | `OcptShootingDayStatus { planned, shot, cancelled }` — a rained-off day is said, not deleted |
| `crewNote` | the call sheet's "NOTE À L'ÉQUIPE", free multi-line text |
| `weatherNote` | typed by hand; the app never reaches the network |
| `notes` | internal notes, not printed |
| `isDeleted` | tombstone |

Sunrise, sunset and the three twilights are **not columns**: they are computed (§7).

### `shooting_slots`

A convocation window inside a day — the *créneau*. A day has at least one; the second reference
call sheet has two, with different crews, different locations and different call times.

| Column | Notes |
| --- | --- |
| `id`, `shootingDayId`, `sortKey`, `isDeleted` | |
| `label` | "Matin", "Nuit" — free text, the call sheet prints it |
| `locationId` | nullable reference to `locations` |
| `setId` | nullable reference to `sets` — the décor, whose location must be `locationId` |
| `crewCallMinute` / `crewWrapMinute` | minutes from midnight |
| `castCallMinute` / `castWrapMinute` | the slot's default *PAT* band, nullable |
| `notes` | |

**Minutes from midnight may exceed 1440.** A night slot running 19:00 → 03:00 stores 1140 → 1620.
Every formatter and every comparison works modulo nothing: the value is an offset from the day's
own midnight, and a single `ocptFormatDayMinute` renders it. This is written down because getting
it wrong only shows up on the one night shoot of a production.

The reference call sheets' "HORAIRES ÉQUIPE IMAGE 16:45 / HORAIRES ÉQUIPE TECHNIQUE 18:30" is
**not** a second pair of columns: it is two people called earlier than the slot, which the
per-person override below expresses without the schema deciding in advance which departments a
production splits.

### `shooting_slot_crew`

Who holds which position during a slot.

| Column | Notes |
| --- | --- |
| `id`, `slotId`, `sortKey`, `isDeleted` | |
| `personId` | reference to `people` |
| `positionId` | an `ocptCrewPositions` id, stored verbatim |
| `customLabel` | when the position is not in the catalogue, as `person_positions` already allows |
| `callMinute` / `wrapMinute` | **nullable overrides** of the slot's crew band |
| `notes` | |

A person holding two positions in one slot (director *and* production manager, which the reference
sheets show) is two rows. The call sheet joins them back into one line.

### `shooting_slot_cast`

Which role is convoked during a slot.

| Column | Notes |
| --- | --- |
| `id`, `slotId`, `roleId`, `sortKey`, `isDeleted` | |
| `arrivalMinute` | nullable — when they arrive, for hair, make-up, costume, rehearsal |
| `castCallMinute` / `castWrapMinute` | nullable overrides of the slot's PAT band |
| `notes` | |

**An actor has three times, not two.** The reference sheets print `ARRIVÉE 16:45` and
`PAT 17:30 – 22:15` side by side, and the gap between them is the make-up chair: collapsing them
would either call an actor two hours before they are needed or lose their preparation entirely.
The arrival is per row only — it is a personal fact — while the PAT band has a slot-level default
each row may override.

**The role is convoked, not the person**: the actor is read through `roles.personId`, so recasting
a role never rewrites the schedule, and an uncast role convoked anyway is a legitimate state that
the alerts report (M3). One actor playing two roles in one night — the reference J5 — is two rows
collapsing into one person on the sheet. **Extras are ordinary `extra` roles**, which the resources
mode already creates by hand; a nameless crowd is a sentence in the day's crew note, not a schema
feature.

### `shooting_day_blocks`

The day's timetable, in order. **This is the heart of the mode.**

| Column | Notes |
| --- | --- |
| `id`, `shootingDayId`, `sortKey`, `isDeleted` | |
| `slotId` | nullable — which convocation window the block sits in |
| `kind` | `OcptShootingBlockKind { shot, preparation, hairMakeUp, meal, travel, wrap, hold }` |
| `shotId` | non-null **iff** `kind == shot`, reference to `shots` |
| `label` | the wording of a non-shot block; for `hold`, what is being reserved |
| `durationMinutes` | nullable; for a shot block, null means "use `shots.estimatedDurationMs`" |
| `anchorMinute` | nullable; when set, the block starts **exactly** there |
| `notes` | |

`hold` is what the mock calls *créneau libre*: "sequence 6 must be shot-listed before its shots can
be placed". It reserves time for work the shot list cannot yet describe, and it is how a production
schedules ahead of its own découpage — which the decision "shots only" would otherwise forbid.

### `shooting_presences`

Written only when the user overrides a computed cell (M3).

| Column | Notes |
| --- | --- |
| `id`, `shootingDayId`, `personId`, `isDeleted` | |
| `code` | `OcptPresenceCode { working, available, travelling, unavailable }` |

## 5. How a day's clock is computed — ADR 0015

The rule, stated once and implemented once, in a pure function
(`lib/utils/ocpt_shooting_day_timeline.dart`, no Flutter, no drift, fully tested):

1. The chain starts at the first slot's `crewCallMinute`.
2. Each block in `sortKey` order starts where the previous one ended, and lasts its
   `durationMinutes` — or, for a shot block with none, the shot's `estimatedDurationMs`, or the
   mode's default when the shot has no estimate either.
3. A block carrying an `anchorMinute` starts **exactly** at that minute. The chain resumes from its
   end.
4. When the chain would have reached an anchored block **later** than its anchor, the timeline is
   over-run: the function reports it as an `OcptTimelineOverrun` rather than silently pushing the
   anchor. The UI shows it in red and the day's total goes over; a schedule that quietly lies about
   a meal break is worse than one that says it no longer fits.
5. A block belonging to a slot whose `crewCallMinute` is later than the chain's current position
   jumps forward to it — a second crew arriving at 11:00 does not start at 10:20 because the
   morning ran short.

Everything downstream — the day view, the week grid, the call sheets, the "estimated end" — reads
this one function. Changing a shot's duration by five minutes therefore moves the rest of the day,
which is the whole point: **that is what makes the plan cheap to rework on set.**

This is recorded as **ADR 0015 — Shooting days as chained blocks with pinned anchors**, written in
M1 alongside the code.

## 6. What happens to `shots.shootingDay`

The column exists and is typed by hand today, its own doc comment saying it waits for this mode.
From M1:

- The schedule's placement is the **only** truth. Placing a shot in a day is what gives it a day.
- The shot list's `Jour de tournage` column becomes a **read-out** (`J3 · Mar 4 août`), and
  `OcptShotListEditableField`'s entry for it goes away.
- **The v11 migration erases the column's values.** No day is invented from the old free text:
  dates are mandatory and `J3` carries none, so a migration that guessed would fabricate a dated
  shoot out of nothing. A blank column and an empty schedule say the same true thing — this
  project has not been scheduled yet — where a half-guessed one would say something false. The
  erasure is part of the migration, so every replica performs it identically and no
  `row_field_versions` stamp is needed.
- The column itself stays in the schema, blank and unwritten, the way `position` did — dropping a
  synchronised column is not something ADR 0010 allows.

## 7. Sun and twilight times

`lib/utils/ocpt_sun_times.dart`, pure Dart, no Flutter, no network, fully tested against published
values for a few known places and dates. The NOAA solar-position algorithm gives, for a date and a
pair of coordinates: sunrise, sunset, and the civil, nautical and astronomical twilights at both
ends of the day — the five figures both reference call sheets print.

- The coordinates come from the day's **first slot's location** (`locations.latitude/longitude`,
  already captured by the resources mode). No coordinates, no sun block: the sheet prints nothing
  rather than a plausible wrong time.
- The time zone is the **device's own offset for that date**. A production shooting in its own
  country — every case this app has — is right; a location abroad would be off by the difference,
  and the day inspector says which offset was used rather than hiding it.

Recorded as **ADR 0016 — Sun times computed offline from the location's coordinates**, because the
alternative (typing them per day, as the reference documents did) is what a user would otherwise
expect, and because the time-zone limitation deserves to be written down where it can be revisited.

## 8. Milestone M1 — planning

**Goal: a shoot can be planned, and the plan can be reworked in seconds.**

- Schema v11: the six tables, the migration, the `onCreate`/`onUpgrade` parity test ADR 0007
  demands.
- `OcptScheduleService` (`lib/managers/projects/services/`), owned by `OcptProjectsManager` beside
  the resources and breakdown services: create/update/reorder/tombstone days, slots, crew, cast and
  blocks; place and unplace a shot; move a block between days; and **duplicate a day** —
  `duplicateDay(sourceId, date)` copies the slots, their crew, their cast and their times, and
  deliberately copies **neither the placed shots nor the crew note**, which belong to the day that
  was planned rather than to the shape of the crew. A stable crew is entered once for a whole
  shoot, and a day lost to rain is re-planned at another date in one gesture.
- `ocpt_shooting_day_timeline.dart` and `ocpt_sun_times.dart`, both pure and tested, plus ADR 0015
  and ADR 0016.
- `OcptProjectVersionCodec` **payload format 6**: the six tables added to the payload, to
  `contentDigest` and to `_applyPayload` — all three, as the codec's own doc warns. An older
  payload upgrades to six empty lists (a project that had no schedule), which is the truthful
  reading.
- `OcptScheduleMode` (`lib/ui/pages/workspace/modes/schedule/`) replacing the empty state, owning
  `OcptScheduleBloc`, mixing in `MixinOcptProjectVersionsBloc`/`…State` and answering its two hooks.
  `OcptWorkspaceMode.schedule.isImplemented` becomes true.
  - **Left dock**: the list of shooting days (date, day number, location, block count, status),
    over the list of **shots still to place**, grouped by sequence, with the *placing* gesture the
    mock uses — pick a shot, then click a day.
  - **Centre**: a header band switching between *Agenda* and *Day*, plus the agenda's own three
    presentations — strip (the day cards, where placing happens), week (an hour grid with the
    day's blocks drawn against sunrise/sunset bands) and month (the shoot at a glance). The day
    view is the timetable: the slots and their convocations above, the chained blocks below, each
    with its computed times, its duration and ± controls, drag-to-reorder, and the anchor pin.
    A shot block additionally carries a **status control** writing the existing `shots.status`
    (to shoot / shot / to redo), so the day reads as a checklist on set and what is left to shoot
    is obvious at the moment the afternoon has to be re-planned. It is the same column the shot
    list edits — one truth, two places to change it.
  - **Right dock**: `Inspector` + the shared `Versions` tab. The inspector shows the selected day
    (date, status, locations, sets, slots, PAT → estimated end, sun times, weather, crew note) or
    the selected block.
- Read-only preview: every writing affordance withheld as a null callback, the pending-edit state
  cleared on entering a preview, per the rules `CLAUDE.md` sets out.
- The shot list's `Jour de tournage` column turned into a read-out (§6).
- l10n: every new string in `intl_en_GB.arb` and `intl_fr.arb`, French saying « séquence ».

**Checkpoint with Benoit** before M2.

## 9. Milestone M2 — the three PDF exports

**Goal: the paperwork a shoot actually runs on.**

Two new services under `lib/managers/export/services/`, both owned by `OcptExportManager`, both
sharing the existing `OcptCourierPrimeFontsLoader`, both taking a labels object so no manager or
service ever sees a `Tr` — the pattern `OcptScenarioCoverageLabels` established.

1. **`OcptCallSheetPdfService`** — one day, two audiences from one composition:
   - *General call sheet*, following the reference `.docx` section by section: recipients, film
     title and director, production and direction contacts, the day's time bands and day number,
     the crew note, the location(s) with address and map link, the sun block, contacts by
     department, the `SEQ / PLANS / EFFET / DÉCORS / RÉSUMÉ / RÔLES` table interleaved with the
     timed milestones (preparation, travel, meal, wrap), the cast table, then the crew list and the
     cast-and-extras list with telephone and e-mail. `EFFET` and `DÉCORS` are read from the scene
     heading and the linked set — the breakdown mode already owns both links.
   - *Named call sheets*, **one PDF per convoked person, written into a folder the user picks**
     (`FDS-J2-Elisa-Mabit.pdf`, …): the same day header, **their** arrival, PAT and wrap times,
     their positions or roles that day, only the blocks they are expected on, the crew note, and
     the key contacts. Not the directory — a call sheet sent to one person should not carry
     everyone else's telephone number. This is the one export that does not write a single file,
     so `OcptSaveLocationService` gains a directory-picking entry point beside its save dialog.
2. **`OcptShootingPlanPdfService`** — the whole shoot, following the `planning tournage.docx`: the
   three summary grids (days × day-parts, by location, by sequence, by person) and then one
   detailed day agenda per day, hour by hour, with its shot tables.

Each is reached from the mode's `⋮` menu through an options dialog opened by `OcptRouterManager`
(which days, which people, title page, page format pre-filled from the project), and each writes
through `OcptSaveLocationService` — no export ever picks a path silently.

**Checkpoint with Benoit** before M3.

## 10. Milestone M3 — grids and alerts

**Goal: seeing what the plan is about to break before it breaks.**

- **Positions matrix**: positions × slots, who holds what, with the mock's orange cell for a
  position that disappears mid-day (held in the morning slot, unfilled in the afternoon one).
- **Presence grid**: people × days, cells computed from the assignments and from
  `person_unavailabilities`, a click cycling an override written to `shooting_presences`, and a
  per-person day count.
- **`lib/utils/ocpt_schedule_alerts.dart`**, pure and tested, producing the alert list the mock
  shows, each pointing at the day it concerns:
  - a person assigned on a day they are unavailable (`person_unavailabilities`, honouring the
    day-part slot) — hard;
  - a slot whose location has no `location_availabilities` window covering it — hard;
  - a key position unfilled in a slot — hard;
  - a position lost between two slots of one day — soft;
  - a role appearing in a placed shot but convoked in no slot that day — soft;
  - a role with no actor — soft;
  - a timeline over-run against a pinned anchor (§5) — soft;
  - a minor's day exceeding what `people.minorNotes` records — soft.
- The alerts panel in the mode, and the alert count in the status bar.

## 11. What this step does not do

- No spreadsheet export (decided; may follow later).
- No weather feed, no map tiles, no geocoding: the app stays offline-only.
- No automatic scheduling or optimisation. The app tells the user what conflicts; it never decides
  the order of a shoot for them.
- **No actual times.** The schedule says what is planned; when a day slips, blocks are moved and
  the estimate recomputes. Logging when each take really started is the script supervisor's report
  — already on the roadmap — and doing half of it here would produce a document nobody can rely on.
- No budget or day-rate arithmetic — that is the budget mode's.
- No per-slot working-time law enforcement beyond the minor's soft alert.

## 12. Definition of done, per milestone

The eight verification gates of `CLAUDE.md` pass at every commit, plus the ninth for any `.md`
touched. In addition:

- **M1**: a project with no schedule opens unchanged; a day can be created, slotted, crewed, cast
  and filled; duplicating a day reproduces its crew and none of its shots; placing a shot, changing
  a duration and pinning an anchor all move the rest of the day; marking a shot as shot from the
  day view shows in the shot list; a project carrying legacy `shootingDay` text migrates to a blank
  column; a version captured before M1 restores without touching the schedule; a version captured
  after it restores the schedule exactly; the migration parity test is green.
- **M2**: the three PDFs are generated from the reference project and read against the documents
  in `debug/plan/`; a day with two slots and two crews prints both; a night slot crossing midnight
  prints the right hours; an actor's arrival and PAT print as two distinct times; the named sheets
  land in the chosen folder, one file per person, none of them carrying the full directory.
- **M3**: every alert has a test with a case that fires it and a case that does not; the presence
  grid's overrides survive a save, a reload and a version round trip.
