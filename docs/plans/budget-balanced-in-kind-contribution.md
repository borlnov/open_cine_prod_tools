<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# A balanced in-kind contribution — its counterpart quote line

An in-kind contribution the production is lent — a camera valued at 5 000 €, a location given for
free — is recorded today as a `budget_resources` row of kind `inKind`, valued at its figure, and
folded into the financing plan's own total (`ocptBudgetResourcesTotalCents`). The quote, meanwhile,
carries nothing in front of it. So the needs/resources balance
(`ocptBudgetNeedsResourcesBalanceOf`) reads the valuation as pure extra coverage — as if the film
had 5 000 € more to spend — which is exactly what a lent camera is **not**: it is a cost the
production will not have to pay, not cash it can spend elsewhere. The financing plan, where the
figure is printed, makes the illusion worse rather than better.

This plan closes that gap the way the CNC nomenclature already asks a financing plan to: an in-kind
contribution is **balanced**, appearing on both sides at the same figure — a resource *and* a
matching charge — so its net effect on the balance is zero. It covers exactly its own cost and
frees no cash. The mechanism is a **counterpart quote line minted from the contribution and linked
to it**, kept balanced by construction rather than by the user's discipline.

**Read [`../architecture/budget.md`](../architecture/budget.md) first** — in particular "An in-kind
contribution is valued, not collected", "The resources tree folds the takings in", "The
resources view says what covers the film, twice", "A quote line is paid directly, the commitment
made for it" (the write-two-rows-as-one precedent), "A commitment's poste is editable, a quote
line's is not" (why a line cannot change poste in place) and "The schema". This file is deleted once
the work ships and its outcome is folded into that document.

## The link, and where the single truth lives

- **`budget_lines` gains one nullable column, `inKindResourceId`**, referencing `budget_resources`,
  declared exactly as `elementId` already is (nullable, a foreign key, read by the new reading
  below). It names the in-kind contribution this line is the counterpart of; null is the ordinary
  case — an ordinary quoted line is nobody's counterpart.
- **No new column on `budget_resources`.** The poste the contribution offsets lives on the
  counterpart line (`budget_lines.posteId`), which is the single place it is stored — a `posteId` on
  the resource too would be a second copy of one truth, the very thing "A poste's quoted amount is
  not stored" argues against. A subsidy or a cash contribution offsets no poste and mints no line,
  so there is nothing to store for them either.
- **The counterpart line is app-managed, not hand-editable.** Its label, poste, amount and rate all
  follow the contribution; it carries no independent `Delete` and no editable amount field in the
  quote. Its whole lifecycle is the resource's, the same way a resource of kind `inKind` already has
  its `Receive` action withheld. This is what forecloses the double-count the manual convention
  risked: the euro is typed once, on the contribution.
- **The line's rate is frozen at 0 %** (`vatRateBasisPoints: 0`, an explicit "no VAT applies", not a
  null inheriting the project's rate). A valuation is not an invoice; freezing it at 0 % keeps
  excluding-tax equal to including-tax, so the header's HT/TTC toggle leaves the figure — and the
  balance — stable, whichever basis a reader is on.

## The wizard gains a poste, for the in-kind kind alone

- `OcptBudgetResourceFormFields` (`lib/models/`) and `OcptBudgetResourceDialog` gain a **poste
  field**, the same CNC poste picker a commitment already offers (`budget_commitments.posteId`),
  drawn **only for the `inKind` kind** — on "New in-kind contribution" while creating, and on an
  edit whenever the kind is, or has just become, in-kind. A subsidy and a cash contribution never
  show it; they offset no poste.
- On confirm, the bloc does as **one logical write** what it would otherwise leave apart: it creates
  the `budget_resources` row through `OcptBudgetFinancingService`, then mints the counterpart line
  through `OcptBudgetQuoteService.createLine` — label seeded from the contribution, `quantityMilli`
  1000, `unitAmountCents` the valued figure, `vatRateBasisPoints` 0, `inKindResourceId` set,
  `posteId` from the pick. This mirrors `OcptBudgetLinePaidDirectlyEvent` creating a commitment then
  an entry as one write ("A quote line is paid directly, the commitment made for it").

## Covered in kind — the reading

The counterpart line is a real quote line: it counts in `ocptBudgetPosteQuotedTotalCents` and
`ocptBudgetProjectQuotedTotalCents`, so the quote total — the needs side — rises by the valuation.
That, against the contribution already summed on the resources side, is what makes
`ocptBudgetNeedsResourcesBalanceOf` net to zero **by construction**: no change to that reading or to
`ocptBudgetResourcesTotalCents` is needed, the two sides simply both move.

But the line must not read as unspent cash or as a strain:

- **A new per-poste reading, `ocptBudgetInKindCoveredCentsByPosteId`** (`lib/utils/`), sums a
  poste's own counterpart lines — its "settled in kind" total, the symmetric twin of
  `ocptBudgetPaidCentsByPosteId`. `ocptBudgetRemainingCents` and `ocptBudgetPosteStrainOf` fold it in
  **alongside** paid and committed, so the counterpart line nets its own quote out: the poste shows
  no phantom remainder to spend and no false under-consumption, and — since the line adds equally to
  quote and to covered — it can never push a poste over.
- **It is never cash.** No journal entry names it, so it stays out of the `Dépensé` tile, out of
  `OcptBudgetCashTotals.balanceCents` and out of every reading over the ledger — exactly as the
  contribution itself is "promised, never received" because no cash will move for a valuation.
- **In the expenses tree** (`OcptBudgetCostTracking`) the line draws under its poste with a badge
  marking it covered in kind, its paid-in-kind figure equal to its own value and its remaining zero.

## The fiche

- **The quote-line fiche variant branches on `inKindResourceId != null`**: it withholds `Pay`,
  `Commit this line…` and `Delete` — a valuation is neither paid, committed nor deleted from the
  quote — and instead names the contribution it counterbalances, with a link across to it, marked
  covered in kind. This is the quote-line twin of the `inKind` resource's own withheld `Receive`.
- **The resource fiche** names the poste it offsets, read from the linked line rather than from a
  field of its own.

## One write manages both sides, across every edit

Every gesture on an in-kind contribution keeps the counterpart line in step, in the same write:

- **Create in-kind** → resource + counterpart line (above).
- **Revalue** → the line's `unitAmountCents` follows the new figure.
- **Rename** → the line's `label` follows.
- **Change the poste** → a quote line cannot move poste in place (`sortKey` is fractional within its
  own `posteId` — "A commitment's poste is editable, a quote line's is not"), so the write **deletes
  the line in the old poste and mints a fresh one in the new**, `inKindResourceId` re-set.
- **Reclassify `inKind` → cash or subsidy** → the counterpart line is tombstoned; the contribution
  offsets no poste any more. **Reclassify cash or subsidy → `inKind`** → a counterpart line is
  minted, which is why the dialog surfaces the poste field the moment the kind becomes in-kind.
- **Delete the contribution** → the counterpart line is tombstoned with it (never a synchronised
  hard delete — ADR 0010).

## Schema and sync

- `budget_lines.inKindResourceId` is a **synchronised column**, so it must reach
  `OcptProjectVersionCodec` in all three of its required places: `_budgetLineToJson` and
  `_budgetLineFromJson` (a new `_inKindResourceIdKey`, declared and read exactly as `_elementIdKey`
  is) and the `contentDigest` canonical rows. Add the column the way the project's current drift
  migration convention adds a nullable one, and **allocate the schema number at merge, not now**
  (ADR 0007). See [`../architecture/foundations.md`](../architecture/foundations.md) for the drift
  schema and the version codec.

## Exports

- **The financial report PDF** (`OcptBudgetFinancialReportPdfService`) reads the quote against paid
  and committed; it must read the counterpart line covered in kind — remaining zero, not an unpaid
  quoted line — so its per-poste variance stays honest, the same treatment the screen gives it.
- **The financing plan PDF** is unchanged: in-kind contributions are already kept visibly apart on
  the resources side, which is the whole point of the document for a commission.
- **The quote PDF** prints the counterpart line as the quoted line it is; whether it is flagged
  in-kind there is a small design question for Benoit, not a correctness one.

## Localization

- New ARB keys in **both** `lib/l10n/intl_en_GB.arb` and `lib/l10n/intl_fr.arb`, via `Tr`: the
  in-kind poste field's label and helper, the "covered in kind" badge, and the fiche's wording for a
  counterpart line and for the poste a contribution offsets.

## Verification

The eight standard gates (`AGENTS.md`, "Verification gates"), plus
`dart run tool/check_markdown.dart` for this file. The honesty invariants earn unit tests of their
own: `ocptBudgetInKindCoveredCentsByPosteId` and its effect on `ocptBudgetRemainingCents` /
`ocptBudgetPosteStrainOf`, the balance netting to zero once a contribution and its line both exist,
and the lifecycle orchestration (create, revalue, re-poste, reclassify, delete) keeping exactly one
counterpart line per in-kind contribution.
