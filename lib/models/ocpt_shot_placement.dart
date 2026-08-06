// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// Where one block places a shot in the schedule: which day, that day's printed rank, and its
/// date.
///
/// One entry per **block**, not per shot: a shot may now be placed more than once (interrupted by
/// the meal break and resumed after it, or picked up again on a later date), so a shot placed twice
/// carries two of these. Returned by `OcptScheduleService.loadShotPlacements`, keyed by shot id onto
/// a **list** — the shot list's own `Jour de tournage` read-out is built from it. A shot with no
/// live `shooting_day_blocks` row has no entry in that map at all, rather than an empty list: "not
/// placed" and "placed nowhere in particular" are not the same state, and only the first exists.
class OcptShotPlacement extends Equatable {
  /// The shot this placement is for.
  final String shotId;

  /// The day this shot is placed on.
  final String dayId;

  /// That day's printed rank (`J3` prints `3`). See `OcptShootingDay.dayNumber`.
  final int dayNumber;

  /// That day's calendar date.
  final DateTime date;

  /// Class constructor
  const OcptShotPlacement({
    required this.shotId,
    required this.dayId,
    required this.dayNumber,
    required this.date,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShotPlacement(shotId: $shotId, dayId: $dayId, dayNumber: $dayNumber)";

  /// Object properties
  @override
  List<Object?> get props => [shotId, dayId, dayNumber, date];
}
