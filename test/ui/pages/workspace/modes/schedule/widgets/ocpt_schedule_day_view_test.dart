// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_day_view.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_slot_card.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a sized box
/// standing in for the workspace shell's own centre area.
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

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay() => OcptShootingDay(
  id: "day-1",
  date: DateTime(2026, 8, 4),
  dayNumber: 1,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds role [id], everything else neutral.
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

/// Builds candidacy [id] of [firstName] for role [roleId], everything else neutral.
OcptRoleCandidate _buildCandidacy({
  required String id,
  required String roleId,
  required String firstName,
}) => OcptRoleCandidate(
  id: id,
  roleId: roleId,
  person: OcptPerson(
    id: "person-$id",
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
    commuteKmMilli: null,
    mileageRateId: null,
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
  ),
  status: OcptRoleCandidateStatus.spotted,
  auditionedOn: null,
  notes: "",
);

/// Builds a slot with the few fields these tests read, anchored by its start at 09:00.
OcptShootingSlot _buildSlot({
  String id = "slot-1",
  List<OcptShootingSlotCastMember> cast = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 540,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: cast,
  guests: const [],
);

/// Builds a block with the few fields these tests read.
OcptShootingDayBlock _buildBlock({
  required String id,
  required OcptShootingBlockKind kind,
  String slotId = "slot-1",
  String? roleId,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: slotId,
  kind: kind,
  shotId: null,
  sceneId: null,
  candidates: const [],
  label: "",
  durationMinutes: 20,
  anchorMinute: null,
  notes: "",
  crewNote: "",
);

/// Builds a day event with the few fields these tests read, everything else neutral.
OcptShootingDayEvent _buildEvent() => const OcptShootingDayEvent(
  id: "event-1",
  shootingDayId: "day-1",
  minute: 1020,
  label: "Fireworks",
  notes: "",
);

/// Pumps [OcptScheduleDayView] with no slot at all unless a test hands one in — most of these
/// tests exercise the events band, which is drawn independently of the slot cards — and every
/// writing affordance withheld unless [onEventAdded] is handed in.
Future<void> _pumpDayView(
  WidgetTester tester, {
  List<OcptShootingDayEvent> events = const [],
  VoidCallback? onEventAdded,
  List<OcptShootingSlot> slots = const [],
  List<OcptShootingDayBlock> blocks = const [],
  OcptShootingDayTimelines? timeline,
  List<OcptRole> roles = const [],
  Map<String, OcptRoleCandidate> roleCandidateById = const {},
  void Function(String blockId, String roleCandidateId)? onBlockCandidateAdded,
}) async {
  await tester.pumpWidget(
    _wrapInApp(
      OcptScheduleDayView(
        day: _buildDay(),
        slots: slots,
        blocks: blocks,
        timeline: timeline,
        dayArrivalMinute: null,
        sunTimes: null,
        alerts: const [],
        locationById: const {},
        setById: const {},
        locations: const [],
        personById: const {},
        roleById: {for (final role in roles) role.id: role},
        people: const [],
        roles: roles,
        shotOf: (_) => null,
        selectedBlockId: null,
        sequences: const [],
        slotLabelValueOf: (_) => "",
        slotNotesValueOf: (_) => "",
        onSlotAdded: null,
        onSlotLabelChanged: null,
        onSlotNotesChanged: null,
        onSlotPlaceChanged: null,
        onSlotAnchorChanged: null,
        onSlotMoved: null,
        onSlotDeletionRequested: null,
        onSlotCrewMemberAdded: null,
        onSlotCrewMemberPositionChanged: null,
        onSlotCrewMemberRemoved: null,
        onSlotCastRoleAdded: null,
        onSlotCastRoleRemoved: null,
        onSlotGuestAdded: null,
        onSlotGuestRemoved: null,
        slotGuestReasonValueOf: (_) => "",
        onSlotGuestReasonChanged: null,
        slotGuestNotesValueOf: (_) => "",
        onSlotGuestNotesChanged: null,
        onBlockSelected: (_) {},
        onBlockReordered: null,
        onBlockDurationChanged: null,
        onBlockAnchorChanged: null,
        onShotStatusChanged: null,
        onBlockSequenceChanged: null,
        onBlockCandidateAdded: onBlockCandidateAdded,
        onBlockCandidateRemoved: null,
        onBlockDeletionRequested: null,
        onBlockAdded: null,
        onShotBlockRequested: null,
        onBlockMovedToSlot: null,
        onAlertsOpenRequested: null,
        events: events,
        eventLabelValueOf: (_) => "Fireworks",
        eventNotesValueOf: (_) => "",
        onEventAdded: onEventAdded,
        onEventMinuteChanged: onEventAdded == null ? null : (_, _) {},
        onEventLabelChanged: onEventAdded == null ? null : (_, _) {},
        onEventNotesChanged: onEventAdded == null ? null : (_, _) {},
        onEventDeletionRequested: onEventAdded == null ? null : (_) {},
        roleCandidateById: roleCandidateById,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    "the events band is absent on a day with no event when the view may not be written to",
    (tester) async {
      await _pumpDayView(tester);

      final tr = Tr.of(tester.element(find.byType(OcptScheduleDayView)));
      expect(find.text(tr.scheduleDayEventsSectionTitle.toUpperCase()), findsNothing);
      expect(find.text(tr.scheduleAddDayEventAction), findsNothing);
    },
  );

  testWidgets("the events band draws once the day has an event, even read-only", (tester) async {
    await _pumpDayView(tester, events: [_buildEvent()]);

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayView)));
    expect(find.text(tr.scheduleDayEventsSectionTitle.toUpperCase()), findsOneWidget);
    expect(find.text("Fireworks"), findsOneWidget);
    // Still read-only: no `+ Event` footer, since every event callback was withheld.
    expect(find.text(tr.scheduleAddDayEventAction), findsNothing);
  });

  testWidgets("the events band draws with no event at all once it may be written to", (
    tester,
  ) async {
    await _pumpDayView(tester, onEventAdded: () {});

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayView)));
    expect(find.text(tr.scheduleDayEventsSectionTitle.toUpperCase()), findsOneWidget);
    expect(find.text(tr.scheduleAddDayEventAction), findsOneWidget);
  });

  testWidgets("a slot holding an audition draws its ordinary card", (tester) async {
    // There is one way to read a slot, whatever its blocks: the compact single-audition row this
    // once had answered a cost — one candidate, one slot — that convoking candidates on the slot
    // itself made vanish.
    await _pumpDayView(
      tester,
      slots: [_buildSlot()],
      blocks: [
        _buildBlock(id: "block-1", kind: OcptShootingBlockKind.audition, roleId: "role-1"),
      ],
    );

    expect(find.byType(OcptScheduleSlotCard), findsOneWidget);
  });

  testWidgets("an audition offers the candidates of a role its own slot also convokes", (
    tester,
  ) async {
    String? pickedCandidacyId;
    await _pumpDayView(
      tester,
      slots: [
        _buildSlot(
          cast: const [
            OcptShootingSlotCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1", notes: ""),
          ],
        ),
      ],
      blocks: [_buildBlock(id: "block-1", kind: OcptShootingBlockKind.audition)],
      roles: [_buildRole(id: "role-1", name: "MARIE")],
      roleCandidateById: {
        "candidacy-1": _buildCandidacy(id: "candidacy-1", roleId: "role-1", firstName: "Camille"),
      },
      onBlockCandidateAdded: (_, roleCandidateId) => pickedCandidacyId = roleCandidateId,
    );

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayView)));
    await tester.tap(find.text(tr.scheduleAddAuditionCandidateAction));
    await tester.pumpAndSettle();
    // Grouped under the part's own name — the cast row's "MARIE" plus the menu's heading — not
    // under the unnamed-role fallback a part missing from the roles list would fall to.
    expect(find.text("MARIE"), findsNWidgets(2));
    expect(find.text(tr.resourcesRoleUnnamed), findsNothing);
    await tester.tap(find.text("Camille"));
    await tester.pumpAndSettle();

    expect(pickedCandidacyId, "candidacy-1");
  });
}
