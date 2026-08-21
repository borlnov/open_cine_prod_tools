// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the budget mode's centre views is currently shown, toggled by the header's own view
/// chips.
///
/// **Only the two views M1 ships.** The mockup validates seven (`docs/plans/budget-mode.md` §1):
/// financing, cash journal, committed spending, catering and travel, and revenue sharing all read
/// tables this milestone's schema does not yet hold (`budget_entries`, `budget_commitments`,
/// `budget_resources`, `budget_revenues`, `budget_shares`), so a value for any of them would draw a
/// chip that opens onto nothing. Each joins this enum, at the end so a stored preference never
/// points at a view that has moved, as the milestone that gives it real content lands.
enum OcptBudgetCentreView {
  /// The read-only overview: the quote's own totals and, poste by poste, its share of them — this
  /// milestone's honest reading of what a project holds, becoming the mockup's full dashboard as
  /// the journal, the commitments and the financing land. The mode's default view.
  dashboard,

  /// The quote itself, poste by poste: the working surface this milestone builds — creating,
  /// renaming and reordering postes and lines, and reading what each poste has consumed once M2
  /// gives that figure content.
  costTracking,
}
