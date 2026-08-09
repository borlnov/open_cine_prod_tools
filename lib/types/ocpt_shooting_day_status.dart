// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Where one day of the shooting schedule stands.
///
/// A day lost to weather or to a location falling through is **said, not deleted**: the day and
/// everything planned on it (its slots, its convocations, its blocks) stay in the schedule, so the
/// production can see it was tried and re-plan around it rather than losing the record of it.
enum OcptShootingDayStatus {
  /// This day is planned but has not happened yet.
  planned,

  /// This day was shot.
  shot,

  /// This day was cancelled (weather, a lost location, an unavailable cast) and did not happen.
  cancelled,
}
