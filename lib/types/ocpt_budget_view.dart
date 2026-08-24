// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the budget mode's views is currently shown, toggled by the header's own view chips.
///
/// **Six values today.** The dashboard, the mode's own default view once it exists again, is a
/// later milestone's; until then the mode opens on [costTracking]. Nothing here is a `Planned`
/// pair the way the retired `OcptBudgetCentreView` once carried `financing` and `committed` as
/// two faces of one chip — each is its own value, its own chip, exactly the shape the shell
/// design draws.
///
/// **A value may be inserted at any position, the dashboard included.** `OcptBudgetState.view` is
/// held in memory for the life of the mode and written to no preference at all, so an inserted
/// value strands nothing. The retired `OcptBudgetCentreView` carried the opposite rule — every
/// value joined it at the end — against a stored preference that was in the end never written, and
/// there is nothing left here for that rule to protect.
enum OcptBudgetView {
  /// The quote itself, poste by poste: the working surface for creating, renaming and reordering
  /// postes and lines, and reading what each poste has consumed.
  costTracking,

  /// The financing plan: every live `budget_resources` row, grouped by
  /// `OcptBudgetResourceGroupKind`, with its own status and what has actually come in against it —
  /// read off the very same journal [cashJournal] and [committed] already read, through
  /// `budget_entries.resourceId`, rather than a stored figure of its own.
  financing,

  /// The cash journal: every live `budget_entries` movement, in chronological order, with the
  /// journal's own running balance and its whole-journal debit/credit/balance totals —
  /// optionally filtered onto one poste, the filter being `OcptBudgetState.filterPosteId`.
  cashJournal,

  /// The committed spending: every live `budget_commitments` row, due-date ordered, with its own
  /// status and its own outstanding total, next to the cash projection those very commitments
  /// build — `lib/utils/ocpt_budget_projection.dart`, opened at the cash journal's own balance.
  committed,

  /// The catering-and-travel pass: what each shooting day costs in meals and at the buffet, and
  /// what each traveller's own commute costs in mileage — read off the schedule, the project's own
  /// meal and buffet prices, and each person's own distance and rate, never typed here at all
  /// (`lib/utils/ocpt_budget_regie.dart`).
  regie,

  /// The revenue sharing: what the takings have actually brought in, what the reimbursable
  /// contributions take back out of that before anything is split, and what each participant is
  /// then due, has been paid and reinvests (`lib/utils/ocpt_budget_shares.dart`).
  sharing,
}

/// Whether [view] can honour the mode's own poste filter (`OcptBudgetState.filterPosteId`).
///
/// **Three of the six cannot, and say so rather than pretending to.** The financing plan reads
/// `budget_resources`, the régie reads the schedule and the defrayals, and the revenue sharing
/// reads `budget_revenues`/`budget_shares`: not one of those tables carries a poste, so there is
/// nothing to narrow. A filter silently ignored on half the mode would be worse than one that is
/// visibly out of scope, since a reader would take an unfiltered view for a filtered one.
bool ocptBudgetViewHonoursPosteFilter(OcptBudgetView view) => switch (view) {
  OcptBudgetView.costTracking || OcptBudgetView.cashJournal || OcptBudgetView.committed => true,
  OcptBudgetView.financing || OcptBudgetView.regie || OcptBudgetView.sharing => false,
};

/// Whether [view] has anything for the right dock's `Inspector` tab — the polymorphic fiche — to
/// show.
///
/// **The cost report, the cash journal and the financing plan do.** The fiche reads
/// `OcptBudgetState.selection` directly, and each of these three selects something of its own —
/// the cost report a poste, a line, a commitment or an entry, the cash journal an entry, the
/// financing plan a resource or a taking. The committed spending, the régie and the revenue
/// sharing select nothing the fiche can show yet — a commitment there is a plain highlight
/// answered by its own row menu, a taking and a share are still a plain highlight,
/// `docs/architecture/budget.md`'s own "A taking is received by being named, a participant is
/// paid the same way" reading unchanged here.
bool ocptBudgetViewHasInspector(OcptBudgetView view) => switch (view) {
  OcptBudgetView.costTracking || OcptBudgetView.cashJournal || OcptBudgetView.financing => true,
  OcptBudgetView.committed || OcptBudgetView.regie || OcptBudgetView.sharing => false,
};
