<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Budget mode — back to the shell design's own shape

This document is the implementation strategy for putting the budget mode's navigation back on the
shape the validated shell design draws, and for closing the two access defects the last rework
opened. It is written for the Sonnet 5 agents that will build it, orchestrated and reviewed by the
main session, with a user checkpoint between each milestone. **Read the repository `CLAUDE.md`
first** — this plan assumes its architecture, ways of working, coding standards, licensing rules
and verification gates, and does not repeat them.

**Nothing in the data model changes.** No table, no column, no migration, no schema number, no
codec step. Every rule `docs/architecture/budget.md` records about what a figure *means* still
holds; what changes is where the user meets it, and — for the two defects of §4 — whether they can
reach it at all.

The screens this plan restores are the ones in the Claude Design project **OpenCineProdTools design
shell** (`5bc089e5-85ae-42c2-b8c4-445abc90ecf4`), file `OpenCineProdTools App Design.dc.html`,
budget mode. §3 restates them in words so no agent has to open the file.

---

## 1. Why this step exists

The budget mode's UX rework shipped whole, on a plan its author approved. Reviewing the built
result, Benoit does not recognise the mode the shell design proposed, and named three things.
Verification against the code found all three, one of them a defect that loses a record:

1. **A movement naming nothing is unreachable.** The capture band always writes an entry naming no
   poste, resource, revenue or share (`budget_mode.dart`'s own `onEntryCaptured`). A **debit** so
   written shows in the expenses tree only inside the aggregate, unclickable `Hors devis` row, and
   is reachable only after switching the reading to `byDate`. A **credit** so written is drawn
   **nowhere**: the `byDate` reading keeps debits alone, and the resources tree keeps credits
   naming a resource or a revenue alone. It cannot be edited or deleted, and the resources document
   starts the band on the credit direction, which makes it the easy case to produce, not the exotic
   one.
2. **The capture band has no full door when nothing matches.** `Autre chose…`, which opens the
   prefilled entry dialog, is drawn on the suggestion row alone. With no suggestion the only
   affordance is `Save`, under a hint reading *"Il n'y a rien d'autre à remplir"* — which is how
   defect 1 gets produced by an ordinary gesture.
3. **The shape.** Seven sibling views became three chips plus two sub-pages behind a 16 px chevron,
   the dashboard was dissolved, and the mode has no left dock.

The three decisions recorded in the retired plan's own §6 — the dashboard dissolved, the régie a
sub-page, three documents rather than seven views — are **reversed by their author, having seen
them built**. That is the whole of the argument for this step; no new one is needed, and this plan
does not relitigate them.

One correction this plan carries: `docs/architecture/budget.md`'s own "The mode's own shape"
states *"There is no left dock, the mockup showing none"*. **The shell design draws one**, headed
`Postes du devis`, for the budget mode as for every other. That sentence is wrong and its
conclusion with it.

## 2. What does not change

Stated first, because it is most of the code, and because it is the boundary of this step. The
rework produced a great deal that is better than what the shell design drew, and **none of it is
given back**:

- **The nesting trees.** `OcptBudgetCostTracking` keeps its poste → line → commitment/entry
  nesting, `OcptBudgetFinancing` its family → resource → receipt nesting, both with
  `expandedNodeIds`. The shell design's own cost view is a flat poste table with the lines in the
  dock; the tree is strictly the better reading and it stays.
- **The polymorphic fiche** (`OcptBudgetFiche`), the sealed `OcptBudgetSelection`, and every
  selection wired into it.
- **The capture band**, its suggestion rule (`ocptBudgetMatchSuggestionsOf`) and its one-click
  accept — §4.2 only gives it back its full door.
- **The estimate to complete**, the final cost, the two variances, and the schema column they were
  given.
- Every service, every rule in `lib/utils/ocpt_budget_*.dart`, every dialog, the four exports, the
  alerts rule, the resources coverage rule, the provisioning plan, the help panel's content.
- `OcptConfirmDialog` for every irreversible action, opened by the page. Withheld-not-disabled
  under a previewed version. No manager, service or util ever sees a `Tr`.

## 3. The design, in one page

**Seven chips, in one row, in the shell design's own order**: `Tableau de bord` · `Suivi de coût` ·
`Financement` · `Trésorerie` · `Engagé` · `Régie` · `Partage`. The design draws an eighth, `Export`;
it stays where the app's standing rule puts it, in the toolbar's own `Export` control, and is not
restored as a chip.

**The breadcrumb, the sub-page menu and the reading switch go away with the shape that needed
them.** A view is a place again; the chronological journal is `Trésorerie`, a place, not a reading
of another document.

**A left dock, `Postes du devis`.** One card per poste: its code (detailed reading only), its name,
a two-tone bar of paid then committed against the quote, `total / devis`, and the consumed
percentage in the strain colour `ocptBudgetPosteStrainOf` already answers. A `Tout` link clears the
filter while one is set. Under the list, a four-line footer: `Devis`, `Payé`, `Engagé`, `Reste`.

**Clicking a card selects the poste and narrows nothing** (§6, decision 3). It opens the fiche and
highlights the card, exactly as a row of the expenses tree already does; narrowing every view of
the mode to one poste stays a gesture that says so, offered on the card's own `⋮` menu
(`Ne montrer que ce poste`) and cleared by the `Tout` link. The design draws the two as one gesture;
the rework's argument against it is the better one, and it is the reading kept — a click meant as
"let me look at this" must not silently narrow views the reader is not looking at.

**The dashboard comes back as the mode's default view**: four KPI tiles (`Devis total`,
`Financement acquis`, `Dépensé`, `Solde en banque`), the two-bar `Équilibre du budget` band
(needs split paid / committed / left to spend, resources split received / to receive / in kind),
the standing alerts, `Postes les plus tendus`, and `Ce qui alimente ce budget`.

**The alerts live there and nowhere else** (§6, decision 4), the header's own alerts band going with
the shape that needed it — but a mode whose warnings are on one page must still say so from the
other six, so the `Tableau de bord` chip carries a **count badge** of the standing alerts wherever
the reader is. The badge is a number, not a dot: two overspent postes and one strained balance are
not the same news as one. It is withheld, not drawn empty, while `ocptComputeBudgetAlerts` answers
none.

**`Trésorerie` is the whole journal again**: debits **and** credits, columns `Date`, `Pièce`,
`Libellé`, `Poste`, `Débit`, `Crédit`, `Solde`, the balance running down the rows, and the
whole-journal debit/credit/balance totals over the table. This is what closes defect 1: every
entry the project holds is drawn in exactly one place that lists all of them, whatever it names.

**`Engagé` gets its cash projection back**, in its own right-hand column beside the commitments,
where the design draws it and where `OcptBudgetCommittedSpending` had it before the rework re-homed
it to the header's alerts band.

## 4. The two access defects

They are defects, not design, so they ship **first** (M1), before anything moves.

### 4.1 Every entry is reachable

`OcptBudgetCashJournal` lists every live entry, credits included, in one chronological table with a
running balance — its pre-rework reading, which the `byDate` milestone narrowed to debits. Its
`Poste` cell prints `budgetCashJournalNoPosteLabel` for an entry naming none, as it already does,
and every row keeps its `⋮` menu (edit, delete through `OcptConfirmDialog`) and its selection into
the fiche.

The expenses tree's `Hors devis` row keeps being a reading rather than a record — it mints no id,
so it is still not selectable and still carries no `⋮` — but it gains a twisty, opening on the
poste-less **debits** it sums, each an ordinary entry sub-row with the menu and the selection every
other entry sub-row already has. A reader who lands on the total can reach what makes it up without
knowing another view exists.

### 4.2 The capture band always offers the full door

`Autre chose…` is drawn whenever the draft reads as saveable, whether or not a suggestion was
found, beside `Enregistrer` rather than only on the suggestion row. The band's own
no-suggestion hint is reworded: it currently claims there is nothing else to fill in, which is
false — the poste, the VAT, the receipt and what the movement settles are all still unset, and
saying so is what stops a user creating an off-quote record without meaning to.

## 5. Architecture

### 5.1 The view model

`OcptBudgetDocument`, `OcptBudgetDocumentReading` and `OcptBudgetSubPage` are replaced by one
`OcptBudgetView` in `lib/types/`, seven values, in chip order. The retired
`lib/types/ocpt_budget_centre_view.dart` (at `f34e0ff6^`) is the shape to start from: it carried
this enum, `ocptBudgetCentreViewHonoursPosteFilter` and its inspector predicate, and its argument
for each is unchanged by anything that has landed since. It comes back with `costTracking` and
`cashJournal` as two of seven values rather than a `Planned` pair, and with the régie in the list.

`OcptBudgetState.document`/`reading`/`subPage` collapse to one `view` field; `selection`,
`filterPosteId`, `expandedNodeIds`, `isSimplified` and `taxBasis` are untouched. **No stored
preference points at a view** — none of these five is persisted — so there is no migration to
write, only a `budgetLeftDockFraction` key to add beside the four modes that already have one.

### 5.2 The header

The header keeps its title and subtitle, **loses its alerts band** to the dashboard (§3), and swaps
its controls: one seven-segment view switch in place of the document and reading switches, then the
simplified switch, the tax-basis switch and the poste filter as today. The filter **stays in the
header** rather than moving into the dock with the gesture that sets it: a dock is collapsible, and
a mode narrowed to one poste with nothing on screen saying so is the silence this mode refuses
everywhere else. The dock's own card menu and this control write the same `filterPosteId`.

The view switch carries the alert badge on its `Tableau de bord` segment. The header's own title
threshold is recomputed for the new set — the switch grows to seven segments, one control leaves —
and the wrap fallback stays, minus the breadcrumb that no longer exists.

### 5.3 The left dock

A new `ocpt_budget_poste_dock.dart` widget, purely presentational, reporting both gestures upward
through two callbacks — `onPosteSelected` and `onPosteFilterRequested` — so the mode stays the one
place that decides what each writes. The mode passes it through `OcptWorkspaceShell.leftPanel` with
the fraction persisted, exactly as the four modes that already carry one do. Every figure it draws
already exists: `ocptBudgetPosteStrainOf`, `ocptBudgetQuotedTotalCents`, the paid and committed
maps, `ocptBudgetProjectQuotedTotalCents`.

**The dock is drawn on every view, including the three with no poste dimension** (financement,
régie, partage): it is the mode's standing reading of where the quote stands, not a control that
belongs to one page. Its `Ne montrer que ce poste` entry is withheld — not disabled — on those
three, since there is nothing there for a poste to narrow.

### 5.4 The dashboard

`ocpt_budget_dashboard.dart` and its test are restored from `c229f4ae^` — 664 and 571 lines that
were deleted whole, not dispersed — and then reconciled with what has landed since: it must read
`OcptBudgetFeedCard` rather than its own inlined copy of that card (`c72fe6c1` extracted it), read
the régie day count the way `28a935ba` left it. It takes the alerts back from the header, which is
where the restored file already drew them, so nothing about them has to be rebuilt — only the
header's own copy deleted and the chip badge added. The ARB keys `b5114f0e` dropped come back with
it.

### 5.5 What moves back, and what it costs

`OcptBudgetCommittedSpending`, `OcptBudgetRegie` and `OcptBudgetCashJournal` change **no content**:
each is routed from a chip instead of a sub-page or a reading. The projection returns to the
committed view's own right column. The whole of this step is roughly 6 000 lines of budget UI
touched, against the 18 000 the rework moved.

## 6. Milestones

Each ends with the nine verification gates green and a user checkpoint. Each is a Sonnet 5 agent's
brief; the main session reviews before the next starts.

### M1 — The two defects

§4, on the shape as it stands today. Shipped first and alone, so a fix that loses no record is not
waiting behind a navigation rework: the journal lists every entry again, the `Hors devis` row opens,
`Autre chose…` is always offered, the hint stops claiming there is nothing else to fill in.

### M2 — Seven views

`OcptBudgetView`, the state collapse, the header's view switch, the breadcrumb and sub-page menu
deleted, every existing view widget routed from its own chip and rendering exactly as it does
today. The mode is fully usable at the end of this milestone, with six views; the dashboard chip
lands in M4.

### M3 — The left dock

The dock, its fraction key, its two gestures — a click that selects, a `⋮` entry that filters — and
the `Tout` link. The header's poste filter stays and is written by both. The three views with no
poste dimension (financement, régie, partage) withhold the filter entry rather than pretending to
honour it, exactly as `ocptBudgetCentreViewHonoursPosteFilter` already argues.

### M4 — The dashboard

§5.4, plus the `Tableau de bord` chip as the mode's default view, plus the alert badge on that chip
and the header's own alerts band deleted, plus the cash projection back beside the commitments.

### M5 — The words and the record

The help panel's own map of the mode, `docs/architecture/budget.md` rewritten in every section this
plan invalidates — "The mode's own shape" first, including the false sentence of §1 — the ARB sweep
across both files, the README screenshots retaken with `tool/screenshot-app.sh`, and this plan
deleted, as `CLAUDE.md` requires once a step ships.

## 7. Decisions taken

Answered by Benoit before M1 started. All four are folded into the sections above, which stand as
written.

1. **The trees** — *kept, nested*, against a shell design that draws a flat poste table with the
   lines in the dock (§2). The chain devis → engagement → paiement is legible on screen only in the
   tree, and it is what lets the `Hors devis` row of §4.1 open on the entries it sums.
2. **The takings** — *left in the resources tree*, where `14d01844` put them, rather than back in
   `Partage` as the shell design draws them. `Partage` keeps the split of what has come in, and
   nothing about this milestone touches either.
3. **The dock's click** — *selects only* (§3). Narrowing stays an explicit gesture on the card's own
   `⋮` menu, and the filter control stays in the header so a collapsed dock never hides the fact
   that the mode is narrowed.
4. **The alerts** — *on the dashboard, with a count badge on its chip* (§3, §5.2, §5.4). The
   header's standing alerts band goes; the badge is what keeps the news reachable from the other
   six views.
