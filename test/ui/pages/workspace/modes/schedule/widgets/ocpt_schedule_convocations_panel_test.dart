// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_convocations_panel.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

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
  home: Scaffold(body: SizedBox(width: 320, height: 700, child: child)),
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
  candidates: const [],
);

/// Pumps [OcptScheduleConvocationsPanel] with the given lookups, everything else defaulting to
/// empty.
Future<void> _pumpPanel(
  WidgetTester tester, {
  List<OcptDayConvocation>? convocations,
  Map<String, OcptPerson> personById = const {},
  Map<String, OcptRole> roleById = const {},
  Map<String, OcptShootingSlot> slotById = const {},
}) => tester.pumpWidget(
  _wrapInApp(
    OcptScheduleConvocationsPanel(
      convocations: convocations,
      personById: personById,
      roleById: roleById,
      slotById: slotById,
    ),
  ),
);

void main() {
  testWidgets("shows the empty hint while no day is selected", (tester) async {
    await _pumpPanel(tester);

    expect(find.text("Select a day to see its convocations."), findsOneWidget);
  });

  testWidgets("a person with a full PAT band reads arrival, band and departure", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Élisa");
    final slot = _buildSlot(id: "slot-1", label: "HMC");

    await _pumpPanel(
      tester,
      convocations: const [
        OcptDayConvocation(
          personId: "person-1",
          roleId: null,
          guestPersonId: null,
          guestFreeName: null,
          arrivalMinute: 390,
          patStartMinute: 480,
          patEndMinute: 1155,
          departureMinute: 1200,
          slotIds: ["slot-1"],
          roleCandidateId: null,
        ),
      ],
      personById: {"person-1": person},
      slotById: {"slot-1": slot},
    );

    expect(find.text(person.displayName), findsOneWidget);
    expect(find.text("06:30 → 08:00–19:15 → 20:00"), findsOneWidget);
    expect(find.text("HMC"), findsOneWidget);
  });

  testWidgets("a person convoked only on preparation slots shows an em dash for the PAT band", (
    tester,
  ) async {
    final person = _buildPerson(id: "person-1", firstName: "Anna");
    final slot = _buildSlot(id: "slot-1", label: "Installation");

    await _pumpPanel(
      tester,
      convocations: const [
        OcptDayConvocation(
          personId: "person-1",
          roleId: null,
          guestPersonId: null,
          guestFreeName: null,
          arrivalMinute: 420,
          patStartMinute: null,
          patEndMinute: null,
          departureMinute: 1200,
          slotIds: ["slot-1"],
          roleCandidateId: null,
        ),
      ],
      personById: {"person-1": person},
      slotById: {"slot-1": slot},
    );

    expect(find.text("07:00 → — → 20:00"), findsOneWidget);
  });

  testWidgets("an uncast role reads as the role, not as a person", (tester) async {
    final role = _buildRole(id: "role-1", name: "ANNA");
    final slot = _buildSlot(id: "slot-1", label: "Plateau A");

    await _pumpPanel(
      tester,
      convocations: const [
        OcptDayConvocation(
          personId: null,
          roleId: "role-1",
          guestPersonId: null,
          guestFreeName: null,
          arrivalMinute: 420,
          patStartMinute: null,
          patEndMinute: null,
          departureMinute: 1200,
          slotIds: ["slot-1"],
          roleCandidateId: null,
        ),
      ],
      roleById: {"role-1": role},
      slotById: {"slot-1": slot},
    );

    expect(find.text("ANNA (not cast)"), findsOneWidget);
  });

  testWidgets("a person linked to two slots lists both slot labels", (tester) async {
    final person = _buildPerson(id: "person-1", firstName: "Léa");
    final morning = _buildSlot(id: "slot-1", label: "Matin");
    final evening = _buildSlot(id: "slot-2", label: "Soir");

    await _pumpPanel(
      tester,
      convocations: const [
        OcptDayConvocation(
          personId: "person-1",
          roleId: null,
          guestPersonId: null,
          guestFreeName: null,
          arrivalMinute: 480,
          patStartMinute: 540,
          patEndMinute: 1200,
          departureMinute: 1260,
          slotIds: ["slot-1", "slot-2"],
          roleCandidateId: null,
        ),
      ],
      personById: {"person-1": person},
      slotById: {"slot-1": morning, "slot-2": evening},
    );

    expect(find.text("Matin · Soir"), findsOneWidget);
  });

  testWidgets("several convocations are ordered by arrival, then by name on a tie", (
    tester,
  ) async {
    final early = _buildPerson(id: "person-early", firstName: "Zoé");
    final tiedOne = _buildPerson(id: "person-b", firstName: "Bruno");
    final tiedTwo = _buildPerson(id: "person-a", firstName: "Alice");
    final slot = _buildSlot(id: "slot-1");

    await _pumpPanel(
      tester,
      convocations: [
        // Given out of order on purpose: the panel is what re-sorts, never the caller.
        OcptDayConvocation(
          personId: tiedOne.id,
          roleId: null,
          guestPersonId: null,
          guestFreeName: null,
          arrivalMinute: 480,
          patStartMinute: null,
          patEndMinute: null,
          departureMinute: 600,
          slotIds: const ["slot-1"],
          roleCandidateId: null,
        ),
        OcptDayConvocation(
          personId: early.id,
          roleId: null,
          guestPersonId: null,
          guestFreeName: null,
          arrivalMinute: 420,
          patStartMinute: null,
          patEndMinute: null,
          departureMinute: 600,
          slotIds: const ["slot-1"],
          roleCandidateId: null,
        ),
        OcptDayConvocation(
          personId: tiedTwo.id,
          roleId: null,
          guestPersonId: null,
          guestFreeName: null,
          arrivalMinute: 480,
          patStartMinute: null,
          patEndMinute: null,
          departureMinute: 600,
          slotIds: const ["slot-1"],
          roleCandidateId: null,
        ),
      ],
      personById: {early.id: early, tiedOne.id: tiedOne, tiedTwo.id: tiedTwo},
      slotById: {"slot-1": slot},
    );

    final earlyOffset = tester.getTopLeft(find.text(early.displayName)).dy;
    final aliceOffset = tester.getTopLeft(find.text(tiedTwo.displayName)).dy;
    final brunoOffset = tester.getTopLeft(find.text(tiedOne.displayName)).dy;

    // Zoé arrives first (420), then the 480 tie breaks alphabetically: Alice before Bruno.
    expect(earlyOffset, lessThan(aliceOffset));
    expect(aliceOffset, lessThan(brunoOffset));
  });

  testWidgets("guests form their own trailing group, after crew and cast, under their own heading", (
    tester,
  ) async {
    final crewPerson = _buildPerson(id: "person-crew", firstName: "Alice");
    final guestPerson = _buildPerson(id: "person-guest", firstName: "Zoé");
    final slot = _buildSlot(id: "slot-1", label: "Plateau");

    await _pumpPanel(
      tester,
      convocations: [
        // The guest arrives before the crew member on purpose: even so, it must draw after — the
        // grouping is not a plain re-sort by arrival across the whole list.
        OcptDayConvocation(
          personId: null,
          roleId: null,
          guestPersonId: guestPerson.id,
          guestFreeName: null,
          arrivalMinute: 300,
          patStartMinute: null,
          patEndMinute: null,
          departureMinute: 360,
          slotIds: const ["slot-1"],
          roleCandidateId: null,
        ),
        OcptDayConvocation(
          personId: crewPerson.id,
          roleId: null,
          guestPersonId: null,
          guestFreeName: null,
          arrivalMinute: 480,
          patStartMinute: null,
          patEndMinute: null,
          departureMinute: 600,
          slotIds: const ["slot-1"],
          roleCandidateId: null,
        ),
      ],
      personById: {crewPerson.id: crewPerson, guestPerson.id: guestPerson},
      slotById: {"slot-1": slot},
    );

    final tr = Tr.of(tester.element(find.byType(OcptScheduleConvocationsPanel)));
    final heading = tr.scheduleConvocationsGuestsSectionTitle.toUpperCase();
    expect(find.text(heading), findsOneWidget);

    final crewOffset = tester.getTopLeft(find.text(crewPerson.displayName)).dy;
    final headingOffset = tester.getTopLeft(find.text(heading)).dy;
    final guestOffset = tester.getTopLeft(find.text(guestPerson.displayName)).dy;

    expect(crewOffset, lessThan(headingOffset));
    expect(headingOffset, lessThan(guestOffset));
  });
}
