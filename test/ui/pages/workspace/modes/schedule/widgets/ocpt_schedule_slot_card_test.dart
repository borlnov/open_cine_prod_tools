// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_group.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
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
  String id = "slot-1",
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
}) => OcptShootingSlot(
  id: id,
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

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({required String id, required String slotId, String label = ""}) =>
    OcptShootingDayBlock(
      id: id,
      shootingDayId: "day-1",
      slotId: slotId,
      kind: OcptShootingBlockKind.preparation,
      shotId: null,
      sceneId: null,
      label: label,
      durationMinutes: null,
      anchorMinute: null,
      notes: "",
    );

/// A neutral `shotOf` resolving nothing, for tests that never place a shot block.
OcptShot? _noShot(String shotId) => null;

void main() {
  final person = _buildPerson(id: "person-1", firstName: "Léa");
  final role = _buildRole(id: "role-1", name: "Marie");

  Widget buildCard({
    required bool isReadOnly,
    String slotId = "slot-1",
    List<OcptShootingSlotCrewMember> crew = const [],
    List<OcptShootingSlotCastMember> cast = const [],
    List<OcptShootingDayGroup> groups = const [],
    OcptSlotConvocations? convocations,
    ValueChanged<String>? onCrewMemberAdded,
    ValueChanged<String>? onCastRoleAdded,
    VoidCallback? onDeletionRequested,
    String notesValue = "",
    ValueChanged<String>? onNotesChanged,
    VoidCallback? onMovedUp,
    VoidCallback? onMovedDown,
    void Function(String crewMemberId, int? leadMinutes)? onCrewMemberLeadChanged,
    void Function(String crewMemberId, String? groupId)? onCrewMemberGroupChanged,
    void Function(String castRoleId, int? leadMinutes)? onCastRoleLeadChanged,
    void Function(String castRoleId, String? groupId)? onCastRoleGroupChanged,
    List<OcptShootingDayBlock> blocks = const [],
    List<OcptSceneShotSequence> sequences = const [],
    List<(String, String)> otherSlots = const [],
    ValueChanged<OcptShootingBlockKind>? onBlockAdded,
    VoidCallback? onShotBlockRequested,
    void Function(String blockId, String targetSlotId)? onBlockMovedToSlot,
  }) => OcptScheduleSlotCard(
    slot: _buildSlot(id: slotId, crew: crew, cast: cast),
    location: null,
    set: null,
    locations: const [],
    personById: {person.id: person},
    roleById: {role.id: role},
    people: [person],
    roles: [role],
    groups: groups,
    convocations: convocations,
    labelValue: "Matin",
    onLabelChanged: isReadOnly ? null : (_) {},
    notesValue: notesValue,
    onNotesChanged: isReadOnly ? null : (onNotesChanged ?? (_) {}),
    onPlaceChanged: isReadOnly ? null : (_, _) {},
    onStartChanged: isReadOnly ? null : (_) {},
    onMovedUp: isReadOnly ? null : onMovedUp,
    onMovedDown: isReadOnly ? null : onMovedDown,
    onDeletionRequested: isReadOnly ? null : (onDeletionRequested ?? () {}),
    onCrewMemberAdded: isReadOnly ? null : (onCrewMemberAdded ?? (_) {}),
    onCrewMemberPositionChanged: isReadOnly ? null : (_, _) {},
    onCrewMemberRemoved: isReadOnly ? null : (_) {},
    onCrewMemberLeadChanged: isReadOnly ? null : (onCrewMemberLeadChanged ?? (_, _) {}),
    onCrewMemberGroupChanged: isReadOnly ? null : (onCrewMemberGroupChanged ?? (_, _) {}),
    onCastRoleAdded: isReadOnly ? null : (onCastRoleAdded ?? (_) {}),
    onCastRoleRemoved: isReadOnly ? null : (_) {},
    onCastRoleLeadChanged: isReadOnly ? null : (onCastRoleLeadChanged ?? (_, _) {}),
    onCastRoleGroupChanged: isReadOnly ? null : (onCastRoleGroupChanged ?? (_, _) {}),
    blocks: blocks,
    timeline: null,
    shotOf: _noShot,
    selectedBlockId: null,
    sequences: sequences,
    otherSlots: otherSlots,
    onBlockSelected: (_) {},
    onBlockReordered: isReadOnly ? null : (_, _) {},
    onBlockDurationChanged: isReadOnly ? null : (_, _) {},
    onBlockAnchorChanged: isReadOnly ? null : (_, _) {},
    onShotStatusChanged: isReadOnly ? null : (_, _) {},
    onBlockSequenceChanged: isReadOnly ? null : (_, _) {},
    onBlockDeletionRequested: isReadOnly ? null : (_) {},
    onBlockAdded: isReadOnly ? null : (onBlockAdded ?? (_) {}),
    onShotBlockRequested: isReadOnly ? null : (onShotBlockRequested ?? () {}),
    onBlockMovedToSlot: isReadOnly ? null : (onBlockMovedToSlot ?? (_, _) {}),
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

  testWidgets("a crew row reads its computed arrival and PAT band, never types into them", (
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
        leadMinutes: 30,
        notes: "",
      ),
    ];
    const convocations = OcptSlotConvocations(
      crew: [
        OcptCrewConvocation(
          id: "crew-1",
          arrivalMinute: 450,
          patStartMinute: 495,
          patEndMinute: 1080,
          leadMinutes: 30,
        ),
      ],
      cast: [],
    );

    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: false, crew: crew, convocations: convocations)),
    );
    await tester.pumpAndSettle();

    // The computed arrival (450 = 07:30) and PAT band (495 = 08:15, 1080 = 18:00) read out, as
    // plain read-only minute fields — nothing here is a `TextField` a crew row could be typed into.
    expect(find.text("07:30"), findsOneWidget);
    expect(find.text("08:15"), findsOneWidget);
    expect(find.text("18:00"), findsOneWidget);
    final crewMinuteFields = tester
        .widgetList<OcptScheduleMinuteField>(find.byType(OcptScheduleMinuteField))
        .where((field) => field.minute == 450 || field.minute == 495 || field.minute == 1080);
    expect(crewMinuteFields, hasLength(3));
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

  testWidgets("a crew row's own lead time reports what is typed into it", (tester) async {
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
    final reported = <(String, int?)>[];

    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: false,
          crew: crew,
          onCrewMemberLeadChanged: (crewMemberId, leadMinutes) =>
              reported.add((crewMemberId, leadMinutes)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The row's own lead (30) seeds the field's own editable text — found by that text, since the
    // card's own slot label field is a `TextField` too — and typing a new one reports it against
    // this row's id.
    final leadFieldFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == "30",
    );
    expect(leadFieldFinder, findsOneWidget);
    await tester.enterText(leadFieldFinder, "45");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(reported, [("crew-1", 45)]);
  });

  testWidgets("a cast row with no lead of its own shows its group's, marked inherited", (
    tester,
  ) async {
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        groupId: "group-1",
        leadMinutes: null,
        notes: "",
      ),
    ];
    const convocations = OcptSlotConvocations(
      crew: [],
      cast: [
        OcptCastConvocation(
          id: "cast-1",
          arrivalMinute: 435,
          patStartMinute: 510,
          patEndMinute: 900,
          leadMinutes: 60,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: false, cast: cast, convocations: convocations)),
    );
    await tester.pumpAndSettle();

    // Nothing was typed for this row (`leadMinutes: null`); the group's own resolved figure (60)
    // is shown as the field's own hint rather than as a value the row claims for itself.
    final leadField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == "60",
      ),
    );
    expect(leadField.controller?.text, "");
  });

  testWidgets("a crew row's own group picker offers the day's groups and reports the one picked", (
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
    const groups = [
      OcptShootingDayGroup(id: "group-1", shootingDayId: "day-1", label: "Figuration", leadMinutes: 90),
    ];
    final reported = <(String, String?)>[];

    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: false,
          crew: crew,
          groups: groups,
          onCrewMemberGroupChanged: (crewMemberId, groupId) => reported.add((crewMemberId, groupId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    // No group picked yet: the button's own current label is "No group", unique on screen before
    // the menu opens (the group's own distinct label appears only once the menu is up).
    await tester.tap(find.text(tr.scheduleGroupNoGroupOption));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Figuration"));
    await tester.pumpAndSettle();

    expect(reported, [("crew-1", "group-1")]);
  });

  testWidgets("picking `No group` on a row already in one clears it back to none", (tester) async {
    final crew = [
      const OcptShootingSlotCrewMember(
        id: "crew-1",
        slotId: "slot-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        groupId: "group-1",
        leadMinutes: null,
        notes: "",
      ),
    ];
    const groups = [
      OcptShootingDayGroup(id: "group-1", shootingDayId: "day-1", label: "Figuration", leadMinutes: 90),
    ];
    final reported = <(String, String?)>[];

    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: false,
          crew: crew,
          groups: groups,
          onCrewMemberGroupChanged: (crewMemberId, groupId) => reported.add((crewMemberId, groupId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    // The row already belongs to "Figuration", so that is its button's own current label — unique
    // before the menu opens.
    await tester.tap(find.text("Figuration"));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleGroupNoGroupOption).last);
    await tester.pumpAndSettle();

    expect(reported, [("crew-1", null)]);
  });

  testWidgets("every crew and cast row's own lead field and group picker are withheld read-only", (
    tester,
  ) async {
    final crew = [
      const OcptShootingSlotCrewMember(
        id: "crew-1",
        slotId: "slot-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        groupId: "group-1",
        leadMinutes: 15,
        notes: "",
      ),
    ];
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        groupId: null,
        leadMinutes: 20,
        notes: "",
      ),
    ];
    const groups = [
      OcptShootingDayGroup(id: "group-1", shootingDayId: "day-1", label: "Figuration", leadMinutes: 90),
    ];

    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: true, crew: crew, cast: cast, groups: groups)),
    );
    await tester.pumpAndSettle();

    // Both figures still read out (plain text, own values), but nothing here is a `TextField`, and
    // the group picker reads as plain text rather than a `PopupMenuButton`.
    expect(find.text("15 min"), findsOneWidget);
    expect(find.text("20 min"), findsOneWidget);
    expect(find.text("Figuration"), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
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
      crew: [
        OcptCrewConvocation(
          id: "crew-1",
          arrivalMinute: 480,
          patStartMinute: 480,
          patEndMinute: 1080,
          leadMinutes: 0,
        ),
      ],
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

    final block = _buildBlock(id: "block-1", slotId: "slot-1", label: "Prep");

    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: true,
          crew: crew,
          cast: cast,
          blocks: [block],
          notesValue: "Parking derrière l'église",
          onMovedUp: () {},
          onMovedDown: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    // No label field, no `⋮` menu, no `+` footers, no remove controls, and not even the slot's own
    // start is editable while read-only — and its own timetable withholds every one of its own
    // writing affordances too: no `+ Block` control and no `Move to…` control.
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text(tr.scheduleAddCrewMemberAction), findsNothing);
    expect(find.text(tr.scheduleAddCastAction), findsNothing);
    expect(find.text(tr.scheduleAddBlockAction), findsNothing);
    expect(find.byIcon(Icons.drive_file_move_outline), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    final editableFields = tester
        .widgetList<OcptScheduleMinuteField>(find.byType(OcptScheduleMinuteField))
        .where((field) => field.onChanged != null);
    expect(editableFields, isEmpty);
    // The slot cannot be moved in its day's list either, both controls being withheld with the
    // rest.
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    // The rows still read, though: nothing here withholds seeing who is convoked, which blocks
    // are placed, or what the slot's own note says.
    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Marie"), findsOneWidget);
    expect(find.text("Prep"), findsOneWidget);
    expect(find.text("Parking derrière l'église"), findsOneWidget);
  });

  testWidgets("a slot card shows only its own blocks, none of another slot's", (tester) async {
    final ownBlock = _buildBlock(id: "block-own", slotId: "slot-1", label: "Prep");
    final otherBlock = _buildBlock(id: "block-other", slotId: "slot-2", label: "Repas");

    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: false, blocks: [ownBlock, otherBlock])),
    );
    await tester.pumpAndSettle();

    expect(find.text("Prep"), findsOneWidget);
    expect(find.text("Repas"), findsNothing);
  });

  testWidgets("the `+ Block` menu names the slot the card sits on", (tester) async {
    final addedOnSlotOne = <OcptShootingBlockKind>[];
    final addedOnSlotTwo = <OcptShootingBlockKind>[];

    await tester.pumpWidget(
      _wrapInApp(
        SingleChildScrollView(
          child: Column(
            children: [
              buildCard(isReadOnly: false, onBlockAdded: addedOnSlotOne.add),
              buildCard(isReadOnly: false, slotId: "slot-2", onBlockAdded: addedOnSlotTwo.add),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard).first));
    // Two cards, each with their own `+ Block` control — tapping the first one's must only ever
    // reach the callback that card itself was built with, never the second card's.
    await tester.tap(find.text(tr.scheduleAddBlockAction).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleBlockKindMeal).last);
    await tester.pumpAndSettle();

    expect(addedOnSlotOne, [OcptShootingBlockKind.meal]);
    expect(addedOnSlotTwo, isEmpty);
  });

  testWidgets(
    "both people halves show by default and fold together on either title",
    (tester) async {
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
      final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
      final crewTitle = find.text(tr.scheduleSlotCrewColumnTitle.toUpperCase());
      final castTitle = find.text(tr.scheduleSlotCastColumnTitle.toUpperCase());

      // Expanded by default: both halves show their cards and their own footer, and each title
      // already says how many people it holds.
      expect(find.text("Léa"), findsOneWidget);
      expect(find.text("Marie"), findsOneWidget);
      expect(find.text(tr.scheduleAddCrewMemberAction), findsOneWidget);
      expect(find.text(tr.scheduleAddCastAction), findsOneWidget);
      expect(find.text(tr.scheduleSlotPeopleCount(1)), findsNWidgets(2));

      // A tap on the **cast** title folds the crew half away with it: the two halves share one
      // fold, so either title answers for both.
      await tester.tap(castTitle);
      await tester.pumpAndSettle();

      expect(find.text("Léa"), findsNothing);
      expect(find.text("Marie"), findsNothing);
      expect(find.text(tr.scheduleAddCrewMemberAction), findsNothing);
      expect(find.text(tr.scheduleAddCastAction), findsNothing);
      expect(find.text(tr.scheduleSlotPeopleCount(1)), findsNWidgets(2));

      // And a tap on the **crew** title brings both back.
      await tester.tap(crewTitle);
      await tester.pumpAndSettle();

      expect(find.text("Léa"), findsOneWidget);
      expect(find.text("Marie"), findsOneWidget);
      expect(find.text(tr.scheduleAddCrewMemberAction), findsOneWidget);
      expect(find.text(tr.scheduleAddCastAction), findsOneWidget);
    },
  );

  testWidgets("the note field reports what is typed into it, below the location line", (
    tester,
  ) async {
    final typed = <String>[];

    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: false, onNotesChanged: typed.add)),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    final noteField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == tr.scheduleSlotNotesHint,
    );
    expect(noteField, findsOneWidget);

    await tester.enterText(noteField, "Parking derrière l'église");
    await tester.pumpAndSettle();

    expect(typed, ["Parking derrière l'église"]);
  });

  testWidgets("the `▲`/`▼` controls report the position the slot moves to", (tester) async {
    var movedUp = 0;
    var movedDown = 0;

    await tester.pumpWidget(
      _wrapInApp(
        buildCard(isReadOnly: false, onMovedUp: () => movedUp++, onMovedDown: () => movedDown++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(movedUp, 1);
    expect(movedDown, 1);
  });

  testWidgets("the `▲` control is drawn but disabled when the slot cannot move up", (tester) async {
    await tester.pumpWidget(
      _wrapInApp(buildCard(isReadOnly: false, onMovedDown: () {})),
    );
    await tester.pumpAndSettle();

    // Both controls are drawn as soon as one of them leads anywhere: a column of cards whose
    // arrows come and go is harder to aim at than one greyed arrow.
    final upButton = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(Icons.keyboard_arrow_up), matching: find.byType(IconButton)),
    );
    expect(upButton.onPressed, isNull);
    final downButton = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(Icons.keyboard_arrow_down), matching: find.byType(IconButton)),
    );
    expect(downButton.onPressed, isNotNull);
  });
}
