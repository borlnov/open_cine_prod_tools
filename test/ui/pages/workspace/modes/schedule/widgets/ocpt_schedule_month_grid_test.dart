// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_first_weekday.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_month_grid.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the agenda's own centre area — [height] defaults to the roomy height every
/// other test in this file renders at, and is only ever overridden to a short one deliberately too
/// small for the six week rows' own fixed `minHeight` (`_OcptScheduleMonthCell`).
Widget _wrapInApp(Widget child, {double height = 700}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 900, height: height, child: child)),
);

/// Builds a shooting day dated [date] with the few fields these tests read, everything else
/// neutral. [date] always falls in August 2026, the one month the grid draws below.
OcptShootingDay _buildDay({required String id, required int dayNumber, required DateTime date}) =>
    OcptShootingDay(
      id: id,
      date: date,
      dayNumber: dayNumber,
      status: OcptShootingDayStatus.planned,
      crewNote: "",
      weatherNote: "",
      notes: "",
    );

/// Builds a shooting slot with the few fields these tests read, everything else neutral. Its own
/// hour is deliberately absent: a cell reads its call off the day's computed timelines, never off a
/// slot's stored anchor (ADR 0015, amended a second time), and these slots are only here for the
/// multi-slot badge that counts them.
OcptShootingSlot _buildSlot({required String id}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: const [],
  guests: const [],
);

void main() {
  // Any date inside August 2026 — the tests below only ever place a single day, on the 3rd.
  final anchorDate = DateTime(2026, 8, 3);

  testWidgets("a month cell reads the day's own earliest resolved start, not its first slot's", (
    tester,
  ) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: anchorDate);
    // slot-1 is given first (`sortKey` order) but starts later than slot-2: the day's own call is
    // still 08:00, the earliest of the two, not 10:00 — which is exactly what `dayStartMinute` is,
    // computed over the resolved starts rather than read off the first slot in the list.
    final slots = [_buildSlot(id: "slot-1"), _buildSlot(id: "slot-2")];
    const timeline = OcptShootingDayTimelines(
      bySlotId: {},
      entries: [],
      overruns: [],
      fixedEndMisses: [],
      anchorCycles: [],
      dayStartMinute: 480,
      dayEndMinute: 1080,
    );

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleMonthGrid(
          anchorDate: anchorDate,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          slotsByDayId: {"day-1": slots},
          firstLocationByDayId: const {},
          dayTintOf: (_) => Colors.transparent,
          timelineOf: (dayId) => dayId == "day-1" ? timeline : null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          alertsOfDay: (dayId) => const [],
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("08:00 – 18:00"), findsOneWidget);
    expect(find.text("10:00 – 18:00"), findsNothing);
  });

  testWidgets("a single-slot day's cell carries no multi-slot badge", (tester) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: anchorDate);
    final slots = [_buildSlot(id: "slot-1")];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleMonthGrid(
          anchorDate: anchorDate,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          slotsByDayId: {"day-1": slots},
          firstLocationByDayId: const {},
          dayTintOf: (_) => Colors.transparent,
          timelineOf: (_) => null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          alertsOfDay: (dayId) => const [],
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("2×"), findsNothing);
  });

  testWidgets("a multi-slot day's cell carries a badge naming its own slot count", (tester) async {
    final day = _buildDay(id: "day-1", dayNumber: 1, date: anchorDate);
    final slots = [
      _buildSlot(id: "slot-1"),
      _buildSlot(id: "slot-2"),
    ];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleMonthGrid(
          anchorDate: anchorDate,
          firstWeekday: OcptFirstWeekday.monday,
          days: [day],
          slotsByDayId: {"day-1": slots},
          firstLocationByDayId: const {},
          dayTintOf: (_) => Colors.transparent,
          timelineOf: (_) => null,
          sunTimesOf: (_) => null,
          selectedDayId: null,
          alertsOfDay: (dayId) => const [],
          onDayOpenRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("2×"), findsOneWidget);
    expect(find.byTooltip("2 slots"), findsOneWidget);
  });

  testWidgets(
    'does not overflow vertically when the available height is too short for the six week rows',
    (tester) async {
      final day = _buildDay(id: "day-1", dayNumber: 1, date: anchorDate);

      // Short enough that the six week rows' own fixed `minHeight` (82 each, ~492 in all) cannot
      // fit without scrolling — before the fix this reproduced a bottom `RenderFlex` overflow.
      await tester.pumpWidget(
        _wrapInApp(
          OcptScheduleMonthGrid(
            anchorDate: anchorDate,
            firstWeekday: OcptFirstWeekday.monday,
            days: [day],
            slotsByDayId: const {},
            firstLocationByDayId: const {},
            dayTintOf: (_) => Colors.transparent,
            timelineOf: (_) => null,
            sunTimesOf: (_) => null,
            selectedDayId: null,
            alertsOfDay: (dayId) => const [],
            onDayOpenRequested: (_) {},
          ),
          height: 200,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
