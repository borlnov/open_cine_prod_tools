<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0015 - Shooting days as chained blocks with pinned anchors

## Status

Accepted

## Context

The schedule mode's day view is a shooting day's timetable: preparation, hair and make-up, shots,
meals, moves and wrap, laid out one after another with a computed clock time on each. Two facts
about a real shoot shaped how that timetable is stored and computed.

- **The plan changes constantly, including during the shoot.** An actor drops out, a location is
  lost the evening before, a scene overruns by two hours. Reworking a day has to take seconds: a
  five-minute change to one shot's duration is expected to move everything after it, not to be
  typed by hand into every block that follows.
- **A handful of moments genuinely are fixed.** A meal break has a legal minimum start, an actor's
  flight leaves at a named time, a location is only available until dusk. These are not "usually
  around 13:00" — they are pinned to the minute, and the rest of the day has to bend around them,
  not the other way round.

Two shapes were on the table for `shooting_day_blocks`: a typed clock time on every row (what the
reference `.docx` planning documents actually show, since a human typed each one by hand), or a
chain of durations computed from the day's crew call, with an escape hatch for the moments that
really are fixed.

## Decision

A shooting day is a **chain of blocks**, in `sortKey` order, each carrying a `durationMinutes`
(nullable — a shot block with none falls back to the shot's own estimate, then to the mode's
default) and an optional `anchorMinute`. The chain is computed by one pure function,
`ocptComputeSlotTimeline` (`lib/utils/ocpt_shooting_day_timeline.dart`), implementing the
rule stated once in `docs/plans/schedule-mode.md` §5:

1. The chain starts at the slot's own `startMinute`.
2. Each block starts where the previous one ended and lasts its own duration.
3. A block carrying an `anchorMinute` starts **exactly** there, unconditionally; the chain resumes
   from its end.
4. When the chain's position was already later than an anchor, that is an **over-run**: reported
   in the result rather than silently absorbed by pushing the anchor later.

No clock time is stored anywhere except `shooting_slots.startMinute` and a block's own
`anchorMinute`. Every other time shown in the UI — a block's start, its end, an actor's computed
PAT band, "estimated wrap" — is read out of this one function's result, never stored.

## Consequences

Changing a shot's duration, inserting a block, or reordering the day rewrites exactly the rows the
plan `sortKey`-order change touches (ADR 0010's fractional indexing already made a reorder a
one-row write); the computed times downstream simply follow, because nothing computed is stored.
This is the entire point: a day can be reworked on set, between takes, without a single clock-time
field to retype.

The cost is that nothing about a day's timetable can be read from one row in isolation — a block's
start is only meaningful in the context of every block before it, so any place that shows a time
(the day view, a call sheet, the shot list's read-out of `J3`) has to run the whole chain first.
The function is cheap (a day holds at most a few dozen blocks) and pure, so this is a non-issue in
practice, but it does mean there is no `shooting_day_blocks.startMinute` column to write a quick
report query against — a report needs the function, not the table.

An over-run is a **diagnostic on the block whose anchor could not be honoured**, not a claim about
the whole slot: rule 3 still pins that block to its anchor exactly, which can pull the chain
backward and make the blocks after it finish *earlier* than an unconstrained sum of durations
would. The flag says "this block's own anchor conflicted with what came before it", nothing more —
a reader has to keep that scope in mind rather than reading an over-run as "the slot ran long by
this much".

The function takes plain value types of its own (`OcptShootingTimelineBlock`) rather than drift
rows or the schedule mode's enums, so it stays reachable from a plain, dependency-free unit test —
the same discipline `ocpt_fractional_key.dart` and `OcptScenarioCoverageLayout` already follow. The
schedule mode's own service is what resolves a `shooting_day_blocks` row (and, for a shot block,
its `shots` row) into one of these before calling it.

## Alternatives considered

- **A typed clock time on every block**, as the reference `.docx` shows: what a human typed once
  and never touched again. Rejected because every one of the "plan changes constantly" cases above
  becomes a cascade of manual retyping — the exact cost this mode exists to remove — and because a
  typed time and a computed duration can silently disagree, with nothing to say which one is true.
- **Storing both** a duration and a computed/cached clock time, refreshed on write: keeps a fast
  read path, but now two representations of the same fact can drift out of sync the moment a write
  is missed (a bulk edit, a sync merge, a version restore), and ADR 0010's row-level stamping has
  nothing to say about which of the two a conflicting edit should win on.
- **Silently pushing an anchor later** when the chain runs into it, so the day always "just works":
  rejected explicitly by rule 4. A schedule that quietly moves a legally-mandated meal break to
  keep the numbers tidy is worse than one that says, in red, that the plan no longer fits — the
  person reading it can then actually fix the real problem instead of trusting a lie.

## Amendment — one chain per slot

The decision above is amended: a day no
longer runs **one** chain shared by every slot, it runs **one chain per slot**, each starting at
that slot's own `startMinute` (the renamed `crewCallMinute`).

- **Rule 5 is dropped.** It read: "a block whose slot calls its crew later than the chain's current
  position pulls the chain forward to meet them, rather than starting a second crew mid-morning
  because an earlier one finished early." It existed only to patch the single-chain model, where a
  second slot's blocks were interleaved into the same sequence as the first's; now that every slot
  chains on its own, from its own start, there is nothing left for it to patch.
- `ocptComputeShootingDayTimeline` is renamed `ocptComputeSlotTimeline` and takes one slot's
  `blocks` and that slot's own `slotStartMinute` (**non-null** — a slot's `startMinute` is a
  required column from schema v12 on, so the old "no first crew call to start from" caller error
  disappears with it). Its result type is renamed `OcptShootingSlotTimeline`, and its
  `dayEndMinute` field is renamed `endMinute` — a fact about one slot, not one day.
- A day's own timetable is the new, thin `ocptComputeShootingDayTimelines`, a loop over
  `ocptComputeSlotTimeline` that joins every slot's own `OcptShootingSlotTimeline` into one
  `OcptShootingDayTimelines` — a map of slot id → timeline, the two per-entry lists flattened for a
  reader that doesn't care which slot produced a block, and a `dayEndMinute` that is the
  **maximum** over every slot's own `endMinute` (null when every slot is empty): a day ends when
  its last unit wraps.
- **Two slots of a day may now overlap in wall-clock time, and that is legal, not a conflict this
  layer reports.** A production splits a day into slots precisely so two units can shoot at once;
  serialising them into one chain, as before this amendment, drew a sequence that never happened
  whenever they did. Whether one *person* ends up convoked in both at the same moment is a
  different question — M3's presence alerts, not this one.

Rules 1-4 above, and everything this record's Consequences and Alternatives sections say about
them, are otherwise unchanged: only their scope narrows from "the day" to "the slot". See ADR 0017
for the convocation rules this amendment enables — a slot's own computed call, wrap and PAT times,
built on top of its own `OcptShootingSlotTimeline`.

## Second amendment — a slot is anchored by either edge

The decision above is amended again: a slot no longer owns a typed `startMinute`, it owns **one
anchored edge**, and the hour that edge sits at may itself be read off another slot of the same day.
`shooting_slots.startMinute` becomes `anchorEdge` (`start` or `end`), `anchorMinute` (the typed
hour) and `anchorSlotId` (the slot whose **opposite** edge is read) — exactly one of the last two
non-null, the discriminator idiom ADR 0014 already uses. Schema version 14 and payload format 9 are
the file's half of it, and both carry every existing slot across as `start`-anchored at the hour it
already had.

A production books a studio until 22:00, or plans backwards from a sunset. Saying either meant doing
the subtraction by hand and redoing it every time a block moved — the exact cost this record exists
to remove, left standing on the one edge it never questioned.

`ocptComputeSlotTimeline` is **untouched**: it still chains forward from a start it is handed, which
is why the amendment is made *around* it, in `ocptComputeShootingDayTimelines`.

1. **Resolution order is dependency order**, not the order the slots are given in: a slot's start
   may depend on another slot's end, which depends on that slot's whole chain. A day where nothing
   is linked resolves exactly as it did before.
2. **A `start`-anchored slot** chains from its resolved hour, as always.
3. **An `end`-anchored slot** starts at `resolvedHour − Σ(resolved durations of its blocks)` and
   then chains forward, unchanged. Adding a block pulls its start earlier and leaves its end where
   it is, which is what pinning an end is for.
4. **A pinned block inside an `end`-anchored slot still obeys rule 3** — it starts exactly at its
   own anchor — so the slot may finish somewhere other than its fixed end. That is an
   `OcptTimelineFixedEndMiss` on the result, **reported, never absorbed**: the same refusal rule 4
   already makes for an over-run. The fixed end wins; nothing is stretched or squeezed to make the
   plan look like it fits.
5. **A source slot with no block at all has no end**, and its end is read as equal to its own
   resolved start — the `endMinute ?? startMinute` convention ADR 0018 already applies to a
   departure.
6. **A circle of anchors** is reported as an `OcptTimelineAnchorCycle` and its slots are resolved as
   if `start`-anchored at the earliest start already resolved for the day (minute 0 when the whole
   day cycles). This is defence, not a state a user can reach: the anchor menu greys out an entry
   that would close one (`ocptSlotAnchorWouldCycle`) and `OcptScheduleService.setSlotAnchor` refuses
   to write one. A pure function that can be handed a database row must not hang on it.

A link only ever joins **two slots of the same day** — a night crossing midnight is already carried
by the day it starts on, in minutes past 1440 — and never two edges of the same side: "these two
start together" is said by typing the same hour twice, not by a link that would have no direction.

`OcptShootingSlotTimeline` gains a non-null `startMinute`, and it is what every reader of "the hour
of this slot" now reads: the three agendas, the day inspector, the convocations and the slot card
alike. `OcptShootingDayTimelines` gains `dayStartMinute` (the minimum over them, and therefore the
day's own earliest arrival, ADR 0018 having removed everything that could pull somebody in ahead of
their slot), `fixedEndMisses` and `anchorCycles`.

Two service rules follow from links existing at all. `duplicateDay` **remaps them onto the copies**:
a copy pointing back at the original day's slot would be a cross-day link, which nothing allows.
`deleteSlot` **freezes its dependents**: each slot reading the deleted one's edge keeps the hour it
was reading, as a typed anchor on its own edge — the same rule unlinking by hand follows, so a
deletion never silently moves a day.

Rules 1-4 of the original decision, and everything its Consequences and Alternatives sections say,
are otherwise unchanged.
