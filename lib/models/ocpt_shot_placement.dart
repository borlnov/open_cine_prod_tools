// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';

/// Where one block places a shot in the schedule: which day, what that day is for, that day's
/// printed rank, and its date.
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
  ///
  /// Meaningless without [dayKind]: the three kinds are numbered in three separate series, so a
  /// `1` here is `J1`, `C1` or `R1` depending on what the day is for.
  final int dayNumber;

  /// What the day this shot is placed on is for. A shot normally sits on a day that shoots; the
  /// column exists because nothing forbids a block outliving a change of kind, and a placement
  /// read-out must print the tag the day actually wears rather than assume a `J`.
  final OcptShootingDayKind dayKind;

  /// That day's calendar date.
  final DateTime date;

  /// Class constructor
  const OcptShotPlacement({
    required this.shotId,
    required this.dayId,
    required this.dayNumber,
    required this.dayKind,
    required this.date,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShotPlacement(shotId: $shotId, dayId: $dayId, dayKind: $dayKind, "
      "dayNumber: $dayNumber)";

  /// Object properties
  @override
  List<Object?> get props => [shotId, dayId, dayNumber, dayKind, date];
}
