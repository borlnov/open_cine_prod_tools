// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// The whole schedule read, joined into the day-level facts every reader of the schedule mode is
/// understood through — a slot's own resolved hours, a day's whole call, its sun times, its first
/// location.
///
/// This is the single place `OcptScheduleState` and the schedule's own coming PDF exports (call
/// sheets, shooting plan) both reach for those joins from: the manager layer the exports run in
/// holds no bloc state, but needs exactly the same answers the day view already reads — the hour a
/// slot starts at, chief among them — and a second implementation of that join is how a printed
/// call sheet and the day view would come to disagree about it. `ocpt_shooting_day_timeline.dart`,
/// `ocpt_shooting_convocations.dart` and `ocpt_sun_times.dart` know nothing of `shots`, `roles` or
/// drift at all; joining their pure inputs out of the stored rows is this class's whole job.
///
/// Built the same way `OcptBreakdownSnapshot.build` is: a pure function of already-loaded lists,
/// with no database access of its own. Unlike a per-read state getter, [locationById]/[setById]/
/// [roleById]/[personById] are built **once**, in [OcptSchedulePlanSnapshot.build], and stored as
/// unmodifiable maps — a caller walking a whole shoot's worth of days must not rebuild the address
/// book once per day.
class OcptSchedulePlanSnapshot extends Equatable {
  /// The whole schedule read: days, slots and blocks.
  final OcptScheduleSnapshot schedule;

  /// The whole shot list read, or null while nothing has been read yet — what a placed shot's own
  /// duration and characters are resolved from.
  final OcptShotListSnapshot? shotList;

  /// The project's whole location catalogue (with their sets), as passed to
  /// [OcptSchedulePlanSnapshot.build].
  final List<OcptLocation> locations;

  /// The project's whole cast, as passed to [OcptSchedulePlanSnapshot.build].
  final List<OcptRole> roles;

  /// The project's whole address book, as passed to [OcptSchedulePlanSnapshot.build].
  final List<OcptPerson> people;

  /// The whole location catalogue, keyed by id.
  final Map<String, OcptLocation> locationById;

  /// Every set of every location of [locations], keyed by id.
  final Map<String, OcptSet> setById;

  /// The whole cast, keyed by id.
  final Map<String, OcptRole> roleById;

  /// The whole address book, keyed by id.
  final Map<String, OcptPerson> personById;

  /// Class constructor. Prefer [OcptSchedulePlanSnapshot.build], which derives [locationById],
  /// [setById], [roleById] and [personById] rather than asking a caller to keep them in step by
  /// hand.
  const OcptSchedulePlanSnapshot({
    required this.schedule,
    required this.shotList,
    required this.locations,
    required this.roles,
    required this.people,
    required this.locationById,
    required this.setById,
    required this.roleById,
    required this.personById,
  });

  /// Builds an [OcptSchedulePlanSnapshot] from [schedule], [shotList] and the three catalogues,
  /// deriving [locationById]/[setById]/[roleById]/[personById] from them once.
  factory OcptSchedulePlanSnapshot.build({
    required OcptScheduleSnapshot schedule,
    required OcptShotListSnapshot? shotList,
    required List<OcptLocation> locations,
    required List<OcptRole> roles,
    required List<OcptPerson> people,
  }) => OcptSchedulePlanSnapshot(
    schedule: schedule,
    shotList: shotList,
    locations: locations,
    roles: roles,
    people: people,
    locationById: Map.unmodifiable({for (final location in locations) location.id: location}),
    setById: Map.unmodifiable({
      for (final location in locations)
        for (final set in location.sets) set.id: set,
    }),
    roleById: Map.unmodifiable({for (final role in roles) role.id: role}),
    personById: Map.unmodifiable({for (final person in people) person.id: person}),
  );

  /// The shot [shotId] names, or null while [shotList] hasn't loaded it (or it has since been
  /// deleted).
  OcptShot? shotById(String shotId) => shotList?.shotsById[shotId];

  /// [dayId]'s own computed timelines (ADR 0015, as amended), one chain per live slot, joined
  /// into a single [OcptShootingDayTimelines] — or null while the day has no live slot to chain at
  /// all.
  ///
  /// Computed here rather than stored: reading it costs nothing beyond a handful of list lookups
  /// already held in memory, and storing it would be one more thing every write to that day's
  /// blocks would have to remember to invalidate.
  OcptShootingDayTimelines? timelinesOfDay(String dayId) {
    final slots = schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    if (slots.isEmpty) {
      return null;
    }

    final blocks = schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[];
    final blocksBySlotId = <String, List<OcptShootingDayBlock>>{};
    for (final block in blocks) {
      (blocksBySlotId[block.slotId] ??= <OcptShootingDayBlock>[]).add(block);
    }

    final timelineSlots = [
      for (final slot in slots)
        OcptShootingTimelineSlot(
          id: slot.id,
          anchorEdge: slot.anchorEdge,
          anchorMinute: slot.anchorMinute,
          anchorSlotId: slot.anchorSlotId,
          blocks: [
            for (final block in blocksBySlotId[slot.id] ?? const <OcptShootingDayBlock>[])
              OcptShootingTimelineBlock(
                id: block.id,
                durationMinutes: block.durationMinutes,
                fallbackDurationMinutes: block.kind == OcptShootingBlockKind.shot && block.shotId != null
                    ? _durationMinutesOfShot(block.shotId!)
                    : null,
                anchorMinute: block.anchorMinute,
              ),
          ],
        ),
    ];

    return ocptComputeShootingDayTimelines(
      slots: timelineSlots,
      defaultDurationMinutes: ocptDefaultBlockDurationMinutes,
    );
  }

  /// Day [dayId]'s own whole call (ADR 0018): one `OcptDayConvocation` per person and per uncast
  /// role linked to any of its live slots, empty while [dayId] names no day with a live slot at all.
  ///
  /// Built by [ocptComputeDayConvocations] over one [OcptConvocationSlot] per live slot
  /// ([_convocationSlotOf]) — that pure function knows nothing of `shots`, `roles` or the timeline,
  /// so joining a slot's already-chained blocks ([timelinesOfDay]) onto its own crew and cast rows,
  /// and resolving a cast role's own actor through [roleById], is this snapshot's job alone.
  List<OcptDayConvocation> convocationsOfDay(String dayId) {
    final slots = schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    if (slots.isEmpty) {
      return const [];
    }

    final timelines = timelinesOfDay(dayId);
    final blocksById = {
      for (final block in schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[])
        block.id: block,
    };

    return ocptComputeDayConvocations(
      slots: [
        // Every live slot of the day was handed to [timelinesOfDay] just above, so each has its own
        // entry back: the `!` is that round trip, not an assumption about the data.
        for (final slot in slots)
          _convocationSlotOf(slot, timelines!.bySlotId[slot.id]!, blocksById),
      ],
    );
  }

  /// Builds [slot]'s own [OcptConvocationSlot]: [OcptConvocationSlot.shootingStartMinute]/
  /// [OcptConvocationSlot.shootingEndMinute] are the minimum start and the maximum end, over
  /// [timeline]'s own entries whose [blocksById] row is a [OcptShootingBlockKind.shot] or a
  /// [OcptShootingBlockKind.hold] — a minimum and a maximum rather than "the first and last entry",
  /// since a pinned anchor can put a block earlier than the one before it in chain order — and
  /// [OcptConvocationSlot.personIds]/[OcptConvocationSlot.uncastRoleIds] come from [slot]'s own live
  /// crew and cast rows, a cast role's own actor read through [roleById]'s own `personId`.
  ///
  /// [OcptConvocationSlot.startMinute] is [timeline]'s own **resolved** start, never a stored
  /// column: a slot pinned by its end starts wherever its blocks put it, and a convocation is what
  /// that lands on.
  OcptConvocationSlot _convocationSlotOf(
    OcptShootingSlot slot,
    OcptShootingSlotTimeline timeline,
    Map<String, OcptShootingDayBlock> blocksById,
  ) {
    int? shootingStartMinute;
    int? shootingEndMinute;
    for (final entry in timeline.entries) {
      final kind = blocksById[entry.blockId]?.kind;
      if (kind != OcptShootingBlockKind.shot && kind != OcptShootingBlockKind.hold) {
        continue;
      }
      if (shootingStartMinute == null || entry.startMinute < shootingStartMinute) {
        shootingStartMinute = entry.startMinute;
      }
      if (shootingEndMinute == null || entry.endMinute > shootingEndMinute) {
        shootingEndMinute = entry.endMinute;
      }
    }

    final personIds = <String>{for (final member in slot.crew) member.personId};
    final uncastRoleIds = <String>{};
    for (final member in slot.cast) {
      final actorId = roleById[member.roleId]?.personId;
      if (actorId != null) {
        personIds.add(actorId);
      } else {
        uncastRoleIds.add(member.roleId);
      }
    }

    return OcptConvocationSlot(
      id: slot.id,
      startMinute: timeline.startMinute,
      endMinute: timeline.endMinute,
      shootingStartMinute: shootingStartMinute,
      shootingEndMinute: shootingEndMinute,
      personIds: personIds,
      uncastRoleIds: uncastRoleIds,
    );
  }

  /// Day [dayId]'s own earliest arrival — the minimum **resolved** start over its live slots
  /// ([OcptShootingDayTimelines.dayStartMinute]) — or null while it has no live slot at all.
  ///
  /// Reads off the slots alone, not off who is convoked (ADR 0018): nothing pulls an arrival ahead
  /// of its own slot's start any more, so the day's earliest slot start already is its earliest
  /// arrival, with no convocation to compute for it. It reads the **resolved** start rather than a
  /// stored column, an end-anchored slot's own start being a fact about its blocks (ADR 0015,
  /// amended a second time).
  int? dayArrivalMinute(String dayId) => timelinesOfDay(dayId)?.dayStartMinute;

  /// [shotId]'s own `estimatedDurationMs`, converted to minutes, or null while it has none yet (or
  /// the shot isn't loaded).
  int? _durationMinutesOfShot(String shotId) {
    final estimatedDurationMs = shotById(shotId)?.estimatedDurationMs;
    return estimatedDurationMs == null ? null : (estimatedDurationMs / 60000).round();
  }

  /// [dayId]'s own computed sun and twilight times (ADR 0016), or null while its first live slot
  /// has no location, or that location has no coordinates pinned yet.
  OcptSunTimes? sunTimesOfDay(String dayId) {
    final day = schedule.daysById[dayId];
    final slots = schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    if (day == null || slots.isEmpty) {
      return null;
    }

    final location = locationById[slots.first.locationId];
    final latitude = location?.latitude;
    final longitude = location?.longitude;
    if (latitude == null || longitude == null) {
      return null;
    }

    return ocptSunTimesOf(date: day.date, latitudeDegrees: latitude, longitudeDegrees: longitude);
  }

  /// [dayId]'s own first live slot's location, or null while it has none — what a day's own tint
  /// (`ocptScheduleDayLocationTint`) and its inspector's own "Locations" line are read off.
  OcptLocation? firstLocationOfDay(String dayId) {
    final slots = schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    return slots.isEmpty ? null : locationById[slots.first.locationId];
  }

  /// Object properties
  @override
  List<Object?> get props => [
    schedule,
    shotList,
    locations,
    roles,
    people,
    locationById,
    setById,
    roleById,
    personById,
  ];
}
