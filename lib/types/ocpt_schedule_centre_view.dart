// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the schedule mode's two centre views is currently shown, toggled by
/// `OcptScheduleHeader`'s own `Agenda`/`Day` switch.
enum OcptScheduleCentreView {
  /// The agenda, itself shown as one of three presentations (`OcptScheduleAgendaMode`) — the
  /// mode's default view.
  agenda,

  /// The selected day's own timetable: its slots and their convocations, then the chained blocks
  /// with their computed times.
  day,
}
