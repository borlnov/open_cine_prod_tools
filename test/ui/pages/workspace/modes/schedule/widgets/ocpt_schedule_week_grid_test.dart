// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
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
OcptShootingDayBlock _buildBlock({required String id}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: "slot-1",
  kind: OcptShootingBlockKind.preparation,
  shotId: null,
  sceneId: null,
  label: "Prep",
  durationMinutes: null,
  anchorMinute: null,
  notes: "",
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
}
