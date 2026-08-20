// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_guest.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_call_sheet_pdf_service_test.dart` follows.
const _labels = OcptShootingPlanLabels(
  fileNameSuffix: "shooting plan",
  documentTitle: "Shooting plan",
  dayTitles: {"day-1": "Shooting plan for Thursday 10 August 2023"},
  tenMinuteGridSectionTitle: "Ten-minute grid",
  directorLine: '"My Movie" by Jane Doe',
  versionLabel: "Version",
  dayTagPrefix: "D",
  locationsGridTitle: "Summary - Locations",
  sequencesGridTitle: "Summary - Sequences",
  peopleGridTitle: "Summary - Crew and cast",
  elementsGridTitle: "Summary - Elements",
  locationsGridRowHeader: "Location",
  sequencesGridRowHeader: "Sequence",
  peopleGridRowHeader: "Position / Role",
  elementsGridRowHeader: "Element",
  elementCategoryLabels: {
    OcptElementCategory.prop: "Props",
    OcptElementCategory.vehicle: "Vehicles",
    OcptElementCategory.animal: "Animals",
    OcptElementCategory.specialEquipment: "Special equipment",
  },
  persoLabel: "Cast",
  sequenceRowPrefix: "Seq.",
  presenceMark: "x",
  crewPositionLabels: {
    "director": "Director",
    "gaffer": "Gaffer",
    "cameraOperator": "Camera operator",
  },
  dayLocationLabel: "Location",
  dayHoursLabel: "Hours",
  daySetsLabel: "Sets",
  dayTimetableLabel: "Timetable",
  callTimeLabel: "call at",
  estimatedEndLabel: "estimated end",
  milestoneFromLabel: "From",
  milestoneToLabel: "to",
  blockKindLabels: {
    OcptShootingBlockKind.preparation: "Preparation",
    OcptShootingBlockKind.hairMakeUp: "Hair and make-up",
    OcptShootingBlockKind.meal: "Meal break",
    OcptShootingBlockKind.pause: "Break",
    OcptShootingBlockKind.travel: "Travel",
    OcptShootingBlockKind.wrap: "Wrap",
    OcptShootingBlockKind.hold: "Reserved",
  },
  rolesLabel: "CAST",
  hoursHeader: "Hours",
  planHeader: "Plan",
  shotSizeHeader: "Shot size",
  moveHeader: "Move.",
  framingHeader: "Frame",
  commentHeader: "Comment",
  emptyPlanNote: "Nothing planned yet.",
  emptyDayScheduleNote: "Nothing planned for this day yet.",
  eventsSectionTitle: "Events",
  guestsSectionTitle: "Guests",
  guestReasonHeader: "Reason",
  nameHeader: "NAME",
  hoursLinePrefix: "HOURS",
  unnamedPersonLabel: "Unnamed",
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber}) => OcptShootingDay(
  id: id,
  date: DateTime(2026, 1, dayNumber),
  dayNumber: dayNumber,
  kind: OcptShootingDayKind.shoot,
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
  OcptShootingSlotAnchorEdge anchorEdge = OcptShootingSlotAnchorEdge.start,
  int? anchorMinute,
  String? anchorSlotId,
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
  List<OcptShootingSlotGuest> guests = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: shootingDayId,
  label: label,
  locationId: locationId,
  setId: null,
  anchorEdge: anchorEdge,
  anchorMinute: anchorMinute,
  anchorSlotId: anchorSlotId,
  notes: "",
  crew: crew,
  cast: cast,
  guests: guests,
  candidates: const [],
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required String id,
  required String shootingDayId,
  required String slotId,
  OcptShootingBlockKind kind = OcptShootingBlockKind.preparation,
  String? shotId,
  String label = "",
  int? durationMinutes = 30,
  String crewNote = "",
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: shootingDayId,
  slotId: slotId,
  kind: kind,
  shotId: shotId,
  sceneId: null,
  label: label,
  durationMinutes: durationMinutes,
  anchorMinute: null,
  notes: "",
  crewNote: crewNote,
  roleCandidateId: null,
  roleId: null,
);

/// Builds a day event with the few fields these tests read, everything else neutral.
OcptShootingDayEvent _buildEvent({
  required String id,
  required String shootingDayId,
  required int minute,
  String label = "",
  String notes = "",
}) => OcptShootingDayEvent(id: id, shootingDayId: shootingDayId, minute: minute, label: label, notes: notes);

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
OcptShootingSlotCastMember _buildCastMember({
  required String id,
  required String slotId,
  required String roleId,
}) => OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

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
  episodeIds: const [],
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
OcptShot _buildShot({
  required String id,
  String? sceneId,
  required String code,
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
  code: code,
  averageDifficulty: 0,
);

/// Builds a one-scene shot list snapshot over [shots], all belonging to one synthetic scene.
OcptShotListSnapshot _buildShotList({required List<OcptShot> shots, String heading = "INT. HOUSE - DAY"}) =>
    OcptShotListSnapshot.build(
      screenplayId: "screenplay-1",
      sequences: [
        OcptSceneShotSequence(
          sceneId: "scene-1",
          heading: heading,
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
/// whichever catalogues a test needs.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, List<OcptShootingDayBlock>> blocksByDayId = const {},
  Map<String, List<OcptShootingDayEvent>> eventsByDayId = const {},
  List<OcptLocation> locations = const [],
  List<OcptRole> roles = const [],
  List<OcptPerson> people = const [],
  List<OcptElement> elements = const [],
  List<OcptShotListSnapshot> shotLists = const [],
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: blocksByDayId,
    eventsByDayId: eventsByDayId,
  ),
  shotLists: shotLists,
  episodes: const [],
  locations: locations,
  roles: roles,
  people: people,
  elements: elements,
  minimumRestMinutes: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptShootingPlanPdfService();
  const pageSetup = OcptPageSetup.standard();
  final pinnedExportDate = DateTime(2026, 1, 15);

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final locationA = _buildLocation(id: "loc-a", name: "Studio A");
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", locationId: "loc-a", anchorMinute: 480);
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [locationA],
      );

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: true,
        includeLocationsGrid: true,
        includeSequencesGrid: true,
        includePeopleGrid: true,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a two-slot day produces two grid columns under one day tag", () async {
      final locationA = _buildLocation(id: "loc-a", name: "Studio A");
      final locationB = _buildLocation(id: "loc-b", name: "Location B");
      final morning = _buildSlot(id: "slot-morning", shootingDayId: "day-1", locationId: "loc-a", anchorMinute: 480);
      final evening = _buildSlot(id: "slot-evening", shootingDayId: "day-1", locationId: "loc-b", anchorMinute: 1080);

      final twoSlotPlan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 2)],
        slotsByDayId: {
          "day-1": [morning, evening],
        },
        locations: [locationA, locationB],
      );
      final oneSlotPlan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 2)],
        slotsByDayId: {
          "day-1": [morning],
        },
        locations: [locationA],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: true,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final full = await generateFor(twoSlotPlan);
      final single = await generateFor(oneSlotPlan);

      expect(_contentStreams(full), isNot(_contentStreams(single)));
      // Two grid columns and two day-slot hours lines printing distinct content is, by construction,
      // a longer document than one.
      expect(full.length, greaterThan(single.length));
    });

    test("a range wide enough to chunk the grid adds at least one extra page over the same "
        "range without it", () async {
      final location = _buildLocation(id: "loc-a", name: "Studio A");
      // Eight days, each with its own single slot at the same location — one row, eight columns,
      // well past the grid's own per-page chunk size.
      final days = [for (var i = 1; i <= 8; i++) _buildDay(id: "day-$i", dayNumber: i)];
      final slotsByDayId = {
        for (var i = 1; i <= 8; i++)
          "day-$i": [_buildSlot(id: "slot-$i", shootingDayId: "day-$i", locationId: "loc-a", anchorMinute: 480)],
      };
      final dayIds = [for (var i = 1; i <= 8; i++) "day-$i"];
      final plan = _buildSnapshot(days: days, slotsByDayId: slotsByDayId, locations: [location]);

      Future<Uint8List> generateFor({required bool includeLocationsGrid}) => service.generate(
        plan: plan,
        dayIds: dayIds,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: includeLocationsGrid,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final withGrid = await generateFor(includeLocationsGrid: true);
      final withoutGrid = await generateFor(includeLocationsGrid: false);

      expect(_pageCount(withGrid) - _pageCount(withoutGrid), greaterThanOrEqualTo(2));
    });

    test("each grid toggled off shrinks the document", () async {
      final location = _buildLocation(id: "loc-a", name: "Studio A");
      final person = _buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard");
      final role = _buildRole(id: "role-1", name: "Alice", personId: "person-1");
      final slot = _buildSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        locationId: "loc-a",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1", positionId: "director")],
        cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["ALICE"]);
      final blocksByDayId = {
        "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", kind: OcptShootingBlockKind.shot, shotId: "shot-1")],
      };
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: blocksByDayId,
        locations: [location],
        roles: [role],
        people: [person],
        shotLists: [_buildShotList(shots: [shot])],
      );

      Future<Uint8List> generateFor({required bool includeGrids}) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: includeGrids,
        includeSequencesGrid: includeGrids,
        includePeopleGrid: includeGrids,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final withGrids = await generateFor(includeGrids: true);
      final withoutGrids = await generateFor(includeGrids: false);

      expect(withoutGrids.length, lessThan(withGrids.length));
    });

    test("a night slot crossing midnight prints the resolved hours, never modulo 1440", () async {
      final nightSlot = _buildSlot(id: "slot-night", shootingDayId: "day-1", anchorMinute: 1140); // 19:00
      final nightSnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [nightSlot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-night", durationMinutes: 480)], // ends at 1620
        },
      );

      final daySlot = _buildSlot(id: "slot-day", shootingDayId: "day-1", anchorMinute: 480);
      final daySnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [daySlot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-day", durationMinutes: 480)],
        },
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final nightBytes = await generateFor(nightSnapshot);
      final dayBytes = await generateFor(daySnapshot);

      expect(ascii.decode(nightBytes.sublist(0, 4)), "%PDF");
      expect(_contentStreams(nightBytes), isNot(_contentStreams(dayBytes)));
    });

    test("a shot table's own hours column prints the resolved hours, never modulo 1440", () async {
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");

      final nightSlot = _buildSlot(id: "slot-night", shootingDayId: "day-1", anchorMinute: 1140); // 19:00
      final nightSnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [nightSlot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-night",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 480, // ends at 1620, i.e. 03:00 the following morning
            ),
          ],
        },
        shotLists: [_buildShotList(shots: [shot])],
      );

      final daySlot = _buildSlot(id: "slot-day", shootingDayId: "day-1", anchorMinute: 480);
      final daySnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [daySlot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-day",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 480,
            ),
          ],
        },
        shotLists: [_buildShotList(shots: [shot])],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final nightBytes = await generateFor(nightSnapshot);
      final dayBytes = await generateFor(daySnapshot);

      expect(ascii.decode(nightBytes.sublist(0, 4)), "%PDF");
      expect(_contentStreams(nightBytes), isNot(_contentStreams(dayBytes)));
    });

    test("an end-anchored slot prints the hours the timeline resolves, not the raw anchor", () async {
      // Both slots are end-anchored on the very same minute (720); only their own block's duration
      // differs, so only the *resolved start* tells them apart.
      final shortSlot = _buildSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
      );
      final shortSnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [shortSlot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1")], // starts at 690
        },
      );

      final longSlot = _buildSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
      );
      final longSnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [longSlot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", durationMinutes: 180),
          ], // starts at 540
        },
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final shortBytes = await generateFor(shortSnapshot);
      final longBytes = await generateFor(longSnapshot);

      expect(_contentStreams(shortBytes), isNot(_contentStreams(longBytes)));
    });

    test("a day with no slot still writes a readable document", () async {
      final plan = _buildSnapshot(days: [_buildDay(id: "day-1", dayNumber: 1)], slotsByDayId: const {});

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: true,
        includeSequencesGrid: true,
        includePeopleGrid: true,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), greaterThanOrEqualTo(1));
    });

    test("a range naming no live day at all still writes a readable, one-note document", () async {
      final plan = _buildSnapshot(days: const [], slotsByDayId: const {});

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["missing-day"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: true,
        includeSequencesGrid: true,
        includePeopleGrid: true,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("the same schedule exported twice, at the same export date, draws exactly the same pages", () async {
      final location = _buildLocation(id: "loc-a", name: "Studio A");
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", locationId: "loc-a", anchorMinute: 480);
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        locations: [location],
      );

      Future<Uint8List> generateOnce() => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: true,
        includeLocationsGrid: true,
        includeSequencesGrid: true,
        includePeopleGrid: true,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final first = await generateOnce();
      final second = await generateOnce();

      expect(_contentStreams(first), _contentStreams(second));
    });

    test("the same schedule exported at two moments of one day draws different pages", () async {
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480)],
        },
      );

      // No title page: what tells these two apart can only be the running head's own stamp, which is
      // the whole point of repeating it on every page rather than printing it on the cover alone.
      Future<Uint8List> generateAt(DateTime exportDate) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: exportDate,
      );

      final morning = await generateAt(DateTime(2026, 1, 15, 9, 15));
      final afternoon = await generateAt(DateTime(2026, 1, 15, 17, 45));

      expect(_contentStreams(morning), isNot(_contentStreams(afternoon)));
    });
  });

  group("events, guests and crew notes", () {
    test("a day's own events, guests and a block's own crew note enlarge the document", () async {
      final bareSlot = _buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final withoutExtras = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [bareSlot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", kind: OcptShootingBlockKind.meal),
          ],
        },
      );

      final busySlot = _buildSlot(
        id: "slot-1",
        shootingDayId: "day-1",
        anchorMinute: 480,
        guests: [_buildGuest(id: "guest-1", slotId: "slot-1", freeName: "Mayor Dupont", reason: "Lends the square")],
      );
      final withExtras = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [busySlot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.meal,
              crewNote: "Catering arrives at noon.",
            ),
          ],
        },
        eventsByDayId: {
          "day-1": [_buildEvent(id: "event-1", shootingDayId: "day-1", minute: 1020, label: "Village fireworks")],
        },
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      // A guest's own convocation is computed like any other, and it never carries a PAT band
      // (ADR 0018) — generating a document over one must not throw.
      final guestConvocation = withExtras.convocationsOfDay("day-1").firstWhere((c) => c.isGuest);
      expect(guestConvocation.patStartMinute, isNull);
      expect(guestConvocation.patEndMinute, isNull);

      final withBytes = await generateFor(withExtras);
      final withoutBytes = await generateFor(withoutExtras);

      expect(ascii.decode(withBytes.sublist(0, 4)), "%PDF");
      expect(_contentStreams(withBytes), isNot(_contentStreams(withoutBytes)));
      expect(withBytes.length, greaterThan(withoutBytes.length));
    });

    test("a milestone block's own crew note changes the document even with no shot on the day", () async {
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);

      OcptSchedulePlanSnapshot buildPlan(String crewNote) => _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.meal,
              crewNote: crewNote,
            ),
          ],
        },
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final withoutNote = await generateFor(buildPlan(""));
      final withNote = await generateFor(buildPlan("Keep noise down before 9am."));

      expect(_contentStreams(withNote), isNot(_contentStreams(withoutNote)));
    });

    test("a shot block's own crew note closes its table chunk and changes the document", () async {
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");

      OcptSchedulePlanSnapshot buildPlan(String crewNote) => _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
              crewNote: crewNote,
            ),
          ],
        },
        shotLists: [_buildShotList(shots: [shot])],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final withoutNote = await generateFor(buildPlan(""));
      final withNote = await generateFor(buildPlan("Bring the rain cover."));

      expect(_contentStreams(withNote), isNot(_contentStreams(withoutNote)));
    });
  });

  group("ten-minute day grid", () {
    test("toggled on grows the document, toggled off leaves it as it was", () async {
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        shotLists: [_buildShotList(shots: [shot])],
      );

      Future<Uint8List> generateFor({required bool includeTenMinuteGrid}) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: includeTenMinuteGrid,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final without = await generateFor(includeTenMinuteGrid: false);
      final withGrid = await generateFor(includeTenMinuteGrid: true);
      final withGridAgain = await generateFor(includeTenMinuteGrid: true);

      expect(withGrid.length, greaterThan(without.length));
      // Toggled off twice in a row, at the very same export date, draws exactly the same pages —
      // nothing about the day agenda itself changed by the option existing at all.
      final withoutAgain = await generateFor(includeTenMinuteGrid: false);
      expect(_contentStreams(without), _contentStreams(withoutAgain));
      expect(_contentStreams(withGrid), _contentStreams(withGridAgain));
    });

    test("a day whose blocks run past midnight still produces it", () async {
      final nightSlot = _buildSlot(id: "slot-night", shootingDayId: "day-1", anchorMinute: 1140); // 19:00
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [nightSlot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-night",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 480, // ends at 1620, i.e. 03:00 the following morning
            ),
          ],
        },
        shotLists: [_buildShotList(shots: [shot])],
      );

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: true,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      // The day agenda, then the ten-minute grid itself spilling onto a second physical page
      // (48 rows for an eight-hour night block) — exactly the case whose own header must repeat.
      expect(_pageCount(bytes), greaterThanOrEqualTo(3));
    });

    test("an event pinned outside every block's own band still produces a readable document", () async {
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final withoutEvent = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", durationMinutes: 60)],
        },
      );
      final withEvent = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", durationMinutes: 60)],
        },
        eventsByDayId: {
          "day-1": [_buildEvent(id: "event-1", shootingDayId: "day-1", minute: 1020, label: "Village fireworks")],
        },
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: true,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final withBytes = await generateFor(withEvent);
      final withoutBytes = await generateFor(withoutEvent);

      expect(ascii.decode(withBytes.sublist(0, 4)), "%PDF");
      expect(_contentStreams(withBytes), isNot(_contentStreams(withoutBytes)));
    });
  });

  group("elements grid", () {
    test("toggled on grows the document, toggled off leaves it as it was", () async {
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final element = _buildElement(
        id: "element-1",
        name: "Revolver",
        code: "PRP-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
            ),
          ],
        },
        shotLists: [_buildShotList(shots: [shot])],
        elements: [element],
      );

      Future<Uint8List> generateFor({required bool includeElementsGrid}) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: includeElementsGrid,
        exportDate: pinnedExportDate,
      );

      final without = await generateFor(includeElementsGrid: false);
      final withGrid = await generateFor(includeElementsGrid: true);
      final withGridAgain = await generateFor(includeElementsGrid: true);

      expect(withGrid.length, greaterThan(without.length));
      // Toggled off twice in a row, at the very same export date, draws exactly the same pages —
      // nothing about the rest of the document changed by the option existing at all.
      final withoutAgain = await generateFor(includeElementsGrid: false);
      expect(_contentStreams(without), _contentStreams(withoutAgain));
      expect(_contentStreams(withGrid), _contentStreams(withGridAgain));
    });

    test("an element linked to a scene the printed range never plays adds no row", () async {
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final playedElement = _buildElement(
        id: "element-1",
        name: "Revolver",
        code: "PRP-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final unplayedElement = _buildElement(
        id: "element-2",
        name: "Getaway car",
        code: "VEH-1",
        category: OcptElementCategory.vehicle,
        sceneLinks: [_buildSceneElementLink(id: "link-2", sceneId: "scene-2")],
      );

      OcptSchedulePlanSnapshot buildPlan(List<OcptElement> elements) => _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
            ),
          ],
        },
        shotLists: [_buildShotList(shots: [shot])],
        elements: elements,
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: true,
        exportDate: pinnedExportDate,
      );

      // The unplayed element contributes no row at all, so adding it changes nothing about the
      // printed grid.
      final onlyPlayed = await generateFor(buildPlan([playedElement]));
      final playedAndUnplayed = await generateFor(buildPlan([playedElement, unplayedElement]));

      expect(_contentStreams(onlyPlayed), _contentStreams(playedAndUnplayed));
    });

    test("a range wide enough to chunk the day columns adds at least one extra page", () async {
      // Eight days, each with its own single slot and shot on its own scene — eight day columns,
      // well past the grid's own per-page chunk size, and one element needed on the first of them
      // alone so the grid draws at least one row.
      final days = [for (var i = 1; i <= 8; i++) _buildDay(id: "day-$i", dayNumber: i)];
      final slotsByDayId = {
        for (var i = 1; i <= 8; i++) "day-$i": [_buildSlot(id: "slot-$i", shootingDayId: "day-$i", anchorMinute: 480)],
      };
      final shots = [for (var i = 1; i <= 8; i++) _buildShot(id: "shot-$i", sceneId: "scene-$i", code: "$i/1")];
      final blocksByDayId = {
        for (var i = 1; i <= 8; i++)
          "day-$i": [
            _buildBlock(
              id: "block-$i",
              shootingDayId: "day-$i",
              slotId: "slot-$i",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-$i",
            ),
          ],
      };
      final element = _buildElement(
        id: "element-1",
        name: "Revolver",
        code: "PRP-1",
        sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
      );
      final dayIds = [for (var i = 1; i <= 8; i++) "day-$i"];
      final plan = _buildSnapshot(
        days: days,
        slotsByDayId: slotsByDayId,
        blocksByDayId: blocksByDayId,
        shotLists: [_buildShotList(shots: shots)],
        elements: [element],
      );

      Future<Uint8List> generateFor({required bool includeElementsGrid}) => service.generate(
        plan: plan,
        dayIds: dayIds,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: false,
        includeElementsGrid: includeElementsGrid,
        exportDate: pinnedExportDate,
      );

      final withGrid = await generateFor(includeElementsGrid: true);
      final withoutGrid = await generateFor(includeElementsGrid: false);

      expect(_pageCount(withGrid) - _pageCount(withoutGrid), greaterThanOrEqualTo(2));
    });
  });

  group("multiple episodes", () {
    /// Episode 1's own one-scene shot list: `scene-e1`, prefixed `1.3` — the number
    /// `OcptShotListService.loadShotList` would already have given it.
    OcptShotListSnapshot buildEpisodeOneShotList(OcptShot shot) => OcptShotListSnapshot.build(
      screenplayId: "episode-1",
      sequences: [
        OcptSceneShotSequence(
          sceneId: "scene-e1",
          heading: "INT. HOUSE - DAY",
          sceneNumber: null,
          displaySceneNumber: "1.3",
          charStart: 0,
          charEnd: 10,
          shots: [shot],
        ),
      ],
    );

    /// Episode 2's own one-scene shot list: `scene-e2`, prefixed [displaySceneNumber] (`2.4` unless a
    /// test deliberately hands in a bare number to simulate the prefix being dropped).
    OcptShotListSnapshot buildEpisodeTwoShotList(OcptShot shot, {String displaySceneNumber = "2.4"}) =>
        OcptShotListSnapshot.build(
          screenplayId: "episode-2",
          sequences: [
            OcptSceneShotSequence(
              sceneId: "scene-e2",
              heading: "EXT. STREET - NIGHT",
              sceneNumber: null,
              displaySceneNumber: displaySceneNumber,
              charStart: 0,
              charEnd: 10,
              shots: [shot],
            ),
          ],
        );

    test(
      "the sequences grid holds a row for each episode's own sequence, and the day agenda's shot "
      "table prints each episode's own prefixed shot code",
      () async {
        final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", anchorMinute: 480);
        final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1");
        final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1");
        final blocks = {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e1",
              durationMinutes: 60,
            ),
            _buildBlock(
              id: "block-2",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e2",
              durationMinutes: 60,
            ),
          ],
        };

        final bothEpisodesPlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: blocks,
          shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        );

        // Episode 2's own shot list is unchanged but for its display number, which is stripped of
        // its prefix here — the very string the day agenda's own shot-table cell (`shot.code`) and
        // the sequences grid's own row label both read from.
        final unprefixedShotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2", code: "4/1");
        final unprefixedPlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: blocks,
          shotLists: [
            buildEpisodeOneShotList(shotOne),
            buildEpisodeTwoShotList(unprefixedShotTwo, displaySceneNumber: "4"),
          ],
        );

        // Episode 1 alone: the control this test's own "both episodes print a row each" assertion is
        // measured against.
        final episodeOneOnlyPlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [blocks["day-1"]!.first],
          },
          shotLists: [buildEpisodeOneShotList(shotOne)],
        );

        Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
          plan: plan,
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeTitlePage: false,
          includeLocationsGrid: false,
          includeSequencesGrid: true,
          includePeopleGrid: false,
          includeTenMinuteGrid: false,
          includeElementsGrid: false,
          exportDate: pinnedExportDate,
        );

        final bothEpisodesBytes = await generateFor(bothEpisodesPlan);
        final unprefixedBytes = await generateFor(unprefixedPlan);
        final episodeOneOnlyBytes = await generateFor(episodeOneOnlyPlan);

        // The prefixed reading of episode 2's own sequence draws differently from the unprefixed
        // one: the prefix genuinely reaches the page rather than being resolved and then dropped.
        expect(_contentStreams(bothEpisodesBytes), isNot(_contentStreams(unprefixedBytes)));
        // Both episodes' own sequence and shot draw more than episode 1's alone.
        expect(bothEpisodesBytes.length, greaterThan(episodeOneOnlyBytes.length));
      },
    );

    test("the ten-minute grid draws a tile for a block of either episode", () async {
      final morning = _buildSlot(id: "slot-morning", shootingDayId: "day-1", anchorMinute: 480);
      final evening = _buildSlot(id: "slot-evening", shootingDayId: "day-1", anchorMinute: 1080);
      final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1");
      final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1");

      OcptSchedulePlanSnapshot buildPlan({required bool withEveningEpisode}) => _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": withEveningEpisode ? [morning, evening] : [morning],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              shootingDayId: "day-1",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e1",
              durationMinutes: 60,
            ),
            if (withEveningEpisode)
              _buildBlock(
                id: "block-2",
                shootingDayId: "day-1",
                slotId: "slot-evening",
                kind: OcptShootingBlockKind.shot,
                shotId: "shot-e2",
                durationMinutes: 60,
              ),
          ],
        },
        shotLists: withEveningEpisode
            ? [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)]
            : [buildEpisodeOneShotList(shotOne)],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        includeLocationsGrid: false,
        includeSequencesGrid: false,
        includePeopleGrid: false,
        includeTenMinuteGrid: true,
        includeElementsGrid: false,
        exportDate: pinnedExportDate,
      );

      final bothBytes = await generateFor(buildPlan(withEveningEpisode: true));
      final morningOnlyBytes = await generateFor(buildPlan(withEveningEpisode: false));

      expect(ascii.decode(bothBytes.sublist(0, 4)), "%PDF");
      expect(_contentStreams(bothBytes), isNot(_contentStreams(morningOnlyBytes)));
    });
  });

  group("shootingPlanFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.shootingPlanFileName(projectName: "My Movie", suffix: "shooting plan"),
        "My Movie - shooting plan.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.shootingPlanFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_call_sheet_pdf_service_test.dart` uses.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order —
/// see `ocpt_call_sheet_pdf_service_test.dart`'s own doc comment for why this, rather than the
/// printed text, is what every "prints something different" assertion below compares.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
