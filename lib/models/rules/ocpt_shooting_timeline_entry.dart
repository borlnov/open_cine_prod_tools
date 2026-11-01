// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_block.dart';

/// One block placed on the timeline: where it starts, where it ends, and how long it actually ran
/// for — which is not always [OcptShootingTimelineBlock.durationMinutes], since that may have been
/// null.
class OcptShootingTimelineEntry {
  /// The [OcptShootingTimelineBlock.id] this entry places.
  final String blockId;

  /// The minute, from the day's own midnight, this block starts at. May exceed 1440 for a night
  /// shoot's small hours — see `ocptFormatDayMinute` (`ocpt_day_minute.dart`).
  final int startMinute;

  /// The minute this block ends at: always `startMinute + durationMinutes`.
  final int endMinute;

  /// The duration this entry actually used: the block's own, its fallback, or the mode's default —
  /// whichever [ocptComputeSlotTimeline] fell back to.
  final int durationMinutes;

  /// Builds a placed entry.
  const OcptShootingTimelineEntry({
    required this.blockId,
    required this.startMinute,
    required this.endMinute,
    required this.durationMinutes,
  });
}
