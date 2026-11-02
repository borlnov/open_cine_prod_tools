// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// A set of slots whose anchors read each other round in a circle — A's start reading B's end while
/// B's start reads A's end — so no one of them can be resolved before the others.
///
/// **This is defence, not a path a user can reach**: the anchor picker refuses to offer an entry
/// that would build one (`ocptSlotAnchorWouldCycle`), and `OcptScheduleService` refuses to write
/// one. A pure function that can be handed a database row — a hand-edited file, a payload restored
/// from another build — must not hang on it, so the cycle is reported here and the slots in it are
/// resolved as if [OcptShootingSlotAnchorEdge.start]-anchored at the earliest start the day had
/// already resolved (minute 0 when the whole day cycles).
class OcptTimelineAnchorCycle extends Equatable {
  /// The [OcptShootingTimelineSlot.id]s that read one another round, in the order the resolution
  /// walked them, the first one being the one the walk came back to.
  final List<String> slotIds;

  /// Build a cycle record.
  const OcptTimelineAnchorCycle({required this.slotIds});

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [slotIds];
}
