// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which of the schedule mode's centre views is currently shown, toggled by
/// `OcptScheduleHeader`'s own segmented switch.
///
/// The order the entries are declared in **is** the order the switch shows them in, and the day
/// comes first deliberately: it is the mode's working surface — the one place the schedule is
/// actually built — while every other view only ever reads it back. A mode opens on the view its
/// user came to act in. [positions] follows [agenda] for the same reason: a cross-shoot read-out
/// belongs after the read-outs of a narrower scope, not before them. A fourth view, the presence
/// grid, is a later addition and belongs after [positions] in turn, for the same reason.
enum OcptScheduleCentreView {
  /// The selected day's own timetable: its slots and their convocations, then the chained blocks
  /// with their computed times — the mode's default view.
  day,

  /// The agenda, itself shown as one of three presentations (`OcptScheduleAgendaMode`), every one
  /// of which only reads the schedule back.
  agenda,

  /// The positions matrix (`OcptSchedulePositionsMatrix`): who holds which crew position, slot by
  /// slot, across the whole shoot — a cross-shoot read-out, like the agenda, but organised by
  /// position rather than by date.
  positions,
}
