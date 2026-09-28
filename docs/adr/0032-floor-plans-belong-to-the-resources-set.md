<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0032 - Floor plans belong to the Resources set

## Status

Accepted

## Context

The storyboard/floor-plan feature (ADR 0031) shipped a first floor-plan model scoped to the
sequence: a "case" per sequence, tabs on the sequence, its décor and its placements all keyed to
`sceneId`. Using the app surfaced the collision that model invited: a floor plan named itself after
a place ("Kitchen") exactly the way a Resources **set** already does, and a production whose same
kitchen appears in three sequences ended up drawing three independent floor plans of the same room,
agreeing about nothing — furniture moved on one never moved on the others, and a location scout had
three plans to keep in sync by hand for one room. The resources mode's own `sets` table (a
location's own places, linked to a sequence through `scene_sets`) was already the one thing the app
calls "a room, drawn once, shot in several sequences" — the floor plan was answering the very
question `sets` already answers, from a second table naming its own rooms all over again.

## Decision

**A floor plan is the plan of a Resources set** (`sets`), not of a sequence. `floor_plan_sets.id`
**is `sets.id`** rather than a fresh id of its own: the plan is created lazily, on the first symbol
placed or underlay imported (each writing method of `OcptFloorPlanService` ensures the row
first), and making its id a pure function
of the set's own id is what lets two replicas that each place the first symbol on the very same set
while offline converge onto **one** row through the sync merge, exactly as any other row two
replicas happen to write the same way — a fresh UUID minted independently on each side would instead
mint two divergent plans for one room. A sequence's floor-plan tabs are **its own live `scene_sets`
links**, the same fact the breakdown's own sets row already reads and writes (`breakdown.md`): no
floor-plan-specific link table, and the two modes can never disagree about which sets a sequence is
shot in.

Three scopes read that one row differently. **Set** scope (`sceneId`/`shotId` both null) is the room
itself — walls, doors, fixed furniture, the underlay — shared by every sequence the set is linked
to. **Sequence** scope (`sceneId` set) is what one sequence re-dresses for its own coverage — a
moved chair, a breakdown prop — without touching the set for every other sequence that plays there.
**Shot** scope (`shotId` set) is one shot's own blocking — cameras, characters, lights, arrows —
never shared with another shot of the same sequence. A sequence-scope row may **override** a live
set-scope row of the same set (`overridesSymbolId`), and a shot-scope row may in turn override a
live sequence-effective one; either override may be **hidden** (`isHidden`) rather than moved —
masking the original for that one sequence or shot without deleting anything, drawn as a faint,
still-selectable ghost the inspector can restore. A set-scope correction — a wall moved half a
metre — therefore still reaches every sequence that has not overridden it, which is the entire point
of drawing the room once.

Two sets that happen to look alike are **never the same row**: duplicating a set (the shot list's
own `Duplicate this set`) mints a fresh Resources set in the same location and copies only its
set-scope symbols across, as independent copies. **Link where it is the same room, copy where it is
another room laid out the same** — a production's two identical hotel rooms are two sets from the
day they are drawn, never one plan two sequences point at and then have to diverge from by hand.

## Consequences

A plan editable from three surfaces at once (a set-scope correction reaching every sequence, a
sequence's own re-dressing reaching only itself) is a more complex read than one flat table would
have been — `OcptFloorPlanSheet.of` resolves set → sequence → shot every time it draws, and the
override/hidden-override bookkeeping (`overridesSymbolId`, `isHidden`) is the price of letting a
correction propagate while a re-dressing stays local. A user moving a chair for one sequence is
asked which of the two they mean the moment the set is shared, a question a per-sequence plan never
had to ask.

The `floor_plan_sets.id == sets.id` identity is a departure from every other synchronised table's
own fresh UUID, and it only works because the row is created lazily and deterministically; it would
not generalise to a table whose row could legitimately be created more than once for the same owner.
Deleting a Resources set or its whole location must remember to cascade into the plan
(`OcptLocationsService.deleteSet`/`.deleteLocation` →
`OcptFloorPlanService.tombstoneFloorPlanRowsOfSet`) — a plan drawn against a décor the production no
longer has being exactly the tombstoned-orphan case every cascade in this app already guards
against.

## Alternatives considered

- **A plan per scene, copied between sequences by hand** — the model this record replaces. Rejected:
  a shared room drifted the moment either copy was edited, and nothing said the two plans were meant
  to agree in the first place.
- **A plan per location, with `sets` reduced to zones inside it** — rejected: a location is regularly
  a whole house or a whole street, at a scale no single scale bar or underlay can serve honestly,
  where a Resources set is already the granularity the maintainer picks per project (a kitchen and a
  hallway as one set when they are always played as one space, two sets when they are not) — folding
  that choice into the floor plan would have reopened a decision `sets` already settles.
- **Two scopes only — the set and the shot, with a sequence's props and re-dressed furniture placed
  shot by shot** — rejected: a candle or a moved table belongs to the sequence, not to one shot, and
  copied into every shot it would drift the first time one copy was touched. The sequence scope
  holds it once; a shot that genuinely changes it overrides it for that shot alone.
