// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the budget mode's centre views is currently shown, toggled by the header's own view
/// chips.
///
/// **All seven views the mockup validates now ship** (`docs/architecture/budget.md`). Each joined
/// this enum **always at the end**, so a stored preference never points at a view that has moved,
/// as the milestone that gave it real content landed — what M2 did for [cashJournal] and
/// [committed], what M3 then did for [financing] and [regie], and what M4 now does one last time
/// for [sharing]: nothing is added past it, this enum being complete.
enum OcptBudgetCentreView {
  /// The read-only overview: the quote's own totals and, poste by poste, its share of them — this
  /// milestone's honest reading of what a project holds, becoming the mockup's full dashboard as
  /// the commitments and the financing land. The mode's default view.
  dashboard,

  /// The quote itself, poste by poste: the working surface this milestone builds — creating,
  /// renaming and reordering postes and lines, and reading what each poste has consumed once M2
  /// gives that figure content.
  costTracking,

  /// The cash journal: every live `budget_entries` movement, in chronological order, with the
  /// journal's own running balance and its whole-journal debit/credit/balance totals — optionally
  /// filtered onto one poste, the filter being `OcptBudgetState.selectedPosteId` itself rather than
  /// a state of its own.
  cashJournal,

  /// The committed spending: every live `budget_commitments` row, due-date ordered, with its own
  /// status and its own outstanding total, next to the cash projection those very commitments
  /// build — `lib/utils/ocpt_budget_projection.dart`, opened at the cash journal's own balance.
  committed,

  /// The financing plan: every live `budget_resources` row, grouped by
  /// `OcptBudgetResourceGroupKind`, with its own status and what has actually come in against it —
  /// read off the very same journal `cashJournal` and `committed` already read, through
  /// `budget_entries.resourceId`, rather than a stored figure of its own.
  financing,

  /// The catering-and-travel pass: what each shooting day costs in meals and snacks, and what each
  /// traveller's own commute costs in mileage — read off the schedule, the project's own meal and
  /// snack prices, and each person's own distance and rate, never typed here at all
  /// (`lib/utils/ocpt_budget_regie.dart`).
  regie,

  /// The revenue sharing: what the takings have actually brought in, what the reimbursable
  /// contributions take back out of that before anything is split, and what each participant is
  /// then due, has been paid and reinvests (`lib/utils/ocpt_budget_shares.dart`).
  sharing,
}
