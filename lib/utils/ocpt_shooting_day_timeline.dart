// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// The duration, in minutes, a block resolves to when it has neither its own `durationMinutes` nor
/// (for a shot block) an estimate to fall back to.
///
/// It lives here, beside the chaining rule it feeds, rather than on the schedule mode's own state:
/// `OcptScheduleService` needs the very same figure to work out the hour a slot's dependents were
/// reading when it deletes one, and two constants that had to agree would eventually stop agreeing.
const int ocptDefaultBlockDurationMinutes = 30;

/// One block of a slot's timetable, already resolved out of its `shooting_day_blocks` row (and,
/// for a shot block, out of the `shots` row it points at) by the caller — [ocptComputeSlotTimeline]
/// itself knows nothing of drift or of the schedule mode's own enums, on purpose: it is the one
/// place the chaining rule (ADR 0015, as amended) is implemented, and it must stay reachable from
/// a plain unit test.
class OcptShootingTimelineBlock {
  /// Builds a block to feed to [ocptComputeSlotTimeline].
  const OcptShootingTimelineBlock({
    required this.id,
    this.durationMinutes,
    this.fallbackDurationMinutes,
    this.anchorMinute,
  });

  /// The block's own id (`shooting_day_blocks.id`), echoed back on every [OcptShootingTimelineEntry]
  /// and [OcptTimelineOverrun] that concerns it, so a caller can join the result back onto its rows.
  final String id;

  /// The block's own `durationMinutes`, when the user set one. Takes priority over
  /// [fallbackDurationMinutes] and over the mode's own default.
  final int? durationMinutes;

  /// A shot block's estimate (`shots.estimatedDurationMs`, already converted to minutes by the
  /// caller), used when [durationMinutes] is null. Null for a block that either isn't a shot or is a
  /// shot with no estimate of its own yet.
  final int? fallbackDurationMinutes;

  /// The block's `anchorMinute`, when it is pinned. A pinned block starts **exactly** here,
  /// unconditionally — see rule 3 on [ocptComputeSlotTimeline].
  final int? anchorMinute;
}

/// One block placed on the timeline: where it starts, where it ends, and how long it actually ran
/// for — which is not always [OcptShootingTimelineBlock.durationMinutes], since that may have been
/// null.
class OcptShootingTimelineEntry {
  /// Builds a placed entry.
  const OcptShootingTimelineEntry({
    required this.blockId,
    required this.startMinute,
    required this.endMinute,
    required this.durationMinutes,
  });

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
}

/// A block whose pinned [OcptShootingTimelineBlock.anchorMinute] the chain could not honour without
/// overlapping the block before it: the chain had already reached [reachedMinute] — later than
/// [anchorMinute] — by the time it got to this block.
///
/// The block is **not** silently pushed to [reachedMinute] to avoid the conflict (rule 4): it still
/// starts at exactly [anchorMinute], the way every anchored block does, and this is the record that
/// says the plan no longer fits there. A schedule that quietly absorbed the overlap would read as
/// fine when it isn't; this is what lets the day view show the block in red instead.
class OcptTimelineOverrun {
  /// Builds an over-run record.
  const OcptTimelineOverrun({required this.blockId, required this.reachedMinute, required this.anchorMinute});

  /// The [OcptShootingTimelineBlock.id] whose anchor could not be honoured.
  final String blockId;

  /// The minute the chain had reached, right before this block pinned it back to [anchorMinute].
  final int reachedMinute;

  /// The anchor the block was pinned to, which [reachedMinute] ran past.
  final int anchorMinute;
}

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

/// A set of slots whose anchors read each other round in a circle — A's start reading B's end while
/// B's start reads A's end — so no one of them can be resolved before the others.
///
/// **This is defence, not a path a user can reach**: the anchor picker refuses to offer an entry
/// that would build one (`ocptSlotAnchorWouldCycle`), and `OcptScheduleService` refuses to write
/// one. A pure function that can be handed a database row — a hand-edited file, a payload restored
/// from another build — must not hang on it, so the cycle is reported here and the slots in it are
/// resolved as if [OcptShootingSlotAnchorEdge.start]-anchored at the earliest start the day had
/// already resolved (minute 0 when the whole day cycles).
class OcptTimelineAnchorCycle {
  /// Builds a cycle record.
  const OcptTimelineAnchorCycle({required this.slotIds});

  /// The [OcptShootingTimelineSlot.id]s that read one another round, in the order the resolution
  /// walked them, the first one being the one the walk came back to.
  final List<String> slotIds;
}

/// The result of chaining one slot's blocks: every block placed, every anchor that could not be
/// honoured, and where the slot starts and ends.
class OcptShootingSlotTimeline {
  /// Builds a computed timeline.
  const OcptShootingSlotTimeline({
    required this.entries,
    required this.overruns,
    required this.startMinute,
    required this.endMinute,
  });

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
}

/// Chains [blocks], in the order given, into a computed [OcptShootingSlotTimeline] — the rule
/// recorded as ADR 0015 (as amended), implemented exactly once, here.
///
/// A slot owns its own chain: it starts at [slotStartMinute] and runs only over that slot's own
/// [blocks], independently of every other slot of the day. Two slots of one day may therefore
/// overlap in wall-clock time once their two timelines are read side by side — a second unit
/// shooting at the same hour as the first — and **that is legal, not a conflict this function (or
/// anything built on it) reports**: a production splits a day into slots precisely so two crews can
/// work at once. Whether one *person* ends up convoked in both at the same moment is a different
/// question, answered elsewhere (M3's presence alerts), not here.
///
/// 1. The chain starts at [slotStartMinute].
/// 2. Each block starts where the previous one ended, and lasts [OcptShootingTimelineBlock
///    .durationMinutes] — or, when that is null, [OcptShootingTimelineBlock.fallbackDurationMinutes]
///    — or, when that is null too, [defaultDurationMinutes].
/// 3. A block whose [OcptShootingTimelineBlock.anchorMinute] is set starts **exactly** there,
///    whatever the chain's position was; the chain resumes from its end. This holds unconditionally,
///    whether the anchor sits after the chain's position (the block simply waits, no [
///    OcptTimelineOverrun]), matches it exactly (no [OcptTimelineOverrun] either — see below), or
///    sits before it (rule 4).
/// 4. When the chain's position was **strictly later** than the anchor, the anchor could not be
///    honoured without overlap: an [OcptTimelineOverrun] is added to the result, naming the block,
///    the minute the chain had reached and the anchor. The block still starts at the anchor (rule 3
///    is not an exception to itself) — nothing here "pushes" the anchor later to make it fit, which
///    is the one thing rule 4 exists to refuse doing silently. Because the chain is pulled backward
///    to the anchor regardless, the rest of the slot is computed from that earlier point too, and can
///    therefore finish **earlier** than a naive sum of every duration would suggest: the over-run
///    is a true statement about *this* block's own conflict, not a claim that the whole slot grew
///    longer by the same amount.
///
/// There used to be a rule 5, pulling the chain forward to meet a second slot's own later call —
/// it existed only because one chain served a whole day; now that every slot runs its own, from its
/// own [slotStartMinute], there is nothing left for it to patch, and it is gone.
///
/// [slotStartMinute] always comes back as [OcptShootingSlotTimeline.startMinute], empty [blocks]
/// included: where a slot starts is a fact about the slot, not about what has been placed in it.
///
/// An **empty** [blocks] list — a slot with nothing placed on it yet — returns no entries, no
/// over-runs and a null [OcptShootingSlotTimeline.endMinute]: there is nothing to call "the end" of
/// a slot that has not been given any content, which is a different fact from a slot whose one block
/// ends the instant it begins ([OcptShootingSlotTimeline.endMinute] equal to [slotStartMinute] in
/// that case).
///
/// A block's own resolved duration ([OcptShootingTimelineBlock.durationMinutes], its
/// [OcptShootingTimelineBlock.fallbackDurationMinutes] or [defaultDurationMinutes], whichever is
/// used) of **zero** is accepted — a milestone marker that consumes no time of its own is a
/// legitimate block. A **negative** resolved duration is not: nothing in the schedule mode ever
/// means "run backward in time" by a duration alone, unlike a pinned anchor, which says exactly
/// that in a way the day view can show and the user chose deliberately. A negative duration throws
/// an [ArgumentError] rather than silently reversing the chain.
OcptShootingSlotTimeline ocptComputeSlotTimeline({
  required List<OcptShootingTimelineBlock> blocks,
  required int slotStartMinute,
  required int defaultDurationMinutes,
}) {
  if (blocks.isEmpty) {
    return OcptShootingSlotTimeline(
      entries: const [],
      overruns: const [],
      startMinute: slotStartMinute,
      endMinute: null,
    );
  }

  var current = slotStartMinute;
  final entries = <OcptShootingTimelineEntry>[];
  final overruns = <OcptTimelineOverrun>[];

  for (final block in blocks) {
    final anchorMinute = block.anchorMinute;
    if (anchorMinute != null) {
      if (current > anchorMinute) {
        overruns.add(
          OcptTimelineOverrun(blockId: block.id, reachedMinute: current, anchorMinute: anchorMinute),
        );
      }
      current = anchorMinute; // Rule 3, unconditionally — including right after the line above.
    }

    final duration = block.durationMinutes ?? block.fallbackDurationMinutes ?? defaultDurationMinutes;
    if (duration < 0) {
      throw ArgumentError("Block '${block.id}' resolves to a negative duration ($duration minutes)");
    }

    final start = current;
    final end = start + duration;
    entries.add(
      OcptShootingTimelineEntry(blockId: block.id, startMinute: start, endMinute: end, durationMinutes: duration),
    );
    current = end;
  }

  return OcptShootingSlotTimeline(
    entries: entries,
    overruns: overruns,
    startMinute: slotStartMinute,
    endMinute: current,
  );
}

/// One slot of a day, ready to be chained by [ocptComputeShootingDayTimelines]: its own id, its own
/// anchor and its own blocks, in the order [ocptComputeSlotTimeline] should place them in.
class OcptShootingTimelineSlot {
  /// Builds a slot to feed to [ocptComputeShootingDayTimelines].
  const OcptShootingTimelineSlot({
    required this.id,
    required this.anchorEdge,
    required this.anchorMinute,
    required this.anchorSlotId,
    required this.blocks,
  });

  /// The slot's own id (`shooting_slots.id`).
  final String id;

  /// Which of this slot's two edges is the pinned one.
  final OcptShootingSlotAnchorEdge anchorEdge;

  /// The hour [anchorEdge] is pinned to, typed by hand — null exactly when [anchorSlotId] is set.
  final int? anchorMinute;

  /// The id of the slot of the same day whose **opposite** edge [anchorEdge] reads its hour off —
  /// null exactly when [anchorMinute] is set. A [anchorSlotId] naming no slot of the day given to
  /// [ocptComputeShootingDayTimelines] is read the same way both being null is: see that function's
  /// own doc comment.
  final String? anchorSlotId;

  /// This slot's own blocks, in `sortKey` order — a block belongs to exactly one slot, so no block
  /// of the day appears in more than one [OcptShootingTimelineSlot].
  final List<OcptShootingTimelineBlock> blocks;
}

/// The result of chaining every slot of a day, each independently: a day is a **set of parallel
/// chains**, not one — see [ocptComputeShootingDayTimelines]'s own doc comment.
class OcptShootingDayTimelines {
  /// Builds a computed set of timelines.
  const OcptShootingDayTimelines({
    required this.bySlotId,
    required this.entries,
    required this.overruns,
    required this.fixedEndMisses,
    required this.anchorCycles,
    required this.dayStartMinute,
    required this.dayEndMinute,
  });

  /// Each slot's own [OcptShootingSlotTimeline], keyed by [OcptShootingTimelineSlot.id].
  final Map<String, OcptShootingSlotTimeline> bySlotId;

  /// Every entry of every slot, flattened: the slots in the order they were given to
  /// [ocptComputeShootingDayTimelines], and within a slot, its own chain order. Exists so a reader
  /// that only cares about a block's own placement (the day view, a call sheet) doesn't have to
  /// know which slot produced it.
  final List<OcptShootingTimelineEntry> entries;

  /// Every over-run of every slot, flattened the same way as [entries].
  final List<OcptTimelineOverrun> overruns;

  /// Every [OcptShootingSlotAnchorEdge.end]-anchored slot whose own blocks did not land on its
  /// fixed end. Empty when none did — including on a day with no end-anchored slot at all.
  final List<OcptTimelineFixedEndMiss> fixedEndMisses;

  /// Every circle of anchors found while resolving the day. Empty on any day a user can build —
  /// see [OcptTimelineAnchorCycle]'s own doc comment.
  final List<OcptTimelineAnchorCycle> anchorCycles;

  /// The **minimum** of every slot's own resolved [OcptShootingSlotTimeline.startMinute] — the
  /// earliest moment anybody on this day is due, which is also its earliest arrival (ADR 0018:
  /// nothing pulls somebody in ahead of their own slot's start). Null only when the day carries no
  /// slot at all; a slot with nothing placed in it still has a start.
  final int? dayStartMinute;

  /// The **maximum** of every slot's own [OcptShootingSlotTimeline.endMinute] — a day ends when its
  /// last unit wraps. Null when every slot is empty (see [OcptShootingSlotTimeline.endMinute]'s own
  /// doc comment on what "empty" means for one slot).
  final int? dayEndMinute;
}

/// Resolves each of [slots]' own anchors, then computes each one's [OcptShootingSlotTimeline]
/// independently through [ocptComputeSlotTimeline], joined into one [OcptShootingDayTimelines].
///
/// A day used to be chained as a single sequence; it no longer is. Two slots of a day — two units
/// shooting at different locations, or the same crew split across a morning and an evening booking
/// — each carry their own crew, their own place and their own hours, and serialising them into one
/// chain would draw a sequence that never happened whenever they run at once. Reading them apart
/// like this is what makes that (legal) overlap visible rather than silently flattened away.
///
/// **This is the amendment ADR 0015 takes a second time**, and it is deliberately made *around*
/// [ocptComputeSlotTimeline] rather than inside it: that function still does one thing, chain a
/// slot's blocks forward from a start it is handed, whichever edge that start was worked out from.
///
/// 1. **Resolution order is dependency order, not the order [slots] are given in.** A slot's start
///    may depend on another slot's end, which depends on that slot's whole chain, so a slot is
///    resolved when the slot it reads has been. A day where nothing is linked comes out exactly as
///    it did before this rule existed.
/// 2. **A [OcptShootingSlotAnchorEdge.start]-anchored slot** chains from its resolved hour.
/// 3. **A [OcptShootingSlotAnchorEdge.end]-anchored slot** starts at `resolvedHour − Σ(resolved
///    durations of its blocks)` and then chains forward, unchanged. Adding a block to it therefore
///    pulls its start earlier and leaves its end where it is, which is the whole point of pinning
///    an end.
/// 4. **A pinned block inside an end-anchored slot obeys ADR 0015's rule 3 as always** — it starts
///    exactly at its own anchor — so the slot may well finish somewhere other than its fixed end.
///    That is reported as an [OcptTimelineFixedEndMiss] and **never absorbed**.
/// 5. **A source slot with no block at all has no end** ([OcptShootingSlotTimeline.endMinute] being
///    null then), and its end is read as **equal to its own resolved start** — the same
///    `endMinute ?? startMinute` convention `ocptComputeDayConvocations` applies to a departure.
/// 6. **A cycle** is reported as an [OcptTimelineAnchorCycle] and the slots in it are resolved as
///    if start-anchored at the earliest start already resolved for this day (minute 0 when the
///    whole day cycles). See that class's own doc comment for why a defence exists at all for a
///    state the UI and the service both refuse to write.
///
/// A slot whose [OcptShootingTimelineSlot.anchorSlotId] names **no slot of [slots]** — a source
/// tombstoned out from under it, a payload restored from elsewhere — and a slot whose anchor is
/// somehow neither typed nor linked are both read the same way: there is no hour to be had, so the
/// slot falls back to the same earliest-already-resolved start rule 6 uses. Nothing is invented and
/// nothing hangs.
OcptShootingDayTimelines ocptComputeShootingDayTimelines({
  required List<OcptShootingTimelineSlot> slots,
  required int defaultDurationMinutes,
}) {
  final slotsById = {for (final slot in slots) slot.id: slot};
  final bySlotId = <String, OcptShootingSlotTimeline>{};
  final fixedEndMisses = <OcptTimelineFixedEndMiss>[];
  final anchorCycles = <OcptTimelineAnchorCycle>[];
  final walking = <String>{};
  final path = <String>[];

  /// The earliest start resolved so far, or 0 when nothing has been — what rules 6 and the
  /// dangling-source case fall back to.
  int fallbackStartMinute() {
    int? earliest;
    for (final timeline in bySlotId.values) {
      if (earliest == null || timeline.startMinute < earliest) {
        earliest = timeline.startMinute;
      }
    }
    return earliest ?? 0;
  }

  /// Chains [slot] from [startMinute], records it, and reports the fixed end it missed (if any).
  OcptShootingSlotTimeline place(
    OcptShootingTimelineSlot slot, {
    required int startMinute,
    required int? fixedEndMinute,
  }) {
    final timeline = ocptComputeSlotTimeline(
      blocks: slot.blocks,
      slotStartMinute: startMinute,
      defaultDurationMinutes: defaultDurationMinutes,
    );

    final endMinute = timeline.endMinute;
    if (fixedEndMinute != null && endMinute != null && endMinute != fixedEndMinute) {
      fixedEndMisses.add(
        OcptTimelineFixedEndMiss(
          slotId: slot.id,
          fixedEndMinute: fixedEndMinute,
          actualEndMinute: endMinute,
        ),
      );
    }

    bySlotId[slot.id] = timeline;
    return timeline;
  }

  /// [slot]'s own start, given the hour its anchored edge sits at: an end-anchored slot walks back
  /// over the durations it holds (rule 3), a start-anchored one is already there (rule 2).
  int startMinuteFor(OcptShootingTimelineSlot slot, int anchoredHour) {
    if (slot.anchorEdge == OcptShootingSlotAnchorEdge.start) {
      return anchoredHour;
    }

    var total = 0;
    for (final block in slot.blocks) {
      total +=
          block.durationMinutes ?? block.fallbackDurationMinutes ?? defaultDurationMinutes;
    }

    return anchoredHour - total;
  }

  /// Resolves [slot]'s own timeline, resolving whatever it reads first.
  OcptShootingSlotTimeline resolve(OcptShootingTimelineSlot slot) {
    final done = bySlotId[slot.id];
    if (done != null) {
      return done;
    }

    if (walking.contains(slot.id)) {
      // Rule 6: the walk came back to a slot it is still resolving. Report the circle it closed,
      // then break it by pinning this slot's start to the fallback hour — the frames still on the
      // stack below check `bySlotId` again before placing anything of their own.
      anchorCycles.add(
        OcptTimelineAnchorCycle(slotIds: path.sublist(path.indexOf(slot.id))),
      );
      return place(slot, startMinute: fallbackStartMinute(), fixedEndMinute: null);
    }

    walking.add(slot.id);
    path.add(slot.id);

    final anchorMinute = slot.anchorMinute;
    final source = slot.anchorSlotId == null ? null : slotsById[slot.anchorSlotId];
    int? anchoredHour;
    if (anchorMinute != null) {
      anchoredHour = anchorMinute;
    } else if (source != null) {
      final sourceTimeline = resolve(source);
      // The linked edge is always the opposite one: my start reads its end (rule 5 giving an empty
      // slot's end as its own start), my end reads its start.
      anchoredHour = slot.anchorEdge == OcptShootingSlotAnchorEdge.start
          ? (sourceTimeline.endMinute ?? sourceTimeline.startMinute)
          : sourceTimeline.startMinute;
    }

    walking.remove(slot.id);
    path.removeLast();

    final placedMeanwhile = bySlotId[slot.id];
    if (placedMeanwhile != null) {
      return placedMeanwhile;
    }

    if (anchoredHour == null) {
      // Neither a typed hour nor a source that exists: there is nothing to read, so the slot is
      // placed the way rule 6 places a slot caught in a circle, and for the same reason.
      return place(slot, startMinute: fallbackStartMinute(), fixedEndMinute: null);
    }

    return place(
      slot,
      startMinute: startMinuteFor(slot, anchoredHour),
      fixedEndMinute: slot.anchorEdge == OcptShootingSlotAnchorEdge.end ? anchoredHour : null,
    );
  }

  for (final slot in slots) {
    resolve(slot);
  }

  // Flattened in the order the slots were **given**, never in the order they happened to be
  // resolved in: a caller reading `entries` is reading the day's own list, and it must not shuffle
  // itself the moment somebody links two slots together.
  final entries = <OcptShootingTimelineEntry>[];
  final overruns = <OcptTimelineOverrun>[];
  int? dayStartMinute;
  int? dayEndMinute;

  for (final slot in slots) {
    final timeline = bySlotId[slot.id]!;
    entries.addAll(timeline.entries);
    overruns.addAll(timeline.overruns);

    if (dayStartMinute == null || timeline.startMinute < dayStartMinute) {
      dayStartMinute = timeline.startMinute;
    }

    final slotEndMinute = timeline.endMinute;
    if (slotEndMinute != null && (dayEndMinute == null || slotEndMinute > dayEndMinute)) {
      dayEndMinute = slotEndMinute;
    }
  }

  return OcptShootingDayTimelines(
    bySlotId: bySlotId,
    entries: entries,
    overruns: overruns,
    fixedEndMisses: fixedEndMisses,
    anchorCycles: anchorCycles,
    dayStartMinute: dayStartMinute,
    dayEndMinute: dayEndMinute,
  );
}

/// Whether pinning [slotId]'s own anchored edge to [sourceSlotId]'s opposite one would close a
/// circle, given [anchorSourceBySlotId] — every slot of the day mapped to the id its own anchor
/// currently reads, or null when its anchor is a typed hour.
///
/// This is the predicate the anchor menu greys an entry out with and `OcptScheduleService` refuses
/// a write on, so that [ocptComputeShootingDayTimelines]'s own rule 6 stays what it says it is: a
/// defence against a file, not a state the app can put a user in. A slot reading **itself** counts
/// as a circle, being the shortest one there is.
///
/// The walk is bounded by the number of slots given, so a map that *already* holds a circle —
/// nothing this app writes, everything a hand-edited file might — answers rather than spinning.
bool ocptSlotAnchorWouldCycle({
  required Map<String, String?> anchorSourceBySlotId,
  required String slotId,
  required String sourceSlotId,
}) {
  var current = sourceSlotId;
  for (var step = 0; step <= anchorSourceBySlotId.length; step++) {
    if (current == slotId) {
      return true;
    }

    final next = anchorSourceBySlotId[current];
    if (next == null) {
      return false;
    }
    current = next;
  }

  return true;
}
