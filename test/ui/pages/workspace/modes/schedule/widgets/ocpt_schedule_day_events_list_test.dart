// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_events_list.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
);

/// Builds an event with the few fields these tests read, everything else neutral.
OcptShootingDayEvent _buildEvent({
  String id = "event-1",
  int minute = 1020,
  String label = "",
}) => OcptShootingDayEvent(id: id, shootingDayId: "day-1", minute: minute, label: label, notes: "");

void main() {
  testWidgets("an event's hour, label and note are drawn", (tester) async {
    final event = _buildEvent(label: "Fireworks");

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleDayEventsList(
          events: [event],
          eventLabelValueOf: (_) => "Fireworks",
          eventNotesValueOf: (_) => "Village square",
          onEventAdded: () {},
          onEventMinuteChanged: (_, _) {},
          onEventLabelChanged: (_, _) {},
          onEventNotesChanged: (_, _) {},
          onEventDeletionRequested: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final minuteField = tester.widget<OcptScheduleMinuteField>(find.byType(OcptScheduleMinuteField));
    expect(minuteField.minute, 1020);
    final labelField = tester.widget<TextField>(
      find.byWidgetPredicate((widget) => widget is TextField && widget.controller?.text == "Fireworks"),
    );
    expect(labelField.controller?.text, "Fireworks");
    final noteField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == "Village square",
      ),
    );
    expect(noteField.controller?.text, "Village square");
  });

  testWidgets("with every callback null (a version preview) the row reads as plain text", (
    tester,
  ) async {
    final event = _buildEvent(label: "Fireworks");

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleDayEventsList(
          events: [event],
          eventLabelValueOf: (_) => "Fireworks",
          eventNotesValueOf: (_) => "Village square",
          onEventAdded: null,
          onEventMinuteChanged: null,
          onEventLabelChanged: null,
          onEventNotesChanged: null,
          onEventDeletionRequested: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Still reads: the hour, the label and the note all show as plain text.
    expect(find.text("17:00"), findsOneWidget);
    expect(find.text("Fireworks"), findsOneWidget);
    expect(find.text("Village square"), findsOneWidget);
    // No `TextField` at all — every editable field reads as plain text instead.
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayEventsList)));
    expect(find.text(tr.scheduleAddDayEventAction), findsNothing);
  });

  testWidgets("`+ Event` and the remove control are absent with every callback null", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleDayEventsList(
          events: const [],
          eventLabelValueOf: (_) => "",
          eventNotesValueOf: (_) => "",
          onEventAdded: null,
          onEventMinuteChanged: null,
          onEventLabelChanged: null,
          onEventNotesChanged: null,
          onEventDeletionRequested: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayEventsList)));
    expect(find.text(tr.scheduleAddDayEventAction), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets("an empty label reads as `Untitled event` and an empty note draws nothing", (
    tester,
  ) async {
    final event = _buildEvent();

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleDayEventsList(
          events: [event],
          eventLabelValueOf: (_) => "",
          eventNotesValueOf: (_) => "",
          onEventAdded: null,
          onEventMinuteChanged: null,
          onEventLabelChanged: null,
          onEventNotesChanged: null,
          onEventDeletionRequested: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayEventsList)));
    expect(find.text(tr.scheduleDayEventUnnamedLabel), findsOneWidget);
  });

  testWidgets("the deletion callback only asks — the widget writes nothing itself", (
    tester,
  ) async {
    final event = _buildEvent(label: "Fireworks");
    final deletionRequests = <String>[];
    final minuteEdits = <(String, int)>[];
    final labelEdits = <(String, String)>[];
    final noteEdits = <(String, String)>[];

    await tester.pumpWidget(
      _wrapInApp(
        OcptScheduleDayEventsList(
          events: [event],
          eventLabelValueOf: (_) => "Fireworks",
          eventNotesValueOf: (_) => "",
          onEventAdded: () {},
          onEventMinuteChanged: (id, minute) => minuteEdits.add((id, minute)),
          onEventLabelChanged: (id, rawValue) => labelEdits.add((id, rawValue)),
          onEventNotesChanged: (id, rawValue) => noteEdits.add((id, rawValue)),
          onEventDeletionRequested: deletionRequests.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(deletionRequests, ["event-1"]);
    // Nothing else fired: a click on the remove control only ever asks.
    expect(minuteEdits, isEmpty);
    expect(labelEdits, isEmpty);
    expect(noteEdits, isEmpty);
  });
}
