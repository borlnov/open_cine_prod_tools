// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber}) => OcptShootingDay(
  id: id,
  screenplayId: "screenplay-1",
  date: DateTime(2026, 1, dayNumber),
  dayNumber: dayNumber,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a slot with the few fields these tests read, everything else neutral: start-anchored at
/// [anchorMinute] unless [anchorEdge] says otherwise.
OcptShootingSlot _buildSlot({
  required String id,
  String? locationId,
  OcptShootingSlotAnchorEdge anchorEdge = OcptShootingSlotAnchorEdge.start,
  int? anchorMinute,
  String? anchorSlotId,
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
  List<OcptShootingSlotGuest> guests = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: "day-1",
  label: "",
  locationId: locationId,
  setId: null,
  anchorEdge: anchorEdge,
  anchorMinute: anchorMinute,
  anchorSlotId: anchorSlotId,
  notes: "",
  crew: crew,
  cast: cast,
  guests: guests,
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required String id,
  required String slotId,
  OcptShootingBlockKind kind = OcptShootingBlockKind.preparation,
  String? shotId,
  int? durationMinutes = 30,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: slotId,
  kind: kind,
  shotId: shotId,
  sceneId: null,
  label: "",
  durationMinutes: durationMinutes,
  anchorMinute: null,
  notes: "",
  crewNote: "",
);

/// Builds a crew member with the few fields these tests read, everything else neutral.
OcptShootingSlotCrewMember _buildCrewMember({
  required String id,
  required String slotId,
  required String personId,
}) => OcptShootingSlotCrewMember(
  id: id,
  slotId: slotId,
  personId: personId,
  positionId: "gaffer",
  customLabel: "",
  notes: "",
);

/// Builds a cast member with the few fields these tests read, everything else neutral.
OcptShootingSlotCastMember _buildCastMember({
  required String id,
  required String slotId,
  required String roleId,
}) => OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required String name, String? personId}) => OcptRole(
  id: id,
  screenplayId: "screenplay-1",
  name: name,
  personId: personId,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
);

/// Builds a location with the few fields these tests read, everything else neutral.
OcptLocation _buildLocation({required String id, double? latitude, double? longitude}) =>
    OcptLocation(
      id: id,
      name: "",
      colorIndex: 0,
      addressLine1: "",
      addressLine2: "",
      postalCode: "",
      city: "",
      region: "",
      country: "",
      latitude: latitude,
      longitude: longitude,
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

/// Builds a person with the few fields these tests read, everything else neutral.
OcptPerson _buildPerson({
  required String id,
  String firstName = "",
  List<OcptPersonUnavailability> unavailabilities = const [],
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
  positions: const [],
  skills: const [],
  unavailabilities: unavailabilities,
);

/// Builds an unavailability window with the few fields these tests read, everything else neutral.
OcptPersonUnavailability _buildUnavailability({
  required String id,
  required String personId,
  required DateTime startDate,
  required DateTime endDate,
}) => OcptPersonUnavailability(
  id: id,
  personId: personId,
  startDate: startDate,
  endDate: endDate,
  slot: OcptDayPartSlot.fullDay,
  startMinute: null,
  endMinute: null,
  reason: "",
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({
  required String id,
  String sceneId = "scene-1",
  List<String> characters = const [],
}) => OcptShot(
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
  characters: characters,
  coverageRanges: const [],
  code: "1/1",
  averageDifficulty: 0,
);

/// Builds a one-shot shot list, its single scene sequence holding [shots].
OcptShotListSnapshot _buildShotList({required List<OcptShot> shots}) => OcptShotListSnapshot.build(
  screenplayId: "screenplay-1",
  sequences: [
    OcptSceneShotSequence(
      sceneId: "scene-1",
      heading: "INT. KITCHEN - DAY",
      sceneNumber: null,
      displaySceneNumber: "1",
      charStart: 0,
      charEnd: 0,
      shots: shots,
    ),
  ],
);

/// Builds a shot list holding two scenes — `scene-1` (`INT. KITCHEN - DAY`) and `scene-2`
/// (`EXT. STREET - NIGHT`) — what `effectCategoryOfDay`'s own "mixed" test places its two shots in.
OcptShotListSnapshot _buildTwoSceneShotList({
  required List<OcptShot> sceneOneShots,
  required List<OcptShot> sceneTwoShots,
}) => OcptShotListSnapshot.build(
  screenplayId: "screenplay-1",
  sequences: [
    OcptSceneShotSequence(
      sceneId: "scene-1",
      heading: "INT. KITCHEN - DAY",
      sceneNumber: null,
      displaySceneNumber: "1",
      charStart: 0,
      charEnd: 0,
      shots: sceneOneShots,
    ),
    OcptSceneShotSequence(
      sceneId: "scene-2",
      heading: "EXT. STREET - NIGHT",
      sceneNumber: null,
      displaySceneNumber: "2",
      charStart: 0,
      charEnd: 0,
      shots: sceneTwoShots,
    ),
  ],
);

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days/slots/blocks, plus
/// whichever catalogues a test needs — everything else defaulting to empty, exactly as
/// `OcptScheduleState.init()` does.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, List<OcptShootingDayBlock>> blocksByDayId = const {},
  Map<String, List<OcptShootingDayEvent>> eventsByDayId = const {},
  OcptShotListSnapshot? shotList,
  List<OcptLocation> locations = const [],
  List<OcptRole> roles = const [],
  List<OcptPerson> people = const [],
  Map<(String, String), OcptPresenceCode> presenceOverrideByDayAndPerson = const {},
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    screenplayId: "screenplay-1",
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: blocksByDayId,
    eventsByDayId: eventsByDayId,
    presenceOverrideByDayAndPerson: presenceOverrideByDayAndPerson,
  ),
  shotList: shotList,
  locations: locations,
  roles: roles,
  people: people,
);

void main() {
  group("timelinesOfDay", () {
    test("resolves an end-anchored slot's own hours against a start-anchored one", () {
      final startSlot = _buildSlot(id: "slot-start", anchorMinute: 480);
      final endSlot = _buildSlot(
        id: "slot-end",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [startSlot, endSlot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "block-start", slotId: "slot-start", durationMinutes: 60),
            _buildBlock(id: "block-end", slotId: "slot-end", durationMinutes: 90),
          ],
        },
      );

      final timelines = snapshot.timelinesOfDay("day-1")!;

      expect(timelines.bySlotId["slot-start"]!.startMinute, 480);
      expect(timelines.bySlotId["slot-start"]!.endMinute, 540);
      // The end-anchored slot starts at 720 − 90 = 630 and lands exactly on its own fixed end.
      expect(timelines.bySlotId["slot-end"]!.startMinute, 630);
      expect(timelines.bySlotId["slot-end"]!.endMinute, 720);
      expect(timelines.dayStartMinute, 480);
      expect(timelines.dayEndMinute, 720);
    });

    test("a night slot crossing midnight keeps its minutes above 1440", () {
      final slot = _buildSlot(id: "slot-1", anchorMinute: 1140); // 19:00
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", slotId: "slot-1", durationMinutes: 480)],
        },
      );

      final timeline = snapshot.timelinesOfDay("day-1")!.bySlotId["slot-1"]!;

      // 19:00 + 8h = 03:00 the next day, stored as 1620 rather than wrapped to 180.
      expect(timeline.startMinute, 1140);
      expect(timeline.endMinute, 1620);
    });
  });

  group("convocationsOfDay", () {
    test("a slot with no block gives a convoked person no PAT band, departing on arrival", () {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      expect(convocation.personId, "person-1");
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 480);
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
    });

    test("a person on two slots reads one band spanning both, gaps included", () {
      final morning = _buildSlot(
        id: "slot-morning",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1")],
      );
      final evening = _buildSlot(
        id: "slot-evening",
        anchorMinute: 1080,
        crew: [_buildCrewMember(id: "crew-2", slotId: "slot-evening", personId: "person-1")],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [morning, evening],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-morning",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
            _buildBlock(
              id: "block-evening",
              slotId: "slot-evening",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-2",
              durationMinutes: 60,
            ),
          ],
        },
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      expect(convocation.arrivalMinute, 480);
      // The band spans from the morning's own shot to the evening's own, the gap between the two
      // slots included — it is not clipped to either slot alone.
      expect(convocation.patStartMinute, 480);
      expect(convocation.patEndMinute, 1140);
      expect(convocation.departureMinute, 1140);
      expect(convocation.slotIds, ["slot-morning", "slot-evening"]);
    });

    test("an uncast role gets its own convocation; a cast one resolves through roles.personId", () {
      final castRole = _buildRole(id: "role-cast", name: "Alice", personId: "person-1");
      final uncastRole = _buildRole(id: "role-uncast", name: "Bob");
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        cast: [
          _buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-cast"),
          _buildCastMember(id: "cast-2", slotId: "slot-1", roleId: "role-uncast"),
        ],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        roles: [castRole, uncastRole],
      );

      final convocations = snapshot.convocationsOfDay("day-1");

      expect(convocations, hasLength(2));
      final castConvocation = convocations.firstWhere((c) => c.personId == "person-1");
      expect(castConvocation.roleId, isNull);
      final uncastConvocation = convocations.firstWhere((c) => c.roleId == "role-uncast");
      expect(uncastConvocation.personId, isNull);
    });
  });

  group("sunTimesOfDay", () {
    test("returns null while the day's first location has no coordinates pinned", () {
      final location = _buildLocation(id: "location-1");
      final slot = _buildSlot(id: "slot-1", locationId: "location-1", anchorMinute: 480);
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [location],
      );

      expect(snapshot.sunTimesOfDay("day-1"), isNull);
    });
  });

  group("a day with no live slot at all", () {
    test("firstLocationOfDay and dayArrivalMinute both answer null", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(days: [day], slotsByDayId: const {});

      expect(snapshot.firstLocationOfDay("day-1"), isNull);
      expect(snapshot.dayArrivalMinute("day-1"), isNull);
      expect(snapshot.timelinesOfDay("day-1"), isNull);
      expect(snapshot.convocationsOfDay("day-1"), isEmpty);
    });
  });

  group("effectCategoryOfDay", () {
    test("null while nothing is placed on the day at all", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
      final snapshot = _buildSnapshot(days: [day], slotsByDayId: {"day-1": [slot]});

      expect(snapshot.effectCategoryOfDay("day-1"), isNull);
    });

    test("a single category when every placed shot's own scene heading agrees", () {
      final shot = _buildShot(id: "shot-1"); // scene-1: INT. KITCHEN - DAY
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        shotList: _buildShotList(shots: [shot]),
      );

      expect(snapshot.effectCategoryOfDay("day-1"), OcptSceneEffectCategory.interiorDay);
    });

    test("mixed when two placed shots' own scenes disagree", () {
      final sceneOneShot = _buildShot(id: "shot-1"); // INT. KITCHEN - DAY
      final sceneTwoShot = _buildShot(id: "shot-2", sceneId: "scene-2"); // EXT. STREET - NIGHT
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
            _buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-2",
              durationMinutes: 60,
            ),
          ],
        },
        shotList: _buildTwoSceneShotList(sceneOneShots: [sceneOneShot], sceneTwoShots: [sceneTwoShot]),
      );

      expect(snapshot.effectCategoryOfDay("day-1"), OcptSceneEffectCategory.mixed);
    });

    test("a hold block naming a sequence with a known heading contributes nothing — only a shot "
        "block's own scene counts", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {"day-1": [slot]},
        blocksByDayId: {
          "day-1": [
            const OcptShootingDayBlock(
              id: "hold-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.hold,
              shotId: null,
              sceneId: "scene-1",
              label: "",
              durationMinutes: 60,
              anchorMinute: null,
              notes: "",
              crewNote: "",
            ),
          ],
        },
        shotList: _buildShotList(shots: const []),
      );

      expect(snapshot.effectCategoryOfDay("day-1"), isNull);
    });
  });

  group("alerts", () {
    test("a person linked to two overlapping slots surfaces as a double-booking alert", () {
      final slotA = _buildSlot(
        id: "slot-a",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-a", personId: "person-1")],
      );
      final slotB = _buildSlot(
        id: "slot-b",
        anchorMinute: 550,
        crew: [_buildCrewMember(id: "crew-2", slotId: "slot-b", personId: "person-1")],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slotA, slotB],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "block-a", slotId: "slot-a", durationMinutes: 200),
            _buildBlock(id: "block-b", slotId: "slot-b", durationMinutes: 200),
          ],
        },
      );

      final alert = snapshot.alerts.whereType<OcptSchedulePersonDoubleBookedAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.personId, "person-1");
    });

    test("a shot's character matched to a role convoked nowhere surfaces the role-not-convoked "
        "alert", () {
      final role = _buildRole(id: "role-1", name: "Alice");
      final shot = _buildShot(id: "shot-1", characters: const ["ALICE"]);
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480); // nobody cast on it
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        shotList: _buildShotList(shots: [shot]),
        roles: [role],
      );

      final alert = snapshot.alerts.whereType<OcptScheduleRoleNotConvokedAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.roleId, "role-1");
      expect(alert.shotId, "shot-1");
    });

    test("is computed once, not once per read", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(days: [day], slotsByDayId: const {});

      expect(identical(snapshot.alerts, snapshot.alerts), isTrue);
    });
  });

  group("presenceCellOf", () {
    test("reads working when the person is convoked on a slot of the day", () {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final person = _buildPerson(id: "person-1");
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        people: [person],
      );

      final cell = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(cell.code, OcptPresenceCode.working);
      expect(cell.isOverridden, isFalse);
    });

    test("reads unavailable when not convoked but a window covers the day's date", () {
      final day = _buildDay(id: "day-1", dayNumber: 1); // 2026-01-01, per _buildDay
      final person = _buildPerson(
        id: "person-1",
        unavailabilities: [
          _buildUnavailability(
            id: "unavailability-1",
            personId: "person-1",
            startDate: DateTime(2025, 12, 31),
            endDate: DateTime(2026, 1, 3),
          ),
        ],
      );
      final snapshot = _buildSnapshot(days: [day], slotsByDayId: const {}, people: [person]);

      final cell = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(cell.code, OcptPresenceCode.unavailable);
      expect(cell.isOverridden, isFalse);
    });

    test("reads blank — neither convoked nor covered by a window", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final person = _buildPerson(id: "person-1");
      final snapshot = _buildSnapshot(days: [day], slotsByDayId: const {}, people: [person]);

      final cell = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(cell.code, isNull);
      expect(cell.isOverridden, isFalse);
    });

    test("a live override always wins over the computed reading", () {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final person = _buildPerson(id: "person-1");
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        people: [person],
        // Computed would read `working` — the override says otherwise, and wins.
        presenceOverrideByDayAndPerson: {("day-1", "person-1"): OcptPresenceCode.unavailable},
      );

      final cell = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(cell.code, OcptPresenceCode.unavailable);
      expect(cell.isOverridden, isTrue);
    });
  });
}
