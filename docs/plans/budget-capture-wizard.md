<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Budget capture — one button, one wizard, one way of counting

This document is the implementation strategy for the budget mode's capture rework. It is written
for the Sonnet 5 agents that will build it, orchestrated and reviewed by the main session, with a
user checkpoint between each milestone. **Read the repository `CLAUDE.md` first** — this plan
assumes its architecture, ways of working, coding standards, licensing rules and verification
gates, and does not repeat them. Read
[`docs/architecture/budget.md`](../architecture/budget.md) next: it describes the mode as it stands
today, and this plan says what changes in it.

The screens were designed and validated with Benoit as mockups before any code was written. When
this plan and the mockups disagree, ask rather than choose.

---

## 1. Why this step exists

The budget mode works, and its shape is wrong in three ways a user runs into within a minute.

**There are nine doors that create things, and no two look alike.** A page carries a capture button
in its header *and* a creation footer under its table; nothing on screen says that one records money
that moved and the other plans money that has not. A user reads them as duplicates, picks the
wrong one, and finds a form asking `Ressource ?` — the name of a database table, offered with no way
to create one when none exists yet.

**Two documents out of five cannot say how much has actually been paid.** A financing resource, a
taking and a sharing participant all answer that question the same way: by adding up the journal
entries that name them, with no stored counter to keep in step. A commitment does not — it carries a
link to *one* settling entry, so an order cannot be paid in two instalments and a deposit has
nowhere to live. A defrayal is worse: nothing links it to anything, so it can never be marked paid,
and the reconciliation strip offers it forever while doing nothing but copying its wording.

**A poste's fiche lies.** It draws the `Estimated → Committed → Paid` chain a quote line uses to show
a real lifecycle, with all three steps lit in hard code. A poste created ten seconds ago, with
nothing quoted and nothing spent, reads `Paid` in bold.

## 2. The design in one page

Restated so an agent has it in front of them. Every line below is a decision already argued and
taken; none of it is open.

### One button

`+ Nouveau` (`+ New`), the same label in the same place on all five routes, including the dashboard
and the cash-flow page which carry none today. It opens the wizard's step 1. **Every creation
footer disappears except `+ Poste`**: a poste is a container that carries no money of its own, and
Benoit keeps it as a control of its own. The wizard's list is complete whatever the route, and the
current route's own gestures are moved to the top with the first one pre-selected — one click for
the frequent case, everything else one scroll away.

Contextual shortcuts stay exactly as they are — a row's `⋮`, a fiche's action — and go on opening
the wizard with what they already know filled in, skipping the steps that answer.

### Step 1 — grouped by document, not by intent

Five headings, each carrying one line that states its tense. The tense is what tells
`J'ai encaissé un financement` apart from `Inscrire une subvention attendue`: the first is past and
first-person, the second is an infinitive about something that has not happened.

| Heading | Its line | Answers |
| --- | --- | --- |
| Le devis | Ce que le film va coûter, poste par poste | a quote line, lines from the breakdown, commit a spend |
| L'argent qui a bougé | Ce qui est déjà entré ou sorti du compte | the six money movements, plus reimbursing somebody |
| Le plan de financement | Ce qui est promis, et pas encore arrivé | a subsidy, a contribution, an expected taking |
| Les défraiements | Ce que la production doit aux personnes | defray somebody |
| Le partage des recettes | Qui touche quoi sur ce que le film rapporte | a participant |

**Every answer carries its own hint line**, not only the complex ones. Those sentences are what a
first-time reader actually reads; they are part of the deliverable, not decoration.

### Steps 2 and 3 — depth follows the gesture

Step 2 asks what the movement attaches to, in the words of the answer picked, showing the figures
needed to choose (a resource states promised, received and outstanding) and offering to create the
missing object in place. Step 3 is the money. A gesture that has nothing to attach to has no step 2,
and **the step counter says so** — `Étape 1 sur 2` where that is the truth.

Step 3 uses **one label idiom throughout**: the label above, the field dense, the way the sheets
already do. Today the row mixes an external label over a dense `InputDecorator` (`Date`), a floating
internal label on a normal field (`Montant`) and a bare external label (`Base`), which is the whole
reason nothing lines up. `OcptPersonSheetDateField` is **not** to be touched: the resources mode uses
it too, and the fix stays inside the wizard.

### The lettrage

The reconciliation strip gets its trade name — *lettrage*, what an accountant calls matching a
payment to what it settles; *rapprochement* is reserved for comparing a bank statement to the
ledger. Three changes: its title says what accepting will **do**, each offer carries the reasons it
was ranked (same amount, same day, a shared word), and **the other candidates are reachable,
`Aucun` included**. Proposing without allowing a different answer is being wrong in silence.

### One way of counting

The mode already knows how to say what has arrived on a financing resource, a taking or a
participant: it **adds up the entries that name them**, and stores no counter. Two documents escape
that pattern, and they are exactly the two that cannot express what users ask for.

| Document | The question | How it is answered today |
| --- | --- | --- |
| Financing resource | how much has been received | sum of entries |
| Taking | how much has been cashed in | sum of entries |
| Sharing participant | how much has been paid out | sum of entries |
| Commitment | how much has been paid | **one stored link — so one payment only** |
| Defrayed person | how much is still owed | **nothing at all** |

Aligning the last two on the first three yields, in one move: a commitment paid in instalments, a
person reimbursed in part, one transfer covering several defrayals, and the disappearance of any
need for several commitments on one quote line. **A quote line keeps exactly one commitment**, and
its `Estimated → Committed → Paid` chain keeps meaning what it means.

### The other corrections

- The poste fiche loses the lifecycle chain and gains a **proportion bar**: paid then committed over
  a track of fixed width, the overrun eating the end of the track in red, a tick marking where the
  quote fell. Fixed width so two postes stay comparable when the bar later appears in a list.
- **`Reste à engager` names two different things in French today** — a poste's estimate to complete
  and a line's still-to-commit — where English tells them apart. The poste's becomes
  `Reste à dépenser (estimé)`; the line keeps `Reste à engager`.
- A **duplicate poste code is signalled, never blocked**: the field turns red under an inline edit
  that saves as you type, and the typed value is kept.
- The twisty is 20 × 20 where the theme's own floor for an icon button is 28. It becomes **28 wide
  over the full row height**, in both tables that draw one. The same constant reserves the alignment
  gutter for rows with nothing to expand, so every label column shifts 8 px right.
- The English `cash journal` becomes **`cash book`**, the `en_GB` term for a chronological record of
  receipts and payments with a running balance. The French already says *journal de trésorerie* and
  is correct. Only user-visible strings and ARB descriptions change; the Dart identifiers and ARB
  key names stay.

## 3. What must not be re-decided

- `+ Poste` keeps its own footer control. It is the only exception.
- A quote line carries at most one commitment.
- A reimbursement is never split across individual defrayals. Ticking defrayals in the wizard
  **computes an amount**; what is stored is a sum paid to a person on a date.
- The overrun bar keeps a fixed width.
- Contextual shortcuts survive and pre-fill.
- The régie's defrayal table becomes a tree grouped by person, not a summary band above a flat list.
- Under a read-only preview an affordance that writes is **withheld, not disabled**.

## 4. Milestones

Each milestone ends green on all nine verification gates and stops for Benoit.

### M1 — the ledger reads one way

No user-visible change. This milestone exists so every later one can assume the counting works.

- `budget_entries` gains two nullable links: `commitmentId` → `budget_commitments`, and `personId` →
  `people`. Both read exactly as `resourceId`/`revenueId`/`shareId` already do — most entries name
  neither, which is a fact rather than an unfinished pick.
- `budget_commitments` loses `settledEntryId`.
- The drift migration carries the data over: every commitment that named a settling entry writes
  `commitmentId` on that entry before the column goes. The migration test is what proves the fold
  correct — it already pins what `onCreate` produces against every upgrade path, and that property
  must hold.
- `OcptProjectVersionCodec` moves to the next payload format together: the commitment payload loses
  its settled-entry key, the entry payload gains two, and `contentDigest` and `_applyPayload` change
  in the same commit as the payload itself.
- We are in alpha and no stable release has ever put this schema on anybody's disk, so **no path
  needs carrying forever** — see [issue 60](https://github.com/borlnov/open_cine_prod_tools/issues/60),
  which states that rule and owns the eventual squash. Do not implement the squash here.
- New pure helpers in `lib/utils/`, tested directly, no Flutter import:
  - what a commitment has been paid, and what it still owes;
  - what a person has advanced, been reimbursed, and is still owed.
- `OcptBudgetCommitment.isSettled` stops reading a stored link. Every caller that asked whether a
  commitment was settled now asks whether its outstanding amount has reached zero. **Find them all**
  — the cash-flow page's upcoming section, the projection, the line fiche, the alerts, the exports.

### M2 — one button, one wizard

- A new type in `lib/types/` names the fifteen answers and their five families, and says for each
  what it attaches to and how many steps it takes. `OcptBudgetEntryNature` stays what it is — the
  nature of a *movement* — and the new type wraps it for the six answers that are movements.
- Step 1 is rebuilt as the grouped list; step 2 is new; step 3 is the existing form with one label
  idiom and the renamed lettrage band.
- Inline creation from step 2 for every object that can be missing: a financing resource, a taking,
  a participant. The taking already has this and is the precedent to follow.
- The header exposes one button on all five routes. The resources footer, the sharing creation
  action and the poste fiche's `Ajouter`/`Depuis le dépouillement` are removed, their gestures now
  reached through the wizard. `+ Poste` stays.
- The breakdown selector is the one step that creates several rows at once, so its button counts out
  loud (`Créer 3 lignes de devis`) and the quantity it proposes comes from the number of scenes —
  a suggestion that is corrected in the table, exactly as a mileage scale suggests a defrayal.

### M3 — the surfaces the wizard feeds

- The poste fiche: proportion bar, no lifecycle chain, `Reste à dépenser (estimé)` with a sentence
  saying what typing it changes.
- The duplicate poste code, signalled.
- The twisty, in both tables.
- The line fiche and the expenses tree learn to draw a commitment's own payments, and the pay action
  offers the outstanding amount rather than the total.

### M4 — the régie holds a running account

- The defrayal table becomes a tree grouped by person: a person row carrying advanced, reimbursed
  and still-owed, expanding onto their defrayals and their reimbursements, over a total row — the
  grammar the expenses and resources tables already speak.
- A defrayal that names nobody is a legitimate row and stays a group of one; it counts against the
  quote and against no running account.
- `Rembourser quelqu'un` is wired end to end, including the partial amount capped at what is owed.

### M5 — the record

- The ARB sweep across both files, chips, hints and `@`-descriptions included, and `cash book`.
- The help panel re-keyed and rewritten: it currently describes a two-step form and a capture band
  that no longer exist.
- `docs/architecture/budget.md` rewritten in every section this plan invalidates.
- Screenshots retaken with `tool/screenshot-app.sh`, seeding the demo project through
  `test/seed_demo_project.dart`, and the README's budget block updated.
- This plan deleted, as `CLAUDE.md` requires once a step ships.
