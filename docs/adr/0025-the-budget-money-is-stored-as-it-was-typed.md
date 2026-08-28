<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0025 - The budget's money is stored as it was typed

## Status

Accepted

## Context

A budget mixes two kinds of figure that look alike and are not. A till receipt for craft services
reads `12.50 €` and that number already includes tax. A supplier's quote for a camera package reads
`1,850.00 €` and that number does not. Both are typed by the same person, into the same table, on
the same afternoon.

The obvious design is to pick one canonical basis, convert on the way in and convert back on the
way out. It does not survive contact with a real production. VAT arithmetic is a division, the
result is rounded to the cent, and the round trip is not the identity: `12.50` stored excluding tax
at 20 % is `10.4166…`, kept as `1042` cents, and read back tax-inclusive as `12.50` — until the rate
is `5.5 %`, or the amount is `0.15 €`, or somebody changes the project's default rate, at which point
the receipt in the user's hand and the figure on their screen differ by a cent. A person
reconciling a bank statement cannot be told that the difference is a rounding.

Two further facts had to be separated, and a single nullable rate column cannot say both. A wage
and a copyright assignment carry **no** VAT: `0 %` is a value somebody states on purpose, and their
excluding-tax figure equals their tax-inclusive one. A line nobody has got round to filling in
carries **no recorded rate at all**, and neither of its converted figures exists yet. Summing the
second as if it were the first understates a total silently, which is the one failure mode a budget
cannot have.

Quantities carry the same problem in a smaller key: `1,484 km`, `5 days` and `1.5 day` all have to
be stated exactly, and a floating-point quantity multiplied by a unit price accumulates a drift
across a ten-poste nomenclature.

## Decision

An amount in the budget mode is **three columns**, and it is never reconstructed from anything else:

- `amountCents` — the figure exactly as typed, in cents;
- `isTaxInclusive` — non-nullable, `true` by default, because the common case a person types by hand
  off a receipt or an invoice total already includes tax;
- `vatRateBasisPoints` — nullable, and this null is the row's **override being absent**, meaning
  "inherit the project's rate", never "nobody has said".

`OcptProjectInfoTable.defaultVatRateBasisPoints` is nullable too, and **its** null means the other
thing: nobody has recorded a rate at all, which is what a new project is born with.
`OcptMoney` (`lib/models/`) is that triple seen from the domain, and
`lib/utils/ocpt_budget_vat.dart` is the **only** place in the repository allowed to convert between
the two bases. Every function in it answers **null, never zero** when the rate an amount would need
is unknown, and `OcptBudgetCoveredTotal` (`lib/utils/ocpt_budget_totals.dart`) carries that honesty
up to a whole table: a total says how many of the rows it was asked to sum it actually covers, and
stops saying so only once every one of them declares a rate, `0 %` included.

The header's excluding/including-tax toggle changes the **display basis**: every row is converted
individually and only then summed. Money that has already moved — `budget_entries`,
`budget_commitments` — is never read through that toggle at all, a bank balance having only one
honest basis. Quantities are integers in thousandths (`quantityMilli`), and a mileage rate in
thousandths of a cent per kilometre (`ratePerKmMilliCents`), for the same reason cents are cents.

A poste's quoted amount is **not stored**: it is the sum of its lines, computed on every read.

## Consequences

Three columns per amount instead of one, on five tables, and a codec that carries all three. Every
table has to be read through `ocpt_budget_vat.dart` rather than by adding a column up, and every
total is an `OcptBudgetCoveredTotal` rather than an `int` — a heavier type that every view, every
inspector and every export has to be able to print incompletely.

In exchange, no figure anybody typed is ever handed back to them altered, a table mixing both bases
and several rates still totals correctly, and a missing rate produces a stated gap rather than a
quiet understatement.

It also forbids a shortcut permanently: no future feature may store a derived monetary figure
beside the rows it derives from. `budget_resources` therefore carries no `receivedCents`,
`budget_commitments` no `settled` flag, `budget_shares` no `paidCents` and `budget_revenues` no
received amount — each is summed from the `budget_entries` rows naming it.

## Alternatives considered

- **One canonical basis, converted on the way in and out** — the round trip is not the identity, and
  a user's own receipt would disagree with the screen by a cent.
- **A single nullable rate column with null meaning `0 %`** — makes "exempt" and "not recorded"
  indistinguishable, and understates every total silently.
- **A non-nullable rate defaulting to the project's** — a line would stop following the project the
  moment the project's rate changed, which is the opposite of what a default is for.
- **Floating-point amounts and quantities** — the classic answer, and the classic source of the
  one-cent disagreement a budget is read to catch.
- **A stored `quotedAmount` per poste** — a second copy of one truth, and the "frozen quote v4" it
  would exist for is already what sealing a project version does.
