// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_xlsx_column.dart';

/// Renders a whole shot list into the bytes of an XLSX workbook.
///
/// This is pure in-memory workbook building with no I/O of its own (no dialog, no file system
/// access): it's owned by `OcptExportManager` and exposed as a public final field, reached through
/// the manager rather than through `globalGetIt()` (RFL18), exactly like `OcptPdfExportService`
/// and `OcptFountainIoService` are.
///
/// The sheet is one header row, then every sequence in the snapshot's own order — each introduced
/// by a separator row carrying its title, empty sequences included, so a scene nobody has broken
/// down yet reads as exactly that rather than silently disappearing — and one row per shot under
/// it. Every [OcptShotListXlsxColumn] is always written, whichever columns the table happens to
/// show: the workbook is what leaves the app, so hiding a column on screen must not amputate the
/// file a crew works from.
class OcptShotListXlsxExportService {
  /// The extension of an Excel workbook file, without its leading dot.
  static const xlsxFileExtension = "xlsx";

  /// The sheet name used when the caller's own [OcptShotListXlsxLabels.sheetName] is blank.
  ///
  /// A workbook whose only sheet has no name is not a valid one, so a missing (or whitespace-only)
  /// localized name falls back to this rather than producing a file no spreadsheet can open.
  static const fallbackSheetName = "Shot list";

  /// Class constructor
  const OcptShotListXlsxExportService();

  /// The `.xlsx` file name to suggest when exporting the shot list of the project named
  /// [projectName].
  String xlsxFileName(String projectName) => "$projectName.$xlsxFileExtension";

  /// Builds the workbook holding [snapshot]'s whole shot list, titled and headed with [labels],
  /// and returns its bytes.
  ///
  /// Throws a [StateError] if the workbook cannot be encoded, which the caller reports as a failed
  /// export: `excel_community` returns null there rather than throwing anything of its own.
  Uint8List generate({
    required OcptShotListSnapshot snapshot,
    required OcptShotListXlsxLabels labels,
  }) {
    final excel = Excel.createExcel();
    final sheetName = _sheetNameOf(labels);
    _renameDefaultSheet(excel, sheetName);

    final sheet = excel[sheetName];
    _appendHeaderRow(sheet, labels);

    for (final sequence in snapshot.sequences) {
      _appendSequenceRows(sheet: sheet, sequence: sequence, labels: labels);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError("The shot list workbook could not be encoded");
    }

    return Uint8List.fromList(bytes);
  }

  /// The name to give the workbook's single sheet: [labels]'s own, or [fallbackSheetName] when it
  /// holds nothing but whitespace.
  String _sheetNameOf(OcptShotListXlsxLabels labels) =>
      labels.sheetName.trim().isEmpty ? fallbackSheetName : labels.sheetName;

  /// Renames the sheet [Excel.createExcel] starts from to [sheetName], so the workbook ends up
  /// with exactly one sheet rather than the named one plus an empty `Sheet1` next to it.
  ///
  /// A no-op when the default sheet already carries that name, which is also what `rename` itself
  /// does when asked to rename a sheet onto an existing name.
  void _renameDefaultSheet(Excel excel, String sheetName) {
    final defaultSheetName = excel.getDefaultSheet();
    if (defaultSheetName == null || defaultSheetName == sheetName) {
      return;
    }

    excel.rename(defaultSheetName, sheetName);
  }

  /// Appends the sheet's single header row, one cell per [OcptShotListXlsxColumn], and emboldens
  /// it.
  void _appendHeaderRow(Sheet sheet, OcptShotListXlsxLabels labels) {
    final headerRowIndex = sheet.maxRows;
    sheet.appendRow([
      for (final column in OcptShotListXlsxColumn.values)
        TextCellValue(labels.headerOf(column)),
    ]);

    for (var columnIndex = 0; columnIndex < OcptShotListXlsxColumn.values.length; columnIndex++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: headerRowIndex))
          .cellStyle = CellStyle(bold: true);
    }
  }

  /// Appends [sequence]'s separator row, then one row per shot it holds.
  void _appendSequenceRows({
    required Sheet sheet,
    required OcptShotSequence sequence,
    required OcptShotListXlsxLabels labels,
  }) {
    final separatorRowIndex = sheet.maxRows;
    sheet.appendRow([TextCellValue(labels.titleOfSequence(sequence.id))]);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: separatorRowIndex))
        .cellStyle = CellStyle(bold: true);

    for (final shot in sequence.shots) {
      sheet.appendRow([
        for (final column in OcptShotListXlsxColumn.values)
          _cellOf(column: column, shot: shot, sequence: sequence, labels: labels),
      ]);
    }
  }

  /// The cell [column] holds for [shot], or null to leave it empty.
  ///
  /// A field the user hasn't filled in is written as an empty cell rather than as the em dash the
  /// table shows in its place: a spreadsheet's own way of saying "nothing here" is a blank cell,
  /// and a dash would be sorted, filtered and summed as if it were data.
  CellValue? _cellOf({
    required OcptShotListXlsxColumn column,
    required OcptShot shot,
    required OcptShotSequence sequence,
    required OcptShotListXlsxLabels labels,
  }) => switch (column) {
    OcptShotListXlsxColumn.shot => TextCellValue(shot.code),
    OcptShotListXlsxColumn.characters => _textOrNull(shot.characters.join(", ")),
    OcptShotListXlsxColumn.set => _textOrNull(_setOf(sequence: sequence, shot: shot)),
    OcptShotListXlsxColumn.shotSize => _textOrNull(shot.shotSize),
    OcptShotListXlsxColumn.framing => _textOrNull(shot.framing),
    OcptShotListXlsxColumn.cameraMove => _textOrNull(shot.cameraMove),
    OcptShotListXlsxColumn.lens => _textOrNull(shot.lens),
    OcptShotListXlsxColumn.recordingFormat => _textOrNull(shot.recordingFormat),
    OcptShotListXlsxColumn.duration => _durationCellOf(shot.estimatedDurationMs),
    OcptShotListXlsxColumn.takes => switch (shot.plannedTakes) {
      final takes? => IntCellValue(takes),
      null => null,
    },
    OcptShotListXlsxColumn.sound => _textOrNull(shot.sound),
    OcptShotListXlsxColumn.difficulty => DoubleCellValue(shot.averageDifficulty),
    OcptShotListXlsxColumn.shootingDay => _textOrNull(shot.shootingDay),
    OcptShotListXlsxColumn.status => _textOrNull(labels.labelOf(shot.status)),
    OcptShotListXlsxColumn.notes => _textOrNull(shot.notes),
    OcptShotListXlsxColumn.locationNotes => _textOrNull(shot.locationNotes),
  };

  /// The set of [shot]: the heading of the scene [sequence] is built from, or the heading that
  /// scene had when it was deleted for a shot of the orphan group — a sequence *is* a screenplay
  /// scene, so its set is never stored on the shot itself.
  String? _setOf({required OcptShotSequence sequence, required OcptShot shot}) => switch (sequence) {
    OcptSceneShotSequence() => sequence.heading,
    OcptOrphanShotSequence() => shot.orphanedHeading,
  };

  /// The cell holding a shot's estimated duration [milliseconds], written `mm:ss` as the app shows
  /// it (both halves on two digits, so a column of durations reads as one column here too), or
  /// null while the shot has no estimate yet.
  ///
  /// Deliberately formatted here rather than through the shot list's own
  /// `ocptFormatShotDuration`: that one lives in the UI layer (which this service, sitting under
  /// the managers, must not depend on) and renders a placeholder dash for a missing duration,
  /// which is exactly what a spreadsheet cell must not carry.
  CellValue? _durationCellOf(int? milliseconds) {
    if (milliseconds == null) {
      return null;
    }

    final totalSeconds = (milliseconds / Duration.millisecondsPerSecond).round();
    final minutes = (totalSeconds ~/ Duration.secondsPerMinute).toString().padLeft(2, "0");
    final seconds = (totalSeconds % Duration.secondsPerMinute).toString().padLeft(2, "0");

    return TextCellValue("$minutes:$seconds");
  }

  /// A text cell holding [value], or null when it is null or holds nothing but whitespace.
  CellValue? _textOrNull(String? value) =>
      value == null || value.trim().isEmpty ? null : TextCellValue(value);
}
