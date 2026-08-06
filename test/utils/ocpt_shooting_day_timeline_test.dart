// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The mode's own default duration used across these tests, standing in for whatever value a
/// project's settings hold — the function never reaches for one on its own.
const _defaultDuration = 20;

void main() {
  group("rule 1 — the chain starts at the first crew call", () {
    test("the first block starts exactly at the crew call", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [OcptShootingTimelineBlock(id: "b1", durationMinutes: 30)],
        firstCrewCallMinute: 480, // 08:00
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.startMinute, 480);
      expect(result.entries.single.endMinute, 510);
      expect(result.dayEndMinute, 510);
    });
  });

  group("rule 2 — each block starts where the previous one ended", () {
    test("chains durations end to end with no gap", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 30),
          OcptShootingTimelineBlock(id: "b2", durationMinutes: 45),
        ],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[0].startMinute, 480);
      expect(result.entries[0].endMinute, 510);
      expect(result.entries[1].startMinute, 510);
      expect(result.entries[1].endMinute, 555);
      expect(result.dayEndMinute, 555);
    });

    test("a shot block with no duration of its own falls back to the shot's estimate", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [OcptShootingTimelineBlock(id: "b1", fallbackDurationMinutes: 50)],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.durationMinutes, 50);
    });

    test("a block's own duration wins over the fallback when both are set", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 15, fallbackDurationMinutes: 50),
        ],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.durationMinutes, 15);
    });

    test("a block with neither its own duration nor a fallback uses the mode's default", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [OcptShootingTimelineBlock(id: "b1")],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.durationMinutes, _defaultDuration);
    });
  });

  group("rule 3 — a pinned block starts exactly at its anchor", () {
    test("the chain waits for an anchor later than its own position (no over-run)", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 30), // 480 -> 510
          OcptShootingTimelineBlock(id: "b2", anchorMinute: 600, durationMinutes: 15),
        ],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[1].startMinute, 600);
      expect(result.entries[1].endMinute, 615);
      expect(result.overruns, isEmpty);
      expect(result.dayEndMinute, 615);
    });

    test("the chain resumes from the anchor's end for the block that follows", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", anchorMinute: 600, durationMinutes: 15),
          OcptShootingTimelineBlock(id: "b2", durationMinutes: 10),
        ],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[1].startMinute, 615);
      expect(result.entries[1].endMinute, 625);
    });

    test("an anchor exactly at the chain's own position is not an over-run", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 30), // 480 -> 510
          OcptShootingTimelineBlock(id: "b2", anchorMinute: 510, durationMinutes: 15),
        ],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.overruns, isEmpty);
      expect(result.entries[1].startMinute, 510);
    });
  });

  group("rule 4 — an anchor the chain has already passed is an over-run", () {
    test("reports the over-run and still pins the block to its exact anchor", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 60), // 480 -> 540
          OcptShootingTimelineBlock(id: "b2", anchorMinute: 510, durationMinutes: 15),
        ],
        firstCrewCallMinute: 480,
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
      "pulling the chain back to an earlier anchor can make the rest of the day finish earlier",
      () {
        // Without the anchor on b2, a plain sum of durations would put the day's end at
        // 480 + 60 + 15 + 10 = 565. With the anchor pulling b2 back to 510, it ends up at
        // 480 + 60 (b1) then reset to 510, +15 (b2) +10 (b3) = 535 -- thirty minutes earlier. The
        // over-run flag on b2 says that block's own anchor could not be honoured without
        // overlapping b1; it is not a claim that the whole day grew longer.
        final result = ocptComputeShootingDayTimeline(
          blocks: const [
            OcptShootingTimelineBlock(id: "b1", durationMinutes: 60), // 480 -> 540
            OcptShootingTimelineBlock(id: "b2", anchorMinute: 510, durationMinutes: 15),
            OcptShootingTimelineBlock(id: "b3", durationMinutes: 10),
          ],
          firstCrewCallMinute: 480,
          defaultDurationMinutes: _defaultDuration,
        );

        expect(result.overruns, hasLength(1));
        expect(result.dayEndMinute, 535);
        expect(result.dayEndMinute, lessThan(480 + 60 + 15 + 10));
      },
    );
  });

  group("rule 5 — a later slot call pulls the chain forward", () {
    test("a second crew called later than the chain's position jumps the chain to meet them", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 20), // 480 -> 500
          OcptShootingTimelineBlock(id: "b2", slotCallMinute: 660, durationMinutes: 30),
        ],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[1].startMinute, 660);
      expect(result.entries[1].endMinute, 690);
    });

    test("a slot call earlier than the chain's position never pulls it backward", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 60), // 480 -> 540
          OcptShootingTimelineBlock(id: "b2", slotCallMinute: 500, durationMinutes: 10),
        ],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[1].startMinute, 540);
    });
  });

  group("edge cases", () {
    test("an empty block list has nothing to place and no day end", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries, isEmpty);
      expect(result.overruns, isEmpty);
      expect(result.dayEndMinute, isNull);
    });

    test("a day with no slot at all has no blocks and therefore no day end either", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [],
        firstCrewCallMinute: null,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.dayEndMinute, isNull);
    });

    test("blocks with no first crew call to start the chain from is a caller error", () {
      expect(
        () => ocptComputeShootingDayTimeline(
          blocks: const [OcptShootingTimelineBlock(id: "b1", durationMinutes: 10)],
          firstCrewCallMinute: null,
          defaultDurationMinutes: _defaultDuration,
        ),
        throwsArgumentError,
      );
    });

    test("a zero duration block is a legitimate milestone that consumes no time", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [OcptShootingTimelineBlock(id: "b1", durationMinutes: 0)],
        firstCrewCallMinute: 480,
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries.single.startMinute, 480);
      expect(result.entries.single.endMinute, 480);
    });

    test("a negative resolved duration is refused rather than run backward silently", () {
      expect(
        () => ocptComputeShootingDayTimeline(
          blocks: const [OcptShootingTimelineBlock(id: "b1", durationMinutes: -5)],
          firstCrewCallMinute: 480,
          defaultDurationMinutes: _defaultDuration,
        ),
        throwsArgumentError,
      );
    });

    test("a night day runs its minutes past 1440 with no wrapping anywhere", () {
      final result = ocptComputeShootingDayTimeline(
        blocks: const [
          OcptShootingTimelineBlock(id: "b1", durationMinutes: 300), // 19:00 -> 24:00
          OcptShootingTimelineBlock(id: "b2", durationMinutes: 180), // -> 03:00
        ],
        firstCrewCallMinute: 1140, // 19:00
        defaultDurationMinutes: _defaultDuration,
      );

      expect(result.entries[0].startMinute, 1140);
      expect(result.entries[0].endMinute, 1440);
      expect(result.entries[1].startMinute, 1440);
      expect(result.entries[1].endMinute, 1620); // 03:00 the following morning
      expect(result.dayEndMinute, 1620);
    });
  });
}
