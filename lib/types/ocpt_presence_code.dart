// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Where one person stands on one shooting day, for the presence grid.
///
/// A cell of the grid is normally **computed** from that day's convocations and from
/// `person_unavailabilities`; this code is only what a `shooting_presences` row overrides it with
/// by hand. Declared in schema v11 alongside the rest of the schedule mode's tables, and read and
/// written from `OcptSchedulePresenceGrid` on. **Declared in the order the grid's own click cycle
/// steps through them** (`ocptNextPresenceOverride`, `lib/utils/`): reordering these values
/// reorders that cycle too.
enum OcptPresenceCode {
  /// This person is working on this day.
  working,

  /// This person is available on this day but not convoked.
  available,

  /// This person is travelling (to or from set) on this day.
  travelling,

  /// This person is unavailable on this day.
  unavailable,
}
