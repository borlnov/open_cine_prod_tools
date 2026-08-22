<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# 0027 - A nomenclature seeded, not frozen

## Status

Accepted

## Context

Every French commission that funds a film expects a quote laid out against the CNC's ten-poste
nomenclature. A production that submits a budget organised its own way gets it back. So the app has
to know those ten postes.

It also has to not insist on them. The same app is used by a short shot over one weekend by five
people, who will never file with a commission and whose real budget has four categories; by a
production working to a Belgian or Swiss frame; and by one that files against the CNC and still
needs an eleventh poste for something the nomenclature never anticipated. A hard-coded, read-only
list of ten serves the first reader and obstructs the other three.

Two mechanisms were available and neither was right on its own. Hard-coding the ten as constants and
rendering them from code makes them uneditable. Leaving `budget_postes` empty and asking the user to
type ten rows makes the common case tedious and guarantees ten different spellings of the same
nomenclature across projects.

There is a third constraint that rules out the obvious seeding implementation. This project is being
built to sync (ADR 0009, ADR 0010), and two replicas of one project may each seed it before they
ever meet. Rows minted with `Uuid().v4()` would merge into twenty postes rather than ten, and no
merge rule could tell which of the two "Poste 1" rows was which.

## Decision

The ten CNC postes are declared in `lib/constants/ocpt_budget_cnc_postes.dart`, each an
`OcptBudgetCncPoste` carrying a **constant, hard-coded UUID** — the same device schema version 18
already uses to derive `role_episodes.id` from the role it links. `OcptBudgetQuoteService.loadPostes`
inserts them (`_seedIfEmpty`) on the **first read of a `budget_postes` table holding no row at
all, tombstones included**.

Three properties follow from exactly where that seeding happens:

- **On first read, not at project creation** — so a project that predates the budget mode entirely
  gets the nomenclature on its very next open, with no migration writing rows.
- **Only when the table holds no row at all, tombstones included** — a user who has deleted every
  poste has said something, and re-inserting them would be the app arguing with them.
- **Deterministic ids** — two replicas seeding the same project independently produce the same ten
  rows and merge into ten.

Once seeded, a poste is an ordinary row: renamed, reordered, deleted or joined by an eleventh like
any other, and never re-inserted by a later read. Each constant carries a `labelKey`/`simpleLabelKey`
naming an ARB key rather than a resolved word, `lib/constants/` and `lib/managers/` being free of
`Tr`; `ocptBudgetCncPosteSeeds` (`lib/ui/utils/ocpt_budget_labels.dart`) turns the constants into
localized `OcptBudgetPosteSeed`s, and `OcptBudgetMode` resolves them **once**, against the outer
listening-safe `BuildContext`, handing the result to the bloc as a constructor argument.

## Consequences

The ten UUIDs are now part of the app's compatibility surface: they may never be changed, because a
project seeded by an older build names them, and a sync partner will match on them. Adding an
eleventh CNC poste later means adding a constant with a new fixed id, and a project already seeded
will not receive it — the seeding rule deliberately does not top up an existing table.

Deleting the last poste of a project turns the seeding off for that project forever, which is the
intended reading of the gesture and will occasionally surprise somebody who deleted them to start
over. The `+ Add` footer is the way back, not a re-seed.

The nomenclature's own words live in the ARB files, so a new UI language has to translate ten poste
labels and their ten simplified variants before that language's users see the nomenclature in their
own tongue.

In exchange, the commission's reader opens a fresh project and finds the document they expect, and
the five-person production renames four of the ten and deletes the rest, with no branch anywhere in
the code distinguishing the two.

## Alternatives considered

- **Hard-code the ten and render them from code** — serves the commission and blocks everyone else;
  no eleventh poste, no rename, no reorder.
- **Seed at project creation** — leaves every project made before the budget mode without a
  nomenclature, and needs a migration that writes rows.
- **Seed with `Uuid().v4()`** — two replicas merge into twenty postes, with no rule able to pair
  them up.
- **Top up the ten on every read** — resurrects a poste the user deliberately deleted, every time
  they open the project.
- **Ship several nomenclatures and ask which** — a choice nobody can make before they have a budget,
  and a second nomenclature nobody here has validated (ADR 0026).
