// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';

/// One column of the locations, sequences and crew-and-cast summary grids: a slot, and the day it
/// belongs to — [dayId]/[dayNumber] let a caller print or write a day tag once above the first
/// column of its own group, [OcptShootingPlanGrids.slotColumns] itself carrying no grouping of its
/// own (a caller compares one column's [dayId] against the one before it, exactly as
/// `OcptShootingPlanGridSections.gridPage` already does).
class OcptShootingPlanGridColumn extends Equatable {
  /// Class constructor
  const OcptShootingPlanGridColumn({
    required this.dayId,
    required this.dayNumber,
    required this.slotId,
    required this.slotLabel,
  });

  /// The id of the day [slotId] belongs to.
  final String dayId;

  /// That day's own printed rank (`OcptShootingDay.dayNumber`).
  final int dayNumber;

  /// The slot this column is about.
  final String slotId;

  /// The slot's own free-text label, verbatim — never substituted with a placeholder here, which is
  /// a drawing-time decision each caller makes for itself.
  final String slotLabel;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanGridColumn(dayId: $dayId, slotId: $slotId)";

  /// Object properties
  @override
  List<Object?> get props => [dayId, dayNumber, slotId, slotLabel];
}
