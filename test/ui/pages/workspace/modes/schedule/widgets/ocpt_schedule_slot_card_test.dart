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
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the day view's own scroll area.
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

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
}) => OcptShootingSlot(
  id: "slot-1",
  shootingDayId: "day-1",
  label: "Matin",
  locationId: null,
  setId: null,
  crewCallMinute: 480,
  crewWrapMinute: 1080,
  castCallMinute: null,
  castWrapMinute: null,
  notes: "",
  crew: crew,
  cast: cast,
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
  photoAssetId: null,
  notes: "",
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required String name}) => OcptRole(
  id: id,
  screenplayId: "screenplay-1",
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
);

void main() {
  final person = _buildPerson(id: "person-1", firstName: "Léa");
  final role = _buildRole(id: "role-1", name: "Marie");

  Widget buildCard({
    required bool isReadOnly,
    List<OcptShootingSlotCrewMember> crew = const [],
    List<OcptShootingSlotCastMember> cast = const [],
    ValueChanged<String>? onCrewMemberAdded,
    ValueChanged<String>? onCastRoleAdded,
    VoidCallback? onDeletionRequested,
  }) => OcptScheduleSlotCard(
    slot: _buildSlot(crew: crew, cast: cast),
    location: null,
    set: null,
    locations: const [],
    personById: {person.id: person},
    roleById: {role.id: role},
    people: [person],
    roles: [role],
    labelValue: "Matin",
    onLabelChanged: isReadOnly ? null : (_) {},
    onPlaceChanged: isReadOnly ? null : (_, _) {},
    onCrewTimesChanged: isReadOnly ? null : (_, _) {},
    onCastTimesChanged: isReadOnly ? null : (_, _) {},
    onDeletionRequested: isReadOnly ? null : (onDeletionRequested ?? () {}),
    onCrewMemberAdded: isReadOnly ? null : (onCrewMemberAdded ?? (_) {}),
    onCrewMemberPositionChanged: isReadOnly ? null : (_, _) {},
    onCrewMemberTimesChanged: isReadOnly ? null : (_, _, _) {},
    onCrewMemberRemoved: isReadOnly ? null : (_) {},
    onCastRoleAdded: isReadOnly ? null : (onCastRoleAdded ?? (_) {}),
    onCastRoleTimesChanged: isReadOnly ? null : (_, _, _, _) {},
    onCastRoleRemoved: isReadOnly ? null : (_) {},
  );

  testWidgets("the `+ Crew member` footer opens a picker dispatching the person just picked", (
    tester,
  ) async {
    final added = <String>[];
    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false, onCrewMemberAdded: added.add)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleAddCrewMemberAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Léa").last);
    await tester.pumpAndSettle();

    expect(added, ["person-1"]);
  });

  testWidgets("the `+ Cast` footer opens a picker dispatching the role just picked", (tester) async {
    final added = <String>[];
    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false, onCastRoleAdded: added.add)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleAddCastAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Marie").last);
    await tester.pumpAndSettle();

    expect(added, ["role-1"]);
  });

  testWidgets("a crew row and a cast row are both shown, with their own remove controls", (
    tester,
  ) async {
    final crew = [
      const OcptShootingSlotCrewMember(
        id: "crew-1",
        slotId: "slot-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        callMinute: null,
        wrapMinute: null,
        notes: "",
      ),
    ];
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        arrivalMinute: null,
        castCallMinute: null,
        castWrapMinute: null,
        notes: "",
      ),
    ];

    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false, crew: crew, cast: cast)));
    await tester.pumpAndSettle();

    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Marie"), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets("every writing affordance is withheld when the mode is read-only", (tester) async {
    final crew = [
      const OcptShootingSlotCrewMember(
        id: "crew-1",
        slotId: "slot-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        callMinute: null,
        wrapMinute: null,
        notes: "",
      ),
    ];
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        arrivalMinute: null,
        castCallMinute: null,
        castWrapMinute: null,
        notes: "",
      ),
    ];

    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: true, crew: crew, cast: cast)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    // No label field, no `⋮` menu, no `+` footers, no remove controls.
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text(tr.scheduleAddCrewMemberAction), findsNothing);
    expect(find.text(tr.scheduleAddCastAction), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    // The rows still read, though: nothing here withholds seeing who is convoked.
    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Marie"), findsOneWidget);
  });
}
