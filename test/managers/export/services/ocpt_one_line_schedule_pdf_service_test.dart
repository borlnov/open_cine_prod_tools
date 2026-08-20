// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_one_line_schedule_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_day_out_of_days_pdf_service_test.dart` follows.
const _labels = OcptOneLineScheduleLabels(
  fileNameSuffix: "one-line schedule",
  documentTitle: "One-line schedule",
  directorLine: '"My Movie" by Jane Doe',
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayTitles: {"day-1": "Thursday, 1 January 2026", "day-2": "Friday, 2 January 2026"},
  seqHeader: "SEQ",
  effectHeader: "EFFECT",
  decorHeader: "SET",
  rolesHeader: "CAST",
  durationHeader: "DURATION",
  noLocationLabel: "No location yet",
  emptyDayNote: "Nothing planned for this day.",
  emptyDocumentNote: "Nothing to print.",
);

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({
  required String id,
  required int dayNumber,
  OcptShootingDayKind kind = OcptShootingDayKind.shoot,
}) => OcptShootingDay(
  id: id,
  date: DateTime(2026, 1, dayNumber),
  dayNumber: dayNumber,
  kind: kind,
  status: OcptShootingDayStatus.planned,
  crewNote: "",
  weatherNote: "",
  notes: "",
);

/// Builds a slot with the few fields these tests read, everything else neutral. [anchorMinute]
/// defaults to 08:00, the same convention `ocpt_day_out_of_days_pdf_service_test.dart` uses.
OcptShootingSlot _buildSlot({
  required String id,
  required String shootingDayId,
  int anchorMinute = 480,
  String? setId,
}) => OcptShootingSlot(
  id: id,
  shootingDayId: shootingDayId,
  label: "",
  locationId: null,
  setId: setId,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: anchorMinute,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: const [],
  guests: const [],
  candidates: const [],
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral —
/// chaining after the slot's own resolved start (or the block before it) by leaving its own anchor
/// minute null, exactly as `ocpt_call_sheet_pdf_service_test.dart`'s own fixture does.
OcptShootingDayBlock _buildBlock({
  required String id,
  required String shootingDayId,
  required String slotId,
  OcptShootingBlockKind kind = OcptShootingBlockKind.shot,
  String? shotId,
  String? sceneId,
  int? durationMinutes = 30,
}) => OcptShootingDayBlock(
  id: id,
  shootingDayId: shootingDayId,
  slotId: slotId,
  kind: kind,
  shotId: shotId,
  sceneId: sceneId,
  label: "",
  durationMinutes: durationMinutes,
  anchorMinute: null,
  notes: "",
  crewNote: "",
  roleCandidateId: null,
  roleId: null,
);

/// Builds a shot with the few fields these tests read, everything else neutral.
OcptShot _buildShot({required String id, String? sceneId, required String code, List<String> characters = const []}) =>
    OcptShot(
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

/// Builds a role with the few fields these tests read, everything else neutral.
OcptRole _buildRole({required String id, required String name, required int number}) => OcptRole(
  id: id,
  name: name,
  personId: null,
  kind: OcptRoleKind.speaking,
  isFromScreenplay: true,
  orphanedName: null,
  castingNotes: "",
  number: number,
  episodeIds: const [],
);

/// Builds a one-scene shot list snapshot over [shots], all belonging to `scene-1` — the same
/// fixture shape `ocpt_call_sheet_pdf_service_test.dart` uses.
OcptShotListSnapshot _buildShotList({
  required List<OcptShot> shots,
  String sceneId = "scene-1",
  String heading = "INT. HOUSE - DAY",
  String displaySceneNumber = "1",
}) => OcptShotListSnapshot.build(
  screenplayId: "screenplay-1",
  sequences: [
    OcptSceneShotSequence(
      sceneId: sceneId,
      heading: heading,
      sceneNumber: null,
      displaySceneNumber: displaySceneNumber,
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
  List<OcptRole> roles = const [],
  List<OcptShotListSnapshot> shotLists = const [],
}) => OcptSchedulePlanSnapshot.build(
  schedule: OcptScheduleSnapshot.build(
    days: days,
    slotsByDayId: slotsByDayId,
    blocksByDayId: blocksByDayId,
    eventsByDayId: const {},
  ),
  shotLists: shotLists,
  episodes: const [],
  locations: const [],
  roles: roles,
  people: const [],
  elements: const [],
  minimumRestMinutes: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also exercises the font-loading
  // cache (repeated `generate` calls must not re-read the asset bundle).
  final service = OcptOneLineSchedulePdfService();
  const pageSetup = OcptPageSetup.standard();
  final pinnedExportDate = DateTime(2026, 1, 15);

  /// A one-day plan with one slot, one shot block placing [shot] in `scene-1`.
  OcptSchedulePlanSnapshot buildOneShotPlan() {
    final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["ALICE"]);
    return _buildSnapshot(
      days: [_buildDay(id: "day-1", dayNumber: 1)],
      slotsByDayId: {
        "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
      },
      blocksByDayId: {
        "day-1": [_buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-1")],
      },
      roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
      shotLists: [_buildShotList(shots: [shot])],
    );
  }

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await service.generate(
        plan: buildOneShotPlan(),
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: true,
        exportDate: pinnedExportDate,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("the title page is one page of its own, and toggling it off drops it", () async {
      final plan = buildOneShotPlan();

      Future<Uint8List> generateFor({required bool includeTitlePage}) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: includeTitlePage,
        exportDate: pinnedExportDate,
      );

      expect(_pageCount(await generateFor(includeTitlePage: true)), 2);
      expect(_pageCount(await generateFor(includeTitlePage: false)), 1);
    });

    test(
      "two consecutive shot blocks of the same scene on one slot print as one line, and the same "
      "two on two different slots print as two",
      () async {
        final shot1 = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["ALICE"]);
        final shot2 = _buildShot(id: "shot-2", sceneId: "scene-1", code: "1/2", characters: const ["ALICE"]);
        final shotList = _buildShotList(shots: [shot1, shot2]);

        final foldedPlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
          },
          blocksByDayId: {
            "day-1": [
              _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-1"),
              _buildBlock(id: "block-2", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-2"),
            ],
          },
          roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
          shotLists: [shotList],
        );

        final twoLinePlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [
              _buildSlot(id: "slot-1", shootingDayId: "day-1"),
              _buildSlot(id: "slot-2", shootingDayId: "day-1"),
            ],
          },
          blocksByDayId: {
            "day-1": [
              _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-1"),
              _buildBlock(id: "block-2", shootingDayId: "day-1", slotId: "slot-2", shotId: "shot-2"),
            ],
          },
          roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
          shotLists: [shotList],
        );

        Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
          plan: plan,
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeTitlePage: false,
          exportDate: pinnedExportDate,
        );

        final foldedBytes = await generateFor(foldedPlan);
        final twoLineBytes = await generateFor(twoLinePlan);

        expect(_contentStreams(foldedBytes), isNot(_contentStreams(twoLineBytes)));
        // One row prints less than two: the same trade `ocpt_shooting_plan_pdf_service_test.dart`
        // makes for "less content prints a smaller file".
        expect(foldedBytes.length, lessThan(twoLineBytes.length));
      },
    );

    test("a hold block prints a line while a meal block prints none", () async {
      OcptSchedulePlanSnapshot buildPlanWith(OcptShootingDayBlock? block) => _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
        },
        blocksByDayId: {"day-1": block == null ? const [] : [block]},
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      final withHold = await generateFor(
        buildPlanWith(
          _buildBlock(
            id: "hold-1",
            shootingDayId: "day-1",
            slotId: "slot-1",
            kind: OcptShootingBlockKind.hold,
            sceneId: "scene-1",
          ),
        ),
      );
      final withMeal = await generateFor(
        buildPlanWith(
          _buildBlock(id: "meal-1", shootingDayId: "day-1", slotId: "slot-1", kind: OcptShootingBlockKind.meal),
        ),
      );
      final withNoBlockAtAll = await generateFor(buildPlanWith(null));

      // A meal block prints no line at all: the day reads exactly as one with no block whatsoever.
      expect(_contentStreams(withMeal), _contentStreams(withNoBlockAtAll));
      // A hold block prints its own line, unlike the meal: the two documents must differ.
      expect(_contentStreams(withHold), isNot(_contentStreams(withMeal)));
    });

    test("a day carrying no shooting block prints its band and its empty-day note", () async {
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
        },
      );

      final bytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);

      final emptyDocumentBytes = await service.generate(
        plan: plan,
        dayIds: const ["nope"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      // The live day still prints its own band, unlike the whole-document note below: the two must
      // read differently even though neither prints a table.
      expect(_contentStreams(bytes), isNot(_contentStreams(emptyDocumentBytes)));
    });

    test("a dayIds naming no live day prints the empty-document note rather than a table", () async {
      final bytes = await service.generate(
        plan: buildOneShotPlan(),
        dayIds: const ["nope"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a day that does not shoot is skipped, exactly as an unknown id is", () async {
      // A one-line schedule is the shoot in one line: a rehearsal day ticked (or reaching this
      // through a hand-edited file) prints nothing of its own, so the document reads exactly as it
      // would with only the id that names no live day at all.
      final plan = _buildSnapshot(
        days: [
          _buildDay(id: "day-1", dayNumber: 1, kind: OcptShootingDayKind.rehearsal),
        ],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
        },
        blocksByDayId: {
          "day-1": [
            _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-1"),
          ],
        },
        roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
        shotLists: [
          _buildShotList(
            shots: [
              _buildShot(
                id: "shot-1",
                sceneId: "scene-1",
                code: "1/1",
                characters: const ["ALICE"],
              ),
            ],
          ),
        ],
      );

      final rehearsalBytes = await service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );
      final unknownDayBytes = await service.generate(
        plan: plan,
        dayIds: const ["nope"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      expect(_contentStreams(rehearsalBytes), _contentStreams(unknownDayBytes));
    });

    test("the export moment is what the version line prints, not the wall clock", () async {
      final plan = buildOneShotPlan();

      Future<Uint8List> generateFor(DateTime exportDate) => service.generate(
        plan: plan,
        dayIds: const ["day-1"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: true,
        exportDate: exportDate,
      );

      final morning = await generateFor(DateTime(2026, 1, 15, 9, 30));
      final afternoon = await generateFor(DateTime(2026, 1, 15, 16, 45));
      final sameMorningAgain = await generateFor(DateTime(2026, 1, 15, 9, 30));

      expect(_contentStreams(morning), isNot(_contentStreams(afternoon)));
      expect(_contentStreams(morning), _contentStreams(sameMorningAgain));
    });
  });

  group("multiple episodes", () {
    /// Episode 1's own one-scene shot list: `scene-e1`, prefixed `1.3` — the number
    /// `OcptShotListService.loadShotList` would already have given it.
    OcptShotListSnapshot buildEpisodeOneShotList(OcptShot shot) =>
        _buildShotList(shots: [shot], sceneId: "scene-e1", displaySceneNumber: "1.3");

    /// Episode 2's own one-scene shot list: `scene-e2`, prefixed `2.4`.
    OcptShotListSnapshot buildEpisodeTwoShotList(OcptShot shot) =>
        _buildShotList(shots: [shot], sceneId: "scene-e2", heading: "EXT. STREET - NIGHT", displaySceneNumber: "2.4");

    test(
      "one line per sequence across both episodes: a shot run's own SEQ cell and a hold's own "
      "carry each episode's own prefixed number",
      () async {
        final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1");
        final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1", characters: const ["ALICE"]);

        final blocks = {
          "day-1": [
            _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-e1"),
            // A hold, reserving episode 2's own scene — a sequence not yet shot-listed, which is
            // exactly the case `sceneNumberBySceneId` (not a shot's own code) has to answer for.
            _buildBlock(
              id: "block-2",
              shootingDayId: "day-1",
              slotId: "slot-1",
              kind: OcptShootingBlockKind.hold,
              sceneId: "scene-e2",
            ),
          ],
        };

        final prefixedPlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: blocks,
          roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
          shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(_buildShot(id: "unused", code: "x"))],
        );

        // The same day, but episode 2's own scene reads back with no prefix at all — what a project
        // stuck on a single episode's own reading would have printed instead.
        final unprefixedPlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: blocks,
          roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
          shotLists: [
            buildEpisodeOneShotList(shotOne),
            _buildShotList(
              shots: [_buildShot(id: "unused", code: "x")],
              sceneId: "scene-e2",
              heading: "EXT. STREET - NIGHT",
              displaySceneNumber: "4",
            ),
          ],
        );

        // Episode 1 alone: the control this test's own "both episodes print a line each" assertion
        // is measured against.
        final episodeOneOnlyPlan = _buildSnapshot(
          days: [_buildDay(id: "day-1", dayNumber: 1)],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [blocks["day-1"]!.first],
          },
          roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
          shotLists: [buildEpisodeOneShotList(shotOne)],
        );

        Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
          plan: plan,
          dayIds: const ["day-1"],
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeTitlePage: false,
          exportDate: pinnedExportDate,
        );

        final prefixedBytes = await generateFor(prefixedPlan);
        final unprefixedBytes = await generateFor(unprefixedPlan);
        final episodeOneOnlyBytes = await generateFor(episodeOneOnlyPlan);

        // The hold's own prefixed reading of episode 2's sequence draws differently from the
        // unprefixed one: `sceneNumberBySceneId`'s own prefix genuinely reaches the page.
        expect(_contentStreams(prefixedBytes), isNot(_contentStreams(unprefixedBytes)));
        // Both episodes' own line prints more than episode 1's alone — the hold is not dropped.
        expect(prefixedBytes.length, greaterThan(episodeOneOnlyBytes.length));
      },
    );
  });

  group("oneLineScheduleFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.oneLineScheduleFileName(projectName: "My Movie", suffix: "one-line schedule"),
        "My Movie - one-line schedule.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.oneLineScheduleFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_day_out_of_days_pdf_service_test.dart` uses.
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
