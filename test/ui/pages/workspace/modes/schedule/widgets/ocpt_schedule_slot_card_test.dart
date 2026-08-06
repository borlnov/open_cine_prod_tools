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
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';

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
  startMinute: 480,
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
    OcptSlotConvocations? convocations,
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
    convocations: convocations,
    labelValue: "Matin",
    onLabelChanged: isReadOnly ? null : (_) {},
    onPlaceChanged: isReadOnly ? null : (_, _) {},
    onStartChanged: isReadOnly ? null : (_) {},
    onDeletionRequested: isReadOnly ? null : (onDeletionRequested ?? () {}),
    onCrewMemberAdded: isReadOnly ? null : (onCrewMemberAdded ?? (_) {}),
    onCrewMemberPositionChanged: isReadOnly ? null : (_, _) {},
    onCrewMemberRemoved: isReadOnly ? null : (_) {},
    onCastRoleAdded: isReadOnly ? null : (onCastRoleAdded ?? (_) {}),
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
        groupId: null,
        leadMinutes: null,
        notes: "",
      ),
    ];
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        groupId: null,
        leadMinutes: null,
        notes: "",
      ),
    ];

    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false, crew: crew, cast: cast)));
    await tester.pumpAndSettle();

    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Marie"), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets("a crew row reads its computed call and wrap, never types into them", (tester) async {
    final crew = [
      const OcptShootingSlotCrewMember(
        id: "crew-1",
        slotId: "slot-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        groupId: null,
        leadMinutes: 30,
        notes: "",
      ),
    ];
    const convocations = OcptSlotConvocations(
      crew: [
        OcptCrewConvocation(id: "crew-1", callMinute: 450, wrapMinute: 1080, leadMinutes: 30),
      ],
      cast: [],
    );

    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: false, crew: crew, convocations: convocations)),
    );
    await tester.pumpAndSettle();

    // The computed call (450 = 07:30) and wrap (1080 = 18:00) read out, as plain read-only minute
    // fields — nothing here is a `TextField` a crew row could be typed into.
    expect(find.text("07:30"), findsOneWidget);
    expect(find.text("18:00"), findsOneWidget);
    final crewMinuteFields = tester
        .widgetList<OcptScheduleMinuteField>(find.byType(OcptScheduleMinuteField))
        .where((field) => field.minute == 450 || field.minute == 1080);
    expect(crewMinuteFields, everyElement(predicate<OcptScheduleMinuteField>((f) => f.onChanged == null)));
  });

  testWidgets("a cast row reads its computed arrival and PAT band, never types into them", (
    tester,
  ) async {
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        groupId: null,
        leadMinutes: 45,
        notes: "",
      ),
    ];
    const convocations = OcptSlotConvocations(
      crew: [],
      cast: [
        OcptCastConvocation(
          id: "cast-1",
          arrivalMinute: 435,
          // Deliberately not the slot's own 480 (08:00) start minute (also shown on the card, as
          // the one editable field), so a match on the PAT start's own text can't be confused with
          // it.
          patStartMinute: 510,
          patEndMinute: 900,
          leadMinutes: 45,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: false, cast: cast, convocations: convocations)),
    );
    await tester.pumpAndSettle();

    // Arrival (435 = 07:15), PAT start (510 = 08:30) and PAT end (900 = 15:00) all read out.
    expect(find.text("07:15"), findsOneWidget);
    expect(find.text("08:30"), findsOneWidget);
    expect(find.text("15:00"), findsOneWidget);
    final castMinuteFields = tester
        .widgetList<OcptScheduleMinuteField>(find.byType(OcptScheduleMinuteField))
        .where((field) => field.minute == 435 || field.minute == 510 || field.minute == 900);
    expect(castMinuteFields, everyElement(predicate<OcptScheduleMinuteField>((f) => f.onChanged == null)));
  });

  testWidgets("the card offers exactly one editable minute field: the slot's own start", (
    tester,
  ) async {
    final crew = [
      const OcptShootingSlotCrewMember(
        id: "crew-1",
        slotId: "slot-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        groupId: null,
        leadMinutes: null,
        notes: "",
      ),
    ];
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        groupId: null,
        leadMinutes: null,
        notes: "",
      ),
    ];
    const convocations = OcptSlotConvocations(
      crew: [OcptCrewConvocation(id: "crew-1", callMinute: 480, wrapMinute: 1080, leadMinutes: 0)],
      cast: [
        OcptCastConvocation(
          id: "cast-1",
          arrivalMinute: 480,
          patStartMinute: 480,
          patEndMinute: 1080,
          leadMinutes: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: false, crew: crew, cast: cast, convocations: convocations)),
    );
    await tester.pumpAndSettle();

    final editableFields = tester
        .widgetList<OcptScheduleMinuteField>(find.byType(OcptScheduleMinuteField))
        .where((field) => field.onChanged != null);
    expect(editableFields, hasLength(1));
    expect(editableFields.single.minute, 480);
  });

  testWidgets("every writing affordance is withheld when the mode is read-only", (tester) async {
    final crew = [
      const OcptShootingSlotCrewMember(
        id: "crew-1",
        slotId: "slot-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        groupId: null,
        leadMinutes: null,
        notes: "",
      ),
    ];
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        groupId: null,
        leadMinutes: null,
        notes: "",
      ),
    ];

    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: true, crew: crew, cast: cast)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    // No label field, no `⋮` menu, no `+` footers, no remove controls, and not even the slot's own
    // start is editable while read-only.
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text(tr.scheduleAddCrewMemberAction), findsNothing);
    expect(find.text(tr.scheduleAddCastAction), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    final editableFields = tester
        .widgetList<OcptScheduleMinuteField>(find.byType(OcptScheduleMinuteField))
        .where((field) => field.onChanged != null);
    expect(editableFields, isEmpty);
    // The rows still read, though: nothing here withholds seeing who is convoked.
    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Marie"), findsOneWidget);
  });
}
