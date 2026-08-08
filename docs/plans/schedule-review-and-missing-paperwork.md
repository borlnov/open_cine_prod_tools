<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Schedule review pass, and the paperwork a production still misses

This document is the implementation strategy for the review pass on the schedule mode, and for the
documents a real production expects that this app does not print yet. It is written for the
Sonnet 5 agents that will build it, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. **Read the repository `AGENTS.md` first** — this plan assumes
its architecture, ways of working, coding standards, licensing rules and verification gates, and
does not repeat them.

The decisions this plan builds on are recorded in [ADR 0015](../adr/0015-shooting-days-as-chained-blocks-with-pinned-anchors.md)
(a slot's blocks and its anchored edge), [ADR 0016](../adr/0016-sun-times-computed-offline-from-the-locations-coordinates.md)
(sun times), [ADR 0018](../adr/0018-a-convocation-is-the-slot-you-are-linked-to.md) (what a
convocation is) and [ADR 0013](../adr/0013-binary-assets-referenced-by-path.md) (assets referenced
by path). When this plan and an ADR disagree, the ADR wins.

---

## 1. Why this step exists

The schedule mode plans a shoot and prints three documents. Using it against a real production's
own paperwork surfaced two different kinds of gap.

The first kind is **the app disagreeing with itself, or saying too much**: a presence grid whose
click writes an override that duplicates what the resources mode already records, a positions
matrix whose columns give no way to tell which day a slot belongs to, an alert badge that says
something is wrong and refuses to take you to it, a `Notes` field on a slot and on a block that
never prints and is never said not to, and two PDF documents that carry no generated-at stamp — so
two versions of one call sheet, sent the same day, cannot be told apart by the person holding them.

The second kind is **what a shoot needs and this app has never printed**. A day has guests. A day
has events it does not control — the village fireworks at 17:00 — that no chain of blocks should
absorb. A cast schedule is negotiated on a *Day Out of Days*, not on a call sheet. The pages of the
day's scenes are handed out with the call sheet. A location needs a permit, and the permit has
dates. In every one of those cases the data is already in the file, or one column away, and nothing
comes out of the app.

Both kinds are addressed here, in that order: the mode is made honest first, then it is made to
print what a production actually hands round.

---

## 2. The strategy in one page

- **One schema bump for the whole pass** (v17, payload format 12). Four additions, one removal.
  Doing it once rather than per milestone gives a single migration to pin against `onCreate`
  (ADR 0007), and every milestone after M1 is UI and PDF work with no migration of its own.
- **Nothing computed becomes typeable, and nothing typed is guessed.** The rule the schedule mode
  already runs on (ADR 0018) decides every open question in this plan: the presence grid stops
  being writable rather than gaining a second override; the *Day Out of Days* prints the four
  codes it can derive and not the two it cannot; a permit with no dates raises nothing.
- **A guest is a person linked to a slot**, exactly as a crew member or a role is, so their hours
  fall out of `ocptComputeDayConvocations` with no new rule. An **event is not**: it is a fact
  about the day at an absolute hour, outside every chain.
- **Every new document is built from `OcptSchedulePlanSnapshot`**, and every layout that is more
  than a table is a **pure, tested class in `lib/models/`** — the shape
  `OcptScenarioCoverageLayout` already has — so the hard cases (a 12-minute block on a 10-minute
  grid, parallel slots, a night crossing midnight) are testable without generating a PDF.
- **Ten milestones after the schema one**, each shippable and reviewable on its own.

---

## 3. What changes in the data model

### 3.1 Schema v17

Four additions and one removal, all in one migration.

| Change | Table / column | Why |
| --- | --- | --- |
| new table | `shooting_slot_guests` | a guest is convoked by a slot, like everybody else |
| new table | `shooting_day_events` | what the day does not control, at an absolute hour |
| new column | `shooting_day_blocks.crewNote` | the note about a block that *does* print |
| new columns | `assets.validFrom` / `assets.validUntil` | a permit is a file with dates |
| new column | `project_info.minimumRestMinutes` | the rest a production says it owes, nullable |
| removed | `shooting_presences` | nothing reads it or writes it any more (§4.1) |

`shooting_slot_guests` carries `id`, `slotId`, a **nullable** `personId` referencing the address
book, a `freeName`, a `reason`, `notes`, `sortKey` and `isDeleted`. Exactly one of `personId` and
`freeName` says who the guest is — the discriminator idiom `breakdown_tags` and
`shooting_slots.anchorMinute`/`anchorSlotId` already use — because a guest is regularly somebody
the production will never enter in its address book (a mayor, a journalist, an owner's cousin),
and forcing a `people` row for them would fill the address book with people nobody will contact.

`shooting_day_events` carries `id`, `shootingDayId`, `minute`, `label`, `notes`, `sortKey` and
`isDeleted`. `minute` is an offset from the day's own midnight and **may exceed 1440**, like every
other minute in this mode. It is **not** a `shooting_day_blocks` row and takes no part in any
chain: a fireworks display does not push a shot back, and a block kind for it would make it do
exactly that.

`assets.validFrom`/`validUntil` are nullable `DateTimeColumn`s. **Null means "nobody has recorded
dates", never "valid forever"** — the same reading `people.maxDailyPresenceMinutes` and a
location declaring no availability window already have, and the reason the permit alert (§4.4)
stays silent rather than advancing a claim nobody entered.

`project_info.minimumRestMinutes` is a nullable `IntColumn`. Null means no minimum has been
recorded and the rest alert says nothing. **It is deliberately not defaulted to 660**: eleven hours
is French law, this app ships in more than one country, and a default would be the app advancing a
legal figure nobody here validated.

### 3.2 Payload format 12

Three kinds of upgrade at once, all of them already precedented:

- `shooting_slot_guests` and `shooting_day_events` materialise as **empty lists** (format 6's
  kind): a version captured in format 11 was taken when nothing in the app could say a day had a
  guest, so "this day had none" is a truthful statement about that moment.
- `shooting_day_blocks.crewNote` materialises as the **empty string**, and
  `assets.validFrom`/`validUntil` plus `project_info.minimumRestMinutes` as **null** (format 11's
  kind): those columns are nullable or defaulted by design, so a version predating them truthfully
  recorded nothing, and that nothing is written back like any other changed column.
- The `shooting_presences` list is **dropped** (format 8's kind, the second entry in the codec
  that removes rather than materialises). A format-11 version genuinely did carry presence
  overrides; the project being restored into has no concept for them any more, so they come back
  as nothing at all, and — as everywhere else — **nothing is reconstructed**: an override that said
  `travelling` does not become a slot nobody asked for.

Read format 8's own doc comment before writing this entry. Every new table has to reach all three
of `OcptProjectVersionCodec`, `contentDigest` and `_applyPayload`.

---

## 4. What changes in the schedule mode

### 4.1 The presence grid stops writing

The grid mixed two things: a **computed reading** — who is convoked on which day — which is a real
production document (it is the `COMÉDIENS × jours` band of the reference `Plan de travail.xlsx`),
and a **click-through override** stored in `shooting_presences`, whose `available`/`unavailable`
values restate what `person_unavailabilities` already says in the resources mode, from a second
source of truth.

The override goes. `OcptSchedulePresenceCell` reduces to `working | unavailable | none`, all three
computed; the cell loses its `onTap` entirely and the grid joins `Convocations`, the positions
matrix and the `Alerts` panel as a view that needs no `isReadOnly` handling at all, having nothing
to withhold. `OcptScheduleService`'s presence writers and the `shooting_presences` table go with
it (§3).

`travelling` disappears with them, and that is a real loss stated here so nobody rediscovers it:
it is the one presence fact no computation gives. §5.8 explains why the *Day Out of Days* prints
four codes rather than six rather than bringing the table back.

### 4.2 The positions matrix

Three changes, none touching the alerts:

- **The "lost" marking is removed altogether.** The cell of a position lost mid-day becomes a plain
  em dash; `OcptSchedulePositionLostAlert` stays and is read in the `Alerts` panel alone. The
  matrix therefore stops reading `lostPositionAlerts` and the widget's whole `lostPersonIdByCell`
  machinery goes with it — including `schedulePositionsMatrixLostCellLabel` and
  `schedulePositionsMatrixLostCellTooltip` in both ARB files.
- **A day band above the slot row.** One header row grouping the columns of a day under its own day
  tag and date, drawn once above the first of its columns — the shape
  `OcptShootingPlanPdfService._gridPage` already uses for its landscape grids. A column header
  today says `D3` on every column, which reads as noise rather than as a grouping.
- **The resolved end beside the resolved start.** Each column header prints
  `<start> → <end>` off `OcptShootingSlotTimeline`, not `startMinute` alone. A slot's end is a fact
  about its blocks and is exactly what a reader of this matrix is looking for when they ask whether
  a position is covered until the wrap.

### 4.3 The alert badge opens the panel

`OcptScheduleDayAlertBadge` gains a **nullable** `onTap`. It is wired in **one place only**: the
day view's own summary band. Its doc comment is amended rather than contradicted — the argument
against a callback holds wherever the badge sits on a surface that is itself clickable (the left
dock's day cards, the three agenda presentations), because a badge swallowing that tap would make
selecting a day depend on hitting a 16-pixel square. The summary band is not a selection target:
the day it describes is already selected, so there is nothing for the badge to steal.

Tapping it dispatches the mode's existing right-dock event with `OcptScheduleRightDockTab.alerts`,
opening the dock if it is closed. It writes nothing, so it stays available under a version preview.

### 4.4 Two new alert kinds

`ocpt_schedule_alerts.dart` gains its tenth and eleventh kinds, both **soft**, both computed from
data the file already holds, and both silent in the absence of the figure they measure against —
the rule the file's own doc comment already argues for the three deliberate absences.

- **`OcptScheduleRestTimeAlert`** — a person's departure on one day and their arrival on the next
  are closer together than `project_info.minimumRestMinutes`. Carries the person id, the two day
  ids and the actual gap in minutes; the panel writes the sentence. Silent when the project records
  no minimum. It is grouped onto the **second** of the two days (the one whose call is too early),
  which is the day a production would move.
- **`OcptSchedulePermitMissingAlert`** — a slot is shot at a location that has at least one
  `permit` asset, and **none of those permits' validity windows covers the day's date**. Carries
  the slot id, the location id and the day id. A location with **no permit asset at all raises
  nothing**, and a permit with no dates raises nothing: absence of data is not a refusal, and a
  production that files no permits must not be drowned — the same argument the file already makes
  for a location declaring no availability window.

Both are read by `OcptScheduleDayAlertBadge` and the status-bar count for free, those reading the
alert list and never a second reading of the rules.

### 4.5 Guests

A third list on the slot card, **under** the crew and cast columns rather than beside them, and
**entirely absent while the slot has no guest** — not a collapsed band, nothing at all. Guests are
rare, and a slot that has none must read exactly as it does today. The `+ Guest` affordance lives
in the slot card's own menu rather than as a permanent footer, for the same reason.

A guest row is: the person (a picker over the address book, or a typed free name), a reason, and a
note. **No clock**, like every other convocation card — the hours are read in `Convocations`.

`ocptComputeDayConvocations` gains guests as a third kind of link, with one difference stated in
its own doc comment: a guest gets an **arrival and a departure and never a PAT band**, whatever
shooting blocks the slot carries. A guest does not shoot; a band would say they were waiting to.
In the `Convocations` panel they form their own trailing group, after crew and cast.

Guests take part in **no alert**: they hold no position to lose, they have no maximum daily
presence, and they are not cast. `duplicateDay` **copies them** along with the crew and the cast —
a location owner who attends every day of a shoot is entered once.

### 4.6 Events

A day-level card in the day view, under the slot cards, and a matching section in the day
inspector: one row per event, its hour typed in the same `OcptScheduleMinuteField` every other time
uses, then its label and its note. Ordered by hour.

Events are drawn as a **full-width marker** on the day view and in the week grid — across every
lane, since an event belongs to the day rather than to a unit. They are never dragged and never
chained: moving one is typing another hour.

`duplicateDay` **does not copy them**. A guest attends a shoot; an event happens on a date. A
duplicated day is a day re-planned at another date, and carrying the village fireworks over to it
would be the app inventing a fact about the new date.

### 4.7 Two kinds of note

`shooting_slots.notes` and `shooting_day_blocks.notes` are renamed **"Private notes"** in the UI
(`Notes privées`) — the column names do not change, this is an ARB change in both files plus the
field labels. They never print, and until now nothing said so.

`shooting_day_blocks.crewNote` is the new **"Crew notes"** (`Notes à l'équipe`) field, edited in
the block inspector beside the duration, and **printed** — on the call sheet under its block's own
row, and in the shooting plan's day agenda. It is the sibling of `shooting_days.crewNote`, which is
the note for the whole day; this one belongs to one block ("the neighbours have asked for silence
before 9:00", "the generator arrives during this move").

---

## 5. Milestones

Each milestone ends on the full verification gate list of `AGENTS.md` and one commit per logical
change. M1 is a prerequisite for everything; M2 to M11 are independent of each other except where
said.

### M1 — Schema v17 and payload format 12

The whole data model of this plan, in one migration: the two new tables, the four new columns, the
`shooting_presences` removal, the codec's format-12 entry (all three kinds — see §3.2), the
migration test pinning `onCreate` against every upgrade path, and the service methods
(`OcptScheduleService` for guests and events, `OcptAssetsService` for the permit dates,
`OcptProjectsManager` for the project's rest minimum). `duplicateDay` is amended here (§4.5, §4.6).

No UI. This milestone is done when the migration test, the codec round-trip test and the restore
tests are green.

### M2 — The reading fixes

Presence grid read-only (§4.1), positions matrix (§4.2), alert badge (§4.3), the two note labels
(§4.7). No schema, no export. The smallest milestone and the one whose absence is felt daily.

### M3 — Guests and events in the app

The slot card's guest band, the day's event card, the day inspector's event section, the block
inspector's crew-note field, the `Convocations` panel's guest group, and the agenda markers
(§4.5, §4.6, §4.7). Every new control is withheld under a version preview through a null callback,
as the mode's existing ones are.

### M4 — The two new alert kinds

`ocpt_schedule_rest_time` and the permit crossing, in `ocpt_schedule_alerts.dart` (§4.4), their
sentences in the `Alerts` panel, the permit validity fields on the location sheet's asset lines,
and the project's rest minimum in `OcptProjectSettingsPage`. Pure-function tests carry this one.

### M5 — The generated-at stamp

One helper in `ocpt_schedule_pdf_shared.dart` formatting the moment a document was produced, so the
two services cannot say it differently, and an `exportDate` parameter threaded through both (the
shooting plan already has one; the call sheet service needs it, and both must be injectable so a
test pins it rather than racing a midnight rollover).

- **Shooting plan**: date **and time** on the title page's version line, and the same stamp in the
  running head of every page.
- **Call sheets**, general and named: a version line in the title block, carrying date and time.

This is what tells two call sheets sent the same day apart, and it is worth its own milestone
because it touches both services and every one of their golden tests.

### M6 — The call sheets

- **Day selection for the named sheets**, exactly as the general export has it. The recipient list
  becomes the union of the selected days' convocations; the export writes **one file per
  (recipient × day)**, a call sheet being a document about a day. The name-collision suffixes
  (`-2`, `-3`) extend to the pair, and `OcptCallSheetExportResult`'s three-outcome reporting is
  unchanged — a file that did not land is somebody never told to turn up.
- **Guests** printed in their own block, **events** printed as their own timed section, and a
  block's **crew note** printed under its row.
- **"To bring"** on a named sheet: the elements whose `broughtByPersonId` is the recipient and
  which are linked to a scene placed on that day. Two existing columns joined, nothing invented
  (§5.7 covers the same data on the shooting plan).

### M7 — The shooting plan

- **An hours column first**, before `Plan`: the block's resolved start over its resolved end, in
  the day agenda's shot tables.
- **The 10-minute day agenda**, a new optional section, one page per day: rows every 10 minutes
  from the day's earliest resolved start to its latest resolved end, one column per slot, blocks
  drawn as tiles spanning their rows, events as full-width markers. It **adds to** the existing
  detailed agenda rather than replacing it, and is a checkbox in the options dialog.

  Its geometry is `OcptShootingDayAgendaGrid.of(...)` in `lib/models/`, **pure Dart, no `pdf` and
  no Flutter**, exactly as `OcptScenarioCoverageLayout` is: a 12-minute block on a 10-minute grid,
  two slots whose chains overlap, and a night crossing midnight are all decided and tested there,
  and the service only draws. A block's exact times are printed inside its tile, the grid being a
  reading aid rather than a claim that everything falls on tens.
- **An elements grid**: elements × days, grouped by `OcptElementCategory`, one row per element
  linked to a scene placed in the printed range — the reference `.xlsx`'s own `ANIMAUX`,
  `VÉHICULES`, `ÉQUIPEMENTS SPÉCIAUX` bands. Grouping is by category and never by department:
  `OcptElementCategory` has fourteen entries and `OcptCrewDepartment` six, and a mapping between
  them would be the app's own opinion about how a production is organised.
- Guests, events and block crew notes printed in the detailed agenda.

### M8 — The Day Out of Days

The most standard cast-scheduling document there is, and the one this app has all the data for:
one row per role, one column per shooting day, a code per cell.

`ocpt_day_out_of_days.dart` (`lib/utils/`, pure, no Flutter and no `Tr`) computes it, and it prints
**four codes, not six**:

- `SW` — start work, the role's first convoked day.
- `W` — work, a day the role is convoked on.
- `WF` — work finish, the role's last convoked day.
- `H` — hold, a day between the first and the last on which the role is not convoked.

`T` (travel) and `R` (rehearsal) **are not printed**, because nothing in this file says either, and
the one column that could have carried travel is the presence override this same plan removes
(§4.1). Printing a `T` nobody entered would be the app inventing a paid day. If a production later
needs them, they come back as a *typed* fact with a table of their own, not as a resurrected
override on a computed grid.

A landscape PDF, chunked across pages like the shooting plan's grids, plus a trailing count of
worked and held days per role. Rows are ordered by role number.

### M9 — The one-liner

The compact strip schedule the industry plans on: one line per sequence, in shooting order, over
the whole shoot — day banner, then sequence number, effect, set, roles, estimated duration. It is
what the mode's strip agenda already shows on screen and has never printed.

Landscape, one continuous flow across pages, with a day band between days. It reads off the same
`ocptOrderedScheduleEntriesOfDay` walk both existing services use.

### M10 — The sides

The pages of the day's scenes, printed as a booklet and handed round with the call sheet.

Everything needed exists: `OcptSchedulePlanSnapshot` says which scenes a day plays,
`FountainScriptComposer` typesets the screenplay, and ADR 0012's source provenance maps a scene's
own source range onto printed rows. The service extracts the runs of rows belonging to the day's
scenes and reprints them through `OcptScriptPagePainter`, keeping the real screenplay layout — a
side is only useful if it looks like the script.

Options: which day, whether to print scene numbers, and whether to print one page per screenplay
page or to pack the runs. A day with nothing placed prints a readable note, never an empty file.

### M11 — The contact list, and the two workbooks

Three smaller exports, grouped because none is worth a milestone alone:

- **A standalone contact list PDF** — crew by department then cast, with positions, phone numbers
  and e-mails. It exists today only buried in a call sheet's own directories, and it is the
  document a production circulates once at the start of a shoot.
- **The shooting plan as XLSX**, through `excel_community` like the two existing workbooks. The
  reference document *is* a spreadsheet, reworked by the production office; a PDF cannot be.
- **The breakdown sheets as XLSX**, for the same reason (`Dépouillement v2.xlsx` is a spreadsheet).

Both workbooks take their headings as an `Ocpt…XlsxLabels` object, exactly as the two existing ones
do: no service here ever sees a `Tr`.

---

## 6. Out of scope, and why

These came out of the same audit and are **not** in this plan. They belong in GitHub issues.

| Subject | Why it is not here |
| --- | --- |
| Daily production report | Needs a script-supervisor mode: what was *actually* shot, not what was planned |
| Camera and sound reports | Same — rolls, cards and timecodes are the script/post modes' data |
| FDX (Final Draft) import | A parser of its own, in `fountain_kit`'s sibling position, not a schedule task |
| ICS calendar export | Small and worth doing, but it is an app-wide export rather than a schedule one |
| Overtime and night hours | Computable from the presence band and the sun times, but needs a per-project reference working day the app does not model |
| Screenplay diff between versions | A cross-mode feature driving re-breakdown; it belongs with the screenplay mode |
| Bulk e-mailing of named call sheets | The app never reaches the network (ADR 0009's spirit); a `.csv` of addresses beside the folder is the local half, and is small enough to fold into M6 later |

---

## 7. Verification

Beyond the standard gates, this plan is done when:

- The migration test pins v17's `onCreate` against every upgrade path, including the
  `shooting_presences` removal.
- A format-11 payload restores into a v17 project with its guests and events empty, its crew notes
  blank, its permit dates and rest minimum null, and **no presence override reconstructed
  anywhere**.
- `ocptComputeDayConvocations` returns a guest with an arrival, a departure and **no PAT band**, on
  a slot carrying shooting blocks.
- The two new alert kinds stay silent on a project that records no rest minimum and files no
  permits.
- `OcptShootingDayAgendaGrid` is tested on a 12-minute block, two overlapping parallel slots, and a
  day running past midnight, with no PDF generated.
- The *Day Out of Days* prints `H` for a gap between a role's first and last convoked day, and
  prints nothing at all outside that span.
