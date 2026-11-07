// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';

/// One slot's own column, as fed to [OcptShootingDayAgendaGrid.of]: its id, its already-resolved
/// [OcptShootingSlotTimeline] and the caption every one of its own blocks prints on its tile.
///
/// The timeline is read straight from `ocpt_shooting_day_timeline.dart` rather than re-derived —
/// this file adds no chaining rule of its own, only a reading of one already computed. A caption
/// is handed in **already localized** (through `ocptScheduleBlockCaptionOf`, or a shot's own code)
/// because it may need a `Tr` this pure-Dart file must never import, exactly the trade
/// `OcptScenarioCoverageLayout` makes for a bar's own label.
class OcptShootingDayAgendaColumnInput extends Equatable {
  /// The slot's own id (`shooting_slots.id`).
  final String slotId;

  /// The slot's own free-text label, exactly as typed — never substituted with a placeholder here,
  /// which is a drawing-time decision.
  final String label;

  /// The slot's own resolved timeline — every block already chained onto the day's clock.
  final OcptShootingSlotTimeline timeline;

  /// Every one of this slot's own blocks' printable caption, keyed by [OcptShootingTimelineEntry
  /// .blockId]. A block whose id has no entry here is skipped rather than drawn blank: a caller
  /// that forgot one is a bug to surface as a missing tile, not as an empty one.
  final Map<String, String> captionByBlockId;

  /// Class constructor
  const OcptShootingDayAgendaColumnInput({
    required this.slotId,
    required this.label,
    required this.timeline,
    required this.captionByBlockId,
  });

  /// Get a string representation of the object, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayAgendaColumnInput(slotId: $slotId, label: $label, "
      "captionCount: ${captionByBlockId.length})";

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [slotId, label, timeline, captionByBlockId];
}
