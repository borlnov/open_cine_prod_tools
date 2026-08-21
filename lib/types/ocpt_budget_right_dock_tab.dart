// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the budget mode's right dock, modelled on `OcptScheduleRightDockTab`'s own shape,
/// reduced to the two tabs this milestone offers — a `Convocations`-like third tab has no
/// counterpart here, this mode having nothing yet that reads like a whole day's own call.
enum OcptBudgetRightDockTab {
  /// The selected poste's own read-out: its figures, its quote lines and its (still empty) related
  /// entries.
  inspector,

  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,
}
