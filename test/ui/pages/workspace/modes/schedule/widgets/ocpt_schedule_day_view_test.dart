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
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/schedule/widgets/ocpt_schedule_compact_slot_row.dart';
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
OcptShootingDay _buildDay({OcptShootingDayKind kind = OcptShootingDayKind.shoot}) =>
    OcptShootingDay(
  id: "day-1",
  date: DateTime(2026, 8, 4),
  dayNumber: 1,
  kind: kind,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a person whose display name is [firstName], everything else neutral.
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

/// Builds a part with the few fields these tests read.
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

/// Builds a candidacy with the few fields these tests read.
OcptRoleCandidate _buildCandidacy({
  required String id,
  required String roleId,
  required OcptPerson person,
}) => OcptRoleCandidate(
  id: id,
  roleId: roleId,
  person: person,
  status: OcptRoleCandidateStatus.seen,
  auditionedOn: null,
  notes: "",
);

/// Builds a slot with the few fields these tests read, anchored by its start at 09:00.
OcptShootingSlot _buildSlot({String id = "slot-1"}) => OcptShootingSlot(
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
  cast: const [],
  guests: const [],
  candidates: const [],
);

/// Builds a block with the few fields these tests read.
OcptShootingDayBlock _buildBlock({
  required String id,
  required OcptShootingBlockKind kind,
  String slotId = "slot-1",
  String? roleId,
  String? roleCandidateId,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: slotId,
  kind: kind,
  shotId: null,
  sceneId: null,
  roleId: roleId,
  roleCandidateId: roleCandidateId,
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
  OcptShootingDayKind dayKind = OcptShootingDayKind.shoot,
  List<OcptShootingSlot> slots = const [],
  List<OcptShootingDayBlock> blocks = const [],
  OcptShootingDayTimelines? timeline,
  Map<String, OcptRole> roleById = const {},
  Map<String, OcptRoleCandidate> roleCandidateById = const {},
}) async {
  await tester.pumpWidget(
    _wrapInApp(
      OcptScheduleDayView(
        day: _buildDay(kind: dayKind),
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
        roleById: roleById,
        people: const [],
        roles: const [],
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
        onAuditionBlockRequested: null,
        roleCandidateById: roleCandidateById,
        onSlotCandidateAdded: null,
        onSlotCandidateRemoved: null,
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

  testWidgets("a casting slot holding one audition draws compact, and opens on demand", (tester) async {
    final candidate = _buildCandidacy(
      id: "candidacy-1",
      roleId: "role-1",
      person: _buildPerson(id: "person-1", firstName: "Camille"),
    );

    await _pumpDayView(
      tester,
      dayKind: OcptShootingDayKind.casting,
      slots: [_buildSlot()],
      blocks: [
        _buildBlock(
          id: "block-1",
          kind: OcptShootingBlockKind.audition,
          roleId: "role-1",
          roleCandidateId: "candidacy-1",
        ),
      ],
      timeline: const OcptShootingDayTimelines(
        bySlotId: {
          "slot-1": OcptShootingSlotTimeline(
            entries: [
              OcptShootingTimelineEntry(
                blockId: "block-1",
                startMinute: 540,
                endMinute: 560,
                durationMinutes: 20,
              ),
            ],
            overruns: [],
            startMinute: 540,
            endMinute: 560,
          ),
        },
        entries: [
          OcptShootingTimelineEntry(
            blockId: "block-1",
            startMinute: 540,
            endMinute: 560,
            durationMinutes: 20,
          ),
        ],
        overruns: [],
        fixedEndMisses: [],
        anchorCycles: [],
        dayStartMinute: 540,
        dayEndMinute: 560,
      ),
      roleById: {"role-1": _buildRole(id: "role-1", name: "MARIE")},
      roleCandidateById: {"candidacy-1": candidate},
    );

    final tr = Tr.of(tester.element(find.byType(OcptScheduleDayView)));
    expect(find.byType(OcptScheduleCompactSlotRow), findsOneWidget);
    expect(find.byType(OcptScheduleSlotCard), findsNothing);
    expect(find.text(tr.scheduleAuditionBlockLabel("Camille", "MARIE")), findsOneWidget);

    // One click is all the row costs: everything a user might do to this slot is on the card.
    await tester.tap(find.byTooltip(tr.scheduleExpandSlotTooltip));
    await tester.pumpAndSettle();

    expect(find.byType(OcptScheduleCompactSlotRow), findsNothing);
    expect(find.byType(OcptScheduleSlotCard), findsOneWidget);
  });

  testWidgets("a casting slot carrying anything more than its audition draws its card", (tester) async {
    await _pumpDayView(
      tester,
      dayKind: OcptShootingDayKind.casting,
      slots: [_buildSlot()],
      blocks: [
        _buildBlock(
          id: "block-1",
          kind: OcptShootingBlockKind.audition,
          roleId: "role-1",
          roleCandidateId: "candidacy-1",
        ),
        _buildBlock(id: "block-2", kind: OcptShootingBlockKind.pause),
      ],
    );

    // A unit with a running order is exactly what a card is for.
    expect(find.byType(OcptScheduleCompactSlotRow), findsNothing);
    expect(find.byType(OcptScheduleSlotCard), findsOneWidget);
  });

  testWidgets("a day that shoots never compacts, whatever its slots hold", (tester) async {
    await _pumpDayView(
      tester,
      slots: [_buildSlot()],
      blocks: [
        _buildBlock(
          id: "block-1",
          kind: OcptShootingBlockKind.audition,
          roleId: "role-1",
          roleCandidateId: "candidacy-1",
        ),
      ],
    );

    expect(find.byType(OcptScheduleCompactSlotRow), findsNothing);
    expect(find.byType(OcptScheduleSlotCard), findsOneWidget);
  });
}
