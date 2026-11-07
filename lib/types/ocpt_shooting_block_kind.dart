// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What one block of a shooting day's timetable is for.
///
/// A day's timetable is a chain of these, in order — `shooting_day_blocks`. Every kind but
/// [shot], [hold], [audition] and [rehearsal] is a milestone the reference call sheets interleave
/// between shots (preparation, hair and make-up, a meal, a break, a travel move, the wrap).
///
/// **Every kind is offered on every day.** A day is never given a kind of its own: a real day
/// auditions in the morning and rehearses in the afternoon, and a rehearsal regularly falls on the
/// morning of the day it is shot — so what a day is for is said by the blocks it holds, and a menu
/// that narrowed itself would be guessing which of those somebody is about to plan.
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

  /// This block sees **the candidacies it names**, for its own duration: the audition a casting
  /// session is made of. Who is read, and for which part, is `shooting_block_candidates` — the one
  /// convocation in this app hanging off a block rather than off a slot (ADR 0024), because a
  /// candidate is expected at twenty past ten rather than "on the unit today".
  ///
  /// **It may name several at once**, and that is the point rather than an accident: two actors of
  /// two different parts are regularly read together to see what they do to each other. *"These
  /// four people, twenty minutes each"* is four blocks of one row apiece — four hours of their own,
  /// inside one slot — and *"these two, together"* is one block of two rows. A block naming nobody
  /// yet is an ordinary state, exactly as a [hold] with no sequence is.
  audition,

  /// This block rehearses a **sequence**, named through the existing `shooting_day_blocks.sceneId`
  /// exactly as [hold] names one — a rehearsal convokes the roles a sequence calls for, not a
  /// candidate, so it needs no column of its own.
  rehearsal,
}
