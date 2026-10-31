// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_column.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';

/// One block drawn as a tile: which column it sits in, which rows it spans, and its own exact
/// clock — carried alongside the row span rather than instead of it, since the row span is a
/// **reading aid**, not a claim that the block actually starts and ends on a ten-minute mark. A
/// renderer prints [caption] and the exact `[startMinute, endMinute)` inside the tile
/// [startRow]..[startRow] + [rowSpan] - 1 spans.
class OcptShootingDayAgendaTile extends Equatable {
  /// Class constructor
  const OcptShootingDayAgendaTile({
    required this.blockId,
    required this.slotId,
    required this.caption,
    required this.startMinute,
    required this.endMinute,
    required this.startRow,
    required this.rowSpan,
  });

  /// The block's own id (`shooting_day_blocks.id`).
  final String blockId;

  /// The id of the [OcptShootingDayAgendaColumn] this tile is drawn in.
  final String slotId;

  /// The tile's own already-localized caption.
  final String caption;

  /// The block's own **exact** resolved start, unsnapped — what the tile prints inside itself, a
  /// 12-minute block on a 10-minute grid still reading `09:12` rather than `09:10`.
  final int startMinute;

  /// The block's own exact resolved end, unsnapped, mirroring [startMinute]. Always strictly
  /// greater than [startMinute] once [OcptShootingDayAgendaGrid.stepMinutes] rounding is undone by
  /// the caller — the grid geometry itself never claims a zero-length span, see [rowSpan].
  final int endMinute;

  /// The 0-based row, within [OcptShootingDayAgendaGrid.rowCount], this tile's own band starts on.
  final int startRow;

  /// How many rows this tile spans, always at least 1: a block resolving to zero minutes (a
  /// milestone marker) or to a duration shorter than [OcptShootingDayAgendaGrid.stepMinutes] (the
  /// 12-minute case) still occupies one whole row rather than a sliver of one — a grid can only
  /// draw whole rows, and a tile with no row of its own would be invisible.
  final int rowSpan;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingDayAgendaTile(blockId: $blockId, slotId: $slotId, rows: $startRow+$rowSpan)";

  /// Object properties
  @override
  List<Object?> get props => [blockId, slotId, caption, startMinute, endMinute, startRow, rowSpan];
}
