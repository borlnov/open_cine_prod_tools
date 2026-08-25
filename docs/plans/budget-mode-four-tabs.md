<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Budget mode — four tabs, two of which do not work

This document is the implementation strategy for putting the budget mode on the four-tab shape its
mockup draws, and for replacing the entry dialog with a two-step wizard. It is written for the
Sonnet 5 agents that will build it, orchestrated and reviewed by the main session, with a user
checkpoint between each milestone. **Read the repository `CLAUDE.md` first** — this plan assumes its
architecture, ways of working, coding standards, licensing rules and verification gates, and does
not repeat them.

## 1. The mockup is the authority, and you must open it

The last rework of this mode failed for one reason worth stating before anything else: its plan
restated the screens in prose so that no agent would have to open the design file, the agents built
the prose, and the prose had drifted from the mockup — it even named the wrong file. **This plan
does not describe the screens. It points at them, and every agent opens them.**

Two files, in the Claude Design project `3e7df5f5-23d6-48d5-bce9-35067267bf0c`:

| File | Governs |
| --- | --- |
| `Budget UX 2b - la forme du mode.dc.html` | the four tabs, the tools drawer, the dashboard, the filter tag, the two-step entry wizard |
| `Budget UX 2a - les deux onglets.dc.html` | the two tables themselves: row grammar, unfolding, the six cost columns, the right-dock fiche, status-versus-money on Resources, no tax-basis switch on what comes in |

`2b` opens with a section stating exactly where it supersedes `2a` (the chip band and the
breadcrumb) and where it does not (everything else). Read `2b` first, then `2a`.

The older project `5bc089e5-85ae-42c2-b8c4-445abc90ecf4`
(`OpenCineProdTools App Design.dc.html`) is **not** an authority for this mode any more. Its budget
screens are the eight-tab shape this work exists to leave behind. Do not open it for guidance.

## 2. Most of what you would be tempted to rebuild is already right

Verified against the code on 2026-08-25, before this plan was written:

- **The expenses table already carries the mockup's columns.** `budgetCostTrackingColumn*` already
  reads `N°`, `Poste`, `Devis`, `Engagé`, `Payé`, `Reste`, `Coût final`, `Écart`. Nothing to add.
- **The expenses tree already nests poste → line → commitment/entry**, with `expandedNodeIds`.
  The mockup's third level exists.
- **`Hors devis` already exists as a synthetic row**, last in the table, with its own twisty, its
  own children, and its total already folded into the table's own `Payé` total
  (`_ocptCostTrackingOffQuoteNodeId`, `_OcptCostTrackingOffQuoteIdentityRow`). No table row, no
  migration, no schema number: "not deletable, not renamable" costs nothing because there is
  nothing to delete or rename.
- **The régie already provisions the quote**, one line per nature
  (`lib/types/ocpt_budget_provision_kind.dart`, `budget_lines.provisionKey`), and defrayals are
  already typed by hand into `budget_allowances`. It is already the utility this plan calls it.
- **The revenue sharing already stores no money of its own** — `lib/utils/ocpt_budget_shares.dart`
  reads the journal on both sides.

**Nothing in the data model changes.** No table, no column, no migration, no schema number, no
codec step. What changes is where the user meets a figure, and how they type one.

## 3. The one thing the mockups do not settle

**Where the cash projection goes.** `lib/utils/ocpt_budget_projection.dart` is drawn today in the
committed view's right column, and the committed view is being deleted. The mockup draws it
nowhere.

**Recommendation to confirm at the M2 checkpoint: the tools drawer's cash-flow page**, under the
statement — the account's future directly under the account's past, read from the same commitments
the expenses table already shows. The alternative is the dashboard, which is defensible but makes a
read-only summary carry a forecast nobody asked it for. **Do not build either until Benoit has
answered.**

## 4. The shape to build

Four chips, in this order, and no left dock at all:

| Chip | Was | Nature |
| --- | --- | --- |
| `Tableau de bord` | the dashboard, reduced | read-only |
| `Dépenses` | the cost tracking, plus what `Engagé` used to hold | working surface |
| `Ressources` | the financing plan | working surface |
| `Outils` | a drawer: `Flux de trésorerie · Régie · Partage` | helpers |

The drawer's rule, which decides what may ever join it: *a tool never stores money of its own —
either it computes something that lands elsewhere, or it re-reads what is already written.* A
candidate that fails this test is a document and takes its own chip.

The types this implies:

```dart
enum OcptBudgetView { dashboard, expenses, resources, tools }

enum OcptBudgetToolsView { cashFlow, regie, sharing }
```

Both are held in memory for the life of the mode and written to no preference, so a value may be
inserted at any position — the rule `OcptBudgetView`'s own doc comment already argues. Rename
`costTracking` → `expenses` and `financing` → `resources` as part of this: the mode's own record is
harder to read when the enum and the chip disagree, and this session lost a day to exactly that
kind of disagreement.

`ocptBudgetViewHonoursPosteFilter` becomes true for `expenses` alone.
`ocptBudgetViewHasInspector` becomes false for `dashboard` alone — the cash-flow page selects an
entry, the régie a defrayal, the sharing a participant.

The tax-basis switch is drawn on `dashboard`, `expenses` and `tools › cashFlow`, and nowhere else —
read it off the mockup's own bands rather than off this sentence.

## 5. Milestones

Each milestone ends green on all nine gates and stops for Benoit.

### M1 — the four chips and the drawer

`OcptBudgetView` and `OcptBudgetToolsView` as above; the header's chip row; the drawer's own
segmented control drawn as a second `.seg`, never a chevron or a menu. **The left dock
(`OcptBudgetPosteDock`) is deleted**, and `budgetLeftDockFraction` with it — the mockup draws no
left dock, and the sentence in `docs/architecture/budget.md` claiming the mockup drew one is wrong
and goes with it. **The band's breadcrumb is deleted**; an active poste filter is announced instead
by a removable tag in the band (mockup `4d`), drawn only while a filter is set.

The cash journal moves into the drawer as `Flux de trésorerie`, **read-only**: no capture affordance
of any kind, but its rows stay selectable so the right-dock fiche keeps `Modifier` / `Supprimer`.
That is not a softening of "read-only" — it is what makes the page the only home of an entry that
names nothing, which neither Expenses nor Resources can show. Mockup `4b`.

### M2 — `Engagé` disappears

Delete `OcptBudgetCommittedSpending` and its view. Nothing of its content is lost: the commitments
are already nested under their lines in the expenses tree. Rehome `onLineShowCommitmentRequested`
(`budget_mode.dart`, `ocpt_budget_fiche.dart`), which today jumps to the committed view. Rehome the
cash projection per §3, **after Benoit has answered**.

### M3 — the dashboard, reduced

Four tiles (`Devis total`, `Financement acquis`, `Dépensé`, `Solde en banque`), the balance band,
the standing alerts. **The feed cards are deleted** — they navigate, they do not summarise. No
capture, no form. A poste row still opens that poste in Expenses: selecting is not writing.
`Dépensé` includes off-quote spending, and says so, so that it agrees with the expenses table's own
total, which already folds `Hors devis` in. Mockup `4a`.

### M4 — the capture band dies, the wizard replaces the dialog

Delete `OcptBudgetCaptureBand` everywhere. Each working surface gets one primary button instead
(`+ Saisir une dépense`, `+ Saisir un encaissement`, `+ Saisir un défraiement` on the régie).

`OcptBudgetEntryDialog` becomes two steps (mockup `5a`, `5b`):

1. **What are you doing?** — five answers, in production French, never in accounting terms. Each
   fixes the direction of the movement and the single link field that follows, so the debit/credit
   choice disappears from the form entirely.
2. **The form**, carrying one link field instead of four, and the reconciliation the capture band
   used to do: once amount and date are typed, a strip proposes what this entry settles, one click
   to accept. `ocptBudgetMatchSuggestionsOf` moves here rather than dying with the band.

Rules settled on 2026-08-25 and not to be re-decided: `Autre mouvement` offers an optional poste,
and an unanswered poste field **shows `Hors devis`** rather than staying empty, so the reader sees
where the entry lands. Editing an existing entry opens step 2 directly, its nature recalled in the
header with a link back to step 1.

The `Partage` page gains a button that pays a participant their share. It opens **this same
dialog**, pre-answered on `J'ai versé sa part à quelqu'un` — a shortcut into Expenses, not a second
capture path, so the drawer's rule holds.

### M5 — the record

`docs/architecture/budget.md` rewritten in every section this plan invalidates. The help panel
(`ocpt_budget_help.dart`) re-keyed to the four views and the three tools. The ARB sweep across both
files, chips and `@`-descriptions included. Screenshots retaken with `tool/screenshot-app.sh` and
the README's budget block updated. This plan deleted, as `CLAUDE.md` requires once a step ships.

## 6. What must not regress

- **`Hors devis` stays out of the quote export and stays in the financial report.** It is absent
  from `ocpt_budget_quote_pdf_service.dart` — correct, it is not a CNC poste — and present in
  `ocpt_budget_financial_report_pdf_service.dart`, where its total is already folded into the paid
  total. Removing it there would make the exported report stop adding up against the bank.
- **The two access defects fixed in the previous step stay fixed**: an entry naming nothing is
  reachable, and there is always a full door into the entry form.
- Every export stays reached from the toolbar's own `Export` control.
- Under a read-only preview an affordance that writes is withheld, not disabled.
