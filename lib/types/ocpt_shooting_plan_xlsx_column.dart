// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One column of the exported shooting plan workbook's `Chronology` sheet, in the order the sheet
/// lays them out — one row per block over the whole printed range, in shooting order
/// (`ocptOrderedScheduleEntriesOfDay`), every block kind included: a shot as much as a meal break or
/// a wrap, this being the sheet a production office reworks the whole timetable from.
///
/// The four summary grids (locations, sequences, crew and cast, elements) have no enum of their
/// own: their columns are the slots or the days themselves (`OcptShootingPlanGridColumn`,
/// `OcptShootingDay`), not a fixed set of fields.
enum OcptShootingPlanXlsxColumn {
  /// The day's own printed rank (`D3`).
  dayTag,

  /// The day's own calendar date.
  date,

  /// The slot's own free-text label.
  slot,

  /// The block's own resolved start.
  start,

  /// The block's own resolved end.
  end,

  /// The block's own kind, localized — a shot as much as every milestone kind.
  kind,

  /// A shot block's own code, blank for every other kind.
  shot,

  /// The sequence a shot or a hold block concerns — a shot's own scene heading, or a hold's own,
  /// blank for every other kind.
  sequence,

  /// The slot's own set, when it names one.
  set,

  /// A shot block's own matched role names, blank for every other kind.
  roles,

  /// The block's own resolved duration, in minutes.
  durationMinutes,

  /// The block's own crew note — the one that prints, `notes` never being exported.
  crewNote,
}
