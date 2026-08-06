// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// What one block of a shooting day's timetable is for.
///
/// A day's timetable is a chain of these, in order — `shooting_day_blocks`. Every kind but
/// [shot] and [hold] is a milestone the reference call sheets interleave between shots
/// (preparation, hair and make-up, a meal, a travel move, the wrap).
enum OcptShootingBlockKind {
  /// This block is a shot from the shot list.
  shot,

  /// This block is time set aside to prepare (rig, dress, light) before shooting starts.
  preparation,

  /// This block is time set aside for hair and make-up.
  hairMakeUp,

  /// This block is a meal break.
  meal,

  /// This block is a move from one place to another.
  travel,

  /// This block is the day's wrap.
  wrap,

  /// This block reserves time for a sequence the shot list cannot yet describe (the mock's
  /// *créneau libre*): it is how a production schedules ahead of its own découpage, which the
  /// "shots only" placement rule would otherwise forbid.
  hold,
}
