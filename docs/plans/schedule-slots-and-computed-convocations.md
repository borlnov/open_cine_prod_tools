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

**A cast convocation** (`shooting_slot_cast`), for a role convoked in a slot:

- `patStartMinute` — the start of the first block of that slot the role appears in; failing that,
  the slot's own first block. A role appears in a **shot block** when the shot's
  `shot_characters` name it, and in a **hold block** when the scene that block reserves time for
  names it. No other block kind puts a role anywhere.
- `patEndMinute` — the end of the **last** such block.
- `arrivalMinute` — `patStartMinute − prepMinutes`, the make-up chair. `prepMinutes` is the one
  figure the user types.
- A role convoked in a slot whose blocks never name it keeps the slot's own bounds: someone
  convoked and not used is still convoked, and a production that put them on the sheet said so
  deliberately.

**A crew convocation** (`shooting_slot_crew`), for a person holding a position in a slot:

- `callMinute` — the slot's own first block start, minus that assignment's `leadMinutes`.
- `wrapMinute` — the slot's own last block end, plus that assignment's `wrapMinutes`.
- Both offsets default from the position rather than from zero, so a fresh crew list is already
  roughly right: the catalogue entry in `lib/constants/ocpt_crew_positions.dart` gains a
  `defaultLeadMinutes`/`defaultWrapMinutes` pair (make-up and camera arrive early, catering
  arrives for the meal, the crew wraps after the last shot).

The slot itself then has **no typed times left**: `crewCallMinute` becomes the one clock the whole
day is anchored on — the moment its first crew is called — and `crewWrapMinute`, `castCallMinute`
and `castWrapMinute` are dropped from the table entirely.

### 2.3 What is still typed

| Figure | Where it lives | Why it cannot be derived |
| --- | --- | --- |
| A slot's crew call | `shooting_slots.crewCallMinute` | The one free choice of the day; everything else hangs off it. |
| A role's prep time | `roles.defaultPrepMinutes`, overridden by `shooting_slot_cast.prepMinutes` | Hair, make-up and costume are a fact about a person and a look, not about a timetable. |
| A crew lead/wrap offset | `ocptCrewPositions` defaults, overridden by `shooting_slot_crew.leadMinutes`/`wrapMinutes` | Same: how early a position must be there is a trade fact. |
| Block durations and anchors | `shooting_day_blocks` | Unchanged — this is the schedule itself. |

## 3. Open questions for Benoit

These three shape the schema, so they are answered before any code is written. The plan below
assumes the **first** option of each.

1. **A role's prep time — one figure per film, or one per convocation?** Assumed: a default on
   `roles`, overridable per `shooting_slot_cast` row. A prosthetic that only appears in the last
   week is then one override rather than a column typed on every day.
2. **Is a crew member's lead time enough, or must a position be tied to specific blocks?**
   Assumed: lead time before the slot's own first block. Tying a grip to particular shots would
   need a block ↔ department model this app does not have, and no reference document in
   `debug/plan/` carries one.
3. **May a computed convocation still be overridden by hand?** Assumed: **no** — that is the
   request. But a real call sheet occasionally states a time no rule derives (an actor's train).
   The fallback, if that turns out to bite, is a nullable `overrideMinute` per row that the UI
   shows as a struck-through computed value; it is deliberately **not** in the schema below.

## 4. Milestones

### M1' — the data model and the rules (no UI)

1. **Schema v12.** `shooting_day_blocks.slotId` non-null; `shooting_slots` loses
   `crewWrapMinute`, `castCallMinute`, `castWrapMinute`; `shooting_slot_cast` loses
   `castCallMinute`/`castWrapMinute` and gains `prepMinutes`; `shooting_slot_crew` swaps its
   `callMinute`/`wrapMinute` for `leadMinutes`/`wrapMinutes`; `roles` gains
   `defaultPrepMinutes`. The migration assigns every orphan block to its day's first live slot,
   and **deletes a block whose day has no slot at all** (impossible through the UI, since
   `createDay` mints a slot, but a restored payload could carry one). The parity test pins
   `onCreate` against every upgrade path, as ADR 0007 requires.
2. **`ocpt_shooting_convocations.dart`**, pure, with ADR 0017 — every rule of §2.2, tested against
   a night slot crossing midnight and against a role convoked but never used.
3. **`ocpt_shooting_day_timeline.dart`** amended per §2.1, with its ADR, and its tests rewritten
   around one slot rather than one day.
4. **`OcptScheduleService`**: `createBlock`/`placeShot` take a slot id; `moveBlockToSlot` replaces
   `moveBlockToDay`; `duplicateDay` unchanged in intent; every write of a dropped column removed.
5. **Payload format 7**, upgrading a format-6 payload by moving each block onto its day's first
   slot and materialising the new columns at their defaults — and the codec, `contentDigest` and
   `_applyPayload` all three, as `CLAUDE.md` warns.

### M2' — the day view

6. Each slot card carries **its own timetable**, below its crew and cast columns. The day's single
   timetable disappears.
7. A block moves between slots by **dragging it from one card's timetable to another's**, and by a
   `Move to…` entry in its own row for the keyboard path. Reordering within a slot is unchanged.
8. Crew and cast rows show their **computed** times as read-outs, with the typed figure (prep,
   lead, wrap) as the editable field beside them — the minute fields those rows carry today are
   removed, not disabled.
9. The week and month agendas draw a day's slots as parallel columns within its own column, since
   two chains can now overlap.

### M3' — the rest

10. `docs/plans/schedule-mode.md`'s M2 (the three PDFs) and M3 (the matrix, the presence grid and
    the alerts), unchanged in scope but now reading computed convocations rather than typed ones.

## 5. Definition of done

`flutter analyze` clean, `flutter test` green, `reuse lint` compliant, the Linux build passing, and
the migration parity test green. A project created under schema v11 opens under v12 with every
block attached to a slot and every convocation computed; a version captured before this plan
restores with its blocks on their day's first slot rather than nowhere. The day view shows no
typed call time anywhere, and moving a block from the morning slot to the evening one moves every
convocation that depended on it.
