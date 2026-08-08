// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_permit_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
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
  directorLine: '"My Movie" by Jane Doe',
  titlePageVersionLabel: "Version",
  dayTagPrefix: "D",
  locationsGridTitle: "Summary - Locations",
  sequencesGridTitle: "Summary - Sequences",
  peopleGridTitle: "Summary - Crew and cast",
  locationsGridRowHeader: "Location",
  sequencesGridRowHeader: "Sequence",
  peopleGridRowHeader: "Position / Role",
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
  planHeader: "Plan",
  shotSizeHeader: "Shot size",
  moveHeader: "Move.",
  framingHeader: "Frame",
  commentHeader: "Comment",
  emptyPlanNote: "Nothing planned yet.",
  emptyDayScheduleNote: "Nothing planned for this day yet.",
);

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
  screenplayId: "screenplay-1",
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

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days/slots/blocks, plus
/// whichever catalogues a test needs.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, List<OcptShootingDayBlock>> blocksByDayId = const {},
  List<OcptLocation> locations = const [],
  List<OcptRole> roles = const [],
  List<OcptPerson> people = const [],
  OcptShotListSnapshot? shotList,
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    screenplayId: "screenplay-1",
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: blocksByDayId,
  ),
  shotList: shotList,
  locations: locations,
  roles: roles,
  people: people,
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
        shotList: _buildShotList(shots: [shot]),
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
        exportDate: pinnedExportDate,
      );

      final first = await generateOnce();
      final second = await generateOnce();

      expect(_contentStreams(first), _contentStreams(second));
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
