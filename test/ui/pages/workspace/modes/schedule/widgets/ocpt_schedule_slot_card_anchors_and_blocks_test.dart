// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_crew_position_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'ocpt_schedule_slot_card_test_doubles.dart';

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
  final person = buildPerson(id: "person-1", firstName: "Léa");

  final role = buildRole(id: "role-1", name: "Marie");

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }
    managers.registerSingleton<OcptRouterManager>(RecordingRouterManager());
  });

  Widget buildCard({
    required bool isReadOnly,
    String slotId = "slot-1",
    OcptPerson? crewPerson,
    List<OcptShootingSlotCrewMember> crew = const [],
    List<OcptShootingSlotCastMember> cast = const [],
    List<OcptShootingSlotGuest> guests = const [],
    List<OcptRole>? roles,
    ValueChanged<String>? onCrewMemberAdded,
    void Function(String crewMemberId, OcptCrewPositionRef position)? onCrewMemberPositionChanged,
    ValueChanged<String>? onCastRoleAdded,
    ValueChanged<String>? onGuestAdded,
    ValueChanged<String>? onGuestRemoved,
    Map<String, OcptRoleCandidate> roleCandidateById = const {},
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
    slot: buildSlot(
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
    roleById: {
      for (final castRole in roles ?? [role]) castRole.id: castRole,
    },
    roleCandidateById: roleCandidateById,
    people: [crewPerson ?? person],
    roles: roles ?? [role],
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
    shotOf: noShot,
    selectedBlockId: null,
    sequences: sequences,
    otherSlots: otherSlots,
    onBlockSelected: (_) {},
    onBlockReordered: isReadOnly ? null : (_, _) {},
    onBlockDurationChanged: isReadOnly ? null : (_, _) {},
    onBlockAnchorChanged: isReadOnly ? null : (_, _) {},
    onShotStatusChanged: isReadOnly ? null : (_, _) {},
    onBlockSequenceChanged: isReadOnly ? null : (_, _) {},
    onBlockCandidateAdded: isReadOnly ? null : (_, _) {},
    onBlockCandidateRemoved: isReadOnly ? null : (_) {},
    onBlockDeletionRequested: isReadOnly ? null : (_) {},
    onBlockAdded: isReadOnly ? null : (onBlockAdded ?? (_) {}),
    onShotBlockRequested: isReadOnly ? null : (onShotBlockRequested ?? () {}),
    onBlockMovedToSlot: isReadOnly ? null : (onBlockMovedToSlot ?? (_, _) {}),
  );

  testWidgets("an anchor entry that would close a circle is shown disabled, with its reason", (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapInApp(
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
      const OcptShootingSlotCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1", notes: ""),
    ];

    final block = buildBlock(id: "block-1", slotId: "slot-1", label: "Prep");

    await tester.pumpWidget(
      wrapInApp(
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
    final ownBlock = buildBlock(id: "block-own", slotId: "slot-1", label: "Prep");
    final otherBlock = buildBlock(id: "block-other", slotId: "slot-2", label: "Repas");

    await tester.pumpWidget(
      wrapInApp(buildCard(isReadOnly: false, blocks: [ownBlock, otherBlock])),
    );
    await tester.pumpAndSettle();

    expect(find.text("Prep"), findsOneWidget);
    expect(find.text("Repas"), findsNothing);
  });

  testWidgets("the `+ Block` menu names the slot the card sits on", (tester) async {
    final addedOnSlotOne = <OcptShootingBlockKind>[];
    final addedOnSlotTwo = <OcptShootingBlockKind>[];

    await tester.pumpWidget(
      wrapInApp(
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

      await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false, crew: crew, cast: cast)));
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
    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false)));
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

    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false, onNotesChanged: typed.add)));
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
      wrapInApp(
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
    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false, onMovedDown: () {})));
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
    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    expect(find.text(tr.scheduleSlotGuestsColumnTitle.toUpperCase()), findsOneWidget);
    expect(find.text(tr.scheduleSlotGuestsEmptyHint), findsOneWidget);
    expect(find.text(tr.scheduleAddGuestAction), findsOneWidget);
  });

  testWidgets("a slot with one guest draws its name, its reason and its remove control", (
    tester,
  ) async {
    final guests = [_buildGuest(id: "guest-1", personId: "person-1", reason: "Visite guidée")];

    await tester.pumpWidget(
      wrapInApp(
        buildCard(isReadOnly: false, guests: guests, guestReasonValueOf: (_) => "Visite guidée"),
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
      final guests = [_buildGuest(id: "guest-1", personId: "person-1", reason: "Visite guidée")];

      await tester.pumpWidget(
        wrapInApp(
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
