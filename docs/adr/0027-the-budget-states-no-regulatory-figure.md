<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0027 - The budget states no regulatory figure and asks for no threshold

## Status

Accepted

## Context

A budget mode is under constant pressure to be helpful by pre-filling. The mockup carried a mileage
scale, a default VAT rate and a `1,500 €` cash floor below which the dashboard would raise an alert.
Each looks like a convenience and each is a claim.

A mileage scale is a legal figure. France publishes one, it changes every year, and it differs by
vehicle: a car, a production van and a motorbike are not reimbursed alike. This app ships in more
than one country and is used by productions that mix vehicles. A scale shipped as a constant would
be wrong for some users on the day it shipped, and wrong for all of them within a year — while
looking, on screen, exactly like a figure the app had verified.

A default VAT rate is the same claim in a smaller frame. A new project born at 20 % is a new project
asserting a country and a regime nobody chose.

The cash floor is a third kind of claim, and the emptiest: `1,500 €` was calibrated by nobody. An
alert threshold that the user did not set and the app cannot justify produces either noise or false
comfort, and the reader has no way to tell which.

The repository had already settled this argument once, for a single column.
`project_info.minimumRestMinutes` ships with no default because a default would be the app
advancing a legal figure nobody here validated.

## Decision

**What this app advances, it either computes or holds from the user.** Generalised from
`minimumRestMinutes` to the whole budget mode:

- **No mileage scale is shipped**, not even a greyed example. `budget_mileage_rates` is a table the
  production fills itself, from the budget settings card, and the card says so rather than
  pre-filling anything. A rate is stored as `ratePerKmMilliCents`, in thousandths of a cent per
  kilometre, because a real scale is quoted to three decimals.
- **`project_info.defaultVatRateBasisPoints` is null for a new project**, meaning "nobody has
  recorded a rate", and the settings field carries a `No rate` button that puts the null back. An
  explicit `0 %` remains a value somebody can state, and it does not mean the same thing (ADR 0025).
- **`mealPriceCents` and `snackPriceCents` are null for a new project** and stay silent rather than
  advancing a figure, exactly as `minimumRestMinutes` does.
- **There is no cash floor and no threshold of any kind.** `ocptComputeBudgetAlerts`
  (`lib/utils/ocpt_budget_alerts.dart`) raises exactly two alerts, and both are arithmetic over data
  the user entered: a poste whose paid plus committed exceeds its own quote, and the cash projection
  — the journal's balance carried forward over the unsettled commitments, instalment by instalment —
  going negative, at the date and by the amount its own first negative step states. Each calibrates
  itself and states something anybody can check against the rows it read.

## Consequences

A new project's budget is emptier than a competitor's. Nothing is pre-filled, so a production has to
type its own VAT rate, its own meal price and its own mileage rates before those parts of the mode
say anything at all — and until they do, every view that would read them prints the em dash rather
than a figure.

Every reader has to be able to print that absence. `ocpt_budget_vat.dart` answers null rather than
zero, `OcptBudgetCoveredTotal` says how many rows a total covers, and each view has a silent state
to draw. That cost is paid once per reading and permanently.

It also forbids a whole class of future feature: no benchmark ("this poste is usually 8 % of a
budget this size"), no suggested rate, no imported scale presented as authoritative. A future
version may import a scale the **user** points it at; it may not ship one.

In exchange the app never says a number it cannot defend, and a figure on screen is always either
something the user typed or something computed from what they typed.

## Alternatives considered

- **Ship the French scale, updated yearly** — commits this project to tracking one country's tax
  administration, and is wrong for every other user on day one.
- **Ship an example rate, greyed, to be renamed** — still a figure on screen, and a placeholder that
  gets left in is indistinguishable from one that was chosen.
- **Default the VAT rate from the project's locale** — the page format and the currency already do
  this, so it is defensible; it was left as an open question in the plan rather than adopted,
  because a rate is a tax regime, not a paper size. One line in `OcptProjectsManager` if it is ever
  wanted.
- **A user-settable cash floor** — better than a shipped one, but the alert that matters is already
  computed by the projection, and a second, weaker alert beside it would only dilute the first.
