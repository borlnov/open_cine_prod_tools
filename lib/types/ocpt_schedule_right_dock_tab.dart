// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the schedule mode's right dock, mirroring `OcptBreakdownRightDockTab`'s and
/// `OcptShotListRightDockTab`'s own two-tab shape.
enum OcptScheduleRightDockTab {
  /// The selected block's own read-out, or — while none is selected — the selected day's own
  /// read-out (date, status, locations, sets, slots, the PAT band, the sun times, the weather and
  /// crew notes).
  inspector,

  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,
}
