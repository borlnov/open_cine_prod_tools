// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/models/ocpt_scene_element_link.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_block_candidate.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// The moment every sheet below is stamped with: pinned rather than left to default to
/// `DateTime.now()`, so a test comparing two documents byte for byte cannot fail — nor pass — for
/// having straddled a minute boundary between them.
final _pinnedExportDate = DateTime(2026, 1, 15, 14, 32);

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_breakdown_sheets_pdf_service_test.dart` follows.
const _labels = OcptCallSheetLabels(
  fileNamePrefix: "FDS",
  documentTitle: "Call sheet",
  dayTitles: {"day-1": "CALL SHEET OF THURSDAY 10 AUGUST 2023"},
  directorLine: "A film by Jane Doe",
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayNumberLabel: "DAY",
  recipientsSectionTitle: "Recipients",
  namedRecipientLabel: "For",
  crewNoteSectionTitle: "Note to the crew",
  locationSectionTitle: "Location",
  mapsLinkLabel: "Google Maps",
  sunSectionTitle: "Sun",
  civilDawnLabel: "Civil dawn",
  sunriseLabel: "Sunrise",
  sunsetLabel: "Sunset",
  civilDuskLabel: "Civil dusk",
  contactsSectionTitle: "Contacts",
  crewDepartmentLabels: {
    OcptCrewDepartment.direction: "DIRECTION",
    OcptCrewDepartment.image: "IMAGE",
    OcptCrewDepartment.sound: "SOUND",
    OcptCrewDepartment.artDepartment: "ART DEPARTMENT",
    OcptCrewDepartment.hmc: "HMC",
    OcptCrewDepartment.production: "PRODUCTION",
  },
  crewPositionLabels: {
    "director": "Director",
    "gaffer": "Gaffer",
    "cameraOperator": "Camera operator",
    "productionManager": "Production manager",
  },
  hoursLinePrefix: "HOURS",
  patLabel: "PAT",
  presenceLabel: "PRESENCE",
  arrivalHeader: "ARRIVAL",
  departureLabel: "Departure",
  toBringSectionTitle: "To bring",
  blockKindLabels: {
    OcptShootingBlockKind.preparation: "Preparation",
    OcptShootingBlockKind.hairMakeUp: "Hair and make-up",
    OcptShootingBlockKind.meal: "Meal break",
    OcptShootingBlockKind.pause: "Break",
    OcptShootingBlockKind.travel: "Travel",
    OcptShootingBlockKind.wrap: "Wrap",
    OcptShootingBlockKind.hold: "Reserved",
    OcptShootingBlockKind.audition: "Audition",
    OcptShootingBlockKind.rehearsal: "Rehearsal",
  },
  seqHeader: "SEQ",
  plansHeader: "SHOTS",
  effetHeader: "EFFECT",
  decorsHeader: "SET",
  rolesHeader: "ROLES",
  castSectionTitle: "Cast",
  roleHeader: "ROLE",
  actorHeader: "ACTOR",
  nameHeader: "NAME",
  positionsHeader: "POSITION(S)",
  phoneHeader: "PHONE",
  emailHeader: "EMAIL",
  crewListSectionTitle: "Crew members",
  castAndExtrasListSectionTitle: "Cast and extras",
  emptyDayNote: "Nothing planned for this day yet.",
  unnamedPersonLabel: "No name",
  eventsSectionTitle: "Events",
  auditionsSectionTitle: "Auditions",
  candidateHeader: "CANDIDAT",
  candidatesSectionTitle: "Candidates",
  guestsSectionTitle: "Guests",
  guestReasonHeader: "Reason",
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber, String crewNote = ""}) =>
    OcptShootingDay(
      id: id,
      date: DateTime(2026, 1, dayNumber),
      dayNumber: dayNumber,
      status: OcptShootingDayStatus.planned,
      crewNote: crewNote,
      weatherNote: "",
      notes: "",
    );

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({
  required String id,
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
  shootingDayId: "day-1",
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
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required String id,
  required String slotId,
  OcptShootingBlockKind kind = OcptShootingBlockKind.preparation,
  String? shotId,
  String? sceneId,
  List<OcptShootingBlockCandidate> candidates = const [],
  String label = "",
  int? durationMinutes = 30,
  String crewNote = "",
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: "day-1",
  slotId: slotId,
  kind: kind,
  shotId: shotId,
  sceneId: sceneId,
  candidates: candidates,
  label: label,
  durationMinutes: durationMinutes,
  anchorMinute: null,
  notes: "",
  crewNote: crewNote,
);

/// Builds a day event with the few fields these tests read, everything else neutral.
OcptShootingDayEvent _buildEvent({required String id, required int minute, String label = "", String notes = ""}) =>
    OcptShootingDayEvent(id: id, shootingDayId: "day-1", minute: minute, label: label, notes: notes);

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

/// Builds an audition block's own candidate convocation with the few fields these tests read.
OcptShootingBlockCandidate _buildBlockCandidate({
  required String id,
  required String blockId,
  required String roleCandidateId,
}) =>
    OcptShootingBlockCandidate(
      id: id,
      blockId: blockId,
      roleCandidateId: roleCandidateId,
      notes: "",
    );

/// Builds a candidacy — somebody seen for a part — with the few fields these tests read.
OcptRoleCandidate _buildRoleCandidate({
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

/// Builds a person with the few fields these tests read, everything else neutral.
OcptPerson _buildPerson({
  required String id,
  required String firstName,
  required String lastName,
  String phone = "",
  String email = "",
}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: email,
  phone: phone,
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
OcptRole _buildRole({required String id, required String name, String? personId, int number = 1}) =>
    OcptRole(
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
OcptLocation _buildLocation({
  required String id,
  String name = "",
  double? latitude,
  double? longitude,
}) => OcptLocation(
  id: id,
  name: name,
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

/// Builds a shot with the few fields these tests read, everything else neutral. [code] is supplied
/// directly (rather than derived through `OcptShot.fromRow`), exactly as this model's own tests do.
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

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days/slots/blocks, plus
/// whichever catalogues a test needs, exactly as `ocpt_schedule_plan_snapshot_test.dart`'s own
/// fixture builder does.
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
  List<OcptRoleCandidate> roleCandidates = const [],
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
  roleCandidates: roleCandidates,
  minimumRestMinutes: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate…` calls must not re-read the asset bundle).
  final service = OcptCallSheetPdfService();
  const pageSetup = OcptPageSetup.standard();

  /// A day with two slots, two crews and two shots — the fixture "a day with two slots and two
  /// crews" tests are measured against, and every location/role/shot the other tests reuse.
  OcptSchedulePlanSnapshot buildTwoSlotDaySnapshot({
    List<OcptShootingSlotCrewMember> extraEveningCrew = const [],
    List<OcptShootingDayEvent> events = const [],
    List<OcptShootingSlotGuest> morningGuests = const [],
  }) {
    final locationA = _buildLocation(id: "loc-a", name: "Studio A", latitude: 48.85, longitude: 2.35);
    final locationB = _buildLocation(id: "loc-b", name: "Location B");

    final morning = _buildSlot(
      id: "slot-morning",
      label: "Morning unit",
      locationId: "loc-a",
      anchorMinute: 480, // 08:00
      crew: [_buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1", positionId: "director")],
      cast: [_buildCastMember(id: "cast-1", slotId: "slot-morning", roleId: "role-1")],
      guests: morningGuests,
    );
    final evening = _buildSlot(
      id: "slot-evening",
      label: "Evening unit",
      locationId: "loc-b",
      anchorMinute: 1080, // 18:00
      crew: [
        _buildCrewMember(id: "crew-2", slotId: "slot-evening", personId: "person-2"),
        ...extraEveningCrew,
      ],
    );

    final shot1 = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["ALICE"]);
    final shot2 = _buildShot(id: "shot-2", sceneId: "scene-1", code: "1/2", characters: const ["ALICE"]);

    return _buildSnapshot(
      days: [_buildDay(id: "day-1", dayNumber: 2, crewNote: "Bring rain gear.")],
      slotsByDayId: {
        "day-1": [morning, evening],
      },
      blocksByDayId: {
        "day-1": [
          _buildBlock(
            id: "block-1",
            slotId: "slot-morning",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
          _buildBlock(
            id: "block-2",
            slotId: "slot-evening",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-2",
            durationMinutes: 90,
          ),
        ],
      },
      eventsByDayId: events.isEmpty ? const {} : {"day-1": events},
      locations: [locationA, locationB],
      roles: [_buildRole(id: "role-1", name: "Alice")],
      people: [
        _buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard", phone: "0601020304"),
        _buildPerson(id: "person-2", firstName: "Marc", lastName: "Petit", phone: "0605060708"),
      ],
      shotLists: [_buildShotList(shots: [shot1, shot2])],
    );
  }

  group("generateGeneralCallSheet", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a day with two slots and two crews prints both", () async {
      final full = await service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      // Drop the evening slot and its crew entirely: the second unit's own time band, its
      // crew-list row and its shot must all disappear with it.
      final locationA = _buildLocation(id: "loc-a", name: "Studio A", latitude: 48.85, longitude: 2.35);
      final morning = _buildSlot(
        id: "slot-morning",
        label: "Morning unit",
        locationId: "loc-a",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1", positionId: "director")],
        cast: [_buildCastMember(id: "cast-1", slotId: "slot-morning", roleId: "role-1")],
      );
      final shot1 = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["ALICE"]);
      final oneSlotOnly = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 2, crewNote: "Bring rain gear.")],
        slotsByDayId: {
          "day-1": [morning],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        locations: [locationA],
        roles: [_buildRole(id: "role-1", name: "Alice")],
        people: [_buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [_buildShotList(shots: [shot1])],
      );

      final single = await service.generateGeneralCallSheet(
        plan: oneSlotOnly,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(_contentStreams(full), isNot(_contentStreams(single)));
      // Two units printing distinct content is, by construction, a longer document than one.
      expect(full.length, greaterThan(single.length));
    });

    test("a role a placed shot plays is printed even when no slot convokes it", () async {
      // One slot convoking nobody, one shot on it played by two roles: the main table's own ROLES
      // column names both numbers, so the cast table must be able to answer for both — the second
      // role having no convocation of its own, and therefore no arrival and no PAT band.
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
      final roles = [
        _buildRole(id: "role-1", name: "Alice"),
        _buildRole(id: "role-2", name: "Bob", number: 2),
      ];
      final blocks = {
        "day-1": [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
        ],
      };

      final bothPlaying = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: blocks,
        roles: roles,
        shotLists: [
          _buildShotList(
            shots: [_buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["ALICE", "BOB"])],
          ),
        ],
      );
      final oneOnly = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: blocks,
        roles: roles,
        shotLists: [
          _buildShotList(
            shots: [_buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["ALICE"])],
          ),
        ],
      );

      final bothBytes = await service.generateGeneralCallSheet(
        plan: bothPlaying,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final oneBytes = await service.generateGeneralCallSheet(
        plan: oneOnly,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      // A second cast row and a second cast-and-extras row, on a day whose slots convoke nobody at
      // all: the two documents can only differ if a role nobody convoked is printed.
      expect(_contentStreams(bothBytes), isNot(_contentStreams(oneBytes)));
      expect(bothBytes.length, greaterThan(oneBytes.length));
    });

    test("a night slot crossing midnight prints the resolved hours, never modulo 1440", () async {
      final nightSlot = _buildSlot(id: "slot-night", anchorMinute: 1140); // 19:00
      final nightSnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [nightSlot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", slotId: "slot-night", durationMinutes: 480)], // ends at 1620
        },
      );

      // A same-length day that never crosses midnight, so the two documents' own time-band lines
      // must print differently: the night one alone spans past 24:00.
      final daySlot = _buildSlot(id: "slot-day", anchorMinute: 480);
      final daySnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [daySlot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", slotId: "slot-day", durationMinutes: 480)],
        },
      );

      // Generating a night slot that resolves well past 1440 minutes must not throw.
      final nightBytes = await service.generateGeneralCallSheet(
        plan: nightSnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final dayBytes = await service.generateGeneralCallSheet(
        plan: daySnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(ascii.decode(nightBytes.sublist(0, 4)), "%PDF");
      expect(_contentStreams(nightBytes), isNot(_contentStreams(dayBytes)));
    });

    test("an end-anchored slot prints the hours the timeline resolves, not the raw anchor", () async {
      // Both slots are end-anchored on the very same minute (720); only their own block's duration
      // differs, so only the *resolved start* tells them apart — a service that printed the stored
      // anchor by mistake would draw the two documents identically.
      final shortSlot = _buildSlot(
        id: "slot-1",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
      );
      final shortSnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [shortSlot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", slotId: "slot-1")], // starts at 690
        },
      );

      final longSlot = _buildSlot(
        id: "slot-1",
        anchorEdge: OcptShootingSlotAnchorEdge.end,
        anchorMinute: 720,
      );
      final longSnapshot = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [longSlot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", slotId: "slot-1", durationMinutes: 180)], // starts at 540
        },
      );

      final shortBytes = await service.generateGeneralCallSheet(
        plan: shortSnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final longBytes = await service.generateGeneralCallSheet(
        plan: longSnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(_contentStreams(shortBytes), isNot(_contentStreams(longBytes)));
    });

    test("a day with no slot at all still writes a readable one-page document", () async {
      final emptySnapshot = _buildSnapshot(days: [_buildDay(id: "day-1", dayNumber: 1)], slotsByDayId: const {});

      final bytes = await service.generateGeneralCallSheet(
        plan: emptySnapshot,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a day id the schedule holds nothing for still writes a readable document", () async {
      final snapshot = _buildSnapshot(days: const [], slotsByDayId: const {});

      final bytes = await service.generateGeneralCallSheet(
        plan: snapshot,
        dayId: "missing-day",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("the same schedule exported twice draws exactly the same pages", () async {
      final first = await service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final second = await service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(_contentStreams(first), _contentStreams(second));
    });

    test("two sheets of one day, produced at two moments, do not draw the same pages", () async {
      Future<Uint8List> generateAt(DateTime exportDate) => service.generateGeneralCallSheet(
        plan: buildTwoSlotDaySnapshot(),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: exportDate,
      );

      final morning = await generateAt(DateTime(2026, 1, 15, 9, 15));
      final afternoon = await generateAt(DateTime(2026, 1, 15, 17, 45));

      expect(_contentStreams(morning), isNot(_contentStreams(afternoon)));
    });
  });

  group("generateNamedCallSheet vs generateGeneralCallSheet", () {
    test("a named sheet carries the day's own directories, so it grows with the crew", () async {
      final plan = buildTwoSlotDaySnapshot();
      final convocation = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final namedBytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: convocation,
        exportDate: _pinnedExportDate,
      );

      // A brand new crew member, on the *other* unit, in a department that never reaches the key
      // contacts block either (image, not production/direction): the only sections that can see them
      // are the department-contacts table and the crew list, both of which a named sheet now prints.
      final grownPlan = buildTwoSlotDaySnapshot(
        extraEveningCrew: [
          _buildCrewMember(id: "crew-3", slotId: "slot-evening", personId: "person-3", positionId: "cameraOperator"),
        ],
      );
      final grownPlanWithPerson = _addPerson(
        grownPlan,
        _buildPerson(id: "person-3", firstName: "Léa", lastName: "Bernard", phone: "0611223344"),
      );
      final grownConvocation = grownPlanWithPerson
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");

      final generalBytesBefore = await service.generateGeneralCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final generalBytesAfter = await service.generateGeneralCallSheet(
        plan: grownPlanWithPerson,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final namedBytesAfter = await service.generateNamedCallSheet(
        plan: grownPlanWithPerson,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: grownConvocation,
        exportDate: _pinnedExportDate,
      );

      // The general sheet's own crew list grew...
      expect(_contentStreams(generalBytesBefore), isNot(_contentStreams(generalBytesAfter)));
      // ...and so did the named one's, the two directories being facts about the day rather than
      // about whoever the sheet is addressed to.
      expect(_contentStreams(namedBytes), isNot(_contentStreams(namedBytesAfter)));
    });

    test("two recipients of one day get sheets narrowed to their own slots", () async {
      final plan = buildTwoSlotDaySnapshot();
      final morning = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final evening = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-2");

      final morningBytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: morning,
        exportDate: _pinnedExportDate,
      );
      final eveningBytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: evening,
        exportDate: _pinnedExportDate,
      );

      // Every closing table is day-wide and therefore identical between the two; what still has to
      // differ is the recipient line, their own band, their location and their own timetable.
      expect(_contentStreams(morningBytes), isNot(_contentStreams(eveningBytes)));
    });

    test("a person's arrival, PAT band and departure print as three distinct figures", () async {
      // slot-1, start-anchored at 08:00: a preparation block (not shooting, 08:00-08:30), a shot
      // block (08:30-09:30) and a wrap block (09:30-10:00, not shooting either) — so arrival
      // (08:00), PAT start (08:30), PAT end (09:30) and departure (10:00) are four distinct minutes.
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final fullPlan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "prep", slotId: "slot-1"),
            _buildBlock(
              id: "shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
            _buildBlock(id: "wrap", slotId: "slot-1", kind: OcptShootingBlockKind.wrap),
          ],
        },
        people: [_buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [_buildShotList(shots: [shot])],
      );

      // Drop the wrap block: departure now collapses onto the PAT end (09:30), so the four-figure
      // fixture's own bytes must differ from this one — proving departure is its own figure.
      final noWrapPlan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "prep", slotId: "slot-1"),
            _buildBlock(
              id: "shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        people: [_buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [_buildShotList(shots: [shot])],
      );

      // Drop the preparation block too: arrival now collapses onto PAT start (08:30) as well.
      final onlyShotPlan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "shot",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        people: [_buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [_buildShotList(shots: [shot])],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) async {
        final convocation = plan.convocationsOfDay("day-1").single;
        return service.generateNamedCallSheet(
          plan: plan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          convocation: convocation,
          exportDate: _pinnedExportDate,
        );
      }

      final full = await generateFor(fullPlan);
      final noWrap = await generateFor(noWrapPlan);
      final onlyShot = await generateFor(onlyShotPlan);

      // Removing the wrap block changes departure alone.
      expect(_contentStreams(full), isNot(_contentStreams(noWrap)));
      // Removing the preparation block too then changes arrival as well.
      expect(_contentStreams(noWrap), isNot(_contentStreams(onlyShot)));
    });

    test("a convocation with no shooting block prints an em dash for its PAT band", () async {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
      );
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "prep", slotId: "slot-1")],
        },
        people: [_buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
      );
      final convocation = plan.convocationsOfDay("day-1").single;

      expect(convocation.patStartMinute, isNull);

      final bytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: convocation,
        exportDate: _pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a named sheet is stamped too: two moments, two documents", () async {
      final plan = buildTwoSlotDaySnapshot();
      final convocation = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");

      Future<Uint8List> generateAt(DateTime exportDate) => service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: convocation,
        exportDate: exportDate,
      );

      final morning = await generateAt(DateTime(2026, 1, 15, 9, 15));
      final afternoon = await generateAt(DateTime(2026, 1, 15, 17, 45));

      expect(_contentStreams(morning), isNot(_contentStreams(afternoon)));
    });
  });

  group("events, guests and crew notes", () {
    test("a day's own events change what both sheets print", () async {
      final withoutEvents = buildTwoSlotDaySnapshot();
      final withEvents = buildTwoSlotDaySnapshot(
        events: [_buildEvent(id: "event-1", minute: 1020, label: "Village fireworks")],
      );

      final generalWithout = await service.generateGeneralCallSheet(
        plan: withoutEvents,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final generalWith = await service.generateGeneralCallSheet(
        plan: withEvents,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      expect(_contentStreams(generalWith), isNot(_contentStreams(generalWithout)));

      final convocationWithout = withoutEvents.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final convocationWith = withEvents.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final namedWithout = await service.generateNamedCallSheet(
        plan: withoutEvents,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: convocationWithout,
        exportDate: _pinnedExportDate,
      );
      final namedWith = await service.generateNamedCallSheet(
        plan: withEvents,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: convocationWith,
        exportDate: _pinnedExportDate,
      );
      expect(_contentStreams(namedWith), isNot(_contentStreams(namedWithout)));
    });

    test("a day's own guests change what both sheets print, and a guest with no PAT band does not crash", () async {
      final withoutGuest = buildTwoSlotDaySnapshot();
      final withGuest = buildTwoSlotDaySnapshot(
        morningGuests: [
          _buildGuest(id: "guest-1", slotId: "slot-morning", freeName: "Mayor Dupont", reason: "Lends the square"),
        ],
      );

      // A guest's own convocation is computed like any other, and it never carries a PAT band
      // (ADR 0018) — generating a sheet over one must not throw.
      final guestConvocation = withGuest.convocationsOfDay("day-1").firstWhere((c) => c.isGuest);
      expect(guestConvocation.patStartMinute, isNull);
      expect(guestConvocation.patEndMinute, isNull);

      final generalWithout = await service.generateGeneralCallSheet(
        plan: withoutGuest,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final generalWith = await service.generateGeneralCallSheet(
        plan: withGuest,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      expect(ascii.decode(generalWith.sublist(0, 4)), "%PDF");
      expect(_contentStreams(generalWith), isNot(_contentStreams(generalWithout)));

      // The guest table is day-wide (like the cast table and the two directories), so it shows up
      // on a named sheet too, even one addressed to the morning unit's own director rather than to
      // the guest.
      final convocationWithout = withoutGuest.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final convocationWith = withGuest.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final namedWithout = await service.generateNamedCallSheet(
        plan: withoutGuest,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: convocationWithout,
        exportDate: _pinnedExportDate,
      );
      final namedWith = await service.generateNamedCallSheet(
        plan: withGuest,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: convocationWith,
        exportDate: _pinnedExportDate,
      );
      expect(ascii.decode(namedWith.sublist(0, 4)), "%PDF");
      expect(_contentStreams(namedWith), isNot(_contentStreams(namedWithout)));
    });

    test("a shot block's own crew note changes the sheet", () async {
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);
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

      final withoutNote = await service.generateGeneralCallSheet(
        plan: buildPlan(""),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final withNote = await service.generateGeneralCallSheet(
        plan: buildPlan("Bring the rain cover."),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(_contentStreams(withNote), isNot(_contentStreams(withoutNote)));
    });

    test("a milestone block's own crew note changes the sheet", () async {
      final slot = _buildSlot(id: "slot-1", anchorMinute: 480);

      OcptSchedulePlanSnapshot buildPlan(String crewNote) => _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [slot],
        },
        blocksByDayId: {
          "day-1": [_buildBlock(id: "block-1", slotId: "slot-1", kind: OcptShootingBlockKind.meal, crewNote: crewNote)],
        },
      );

      final withoutNote = await service.generateGeneralCallSheet(
        plan: buildPlan(""),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final withNote = await service.generateGeneralCallSheet(
        plan: buildPlan("Catering arrives at noon."),
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(_contentStreams(withNote), isNot(_contentStreams(withoutNote)));
    });

    test("a named sheet prints only its own slots' blocks' crew notes", () async {
      final morning = _buildSlot(
        id: "slot-morning",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1")],
      );
      final evening = _buildSlot(
        id: "slot-evening",
        anchorMinute: 1080,
        crew: [_buildCrewMember(id: "crew-2", slotId: "slot-evening", personId: "person-2")],
      );
      final shot1 = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final shot2 = _buildShot(id: "shot-2", sceneId: "scene-1", code: "1/2");

      OcptSchedulePlanSnapshot buildPlan({required String eveningCrewNote}) => _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [morning, evening],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
              crewNote: "Morning note.",
            ),
            _buildBlock(
              id: "block-2",
              slotId: "slot-evening",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-2",
              durationMinutes: 60,
              crewNote: eveningCrewNote,
            ),
          ],
        },
        people: [
          _buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard"),
          _buildPerson(id: "person-2", firstName: "Marc", lastName: "Petit"),
        ],
        shotLists: [_buildShotList(shots: [shot1, shot2])],
      );

      final withoutEveningNote = buildPlan(eveningCrewNote: "");
      final withEveningNote = buildPlan(eveningCrewNote: "Evening note.");

      // The morning recipient's own sheet only ever draws their own slot's blocks: changing the
      // evening slot's own crew note must not move a single byte of it.
      final morningConvocationWithout = withoutEveningNote
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final morningConvocationWith = withEveningNote
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");
      final morningBytesWithout = await service.generateNamedCallSheet(
        plan: withoutEveningNote,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: morningConvocationWithout,
        exportDate: _pinnedExportDate,
      );
      final morningBytesWith = await service.generateNamedCallSheet(
        plan: withEveningNote,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: morningConvocationWith,
        exportDate: _pinnedExportDate,
      );
      expect(_contentStreams(morningBytesWith), _contentStreams(morningBytesWithout));

      // But the evening recipient's own sheet does draw the new note.
      final eveningConvocationWithout = withoutEveningNote
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-2");
      final eveningConvocationWith = withEveningNote
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-2");
      final eveningBytesWithout = await service.generateNamedCallSheet(
        plan: withoutEveningNote,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: eveningConvocationWithout,
        exportDate: _pinnedExportDate,
      );
      final eveningBytesWith = await service.generateNamedCallSheet(
        plan: withEveningNote,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: eveningConvocationWith,
        exportDate: _pinnedExportDate,
      );
      expect(_contentStreams(eveningBytesWith), isNot(_contentStreams(eveningBytesWithout)));
    });
  });

  group("the named sheet's own 'to bring' section", () {
    /// A day with one crew member (`person-1`) and one uncast role (`role-1`) convoked on the same
    /// slot, shooting `scene-1` — enough to test the section's own presence, absence and the general
    /// sheet's own indifference to it.
    OcptSchedulePlanSnapshot buildPlan({required List<OcptElement> elements}) {
      final slot = _buildSlot(
        id: "slot-1",
        anchorMinute: 480,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-1")],
        cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");

      return _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
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
        roles: [_buildRole(id: "role-1", name: "Alice")], // personId null: an uncast role.
        people: [_buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        shotLists: [_buildShotList(shots: [shot])],
        elements: elements,
      );
    }

    test("a named sheet differs once its recipient's own element is linked to a scene the day plays", () async {
      final linkedPlan = buildPlan(
        elements: [
          _buildElement(
            id: "element-1",
            name: "Umbrella",
            broughtByPersonId: "person-1",
            sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
          ),
        ],
      );
      final unlinkedPlan = buildPlan(
        elements: [
          _buildElement(id: "element-1", name: "Umbrella", broughtByPersonId: "person-1"),
        ],
      );

      final linkedConvocation = linkedPlan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final unlinkedConvocation = unlinkedPlan
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.personId == "person-1");

      final linkedBytes = await service.generateNamedCallSheet(
        plan: linkedPlan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: linkedConvocation,
        exportDate: _pinnedExportDate,
      );
      final unlinkedBytes = await service.generateNamedCallSheet(
        plan: unlinkedPlan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: unlinkedConvocation,
        exportDate: _pinnedExportDate,
      );

      expect(_contentStreams(linkedBytes), isNot(_contentStreams(unlinkedBytes)));
    });

    test("a named sheet for an uncast role is unchanged by any element at all", () async {
      final withElement = buildPlan(
        elements: [
          _buildElement(
            id: "element-1",
            name: "Umbrella",
            broughtByPersonId: "person-1",
            sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
          ),
        ],
      );
      final withoutElement = buildPlan(elements: const []);

      final withElementConvocation = withElement.convocationsOfDay("day-1").firstWhere((c) => c.roleId == "role-1");
      final withoutElementConvocation = withoutElement
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.roleId == "role-1");

      final withElementBytes = await service.generateNamedCallSheet(
        plan: withElement,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: withElementConvocation,
        exportDate: _pinnedExportDate,
      );
      final withoutElementBytes = await service.generateNamedCallSheet(
        plan: withoutElement,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: withoutElementConvocation,
        exportDate: _pinnedExportDate,
      );

      expect(
        _contentStreams(withElementBytes),
        _contentStreams(withoutElementBytes),
        reason: "an uncast role has nobody to bring anything, so the section never opens for it",
      );
    });

    test("the general sheet is unchanged by the same element", () async {
      final withElement = buildPlan(
        elements: [
          _buildElement(
            id: "element-1",
            name: "Umbrella",
            broughtByPersonId: "person-1",
            sceneLinks: [_buildSceneElementLink(id: "link-1", sceneId: "scene-1")],
          ),
        ],
      );
      final withoutElement = buildPlan(elements: const []);

      final withElementBytes = await service.generateGeneralCallSheet(
        plan: withElement,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );
      final withoutElementBytes = await service.generateGeneralCallSheet(
        plan: withoutElement,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        exportDate: _pinnedExportDate,
      );

      expect(
        _contentStreams(withElementBytes),
        _contentStreams(withoutElementBytes),
        reason: "what to bring is a fact about one recipient; the general sheet never reads it at all",
      );
    });
  });

  group("a day that does not only shoot", () {
    /// A candidate seen for `role-1`, and the person behind them.
    final camille = _buildPerson(
      id: "person-camille",
      firstName: "Camille",
      lastName: "Renard",
      phone: "0611223344",
      email: "camille@example.org",
    );
    final candidate = _buildRoleCandidate(id: "candidate-1", roleId: "role-1", person: camille);

    /// The link naming [candidate] on audition block [blockId].
    OcptShootingBlockCandidate namedOn(String blockId) =>
        _buildBlockCandidate(id: "link-$blockId", blockId: blockId, roleCandidateId: "candidate-1");

    /// A day of one slot, given [blocks].
    OcptSchedulePlanSnapshot buildDay({
      required List<OcptShootingDayBlock> blocks,
      List<OcptShot> shots = const [],
    }) => _buildSnapshot(
      days: [_buildDay(id: "day-1", dayNumber: 1)],
      slotsByDayId: {
        "day-1": [_buildSlot(id: "slot-1", label: "Casting", anchorMinute: 540)],
      },
      blocksByDayId: {"day-1": blocks},
      roles: [_buildRole(id: "role-1", name: "Marie", number: 3)],
      people: [camille],
      roleCandidates: [candidate],
      shotLists: shots.isEmpty ? const [] : [_buildShotList(shots: shots)],
    );

    /// [plan]'s own general call sheet of `day-1`, at the pinned moment.
    Future<Uint8List> generalOf(OcptSchedulePlanSnapshot plan) => service.generateGeneralCallSheet(
      plan: plan,
      dayId: "day-1",
      pageSetup: pageSetup,
      labels: _labels,
      projectName: "My Movie",
      exportDate: _pinnedExportDate,
    );

    test("a day of auditions prints a table a day of the same blocks without them does not", () async {
      final auditions = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 120,
            candidates: [namedOn("block-1")],
          ),
        ],
      );
      final holds = buildDay(
        blocks: [
          _buildBlock(id: "block-1", slotId: "slot-1", kind: OcptShootingBlockKind.hold, durationMinutes: 120),
        ],
      );

      final auditionBytes = await generalOf(auditions);
      final holdBytes = await generalOf(holds);

      expect(ascii.decode(auditionBytes.sublist(0, 4)), "%PDF");
      expect(_contentStreams(auditionBytes), isNot(_contentStreams(holdBytes)));
      // The audition table is a whole section the hold day has no heading for at all.
      expect(auditionBytes.length, greaterThan(holdBytes.length));
    });

    test("a second audition adds a row rather than a second table", () async {
      final one = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 60,
            candidates: [namedOn("block-1")],
          ),
        ],
      );
      final two = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 60,
            candidates: [namedOn("block-1")],
          ),
          _buildBlock(
            id: "block-2",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 60,
            candidates: [namedOn("block-2")],
          ),
        ],
      );

      final oneBytes = await generalOf(one);
      final twoBytes = await generalOf(two);

      expect(_contentStreams(twoBytes), isNot(_contentStreams(oneBytes)));
      expect(twoBytes.length, greaterThan(oneBytes.length));
    });

    test("a day that auditions nobody prints no audition table at all", () async {
      // The whole point of the section being skipped rather than drawn over an em dash: a day of
      // shots must be byte for byte the sheet it was before auditions existed.
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final shooting = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
        ],
        shots: [shot],
      );

      final bytes = await generalOf(shooting);

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a day mixing auditions and shots prints both tables, on one sheet", () async {
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final shotsOnly = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.shot,
            shotId: "shot-1",
            durationMinutes: 60,
          ),
        ],
        shots: [shot],
      );
      final both = buildDay(
        blocks: [
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
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 60,
          ),
        ],
        shots: [shot],
      );

      final shotsOnlyBytes = await generalOf(shotsOnly);
      final bothBytes = await generalOf(both);

      expect(_contentStreams(bothBytes), isNot(_contentStreams(shotsOnlyBytes)));
      expect(bothBytes.length, greaterThan(shotsOnlyBytes.length));
      // One day, one piece of paper: the second table joins the first rather than starting a
      // second document.
      expect(_pageCount(bothBytes), 1);
    });

    test("a day of rehearsals prints the sequence each band works, not the bare kind", () async {
      final withSequence = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", anchorMinute: 540)],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.rehearsal,
              sceneId: "scene-1",
              durationMinutes: 120,
            ),
          ],
        },
        shotLists: [_buildShotList(shots: const [], heading: "INT. KITCHEN - NIGHT")],
      );
      final withoutSequence = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", anchorMinute: 540)],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.rehearsal,
              durationMinutes: 120,
            ),
          ],
        },
        shotLists: [_buildShotList(shots: const [], heading: "INT. KITCHEN - NIGHT")],
      );

      final withBytes = await generalOf(withSequence);
      final withoutBytes = await generalOf(withoutSequence);

      // The band reads the sequence's own heading exactly as a hold's does — the two sheets would
      // be identical if a rehearsal still printed nothing but its kind label.
      expect(_contentStreams(withBytes), isNot(_contentStreams(withoutBytes)));
    });

    test("a candidate named on an audition is listed under the cast table, with their contact", () async {
      final without = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 120,
          ),
        ],
      );
      final with_ = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 120,
            candidates: [namedOn("block-1")],
          ),
        ],
      );

      // The candidate's own hours come off the audition that sees them, not off the unit's day
      // (ADR 0024) — here they happen to be the same, the slot holding that one block.
      final convocation = with_.convocationsOfDay("day-1").firstWhere((c) => c.isSeenForAPart);
      expect(convocation.roleCandidateIds, {"candidate-1"});
      expect(convocation.patStartMinute, 540);
      expect(convocation.patEndMinute, 660);

      final withoutBytes = await generalOf(without);
      final withBytes = await generalOf(with_);

      expect(_contentStreams(withBytes), isNot(_contentStreams(withoutBytes)));
      expect(withBytes.length, greaterThan(withoutBytes.length));
    });

    test("the audition table names who is seen at which hour", () async {
      // The `CANDIDAT` column: a block naming somebody prints their name beside the hour, where a
      // block naming nobody prints the hour alone.
      final named = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 20,
            candidates: [namedOn("block-1")],
          ),
        ],
      );
      final nameless = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 20,
          ),
        ],
      );

      final namedBytes = await generalOf(named);
      final namelessBytes = await generalOf(nameless);

      expect(_contentStreams(namedBytes), isNot(_contentStreams(namelessBytes)));
      expect(namedBytes.length, greaterThan(namelessBytes.length));
    });

    test("two candidacies on one block print two rows sharing one hour", () async {
      final alice = _buildPerson(id: "person-alice", firstName: "Alice", lastName: "Simon");
      final second = _buildRoleCandidate(id: "candidate-2", roleId: "role-2", person: alice);
      OcptSchedulePlanSnapshot buildWith(List<OcptShootingBlockCandidate> links) => _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", label: "Casting", anchorMinute: 540)],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 40,
              candidates: links,
            ),
          ],
        },
        roles: [
          _buildRole(id: "role-1", name: "Marie", number: 3),
          _buildRole(id: "role-2", name: "Julien", number: 4),
        ],
        people: [camille, alice],
        roleCandidates: [candidate, second],
      );

      final oneBytes = await generalOf(buildWith([namedOn("block-1")]));
      final twoBytes = await generalOf(
        buildWith([
          namedOn("block-1"),
          _buildBlockCandidate(id: "link-2", blockId: "block-1", roleCandidateId: "candidate-2"),
        ]),
      );

      expect(_contentStreams(twoBytes), isNot(_contentStreams(oneBytes)));
      expect(twoBytes.length, greaterThan(oneBytes.length));
    });

    test("the candidates list is day-wide on a named sheet, the audition table is not", () async {
      final morning = _buildSlot(
        id: "slot-morning",
        label: "Casting",
        anchorMinute: 540,
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1")],
      );
      final afternoon = _buildSlot(id: "slot-afternoon", label: "Second unit", anchorMinute: 840);

      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [morning, afternoon],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-morning",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 60,
              candidates: [namedOn("block-1")],
            ),
            _buildBlock(
              id: "block-2",
              slotId: "slot-afternoon",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 60,
            ),
          ],
        },
        roles: [_buildRole(id: "role-1", name: "Marie", number: 3)],
        people: [camille, _buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
        roleCandidates: [candidate],
      );

      final crewConvocation = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
      final named = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: crewConvocation,
        exportDate: _pinnedExportDate,
      );
      final general = await generalOf(plan);

      expect(ascii.decode(named.sublist(0, 4)), "%PDF");
      // The general sheet's audition table holds both blocks, the crew member's own holds only the
      // morning's — the timetable is the one thing a named sheet narrows.
      expect(_contentStreams(named), isNot(_contentStreams(general)));
    });

    test("a candidate gets a named sheet of their own, headed by their name and the part", () async {
      final plan = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 120,
            candidates: [namedOn("block-1")],
          ),
        ],
      );

      final candidateConvocation = plan.convocationsOfDay("day-1").firstWhere((c) => c.isSeenForAPart);
      final bytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: candidateConvocation,
        exportDate: _pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
      // The recipient's own name is what the file is called: not the fallback label a convocation
      // this service could name nobody for would fall back to.
      expect(
        service.namedCallSheetFileName(labels: _labels, dayNumber: 1, personName: "Camille Renard"),
        "FDS-D1-Camille-Renard.pdf",
      );
    });

    test("a candidate's own sheet prints their audition and their line, and no other's", () async {
      // The one place a named sheet narrows a directory (ADR 0024): who else is being seen for a
      // part, and on what phone number, is the production's business and not another candidate's.
      // Proved by swapping *who* that other candidate is: Camille's own sheet must come out
      // identical, which it only can if neither the audition table nor the directory carries them.
      OcptSchedulePlanSnapshot buildWithOther(OcptPerson otherPerson) {
        final other = _buildRoleCandidate(
          id: "candidate-2",
          roleId: "role-1",
          person: otherPerson,
        );

        return _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [_buildSlot(id: "slot-1", label: "Casting", anchorMinute: 540)],
          },
          blocksByDayId: {
            "day-1": [
              _buildBlock(
                id: "block-1",
                slotId: "slot-1",
                kind: OcptShootingBlockKind.audition,
                durationMinutes: 20,
                candidates: [namedOn("block-1")],
              ),
              _buildBlock(
                id: "block-2",
                slotId: "slot-1",
                kind: OcptShootingBlockKind.audition,
                durationMinutes: 20,
                candidates: [
                  _buildBlockCandidate(
                    id: "link-2",
                    blockId: "block-2",
                    roleCandidateId: "candidate-2",
                  ),
                ],
              ),
            ],
          },
          roles: [_buildRole(id: "role-1", name: "Marie", number: 3)],
          people: [camille, otherPerson],
          roleCandidates: [candidate, other],
        );
      }

      Future<Uint8List> camilleSheetOf(OcptSchedulePlanSnapshot plan) =>
          service.generateNamedCallSheet(
            plan: plan,
            dayId: "day-1",
            pageSetup: pageSetup,
            labels: _labels,
            projectName: "My Movie",
            convocation: plan
                .convocationsOfDay("day-1")
                .firstWhere((c) => c.roleCandidateIds.contains("candidate-1")),
            exportDate: _pinnedExportDate,
          );

      final withAlice = buildWithOther(
        _buildPerson(
          id: "person-alice",
          firstName: "Alice",
          lastName: "Simon",
          phone: "0655667788",
          email: "alice@example.org",
        ),
      );
      final withJonas = buildWithOther(
        _buildPerson(
          id: "person-jonas",
          firstName: "Jonas",
          lastName: "Weber",
          phone: "0699887766",
          email: "jonas@example.org",
        ),
      );

      // Each candidate is expected at their own twenty minutes, off their own block rather than off
      // the unit's whole session.
      final convocations = withAlice.convocationsOfDay("day-1");
      final camilleCall = convocations.firstWhere((c) => c.roleCandidateIds.contains("candidate-1"));
      final aliceCall = convocations.firstWhere((c) => c.roleCandidateIds.contains("candidate-2"));
      expect(camilleCall.arrivalMinute, 540);
      expect(camilleCall.departureMinute, 560);
      expect(aliceCall.arrivalMinute, 560);
      expect(aliceCall.departureMinute, 580);

      expect(
        _contentStreams(await camilleSheetOf(withAlice)),
        _contentStreams(await camilleSheetOf(withJonas)),
        reason: "who else was seen that day appears nowhere on this candidate's own sheet",
      );

      // The general sheet, by contrast, carries both of them — it is the day's own paperwork.
      expect(
        _contentStreams(await generalOf(withAlice)),
        isNot(_contentStreams(await generalOf(withJonas))),
      );
    });

    test("a day that films nothing heads its band PRESENCE rather than PAT", () async {
      // The label follows the band, not the day's paperwork: a day of auditions has no take for
      // anybody to be ready for, so the word `PAT` cannot appear on it at all.
      final auditions = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 20,
            candidates: [namedOn("block-1")],
          ),
        ],
      );

      final call = auditions
          .convocationsOfDay("day-1")
          .firstWhere((c) => c.roleCandidateIds.contains("candidate-1"));
      expect(call.patStartMinute, 540);
      expect(call.isPatBand, isFalse);

      final bytes = await service.generateNamedCallSheet(
        plan: auditions,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: call,
        exportDate: _pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("a candidate and an actor read different words on the one mixed sheet", () async {
      // The whole reason the label is per convocation: the unit is due ready to shoot at 13:00 and
      // the candidate is due to be seen at 09:00, and one word cannot be both.
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [
            _buildSlot(
              id: "slot-1",
              label: "Casting",
              anchorMinute: 540,
              cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
            ),
          ],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
              candidates: [namedOn("block-1")],
            ),
            _buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-1",
              durationMinutes: 60,
            ),
          ],
        },
        roles: [_buildRole(id: "role-1", name: "Marie", number: 3, personId: "person-lea")],
        people: [camille, _buildPerson(id: "person-lea", firstName: "Léa", lastName: "Dubois")],
        roleCandidates: [candidate],
        shotLists: [_buildShotList(shots: [shot])],
      );

      final convocations = plan.convocationsOfDay("day-1");
      expect(convocations.firstWhere((c) => c.personId == "person-lea").isPatBand, isTrue);
      expect(convocations.firstWhere((c) => c.isSeenForAPart).isPatBand, isFalse);
    });

    test("crewing the day and being seen for a part is one recipient, one sheet", () async {
      // The fault reading the exports showed: a person held two convocations and received two
      // sheets. They arrive once and leave once, and the one sheet says everything they do.
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [
            _buildSlot(
              id: "slot-1",
              label: "Casting",
              anchorMinute: 480, // 08:00 — on the unit from the start
              crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-camille")],
            ),
          ],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "block-1", slotId: "slot-1", durationMinutes: 120),
            _buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.audition,
              durationMinutes: 20,
              candidates: [namedOn("block-2")],
            ),
          ],
        },
        roles: [_buildRole(id: "role-1", name: "Marie", number: 3)],
        people: [camille],
        roleCandidates: [candidate],
      );

      // One convocation, not two, and it spans both reasons.
      final convocation = plan.convocationsOfDay("day-1").single;
      expect(convocation.personId, camille.id);
      expect(convocation.roleCandidateIds, {"candidate-1"});
      expect(convocation.arrivalMinute, 480);
      expect(convocation.departureMinute, 620);
      // The day films nothing, so their band is a presence one however they got there.
      expect(convocation.isPatBand, isFalse);

      final bytes = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: convocation,
        exportDate: _pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("an actor's own sheet drops the shots they are not in, and keeps every milestone", () async {
      // The fault reading the exports showed: a sheet narrowed to the recipient's units and then
      // printed the whole running order, so an actor had to work out which shots were theirs.
      // Thirty shots, alternating between two parts, is enough for the difference to be a page.
      final lea = _buildPerson(id: "person-lea", firstName: "Léa", lastName: "Dubois");
      final shots = [
        for (var i = 0; i < 30; i++)
          _buildShot(
            id: "shot-$i",
            sceneId: "scene-1",
            code: "$i/1",
            characters: [if (i.isEven) "MARIE" else "JULIEN"],
          ),
      ];
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [
            _buildSlot(
              id: "slot-1",
              anchorMinute: 480,
              cast: [
                _buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1"),
                _buildCastMember(id: "cast-2", slotId: "slot-1", roleId: "role-2"),
              ],
            ),
          ],
        },
        blocksByDayId: {
          "day-1": [
            for (var i = 0; i < 30; i++)
              _buildBlock(
                id: "block-$i",
                slotId: "slot-1",
                kind: OcptShootingBlockKind.shot,
                shotId: "shot-$i",
                durationMinutes: 20,
              ),
            _buildBlock(
              id: "block-meal",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.meal,
              durationMinutes: 45,
            ),
          ],
        },
        roles: [
          _buildRole(id: "role-1", name: "MARIE", number: 3, personId: "person-lea"),
          _buildRole(id: "role-2", name: "JULIEN", number: 4, personId: "person-jules"),
        ],
        people: [lea, _buildPerson(id: "person-jules", firstName: "Jules", lastName: "Marchand")],
        shotLists: [_buildShotList(shots: shots)],
      );

      final leaCall = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-lea");
      final leaSheet = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: leaCall,
        exportDate: _pinnedExportDate,
      );
      final general = await generalOf(plan);

      // The day's whole order runs onto a second page; hers, holding half of it, does not.
      expect(_pageCount(general), greaterThan(1));
      expect(_pageCount(leaSheet), 1);
    });

    test("a technician keeps the whole running order of the unit they crew", () async {
      // The rule that keeps a narrowing from taking a sheet apart: a slot naming somebody as crew
      // is an order they work end to end, whatever it plays.
      final gaffer = _buildPerson(id: "person-gaffer", firstName: "Sam", lastName: "Roche");
      final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["MARIE"]);
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [
            _buildSlot(
              id: "slot-1",
              anchorMinute: 480,
              crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-gaffer")],
            ),
          ],
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
        roles: [_buildRole(id: "role-1", name: "MARIE", number: 3)],
        people: [gaffer],
        shotLists: [_buildShotList(shots: [shot])],
      );

      final call = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-gaffer");
      final theirs = await service.generateNamedCallSheet(
        plan: plan,
        dayId: "day-1",
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        convocation: call,
        exportDate: _pinnedExportDate,
      );

      // The shot plays a part they do not, and it is still on their sheet: they light it.
      expect(ascii.decode(theirs.sublist(0, 4)), "%PDF");
      expect(_pageCount(theirs), 1);
    });

    test("a candidate carries a selection key, so the named export can be narrowed to them", () async {
      final plan = buildDay(
        blocks: [
          _buildBlock(
            id: "block-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.audition,
            durationMinutes: 120,
            candidates: [namedOn("block-1")],
          ),
        ],
      );

      // Keyed by their **person**: a sheet is addressed to somebody, so somebody crewing the day
      // and seen for a part is one recipient and one PDF. A guest is the one convocation kind
      // carrying no key at all, which is what keeps them out of the named sheets dialog without
      // that dialog needing a rule of its own.
      final convocations = plan.convocationsOfDay("day-1");
      expect(convocations.single.selectionKey, camille.id);
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

    /// Episode 2's own one-scene shot list: `scene-e2`, prefixed `2.4`.
    OcptShotListSnapshot buildEpisodeTwoShotList(OcptShot shot) => OcptShotListSnapshot.build(
      screenplayId: "episode-2",
      sequences: [
        OcptSceneShotSequence(
          sceneId: "scene-e2",
          heading: "EXT. STREET - NIGHT",
          sceneNumber: null,
          displaySceneNumber: "2.4",
          charStart: 0,
          charEnd: 10,
          shots: [shot],
        ),
      ],
    );

    test(
      "a role speaking in shots of both episodes is one cast row, not two, carrying scene "
      "numbers from both — and the SEQ column carries both episodes' own prefixed codes",
      () async {
        final role = _buildRole(id: "role-1", name: "Alice");
        final slot = _buildSlot(
          id: "slot-1",
          anchorMinute: 480,
          cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
        );
        final blocks = {
          "day-1": [
            _buildBlock(
              id: "block-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e1",
              durationMinutes: 60,
            ),
            _buildBlock(
              id: "block-2",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.shot,
              shotId: "shot-e2",
              durationMinutes: 60,
            ),
          ],
        };

        // Alice speaks in both episodes' own shots: one role, cast once on the slot, its character
        // read off two shots of two different scenes.
        final oneRoleShotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1", characters: const ["ALICE"]);
        final oneRoleShotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1", characters: const ["ALICE"]);
        final oneRolePlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: blocks,
          roles: [role],
          shotLists: [buildEpisodeOneShotList(oneRoleShotOne), buildEpisodeTwoShotList(oneRoleShotTwo)],
        );

        // A second, distinct role speaks in the second episode's own shot instead — a whole second
        // identity, where the fixture above kept it the very same Alice.
        final secondRole = _buildRole(id: "role-2", name: "Bob", number: 2);
        final twoRolesShotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1", characters: const ["ALICE"]);
        final twoRolesShotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1", characters: const ["BOB"]);
        final twoRolesSlot = _buildSlot(
          id: "slot-1",
          anchorMinute: 480,
          cast: [
            _buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1"),
            _buildCastMember(id: "cast-2", slotId: "slot-1", roleId: "role-2"),
          ],
        );
        final twoRolesPlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [twoRolesSlot],
          },
          blocksByDayId: blocks,
          roles: [role, secondRole],
          shotLists: [buildEpisodeOneShotList(twoRolesShotOne), buildEpisodeTwoShotList(twoRolesShotTwo)],
        );

        final oneRoleBytes = await service.generateGeneralCallSheet(
          plan: oneRolePlan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          exportDate: _pinnedExportDate,
        );
        final twoRolesBytes = await service.generateGeneralCallSheet(
          plan: twoRolesPlan,
          dayId: "day-1",
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          exportDate: _pinnedExportDate,
        );

        // Both documents print the same two SEQ rows (1.3 then 2.4), so the only thing that can
        // still tell them apart is the cast side: a second, distinct role costs a whole extra row
        // in the cast table and a whole extra entry in the cast-and-extras list, where the very same
        // Alice speaking a second time costs one more scene number appended to her own row. If the
        // cast table had printed Alice twice instead of merging her two episodes into one row, the
        // two documents would be the same size; they are not, and the two-role one is the larger of
        // the two.
        expect(_contentStreams(oneRoleBytes), isNot(_contentStreams(twoRolesBytes)));
        expect(twoRolesBytes.length, greaterThan(oneRoleBytes.length));
      },
    );

    test(
      "a named sheet's own timetable narrows to its recipient's episode, but its cast table "
      "stays the day's — naming a role that speaks only in the other episode's own slot",
      () async {
        final role = _buildRole(id: "role-1", name: "Alice");
        final secondRole = _buildRole(id: "role-2", name: "Bob", number: 2);
        final morning = _buildSlot(
          id: "slot-morning",
          anchorMinute: 480,
          crew: [_buildCrewMember(id: "crew-1", slotId: "slot-morning", personId: "person-1")],
        );
        final evening = _buildSlot(id: "slot-evening", anchorMinute: 1080);
        final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1", characters: const ["ALICE"]);
        final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1", characters: const ["BOB"]);

        OcptSchedulePlanSnapshot buildPlan({required bool withEveningEpisode}) => _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": withEveningEpisode ? [morning, evening] : [morning],
          },
          blocksByDayId: {
            "day-1": [
              _buildBlock(
                id: "block-1",
                slotId: "slot-morning",
                kind: OcptShootingBlockKind.shot,
                shotId: "shot-e1",
                durationMinutes: 60,
              ),
              if (withEveningEpisode)
                _buildBlock(
                  id: "block-2",
                  slotId: "slot-evening",
                  kind: OcptShootingBlockKind.shot,
                  shotId: "shot-e2",
                  durationMinutes: 60,
                ),
            ],
          },
          roles: withEveningEpisode ? [role, secondRole] : [role],
          people: [_buildPerson(id: "person-1", firstName: "Justine", lastName: "Renard")],
          shotLists: withEveningEpisode
              ? [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)]
              : [buildEpisodeOneShotList(shotOne)],
        );

        final withBothEpisodes = buildPlan(withEveningEpisode: true);
        final morningEpisodeOnly = buildPlan(withEveningEpisode: false);

        Future<Uint8List> generateNamedFor(OcptSchedulePlanSnapshot plan) async {
          final convocation = plan.convocationsOfDay("day-1").firstWhere((c) => c.personId == "person-1");
          return service.generateNamedCallSheet(
            plan: plan,
            dayId: "day-1",
            pageSetup: pageSetup,
            labels: _labels,
            projectName: "My Movie",
            convocation: convocation,
            exportDate: _pinnedExportDate,
          );
        }

        final withBothEpisodesBytes = await generateNamedFor(withBothEpisodes);
        final morningEpisodeOnlyBytes = await generateNamedFor(morningEpisodeOnly);

        // The morning recipient's own main table never sees the evening slot at all, so this can
        // only differ through the day-wide cast table (and the two closing lists it feeds): Bob, cast
        // in the evening's own episode 2 shot alone, still has to show up on a sheet addressed to
        // somebody who never shares a slot with him.
        expect(_contentStreams(withBothEpisodesBytes), isNot(_contentStreams(morningEpisodeOnlyBytes)));
        expect(withBothEpisodesBytes.length, greaterThan(morningEpisodeOnlyBytes.length));
      },
    );
  });

  group("callSheetFileName", () {
    test("joins the file name prefix and the day tag", () {
      expect(service.callSheetFileName(labels: _labels, dayNumber: 2), "FDS-D2.pdf");
    });
  });

  group("namedCallSheetFileName", () {
    test("appends the sanitized person name", () {
      expect(
        service.namedCallSheetFileName(labels: _labels, dayNumber: 2, personName: "Elisa Mabit"),
        "FDS-D2-Elisa-Mabit.pdf",
      );
    });

    test("a name with a slash, an accent and a space produces a safe file name", () {
      final fileName = service.namedCallSheetFileName(
        labels: _labels,
        dayNumber: 2,
        personName: "Élise/Bénard Dupont",
      );

      expect(fileName, isNot(contains("/")));
      expect(fileName, isNot(contains("É")));
      expect(fileName, isNot(contains("é")));
      expect(fileName, "FDS-D2-EliseBenard-Dupont.pdf");
    });

    test("a blank name falls back to the localized unnamed-person label, sanitized", () {
      expect(
        service.namedCallSheetFileName(labels: _labels, dayNumber: 3, personName: "   "),
        "FDS-D3-No-name.pdf",
      );
    });
  });
}

/// [plan] with [person] appended to its address book — used to grow a fixture's own catalogue
/// without rebuilding every other field.
OcptSchedulePlanSnapshot _addPerson(OcptSchedulePlanSnapshot plan, OcptPerson person) =>
    OcptSchedulePlanSnapshot.build(
      schedule: plan.schedule,
      shotLists: plan.shotLists,
      episodes: const [],
      locations: plan.locations,
      roles: plan.roles,
      people: [...plan.people, person],
      elements: plan.elements,
      minimumRestMinutes: plan.minimumRestMinutes,
    );

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_breakdown_sheets_pdf_service_test.dart` uses.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order —
/// see `ocpt_breakdown_sheets_pdf_service_test.dart`'s own doc comment for why this, rather than the
/// printed text, is what every "prints something different" assertion below compares.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
