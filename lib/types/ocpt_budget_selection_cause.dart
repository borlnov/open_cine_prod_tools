// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Why the budget mode's shared selection last moved (`OcptBudgetState.selectionCause`).
///
/// The shared selection is `OcptBudgetState.selection`, `OcptBudgetState.filterAccountId`,
/// `OcptBudgetState.selectedShareId` and `OcptBudgetState.provisionAccountId`. A view reads the
/// cause to know how much of what it holds was scoped to the selection that has just gone.
enum OcptBudgetSelectionCause {
  /// Nothing has moved the selection yet.
  none,

  /// A row was selected from a view: an account, a quote line, a commitment, an entry, a receipt, a
  /// resource or a taking. The right dock opens on its `Inspector` tab.
  selected,

  /// A revenue sharing share was selected, which highlights it and opens nothing.
  shareSelected,

  /// A view created a record and the mode selected it. An account and a quote line open the right
  /// dock, a resource, a taking and a share do not.
  created,

  /// Every view was narrowed to an account, or the narrowing was cleared.
  filtered,

  /// The logistics's provisioning was pointed at another account.
  provisionSelected,

  /// The central view or the tools page was changed asking to drop the selection.
  viewChanged,

  /// A read of the snapshot found that the selected row, the filtered account or the selected share
  /// is gone, and dropped it.
  reconciled,

  /// The selection was dropped ahead of an action that replaces the database (a version preview, a
  /// restore, a saved version, a package export).
  cleared,

  /// The mode read everything again and cleared its selection: on entry, when a version preview was
  /// entered or left, or when a version was restored.
  load,
}
