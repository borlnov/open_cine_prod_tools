// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Where one person stands on one shooting day, for the presence grid.
///
/// Both values are **computed**, by `OcptSchedulePlanSnapshot.presenceCellOf`, from that day's
/// convocations and from `person_unavailabilities` — there is no third source: schema v11 declared
/// a `shooting_presences` table for a by-hand override of this reading, and schema v17 drops it
/// again (see `OcptProjectDatabase`'s own doc comment), the grid having never needed to say
/// anything a click could contradict what the resources mode already recorded. A cell naming
/// neither of these two reads as blank instead — absence of information, never a third code.
enum OcptPresenceCode {
  /// This person is working on this day.
  working,

  /// This person is unavailable on this day.
  unavailable,
}
