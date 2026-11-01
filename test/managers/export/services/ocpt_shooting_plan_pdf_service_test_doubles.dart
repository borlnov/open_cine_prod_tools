// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
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
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_call_sheet_pdf_service_test_doubles.dart` follows.
const labels = OcptShootingPlanLabels(
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
OcptShootingDay buildDay({required String id, required int dayNumber}) => OcptShootingDay(
  id: id,
  date: DateTime(2026, 1, dayNumber),
  dayNumber: dayNumber,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot buildSlot({
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
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock buildBlock({
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
  candidates: const [],
  label: label,
  durationMinutes: durationMinutes,
  anchorMinute: null,
  notes: "",
  crewNote: crewNote,
);

/// Builds a shot with the few fields these tests read, everything else neutral.
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
/// whichever catalogues a test needs.
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

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_call_sheet_pdf_service_test_doubles.dart` uses.
int pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order
/// — see `ocpt_call_sheet_pdf_service_test_doubles.dart`'s own doc comment for why this, rather
/// than the printed text, is what every "prints something different" assertion below compares.
List<String> contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
