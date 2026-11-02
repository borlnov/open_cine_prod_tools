// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_anchor_cycle.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_fixed_end_miss.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_overrun.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// The result of chaining every slot of a day, each independently: a day is a **set of parallel
/// chains**, not one — see [ocptComputeShootingDayTimelines]'s own doc comment.
class OcptShootingDayTimelines extends Equatable {
  /// Each slot's own [OcptShootingSlotTimeline], keyed by [OcptShootingTimelineSlot.id].
  final Map<String, OcptShootingSlotTimeline> bySlotId;

  /// Every entry of every slot, flattened: the slots in the order they were given to
  /// [ocptComputeShootingDayTimelines], and within a slot, its own chain order. Exists so a reader
  /// that only cares about a block's own placement (the day view, a call sheet) doesn't have to
  /// know which slot produced it.
  final List<OcptShootingTimelineEntry> entries;

  /// Every over-run of every slot, flattened the same way as [entries].
  final List<OcptTimelineOverrun> overruns;

  /// Every [OcptShootingSlotAnchorEdge.end]-anchored slot whose own blocks did not land on its
  /// fixed end. Empty when none did — including on a day with no end-anchored slot at all.
  final List<OcptTimelineFixedEndMiss> fixedEndMisses;

  /// Every circle of anchors found while resolving the day. Empty on any day a user can build —
  /// see [OcptTimelineAnchorCycle]'s own doc comment.
  final List<OcptTimelineAnchorCycle> anchorCycles;

  /// The **minimum** of every slot's own resolved [OcptShootingSlotTimeline.startMinute] — the
  /// earliest moment anybody on this day is due, which is also its earliest arrival (ADR 0018:
  /// nothing pulls somebody in ahead of their own slot's start). Null only when the day carries no
  /// slot at all; a slot with nothing placed in it still has a start.
  final int? dayStartMinute;

  /// The **maximum** of every slot's own [OcptShootingSlotTimeline.endMinute] — a day ends when its
  /// last unit wraps. Null when every slot is empty (see [OcptShootingSlotTimeline.endMinute]'s own
  /// doc comment on what "empty" means for one slot).
  final int? dayEndMinute;

  /// Build a computed set of timelines.
  const OcptShootingDayTimelines({
    required this.bySlotId,
    required this.entries,
    required this.overruns,
    required this.fixedEndMisses,
    required this.anchorCycles,
    required this.dayStartMinute,
    required this.dayEndMinute,
  });

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [
    bySlotId,
    entries,
    overruns,
    fixedEndMisses,
    anchorCycles,
    dayStartMinute,
    dayEndMinute,
  ];
}
