// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber}) => OcptShootingDay(
  id: id,
  date: DateTime(2026, 1, dayNumber),
  dayNumber: dayNumber,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({
  required String id,
  required String shootingDayId,
  String label = "",
  String? locationId,
  String? setId,
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: shootingDayId,
  label: label,
  locationId: locationId,
  setId: setId,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: crew,
  cast: cast,
  guests: const [],
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required String id,
  required String shootingDayId,
  required String slotId,
  OcptShootingBlockKind kind = OcptShootingBlockKind.shot,
  String? shotId,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: shootingDayId,
  slotId: slotId,
  kind: kind,
  shotId: shotId,
  sceneId: null,
  label: "",
  durationMinutes: 30,
  anchorMinute: null,
  notes: "",
  crewNote: "",
);

/// Builds a crew member with the few fields these tests read, everything else neutral.
OcptShootingSlotCrewMember _buildCrewMember({
  required String id,
  required String slotId,
  required String personId,
  String positionId = "gaffer",
}) => OcptShootingSlotCrewMember(
  id: id,
  slotId: slotId,
  personId: personId,
  positionId: positionId,
  customLabel: "",
  notes: "",
);

/// Builds a cast member with the few fields these tests read, everything else neutral.
OcptShootingSlotCastMember _buildCastMember({required String id, required String slotId, required String roleId}) =>
    OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required String name, String? personId, int number = 1}) => OcptRole(
  id: id,
  name: name,
  personId: personId,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: number,
);

/// Builds a location with the few fields these tests read, everything else neutral.
OcptLocation _buildLocation({required String id, String name = ""}) => OcptLocation(
  id: id,
  name: name,
  colorIndex: 0,
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  latitude: null,
  longitude: null,
  contactPersonId: null,
  contactNotes: "",
  permitStatus: OcptPermitStatus.notNeeded,
  permitLabel: "",
  permitDate: null,
  permitAssetId: null,
  parkingNotes: "",
  powerNotes: "",
  facilitiesNotes: "",
  constraintsNotes: "",
  notes: "",
  sets: const [],
  photos: const [],
  permitDocument: null,
  availabilities: const [],
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({required String id, String? sceneId, required String code}) => OcptShot(
  id: id,
  screenplayId: "screenplay-1",
  sceneId: sceneId,
  orphanedHeading: null,
  position: 0,
  shotSize: "",
  abbreviation: "",
  framing: "",
  cameraMove: "",
  lens: "",
  recordingFormat: "",
  estimatedDurationMs: null,
  shootingDay: null,
  plannedTakes: null,
  sound: "",
  status: OcptShotStatus.toShoot,
  difficultySet: 0,
  difficultyCamera: 0,
  difficultyActing: 0,
  difficultySound: 0,
  notes: "",
  locationNotes: "",
  needsCheck: false,
  checkReason: null,
  characters: const [],
  coverageRanges: const [],
  code: code,
  averageDifficulty: 0,
);

/// Builds a one-scene shot list snapshot over [shots], all belonging to `scene-1`.
OcptShotListSnapshot _buildShotList({required List<OcptShot> shots}) => OcptShotListSnapshot.build(
  screenplayId: "screenplay-1",
  sequences: [
    OcptSceneShotSequence(
      sceneId: "scene-1",
      heading: "INT. HOUSE - DAY",
      sceneNumber: null,
      displaySceneNumber: "1",
      charStart: 0,
      charEnd: 10,
      shots: shots,
    ),
  ],
);

/// Builds a scene-element link with the few fields these tests read, everything else neutral.
OcptSceneElementLink _buildSceneElementLink({required String id, required String sceneId}) =>
    OcptSceneElementLink(id: id, sceneId: sceneId, quantity: "", notes: "");

/// Builds an element with the few fields these tests read, everything else neutral.
OcptElement _buildElement({
  required String id,
  required String name,
  required String code,
  OcptElementCategory category = OcptElementCategory.prop,
  List<OcptSceneElementLink> sceneLinks = const [],
}) => OcptElement(
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: code,
  quantity: "",
  sourceKind: OcptElementSourceKind.owned,
  status: OcptElementStatus.toFind,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: null,
  storageNotes: "",
  isSecured: false,
  isReadyForShoot: false,
  isReturned: false,
  cost: null,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: sceneLinks,
  roleLinks: const [],
);

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days/slots/blocks, plus
/// whichever catalogues a test needs — mirrors
/// `ocpt_shooting_plan_pdf_service_test.dart`'s own `_buildSnapshot`.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, List<OcptShootingDayBlock>> blocksByDayId = const {},
  List<OcptLocation> locations = const [],
  List<OcptRole> roles = const [],
  List<OcptElement> elements = const [],
  OcptShotListSnapshot? shotList,
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: blocksByDayId,
    eventsByDayId: const {},
  ),
  shotList: shotList,
  locations: locations,
  roles: roles,
  people: const [],
  elements: elements,
  minimumRestMinutes: null,
);

void main() {
  const presenceMark = "x";
  const persoLabel = "Cast";
  const sequenceRowPrefix = "Seq.";
  const emptyValue = "—";

  OcptShootingPlanGrids buildGrids({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    Map<String, String> crewPositionLabelById = const {},
    Map<OcptElementCategory, String> elementCategoryLabels = const {},
  }) => OcptShootingPlanGrids.of(
    plan: plan,
    dayIds: dayIds,
    presenceMark: presenceMark,
    persoLabel: persoLabel,
    sequenceRowPrefix: sequenceRowPrefix,
    emptyValue: emptyValue,
    crewPositionLabelById: crewPositionLabelById,
    elementCategoryLabels: elementCategoryLabels,
  );

  group("slotColumns/dayColumns", () {
    test("a day with two parallel slots produces two slot columns under the same day", () {
      final day = _buildDay(id: "day-1", dayNumber: 3);
      final slotA = _buildSlot(id: "slot-a", shootingDayId: "day-1", label: "Morning");
      final slotB = _buildSlot(id: "slot-b", shootingDayId: "day-1", label: "Evening");

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slotA, slotB],
          },
        ),
        dayIds: const ["day-1"],
      );

      expect(grids.slotColumns, hasLength(2));
      expect(grids.slotColumns[0].slotId, "slot-a");
      expect(grids.slotColumns[0].slotLabel, "Morning");
      expect(grids.slotColumns[1].slotId, "slot-b");
      expect(grids.slotColumns.every((column) => column.dayId == "day-1"), isTrue);
      expect(grids.slotColumns.every((column) => column.dayNumber == 3), isTrue);
    });

    test("a day with no live slot contributes no slot column but still a day column", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);

      final grids = buildGrids(
        plan: _buildSnapshot(days: [day], slotsByDayId: const {}),
        dayIds: const ["day-1"],
      );

      expect(grids.slotColumns, isEmpty);
      expect(grids.dayColumns, [day]);
    });
  });

  group("locationsRows", () {
    test("a location used on two days is one name row and one Perso. row spanning both", () {
      final location = _buildLocation(id: "loc-a", name: "Studio A");
      final dayOne = _buildDay(id: "day-1", dayNumber: 1);
      final dayTwo = _buildDay(id: "day-2", dayNumber: 2);
      final person = _buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1");
      final slotOne = _buildSlot(id: "slot-1", shootingDayId: "day-1", locationId: "loc-a", crew: [person]);
      final slotTwo = _buildSlot(id: "slot-2", shootingDayId: "day-2", locationId: "loc-a");

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [dayOne, dayTwo],
          slotsByDayId: {
            "day-1": [slotOne],
            "day-2": [slotTwo],
          },
          locations: [location],
        ),
        dayIds: const ["day-1", "day-2"],
      );

      expect(grids.locationsRows, hasLength(2));
      final nameRow = grids.locationsRows[0];
      expect(nameRow.label, "Studio A");
      expect(nameRow.isBold, isTrue);
      // No set chosen on either slot, so both columns fall back to the presence mark.
      expect(nameRow.cells, [presenceMark, presenceMark]);

      final persoRow = grids.locationsRows[1];
      expect(persoRow.label, persoLabel);
      expect(persoRow.isIndented, isTrue);
      expect(persoRow.isMuted, isTrue);
      expect(persoRow.cells, ["", ""]);
    });

    test("a slot shot at another location leaves that column blank, not the presence mark", () {
      final locationA = _buildLocation(id: "loc-a", name: "Studio A");
      final locationB = _buildLocation(id: "loc-b", name: "Studio B");
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slotA = _buildSlot(id: "slot-a", shootingDayId: "day-1", locationId: "loc-a");
      final slotB = _buildSlot(id: "slot-b", shootingDayId: "day-1", locationId: "loc-b");

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slotA, slotB],
          },
          locations: [locationA, locationB],
        ),
        dayIds: const ["day-1"],
      );

      final rowForA = grids.locationsRows.firstWhere((row) => row.label == "Studio A");
      expect(rowForA.cells, [presenceMark, ""]);
    });

    test("a location with a blank name falls back to the caller's own empty value", () {
      final location = _buildLocation(id: "loc-a", name: "   ");
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", locationId: "loc-a");

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
          locations: [location],
        ),
        dayIds: const ["day-1"],
      );

      expect(grids.locationsRows.first.label, emptyValue);
    });
  });

  group("sequencesRows", () {
    test("a sequence shot across two slots produces one row with both slots' own ranks", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slotA = _buildSlot(id: "slot-a", shootingDayId: "day-1");
      final slotB = _buildSlot(id: "slot-b", shootingDayId: "day-1");
      final shot1 = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final shot2 = _buildShot(id: "shot-2", sceneId: "scene-1", code: "1/2");
      final blockA = _buildBlock(id: "block-a", shootingDayId: "day-1", slotId: "slot-a", shotId: "shot-1");
      final blockB = _buildBlock(id: "block-b", shootingDayId: "day-1", slotId: "slot-b", shotId: "shot-2");

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slotA, slotB],
          },
          blocksByDayId: {
            "day-1": [blockA, blockB],
          },
          shotList: _buildShotList(shots: [shot1, shot2]),
        ),
        dayIds: const ["day-1"],
      );

      expect(grids.sequencesRows, hasLength(1));
      final row = grids.sequencesRows.first;
      expect(row.label, "Seq. 1");
      expect(row.cells, ["1", "2"]);
    });

    test("a sequence with no shot placed anywhere in the printed range contributes no row", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1");
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
          shotList: _buildShotList(shots: [shot]),
        ),
        dayIds: const ["day-1"],
      );

      expect(grids.sequencesRows, isEmpty);
    });
  });

  group("peopleRows", () {
    test("an uncast role convoked on a slot prints the presence mark", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final cast = _buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1");
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", cast: [cast]);
      final role = _buildRole(id: "role-1", name: "Cop", number: 3);

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
          roles: [role],
        ),
        dayIds: const ["day-1"],
      );

      expect(grids.peopleRows, hasLength(1));
      expect(grids.peopleRows.first.label, "3 · Cop");
      expect(grids.peopleRows.first.isBold, isFalse);
      expect(grids.peopleRows.first.cells, [presenceMark]);
    });

    test("a role convoked on no slot of the printed range contributes no row", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1");
      final role = _buildRole(id: "role-1", name: "Cop", number: 3);

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
          roles: [role],
        ),
        dayIds: const ["day-1"],
      );

      expect(grids.peopleRows, isEmpty);
    });

    test("a held crew position lists the first names of who holds it", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final crew = _buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1");
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", crew: [crew]);

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
        ),
        dayIds: const ["day-1"],
        crewPositionLabelById: const {"gaffer": "Gaffer"},
      );

      expect(grids.peopleRows, hasLength(1));
      expect(grids.peopleRows.first.label, "Gaffer");
      expect(grids.peopleRows.first.isBold, isTrue);
    });
  });

  group("elementsRows", () {
    test("an element linked to a scene played on one day of the range marks only that day", () {
      final dayOne = _buildDay(id: "day-1", dayNumber: 1);
      final dayTwo = _buildDay(id: "day-2", dayNumber: 2);
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1");
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final block = _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-1");
      final element = _buildElement(
        id: "el-1",
        name: "Coat",
        code: "PRP-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );

      final grids = buildGrids(
        plan: _buildSnapshot(
          days: [dayOne, dayTwo],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [block],
          },
          shotList: _buildShotList(shots: [shot]),
          elements: [element],
        ),
        dayIds: const ["day-1", "day-2"],
        elementCategoryLabels: const {OcptElementCategory.prop: "Props"},
      );

      expect(grids.dayColumns, [dayOne, dayTwo]);
      expect(grids.elementsRows, hasLength(2));

      final band = grids.elementsRows[0] as OcptShootingPlanElementsGridCategoryBand;
      expect(band.label, "Props");

      final elementRow = grids.elementsRows[1] as OcptShootingPlanElementsGridElementRow;
      expect(elementRow.label, "PRP-1 · Coat");
      expect(elementRow.cells, [presenceMark, ""]);
    });

    test("an element linked to no scene of the printed range contributes no row", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final element = _buildElement(
        id: "el-1",
        name: "Coat",
        code: "PRP-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-unused")],
      );

      final grids = buildGrids(
        plan: _buildSnapshot(days: [day], slotsByDayId: const {}, elements: [element]),
        dayIds: const ["day-1"],
        elementCategoryLabels: const {OcptElementCategory.prop: "Props"},
      );

      expect(grids.elementsRows, isEmpty);
    });
  });
}
