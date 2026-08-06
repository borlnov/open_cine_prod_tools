// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The mode's own default duration used across these tests, standing in for whatever value a
/// project's settings hold — the function never reaches for one on its own.
const _defaultDuration = 20;

void main() {
  group("rule 1 — the chain starts at the slot's own start minute", () {
    test("the first block starts exactly at the slot's start", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [OcptShootingTimelineBlock(id: "b1", durationMinutes: 30)],
        slotStartMinute: 480, // 08:00
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.startMinute, 480);
      expect(result.entries.single.endMinute, 510);
      expect(result.endMinute, 510);
    });
  });

  group("rule 2 — each block starts where the previous one ended", () {
    test("chains durations end to end with no gap", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 30),
          OcptShootingTimelineBlock(id: "b2", durationMinutes: 45),
        ],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[0].startMinute, 480);
      expect(result.entries[0].endMinute, 510);
      expect(result.entries[1].startMinute, 510);
      expect(result.entries[1].endMinute, 555);
      expect(result.endMinute, 555);
    });

    test("a shot block with no duration of its own falls back to the shot's estimate", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [OcptShootingTimelineBlock(id: "b1", fallbackDurationMinutes: 50)],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.durationMinutes, 50);
    });

    test("a block's own duration wins over the fallback when both are set", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 15, fallbackDurationMinutes: 50),
        ],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.durationMinutes, 15);
    });

    test("a block with neither its own duration nor a fallback uses the mode's default", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [OcptShootingTimelineBlock(id: "b1")],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.durationMinutes, _defaultDuration);
    });
  });

  group("rule 3 — a pinned block starts exactly at its anchor", () {
    test("the chain waits for an anchor later than its own position (no over-run)", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 30), // 480 -> 510
          OcptShootingTimelineBlock(id: "b2", anchorMinute: 600, durationMinutes: 15),
        ],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[1].startMinute, 600);
      expect(result.entries[1].endMinute, 615);
      expect(result.overruns, isEmpty);
      expect(result.endMinute, 615);
    });

    test("the chain resumes from the anchor's end for the block that follows", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", anchorMinute: 600, durationMinutes: 15),
          OcptShootingTimelineBlock(id: "b2", durationMinutes: 10),
        ],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[1].startMinute, 615);
      expect(result.entries[1].endMinute, 625);
    });

    test("an anchor exactly at the chain's own position is not an over-run", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 30), // 480 -> 510
          OcptShootingTimelineBlock(id: "b2", anchorMinute: 510, durationMinutes: 15),
        ],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.overruns, isEmpty);
      expect(result.entries[1].startMinute, 510);
    });
  });

  group("rule 4 — an anchor the chain has already passed is an over-run", () {
    test("reports the over-run and still pins the block to its exact anchor", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 60), // 480 -> 540
          OcptShootingTimelineBlock(id: "b2", anchorMinute: 510, durationMinutes: 15),
        ],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.overruns, hasLength(1));
      final overrun = result.overruns.single;
      expect(overrun.blockId, "b2");
      expect(overrun.reachedMinute, 540);
      expect(overrun.anchorMinute, 510);

      // Rule 3 is not suspended by rule 4: the block still starts exactly at the anchor, the
      // anchor is never "pushed" later to silently absorb the conflict.
      expect(result.entries[1].startMinute, 510);
      expect(result.entries[1].endMinute, 525);
    });

    test(
      "pulling the chain back to an earlier anchor can make the rest of the slot finish earlier",
      () {
        // Without the anchor on b2, a plain sum of durations would put the slot's end at
        // 480 + 60 + 15 + 10 = 565. With the anchor pulling b2 back to 510, it ends up at
        // 480 + 60 (b1) then reset to 510, +15 (b2) +10 (b3) = 535 -- thirty minutes earlier. The
        // over-run flag on b2 says that block's own anchor could not be honoured without
        // overlapping b1; it is not a claim that the whole slot grew longer.
        final result = ocptComputeSlotTimeline(
          blocks: const [
            OcptShootingTimelineBlock(id: "b1", durationMinutes: 60), // 480 -> 540
            OcptShootingTimelineBlock(id: "b2", anchorMinute: 510, durationMinutes: 15),
            OcptShootingTimelineBlock(id: "b3", durationMinutes: 10),
          ],
          slotStartMinute: 480,
          defaultDurationMinutes: _defaultDuration,
        );

        expect(result.overruns, hasLength(1));
        expect(result.endMinute, 535);
        expect(result.endMinute, lessThan(480 + 60 + 15 + 10));
      },
    );
  });

  group("edge cases", () {
    test("an empty block list has nothing to place and no end", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries, isEmpty);
      expect(result.overruns, isEmpty);
      expect(result.endMinute, isNull);
    });

    test("a zero duration block is a legitimate milestone that consumes no time", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [OcptShootingTimelineBlock(id: "b1", durationMinutes: 0)],
        slotStartMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.startMinute, 480);
      expect(result.entries.single.endMinute, 480);
    });

    test("a negative resolved duration is refused rather than run backward silently", () {
      expect(
        () => ocptComputeSlotTimeline(
          blocks: const [OcptShootingTimelineBlock(id: "b1", durationMinutes: -5)],
          slotStartMinute: 480,
          defaultDurationMinutes: _defaultDuration,
        ),
        throwsArgumentError,
      );
    });

    test("a night slot runs its minutes past 1440 with no wrapping anywhere", () {
      final result = ocptComputeSlotTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 300), // 19:00 -> 24:00
          OcptShootingTimelineBlock(id: "b2", durationMinutes: 180), // -> 03:00
        ],
        slotStartMinute: 1140, // 19:00
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[0].startMinute, 1140);
      expect(result.entries[0].endMinute, 1440);
      expect(result.entries[1].startMinute, 1440);
      expect(result.entries[1].endMinute, 1620); // 03:00 the following morning
      expect(result.endMinute, 1620);
    });
  });

  group("ocptComputeShootingDayTimelines — a day as a set of parallel chains", () {
    test("keys each slot's own timeline by its id", () {
      final result = ocptComputeShootingDayTimelines(
        slots: const [
          OcptShootingTimelineSlot(
            id: "slot-1",
            startMinute: 480,
            blocks: [OcptShootingTimelineBlock(id: "b1", durationMinutes: 30)],
          ),
          OcptShootingTimelineSlot(
            id: "slot-2",
            startMinute: 600,
            blocks: [OcptShootingTimelineBlock(id: "b2", durationMinutes: 45)],
          ),
        ],
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.bySlotId.keys, unorderedEquals(["slot-1", "slot-2"]));
      expect(result.bySlotId["slot-1"]!.entries.single.startMinute, 480);
      expect(result.bySlotId["slot-2"]!.entries.single.startMinute, 600);
    });

    test("flattens every slot's entries and overruns, slot order then chain order", () {
      final result = ocptComputeShootingDayTimelines(
        slots: const [
          OcptShootingTimelineSlot(
            id: "slot-1",
            startMinute: 480,
            blocks: [
              OcptShootingTimelineBlock(id: "b1", durationMinutes: 60), // 480 -> 540
              OcptShootingTimelineBlock(id: "b2", anchorMinute: 510, durationMinutes: 15), // over-run
            ],
          ),
          OcptShootingTimelineSlot(
            id: "slot-2",
            startMinute: 600,
            blocks: [OcptShootingTimelineBlock(id: "b3", durationMinutes: 30)],
          ),
        ],
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.map((entry) => entry.blockId), ["b1", "b2", "b3"]);
      expect(result.overruns, hasLength(1));
      expect(result.overruns.single.blockId, "b2");
    });

    test("dayEndMinute is the maximum over every slot's own end", () {
      final result = ocptComputeShootingDayTimelines(
        slots: const [
          OcptShootingTimelineSlot(
            id: "slot-1",
            startMinute: 480,
            blocks: [OcptShootingTimelineBlock(id: "b1", durationMinutes: 30)], // ends 510
          ),
          OcptShootingTimelineSlot(
            id: "slot-2",
            startMinute: 1140,
            blocks: [OcptShootingTimelineBlock(id: "b2", durationMinutes: 300)], // ends 1440
          ),
        ],
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.dayEndMinute, 1440);
    });

    test("dayEndMinute is null when every slot is empty", () {
      final result = ocptComputeShootingDayTimelines(
        slots: const [
          OcptShootingTimelineSlot(id: "slot-1", startMinute: 480, blocks: []),
          OcptShootingTimelineSlot(id: "slot-2", startMinute: 600, blocks: []),
        ],
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.dayEndMinute, isNull);
      expect(result.entries, isEmpty);
      expect(result.overruns, isEmpty);
    });

    test("two slots whose bands overlap in wall-clock time are computed independently", () {
      // Two units shooting at the same hour: neither slot's own chain is affected by the other's,
      // which is the whole point of a slot owning its chain rather than sharing the day's one.
      final result = ocptComputeShootingDayTimelines(
        slots: const [
          OcptShootingTimelineSlot(
            id: "unit-a",
            startMinute: 480,
            blocks: [OcptShootingTimelineBlock(id: "a1", durationMinutes: 120)], // 480 -> 600
          ),
          OcptShootingTimelineSlot(
            id: "unit-b",
            startMinute: 500,
            blocks: [OcptShootingTimelineBlock(id: "b1", durationMinutes: 120)], // 500 -> 620
          ),
        ],
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.bySlotId["unit-a"]!.entries.single.startMinute, 480);
      expect(result.bySlotId["unit-a"]!.entries.single.endMinute, 600);
      expect(result.bySlotId["unit-b"]!.entries.single.startMinute, 500);
      expect(result.bySlotId["unit-b"]!.entries.single.endMinute, 620);
      expect(result.dayEndMinute, 620);
    });

    test("an empty slot list produces an empty result", () {
      final result = ocptComputeShootingDayTimelines(slots: const [], defaultDurationMinutes: _defaultDuration);

      expect(result.bySlotId, isEmpty);
      expect(result.entries, isEmpty);
      expect(result.overruns, isEmpty);
      expect(result.dayEndMinute, isNull);
    });
  });
}
