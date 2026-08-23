// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A sub-page of `OcptBudgetDocument.expenses`, reached through the header's own breadcrumb rather
/// than through one of its three chips.
///
/// **Nullable everywhere it is carried.** `OcptBudgetState.subPage` is null at a document's own top
/// level and one of these three values inside one of them — the breadcrumb itself draws
/// `Expenses` alone in the first case and `Expenses › Catering & travel` in the second, and clicking
/// the `Expenses` ancestor is what returns to null. Every value here belonged to `OcptBudgetCentreView`
/// before this milestone; each keeps the widget it already rendered (`docs/plans/budget-mode-ux.md`
/// M2's own table), only its door having moved.
enum OcptBudgetSubPage {
  /// The committed spending: every live commitment, due-date ordered, with its own cash projection
  /// — `OcptBudgetCommittedSpending`.
  committedSpending,

  /// The catering-and-travel pass: what each shooting day costs, and what each traveller's own
  /// commute costs — `OcptBudgetRegie`.
  regie,

  /// The read-only overview: the quote's own totals, poste by poste — `OcptBudgetDashboard`. Kept
  /// whole for this milestone; a later one dissolves it (`docs/plans/budget-mode-ux.md` M7).
  dashboard,
}
