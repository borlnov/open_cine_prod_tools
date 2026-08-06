// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_week_grid.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the agenda's own centre area.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 900, height: 700, child: child)),
);

/// Builds a shooting day dated [date] with the few fields these tests read, everything else
/// neutral. [date] is always a Monday of the week `2026-08-03` falls in, so every test day lands
/// inside the one week the grid draws.
OcptShootingDay _buildDay({required String id, required int dayNumber, required DateTime date}) =>
    OcptShootingDay(
      id: id,
      screenplayId: "screenplay-1",
      date: date,
      dayNumber: dayNumber,
      status: OcptShootingDayStatus.planned,
      crewNote: "",
      weatherNote: "",
      notes: "",
    );

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
/// [slotId] and [label] default to the single-slot-day shape most tests exercise.
OcptShootingDayBlock _buildBlock({required String id, String slotId = "slot-1", String label = "Prep"}) =>
    OcptShootingDayBlock(
      id: id,
      shootingDayId: "day-1",
      slotId: slotId,
      kind: OcptShootingBlockKind.preparation,
      shotId: null,
      sceneId: null,
      label: label,
      durationMinutes: null,
      anchorMinute: null,
      notes: "",
    );

/// Builds a shooting slot with the few fields these tests read, everything else neutral — no crew,
/// no cast, since the grid never reads either.
OcptShootingSlot _buildSlot({required String id, String label = ""}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: label,
  locationId: null,
  setId: null,
  startMinute: 480,
  notes: "",
  crew: const [],
  cast: const [],
);

/// The [Positioned] the grid places block [label]'s own band inside — the single ancestor of that
/// kind above its text, whose `left`/`width` say which lane it landed in.
Positioned _blockPositioned(WidgetTester tester, String label) => tester.widget<Positioned>(
  find.ancestor(of: find.text(label), matching: find.byType(Positioned)).first,
);

/// Finds the grid's own sun-shading bands, and only those.
///
/// The grid paints three kinds of [ColoredBox] inside its own subtree — the hour rules, the night
/// bands and the dusk band — so a bare type search would no longer say anything about the sun. The
/// two band tints are the theme's `primary` and `tertiary`; the hour rules are `outlineVariant`,
/// which is what separates them here.
Finder _sunBandFinder(WidgetTester tester) {
  final theme = Theme.of(tester.element(find.byType(OcptScheduleWeekGrid)));
  final bandColors = {
    theme.colorScheme.primary.withValues(alpha: 0.05),
    theme.colorScheme.tertiary.withValues(alpha: 0.08),
  };

  return find.descendant(
    of: find.byType(OcptScheduleWeekGrid),
    matching: find.byWidgetPredicate(
      (widget) => widget is ColoredBox && bandColors.contains(widget.color),
    ),
  );
}

void main() {
  // The Monday of the week `OcptScheduleWeekGrid` draws when anchored on this Wednesday.
  final monday = DateTime(2026, 8, 3);

  testWidgets("a night day's blocks draw past midnight, extending the grid's own hour labels", (
    tester,
  ) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: monday);
    final block = _buildBlock(id: "block-1");
    // 19:00 → 03:00 the following morning: `endMinute` (1620) exceeds a bare 24 h (1440).
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 1140, endMinute: 1620, durationMinutes: 480),
      ],
      overruns: [],
      dayEndMinute: 1620,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleWeekGrid(
          anchorDate: monday,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          firstLocationByDayId: const {},
          slotsByDayId: {"day-1": [_buildSlot(id: "slot-1")]},
          blocksByDayId: {"day-1": [block]},
          shotOf: (_) => null,
          timelineOf: (dayId) => dayId == "day-1" ? timeline : null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Under the default 06:00-24:00 span alone, the gutter would never print an early-morning
    // label: finding one proves the grid's own range stretched to cover the night block.
    expect(find.text("02:00"), findsOneWidget);
    expect(find.text("Prep"), findsOneWidget);
  });

  testWidgets("a day with no sun times draws no shading band", (tester) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: monday);
    final block = _buildBlock(id: "block-1");
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleWeekGrid(
          anchorDate: monday,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          firstLocationByDayId: const {},
          slotsByDayId: {"day-1": [_buildSlot(id: "slot-1")]},
          blocksByDayId: {"day-1": [block]},
          shotOf: (_) => null,
          timelineOf: (dayId) => dayId == "day-1" ? timeline : null,
          // No coordinates pinned on the day's own location: `sunTimesOf` answers null.
          sunTimesOf: (_) => null,
          selectedDayId: null,
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_sunBandFinder(tester), findsNothing);
  });

  testWidgets("a shading band is drawn once sun times are available", (tester) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: monday);
    final block = _buildBlock(id: "block-1");
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 510,
    );
    const sunTimes = OcptSunTimes(
      sunriseMinute: 420,
      sunsetMinute: 1200,
      civilDawnMinute: 390,
      civilDuskMinute: 1230,
      nauticalDawnMinute: null,
      nauticalDuskMinute: null,
      astronomicalDawnMinute: null,
      astronomicalDuskMinute: null,
      utcOffsetUsed: Duration(hours: 2),
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleWeekGrid(
          anchorDate: monday,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          firstLocationByDayId: const {},
          slotsByDayId: {"day-1": [_buildSlot(id: "slot-1")]},
          blocksByDayId: {"day-1": [block]},
          shotOf: (_) => null,
          timelineOf: (dayId) => dayId == "day-1" ? timeline : null,
          sunTimesOf: (dayId) => dayId == "day-1" ? sunTimes : null,
          selectedDayId: null,
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_sunBandFinder(tester), findsWidgets);
  });

  testWidgets("an hour rule is drawn per hour of the grid, in every column", (tester) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: monday);

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleWeekGrid(
          anchorDate: monday,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          firstLocationByDayId: const {},
          slotsByDayId: const {},
          blocksByDayId: const {},
          shotOf: (_) => null,
          timelineOf: (_) => null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing placed anywhere, so the grid keeps its default 06:00-24:00 range: 18 hours, whose
    // first carries no rule (the header's own bottom border already draws that edge), across the
    // week's seven columns.
    final theme = Theme.of(tester.element(find.byType(OcptScheduleWeekGrid)));
    final hourRules = find.descendant(
      of: find.byType(OcptScheduleWeekGrid),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
      ),
    );

    expect(hourRules, findsNWidgets(17 * 7));
  });

  testWidgets("clicking a day's column header opens that day", (tester) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: monday);
    final opened = <String>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleWeekGrid(
          anchorDate: monday,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          firstLocationByDayId: const {},
          slotsByDayId: const {},
          blocksByDayId: const {},
          shotOf: (_) => null,
          timelineOf: (_) => null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          onDayOpenRequested: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("J1"));
    await tester.pump();

    expect(opened, ["day-1"]);
  });

  testWidgets("a one-slot day's block spans the whole column, as it did before lanes existed", (
    tester,
  ) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: monday);
    final block = _buildBlock(id: "block-1");
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleWeekGrid(
          anchorDate: monday,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          firstLocationByDayId: const {},
          slotsByDayId: {"day-1": [_buildSlot(id: "slot-1")]},
          blocksByDayId: {"day-1": [block]},
          shotOf: (_) => null,
          timelineOf: (dayId) => dayId == "day-1" ? timeline : null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A single lane sits flush against the column's own left margin (`2`, the grid's own
    // horizontal band margin, unchanged since before a day could carry more than one lane) — the
    // regression a multi-lane column must not disturb.
    expect(_blockPositioned(tester, "Prep").left, 2);
    // No divider to draw with only one lane, and no tooltip either — nothing to tell apart.
    expect(find.byTooltip("Unnamed slot"), findsNothing);
  });

  testWidgets("a two-slot day draws its blocks in two distinct, non-overlapping lanes", (
    tester,
  ) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: monday);
    final morningBlock = _buildBlock(id: "block-1", label: "BlockA");
    final eveningBlock = _buildBlock(id: "block-2", slotId: "slot-2", label: "BlockB");
    // Both blocks placed over the very same minutes: were they drawn as one shared band, as a
    // pre-lanes day would, they would sit exactly on top of one another. Landing in two lanes is
    // what proves the two slots read apart despite the overlap the timeline itself allows.
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
        OcptShootingTimelineEntry(blockId: "block-2", startMinute: 480, endMinute: 510, durationMinutes: 30),
      ],
      overruns: [],
      dayEndMinute: 510,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleWeekGrid(
          anchorDate: monday,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          firstLocationByDayId: const {},
          slotsByDayId: {
            "day-1": [_buildSlot(id: "slot-1", label: "Morning"), _buildSlot(id: "slot-2", label: "Evening")],
          },
          blocksByDayId: {
            "day-1": [morningBlock, eveningBlock],
          },
          shotOf: (_) => null,
          timelineOf: (dayId) => dayId == "day-1" ? timeline : null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final morningPositioned = _blockPositioned(tester, "BlockA");
    final eveningPositioned = _blockPositioned(tester, "BlockB");
    final morningLeft = morningPositioned.left!;
    final morningRight = morningLeft + morningPositioned.width!;
    final eveningLeft = eveningPositioned.left!;
    final eveningRight = eveningLeft + eveningPositioned.width!;

    // Two lanes, not one band drawn twice: each starts at its own `left`, and neither's own span
    // reaches into the other's.
    expect(morningLeft, isNot(eveningLeft));
    expect(morningRight <= eveningLeft || eveningRight <= morningLeft, isTrue);

    // The lane divider between them, and a tooltip naming each slot — the two cues that say whose
    // lane is whose.
    final theme = Theme.of(tester.element(find.byType(OcptScheduleWeekGrid)));
    final laneDividers = find.descendant(
      of: find.byType(OcptScheduleWeekGrid),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
    expect(laneDividers, findsOneWidget);
    expect(find.byTooltip("Morning"), findsOneWidget);
    expect(find.byTooltip("Evening"), findsOneWidget);
  });

  testWidgets("a second slot's night blocks stretch the grid's own range too", (tester) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: monday);
    final dayBlock = _buildBlock(id: "block-1", label: "Day unit");
    final nightBlock = _buildBlock(id: "block-2", slotId: "slot-2", label: "Night unit");
    // slot-1 runs an ordinary daytime stretch; slot-2 alone runs 19:00 → 03:00 the next morning
    // (`endMinute` 1620, past a bare 24 h). Nothing about slot-1 pushes the range — only slot-2
    // does, which is what this test pins down.
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [
        OcptShootingTimelineEntry(blockId: "block-1", startMinute: 480, endMinute: 510, durationMinutes: 30),
        OcptShootingTimelineEntry(blockId: "block-2", startMinute: 1140, endMinute: 1620, durationMinutes: 480),
      ],
      overruns: [],
      dayEndMinute: 1620,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleWeekGrid(
          anchorDate: monday,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          firstLocationByDayId: const {},
          slotsByDayId: {
            "day-1": [_buildSlot(id: "slot-1", label: "Day"), _buildSlot(id: "slot-2", label: "Night")],
          },
          blocksByDayId: {
            "day-1": [dayBlock, nightBlock],
          },
          shotOf: (_) => null,
          timelineOf: (dayId) => dayId == "day-1" ? timeline : null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("02:00"), findsOneWidget);
    expect(find.text("Day unit"), findsOneWidget);
    expect(find.text("Night unit"), findsOneWidget);
  });
}
