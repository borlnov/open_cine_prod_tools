// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_prefill.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

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

/// Builds a slot with the few fields these tests read, everything else neutral — anchored by its
/// start at 08:00 unless a test says otherwise.
OcptShootingSlot _buildSlot({
  String id = "slot-1",
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
  List<OcptShootingSlotGuest> guests = const [],
  OcptShootingSlotAnchorEdge anchorEdge = OcptShootingSlotAnchorEdge.start,
  int? anchorMinute = 480,
  String? anchorSlotId,
}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: "Matin",
  locationId: null,
  setId: null,
  anchorEdge: anchorEdge,
  anchorMinute: anchorMinute,
  anchorSlotId: anchorSlotId,
  notes: "",
  crew: crew,
  cast: cast,
  guests: guests,
);

/// Builds a person with the few fields these tests read, everything else neutral.
OcptPerson _buildPerson({
  required String id,
  required String firstName,
  List<OcptPersonPosition> positions = const [],
}) => OcptPerson(
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
  positions: positions,
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
      crewNote: "",
    );

/// A neutral `shotOf` resolving nothing, for tests that never place a shot block.
OcptShot? _noShot(String shotId) => null;

/// Builds a guest attendance with the few fields these tests read, everything else neutral.
OcptShootingSlotGuest _buildGuest({
  required String id,
  String slotId = "slot-1",
  String? personId,
  String freeName = "",
  String reason = "",
  String notes = "",
}) => OcptShootingSlotGuest(
  id: id,
  slotId: slotId,
  personId: personId,
  freeName: freeName,
  reason: reason,
  notes: notes,
);

void main() {
  final person = _buildPerson(id: "person-1", firstName: "Léa");
  final role = _buildRole(id: "role-1", name: "Marie");

  Widget buildCard({
    required bool isReadOnly,
    String slotId = "slot-1",
    OcptPerson? crewPerson,
    List<OcptShootingSlotCrewMember> crew = const [],
    List<OcptShootingSlotCastMember> cast = const [],
    List<OcptShootingSlotGuest> guests = const [],
    ValueChanged<String>? onCrewMemberAdded,
    void Function(String crewMemberId, OcptCrewPositionRef position)?
    onCrewMemberPositionChanged,
    ValueChanged<String>? onCastRoleAdded,
    ValueChanged<String>? onGuestAdded,
    ValueChanged<String>? onGuestRemoved,
    String Function(String guestId)? guestReasonValueOf,
    void Function(String guestId, String rawValue)? onGuestReasonChanged,
    String Function(String guestId)? guestNotesValueOf,
    void Function(String guestId, String rawValue)? onGuestNotesChanged,
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
    OcptShootingSlotAnchorEdge anchorEdge = OcptShootingSlotAnchorEdge.start,
    int? anchorMinute = 480,
    String? anchorSlotId,
    Map<String, String?> anchorSourceBySlotId = const {},
    OcptShootingSlotTimeline? timeline,
    void Function(OcptShootingSlotAnchorEdge edge, int? minute, String? sourceSlotId)?
    onAnchorChanged,
  }) => OcptScheduleSlotCard(
    slot: _buildSlot(
      id: slotId,
      crew: crew,
      cast: cast,
      guests: guests,
      anchorEdge: anchorEdge,
      anchorMinute: anchorMinute,
      anchorSlotId: anchorSlotId,
    ),
    location: null,
    set: null,
    locations: const [],
    personById: {(crewPerson ?? person).id: crewPerson ?? person},
    roleById: {role.id: role},
    people: [crewPerson ?? person],
    roles: [role],
    labelValue: "Matin",
    onLabelChanged: isReadOnly ? null : (_) {},
    notesValue: notesValue,
    onNotesChanged: isReadOnly ? null : (onNotesChanged ?? (_) {}),
    onPlaceChanged: isReadOnly ? null : (_, _) {},
    onAnchorChanged: isReadOnly ? null : (onAnchorChanged ?? (_, _, _) {}),
    anchorSourceBySlotId: anchorSourceBySlotId,
    onMovedUp: isReadOnly ? null : onMovedUp,
    onMovedDown: isReadOnly ? null : onMovedDown,
    onDeletionRequested: isReadOnly ? null : (onDeletionRequested ?? () {}),
    onCrewMemberAdded: isReadOnly ? null : (onCrewMemberAdded ?? (_) {}),
    onCrewMemberPositionChanged: isReadOnly ? null : (onCrewMemberPositionChanged ?? (_, _) {}),
    onCrewMemberRemoved: isReadOnly ? null : (_) {},
    onCastRoleAdded: isReadOnly ? null : (onCastRoleAdded ?? (_) {}),
    onCastRoleRemoved: isReadOnly ? null : (_) {},
    onGuestAdded: isReadOnly ? null : (onGuestAdded ?? (_) {}),
    onGuestRemoved: isReadOnly ? null : (onGuestRemoved ?? (_) {}),
    guestReasonValueOf: guestReasonValueOf ?? (_) => "",
    onGuestReasonChanged: isReadOnly ? null : (onGuestReasonChanged ?? (_, _) {}),
    guestNotesValueOf: guestNotesValueOf ?? (_) => "",
    onGuestNotesChanged: isReadOnly ? null : (onGuestNotesChanged ?? (_, _) {}),
    blocks: blocks,
    timeline: timeline,
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
        notes: "",
      ),
    ];
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
        notes: "",
      ),
    ];

    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false, crew: crew, cast: cast)));
    await tester.pumpAndSettle();

    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Marie"), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets(
    "the crew row's position picker promotes the person's declared positions above the catalogue",
    (tester) async {
      final crewPerson = _buildPerson(
        id: "person-1",
        firstName: "Léa",
        positions: const [
          OcptPersonPosition(
            id: "pp-1",
            personId: "person-1",
            positionId: "director",
            customLabel: "",
          ),
        ],
      );
      final crew = [
        const OcptShootingSlotCrewMember(
          id: "crew-1",
          slotId: "slot-1",
          personId: "person-1",
          positionId: "",
          customLabel: "",
          notes: "",
        ),
      ];

      await tester.pumpWidget(
        _wrapInApp(buildCard(isReadOnly: false, crewPerson: crewPerson, crew: crew)),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
      await tester.tap(find.text(tr.scheduleSlotCrewPositionPlaceholder));
      await tester.pumpAndSettle();

      final menuItems = tester.widgetList<PopupMenuItem<OcptCrewPositionRef>>(
        find.byType(PopupMenuItem<OcptCrewPositionRef>),
      );
      // The person's own declared position, promoted ahead of every catalogue entry, including
      // the catalogue's own "director" one.
      expect(
        menuItems.first.value,
        const OcptCrewPositionRef(positionId: "director", customLabel: ""),
      );
      expect(find.byType(PopupMenuDivider), findsOneWidget);
    },
  );

  testWidgets(
    "the picker never offers a position that person already holds on that slot",
    (tester) async {
      final crewPerson = _buildPerson(
        id: "person-1",
        firstName: "Léa",
        positions: const [
          OcptPersonPosition(
            id: "pp-1",
            personId: "person-1",
            positionId: "director",
            customLabel: "",
          ),
          OcptPersonPosition(
            id: "pp-2",
            personId: "person-1",
            positionId: "boomOperator",
            customLabel: "",
          ),
        ],
      );
      final crew = [
        // Already holds "director" on this slot.
        const OcptShootingSlotCrewMember(
          id: "crew-1",
          slotId: "slot-1",
          personId: "person-1",
          positionId: "director",
          customLabel: "",
          notes: "",
        ),
        // The blank row whose picker is under test.
        const OcptShootingSlotCrewMember(
          id: "crew-2",
          slotId: "slot-1",
          personId: "person-1",
          positionId: "",
          customLabel: "",
          notes: "",
        ),
      ];

      await tester.pumpWidget(
        _wrapInApp(buildCard(isReadOnly: false, crewPerson: crewPerson, crew: crew)),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
      await tester.tap(find.text(tr.scheduleSlotCrewPositionPlaceholder));
      await tester.pumpAndSettle();

      final menuItems = tester.widgetList<PopupMenuItem<OcptCrewPositionRef>>(
        find.byType(PopupMenuItem<OcptCrewPositionRef>),
      );
      // "Director" is already held on this slot — absent everywhere, promoted block and
      // catalogue alike — while "boomOperator", still free, is promoted.
      expect(
        menuItems.map((item) => item.value),
        isNot(contains(const OcptCrewPositionRef(positionId: "director", customLabel: ""))),
      );
      expect(
        menuItems.first.value,
        const OcptCrewPositionRef(positionId: "boomOperator", customLabel: ""),
      );
    },
  );

  testWidgets(
    "picking a declared free-label entry reports a ref carrying that label",
    (tester) async {
      final crewPerson = _buildPerson(
        id: "person-1",
        firstName: "Léa",
        positions: const [
          OcptPersonPosition(id: "pp-1", personId: "person-1", positionId: "", customLabel: "Rigger"),
        ],
      );
      final crew = [
        const OcptShootingSlotCrewMember(
          id: "crew-1",
          slotId: "slot-1",
          personId: "person-1",
          positionId: "",
          customLabel: "",
          notes: "",
        ),
      ];
      final reported = <(String, OcptCrewPositionRef)>[];

      await tester.pumpWidget(
        _wrapInApp(
          buildCard(
            isReadOnly: false,
            crewPerson: crewPerson,
            crew: crew,
            onCrewMemberPositionChanged: (crewMemberId, position) =>
                reported.add((crewMemberId, position)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
      await tester.tap(find.text(tr.scheduleSlotCrewPositionPlaceholder));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Rigger"));
      await tester.pumpAndSettle();

      expect(reported, [("crew-1", const OcptCrewPositionRef(positionId: "", customLabel: "Rigger"))]);
    },
  );

  testWidgets(
    "a read-only crew row shows its position as plain text, with no picker",
    (tester) async {
      final crew = [
        const OcptShootingSlotCrewMember(
          id: "crew-1",
          slotId: "slot-1",
          personId: "person-1",
          positionId: "director",
          customLabel: "",
          notes: "",
        ),
      ];

      await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: true, crew: crew)));
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
      expect(find.text(ocptCrewPositionLabel(tr, "director")), findsOneWidget);
      expect(find.byType(PopupMenuButton<OcptCrewPositionRef>), findsNothing);
    },
  );

  testWidgets("the card offers exactly one editable minute field: the slot's own anchor", (
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

  testWidgets("the anchor control names the pinned edge and reads the other one out", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: false,
          anchorEdge: OcptShootingSlotAnchorEdge.end,
          anchorMinute: 1080,
          timeline: const OcptShootingSlotTimeline(
            entries: [],
            overruns: [],
            startMinute: 900,
            endMinute: 1080,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    expect(find.text(tr.scheduleSlotEndLabel), findsOneWidget);
    // The opposite edge is computed, never typed: it is read out under the pinned one.
    expect(find.text("${tr.scheduleSlotStartLabel} 15:00"), findsOneWidget);
  });

  testWidgets("a linked edge carries its whole sentence and no editable minute field", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: false,
          anchorMinute: null,
          anchorSlotId: "slot-2",
          otherSlots: const [("slot-2", "Prépa")],
          anchorSourceBySlotId: const {"slot-1": "slot-2", "slot-2": null},
          timeline: const OcptShootingSlotTimeline(
            entries: [],
            overruns: [],
            startMinute: 600,
            endMinute: 720,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    expect(find.text(tr.scheduleSlotAnchorStartFromSlot("Prépa")), findsOneWidget);
    expect(
      tester
          .widgetList<OcptScheduleMinuteField>(find.byType(OcptScheduleMinuteField))
          .where((field) => field.onChanged != null),
      isEmpty,
    );
  });

  testWidgets("picking a fixed-hour entry freezes the hour the edge was reading", (tester) async {
    OcptShootingSlotAnchorEdge? pickedEdge;
    int? pickedMinute;
    String? pickedSourceSlotId;

    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: false,
          anchorMinute: null,
          anchorSlotId: "slot-2",
          otherSlots: const [("slot-2", "Prépa")],
          anchorSourceBySlotId: const {"slot-1": "slot-2", "slot-2": null},
          timeline: const OcptShootingSlotTimeline(
            entries: [],
            overruns: [],
            startMinute: 600,
            endMinute: 720,
          ),
          onAnchorChanged: (edge, minute, sourceSlotId) {
            pickedEdge = edge;
            pickedMinute = minute;
            pickedSourceSlotId = sourceSlotId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleSlotAnchorStartFromSlot("Prépa")));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.scheduleSlotAnchorStartFixed));
    await tester.pumpAndSettle();

    expect(pickedEdge, OcptShootingSlotAnchorEdge.start);
    expect(pickedMinute, 600);
    expect(pickedSourceSlotId, isNull);
  });

  testWidgets("an anchor entry that would close a circle is shown disabled, with its reason", (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: false,
          otherSlots: const [("slot-2", "Prépa")],
          // slot-2 already reads slot-1's own edge, so slot-1 reading slot-2's would close the
          // circle both directions of that entry would build.
          anchorSourceBySlotId: const {"slot-1": null, "slot-2": "slot-1"},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleSlotStartLabel));
    await tester.pumpAndSettle();

    // Shown rather than left out — in a menu this short, a missing entry reads as a bug — and
    // greyed, with the reason under it, in both directions the link could have been read in.
    expect(find.text(tr.scheduleSlotAnchorStartFromSlot("Prépa")), findsOneWidget);
    expect(find.text(tr.scheduleSlotAnchorEndFromSlot("Prépa")), findsOneWidget);
    expect(find.text(tr.scheduleSlotAnchorCycleReason), findsNWidgets(2));
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem && !widget.enabled),
      findsNWidgets(2),
    );
  });

  testWidgets("every writing affordance is withheld when the mode is read-only", (tester) async {
    final crew = [
      const OcptShootingSlotCrewMember(
        id: "crew-1",
        slotId: "slot-1",
        personId: "person-1",
        positionId: "director",
        customLabel: "",
        notes: "",
      ),
    ];
    final cast = [
      const OcptShootingSlotCastMember(
        id: "cast-1",
        slotId: "slot-1",
        roleId: "role-1",
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
    "the three kinds of person show by default and fold together on the section's own title",
    (tester) async {
      final crew = [
        const OcptShootingSlotCrewMember(
          id: "crew-1",
          slotId: "slot-1",
          personId: "person-1",
          positionId: "director",
          customLabel: "",
          notes: "",
        ),
      ];
      final cast = [
        const OcptShootingSlotCastMember(
          id: "cast-1",
          slotId: "slot-1",
          roleId: "role-1",
          notes: "",
        ),
      ];

      await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false, crew: crew, cast: cast)));
      await tester.pumpAndSettle();
      final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
      final sectionTitle = find.text(tr.scheduleSlotPeopleSectionTitle.toUpperCase());

      // Expanded by default: the three kinds show their cards and their own footer, each kind's own
      // title says how many it holds, and the section's own title counts the three together.
      expect(find.text("Léa"), findsOneWidget);
      expect(find.text("Marie"), findsOneWidget);
      expect(find.text(tr.scheduleAddCrewMemberAction), findsOneWidget);
      expect(find.text(tr.scheduleAddCastAction), findsOneWidget);
      expect(find.text(tr.scheduleAddGuestAction), findsOneWidget);
      expect(find.text(tr.scheduleSlotPeopleCount(1)), findsNWidgets(2));
      expect(find.text(tr.scheduleSlotPeopleCount(2)), findsOneWidget);

      // A tap on the section's own title folds the three of them away at once.
      await tester.tap(sectionTitle);
      await tester.pumpAndSettle();

      expect(find.text("Léa"), findsNothing);
      expect(find.text("Marie"), findsNothing);
      expect(find.text(tr.scheduleAddCrewMemberAction), findsNothing);
      expect(find.text(tr.scheduleAddCastAction), findsNothing);
      expect(find.text(tr.scheduleAddGuestAction), findsNothing);
      expect(find.text(tr.scheduleSlotPeopleCount(2)), findsOneWidget);

      // And a second tap brings the three back.
      await tester.tap(sectionTitle);
      await tester.pumpAndSettle();

      expect(find.text("Léa"), findsOneWidget);
      expect(find.text("Marie"), findsOneWidget);
      expect(find.text(tr.scheduleAddCrewMemberAction), findsOneWidget);
      expect(find.text(tr.scheduleAddCastAction), findsOneWidget);
      expect(find.text(tr.scheduleAddGuestAction), findsOneWidget);
    },
  );

  testWidgets("neither the crew nor the cast title folds its own half", (tester) async {
    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));

    // The one fold on the card is the section's own: the three kinds' titles are plain read-outs,
    // so tapping one changes nothing at all.
    await tester.tap(find.text(tr.scheduleSlotCrewColumnTitle.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr.scheduleAddCrewMemberAction), findsOneWidget);

    await tester.tap(find.text(tr.scheduleSlotCastColumnTitle.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.text(tr.scheduleAddCastAction), findsOneWidget);
  });

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

  testWidgets("a slot with no guest still draws its guest band, its hint and its footer", (
    tester,
  ) async {
    await tester.pumpWidget(_wrapInApp(buildCard(isReadOnly: false)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    expect(find.text(tr.scheduleSlotGuestsColumnTitle.toUpperCase()), findsOneWidget);
    expect(find.text(tr.scheduleSlotGuestsEmptyHint), findsOneWidget);
    expect(find.text(tr.scheduleAddGuestAction), findsOneWidget);
  });

  testWidgets("a slot with one guest draws its name, its reason and its remove control", (
    tester,
  ) async {
    final guests = [
      _buildGuest(id: "guest-1", personId: "person-1", reason: "Visite guidée"),
    ];

    await tester.pumpWidget(
      _wrapInApp(
        buildCard(
          isReadOnly: false,
          guests: guests,
          guestReasonValueOf: (_) => "Visite guidée",
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    expect(find.text(tr.scheduleSlotGuestsColumnTitle.toUpperCase()), findsOneWidget);
    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Visite guidée"), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets(
    "with every callback null (a version preview) the remove control and the footer are gone",
    (tester) async {
      final guests = [
        _buildGuest(id: "guest-1", personId: "person-1", reason: "Visite guidée"),
      ];

      await tester.pumpWidget(
        _wrapInApp(
          buildCard(isReadOnly: true, guests: guests, guestReasonValueOf: (_) => "Visite guidée"),
        ),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
      // The band itself still reads — its title, the guest's own name and reason — since a stored
      // guest is never hidden, only the affordances that would change something.
      expect(find.text(tr.scheduleSlotGuestsColumnTitle.toUpperCase()), findsOneWidget);
      expect(find.text("Léa"), findsOneWidget);
      expect(find.text("Visite guidée"), findsOneWidget);
      expect(find.text(tr.scheduleAddGuestAction), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );
}
