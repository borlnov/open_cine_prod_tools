// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A tab of the schedule mode's right dock — one more than `OcptBreakdownRightDockTab`'s and
/// `OcptShotListRightDockTab`'s own two-tab shape, this mode being the one where a day's whole
/// call (ADR 0018) needs its own place to be read from, having stopped being readable off any
/// single slot card.
enum OcptScheduleRightDockTab {
  /// The selected block's own read-out, or — while none is selected — the selected day's own
  /// read-out (date, status, locations, sets, slots, the day's arrival → end band, the sun times,
  /// the weather and
  /// crew notes).
  inspector,

  /// The selected day's whole call: one row per person (crew and cast folded together) and per
  /// uncast role, joined across every slot they are linked to — the reading `OcptScheduleInspector`
  /// itself cannot give once a person may sit on several slots of the same day (ADR 0018).
  convocations,

  /// The project's named versions: the production history the user creates, browses read-only and
  /// deletes.
  versions,
}
