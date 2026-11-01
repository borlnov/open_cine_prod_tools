// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_block.dart';

/// A block whose pinned [OcptShootingTimelineBlock.anchorMinute] the chain could not honour without
/// overlapping the block before it: the chain had already reached [reachedMinute] — later than
/// [anchorMinute] — by the time it got to this block.
///
/// The block is **not** silently pushed to [reachedMinute] to avoid the conflict (rule 4): it still
/// starts at exactly [anchorMinute], the way every anchored block does, and this is the record that
/// says the plan no longer fits there. A schedule that quietly absorbed the overlap would read as
/// fine when it isn't; this is what lets the day view show the block in red instead.
class OcptTimelineOverrun {
  /// The [OcptShootingTimelineBlock.id] whose anchor could not be honoured.
  final String blockId;

  /// The minute the chain had reached, right before this block pinned it back to [anchorMinute].
  final int reachedMinute;

  /// The anchor the block was pinned to, which [reachedMinute] ran past.
  final int anchorMinute;

  /// Build an over-run record.
  const OcptTimelineOverrun({
    required this.blockId,
    required this.reachedMinute,
    required this.anchorMinute,
  });
}
