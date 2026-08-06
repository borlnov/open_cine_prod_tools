<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0017 - Convocations computed from the slot chain

## Status

Accepted

## Context

M1 of the schedule mode stored a convocation's clock times by hand: `shooting_slots` carried a
`crewCallMinute`, a `crewWrapMinute` and a PAT band, and every row of `shooting_slot_crew` and
`shooting_slot_cast` could override them again. That is backwards. Those times are *consequences*
of the day's own timetable, not facts a user holds independently of it: the first shot of the day
starts at 09:00, so the actor in it is ready at 09:00, so — with 45 minutes of make-up — they arrive
at 08:15, and the make-up artist arrives before that. Typing all three by hand means retyping all
three every time a block moves, which is exactly the rework `docs/adr/0015` set out to make cheap
for the timetable itself, and left untouched for convocations.

ADR 0015 (amended alongside this record — see its own Amendment section) already gives every slot a
computed chain of blocks, each with a start and an end. A convocation's own times are readable off
that chain directly: nobody needs to say "call time 08:15", they need to say "this person needs 45
minutes before they're needed", and the app can read the rest off the plan.

What is left to decide is what a user still types by hand, and how the two figures a lead time can
come from — a named group of people who walk in together, or one person's own override — combine.

## Decision

**A slot has one typed clock left**, its own `startMinute`. Everything else a call sheet prints for
that slot is computed by a new pure function, `ocptComputeSlotConvocations`
(`lib/utils/ocpt_shooting_convocations.dart`), from that slot's own chained blocks
(`OcptShootingSlotTimeline`, ADR 0015) and a lead time.

**A lead time is the one figure a user types beside a person.** It answers "how many minutes before
this person is needed do they have to be here" — hair, make-up, costume, or simply travel time — and
it can be typed in two places: on a **group** the day carries (`shooting_day_groups.leadMinutes`,
a named band of people who are called together, crew or cast alike) or on the convocation row
itself (`shooting_slot_crew.leadMinutes`/`shooting_slot_cast.leadMinutes`). **The row's own figure
wins when it is set** — `leadMinutes ?? groupLeadMinutes ?? 0` — because an individual override
(one actor's own prosthetic taking longer than the rest of the band) is a fact about that person,
not about the group. A resolved lead that comes out negative is refused with an `ArgumentError`:
nothing in this mode means "be convoked after you are needed", so a lead is typed by a human, never
derived into something impossible.

**The slot's own band** is the minimum start and the maximum end over its blocks — a minimum and a
maximum, not "the first and last block in chain order", since a pinned anchor can put a block
earlier than the one that precedes it in the chain.

**A crew convocation**'s `callMinute` is that band's start minus the resolved lead; its `wrapMinute`
is the band's end, full stop. There is deliberately **no after-offset anywhere in this model**:
"finishing later" is stated as a `wrap` block appended to the chain — the block kind already exists
for exactly this — which moves the band end, and with it every crew member's wrap at once, rather
than one row's typed override drifting from what the plan actually says.

**A cast convocation**'s PAT band is the same minimum/maximum, taken only over the blocks that name
that role — a shot block through its `shot_characters`, a hold block through the scene it reserves
time for, no other block kind naming a role at all. A role no block of the slot names keeps the
**slot's own** band instead of an empty one: someone convoked and not used is still convoked, and a
production that put them on the sheet meant it. `arrivalMinute` is `patStartMinute` minus the
resolved lead — the make-up chair, which is why a lead lives per role and per day rather than once
per film.

**Nothing computed here is ever overridable by hand.** A typed clock is a claim nothing keeps true
once a block moves — the exact failure mode ADR 0015 already rejected for the timetable itself, and
the same argument applies unchanged to a convocation built on top of it. Arriving earlier or
finishing later is always stated as a lead time or as a block, never as a second, competing clock
field.

## Consequences

Moving a block from a slot's morning half to its afternoon one recomputes every convocation that
chain feeds, for free — the entire point, mirroring what ADR 0015 already bought for the timetable
itself. The cost is the same one that decision already accepted: a convocation cannot be read from
one row in isolation, it needs the slot's whole chain run first, so any place that shows a call time
has to go through `ocptComputeSlotTimeline` and then `ocptComputeSlotConvocations`, in that order.

A lead of zero is a legitimate, common answer ("arriving ready", no make-up needed) rather than a
placeholder for "not filled in yet" — there is nothing to distinguish the two, which is fine: a
crew or cast row with no lead of its own and no group either is exactly the case where showing up
right at the band's start is correct.

Resolving *which* group a row belongs to, and seeding a new row's lead from that person's or role's
most recent convocation, are both left to the caller (`OcptScheduleService`, wired in a later
milestone) — this function only resolves the figure it is handed, on `leadMinutes ??
groupLeadMinutes ?? 0`, and knows nothing of `shooting_day_groups`, `shooting_slot_crew` or
`shooting_slot_cast` rows.

## Alternatives considered

- **Keep the typed clocks, add computed ones alongside them as a read-only preview**: rejected for
  the same reason ADR 0015 rejected storing both a duration and a cached clock time — two
  representations of the same fact drift the moment a write is missed, and a user staring at two
  numbers that disagree has no way to know which one the sheet will actually print.
- **A lead time per person, film-wide, with no per-day override**: rejected by Benoit (see the
  plan's §3) — the same crew is called earlier on a January exterior than in a heated studio, so the
  figure is a fact about a day, not about a person in the abstract.
- **Deriving `wrapMinute` from `callMinute` plus a typed duration**, mirroring the block chain's own
  shape: rejected because a convocation's wrap is never independent of the slot's actual plan — it
  is always "when the last block of the slot ends", and a duration typed alongside it could disagree
  with the timetable the moment either one changed.

## Amendment

A crew convocation is now expressed the same way a cast convocation already was: an `arrivalMinute`,
a `patStartMinute` and a `patEndMinute`, in place of `callMinute` and `wrapMinute`. The *prêt à
tourner* moment is as real for a technician as for an actor — a gaffer is not merely "called", they
are ready to shoot at a given minute, same as the cast — so the two convocation shapes now name the
same three figures rather than two of them under different names. `patStartMinute`/`patEndMinute`
are still the slot's own band, unchanged, and `arrivalMinute` is still that band's start minus the
resolved lead; nothing about what is computed changed, only what the result is called and how much
of it is returned. `OcptCastConvocation.patEndMinute`'s own doc comment, which used to point at
`OcptCrewConvocation.wrapMinute` for the empty-slot convention, now points at
`OcptCrewConvocation.patEndMinute` instead.
