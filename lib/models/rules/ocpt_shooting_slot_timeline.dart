// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_overrun.dart';

/// The result of chaining one slot's blocks: every block placed, every anchor that could not be
/// honoured, and where the slot starts and ends.
class OcptShootingSlotTimeline {
  /// Every block placed, in the order it was given.
  final List<OcptShootingTimelineEntry> entries;

  /// Every anchor the chain ran into. Empty when nothing over-ran.
  final List<OcptTimelineOverrun> overruns;

  /// The minute this slot's chain was started from — its **resolved** start, whichever edge the
  /// slot is anchored by and wherever that edge read its own hour. This, never a stored column, is
  /// what every reader of "the hour of this slot" reads.
  final int startMinute;

  /// The minute the last block ends at, or null when there was nothing to place at all — see
  /// [ocptComputeSlotTimeline]'s doc comment on the empty-slot case.
  final int? endMinute;

  /// Builds a computed timeline.
  const OcptShootingSlotTimeline({
    required this.entries,
    required this.overruns,
    required this.startMinute,
    required this.endMinute,
  });
}
