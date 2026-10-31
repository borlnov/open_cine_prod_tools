// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_timeline_entry.dart';

/// One slot's own block, already placed on the day's clock — the raw material every reader of a
/// day's timetable is built from, whichever of the two schedule PDF exports is reading it.
class OcptOrderedScheduleEntry {
  /// Class constructor
  const OcptOrderedScheduleEntry({required this.slot, required this.block, required this.entry});

  /// The slot [block] belongs to.
  final OcptShootingSlot slot;

  /// The block itself.
  final OcptShootingDayBlock block;

  /// Where [block] is placed — the *resolved* clock, never a stored anchor.
  final OcptShootingTimelineEntry entry;
}
