// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One typed free-text field the schedule mode's inspector (or, once built, the day view's slot
/// and block cards) can edit, ridden on `OcptScheduleBloc`'s own 2 s field-edit debounce —
/// everything else the mode writes (a status, a time, a pick) is written the moment it changes.
///
/// A single flat enum across every entity the mode edits text on (a day, a slot, a block, a crew
/// assignment, a cast convocation, a guest attendance, a day's own event) rather than one enum per
/// entity (the `OcptElementField` idiom): the seven entities share one pending-edit map and one
/// flush handler in `OcptScheduleBloc`, and a field's own name already says which entity it belongs
/// to.
enum OcptScheduleField {
  /// `shooting_days.crewNote` — the call sheet's "NOTE À L'ÉQUIPE".
  dayCrewNote,

  /// `shooting_days.weatherNote` — the forecast, typed by hand.
  dayWeatherNote,

  /// `shooting_days.notes` — internal notes, never printed.
  dayNotes,

  /// `shooting_slots.label` — "Matin", "Nuit".
  slotLabel,

  /// `shooting_slots.notes`.
  slotNotes,

  /// `shooting_day_blocks.label` — the wording of a non-shot block, a caption rather than what a
  /// `hold` reserves: that is `shooting_day_blocks.sceneId`'s own job.
  blockLabel,

  /// `shooting_day_blocks.notes`.
  blockNotes,

  /// `shooting_slot_crew.customLabel` — a free-text position label, used when the catalogue has
  /// nothing that fits.
  crewMemberCustomLabel,

  /// `shooting_slot_crew.notes`.
  crewMemberNotes,

  /// `shooting_slot_cast.notes`.
  castMemberNotes,

  /// `shooting_slot_guests.reason` — why this guest is on set.
  guestReason,

  /// `shooting_slot_guests.notes`.
  guestNotes,

  /// `shooting_day_events.label` — what the event is.
  dayEventLabel,

  /// `shooting_day_events.notes`.
  dayEventNotes,
}
