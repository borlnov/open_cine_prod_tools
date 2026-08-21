<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0024 - What a day is for is what it holds

## Status

Accepted

## Context

The schedule mode could only put a **shot** in a block. The weeks of auditions and rehearsals a
production runs before its first shooting day are planned exactly like shooting days — a date, a
place, people convoked, a running order — and the mode already had every one of those pieces. What
it lacked was something other than a shot to put in the running order.

Two shapes were available for that, and they are not interchangeable.

The first is a **kind on the day**: `shooting_days.kind`, a `Nature` picker, one numbering series per
kind, the exports scoped to the shooting days. It reads well until a real day is described. A day
auditions in the morning and rehearses in the afternoon. A rehearsal regularly falls on the morning
of the day it is shot. A production that auditions until noon and shoots from two o'clock is one
day, one crew, one piece of paper — and a column that has to name it once can only be wrong.

The second question is who an audition convokes. An audition block naming the **part** it sees, with
the people convoked on the slot beside it, is the shape ADR 0018 suggests by default: everything
else in this app is convoked by a slot. It was built, and printed a casting day where twelve
candidates were all convoked 09:00 – 18:00 — which is exactly the hour a casting day exists to
state. It also could not describe the ordinary exercise of reading **two actors of two different
parts together**, the block having one `roleId` to name a part with.

The third fault only reading the printed sheets showed. `audition` and `rehearsal` were made
shooting time — right, for computing a band — and nobody then asked what that band should be
**called**. `PAT` (*prêt à tourner*) is the hour a performer must be costumed, made up and on set,
ready for a take: it presupposes a take, and a casting day has none.

## Decision

**A day is never given a kind. What a day is for is said by the blocks it holds, and by nothing
else.** `OcptShootingBlockKind` gains `audition` and `rehearsal`, offered on every day like every
other kind, and the paperwork adapts to what it finds rather than to a label somebody picked. A
`rehearsal` names a **sequence** through the existing `shooting_day_blocks.sceneId`, exactly as
`hold` does, and needs no column of its own.

**An audition block names the candidacies it sees** — somebody, for a part — through
`shooting_block_candidates` (`blockId` → `role_candidates`), and may name several: two actors of two
different parts read together are one block carrying two rows, while four people seen twenty minutes
each are four blocks of one row apiece. The block carries **no `roleId`**: a candidacy already says
which part it is for, and two columns saying the part is one column too many — the one that can be
wrong.

**That link is the one convocation in this app read off a block rather than off a slot.** It is ADR
0018 applied rather than bent: you are convoked by what you are linked to, and your clocks come from
it. A candidate is expected at twenty past ten, for twenty minutes, so that block — not the unit's
whole day — is what their arrival, their band and their departure are read off.
`ocptComputeDayConvocations` takes the day's auditions beside its slots, and a person's auditions
**join the same walk** as their slots rather than making a convocation of their own: a person
arrives once and leaves once, whatever brings them in. `OcptDayConvocation` therefore has no
candidate arm; it carries `roleCandidateIds`, the candidacies of this person the day sees, empty for
everybody else.

**A band is called `PAT` only over filming.** `OcptShootingBlockKind.isFilming` (`shot` and `hold`)
is a separate question from `isShootingTime` (those two plus `audition` and `rehearsal`), and the
label follows the band **per convocation**: `PAT` when the blocks it was read off include filming,
`PRÉSENCE` otherwise. A day that auditions in the morning and shoots in the afternoon prints `PAT`
for its cast and `PRÉSENCE` for its candidates, on the one sheet.

**One call sheet composition reads the day's own blocks.** A day carrying auditions prints an
`HORAIRES / RÔLE / CANDIDAT` table beside — never instead of — the `SEQ / PLANS / EFFET / DÉCORS /
RÔLES` one, and its convoked candidates are listed under the cast table with their contact. A named
sheet narrows the timetable to the blocks its recipient is actually in, and its audition table to
their own candidacies alone: who else is being seen for a part is the production's business, not
another candidate's.

**Three things were built on this branch and taken back out**, and this record is where that is
kept. `shooting_days.kind`, its three numbering series, its `Nature` picker, its agenda tint and its
shoot-only export scoping went for the reason above. `shooting_slot_candidates` — a candidate
convoked on the whole slot — went because a slot-wide convocation says "some time today", which is
the hour this whole exercise exists to stop printing. `shooting_day_blocks.roleId` went with it. No
released build ever wrote any of them, so schema v23 and v24 **drop them defensively**
(`_dropColumnIfPresent`, `_dropTableIfPresent`) rather than migrating anything, and payload formats
19 and 20 strip their keys without reconstructing a thing.

## Consequences

A production plans its casting and its rehearsals in the mode it already plans its shoot in, with
the same slots, the same anchors, the same alerts and the same paperwork. Twelve candidates at
twenty-minute intervals cost **twelve blocks inside one slot**, not twelve slots: one running order,
twelve hours, twelve convocations, and the day still reads as the single unit it is.

The cost is that "what does this day do" is never a column and can only be answered by walking its
blocks. Every reader that wants that answer — the call sheet's two tables, the audition table's own
existence, the band's label — pays a walk for it, and a future reader must resist adding the column
back as a cache.

**No alert knows any of this exists, deliberately.** Every rule about people fires as it always did
— a rehearsal the day before a 07:00 call eats the same turnaround — and there is no "a candidate
nobody has given an hour to" alert, which would be an opinion about how a production runs its
auditions. The presence grid counts such a day as `working`, somebody at a rehearsal being there.

A `shooting_block_candidates` row whose candidacy has since been removed is **read defensively and
drops out**, no cascade written for it — the treatment `shooting_slot_cast` already gets for a role
deleted under it. The link carries no `personId`, so it joins no erasure implementation;
`role_candidates` stays the row an erasure blanks.

## Alternatives considered

- **A kind on the day** (built, then removed): rejected — a real day mixes casting, rehearsal and
  shooting, and a column naming it once can only be wrong about the mixed day, which is the common
  one.
- **An audition block naming a role, the people convoked on the slot** (built, then removed):
  rejected — it convoked twelve candidates 09:00 – 18:00 and could not read two parts together.
- **A candidate as a fifth arm of `OcptDayConvocation`'s discriminator** (built, then removed):
  rejected — it handed two call sheets to somebody both crewing the day and seen for a part, and two
  more to somebody seen for two parts. A person arrives once and leaves once.
- **A second call sheet service for casting days**: rejected — one day, one piece of paper; a day
  holding both an audition and a shot would have had to be printed by both services.
- **Calling the band `PAT` everywhere and explaining it in a legend**: rejected — no convention of
  the trade stretches *prêt à tourner* to mean "on site", and a legend does not stop an assistant
  director reading the column the way the trade reads it.
- **Deriving `role_candidates.auditionedOn` from the audition block that sees them**: rejected — a
  candidate seen over a self-tape, or before the app was opened, has a date and no session, and a
  derived date would go empty the day the session is deleted.
