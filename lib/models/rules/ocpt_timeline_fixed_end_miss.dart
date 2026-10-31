// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_overrun.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// A slot whose own blocks do not finish on the [fixedEndMinute] its
/// [OcptShootingSlotAnchorEdge.end] anchor pins it to: a pinned block inside it (ADR 0015's rule 3)
/// started exactly at its own anchor, which moved everything after it, so the chain lands on
/// [actualEndMinute] instead.
///
/// **The fixed end wins, and the mismatch is reported rather than absorbed** — the same refusal
/// [OcptTimelineOverrun] already makes: the slot's start was computed as `fixedEndMinute − Σ
/// durations`, the chain then ran forward from there exactly as always, and nothing is stretched or
/// squeezed afterwards to make the plan look like it fits. A schedule that quietly moved the fixed
/// end to wherever the blocks happened to land would say the studio was booked until a time nobody
/// agreed to.
class OcptTimelineFixedEndMiss {
  /// Builds a missed-fixed-end record.
  const OcptTimelineFixedEndMiss({
    required this.slotId,
    required this.fixedEndMinute,
    required this.actualEndMinute,
  });

  /// The [OcptShootingTimelineSlot.id] whose fixed end its own blocks did not land on.
  final String slotId;

  /// The hour the slot's [OcptShootingSlotAnchorEdge.end] anchor resolved to.
  final int fixedEndMinute;

  /// The minute the slot's chain actually ends at.
  final int actualEndMinute;
}
