// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the budget mode's right dock, modelled on `OcptScheduleRightDockTab`'s own shape.
///
/// **Each value joined this enum at its own end**: a value here is stored as a preference
/// (`OcptPropertiesManager.budgetLastRightDockTab`), so it must never move under a reader who
/// stored one. [help] is the third and, for now, last.
enum OcptBudgetRightDockTab {
  /// The fiche: whichever row the selection currently names — a poste, a quote line, a
  /// commitment, an entry, a resource, a revenue or a receipt — read out with its own states, the
  /// figures behind it and what to do next (`docs/architecture/budget.md`).
  inspector,

  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,

  /// The mode's own explanation of itself: the chain of states the current document's rows pass
  /// through, then a short page for the route currently on screen
  /// (`docs/architecture/budget.md`). It writes nothing, so it is never withheld under a version
  /// preview.
  help,
}
