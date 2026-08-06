// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_group.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// The whole schedule of one screenplay, as `OcptScheduleService.loadSchedule` builds it and the
/// schedule mode's bloc holds it.
///
/// Built the same way `OcptShotListSnapshot.build` is: a pure function of already-loaded, already
/// ordered lists, with no database access of its own. [days] is in [OcptShootingDay.dayNumber]
/// order (i.e. `sortKey` order); each day's [groupsByDayId] and [slotsByDayId] entries are each in
/// `sortKey` order, each slot carrying its own live crew and cast already nested
/// (`OcptShootingSlot.crew`/`.cast`); each day's [blocksByDayId] entry is in `sortKey` order too —
/// the timetable order `lib/utils/ocpt_shooting_day_timeline.dart` reads to chain a slot's clock,
/// this snapshot deferring to it for every clock time rather than computing one.
class OcptScheduleSnapshot extends Equatable {
  /// The screenplay this schedule belongs to.
  final String screenplayId;

  /// Every live day, in [OcptShootingDay.dayNumber] order.
  final List<OcptShootingDay> days;

  /// Every day of [days], keyed by its id.
  final Map<String, OcptShootingDay> daysById;

  /// Every day's live groups, keyed by `shootingDayId`, each list in `sortKey` order. Absent for a
  /// day with no group at all — a day starts with none, `OcptScheduleService.createDay` only
  /// copying the previous day's groups when there is a previous day to copy from — so callers use
  /// `[]` on the lookup rather than assuming a key, exactly as [slotsByDayId] does.
  final Map<String, List<OcptShootingDayGroup>> groupsByDayId;

  /// Every day's live slots, keyed by `shootingDayId`, each list in `sortKey` order. A day with no
  /// entry here does not happen in practice — `OcptScheduleService.createDay` always mints a day
  /// with its first slot — but a day whose only slot was since deleted reads as an absent key
  /// rather than an empty list, so callers use `[] ` on the lookup rather than assuming a key.
  final Map<String, List<OcptShootingSlot>> slotsByDayId;

  /// Every day's live blocks — its timetable — keyed by `shootingDayId`, each list in `sortKey`
  /// order (the chain order `ocpt_shooting_day_timeline.dart` reads). Absent for a day with no
  /// block yet, for the same reason [slotsByDayId] is.
  final Map<String, List<OcptShootingDayBlock>> blocksByDayId;

  /// The id of every shot that is placed somewhere in the schedule: every live block whose `kind`
  /// is [OcptShootingBlockKind.shot], across every day. `OcptScheduleService.placeShot` is the only
  /// writer that can grow this set, and it never lets a shot appear in it twice.
  final Set<String> placedShotIds;

  /// Class constructor
  const OcptScheduleSnapshot({
    required this.screenplayId,
    required this.days,
    required this.daysById,
    required this.groupsByDayId,
    required this.slotsByDayId,
    required this.blocksByDayId,
    required this.placedShotIds,
  });

  /// Builds an [OcptScheduleSnapshot] for [screenplayId] from its already-ordered [days],
  /// [groupsByDayId], [slotsByDayId] and [blocksByDayId], deriving [daysById] and [placedShotIds]
  /// from them.
  factory OcptScheduleSnapshot.build({
    required String screenplayId,
    required List<OcptShootingDay> days,
    required Map<String, List<OcptShootingDayGroup>> groupsByDayId,
    required Map<String, List<OcptShootingSlot>> slotsByDayId,
    required Map<String, List<OcptShootingDayBlock>> blocksByDayId,
  }) {
    final placedShotIds = <String>{
      for (final blocks in blocksByDayId.values)
        for (final block in blocks)
          if (block.kind == OcptShootingBlockKind.shot && block.shotId != null) block.shotId!,
    };

    return OcptScheduleSnapshot(
      screenplayId: screenplayId,
      days: days,
      daysById: Map.unmodifiable({for (final day in days) day.id: day}),
      groupsByDayId: Map.unmodifiable(groupsByDayId),
      slotsByDayId: Map.unmodifiable(slotsByDayId),
      blocksByDayId: Map.unmodifiable(blocksByDayId),
      placedShotIds: Set.unmodifiable(placedShotIds),
    );
  }

  /// The total number of live days.
  int get dayCount => days.length;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptScheduleSnapshot(screenplayId: $screenplayId, dayCount: $dayCount, "
      "placedShotCount: ${placedShotIds.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    screenplayId,
    days,
    daysById,
    groupsByDayId,
    slotsByDayId,
    blocksByDayId,
    placedShotIds,
  ];
}
