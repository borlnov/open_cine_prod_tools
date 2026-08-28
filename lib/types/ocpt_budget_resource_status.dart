// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// How far a `budget_resources` row has progressed towards actually financing the production —
/// **the step it stands at, never the word that step is called**.
///
/// **The three values are deliberately anonymous, because the word belongs to the group, not to
/// this enum.** A subsidy is `Applied` for, then `Notified`, then `Secured`; a cash contribution is
/// `Requested`, then `Agreed`, then `Contracted`; a contribution in kind is `Promised`, then
/// `Valued`, then `Signed`. Those are three different trades speaking, and asking a production to
/// call a lent camera "applied for" was asking it to file a dossier at a commission that does not
/// exist. `ocptBudgetResourceStatusLabel` resolves the word from the row's own
/// `OcptBudgetResourceGroupKind` **and** its step, so the financing view, the resource dialog and
/// the exported financing plan all read the trade's own vocabulary while the column stores one
/// value.
///
/// **What the three steps have in common is what makes them one enum**: a resource is first merely
/// in play, then answered — a figure is on it — then held on paper. That progression is the same
/// whichever group a row sits in, which is why a production may reclassify a resource without its
/// status becoming meaningless: the step survives the change of kind and simply re-words itself.
///
/// **Nothing is hidden or disabled by kind**, and nothing needs to be: the mode's standing rule
/// that the UI carries no conditional branch on the state of the data (`docs/architecture/
/// budget.md`) holds because every step offered is a step that group genuinely has. The picker
/// always shows three chips; only their words change.
enum OcptBudgetResourceStatus {
  /// The resource is in play and nothing has come back: a subsidy's dossier is filed, a
  /// co-producer has been asked, a supplier has promised the loan.
  pending,

  /// The resource has been answered and carries a figure, but nothing is on paper yet: a subsidy
  /// is notified, a contribution agreed, a lent asset valued.
  agreed,

  /// The resource is held on paper: a subsidy is secured, a contribution contracted, a loan
  /// agreement signed.
  confirmed,
}
