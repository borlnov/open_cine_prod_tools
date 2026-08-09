<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0018 - A convocation is the slot you are linked to

## Status

Accepted

## Context

ADR 0017 removed the typed call times and replaced them with one typed figure: a **lead time**, the
minutes a person needs before they are wanted, carried by the convocation row itself or by a
`shooting_day_groups` row it points at. Every clock a call sheet printed was then read off the
slot's chain minus that figure.

Using the mode against the reference documents in `debug/plan/` showed what that figure cannot say.
A lead time says *how long*, never *what for*. Forty-five minutes of prosthetics, twenty minutes of
rigging a set and an hour of driving to the location are three different facts a production plans,
argues about and prints on paper — and the file held all three as the same anonymous integer.

They are also facts with a **duration and a place**. Prosthetics happen in the make-up truck; the
rigging happens on the set being lit; the drive happens on the road. A `shooting_slots` row is
already exactly that: a working unit with a label, a location, a set, a start and a chain of blocks,
drawn by the day view as its own lane. The model was expressing as an offset something it already
had a first-class, placeable, printable way to say — and then needed a second concept,
`shooting_day_groups`, purely to stop that offset being retyped on every row.

The forcing question was where a make-up call belongs on the printed day. On the reference call
sheets it is a line of the timetable with a place and an hour, not a subtraction the reader is
expected to perform.

## Decision

**Nothing is offset from anything.** A person is convoked by being **linked to a slot**, and every
figure about them is read off the slots they are linked to and the blocks inside them. A production
that wants somebody at 06:00 for make-up creates a 06:00 slot, labels it (`HMC`, `Installation`),
gives it the blocks that say how long it runs, and links that person to it.

For a person **P** on a day **D**, over `S(P)` — the live slots of D that P is linked to, by a
`shooting_slot_crew` row (a person) or a `shooting_slot_cast` row (a role), both kinds counting:

| Figure | Definition |
| --- | --- |
| Arrival | the **earliest** `startMinute` over `S(P)` |
| PAT start | the start of the **earliest shooting block** over `S(P)`, or null when there is none |
| PAT end | the end of the **latest shooting block** over `S(P)`, or null when there is none |
| Departure | the **latest** slot end over `S(P)` — that slot's own last block end |

A **shooting block** means `shot` **and** `hold`: a hold reserves the time of a sequence not yet
shot-listed, and a production scheduling a week ahead of its own découpage must still read a PAT
band. `preparation`, `hairMakeUp`, `meal`, `pause`, `travel` and `wrap` are not shooting time and
never open or close a band.

This is implemented exactly once, in `ocptComputeDayConvocations`
(`lib/utils/ocpt_shooting_convocations.dart`), pure, taking a day's slots — each with its own
already-computed `OcptShootingSlotTimeline` (ADR 0015, untouched) and its own linked person and role
ids — and answering one `OcptDayConvocation` per person and per uncast role. Resolving who a role's
actor is stays the caller's job, as it already was.

`shooting_day_groups` and the `leadMinutes`/`groupId` columns on both convocation tables are
**dropped** (schema v13, payload format 8). Nothing is guessed on the way out: a lead time is not
converted into a preparation slot nobody asked for, exactly as the v11→v12 migration dropped the
typed clocks rather than reconstructing them.

**Nothing depends on a block naming the person any more.** `shot_characters`, the roles the
breakdown tagged in a hold's sequence — none of it takes part in a convocation. Whoever is linked to
the slot is convoked by the slot, for the whole of it.

## Consequences

What a user types is now a **cause with a place and a duration** rather than an anonymous number,
and the day view already draws it: a make-up call is a lane on the day, printable as a line of the
call sheet, movable like any other block. Two concepts disappear with the one they existed to
support — no group table, no group band, no inheritance rule, no seeding of a figure from the last
day that convoked somebody.

The cost is that convoking somebody earlier now costs a **slot**, not a number typed in place. A
production that wants one actor in the chair 45 minutes before the rest has to create the slot that
says so and link them to it. That is more clicks for the simple case, and it is the trade accepted:
the resulting file says what is actually happening, and prints.

A convocation can no longer be read from one slot in isolation — it is a fact about a **person on a
day**, joined across every slot they sit on. That is why the day view's slot cards stopped showing
clocks at all (a card cannot answer a question about the day) and why the times moved to their own
right-dock panel, whose scope is the whole day.

The PAT band is **not** clipped to one slot: someone on a morning slot and an evening slot reads one
band running from the morning's first shot to the evening's last, gaps included. The day view's
lanes are where those gaps are read, and a band is deliberately not a claim that the person is
working throughout it.

A slot with **no shooting block gives no PAT at all**. Somebody convoked only on preparation slots
has an arrival and a departure and no band, which is the truthful reading: they are there, they are
not waiting to shoot. A slot carrying no block whatsoever ends at its own `startMinute` — a
convocation with no content yet, not a zero-length error.

## Alternatives considered

- **Keep the lead time and add a reason field beside it**: rejected — a reason with no duration and
  no place still cannot be printed as a line of a timetable, and the app would then hold two ways of
  saying "make-up at 06:00", one of which draws nothing.
- **Keep groups as a convenience, dropping only the per-row lead**: rejected — a group is a shared
  lead time; with no lead time left there is nothing for it to carry, and a "group" that only names
  people is a department, which the resources mode's positions already say better.
- **Derive a preparation slot automatically from each existing lead time on migration**: rejected
  for the reason the v11→v12 migration already gave for typed clocks — a slot invented by the app,
  with a label nobody wrote and a duration nobody checked, is worse than no slot at all, and the
  user is the only one who knows what the forty-five minutes were for.
- **Make the PAT band per slot rather than per day**: rejected — a person reads their own day as one
  arrival and one wrap, and a call sheet prints it that way; per-slot bands would put the same
  person on three lines of the cast table with no way to say which one is their call.
