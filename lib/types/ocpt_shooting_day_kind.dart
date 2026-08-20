// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What one day of the schedule is *for*.
///
/// The weeks of auditions and rehearsals a production runs before its first shooting day are
/// planned exactly like a shooting day — a date, a place, people convoked, a running order — so
/// they are **days of this schedule**, with slots, blocks, convocations, alerts and paperwork of
/// their own, rather than a parallel table that would have to grow every one of those again.
///
/// Each kind is **numbered in its own series**, in date order: a casting day is `C1` whatever the
/// shooting days around it are called, and inserting a rehearsal mid-shoot renumbers no `J`. See
/// `OcptShootingDay.dayNumber` and `ocptScheduleDayTagLabel`.
enum OcptShootingDayKind {
  /// This day shoots — what every day of this schedule was before the other two existed, and what
  /// the shooting plan, the day out of days, the one-line schedule and the sides keep listing.
  shoot,

  /// This day sees candidates for a part: the auditions a production runs before `roles.personId`
  /// can be filled in.
  casting,

  /// This day rehearses: the cast working a sequence before it is shot.
  rehearsal,
}
