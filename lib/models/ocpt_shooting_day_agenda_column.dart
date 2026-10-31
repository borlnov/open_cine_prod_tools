// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_column_input.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';

/// One slot column of the grid: its id and its own label, carried through from
/// [OcptShootingDayAgendaColumnInput] unchanged — everything else that input held (the timeline,
/// the captions) has already been turned into [OcptShootingDayAgendaGrid.tiles] by the time the
/// grid is built.
class OcptShootingDayAgendaColumn extends Equatable {
  /// Class constructor
  const OcptShootingDayAgendaColumn({required this.slotId, required this.label});

  /// The slot's own id.
  final String slotId;

  /// The slot's own free-text label.
  final String label;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingDayAgendaColumn(slotId: $slotId, label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [slotId, label];
}
