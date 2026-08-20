// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_view.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the workspace shell's own centre area.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 640, height: 700, child: child)),
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay() => OcptShootingDay(
  id: "day-1",
  date: DateTime(2026, 8, 4),
  dayNumber: 1,
  kind: OcptShootingDayKind.shoot,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a day event with the few fields these tests read, everything else neutral.
OcptShootingDayEvent _buildEvent() => const OcptShootingDayEvent(
  id: "event-1",
  shootingDayId: "day-1",
  minute: 1020,
  label: "Fireworks",
  notes: "",
);

/// Pumps [OcptScheduleDayView] with no slots at all — these tests only exercise the events band,
/// which is drawn independently of the slot cards — and every writing affordance withheld unless
/// [onEventAdded] is handed in.
Future<void> _pumpDayView(
  WidgetTester tester, {
  List<OcptShootingDayEvent> events = const [],
  VoidCallback? onEventAdded,
}) async {
  await tester.pumpWidget(
    _wrapInApp(
      OcptScheduleDayView(
        day: _buildDay(),
        slots: const [],
        blocks: const [],
        timeline: null,
        dayArrivalMinute: null,
        sunTimes: null,
        alerts: const [],
        locationById: const {},
        setById: const {},
        locations: const [],
        personById: const {},
        roleById: const {},
        people: const [],
        roles: const [],
        shotOf: (_) => null,
        selectedBlockId: null,
        sequences: const [],
        slotLabelValueOf: (_) => "",
        slotNotesValueOf: (_) => "",
        onSlotAdded: null,
        onSlotLabelChanged: null,
        onSlotNotesChanged: null,
        onSlotPlaceChanged: null,
        onSlotAnchorChanged: null,
        onSlotMoved: null,
        onSlotDeletionRequested: null,
        onSlotCrewMemberAdded: null,
        onSlotCrewMemberPositionChanged: null,
        onSlotCrewMemberRemoved: null,
        onSlotCastRoleAdded: null,
        onSlotCastRoleRemoved: null,
        onSlotGuestAdded: null,
        onSlotGuestRemoved: null,
        slotGuestReasonValueOf: (_) => "",
        onSlotGuestReasonChanged: null,
        slotGuestNotesValueOf: (_) => "",
        onSlotGuestNotesChanged: null,
        onBlockSelected: (_) {},
        onBlockReordered: null,
        onBlockDurationChanged: null,
        onBlockAnchorChanged: null,
        onShotStatusChanged: null,
        onBlockSequenceChanged: null,
        onBlockDeletionRequested: null,
        onBlockAdded: null,
        onShotBlockRequested: null,
        onBlockMovedToSlot: null,
        onAlertsOpenRequested: null,
        events: events,
        eventLabelValueOf: (_) => "Fireworks",
        eventNotesValueOf: (_) => "",
        onEventAdded: onEventAdded,
        onEventMinuteChanged: onEventAdded == null ? null : (_, _) {},
        onEventLabelChanged: onEventAdded == null ? null : (_, _) {},
        onEventNotesChanged: onEventAdded == null ? null : (_, _) {},
        onEventDeletionRequested: onEventAdded == null ? null : (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    "the events band is absent on a day with no event when the view may not be written to",
    (tester) async {
      await _pumpDayView(tester);

      final tr = Tr.of(tester.element(find.byType(OcptScheduleDayView)));
      expect(find.text(tr.scheduleDayEventsSectionTitle.toUpperCase()), findsNothing);
      expect(find.text(tr.scheduleAddDayEventAction), findsNothing);
    },
  );

  testWidgets("the events band draws once the day has an event, even read-only", (tester) async {
    await _pumpDayView(tester, events: [_buildEvent()]);

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayView)));
    expect(find.text(tr.scheduleDayEventsSectionTitle.toUpperCase()), findsOneWidget);
    expect(find.text("Fireworks"), findsOneWidget);
    // Still read-only: no `+ Event` footer, since every event callback was withheld.
    expect(find.text(tr.scheduleAddDayEventAction), findsNothing);
  });

  testWidgets("the events band draws with no event at all once it may be written to", (
    tester,
  ) async {
    await _pumpDayView(tester, onEventAdded: () {});

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayView)));
    expect(find.text(tr.scheduleDayEventsSectionTitle.toUpperCase()), findsOneWidget);
    expect(find.text(tr.scheduleAddDayEventAction), findsOneWidget);
  });
}
