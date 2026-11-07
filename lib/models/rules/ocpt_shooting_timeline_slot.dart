// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_block.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// One slot of a day, ready to be chained by [ocptComputeShootingDayTimelines]: its own id, its own
/// anchor and its own blocks, in the order [ocptComputeSlotTimeline] should place them in.
class OcptShootingTimelineSlot extends Equatable {
  /// The slot's own id (`shooting_slots.id`).
  final String id;

  /// Which of this slot's two edges is the pinned one.
  final OcptShootingSlotAnchorEdge anchorEdge;

  /// The hour [anchorEdge] is pinned to, typed by hand — null exactly when [anchorSlotId] is set.
  final int? anchorMinute;

  /// The id of the slot of the same day whose **opposite** edge [anchorEdge] reads its hour off —
  /// null exactly when [anchorMinute] is set. A [anchorSlotId] naming no slot of the day given to
  /// [ocptComputeShootingDayTimelines] is read the same way both being null is: see that function's
  /// own doc comment.
  final String? anchorSlotId;

  /// This slot's own blocks, in `sortKey` order — a block belongs to exactly one slot, so no block
  /// of the day appears in more than one [OcptShootingTimelineSlot].
  final List<OcptShootingTimelineBlock> blocks;

  /// Build a slot to feed to [ocptComputeShootingDayTimelines].
  const OcptShootingTimelineSlot({
    required this.id,
    required this.anchorEdge,
    required this.anchorMinute,
    required this.anchorSlotId,
    required this.blocks,
  });

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [id, anchorEdge, anchorMinute, anchorSlotId, blocks];
}
