<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the budget mode

The production's money, read honestly in whichever tax basis it was typed in: the quote against
the CNC nomenclature, the cash journal it is measured against — every entry the account has
actually seen, and every commitment still owed but not yet paid — the financing plan that says what
pays for all of it, and the catering and travel a shooting day actually costs, read off the
schedule rather than typed a second time. The revenue sharing alone is still ahead of it
(`docs/plans/budget-mode.md`).

## Who it serves, and what the mode now shows

- `lib/ui/pages/workspace/modes/budget/` has to serve two readers who want different documents
  from the same figures: the **commission**, which expects the CNC nomenclature, a financing plan
  with its in-kind contributions valued separately and a final report against the quote; and the
  **production that shot the film with five people**, whose real account book is a debit/credit
  journal with free categories, a meals sheet and a sharing sheet. Nothing about the mode so far
  favours one reader over the other — it builds the one document both eventually need, the quote,
  and then the ledger both eventually keep, the cash journal that measures what has actually moved
  against it and what is still owed, and now the financing plan that measures against the quote in
  turn. `OcptBudgetCentreView` holds the six views this stands for today — `dashboard`,
  `costTracking`, `cashJournal`, `committed`, `financing` and `regie` — of the seven the mockup
  validates; **revenue sharing** alone is still missing, reading tables no milestone so far holds at
  all (`budget_revenues`, `budget_shares`) — a value added for it today would be a header chip that
  opens onto nothing, which this app never draws. It joins the enum at its own end, as the milestone
  that gives it real content lands, so a stored preference never points at a view that has moved —
  the reading `cashJournal`/`committed`, then `financing`/`regie`, already proved out, one milestone
  after `dashboard`/`costTracking` did the same.

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
  before M3's catering pass. This is schema **v20**. `OcptProjectVersionCodec` gains both tables and
  the three columns in all three of its required places — the payload, `contentDigest` and
  `_applyPayload` — under **payload format 16**, whose upgrade from every earlier format
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
  below. This is schema **v21**. `OcptProjectVersionCodec`
  gains both tables and the `assets` column in all three of its required places under **payload
  format 17**, whose upgrade from format 16 **materialises** `budgetEntries` and `budgetCommitments`
  as empty lists and every `assets` row's `budgetEntryId` as null — a version sealed before the
  journal existed truthfully had no entry and no commitment, and no asset could yet reference one
  that didn't exist, exactly the reading format 16's own upgrade already gives the tables it
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
  `maxDailyPresenceMinutes`. This is schema **v22**. `OcptProjectVersionCodec` gains both tables and
  all three columns in all three of its required places under **payload format 18**, whose upgrade
  from format 17 **materialises** `budgetResources` and `budgetMileageRates` as empty lists and every
  `budget_entries.resourceId`, `people.commuteKmMilli` and `people.mileageRateId` as null — a version
  sealed before the financing plan existed truthfully named no resource and no rate, and no entry
  could name a resource that did not exist, exactly the reading format 17's own upgrade already
  gives what it materialises.

## The mode's own shape

- **One budget for the whole production, not one per episode** (ADR 0019): `budget_postes` and
  `budget_lines` name no episode at all, so `OcptBudgetMode` keeps the shell's own
  `onEpisodeSelected` null, exactly as the schedule mode already does and for the schedule's own
  reason — a selector would filter a read that was never split by episode to begin with, not a
  standing-in for a bloc this mode does not have; it has one. There is **no left dock**, the mockup
  showing none for this milestone's views, and the right dock offers exactly two tabs
  (`OcptBudgetRightDockTab`): `Inspector`, the selected poste's own figures, its quote lines — each
  a card collapsed to a summary row and expanding **in place**, never into a dialog, into its own
  editable fields (quantity, unit, unit price, whether it includes tax, and the rate it reads
  under) — and, since the journal exists, its own **related entries**: the cash journal's live
  entries naming this poste, newest first, a debit and a credit told apart by
  `ColorScheme.error`/`.primary`, printing the em dash for an entry it cannot read and a coverage
  read-out the moment some of them are; and the shared `Versions` tab every mode carries.
  The header's six view chips (`Dashboard`, `Cost tracking`, `Financing`, `Trésorerie` in French —
  `Cash journal` in English, deliberately renamed off "Journal de caisse" once that first choice
  turned out to name a petty-cash book rather than the bank account the view actually reads —
  `Committed`, and `Régie` in French — `Catering & travel` in English, the same asymmetry and for the
  same reason: the trade word has no one-word English equivalent) and its two further toggles,
  simplified/detailed and excluding/including-tax, are
  **always offered, whatever the project holds**: neither is ever withheld or disabled according to
  the state of the data, there is no conditional branch in
  `OcptBudgetHeader` at all, only a value that may turn out empty once the centre reads it.
  **The chips are deliberately not in `OcptBudgetCentreView`'s own order.** That enum grows strictly
  by the end, so a value never moves under a reader who stored one; the header, by contrast, lists
  its segments explicitly and orders them the way the money actually reads — the quote, then what
  pays for it, then what has moved, then what is still owed, then what the shoot eats and drives.
  `_OcptBudgetCentreViewSwitch` says so where the segments are listed, since a divergence nobody
  argued for would look like a mistake the next time somebody adds a view. Each chip also widens
  that one switch, so `_ocptBudgetHeaderTitleMinWidth` — the width under which the header sheds its
  title rather than crowd its controls — moves out by a segment's own width every time one lands. Every
  other write in the mode lands the instant it is dispatched — a tax-basis radio, a reorder, a
  delete, a creation — while the free-text fields alone (`OcptBudgetField`: a poste's label and
  code, a line's label, quantity, unit, unit price and notes) ride a 2 s autosave debounce, flushed
  on a selection change, a dock tab change, entering a version preview and the mode's own
  `deactivate()`. A line's VAT override is the one field with no direct mirror: an empty or
  unparseable submission reads as "leave the override exactly as it is," never "clear it," since a
  stray backspace must not silently drop an override typed on purpose — going back to inheriting the
  project's rate is its own dedicated, immediate gesture
  (`OcptBudgetLineVatRateInheritedRequestedEvent`), mirroring the project settings page's own
  `No rate` button for `defaultVatRateBasisPoints`.
  **The `Export` control is wired**, opening `OcptWorkspaceExportDialog<Never>` with an empty
  `entries` list — generic over `Never` because there is no document enum yet to be generic over —
  so the panel draws onto **no document at all**, its own standing project-package card being the
  one thing on it, exactly as `exports.md` describes that card as the dialog's own rather than any
  mode's. The exhaustive switch over the pick the panel returns still names the unreachable
  `OcptWorkspaceExportDocumentPick<Never>` case explicitly, rather than folding it into a bare
  `default`, so a real document enum added here at M4 has to be handled rather than silently falling
  through. Wiring the panel at all is what a bloc buys this milestone: `OcptBudgetBloc` mixes in
  `MixinOcptProjectPackageBloc` exactly as every other mode's bloc does, so a colleague can already
  receive this project as a portable `.ocptz` before the mode prints a single PDF of its own.

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
  What is still missing is exactly the two tables `budget_revenues` and `budget_shares` would feed:
  **revenue sharing** — the takings, the reimbursable contributions repaid before anything is split,
  and the split itself. It reads no byte the schema holds today, is argued in full in
  `docs/plans/budget-mode.md`, and joins `OcptBudgetCentreView` the day its own milestone gives it
  something real to show.

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
  **A debit naming a resource is deliberately not subtracted.** Repaying a reimbursable contribution
  does not un-receive it — the money did come in — and what a production has paid back is the
  revenue-sharing view's own subject, not a correction to this figure.
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
  **flat and four-valued** (`applied`, `notified`, `secured`, `valued`), nothing hidden or disabled
  according to which group a row sits in: `valued` is what an in-kind contribution normally wears,
  but it is the user who says so, not a branch in the code — the mode's standing rule that the UI
  carries no conditional branch on the state of the data.
  The one silence this view keeps is a different thing from a withheld affordance: an `inKind`
  resource prints `ocptBudgetEmptyValue` for both *received* and *outstanding* **while no journal
  entry names it**, because a contribution in kind is valued rather than collected — no cash will
  ever move for it, so "how much of it has arrived" is not a question with an answer, exactly the
  silence `Consumed` already keeps for a poste with no quote (see "What the mode still does not
  show"). The moment an entry does name such a resource the real figures are printed instead: the
  app never hides a movement that actually happened.
  A resource row is **selected and highlighted, and opens no inspector**. The right dock's
  `Inspector` tab is built entirely around a poste's own quote lines, and a resource has none;
  growing a conditional branch onto that dock, or inventing a second inspector concept beside it,
  would both cost more than the reading is worth. `OcptBudgetState.selectedResourceId` is therefore
  a plain highlight, reconciled against a freshly loaded snapshot exactly as `selectedPosteId` is.

## The catering and travel pass types nothing at all

- `OcptBudgetRegie` is the one centre view that **writes nothing, and therefore carries no
  `isReadOnly` flag at all** — a previewed version withholds nothing here, exactly the argument
  `OcptBudgetDashboard` already makes for itself. Every figure on it is typed somewhere else and
  read here: the head counts come from the schedule, the two unit prices from the project settings,
  and each traveller's distance and rate from their own sheet in the resources mode. That is the
  whole promise — nothing is entered twice — and it is why the view's three cross-links matter as
  much as its figures: each row reports upward and `budget_mode.dart` dispatches through
  `OcptWorkspaceBloc`, never navigation of the mode's own making, so a reader who disagrees with a
  number is sent to the one place it can be changed.
  **It reads `OcptScheduleSnapshot`, deliberately not `OcptSchedulePlanSnapshot`.** The plan snapshot
  is the obvious-looking type and the wrong one: it requires every episode's own shot list and the
  episode list, neither of which counting heads needs, and building one here would make the budget
  mode load the whole découpage to count meals. The schedule snapshot — the very field a plan
  snapshot wraps — carries days and slots, and a slot already carries its own live crew, cast and
  guests, which is everything `ocpt_budget_regie.dart` reads.
  The counting rules are all in that pure file and all stated on screen rather than hidden: a person
  convoked to three slots of one day **eats once**; a role counts as an extra exactly when its own
  `OcptRoleKind` says so, and a role the read cannot resolve counts as cast rather than as nothing,
  since it is still a convocation the production has to feed; and **a guest is not counted at all**
  — a visitor is not somebody the production convoked to work, which is the distinction ADR 0018
  already draws by refusing a guest a shooting band. One meal and one snack per head per shooting day
  is the only rule here a production might reasonably want to change, so the view prints it in the
  table's own caption rather than burying it in the arithmetic.
  A travel row crosses the presence grid with a person's **one-way** `commuteKmMilli`, doubled where
  the journey is counted rather than stored doubled, and the rate their own sheet names; the whole
  computation is integer arithmetic with a single rounding at the end, for the reason `quantityMilli`
  exists at all. A traveller who claims nothing — no distance, or no rate, or a rate id naming a row
  since tombstoned — is **still listed**, with the money silent and the trip count showing: that is
  how somebody discovers a distance nobody filled in, and dropping the row would make an absent
  figure indistinguishable from an absent person. Both of the view's totals are
  `OcptBudgetCoveredTotal`s printing the very same coverage read-out the cost-tracking table already
  does, for as long as a price, a distance or a rate is missing.

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
  A third card, **"what feeds this budget"**, reads three other sources the quote itself never
  types: how many breakdown elements a quote line already prices and how many still are not (see
  "A quote line can price a breakdown element" below), how many shooting days the schedule holds —
  the base every per-day poste is quoted against — and the meals and snacks the schedule's own
  presences already produce. Each row reports a click upward, through the workspace bloc rather than
  navigating on its own: the breakdown row opens the resources mode's elements tab with nothing
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
  catalogue: `OcptBudgetPosteInspector`'s own `+ From breakdown` gesture opens a picker over every
  live element no live line names yet, and creating one from it writes a line whose label is the
  element's own name, whose `elementId` names it, and whose `unitAmountCents` is `OcptElement.cost`
  — `OcptBudgetQuoteService.createLine`'s own widened signature, called the same way the ordinary
  `+ Add` footer already calls it, minus the two arguments that footer leaves at their default.
  **A null `elements.cost` is not a zero unit price.** `elements.cost` is nobody's business to have
  filled in yet during preparation, and a line minted from it is passed [Value.absent] rather than
  `Value(0)` for exactly that reason: the fresh line is left at `budget_lines.unitAmountCents`'s own
  ordinary default, reading exactly as a plain `+ Add` line already does, rather than claiming a
  price of zero that nobody has typed — the same "null, never zero" honesty `ocpt_budget_vat.dart`
  already keeps for a rate nobody has recorded.
  A line minted this way says so wherever it is drawn, in a second, quiet line under its own label —
  the element's own name — so a reader can tell a line typed from nothing apart from one that
  answers a real need the breakdown found, the same distinction the dashboard's own feed card counts
  by.
