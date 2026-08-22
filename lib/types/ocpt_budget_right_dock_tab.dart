// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the budget mode's right dock, modelled on `OcptScheduleRightDockTab`'s own shape.
///
/// **Each value joined this enum at its own end, for the reason `OcptBudgetCentreView`'s own doc
/// comment gives**: a value here is stored as a preference (`OcptPropertiesManager
/// .budgetLastRightDockTab`), so it must never move under a reader who stored one. [help] is the
/// third and, for now, last.
enum OcptBudgetRightDockTab {
  /// The selected poste's own read-out: its figures, its quote lines and its (still empty) related
  /// entries.
  inspector,

  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,

  /// The mode's own explanation of itself: the same "what pays for it, what has moved" map on
  /// every page, then a short page for whichever centre view is currently on screen
  /// (`docs/architecture/budget.md`). It writes nothing, so it is never withheld under a version
  /// preview.
  help,
}
