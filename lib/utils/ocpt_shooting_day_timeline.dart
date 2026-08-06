// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One block of a slot's timetable, already resolved out of its `shooting_day_blocks` row (and,
/// for a shot block, out of the `shots` row it points at) by the caller — [ocptComputeSlotTimeline]
/// itself knows nothing of drift or of the schedule mode's own enums, on purpose: it is the one
/// place the plan's chaining rule (§2.1 of `docs/plans/schedule-slots-and-computed-convocations.md`)
/// is implemented, and it must stay reachable from a plain unit test.
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

/// The result of chaining one slot's blocks: every block placed, every anchor that could not be
/// honoured, and where the slot ends.
class OcptShootingSlotTimeline {
  /// Builds a computed timeline.
  const OcptShootingSlotTimeline({required this.entries, required this.overruns, required this.endMinute});

  /// Every block placed, in the order it was given.
  final List<OcptShootingTimelineEntry> entries;

  /// Every anchor the chain ran into. Empty when nothing over-ran.
  final List<OcptTimelineOverrun> overruns;

  /// The minute the last block ends at, or null when there was nothing to place at all — see
  /// [ocptComputeSlotTimeline]'s doc comment on the empty-slot case.
  final int? endMinute;
}

/// Chains [blocks], in the order given, into a computed [OcptShootingSlotTimeline] — the rule
/// stated in `docs/plans/schedule-slots-and-computed-convocations.md` §2.1 and recorded as ADR
/// 0015 (amended by that plan), implemented exactly once, here.
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
/// [slotStartMinute] is only read when [blocks] is non-empty — see the empty-list case below.
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
    return const OcptShootingSlotTimeline(entries: [], overruns: [], endMinute: null);
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

  return OcptShootingSlotTimeline(entries: entries, overruns: overruns, endMinute: current);
}

/// One slot of a day, ready to be chained by [ocptComputeShootingDayTimelines]: its own id, its own
/// start and its own blocks, in the order [ocptComputeSlotTimeline] should place them in.
class OcptShootingTimelineSlot {
  /// Builds a slot to feed to [ocptComputeShootingDayTimelines].
  const OcptShootingTimelineSlot({required this.id, required this.startMinute, required this.blocks});

  /// The slot's own id (`shooting_slots.id`).
  final String id;

  /// The slot's own `startMinute` — the one clock time still typed by hand (§2.4 of
  /// `docs/plans/schedule-slots-and-computed-convocations.md`), and the point [ocptComputeSlotTimeline]
  /// starts this slot's chain at.
  final int startMinute;

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

  /// The **maximum** of every slot's own [OcptShootingSlotTimeline.endMinute] — a day ends when its
  /// last unit wraps. Null when every slot is empty (see [OcptShootingSlotTimeline.endMinute]'s own
  /// doc comment on what "empty" means for one slot).
  final int? dayEndMinute;
}

/// Computes [slots]' own [OcptShootingSlotTimeline] independently — a thin loop over
/// [ocptComputeSlotTimeline], one call per slot, joined into one [OcptShootingDayTimelines].
///
/// A day used to be chained as a single sequence; it no longer is. Two slots of a day — two units
/// shooting at different locations, or the same crew split across a morning and an evening booking
/// — each carry their own crew, their own place and their own hours, and serialising them into one
/// chain would draw a sequence that never happened whenever they run at once. Reading them apart
/// like this is what makes that (legal) overlap visible rather than silently flattened away.
OcptShootingDayTimelines ocptComputeShootingDayTimelines({
  required List<OcptShootingTimelineSlot> slots,
  required int defaultDurationMinutes,
}) {
  final bySlotId = <String, OcptShootingSlotTimeline>{};
  final entries = <OcptShootingTimelineEntry>[];
  final overruns = <OcptTimelineOverrun>[];
  int? dayEndMinute;

  for (final slot in slots) {
    final timeline = ocptComputeSlotTimeline(
      blocks: slot.blocks,
      slotStartMinute: slot.startMinute,
      defaultDurationMinutes: defaultDurationMinutes,
    );

    bySlotId[slot.id] = timeline;
    entries.addAll(timeline.entries);
    overruns.addAll(timeline.overruns);

    final slotEndMinute = timeline.endMinute;
    if (slotEndMinute != null && (dayEndMinute == null || slotEndMinute > dayEndMinute)) {
      dayEndMinute = slotEndMinute;
    }
  }

  return OcptShootingDayTimelines(
    bySlotId: bySlotId,
    entries: entries,
    overruns: overruns,
    dayEndMinute: dayEndMinute,
  );
}
