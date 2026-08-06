// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// The sheet name every test here exports under.
const _sheetName = "Shot list";

/// Builds a shot, every field left at a neutral value unless the test overrides it.
OcptShot _buildShot({
  required String id,
  required String code,
  String? orphanedHeading,
  List<String> characters = const [],
  String shotSize = "",
  String abbreviation = "",
  String framing = "",
  String cameraMove = "",
  String lens = "",
  String recordingFormat = "",
  int? estimatedDurationMs,
  String? shootingDay,
  int? plannedTakes,
  String sound = "",
  OcptShotStatus status = OcptShotStatus.toShoot,
  double averageDifficulty = 1,
  String notes = "",
  String locationNotes = "",
}) => OcptShot(
  id: id,
  screenplayId: "screenplay",
  sceneId: orphanedHeading == null ? "scene" : null,
  orphanedHeading: orphanedHeading,
  position: 0,
  shotSize: shotSize,
  abbreviation: abbreviation,
  framing: framing,
  cameraMove: cameraMove,
  lens: lens,
  recordingFormat: recordingFormat,
  estimatedDurationMs: estimatedDurationMs,
  shootingDay: shootingDay,
  plannedTakes: plannedTakes,
  sound: sound,
  status: status,
  difficultySet: 1,
  difficultyCamera: 1,
  difficultyActing: 1,
  difficultySound: 1,
  notes: notes,
  locationNotes: locationNotes,
  needsCheck: false,
  checkReason: null,
  characters: characters,
  coverageRanges: const [],
  code: code,
  averageDifficulty: averageDifficulty,
);

/// Builds a scene sequence holding [shots].
OcptSceneShotSequence _buildSceneSequence({
  required String sceneId,
  required String heading,
  required List<OcptShot> shots,
}) => OcptSceneShotSequence(
  sceneId: sceneId,
  heading: heading,
  sceneNumber: null,
  displaySceneNumber: "1",
  charStart: 0,
  charEnd: 40,
  shots: shots,
);

/// Builds the labels the tests export with: a header naming each column after the enum value
/// itself, so an assertion can tell any two columns apart without depending on the app's own
/// translations.
OcptShotListXlsxLabels _buildLabels({
  Map<String, String> sequenceTitles = const {},
  String sheetName = _sheetName,
}) => OcptShotListXlsxLabels(
  sheetName: sheetName,
  columnHeaders: {
    for (final column in OcptShotListXlsxColumn.values) column: column.name,
  },
  statusLabels: const {
    OcptShotStatus.toShoot: "To shoot",
    OcptShotStatus.shot: "Shot",
    OcptShotStatus.retake: "Retake",
  },
  sequenceTitles: sequenceTitles,
);

/// Decodes [bytes] and returns the rows of its [_sheetName] sheet, as plain Dart values.
///
/// Every cell is unwrapped to the value it holds (a `String`, an `int` or a `double`) so a test
/// asserts on what the spreadsheet shows rather than on the library's own cell wrappers; an empty
/// cell reads as null.
List<List<Object?>> _rowsOf(List<int> bytes, {String sheetName = _sheetName}) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables[sheetName];
  expect(sheet, isNotNull, reason: "the workbook has no sheet named $sheetName");

  return [
    for (final row in sheet!.rows) [for (final cell in row) _valueOf(cell)],
  ];
}

/// The plain Dart value [cell] holds, or null when it is empty.
Object? _valueOf(Data? cell) => switch (cell?.value) {
  TextCellValue(:final value) => value.toString(),
  IntCellValue(:final value) => value,
  DoubleCellValue(:final value) => value,
  null => null,
  final other => other.toString(),
};

/// The value of the column [column] in [row], or null when the row is shorter than that column.
///
/// A row the workbook wrote fewer cells into than the sheet has columns (a sequence separator row)
/// is read as empty there rather than as an out-of-range error.
Object? _cellOf(List<Object?> row, OcptShotListXlsxColumn column) =>
    column.index < row.length ? row[column.index] : null;

void main() {
  const service = OcptShotListXlsxExportService();

  group('xlsxFileName', () {
    test('appends the .xlsx extension to the project name', () {
      expect(service.xlsxFileName("My Movie"), "My Movie.xlsx");
    });
  });

  group('generate', () {
    test('writes the header row, then one separator row per sequence and one row per shot', () {
      final snapshot = OcptShotListSnapshot.build(
        screenplayId: "screenplay",
        sequences: [
          _buildSceneSequence(
            sceneId: "scene-1",
            heading: "INT. FLAT - NIGHT",
            shots: [
              _buildShot(id: "shot-1", code: "1/1"),
              _buildShot(id: "shot-2", code: "1/2"),
            ],
          ),
          _buildSceneSequence(
            sceneId: "scene-2",
            heading: "EXT. STREET - DAY",
            shots: [_buildShot(id: "shot-3", code: "2/1")],
          ),
        ],
      );

      final rows = _rowsOf(
        service.generate(
          snapshot: snapshot,
          labels: _buildLabels(
            sequenceTitles: const {"scene-1": "Sequence 1", "scene-2": "Sequence 2"},
          ),
        ),
      );

      expect(rows, hasLength(6));
      expect(
        rows.first,
        [for (final column in OcptShotListXlsxColumn.values) column.name],
      );
      expect(rows[1].first, "Sequence 1");
      expect(_cellOf(rows[2], OcptShotListXlsxColumn.shot), "1/1");
      expect(_cellOf(rows[3], OcptShotListXlsxColumn.shot), "1/2");
      expect(rows[4].first, "Sequence 2");
      expect(_cellOf(rows[5], OcptShotListXlsxColumn.shot), "2/1");
    });

    test('writes every column of a shot, whichever the table happens to show', () {
      final snapshot = OcptShotListSnapshot.build(
        screenplayId: "screenplay",
        sequences: [
          _buildSceneSequence(
            sceneId: "scene-1",
            heading: "INT. FLAT - NIGHT",
            shots: [
              _buildShot(
                id: "shot-1",
                code: "1/1",
                characters: const ["LÉA", "MARC"],
                shotSize: "Close-up",
                abbreviation: "CU",
                framing: "Low angle",
                cameraMove: "Slow push in",
                lens: "35mm",
                recordingFormat: "4K · 25 fps",
                estimatedDurationMs: 90000,
                plannedTakes: 4,
                sound: "Direct sound",
                status: OcptShotStatus.retake,
                averageDifficulty: 2.75,
                notes: "Keep the door in frame.",
                locationNotes: "Flat visited on the 12th.",
              ),
            ],
          ),
        ],
        placementsByShotId: {
          "shot-1": OcptShotPlacement(
            shotId: "shot-1",
            dayId: "day-3",
            dayNumber: 3,
            date: DateTime(2026, 8, 4),
          ),
        },
      );

      final rows = _rowsOf(
        service.generate(
          snapshot: snapshot,
          labels: _buildLabels(sequenceTitles: const {"scene-1": "Sequence 1"}),
        ),
      );
      final shotRow = rows[2];

      expect(_cellOf(shotRow, OcptShotListXlsxColumn.shot), "1/1");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.characters), "LÉA, MARC");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.set), "INT. FLAT - NIGHT");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.shotSize), "Close-up");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.abbreviation), "CU");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.framing), "Low angle");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.cameraMove), "Slow push in");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.lens), "35mm");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.recordingFormat), "4K · 25 fps");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.duration), "01:30");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.takes), 4);
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.sound), "Direct sound");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.difficulty), 2.75);
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.shootingDay), "J3 · 2026-08-04");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.status), "Retake");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.notes), "Keep the door in frame.");
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.locationNotes), "Flat visited on the 12th.");
    });

    test('leaves a field the user never filled in as an empty cell, never as a dash', () {
      final snapshot = OcptShotListSnapshot.build(
        screenplayId: "screenplay",
        sequences: [
          _buildSceneSequence(
            sceneId: "scene-1",
            heading: "INT. FLAT - NIGHT",
            shots: [_buildShot(id: "shot-1", code: "1/1")],
          ),
        ],
      );

      final rows = _rowsOf(
        service.generate(
          snapshot: snapshot,
          labels: _buildLabels(sequenceTitles: const {"scene-1": "Sequence 1"}),
        ),
      );
      final shotRow = rows[2];

      expect(_cellOf(shotRow, OcptShotListXlsxColumn.shotSize), isNull);
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.abbreviation), isNull);
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.characters), isNull);
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.duration), isNull);
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.takes), isNull);
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.shootingDay), isNull);
      expect(_cellOf(shotRow, OcptShotListXlsxColumn.notes), isNull);
    });

    test('writes the orphan group, each of its shots keeping the heading its scene had', () {
      final snapshot = OcptShotListSnapshot.build(
        screenplayId: "screenplay",
        sequences: [
          _buildSceneSequence(
            sceneId: "scene-1",
            heading: "INT. FLAT - NIGHT",
            shots: [_buildShot(id: "shot-1", code: "1/1")],
          ),
          OcptOrphanShotSequence(
            shots: [
              _buildShot(id: "shot-2", code: "—/1", orphanedHeading: "INT. CELLAR - DAY"),
            ],
          ),
        ],
      );

      final rows = _rowsOf(
        service.generate(
          snapshot: snapshot,
          labels: _buildLabels(
            sequenceTitles: const {
              "scene-1": "Sequence 1",
              OcptOrphanShotSequence.sequenceId: "Orphaned shots",
            },
          ),
        ),
      );

      expect(rows[3].first, "Orphaned shots");
      expect(_cellOf(rows[4], OcptShotListXlsxColumn.shot), "—/1");
      expect(_cellOf(rows[4], OcptShotListXlsxColumn.set), "INT. CELLAR - DAY");
    });

    test('writes a sequence holding no shot at all as its separator row alone', () {
      final snapshot = OcptShotListSnapshot.build(
        screenplayId: "screenplay",
        sequences: [
          _buildSceneSequence(sceneId: "scene-1", heading: "INT. FLAT - NIGHT", shots: const []),
        ],
      );

      final rows = _rowsOf(
        service.generate(
          snapshot: snapshot,
          labels: _buildLabels(sequenceTitles: const {"scene-1": "Sequence 1"}),
        ),
      );

      expect(rows, hasLength(2));
      expect(rows[1].first, "Sequence 1");
    });

    test('writes the header row alone for a screenplay with no sequence at all', () {
      final snapshot = OcptShotListSnapshot.build(screenplayId: "screenplay", sequences: const []);

      final rows = _rowsOf(service.generate(snapshot: snapshot, labels: _buildLabels()));

      expect(rows, hasLength(1));
      expect(rows.first.first, OcptShotListXlsxColumn.shot.name);
    });

    test('names the single sheet after the labels, with no leftover default sheet', () {
      final snapshot = OcptShotListSnapshot.build(screenplayId: "screenplay", sequences: const []);

      final excel = Excel.decodeBytes(
        service.generate(
          snapshot: snapshot,
          labels: _buildLabels(sheetName: "Découpage technique"),
        ),
      );

      expect(excel.tables.keys, ["Découpage technique"]);
    });

    test('falls back to a valid sheet name when the labels carry a blank one', () {
      final snapshot = OcptShotListSnapshot.build(screenplayId: "screenplay", sequences: const []);

      final excel = Excel.decodeBytes(
        service.generate(snapshot: snapshot, labels: _buildLabels(sheetName: "   ")),
      );

      expect(excel.tables.keys, [OcptShotListXlsxExportService.fallbackSheetName]);
    });
  });
}
