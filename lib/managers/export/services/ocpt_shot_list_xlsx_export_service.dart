// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
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
  /// [projectName]. [episodeTag] is the selected episode's own tag, present only while the open
  /// project holds more than one episode — see `ocptExportFileNameOf`'s own doc comment.
  String xlsxFileName({required String projectName, String? episodeTag}) => ocptExportFileNameOf(
    projectName: projectName,
    episodeTag: episodeTag,
    extension: xlsxFileExtension,
  );

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
      _appendSequenceRows(
        sheet: sheet,
        sequence: sequence,
        labels: labels,
        placementsByShotId: snapshot.placementsByShotId,
      );
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

  /// Appends [sequence]'s separator row, then one row per shot it holds. [placementsByShotId] is
  /// [OcptShotListSnapshot.placementsByShotId], keyed by shot id onto every block that places it.
  void _appendSequenceRows({
    required Sheet sheet,
    required OcptShotSequence sequence,
    required OcptShotListXlsxLabels labels,
    required Map<String, List<OcptShotPlacement>> placementsByShotId,
  }) {
    final separatorRowIndex = sheet.maxRows;
    sheet.appendRow([TextCellValue(labels.titleOfSequence(sequence.id))]);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: separatorRowIndex))
        .cellStyle = CellStyle(bold: true);

    for (final shot in sequence.shots) {
      sheet.appendRow([
        for (final column in OcptShotListXlsxColumn.values)
          _cellOf(
            column: column,
            shot: shot,
            sequence: sequence,
            labels: labels,
            placements: placementsByShotId[shot.id] ?? const [],
          ),
      ]);
    }
  }

  /// The cell [column] holds for [shot], or null to leave it empty. [placements] is [shot]'s own
  /// entry of [OcptShotListSnapshot.placementsByShotId], empty while it hasn't been placed on any
  /// day yet.
  ///
  /// A field the user hasn't filled in is written as an empty cell rather than as the em dash the
  /// table shows in its place: a spreadsheet's own way of saying "nothing here" is a blank cell,
  /// and a dash would be sorted, filtered and summed as if it were data.
  CellValue? _cellOf({
    required OcptShotListXlsxColumn column,
    required OcptShot shot,
    required OcptShotSequence sequence,
    required OcptShotListXlsxLabels labels,
    required List<OcptShotPlacement> placements,
  }) => switch (column) {
    OcptShotListXlsxColumn.shot => TextCellValue(shot.code),
    OcptShotListXlsxColumn.characters => _textOrNull(shot.characters.join(", ")),
    OcptShotListXlsxColumn.set => _textOrNull(_setOf(sequence: sequence, shot: shot)),
    OcptShotListXlsxColumn.shotSize => _textOrNull(shot.shotSize),
    OcptShotListXlsxColumn.abbreviation => _textOrNull(shot.abbreviation),
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
    OcptShotListXlsxColumn.shootingDay => _placementCellOf(placements, labels: labels),
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

  /// The cell holding [placements]'s read-out — mirroring `ocptShotPlacementLabel` for a caller with
  /// no `BuildContext`: `D3 · 2026-08-04` (the day's printed rank then its calendar date) when every
  /// placement lands on the same day, the day tags alone joined with `, ` (`D3, D5`) when they don't,
  /// or null for a shot the schedule carries no placement for at all — exactly like any other field
  /// the user hasn't filled in ([_textOrNull]). Days are deduplicated by `OcptShotPlacement.dayId`
  /// and kept in ascending **date** order, exactly as `ocptShotPlacementLabel` does — a day's number
  /// ranks it among its own kind alone, so ordering by it would interleave a `C1` between two
  /// shooting days.
  ///
  /// The day tag's own letter is [labels]' own `dayTagPrefixes` entry **for that day's kind**,
  /// resolved by the caller from `Tr` since this service has none of its own — the paperwork a crew
  /// reads follows the app's language, letter included. The date half stays locale-free: a spreadsheet cell with no `Tr` to
  /// format a date with is exactly the situation `yyyy-MM-dd` already serves elsewhere in this
  /// codebase (`OcptResourcesXlsxExportService._isoDate`), inlined here rather than imported since
  /// the service layer this class sits in must not depend on the UI layer that helper lives in.
  CellValue? _placementCellOf(List<OcptShotPlacement> placements, {required OcptShotListXlsxLabels labels}) {
    if (placements.isEmpty) {
      return null;
    }

    final distinctDays = <String, OcptShotPlacement>{};
    for (final placement in placements) {
      distinctDays[placement.dayId] = placement;
    }
    final orderedDays = distinctDays.values.toList()..sort((a, b) => a.date.compareTo(b.date));

    if (orderedDays.length == 1) {
      final placement = orderedDays.single;
      return TextCellValue(
        "${labels.dayTagPrefixOf(placement.dayKind)}${placement.dayNumber} · "
        "${_isoDate(placement.date)}",
      );
    }

    return TextCellValue(
      orderedDays
          .map(
            (placement) => "${labels.dayTagPrefixOf(placement.dayKind)}${placement.dayNumber}",
          )
          .join(", "),
    );
  }

  /// [date] as `yyyy-MM-dd`, mirroring `OcptResourcesXlsxExportService._isoDate`.
  String _isoDate(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-"
      "${date.day.toString().padLeft(2, '0')}";
}
