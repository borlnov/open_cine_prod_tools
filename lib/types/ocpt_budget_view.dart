// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_tools_view.dart';

/// Which of the budget mode's four chips is currently shown, toggled by the header's own chip
/// row.
///
/// [dashboard] is the mode's own default view, the whole project's standing reading; [expenses]
/// and [resources] are its two working surfaces; [tools] is a drawer over three helpers of its
/// own, distinguished by `OcptBudgetToolsView` — see that type's own doc comment for the rule
/// deciding what may ever join it.
///
/// **A value may be inserted at any position.** `OcptBudgetState.view` is held in memory for the
/// life of the mode and written to no preference at all, so an inserted value strands nothing —
/// [dashboard] itself landed first rather than last, which is exactly the freedom this rule
/// argues for.
enum OcptBudgetView {
  /// The whole project's standing reading: the KPI tiles, the balance band, the standing alerts.
  /// Opens on nothing of its own — a poste row here selects the poste and switches to [expenses],
  /// which is where the fiche then opens.
  dashboard,

  /// The quote itself, poste by poste: the working surface for creating, renaming and reordering
  /// postes and lines, reading what each poste has consumed and picking the poste every other
  /// view is narrowed to.
  expenses,

  /// The financing plan: every live `budget_resources` row, grouped by
  /// `OcptBudgetResourceGroupKind`, with its own status and what has actually come in against it —
  /// read off the very same journal the tools drawer's cash-flow page reads, through
  /// `budget_entries.resourceId`, rather than a stored figure of its own.
  resources,

  /// The tools drawer: `OcptBudgetToolsView` picks which of its three helpers is on screen.
  tools,
}

/// Whether [view] can honour the mode's own poste filter (`OcptBudgetState.filterPosteId`).
///
/// **True for [OcptBudgetView.expenses] alone.** It is the only surface left that draws a
/// poste-keyed row — the tools drawer's cash-flow page no longer honours the filter (a statement
/// reads across the whole account, not one category of it) and the resources plan and the tools
/// drawer's other two pages read no poste at all. A filter silently ignored elsewhere would be
/// worse than one that is visibly out of scope, since a reader would take an unfiltered view for
/// a filtered one.
bool ocptBudgetViewHonoursPosteFilter(OcptBudgetView view) => switch (view) {
  OcptBudgetView.expenses => true,
  OcptBudgetView.dashboard || OcptBudgetView.resources || OcptBudgetView.tools => false,
};

/// Whether [view] (and, while it is [OcptBudgetView.tools], [toolsView]) has anything for the
/// right dock's `Inspector` tab — the polymorphic fiche — to show.
///
/// **False for [OcptBudgetView.dashboard] and `tools › regie` alone.** The fiche reads
/// `OcptBudgetState.selection` directly, and [OcptBudgetView.expenses],
/// [OcptBudgetView.resources] and the tools drawer's own `cashFlow`/`sharing` pages each select
/// something of their own: the quote a poste, a line, a commitment or an entry, the resources plan
/// a resource or a taking, cash flow an entry, sharing a revenue or a share. A dashboard poste row
/// is a *link to where the poste is worked on*, not a selection of its own: it selects the poste
/// **and** switches to [OcptBudgetView.expenses] in the same gesture, which is where the fiche
/// then opens. Régie selects nothing at all — it is not a stage of anything, and reads no row that
/// the fiche could ever open on.
bool ocptBudgetViewHasInspector(OcptBudgetView view, OcptBudgetToolsView toolsView) =>
    switch (view) {
      OcptBudgetView.expenses || OcptBudgetView.resources => true,
      OcptBudgetView.tools => toolsView != OcptBudgetToolsView.regie,
      OcptBudgetView.dashboard => false,
    };
