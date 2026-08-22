<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0025 - The budget reads the other modes, it does not copy them

## Status

Accepted

## Context

The budget arrives last, into an app that already knows almost everything it needs. The breakdown
has catalogued every element the film requires and what each is expected to cost
(`elements.cost`). The schedule knows how many shooting days there are and, slot by slot, exactly
who is convoked to each of them. The resources catalogue knows who those people are. The project
knows which currency it counts in.

A budget mode could ignore all of it and ask for it again. That is what a spreadsheet does, and it
is why a spreadsheet is wrong within a week: the shoot loses a day, the schedule says so, and the
catering line still bills for the day that was cut. Every figure typed twice is a figure that will
disagree with itself, and the disagreement is discovered by a commission rather than by the
production.

The opposite excess is as bad. Copying the schedule's head counts into `budget_lines` at the moment
somebody opens the catering view produces rows that look like data and are a stale snapshot, and it
makes the budget mode a writer of tables it does not own.

Some facts genuinely belong to nobody yet. How far a gaffer drives to set is not in the schedule, is
not in the breakdown, and is not a budget figure either — it is a fact about that person, and the
schedule will want it too the day it prints travel times.

## Decision

**The budget mode reads the other modes' tables and stores nothing it can read.**

- The catering-and-travel pass (`lib/utils/ocpt_budget_regie.dart`) counts meals and snacks off
  `OcptScheduleSnapshot`'s own days, slots and per-slot crew, cast and guests, priced by
  `project_info.mealPriceCents`/`snackPriceCents`. It writes nothing, carries no `isReadOnly` flag
  because there is nothing to withhold, and every row of it reports a click upward so a reader who
  disagrees with a figure is sent to the one place it can be changed.
- The dashboard's "what feeds this budget" card counts how many breakdown elements a quote line
  already prices and how many do not, how many shooting days the schedule holds, and the meals those
  presences produce.
- `budget_lines.elementId` crosses a quote line with the element it prices; a line minted from one
  takes the element's own name and `elements.cost` as its unit price — and a **null** `elements.cost`
  is passed as `Value.absent()`, not `Value(0)`.
- The currency comes from `project_info.currencyCode`, set once on the project settings page.

**What can be computed nowhere is typed once, where it belongs — not in the budget.**
`people.commuteKmMilli` and `people.mileageRateId` are columns on `people`, edited on a person's own
sheet in the resources mode, and read by the budget. A one-way commute is a fact about a person, so
it is stored with the person, and it is scrubbed by all three of the erasure paths a person's row
travels.

`budget_mileage_rates` is the one table the budget owns for this purpose, and it holds only what
nobody else could hold: the rates a production names for itself.

## Consequences

The budget mode's reads are wide: `OcptBudgetSnapshot` joins the quote, the journal, the financing
plan, the schedule, the roles and the people. A change to the schedule's own model can therefore
break a budget reading, and the catering pass is coupled to `OcptShootingSlot`'s crew, cast and
guest links in a way a stored copy would not have been.

It also constrains what may be shown: the budget can only state a figure some other mode already
holds, which is why `Consumed` prints the em dash for a poste with no quote and why a traveller with
no recorded distance is still listed, with the money silent — the absence is the reading.

In exchange, nothing is entered twice, and a figure that changes changes everywhere at once. The
cross-links each view carries are what make that navigable rather than merely true.

The pass deliberately reads `OcptScheduleSnapshot` rather than `OcptSchedulePlanSnapshot`: the plan
snapshot requires every episode's shot list and the episode list, and counting heads needs neither —
building one would make the budget mode load the whole découpage to count meals.

## Alternatives considered

- **Copy the counts into `budget_lines` on open** — rows that look like data and are a stale
  snapshot, and the budget mode writing tables it does not own.
- **A `commuteKm` column on a budget table** — the same fact stored in the mode that happens to read
  it first, guaranteeing a second copy the day the schedule wants it too.
- **Ask the user for the number of shooting days** — a figure the app already knows, and one that
  would silently stop matching the schedule the first time a day was cut.
- **Read the plan snapshot for the catering pass** — the obvious-looking type, and the one that
  makes counting meals load the entire découpage.
