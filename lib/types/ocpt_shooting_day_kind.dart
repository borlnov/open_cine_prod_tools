// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

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
///
/// What a day is for also scopes what its timetable proposes to put in it — see
/// [OcptShootingDayKindBlockKinds].
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

/// Which block kinds a day of this kind offers when somebody adds one to a timetable.
///
/// **A scoping of the menu, not a rule of the schema** (see `OcptShootingBlockKind`'s own doc
/// comment): nothing refuses to store any block on any day, and a block already there when the kind
/// changes is left alone and keeps working — this only says what a `+ Block` menu proposes on a day
/// that says what it is for. A shooting day never proposes an audition, a casting or rehearsal day
/// never proposes a shot, and the milestones — the preparation, the chair, the meal, the break, the
/// move, the wrap — are proposed on all three: every day of a production is cut by them.
extension OcptShootingDayKindBlockKinds on OcptShootingDayKind {
  /// Whether a day of this kind offers [kind] in its `+ Block` menu. See the extension's doc
  /// comment.
  ///
  /// A `switch` with no `default` on either side: a new day kind, or a new block kind, has to say
  /// where it stands here rather than silently being offered everywhere.
  bool offersBlockKind(OcptShootingBlockKind kind) => switch (kind) {
    // A shot is placed from the shot list, and a hold reserves the time of a sequence still to be
    // shot: neither says anything on a day that does not shoot.
    OcptShootingBlockKind.shot ||
    OcptShootingBlockKind.hold => this == OcptShootingDayKind.shoot,
    // Seeing somebody for a part is what a casting day is.
    OcptShootingBlockKind.audition => this == OcptShootingDayKind.casting,
    // A rehearsal is proposed on every kind of day: a production regularly works a sequence with
    // its cast on the morning of the day it shoots it, and on a casting day between two auditions.
    OcptShootingBlockKind.rehearsal => true,
    OcptShootingBlockKind.preparation ||
    OcptShootingBlockKind.hairMakeUp ||
    OcptShootingBlockKind.meal ||
    OcptShootingBlockKind.pause ||
    OcptShootingBlockKind.travel ||
    OcptShootingBlockKind.wrap => true,
  };
}
