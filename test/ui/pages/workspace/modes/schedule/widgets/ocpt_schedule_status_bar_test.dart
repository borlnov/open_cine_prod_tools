// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_status_bar.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a band [width]
/// wide.
Widget _wrapInApp(Widget child, {double width = 700}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: width, child: child)),
);

void main() {
  /// Pumps the status bar for a schedule of [dayCount] days, with or without a selected day and its
  /// own computed end.
  Future<void> pumpStatusBar(
    WidgetTester tester, {
    int dayCount = 1,
    required bool isDaySelected,
    required int? selectedDayEndMinute,
  }) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleStatusBar(
          dayCount: dayCount,
          placedShotCount: 0,
          shotsLeftToPlaceCount: 0,
          isDaySelected: isDaySelected,
          selectedDayEndMinute: selectedDayEndMinute,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the selected day's estimated end is reported once it has one", (tester) async {
    await pumpStatusBar(tester, isDaySelected: true, selectedDayEndMinute: 1110);

    final tr = Tr.of(tester.element(find.byType(OcptScheduleStatusBar)));
    expect(find.text(tr.scheduleStatsEstimatedEnd("18:30")), findsOneWidget);
  });

  testWidgets("a selected day holding nothing yet doesn't read as no day at all", (tester) async {
    // The timeline of a day with no block has no end to report, which is a different fact from
    // nothing being selected — the user has just created that day and is looking at it.
    await pumpStatusBar(tester, isDaySelected: true, selectedDayEndMinute: null);

    final tr = Tr.of(tester.element(find.byType(OcptScheduleStatusBar)));
    expect(find.text(tr.scheduleStatsNothingPlannedYet), findsOneWidget);
    expect(find.text(tr.scheduleStatsNoDaySelected), findsNothing);
  });

  testWidgets("no day selected says so", (tester) async {
    await pumpStatusBar(tester, dayCount: 0, isDaySelected: false, selectedDayEndMinute: null);

    final tr = Tr.of(tester.element(find.byType(OcptScheduleStatusBar)));
    expect(find.text(tr.scheduleStatsNoDaySelected), findsOneWidget);
  });

  testWidgets("a night day's end past midnight reads as a clock face", (tester) async {
    await pumpStatusBar(tester, isDaySelected: true, selectedDayEndMinute: 1620);

    final tr = Tr.of(tester.element(find.byType(OcptScheduleStatusBar)));
    expect(find.text(tr.scheduleStatsEstimatedEnd("03:00")), findsOneWidget);
  });
}
