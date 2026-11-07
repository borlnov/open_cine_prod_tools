// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_column_input.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';

/// One event, as fed to [OcptShootingDayAgendaGrid.of]: its id, its absolute minute and its
/// already-localized label — the same trade [OcptShootingDayAgendaColumnInput.captionByBlockId]
/// makes, for the same reason.
class OcptShootingDayAgendaEventInput extends Equatable {
  /// The event's own id (`shooting_day_events.id`).
  final String id;

  /// The minute, from the day's own midnight, this event happens at. May exceed 1440, exactly as
  /// every other minute in this file may.
  final int minute;

  /// The event's own printable label.
  final String label;

  /// Class constructor
  const OcptShootingDayAgendaEventInput({
    required this.id,
    required this.minute,
    required this.label,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() => "OcptShootingDayAgendaEventInput(id: $id, minute: $minute, label: $label)";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [id, minute, label];
}
