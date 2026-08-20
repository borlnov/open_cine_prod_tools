// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
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
  List<OcptShootingSlotCandidate> candidates = const [],
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
  candidates: candidates,
);

/// Builds a candidacy — somebody seen for a part — with the few fields these tests read.
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

/// Builds a candidate's own convocation on a slot, with the few fields these tests read.
OcptShootingSlotCandidate _buildSlotCandidate({
  required String id,
  required String slotId,
  required String roleCandidateId,
}) => OcptShootingSlotCandidate(
  id: id,
  slotId: slotId,
  roleCandidateId: roleCandidateId,
  notes: "",
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
  roleId: null,
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

/// Builds a guest attendance with the few fields these tests read, everything else neutral.
OcptShootingSlotGuest _buildGuest({
  required String id,
  required String slotId,
  String? personId,
  String freeName = "",
}) => OcptShootingSlotGuest(
  id: id,
  slotId: slotId,
  personId: personId,
  freeName: freeName,
  reason: "",
  notes: "",
);

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required String name, String? personId}) => OcptRole(
  id: id,
  name: name,
  personId: personId,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

/// Builds a location with the few fields these tests read, everything else neutral.
OcptLocation _buildLocation({
  required String id,
  double? latitude,
  double? longitude,
  OcptAssetRef? permitDocument,
}) => OcptLocation(
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
  permitDocument: permitDocument,
  availabilities: const [],
);

/// Builds a permit document (an `assets` row of kind [OcptAssetKind.document]) with the few fields
/// these tests read, everything else neutral.
OcptAssetRef _buildPermitDocument({
  required String id,
  required String locationId,
  DateTime? validFrom,
  DateTime? validUntil,
}) => OcptAssetRef(
  id: id,
  kind: OcptAssetKind.document,
  path: "",
  label: "",
  addedAt: DateTime(2026),
  personId: null,
  locationId: locationId,
  elementId: null,
  validFrom: validFrom,
  validUntil: validUntil,
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

/// Builds an element with the few fields these tests read, everything else neutral.
OcptElement _buildElement({
  required String id,
  String name = "",
  OcptElementCategory category = OcptElementCategory.prop,
  String? broughtByPersonId,
  List<OcptSceneElementLink> sceneLinks = const [],
}) => OcptElement(
  id: id,
  category: category,
  subCategory: "",
  name: name,
  code: "",
  quantity: "1",
  sourceKind: OcptElementSourceKind.owned,
  status: OcptElementStatus.toFind,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: broughtByPersonId,
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

/// Builds a *dépouillement* link with the few fields these tests read, everything else neutral.
OcptSceneElementLink _buildSceneElementLink({required String id, required String sceneId}) =>
    OcptSceneElementLink(id: id, sceneId: sceneId, quantity: "1", notes: "");

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

/// Builds a one-scene, one-shot shot list for one episode, its scene's own display number already
/// carrying the `<episode>.<scene>` prefix `OcptShotListService.loadShotList` would have given it —
/// what the "multiple episodes" tests below merge across [OcptSchedulePlanSnapshot.shotLists].
OcptShotListSnapshot _buildEpisodeShotList({
  required String screenplayId,
  required String sceneId,
  required String heading,
  required String displaySceneNumber,
  required OcptShot shot,
}) => OcptShotListSnapshot.build(
  screenplayId: screenplayId,
  sequences: [
    OcptSceneShotSequence(
      sceneId: sceneId,
      heading: heading,
      sceneNumber: null,
      displaySceneNumber: displaySceneNumber,
      charStart: 0,
      charEnd: 0,
      shots: [shot],
    ),
  ],
);

/// Builds an [OcptSchedulePlanSnapshot] over one project's worth of days/slots/blocks, plus
/// whichever catalogues a test needs — everything else defaulting to empty, exactly as
/// `OcptScheduleState.init()` does.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, List<OcptShootingDayBlock>> blocksByDayId = const {},
  Map<String, List<OcptShootingDayEvent>> eventsByDayId = const {},
  List<OcptShotListSnapshot> shotLists = const [],
  List<OcptEpisode> episodes = const [],
  List<OcptLocation> locations = const [],
  List<OcptRole> roles = const [],
  List<OcptPerson> people = const [],
  List<OcptElement> elements = const [],
  List<OcptRoleCandidate> roleCandidates = const [],
  int? minimumRestMinutes,
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: blocksByDayId,
    eventsByDayId: eventsByDayId,
  ),
  shotLists: shotLists,
  episodes: episodes,
  locations: locations,
  roles: roles,
  people: people,
  elements: elements,
  roleCandidates: roleCandidates,
  minimumRestMinutes: minimumRestMinutes,
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

    test("a guest reads as its own convocation, with an arrival and a departure but no PAT band", () {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        guests: [_buildGuest(id: "guest-1", slotId: "slot-1", personId: "person-guest")],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
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
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      expect(convocation.isGuest, isTrue);
      expect(convocation.guestPersonId, "person-guest");
      expect(convocation.personId, isNull);
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 540);
      expect(convocation.patStartMinute, isNull);
      expect(convocation.patEndMinute, isNull);
    });

    test("a candidate convoked on a day reads a band over its auditions", () {
      final person = _buildPerson(id: "person-1", firstName: "Camille");
      final candidacy = _buildCandidacy(id: "candidacy-1", roleId: "role-1", person: person);
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 540,
        candidates: [
          _buildSlotCandidate(id: "convocation-1", slotId: "slot-1", roleCandidateId: "candidacy-1"),
        ],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-arrival",
              slotId: "slot-1",
              durationMinutes: 15,
            ),
            _buildBlock(
              id: "block-audition",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
            ),
          ],
        },
        people: [person],
        roleCandidates: [candidacy],
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      // An audition is shooting time, the preparation before it is not: the band opens where the
      // candidate is actually seen, and the arrival stays the slot's own start.
      expect(convocation.isCandidate, isTrue);
      expect(convocation.roleCandidateId, "candidacy-1");
      expect(convocation.arrivalMinute, 540);
      expect(convocation.patStartMinute, 555);
      expect(convocation.patEndMinute, 575);
      expect(convocation.departureMinute, 575);
    });

    test("a rehearsal block opens a band exactly as a shot does", () {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 540,
        cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-rehearsal",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.rehearsal,
              durationMinutes: 90,
            ),
          ],
        },
        roles: [_buildRole(id: "role-1", name: "MARIE", personId: "person-1")],
      );

      final convocation = snapshot.convocationsOfDay("day-1").single;

      expect(convocation.personId, "person-1");
      expect(convocation.patStartMinute, 540);
      expect(convocation.patEndMinute, 630);
    });

    test("a convocation onto a candidacy that has since been removed convokes nobody", () {
      // No cascade drops a `shooting_slot_candidates` row when its candidacy is removed — the row
      // is read defensively instead, and drops out here.
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 540,
        candidates: [
          _buildSlotCandidate(id: "convocation-1", slotId: "slot-1", roleCandidateId: "gone"),
        ],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
      );

      expect(snapshot.convocationsOfDay("day-1"), isEmpty);
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
        shotLists: [_buildShotList(shots: [shot])],
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
        shotLists: [_buildTwoSceneShotList(sceneOneShots: [sceneOneShot], sceneTwoShots: [sceneTwoShot])],
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
              roleId: null,
            ),
          ],
        },
        shotLists: [_buildShotList(shots: const [])],
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
        shotLists: [_buildShotList(shots: [shot])],
        roles: [role],
      );

      final alert = snapshot.alerts.whereType<OcptScheduleRoleNotConvokedAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.roleId, "role-1");
      expect(alert.shotId, "shot-1");
    });

    test("a day spent rehearsing double-books a person exactly as a shooting one does", () {
      // Every alert about people is blind to what a day holds, and deliberately: a rehearsal eats
      // a person's day like a shoot does, and the plan is just as broken either way.
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
            _buildBlock(
              id: "block-a",
              slotId: "slot-a",
              kind: OcptShootingBlockKind.rehearsal,
              durationMinutes: 200,
            ),
            _buildBlock(
              id: "block-b",
              slotId: "slot-b",
              kind: OcptShootingBlockKind.rehearsal,
              durationMinutes: 200,
            ),
          ],
        },
      );

      final alert = snapshot.alerts.whereType<OcptSchedulePersonDoubleBookedAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.personId, "person-1");
    });

    test("a day of auditions raises no role-not-convoked alert, carrying no shot to call one", () {
      // The rule is about a role a **placed shot** plays, so it finds nothing on a day whose
      // timetable holds auditions alone: it needs no special case of its own, and gets none.
      final role = _buildRole(id: "role-1", name: "Alice");
      final shot = _buildShot(id: "shot-1", characters: const ["ALICE"]);
      final slot = _buildSlot(id: "slot-1", anchorMinute: 540);
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-audition",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
            ),
          ],
        },
        shotLists: [_buildShotList(shots: [shot])],
        roles: [role],
      );

      expect(snapshot.alerts.whereType<OcptScheduleRoleNotConvokedAlert>(), isEmpty);
    });

    test("a candidate's own convocation raises nothing at all", () {
      // Deliberately, and on the guests' own argument: a candidate holds no position to lose, has
      // no daily maximum of the production's making and is not cast. Their convocation is read
      // everywhere it is owed an hour, and nowhere a rule is about somebody's work.
      final person = _buildPerson(id: "person-1", firstName: "Camille");
      final candidacy = _buildCandidacy(id: "candidacy-1", roleId: "role-1", person: person);
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 540,
        candidates: [
          _buildSlotCandidate(id: "convocation-1", slotId: "slot-1", roleCandidateId: "candidacy-1"),
        ],
      );
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-audition",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
            ),
          ],
        },
        people: [person],
        roleCandidates: [candidacy],
      );

      expect(snapshot.alerts, isEmpty);
      // And they are convoked all the same: the reading the `Convocations` tab gives is untouched
      // by the alerts saying nothing about them.
      expect(snapshot.convocationsOfDay("day-1").single.roleCandidateId, "candidacy-1");
    });

    test("a location's dated permit document not covering the day surfaces the permit alert", () {
      final location = _buildLocation(
        id: "location-1",
        permitDocument: _buildPermitDocument(
          id: "permit-1",
          locationId: "location-1",
          validFrom: DateTime(2026, 2),
          validUntil: DateTime(2026, 2, 28),
        ),
      );
      final slot = _buildSlot(id: "slot-1", locationId: "location-1", anchorMinute: 480);
      final day = _buildDay(id: "day-1", dayNumber: 1); // date: 2026-01-01, per _buildDay
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [location],
      );

      final alert = snapshot.alerts.whereType<OcptSchedulePermitNotValidAlert>().single;
      expect(alert.dayId, "day-1");
      expect(alert.slotId, "slot-1");
      expect(alert.locationId, "location-1");
    });

    test("a permit document recording neither date raises nothing — the same reading as no permit "
        "at all", () {
      final location = _buildLocation(
        id: "location-1",
        permitDocument: _buildPermitDocument(id: "permit-1", locationId: "location-1"),
      );
      final slot = _buildSlot(id: "slot-1", locationId: "location-1", anchorMinute: 480);
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [location],
      );

      expect(snapshot.alerts.whereType<OcptSchedulePermitNotValidAlert>(), isEmpty);
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

      final code = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(code, OcptPresenceCode.working);
    });

    test("a guest is never working — attending is not being convoked to work", () {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        guests: [_buildGuest(id: "guest-1", slotId: "slot-1", personId: "person-1")],
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

      final code = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(code, isNot(OcptPresenceCode.working));
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

      final code = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(code, OcptPresenceCode.unavailable);
    });

    test("reads blank — neither convoked nor covered by a window", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final person = _buildPerson(id: "person-1");
      final snapshot = _buildSnapshot(days: [day], slotsByDayId: const {}, people: [person]);

      final code = snapshot.presenceCellOf(dayId: "day-1", personId: "person-1");

      expect(code, isNull);
    });
  });

  group("sceneIdsOfDay", () {
    test("the scene ids of the day's own shot blocks, deduplicated", () {
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final shotOne = _buildShot(id: "shot-1");
      final shotTwo = _buildShot(id: "shot-2");
      final shotThree = _buildShot(id: "shot-3", sceneId: "scene-2");
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "block-1", slotId: "slot-1", kind: OcptShootingBlockKind.shot, shotId: "shot-1"),
            _buildBlock(id: "block-2", slotId: "slot-1", kind: OcptShootingBlockKind.shot, shotId: "shot-2"),
            _buildBlock(id: "block-3", slotId: "slot-1", kind: OcptShootingBlockKind.shot, shotId: "shot-3"),
            // A milestone block names no shot and contributes nothing.
            _buildBlock(id: "block-4", slotId: "slot-1", kind: OcptShootingBlockKind.meal),
          ],
        },
        shotLists: [_buildShotList(shots: [shotOne, shotTwo, shotThree])],
      );

      expect(snapshot.sceneIdsOfDay("day-1"), {"scene-1", "scene-2"});
    });

    test("empty for a day with no shot block at all", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(days: [day], slotsByDayId: const {});

      expect(snapshot.sceneIdsOfDay("day-1"), isEmpty);
    });
  });

  group("sceneSpanBySceneId", () {
    test("a scene sequence's span is read back", () {
      final snapshot = _buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              const OcptSceneShotSequence(
                sceneId: "scene-1",
                heading: "INT. KITCHEN - DAY",
                sceneNumber: null,
                displaySceneNumber: "1",
                charStart: 42,
                charEnd: 108,
                shots: [],
              ),
            ],
          ),
        ],
      );

      expect(snapshot.sceneSpanBySceneId, {
        "scene-1": (charStart: 42, charEnd: 108),
      });
    });

    test("an orphan sequence contributes no entry", () {
      final snapshot = _buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [
          OcptShotListSnapshot.build(
            screenplayId: "screenplay-1",
            sequences: [
              OcptOrphanShotSequence(shots: [_buildShot(id: "shot-1")]),
            ],
          ),
        ],
      );

      expect(snapshot.sceneSpanBySceneId, isEmpty);
    });
  });

  group("convokedRoleIdsOfDay", () {
    test("the union of every live slot's own cast, deduplicated", () {
      final morning = _buildSlot(
        id: "slot-morning",
        anchorMinute: 480,
        cast: [
          _buildCastMember(id: "cast-1", slotId: "slot-morning", roleId: "role-1"),
          _buildCastMember(id: "cast-2", slotId: "slot-morning", roleId: "role-2"),
        ],
      );
      final evening = _buildSlot(
        id: "slot-evening",
        anchorMinute: 1080,
        // The same role, convoked twice in one day, is on that day once.
        cast: [_buildCastMember(id: "cast-3", slotId: "slot-evening", roleId: "role-1")],
      );
      final snapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [morning, evening],
        },
      );

      expect(snapshot.convokedRoleIdsOfDay("day-1"), {"role-1", "role-2"});
    });

    test("names the role even when it is cast, an actor never standing in for it", () {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final snapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        roles: [_buildRole(id: "role-1", name: "Alice", personId: "person-1")],
      );

      expect(snapshot.convokedRoleIdsOfDay("day-1"), {"role-1"});
    });

    test("empty for a day with no slot at all", () {
      final snapshot = _buildSnapshot(days: [_buildDay(id: "day-1", dayNumber: 1)], slotsByDayId: const {});

      expect(snapshot.convokedRoleIdsOfDay("day-1"), isEmpty);
    });
  });

  group("elementsToBringOnDay", () {
    /// A day playing `scene-1` alone, through one placed shot — the fixture every test below places
    /// its element against.
    OcptSchedulePlanSnapshot buildDayPlayingSceneOne({required List<OcptElement> elements}) {
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final shot = _buildShot(id: "shot-1");
      return _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", slotId: "slot-1", kind: OcptShootingBlockKind.shot, shotId: "shot-1")],
        },
        shotLists: [_buildShotList(shots: [shot])],
        elements: elements,
      );
    }

    test("an element brought by the right person but needed in no scene the day plays is absent", () {
      final element = _buildElement(
        id: "element-1",
        name: "Umbrella",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-2")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [element]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-1");

      expect(
        toBring,
        isEmpty,
        reason: "a call sheet says what to bring today, not everything this person was ever assigned",
      );
    });

    test("an element needed in a scene the day plays but brought by somebody else is absent", () {
      final element = _buildElement(
        id: "element-1",
        name: "Umbrella",
        broughtByPersonId: "person-2",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [element]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-1");

      expect(toBring, isEmpty);
    });

    test("an element brought by this person and needed in a scene the day plays is present", () {
      final element = _buildElement(
        id: "element-1",
        name: "Umbrella",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [element]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-1");

      expect(toBring, [element]);
    });

    test("empty for a person id nobody brings anything for", () {
      final element = _buildElement(
        id: "element-1",
        name: "Umbrella",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [element]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-404");

      expect(toBring, isEmpty);
    });

    test("sorted by category then by name", () {
      final costume = _buildElement(
        id: "element-costume",
        name: "Coat",
        category: OcptElementCategory.costume,
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-costume", sceneId: "scene-1")],
      );
      final propB = _buildElement(
        id: "element-prop-b",
        name: "Umbrella",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-prop-b", sceneId: "scene-1")],
      );
      final propA = _buildElement(
        id: "element-prop-a",
        name: "Cane",
        broughtByPersonId: "person-1",
        sceneLinks: [_buildSceneElementLink(id: "link-prop-a", sceneId: "scene-1")],
      );
      final snapshot = buildDayPlayingSceneOne(elements: [costume, propB, propA]);

      final toBring = snapshot.elementsToBringOnDay(dayId: "day-1", personId: "person-1");

      // OcptElementCategory.prop comes before OcptElementCategory.costume in the enum's own
      // declaration order, and within `prop` the two elements sort by name ("Cane" before
      // "Umbrella").
      expect(toBring, [propA, propB, costume]);
    });
  });

  group("multiple episodes", () {
    const episodeOne = OcptEpisode(id: "episode-1", number: 1, title: "");
    const episodeTwo = OcptEpisode(id: "episode-2", number: 2, title: "");

    /// Episode 1's own one-scene shot list: `scene-e1`, prefixed `1.3` — the number
    /// `OcptShotListService.loadShotList` would already have given it.
    OcptShotListSnapshot buildEpisodeOneShotList(OcptShot shot) => _buildEpisodeShotList(
      screenplayId: episodeOne.id,
      sceneId: "scene-e1",
      heading: "INT. HOUSE - DAY",
      displaySceneNumber: "1.3",
      shot: shot,
    );

    /// Episode 2's own one-scene shot list: `scene-e2`, prefixed `2.4`.
    OcptShotListSnapshot buildEpisodeTwoShotList(OcptShot shot) => _buildEpisodeShotList(
      screenplayId: episodeTwo.id,
      sceneId: "scene-e2",
      heading: "EXT. STREET - NIGHT",
      displaySceneNumber: "2.4",
      shot: shot,
    );

    test("resolves shotById for a shot of either episode, and merges the heading and span maps "
        "across both", () {
      final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1");
      final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2");
      final snapshot = _buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        episodes: const [episodeOne, episodeTwo],
      );

      expect(snapshot.shotById("shot-e1"), shotOne);
      expect(snapshot.shotById("shot-e2"), shotTwo);
      expect(snapshot.headingBySceneId, {
        "scene-e1": "INT. HOUSE - DAY",
        "scene-e2": "EXT. STREET - NIGHT",
      });
      expect(snapshot.sceneSpanBySceneId.keys, {"scene-e1", "scene-e2"});
    });

    test("sceneNumberBySceneId returns each episode's own prefixed number, unchanged by the "
        "merge", () {
      final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1");
      final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2");
      final snapshot = _buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        episodes: const [episodeOne, episodeTwo],
      );

      expect(snapshot.sceneNumberBySceneId["scene-e1"], "1.3");
      expect(snapshot.sceneNumberBySceneId["scene-e2"], "2.4");
    });

    test("screenplayIdBySceneId names the right episode for a scene of each", () {
      final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1");
      final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2");
      final snapshot = _buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        episodes: const [episodeOne, episodeTwo],
      );

      expect(snapshot.screenplayIdBySceneId["scene-e1"], episodeOne.id);
      expect(snapshot.screenplayIdBySceneId["scene-e2"], episodeTwo.id);
    });

    test("a day placing shots from both episodes reports both scenes through sceneIdsOfDay", () {
      final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1");
      final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2");
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final snapshot = _buildSnapshot(
        days: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e1",
            ),
            _buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e2",
            ),
          ],
        },
        shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        episodes: const [episodeOne, episodeTwo],
      );

      expect(snapshot.sceneIdsOfDay("day-1"), {"scene-e1", "scene-e2"});
    });

    test("a single-episode plan behaves exactly as before — no prefix anywhere", () {
      final shot = _buildShot(id: "shot-1");
      final snapshot = _buildSnapshot(
        days: const [],
        slotsByDayId: const {},
        shotLists: [_buildShotList(shots: [shot])],
        episodes: const [OcptEpisode(id: "screenplay-1", number: 1, title: "")],
      );

      expect(snapshot.sceneNumberBySceneId["scene-1"], "1");
    });
  });
}
