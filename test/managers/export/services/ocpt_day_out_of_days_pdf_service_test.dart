// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_day_out_of_days_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_out_of_days.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the schedule does — the same convention `ocpt_shooting_plan_pdf_service_test.dart` follows.
const _labels = OcptDayOutOfDaysLabels(
  fileNameSuffix: "day out of days",
  documentTitle: "Day Out of Days",
  directorLine: '"My Movie" by Jane Doe',
  versionLabel: "Version",
  dayTagPrefix: "D",
  dayDateLabels: {"day-1": "1/1", "day-2": "1/2", "day-3": "1/3"},
  roleHeader: "Role",
  workedDaysHeader: "Worked",
  heldDaysHeader: "Held",
  codeLabels: {
    OcptDayOutOfDaysCode.startWork: "SW",
    OcptDayOutOfDaysCode.work: "W",
    OcptDayOutOfDaysCode.workFinish: "WF",
    OcptDayOutOfDaysCode.startWorkFinish: "SWF",
    OcptDayOutOfDaysCode.hold: "H",
  },
  codeDescriptions: {
    OcptDayOutOfDaysCode.startWork: "Start work",
    OcptDayOutOfDaysCode.work: "Work",
    OcptDayOutOfDaysCode.workFinish: "Work finish",
    OcptDayOutOfDaysCode.startWorkFinish: "Start work and finish",
    OcptDayOutOfDaysCode.hold: "Hold",
  },
  legendSectionTitle: "Legend",
  unnamedRoleLabel: "Unnamed role",
  emptyTableNote: "No role is called on the printed days yet.",
);

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

/// Builds a slot convoking [roleIds], everything else neutral.
OcptShootingSlot _buildSlot({
  required String id,
  required String shootingDayId,
  List<String> roleIds = const [],
}) => OcptShootingSlot(
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
  cast: [
    for (final roleId in roleIds)
      OcptShootingSlotCastMember(id: "cast-$id-$roleId", slotId: id, roleId: roleId, notes: ""),
  ],
  guests: const [],
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
  candidates: const [],
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

/// Builds a one-scene shot list snapshot over [shots] — for one episode's own `screenplayId`, its
/// scene's own `displaySceneNumber` already carrying the `<episode>.<scene>` prefix
/// `OcptShotListService.loadShotList` would have given it.
OcptShotListSnapshot _buildEpisodeShotList({
  required String screenplayId,
  required String sceneId,
  required String displaySceneNumber,
  required List<OcptShot> shots,
}) => OcptShotListSnapshot.build(
  screenplayId: screenplayId,
  sequences: [
    OcptSceneShotSequence(
      sceneId: sceneId,
      heading: "INT. HOUSE - DAY",
      sceneNumber: null,
      displaySceneNumber: displaySceneNumber,
      charStart: 0,
      charEnd: 10,
      shots: shots,
    ),
  ],
);

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days and slots, plus its
/// cast.
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
  final service = OcptDayOutOfDaysPdfService();
  const pageSetup = OcptPageSetup.standard();
  final pinnedExportDate = DateTime(2026, 1, 15);

  /// A three-day shoot whose only role works on the first and the last day.
  OcptSchedulePlanSnapshot buildThreeDayPlan() => _buildSnapshot(
    days: [
      _buildDay(id: "day-1", dayNumber: 1),
      _buildDay(id: "day-2", dayNumber: 2),
      _buildDay(id: "day-3", dayNumber: 3),
    ],
    slotsByDayId: {
      "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1", roleIds: const ["role-1"])],
      "day-2": [_buildSlot(id: "slot-2", shootingDayId: "day-2")],
      "day-3": [_buildSlot(id: "slot-3", shootingDayId: "day-3", roleIds: const ["role-1"])],
    },
    roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
  );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await service.generate(
        plan: buildThreeDayPlan(),
        dayIds: const ["day-1", "day-2", "day-3"],
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
      final plan = buildThreeDayPlan();

      Future<Uint8List> generateFor({required bool includeTitlePage}) => service.generate(
        plan: plan,
        dayIds: const ["day-1", "day-2", "day-3"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: includeTitlePage,
        exportDate: pinnedExportDate,
      );

      expect(_pageCount(await generateFor(includeTitlePage: true)), 2);
      expect(_pageCount(await generateFor(includeTitlePage: false)), 1);
    });

    test("a role held on a middle day prints differently from one released before it", () async {
      final withHold = buildThreeDayPlan();
      final withoutHold = _buildSnapshot(
        days: [
          _buildDay(id: "day-1", dayNumber: 1),
          _buildDay(id: "day-2", dayNumber: 2),
          _buildDay(id: "day-3", dayNumber: 3),
        ],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1", roleIds: const ["role-1"])],
          "day-2": [_buildSlot(id: "slot-2", shootingDayId: "day-2")],
          "day-3": [_buildSlot(id: "slot-3", shootingDayId: "day-3")],
        },
        roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
      );

      Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
        plan: plan,
        dayIds: const ["day-1", "day-2", "day-3"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      // The held day prints an `H` the released one leaves blank, and the trailing counts differ.
      expect(_contentStreams(await generateFor(withHold)), isNot(_contentStreams(await generateFor(withoutHold))));
    });

    test("a range naming no live day prints the empty note rather than a table", () async {
      final bytes = await service.generate(
        plan: buildThreeDayPlan(),
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

    test("a shoot convoking nobody still produces a readable one-page document", () async {
      final plan = _buildSnapshot(
        days: [_buildDay(id: "day-1", dayNumber: 1)],
        slotsByDayId: {
          "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1")],
        },
        roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
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

      expect(_pageCount(bytes), 1);
    });

    test("a range wider than one page chunks the columns over several pages", () async {
      final days = [for (var i = 1; i <= 30; i++) _buildDay(id: "day-$i", dayNumber: i)];
      final plan = _buildSnapshot(
        days: days,
        slotsByDayId: {
          for (var i = 1; i <= 30; i++)
            "day-$i": [_buildSlot(id: "slot-$i", shootingDayId: "day-$i", roleIds: const ["role-1"])],
        },
        roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
      );

      final bytes = await service.generate(
        plan: plan,
        dayIds: [for (var i = 1; i <= 30; i++) "day-$i"],
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
        exportDate: pinnedExportDate,
      );

      // 30 day columns against a 12-column page: three chunks, one page each.
      expect(_pageCount(bytes), 3);
    });

    test("the export moment is what the version line prints, not the wall clock", () async {
      final plan = buildThreeDayPlan();

      Future<Uint8List> generateFor(DateTime exportDate) => service.generate(
        plan: plan,
        dayIds: const ["day-1", "day-2", "day-3"],
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
    test(
      "a role convoked on days that play different episodes still draws one row spanning the "
      "whole series, held on the day between them",
      () async {
        // Day 1 plays episode 1's own scene, day 3 plays episode 2's — the very shape a series shot
        // out of order produces, and exactly the case §4.4 says buys a single Day Out of Days row
        // "for free": `convokedRoleIdsOfDay` reads `slot.cast` alone, which never named a screenplay
        // to begin with (ADR 0019), so the span below is computed no differently than it would be
        // for a role convoked on two days of one screenplay.
        final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1");
        final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1");

        OcptSchedulePlanSnapshot buildPlan({required bool day3ConvokesRole}) => _buildSnapshot(
          days: [
            _buildDay(id: "day-1", dayNumber: 1),
            _buildDay(id: "day-2", dayNumber: 2),
            _buildDay(id: "day-3", dayNumber: 3),
          ],
          slotsByDayId: {
            "day-1": [_buildSlot(id: "slot-1", shootingDayId: "day-1", roleIds: const ["role-1"])],
            "day-2": [_buildSlot(id: "slot-2", shootingDayId: "day-2")],
            "day-3": [
              _buildSlot(id: "slot-3", shootingDayId: "day-3", roleIds: day3ConvokesRole ? const ["role-1"] : const []),
            ],
          },
          blocksByDayId: {
            "day-1": [
              _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-e1"),
            ],
            "day-3": [
              _buildBlock(id: "block-3", shootingDayId: "day-3", slotId: "slot-3", shotId: "shot-e2"),
            ],
          },
          roles: [_buildRole(id: "role-1", name: "Alice", number: 1)],
          shotLists: [
            _buildEpisodeShotList(
              screenplayId: "episode-1",
              sceneId: "scene-e1",
              displaySceneNumber: "1.3",
              shots: [shotOne],
            ),
            _buildEpisodeShotList(
              screenplayId: "episode-2",
              sceneId: "scene-e2",
              displaySceneNumber: "2.4",
              shots: [shotTwo],
            ),
          ],
        );

        Future<Uint8List> generateFor(OcptSchedulePlanSnapshot plan) => service.generate(
          plan: plan,
          dayIds: const ["day-1", "day-2", "day-3"],
          pageSetup: pageSetup,
          labels: _labels,
          projectName: "My Movie",
          includeTitlePage: false,
          exportDate: pinnedExportDate,
        );

        // Alice is convoked on day 1 (episode 1) and day 3 (episode 2) alike: one row spans start
        // to finish across the episode boundary, held (not released) on day 2 in between.
        final spanningBytes = await generateFor(buildPlan(day3ConvokesRole: true));
        // Released before episode 2's own day instead: the span's own finish, and therefore day 2's
        // own code and the trailing counts, must read differently.
        final releasedBytes = await generateFor(buildPlan(day3ConvokesRole: false));

        expect(ascii.decode(spanningBytes.sublist(0, 4)), "%PDF");
        expect(_contentStreams(spanningBytes), isNot(_contentStreams(releasedBytes)));
      },
    );
  });

  group("dayOutOfDaysFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.dayOutOfDaysFileName(projectName: "My Movie", suffix: "day out of days"),
        "My Movie - day out of days.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.dayOutOfDaysFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — the same cheap approach `ocpt_shooting_plan_pdf_service_test.dart` uses.
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
