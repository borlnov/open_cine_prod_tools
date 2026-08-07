<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Schedule mode — convocations read off the slots alone

This document is the implementation strategy for the third rework of the schedule mode's
convocations, decided by Benoit after using the second one. It is written for the Sonnet 5 agents
that will build it, orchestrated and reviewed by the main session. **Read the repository
`CLAUDE.md` first** — this plan assumes its architecture, ways of working, coding standards,
licensing rules and verification gates, and does not repeat them.

It supersedes the convocation half of `docs/plans/schedule-slots-and-computed-convocations.md`
(shipped as 28b/28c) and rewrites the rule ADR 0017 states. The three PDFs of
`docs/plans/schedule-mode.md` M2 are still downstream of it: a call sheet prints exactly the
figures this plan changes the origin of.

---

## 1. What is wrong today

A convocation is computed from a **lead time** — minutes before the moment someone is needed —
carried by the crew or cast row itself or by a `shooting_day_groups` row it points at.

A lead time says *how long*, never *what for*. Nothing in the file distinguishes forty-five minutes
of prosthetics from twenty minutes of rigging or from an hour of driving, and those are three
different facts a production has to plan, argue about and print. Worse, they are facts with a
**duration and a place** — a make-up truck, a set to light — which is precisely what a slot already
is. The model was expressing as an anonymous offset something it already had a first-class way to
say.

## 2. The rule, from here on

**Nothing is offset from anything.** A person is convoked by being linked to a slot, and every
figure about them is read off the slots they are linked to and the blocks in them. A production
that wants somebody there at 06:00 for make-up creates a 06:00 slot and links them to it — its
label ("HMC", "Installation") is what says why, its blocks are what say how long, and the day view
already draws slots as parallel lanes.

For a person **P** on a day **D**, over `S(P)` = the live slots of D that P is linked to (a
`shooting_slot_crew` row by person, a `shooting_slot_cast` row by role, both kinds counting):

| Figure | Definition |
| --- | --- |
| Arrival | the **earliest** `startMinute` over `S(P)` |
| PAT start | the start of the **earliest shooting block** over `S(P)`, or null when there is none |
| PAT end | the end of the **latest shooting block** over `S(P)`, or null when there is none |
| Departure | the **latest** slot end over `S(P)` — that slot's own last block end |

Consequences to hold on to while building this:

- **A slot with no shooting block gives no PAT.** A person convoked only on preparation slots has
  an arrival and a departure and no PAT band at all, which is the truthful reading: they are there,
  they are not waiting to shoot.
- The PAT band is **not** clipped to one slot. Someone on a morning slot and an evening slot has
  one band running from the first shot of the morning to the last shot of the evening, gaps
  included; the day view's lanes are where the gaps are read.
- Nothing depends on a block **naming** the person any more. `shot_characters`, the roles the
  breakdown tagged in a hold's sequence, `OcptScheduleState.roleIdsBySceneId` — none of it takes
  part in a convocation. Whoever is linked to the slot is convoked by the slot.
- A **shooting block** means `shot` **and** `hold`: a hold reserves the time of a sequence not yet
  shot-listed, and a production that has scheduled a whole week ahead of its découpage must still
  see a PAT band. Every other kind (`preparation`, `hairMakeUp`, `meal`, `pause`, `travel`, `wrap`)
  is not shooting time and never opens or closes a band.
- A slot carrying no block at all ends at its own `startMinute`: it is a convocation with no
  content yet, not a zero-length error.

## 3. What goes away

- `shooting_slot_crew.leadMinutes`, `shooting_slot_cast.leadMinutes`, and the `groupId` on both.
- The `shooting_day_groups` table, and with it the day view's `People groups` band, its `ⓘ`, its
  creation/rename/retime/delete flow and the group pickers on every crew and cast card.
- `OcptScheduleService`'s group operations, its seeding of a lead time and a group from the most
  recent day that convoked the person, and the copying of groups by `createDay`/`duplicateDay`.
- The arrival and PAT read-outs **on the crew and cast cards** of a slot card: a card there goes
  back to saying who is convoked and in what function, nothing about clocks. The times move to the
  new panel of §5.
- `OcptScheduleLeadField` and `OcptScheduleGroupsBand`, and their tests.

Nothing is guessed on the way out: a lead time and a group are dropped, not converted into a
preparation slot the user never asked for — the same rule the v11→v12 migration followed when it
dropped typed clocks.

## 4. Data model

**Schema v13** (allocated at merge time, ADR 0007 — renumber if another branch lands first):

- `m.deleteTable('shooting_day_groups')`.
- One `TableMigration` per convocation table, recreating `shooting_slot_crew` and
  `shooting_slot_cast` without `group_id` and `lead_minutes` — the `_alterScheduleTablesToV12`
  idiom, `// ignore: experimental_member_use` included.
- The migration test pins what `onCreate` produces against every upgrade path, as always.

**Payload format 8**: `_payloadUpgrades`' entry from 7 drops the `shooting_day_groups` list and the
two keys on every crew and cast row. This is the first entry that removes rather than materialises,
and it means what it says — a version captured while groups existed comes back with none, because
the concept no longer exists in the project it is being restored into. `contentDigest` and
`_applyPayload` follow the same removal.

`OcptShootingDayGroup` (model), `OcptScheduleSnapshot`'s groups, and the group/lead fields of
`OcptShootingSlotCrewMember`/`OcptShootingSlotCastMember` go with them.

## 5. The convocations panel

A **third right-dock tab**, `OcptScheduleRightDockTab.convocations`, between `inspector` and
`versions`: the day's whole call, one row per person, which is the reading nobody could get from
the slot cards once a person may sit on three of them.

- Scope: the **selected day**. No day selected, no rows — the panel says so, as the inspector does.
- One row per **person**, crew and cast folded together (an actor read through `roles.personId`),
  since the question is "when does this human arrive". A **role with nobody cast** is its own row,
  named by the role: it is a convocation the production still has to honour.
- Columns: arrival, PAT band (or an em dash when there is none), departure, and the slots the
  person is on, by label.
- Sorted by arrival, then by name, so the panel reads as the order people walk in.
- Read-only: everything on it is computed, and the way to change any of it is to move a block or a
  slot. It is therefore identical under a version preview, and needs no `isReadOnly` handling
  beyond not offering anything in the first place.

## 6. Pure code and the ADR

`lib/utils/ocpt_shooting_convocations.dart` is rewritten: `ocptComputeSlotConvocations` (per slot,
per lead time) gives way to `ocptComputeDayConvocations`, which takes a day's slots — each with its
own already-computed `OcptShootingSlotTimeline` (`ocpt_shooting_day_timeline.dart` is untouched)
and its own linked person and role ids — and answers one `OcptDayConvocation` per person and per
uncast role. It stays **pure**: no drift row, no Flutter, resolving who a role's actor is remains
the caller's job.

`docs/adr/0017-convocations-computed-from-the-slot-chain.md` is **superseded** by a new
`docs/adr/0018-…`, rather than amended a second time: the decision it records (a convocation is a
band minus a lead time) is not being refined, it is being replaced by "a convocation is the slot
you are linked to". 0017 gets the standard superseded header pointing at 0018.

## 7. Milestones

Each one ends on the full verification gates and one commit per logical change.

1. **M1 — the model.** Schema v13, payload format 8, the models and the snapshot, the service
   cleanup (group operations, seeding, `createDay`/`duplicateDay`). Tests: migration, codec,
   versions service, schedule service.
2. **M2 — the rule.** `ocptComputeDayConvocations` and its tests; ADR 0018 and 0017's superseded
   header.
3. **M3 — the day view.** The groups band and lead field deleted, the crew and cast cards slimmed
   to who and what function, the bloc/state/events cleaned of groups and leads,
   `dayArrivalMinute` reduced to the earliest slot start, the day inspector and the strip agenda
   following.
4. **M4 — the panel.** The new tab, `OcptScheduleConvocationsPanel`, its l10n and its tests.
5. **M5 — the documentation.** `AGENTS.md`'s schedule section and its status table.

M1 and M2 are independent of one another and may run in parallel; M3 needs both; M4 needs M2.

## 8. Out of scope

The presence grid, the conflict alerts and the three PDFs (`docs/plans/schedule-mode.md` M2/M3)
stay where they are. `shooting_presences` is still declared and still unwritten.
