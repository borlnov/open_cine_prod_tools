// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_plan_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// Every localized string of the workbook, named after its own key so a test can tell any two
/// sheets or columns apart without depending on the app's own translations. Mirrors
/// `ocpt_breakdown_xlsx_export_service_test.dart`'s own `_buildLabels`.
const _locationsSheetName = "Locations";
const _sequencesSheetName = "Sequences";
const _peopleSheetName = "Crew and cast";
const _elementsSheetName = "Elements";
const _chronologySheetName = "Chronology";

OcptShootingPlanXlsxLabels _buildLabels() => OcptShootingPlanXlsxLabels(
  fileNameSuffix: "shooting plan",
  locationsSheetName: _locationsSheetName,
  sequencesSheetName: _sequencesSheetName,
  peopleSheetName: _peopleSheetName,
  elementsSheetName: _elementsSheetName,
  chronologySheetName: _chronologySheetName,
  locationsRowHeader: "Location",
  sequencesRowHeader: "Sequence",
  peopleRowHeader: "Position / Role",
  elementsRowHeader: "Element",
  chronologyColumnHeaders: {
    for (final column in OcptShootingPlanXlsxColumn.values) column: column.name,
  },
  dayTagPrefix: "D",
  presenceMark: "x",
  persoLabel: "Cast",
  sequenceRowPrefix: "Seq.",
  crewPositionLabels: const {},
  elementCategoryLabels: const {},
  blockKindLabels: {
    for (final kind in OcptShootingBlockKind.values) kind: kind.name,
  },
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

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({
  required String id,
  required String shootingDayId,
  String label = "",
  List<OcptShootingSlotCastMember> cast = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: shootingDayId,
  label: label,
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: const [],
  cast: cast,
  guests: const [],
  candidates: const [],
);

/// Builds a shooting day block with the few fields these tests read, everything else neutral.
OcptShootingDayBlock _buildBlock({
  required String id,
  required String shootingDayId,
  required String slotId,
  OcptShootingBlockKind kind = OcptShootingBlockKind.shot,
  String? shotId,
  String? sceneId,
  int? durationMinutes = 30,
  String crewNote = "",
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
  crewNote: crewNote,
  roleCandidateId: null,
  roleId: null,
);

/// Builds a cast member with the few fields these tests read, everything else neutral.
OcptShootingSlotCastMember _buildCastMember({required String id, required String slotId, required String roleId}) =>
    OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

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

/// Builds a one-scene shot list snapshot over [shots], all belonging to `scene-1`.
OcptShotListSnapshot _buildShotList({required List<OcptShot> shots}) => OcptShotListSnapshot.build(
  screenplayId: "screenplay-1",
  sequences: [
    OcptSceneShotSequence(
      sceneId: "scene-1",
      heading: "INT. HOUSE - DAY",
      sceneNumber: null,
      displaySceneNumber: "1",
      charStart: 0,
      charEnd: 10,
      shots: shots,
    ),
  ],
);

/// Builds an [OcptSchedulePlanSnapshot] over one screenplay's worth of days/slots/blocks, plus
/// whichever catalogues a test needs — mirrors
/// `ocpt_shooting_plan_pdf_service_test.dart`'s own `_buildSnapshot`.
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

/// Decodes [bytes] and returns the rows of [sheetName], every cell unwrapped to a plain Dart value
/// (a [DateCellValue] kept as-is so a test can compare it directly), an empty cell reading as null.
/// Mirrors `ocpt_resources_xlsx_export_service_test.dart`'s own `_rowsOf`.
List<List<Object?>> _rowsOf(List<int> bytes, String sheetName) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables[sheetName];
  expect(sheet, isNotNull, reason: "the workbook has no sheet named $sheetName");

  return [
    for (final row in sheet!.rows) [for (final cell in row) _valueOf(cell)],
  ];
}

/// The plain Dart value [cell] holds, or null when it is empty.
Object? _valueOf(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    TextCellValue(:final value) => value.toString(),
    IntCellValue(:final value) => value,
    DateCellValue() => value,
    null => null,
    _ => value.toString(),
  };
}

/// The value of column [index] in [row], or null when the row is shorter than that column.
Object? _cellAt(List<Object?> row, int index) => index < row.length ? row[index] : null;

void main() {
  const service = OcptShootingPlanXlsxExportService();

  Uint8List generate({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
  }) => service.generate(plan: plan, dayIds: dayIds, labels: _buildLabels());

  group("xlsxFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.xlsxFileName(projectName: "My Movie", suffix: "shooting plan"),
        "My Movie - shooting plan.xlsx",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.xlsxFileName(projectName: "My Movie", suffix: "  "), "My Movie.xlsx");
    });
  });

  group("generate", () {
    test("writes exactly five sheets, named after the labels", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final bytes = generate(
        plan: _buildSnapshot(days: [day], slotsByDayId: const {}),
        dayIds: const ["day-1"],
      );

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys.toSet(), {
        _locationsSheetName,
        _sequencesSheetName,
        _peopleSheetName,
        _elementsSheetName,
        _chronologySheetName,
      });
    });

    test("the Chronology sheet's own header row is bold", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final bytes = generate(
        plan: _buildSnapshot(days: [day], slotsByDayId: const {}),
        dayIds: const ["day-1"],
      );

      final excel = Excel.decodeBytes(bytes);
      final headerCell = excel.tables[_chronologySheetName]!.rows.first.first;
      expect(headerCell?.cellStyle?.isBold, isTrue);
    });

    test("the Locations sheet's own two header rows are bold", () {
      final day = _buildDay(id: "day-1", dayNumber: 1);
      final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1", label: "Morning");
      final bytes = generate(
        plan: _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
        ),
        dayIds: const ["day-1"],
      );

      final excel = Excel.decodeBytes(bytes);
      final rows = excel.tables[_locationsSheetName]!.rows;
      expect(rows[0][1]?.cellStyle?.isBold, isTrue);
      expect(rows[1][0]?.cellStyle?.isBold, isTrue);
      expect(rows[1][1]?.cellStyle?.isBold, isTrue);
    });

    test("an empty range still produces a decodable workbook", () {
      final bytes = generate(plan: _buildSnapshot(days: const [], slotsByDayId: const {}), dayIds: const []);

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, isNotEmpty);
      // Every sheet is left with its own header row(s) alone.
      expect(_rowsOf(bytes, _chronologySheetName), hasLength(1));
    });

    group("the Chronology sheet", () {
      test("holds one row per block, in shooting order, across every printed day", () {
        final dayOne = _buildDay(id: "day-1", dayNumber: 1);
        final dayTwo = _buildDay(id: "day-2", dayNumber: 2);
        final slotOne = _buildSlot(id: "slot-1", shootingDayId: "day-1", label: "Morning");
        final slotTwo = _buildSlot(id: "slot-2", shootingDayId: "day-2", label: "Morning");
        final shotA = _buildShot(id: "shot-a", sceneId: "scene-1", code: "1/1");
        final shotB = _buildShot(id: "shot-b", sceneId: "scene-1", code: "1/2");
        final blockA = _buildBlock(id: "block-a", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-a");
        final blockB = _buildBlock(id: "block-b", shootingDayId: "day-2", slotId: "slot-2", shotId: "shot-b");

        final bytes = generate(
          plan: _buildSnapshot(
            days: [dayOne, dayTwo],
            slotsByDayId: {
              "day-1": [slotOne],
              "day-2": [slotTwo],
            },
            blocksByDayId: {
              "day-1": [blockA],
              "day-2": [blockB],
            },
            shotLists: [_buildShotList(shots: [shotA, shotB])],
          ),
          dayIds: const ["day-1", "day-2"],
        );

        final rows = _rowsOf(bytes, _chronologySheetName);
        expect(rows, hasLength(3)); // header + one row per block
        expect(
          _cellAt(rows[1], OcptShootingPlanXlsxColumn.shot.index),
          "1/1",
        );
        expect(
          _cellAt(rows[2], OcptShootingPlanXlsxColumn.shot.index),
          "1/2",
        );
        expect(
          _cellAt(rows[1], OcptShootingPlanXlsxColumn.dayTag.index),
          "D1",
        );
        expect(
          _cellAt(rows[1], OcptShootingPlanXlsxColumn.date.index),
          DateCellValue.fromDateTime(dayOne.date),
        );
      });

      test("a day that does not shoot is skipped, ticked or not", () {
        // This workbook is about the shoot: a casting day reaching it — through a hand-edited file,
        // or a day whose kind changed after the dialog was opened — prints nothing, exactly as an
        // id naming no live day at all does.
        final shootDay = _buildDay(id: "day-1", dayNumber: 1);
        final castingDay = _buildDay(
          id: "day-2",
          dayNumber: 1,
          kind: OcptShootingDayKind.casting,
        );
        final shootSlot = _buildSlot(id: "slot-1", shootingDayId: "day-1", label: "Morning");
        final castingSlot = _buildSlot(id: "slot-2", shootingDayId: "day-2", label: "Morning");
        final shotA = _buildShot(id: "shot-a", sceneId: "scene-1", code: "1/1");
        final shotB = _buildShot(id: "shot-b", sceneId: "scene-1", code: "1/2");

        final bytes = generate(
          plan: _buildSnapshot(
            days: [shootDay, castingDay],
            slotsByDayId: {
              "day-1": [shootSlot],
              "day-2": [castingSlot],
            },
            blocksByDayId: {
              "day-1": [
                _buildBlock(
                  id: "block-a",
                  shootingDayId: "day-1",
                  slotId: "slot-1",
                  shotId: "shot-a",
                ),
              ],
              "day-2": [
                _buildBlock(
                  id: "block-b",
                  shootingDayId: "day-2",
                  slotId: "slot-2",
                  shotId: "shot-b",
                ),
              ],
            },
            shotLists: [_buildShotList(shots: [shotA, shotB])],
          ),
          dayIds: const ["day-1", "day-2"],
        );

        final rows = _rowsOf(bytes, _chronologySheetName);
        expect(rows, hasLength(2)); // header + the shooting day's own single block
        expect(_cellAt(rows[1], OcptShootingPlanXlsxColumn.shot.index), "1/1");
      });

      test("a day with no live slot writes no chronology row", () {
        final day = _buildDay(id: "day-1", dayNumber: 1);

        final bytes = generate(
          plan: _buildSnapshot(days: [day], slotsByDayId: const {}),
          dayIds: const ["day-1"],
        );

        expect(_rowsOf(bytes, _chronologySheetName), hasLength(1));
      });

      test("prints the block's own kind, duration, roles and crew note", () {
        final day = _buildDay(id: "day-1", dayNumber: 1);
        final slot = _buildSlot(
          id: "slot-1",
          shootingDayId: "day-1",
          cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
        );
        final role = _buildRole(id: "role-1", name: "COP");
        final shot = _buildShot(id: "shot-1", sceneId: "scene-1", code: "1/1", characters: const ["COP"]);
        final block = _buildBlock(
          id: "block-1",
          shootingDayId: "day-1",
          slotId: "slot-1",
          shotId: "shot-1",
          durationMinutes: 45,
          crewNote: "Careful with the vase",
        );

        final bytes = generate(
          plan: _buildSnapshot(
            days: [day],
            slotsByDayId: {
              "day-1": [slot],
            },
            blocksByDayId: {
              "day-1": [block],
            },
            roles: [role],
            shotLists: [_buildShotList(shots: [shot])],
          ),
          dayIds: const ["day-1"],
        );

        final row = _rowsOf(bytes, _chronologySheetName)[1];
        expect(_cellAt(row, OcptShootingPlanXlsxColumn.kind.index), OcptShootingBlockKind.shot.name);
        expect(_cellAt(row, OcptShootingPlanXlsxColumn.durationMinutes.index), 45);
        expect(_cellAt(row, OcptShootingPlanXlsxColumn.roles.index), "COP");
        expect(_cellAt(row, OcptShootingPlanXlsxColumn.crewNote.index), "Careful with the vase");
      });

      test("a hold block prints its sequence's own heading and no shot code", () {
        final day = _buildDay(id: "day-1", dayNumber: 1);
        final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1");
        final block = _buildBlock(
          id: "block-1",
          shootingDayId: "day-1",
          slotId: "slot-1",
          kind: OcptShootingBlockKind.hold,
          sceneId: "scene-1",
        );

        final bytes = generate(
          plan: _buildSnapshot(
            days: [day],
            slotsByDayId: {
              "day-1": [slot],
            },
            blocksByDayId: {
              "day-1": [block],
            },
            shotLists: [_buildShotList(shots: const [])],
          ),
          dayIds: const ["day-1"],
        );

        final row = _rowsOf(bytes, _chronologySheetName)[1];
        expect(_cellAt(row, OcptShootingPlanXlsxColumn.sequence.index), "INT. HOUSE - DAY");
        expect(_cellAt(row, OcptShootingPlanXlsxColumn.shot.index), isNull);
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

      /// A day with one slot playing one shot of each episode, on two different scenes.
      OcptSchedulePlanSnapshot buildTwoEpisodeDayPlan() {
        final day = _buildDay(id: "day-1", dayNumber: 1);
        final slot = _buildSlot(id: "slot-1", shootingDayId: "day-1");
        final shotOne = _buildShot(id: "shot-e1", sceneId: "scene-e1", code: "1.3/1");
        final shotTwo = _buildShot(id: "shot-e2", sceneId: "scene-e2", code: "2.4/1");

        return _buildSnapshot(
          days: [day],
          slotsByDayId: {
            "day-1": [slot],
          },
          blocksByDayId: {
            "day-1": [
              _buildBlock(id: "block-1", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-e1"),
              _buildBlock(id: "block-2", shootingDayId: "day-1", slotId: "slot-1", shotId: "shot-e2"),
            ],
          },
          shotLists: [buildEpisodeOneShotList(shotOne), buildEpisodeTwoShotList(shotTwo)],
        );
      }

      test(
        "the Sequences sheet reads exactly OcptShootingPlanGrids.sequencesRows, episode 1 before "
        "episode 2 — the same rows the PDF service draws, never a second computation of them",
        () {
          final plan = buildTwoEpisodeDayPlan();
          final labels = _buildLabels();

          final grids = OcptShootingPlanGrids.of(
            plan: plan,
            dayIds: const ["day-1"],
            presenceMark: labels.presenceMark,
            persoLabel: labels.persoLabel,
            sequenceRowPrefix: labels.sequenceRowPrefix,
            emptyValue: "—",
            crewPositionLabelById: labels.crewPositionLabels,
            elementCategoryLabels: labels.elementCategoryLabels,
          );

          final bytes = generate(plan: plan, dayIds: const ["day-1"]);
          final rows = _rowsOf(bytes, _sequencesSheetName);
          // The sheet's own two header rows (the day-tag row, the slot-label row) come first, then
          // one row per `OcptShootingPlanGridRow` of the grid, in the very same order.
          final sequenceLabels = [for (final row in rows.skip(2)) _cellAt(row, 0)];

          expect(sequenceLabels, grids.sequencesRows.map((row) => row.label).toList());
          expect(sequenceLabels, ["Seq. 1.3", "Seq. 2.4"]);
        },
      );

      test("the Chronology sheet's own shot cells carry each episode's own prefixed code", () {
        final bytes = generate(plan: buildTwoEpisodeDayPlan(), dayIds: const ["day-1"]);

        final rows = _rowsOf(bytes, _chronologySheetName);
        expect(_cellAt(rows[1], OcptShootingPlanXlsxColumn.shot.index), "1.3/1");
        expect(_cellAt(rows[2], OcptShootingPlanXlsxColumn.shot.index), "2.4/1");
      });
    });
  });
}
