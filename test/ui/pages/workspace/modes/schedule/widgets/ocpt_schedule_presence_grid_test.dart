// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_presence_grid.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the mode's own centre area.
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
      date: date,
      dayNumber: dayNumber,
      kind: OcptShootingDayKind.shoot,
      status: OcptShootingDayStatus.planned,
      crewNote: "",
      weatherNote: "",
      notes: "",
    );

void main() {
  testWidgets("shows the empty hint while the address book holds nobody", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(
        OcptSchedulePresenceGrid(
          days: const [],
          people: const [],
          roles: const [],
          presenceCellOf: (dayId, personId) => null,
          unavailableAlerts: const [],
          onDayOpenRequested: (dayId) {},
        ),
      ),
    );

    expect(find.text("Add people to the address book to see them here."), findsOneWidget);
  });

  testWidgets("a computed working cell reads its own letter and full-word tooltip", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));

    await tester.pumpWidget(
      _wrapInApp(
        OcptSchedulePresenceGrid(
          days: [day],
          people: [person],
          roles: const [],
          presenceCellOf: (dayId, personId) => OcptPresenceCode.working,
          unavailableAlerts: const [],
          onDayOpenRequested: (dayId) {},
        ),
      ),
    );

    expect(find.text("W"), findsOneWidget);
    expect(find.byTooltip("Working"), findsOneWidget);
  });

  testWidgets("a computed unavailable cell reads its own letter and full-word tooltip",
      (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));

    await tester.pumpWidget(
      _wrapInApp(
        OcptSchedulePresenceGrid(
          days: [day],
          people: [person],
          roles: const [],
          presenceCellOf: (dayId, personId) => OcptPresenceCode.unavailable,
          unavailableAlerts: const [],
          onDayOpenRequested: (dayId) {},
        ),
      ),
    );

    expect(find.text("U"), findsOneWidget);
    expect(find.byTooltip("Unavailable"), findsOneWidget);
  });

  testWidgets("a cell named by a person-unavailable alert reads in the error colour", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));

    await tester.pumpWidget(
      _wrapInApp(
        OcptSchedulePresenceGrid(
          days: [day],
          people: [person],
          roles: const [],
          presenceCellOf: (dayId, personId) => OcptPresenceCode.working,
          unavailableAlerts: const [
            OcptSchedulePersonUnavailableAlert(
              dayId: "day-1",
              personId: "person-1",
              unavailabilityId: "unavailability-1",
              slotIds: ["slot-1"],
            ),
          ],
          onDayOpenRequested: (dayId) {},
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.text("W")));
    final letterStyle = tester.widget<Text>(find.text("W")).style;
    expect(letterStyle?.color, theme.colorScheme.error);
  });

  testWidgets("clicking a column header opens its own day", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 3));

    String? openedDayId;
    await tester.pumpWidget(
      _wrapInApp(
        OcptSchedulePresenceGrid(
          days: [day],
          people: [person],
          roles: const [],
          presenceCellOf: (dayId, personId) => null,
          unavailableAlerts: const [],
          onDayOpenRequested: (dayId) => openedDayId = dayId,
        ),
      ),
    );

    await tester.tap(find.text("D1"));
    await tester.pump();

    expect(openedDayId, "day-1");
  });
}
