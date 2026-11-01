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
import 'package:open_cine_prod_tools/models/ocpt_person_position.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_slot_timeline.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_minute_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_crew_position_picker_dialog.dart';
import 'ocpt_schedule_slot_card_test_doubles.dart';

/// Builds candidacy [id] of [firstName] for role [roleId], everything else neutral.
OcptRoleCandidate _buildCandidacy({
  required String id,
  required String roleId,
  required String firstName,
}) => OcptRoleCandidate(
  id: id,
  roleId: roleId,
  person: buildPerson(id: "person-$id", firstName: firstName),
  status: OcptRoleCandidateStatus.spotted,
  auditionedOn: null,
  notes: "",
);

/// Run the tests of the schedule slot card footers and pickers.
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

  testWidgets("the `+ Crew member` footer opens a picker dispatching the person just picked", (
    tester,
  ) async {
    final added = <String>[];
    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false, onCrewMemberAdded: added.add)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleAddCrewMemberAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Léa").last);
    await tester.pumpAndSettle();

    expect(added, ["person-1"]);
  });

  testWidgets("the `+ Cast` footer opens a picker dispatching the role just picked", (
    tester,
  ) async {
    final added = <String>[];
    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false, onCastRoleAdded: added.add)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleAddCastAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Marie").last);
    await tester.pumpAndSettle();

    expect(added, ["role-1"]);
  });

  testWidgets("the `+ Cast` picker leaves out the roles the slot already convokes", (tester) async {
    final added = <String>[];
    await tester.pumpWidget(
      wrapInApp(
        buildCard(
          isReadOnly: false,
          roles: [
            role,
            buildRole(id: "role-2", name: "Paul"),
          ],
          cast: [
            const OcptShootingSlotCastMember(
              id: "cast-1",
              slotId: "slot-1",
              roleId: "role-1",
              notes: "",
            ),
          ],
          onCastRoleAdded: added.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleAddCastAction));
    await tester.pumpAndSettle();

    // "Marie" is only the convoked row's own name, not a menu entry.
    expect(find.text("Marie"), findsOneWidget);
    await tester.tap(find.text("Paul"));
    await tester.pumpAndSettle();

    expect(added, ["role-2"]);
  });

  testWidgets("the `+ Cast` picker says so, rather than not opening, once every role is convoked", (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapInApp(
        buildCard(
          isReadOnly: false,
          cast: [
            const OcptShootingSlotCastMember(
              id: "cast-1",
              slotId: "slot-1",
              roleId: "role-1",
              notes: "",
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleAddCastAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.scheduleCastPickerAllConvokedHint), findsOneWidget);
  });

  testWidgets("an audition still offers the candidates of a role the slot also convokes", (
    tester,
  ) async {
    String? pickedCandidacyId;
    await tester.pumpWidget(
      wrapInApp(
        OcptScheduleSlotCard(
          slot: buildSlot(
            cast: const [
              OcptShootingSlotCastMember(
                id: "cast-1",
                slotId: "slot-1",
                roleId: "role-1",
                notes: "",
              ),
            ],
          ),
          location: null,
          set: null,
          locations: const [],
          personById: {person.id: person},
          roleById: {role.id: role},
          roleCandidateById: {
            "candidacy-1": _buildCandidacy(
              id: "candidacy-1",
              roleId: "role-1",
              firstName: "Camille",
            ),
          },
          people: [person],
          roles: [role],
          labelValue: "Matin",
          onLabelChanged: null,
          notesValue: "",
          onNotesChanged: null,
          onPlaceChanged: null,
          onAnchorChanged: null,
          anchorSourceBySlotId: const {},
          onMovedUp: null,
          onMovedDown: null,
          onDeletionRequested: null,
          onCrewMemberAdded: null,
          onCrewMemberPositionChanged: null,
          onCrewMemberRemoved: null,
          onCastRoleAdded: null,
          onCastRoleRemoved: null,
          onGuestAdded: null,
          onGuestRemoved: null,
          guestReasonValueOf: (_) => "",
          onGuestReasonChanged: null,
          guestNotesValueOf: (_) => "",
          onGuestNotesChanged: null,
          blocks: [
            buildBlock(id: "block-1", slotId: "slot-1", kind: OcptShootingBlockKind.audition),
          ],
          timeline: null,
          shotOf: noShot,
          selectedBlockId: null,
          sequences: const [],
          otherSlots: const [],
          onBlockSelected: (_) {},
          onBlockReordered: null,
          onBlockDurationChanged: null,
          onBlockAnchorChanged: null,
          onShotStatusChanged: null,
          onBlockSequenceChanged: null,
          onBlockCandidateAdded: (_, roleCandidateId) => pickedCandidacyId = roleCandidateId,
          onBlockCandidateRemoved: null,
          onBlockDeletionRequested: null,
          onBlockAdded: null,
          onShotBlockRequested: null,
          onBlockMovedToSlot: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleAddAuditionCandidateAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camille"));
    await tester.pumpAndSettle();

    expect(pickedCandidacyId, "candidacy-1");
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
      const OcptShootingSlotCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1", notes: ""),
    ];

    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false, crew: crew, cast: cast)));
    await tester.pumpAndSettle();

    expect(find.text("Léa"), findsOneWidget);
    expect(find.text("Marie"), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets(
    "the crew row's position picker promotes the person's declared positions above the catalogue",
    (tester) async {
      // The crew position picker dialog needs more room than the default test surface for its
      // own thirteen departments, same as `ocpt_crew_position_picker_dialog_test.dart`.
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final crewPerson = buildPerson(
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
        wrapInApp(buildCard(isReadOnly: false, crewPerson: crewPerson, crew: crew)),
      );
      await tester.pumpAndSettle();

      final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
      await tester.tap(find.text(tr.scheduleSlotCrewPositionPlaceholder));
      await tester.pumpAndSettle();

      // The person's own declared position, promoted ahead of every catalogue entry, including
      // the catalogue's own "director" one — printed twice, once under the promoted heading and
      // once under the catalogue's own "Direction" department.
      expect(find.byType(OcptCrewPositionPickerDialog), findsOneWidget);
      expect(find.text(tr.resourcesCrewPositionPickerPromotedHeading), findsOneWidget);
      expect(find.text(ocptCrewPositionLabel(tr, "director")), findsNWidgets(2));
      final promotedHeadingY = tester
          .getTopLeft(find.text(tr.resourcesCrewPositionPickerPromotedHeading))
          .dy;
      final firstDirectorY = tester
          .getTopLeft(find.text(ocptCrewPositionLabel(tr, "director")).first)
          .dy;
      expect(promotedHeadingY, lessThan(firstDirectorY));
    },
  );

  testWidgets("the picker never offers a position that person already holds on that slot", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final crewPerson = buildPerson(
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
      wrapInApp(buildCard(isReadOnly: false, crewPerson: crewPerson, crew: crew)),
    );
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    await tester.tap(find.text(tr.scheduleSlotCrewPositionPlaceholder));
    await tester.pumpAndSettle();

    final dialog = find.byType(OcptCrewPositionPickerDialog);
    expect(dialog, findsOneWidget);
    // "Director" is already held on this slot — left out everywhere the dialog offers,
    // promoted block and catalogue alike.
    expect(
      find.descendant(of: dialog, matching: find.text(ocptCrewPositionLabel(tr, "director"))),
      findsNothing,
    );
    // "boomOperator", still free, is promoted ahead of the catalogue.
    expect(find.text(tr.resourcesCrewPositionPickerPromotedHeading), findsOneWidget);
    final promotedHeadingY = tester
        .getTopLeft(find.text(tr.resourcesCrewPositionPickerPromotedHeading))
        .dy;
    final firstBoomOperatorY = tester
        .getTopLeft(find.text(ocptCrewPositionLabel(tr, "boomOperator")).first)
        .dy;
    expect(promotedHeadingY, lessThan(firstBoomOperatorY));
  });

  testWidgets("picking a declared free-label entry reports a ref carrying that label", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final crewPerson = buildPerson(
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
      wrapInApp(
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

    expect(reported, [
      ("crew-1", const OcptCrewPositionRef(positionId: "", customLabel: "Rigger")),
    ]);
  });

  testWidgets("a read-only crew row shows its position as plain text, with no picker", (
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

    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: true, crew: crew)));
    await tester.pumpAndSettle();

    final tr = Tr.of(tester.element(find.byType(OcptScheduleSlotCard)));
    expect(find.text(ocptCrewPositionLabel(tr, "director")), findsOneWidget);
    await tester.tap(find.text(ocptCrewPositionLabel(tr, "director")));
    await tester.pumpAndSettle();
    expect(find.byType(OcptCrewPositionPickerDialog), findsNothing);
  });

  testWidgets("the card offers exactly one editable minute field: the slot's own anchor", (
    tester,
  ) async {
    await tester.pumpWidget(wrapInApp(buildCard(isReadOnly: false)));
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
      wrapInApp(
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
      wrapInApp(
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
      wrapInApp(
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
}
