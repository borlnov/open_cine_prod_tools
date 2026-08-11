<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the schedule mode

When the film is shot: the data and the time model, the four views, the alerts, and the
seven documents a production runs on.

## The data and the time model

- The mode lives in `lib/ui/pages/workspace/modes/schedule/` and says **when** the film is shot.
  It sits after the shot list, since what is placed on a day is a shot.
  It is the **one mode that reads every episode at once** (ADR 0019), so the shell draws it no
  episode selector at all: `shooting_days` carries no `screenplayId`, a day regularly covering two
  episodes at one location being the whole point of shooting a series out of order, and filing it
  under one would make the mode lie about the plan it holds. `OcptScheduleService` loads across the
  project and `OcptSchedulePlanSnapshot` joins them — its shot list, its scene headings, its scene
  numbers (`sceneNumberBySceneId`, `ocptSceneDisplayNumberOf`'s answer, hence `2.12`) and its scene
  spans are the project's, not one screenplay's. Nothing about a day, a slot, a block or a
  convocation changes: they never named a screenplay to begin with. The status band says so too —
  `N episodes` sits second, right after the alerts, and is **absent on a single-episode project**,
  which names no episode anywhere.
  A **shooting day** (`shooting_days`) is **always dated** — the week and month views, the sun times
  and every availability crossing depend on it — and its number, the `J3` a call sheet prints, is a
  **read-time rank** over the live days **in date order**, never a column, exactly as
  `OcptShot.position` is. `J1`/`J2` are a **chronological label, not an id**: re-dating a day
  renumbers the schedule around it, and `sortKey` survives only as the tiebreaker between two days
  sharing one date. `ocptScheduleDayTagLabel` renders it **through `Tr`** (`D3` in English, `J3` in
  French): the paperwork a crew reads is printed in the language the app is set to, so the letter
  follows it. The workbook export, having no `Tr` of its own, takes it as
  `OcptShotListXlsxLabels.dayTagPrefix`.
  A day holds one or more **slots** (`shooting_slots`), the *créneaux* — a working unit with its own
  location, set, crew and hours; a real call sheet regularly has two, with different crews and
  different call times, which is why they are rows rather than columns. A slot owns **one anchored
  edge and no other clock** (ADR 0015): `anchorEdge` says whether its start or its **end** is the
  pinned one, and that edge's hour comes from exactly one of a typed `anchorMinute` and the
  **opposite** edge of another slot of the same day (`anchorSlotId`) — the discriminator idiom
  `breakdown_tags` already uses. A production books a studio until 22:00, or plans backwards from a
  sunset, as often as it plans forwards; where the slot actually starts and ends is computed from
  that one hour and its own blocks, never read off a column. A link never crosses two days and never
  joins two same-side edges ("these two start together" is said by typing the same hour twice).
  Who is convoked is `shooting_slot_crew` (a person and a position, two rows for one person holding
  two functions), `shooting_slot_cast` (**the role, not the person** — the actor is read through
  `roles.personId`, so recasting never rewrites the schedule) and `shooting_slot_guests` (somebody
  neither crew nor cast — a mayor lending a square, a journalist —, named by either a `people` row
  or a free name; the free half is **read back defensively and never written**, nobody being created
  from this mode). A day also carries **events** (`shooting_day_events`): what it does **not**
  control, at an absolute hour — the village fireworks at 17:00 — belonging to the day rather than
  to a unit, and taking part in **no chain** (a block kind for it would let it push a shot back).
  Every minute in this mode is an **offset from the day's own midnight and may exceed 1440**: a
  night slot running 19:00 → 03:00 stores 1140 → 1620, nothing is ever taken modulo anything, and
  `ocptFormatDayMinute` (`lib/utils/ocpt_day_minute.dart`) is the single formatter that reads one as
  a clock face. Getting this wrong only shows up on the one night shoot of a production.
  A timetable is `shooting_day_blocks`, and **every block belongs to exactly one slot**: a day is a
  set of **parallel chains**, one per slot, not one chain shared by all of them. **How a chain
  becomes clock times is stated once and implemented once**, in `ocptComputeSlotTimeline`
  (`lib/utils/ocpt_shooting_day_timeline.dart`, ADR 0015): durations chaining from that slot's own
  resolved start, a block with an `anchorMinute` starting exactly there, and an anchor the chain has
  already run past reported as an `OcptTimelineOverrun` rather than silently pushed.
  `ocptComputeShootingDayTimelines` **resolves the anchors** before that loop runs, around it rather
  than inside it: slots are resolved in **dependency order**, an `end`-anchored one starts at
  `end − Σ durations` and then chains forward unchanged (so adding a block pulls its start earlier
  and leaves its end where it was), a pinned block that makes such a slot finish elsewhere is an
  `OcptTimelineFixedEndMiss` — **reported, never absorbed**, the fixed end winning — and a circle of
  anchors is an `OcptTimelineAnchorCycle` whose slots are placed at the day's earliest
  already-resolved start rather than hung on. That circle is defence against a file, not a state a
  user can reach: the anchor menu greys out an entry that would close one
  (`ocptSlotAnchorWouldCycle`) and `OcptScheduleService.setSlotAnchor` refuses to write one.
  `OcptShootingSlotTimeline.startMinute` is the **resolved** start every reader of "the hour of this
  slot" reads; `dayStartMinute` is the minimum over them and `dayEndMinute` the **maximum** over
  their ends — a day ends when its last unit wraps. Two slots overlapping in wall-clock time is
  **legal, not a conflict**: that is what splitting a day into slots is for, and one *person*
  convoked in both at once is an alert, a different question. **No computed time is ever stored** —
  that is what makes a day cheap to rework between takes — so everything downstream reads those
  functions and nothing re-derives them.
  A `hold` block reserves time for a sequence not yet shot-listed, which is how a production
  schedules ahead of its own découpage, and it names that sequence through
  `shooting_day_blocks.sceneId` rather than through its free-text label, free text answering nobody
  (the column is nullable, a production blocking time out before settling what goes there); a
  `pause` block is the break that is not a meal, and like every milestone kind it names no role. A
  block carries a **crew note** beside its `notes`: `notes` is private and never prints, `crewNote`
  is the one that does, and the UI labels the former **`Private notes`** (`Notes privées`) so the
  two cannot be mistaken for one another.
  **A convocation is the slot you are linked to** (`ocptComputeDayConvocations`,
  `lib/utils/ocpt_shooting_convocations.dart`, ADR 0018): nobody types a call time, and **nothing is
  offset from anything**. A person is convoked by being **linked to a slot** — by person, by role or
  by either half of a guest row, all three kinds counting — and every figure about them is read off
  the slots they are linked to and the blocks in them, joined across the **whole day**: their
  **arrival** is the earliest start over those slots, their **PAT band** runs from the earliest
  shooting block to the latest, and their **departure** is the latest slot end. A production that
  wants somebody there at 06:00 for make-up creates a 06:00 slot and links them to it — its label
  (`HMC`, `Installation`) is what says why, its blocks are what say how long. That is the trade ADR
  0018 accepts: convoking one actor earlier costs a **slot** rather than a number typed in place,
  and the resulting file says what is actually happening, and prints.
  A **shooting block** means `shot` **and** `hold` — a production scheduling ahead of its own
  découpage still owes its cast a band — while every other kind (`preparation`, `hairMakeUp`,
  `meal`, `pause`, `travel`, `wrap`) is not shooting time and never opens or closes one. **A slot
  with no shooting block therefore gives no PAT at all**: somebody convoked only on preparation
  slots has an arrival and a departure and no band, which is the truthful reading — they are there,
  they are not waiting to shoot — and a slot carrying no block whatsoever ends at its own start, a
  convocation with no content yet rather than a zero-length error. The band is **not clipped to one
  slot**: someone on a morning slot and an evening slot reads one band spanning both, gaps included.
  **Nothing depends on a block naming the person**: `shot_characters` and the roles the breakdown
  tagged in a hold's sequence take no part in a convocation — whoever is linked to the slot is
  convoked by the slot, for the whole of it. **A guest never gets a band at all**, whatever shooting
  blocks their slots carry: an arrival, a departure and an em dash between them, a guest not being
  there to shoot. A guest is also the one kind that may double: somebody convoked as crew or cast
  **and** attending the same day as a guest reads as **two** convocations, deliberately — folding
  the two would put a PAT band on a visit. It follows that a guest is never `working` in the
  presence grid either, and that guests take part in **no alert** (they hold no position to lose,
  have no daily maximum and are not cast). There is no after-offset anywhere, finishing later being
  said with a `wrap` block, which moves everybody's departure at once, and **nothing computed is
  overridable by hand**: a typed clock is a claim nothing keeps true once a block moves.
  Sunrise, sunset and the three twilights are **computed offline** from the day's first slot's
  location (`ocptSunTimesOf`, `lib/utils/ocpt_sun_times.dart`, ADR 0016), each figure independently
  nullable — no coordinates, or a phase that never happens at that latitude, prints nothing rather
  than a plausible wrong time. The time zone is the **device's own** for that date, which the day
  inspector says rather than hides.
  `OcptScheduleService` is owned by `OcptProjectsManager` beside the other services. **A shot may be
  placed as many times as the plan needs**: a shot interrupted by the meal break and resumed after
  it is two blocks on that day, not one, so `placeShot` only ever creates — a placement is moved and
  removed like any other block, and there is no operation keyed by shot. `loadShotPlacements`
  therefore answers with a **list** per shot, which the shot list's `Jour de tournage` reads out as
  the day tag and its date while every placement lands on one day (the meal-break case included) and
  as the day tags alone, joined, once they don't (`ocptShotPlacementLabel`, mirrored cell for cell
  by the workbook's own `_placementCellOf`). Deleting a day cascades onto everything hanging off it;
  deleting a **slot** carries its blocks over to the day's first remaining slot, and tombstones them
  with it only when it was the day's last one — nothing can hold a block any more then.
  `duplicateDay` copies the slots, their crew, their cast and their guests (a location owner
  attending every day is entered once), and deliberately **neither the placed shots, nor the crew
  note, nor the events**: a stable crew is entered once for a whole shoot, a day lost to rain is
  re-planned at another date in one gesture, and an event happens on a date. Convoking somebody
  **seeds nothing**: a convocation is the link and only the link.
  **`OcptSchedulePlanSnapshot`** (`lib/models/`) is where the mode's six reads — the schedule, the
  shot list, the locations, the cast, the address book and the elements catalogue — are joined into
  the day-level facts everything else asks for: `timelinesOfDay`, `convocationsOfDay`,
  `sunTimesOfDay`, `dayArrivalMinute`, `firstLocationOfDay`, `presenceCellOf`, `sceneIdsOfDay`,
  `elementsToBringOnDay`, `sceneNumberBySceneId`, `sceneSpanBySceneId`, `convokedRoleIdsOfDay` and
  `alerts` — the whole-shoot walk, computed **once** per snapshot rather than per read, which is
  what made this class stop being `const` exactly as `OcptScheduleState` did. It exists because
  those joins have **two** callers, `OcptScheduleState` and the manager layer's export services, and
  a second implementation over there is exactly how a printed call sheet and the day view would come
  to disagree about what hour a slot starts at. The state builds one **per state instance**, not per
  read: a state is immutable, so the join cannot go stale inside one.

## The views

- The centre is one of **four** (`OcptScheduleCentreView`, whose declaration order is the header
  switch's own): the day view, the agenda, the positions matrix and the presence grid — the
  working surface first, the three readings of it after.
  The **day view** is the working surface: the slot cards, each carrying its own **private note**
  under its location and set (what that unit alone needs saying — the parking, the key holder —, the
  day's own note to the crew being a different thing) and a `▲`/`▼` pair moving it in the day's list
  (the pair is drawn as soon as one of the two leads anywhere, the other reading as disabled rather
  than disappearing). Each card enters its own crew, cast and guests on itself, under **one foldable
  section**, `Assigner des personnes`, whose title is the only one that folds — expanded by default,
  its count being the three kinds together while each kind's own title is a plain read-out: a
  settled crew, cast and guest list are entered once and then read past for the rest of the shoot,
  and the point of the fold is to get to the timetable, so one gesture answers for the three. That
  fold is local widget state — a reading preference costs nothing to lose. The crew and cast lists
  sit side by side, **at most half the card's width each**, their cards **wrapping** into as many
  columns as that half affords; the guests get a third band, full width **under** those two halves,
  **always drawn**, empty hint and all — a band that had to be revealed from a menu before it could
  be filled hid the very affordance somebody looking for it was after. A convoked person is **one
  card**, whichever kind — the position picker or the role name or the guest's reason, then who that
  is, and **no clock at all**: a convocation is a fact about a person on a **day**, joined across
  every slot they sit on, and cannot honestly be read from one slot's card in isolation. The times
  live in the `Convocations` dock tab instead.
  **A crew row's position is pre-filled from the address book, and the picker is the same join read
  the other way** (`ocptCrewPositionPrefillOf`, `lib/utils/ocpt_crew_position_prefill.dart`, pure and
  tested): a position's identity is the pair (`positionId`, `customLabel`) both tables already model
  one with, and the function answers, out of a person's declared `person_positions` and what they
  already hold **on that slot**, which position to pre-fill and which to promote.
  `addSlotCrewMember` lands a fresh row on their first declared position not already taken there —
  so convoking the same person twice lands on their second, then their third — and only ever fills a
  blank, a caller passing a position keeping it. The row's own picker shows those declared positions
  above the catalogue's departments, behind a divider, and **never offers a position that person
  already holds on that slot**, this row's own included: the duplicate is refused where it is chosen
  rather than the add being blocked, and the taken one is absent rather than greyed, being visible
  on the card right beside the picker. It is a **pre-fill, not a rule**: nothing keeps the two tables
  in step once the user has corrected it.
  On the card itself sits **that slot's own timetable**: a day carries no timetable of its own,
  every block belonging to exactly one slot. Its blocks are dragged into place, nudged by `±` —
  which **snaps to the nearest five minutes**, so a duration of 12 steps up to 15 and down to 10,
  the odd figure being deliberately lost — pinned by an anchor whose minute is typed in the same
  `OcptScheduleMinuteField` every other time uses (rendered without a callback, that field is also
  how a computed time is read out), and shown in the error colour when their anchor over-ran. A
  block leaves its slot either by being **dragged onto another card's timetable** — the drag handle
  keeps the in-slot reorder and the row body carries the cross-slot drag, so the two never meet in
  the gesture arena — or through its row's own `Move to…` entry, the pointerless path. A shot block
  carries a **status control writing `shots.status`**, the same column the shot list edits — one
  truth, two places to change it — so a day reads as a checklist on set. **A shot is placed from the
  slot it is shot in**: the timetable's own `+ Block` menu opens on `Shot`, which opens
  `OcptScheduleShotPickerDialog` — the whole shot list, searched and grouped by sequence, every row
  selectable including a shot already placed, which merely carries the day tags it sits on so a
  second placement reads as a choice rather than an accident. The picker is the mode's to open,
  never the timetable's: the widget only asks (`onShotBlockRequested`).
  A day's **events** are drawn by **one widget shown twice** (`OcptScheduleDayEventsList`): the day
  view frames it in its own band under the slot cards, the day inspector in a section of its own,
  both editable, so the two surfaces cannot read a day's events apart. A row is its hour, its label,
  its note and a remove control that only **asks** — an event is a typed row like a block, so
  deleting one goes through `OcptConfirmDialog` as every irreversible action here does. A fresh
  event lands on the day's own earliest resolved slot start (09:00 with no slot yet), **a starting
  point the row's own field immediately corrects rather than a claim about when anything happens**.
  The **agenda** is the second view, in three presentations: strip, week (an hour grid shaded by the
  sun times, stretched to whatever the timeline returns so a night shoot draws where it belongs, a
  day's own column split into **one lane per slot** since two chains may overlap, the hour rules and
  the sun shading staying column-wide because they are facts about the day rather than about a unit)
  and month (a cell reading the **earliest** of its slots' starts, the first in `sortKey` order not
  being the earliest once slots run in parallel, and saying how many units the day carries). The
  strip is **informative**: it shows what each day carries and **opens** one, and nothing is placed
  or unplaced from it — a block lives in a slot, so it is made and unmade where the slot is. Only
  the week grid draws an **event**, as a full-width marker across every lane — it belongs to the
  day, not to a unit — and stretches its own hour range to show one pinned outside every block's
  span. A day's own band is read **arrival → end**, on the strip card as in the day inspector and
  the day view's summary: `OcptScheduleState.dayArrivalMinute` is the **earliest resolved start over
  the day's live slots**, never a stored column — an end-anchored slot's own start being a fact
  about its blocks. The week and month grids read the same figure and mean something narrower by it
  on purpose: a cell there answers "when does this day shoot", not "when is the call".
  The agenda's own **`Colour by`** control tints its three presentations by **location** or by
  **effect**, INT/EXT crossed with day/night read off the headings of the shots placed on that day
  through `ocptSceneEffectOf` (`lib/utils/ocpt_scene_effect.dart`, pure and shared with the call
  sheet's own `EFFET` column, so a printed sheet and the agenda cannot disagree about what a heading
  says). It classifies `DAY`/`NIGHT`/`JOUR`/`NUIT` and **nothing else** — widening that set is a
  decision about a language, not a bug fix — and a day mixing two effects reads as an explicit
  **mixed** tint (`lib/constants/ocpt_schedule_effect_palette.dart`, fixed ARGB like every other
  palette that must read the same in every project) rather than as a dominance nobody computed,
  while a day with nothing placed or nothing classifiable keeps the theme's neutral: information and
  its absence never wear the same colour. The choice is state beside `agendaMode`, not persisted.
  The **positions matrix** is the third view: positions × slots, one column per slot grouped under
  its day and one row per position **somebody actually holds somewhere** (free labels grouped last,
  having no department). The grouping is drawn as a **day band** over the slot headers — the day tag
  and the date once, spanning that day's own columns — so a column header carries the slot's label
  and its **resolved hours, start over end** alone: a slot's end is what a reader of this matrix is
  after when they ask whether a position is covered until the wrap. A position **lost mid-day** is
  **read here and nowhere else**: two neighbouring columns of one day say it without a word, and it
  raises no alert anywhere in the app — a crew that changes between a morning unit and an afternoon
  one is what a slot is *for*, so a sentence about every such change only ever cried wolf on the
  ordinary case. Every cell is therefore a holder or an em dash, and the matrix writes nothing.
  The **presence grid** is the fourth: people × days, a trailing count of each person's working
  days, and cells that are **computed** — `working` when that person is convoked that day,
  `unavailable` when they are not but a `person_unavailabilities` window covers the date, and
  **blank** otherwise, blank being absence of information rather than a claim about it. **All three
  are computed and nothing there is clickable**: a by-hand override table was declared and then
  dropped, having restated from a second source of truth what `person_unavailabilities` already
  records in the resources mode, and `OcptPresenceCode` keeps only the two values a computation can
  actually give. `travelling` went with it, and that is a **real loss** rather than an oversight: it
  is the one presence fact nothing computes, and it comes back, if it ever does, as a typed fact
  with a table of its own — not as a resurrected override on a computed grid. The reading lives in
  `OcptSchedulePlanSnapshot.presenceCellOf` (a plain `OcptPresenceCode?`, null being the blank
  cell), and a cell whose person is convoked on a day they are unavailable is marked from
  `OcptSchedulePersonUnavailableAlert`, not from a second reading of that rule.
  The left dock is the day list over the shots still to place, and a click on one of those
  **selects** it, nothing more. Those shots and `OcptScheduleShotPickerDialog`'s own list are the
  two surfaces a multi-episode project regroups: both already grouped by sequence and head their
  groups by **episode, then sequence** through the shared `OcptScheduleEpisodeBand` — a band rather
  than a mechanism, and drawn by neither while the project holds one episode. The right dock is
  `Inspector` + `Convocations` + `Alerts` + the shared `Versions` tab, the inspector reading block,
  then shot, then day, the block and shot selections being mutually exclusive by construction. A
  block's own **duration is typed in the inspector** — any figure, 12 included, against the `±`
  stepper's five-minute grid, the two writing the same column from the two places a duration is
  thought about — and its **crew note** right under it. **`Convocations` is the day's whole call**
  — one card per person, crew and cast folded together (an actor read through `roles.personId`),
  plus one per **uncast role**, which is a convocation the production still has to honour and is
  named by the role; each card reads arrival → PAT band → departure, an **em dash** where there is
  no band, over the slots it is linked to by label. It is scoped to the **selected day**, sorted by
  arrival then by name (the order people walk in — `ocptComputeDayConvocations` itself can only tie
  on id, knowing no names, so the panel does that last sort), and it is the reading no slot card can
  give once a person sits on several slots of one day. **Guests form their own trailing group**,
  after the crew and cast cards and under their own heading: they are on the day and are owed an
  hour, but they are not the call the assistant director reads down.

## The alerts

- **`lib/utils/ocpt_schedule_alerts.dart`** (pure, no Flutter, no drift,
  no `Tr`) is what the mode says about a plan before the plan breaks: a sealed `OcptScheduleAlert`
  per kind, each carrying **ids and figures alone** — resolving a name and writing the sentence is
  the panel's job — and a severity that is a property of the *kind* rather than of an occurrence.
  Ten kinds: a person convoked on a day they are unavailable (honouring the day-part window), a
  person on two slots of one day whose bands overlap, and a slot outside every window its location
  declares are **hard**; a role in a placed shot convoked on no slot that day, a role with no actor
  (only among the roles the schedule actually uses), a timeline over-run against a pinned anchor, a
  slot whose fixed end its own blocks over-run, a person's day past the maximum recorded for them, a
  person's rest short of the project's own minimum, and a slot booked at a location whose recorded
  permit does not cover that date are **soft**. `OcptScheduleRestTimeAlert` compares a person's
  departure with their arrival on the **next day they are actually convoked on** — never merely the
  next calendar date, which is why the rule sorts the days by date itself rather than reading the
  caller's own order — and the gap crosses midnights honestly, a night ending at 1620 followed by a
  07:00 call the next date reading as four hours. It is raised on the **second** of the two days,
  the one whose call is too early and the day a production would move.
  `OcptSchedulePermitNotValidAlert` is named for what it says: it never fires on a **missing**
  permit, only on a recorded window that fails to cover the date. Four absences are deliberate and
  each is argued in the file's own doc comment: **a location declaring no window at all raises
  nothing** (absence of data is not a refusal, and a project that never entered availabilities must
  not be drowned — the same argument silences the permit crossing on a location that files none), an
  **anchor cycle** is not an alert (the anchor menu already refuses to close one), a **position lost
  between two slots** is not one either (the positions matrix is where that is read, above), and
  there is **no "key position unfilled" alert** — nothing in this app says which position on a film
  is key, and a list invented for the occasion would read as the app's own opinion rather than the
  production's.
  The maximum a day is measured against is `people.maxDailyPresenceMinutes` (nullable): **null means
  "nobody has recorded one", never "no limit"**, so the alert stays silent rather than advancing a
  legal maximum nobody here validated — which is why the column exists at all instead of a constant.
  It is not restricted to minors (an adult under a medical restriction is the same fact) but sits
  beside `minorNotes` on the person sheet, and is blanked by **both** erasure paths alongside it.
  `project_info.minimumRestMinutes` (nullable) is that same argument at the project's own level —
  the rest a production says it owes between two days — and it is **deliberately not defaulted to
  660**: eleven hours is French law, this app ships in more than one country, and a default would be
  the app advancing a legal figure nobody here validated. It is typed on `OcptProjectSettingsPage`
  **in hours** — the unit a production says a turnaround in, half hours included (`11,5`) — through
  `ocptMinimumRestMinutesOf`, which is what turns it into the minutes the column and every rest
  computation work in, and is **left empty by default**. The field wears its `h` as a `suffixText`
  rather than in its own text, so what a commit reads back is always something it accepts again.
  The alerts live in the `Alerts` **dock tab** rather than above the agenda the mock puts them over:
  a plan is broken whichever view is being read, and the count in the status bar is what says so
  from the other three. Each entry names what it concerns and offers the day it concerns — a
  selection, so the panel writes nothing.
  **Which day is broken is said on the day itself**, by `OcptScheduleDayAlertBadge`: the left dock's
  day cards, the three agenda presentations (compact — the mark alone — in the week header and the
  month cell) and the day view's own summary band all wear it, over `ocptGroupScheduleAlertsByDay`
  (pure, in the alerts file). A day raising nothing draws **nothing at all** rather than a zero, the
  mark is the graver of the two severities among that day's own alerts (one hard alert makes the day
  read as blocked), and it is **read off the alerts, never a second reading of the ten rules** — the
  rule the presence grid already follows. Its tooltip names how many and of which kinds, each kind
  once however often it was raised. Its `onTap` is **nullable and wired in exactly one place**, the
  day view's own summary band, where it opens the `Alerts` dock tab: everywhere else it is left
  null, every one of those surfaces being clickable already — a day card selects its day, an agenda
  cell opens it — and a badge swallowing that tap would make selecting a day depend on hitting a
  16-pixel square. `OcptScheduleRoleUncastAlert` marks no day, carrying none: a role's casting is
  not a fact about any one day of the shoot.

## The paperwork

- The export panel offers the **seven** documents the reference production paperwork is modelled
  on — six PDFs and one workbook —, each through its own options dialog and each offered **under
  a version preview too**, an export only reading.
  `OcptCallSheetPdfService` renders the **general** call sheet and the **named** ones from one
  composition, section for section against the reference `.docx`: recipients, the title block, the
  day's per-slot time bands, its events as their own timed section beside them (a fact about the
  day, in no chain, so never interleaved into the main table), the crew note, the location(s) with a
  map link built from the coordinates alone (**never a network call**), the sun block, the contacts
  by department, the `SEQ / PLANS / EFFET / DÉCORS / RÔLES` table interleaved with the non-shooting
  blocks as full-width milestone rows and a block's own `crewNote` printed under its row, then the
  cast table, the two directories and a trailing `NOM / MOTIF / HORAIRES` guest table. That table
  carries **five columns, not the reference's six**: no field of this app says what happens in a
  sequence, so `RÉSUMÉ` could only ever have printed an em dash on every row. The **cast table lists
  every role the day calls for**, not only the convoked ones: a role a placed shot plays but nobody
  linked to a slot is printed too, with em dashes for its arrival and its PAT band — the `RÔLES`
  column prints role *numbers*, and a reader looking `3` up has nowhere else on the sheet to find
  out who that is. Nothing is guessed from the shot's own hours, so those em dashes say exactly what
  `OcptScheduleRoleNotConvokedAlert` raises in the app; the cast-and-extras directory follows the
  table row for row, the actor nobody called being precisely the one an assistant director has to
  phone. A **hair-and-make-up block additionally names the numbers of the roles its slot convokes**
  (`ocptScheduleBlockRoleNumbersOf`, `ocptScheduleBlockRoleNumbersLine`), on a **line of its own
  under the caption, behind the `RÔLES` label** rather than in brackets after it — forty bracketed
  numbers are unreadable where a labelled line still scans. They are printed whatever the caption
  turned out to be, and come off the slot's cast alone: a chair is a fact about the **unit**, not
  about whichever shot happens to be running. The events, guest and crew-note sections are
  **skipped entirely** on a day that has none rather than drawn over an em dash.
  What a **named** sheet narrows is the **timetable, and only the timetable**: it keeps the day's
  header, prints the rows its recipient's own slots carry — and then the day's own cast table and
  both directories, exactly as the general sheet does, those answering "who else is on this day and
  how do I reach them", which is a question about the day rather than about the reader. **Three**
  sections belong to a named sheet alone: its recipient line, its own arrival/PAT/departure band,
  and its **`À apporter`** table — `elementsToBringOnDay`'s join of the elements whose
  `broughtByPersonId` is that recipient with the scenes `sceneIdsOfDay` says the day actually plays.
  **Both conditions matter and neither alone is enough**: an element somebody brings that no scene
  of the day needs is left off (a call sheet says what to bring *today*), and one a scene needs but
  somebody else brings is exactly as absent, being nobody's own instruction to pack it. It is the
  one section the **general** sheet has no reading for at all, is skipped for an **uncast role**,
  and is why the schedule mode reads the elements catalogue as its sixth read while showing an
  element nowhere on screen.
  Both sheets write **one PDF per file into a folder the user picks**, and the **named** export
  picks its own days exactly as the general one does: its recipient list is the **union** of the
  ticked days' convocations, deduplicated by the person's or the uncast role's own id, and it writes
  one file per **(recipient × day)** — a call sheet being a document about a day, so somebody
  convoked on two of them gets two sheets, while a recipient ticked but convoked on none of a given
  day's slots simply gets no file for that day. Ticking a day carries the tick state over rather
  than resetting it (a recipient still in the union keeps what the user set, a new one arrives
  ticked, one that has left is dropped), and the dialog's own `Export` button is what checks there
  is a recipient at all, where checking on the shell would walk the whole shoot's convocations on
  every rebuild. Two recipients whose names collide each keep a file of their own (`-2`, `-3`), an
  overwrite being somebody never told to turn up. The named sheets **filter guest convocations out**
  of their *recipient* list even though they print a guest table: a guest is somebody the sheet
  tells you about, not somebody a sheet is addressed to.
  `OcptShootingPlanPdfService` prints the whole shoot: three **landscape** summary grids (locations,
  sequences, crew and cast) whose columns are **one per slot grouped under its day** — the
  reference's day-parts being exactly what a slot is here — chunked across pages when a shoot runs
  wide, then one portrait agenda per day with its hours, its events, its sets, its shot tables (each
  **leading with the hours** its block resolves to, the one column the reference has no equivalent
  of, and printing a block's `crewNote` under its row) and its trailing guest table. **What those
  grids hold is not the service's own**: `OcptShootingPlanGrids` (`lib/models/`, **pure Dart, no
  `pdf` and no Flutter**) computes the columns and the four grids' rows, each row's cells
  **resolved** rather than carried as a `valueOf(column)` closure — a closure is a drawing
  convenience, not a model — and the service keeps everything about **paper** alone: the chunking,
  the geometry, the header repetition, the drawing. It exists because those grids have **two**
  readers, the PDF and the workbook below. It takes the handful of words it needs as plain `String`
  parameters rather than a labels class. Its `Description` column is dropped for `RÉSUMÉ`'s reason.
  A **fourth summary grid**, the elements one, crosses **days** rather than slots: an element is
  needed on a day or it is not, and which unit of that day carries it is not something this app
  says. Its rows are the elements at least one scene of the printed range plays (`sceneIdsOfDay` ∩
  `OcptElement.sceneLinks`, `elementsToBringOnDay`'s join widened to everybody), grouped under an
  `OcptElementCategory` band in the enum's own order and **never** by `OcptCrewDepartment` —
  fourteen entries against six, and a mapping between them would be the app's own opinion about how
  a production is organised. A cell is the presence mark, **never a quantity summed across the day's
  scenes**: `scene_elements.quantity` is per link, so the same coat in three scenes is one coat.
  A day may additionally be printed as an optional **ten-minute grid** page, one per day, which
  **adds to** the detailed agenda rather than replacing it: rows every ten minutes, one column per
  slot, a block as a tile spanning the rows it touches with its **exact** times printed inside it,
  and an event as a full-width marker. Every row opens on a **light grey rule the whole width of the
  page**, carried by the row's own decoration and painted *over* the tiles (a `pw.BoxDecoration`
  draws its border in the foreground phase), so a reader following a time across three slot columns
  has something to line their eye up on; it is lighter than every other rule of the document
  precisely so that crossing a multi-row tile never reads as that tile having been cut in two. Its
  whole geometry is `OcptShootingDayAgendaGrid` (`lib/models/`, **pure Dart, no `pdf` and no
  Flutter**), so the hard cases — a 12-minute block on a ten-minute grid, two slots whose chains
  overlap, a night crossing midnight, a band resolving to a **negative** minute because an
  end-anchored slot walked back past its own midnight — are decided and tested with no PDF
  generated, and the service only draws. Its rows are bounded by the **blocks alone**: an event
  outside that band is a marker drawn at the edge it falls beyond, never a reason to stretch the
  rows to it — the week grid on screen scrolls and may stretch, a printed page would pay for it in
  blank rows, which is the one place the two deliberately read differently.
  `OcptShootingPlanXlsxExportService` prints the **same plan as a workbook**, the reference document
  being a spreadsheet the production office reworks and a PDF never being one: the four summary
  grids as four sheets — read off `OcptShootingPlanGrids`, so the two documents cannot draw a
  different grid — plus a fifth, **chronology** sheet the PDF has no equivalent of, one row per
  block over the whole printed range in shooting order. A workbook has no page, so its dialog asks
  the **days and nothing else**: the page format, the title page and the section toggles the PDF's
  own dialog offers all mean something about paper, and a sheet costs nothing and hides in one click.
  `OcptDayOutOfDaysPdfService` prints the **Day Out of Days** — the cast's own schedule, one row per
  role and one column per printed day, landscape and chunked over its own twelve-column budget
  rather than the shooting plan's six (a cell here holds two letters where one there holds a set
  name, so tying the two together would let one document's legibility decide the other's). Every
  code comes from **`ocptComputeDayOutOfDays`** (`lib/utils/ocpt_day_out_of_days.dart`, pure): a
  role's `SW` on its first convoked day of the range, `W` between, `WF` on its last, `H` on a day
  **inside** that span it is not convoked on, and **nothing at all** outside it — a day before a
  part joins the shoot is not a missing value but a day the document deliberately says nothing
  about, which is why that cell prints truly empty rather than `ocptScheduleEmptyValue`. The one
  cell where a span's two ends meet is `SWF`: printing a bare `SW` on a role convoked on a single
  day would say it starts and never finishes. **`T` (travel) and `R` (rehearsal) are not printed**,
  no column of this app saying either, and if a production ever needs them they come back as a
  **typed** fact with a table of their own, never as a code guessed on a computed grid. The service
  decides two things only, both about paper: the rows' order (by role number) and the drawing; the
  "which roles" question is the pure function's, and a role the printed range convokes **nowhere**
  gets no row at all — a blank line would be indistinguishable from a hold-free span. Its cells read
  `convokedRoleIdsOfDay`, which names **roles and never actors**: a *Day Out of Days* is negotiated
  per part, so recasting must not redraw it — and a role being the production's rather than one
  script's (ADR 0019), it draws **one row per part over the whole series**, which is how a cast
  contract is actually negotiated, with no work of its own. The five code letters travel through
  `Tr` like everything else (they read the same in both languages today, which is why the **legend**
  printed under the last chunk is fully localized), and the two trailing counts — days worked, days
  held — are the **whole printed range's**, never the chunk's: a contract is negotiated over the
  shoot, not over whichever days fell on one sheet.
  `OcptOneLineSchedulePdfService` prints the **one-line schedule** (`Plan de travail synthétique`,
  deliberately named apart from the shooting plan's own `Plan de travail` and the *Day Out of Days*'
  `Plan de travail comédiens`) — the compact strip schedule a production plans on: one line per
  sequence, in shooting order, over the whole shoot, landscape and in **one continuous flow**, a day
  band interrupting it between days while the running head and the column widths carry on unbroken.
  It is the one document that reads the whole shoot start to finish rather than comparing day
  against day, which is why it chunks nothing. A line is folded by the very rule the call sheet
  states: a run of consecutive `shot` blocks on **one slot** naming **one scene**. A `hold` is a
  line of its own and never folds — a sequence blocked out ahead of the découpage is still a
  sequence — and **every other block kind gives no line at all**: a meal, a move or a wrap is not a
  sequence. Five columns, `SEQ / EFFET / DÉCOR / RÔLES / DURÉE`, the first four read exactly as the
  call sheet's own table reads them (the same ARB headings, the same `ocptSceneEffectOf`, the same
  slot set, the same `normalizeCharacterName` join) so the two cannot disagree about a line they
  both print; `SEQ` additionally goes through `sceneNumberBySceneId`, since a hold names a sequence
  through no shot code. **No hours column**: this document is read as an *order*, and the clock a
  line falls at is the shooting plan's own day agenda — printing it twice would be the two documents
  disagreeing about which one says when. A **hold prints an em dash under `RÔLES`** rather than a
  guess: nothing in the manager layer says which roles a sequence not yet shot-listed calls for
  (that reading is the breakdown's, which is not among this mode's six reads), and a part invented
  on a printed page is a part somebody plans around. A day whose entries fold down to no line prints
  its band and its own note, never a bare band, and a range naming no live day prints one note page
  rather than an empty file.
  `OcptSidesPdfService` prints the **sides** (`Pages du jour`) — the pages of one day's own
  sequences, stapled and handed round with the call sheet. It is the one schedule document that is
  not a table: it is a **slice of the real screenplay layout**, drawn through the same
  `OcptScriptPagePainter` and composed by the same `FountainScriptComposer` the screenplay PDF and
  the coverage export already use, because a side that re-typeset its text would stop being the very
  page the crew is holding. **`OcptScriptSidesLayout`** (`lib/models/`, pure Dart, no `pdf` and no
  Flutter) is composed **once per episode** the day plays, the booklet chaining the results in
  episode order under each run's own running head, and the bloc's export handler reads every one of
  those screenplays rather than the one — a day regularly plays two episodes, and that is what the
  shared schedule buys. The scene numbers in the margin stay the **screenplay's own, unprefixed**,
  the pages being the script as written. It decides which rows land on which page and is where every
  hard case is tested: a day's scenes are `sceneIdsOfDay` resolved through `sceneSpanBySceneId`, and
  each span is resolved onto
  printed rows by the very bridge rule the coverage layout states — the first and last row whose
  `sourceRange` overlaps it, and **every row between them, anchored or not**, so a scene's blank
  separators, its `(MORE)` and its repeated `NAME (CONT'D)` stay inside the extract rather than
  punching a hole through it. The extract is in **screenplay order, never shooting order**: one
  printed page regularly holds two sequences, so the page-faithful presentation can read no other
  way, and the order a day shoots in is already printed by the call sheet's own table and the
  one-line schedule. Two presentations, and the layout is what makes them two readings of one
  document rather than two documents: `scriptPages` reproduces every screenplay page carrying one of
  the day's rows, the unselected rows blanked **at their true row indices** so the page keeps the
  shape a reader recognises, while `packed` chains the extracts onto fresh pages with one blank
  separator between two runs that were not adjacent (dropped when it would open a page) — and
  **neither a `(MORE)` nor a `(CONT'D)` is ever synthesised** for a speech `packed` happens to cut,
  those two being the composer's own statement about the screenplay's pagination and a page break
  this booklet has already given up. Every page carries its own running head and foot, the painter's
  own page number silenced with `pageNumber: 0`: the head names the day on the left and, on the
  right, the page's identity — the **screenplay's own page number** for a `scriptPages` page, which
  is the whole point of a side, and `n / m` for a `packed` one, the only honest thing it can say.
  Its file name is the one of the six carrying a **day tag** (`My Movie - sides - D3.pdf`): the
  other five are produced once for a whole shoot, a booklet once per day, and two of them saved into
  one folder would otherwise overwrite each other; its dialog picks **one** day out of a dropdown
  for the same reason. A day playing no sequence the screenplay still holds prints one readable note
  page rather than an empty file. It is also the mode's only export that reads the **screenplay**,
  and the bloc reads it in the export handler rather than on load: nothing else the schedule mode
  draws needs the Fountain text, so a seventh read on every load would serve one rarely-run export.
  `ocpt_schedule_pdf_shared.dart` holds what these documents must not read differently: the walk
  that puts a day's parallel slot chains back into a single clock order
  (`ocptOrderedScheduleEntriesOfDay`), a block's caption, the HMC role numbers and the line they
  print as (each document handing in its own already-localized `RÔLES` label), a location's address
  line, a day's **guest rows** (`ocptScheduleGuestRowsOfDay`, taking the fallback name as a plain
  string so this file never learns either document's labels class), the **arrival – departure** band
  (`ocptScheduleArrivalDepartureLabel`), and `ocptScheduleGeneratedAtStamp` — **the moment a
  document was produced**, `yyyy-MM-dd HH:mm`, deliberately carrying the **time** (a call sheet is
  regularly reissued the afternoon of the day it first went out, and two sheets stamped with the
  date alone cannot be told apart in the hand of somebody holding both) and deliberately **not**
  locale-formatted, that stamp being read as an identifier rather than as a sentence. How a shot's
  `<sceneNumber>/<rank>` display code splits lives in `lib/utils/ocpt_shot_code.dart` rather than
  here, a `lib/models/` file that needs it being unable to import the manager layer: `lib/utils/` is
  where a pure rule both layers read belongs. Every service takes a nullable `exportDate` defaulting
  to `DateTime.now()`, resolved **once per document**, and `OcptExportManager` resolves it once per
  **run** for the exports that write a folder of files, a batch that read the clock per file reading
  as several issues of one day's paperwork. **Every page of every one of these documents says what
  it is**: the running head goes through `pw.MultiPage`'s own `header:` rather than a body child (a
  `build:` child is drawn once per flow, not once per page) and every table that can flow marks its
  header row `repeat: true`, so a day agenda torn out of the plan, or a grid's second page pinned on
  a wall, still names its issue and its columns. An elements-grid **category band** is the one
  exception, deliberately not repeated — `repeat` redraws every marked row on every page, so several
  bands would stack into a heading that lies, and an element row already names itself. **Every hour
  on every page is the resolved one** and every convocation figure comes from
  `ocptComputeDayConvocations`; nothing is re-derived and nothing is invented. **No document gains
  an episode column**: the six read their sequence numbers off `OcptSchedulePlanSnapshot` and so
  print `2.12` for free, and a column would say the same thing twice while costing width on grids
  already chunked for want of it.
