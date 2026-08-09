// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// A document the schedule mode's export panel offers, through `OcptWorkspaceExportDialog`.
///
/// All seven values share one `OcptWorkspaceExportEntry.unavailableReason`: a project holding no
/// live shooting day leaves nothing for any of them to print.
enum OcptScheduleExportDocument {
  /// The general call sheets, one per day.
  callSheets,

  /// The named call sheets, one per recipient and per day.
  namedCallSheets,

  /// The shooting plan: the whole shoot's summary grids and its per-day agendas.
  shootingPlan,

  /// The shooting plan's own workbook: the same summary grids, one sheet each, plus a fifth
  /// Chronology sheet, one row per block over the whole printed range.
  shootingPlanXlsx,

  /// The *Day Out of Days*: one row per role, one column per day.
  dayOutOfDays,

  /// The one-line schedule: one line per sequence, in shooting order, over the whole shoot.
  oneLineSchedule,

  /// The sides: the pages of one day's own sequences.
  sides,
}
