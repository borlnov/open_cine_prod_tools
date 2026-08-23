<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Budget mode UX — three documents, one grammar

This document is the implementation strategy for reworking the budget mode's interface. It is
written for the Sonnet 5 agents that will build it, orchestrated and reviewed by the main session,
with a user checkpoint between each milestone. **Read the repository `CLAUDE.md` first** — this
plan assumes its architecture, ways of working, coding standards, licensing rules and verification
gates, and does not repeat them.

**Nothing in the data model changes**, with one stated exception (§4.4). Every rule
`docs/architecture/budget.md` records about what a figure means still holds; what changes is where
the user meets it.

The validated screens live in the private Claude Design project **OCPT — refonte UX du mode
budget** (`3e7df5f5-23d6-48d5-bce9-35067267bf0c`), file `Budget UX 2a - les deux onglets.dc.html`,
options `3a` (expenses) and `3b` (resources). §3 restates them in words so no agent has to open
them.

---

## 1. Why this step exists

The budget mode shipped whole and works. Its interface does not, and the defect has a name: **six
sibling pages for what is one chain.**

- The chip bar presents Dashboard · Quote · Planned · Cash flow · Catering & travel · Revenue
  sharing as equal and simultaneous, when three of them are the *stages* of a single object.
  Nothing on screen ever says "this comes from that".
- The help panel explains the mode with a two-by-two matrix (promised / has moved × coming in /
  going out) that the navigation does not reflect, and two of the six pages are not in the matrix
  at all. When a table is needed to explain a tab bar, the tab bar is wrong.
- One sum lives three times with no visible link: a quote line, the commitment it becomes, the
  entry that settles it. Each is created separately and each asks for the amount again. The same
  defect, seen from the other end, is why creating a taking from the cash journal makes the user
  type one figure twice.
- The trade already solved this. A production's central document is the **cost report**: one
  table, one row per poste, and the columns budget · committed · paid · estimate to complete ·
  estimated final cost · variance. The quote view is already that at eighty per cent — but it is
  filed as one tab among six, and it lacks the one column a producer actually reads.

## 2. What the mode is for, restated

Answered by Benoit, and it governs every trade-off below:

- **The daily gesture is recording what arrives** — an invoice, a receipt, a transfer — and it must
  land in the right place without hunting for it.
- **One person, short or medium-length films.** No production accountant, no unit manager. The
  interface has to be readable by someone who does not know the trade vocabulary, while still
  holding up in front of someone who does.

## 3. The design, in one page

**Six pages become three documents**: `Dépenses` · `Ressources` · `Partage`. One reading grammar
serves all three.

**Recording what arrives comes first.** A one-line capture band sits at the top of expenses and of
resources: a direction (out or in), an amount, a name, a date, and a save. Nothing else is asked
for. The moment those four are typed, **the app proposes what the movement settles** — "solde
l'engagement « Couronne », 250,00 €, poste 5, échéance aujourd'hui: même montant, même
fournisseur" — and the answer is one click. `Autre chose…` opens the full entry dialog, prefilled.
The suggestion is offered at capture time and only then: once answered or ignored, the band clears
and the movement is an ordinary entry. Nothing queues, so nothing has to remember that it was
queued.

**The table nests.** A row opens on what it is made of. In expenses: a poste opens on its lines, a
line opens on its commitment and on the entries that settle it, each as an indented sub-row with
its own badge. In resources: a family opens on its resources, a resource opens on the receipts that
name it. One level fewer on the right, because an aid has no sub-lines.

**The dock tells the story.** Whatever row is selected, the right dock shows one panel: a
breadcrumb up to the document, the object's name and amount, a small stepper of its states
(`Estimé — Engagé — Payé` on the left, `Promis — Rentré` on the right), the figures that make it
up, the outstanding amount in large type, **one primary action**, and at most two secondary ones.
The table says where things stand; the fiche says where they come from and what to do next.

**The columns differ, and only the columns.** Expenses carries six money columns — `Devis`,
`Engagé`, `Payé`, `Reste`, `Coût final`, `Écart`. Resources carries three — `Promis`, `Rentré`,
`Reste à venir` — plus a `Dossier` column that expenses has no use for: a paperwork status
(*conventionnée*, *annoncée*, *facturée*) held deliberately apart from the money, because
"conventionnée" has never meant "versée".

**The bottom band answers the document's own question.** On expenses, the total row already does
it. On resources, a two-tone bar answers *does this cover the film?* — one tone for what has really
come in, another for what is only promised — and says in words how much is missing. A valued
in-kind contribution counts as promised and **never** as still to come: no cash will ever move for
it, so both cash columns read an em dash.

**Controls are contextual, not global.** The tax-basis switch appears on expenses only; money
coming in is always read tax-inclusive, so the control is withheld rather than disabled, as
everywhere else in the app.

## 4. Architecture

### 4.1 What does not change

Stated first, because it is most of the code, and because it is also the boundary of this step:

- **No table is added, renamed or dropped**, and no column either, but the one of §4.4. In
  particular the capture band invents nothing: a movement waiting to be attached is a
  `budget_entries` row naming no poste, resource, revenue or share, which is already a legal state
  and already what "off quote" means.
- Every service and every reading rule in `lib/utils/ocpt_budget_*.dart`. Tombstones, `sortKey`,
  the covered-total "null, never zero" rule, the VAT bases, the provisioning plan.
- **The four exports keep printing exactly what they print today** (`quote`, `financing plan`,
  `cash journal xlsx`, `financial report`). They read the model, not the UI. An agent must *verify*
  this rather than assume it — an export that reaches into a view's own labels has to be untangled
  before that view moves.
- Every dialog: entry, commitment, resource, revenue, share, allowance, element picker. They are
  reached from new places and opened prefilled; they are not rewritten.
- `OcptConfirmDialog` for every irreversible action, opened by the page. Withheld-not-disabled
  under a previewed version. No manager, service or util ever sees a `Tr`.

### 4.2 The view model

`OcptBudgetCentreView` (seven values) is replaced by `OcptBudgetDocument` (three: `expenses`,
`resources`, `sharing`) plus, per document, a **reading**: `byTree` or `byDate`. The chronological
journal is not a place, it is the same document ordered by date — debits under expenses, credits
under resources.

The stored last-view preference has to be migrated: a persisted `cashJournal` becomes
`expenses` + `byDate`, `committed` and `costTracking` become `expenses` + `byTree`, `financing`
becomes `resources`, `dashboard` becomes `expenses`, `regie` becomes the régie sub-page.

Selection grows a type. Today `selectedPosteId` names a poste; the fiche needs to name any of
poste, quote line, commitment, entry, resource, revenue, receipt. One sealed
`OcptBudgetSelection` in `lib/types/`, carried by the state, is the shape.

`filterPosteId` survives, scoped to the current document. It earns its keep in the `byDate`
reading, where there is no tree to expand.

### 4.3 The widgets

- `ocpt_budget_cost_tracking.dart` becomes the expenses tree; `ocpt_budget_committed_spending.dart`
  and `ocpt_budget_cash_journal.dart` dissolve into it (their rows become sub-rows and their
  `byDate` reading), keeping their column widths and their sideways-scroll floors.
- `ocpt_budget_financing.dart` becomes the resources tree and absorbs the revenues list out of
  `ocpt_budget_sharing.dart`.
- `ocpt_budget_poste_inspector.dart` becomes the polymorphic fiche.
- A new capture band widget, shared by expenses and resources, taking its suggestion as a resolved
  labels object so it never sees a `Tr`.
- `ocpt_budget_dashboard.dart` dissolves: its alerts become a band on each document, its totals
  become the bands already drawn, its "what feeds this budget" links move to the régie page and to
  the expenses empty state.
- `ocpt_budget_regie.dart` keeps its content and moves to a sub-page of expenses, reached by the
  breadcrumb.
- `ocpt_budget_header.dart` loses four controls and gains a breadcrumb.

That is roughly 18 000 lines of budget UI touched. The milestones below are cut so the app is
usable and every gate is green at the end of each.

### 4.4 The one schema change

`Coût final` = paid + committed + **estimate to complete**, and the variance is read against it.
Derived as `max(0, quote − paid − committed)`, the estimate to complete makes the final cost equal
the quote until a poste goes over, which reduces the column to a restatement of the variance. A
real cost report has a human adjust it.

So: one nullable `estimateToCompleteCents` on `budget_postes`. Null means "derive it", and the cell
prints the derived figure in grey; a typed value prints in ordinary ink. It is held **per poste,
not per quote line**: a line-level estimate is a second plan running beside the quote, which is
more machinery than a film of this size needs.

That is one schema number allocated **at merge time** (ADR 0007), one migration step, and the
column reaching `OcptProjectVersionCodec`'s payload, its `contentDigest`, its `_payloadFromJson`
and a `_payloadUpgrades` step, together.

## 5. Milestones

Each ends with the nine verification gates green and a user checkpoint. Each is a Sonnet 5 agent's
brief; the main session reviews before the next starts.

### M1 — The rules, where they can be tested without an interface

- `ocptBudgetEstimateToCompleteCents`, `ocptBudgetFinalCostCents`, `ocptBudgetVarianceCents` in
  `lib/utils/`, pure, obeying the tax-basis and covered-total rules the existing totals obey.
- `ocptBudgetMatchSuggestionsOf` in `lib/utils/ocpt_budget_match.dart`: given a draft movement —
  direction, amount, date, wording — it ranks what that movement could settle among the
  commitments still owed, the resources still to come, the revenues still expected and the
  defrayals still unpaid. Exact amount first, then date proximity, then wording. Pure, no `Tr`, and
  it returns *why* it matched so the band can say it in words.
- The schema change of §4.4, its migration, its codec step, its migration-test row.
- The two new columns added to the existing quote table, and the ability to type an estimate to
  complete on a poste. Nothing else moves yet, so the change is visible and reviewable on its own.

### M2 — Three documents, one navigation

- `OcptBudgetDocument`, the reading switch, the sealed selection, the preference migration.
- The header rebuilt: three chips, a breadcrumb, contextual controls, the alerts band.
- **Every existing view keeps rendering unchanged inside its new home.** This milestone moves
  doors, not rooms, so the app stays fully usable while the trees are built.

### M3 — The capture band

The daily gesture, delivered before the documents it sits on are rebuilt, because it is what the
mode is used for.

- The band at the top of expenses and of resources: direction, amount, name, date, save.
- The suggestion under it, from M1's rule, with its one-click accept, its `Autre chose…` that opens
  the entry dialog prefilled, and its dismissal.
- The band is withheld whole under a previewed version.

### M4 — The expenses tree

- Expansion state in the bloc, keyed by object id, surviving a rebuild.
- Commitments and entries as sub-rows under their line, with their badges and their own menus.
- The `byDate` reading of expenses, replacing the cash journal's debit half, voucher numbers and
  all.
- The cash projection that lived in the planned-outgoings view re-homed to the alerts band.

### M5 — The fiche

- One dock panel, polymorphic on the selection: breadcrumb, stepper, figures, outstanding amount,
  one primary action, two secondary.
- Every object type answered: poste, quote line, commitment, entry, resource, revenue, receipt.
- The primary action always writes through the dialog that already exists, **prefilled with the
  amount** — this, with M3, is what ends the double typing.

### M6 — The resources tree

- Three families, resources and revenues in one document, receipts as sub-rows.
- The `Dossier` column, the coverage band, the valued-contribution rule.
- Revenues leave the sharing view; sharing keeps only the split of what has come in.

### M7 — What is left over

- The régie as a sub-page of expenses, reached by the breadcrumb, its content untouched.
- The dashboard dissolved, its parts placed as §4.3 says.
- The sharing document reduced to contributions and shares.

### M8 — The words and the record

- The help panel rewritten: its two-by-two matrix described a navigation that no longer exists.
- `docs/architecture/budget.md` rewritten in every section the milestones invalidate, and this plan
  deleted, as `CLAUDE.md` requires once a step ships.
- The ARB sweep: roughly 500 budget keys, of which the chip, title and empty-state families are
  renamed or removed. Both files, both languages, `dart run intl_utils:generate` after.
- The README screenshots of the budget mode retaken with `tool/screenshot-app.sh`.

## 6. Decisions taken

Answered by Benoit before M1 started. All three go the way the sections above propose, so §4.4
and §4.3 stand as written.

1. **The estimate to complete** — *typed, with a derived default*, as §4.4 recommends: one nullable
   `estimateToCompleteCents` on `budget_postes`, null meaning "derive it". A derived-only column
   would have made `Coût final` a restatement of `Écart`.
2. **The dashboard** — *dissolved*, as §4.3 proposes: its alerts become a band on each document,
   its totals the bands already drawn, its "what feeds this budget" links move to the régie page
   and to the expenses empty state. Three documents, not four.
3. **The régie** — *a sub-page of expenses*, reached by the breadcrumb, its content untouched.

### One correction M1 uncovered

`ocptBudgetVarianceCents` **already exists** in `lib/utils/ocpt_budget_totals.dart`
(`paid + committed − quote`) and is read by the alerts and by the financial report PDF, which §4.1
says must keep printing exactly what it prints today. M1 therefore **adds** the final-cost reading
under its own name rather than redefining that one; both live side by side, and M8 records the two
in `docs/architecture/budget.md`.
