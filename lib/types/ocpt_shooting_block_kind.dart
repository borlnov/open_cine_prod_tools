// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What one block of a shooting day's timetable is for.
///
/// A day's timetable is a chain of these, in order — `shooting_day_blocks`. Every kind but
/// [shot], [hold], [audition] and [rehearsal] is a milestone the reference call sheets interleave
/// between shots (preparation, hair and make-up, a meal, a break, a travel move, the wrap).
///
/// **Which kinds a `+ Block` menu offers is scoped by the day's own `OcptShootingDayKind`**, and
/// that is a scoping of the menu rather than a rule of the schema: a block already sitting on a day
/// keeps working whatever that day later becomes, refusing to draw a row a file holds being how a
/// plan becomes unreadable.
enum OcptShootingBlockKind {
  /// This block is a shot from the shot list.
  shot,

  /// This block is time set aside to prepare (rig, dress, light) before shooting starts.
  preparation,

  /// This block is time set aside for hair and make-up.
  hairMakeUp,

  /// This block is a meal break.
  meal,

  /// This block is a break that is not a meal — the coffee or technical pause a day is cut by.
  pause,

  /// This block is a move from one place to another.
  travel,

  /// This block is the day's wrap.
  wrap,

  /// This block reserves time for a sequence the shot list cannot yet describe (the mock's
  /// *créneau libre*): it is how a production schedules ahead of its own découpage, which the
  /// "shots only" placement rule would otherwise forbid.
  hold,

  /// This block sees **one candidate, for one part**: the audition a casting day is made of. It
  /// names both through `shooting_day_blocks.roleId`/`.roleCandidateId`, non-null exactly on this
  /// kind.
  ///
  /// **One block per candidate**: *"these four people, for that part, twenty minutes each"* is four
  /// blocks, which is also what makes the printed audition table read four rows.
  audition,

  /// This block rehearses a **sequence**, named through the existing `shooting_day_blocks.sceneId`
  /// exactly as [hold] names one — a rehearsal convokes the roles a sequence calls for, not a
  /// candidate, so it needs no column of its own.
  rehearsal,
}

/// Whether a block of this kind is **shooting time** — the working time of the day it sits on, the
/// span a convocation's PAT (*prêt à tourner*) band is read off (ADR 0018).
///
/// Four kinds are: [OcptShootingBlockKind.shot] and [OcptShootingBlockKind.hold] — a production
/// scheduling ahead of its own découpage still owes its cast a band — and
/// [OcptShootingBlockKind.audition] and [OcptShootingBlockKind.rehearsal], for the very same
/// reason one step earlier: a candidate seen for a part, or an actor working a sequence, is owed
/// their band exactly as a cast member is on a shooting day. Every other kind is time around the
/// work and never opens or closes a band.
///
/// Written here, on the enum, rather than in whichever reader needs it first: "does this block
/// count as work" is a question about the kind itself, and a second reader deciding it again is how
/// a printed call sheet and the convocations panel come to disagree about somebody's band.
extension OcptShootingBlockKindShootingTime on OcptShootingBlockKind {
  /// Whether a block of this kind is shooting time. See the extension's doc comment.
  ///
  /// A `switch` with no `default`: an eleventh kind must be placed on one side or the other here
  /// rather than silently counting as time around the work.
  bool get isShootingTime => switch (this) {
    OcptShootingBlockKind.shot => true,
    OcptShootingBlockKind.hold => true,
    OcptShootingBlockKind.audition => true,
    OcptShootingBlockKind.rehearsal => true,
    OcptShootingBlockKind.preparation => false,
    OcptShootingBlockKind.hairMakeUp => false,
    OcptShootingBlockKind.meal => false,
    OcptShootingBlockKind.pause => false,
    OcptShootingBlockKind.travel => false,
    OcptShootingBlockKind.wrap => false,
  };
}
