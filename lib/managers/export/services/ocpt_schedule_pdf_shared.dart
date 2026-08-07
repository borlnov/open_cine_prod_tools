// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// What every PDF built off a shooting schedule prints in place of a value the project has not
/// filled in yet, or a computed figure that has none (a convocation with no PAT band, ADR 0018).
///
/// Shared by `OcptCallSheetPdfService` and `OcptShootingPlanPdfService` — the two documents read
/// the very same schedule, and a printed blank meaning two different things between them would be
/// the app disagreeing with itself about the one thing this milestone exists to get right.
const String ocptScheduleEmptyValue = "—";

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

/// Every block of [dayId], across every live slot (or only [onlySlotIds]' own, for a call sheet
/// addressed to one person), placed on the day's clock and sorted **in resolved clock order across
/// every slot**: two blocks starting at the same minute are ordered by their slot's own position in
/// the day, then by chain order — the one place a day's parallel chains are read as a single run,
/// which is what lets a call sheet's two crews, or a shooting plan's own day-part columns, fall out
/// of this app's own per-slot model.
List<OcptOrderedScheduleEntry> ocptOrderedScheduleEntriesOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  Set<String>? onlySlotIds,
}) {
  final timelines = plan.timelinesOfDay(dayId);
  if (timelines == null) {
    return const [];
  }

  final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
  final blocksById = {
    for (final block in plan.schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[]) block.id: block,
  };

  final tagged = <(int, OcptShootingSlot, OcptShootingTimelineEntry, int)>[];
  for (final (slotIndex, slot) in slots.indexed) {
    if (onlySlotIds != null && !onlySlotIds.contains(slot.id)) {
      continue;
    }
    final timeline = timelines.bySlotId[slot.id];
    if (timeline == null) {
      continue;
    }
    for (final (chainIndex, entry) in timeline.entries.indexed) {
      tagged.add((slotIndex, slot, entry, chainIndex));
    }
  }

  tagged.sort((a, b) {
    final byStart = a.$3.startMinute.compareTo(b.$3.startMinute);
    if (byStart != 0) {
      return byStart;
    }
    final bySlot = a.$1.compareTo(b.$1);
    if (bySlot != 0) {
      return bySlot;
    }
    return a.$4.compareTo(b.$4);
  });

  return [
    for (final (_, slot, entry, _) in tagged)
      if (blocksById[entry.blockId] case final block?) OcptOrderedScheduleEntry(slot: slot, block: block, entry: entry),
  ];
}

/// A map from every real scene's id to its own heading, built once per generated document — read
/// by both schedule PDF exports for a [OcptShootingBlockKind.hold] block's own caption, and by the
/// call sheet's main table for its own `EFFET` column, never re-derived from
/// `OcptSchedulePlanSnapshot.shotList` at each call site.
Map<String, String> ocptScheduleHeadingBySceneId(OcptSchedulePlanSnapshot plan) => {
  for (final sequence in plan.shotList?.sequences ?? const [])
    if (sequence is OcptSceneShotSequence) sequence.sceneId: sequence.heading,
};

/// The caption a non-shot [block] prints: its own free-text label when it has one, a
/// [OcptShootingBlockKind.hold]'s own sequence heading when it names one and carries no free-text
/// label, or [blockKindLabelOf] as the final fallback.
///
/// [blockKindLabelOf] is a resolver rather than a labels object: the two schedule PDF exports each
/// carry their own labels class (`OcptCallSheetLabels`, `OcptShootingPlanLabels`), and this
/// function has no reason to know about either — its caller hands in the one accessor it needs.
String ocptScheduleBlockCaptionOf({
  required OcptShootingDayBlock block,
  required Map<String, String> headingBySceneId,
  required String Function(OcptShootingBlockKind kind) blockKindLabelOf,
}) {
  final ownLabel = block.label.trim();
  if (ownLabel.isNotEmpty) {
    return ownLabel;
  }

  if (block.kind == OcptShootingBlockKind.hold && block.sceneId != null) {
    final heading = headingBySceneId[block.sceneId]?.trim();
    if (heading != null && heading.isNotEmpty) {
      return heading;
    }
  }

  return blockKindLabelOf(block.kind);
}

/// Every distinct location of [slots], in the order they are first met — a general document's own
/// locations (every slot of the day) or a named one's own (only the slots its recipient is linked
/// to).
List<OcptLocation> ocptScheduleLocationsOfSlots(OcptSchedulePlanSnapshot plan, List<OcptShootingSlot> slots) {
  final seen = <String>{};
  final locations = <OcptLocation>[];
  for (final slot in slots) {
    final locationId = slot.locationId;
    if (locationId == null) {
      continue;
    }
    final location = plan.locationById[locationId];
    if (location == null || !seen.add(location.id)) {
      continue;
    }
    locations.add(location);
  }
  return locations;
}

/// [location]'s own name and address, joined into one printable line, or [ocptScheduleEmptyValue]
/// when every part of it is blank.
String ocptScheduleLocationAddressLine(OcptLocation location) {
  final parts = [
    location.name.trim(),
    [location.addressLine1, location.addressLine2].where((line) => line.trim().isNotEmpty).join(", "),
    [location.postalCode, location.city].where((part) => part.trim().isNotEmpty).join(" "),
  ].where((part) => part.trim().isNotEmpty).toList();

  return parts.isEmpty ? ocptScheduleEmptyValue : parts.join(" — ");
}

/// The scene-number half of [shot]'s own `<sceneNumber>/<rank>` display code — what a call sheet's
/// own `SEQ` column and a shooting plan's own sequence grid read a shot's scene off.
String ocptShotSceneNumberOf(OcptShot shot) => shot.code.contains("/") ? shot.code.split("/").first : shot.code;

/// The per-scene rank half of [shot]'s own `<sceneNumber>/<rank>` display code — what a call sheet's
/// own `PLANS` column and a shooting plan's own `Plan`/sequence-grid cells read, since whichever one
/// is naming it already says the scene.
String ocptShotRankOf(OcptShot shot) => shot.code.contains("/") ? shot.code.split("/").last : shot.code;
