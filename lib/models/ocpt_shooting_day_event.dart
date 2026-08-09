// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/database/ocpt_project_database.dart';

/// Something a `OcptShootingDay` does not control, happening at an absolute hour.
///
/// [minute] is an offset from the day's own midnight and may exceed 1440 — see
/// `OcptShootingDayEventsTable`'s own doc comment for why this is deliberately not a
/// `shooting_day_blocks` row: it takes no part in any slot's chain, and moving one is typing another
/// hour, never dragging it.
class OcptShootingDayEvent extends Equatable {
  /// The stable, unique id of this event (a UUID).
  final String id;

  /// The day this event happens on.
  final String shootingDayId;

  /// The hour this event happens at, as an offset from the day's own midnight. May exceed 1440.
  final int minute;

  /// This event's own label.
  final String label;

  /// Free-form notes about this event.
  final String notes;

  /// Class constructor
  const OcptShootingDayEvent({
    required this.id,
    required this.shootingDayId,
    required this.minute,
    required this.label,
    required this.notes,
  });

  /// Builds an [OcptShootingDayEvent] from its stored [row].
  factory OcptShootingDayEvent.fromRow(OcptShootingDayEventRow row) => OcptShootingDayEvent(
    id: row.id,
    shootingDayId: row.shootingDayId,
    minute: row.minute,
    label: row.label,
    notes: row.notes,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayEvent(id: $id, shootingDayId: $shootingDayId, minute: $minute, "
      "label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [id, shootingDayId, minute, label, notes];
}
