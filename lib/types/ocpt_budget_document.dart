// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_budget_sub_page.dart';

/// Which of the budget mode's three documents is currently shown, toggled by the header's own
/// three chips.
///
/// **Three documents, not seven views.** `OcptBudgetCentreView`'s own seven values used to sit
/// side by side as if they were equals, when three of them — the quote, the committed spending and
/// the cash journal — are stages of one chain: an estimate, what it becomes once somebody is owed,
/// and what has actually moved. [expenses] is that whole chain read as one document, in one of two
/// [OcptBudgetDocumentReading]s at its own top level, with its remaining stage (and the catering
/// pass) reached as an `OcptBudgetSubPage` through the header's own breadcrumb rather than through
/// a chip of their own. [resources] and [sharing] each keep one reading for now — see
/// [OcptBudgetDocumentReading]'s own doc comment for why neither offers the switch yet.
enum OcptBudgetDocument {
  /// What the film costs: the quote against the CNC nomenclature, read either poste by poste
  /// ([OcptBudgetDocumentReading.byTree]) or in the order money actually moved
  /// ([OcptBudgetDocumentReading.byDate]) — plus, reached through the breadcrumb, the committed
  /// spending and the catering-and-travel pass.
  expenses,

  /// What pays for the film: the financing plan's own subsidies, cash and in-kind contributions,
  /// read poste-tree style ([OcptBudgetDocumentReading.byTree]) — the only reading it offers today.
  resources,

  /// What the finished film earns, and how it is shared once its own contributions are repaid.
  sharing,
}

/// Which order the current [OcptBudgetDocument]'s own rows are read in — a *reading* of the same
/// document, not a different place: the chronological journal is not a place, it is
/// [OcptBudgetDocument.expenses] itself ordered by date rather than by poste.
///
/// **Only [OcptBudgetDocument.expenses] offers both today.** [OcptBudgetDocument.resources] and
/// [OcptBudgetDocument.sharing] have no [byDate] reading of their own yet — a resource's own
/// chronological reading is a later milestone's — so the header's own reading switch is withheld,
/// never disabled, wherever the document it would switch has nothing to switch to (CLAUDE.md's
/// standing rule for an affordance without a subject).
enum OcptBudgetDocumentReading {
  /// Rows nested under the poste (or resource family) that owns them — `Devis`, `Engagé`, `Payé`
  /// and the rest of the cost report's own columns.
  byTree,

  /// The very same rows, flattened and ordered by the date money actually moved — a debit and a
  /// credit both, since the cash journal is where both are read.
  byDate,
}

/// Whether the current route — [document], read in whichever `OcptBudgetDocumentReading` and,
/// while inside one, [subPage] — narrows itself to `OcptBudgetState.filterPosteId` at all.
///
/// Mirrors the retired `ocptBudgetCentreViewHonoursPosteFilter`'s own argument, carried onto the
/// new three-document shape: the committed spending, the cost-tracking table and the cash journal
/// each read a poste-keyed table and honour the filter; the catering-and-travel pass, the financing
/// plan and the revenue sharing each read a table that carries no poste at all, so there is nothing
/// here to narrow. The reading never changes the answer within [OcptBudgetDocument.expenses] at its
/// own top level: both the poste tree and the chronological journal read the very same poste-keyed
/// rows, merely in a different order.
bool ocptBudgetHonoursPosteFilter({
  required OcptBudgetDocument document,
  required OcptBudgetSubPage? subPage,
}) => switch (document) {
  OcptBudgetDocument.expenses => switch (subPage) {
    null => true,
    OcptBudgetSubPage.committedSpending => true,
    OcptBudgetSubPage.regie => false,
  },
  OcptBudgetDocument.resources || OcptBudgetDocument.sharing => false,
};

/// Whether the current route has anything for the right dock's `Inspector` tab — the polymorphic
/// fiche — to show.
///
/// **Expenses (either reading) and resources, both at their own top level.** The fiche reads
/// `OcptBudgetState.selection` directly, and both readings of [OcptBudgetDocument.expenses] select
/// something of their own — the poste tree a poste, a line, a commitment or an entry, the
/// chronological journal an entry — as does [OcptBudgetDocument.resources]' own row. Neither a
/// sub-page (the committed spending on its own, the catering-and-travel pass) nor
/// [OcptBudgetDocument.sharing] selects anything the fiche can show yet — a taking and a share are
/// still a plain highlight, `docs/architecture/budget.md`'s own "A taking is received by being
/// named, a participant is paid the same way" reading unchanged by this milestone.
bool ocptBudgetHasInspector({required OcptBudgetDocument document, required OcptBudgetSubPage? subPage}) =>
    switch (document) {
      OcptBudgetDocument.expenses || OcptBudgetDocument.resources => subPage == null,
      OcptBudgetDocument.sharing => false,
    };
