// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';

/// What both schedule PDF exports hand [ocptScheduleBlockCaptionOf] as its own kind resolver —
/// recognisable placeholders rather than the real localized labels, which live in the UI layer.
String _blockKindLabelOf(OcptShootingBlockKind kind) => switch (kind) {
  OcptShootingBlockKind.shot => "Shot",
  OcptShootingBlockKind.preparation => "Preparation",
  OcptShootingBlockKind.hairMakeUp => "HMC",
  OcptShootingBlockKind.meal => "Meal break",
  OcptShootingBlockKind.pause => "Break",
  OcptShootingBlockKind.travel => "Travel",
  OcptShootingBlockKind.wrap => "Wrap",
  OcptShootingBlockKind.hold => "Reserved",
};

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({
  String id = "slot-1",
  int anchorMinute = 480,
  List<OcptShootingSlotCastMember> cast = const [],
  List<OcptShootingSlotGuest> guests = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: anchorMinute,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: cast,
  guests: guests,
);

/// Builds a cast member linking [roleId] to the fixture's own slot.
OcptShootingSlotCastMember _buildCastMember(String roleId) =>
    OcptShootingSlotCastMember(id: "cast-$roleId", slotId: "slot-1", roleId: roleId, notes: "");

/// Builds a slot guest with the few fields these tests read, everything else neutral.
OcptShootingSlotGuest _buildGuest({
  required String id,
  required String slotId,
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

/// Builds a person with the few fields these tests read, everything else neutral.
OcptPerson _buildPerson({required String id, required String firstName, required String lastName}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: lastName,
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
  photoAssetId: null,
  photo: null,
  imageRightsDocument: null,
  notes: "",
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// Builds a one-day plan snapshot over [slots], plus whichever [people] a guest test needs to
/// resolve (or fail to resolve) an address-book name from, and whichever [shotLists] a heading
/// test needs.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingSlot> slots,
  List<OcptPerson> people = const [],
  List<OcptShotListSnapshot> shotLists = const [],
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    days: [
      OcptShootingDay(
        id: "day-1",
        date: DateTime(2026),
        dayNumber: 1,
        kind: OcptShootingDayKind.shoot,
        status: OcptShootingDayStatus.planned,
        crewNote: "",
        weatherNote: "",
        notes: "",
      ),
    ],
    slotsByDayId: {"day-1": slots},
    blocksByDayId: const {},
    eventsByDayId: const {},
  ),
  shotLists: shotLists,
  episodes: const [],
  locations: const [],
  roles: const [],
  people: people,
  elements: const [],
  minimumRestMinutes: null,
);

/// Builds a block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required OcptShootingBlockKind kind,
  String label = "",
  String? sceneId,
}) => OcptShootingDayBlock(
  id: "block-1",
  shootingDayId: "day-1",
  slotId: "slot-1",
  kind: kind,
  shotId: null,
  sceneId: sceneId,
  label: label,
  durationMinutes: 30,
  anchorMinute: null,
  notes: "",
  crewNote: "",
);

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required int number}) => OcptRole(
  id: id,
  name: "Role $number",
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: number,
  episodeIds: const [],
);

void main() {
  final roleById = {
    "role-a": _buildRole(id: "role-a", number: 5),
    "role-b": _buildRole(id: "role-b", number: 3),
    "role-c": _buildRole(id: "role-c", number: 8),
  };

  group("ocptScheduleGeneratedAtStamp", () {
    test("prints the date and the time, zero-padded, as one sortable stamp", () {
      expect(ocptScheduleGeneratedAtStamp(DateTime(2026, 8, 8, 14, 32)), "2026-08-08 14:32");
    });

    test("pads a single-digit month, day, hour and minute alike", () {
      expect(ocptScheduleGeneratedAtStamp(DateTime(2026, 1, 2, 3, 4)), "2026-01-02 03:04");
    });

    test("two moments of one day differ by their time alone, which is the point of the stamp", () {
      final morning = ocptScheduleGeneratedAtStamp(DateTime(2026, 8, 8, 9, 15));
      final afternoon = ocptScheduleGeneratedAtStamp(DateTime(2026, 8, 8, 17, 45));

      expect(morning, isNot(afternoon));
      expect(morning.substring(0, 10), afternoon.substring(0, 10));
    });

    test("midnight prints as 00:00 rather than as 24:00 of the day before", () {
      expect(ocptScheduleGeneratedAtStamp(DateTime(2026, 8, 9)), "2026-08-09 00:00");
    });
  });

  group("ocptScheduleSlotRoleNumbersOf", () {
    test("reads the slot's own cast, sorted ascending rather than in link order", () {
      final slot = _buildSlot(
        cast: [_buildCastMember("role-a"), _buildCastMember("role-c"), _buildCastMember("role-b")],
      );

      expect(ocptScheduleSlotRoleNumbersOf(slot: slot, roleById: roleById), [3, 5, 8]);
    });

    test("a slot convoking nobody answers with no number at all", () {
      expect(ocptScheduleSlotRoleNumbersOf(slot: _buildSlot(), roleById: roleById), isEmpty);
    });

    test("a cast row naming a role the project no longer holds is skipped, not printed as a gap", () {
      final slot = _buildSlot(cast: [_buildCastMember("role-a"), _buildCastMember("role-gone")]);

      expect(ocptScheduleSlotRoleNumbersOf(slot: slot, roleById: roleById), [5]);
    });
  });

  group("ocptScheduleBlockRoleNumbersOf", () {
    test("an HMC block answers with the numbers of the roles its slot convokes", () {
      final numbers = ocptScheduleBlockRoleNumbersOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hairMakeUp),
        slot: _buildSlot(cast: [_buildCastMember("role-a"), _buildCastMember("role-b")]),
        roleById: roleById,
      );

      expect(numbers, [3, 5]);
    });

    test("an HMC block on a slot convoking nobody answers with no number at all", () {
      final numbers = ocptScheduleBlockRoleNumbersOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hairMakeUp),
        slot: _buildSlot(),
        roleById: roleById,
      );

      expect(numbers, isEmpty);
    });

    test("every other kind carries none, however much cast its slot convokes", () {
      final slot = _buildSlot(cast: [_buildCastMember("role-a"), _buildCastMember("role-b")]);

      for (final kind in OcptShootingBlockKind.values) {
        if (kind == OcptShootingBlockKind.hairMakeUp) {
          continue;
        }
        expect(
          ocptScheduleBlockRoleNumbersOf(block: _buildBlock(kind: kind), slot: slot, roleById: roleById),
          isEmpty,
          reason: "a $kind block must not carry its slot's role numbers",
        );
      }
    });
  });

  group("ocptScheduleBlockRoleNumbersLine", () {
    test("names the numbers behind the calling document's own label", () {
      expect(
        ocptScheduleBlockRoleNumbersLine(roleNumbers: const [3, 5], rolesLabel: "CAST"),
        "CAST : 3, 5",
      );
    });

    test("a band expecting nobody prints no line at all", () {
      expect(ocptScheduleBlockRoleNumbersLine(roleNumbers: const [], rolesLabel: "CAST"), isNull);
    });
  });

  group("ocptScheduleBlockCaptionOf", () {
    test("an HMC block's own caption carries no role number of its own", () {
      final caption = ocptScheduleBlockCaptionOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hairMakeUp),
        headingBySceneId: const {},
        blockKindLabelOf: _blockKindLabelOf,
      );

      expect(caption, "HMC");
    });

    test("an HMC block's own free text is printed as it stands", () {
      final caption = ocptScheduleBlockCaptionOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hairMakeUp, label: "HMC dressing room 2"),
        headingBySceneId: const {},
        blockKindLabelOf: _blockKindLabelOf,
      );

      expect(caption, "HMC dressing room 2");
    });

    test("every kind with no caption of its own falls back to its kind label", () {
      for (final kind in OcptShootingBlockKind.values) {
        expect(
          ocptScheduleBlockCaptionOf(
            block: _buildBlock(kind: kind),
            headingBySceneId: const {},
            blockKindLabelOf: _blockKindLabelOf,
          ),
          _blockKindLabelOf(kind),
        );
      }
    });

    test("a hold block names its own sequence's heading over the kind label", () {
      final caption = ocptScheduleBlockCaptionOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hold, sceneId: "scene-1"),
        headingBySceneId: const {"scene-1": "INT. HOUSE - DAY"},
        blockKindLabelOf: _blockKindLabelOf,
      );

      expect(caption, "INT. HOUSE - DAY");
    });

    test("a block's own free text wins over both its sequence heading and its kind label", () {
      final caption = ocptScheduleBlockCaptionOf(
        block: _buildBlock(kind: OcptShootingBlockKind.hold, sceneId: "scene-1", label: "Reserved for the storm"),
        headingBySceneId: const {"scene-1": "INT. HOUSE - DAY"},
        blockKindLabelOf: _blockKindLabelOf,
      );

      expect(caption, "Reserved for the storm");
    });
  });

  group("ocptScheduleHeadingBySceneId", () {
    test("resolves a scene's own heading whichever of two episodes it belongs to", () {
      final plan = _buildSnapshot(
        slots: const [],
        shotLists: [
          OcptShotListSnapshot.build(
            screenplayId: "episode-1",
            sequences: const [
              OcptSceneShotSequence(
                sceneId: "scene-e1",
                heading: "INT. HOUSE - DAY",
                sceneNumber: null,
                displaySceneNumber: "1.3",
                charStart: 0,
                charEnd: 10,
                shots: [],
              ),
            ],
          ),
          OcptShotListSnapshot.build(
            screenplayId: "episode-2",
            sequences: const [
              OcptSceneShotSequence(
                sceneId: "scene-e2",
                heading: "EXT. STREET - NIGHT",
                sceneNumber: null,
                displaySceneNumber: "2.4",
                charStart: 0,
                charEnd: 10,
                shots: [],
              ),
            ],
          ),
        ],
      );

      final headingBySceneId = ocptScheduleHeadingBySceneId(plan);

      expect(headingBySceneId["scene-e1"], "INT. HOUSE - DAY");
      expect(headingBySceneId["scene-e2"], "EXT. STREET - NIGHT");

      // What this buys a hold block naming either episode's own scene: its caption resolves
      // exactly as it would if the two episodes' shot lists had never been merged.
      expect(
        ocptScheduleBlockCaptionOf(
          block: _buildBlock(kind: OcptShootingBlockKind.hold, sceneId: "scene-e2"),
          headingBySceneId: headingBySceneId,
          blockKindLabelOf: _blockKindLabelOf,
        ),
        "EXT. STREET - NIGHT",
      );
    });
  });

  group("ocptScheduleArrivalDepartureLabel", () {
    test("no convocation at all reads as the empty value", () {
      expect(ocptScheduleArrivalDepartureLabel(null), ocptScheduleEmptyValue);
    });

    test("a live convocation reads its own arrival and departure", () {
      final plan = _buildSnapshot(
        slots: [
          _buildSlot(guests: [_buildGuest(id: "guest-1", slotId: "slot-1", freeName: "Mayor Dupont")]),
        ],
      );
      final convocation = plan.convocationsOfDay("day-1").single;

      // The slot carries no block, so its own start is its own end too (ADR 0018): a convocation
      // with nothing placed on it yet still reads a band, just a zero-length one.
      expect(ocptScheduleArrivalDepartureLabel(convocation), "08:00 – 08:00");
    });
  });

  group("ocptScheduleGuestRowsOfDay", () {
    test("a guest on two slots keeps both slots' own reasons, comma-joined", () {
      final plan = _buildSnapshot(
        slots: [
          _buildSlot(
            id: "slot-morning",
            guests: [
              _buildGuest(
                id: "guest-morning",
                slotId: "slot-morning",
                freeName: "Mayor Dupont",
                reason: "Ribbon cutting",
              ),
            ],
          ),
          _buildSlot(
            id: "slot-afternoon",
            anchorMinute: 600,
            guests: [
              _buildGuest(
                id: "guest-afternoon",
                slotId: "slot-afternoon",
                freeName: "Mayor Dupont",
                reason: "Closing speech",
                notes: "Leaves early",
              ),
            ],
          ),
        ],
      );

      final rows = ocptScheduleGuestRowsOfDay(plan: plan, dayId: "day-1", unnamedPersonLabel: "Unnamed");

      // Both slots convoke the very same free-named guest, so the join reads as one row rather than
      // two — a guest attending two slots for two different reasons has both printed, never one
      // picked over the other.
      expect(rows, hasLength(1));
      expect(rows.single.name, "Mayor Dupont");
      expect(rows.single.reason, "Ribbon cutting, Closing speech");
      expect(rows.single.notes, "Leaves early");
    });

    test("a free-name guest reads their own name, having no address-book row to prefer", () {
      final plan = _buildSnapshot(
        slots: [_buildSlot(guests: [_buildGuest(id: "guest-1", slotId: "slot-1", freeName: "Zoé Martin")])],
      );

      final rows = ocptScheduleGuestRowsOfDay(plan: plan, dayId: "day-1", unnamedPersonLabel: "Unnamed");

      expect(rows.single.name, "Zoé Martin");
    });

    test("an address-book guest reads the address book's own display name", () {
      final plan = _buildSnapshot(
        slots: [
          _buildSlot(guests: [_buildGuest(id: "guest-1", slotId: "slot-1", personId: "person-1")]),
        ],
        people: [_buildPerson(id: "person-1", firstName: "Camille", lastName: "Roy")],
      );

      final rows = ocptScheduleGuestRowsOfDay(plan: plan, dayId: "day-1", unnamedPersonLabel: "Unnamed");

      expect(rows.single.name, "Camille Roy");
    });

    test("a guest whose person resolves to nothing falls back to the given label", () {
      final plan = _buildSnapshot(
        slots: [
          _buildSlot(guests: [_buildGuest(id: "guest-1", slotId: "slot-1", personId: "person-gone")]),
        ],
      );

      final rows = ocptScheduleGuestRowsOfDay(plan: plan, dayId: "day-1", unnamedPersonLabel: "Unnamed");

      expect(rows.single.name, "Unnamed");
    });

    test("a day with no guest at all answers with no row", () {
      final plan = _buildSnapshot(slots: [_buildSlot()]);

      expect(ocptScheduleGuestRowsOfDay(plan: plan, dayId: "day-1", unnamedPersonLabel: "Unnamed"), isEmpty);
    });
  });
}
