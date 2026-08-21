<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Budget mode — the quote, the cash journal, the financing and the sharing

This document is the implementation strategy for the last production mode still showing the shared
empty state. It is written for the Sonnet 5 agents that will build it, orchestrated and reviewed by
the main session, with a user checkpoint between each milestone. **Read the repository `CLAUDE.md`
first** — this plan assumes its architecture, ways of working, coding standards, licensing rules and
verification gates, and does not repeat them.

Tracked by [issue #73](https://github.com/borlnov/open_cine_prod_tools/issues/73).

---

## 1. Why this mode exists

`OcptBudgetMode` is a `StatelessWidget` rendering `OcptWorkspaceEmptyMode`: no bloc, no data, no
`Export` control. The groundwork was nonetheless laid as the other modes shipped —
`elements.cost` carries the comment "Read by the budget mode later", `project_info.currencyCode` is
set from the project settings page, `OcptProjectSettingsCurrencySection` says in its own doc comment
that the budget settings are expected to join it, and `ocptCostCentsOf`/`ocptCostTextOf` already
know how to read and write money somebody typed by hand.

The mode has to serve two readers at once, and they want different documents:

- the **commission**, which expects the CNC nomenclature, a financing plan with the in-kind
  contributions valued separately, and a final financial report against the quote;
- the **production that shot the film with five people**, whose real account book is a
  debit/credit/balance journal with free categories, a meals sheet counted off the shooting days,
  and a sharing sheet where the contributions are repaid before anything is split.

The validated mockup covers seven views — dashboard, cost tracking, financing, cash journal,
committed spending, catering and travel, revenue sharing. **Exporting is not one of them**: it is the
toolbar's own `Export` control opening `OcptWorkspaceExportDialog`, as in every other mode.

---

## 2. Decisions already taken

- **Four milestones**, the foundations first, with a checkpoint between each.
- **The CNC nomenclature is seeded, not frozen**: the ten postes are inserted as ordinary rows, then
  renamed, reordered and extended like any other record.
- **Both header toggles**: simplified/detailed, and excluding/including tax. Nothing is ever
  withheld or disabled according to the state of the project — there is no conditional branch in the
  UI, only a value that may be absent.
- **A default VAT rate on the project, overridden line by line**, and an explicit **0 %** is a value
  somebody can state.
- **Presentation**: the `Quote` column carries the amount as typed and sets the excluding-tax figure
  and the rate underneath it, in small type, **only when a rate is known**. Only the quote carries
  that detail: paid, committed and remaining are money that moved, so they are always tax-inclusive.
  An overridden rate is written in the accent colour, one inherited from the project in grey.
- **The revenue sharing view lands last**: it only means anything once the takings are in, long after
  the shoot, and it blocks nobody during production.

---

## 3. The money rule

**An amount is stored exactly as it was typed, and never reconstructed.** This is the constraint
everything else follows from: somebody who enters the 12.50 € printed on a till receipt has to read
12.50 € back everywhere, without a round trip through the other tax basis ever handing them 12.49 €.
An amount is therefore **three columns**:

- `amountCents` — the number typed, in cents;
- `isTaxInclusive` — non-nullable, **`true` by default**: does that number include tax? A till
  receipt does, a supplier quote does not, and a real budget mixes the two. No canonical basis is
  imposed, precisely so that nothing is ever converted on its way to the screen;
- `vatRateBasisPoints` — nullable, and this null means **"inherit the project's rate"**, not "nobody
  has said". It is the override: a line that says nothing follows the project, a line that says
  5.5 % departs from it, and changing the project's rate moves every silent line with it.

`project_info.defaultVatRateBasisPoints` is nullable too, and **its** null does mean "nobody has
recorded a rate" — the value a new project is born with, and the common case. The excluding-tax and
VAT figures are then simply empty, and **nothing disappears from the screen**.

**"Exempt" and "not recorded" are two different facts.** A rate explicitly set to **0 %** is a
value: wages and a copyright assignment carry no VAT, so their excluding-tax figure equals their
tax-inclusive one. A line whose rate nobody filled in contributes to neither total. It follows that:

- an excluding-tax total sums only the lines whose rate is known, and **says how many it covers**
  (`10,349 € · over 2 of the 5 postes`) for as long as any are missing;
- it becomes complete, and stops saying so, once every line has declared a rate — 0 % included.

The header toggle changes the **display basis**: every row is converted individually and then summed,
never the other way round, so a table mixing the two bases still totals correctly. `OcptMoney`
(`lib/models/`, pure) is that triple seen from the domain, and `lib/utils/ocpt_budget_vat.dart`
(pure, tested) is the only place in the repository that converts between the two bases.

Quantities are integers **in thousandths** (`quantityMilli`), for the reason cents are cents:
1,484 km, 5 days and 1.5 day all have to be said exactly.

**A poste's quoted amount is not stored**: it is the sum of its lines. A `quotedAmount` column
beside those lines would be the second copy of one truth, and the frozen "quote v4" the mockup names
is already what a project version does.

---

## 4. What the schema gains

Every table below is synchronised: it carries `isDeleted` and `sortKey`, no service ever deletes a
row, and every read filters the tombstones back out (ADR 0010).

| Milestone | Table | What it holds |
| --- | --- | --- |
| M1 | `budget_postes` | `code`, `label`, `simpleLabel?` |
| M1 | `budget_lines` | `posteId`, `label`, `quantityMilli`, `unit`, the money triple on the unit price, `elementId?`, `notes?` |
| M2 | `budget_entries` | the journal: `date`, `label`, `posteId?`, `resourceId?`, `debitCents`, `creditCents`, `isTaxInclusive`, `vatRateBasisPoints?`, `voucherNumber` |
| M2 | `budget_commitments` | committed, not paid: `dueDate`, `label`, `posteId`, the money triple, `status`, `settledEntryId?` |
| M3 | `budget_resources` | financing: `groupKind`, `label`, `amountCents`, `status`, `receivedCents`, `isReimbursable`, `notes?` |
| M3 | `budget_mileage_rates` | `label`, `ratePerKmCents` |
| M4 | `budget_revenues` | takings: `date`, `label`, `amountCents`, `status` |
| M4 | `budget_shares` | sharing: `personId?`, `label`, `sharePermille`, `reinvestPermille`, `paidCents` |

Columns added to tables that already exist:

- `project_info`: `defaultVatRateBasisPoints?`, `mealPriceCents?`, `snackPriceCents?` — three
  nullable columns, the reader staying silent rather than advancing a figure, exactly as
  `minimumRestMinutes` already does. They are set in a new `OcptProjectSettingsBudgetSection`,
  beside the currency card that announced this neighbour in its own doc comment. Its VAT field
  carries a **`No rate`** button putting the null back, without which a value entered by mistake
  could never be removed — and **`0 %` remains a value somebody can enter**, which does not mean the
  same thing.
- `people`: `commuteKm?` and `mileageRateId?` (M3) — one person's one-way distance and the rate that
  applies to them, typed once on their own sheet. Both nullable: somebody who does not drive claims
  nothing.
- `assets`: `budgetEntryId?` and `OcptAssetKind.receipt` (M2), for the vouchers — a voucher is a file
  referenced by path like everything else (ADR 0013), and `OcptAssetsService` stays the one place a
  row of that table is minted or tombstoned.

**No single mileage rate, and no rate shipped at all.** A rate depends on the vehicle — a car, a
production van and a motorbike are not reimbursed alike — and this app **cannot carry a national
scale as a constant**: it ships in more than one country, and `minimumRestMinutes` already settled
that argument ("a default would be it advancing a legal figure nobody here validated"). Hence a small
table of **rates the user names themselves**, managed from the budget settings card. No legal figure
is advanced, and a production mixing vehicles is right.

**No cash alert threshold either.** The mockup's 1,500 € was calibrated by nobody, and the alert that
matters is already computed by the committed-spending view: the balance less the commitments falling
due, instalment by instalment, and the date it goes negative. It calibrates itself and states
something anybody can check.

**Seeding the postes**: the ten CNC postes are inserted with **constant UUIDs**, one per code,
declared in `lib/constants/ocpt_budget_cnc_postes.dart`. Two replicas seeding the same project
produce the same ten rows and merge into ten rather than twenty — the very device the v18 migration
already uses for `role_episodes`. The seeding is done by the service on the first read of an empty
table, not at project creation, so an existing project gets it too.

**Schema number**: allocated at merge time, not at branch time (ADR 0007). Each milestone merges with
its own. Every new table has to join `OcptProjectVersionCodec` in three places (the payload, the
`contentDigest` and `_applyPayload`) and bump `payloadFormat`, with a **materialised**
`_payloadUpgrades` entry — an empty list, meaning this project had no budget.

**One budget for the production, not one per episode** (ADR 0019), exactly as the schedule already
works: the mode reads every episode and keeps `onEpisodeSelected` null — for the schedule's reason
now, not for want of a bloc.

---

## 5. The four milestones

### M1 — The foundations and the quote

- `budget_postes`, `budget_lines`, `OcptBudgetQuoteService`
  (`lib/managers/projects/services/`), owned by `OcptProjectsManager` beside the resources services.
- `OcptBudgetSnapshot` (`lib/models/`), joining the reads the way `OcptResourcesSnapshot` already
  joins its own four.
- `OcptBudgetBloc` / `…State` / `…Event` (the ACT pattern), and `OcptBudgetMode` stops being a
  `StatelessWidget`: the shell with the header, the view chips and the content in the centre,
  `Inspector` and `Versions` in the right dock, no left dock (the mockup shows none), the `Export`
  control wired.
- The **dashboard** and **cost tracking** views, the simplified/detailed and tax-basis toggles, and
  the poste inspector (figures, quote lines, related entries — empty until M2).
- Pure and tested: `ocpt_budget_vat.dart`, `ocpt_budget_totals.dart` (paid plus committed,
  remaining, variance, consumed, and the colour a stretched poste wears).
- `OcptWorkspaceExportDialog` opened with a grid holding the project package card alone, the
  documents arriving at M4 — the mode now has a bloc, so `MixinOcptProjectPackageBloc` plugs into it.
- Docs: `docs/architecture/budget.md` created; `foundations.md` and `exports.md` **corrected**, both
  stating today, with an argument, that this mode has neither a bloc nor an `Export` control, and
  using it as a precedent for other rules.

### M2 — Cash and commitments

- `budget_entries`, `budget_commitments`, `OcptBudgetJournalService`.
- **Cash journal** view: the entries with a running balance, a filter by poste (set by a click in the
  cost tracking view), the debit/credit/balance totals, and the add-an-entry dialog.
- **Committed** view: the commitments by due date with their status, and the cash projection — the
  balance falling instalment by instalment (`ocpt_budget_projection.dart`, pure and tested).
- Vouchers: `assets.budgetEntryId` and `OcptAssetKind.receipt`, referenced through
  `OcptAssetsService` like the permits and the photos.
- The poste inspector finally shows the entries attached to it.
- The dashboard's two alerts, **both computed and neither configured**: a poste over its quote (paid
  plus committed above it), and the date the projection goes negative.

### M3 — Financing, catering and travel

- `budget_resources`, `budget_mileage_rates`, `OcptBudgetFinancingService`.
- **Financing** view: subsidies, cash contributions and in-kind contributions grouped, each with its
  status, what has been received and what is left to receive; the in-kind ones valued on both sides
  of the budget.
- **Catering and travel** view: **nothing is typed twice here**. The head counts per shooting day
  (crew, cast, extras) come from `OcptSchedulePlanSnapshot`, the unit prices from the project
  settings, and `ocpt_budget_regie.dart` (pure, tested) does the arithmetic. The travel allowances
  cross the presence grid (how many return trips) with each person's own `commuteKm` and **the rate
  their sheet names**. A missing price, distance or rate leaves the line silent rather than counting
  it as zero.
- The dashboard gains its needs/resources balance bar and its "what feeds this budget" card, with the
  cross-mode links to the breakdown and the schedule (`OcptWorkspaceRevealRequest`, never navigation
  of its own making).
- `budget_lines.elementId` becomes visible: the breakdown elements attached to no quote line are the
  "unpriced needs" alert, and `elements.cost` seeds the unit price of a line created from one.

### M4 — Sharing and the exports

- `budget_revenues`, `budget_shares`; the **sharing** view: the takings received, the reimbursable
  contributions repaid before anything is split, the split by share, and the reinvestment
  (`ocpt_budget_shares.dart`, pure and tested — the one view whose arithmetic is already written down
  in the reference spreadsheet).
- The exports, through `OcptExportManager` and `OcptWorkspaceExportDialog` (so the **button**, never
  a tab), each with its words resolved by the mode and never by the service:
  1. **Quote** — PDF, the full nomenclature, poste by poste with its lines;
  2. **Financing plan** — PDF, the in-kind contributions kept separate;
  3. **Cash journal** — XLSX, every entry with its voucher number;
  4. **Financial report** — PDF, quoted against actual, with the variance.
  The mockup's two remaining documents (the statement of justified spending, the in-kind
  contributions certificate) go on the roadmap rather than being rushed.
- The ADRs and the final documentation; `docs/architecture/budget.md` completed, and the tables in
  `AGENTS.md` and `docs/architecture/README.md` updated.

---

## 6. ADRs to write

- **The budget's money**: an amount is stored exactly as it was typed (cents, basis, and a rate
  either inherited or overridden) and never reconstructed; `0 %` and "not recorded" are two different
  facts; quantities in thousandths; a quote derived from its lines.
- **The budget reads the other modes, it does not copy them**: the catering comes from the schedule,
  the needs from the breakdown, the currency from the project — and what can be computed nowhere
  (`commuteKm`, a person's rate) is typed once, where it belongs, not in the budget.
- **The budget states no regulatory figure and asks for no threshold**: no mileage scale shipped, no
  default VAT rate at project creation, no cash floor — what the app advances, it either computes or
  holds from the user. This one generalises to a whole mode what `minimumRestMinutes` settled for a
  single column.
- **A nomenclature seeded, not frozen**: the ten CNC postes with deterministic ids, then editable.

---

## 7. Verification

At each milestone, inside the devcontainer, from the repository root:

1. `flutter pub get`, `dart run intl_utils:generate`, `dart run build_runner build`
2. `flutter analyze` → 0 issues
3. `flutter test` → all green, **the migration test included** (what `onCreate` produces against what
   every upgrade path produces) and the new pure tests under `lib/utils/`
4. `flutter build linux --debug`
5. `reuse lint` → compliant
6. `git grep -l 'allcircuits.com' -- ':!actlibs' ':!AGENTS.md' ':!docs/plans'` → empty
7. `dart run tool/check_markdown.dart`, the docs being touched at every milestone
8. A screenshot of the running app through `tool/screenshot-app.sh` (rebuild in **release** first),
   to compare the delivered view against the mockup
9. A version round trip: create a project version, change the budget, restore — the budget must come
   back exactly, tombstones included. This is the classic trap of a new table left out of one of the
   codec's three places.
10. **Both ways of working, at every milestone that touches an amount**: on a project with no rate,
    every amount typed reads back to the cent in every view and every export, and the excluding-tax
    and VAT columns are empty without anything vanishing from the screen; on a project at 20 %, a
    line overridden to 5.5 % does not follow the project, a line at **0 %** counts its excluding-tax
    figure equal to its tax-inclusive one, a silent line counts for neither, the total says how many
    lines it covers for as long as any are missing, and a table mixing the two bases totals correctly.

Wait for a green CI before opening each milestone's pull request.

---

## 8. Still open

- **The VAT rate a new project is born with** is null, so "nobody has recorded a rate". It is the
  common case and the only one that asks nothing of anybody, but it is a choice: a new project could
  instead inherit the rate of its locale's country, the way the page format and the currency already
  do. One line in `OcptProjectsManager`.
- **The mileage rates start empty**: the app offers none, not even a greyed example. A new project
  could be born with one or two typical entries to rename — but then somebody has to choose which
  figures go in them, which is precisely what the third ADR above exists to refuse.
