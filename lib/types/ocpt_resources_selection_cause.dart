// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Why the resources mode's selection last moved (`OcptResourcesState.selectionCause`).
///
/// The selection is the active tab and the selected person, role, location and element. A view
/// reads the cause to know how much of what it holds was scoped to the selection that has just
/// gone.
enum OcptResourcesSelectionCause {
  /// Nothing has moved the selection yet.
  none,

  /// Another tab was selected, which clears the four selected records.
  tab,

  /// A person was selected.
  person,

  /// A role was selected, which also switches to the roles tab.
  role,

  /// A location was selected.
  location,

  /// An element was selected.
  element,

  /// A person's sheet was opened from another sheet (the role sheet's `↗`): the people tab is shown
  /// and the other three selections are cleared.
  personSheetOpened,

  /// A role's sheet was opened from another sheet (the element sheet's `Roles concerned` chips):
  /// the roles tab is shown and the other three selections are cleared.
  roleSheetOpened,

  /// A record was created and selected.
  created,

  /// The selected record was deleted, which clears its selection.
  dropped,

  /// The mode read everything again and cleared its selection: on entry, when a version preview
  /// was entered or left, or when a version was restored.
  load,
}
