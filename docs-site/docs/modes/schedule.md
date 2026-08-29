<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: CC-BY-4.0
-->

# Schedule

## What this mode is for

The Schedule is where you decide **when** the film is shot. It comes after the shot list, because
what you place on a day is a shot. It answers the production office's question: which scenes,
which crew, which cast and which locations come together on which dates, and at what times.

![The schedule mode, showing a shooting day](/img/screenshots/schedule.png)

It is the one mode that looks at **the whole project at once** — every episode together — hence
the absence of an episode selector. A single day routinely covers scenes from two episodes at one
location.

## The objects you work with

- **Shooting days.** Each day is dated. Its number — the `D3` a call sheet prints — is not a
  fixed label but a **rank in date order**: re-date a day and the whole schedule renumbers.
- **Slots.** A day holds one or more slots. A slot is a working unit with its own location, crew
  and hours — often two in a real day (a morning unit, an evening one).
- **Blocks.** A slot's timetable is made of blocks: shots, holds, rehearsals, auditions, and the
  time around them (preparation, hair-and-make-up, meals, breaks, travel, wrap). You drag them
  into place or nudge them in five-minute steps.
- **The time model, in plain terms.** You never fill in a column of hours. You pin **one** edge
  of a slot — "we have the location until 22:00" or "start at first light" — and everything else
  is computed by chaining the blocks' durations. Nights past midnight are handled. Each block
  carries a private note (never printed) and a **crew note** (which does print).
- **Events.** What the day does not control — the village fireworks at 17:00 — sit at an absolute
  hour and push nothing.

## The four views

- **Day view** — the working surface. One card per slot, each with an "Assign people" section
  (crew, cast, guests) and its timetable. This is where you place shots, drag blocks, set a
  shot's status.
- **Agenda** — three presentations: a **strip** (what each day carries), a **week** hour-grid
  shaded by sun times, and a **month**. A "Colour by" control tints days by location or by
  INT/EXT day/night effect.
- **Positions matrix** — positions × slots: which position is covered on which unit, each column
  headed by the slot's resolved hours.
- **Presence grid** — people × days, with each person's working-day count. Cells are computed (at
  work, unavailable, or blank) and nothing here is editable.

## Call times

A call time **is the slot** you link the person to. You never type a call time. Link a person, a
role or a guest to a slot, and their hours are read from it: **arrival** is the earliest slot
start, the **PAT** band (*prêt à tourner* — costumed, made up, ready to shoot) runs from the
first to the last shooting block, and **departure** is the last slot end. To bring an actor in
early for make-up, you create a 06:00 slot (labelled `HMC`) and link them to it — the file then
says exactly what is happening. Guests get an arrival and a departure, but never a band.

## The alerts

The mode raises ten kinds of alert. **Hard**: a person called when unavailable; a person
double-booked on two overlapping slots; a slot outside every window its location declares.
**Soft**: a role placed but called on no slot; a role with no actor; an over-run against a pinned
edge; a person's day past their maximum; rest short of the project's minimum; a location permit
that does not cover the date. Alerts live in a dedicated tab, the status bar carries their count,
and each day at fault wears a badge.

## The documents

The Schedule produces the documents a production runs on:

- **Call sheets** (general and named) — one PDF per person; the named one adds its arrival / PAT /
  departure band and an "À apporter" (things to bring) table.
- **Shooting plan (PDF)** — the whole shoot: summary grids (locations, scenes, crew/cast,
  elements) and a per-day agenda.
- **Shooting plan (XLSX)** — the same plan as an editable spreadsheet, with a chronology sheet.
- **Day Out of Days** — the cast schedule, one row per role, with SW/W/WF/H codes.
- **One-line schedule** — a compact strip, one line per scene in shooting order, read as an order
  with no hours column.
- **Sides** — the actual screenplay pages of a day's scenes.

Every export lists every day, every hour is the resolved one, and scene numbers already print as
`2.12`.
