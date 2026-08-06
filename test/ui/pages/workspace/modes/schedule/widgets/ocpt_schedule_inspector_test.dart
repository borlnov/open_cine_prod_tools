// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_inspector.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the `OcptWorkspaceDock` right panel the inspector fills in the app.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 320, height: 700, child: child)),
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({
  OcptShootingDayStatus status = OcptShootingDayStatus.planned,
  String crewNote = "",
  String weatherNote = "",
}) => OcptShootingDay(
  id: "day-1",
  screenplayId: "screenplay-1",
  date: DateTime(2026, 8, 4),
  dayNumber: 3,
  status: status,
  crewNote: crewNote,
  weatherNote: weatherNote,
  notes: "",
);

/// Pumps [OcptScheduleInspector] with [day] selected and no block, [sunTimes] as given.
Future<void> _pumpDayInspector(
  WidgetTester tester, {
  required OcptShootingDay day,
  OcptSunTimes? sunTimes,
  ValueChanged<OcptShootingDayStatus>? onDayStatusChanged,
  ValueChanged<String>? onCrewNoteChanged,
  ValueChanged<String>? onWeatherNoteChanged,
}) async {
  await tester.pumpWidget(
    _wrapInApp(
      OcptScheduleInspector(
        day: day,
        slots: const [],
        locationById: const {},
        setById: const {},
        timeline: null,
        sunTimes: sunTimes,
        crewNoteValue: day.crewNote,
        weatherNoteValue: day.weatherNote,
        onDayStatusChanged: onDayStatusChanged,
        onCrewNoteChanged: onCrewNoteChanged,
        onWeatherNoteChanged: onWeatherNoteChanged,
        block: null,
        blockShot: null,
        blockSlotLabel: null,
        blockEntry: null,
        onShotStatusChanged: null,
        blockNotesValue: "",
        onBlockNotesChanged: null,
        isReadOnly: onDayStatusChanged == null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("shows the selected day's own date, status and PAT-to-end read-outs", (
    tester,
  ) async {
    final day = _buildDay(status: OcptShootingDayStatus.shot);
    await _pumpDayInspector(tester, day: day, onDayStatusChanged: (_) {});

    final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
    expect(find.text(tr.scheduleInspectorDayTitle("J3")), findsOneWidget);
    expect(find.text(tr.scheduleDayStatusShot), findsOneWidget);
    // No slot at all: PAT → end reads as an em dash rather than crashing.
    expect(find.text("—"), findsWidgets);
  });

  testWidgets("a day with no sun times shows the hint rather than crashing", (tester) async {
    // The helper defaults `sunTimes` to null: no coordinates on the day's first location, so
    // nothing was computed.
    await _pumpDayInspector(tester, day: _buildDay(), onDayStatusChanged: (_) {});

    final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
    expect(find.text(tr.scheduleInspectorNoSunTimes), findsOneWidget);
    expect(find.textContaining("null"), findsNothing);
  });

  testWidgets(
    "a day whose sun times hold null figures never prints the word 'null', an em dash instead",
    (tester) async {
      const sunTimesWithNoFigures = OcptSunTimes(
        sunriseMinute: null,
        sunsetMinute: null,
        civilDawnMinute: null,
        civilDuskMinute: null,
        nauticalDawnMinute: null,
        nauticalDuskMinute: null,
        astronomicalDawnMinute: null,
        astronomicalDuskMinute: null,
        utcOffsetUsed: Duration(hours: 2),
      );

      await _pumpDayInspector(
        tester,
        day: _buildDay(),
        sunTimes: sunTimesWithNoFigures,
        onDayStatusChanged: (_) {},
      );

      final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
      expect(
        find.text(tr.scheduleInspectorSunTimesLine("—", "—", "—", "—", "UTC+2")),
        findsOneWidget,
      );
      expect(find.textContaining("null"), findsNothing);
    },
  );

  testWidgets("the status control and note fields write immediately when picked or typed", (
    tester,
  ) async {
    OcptShootingDayStatus? pickedStatus;
    final crewNoteEdits = <String>[];

    await _pumpDayInspector(
      tester,
      day: _buildDay(),
      onDayStatusChanged: (status) => pickedStatus = status,
      onCrewNoteChanged: crewNoteEdits.add,
      onWeatherNoteChanged: (_) {},
    );

    final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
    await tester.tap(find.text(tr.scheduleDayStatusPlanned));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleDayStatusShot).last);
    await tester.pumpAndSettle();
    expect(pickedStatus, OcptShootingDayStatus.shot);

    // The weather field comes first in the inspector, the crew note second: both are plain
    // `TextField`s, so the crew note is the last of the two.
    await tester.enterText(find.byType(TextField).last, "Rain expected");
    expect(crewNoteEdits, ["Rain expected"]);
  });

  testWidgets("every writing affordance is withheld when the mode is read-only", (tester) async {
    // Every callback left at the helper's own default, which is null: read-only is expressed as
    // "no callback, no affordance", so handing none of them is exactly what the mode does while a
    // version is being previewed.
    await _pumpDayInspector(tester, day: _buildDay(crewNote: "Bring umbrellas"));

    final tr = Tr.of(tester.element(find.byType(OcptScheduleInspector)));
    // The status reads as plain text, no drop-down affordance.
    expect(find.byType(PopupMenuButton<OcptShootingDayStatus>), findsNothing);
    expect(find.text(tr.scheduleDayStatusPlanned), findsOneWidget);
    // The crew note reads as plain selectable text, not an editable field.
    expect(find.byType(TextField), findsNothing);
    expect(find.text("Bring umbrellas"), findsOneWidget);
  });
}
