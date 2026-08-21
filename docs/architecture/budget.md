<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Architecture — the budget mode

The production's money, read honestly in whichever tax basis it was typed in: the quote against
the CNC nomenclature this milestone (M1) builds, the cash journal, the financing plan and the
revenue sharing still ahead of it (`docs/plans/budget-mode.md`).

## Who it serves, and what M1 ships

- `lib/ui/pages/workspace/modes/budget/` has to serve two readers who want different documents
  from the same figures: the **commission**, which expects the CNC nomenclature, a financing plan
  with its in-kind contributions valued separately and a final report against the quote; and the
  **production that shot the film with five people**, whose real account book is a debit/credit
  journal with free categories, a meals sheet and a sharing sheet. Nothing about M1 favours one
  reader over the other — it builds the one document both eventually need, the quote, and stops
  there. `OcptBudgetCentreView` holds exactly the two views this milestone can honestly show,
  `dashboard` and `costTracking`: the mockup validates seven (financing, cash journal, committed
  spending, catering and travel, revenue sharing among them), and every one of the missing five
  reads a table this milestone's schema does not hold at all (`budget_entries`,
  `budget_commitments`, `budget_resources`, `budget_revenues`, `budget_shares`) — a value added for
  any of them today would be a header chip that opens onto nothing, which this app never draws.
  Each joins the enum, at its end, as the milestone that gives it real content lands, so a stored
  preference never points at a view that has moved.

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

## A poste's quoted amount is not stored

- `OcptBudgetPostesTable` carries **no `quotedAmount` column**, and `OcptBudgetPoste` carries no
  such field either: a poste's total is the sum of its own `OcptBudgetLine` rows, computed on every
  read rather than stored beside them. A stored figure would be a second copy of one truth, kept in
  step with the lines by hand or by a write nobody could guarantee never to forget — and the "frozen
  quote v4" the reference paperwork names is already what a project version *is*: sealing one
  freezes every poste and every line exactly as they stood, so a separate frozen-total column would
  freeze nothing a version doesn't already.

## The nomenclature is seeded, not frozen

- `lib/constants/ocpt_budget_cnc_postes.dart` declares the ten postes of the CNC nomenclature every
  French commission expects, each an `OcptBudgetCncPoste` carrying a **constant, hard-coded UUID**
  rather than one minted at seeding time — the very device schema version 18 already uses to derive
  `role_episodes.id` from the role it links: a deterministic id is what lets two replicas seeding
  the same project independently agree on ten rows rather than each minting their own ten for a
  merge to reconcile into twenty. `OcptBudgetQuoteService.loadPostes` seeds them (`_seedIfEmpty`)
  on the **first read of a `budget_postes` table holding no row at all, tombstones included** — not
  at project creation, so a project that predates this milestone gets them on its very next open,
  and not when the table holds even one tombstoned row, because a user who has deleted every poste
  has not asked for them back. Once seeded, a poste is an ordinary row from that moment on: renamed,
  reordered or deleted like any other, and never re-inserted by a later read.
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
  nullable `elementId` — declared now but read by no service before M3 — and free-form `notes`).
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
  under) — and its related entries, drawn and empty until M2 gives them content; and the shared
  `Versions` tab every mode carries.
  The header's two toggles — `Dashboard`/`Cost tracking`, simplified/detailed, and
  excluding/including-tax — are **always offered, whatever the project holds**: neither is ever
  withheld or disabled according to the state of the data, there is no conditional branch in
  `OcptBudgetHeader` at all, only a value that may turn out empty once the centre reads it. Every
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

## What M1 deliberately does not show

- `budget_entries` and `budget_commitments`, the cash journal and the commitments the dashboard's
  `Paid` and `Committed` figures need, are M2's tables and do not exist yet. The cost-tracking
  table and the poste inspector read them all the same, through the very functions
  `lib/utils/ocpt_budget_totals.dart` will keep answering once those tables land
  (`ocptBudgetRemainingCents`, `ocptBudgetVarianceCents`, `ocptBudgetConsumedRatioOf`,
  `ocptBudgetPosteStrainOf`), but every call site hands them a plain `paidCentsOf`/`committedCentsOf`
  that always answers zero — and the five columns those feed print `ocptBudgetEmptyValue` (an em
  dash), never `0 €` or `0 %`. **Nothing having moved against a poste is not the same fact as zero
  having moved against it**, and this milestone is careful never to claim the second when it only
  knows the first; M2 only has to start answering those two functions for real and flip
  `isCashDataAvailable`, and every column already wired here starts reading honestly with no other
  change. The dashboard is held to the same rule: no alert (a poste over its quote, the cash
  projection going negative — M2), no needs/resources balance bar or "what feeds this budget" card
  (M3), no catering pass (M3), no revenue sharing (M4) — each arrives with the milestone that gives
  it real content, argued in full in `docs/plans/budget-mode.md`, which is where the rest of this
  mode is still only planned.
