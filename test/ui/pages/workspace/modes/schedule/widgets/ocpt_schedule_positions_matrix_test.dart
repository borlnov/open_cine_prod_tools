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

/// Builds a minimal [OcptShootingDayTimelines] resolving each slot id of [hoursBySlotId] to its own
/// given resolved start and end (a null end standing for a slot carrying no block at all), and
/// nothing else — enough for a column header to print real hours instead of falling back to the
/// very em dash the empty-cell test means to count on its own.
OcptShootingDayTimelines _buildTimelines(Map<String, (int, int?)> hoursBySlotId) => OcptShootingDayTimelines(
  bySlotId: {
    for (final entry in hoursBySlotId.entries)
      entry.key: OcptShootingSlotTimeline(
        entries: const [],
        overruns: const [],
        startMinute: entry.value.$1,
        endMinute: entry.value.$2,
      ),
  },
  entries: const [],
  overruns: const [],
  fixedEndMisses: const [],
  anchorCycles: const [],
  dayStartMinute: hoursBySlotId.values.isEmpty
      ? null
      : hoursBySlotId.values.map((hours) => hours.$1).reduce((a, b) => a < b ? a : b),
  dayEndMinute: null,
);

/// Pumps [OcptSchedulePositionsMatrix] with the given schedule, everything else defaulting to
/// empty or to a widget that resolves no timeline at all.
Future<void> _pumpMatrix(
  WidgetTester tester, {
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, OcptPerson> personById = const {},
  OcptShootingDayTimelines? Function(String dayId) timelinesOfDay = _noTimelines,
}) => tester.pumpWidget(
  _wrapInApp(
    OcptSchedulePositionsMatrix(
      days: days,
      slotsByDayId: slotsByDayId,
      personById: personById,
      timelinesOfDay: timelinesOfDay,
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
          ? _buildTimelines({"slot-1": (480, 1140)})
          : _buildTimelines({"slot-2": (480, 1140)}),
    );

    expect(find.text("Director"), findsOneWidget);
    expect(find.text("—"), findsOneWidget);
  });

  testWidgets("a day band names its day once, however many slots that day holds", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day1 = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));
    final day2 = _buildDay(id: "day-2", dayNumber: 2, date: DateTime(2026, 8, 4));
    final morning = _buildSlot(
      id: "slot-1",
      label: "Matin",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: person.id)],
    );
    final evening = _buildSlot(
      id: "slot-2",
      label: "Soir",
      crew: [_buildCrewMember(id: "crew-2", slotId: "slot-2", personId: person.id)],
    );
    final nextDay = _buildSlot(
      id: "slot-3",
      label: "Nuit",
      crew: [_buildCrewMember(id: "crew-3", slotId: "slot-3", personId: person.id)],
    );

    await _pumpMatrix(
      tester,
      days: [day1, day2],
      slotsByDayId: {
        "day-1": [morning, evening],
        "day-2": [nextDay],
      },
      personById: {person.id: person},
    );

    // Two slots on the first day, and its tag drawn once above both of them rather than on each
    // column — which is the whole point of the band.
    expect(find.text("D1"), findsOneWidget);
    expect(find.text("D2"), findsOneWidget);
    expect(find.text("Matin"), findsOneWidget);
    expect(find.text("Soir"), findsOneWidget);
  });

  testWidgets("a column header prints its slot's own resolved start and end", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));
    final slot = _buildSlot(
      id: "slot-1",
      label: "Matin",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: person.id)],
    );

    await _pumpMatrix(
      tester,
      days: [day],
      slotsByDayId: {
        "day-1": [slot],
      },
      personById: {person.id: person},
      timelinesOfDay: (dayId) => _buildTimelines({"slot-1": (480, 1140)}),
    );

    expect(find.text("08:00 – 19:00"), findsOneWidget);
  });

  testWidgets("a slot carrying no block prints its resolved start alone", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));
    final slot = _buildSlot(
      id: "slot-1",
      label: "Matin",
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: person.id)],
    );

    await _pumpMatrix(
      tester,
      days: [day],
      slotsByDayId: {
        "day-1": [slot],
      },
      personById: {person.id: person},
      timelinesOfDay: (dayId) => _buildTimelines({"slot-1": (480, null)}),
    );

    expect(find.text("08:00"), findsOneWidget);
  });

  testWidgets("clicking a day band opens its own day", (tester) async {
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
          onDayOpenRequested: (dayId) => openedDayId = dayId,
        ),
      ),
    );

    await tester.tap(find.text("D1"));
    await tester.pump();

    expect(openedDayId, "day-1");
  });

  testWidgets("clicking a column header opens its own day", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));
    final slot = _buildSlot(
      id: "slot-1",
      label: "Matin",
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
          onDayOpenRequested: (dayId) => openedDayId = dayId,
        ),
      ),
    );

    await tester.tap(find.text("Matin"));
    await tester.pump();

    expect(openedDayId, "day-1");
  });
}
