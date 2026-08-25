<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the budget mode

The production's money, read honestly in whichever tax basis it was typed in: the quote against
the CNC nomenclature, the cash journal it is measured against — every entry the account has
actually seen, and every commitment still owed but not yet paid — the financing plan that says what
pays for all of it, the catering a shooting day actually costs — read off the schedule rather than
typed a second time — beside the defrayals a production types row by row and provisions into the
quote, and the revenue sharing that says, once the film has earned something, who gets what of it.
The mode is complete: its seven views and its four exports are all here, and this file is the whole
record of them.

## Who it serves, and what the mode now shows

- `lib/ui/pages/workspace/modes/budget/` has to serve two readers who want different documents
  from the same figures: the **commission**, which expects the CNC nomenclature, a financing plan
  with its in-kind contributions valued separately and a final report against the quote; and the
  **production that shot the film with five people**, whose real account book is a debit/credit
  journal with free categories, a meals sheet and a sharing sheet. Nothing about the mode favours
  one reader over the other — it builds the one document both eventually need, the quote, and then
  the ledger both eventually keep, the cash journal that measures what has actually moved against
  it and what is still owed, and the financing plan that measures against the quote in turn, and
  finally the revenue sharing that splits what the finished film earns.
- **Seven views, not three documents.** `OcptBudgetView` (`lib/types/`) carries seven values, in
  the header's own chip order — `dashboard`, `costTracking`, `financing`, `cashJournal`,
  `committed`, `regie`, `sharing` — each its own chip, replacing `OcptBudgetDocument`'s three
  (`expenses`, `resources`, `sharing`) and the `OcptBudgetDocumentReading`/`OcptBudgetSubPage`
  machinery a since-reverted rework built to fit the quote, the committed spending and the cash
  journal under one `expenses` document, reached through a reading switch and the header's own
  breadcrumb. That three-document shape was built, reviewed on screen and reversed by its own
  author, who did not recognise the mode the validated shell design had itself proposed; it is
  retired, and a reader who meets `OcptBudgetDocument` or `OcptBudgetCentreView` in `git log` should
  read this paragraph as the reason. `dashboard` is the mode's own default view, and it landed
  first rather than last — a freedom the retired shape's own stored-preference rule never had, since
  a value held only in memory strands nothing by being inserted anywhere (`OcptBudgetView`'s own
  doc comment).
- **The chronological journal is a place.** It is `OcptBudgetView.cashJournal` — `Trésorerie` in
  French, `Cash journal` in English — its own chip in the header, and it is the only view listing
  every entry the project holds, credits included, in one chronological table.
  `OcptBudgetCashJournal`, the widget that draws it, is unchanged in shape.
- **Selection grew a type.** `OcptBudgetSelection` (`lib/types/`), a sealed class with one `final`
  variant per kind of row the fiche can show — poste, quote line, commitment, entry, resource,
  revenue, receipt — replaces what used to be several independent id fields
  (`selectedPosteId`/`selectedResourceId`/…): a fiche able to show any one object can only ever be
  looking at one of them at a time, and one field now says which. `OcptBudgetState.selectedPosteId`
  and `.selectedResourceId` survive as plain getters folding onto `selection`, so nothing that read
  them before had to change; `.selectedShareId` stays its own field, a share opening no fiche in any
  document this reaches yet.
- **`view`, `isSimplified`, `taxBasis`, `selection`, `filterPosteId` and `expandedNodeIds` are not
  persisted.** The schedule mode's own agenda mode is the precedent: only `budgetLeftDockFraction`,
  `budgetRightDockFraction` and `budgetLastRightDockTab` (`OcptPropertiesManager`) survive a
  relaunch, exactly as before this rework. A reader who left the mode on the financing tree,
  mid-way through a filter, opens back on the mode's own default — `dashboard`, nothing selected,
  nothing filtered — every time, the same way the schedule mode's own agenda already forgets its own
  last state.

## The money rule

- **An amount is stored exactly as it was typed, and never reconstructed.** Somebody who enters
  the 12.50 € printed on a till receipt has to read 12.50 € back everywhere, without a round trip
  through the other tax basis ever handing them 12.49 €. `OcptBudgetLinesTable` therefore carries
  the amount as **three columns** rather than one, mirrored in the domain by `OcptMoney`
  (`lib/models/`, pure): `unitAmountCents`, the figure exactly as typed; `isTaxInclusive`,
  non-nullable and **`true` by default** since the common case somebody types by hand off a receipt
  or an invoice total already includes tax; and `vatRateBasisPoints`, nullable — and this is the
  line's own **override**, so its null means "inherit the project's rate," not "nobody has said."
  `OcptProjectInfoTable.defaultVatRateBasisPoints` is nullable too, and **its** null means the other
  thing, the common one: nobody has recorded a rate at all, which is what a new project is born
  with. **The two nulls are different facts read by the same code**: a silent line follows the
  project and moves with it when the project's rate changes, while a project with no rate leaves
  every silent line's excluding-tax and VAT figures simply empty — nothing disappears from the
  screen, there is just nothing yet to show.
  **An explicit 0 % is a value, not an absence.** Wages and a copyright assignment carry no VAT,
  so their excluding-tax figure equals their tax-inclusive one — a fact a line or the project states
  on purpose — and that is a different fact from a rate nobody has filled in, which contributes to
  neither total. `lib/utils/ocpt_budget_vat.dart` is the **only** place in the repository allowed to
  convert between the two bases, and every function in it answers **null, never zero**, when the
  rate an amount would need is unknown: `ocptExcludingTaxAmountCentsOf`, its mirror
  `ocptIncludingTaxAmountCentsOf`, and `ocptVatAmountCentsOf`, the difference between them (itself
  null when either side is). `ocptEffectiveVatRateOf` is the one place that resolves which rate a
  line actually reads under, pairing the basis-points figure with whether it came from the line's
  own override or the project's default — the cost-tracking table paints the first in the accent
  colour and the second in grey, switching on that pairing rather than re-deriving the comparison.
  Quantities are integers **in thousandths** (`quantityMilli`), for the same reason cents are cents:
  1,484 km, 5 days and 1.5 day all have to be said exactly, and a total computed from it
  (`lib/utils/ocpt_budget_totals.dart`) is exact rather than accumulating a rounding a
  floating-point quantity would.

## Totals are computed row by row, then summed

- `ocptBudgetLineTotalCents` is a line's own total in whatever basis it was typed in —
  `quantityMilli × unitAmountCents ÷ 1000`, rounded to the nearest cent, never converted. A poste's
  quoted total (`ocptBudgetPosteQuotedTotalCents`) and the project's own
  (`ocptBudgetProjectQuotedTotalCents`) are the sum of those, row by row, poste by poste — the
  reading `OcptBudgetPostesTable`'s own doc comment demands, since computing it any other order
  would let a rounding at the poste level disagree, by a cent, with the sum a reader gets by adding
  the lines up themselves. The header's excluding/including-tax toggle asks the table to read every
  row in the **other** basis, and that conversion is done **individually, line by line, and only
  then summed** (`ocptBudgetExcludingTaxTotalOf`, its mirror inside `ocptBudgetTotalOf`) — never a
  summed tax-inclusive total converted by one rate, which would silently assume every line shared
  it, and would give the wrong figure the moment a table mixes bases or rates, which a real quote
  always does.
  A total therefore does not just answer an amount: `OcptBudgetCoveredTotal`
  (`lib/utils/ocpt_budget_totals.dart`, pure) pairs it with **how many of the lines it was asked to
  sum actually carried a known rate** — the whole-table reading of `ocpt_budget_vat.dart`'s
  "null, never zero" rule. A line whose rate nobody has recorded contributes to neither the amount
  nor the count, so `OcptBudgetCoveredTotal.isComplete` is false for as long as any line is missing
  one, and the cost-tracking table's own total row prints `tr.budgetCostTrackingCoverageReadOut`
  (`<amount> · over <coveredCount> of the <posteCount> postes`) in that row's place, falling back to
  the plain amount the moment every poste's own lines have all declared a rate, **0 % included**: a
  line stating 0 % on purpose counts as covered, a silent one never does. `OcptBudgetStatusBar`, by
  contrast, reads the plain, **unconverted** sum
  of every line's typed amount, deliberately never the header's own selected basis: a status band
  read at a glance is not the place to explain which of the two bases a figure is read in, and the
  untouched sum needs no rate at all to be complete, unlike either converted reading.

## Money that has moved is read tax-inclusive, always

- The quote's own header offers a basis to pick because a quote is a plan, read either way
  depending on who is looking at it; a payment is not a plan, it is the very cash a bank account
  actually saw leave or enter, and there is no second way to look at that. `budget_entries` and
  `budget_commitments` are therefore never read through the header's toggle at all:
  `ocptBudgetEntryDebitCentsOf`/`ocptBudgetEntryCreditCentsOf` (`lib/utils/ocpt_budget_journal.dart`)
  and `ocptBudgetCommitmentCashCentsOf` (`lib/utils/ocpt_budget_projection.dart`) each go straight to
  `ocptIncludingTaxAmountCentsOf`, the one basis a real balance is ever expressed in. An amount typed
  excluding tax with no rate anywhere to gross it back up with — neither the row's own override nor
  the project's default — is exactly the case `ocpt_budget_vat.dart`'s "null, never zero" rule
  already governs, so it answers null here too, carried out through the very same
  `OcptBudgetCoveredTotal` the quote's own totals use: a journal, a poste's paid total or a
  projection missing a rate says *how many* of its rows it covers, never a wrong figure standing in
  for the rows it does not.
  The running balance the cash journal prints inherits that honesty at the row level rather than
  losing it: `ocptBudgetJournalRowsOf` never reorders the entries it is handed — a balance only means
  anything read in the order money actually moved — and an entry it cannot read leaves that row's own
  `balanceAfterCents` **null**, not a repeat of the balance before it and not a guess at what it might
  become. The balance the reader already had is not in doubt; the balance *after* a movement of
  unknown size genuinely is, and printing the old figure again would claim, falsely, that this
  movement changed nothing. The row below the hole is not poisoned by it either: it keeps counting
  from exactly where the journal stood before the gap, so one unreadable entry costs the reader one
  blank cell, never the rest of the ledger.

## The journal's balance is the whole journal's

- `OcptBudgetCashTotals.balanceCents` is always read over **every** live entry, never the subset a
  poste filter happens to be showing: a bank balance does not change because the screen is scrolled
  to one category, and a filtered view that quietly totalled only what it displayed would print a
  number that looks like the account's balance while actually being something else. `OcptBudgetCashJournal`
  narrows which **rows** draw by `OcptBudgetState.filterPosteId` — the mode's own single filter, set
  by the header's poste chip and honoured across every document that can (see "Selecting a poste
  and filtering by one are two different facts" below) — while its running balance and its own
  `Debit`/`Credit`/`Balance` band read `entries` whole, before that filter is applied: an account
  does not change because somebody narrowed a view. Filtering to a poste from the header lands every
  view that honours the filter already narrowed to it, and every one of them agrees on what
  "filtered by this poste" means because they all read one flag rather than several that could
  drift apart.

## Off-quote spending is named, never hidden

- `budget_entries.posteId` is nullable because a poste-less entry is a real fact, and the entry
  dialog's own `Aucun poste` choice says so on a **debit** exactly as it does on a credit — the
  small-production reading this whole mode is built for lets somebody record a till receipt for
  something the CNC nomenclature never anticipated. `ocptBudgetPaidCentsByPosteId` only ever keys an
  entry that names a poste, so a cost recorded this way used to be counted **nowhere**: not in the
  `Paid` KPI, not in the cost-tracking table, only ever inside `OcptBudgetCashTotals.balanceCents`,
  read over every live entry regardless of what it names. `Paid` could read less than the account had
  actually seen leave, with nothing on screen saying so — precisely the silence this mode refuses
  everywhere else, since every other total states how many of the rows it was asked to sum it
  actually covers.
- `ocptBudgetOffQuotePaidTotalOf` (`lib/utils/ocpt_budget_journal.dart`) is the reading that closes
  the gap: the tax-inclusive sum of every **debit** naming no poste at all, read through
  `ocptBudgetEntryDebitCentsOf` like every other movement in the file, answering an
  `OcptBudgetCoveredTotal` so a debit missing the rate it would need to be grossed up leaves the
  figure covered-but-incomplete rather than wrong. **A credit naming no poste is deliberately not
  counted here** — it is money coming *in*, a subsidy instalment or a contribution, already read by
  the resources and revenue-sharing documents (`ocptBudgetReceivedByResourceId`,
  `ocptBudgetReceivedByRevenueId`); folding it into a reading about spending would count the same
  euro twice, once as a resource received and once as a cost.
- `OcptBudgetCostTracking` draws this total as **one extra row, `Off quote`**, between the last
  poste and the `Total` row, and **only while there is something to show**
  (`OcptBudgetCoveredTotal.lineCount` above zero) — a row with nothing in it would claim a category
  the project does not have, exactly the argument the resources tree already makes for declining
  to draw a family holding no resource. Only its own `Payé` cell carries a figure; every other cell
  prints `ocptBudgetEmptyValue`, since there is no quote behind this row to measure any of them
  against. It carries **no `N°`, no `⋮` menu and no selection**: it is not a poste and nothing about
  it may look like one, since it is a reading over the journal's own poste-less debits, not a record
  anybody can rename, reorder or delete.
  **It does carry a twisty, and opens** — `_OcptCostTrackingOffQuoteIdentityRow`, keyed by the
  reserved `_ocptCostTrackingOffQuoteNodeId` rather than by a poste or a line id, since the row sums
  a reading over the journal and names no record of its own to key one by. A reader landing on the
  total could not otherwise reach what made it up, and that is the whole of the distinction this row
  turns on: it is still a *reading*, which is why it mints no id anybody can rename, reorder or
  delete, but a reading is allowed to open. Every child it reveals is an ordinary entry sub-row,
  with the menu and the selection every other entry sub-row has — the debit itself is a real
  `budget_entries` row, only the total above it is not a record of anything.
- The table's own `Total` row folds `paidByPosteId` and the off-quote total together
  (`ocptBudgetCoveredTotalsFoldOf`, `lib/utils/ocpt_budget_totals.dart`) into its own `Paid` cell,
  so that column adds up to what actually left the account — the only reading a reader adding the
  column up themselves would accept — printing the fold's own coverage read-out
  (`tr.budgetCostTrackingPaidCoverageReadOut`) whenever either side is incomplete. The financial
  report's own totals row folds the very same two totals for the very same reason, so the paper
  agrees with the screen instead of quietly disagreeing with it.
- **`ocptBudgetPosteStrainOf` and `ocptComputeBudgetAlerts` never read the off-quote total.** Both
  are readings about a poste exceeding its own quote; off-quote spending prices no poste at all, so
  it cannot make one strained, and folding it into either would answer a question neither was asked.
- The exported financial report reads the very same `snapshot.offQuotePaidTotal`
  (`OcptBudgetFinancialReportPdfService`, "The four documents" below): the paper gives the same
  reading the screen does, not less of one.

## A poste's quoted amount is not stored

- `OcptBudgetPostesTable` carries **no `quotedAmount` column**, and `OcptBudgetPoste` carries no
  such field either: a poste's total is the sum of its own `OcptBudgetLine` rows, computed on every
  read rather than stored beside them. A stored figure would be a second copy of one truth, kept in
  step with the lines by hand or by a write nobody could guarantee never to forget — and the "frozen
  quote v4" the reference paperwork names is already what a project version *is*: sealing one
  freezes every poste and every line exactly as they stood, so a separate frozen-total column would
  freeze nothing a version doesn't already.

## The estimate to complete, and two variances that answer different questions

- A real cost report has a fifth column beside `Devis` (quote), `Engagé` (committed) and `Payé`
  (paid): the **estimate to complete** — what a human still expects to spend, which need not equal
  what the quote said and need not equal zero once a poste has gone over. `budget_postes` therefore
  gained one nullable column, `estimateToCompleteCents`. **Null means "derive it"**:
  `ocptBudgetEstimateToCompleteCents` (`lib/utils/ocpt_budget_totals.dart`) answers
  `max(0, quote − paid − committed)` while the column is null, and the poste's own typed figure the
  moment it is not. **It is typed on the fiche's own poste panel and nowhere else** — the cost
  report carries no column for it, only the `Coût final` it feeds. The field stands empty while the
  column is null, its own placeholder printing the derived figure, so the reader sees what the app
  would answer before deciding to overrule it — the same pairing `ocptEffectiveVatRateOf` already
  draws for an inherited VAT rate — and a `Derive again` button beside it hands a typed figure back
  to null.
  **It is held per poste, not per quote line, on purpose**: a line-level estimate would be a second
  plan running beside the quote, more machinery than a film of this size needs, and the derived
  reading already makes the column a restatement of the quote until a poste actually goes over — a
  real cost report has a human adjust *that* figure, once, where it is read.
  `ocptBudgetFinalCostCents` reads `paid + committed + estimateToComplete`, drawn as `Coût final`.
  **Read the second variance's name carefully — it is not `ocptBudgetVarianceCents`.** That one
  already existed before this milestone, reads `paid + committed − quote`, and is what the header's
  alerts band, the cost-tracking table's own `Écart` column and the financial report PDF print; it
  stays exactly as it is and keeps every one of its callers, because a variance read against what
  has actually moved is not the same fact as a variance read against what a human now expects the
  final bill to be. `ocptBudgetFinalCostVarianceCents` reads `finalCost − quote` instead, and is
  drawn nowhere but the fiche's own poste panel, beside `Coût final`, under the very same `Écart`
  label the cost-tracking table already uses for the other one — two readings sharing one word in
  two different places, each honest about what it answers where it is printed.
  With `Estimate to complete` and `Consumed` retired as columns of their own (their reading survives
  inside `Coût final`), `Payé`, `Engagé`, `Reste`, `Coût final` and `Écart` all print a real amount
  at poste level, `0` where nothing has moved — the honest reading the journal's own existence
  already earns, argued once for the whole mode above. Nothing in expenses is silent any more for
  want of a figure that cannot exist; the em dashes still standing are the off-quote row's own (it
  prices no poste) and the resources document's own for an unentered in-kind contribution (below).

## A commitment settles by naming the entry that paid it

- `OcptBudgetCommitmentStatus` carries four steps — quote accepted, contract signed, invoice
  received, declared — and **deliberately no fifth, `settled`**. A commitment is settled the moment
  `budget_commitments.settledEntryId` names the `budget_entries` row that paid it
  (`OcptBudgetCommitment.isSettled`), and that is exactly the argument the poste's own missing
  `quotedAmount` column already makes: a `settled` flag living beside a link that says the same
  thing would be a second copy of one truth, kept in step by hand or by a write nobody could
  guarantee never to forget. Reading settlement off the link rather than off a status also lets a
  commitment be `declared` and settled at once, or settled without ever having been marked
  `declared` at all — a production that pays before its paperwork catches up is not a state this
  enum has to pretend cannot happen. A settled commitment is excluded **outright** from
  `ocptBudgetCommittedCentsByPosteId`'s own map and from `ocptBudgetProjectionOf`'s own steps — not
  counted at zero, simply not there — because the money it stood for has already left the account
  and is already counted once, as *paid*, by the very entry it now names: counting it a second time,
  as still owed, would double the very same movement. It keeps its own row in the committed-spending
  sub-page regardless, marked settled rather than removed, since a production still wants to see what
  it once owed and to whom.
  The `Settle` gesture on a commitment is not a status flip: it opens `OcptBudgetEntryDialog`
  pre-filled with today's date, the commitment's own label, poste, amount, tax basis and rate, as a
  debit — the very same dialog an ordinary entry uses, seeded rather than editing one already
  stored — and confirming it both creates that journal entry and points `settledEntryId` at it in one
  event, so a settlement can never exist as a link with no entry behind it. Undoing a settlement
  clears that link alone; the journal entry it once named is left exactly as it was, since the
  payment it recorded did happen and un-settling a commitment is a correction to the commitment's own
  bookkeeping, not a claim that the money came back.

## A commitment's poste is editable, a quote line's is not

- `OcptBudgetQuoteService.updateLine` refuses to move a line to another poste, because
  `OcptBudgetLinesTable.sortKey` is fractional **within its own `posteId`** (`OcptBudgetPostesTable`
  orders flat; `budget_lines` orders "like a shot within a scene"): moving a line to a different
  poste would need its position recomputed against a different group entirely, a real second
  operation wearing the name of a field write. `OcptBudgetCommitmentsTable.sortKey` is flat, exactly
  as `budget_entries`' own is, so no such recomputation is hiding behind a poste change here — and a
  commitment's poste is exactly the field a person types once against a ten-poste nomenclature and
  sometimes gets wrong. Refusing the edit would leave a mistyped commitment correctable only by
  deleting it, and a delete here is a tombstone kept forever (ADR 0010) — too heavy a price for a
  slip of the mouse. `OcptBudgetCommitmentDialog` therefore offers the same `Poste` picker on an edit
  that it offers on creation, and `updateCommitment` writes it like any other field.

## The nomenclature is seeded, not frozen

- `lib/constants/ocpt_budget_cnc_postes.dart` declares the ten postes of the CNC nomenclature every
  French commission expects, each an `OcptBudgetCncPoste` carrying a **constant, hard-coded UUID**
  rather than one minted at seeding time — the very device schema version 18 already uses to derive
  `role_episodes.id` from the role it links: a deterministic id is what lets two replicas seeding
  the same project independently agree on ten rows rather than each minting their own ten for a
  merge to reconcile into twenty. `OcptBudgetQuoteService.loadPostes` seeds them (`_seedIfEmpty`)
  on the **first read of a `budget_postes` table holding no row at all, tombstones included** — not
  at project creation, so a project that predates the budget mode entirely gets them on its very
  next open, and not when the table holds even one tombstoned row, because a user who has deleted
  every poste has not asked for them back. Once seeded, a poste is an ordinary row from that moment
  on: renamed, reordered or deleted like any other, and never re-inserted by a later read.
  Every entry carries only a `labelKey`/`simpleLabelKey` pair naming an ARB key, never a resolved
  word — `lib/constants/` and every service under `lib/managers/` must stay free of `Tr`
  (`AGENTS.md`). `ocptBudgetCncPosteSeeds` (`lib/ui/utils/ocpt_budget_labels.dart`) is the one place
  that turns the ten constants into `OcptBudgetPosteSeed` (`lib/models/`, already localized), and
  `OcptBudgetMode` calls it **once**, against the outer, listening-safe `BuildContext`, and hands the
  result to `OcptBudgetBloc` as a constructor argument rather than something the bloc watches: a
  provider's own `create` callback may never perform a listening `Tr.of` read, and nothing about a
  seed's own words changes between a preview and a restore, which swap the database, not the app's
  locale.

## The schema

- Two synchronised tables (`isDeleted`, `sortKey`, tombstones filtered back out on every read, ADR
  0010): `budget_postes` (`code`, `label`, a nullable `simpleLabel` reading exactly as
  `vatRateBasisPoints` does — null falls back to `label` rather than meaning "no name at all") and
  `budget_lines` (`posteId`, `label`, `quantityMilli`, `unit`, the money triple on the unit price, a
  nullable `elementId` naming the breakdown element this line prices, and free-form `notes`).
  `budget_postes` orders flat by its own `sortKey`, like `OcptElementsService`'s catalogue;
  `budget_lines` orders by `sortKey` **within its own `posteId`**, like a shot within a scene — a
  line only ever competes for a position against the other lines of the very poste it prices.
  `project_info` gains three nullable columns read the same way `minimumRestMinutes` already is —
  null means "nobody has recorded a figure," never a claim about the figure's absence:
  `defaultVatRateBasisPoints`, `mealPriceCents` and `snackPriceCents`, the last two read by no view
  before the catering pass existed. This is schema **v25**. `OcptProjectVersionCodec` gains both
  tables and
  the three columns in all three of its required places — the payload, `contentDigest` and
  `_applyPayload` — under **payload format 21**, whose upgrade from every earlier format
  **materialises** `budgetPostes` and `budgetLines` as empty lists and the three project columns as
  null: a version sealed before this milestone existed truthfully had no budget at all, so restoring
  it tombstones every poste and line added since, exactly the same reading a restore already gives a
  dropped column or an episode a version predates.
  Two more synchronised tables follow the same rule: `budget_entries` (`date`, `label`, a nullable
  `posteId` — money coming in prices no poste, so this is a real fact rather than an omission — the
  money triple, and `voucherNumber`) and `budget_commitments` (`dueDate?`, `label`, a **non-nullable**
  `posteId` — a commitment is always a cost against the quote — the money triple, `status` and a
  nullable `settledEntryId` referencing `budget_entries`). `assets` gains one column,
  `budgetEntryId`, and one kind, `OcptAssetKind.receipt`, for a voucher file — see "The voucher"
  below. This is schema **v26**. `OcptProjectVersionCodec`
  gains both tables and the `assets` column in all three of its required places under **payload
  format 22**, whose upgrade from format 21 **materialises** `budgetEntries` and `budgetCommitments`
  as empty lists and every `assets` row's `budgetEntryId` as null — a version sealed before the
  journal existed truthfully had no entry and no commitment, and no asset could yet reference one
  that didn't exist, exactly the reading format 21's own upgrade already gives the tables it
  materialises.
  Two last synchronised tables complete the plan: `budget_resources` (`groupKind` — a subsidy, a
  cash contribution or a contribution in kind — `label`, `amountCents`, `status`, `isReimbursable`
  and `notes`) and `budget_mileage_rates` (`label` and `ratePerKmMilliCents`). Neither carries the
  money triple, and `budget_resources` carries **no `receivedCents` counter**: see "A resource is
  received by being named, and a rate is nobody's to seed" below for both arguments. `budget_entries`
  gains the `resourceId` it was always going to gain, a nullable foreign key onto `budget_resources`
  added with `Migrator.addColumn` exactly the way `budget_entries.posteId` was added onto an
  already-existing `budget_postes`; and `people` gains `commuteKmMilli` — a **one-way** commute, in
  thousandths of a kilometre, for the reason `budget_lines.quantityMilli` is in thousandths — and
  `mileageRateId`, the rate that applies to that person. Both are **personal data**: a one-way
  commute says roughly where somebody lives, so both are nulled by every one of the three erasure
  paths a person's row travels (`ocpt_erased_person_scrub.dart`, `OcptPeopleService`'s own live
  erasure, and `OcptProjectVersionsService`'s own on a restored payload), beside
  `maxDailyPresenceMinutes`. This is schema **v27**. `OcptProjectVersionCodec` gains both tables and
  all three columns in all three of its required places under **payload format 23**, whose upgrade
  from format 22 **materialises** `budgetResources` and `budgetMileageRates` as empty lists and every
  `budget_entries.resourceId`, `people.commuteKmMilli` and `people.mileageRateId` as null — a version
  sealed before the financing plan existed truthfully named no resource and no rate, and no entry
  could name a resource that did not exist, exactly the reading format 22's own upgrade already
  gives what it materialises.
  Two last synchronised tables close the mode: `budget_revenues` (`date`, `label`, `amountCents`,
  `status`, `notes`) and `budget_shares` (a nullable `personId`, `label`, `sharePermille`,
  `reinvestPermille`, `notes`), both ordered flat by their own `sortKey` like `budget_resources`.
  Neither stores what has moved — see "A taking is received by being named, a participant is paid
  the same way" below — and `budget_shares` carries **no constraint that its shares sum to
  `1000`**: a sharing plan still being negotiated legitimately does not add up yet, and refusing the
  write over it would make the app unusable while the plan is being built. `budget_entries` gains
  the last two nullable foreign keys it was ever going to gain, `revenueId` and `shareId`, added
  with `Migrator.addColumn` exactly the way `resourceId` was. This is schema **v28**.
  `OcptProjectVersionCodec` gains both tables and both columns in all three of its required places
  under **payload format 24**, whose upgrade from format 23 **materialises** `budgetRevenues` and
  `budgetShares` as empty lists and every `budget_entries.revenueId` and `.shareId` as null — a
  version sealed before the sharing existed truthfully named no taking and no participant, exactly
  the reading format 23's own upgrade already gives what it materialises.
  Two last nullable columns close the mode's own schema, neither adding a table: `budget_resources`
  gains `personId`, declared the way `budget_shares.personId` already is — the person a financing
  resource comes from, so several separate contributions from one lender can be added up (a subsidy
  names nobody, which is why it stays nullable, the same reading `budget_shares.personId` already
  carries) — and `project_info` gains `isBudgetSimplified`, the header's simplified/detailed toggle,
  until now held in memory alone and lost on every close. Null means "nobody has ever chosen", and
  the mode opens **detailed** for it, exactly what it already does today before this column existed
  at all. **`budget_resources.personId` is a link to a person, not a fact about them** — the honest
  comparison is `roles.personId`, not `people.commuteKmMilli`: none of the three erasure paths a
  person's row travels (`ocpt_erased_person_scrub.dart`, `OcptPeopleService`'s own live erasure,
  `OcptProjectVersionsService`'s own on a restored payload) touches it, exactly as none of them
  touches `roles.personId` or `budget_shares.personId` either. Erasing a person blanks and
  tombstones their own `people` row; the resource that named them keeps naming that now-blanked row,
  the link itself staying valid, which is what lets a reader still see that *someone* lent this
  money even once that someone's own data is gone. This is schema **v29**. `OcptProjectVersionCodec`
  gains both columns in all three of its required places under **payload format 25**, whose upgrade
  from format 24 gives every `budgetResources` row a **null** `personId` and the project settings a
  **null** `isBudgetSimplified` — a version sealed before either column existed truthfully named no
  lender for any resource and had never chosen between the two header views, exactly the reading
  format 24's own upgrade already gives what it materialises.
  One last change touches no table and no column: `budget_resources.status` stops naming a *word*
  and starts naming a *step*. The four values the three groups used to share (`applied`, `notified`,
  `secured`, `valued`) become three (`pending`, `agreed`, `confirmed`), whose word is resolved from
  the group the row sits in — see "The word a status is called is the group's" below. The migration
  is the **first in the file that rewrites values rather than a shape**, and it rebuilds the column
  rather than only refilling it: the retired words also live in the column's own `DEFAULT`, which
  SQLite gives no way to alter in place, so a file that kept `DEFAULT 'applied'` would write a
  retired word onto the next resource created in it and `OcptBudgetResourceStatusConverter` reads
  the column strictly. Adding the column afresh, filling it from the old one, dropping that one and
  taking its name is the whole of it — four statements against a column nothing references, landing
  an upgraded file on exactly the declaration `onCreate` writes, which is what the migration test's
  own shape comparison checks. This is schema **v30**. `OcptProjectVersionCodec` reads the same
  column under **payload format 26**, whose upgrade from format 25 maps each retired word onto the
  step it already stated — a **fourth kind** of upgrade step beside the empty list, the null and the
  removal: nothing arrives and nothing goes, one column simply stops meaning what it meant. It has
  to happen there rather than being tolerated at read time, because the codec reads the key
  strictly: a payload still saying `applied` would be refused outright, not defaulted. **Nothing is
  invented** on either side — `valued`, the one word that was already a group's rather than a step's,
  lands on `agreed`, which is exactly what it said: a figure is on this resource, nothing is signed.
  Four steps follow, each documented where the reader meets its reason rather than here: schema
  **v31**, `budget_allowances` — see "A defrayal is typed, never deduced" below; schema **v32**,
  `budget_lines.provisionKey`/`.provisionDigest` — see "The régie provisions into the quote" below;
  schema **v33**, `budget_commitments.lineId` — see "A quote line can be promoted into a commitment"
  below. One nullable column closes the mode's own schema for now: `budget_postes` gains
  `estimateToCompleteCents`, null meaning "derive it" — see "The estimate to complete, and two
  variances that answer different questions" above. This is schema **v34**.
  `OcptProjectVersionCodec` gains the column in all three of its required places under **payload
  format 30**, whose upgrade from format 29 (`_upgradeFormat29To30`) **materialises** every
  `budget_postes` row's `estimateToCompleteCents` as **null** — a version sealed before the column
  existed was captured at a moment when nobody could have judged a poste's estimate to complete, so
  null states exactly what was true then, not an empty list, which would claim the poste itself was
  new, and not zero, which would be a judgement nobody made.

## The mode's own shape

- **One budget for the whole production, not one per episode** (ADR 0019): `budget_postes` and
  `budget_lines` name no episode at all, so `OcptBudgetMode` keeps the shell's own
  `onEpisodeSelected` null, exactly as the schedule mode already does and for the schedule's own
  reason — a selector would filter a read that was never split by episode to begin with, not a
  standing-in for a bloc this mode does not have; it has one.
- **Seven chips in the header, in the design's own order** — `dashboard`, `costTracking`,
  `financing`, `cashJournal`, `committed`, `regie`, `sharing` — each switching
  `OcptBudgetState.view` and nothing else, no breadcrumb or reading switch behind any of them.
  **A left dock, headed `Postes du devis`**, exactly as the validated shell design draws one for
  this mode as for every other — see "The left dock" below for the whole of its own argument. The
  right dock offers exactly three tabs (`OcptBudgetRightDockTab`): `Inspector`, the polymorphic
  fiche described below; the shared `Versions` tab every mode carries; and `Help`.

## The left dock

- `OcptBudgetPosteDock` (`ocpt_budget_poste_dock.dart`) is the mode's own left dock, headed
  `Postes du devis`: one card per live poste, in the mode's own poste order, over a four-line
  footer totalling the whole project (`Devis`, `Payé`, `Engagé`, `Reste`). A card draws its own
  code (detailed reading only) and name, a two-tone bar reading paid then committed against its own
  quoted total, the `total / devis` read-out, and the consumed percentage in
  `ocptBudgetPosteStrainOf`'s own strain colour — the very reading the cost-tracking table's own
  `Écart` column and the dashboard's own alert already use, so a poste reading strained here reads
  strained everywhere. A title-row `Tout` link clears the mode's own poste filter when one is set.
- **Purely presentational.** No bloc, no `globalGetIt()`, no service: every figure it draws arrives
  already computed by `OcptBudgetState` and `lib/utils/ocpt_budget_totals.dart`, and every gesture
  is only ever reported upward through a callback, so the mode stays the one place deciding what
  each one writes — exactly the composite-panel idiom the fiche and every tree of this mode already
  follow.
- **Drawn on every view, `financing`, `regie` and `sharing` included**, the three with no poste
  dimension of their own. It is the mode's own standing reading of where the quote stands, not a
  control belonging to one page: the cost-tracking table can be scrolled away or off screen
  entirely, and the dock still answers "how is the quote doing" without asking the reader to switch
  views to find out — the same reason the KPI tiles read the whole project rather than the view on
  screen (see "The dashboard" below).
- **Two gestures on a card, and they mean two different things.** A click on the card itself
  *selects* the poste — it opens the fiche and highlights the card, and narrows nothing, exactly the
  distinction "Selecting a poste and filtering by one are two different facts" below already argues
  for the cost-tracking table's own row. The card's own `⋮` menu carries the one gesture that *does*
  narrow, reached deliberately through a menu rather than the card's own click target, so filtering
  stays a decision a reader makes on purpose rather than a side effect of a closer look. Both
  gestures, and the `Tout` link beside them, are **withheld together** on the three poste-less
  views — no filter entry in the menu, no `Tout` link in the title row — even while the header's own
  chip still names a poste: the filter is still set, and leaving brings it back, exactly as the
  header's own chip already reads it there.
- The dock's own fraction is persisted as `budgetLeftDockFraction` (`OcptPropertiesManager`),
  beside `budgetRightDockFraction` and `budgetLastRightDockTab`.

## The dashboard

- `OcptBudgetDashboard` (`ocpt_budget_dashboard.dart`) is the mode's own default view, opened the
  moment the mode is: the KPI tiles, the needs/resources balance band, the standing alerts, the
  quote read poste by poste, then the "what feeds this budget" card, in that order.
- **It types nothing of its own — every figure on it is read from the other six views' own
  tables**, exactly as `OcptBreakdownRecapTable` is a computed reading over the breakdown rather
  than a table with rows of its own. Its KPI tiles — `Paid`, `Committed`, `Cash balance`, `Total
  resources` — and its needs/resources balance bar (`ocptBudgetNeedsResourcesBalanceOf`) read the
  whole project and **never the header's own poste filter**: a whole-project standing reading that
  quietly narrowed to one poste would leave its own tiles silently disagreeing with the ones the
  reader saw a second ago on another view, which is exactly why `ocptBudgetViewHonoursPosteFilter`
  answers false for `dashboard` alongside the three views that carry no poste dimension at all.
- **The standing alerts live here, and are reachable from everywhere.** `ocptComputeBudgetAlerts`
  is computed once, carried by the state, and the dashboard is the only view that draws the alert
  cards themselves; every other view reaches them through the `Tableau de bord` chip's own count
  badge (see "The alerts compute themselves" below). The strained postes read poste by poste
  follow, each row in its own strain colour.
- **A poste row here selects the poste and switches to `costTracking` in the same gesture**, which
  is where the fiche then opens (`OcptBudgetMode._handleDashboardPosteOpened`). The two used to
  differ — a row's click merely selected the poste, opening the right dock's inspector over a page
  that is itself a read-only summary, a second read-only reading of a figure already on screen in a
  narrower column — and that was the fault. This is the same argument "Selecting a poste and
  filtering by one are two different facts" makes for the cost-tracking table's own row, carried one
  turn further: a click that only selects must not silently narrow *or* strand the reader on a page
  with nothing left to do about what it just selected. `ocptBudgetViewHasInspector` answers false
  for `dashboard` for the very same reason — a dashboard poste row is a link to where the poste is
  worked on, not a selection of its own.

## The expenses tree nests what used to sit apart

- `OcptBudgetCostTracking` (`ocpt_budget_cost_tracking.dart`) draws `OcptBudgetView.costTracking`
  as one nesting table: a poste opens on its own quote lines, a quote line opens
  on its own commitment and the entry that settled it — or, while it is still owed, a muted
  `tr.budgetCostTrackingNoEntryHint` row saying so in words rather than drawing nothing — and a
  poste's own **off-line** commitments and entries, the ones naming no `lineId`, draw at the poste's
  own indentation once it is open, since they have no line to nest under. A commitment or an entry
  sub-row carries its own small badge: a commitment's own coloured by
  `ocptBudgetCommitmentStatusAccentColor`, worded with its settlement status; an entry's own in the
  accent colour, worded with its `voucherNumber`.
  **Expansion state is `OcptBudgetState.expandedNodeIds`**, a `Set<String>` keyed by **poste and
  line ids alone** — a commitment or an entry sub-row draws no twisty of its own, so its own child
  shows or hides wholesale with whichever line or poste it sits directly under — and it survives a
  rebuild, since it lives in the state rather than in the widget. A quote line with nothing under it
  draws no twisty at all: an empty expansion is worse than none.
  **A row's own `Rename` menu entry selects it and opens the fiche rather than editing its name in
  place.** This app has no precedent for renaming a record inline inside a plain list — the two
  inline-answer exceptions the confirm-dialog rule already carries (the `Versions` dock panel, the
  project dictionary dialog) exist because a list of rows there has no other way of saying *which*
  row is being talked about, which is not this table's problem: every row already opens its own
  fiche on selection.

## The resources tree folds the takings in

- `OcptBudgetFinancing` (`ocpt_budget_financing.dart`) draws `OcptBudgetView.financing` as a
  nesting tree too: three family rows — subsidies, contributions, takings
  (`OcptBudgetResourceFamily`) — each opening onto its own resources or takings, each of those
  opening onto the receipts (journal credits) that name it. `OcptBudgetResourceGroupKind` still
  answers *how* a `budget_resources` row was created — a subsidy, a cash contribution, an in-kind
  one, exactly as it always has — while `OcptBudgetResourceFamily` answers *which card a row draws
  in*, merging cash and in-kind contributions together under one `Contributions` family, the way the
  validated mockup's own `Apports` card does. **Creating a resource is still three explicit
  gestures, one per `OcptBudgetResourceGroupKind`, not one**: a `MenuAnchor`-anchored button naming
  the three kinds opens `OcptBudgetResourceDialog` with the kind already set and named in the
  dialog's own title, its `Group` picker withheld while creating for exactly the reason it always
  was, offered again on an edit since a production is free to reclassify a resource it already
  created.
  The takings (`budget_revenues`) left the sharing document's own left column for this tree's own
  `Takings` family — every gesture on a taking (create, edit, receipt, reorder, delete, select) now
  lives here, where a resource's own already does, rather than being duplicated in two places.
  **The `Dossier` column is held apart from the money**, a small status badge naming the row's own
  paperwork progress (*conventionnée*, *annoncée*, *facturée* and their siblings — "The word a
  status is called is the group's" below), because "conventionnée" has never meant "versée": the
  three money columns are `Promis`, `Rentré` and `Reste à venir`, and `Dossier` carries no figure at
  all.
  **An in-kind contribution counts as promised and never as received, until an entry says
  otherwise.** `Rentré` and `Reste à venir` both print `ocptBudgetEmptyValue` for an `inKind`
  resource **while no journal entry has ever named it** — no cash will ever move for a valuation, so
  "how much of it has arrived" is not a question with an answer — and the real figures the moment an
  entry does name it: the app never hides a movement that actually happened. A resource row, like a
  taking's, is selected and opens the fiche; expansion follows the same `expandedNodeIds` idiom as
  the expenses tree, keyed by a family's own `name` (a family mints no id of its own), a resource id
  or a revenue id.

## The financing view says what covers the film, twice

- Two different questions share the word "coverage", and this mode now answers each in its own
  place rather than letting one stand in for the other.
  **`OcptBudgetResourcesCoverage`/`ocptBudgetResourcesCoverageOf`** (`lib/utils/ocpt_budget_financing.dart`)
  is the one drawn live, at the foot of the resources tree, as a two-tone bar: a lighter tone for
  everything **promised** (received plus what is only expected), a solid tone on top for what has
  **really** arrived. It reads the needs side tax-inclusive **always**, whatever the header's own
  basis toggle shows elsewhere — money coming in is always read tax-inclusive, and comparing an
  excluding-tax quote against a tax-inclusive resource would compare two different figures while
  looking like it compared one. The band is **withheld whole** rather than drawn empty while the
  quote holds no line at all: a plain `resources ≥ needs` reading would otherwise declare the
  financing plan sufficient against a quote nobody has begun, exactly the claim `Consumed` used to
  refuse for a poste with no quote.
  **`OcptBudgetNeedsResourcesBalance`/`ocptBudgetNeedsResourcesBalanceOf`** is the older reading, and
  it stays exactly as it is — read today only by the financing-plan and financial-report PDF export
  services, which is where its own **three-way** verdict belongs: no quote yet, covered, or short by
  an amount, worded for a document rather than a live screen. It is not drawn anywhere in the mode's
  own UI any more; the two-tone bar above answers the live question, this one the printed one, and
  neither is a second way of computing the other's figure.

## The fiche is one panel for seven kinds of row

- `OcptBudgetFiche` (`ocpt_budget_fiche.dart`) is the right dock's own `Inspector` tab, once and for
  all: a single panel, polymorphic on `OcptBudgetState.selection`, switching over every
  `OcptBudgetSelection` variant — poste, quote line, commitment, entry, resource, revenue, receipt.
  Every variant draws the same grammar, top to bottom: a breadcrumb up to the chip the row lives
  under, the object's own name and amount, a small stepper of its states, the figures that make it
  up, the outstanding amount in large type, one primary action and at most two secondary ones. The
  table says where things stand; the fiche says where they come from and what to do next.
  **A breadcrumb resolves through the header's own segment labels, never a name of its own.** A
  poste's own breadcrumb is the `Cost tracking` chip's own segment label; a resource's and a
  taking's both open on `Financing`'s, a resource's own second segment naming its group, a taking's
  the `Takings` family. A quote line's, a commitment's and an entry's climb through their own poste
  instead, exactly as before. **A taking's own breadcrumb was corrected to `Financing`** — it used
  to read `Sharing`, from when a taking's own row still lived in that view's left column — the
  moment every gesture on a taking (create, edit, receipt, reorder, delete, select) moved into the
  financing tree's own `Takings` family (see "The resources tree folds the takings in" above): a
  breadcrumb naming where a gesture used to live, once every gesture has moved, would send a reader
  looking for `Record a receipt` to a page that no longer offers it.
  - A **poste**'s stepper reads `Estimated · Committed · Paid`, all three always reached — an
    aggregate reading, not a lifecycle a single poste passes through — and its primary action is
    `Add`, opening a fresh quote line; a secondary offers `From breakdown`.
  - A **quote line**'s stepper is the same three words, its reached count following whether the
    line has been promoted and settled; its primary action is `Commit this line…` while it has not,
    `Pay {amount}` once it has been promoted and is still owed, and none once settled — mirroring
    "A quote line can be promoted into a commitment" below.
  - A **commitment**'s primary action is `Pay {amount}` (`onCommitmentSettleRequested`), opening
    `OcptBudgetEntryDialog` pre-filled from it exactly as the `Settle` gesture always has, and null
    once settled.
  - An **entry**'s stepper is always fully reached; its primary action is `Edit`, its secondary
    `Delete`.
  - A **resource**'s stepper reads `Promised · Received`, its badge the `Dossier` fact held apart
    from the money; its primary action is `Receive {outstanding}` (`onResourceReceiptRequested`),
    withheld for an in-kind resource or once it is fully received.
  - A **revenue** (a taking) mirrors a resource, with no `Dossier` grouping and no in-kind reading:
    `Receive {outstanding}` (`onRevenueReceiptRequested`).
  - A **receipt** — a journal entry read as the sub-row it settles — shares the entry's own fiche,
    with its stepper and breadcrumb overridden to read through the resource or the revenue it
    settles.
  **Every primary action that writes opens the very dialog that already exists, pre-filled with the
  amount** — this, with the capture band below, is what ends the double typing the mode used to ask
  for: an amount typed once, into a quote line or a resource, is offered back rather than retyped
  the moment it becomes a commitment, a receipt or a payout.

## The right dock belongs to the view, not to the mode

- `OcptBudgetRightDock` used to draw every value of `OcptBudgetRightDockTab` whatever was on
  screen, so a poste chosen in the quote went on filling the `Inspector` over the régie and the
  revenue sharing — pages that have nothing to do with a poste and never put one there.
- The tab is now offered only where there is something for the fiche to show:
  `ocptBudgetViewHasInspector(view)` (`lib/types/ocpt_budget_view.dart`) answers true for
  `costTracking`, `cashJournal` and `financing` — the three views whose own rows select something
  of their own, a poste, a line, a commitment or an entry on the first, an entry on the second, a
  resource or a taking on the third — and false for `committed`, `regie` and `sharing`, whose own
  rows select nothing the fiche can show yet, a plain highlight answered by the row's own menu
  instead. **`dashboard` answers false too, and it is the one genuinely new case this predicate has
  to account for**: a dashboard poste row is a link to where the poste is worked on, not a
  selection of its own — see "The dashboard" above for the whole of that argument.
- **Withheld, not disabled**, the standing rule for an affordance without a subject. `Versions` and
  `Help` are offered everywhere, so the dock never has an empty tab bar.
- A stored `Inspector` preference **is not overwritten** where it cannot be honoured: the dock
  draws `Help` instead and leaves `OcptBudgetState.rightDockTab` alone, so a reader who left a view
  on the inspector comes back to the inspector rather than to whatever the other view showed them.

## Selecting a poste and filtering by one are two different facts

- They used to be one field. `OcptBudgetState.selectedPosteId` drove both the right dock's
  inspector *and* the cash journal's filter, so **clicking a row in the quote silently narrowed a
  view the reader was not looking at** — they found out on arriving at the journal, where the only
  notice was a caption inside its own top band and the only way out an unlabelled `Remove filter`
  button sitting in a row of figures.
- **`selectedPosteId` is now a plain getter, folding onto `OcptBudgetSelection`** — it answers a
  poste id only while `state.selection` is an `OcptBudgetPosteSelection`, and drives the fiche and
  the row's own highlight, and narrows no view. `OcptBudgetState.filterPosteId` is the mode's own
  filter, written by **two controls** rather than one — the header's poste chip and the left dock's
  own card `⋮` menu entry — and honoured by every view that can
  (`ocptBudgetViewHonoursPosteFilter`, `lib/types/ocpt_budget_view.dart`): `costTracking`,
  `cashJournal` and `committed`, the three places a poste-keyed row is drawn at all. The dock card's
  own click, like the tree row's own, only ever selects; only its `⋮` entry writes the filter — see
  "The left dock" above for the same distinction stated from that widget's own side.
- **The chip is both the control and the indicator.** It reads `Every poste` or the poste's own
  name, tinted `primary` while filtering, with a clear button beside the name. Sitting in the
  header, it is on screen whatever view is, which is the whole point: one place to see a filter,
  one place to remove it. The same predicate also governs the simplified/detailed switch, which
  reads a poste-keyed row's own name exactly as the filter narrows poste-keyed rows, and is withheld
  alongside it, never separately.
- **Four views cannot honour it and say so.** `financing`, `regie` and `sharing` read tables that
  carry no poste at all — the financing plan `budget_resources`, the régie the schedule and the
  defrayals, the revenue sharing `budget_revenues`/`budget_shares` — so there is nothing on any of
  them to narrow. `dashboard` cannot either, for a reason of its own rather than theirs: it is the
  whole project's standing reading, and narrowing it to one poste would leave nothing on it but that
  poste's own row, its KPI tiles silently disagreeing with the ones the reader saw a second ago on
  another view (`ocptBudgetViewHonoursPosteFilter`'s own doc comment). On all four the header's chip
  keeps the poste's name — the filter is still set, and leaving brings it back — and adds `Not
  applied here` underneath; hiding it there would have been calmer and dishonest, an unfiltered view
  passing for a filtered one. The left dock reads the same predicate: a card's own `⋮` menu carries
  no filter entry on these four, and the title row's own `Tout` link goes with it — a link to clear
  a filter that cannot be set from here has nothing of its own to clear.
- **The narrowing happens in the mode, not in the views.** `OcptBudgetMode` hands each widget the
  already-filtered list, so a filtered table's own `Total` is the total of what is on screen —
  the only honest thing it can say. The cash journal is the exception the other way — see "The
  journal's balance is the whole journal's" above.
- The filter is reconciled against every fresh snapshot exactly as the selection is: deleting the
  filtered poste clears it, rather than leaving the mode showing nothing under a chip naming a
  poste the project no longer has.

## The capture band is the daily gesture

- `OcptBudgetCaptureBand` (`ocpt_budget_capture_band.dart`) sits at the top of three views now
  (`OcptBudgetMode._captureBandDirectionOf`): `costTracking` and `cashJournal` open it as a debit,
  `financing` as a credit, never `dashboard`, `committed`, `regie` or `sharing`. A direction toggle
  (`Out of the account` / `Into the account`), an amount, a wording, a date and a `Save`. Nothing
  else is asked for.
- **It keeps its own half-typed draft across `costTracking` and `cashJournal`, and remounts fresh
  only moving into or out of `financing`.** The first two read the very same underlying data, poste
  by poste or by date, so a reader clicking from one to the other is not switching what the band is
  capturing, only how the rest of the screen reads it — losing a half-typed draft over a click that
  changed nothing about the movement itself would read as the app forgetting what it was just told.
  `financing` is a different direction outright, a credit rather than a debit, and earns a fresh
  draft the way any other change of subject would; the band is keyed on `_captureBandDirectionOf`'s
  own answer, so it remounts exactly when that answer changes and stays mounted exactly when it does
  not.
- **The moment amount and wording are both typed, the app proposes what the movement settles.**
  `ocptBudgetMatchSuggestionsOf` (`lib/utils/ocpt_budget_match.dart`, pure) ranks what a draft
  movement — direction, amount, date, wording — could settle among the commitments still owed and
  every live defrayal on a debit, or the resources and the revenues still short on a credit, in that
  order: **exact amount first**, then **date proximity** (within a 7-day window; a candidate with no
  date of its own sorts after every dated one, never as infinitely close), then **wording overlap**
  (a folded, diacritic-insensitive word-set intersection). A candidate agreeing with the draft on
  none of the three is dropped outright — proposing something that agrees on nothing is worse than
  proposing nothing — and every surviving candidate carries **why** it matched
  (`matchesAmount`/`matchesDate`/`matchesWording`), which the band, never the pure util, turns into
  words: "solde l'engagement « Couronne », 250,00 €, poste 5, échéance aujourd'hui: même montant,
  même fournisseur."
- **`That's it` accepts the first suggestion in one click.** `Something else…` opens
  `OcptBudgetEntryDialog` pre-filled with the band's own draft instead. Once answered or ignored,
  the band clears and the movement is an ordinary entry — nothing queues, so nothing has to remember
  that it was queued, and a movement waiting to be attached invents no table of its own: it is a
  `budget_entries` row naming no poste, resource, revenue or share, which was always a legal state.
- **`Something else…` is a full door, not a fallback for when nothing matched.** It is offered
  whenever the draft reads as saveable, a suggestion or no suggestion — never withheld merely
  because `_suggestionsOf` found nothing to propose. The alternative was tried and reversed: a band
  offering `Something else…` only alongside a suggestion let a reader record an off-quote movement
  without ever meaning to, under a hint that claimed, wrongly, that there was nothing else here to
  fill in.
- **The band is withheld whole, never disabled, on the four views `_captureBandDirectionOf` answers
  null for** — `dashboard`, `committed`, `regie`, `sharing` — **and under a previewed version.**
  `OcptBudgetMode` simply does not build it there: the daily gesture belongs to a view that reads
  money moving in one direction at its own top level, not to a whole-project standing reading, a
  view that already reads a projection of its own, or a page that types nothing at all.

## Money is added in one way, reached through several doors

- **Exactly two events ever write a `budget_entries` row**: `OcptBudgetEntryCreationConfirmedEvent`
  and `OcptBudgetCommitmentSettlementConfirmedEvent`, the second naming the commitment it settles
  alongside the very same fields the first collects. Every door the mode offers converges on one of
  these two, never inventing a third: `OcptBudgetEntryDialog`'s own `Save`, wherever it is opened
  from; a facilitator that opens it pre-filled — a resource's `Record a receipt`, a revenue's
  `Receive`, a commitment's `Settle`, a share's `Record a payout` — reached from a row's own `⋮`
  menu or from the fiche's own primary action; and the capture band's own `That's it`, which
  dispatches straight to whichever of the two events the matched candidate needs, without opening
  the dialog at all. A reader never sees three different write paths — they see one shape of
  movement, reached however is fastest for the gesture at hand.
- The one thing no door could do was **mint** a taking, so recording a festival prize meant leaving
  the journal for the resources tree, creating the taking there and coming back. The `Taking`
  picker inside `OcptBudgetEntryDialog` carries a `New taking…` entry that opens
  `OcptBudgetRevenueDialog` — the very dialog the resources tree opens — and the taking travels back
  on `OcptBudgetEntryFormFields.newRevenue`, which the bloc creates through the same two service
  calls `OcptBudgetRevenueCreationConfirmedEvent` uses. A taking born from the entry dialog is byte
  for byte one born in the resources tree: the door differs, the row never does.
- The picker holds it as a **sentinel value**, not an id, since no row exists until the movement is
  saved; the sentinel never leaves the dialog. Cancelling the taking dialog leaves the picker where
  it was, an accidental open costing nothing.
- The rule the help panel states in one line, and the reason there is no further way: **a taking or
  a financing resource is an expectation; a journal entry is a movement.** The first says what is
  owed to the film, the second says what the account has actually seen.

## A travel defrayal is priced by a scale, and remembers only the number

- `OcptBudgetAllowanceDialog` draws a **mileage-scale dropdown in place of the unit price** while
  the nature is `travel` and the project names at least one scale
  (`budget_mileage_rates`). Picking a scale writes its own rate into the amount the form submits;
  `Free amount…` hands the plain field back **under the dropdown, never in place of it**, so a
  reader who picked a free amount by mistake can pick a scale again. A project naming no scale at
  all gets no dropdown — an offer whose only entry is `Free amount…` explains nothing — and a hint
  under the field says where scales come from instead.
- **What is stored is the amount, never the scale.** `budget_allowances` has no `mileageRateId`
  column and will not grow one: a scale corrected next year must not silently reprice a defrayal
  already paid. The dialog re-derives which scale is showing by matching the stored rate against
  the project's own scales when it opens, which is a display concern and dies with the dialog.
- The `Use this person's own rate` button, which fills the commute distance *and* the rate from the
  person's own record, now also lands the dropdown on the very scale it copied, so the two controls
  never disagree about what is pricing the trip. It needs an explicit `ValueKey` to do it:
  `FormFieldState.didUpdateWidget` does not re-read `initialValue`, so a value changed in code
  would otherwise leave the field showing the old scale over a new amount.

## The alerts compute themselves, and ask for no threshold

- `ocptComputeBudgetAlerts` (`lib/utils/ocpt_budget_alerts.dart`, pure) raises exactly two kinds of
  alert, and both are read straight off arithmetic the mode already has rather than a figure typed
  in on purpose for the alert's own sake: a poste whose paid plus committed already exceeds its own
  quote (`ocptBudgetPosteStrainOf` answering `over`, paired with `ocptBudgetVarianceCents`'s own
  figure), and the cash projection (`ocptBudgetProjectionOf`, opened at the journal's own balance
  over the unsettled commitments) going negative, at the date and by the amount its own first
  negative step already says. The mockup's own 1,500 € cash floor is deliberately not a third alert:
  it was calibrated by nobody, and it is not the app's place to advance a figure nobody here
  validated — the same argument `minimumRestMinutes` already settled for a single column, applied
  here to a whole mode.
- **Both alerts, and the cash projection they read, now draw as a band under `OcptBudgetHeader`**
  (`_OcptBudgetHeaderAlertBand`) rather than on a dashboard, which is dissolved (see below). The
  header's own alerts band also carries `OcptBudgetCashProjection`, re-homed from the
  committed-spending sub-page it used to sit beside, and draws it ahead of every alert, on
  `expenses`'s own top level only.
- Each alert card offers exactly one action back into the data it is about, never a dismiss, since
  the alert is not a notification to clear, it is a standing fact about the project that stays true
  until the underlying figures change: a poste over its quote selects that poste
  (`OcptBudgetPosteSelectedEvent`) and switches the reading to `byTree`
  (`OcptBudgetDocumentReadingSelectedEvent`); the cash projection going negative opens the
  committed-spending sub-page (`OcptBudgetSubPageSelectedEvent(subPage: committedSpending)`).

## The voucher

- `OcptBudgetJournalService._nextVoucherNumber` mints an entry's own accounting reference the
  instant `createEntry` runs — `J-001`, `J-002`, …, growing past three digits rather than wrapping —
  scanning every voucher number ever minted, tombstones included, so a number is never reused even
  once the entry that carried it has since been deleted and some paper trail elsewhere still names
  it. It is **deliberately not localized**: a voucher number is stapled, physically or figuratively,
  to a receipt or an invoice, and has to read the same whatever language the UI happens to be shown
  in that day — the same reason every service under `lib/managers/` stays free of `Tr`. Editing an
  entry can retype it, since a user may need it to match a paper trail the minted reference doesn't;
  creating one cannot, the number belonging to the service that mints it.
  The voucher **file** is a different thing entirely from the voucher **number**: a till receipt, an
  invoice PDF, a bank slip, referenced by path rather than embedded (ADR 0013), through
  `assets.budgetEntryId` and the new `OcptAssetKind.receipt` — there is no `receiptAssetId` column on
  `budget_entries` itself to keep in step, for the very reason a poste keeps no `quotedAmount`
  column: a second copy of the same fact is a second place for it to drift from the first.
  `OcptBudgetJournalService.setEntryReceipt` tombstones whichever voucher an entry already
  referenced before recording the new one, since an entry has at most one and a row nothing points
  at any more is an orphan, not history worth keeping — and the file itself is never touched by
  either a replace or a `clearEntryReceipt`, ADR 0013's own reading of a missing path as a normal
  state applying to a voucher exactly as it does to a permit or a photo.

## The one deliberate divergence: picking a receipt

- `OcptBudgetEntryDialog` resolves `globalGetIt().get<FileSelectorManager>()` directly, in its own
  `_pickReceipt`, rather than dispatching a bloc event the way every other file pick in the app does
  (the resources mode's own photo and document pickers write the instant a file is chosen, because
  that gesture has no `Save` step of its own to defer to). This dialog is built the other way round:
  every other field it collects — the label, the amount, the tax basis, the VAT override — is gathered
  locally and written once, on `Save`, and a receipt pick is no different in kind, only in the fact
  that it happens to involve a file. Calling the manager here is a plain read of a path the OS
  dialog already reports, with nothing to decode and no `assets` row to mint on the spot: the
  actual write — minting or tombstoning that row — happens in the very same bloc handler that
  creates or updates the entry, once `Save` is pressed, exactly where every other field's write
  already lands. Routing the pick itself through an event first would buy nothing but an extra
  round trip before the dialog even knows whether the user will keep the entry at all.

## A resource is received by being named, and a rate is nobody's to seed

- `budget_resources` carries **no `receivedCents` column**, and that is the third time this mode has
  refused the same shape for the same reason: a poste keeps no `quotedAmount` and a commitment keeps
  no `settled` flag, because a stored second copy of one truth has to be kept in step by a write
  nobody can guarantee never to forget. What has come in against a resource is the sum of the
  `budget_entries` **credits** naming it through `budget_entries.resourceId`
  (`ocptBudgetReceivedByResourceId`, `lib/utils/ocpt_budget_financing.dart`), read through
  `ocptBudgetEntryCreditCentsOf` like every other movement rather than off `creditCents` raw, so a
  resource whose entries are missing the rate they would need is *covered-but-incomplete* rather
  than wrong. That link is also what makes `resourceId` earn its place: the resources tree's own row
  menu offers **`Record a receipt`** (`tr.budgetFinancingRecordReceiptAction`), and the fiche's own
  primary action on a resource, `Receive {outstanding}` (`onResourceReceiptRequested`), do the same
  thing two ways — mirroring the commitment's `Settle` exactly, opening `OcptBudgetEntryDialog`
  pre-filled as a **credit**, dated today, for whatever is still outstanding, with the resource
  already named, so a receipt can never exist as a figure with no movement behind it.
  **`Record a receipt` is withheld — never disabled — once a resource is fully received (received
  `>=` amount) and on any in-kind resource at all, entered or not.** A contribution in kind is
  valued rather than collected (see "The resources tree folds the takings in" above), so no cash
  will ever move for it and the gesture has nothing to offer; a resource whose received total
  already meets its own amount likewise has nothing left to receive, though a **partially** received
  one keeps offering it — several instalments landing against the one resource is the ordinary case,
  not an edge one. **`Undo the last receipt`** is the way back: a row's own `⋮` menu entry, offered
  once a resource has received anything at all, it resolves the most recently recorded live credit
  naming that resource
  (`ocptBudgetLatestReceiptEntryIdOf`, `lib/utils/ocpt_budget_financing.dart`, reading [entries] in
  the very same chronological order the journal itself is loaded in) and, once `OcptConfirmDialog`
  confirms it, dispatches the very same `OcptBudgetEntryDeletionConfirmedEvent` the cash journal's
  own `Delete` already uses — tombstoning the entry (ADR 0010) rather than a second delete path of
  its own, and never un-receiving the resource through any figure of its own, since
  `budget_resources` stores none.
  **A debit naming a resource is deliberately not subtracted.** Repaying a reimbursable contribution
  does not un-receive it — the money did come in — and what a production has paid back is the
  revenue-sharing document's own subject, not a correction to this figure. This is also why `Undo the
  last receipt` only ever considers a **credit**: undoing a repayment debit is not what the gesture
  is for.
  `budget_resources` carries **no money triple** either: a financing resource is money coming in,
  which "Money that has moved is read tax-inclusive, always" (above) already settles once for the
  whole mode.
  `budget_mileage_rates` exists for the symmetrical reason: **this app states no regulatory figure
  of its own.** A mileage scale depends on the vehicle and on the country, and the app ships in more
  than one — the very argument `project_info.minimumRestMinutes` already settled for a single column,
  applied here to a whole table. So no scale is seeded, not even a greyed example, and the project
  settings page's own rates card says as much rather than pre-filling anything. The rate is stored as
  `ratePerKmMilliCents`, in **thousandths of a cent** per kilometre (`0.529 €/km` is `52900`), read
  and written by `ocptMileageRateMilliCentsOf`/`ocptMileageRateTextOf`
  (`lib/utils/ocpt_mileage_rate_amount.dart`) rather than by `ocptCostCentsOf`: a real scale is
  quoted to three decimals, and whole cents cannot state the figure the user has in front of them —
  which is the money rule at the top of this file, applied to a rate.

## A defrayal is typed, never deduced

- The régie view used to compute what a traveller costs as **one return trip per day of presence**,
  from their own home-to-set distance and their own mileage rate. A real shoot does not work that
  way, and the product owner said so plainly: somebody travels in on the first day, is housed near
  the set for a fortnight and travels home on the last; somebody else is defrayed for two journeys
  out of fifteen days; technicians claim expenses too, not only the cast. None of that is derivable
  from a presence.
- `budget_allowances` is therefore a **synchronised table of typed rows** — a person (nullable, the
  way `budget_shares.personId` is), a nature (`OcptBudgetAllowanceKind`: travel, accommodation,
  meal, other), a wording, a date and an optional end date for a stay, a `quantityMilli` and a
  `unitAmountMilliCents`. This is schema **v31**, and `OcptProjectVersionCodec` reads it under
  **payload format 27**, whose upgrade from format 26 materialises an **empty list**: a version
  sealed before the table truthfully defrayed nobody, and what the view then showed was a
  computation held in memory and stored nowhere, so there is no earlier figure to carry over and
  nothing for the upgrade to invent.
- **The mileage scale did not become useless, it became a pre-fill.** Opening the dialog on a
  person whose `commuteKmMilli` and `mileageRateId` are known offers that distance and that rate
  already filled in; changing either is an ordinary edit, and neither is read again afterwards. The
  rate suggests, it never decides — the same register "A resource is received by being named, and a
  rate is nobody's to seed" already argues for the scale itself.
- `unitAmountMilliCents` is in **thousandths of a cent** for `budget_mileage_rates`' own reason: a
  published scale reads 0,529 €/km, which whole cents cannot state. `ocptBudgetAllowanceAmountCents`
  multiplies then rounds **half up once, at the very end** — 168 km at that scale is 88,87 €, which
  rounding the rate first would have turned into 88,90 € or 88,04 €. Totals round **each row before
  summing**, never the sum: each row is a figure somebody is actually owed, and rounding the total
  instead would leave the printed rows disagreeing with the printed total by a cent nobody could
  account for.
- **No money triple**, for the third time this mode makes that argument: a defrayal row is what the
  provisioning reads to write a quote line, and it is that line which carries the tax basis and the
  VAT rate. Asking for the VAT twice would be asking the same question in two places.

## The journal scrolls rather than losing a column

- The cash journal's table gives every column but `Label` a fixed width, and `Label` takes what is
  left. Below the sum of the fixed ones the flexible column was driven to **nothing** and the row
  overflowed its frame: with the right dock open on a laptop screen the wording of every entry
  disappeared outright and the balance column ran off the edge, clipped rather than striped, since
  a release build draws no overflow banner.
- The table is therefore laid out at `_ocptCashJournalMinTableWidth` (984 = 728 of fixed columns +
  24 for the row's own inset + 232 for the wording) whenever the slot is narrower, and **scrolls
  sideways inside its own frame**.
  The header and the rows sit in the same scroll view, since they share those fixed widths and
  scrolling either alone would slide the figures out from under their own headings. No column is
  dropped and none shrinks: what does not fit is scrolled to, which is the treatment the rest of the
  app already gives a table too wide for its slot.

## A stacked pane states its height, it does not take a share of one

- The régie draws **two panes**, side by side while the centre is wide and stacked once it is not.
  Stacked, each pane used to take an `Expanded` share of the height — three fifths and two. That
  works while the view is tall and fails silently once it is not: a share smaller than the pane's
  own heading band plus its card's chrome (padding, header row, dividers, total row) leaves the
  `ListView` **nothing at all**, so the table prints its header and its total with no row between
  them, and past that the pane spills over whatever sits under it. A release build paints no
  overflow banner, so what a user sees is a table that has quietly lost its content and a heading
  printed over another one.
- Stacked, a pane therefore **states its own height**: its heading band takes the height it needs,
  and its card is sized by its rows — between two and eight of them, so a two-line table is not
  given a page and a thirty-day shoot does not make one — and **the view scrolls** when the two
  panes together are taller than it. This is the same answer the tables already give sideways, one
  axis over.
- Side by side, both panes still take the whole height, floored at 320 px: under that the pair
  scrolls rather than being crushed, which is the same rule stated for a window nobody normally
  opens that short.
- The committed-spending sub-page, which used to stack the same way beside its own cash projection,
  now draws that projection nowhere: the projection moved to the header's own alerts band (see "The
  alerts compute themselves" above), so the sub-page is a single table today, sized and scrolled the
  ordinary way any one table in this mode is.

## An add button shows one plus, not two

- Every creation control of this mode that carries an `Icons.add` icon has a label with **no `+` of
  its own**: `Poste`, `Add`, `From breakdown`, `Entry`, `Commitment`, `Resource`. The icon already
  says what the gesture is, and a label repeating it drew the sign twice side by side.
- **The `+ ` prefix is not wrong everywhere** — it is the house convention for a *text-only*
  affordance, which is why the resources mode's own `+ Add a person` keeps it, and why the sharing
  view's own `+ Participant` footer does too: a plain `InkWell` with no icon, so the sign in the
  text is the only thing marking it as adding anything. The rule is one plus per button, wherever it
  lives.

## The word a status is called is the group's

- A financing resource's status used to be one flat list of four words shared by all three groups,
  and the product owner's objection to it is the same one that had already split `Resource` into
  three gestures: with three different ways of creating a resource, one should not be able to
  create it at a status that has nothing to do with what is being created. Asking a production to
  mark a lent camera `applied` was asking it to file a dossier at a commission that does not exist.
- The answer is **not a per-group subset of one word list**, which would have left `applied` meaning
  a filed dossier in one card and something vaguer in the next. `OcptBudgetResourceStatus` stores a
  **step** — `pending`, `agreed`, `confirmed`, deliberately anonymous — and
  `ocptBudgetResourceStatusLabel(tr, kind, status)` resolves the word from the row's own
  `OcptBudgetResourceGroupKind` **and** its step, exactly as before this milestone's tree replaced
  the group's own card with a family's: `OcptBudgetResourceFamily` decides which card a row draws
  in, `OcptBudgetResourceGroupKind` still decides which nine words it can be called. Nine words,
  three steps, one stored column: a subsidy is `Applied`, `Notified`, `Secured`; a cash contribution
  `Requested`, `Agreed`, `Contracted`; a contribution in kind `Promised`, `Valued`, `Signed`. In
  French, where the gender follows the group's own noun: `Déposée`/`Notifiée`/`Acquise`,
  `Sollicité`/`Accordé`/`Contractualisé`, `Convenu`/`Valorisé`/`Signé`.
- **What the three steps have in common is what makes them one enum**: a resource is first merely in
  play, then answered — a figure is on it — then held on paper. That progression is the same
  whichever group a row sits in, and it is what lets a production reclassify a resource without its
  status becoming meaningless: the step survives the change of kind and the picker simply re-words
  itself under the user's hand, which the resource dialog's own test pins.
- **Nothing is hidden or disabled by kind, and nothing needs to be.** The mode's standing rule that
  the UI carries no conditional branch on the state of the data survives this change rather than
  being spent on it: the picker always offers the same three chips, and only their words change.
  The *colour* is the step's alone, never the group's — `ocptBudgetResourceStatusAccentColor` takes
  no kind — so a contribution in kind that is signed and a subsidy that is secured read as equally
  far along, which is what they are.
- The exported financing plan reads the same words as the screen, and the same way: the labels
  object it is handed carries a map **per group** (`OcptBudgetFinancingPlanLabels.statusLabels`,
  `statusLabelOf(kind, status)`), built from the very same resolver the view uses, so a printed plan
  can never disagree with the screen about what a step is called.

## The catering is computed, the defrayals are typed, and both reach the quote

- `OcptBudgetRegie` reads in **two opposite directions, side by side**. The left column is
  *computed*: what each shooting day costs in meals and at the buffet, off the schedule and the
  project's own two unit prices, nothing typed here at all. The right column is *typed*: one
  `budget_allowances` row per thing actually owed, because what a production pays somebody back is
  not derivable from their presence — see "A defrayal is typed, never deduced" above. Under
  [_ocptRegieWrapWidth] the two stack rather than crush each other, each table has a floor below
  which it scrolls sideways exactly as the journal's own does, and stacked each states its own
  height rather than taking a share of one — see "A stacked pane states its height" above.
  `OcptBudgetFeedCard`, the "what feeds this budget" card described below, sits at the very top of
  the page, above both columns, in either reading: each of its three rows — the breakdown, the
  schedule, the catering itself — is a title, a one-line reading and a click that only ever reports
  upward, and the régie withholds its own catering row, since that row would only send the reader
  back to the page they are already on.
- **The view writes, and therefore carries `isReadOnly`** — it did not before, being read-only start
  to finish. Under a previewed version the `Defrayal` button, the row menus, the poste picker and
  the provisioning button are **withheld, never disabled**, expressed as null callbacks by the mode
  and again by the view itself.
- Every figure the *catering* reads is typed somewhere else, so each source gets a way back to it,
  reported upward rather than navigated here: the head counts point at the schedule, the two unit
  prices at the project settings, and a defrayed person at their own sheet in the resources mode.
  `OcptBudgetMode` turns each into a real dispatch.
- Empty state: a project holding **neither** a shooting day **nor** a defrayal shows
  `OcptWorkspaceEmptyMode` over the whole view. One holding defrayals but no schedule keeps the
  layout — there is a `+` action of this view's own to keep a heading band drawn for now.

## The régie provisions into the quote, and never overwrites a hand

- The view used to compute figures and write them nowhere, which the product owner named exactly:
  *"il fait des calculs mais ces calculs, où sont-ils enregistrés ou provisionnés ?"* — they were
  nowhere. A band under both columns now reads `Computed here`, `Quoted on this poste` and the
  **gap** between them, and offers the gesture that closes it.
- **One quote line per nature**, never one lump: `OcptBudgetProvisionKind`'s own six values —
  catering meals, craft services, and the four defrayal natures — so the quote stays readable and
  the gap can be read nature by nature. A catering meal and a defrayed meal are two of those values
  on purpose: the first is what the production fed the unit on a shooting day, the second what one
  person is paid back for a meal it did not provide, and a quote holding both must not read the same
  word twice.
- **The target poste is picked, with the CNC `Transports, défraiements, régie` as the default** —
  by its stable seeded id, and only while the project still has it. The nomenclature is seeded, not
  frozen: a production is free to have renamed, split or deleted that poste, so this is a preference
  among the postes that exist, never an assumption that one of them does. A quote holding no poste
  at all says so instead of offering an inert picker.
- **Reprovisioning updates what it wrote, and reports what it did not.** `budget_lines.provisionKey`
  names the nature a line was provisioned for — a key rather than a foreign key, since the figure
  sums across every shooting day and every defrayal and no single row exists to point at — and
  `budget_lines.provisionDigest` holds `[label, quantityMilli, unitAmountCents]` exactly as the
  provisioning last wrote them. `ocptBudgetProvisionPlanOf` then reads three cases: a nature with no
  line is **created**; a line still holding what the app wrote is the app's own to **update** (or is
  left `unchanged`); and a line whose figures have moved has been **retouched by somebody** and is
  reported rather than overwritten. A figure a user typed is never silently corrected — the money
  rule of this whole mode. A line carrying no key at all is never touched: a van hire quoted on the
  same poste is nobody's business but the person who typed it.
- **A provisioned line whose nature no longer has any figure is updated to nothing**, not deleted
  and not left standing: it is a line the app wrote and still owns, so leaving yesterday's travel
  total in the quote after every defrayal has gone would be the one dishonest option, and deleting
  it would take a decision that belongs to the user, who can see the zero and remove the line.
- **The plan is computed whole before a row is written**, and the counts go in front of the user in
  an `OcptConfirmDialog` opened by the mode — *n created, n updated, n left exactly as they are*.
  It is opened **not destructive**, unlike every other confirmation of this mode: provisioning
  creates and updates lines the app itself owns and never overwrites one somebody edited, so a red
  button would say something about the gesture that is not true. The plan then travels with the
  event rather than being recomputed: it is what the user said yes to.
- **The counts are worded so no number ever disagrees with its noun**: `To create: 0 · To update:
  2 · Left as they are, edited by hand: 0`, rather than a sentence that would have to read "0
  lignes seraient créées" in French. Three ICU plurals in one string would have said the same thing
  at four times the cost.
- **A provisioned line's wording follows the app's language, and reprovisioning offers to update
  it.** A line written while the app spoke English says `Catering — craft services`; switch to
  French and the next provisioning reports it as an update, because the label is part of what the
  digest compares. That is the honest behaviour rather than a wrinkle to engineer around — the line
  is the app's own, and offering to rename it into the language actually on screen is what a reader
  would expect. Nothing is rewritten without the confirmation, and a line somebody edited is still
  never touched.
- **A provisioning that would do nothing is withheld, and the band says why in its place.** The
  same plan is computed for the band as for the gesture, so the reason — the quote already holds
  everything, or every line it would touch has been edited by hand — sits beside the figures rather
  than behind a click that answers "no". This is schema **v32** and **payload format 28**, whose
  upgrade nulls both columns on every existing line: no line of any project was ever written by a
  provisioning that did not exist.

## A quote line can be promoted into a commitment, and the line stays

- A quote line and a commitment hold the same shape of fact — a poste, a wording, an amount, a tax
  reading — and differ in the two things that make a debt a debt: **who is owed, and when**. So the
  quote line's own fiche offers `Commit this line…`, which opens `OcptBudgetCommitmentDialog`
  pre-filled from the line (a `prefill` parameter, mirroring `OcptBudgetEntryDialog.prefill`) with
  only those two left to say.
- **A promotion, never a move.** The line stays in the quote: comparing the 1,200 € estimated with
  the 1,450 € actually owed is the whole use of having both, and losing the estimate at the moment
  it becomes useful would be the wrong trade. Nothing is double-counted either — a poste's `Quote`
  column reads its lines and its `Committed` column reads commitments; the two were never summed.
- `budget_commitments.lineId` records the provenance (schema 33, payload format 29). **Nothing is
  ever read back off the line through it**: the commitment's amount, wording and due date are its
  own from creation, and correcting the estimate afterwards leaves the debt alone. The column buys
  exactly two behaviours — a line already promoted says so instead of silently making a second debt
  every time the gesture is used, and the promotion can be undone from the line it came from.
- The line's own fiche therefore draws **one of two mutually exclusive states**: `Commit this
  line…`, or `Pay {amount}` as its primary once promoted and unsettled, with `Show the commitment`
  and `Uncommit` as its two secondaries; once settled, no primary action at all, with `Show the
  commitment` and `Delete` as its secondaries. Uncommitting goes through `OcptConfirmDialog` like
  every irreversible action, and deletes the commitment while leaving the quote line alone.
- **Uncommitting is withheld once a journal entry has settled the commitment**, with the reason
  written where the button was: undoing the promotion would then delete a debt somebody has already
  been paid against.
- `lineId` is **not part of `OcptBudgetCommitmentFormFields`**. The form collects what a user
  typed; the provenance is where the gesture came from, which the dialog neither knows nor asks
  about — and keeping it out leaves the dialog usable, unchanged, for a commitment that has no line
  behind it.

## The mode explains itself

- The product owner used the mode and still could not say what told three of the seven old views
  apart — a real defect the screens alone never fixed, however each one's own figures were made
  honest. `OcptWorkspaceToolbar` therefore carries a nullable `helpAction` slot, the same shape and
  idiom as `exportAction`/`dockToggles`/`saveAction`/`projectSettingsAction` (`foundations.md`): a
  mode with nothing to explain renders no button at all, and every mode but this one leaves it null.
  Clicking it dispatches the very same `OcptBudgetRightDockTabSelectedEvent` the dock's own tab row
  already sends, naming `OcptBudgetRightDockTab.help`, so the toolbar button and the dock tab are
  one gesture rather than two: opening the dock on `Help`, and closing it again on a second click
  while `Help` is already showing — the toggle every other dock control already has.
  `OcptBudgetHelp` (`lib/ui/pages/workspace/modes/budget/widgets/`) **writes nothing**, exactly the
  argument `OcptBudgetRegie` used to make for itself before it started writing defrayals, so it
  carries no `isReadOnly` flag and is offered identically under a previewed version. Its content
  follows `OcptBudgetState.document`/`.reading`/`.subPage`: switching the header's own chips or
  breadcrumb changes what the panel says, with no extra click, since the dock stays open on `Help`
  across a route change exactly as it stays open on `Inspector` across a selection.
- **The two-by-two matrix is gone, replaced by the chain of states each document's rows pass
  through.** The matrix used to cross what is only promised against what has actually moved,
  promised money coming in against money going out — a navigation of six sibling pages that no
  longer exists, and two of the six were never in the matrix to begin with. What a document's own
  rows actually do is pass through a small chain: an estimate becomes a commitment becomes a
  payment, a promise becomes a receipt. Every page but the régie now opens on its own chain, one
  cell per state, left to right, each carrying the state's own word and, under it, a short caption
  naming where that figure comes from:
  - `expenses`: **Estimated** (the quote) · **Committed** (a commitment) · **Paid** (an entry).
  - `resources`: **Promised** (a resource or a taking) · **Received** (an entry naming it) — no
    hand-typed step in between, unlike the expenses chain's own commitment.
  - `sharing`: **Received** (the takings) · **Already repaid** (the reimbursable contributions) ·
    **Left to share** (the agreed shares).
  Under the chain, one short sentence says how a step becomes the next; the page below it is the
  detail, worded in the plain language this file already argues for it in, every cross-reference to
  a figure or a label resolved as an ICU argument (`intl_utils`'s own convention, "The four
  documents" below) rather than restated by hand, so the help text can never drift from the very
  word it is pointing at.
- **The régie draws no chain** — it is not a stage of anything, it types nothing, and its own first
  paragraph says so.
- **The current step wears no extra word of its own, only a wash and a weight, and is announced
  through `Semantics` rather than drawn.** A cell's label carries a second sentence — `"{label},
  You are here"` — only while it is the reader's current one; colour alone would say nothing in
  high contrast, nothing to a colour-blind reader and nothing at all to a screen reader, so the
  meaning rides the accessibility tree instead of the paint.
- **The header's three chips — `Expenses`, `Resources`, `Sharing` — read left to right as the
  sentence they explain**: what the film costs, what pays for it, what it earns, long after both.
  **Controls are contextual now, a departure from the seven-chip header's own "always offered,
  whatever the project holds" rule.** The reading switch and the tax-basis switch are offered on
  `expenses` alone: money coming in is always read tax-inclusive, so there is nothing for the
  toggle to do anywhere else, and `resources`/`sharing` have no `byDate` reading yet to switch to.
  The simplified/detailed switch and the poste filter are offered exactly where a poste-keyed row is
  drawn — `expenses`, either reading, and its own `committedSpending` sub-page — and withheld,
  never disabled or captioned, everywhere else: the standing rule for an affordance without a
  subject. Every one of these is a **list-literal conditional**, not a disabled or greyed control:
  the widget the header would have drawn simply is not built.
- **No chip is worded by the simplified reading, and none should be**, exactly the argument that
  held for the old seven — real trade words retitled for a five-person crew lost their reason the
  moment the navigation itself stopped naming a stage by its trade name. What the simplified toggle
  still governs is the ten CNC poste labels (`budget_postes.simpleLabel`) and the empty-state
  sentences that name the ledgers in prose: real translations of opaque trade language, unlike a
  second name for a document that already said the plain thing it was.
- **Shedding the title is not enough on its own**, and the header does not stop there: under
  `_ocptBudgetHeaderTitleMinWidth` the controls **wrap onto a second line**, and the chips wrap
  inside their own border too, as `OcptScheduleHeader`'s controls already do. The centre narrows for
  a reason the header cannot see — the right dock opening takes roughly 580 px of it — and a plain
  `Row` then clips silently in release, which had been taking the tax-basis switch off the screen
  altogether. A control scrolled out of a clipped row is worse than a disabled one: nothing on
  screen says it exists.
  Every other write in the mode lands the instant it is dispatched — a tax-basis radio, a reorder,
  a delete, a creation — while the free-text fields alone (`OcptBudgetField`: a poste's label and
  code, a line's label, quantity, unit, unit price and notes) ride a 2 s autosave debounce, flushed
  on a selection change, a dock tab change, a change of document, reading or sub-page, either header
  toggle, entering a version preview and the mode's own `deactivate()`. Those last paths were added
  after the fact and are the reason the mode once looked like it ignored what it was told: an
  amount typed in the cost-tracking table and followed straight by a click on another document was
  still sitting in the debounce, so that document drew the snapshot from before it and corrected
  itself two seconds later. The write was never lost; it simply was not shown. Every path that stops
  the typing and starts the reading has to flush.
  A line's VAT override is the one field with no direct mirror: an empty or
  unparseable submission reads as "leave the override exactly as it is," never "clear it," since a
  stray backspace must not silently drop an override typed on purpose — going back to inheriting the
  project's rate is its own dedicated, immediate gesture
  (`OcptBudgetLineVatRateInheritedRequestedEvent`), mirroring the project settings page's own
  `No rate` button for `defaultVatRateBasisPoints`.
  **The `Export` control opens onto four documents**, `OcptWorkspaceExportDialog
  <OcptBudgetExportDocument>` drawing one card each for the quote, the financing plan, the cash
  journal and the financial report, above the dialog's own standing project-package card — see "The
  four documents" below. `OcptBudgetBloc` also mixes in `MixinOcptProjectPackageBloc` exactly as
  every other mode's bloc does, which is what let a colleague receive this project as a portable
  `.ocptz` a milestone before the mode printed a single PDF of its own.

## The sharing view says what each person put in, not only what comes back

- The card used to be titled `Repaying the contributions` and `ocptBudgetRepaymentLinesOf` skipped
  every resource not marked reimbursable. On a project where nothing was marked — the ordinary
  state the day it is created — that read as an empty card, and the view showed nothing but
  percentages. The product owner reported exactly that: *"je ne vois pas la valeur additionnée que
  la personne a versée"*.
- It is now `What each person put in`, and **every** resource is grouped, in cash or in kind,
  reimbursable or not. `OcptBudgetRepaymentLine` carries the two figures apart:
  `contributedCents` is what the person gave the film, `reimbursableCents` is how much of it the
  film has to give back. `outstandingCents` reads the second, never the first — nothing is owed
  against a gift, however much it was worth — and a line with nothing owed prints
  `ocptBudgetEmptyValue` rather than `0.00`, since nothing owed is not a debt that came to zero.
- **The two halves of a contract finally meet.** `budget_resources` and `budget_shares` both name a
  person, and nothing put the two together: a reader held "Marie put in 300 €" from one card and
  "Marie has 15 %" from another and joined them in their head. A contributor who also holds a share
  now says so under their own name. Matched on `personId` alone — two rows sharing a typed label
  are not evidence of one person.
- **The card that says what is owed now offers to pay it**: `Record a repayment` opens the entry
  dialog on a debit already naming the resource, for whatever is still owed. It is the same
  facilitator the resources tree's own `Record a receipt` already is, pointing the other way, and
  it writes through the same one shape of movement — see "Money is added in one way" above.
  Withheld under a previewed version, and withheld on a contributor with nothing left owed.
- A contributor whose contributions are spread over several resources is repaid against the
  **first one still owed**. The card groups them into one debt on purpose, and asking which of
  three 100 € loans a 100 € repayment settles is a question nobody has an answer to.
- **The takings left this view for the resources tree's own `Takings` family**, where every gesture
  on one already lives; this view's own left column now holds only `Repaying the contributions`,
  which is what the view is for, and its right column holds the split of what is left — see below.

## The contributions come off the top, and no remainder is redistributed

- The order the sharing view states things in **is** the rule it exists to make legible, and
  `lib/utils/ocpt_budget_shares.dart` is where that order is arithmetic rather than layout: the
  takings come in, the reimbursable contributions are taken off the top, and only what is left is
  anybody's to split. `ocptBudgetReimbursableTotalCents` reads `budget_resources.isReimbursable` —
  the column the resources plan stores and the sharing view reads — and nothing there branches on
  `OcptBudgetResourceGroupKind`: an in-kind contribution counts if the user marked it reimbursable,
  which is the mode's standing rule that the code carries no conditional branch on the state of the
  data. `ocptBudgetRepaidContributionsTotalOf` is the other half of the sentence
  `ocpt_budget_financing.dart` already writes when it declines to subtract a debit naming a
  resource: this is that debit's reader, and it counts only debits against a **reimbursable**
  contribution, a debit against a subsidy being a correction or an unspent balance handed back
  rather than a repayment the sharing has to clear.
  **`OcptBudgetSharingPot.shareableCents` deducts the whole reimbursable total, not merely what is
  still outstanding.** Whether a contribution has physically gone back is a question about the
  production's cash, not about what belongs to the participants: a film that has earned 4,000 €
  against 3,500 € of reimbursable contributions has 500 € to share whether the 3,500 € went back
  last week or has not gone back at all — and reading the outstanding figure here instead would let
  a production enlarge the pot simply by delaying a repayment. What is still owed is printed too,
  in its own line of the same card, because it is a real fact; it is just not this one.
  **The `Repaying the contributions` card also details who is owed what, one line per lender, above
  the three aggregate figures it always kept.** Three aggregate figures could not answer the
  product owner's own question: if Marie lends 100 € three times over, the card had no way to show
  that she is owed 300 €, all at once, ahead of everyone else. `ocptBudgetRepaymentLinesOf`
  (`lib/utils/ocpt_budget_shares.dart`) groups every **reimbursable** resource by lender —
  `budget_resources.personId` when it is set, the resource's own `label` otherwise, so a resource
  naming nobody still earns its own line rather than being lumped into a catch-all, and two
  resources naming nobody but sharing the same label group together, the label being the only thing
  left to tell them apart. Each line's own repaid figure reads `budget_entries` debits naming one of
  that lender's own resources through `budget_entries.resourceId`, exactly the reading
  `ocptBudgetRepaidContributionsTotalOf` already gives the whole plan — a repayment recorded against
  any one of several resources grouped under the same lender lands on that lender's own line, never
  a sibling's. **`OcptBudgetSharingPot`'s own arithmetic is untouched**: this is a presentation
  layer over readings the pot already computes, not a second way of computing them, and the card's
  existing three-line footer (the reimbursable total, what has already gone back, what is left to
  share) stays exactly as it was, now sitting under the per-lender detail rather than being the
  whole card.
  **No remainder is redistributed.** Each participant's due is `shareableCents × sharePermille ÷
  1000`, rounded on its own, in integer arithmetic throughout — so three participants splitting a
  thousand cents in thirds are each due 333 and the missing cent stays visible. Handing it to
  whoever happens to be listed last would be the app deciding a question the participants have not.
  For the same reason the shares are **stated, never policed**: `ocptBudgetSharesPermilleTotal`
  against `1000` is a line the table prints only when the two differ, showing what the shares as
  written claim (`ocptBudgetDueTotalCents`) beside what there actually is to share, which is the
  only way a reader can see that the plan does not add up — and `OcptBudgetSharesTable` refuses to
  reject the write for the reason its own doc comment gives.
  `OcptBudgetShareSplit` is named `…Split` rather than `…Row` because `OcptBudgetShareRow` is
  already drift's own data class for `budget_shares`, and a computed reading and a stored row must
  not wear one name.

## A taking is received by being named, a participant is paid the same way

- `budget_revenues` carries **no received amount** and `budget_shares` **no `paidCents`**, and that
  is the fourth and fifth time this mode has refused the same shape for the same reason: a poste
  keeps no `quotedAmount`, a commitment no `settled` flag, a resource no `receivedCents`, because a
  stored second copy of one truth has to be kept in step by a write nobody can guarantee never to
  forget. A taking's own row states what was **expected** — its date, its label, the amount and how
  far its paperwork has got — and the journal states what **arrived**: the sum of the
  `budget_entries` credits naming it through `budget_entries.revenueId`
  (`ocptBudgetReceivedByRevenueId`, `lib/utils/ocpt_budget_shares.dart`). What a participant has
  actually been paid is the mirror image, read off the other column: the debits naming them through
  `budget_entries.shareId` (`ocptBudgetPaidByShareId`). Both go through
  `ocptBudgetEntryCreditCentsOf`/`ocptBudgetEntryDebitCentsOf` rather than the raw columns, so a row
  missing the rate it would need is *covered-but-incomplete* rather than wrong, and both answer an
  `OcptBudgetCoveredTotal` for that reason.
  `OcptBudgetRevenueStatus` is therefore **flat and three-valued** (`expected`, `confirmed`,
  `invoiced`) and deliberately carries **no `cashed`**, which is exactly the argument
  `OcptBudgetCommitmentStatus` already makes for its own missing `settled`: a status living beside a
  figure the journal already answers would be that second copy again. A prize announced in February
  and paid in June is one row and one entry, and the resources tree tells the two apart by printing
  the expected amount as a quiet second line whenever it differs from what came in.
  The two gestures follow from the shape: **`Receive`** on a taking, reached from the resources
  tree's own row menu or from the fiche once it is selected, and **`Record a payout`** on a
  participant, reached from the sharing document, both open `OcptBudgetEntryDialog` pre-filled and
  dated today — a credit for whatever the taking still has outstanding, a debit for whatever the
  participant is still owed — exactly as a resource's own `Record a receipt` and a commitment's
  `Settle` already do, so neither a receipt nor a payout can ever exist as a figure with no movement
  behind it.
  **A debit naming a taking is not subtracted, and a credit naming a participant is not either.** A
  refunded taking and a participant handing money back are each movements of their own, and neither
  is a claim that what already happened did not.

## An in-kind contribution is valued, not collected

- **Creating a resource is three explicit gestures, one per `OcptBudgetResourceGroupKind`, not
  one.** Adding a camera that is valued is not the same gesture as adding real money that is going
  to buy the crew lunch, even though both end up as a `budget_resources` row — the product owner
  could not tell a valuation from real money through a single `Resource` button, which opened one
  form for all three kinds with no word said about which one was being created.
  `_OcptAddResourceButton` replaces it: a `MenuAnchor` anchored on one button, naming the three
  kinds (`Subvention`/`Apport en numéraire`/`Apport en nature` in French), chosen over three
  separate buttons the tree's own header row has no width to spare for, and over a `Wrap` of
  `MenuItemButton`s, which throws the moment a `MenuAnchor` hands one an unbounded width
  (`AGENTS.md`'s own known pitfall). Picking one opens `OcptBudgetResourceDialog` with that kind
  already set and named in the dialog's own title (`New subsidy`/`New cash contribution`/`New
  in-kind contribution`) — its own `Group` picker is not drawn while creating, since the kind is
  already decided by the very gesture that opened the dialog, and offering it again one field later
  would let that gesture be second-guessed for no reason a reader could name. **The kind stays
  editable on an existing resource**: the picker returns the moment the dialog opens on one, exactly
  as it always has, since a production is free to reclassify a resource it already created.
  Once the kind is known, the `Amount` field's own label and helper text are worded for it — an
  in-kind contribution's figure is `Valued at`, what it is *valued at*, never an amount that will be
  received, while a subsidy or a cash contribution keeps the plain `Amount` label — and the `Status`
  field's own chips are worded for it too, alongside a helper saying what progress means for that
  kind ("The word a status is called is the group's", above).
- A resource row is **selected and opens the fiche**, whose own primary action is described in "The
  fiche is one panel for seven kinds of row" above. `OcptBudgetState.selectedResourceId` is a plain
  getter folding onto `selection`, reconciled against a freshly loaded snapshot exactly as
  `selectedPosteId` is — see "Selecting a poste and filtering by one are two different facts".

## The four documents

- The mode prints four, each reached the way every export in this app is — the toolbar's own
  `Export` control, never a tab of its own (`exports.md`), and a native save dialog every time:
  the **quote** (PDF, the whole nomenclature poste by poste with its lines), the **financing plan**
  (PDF, its contributions in kind kept visibly apart, which is the whole point of the document for
  a commission), the **cash journal** (XLSX, every entry in the order money actually moved, with
  its voucher number) and the **financial report** (PDF, the quote read against what has actually
  been paid and what is still committed, with the variance). The two the reference paperwork also
  names — the statement of justified spending and the in-kind contributions certificate — are on
  the roadmap rather than rushed.
  Every honesty rule the screens keep, the documents keep. A total that is not
  `OcptBudgetCoveredTotal.isComplete` prints the same coverage read-out beside it rather than a
  figure standing in for the rows it does not cover; a running balance the journal could not read
  writes an **empty cell**, never the balance before it; an `inKind` resource no entry names prints
  the empty-value mark for received and outstanding; and the needs/resources balance gives the same
  three-way verdict — no quote yet, covered, or short by an amount — rather than declaring a
  financing plan sufficient against a quote nobody has begun (`OcptBudgetNeedsResourcesBalance`,
  read by these documents alone now that the live screen draws its own two-tone reading instead —
  see "The financing view says what covers the film, twice" above).
  **The financial report reads the cost-tracking table's own off-quote reading too.** It draws an
  `Off quote` row, reusing the cost-tracking table's own label
  (`tr.budgetCostTrackingOffQuoteLabel`), between the last poste and the totals row, only while
  `snapshot.offQuotePaidTotal` holds anything (`OcptBudgetFinancialReportPdfService._offQuoteRow`) —
  its `Quoted`, `Committed`, `Remaining` and `Variance` cells print the empty-value mark, since there
  is no quote behind it to measure any of them against, and only its `Paid` cell carries a figure.
  The totals row's own `Paid` cell folds every poste's own paid total with the off-quote total
  (`ocptBudgetCoveredTotalsFoldOf`, the very fold the cost-tracking table's own total row already
  uses), so that column adds up to what actually left the account, printing the coverage read-out
  the moment either side is incomplete.
  **Only the quote offers a tax basis**, and its dialog opens on whichever one the header was
  already showing, so the document somebody exports is the one they were just reading. The other
  three are money that has moved or money coming in, which "Money that has moved is read
  tax-inclusive, always" (above) settles once for the whole mode.
  **A card that cannot print is greyed and inert with the reason in its description, never
  hidden** — the quote and the financial report while the project holds no live poste at all (every
  one of the ten seeded CNC postes can be deleted), the financing plan while it holds no resource,
  the cash journal while it holds no entry. Each is a real, reachable state, and a card that
  vanished would make the panel lie about what the mode knows how to print.
  The services (`lib/managers/export/services/ocpt_budget_*`) see **no `Tr` at all**: every heading,
  column title, group name, status name and verdict sentence arrives as one of four labels classes
  the mode resolves (`ocptBudgetQuoteLabelsOf` and its three siblings,
  `lib/ui/utils/ocpt_budget_labels.dart`). Two of those fields are **raw templates** the manager
  fills in at export time, `{amount} · {coveredCount} of {totalCount} known` and its shortfall
  sibling, because a coverage read-out is built per total, deep inside a service that cannot ask
  `Tr` for anything. `intl_utils` reads any `{word}` in an ARB string as an ICU argument whatever
  the `placeholders` map says, so the template is resolved through `Tr` with **the placeholder
  names themselves** as its arguments — which keeps each locale's own word order — and handed on as
  a plain string for the service to substitute into. The indirection is stated in the two ARB keys'
  own descriptions and at the helper that performs it, since it would otherwise read as a mistake.
