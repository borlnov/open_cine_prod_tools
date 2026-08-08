// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What fact the schedule agenda's own "Colour by" control tints a day with, toggled by
/// `OcptScheduleHeader`'s own segmented switch. Shown, and read, only while the agenda is the
/// active centre view.
///
/// Session-only state (`OcptScheduleState.agendaColorMode`), unlike `OcptScheduleState.firstWeekday`
/// beside it: which fact a day is tinted by is a reading preference for the sitting, not an
/// app-wide one worth remembering across launches.
enum OcptScheduleAgendaColorMode {
  /// By the day's own first slot's location (`ocptScheduleDayLocationTint`) — the only rule before
  /// this control existed, and still the default.
  location,

  /// By the day's own EFFET reading — INT/EXT crossed with day/night, read off the scene headings
  /// of the shots placed on it (`ocptSceneEffectCategoryOf`). A day mixing more than one reading
  /// tints as an explicit "mixed" wash rather than any one of the four, and a day with nothing to
  /// say (nothing placed, or nothing classifiable) tints neutral — see
  /// `OcptSceneEffectCategory`'s own doc comment for why those two must not be confusable.
  effect,
}
