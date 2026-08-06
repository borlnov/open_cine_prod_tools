// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// One block of a shooting day's timetable, already resolved out of its `shooting_day_blocks` row
/// (and, for a shot block, out of the `shots` row it points at) by the caller —
/// [ocptComputeShootingDayTimeline] itself knows nothing of drift or of the schedule mode's own
/// enums, on purpose: it is the one place the plan's chaining rule (§5) is implemented, and it must
/// stay reachable from a plain unit test.
class OcptShootingTimelineBlock {
  /// Builds a block to feed to [ocptComputeShootingDayTimeline].
  const OcptShootingTimelineBlock({
    required this.id,
    this.durationMinutes,
    this.fallbackDurationMinutes,
    this.anchorMinute,
    this.slotCallMinute,
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
  /// unconditionally — see rule 3 on [ocptComputeShootingDayTimeline].
  final int? anchorMinute;

  /// The `crewCallMinute` of the slot this block sits in, when it sits in one. Used by rule 5: a
  /// slot's own crew arriving later than the chain's current position pulls the chain forward to
  /// meet them, rather than starting them mid-morning because an earlier slot ran short.
  final int? slotCallMinute;
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
  /// whichever [ocptComputeShootingDayTimeline] fell back to.
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

/// The result of chaining a day's blocks: every block placed, every anchor that could not be
/// honoured, and where the day ends.
class OcptShootingDayTimeline {
  /// Builds a computed timeline.
  const OcptShootingDayTimeline({required this.entries, required this.overruns, required this.dayEndMinute});

  /// Every block placed, in the order it was given.
  final List<OcptShootingTimelineEntry> entries;

  /// Every anchor the chain ran into. Empty when nothing over-ran.
  final List<OcptTimelineOverrun> overruns;

  /// The minute the last block ends at, or null when there was nothing to place at all — see
  /// [ocptComputeShootingDayTimeline]'s doc comment on the empty-day case.
  final int? dayEndMinute;
}

/// Chains [blocks], in the order given, into a computed [OcptShootingDayTimeline] — the rule stated
/// in `docs/plans/schedule-mode.md` §5 and recorded as ADR 0015, implemented exactly once, here.
///
/// 1. The chain starts at [firstCrewCallMinute].
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
///    to the anchor regardless, the rest of the day is computed from that earlier point too, and can
///    therefore finish **earlier** than a naive sum of every duration would suggest: the over-run
///    is a true statement about *this* block's own conflict, not a claim that the whole day grew
///    longer by the same amount.
/// 5. Before either of the above, a block belonging to a slot whose [OcptShootingTimelineBlock
///    .slotCallMinute] is **later** than the chain's current position pulls the chain forward to
///    meet it: a second crew called at 11:00 does not start at 10:20 because the morning ran short.
///    A slot call **earlier** than the chain's position changes nothing — the chain never jumps
///    backward for a slot, only an anchor can pull it back, and only rule 3/4 above says when that
///    over-runs.
///
/// [firstCrewCallMinute] is only read when [blocks] is non-empty — see the empty-list case below —
/// and it is a caller error to pass one that is null while [blocks] is not: nothing schedules a
/// block for a day with no slot to call a first crew from in the first place, so this is not a state
/// the function tries to guess its way through. It throws an [ArgumentError] instead of inventing a
/// start.
///
/// An **empty** [blocks] list — a day with nothing placed on it yet, which is also what "a day with
/// no slot at all" looks like from here, since a slotless day can hold no blocks either — returns no
/// entries, no over-runs and a null [OcptShootingDayTimeline.dayEndMinute]: there is nothing to call
/// "the end" of a day that has not been given any content, which is a different fact from a day
/// whose one block ends the instant it begins ([OcptShootingDayTimeline.dayEndMinute] equal to
/// [firstCrewCallMinute] in that case).
///
/// A block's own resolved duration ([OcptShootingTimelineBlock.durationMinutes], its
/// [OcptShootingTimelineBlock.fallbackDurationMinutes] or [defaultDurationMinutes], whichever is
/// used) of **zero** is accepted — a milestone marker that consumes no time of its own is a
/// legitimate block. A **negative** resolved duration is not: nothing in the schedule mode ever
/// means "run backward in time" by a duration alone, unlike a pinned anchor, which says exactly
/// that in a way the day view can show and the user chose deliberately. A negative duration throws
/// an [ArgumentError] rather than silently reversing the chain.
OcptShootingDayTimeline ocptComputeShootingDayTimeline({
  required List<OcptShootingTimelineBlock> blocks,
  required int? firstCrewCallMinute,
  required int defaultDurationMinutes,
}) {
  if (blocks.isEmpty) {
    return const OcptShootingDayTimeline(entries: [], overruns: [], dayEndMinute: null);
  }
  if (firstCrewCallMinute == null) {
    throw ArgumentError.notNull("firstCrewCallMinute");
  }

  var current = firstCrewCallMinute;
  final entries = <OcptShootingTimelineEntry>[];
  final overruns = <OcptTimelineOverrun>[];

  for (final block in blocks) {
    final slotCallMinute = block.slotCallMinute;
    if (slotCallMinute != null && slotCallMinute > current) {
      current = slotCallMinute; // Rule 5.
    }

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

  return OcptShootingDayTimeline(entries: entries, overruns: overruns, dayEndMinute: current);
}
