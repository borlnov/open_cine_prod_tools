// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One of the three presentations `OcptScheduleCentreView.agenda` can be shown as, toggled by
/// `OcptScheduleHeader`'s own segmented control.
enum OcptScheduleAgendaMode {
  /// The day cards, one per shooting day, in order — where the *placing* gesture happens. The
  /// mode's default presentation.
  strip,

  /// An hour grid, one column per day of the week `OcptScheduleState.agendaAnchorDate` falls in,
  /// the day's blocks drawn against sunrise/sunset bands.
  week,

  /// The whole shoot at a glance, one cell per day of the month `OcptScheduleState.agendaAnchorDate`
  /// falls in.
  month,
}
