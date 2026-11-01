// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
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
final pinnedExportDate = DateTime(2026, 1, 15, 14, 32);

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_breakdown_sheets_pdf_service_test.dart` follows.
const labels = OcptCallSheetLabels(
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
    OcptCrewDepartment.production: "PRODUCTION",
    OcptCrewDepartment.unit: "UNIT",
    OcptCrewDepartment.castingAndExtras: "CASTING AND EXTRAS",
    OcptCrewDepartment.image: "IMAGE",
    OcptCrewDepartment.electricAndGrip: "ELECTRIC AND GRIP",
    OcptCrewDepartment.sound: "SOUND",
    OcptCrewDepartment.artDepartment: "ART DEPARTMENT",
    OcptCrewDepartment.costume: "COSTUME",
    OcptCrewDepartment.hairAndMakeUp: "HAIR AND MAKE-UP",
    OcptCrewDepartment.specialEffects: "SPECIAL EFFECTS",
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
OcptShootingDay testBuildDay({required String id, required int dayNumber, String crewNote = ""}) =>
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
OcptShootingSlot buildSlot({
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
OcptShootingDayBlock buildBlock({
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

/// Builds a crew member with the few fields these tests read, everything else neutral.
OcptShootingSlotCrewMember buildCrewMember({
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
OcptShootingSlotCastMember buildCastMember({
  required String id,
  required String slotId,
  required String roleId,
}) => OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

/// Builds an audition block's own candidate convocation with the few fields these tests read.
OcptShootingBlockCandidate buildBlockCandidate({
  required String id,
  required String blockId,
  required String roleCandidateId,
}) => OcptShootingBlockCandidate(
  id: id,
  blockId: blockId,
  roleCandidateId: roleCandidateId,
  notes: "",
);

/// Builds a candidacy — somebody seen for a part — with the few fields these tests read.
OcptRoleCandidate buildRoleCandidate({
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
OcptPerson buildPerson({
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
  commuteKmMilli: null,
  mileageRateId: null,
  positions: const [],
  skills: const [],
  unavailabilities: const [],
);

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole buildRole({required String id, required String name, String? personId, int number = 1}) =>
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
OcptLocation buildLocation({
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
OcptShot buildShot({
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
OcptShotListSnapshot buildShotList({
  required List<OcptShot> shots,
  String heading = "INT. HOUSE - DAY",
}) => OcptShotListSnapshot.build(
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
/// whichever catalogues a test needs, exactly as `ocpt_schedule_plan_snapshot_test_doubles.dart`'s
/// own fixture builder does.
OcptSchedulePlanSnapshot buildSnapshot({
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

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_breakdown_sheets_pdf_service_test.dart` uses.
int pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order
/// — see `ocpt_breakdown_sheets_pdf_service_test.dart`'s own doc comment for why this, rather than
/// the printed text, is what every "prints something different" assertion below compares.
List<String> contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
