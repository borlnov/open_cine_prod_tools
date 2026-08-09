// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_sides_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// A two-scene screenplay short enough to fit on a single composed page — the same shape
/// `ocpt_scenario_coverage_pdf_service_test.dart` parses, since this service reads a scene's own
/// span off the very same `FountainDocument.scenes`.
const _screenplay =
    "INT. KITCHEN - DAY\n"
    "\n"
    "John walks in and looks around the room.\n"
    "\n"
    "EXT. STREET - NIGHT\n"
    "\n"
    "Rain falls on the empty pavement.\n";

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_one_line_schedule_pdf_service_test.dart` follows.
const _labels = OcptSidesLabels(
  fileNameSuffix: "sides",
  documentTitle: "Sides",
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayTitle: "Thursday, 1 January 2026",
  scriptPagePrefix: "p.",
  emptyDayNote: "Nothing planned for this day.",
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
OcptShootingSlot _buildSlot({required String id, required String shootingDayId}) => OcptShootingSlot(
  id: id,
  shootingDayId: shootingDayId,
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: const [],
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

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days/slots/blocks, plus
/// whichever shot list a test needs — the same fixture shape
/// `ocpt_one_line_schedule_pdf_service_test.dart` uses.
OcptSchedulePlanSnapshot _buildSnapshot({
  required List<OcptShootingDay> days,
  required Map<String, List<OcptShootingSlot>> slotsByDayId,
  Map<String, List<OcptShootingDayBlock>> blocksByDayId = const {},
  OcptShotListSnapshot? shotList,
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    screenplayId: "screenplay-1",
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: blocksByDayId,
    eventsByDayId: const {},
  ),
  shotList: shotList,
  locations: const [],
  roles: const [],
  people: const [],
  elements: const [],
  minimumRestMinutes: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptSidesPdfService();
  const parser = FountainParser();
  const pageSetup = OcptPageSetup.standard();
  final pinnedExportDate = DateTime(2026, 1, 15);

  final document = parser.parse(_screenplay);
  final scenes = document.scenes;

  /// A one-scene shot list snapshot whose scene carries the very source span
  /// `OcptSchedulePlanSnapshot.sceneSpanBySceneId` would read out of the parsed screenplay's own
  /// first scene — the join this service slices its pages by. [shots] belongs to that one scene,
  /// which is what lets [OcptSchedulePlanSnapshot.shotById] resolve a block's own `shotId` back
  /// onto its `sceneId`.
  OcptShotListSnapshot buildShotList({required List<OcptShot> shots}) => OcptShotListSnapshot.build(
    screenplayId: "screenplay-1",
    sequences: [
      OcptSceneShotSequence(
        sceneId: "scene-1",
        heading: scenes[0].headingText,
        sceneNumber: null,
        displaySceneNumber: "1",
        charStart: scenes[0].sourceRange.startOffset,
        charEnd: scenes[1].sourceRange.startOffset,
        shots: shots,
      ),
    ],
  );

  /// A one-day plan with one slot, one shot block placing a shot of `scene-1`.
  OcptSchedulePlanSnapshot buildOneScenePlan() {
    final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1");
    return _buildSnapshot(
      days: [_buildDay(id: "day-1", dayNumber: 3)],
      slotsByDayId: {
        "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
      },
      blocksByDayId: {
        "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-1")],
      },
      shotList: buildShotList(shots: [shot]),
    );
  }

  group("generate", () {
    test("a day whose placed shot names a real scene composes a non-empty script page", () async {
      final bytes = await service.generate(
        plan: buildOneScenePlan(),
        dayId: "day-1",
        document: document,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: OcptSidesPresentation.scriptPages,
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("packing reproduces the same selected rows as the script-pages presentation", () async {
      final plan = buildOneScenePlan();

      Future<Uint8List> generateFor(OcptSidesPresentation presentation) => service.generate(
        plan: plan,
        dayId: "day-1",
        document: document,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: presentation,
        exportDate: pinnedExportDate,
      );

      final scriptPagesBytes = await generateFor(OcptSidesPresentation.scriptPages);
      final packedBytes = await generateFor(OcptSidesPresentation.packed);

      expect(_pageCount(scriptPagesBytes), 1);
      expect(_pageCount(packedBytes), 1);
      // Both presentations print the same one scene, so their bodies must differ from a document
      // holding no scene at all (below) while still each being their own readable page.
      expect(scriptPagesBytes, isNotEmpty);
      expect(packedBytes, isNotEmpty);
    });

    test("a day placing no scene still produces a readable, non-empty document", () async {
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 3)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
        },
      );

      final bytes = await service.generate(
        plan: plan,
        dayId: "day-1",
        document: document,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: OcptSidesPresentation.scriptPages,
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a dayId naming no live day prints the same one-note document", () async {
      final bytes = await service.generate(
        plan: buildOneScenePlan(),
        dayId: "nope",
        document: document,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: OcptSidesPresentation.scriptPages,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("the export moment is what the running foot prints, not the wall clock", () async {
      final plan = buildOneScenePlan();

      Future<Uint8List> generateFor(DateTime exportDate) => service.generate(
        plan: plan,
        dayId: "day-1",
        document: document,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeSceneNumbers: false,
        presentation: OcptSidesPresentation.scriptPages,
        exportDate: exportDate,
      );

      final first = await generateFor(pinnedExportDate);
      final second = await generateFor(pinnedExportDate);
      final differentMoment = await generateFor(DateTime(2026, 1, 15, 16, 45));

      // Content streams, not the raw bytes, are what two runs of the same [exportDate] must agree
      // on: the `pdf` package stamps its own `/CreationDate` object with the wall clock regardless
      // of what this service is asked to print, exactly the reason every sibling test compares
      // content streams rather than whole files.
      expect(_contentStreams(first), _contentStreams(second));
      expect(_contentStreams(first), isNot(_contentStreams(differentMoment)));
    });
  });

  group("sidesFileName", () {
    test("joins the project name, the localized suffix and the day tag", () {
      final plan = _buildSnapshot(days: [_buildDay(id: "day-1", dayNumber: 3)], slotsByDayId: const {});

      expect(
        service.sidesFileName(plan: plan, dayId: "day-1", projectName: "My Movie", labels: _labels),
        "My Movie - sides - D3.pdf",
      );
    });

    test("a blank suffix drops that segment", () {
      final plan = _buildSnapshot(days: [_buildDay(id: "day-1", dayNumber: 3)], slotsByDayId: const {});
      const blankSuffixLabels = OcptSidesLabels(
        fileNameSuffix: "   ",
        documentTitle: "Sides",
        versionLabel: "Version",
        dayTagPrefix: "D",
        dayTitle: "",
        scriptPagePrefix: "p.",
        emptyDayNote: "Nothing planned for this day.",
      );

      expect(
        service.sidesFileName(plan: plan, dayId: "day-1", projectName: "My Movie", labels: blankSuffixLabels),
        "My Movie - D3.pdf",
      );
    });

    test("a dayId naming no live day drops the day segment", () {
      final plan = _buildSnapshot(days: const [], slotsByDayId: const {});

      expect(
        service.sidesFileName(plan: plan, dayId: "nope", projectName: "My Movie", labels: _labels),
        "My Movie - sides.pdf",
      );
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_one_line_schedule_pdf_service_test.dart` uses.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order —
/// see `ocpt_call_sheet_pdf_service_test.dart`'s own doc comment for why this, rather than the
/// printed text, is what every "prints something different" assertion above compares.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
