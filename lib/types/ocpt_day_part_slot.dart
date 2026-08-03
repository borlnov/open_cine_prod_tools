// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which part of each day a dated window covers, over the range of dates that window spans.
///
/// Shared by the two tables that describe when something may be counted on: a
/// `person_unavailabilities` row (the days a person is *not* there) and a `location_availabilities`
/// row (the days a location *is*). The four values answer the same question either way, so the two
/// read the same way in the schedule mode and only one converter exists.
///
/// [custom] is the one case that reads two further columns (`startMinute`/`endMinute`): the other
/// three describe themselves, and a production that plans in half-days should not have to type
/// `08:00` and `12:00` to say "morning".
enum OcptDayPartSlot {
  /// The whole of each day in the range.
  fullDay,

  /// The morning of each day in the range.
  morning,

  /// The afternoon of each day in the range.
  afternoon,

  /// The explicit `startMinute`–`endMinute` window of each day in the range.
  custom,
}
