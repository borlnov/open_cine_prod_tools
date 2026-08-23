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
The mode is complete: its seven views and its four documents
are all here, and this file is the whole record of them.

## Who it serves, and what the mode now shows

- `lib/ui/pages/workspace/modes/budget/` has to serve two readers who want different documents
  from the same figures: the **commission**, which expects the CNC nomenclature, a financing plan
  with its in-kind contributions valued separately and a final report against the quote; and the
  **production that shot the film with five people**, whose real account book is a debit/credit
  journal with free categories, a meals sheet and a sharing sheet. Nothing about the mode so far
  favours one reader over the other — it builds the one document both eventually need, the quote,
  and then the ledger both eventually keep, the cash journal that measures what has actually moved
  against it and what is still owed, and now the financing plan that measures against the quote in
  turn, and finally the revenue sharing that splits what the finished film earns.
  `OcptBudgetCentreView` holds all seven the mockup validates — `dashboard`, `costTracking`,
  `cashJournal`, `committed`, `financing`, `regie` and `sharing` — and is **complete**: every value
  joined it at its own end, as the milestone that gave it real content landed, so a stored
  preference never pointed at a view that had moved. That reading was proved out three times
  (`cashJournal`/`committed`, then `financing`/`regie`, then `sharing`) and is the one an eighth
  view, should the roadmap ever want one, has to repeat.

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
  number that looks like the account's balance while actually being something else. The cash journal
  view's own poste filter is not a piece of state of its own for exactly this reason — it is
  `OcptBudgetState.selectedPosteId`, the very same field the cost-tracking table already writes when
  a row is clicked, read again here rather than duplicated. Selecting a poste there and switching to
  `cashJournal` lands already filtered to it, and the two views agree on what "filtered by this
  poste" means because they are reading one flag rather than two that could drift apart.

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
  the financing and revenue-sharing views (`ocptBudgetReceivedByResourceId`,
  `ocptBudgetReceivedByRevenueId`); folding it into a reading about spending would count the same
  euro twice, once as a resource received and once as a cost.
- `OcptBudgetCostTracking` draws this total as **one extra row, `Off quote`**, between the last
  poste and the `Total` row, and **only while there is something to show**
  (`OcptBudgetCoveredTotal.lineCount` above zero) — a row with nothing in it would claim a category
  the project does not have, exactly the argument `OcptBudgetFinancing` already makes for declining
  to draw a group card holding no resource. Only its own `Paid` cell carries a figure; `Quote`,
  `Committed`, `Remaining`, `Variance` and `Consumed` all print `ocptBudgetEmptyValue`, since there
  is no quote behind this row to measure any of them against — the same silence `Consumed` already
  keeps for a poste with no quote at all. It carries **no `N°`, no `⋮` menu and no selection**: it
  is not a poste and nothing about it may look like one, since it is a reading over the journal's
  own poste-less debits, not a record anybody can rename, reorder or delete — clicking it does not
  set `OcptBudgetState.selectedPosteId`.
- The table's own `Total` row folds `paidByPosteId` and the off-quote total together
  (`ocptBudgetCoveredTotalsFoldOf`, `lib/utils/ocpt_budget_totals.dart`, the same fold the
  dashboard's own KPIs use) into its own `Paid` cell, so that column adds up to what actually left
  the account — the only reading a reader adding the column up themselves would accept — printing
  the fold's own coverage read-out (`tr.budgetCostTrackingPaidCoverageReadOut`) whenever either side
  is incomplete. The dashboard's own `Paid` KPI folds the very same two totals for the very same
  reason, so it agrees with the cash journal instead of quietly disagreeing with it.
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
  as still owed, would double the very same movement. It keeps its row in the committed-spending
  view regardless, marked settled rather than removed, since a production still wants to see what it
  once owed and to whom.
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

## The mode's own shape

- **One budget for the whole production, not one per episode** (ADR 0019): `budget_postes` and
  `budget_lines` name no episode at all, so `OcptBudgetMode` keeps the shell's own
  `onEpisodeSelected` null, exactly as the schedule mode already does and for the schedule's own
  reason — a selector would filter a read that was never split by episode to begin with, not a
  standing-in for a bloc this mode does not have; it has one. There is **no left dock**, the mockup
  showing none for this milestone's views, and the right dock offers exactly three tabs
  (`OcptBudgetRightDockTab`): `Inspector`, the selected poste's own figures, its quote lines — each
  a card collapsed to a summary row and expanding **in place**, never into a dialog, into its own
  editable fields (quantity, unit, unit price, whether it includes tax, and the rate it reads
  under) — and, since the journal exists, its own **related entries**: the cash journal's live
  entries naming this poste, newest first, a debit and a credit told apart by
  `ColorScheme.error`/`.primary`, printing the em dash for an entry it cannot read and a coverage
  read-out the moment some of them are; the shared `Versions` tab every mode carries; and `Help`.

## The mode explains itself

- The product owner used the mode and still could not say what told `financing`, `cashJournal` and
  `committed` apart — a real defect the screens alone never fixed, however each one's own figures
  were made honest. `OcptWorkspaceToolbar` therefore gains a nullable `helpAction` slot, the same
  shape and idiom as `exportAction`/`dockToggles`/`saveAction`/`projectSettingsAction`
  (`foundations.md`): a mode with nothing to explain renders no button at all, and every mode but
  this one leaves it null. Clicking it dispatches the very same `OcptBudgetRightDockTabSelectedEvent`
  the dock's own tab row already sends, naming `OcptBudgetRightDockTab.help`, so the toolbar button
  and the dock tab are one gesture rather than two: opening the dock on `Help`, and closing it again
  on a second click while `Help` is already showing — the toggle every other dock control already
  has. `OcptBudgetHelp` (`lib/ui/pages/workspace/modes/budget/widgets/`) **writes nothing**, exactly
  the argument the dashboard already makes for itself, so it carries no `isReadOnly` flag and is
  offered identically under a previewed version — unlike `OcptBudgetRegie`, which gained one the day
  it started writing defrayals.
  Its content follows `OcptBudgetState.centreView`: switching the header's own chips changes what the
  panel says, with no extra click, since the dock stays open on `Help` across a chip change exactly
  as it stays open on `Inspector` across a poste selection.
  Every page opens with the same small map before its own substance — the map *is* the answer to the
  product owner's own question, crossing what is only **promised** against what has **actually
  moved**, and money **coming in** against money **going out**: `financing` is the promised-coming-in
  cell, `committed` the promised-going-out cell, and `cashJournal` the whole has-moved column at
  once, since the journal is where both a credit and a debit are read. The quote is stated as sitting
  outside the map entirely — it prices what the film is *planned* to cost, and nothing in the map
  feeds it or is fed by it. The current view's own cell, when it has one, is highlighted; `dashboard`,
  `costTracking`, `regie` and `sharing` occupy none of the four, each reading across the whole map or
  a different figure entirely rather than standing in one cell of it. Under the map, one short page
  per view states its own substance in the plain language this file already argues for it in, every
  cross-reference to a figure or another view worded exactly as its own on-screen label or chip
  already reads, resolved as an ICU argument (`intl_utils`'s own convention, "The four documents"
  below) rather than restated by hand — so the help text can never drift from the very word it is
  pointing at.
  The header's six view chips (`Dashboard`, `Quote`, `Planned`, which stands for two views at once
  (see "What is promised is one place, read in two directions"), `Flux de trésorerie` in French —
  `Cash flow` in English, deliberately renamed off "Journal de caisse" once that first choice
  turned out to name a petty-cash book rather than the bank account the view actually reads, and
  off `Cash journal`/`Trésorerie` once the pair `Quote`, `Planned`, `Cash flow` turned out to read
  as one sentence — `Régie` in French — `Catering & travel` in English, the same asymmetry and for
  the same reason: the trade word has no one-word English equivalent — and `Revenue sharing`) and
  its two further toggles, simplified/detailed and excluding/including-tax, are
  **always offered, whatever the project holds**: neither is ever withheld or disabled according to
  the state of the data, there is no conditional branch in
  `OcptBudgetHeader` at all, only a value that may turn out empty once the centre reads it.
  **No chip is worded by the simplified reading, and none should be.** Two were: `Cash journal`
  and `Committed` are trade words, and the switch handed a five-person crew `Spending` and `To pay`
  instead. Both re-wordings lost their reason at once — the journal's chip now says `Cash flow`,
  which needs no plainer synonym and is what the band and the help panel say too, and the committed
  spending is no longer a chip at all but one half of `Planned`, reached through a sub-switch that
  words itself in either reading. What the simplified toggle still governs is the ten CNC poste
  labels (`budget_postes.simpleLabel`) and the two empty-state sentences that name the ledgers in
  prose: real translations of opaque trade language, unlike a second name for a view that already
  said the plain thing it was.
  **The chips are deliberately not in `OcptBudgetCentreView`'s own order.** That enum grows strictly
  by the end, so a value never moves under a reader who stored one; the header, by contrast, lists
  its segments explicitly and orders them so that reading the bar left to right *is* the
  explanation: `Quote`, `Planned`, `Cash flow` — what the film should cost, what is promised in
  either direction, what has actually moved — then what the shoot eats and drives, then, long
  after all of it, what the finished film earns.
  `Cash flow` used to sit ahead of `Planned`, on the ground that a production keeping a cash flow
  and doing no planning at all should not have to walk past two forecasting views to reach the one
  it opens daily. That reasoning undervalued what the three chips say in a row: a reader who has
  that order once needs no explanation of any single view again, whereas reaching a daily view one
  chip further along is a cost paid once per session.
  `_OcptBudgetCentreViewSwitch` says so where the segments are listed, since a divergence nobody
  argued for would look like a mistake the next time somebody adds a view. Each chip also widens
  that one switch, so `_ocptBudgetHeaderTitleMinWidth` — the width under which the header sheds its
  title rather than crowd its controls — moves out by a segment's own width every time one lands.
  **Shedding the title is not enough on its own**, and the header does not stop there: under that
  same threshold the three controls **wrap onto a second line**, and the seven chips wrap inside
  their own border too, as `OcptScheduleHeader`'s controls already do. The centre narrows for a
  reason the header cannot see — the right dock opening takes roughly 580 px of it — and a plain
  `Row` then clips silently in release, which had been taking the tax-basis switch off the screen
  altogether. A control scrolled out of a clipped row is worse than a disabled one: nothing on
  screen says it exists. `OcptBudgetFinancing`'s own KPI row wraps for the same reason, its three
  captioned figures having outgrown any centre under roughly 1,120 px.
  Every
  other write in the mode lands the instant it is dispatched — a tax-basis radio, a reorder, a
  delete, a creation — while the free-text fields alone (`OcptBudgetField`: a poste's label and
  code, a line's label, quantity, unit, unit price and notes) ride a 2 s autosave debounce, flushed
  on a selection change, a dock tab change, **a change of centre view or of either header toggle**,
  entering a version preview and the mode's own `deactivate()`. Those three last paths were added
  after the fact and are the reason the mode once looked like it ignored what it was told: an
  amount typed in the cost-tracking table and followed straight by a click on `Dashboard` was still
  sitting in the debounce, so the dashboard drew the snapshot from before it and corrected itself
  two seconds later. The write was never lost; it simply was not shown. Every path that stops the
  typing and starts the reading has to flush.
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

## The dashboard's two alerts compute themselves, and ask for no threshold

- `ocptComputeBudgetAlerts` (`lib/utils/ocpt_budget_alerts.dart`, pure) raises exactly two kinds of
  alert, and both are read straight off arithmetic the mode already has rather than a figure typed
  in on purpose for the alert's own sake: a poste whose paid plus committed already exceeds its own
  quote (`ocptBudgetPosteStrainOf` answering `over`, paired with `ocptBudgetVarianceCents`'s own
  figure), and the cash projection (`ocptBudgetProjectionOf`, opened at the journal's own balance
  over the unsettled commitments) going negative, at the date and by the amount its own first
  negative step already says. The mockup's own 1,500 € cash floor is deliberately not a third alert:
  it was calibrated by nobody, and it is not the app's place to advance a figure nobody here
  validated — the same argument `minimumRestMinutes` already settled for a single column, applied
  here to a whole mode. Each alert card offers exactly one action back into the data it is about:
  a poste over its quote selects that poste and switches to `costTracking`, the projection going
  negative switches to `committed` — never a dismiss, since the alert is not a notification to clear,
  it is a standing fact about the project that stays true until the underlying figures change.

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

## What the mode still does not show

- The cash journal changed what this section can honestly say, not just what it has to say: for as
  long as `budget_entries` and `budget_commitments` did not exist, "nothing paid" and "nothing known
  about what was paid" were the same unavoidable fact, and the app printed the em dash for both
  rather than claim the second when it only ever knew the first. Now that the journal is real,
  `OcptBudgetSnapshot.paidCentsOf` and `.committedCentsOf` answer **zero**, in cents, the moment
  their own map carries no entry for a poste — its own doc comment states plainly why that `?? 0` is
  the honest reading now and would not have been before: the app has gone from *not being able to
  know* whether anything had moved against a poste to *knowing that nothing has*, and a fact
  established is not a fact withheld. `Paid`, `Committed`, `Remaining` and `Variance` therefore
  always print a real amount today. `Consumed` alone still prints `ocptBudgetEmptyValue`, and for a
  reason that has nothing to do with the journal: it is a ratio, paid-plus-committed over the quote,
  and a poste with no quote at all makes that a division by zero — a figure that cannot exist rather
  than one that happens to be absent, which is a different silence from the one this section used to
  describe and survives regardless of what the journal ever learns.
  Nothing else is missing: `budget_revenues` and `budget_shares` landed with the sharing view, and
  the silences this mode still keeps are all of that same kind — a figure that cannot exist rather
  than one nobody has entered yet.

## A resource is received by being named, and a rate is nobody's to seed

- `budget_resources` carries **no `receivedCents` column**, and that is the third time this mode has
  refused the same shape for the same reason: a poste keeps no `quotedAmount` and a commitment keeps
  no `settled` flag, because a stored second copy of one truth has to be kept in step by a write
  nobody can guarantee never to forget. What has come in against a resource is the sum of the
  `budget_entries` **credits** naming it through `budget_entries.resourceId`
  (`ocptBudgetReceivedByResourceId`, `lib/utils/ocpt_budget_financing.dart`), read through
  `ocptBudgetEntryCreditCentsOf` like every other movement rather than off `creditCents` raw, so a
  resource whose entries are missing the rate they would need is *covered-but-incomplete* rather
  than wrong. That link is also what makes `resourceId` earn its place: `OcptBudgetFinancing`'s own
  **`Record a receipt`** gesture mirrors the commitment's `Settle` exactly — it opens
  `OcptBudgetEntryDialog` pre-filled as a **credit**, dated today, for whatever is still outstanding,
  with the resource already named, so a receipt can never exist as a figure with no movement behind
  it.
  **`Record a receipt` is withheld — never disabled — once a resource is fully received (received
  `>=` amount) and on any in-kind resource at all, entered or not.** A contribution in kind is
  valued rather than collected (see "An in-kind contribution is valued, not collected" below), so no
  cash will ever move for it and the gesture has nothing to offer; a resource whose received total
  already meets its own amount likewise has nothing left to receive, though a **partially** received
  one keeps offering it — several instalments landing against the one resource is the ordinary case,
  not an edge one. **`Undo the last receipt`** is the way back: offered once a resource has received
  anything at all, it resolves the most recently recorded live credit naming that resource
  (`ocptBudgetLatestReceiptEntryIdOf`, `lib/utils/ocpt_budget_financing.dart`, reading [entries] in
  the very same chronological order the journal itself is loaded in) and, once `OcptConfirmDialog`
  confirms it, dispatches the very same `OcptBudgetEntryDeletionConfirmedEvent` the cash journal's
  own `Delete` already uses — tombstoning the entry (ADR 0010) rather than a second delete path of
  its own, and never un-receiving the resource through any figure of its own, since
  `budget_resources` stores none.
  **A debit naming a resource is deliberately not subtracted.** Repaying a reimbursable contribution
  does not un-receive it — the money did come in — and what a production has paid back is the
  revenue-sharing view's own subject, not a correction to this figure. This is also why `Undo the
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

## An in-kind contribution is valued, not collected

- `OcptBudgetFinancing` groups the plan by `OcptBudgetResourceGroupKind` — subsidies, cash
  contributions, contributions in kind — one bordered card each, a group holding no resource simply
  not drawn, since an empty card with a zero subtotal states nothing. `OcptBudgetResourceStatus` is
  **flat and three-valued** (`pending`, `agreed`, `confirmed`) — three *steps*, deliberately
  anonymous, because the word a step is called belongs to the group and not to the enum: see "The
  word a status is called is the group's" below.
  The one silence this view keeps is a different thing from a withheld affordance: an `inKind`
  resource prints `ocptBudgetEmptyValue` for both *received* and *outstanding* **while no journal
  entry names it**, because a contribution in kind is valued rather than collected — no cash will
  ever move for it, so "how much of it has arrived" is not a question with an answer, exactly the
  silence `Consumed` already keeps for a poste with no quote (see "What the mode still does not
  show"). The moment an entry does name such a resource the real figures are printed instead: the
  app never hides a movement that actually happened.
  **Creating a resource is three explicit gestures, one per `OcptBudgetResourceGroupKind`, not
  one.** Adding a camera that is valued is not the same gesture as adding real money that is going
  to buy the crew lunch, even though both end up as a `budget_resources` row — the product owner
  could not tell a valuation from real money through the single `Resource` button this view used
  to offer, which opened one form for all three kinds with no word said about which one was being
  created. `_OcptAddResourceButton` replaces it: a `MenuAnchor` anchored on one button, naming the
  three kinds (`Subvention`/`Apport en numéraire`/`Apport en nature` in French), chosen over three
  separate buttons the KPI row has no width to spare for beside its own three figures, and over a
  `Wrap` of `MenuItemButton`s, which throws the moment a `MenuAnchor` hands one an unbounded width
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
  kind ("The word a status is called is the group's", below).
  A resource row is **selected and highlighted, and opens no inspector**. The right dock's
  `Inspector` tab is built entirely around a poste's own quote lines, and a resource has none;
  growing a conditional branch onto that dock, or inventing a second inspector concept beside it,
  would both cost more than the reading is worth. `OcptBudgetState.selectedResourceId` is therefore
  a plain highlight, reconciled against a freshly loaded snapshot exactly as `selectedPosteId` is.

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

## What is promised is one place, read in two directions

- The financing plan and the committed spending share **one header chip, `Planned`**
  (« Prévisionnel »), and a sub-switch drawn inside the view — `OcptBudgetPlannedSubSwitch` —
  moves between `Coming in` and `Going out`. Seven chips asked a reader to hold as two separate
  places what is one reading in two directions: money that is promised and has not moved, owed to
  the production or by it. The cash journal, which answers the other half of that question, needs
  no such split because a debit and a credit already sit in one table.
- **The two words are the help panel's own.** Its map already reads `Coming in`/`Going out`
  against a `Promised`/`Has moved` split, and this view is that map's promised column: naming the
  sub-switch in the map's words is what lets the help explain the mode once. The ARB keys stay
  separate, being two different surfaces.
- **`OcptBudgetCentreView` keeps both values.** They are one place in the mode but two things to
  remember, and `OcptPropertiesManager.budgetLastCentreView` has to be able to point at the half a
  reader left the mode on. The chip therefore reads active for either — `_OcptBudgetSwitchSegment`
  gained an `alsoActiveFor` set for it — and, being active, takes no click, so a reader on `Going
  out` is never thrown back onto `Coming in` by the chip they are already under. Reached from
  anywhere else, the chip lands on the financing plan.
- The help panel is untouched by the merge: each half keeps its own page, its own title and its own
  cell in the map, because the help speaks about the view actually on screen, never about the chip
  above it.

## The journal scrolls rather than losing a column

- The cash journal's table gives every column but `Label` a fixed width, and `Label` takes what is
  left. Below the sum of the fixed ones the flexible column was driven to **nothing** and the row
  overflowed its frame: with the right dock open on a laptop screen the wording of every entry
  disappeared outright and the balance column ran off the edge, clipped rather than striped, since
  a release build draws no overflow banner.
- The table is therefore laid out at `_ocptCashJournalMinTableWidth` (960 = 728 of fixed columns +
  232 for the wording) whenever the slot is narrower, and **scrolls sideways inside its own frame**.
  The header and the rows sit in the same scroll view, since they share those fixed widths and
  scrolling either alone would slide the figures out from under their own headings. No column is
  dropped and none shrinks: what does not fit is scrolled to, which is the treatment the rest of the
  app already gives a table too wide for its slot.

## An add button shows one plus, not two

- Every creation control of this mode that carries an `Icons.add` icon has a label with **no `+` of
  its own**: `Poste`, `Add`, `From breakdown`, `Entry`, `Commitment`, `Resource`. The icon already
  says what the gesture is, and a label repeating it drew the sign twice side by side.
- **The `+ ` prefix is not wrong everywhere** — it is the house convention for a *text-only*
  affordance, which is why the resources mode's own `+ Add a person` keeps it, and why the sharing
  view's own `+ Taking`/`+ Participant` footers do too: they are plain `InkWell`s with no icon, so
  the sign in the text is the only thing marking them as adding anything. The rule is one plus per
  button, wherever it lives.

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
  `OcptBudgetResourceGroupKind` **and** its step. Nine words, three steps, one stored column: a
  subsidy is `Applied`, `Notified`, `Secured`; a cash contribution `Requested`, `Agreed`,
  `Contracted`; a contribution in kind `Promised`, `Valued`, `Signed`. In French, where the gender
  follows the group's own noun: `Déposée`/`Notifiée`/`Acquise`, `Sollicité`/`Accordé`/
  `Contractualisé`, `Convenu`/`Valorisé`/`Signé`.
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
  [_ocptRegieWrapWidth] the two stack rather than crush each other, and the defrayal table itself
  has a floor of 580 px below which it scrolls sideways, exactly as the journal's own does.
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

## The dashboard reads the financing plan once it exists

- The dashboard's own KPI row gains a `Total resources` tile the moment `budget_resources` does —
  `ocptBudgetResourcesTotalCents`, with how much of it is in kind
  (`ocptBudgetResourcesTotalByGroupKind`) as a smaller second line — mirroring every other tile
  already there. Under it, a **needs/resources balance bar**
  (`ocptBudgetNeedsResourcesBalanceOf`, `lib/utils/ocpt_budget_financing.dart`) states the quote's
  own total against the financing plan's own total and, underneath, either that the two balance or
  by how much the plan still falls short.
  **The needs side is read tax-inclusive, always, whatever the header's own basis toggle currently
  shows.** A resource is money coming in, and "Money that has moved is read tax-inclusive, always"
  (above) already settles that there is only one honest basis for that; comparing an
  excluding-tax quote against a tax-inclusive resource would compare two different figures while
  looking like it compared one, so the bar's own needs total is `ocptBudgetTotalOf`'s own
  including-tax reading, resolved once here and never through `OcptBudgetState.taxBasis`. Whenever
  that total is not `OcptBudgetCoveredTotal.isComplete`, the bar prints the very same coverage
  read-out the cost-tracking table's own total row already does
  (`tr.budgetCostTrackingCoverageReadOut`) rather than a second wording for the same fact.
  **And a quote with no line at all gets no verdict.** A plain `resources >= needs` reading answers
  "balanced" for a project that has recorded nothing, declaring the financing plan sufficient
  against a quote nobody has begun — the sort of claim the data cannot support that this mode
  refuses everywhere else. The message is three-way rather than two: no quote yet, covered, or short
  by an amount. The bar itself is drawn either way, nothing disappearing from the screen; it simply
  stops asserting a verdict it has no grounds for, exactly as `Consumed` prints the em dash for a
  poste with no quote rather than a ratio it cannot compute.
  A third card, **"what feeds this budget"**, reads three other sources the quote itself never
  types: how many breakdown elements a quote line already prices and how many still are not (see "A
  quote line can price a breakdown element" below), how many shooting days the schedule holds — the
  base every per-day poste is quoted against — and the meals and buffet servings the schedule's own
  timetable already produces. Each row reports a click upward, through the workspace bloc rather
  than navigating on its own: the breakdown row opens the resources mode's elements tab with nothing
  selected (`OcptResourcesRevealRequest(tab: OcptResourcesTab.elements, recordId: null)`, the same
  request the breakdown mode's own `Open in Resources` already uses, its `recordId` deliberately
  null since the card names a count, not one element), the schedule row switches to the schedule
  mode, and the catering row switches this very mode to its own `regie` view.
  **The unpriced-elements count is deliberately not a third alert.** `ocptComputeBudgetAlerts`'s own
  two rules are each a standing fact that something is wrong; a dozen elements still waiting to be
  priced during preparation is the normal state of a production still building its breakdown, true
  for months on end, which is exactly the register this card states things in rather than the
  alerts row's.

## A quote line can price a breakdown element

- `budget_lines.elementId` is what crosses a quote line with the *dépouillement*'s own elements
  catalogue: `OcptBudgetPosteInspector`'s own `From breakdown` gesture opens a picker over every
  live element no live line names yet, and creating one from it writes a line whose label is the
  element's own name, whose `elementId` names it, and whose `unitAmountCents` is `OcptElement.cost`
  — `OcptBudgetQuoteService.createLine`'s own widened signature, called the same way the ordinary
  `Add` footer already calls it, minus the two arguments that footer leaves at their default.
  **A null `elements.cost` is not a zero unit price.** `elements.cost` is nobody's business to have
  filled in yet during preparation, and a line minted from it is passed [Value.absent] rather than
  `Value(0)` for exactly that reason: the fresh line is left at `budget_lines.unitAmountCents`'s own
  ordinary default, reading exactly as a plain `Add` line already does, rather than claiming a
  price of zero that nobody has typed — the same "null, never zero" honesty `ocpt_budget_vat.dart`
  already keeps for a rate nobody has recorded.
  A line minted this way says so wherever it is drawn, in a second, quiet line under its own label —
  the element's own name — so a reader can tell a line typed from nothing apart from one that
  answers a real need the breakdown found, the same distinction the dashboard's own feed card counts
  by.

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
  and paid in June is one row and one entry, and the view tells the two apart by printing the
  expected amount as a quiet second line whenever it differs from what came in.
  The two gestures follow from the shape: **`Record a receipt`** on a taking and **`Record a
  payout`** on a participant both open `OcptBudgetEntryDialog` pre-filled and dated today — a credit
  for whatever the taking still has outstanding, a debit for whatever the participant is still owed
  — exactly as the financing plan's own `Record a receipt` and a commitment's `Settle` already do,
  so neither a receipt nor a payout can ever exist as a figure with no movement behind it.
  **A debit naming a taking is not subtracted, and a credit naming a participant is not either.** A
  refunded taking and a participant handing money back are each movements of their own, and neither
  is a claim that what already happened did not.

## The contributions come off the top, and no remainder is redistributed

- The order the sharing view states things in **is** the rule it exists to make legible, and
  `lib/utils/ocpt_budget_shares.dart` is where that order is arithmetic rather than layout: the
  takings come in, the reimbursable contributions are taken off the top, and only what is left is
  anybody's to split. `ocptBudgetReimbursableTotalCents` reads `budget_resources.isReimbursable` —
  the column the financing plan stored and no view read until the sharing landed — and nothing
  there branches on
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
  not wear one name. Like a resource row, a taking and a participant are **selected and highlighted
  and open no inspector**: the right dock's `Inspector` is built entirely around a poste's own quote
  lines, and neither of these has any.

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
  financing plan sufficient against a quote nobody has begun.
  **The financial report reads the cost-tracking table's own off-quote reading too.** It draws an
  `Off quote` row, reusing the cost-tracking table's own label
  (`tr.budgetCostTrackingOffQuoteLabel`), between the last poste and the totals row, only while
  `snapshot.offQuotePaidTotal` holds anything (`OcptBudgetFinancialReportPdfService._offQuoteRow`) —
  its `Quoted`, `Committed`, `Remaining` and `Variance` cells print the empty-value mark, since there
  is no quote behind it to measure any of them against, and only its `Paid` cell carries a figure.
  The totals row's own `Paid` cell folds every poste's own paid total with the off-quote total
  (`ocptBudgetCoveredTotalsFoldOf`, the very fold the dashboard's own `Paid` KPI and the
  cost-tracking table's own total row already use), so that column adds up to what actually left
  the account, printing the coverage read-out the moment either side is incomplete.
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
