// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_positions_matrix.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_prefill.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the mode's own centre area — wide enough for a handful of slot columns beside
/// the frozen label column.
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

/// Builds a person with the few fields these tests read, everything else neutral.
OcptPerson _buildPerson({required String id, required String firstName}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: "",
  email: "",
  phone: "",
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: 0,
  birthDate: null,
  minorNotes: "",
  maxDailyPresenceMinutes: null,
  isTransportAutonomous: null,
  accommodationNotes: "",
  travelNotes: "",
  dietaryNotes: "",
  allergies: "",
  measurementHeight: "",
  measurementChest: "",
  measurementWaist: "",
  measurementHips: "",
  sizeTop: "",
  sizeBottom: "",
  sizeShoes: "",
  hmcNotes: "",
  imageRightsStatus: OcptImageRightsStatus.notApplicable,
  imageRightsDate: null,
  imageRightsAssetId: null,
  imageRightsDocument: null,
  photoAssetId: null,
  photo: null,
  notes: "",
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
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

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({
  required String id,
  String label = "",
  List<OcptShootingSlotCrewMember> crew = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: label,
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: crew,
  cast: const [],
  guests: const [],
);

/// Builds a crew assignment holding the catalogue's `director` position by default — the few
/// fields these tests read, everything else neutral.
OcptShootingSlotCrewMember _buildCrewMember({
  required String id,
  required String slotId,
  required String personId,
  String positionId = "director",
}) => OcptShootingSlotCrewMember(
  id: id,
  slotId: slotId,
  personId: personId,
  positionId: positionId,
  customLabel: "",
  notes: "",
);

/// Builds a minimal [OcptShootingDayTimelines] resolving each slot id of [startMinuteBySlotId] to
/// its own given start, and nothing else — enough for a column header to print a real hour instead
/// of falling back to the very em dash the empty-cell test means to count on its own.
OcptShootingDayTimelines _buildTimelines(Map<String, int> startMinuteBySlotId) => OcptShootingDayTimelines(
  bySlotId: {
    for (final entry in startMinuteBySlotId.entries)
      entry.key: OcptShootingSlotTimeline(
        entries: const [],
        overruns: const [],
        startMinute: entry.value,
        endMinute: null,
      ),
  },
  entries: const [],
  overruns: const [],
  fixedEndMisses: const [],
  anchorCycles: const [],
  dayStartMinute: startMinuteBySlotId.values.isEmpty
      ? null
      : startMinuteBySlotId.values.reduce((a, b) => a < b ? a : b),
  dayEndMinute: null,
);

/// Pumps [OcptSchedulePositionsMatrix] with the given schedule, everything else defaulting to
/// empty or to a widget that resolves no timeline at all.
Future<void> _pumpMatrix(
  WidgetTester tester, {
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, OcptPerson> personById = const {},
  List<OcptSchedulePositionLostAlert> lostPositionAlerts = const [],
  OcptShootingDayTimelines? Function(String dayId) timelinesOfDay = _noTimelines,
}) => tester.pumpWidget(
  _wrapInApp(
    OcptSchedulePositionsMatrix(
      days: days,
      slotsByDayId: slotsByDayId,
      personById: personById,
      timelinesOfDay: timelinesOfDay,
      lostPositionAlerts: lostPositionAlerts,
      onDayOpenRequested: (dayId) {},
    ),
  ),
);

/// [_pumpMatrix]'s own default `timelinesOfDay`: no day has ever computed one.
OcptShootingDayTimelines? _noTimelines(String dayId) => null;

void main() {
  testWidgets("shows the empty hint while no position has been held on a slot yet", (tester) async {
    await _pumpMatrix(tester, days: const [], slotsByDayId: const {});

    expect(find.text("No position has been held on a slot yet."), findsOneWidget);
  });

  testWidgets("a slot nobody holds a position on renders the empty mark", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day1 = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));
    final day2 = _buildDay(id: "day-2", dayNumber: 2, date: DateTime(2026, 8, 4));
    final heldSlot = _buildSlot(
      id: "slot-1",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: person.id)],
    );
    // A different day, deliberately: two slots of the *same* day would raise a lost-position
    // alert of their own (rule 4) the moment one holds a position the next one doesn't, which is
    // not what this test means to exercise — see the next test for that case.
    final emptySlot = _buildSlot(id: "slot-2");

    await _pumpMatrix(
      tester,
      days: [day1, day2],
      slotsByDayId: {
        "day-1": [heldSlot],
        "day-2": [emptySlot],
      },
      personById: {person.id: person},
      // Real resolved starts on both headers, so the sole em dash left on screen is the empty
      // cell itself — see [_buildTimelines]'s own doc comment.
      timelinesOfDay: (dayId) => dayId == "day-1"
          ? _buildTimelines({"slot-1": 480})
          : _buildTimelines({"slot-2": 480}),
    );

    expect(find.text("Director"), findsOneWidget);
    expect(find.text("—"), findsOneWidget);
  });

  testWidgets("a lost position renders its warning cell", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));
    final heldSlot = _buildSlot(
      id: "slot-1",
      label: "Matin",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: person.id)],
    );
    final droppedSlot = _buildSlot(id: "slot-2", label: "Soir");

    await _pumpMatrix(
      tester,
      days: [day],
      slotsByDayId: {
        "day-1": [heldSlot, droppedSlot],
      },
      personById: {person.id: person},
      lostPositionAlerts: const [
        OcptSchedulePositionLostAlert(
          dayId: "day-1",
          personId: "person-1",
          slotId: "slot-2",
          position: OcptCrewPositionRef(positionId: "director", customLabel: ""),
        ),
      ],
    );

    expect(find.text("Lost"), findsOneWidget);
  });

  testWidgets("clicking a column header opens its own day", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));
    final slot = _buildSlot(
      id: "slot-1",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: person.id)],
    );

    String? openedDayId;
    await tester.pumpWidget(
      _wrapInApp(
        OcptSchedulePositionsMatrix(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
          personById: {person.id: person},
          timelinesOfDay: (dayId) => null,
          lostPositionAlerts: const [],
          onDayOpenRequested: (dayId) => openedDayId = dayId,
        ),
      ),
    );

    await tester.tap(find.text("D1"));
    await tester.pump();

    expect(openedDayId, "day-1");
  });
}
