// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A document the budget mode's export panel offers, through `OcptWorkspaceExportDialog`.
///
/// The mockup names two further documents — the statement of justified spending and the in-kind
/// contributions certificate — that stay on the roadmap rather than being rushed into this
/// milestone (`docs/plans/budget-mode.md` §5, M4).
enum OcptBudgetExportDocument {
  /// The quote: the full CNC nomenclature, poste by poste with its own lines and totals.
  quote,

  /// The financing plan: every resource, grouped by kind so an in-kind contribution stays visibly
  /// apart from a cash one, against the plan's own grand total.
  financingPlan,

  /// The cash journal: every live entry, in its own chronological order, with its running balance.
  cashJournal,

  /// The financial report: the quote read against what has actually moved, poste by poste, with
  /// the variance.
  financialReport,
}
