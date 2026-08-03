// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Which part of each day a `person_unavailabilities` row covers, over the range of dates that row
/// spans.
///
/// [custom] is the one case that reads two further columns (`startMinute`/`endMinute`): the other
/// three describe themselves, and a production that plans in half-days should not have to type
/// `08:00` and `12:00` to say "morning".
enum OcptUnavailabilitySlot {
  /// The whole of each day in the range.
  fullDay,

  /// The morning of each day in the range.
  morning,

  /// The afternoon of each day in the range.
  afternoon,

  /// The explicit `startMinute`–`endMinute` window of each day in the range.
  custom,
}
