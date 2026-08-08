<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0016 - Sun times computed offline from the location's coordinates

## Status

Accepted

## Context

Every reference call sheet read while planning the schedule mode prints sunrise, sunset and a
twilight figure for the day. `Plan de travail et planning.xlsx`, the professional strip board, goes
further and carries astronomical twilight as one of its per-day columns. In every one of those
documents, the figures were **typed in by hand** — someone looked them up on an external site or an
almanac and copied them into the cell.

That is the naive expectation a user coming from those documents would carry into this app: a field
to type the sunrise and sunset into, per day. Three things argued against it.

- **It is data the app can derive** from facts it already has: a shooting day's date, and the
  location its first slot is called to (`locations.latitude`/`longitude`, already captured by the
  resources mode). A field that duplicates a derivable fact is one more thing to keep in sync by
  hand and one more thing a version restore has to reconcile.
- **The app is offline-first by design** (no network storage, no remote service anywhere in its
  architecture — see the top-level project overview). Looking the figures up would mean either the
  first tool in the app that needs a network connection, or a bundled table of some other tool's
  output that goes stale the moment its source updates its own data.
- **The five figures follow a well-published, implementable algorithm.** The NOAA General Solar
  Position Calculations (the low-precision formulas at
  <https://gml.noaa.gov/grad/solcalc/solareqns.PDF>) give sunrise, sunset and the civil, nautical
  and astronomical twilights at both ends of the day from nothing but a date, a latitude and a
  longitude — exactly the inputs already on hand.

## Decision

`lib/utils/ocpt_sun_times.dart` implements the NOAA formulas in pure Dart (`ocptSunTimesOf`,
`OcptSunTimes`), computed **entirely offline**: no network call, no bundled table, no external
service. It solves each of the eight figures (sunrise, sunset, and civil/nautical/astronomical
dawn and dusk) twice — once against noon's own solar position to get a first estimate, then again
against the solar position at that estimate — which keeps the result meaningfully closer to
accurate away from the solstices than a single noon-based pass, at the cost of running the
trigonometry twice for a function called at most a few times per day view render.

Every figure is returned as a **nullable** minute count. Above roughly the polar circles, and for
the deeper twilight phases at surprisingly ordinary latitudes (Paris already loses its
astronomical twilight for a few weeks around its own summer solstice), the sun can fail to reach a
given depth below the horizon at all: the hour-angle equation has no solution, and the honest
answer is that the figure does not exist that day at that place, not a wrapped or clamped
approximation of one.

Every figure is a minute **from the day's own local midnight, wrapping nothing** — the same
convention `shooting_day_blocks` already uses (ADR 0015): a sunset that falls after the following
midnight (a high-latitude summer night) comes back at 1440 or more, and an event before local
midnight comes back negative. `ocptFormatDayMinute` already reads either correctly.

The **time zone is the device's own offset for the given date** (`DateTime.timeZoneOffset`, which
already accounts for a daylight-saving change partway through the year). This is correct for a
production shooting in its own time zone — every case this app has today — and wrong by the exact
difference for one shooting on a device still set to its home zone. `OcptSunTimes.utcOffsetUsed`
reports the offset that was applied, specifically so this limitation is visible rather than
silently wrong: the day inspector can say "times shown for UTC+1" instead of presenting a number
with no way to tell it might be off.

## Consequences

A shoot planned in a field with no signal gets the same sun times as one planned in an office, and
nothing about this feature can go stale the way a bundled table would. A location with no
coordinates yet simply has no sun block to show — the caller's decision, not this function's, since
`ocptSunTimesOf` always requires both.

The NOAA low-precision formula is itself an approximation, documented as accurate to roughly a
minute or two away from the poles; this project's own tests assert against a published reference
within a few minutes' tolerance rather than exactly, for the same reason — an exact assertion
against an approximate algorithm would be a false promise. Near a shallow sunrise or sunset angle
(a high latitude close to its own solstice), the same small error in the sun's computed position
corresponds to a noticeably larger error in *when* it crosses a given depth, since the sun is
moving almost sideways rather than upward at that point in its path; this is a property of the
geometry rather than a defect, and the tests widen their tolerance for exactly those cases rather
than pretending otherwise.

The device-time-zone limitation is a real cost, not a hypothetical one: a French production
scouting a location abroad, or simply a laptop whose clock was never reset after travel, gets
figures off by whatever the difference is. It is written down here on purpose, rather than fixed,
because fixing it needs a decision this project has not made yet — asking the user for a time zone
per location, deriving one from the coordinates via a bundled offline database, or something else —
and `OcptSunTimes.utcOffsetUsed` is the one clearly-named seam a future change would replace, rather
than a computation to re-derive from scratch.

## Alternatives considered

- **A typed field per day**, matching what the reference documents show: the naive expectation, and
  rejected for duplicating a derivable fact — every one of the "why not a typed clock time" costs
  ADR 0015 lists for a block's start time applies here too, plus the tedium of an entirely manual
  lookup for every single shooting day of a production.
- **A bundled table of precomputed sun times** for a fixed set of places and years: avoids the
  trigonometry, but a table is finite by construction — the first production shooting in a town
  outside it, or in a year past its coverage, gets nothing, and the table itself would need
  maintenance the algorithm never does.
- **A live lookup against a sun-times web service**: the most accurate option, and the one rejected
  outright by the project's offline-first architecture — it would be the first feature in the app
  that stops working with no signal, in an app explicitly built to keep working on a set with none.
- **A higher-precision solar-position algorithm** (full VSOP87 or a Meeus-style ephemeris): more
  accurate, particularly at high latitudes, at the cost of materially more code and a set of
  coefficient tables the NOAA low-precision formula does not need. Rejected as disproportionate to
  what a call sheet needs — a figure rounded to the minute — and revisitable later behind the same
  `ocptSunTimesOf` signature if a production ever needs tighter accuracy than this gives.
