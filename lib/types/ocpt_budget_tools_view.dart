// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the budget mode's tools drawer three pages is currently shown, toggled by the
/// header's own second segmented switch while `OcptBudgetView.tools` is on screen.
///
/// **The drawer's own entry rule**: a tool never stores money of its own — either it computes
/// something that lands elsewhere, or it re-reads what is already written; a candidate that fails
/// this test is a document and takes its own chip. [cashFlow] re-reads the journal read-only,
/// [regie] computes what a shooting day costs and provisions it into the quote, [sharing] re-reads
/// the journal too, on the other side of the same rule. None of the three writes a euro nobody can
/// point back at a real `budget_entries` row.
///
/// **A value may be inserted at any position.** `OcptBudgetState.toolsView` is held in memory for
/// the life of the mode and written to no preference at all, so an inserted value strands nothing
/// — exactly the argument `OcptBudgetView`'s own doc comment already makes for the chip it nests
/// under.
enum OcptBudgetToolsView {
  /// The cash journal, read-only: every live entry the project holds, in chronological order,
  /// with the account's own running balance. No capture affordance of any kind — an entry spotted
  /// on the statement is corrected through the right dock's fiche, never created from here.
  cashFlow,

  /// The catering-and-travel pass: what each shooting day costs in meals and at the buffet,
  /// computed off the schedule, and what each defrayal actually owed a traveller costs, typed row
  /// by row — both provisioned into the quote, one line per nature.
  regie,

  /// The revenue sharing: what the takings have actually brought in, what the reimbursable
  /// contributions take back out of that before anything is split, and what each participant is
  /// then due, has been paid and reinvests.
  sharing,
}
