<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Schedule mode — per-slot timetables and computed convocations

This document is the implementation strategy for two reworks of the schedule mode that M1 got
wrong, both raised by Benoit after using it. It is written for the Sonnet 5 agents that will build
it, orchestrated and reviewed by the main session. **Read the repository `CLAUDE.md` first** — this
plan assumes its architecture, ways of working, coding standards, licensing rules and verification
gates, and does not repeat them.

It supersedes nothing in `docs/plans/schedule-mode.md`: M2 (the three PDFs) and M3 (the grids and
the alerts) still describe work to do, and both are **downstream of this one** — a call sheet
prints exactly the convocation times this plan changes the origin of, so building it first would
mean printing the wrong column twice.

---

## 1. What is wrong today

M1 shipped a schedule where a shooting day has slots *and*, separately, one timetable. Two
consequences fall out of that, and both are wrong about how a shoot works.

**A day has one timetable, shared by every slot.** `shooting_day_blocks.slotId` is nullable and
mostly null; the chain runs through the whole day, and rule 5 of ADR 0015 exists solely to stop a
second crew's blocks from starting before that crew was called. But a slot **is** a working unit
with its own crew, its own place and its own hours — two units regularly work the same day at two
locations, sometimes at the same time. A single chain cannot express that: it serialises what is
parallel, and the moment two slots overlap the day view draws a sequence that never happened.

**Convocation times are typed by hand.** `shooting_slots.crewCallMinute`, its PAT band, and every
per-row override on `shooting_slot_crew` and `shooting_slot_cast` are all values a user enters.
That is backwards: those times are *consequences* of the timetable. The first shot of the day
starts at 09:00, so the actor in it is ready at 09:00, so — with 45 minutes of make-up — they
arrive at 08:15, and the make-up artist arrives before that. Typing all three means retyping all
three every time a block moves, which is exactly the rework M1 set out to make cheap.

## 2. What replaces it

**A slot owns its own timetable.** `slotId` becomes required; every block belongs to exactly one
slot; each slot's blocks chain from that slot's own crew call. A day is then a set of parallel
chains rather than one, which is what a call sheet with two units already looks like on paper.

**A convocation is computed, and what a user edits is its cause.** Nobody types a call time. They
type a make-up duration and a lead time; the app derives the clock.

### 2.1 Consequences for ADR 0015

The chain rule gets **simpler**, not more complex, and ADR 0015 is amended rather than replaced:

- Rule 5 (a slot's call pulling the chain forward) **disappears**. It only ever existed to patch
  the single-chain model. A slot's chain starts at its own `crewCallMinute` by construction, so
  `OcptShootingTimelineBlock.slotCallMinute` is dropped from the input record.
- Rules 1-4 are untouched: durations chain, an anchor pins, an anchor the chain has run past is
  reported as an `OcptTimelineOverrun` rather than silently pushed.
- `ocptComputeShootingDayTimeline` is renamed `ocptComputeSlotTimeline` and takes one slot's
  blocks. **A day's** timeline becomes a map of slot id → timeline, computed by a thin
  `ocptComputeShootingDayTimelines` over the day's slots, whose `dayEndMinute` is the **maximum**
  over its slots (null when every slot is empty) — a day ends when its last unit wraps.

The two slots of a day may now overlap in wall-clock time, and **that is legal, not a conflict to
report**: two units shooting at once is the ordinary reason a production splits a day into slots at
all. Detecting that one *person* is in two places at once is a different question, and it belongs
to M3's alert list — the data this plan produces is exactly what makes it answerable.

### 2.2 The convocation rules

Stated once here, implemented once in a new pure `lib/utils/ocpt_shooting_convocations.dart`, and
recorded as **ADR 0017**. Every figure below is a minute from the day's own midnight and may exceed
1440, like every other minute in this mode.

**A slot has one typed clock**, and it is the only one left: `startMinute` (the renamed
`crewCallMinute`), the moment its first block begins. Everything below hangs off that and off the
block chain it starts.

**A lead time** is the one figure a user types beside a person. It is carried either by a **group**
the convocation belongs to (`shooting_day_groups.leadMinutes`) or by the convocation itself, whose
own figure wins when it is set. Both readings of it are "minutes before the moment this person is
needed" — the moment differs by kind, below.

**A crew convocation** (`shooting_slot_crew`), for a person holding a position in a slot:

- `callMinute` — the slot's own **first block start**, minus that assignment's lead.
- `wrapMinute` — the slot's own **last block end**, full stop. There is no after-offset anywhere in
  this model: wanting to finish later is stated as a `wrap` block in the chain, which is what that
  block kind is for, and which then moves everybody's wrap at once rather than one row's.

**A cast convocation** (`shooting_slot_cast`), for a role convoked in a slot:

- `patStartMinute` — the start of the **first block of that slot the role appears in**. A role
  appears in a **shot block** when the shot's `shot_characters` name it, and in a **hold block**
  when the scene that block reserves time for names it. No other block kind puts a role anywhere.
- `patEndMinute` — the end of the **last** such block.
- `arrivalMinute` — `patStartMinute` minus that convocation's lead: the make-up chair, which is why
  it is per role and per day rather than per film. A lead of zero means arriving ready.
- A role convoked in a slot whose blocks never name it keeps the slot's own bounds: someone
  convoked and not used is still convoked, and a production that put them on the sheet said so
  deliberately.

### 2.3 Groups

A **group** (`shooting_day_groups`) is a named lead time a day carries, and any convocation of that
day may point at it — a crew row and a cast row alike, since "figurants" is a bag of `extra` roles
and "équipe technique" a bag of people, and both are the same idea. It is deliberately **not** the
crew department: a department says which trade someone practises, a group says who walks in at the
same time, and the two only coincide by accident.

Groups belong to the **day** because the lead time does: the same crew called at 06:00 on a January
exterior is called at 09:00 in a studio. A day created after another **inherits the previous day's
groups**, labels and figures alike (the previous day being the last one in the plan's own order,
which is where `createDay` appends). Nothing else is inherited — copying the crew and the cast
themselves is what `duplicateDay` is for, and it keeps doing exactly that.

An **individual** figure is inherited too, but at a different moment and by a different rule:
adding a person or a role to a slot seeds that convocation's own lead, and its group, from that
same person-and-position (or that same role) on the **most recent day they were convoked**, matching
the group by label since group ids are per day. Without it, "ANNA needs 90 minutes of prosthetics"
would be retyped on every one of her days, which is exactly what answering "from the previous day"
was meant to avoid. **This is a derivation from that answer rather than something stated**, and it
is the one rule here worth a second look before it is built.

### 2.4 What is still typed

| Figure | Where it lives | Why it cannot be derived |
| --- | --- | --- |
| A slot's start | `shooting_slots.startMinute` | The one free clock of a slot; the whole chain hangs off it. |
| A group's lead time | `shooting_day_groups.leadMinutes` | How early a band of people must be there, on **this** day. |
| One person's own lead | `shooting_slot_crew.leadMinutes`, `shooting_slot_cast.leadMinutes` | Hair, make-up and costume are a fact about a person and a look. Overrides the group's. |
| Block durations and anchors | `shooting_day_blocks` | Unchanged — this is the schedule itself. |

Everything else a call sheet prints is computed, and **nothing computed can be overridden by hand**:
arriving earlier or finishing later is stated as a lead time or as a block, never as a typed clock
contradicting the plan. That is the whole point of the rework — a typed time is a claim nothing
keeps true once a block moves.

## 3. Decisions taken

Benoit answered the three questions this plan was blocked on.

1. **A lead time is a fact about a day**, not about the film: the same crew is called at a different
   hour on an exterior in January and in a studio. It is therefore stored per day, and a new day
   inherits the previous one's — no per-film default column anywhere.
2. **A group is a bag of convoked people**, crew and cast alike, living on the day (§2.3). A crew
   member's lead is shared by the band they walk in with; an actor's is their own, because it is
   their make-up.
3. **Nothing computed is overridable.** Arriving earlier or finishing later is justified by a lead
   time or by a block — never by a typed clock. `wrap`, `preparation` and `hairMakeUp` already
   exist as block kinds, so the vocabulary for saying it is already there.

One thing is a **derivation rather than an answer**, flagged in §2.3 and worth confirming before it
is built: an individual lead is seeded from that person's or role's most recent convocation, so a
90-minute prosthetic is typed once rather than on each of that actor's days.

## 4. Milestones

### M1' — the data model and the rules (no UI) — **shipped**

Everything below is built and merged into the branch: schema v12, the two pure utils and their
ADRs (0015 amended, 0017), the service, payload format 7, and the mode reading its convocation
times out rather than asking for them. The code and those two ADRs are the record from here on —
the list is kept only until this plan's own remaining milestones ship with it.

1. **Schema v12.**
   - `shooting_day_blocks.slotId` becomes non-null, and a nullable `sceneId` is added beside it:
     the sequence a `hold` reserves time for, which is what says who that block convokes (§2.2) —
     its free-text label never could.
   - `shooting_slots`: `crewCallMinute` is renamed `startMinute`; `crewWrapMinute`,
     `castCallMinute` and `castWrapMinute` are dropped.
   - **`shooting_day_groups`** is added — `id`, `shootingDayId`, `sortKey`, `label`,
     `leadMinutes`, `isDeleted` — synchronised like every other table (ADR 0010).
   - `shooting_slot_crew`: `callMinute`/`wrapMinute` give way to a nullable `groupId` and a
     nullable `leadMinutes`.
   - `shooting_slot_cast`: `arrivalMinute`, `castCallMinute` and `castWrapMinute` give way to the
     same nullable `groupId`/`leadMinutes` pair — all three were computable from the chain.
   - The migration assigns every orphan block to its day's first live slot, and **deletes a block
     whose day has no slot at all** (impossible through the UI, since `createDay` mints a slot, but
     a restored payload could carry one). Nothing tries to reconstruct a lead time out of the
     dropped clocks: a figure guessed from a timetable that has since moved would be worse than the
     zero every row starts at. The parity test pins `onCreate` against every upgrade path, as
     ADR 0007 requires.
2. **`ocpt_shooting_convocations.dart`**, pure, with ADR 0017 — every rule of §2.2, tested against
   a night slot crossing midnight, a role convoked but never used, and a group whose figure a row
   overrides.
3. **`ocpt_shooting_day_timeline.dart`** amended per §2.1, with its ADR, and its tests rewritten
   around one slot rather than one day.
4. **`OcptScheduleService`**: `createBlock`/`placeShot` take a slot id; `moveBlockToSlot` replaces
   `moveBlockToDay`; `createDay` copies the previous day's groups; `addSlotCrewMember` and
   `addSlotCastRole` seed the lead and the group from that person's or role's most recent
   convocation (§2.3); `duplicateDay` also copies the groups, and keeps copying the crew and the
   cast as it already does; every write of a dropped column is removed.
5. **Payload format 7**, carrying `shooting_day_groups` and upgrading a format-6 payload by moving
   each block onto its day's first slot, materialising the group table as an empty list and every
   new column at its default — the codec, `contentDigest` and `_applyPayload` all three, as
   `CLAUDE.md` warns.

### M2' — the day view — **shipped**

Everything below is built and merged into the branch. The code is the record from here on, and this
list is kept only until M3' ships with it — at which point this whole plan goes, its two ADRs and
`docs/plans/schedule-mode.md` being what remains.

One thing shipped with it that no item below asked for, on Benoit's reading of the built day view:
**the one-placement-per-shot rule is gone**. A shot is placed from the slot it is shot in — the
timetable's own `+ Block` menu opens on `Shot` and a picker dialog over the whole shot list — and it
may be placed as many times as the plan needs, a shot resumed after the meal break being two blocks
rather than one. The left dock's click on a shot is now a plain selection the inspector reads out,
and the strip agenda is informative: nothing is placed or unplaced from it.

A second reading pass over the built day view shipped with it too, and none of it is asked for
below either. A **crew member has a PAT band** like an actor does, the two convocation shapes now
naming the same three figures (ADR 0017's own Amendment). A **`pause` block** joins the milestone
kinds. The shooting days are **ranked by date** rather than by hand, `J1`/`J2` being a chronological
label a `Change the date…` action renumbers, and the letter itself is **localized** (`D3`/`J3`). A
crew row is a **card** built like a cast one, both wrapping inside a half-width column the crew side
can **fold**. The groups band says `People groups` and carries an `ⓘ` explaining what a group is
for. The `±` duration controls **snap to five minutes**, the exact figure being typed in the
inspector instead. And a day's band is read **arrival → end** — the earliest minute anybody has to
be there — rather than opening on the first slot's start, which the strip card had never managed to
print at all.

6. A `hold` block's own **sequence picker**, writing the `shooting_day_blocks.sceneId` schema v12
   already carries, and the roles that sequence calls for read out of the breakdown — until both
   land, a hold names nobody and every role convoked beside it keeps the slot's own bounds.
7. Each slot card carries **its own timetable**, below its crew and cast columns. The day's single
   timetable disappears.
8. A block moves between slots by **dragging it from one card's timetable to another's**, and by a
   `Move to…` entry in its own row for the keyboard path. Reordering within a slot is unchanged.
9. Crew and cast rows show their computed times as read-outs — which they already do — beside the
   lead time as the one **editable** field, and a group picked from the day's own groups; a row with
   no figure of its own reads its group's, shown as inherited rather than blank.
10. The day view grows a **groups band**, above the slots: the day's groups, their labels and their
    lead times, with the count of who is in each. It is the one place a group is created, renamed or
    deleted, and deleting one leaves its members with no group rather than removing them.
11. The week and month agendas draw a day's slots as parallel columns within its own column, since
    two chains can now overlap.

### M3' — the rest

12. `docs/plans/schedule-mode.md`'s M2 (the three PDFs) and M3 (the matrix, the presence grid and
    the alerts), unchanged in scope but now reading computed convocations rather than typed ones.

## 5. Definition of done

`flutter analyze` clean, `flutter test` green, `reuse lint` compliant, the Linux build passing, and
the migration parity test green. A project created under schema v11 opens under v12 with every
block attached to a slot and every convocation computed; a version captured before this plan
restores with its blocks on their day's first slot rather than nowhere. The day view shows no
typed call time anywhere, and moving a block from the morning slot to the evening one moves every
convocation that depended on it. Creating a day after another brings its groups across, and
convoking an actor already convoked earlier brings their own lead time with them.
