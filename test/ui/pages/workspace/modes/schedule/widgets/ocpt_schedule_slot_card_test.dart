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
    ValueChanged<String>? onCrewMemberAdded,
    ValueChanged<String>? onCastRoleAdded,
    VoidCallback? onDeletionRequested,
    String notesValue = "",
    ValueChanged<String>? onNotesChanged,
    VoidCallback? onMovedUp,
    VoidCallback? onMovedDown,
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
    onCastRoleAdded: isReadOnly ? null : (onCastRoleAdded ?? (_) {}),
    onCastRoleRemoved: isReadOnly ? null : (_) {},
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

  testWidgets("the card offers exactly one editable minute field: the slot's own start", (
    tester,
  ) async {
    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false)));
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
