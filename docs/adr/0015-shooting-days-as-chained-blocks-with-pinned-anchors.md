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
