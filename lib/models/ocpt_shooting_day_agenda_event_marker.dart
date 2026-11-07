// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_event_placement.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_tile.dart';

/// One event drawn either as a full-width marker inside the grid's own rows, or as a leading or
/// trailing one just outside them — see [OcptShootingDayAgendaEventPlacement].
class OcptShootingDayAgendaEventMarker extends Equatable {
  /// The event's own id.
  final String eventId;

  /// The event's own already-localized label.
  final String label;

  /// The event's own exact minute, unsnapped — mirrors [OcptShootingDayAgendaTile.startMinute].
  final int minute;

  /// Where this marker is drawn relative to the grid's own rows.
  final OcptShootingDayAgendaEventPlacement placement;

  /// The 0-based row this marker is drawn across, the whole width of the grid — meaningful only
  /// when [placement] is [OcptShootingDayAgendaEventPlacement.inGrid], null otherwise: there is no
  /// row to name for a marker drawn outside the grid entirely.
  final int? row;

  /// Class constructor
  const OcptShootingDayAgendaEventMarker({
    required this.eventId,
    required this.label,
    required this.minute,
    required this.placement,
    required this.row,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayAgendaEventMarker(eventId: $eventId, placement: $placement, row: $row)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [eventId, label, minute, placement, row];
}
