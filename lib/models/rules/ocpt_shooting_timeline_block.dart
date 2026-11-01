// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_timeline_overrun.dart';

/// One block of a slot's timetable, already resolved out of its `shooting_day_blocks` row (and,
/// for a shot block, out of the `shots` row it points at) by the caller — [ocptComputeSlotTimeline]
/// itself knows nothing of drift or of the schedule mode's own enums, on purpose: it is the one
/// place the chaining rule (ADR 0015, as amended) is implemented, and it must stay reachable from
/// a plain unit test.
class OcptShootingTimelineBlock {
  /// The block's own id (`shooting_day_blocks.id`), echoed back on every
  /// [OcptShootingTimelineEntry] and [OcptTimelineOverrun] that concerns it, so a caller can join
  /// the result back onto its rows.
  final String id;

  /// The block's own `durationMinutes`, when the user set one. Takes priority over
  /// [fallbackDurationMinutes] and over the mode's own default.
  final int? durationMinutes;

  /// A shot block's estimate (`shots.estimatedDurationMs`, already converted to minutes by the
  /// caller), used when [durationMinutes] is null. Null for a block that either isn't a shot or is
  /// a shot with no estimate of its own yet.
  final int? fallbackDurationMinutes;

  /// The block's `anchorMinute`, when it is pinned. A pinned block starts **exactly** here,
  /// unconditionally — see rule 3 on [ocptComputeSlotTimeline].
  final int? anchorMinute;

  /// Builds a block to feed to [ocptComputeSlotTimeline].
  const OcptShootingTimelineBlock({
    required this.id,
    this.durationMinutes,
    this.fallbackDurationMinutes,
    this.anchorMinute,
  });
}
