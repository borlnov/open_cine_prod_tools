// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which single field the entry wizard's own step 2 asks for, once `OcptBudgetEntryNature` has
/// picked one of the mode's four ledgers to attach the movement to.
///
/// **Exactly one of these is ever drawn at once** — `OcptBudgetEntryNatureLinkKindOf` names it,
/// `OcptBudgetEntryDialog`'s own step 2 draws the matching field and none of the other three, and
/// every one of the four still travels in `OcptBudgetEntryFormFields` regardless of which was
/// drawn, so an entry that already names something unusual survives being edited.
enum OcptBudgetEntryLinkKind {
  /// A quote poste — `budget_lines`, read through `OcptBudgetPoste`. Left unanswered, the entry
  /// reads `Hors devis`, never nothing at all.
  poste,

  /// A financing resource — `budget_resources`.
  financingResource,

  /// A taking the finished film earns — `budget_revenues`.
  taking,

  /// A participant in the revenue-sharing split — `budget_shares`.
  participant,
}
