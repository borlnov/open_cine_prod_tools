// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// Builds an [OcptShootingSlotTimeline] test double directly, without going through
/// [ocptComputeSlotTimeline]: these tests are about [OcptShootingDayAgendaGrid.of]'s own reading of
/// an already-resolved timeline, not about the chaining rule itself (covered by
/// `ocpt_shooting_day_timeline_test.dart`).
OcptShootingSlotTimeline _timeline({
  required int startMinute,
  int? endMinute,
  List<OcptShootingTimelineEntry> entries = const [],
}) => OcptShootingSlotTimeline(entries: entries, overruns: const [], startMinute: startMinute, endMinute: endMinute);

/// A single-entry timeline: one block running `[startMinute, startMinute + duration)`.
OcptShootingSlotTimeline _oneBlockTimeline({
  required String blockId,
  required int startMinute,
  required int duration,
}) => _timeline(
  startMinute: startMinute,
  endMinute: startMinute + duration,
  entries: [
    OcptShootingTimelineEntry(
      blockId: blockId,
      startMinute: startMinute,
      endMinute: startMinute + duration,
      durationMinutes: duration,
    ),
  ],
);

void main() {
  group("bounds", () {
    test("a day with no slot is empty and never crashes", () {
      final grid = OcptShootingDayAgendaGrid.of(columns: const [], events: const []);

      expect(grid.isEmpty, isTrue);
      expect(grid.rowCount, 0);
      expect(grid.columns, isEmpty);
      expect(grid.tiles, isEmpty);
      expect(grid.events, isEmpty);
    });

    test("a slot with no block at all still contributes its own start as a bound", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _timeline(startMinute: 483), // 08:03, not on a ten-minute mark
            captionByBlockId: const {},
          ),
        ],
        events: const [],
      );

      expect(grid.isEmpty, isFalse);
      // Snapped down to 08:00, then a whole extra row is owed since the band is otherwise empty.
      expect(grid.startMinute, 480);
      expect(grid.endMinute, 490);
      expect(grid.rowCount, 1);
      expect(grid.tiles, isEmpty);
    });

    test("the earliest start and the latest end are snapped outward onto ten minutes", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            // 09:05 -> 12:13, neither end on a ten-minute mark.
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 545, duration: 188),
            captionByBlockId: const {"b1": "Shot 1"},
          ),
        ],
        events: const [],
      );

      expect(grid.startMinute, 540); // floored to 09:00
      expect(grid.endMinute, 740); // ceiled to 12:20
      expect(grid.rowCount, 20);
    });
  });

  group("a block that does not fall on tens", () {
    test("a 12-minute block still spans the rows it touches, with its exact times on the tile", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 12),
            captionByBlockId: const {"b1": "Shot 1"},
          ),
        ],
        events: const [],
      );

      final tile = grid.tiles.single;
      expect(tile.startMinute, 540);
      expect(tile.endMinute, 552);
      expect(tile.startRow, 0);
      // 552 falls inside the second row (540-550, 550-560): the tile must cover both.
      expect(tile.rowSpan, 2);
    });

    test("a zero-duration milestone still occupies exactly one row", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 0),
            captionByBlockId: const {"b1": "Pause"},
          ),
        ],
        events: const [],
      );

      expect(grid.tiles.single.rowSpan, 1);
    });
  });

  group("two slots whose chains overlap", () {
    test("they land in their own separate columns with no interaction", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "a1", startMinute: 540, duration: 60),
            captionByBlockId: const {"a1": "Shot A"},
          ),
          OcptShootingDayAgendaColumnInput(
            slotId: "s2",
            label: "Unit B",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 60),
            captionByBlockId: const {"b1": "Shot B"},
          ),
        ],
        events: const [],
      );

      expect(grid.columns.map((c) => c.slotId), ["s1", "s2"]);
      final tileA = grid.tiles.firstWhere((t) => t.blockId == "a1");
      final tileB = grid.tiles.firstWhere((t) => t.blockId == "b1");
      expect(tileA.slotId, "s1");
      expect(tileB.slotId, "s2");
      expect(tileA.startRow, tileB.startRow);
      expect(tileA.rowSpan, tileB.rowSpan);
    });
  });

  group("a night crossing midnight", () {
    test("minutes past 1440 are never taken modulo anything", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Night unit",
            // 19:00 -> 03:00 the next day, stored as 1140 -> 1620.
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 1140, duration: 480),
            captionByBlockId: const {"b1": "Night shoot"},
          ),
        ],
        events: const [],
      );

      expect(grid.startMinute, 1140);
      expect(grid.endMinute, 1620);
      final tile = grid.tiles.single;
      expect(tile.startMinute, 1140);
      expect(tile.endMinute, 1620);
      expect(tile.startRow, 0);
      expect(tile.rowSpan, 48); // 480 minutes / 10-minute rows
    });
  });

  group("an event pinned outside the blocks' own band", () {
    test("the grid's own bounds do not stretch to keep it visible on paper", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 60), // 09:00-10:00
            captionByBlockId: const {"b1": "Shot 1"},
          ),
        ],
        events: const [
          OcptShootingDayAgendaEventInput(id: "e1", minute: 1025, label: "Village fireworks"), // 17:05
        ],
      );

      // Bounds come from the blocks alone now — no thirty blank rows to reach a marker.
      expect(grid.startMinute, 540);
      expect(grid.endMinute, 600);
      expect(grid.rowCount, 6);
      final marker = grid.events.single;
      expect(marker.minute, 1025);
      expect(marker.placement, OcptShootingDayAgendaEventPlacement.afterGrid);
      expect(marker.row, isNull);
    });

    test("an event before every slot's own start is a leading marker, not a new bound", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 60),
            captionByBlockId: const {"b1": "Shot 1"},
          ),
        ],
        events: const [OcptShootingDayAgendaEventInput(id: "e1", minute: 480, label: "Early gate opening")],
      );

      expect(grid.startMinute, 540); // untouched by the event
      final marker = grid.events.single;
      expect(marker.placement, OcptShootingDayAgendaEventPlacement.beforeGrid);
      expect(marker.row, isNull);
    });

    test("an event exactly on the grid's own exclusive end boundary is a trailing marker", () {
      // The block's own band runs 540-600, already an exact multiple of ten at both ends, so
      // nothing is rounded up. The event, pinned exactly at 600, has nothing to sit on: a row
      // covers [start, start + stepMinutes), and 600 is the end of the last row rather than a
      // minute any row contains.
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 60),
            captionByBlockId: const {"b1": "Shot 1"},
          ),
        ],
        events: const [OcptShootingDayAgendaEventInput(id: "e1", minute: 600, label: "Wrap party")],
      );

      expect(grid.endMinute, 600);
      final marker = grid.events.single;
      expect(marker.placement, OcptShootingDayAgendaEventPlacement.afterGrid);
      expect(marker.row, isNull);
    });

    test("an event on the grid's own last row's own start is still in it", () {
      // The mirror of the previous test: 590 is exactly [endMinute - stepMinutes], the *start* of
      // the last row, so it belongs inside the grid rather than trailing it.
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 60),
            captionByBlockId: const {"b1": "Shot 1"},
          ),
        ],
        events: const [OcptShootingDayAgendaEventInput(id: "e1", minute: 590, label: "Last call")],
      );

      expect(grid.endMinute, 600);
      final marker = grid.events.single;
      expect(marker.placement, OcptShootingDayAgendaEventPlacement.inGrid);
      expect(marker.row, 5);
    });

    test("an event inside the band keeps a row of its own", () {
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 60), // 09:00-10:00
            captionByBlockId: const {"b1": "Shot 1"},
          ),
        ],
        events: const [OcptShootingDayAgendaEventInput(id: "e1", minute: 565, label: "Camera check")],
      );

      final marker = grid.events.single;
      expect(marker.placement, OcptShootingDayAgendaEventPlacement.inGrid);
      expect(marker.row, 2); // [560, 570)
    });
  });

  group("bounds below the day's own midnight", () {
    test("an end-anchored slot walking back past midnight resolves to a negative start", () {
      // Anchored to end at 02:00 (minute 120) with four hours (240 minutes) of blocks: the slot's
      // own resolved start is minute -120, before the day's own midnight (ADR 0015, amended a
      // second time) — `ocptComputeShootingDayTimelines`'s own `startMinuteFor` clamps nothing.
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Night unit",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: -120, duration: 240),
            captionByBlockId: const {"b1": "Night shoot"},
          ),
        ],
        events: const [],
      );

      expect(grid.startMinute, -120); // already an exact multiple of ten
      expect(grid.endMinute, 120);
      expect(grid.rowCount, 24);
      final tile = grid.tiles.single;
      expect(tile.startRow, 0);
      expect(tile.rowSpan, 24);
    });

    test("a block starting at a negative minute that is not a multiple of ten floors correctly", () {
      // -125 must floor to -130, not the -120 a truncating `~/` would give (Dart's `~/` truncates
      // toward zero, which rounds a negative value *up*, one step too late).
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Night unit",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: -125, duration: 12),
            captionByBlockId: const {"b1": "Night shoot"},
          ),
        ],
        events: const [],
      );

      expect(grid.startMinute, -130);
      expect(grid.endMinute, -110); // -113 ceiled up to the next ten
      expect(grid.rowCount, 2);
      final tile = grid.tiles.single;
      expect(tile.startMinute, -125);
      expect(tile.endMinute, -113);
      expect(tile.startRow, 0); // -125 falls inside the very first row, [-130, -120)
      expect(tile.rowSpan, 2); // -113 spills into the second row, [-120, -110)
    });

    test("an event at a negative minute before a band starting at 07:00 is a leading marker", () {
      // The rounding fix must keep working here too: even though this event no longer touches the
      // bounds, `_eventMarkerOf`'s own `event.minute < snappedStart` comparison must still read
      // -15 as before a band starting at 420 (07:00), not accidentally fold it in some other way.
      final grid = OcptShootingDayAgendaGrid.of(
        columns: [
          OcptShootingDayAgendaColumnInput(
            slotId: "s1",
            label: "Unit A",
            timeline: _oneBlockTimeline(blockId: "b1", startMinute: 420, duration: 60),
            captionByBlockId: const {"b1": "Shot 1"},
          ),
        ],
        events: const [OcptShootingDayAgendaEventInput(id: "e1", minute: -15, label: "Early crew arrival")],
      );

      expect(grid.startMinute, 420); // untouched by the event
      final marker = grid.events.single;
      expect(marker.minute, -15);
      expect(marker.placement, OcptShootingDayAgendaEventPlacement.beforeGrid);
      expect(marker.row, isNull);
    });
  });

  test("a block whose caller supplies no caption is skipped rather than drawn blank", () {
    final grid = OcptShootingDayAgendaGrid.of(
      columns: [
        OcptShootingDayAgendaColumnInput(
          slotId: "s1",
          label: "Unit A",
          timeline: _oneBlockTimeline(blockId: "b1", startMinute: 540, duration: 60),
          captionByBlockId: const {},
        ),
      ],
      events: const [],
    );

    expect(grid.tiles, isEmpty);
  });
}
