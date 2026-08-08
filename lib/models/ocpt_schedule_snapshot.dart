// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// The whole schedule of one screenplay, as `OcptScheduleService.loadSchedule` builds it and the
/// schedule mode's bloc holds it.
///
/// Built the same way `OcptShotListSnapshot.build` is: a pure function of already-loaded, already
/// ordered lists, with no database access of its own. [days] is in [OcptShootingDay.dayNumber]
/// order (i.e. `sortKey` order); each day's [slotsByDayId] entry is in `sortKey` order, each slot
/// carrying its own live crew, cast and guests already nested
/// (`OcptShootingSlot.crew`/`.cast`/`.guests`); each day's [blocksByDayId] entry is in `sortKey`
/// order too — the timetable order `lib/utils/ocpt_shooting_day_timeline.dart` reads to chain a
/// slot's clock, this snapshot deferring to it for every clock time rather than computing one; each
/// day's [eventsByDayId] entry is ordered by [OcptShootingDayEvent.minute], ties broken by
/// `sortKey` — an event's own hour, not a chain, being the only thing that orders it.
class OcptScheduleSnapshot extends Equatable {
  /// The screenplay this schedule belongs to.
  final String screenplayId;

  /// Every live day, in [OcptShootingDay.dayNumber] order.
  final List<OcptShootingDay> days;

  /// Every day of [days], keyed by its id.
  final Map<String, OcptShootingDay> daysById;

  /// Every day's live slots, keyed by `shootingDayId`, each list in `sortKey` order. A day with no
  /// entry here does not happen in practice — `OcptScheduleService.createDay` always mints a day
  /// with its first slot — but a day whose only slot was since deleted reads as an absent key
  /// rather than an empty list, so callers use `[] ` on the lookup rather than assuming a key.
  final Map<String, List<OcptShootingSlot>> slotsByDayId;

  /// Every day's live blocks — its timetable — keyed by `shootingDayId`, each list in `sortKey`
  /// order (the chain order `ocpt_shooting_day_timeline.dart` reads). Absent for a day with no
  /// block yet, for the same reason [slotsByDayId] is.
  final Map<String, List<OcptShootingDayBlock>> blocksByDayId;

  /// Every day's live events — what it does not control, at an absolute hour — keyed by
  /// `shootingDayId`, each list ordered by [OcptShootingDayEvent.minute] then by `sortKey`. Absent
  /// for a day with no event, for the same reason [slotsByDayId] is.
  final Map<String, List<OcptShootingDayEvent>> eventsByDayId;

  /// The id of every shot that is placed somewhere in the schedule: every live block whose `kind`
  /// is [OcptShootingBlockKind.shot], across every day. `OcptScheduleService.placeShot` is the only
  /// writer that can grow this set — a shot placed more than once (interrupted by the meal break and
  /// resumed after it, say) still appears here exactly once, this being a set of shots rather than
  /// of placements; `OcptShotListSnapshot.placementsByShotId` is where a shot's *own* count of
  /// placements is read.
  final Set<String> placedShotIds;

  /// Every live `shooting_presences` row, keyed by `(shootingDayId, personId)` — the presence grid's
  /// own by-hand overrides, one cell lookup being one map read rather than a scan. A pair with no
  /// entry here carries no override at all, which `OcptSchedulePlanSnapshot.presenceCellOf` reads as
  /// "the computed value stands", exactly as `OcptShootingPresencesTable`'s own doc comment says.
  final Map<(String dayId, String personId), OcptPresenceCode> presenceOverrideByDayAndPerson;

  /// Class constructor
  const OcptScheduleSnapshot({
    required this.screenplayId,
    required this.days,
    required this.daysById,
    required this.slotsByDayId,
    required this.blocksByDayId,
    required this.eventsByDayId,
    required this.placedShotIds,
    required this.presenceOverrideByDayAndPerson,
  });

  /// Builds an [OcptScheduleSnapshot] for [screenplayId] from its already-ordered [days],
  /// [slotsByDayId], [blocksByDayId], [eventsByDayId] and [presenceOverrideByDayAndPerson], deriving
  /// [daysById] and [placedShotIds] from them.
  factory OcptScheduleSnapshot.build({
    required String screenplayId,
    required List<OcptShootingDay> days,
    required Map<String, List<OcptShootingSlot>> slotsByDayId,
    required Map<String, List<OcptShootingDayBlock>> blocksByDayId,
    required Map<String, List<OcptShootingDayEvent>> eventsByDayId,
    Map<(String dayId, String personId), OcptPresenceCode> presenceOverrideByDayAndPerson = const {},
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
      slotsByDayId: Map.unmodifiable(slotsByDayId),
      blocksByDayId: Map.unmodifiable(blocksByDayId),
      eventsByDayId: Map.unmodifiable(eventsByDayId),
      placedShotIds: Set.unmodifiable(placedShotIds),
      presenceOverrideByDayAndPerson: Map.unmodifiable(presenceOverrideByDayAndPerson),
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
    slotsByDayId,
    blocksByDayId,
    eventsByDayId,
    placedShotIds,
    presenceOverrideByDayAndPerson,
  ];
}
