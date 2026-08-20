// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';

/// One day of the shooting schedule.
///
/// A day belongs to no episode — see `OcptShootingDaysTable`'s own doc comment
/// (`docs/adr/0019-one-project-several-episodes.md`) — the schedule being the production's rather
/// than any one screenplay's.
///
/// [dayNumber] is the printed `J3` — a **read-time rank**, 1-based, over the project's live days
/// ordered chronologically (by `date`, `sortKey` breaking a tie between two days sharing one
/// date), exactly as `OcptShot.position` is never `shots.position`. It is a **label, not an id**:
/// moving a day's date renumbers every day around it, which is what `J1`/`J2` mean on a call
/// sheet. It is never stored: `OcptScheduleService.loadSchedule` counts it off while ordering the
/// days it loads.
class OcptShootingDay extends Equatable {
  /// The stable, unique id of this day (a UUID).
  final String id;

  /// The calendar date of this day. Never null — see `OcptShootingDaysTable`'s own doc comment.
  final DateTime date;

  /// This day's 1-based rank among its screenplay's live days, ordered chronologically. See the
  /// class doc comment.
  final int dayNumber;

  /// Where this day stands.
  final OcptShootingDayStatus status;

  /// The call sheet's "NOTE À L'ÉQUIPE", free multi-line text printed for the whole crew.
  final String crewNote;

  /// The weather forecast for this day, typed by hand.
  final String weatherNote;

  /// Internal notes about this day, never printed on a call sheet.
  final String notes;

  /// Class constructor
  const OcptShootingDay({
    required this.id,
    required this.date,
    required this.dayNumber,
    required this.status,
    required this.crewNote,
    required this.weatherNote,
    required this.notes,
  });

  /// Builds an [OcptShootingDay] from its stored [row] and its 1-based [dayNumber]. [dayNumber] is
  /// passed in rather than read off [row]: see the class doc comment.
  factory OcptShootingDay.fromRow({required OcptShootingDayRow row, required int dayNumber}) =>
      OcptShootingDay(
        id: row.id,
        date: row.date,
        dayNumber: dayNumber,
        status: row.status,
        crewNote: row.crewNote,
        weatherNote: row.weatherNote,
        notes: row.notes,
      );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingDay(id: $id, dayNumber: $dayNumber, date: $date)";

  /// Object properties
  @override
  List<Object?> get props => [
    id,
    date,
    dayNumber,
    status,
    crewNote,
    weatherNote,
    notes,
  ];
}
