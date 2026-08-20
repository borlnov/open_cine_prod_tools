// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_alerts_panel.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the right dock the panel fills in the app.
Widget _wrapInApp(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 340, height: 700, child: child)),
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

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required String name}) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
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

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({required String id, String label = ""}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: label,
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

/// Pumps [OcptScheduleAlertsPanel] with the given alerts and lookups, everything else defaulting to
/// empty.
Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<OcptScheduleAlert> alerts,
  Map<String, OcptPerson> personById = const {},
  Map<String, OcptRole> roleById = const {},
  Map<String, OcptLocation> locationById = const {},
  Map<String, OcptShootingDay> daysById = const {},
  Map<String, OcptShootingSlot> slotById = const {},
  Map<String, OcptShootingDayBlock> blockById = const {},
  ValueChanged<String>? onDayOpenRequested,
}) => tester.pumpWidget(
  _wrapInApp(
    OcptScheduleAlertsPanel(
      alerts: alerts,
      personById: personById,
      roleById: roleById,
      locationById: locationById,
      daysById: daysById,
      slotById: slotById,
      blockById: blockById,
      shotOf: (shotId) => null,
      onDayOpenRequested: onDayOpenRequested ?? (dayId) {},
    ),
  ),
);

void main() {
  testWidgets("an empty plan reads as nothing to look at", (tester) async {
    await _pumpPanel(tester, alerts: const []);

    expect(find.text("The plan raises nothing to look at."), findsOneWidget);
  });

  testWidgets("a hard alert reads as a statement of fact, coloured as a real error", (
    tester,
  ) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 8, 4));
    final morning = _buildSlot(id: "slot-1", label: "Matin");
    final evening = _buildSlot(id: "slot-2", label: "Soir");

    await _pumpPanel(
      tester,
      alerts: const [
        OcptSchedulePersonDoubleBookedAlert(
          dayId: "day-1",
          personId: "person-1",
          firstSlotId: "slot-1",
          secondSlotId: "slot-2",
        ),
      ],
      personById: {"person-1": person},
      daysById: {"day-1": day},
      slotById: {"slot-1": morning, "slot-2": evening},
    );

    expect(find.text("Double-booked"), findsOneWidget);
    expect(
      find.text("Léa is convoked on both Matin and Soir, whose times overlap."),
      findsOneWidget,
    );

    final titleFinder = find.text("Double-booked");
    final titleStyle = tester.widget<Text>(titleFinder).style;
    final theme = Theme.of(tester.element(titleFinder));
    expect(titleStyle?.color, theme.colorScheme.error);
  });

  testWidgets("a soft alert with no day carries no day control", (tester) async {
    final role = _buildRole(id: "role-1", name: "ANNA");

    await _pumpPanel(
      tester,
      alerts: const [OcptScheduleRoleUncastAlert(roleId: "role-1")],
      roleById: {"role-1": role},
    );

    expect(find.text("Role not cast"), findsOneWidget);
    expect(find.text("ANNA has no actor cast yet."), findsOneWidget);
    // Rule 6 is the one alert with no day, so there is nothing here to click.
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
  });

  testWidgets("clicking a card's day control opens that day", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final day = _buildDay(id: "day-1", dayNumber: 3, date: DateTime(2026, 8, 4));
    final slot = _buildSlot(id: "slot-1", label: "Matin");

    String? openedDayId;
    await _pumpPanel(
      tester,
      alerts: const [
        OcptSchedulePersonUnavailableAlert(
          dayId: "day-1",
          personId: "person-1",
          unavailabilityId: "unavailability-1",
          slotIds: ["slot-1"],
        ),
      ],
      personById: {"person-1": person},
      daysById: {"day-1": day},
      slotById: {"slot-1": slot},
      onDayOpenRequested: (dayId) => openedDayId = dayId,
    );

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pump();

    expect(openedDayId, "day-1");
  });
}
