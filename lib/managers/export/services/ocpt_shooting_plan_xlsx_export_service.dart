// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_plan_xlsx_column.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';

/// Renders the whole shoot's own shooting plan into the bytes of an XLSX workbook: the same four
/// summary grids `OcptShootingPlanPdfService` prints as landscape pages — `Locations`, `Sequences`,
/// `Crew and cast`, `Elements` — as one sheet each, plus a fifth, `Chronology`, one row per block
/// over the whole printed range in shooting order. The reference document *is* a spreadsheet the
/// production office reworks; a PDF cannot be.
///
/// The four grid sheets are built from [OcptShootingPlanGrids] (`lib/models/`), the very rows and
/// columns the PDF service already draws — never a second computation of them, which is exactly how
/// a printed plan and this workbook would come to disagree about what a production is doing on a
/// given day. Unlike the PDF's own landscape pages, a sheet is never chunked: [OcptShootingPlanGrids
/// .slotColumns]/`.dayColumns` are written whole, a spreadsheet running its columns on rather than
/// paying for a page break.
///
/// The `Chronology` sheet has no equivalent on the PDF at all: it reads
/// `ocptOrderedScheduleEntriesOfDay` — the very walk the call sheets, the shooting plan's own day
/// agendas and the one-line schedule already share — rather than a second walk of its own, one row
/// per block, every kind included (a shot as much as a meal break or a wrap). A day with no live
/// slot at all therefore writes no chronology row, that walk returning none for it.
///
/// This is pure in-memory workbook building with no I/O of its own (no dialog, no file system
/// access): it's owned by `OcptExportManager` and exposed as a public final field, reached through
/// the manager rather than through `globalGetIt()` (RFL18), exactly like `OcptBreakdownXlsxExportService`
/// and its own siblings. It takes no options: the export panel's card goes straight to the day
/// picker, that dialog's own days being this service's whole `dayIds`.
class OcptShootingPlanXlsxExportService {
  /// The sheet name used when the caller's own [OcptShootingPlanXlsxLabels.locationsSheetName] is
  /// blank.
  static const fallbackLocationsSheetName = "Locations";

  /// The sheet name used when the caller's own [OcptShootingPlanXlsxLabels.sequencesSheetName] is
  /// blank.
  static const fallbackSequencesSheetName = "Sequences";

  /// The sheet name used when the caller's own [OcptShootingPlanXlsxLabels.peopleSheetName] is
  /// blank.
  static const fallbackPeopleSheetName = "Crew and cast";

  /// The sheet name used when the caller's own [OcptShootingPlanXlsxLabels.elementsSheetName] is
  /// blank.
  static const fallbackElementsSheetName = "Elements";

  /// The sheet name used when the caller's own [OcptShootingPlanXlsxLabels.chronologySheetName] is
  /// blank.
  static const fallbackChronologySheetName = "Chronology";

  /// Class constructor
  const OcptShootingPlanXlsxExportService();

  /// The `.xlsx` file name to suggest when exporting the shooting plan of the project named
  /// [projectName], with [suffix] appended, mirroring
  /// `OcptResourcesXlsxExportService.xlsxFileName`.
  String xlsxFileName({required String projectName, required String suffix}) {
    final trimmedSuffix = suffix.trim();
    final extension = OcptShotListXlsxExportService.xlsxFileExtension;

    return trimmedSuffix.isEmpty
        ? "$projectName.$extension"
        : "$projectName - $trimmedSuffix.$extension";
  }

  /// Builds the workbook of [plan] over [dayIds], titled and headed with [labels], and returns its
  /// bytes.
  ///
  /// A [dayIds] entry naming no live day of [plan] is silently skipped, exactly as
  /// `OcptShootingPlanPdfService.generate` reads a missing one.
  ///
  /// **Shooting days only.** This document is about the shoot: a [dayIds] entry naming a day whose
  /// `OcptShootingDayKind` is not [OcptShootingDayKind.shoot] is skipped exactly as an entry naming
  /// no live day at all is. The scoping lives here rather than at the call site so every caller
  /// gets the same answer — the mode's own day picker offers the shooting days alone, and this is
  /// what makes that an agreement rather than a coincidence.
  ///
  /// Throws a [StateError] if the workbook cannot be encoded, which the caller reports as a failed
  /// export: `excel_community` returns null there rather than throwing anything of its own.
  Uint8List generate({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptShootingPlanXlsxLabels labels,
  }) {
    final resolvedDayIds = [
      for (final id in dayIds)
        if (plan.schedule.daysById[id]?.kind == OcptShootingDayKind.shoot) id,
    ];

    final excel = Excel.createExcel();
    final locationsSheetName = _sheetNameOr(labels.locationsSheetName, fallbackLocationsSheetName);
    _renameDefaultSheet(excel, locationsSheetName);

    final grids = OcptShootingPlanGrids.of(
      plan: plan,
      dayIds: resolvedDayIds,
      presenceMark: labels.presenceMark,
      persoLabel: labels.persoLabel,
      sequenceRowPrefix: labels.sequenceRowPrefix,
      emptyValue: ocptScheduleEmptyValue,
      crewPositionLabelById: labels.crewPositionLabels,
      elementCategoryLabels: labels.elementCategoryLabels,
    );

    _appendSlotGridSheet(
      sheet: excel[locationsSheetName],
      columns: grids.slotColumns,
      rows: grids.locationsRows,
      rowHeaderLabel: labels.locationsRowHeader,
      labels: labels,
    );
    _appendSlotGridSheet(
      sheet: excel[_sheetNameOr(labels.sequencesSheetName, fallbackSequencesSheetName)],
      columns: grids.slotColumns,
      rows: grids.sequencesRows,
      rowHeaderLabel: labels.sequencesRowHeader,
      labels: labels,
    );
    _appendSlotGridSheet(
      sheet: excel[_sheetNameOr(labels.peopleSheetName, fallbackPeopleSheetName)],
      columns: grids.slotColumns,
      rows: grids.peopleRows,
      rowHeaderLabel: labels.peopleRowHeader,
      labels: labels,
    );
    _appendElementsGridSheet(
      sheet: excel[_sheetNameOr(labels.elementsSheetName, fallbackElementsSheetName)],
      dayColumns: grids.dayColumns,
      rows: grids.elementsRows,
      rowHeaderLabel: labels.elementsRowHeader,
      labels: labels,
    );
    _appendChronologySheet(
      sheet: excel[_sheetNameOr(labels.chronologySheetName, fallbackChronologySheetName)],
      plan: plan,
      dayIds: resolvedDayIds,
      labels: labels,
    );

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError("The shooting plan workbook could not be encoded");
    }

    return Uint8List.fromList(bytes);
  }

  /// [name] if it holds anything other than whitespace, [fallback] otherwise.
  String _sheetNameOr(String name, String fallback) => name.trim().isEmpty ? fallback : name;

  /// Renames the sheet [Excel.createExcel] starts from to [sheetName], so the workbook doesn't end
  /// up with the named sheet plus an empty `Sheet1` next to it. A no-op when the default sheet
  /// already carries that name.
  void _renameDefaultSheet(Excel excel, String sheetName) {
    final defaultSheetName = excel.getDefaultSheet();
    if (defaultSheetName == null || defaultSheetName == sheetName) {
      return;
    }

    excel.rename(defaultSheetName, sheetName);
  }

  /// Emboldens every cell of row [rowIndex], from column 0 up to (but excluding) [columnCount].
  void _boldRow(Sheet sheet, int rowIndex, int columnCount) {
    for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle =
          CellStyle(bold: true);
    }
  }

  /// Writes one of the three slot-shaped summary grids (`Locations`, `Sequences`, `Crew and cast`)
  /// into [sheet]: a bold day-tag row (a day's tag printed once above the first of its own slot
  /// columns, mirroring `OcptShootingPlanPdfService._gridPage`'s own header), a bold slot-label row,
  /// then [rows] — a row's own [OcptShootingPlanGridRow.isIndented] read as a two-space indent on
  /// its label, since a spreadsheet cell has no visual indent of its own to reach for.
  void _appendSlotGridSheet({
    required Sheet sheet,
    required List<OcptShootingPlanGridColumn> columns,
    required List<OcptShootingPlanGridRow> rows,
    required String rowHeaderLabel,
    required OcptShootingPlanXlsxLabels labels,
  }) {
    sheet.appendRow([
      TextCellValue(""),
      for (final (index, column) in columns.indexed)
        TextCellValue(
          (index == 0 || columns[index - 1].dayId != column.dayId)
              ? "${labels.dayTagPrefix}${column.dayNumber}"
              : "",
        ),
    ]);
    _boldRow(sheet, sheet.maxRows - 1, columns.length + 1);

    sheet.appendRow([
      TextCellValue(rowHeaderLabel),
      for (final column in columns)
        TextCellValue(column.slotLabel.trim().isEmpty ? ocptScheduleEmptyValue : column.slotLabel.trim()),
    ]);
    _boldRow(sheet, sheet.maxRows - 1, columns.length + 1);

    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.isIndented ? "  ${row.label}" : row.label),
        for (final cell in row.cells) _textOrNull(cell),
      ]);
      if (row.isBold) {
        _boldRow(sheet, sheet.maxRows - 1, 1);
      }
    }
  }

  /// Writes the elements summary grid into [sheet]: a bold day header row (one column per
  /// [OcptShootingPlanGrids.dayColumns] entry, unlike the three slot-shaped grids' own two-row
  /// header, this grid having no second, slot-label row to draw), then [rows] — an
  /// [OcptShootingPlanElementsGridCategoryBand] as its own bold, single-cell row and an
  /// [OcptShootingPlanElementsGridElementRow] as an ordinary data row.
  void _appendElementsGridSheet({
    required Sheet sheet,
    required List<OcptShootingDay> dayColumns,
    required List<OcptShootingPlanElementsGridRow> rows,
    required String rowHeaderLabel,
    required OcptShootingPlanXlsxLabels labels,
  }) {
    sheet.appendRow([
      TextCellValue(rowHeaderLabel),
      for (final day in dayColumns) TextCellValue("${labels.dayTagPrefix}${day.dayNumber}"),
    ]);
    _boldRow(sheet, sheet.maxRows - 1, dayColumns.length + 1);

    for (final row in rows) {
      switch (row) {
        case OcptShootingPlanElementsGridCategoryBand():
          sheet.appendRow([TextCellValue(row.label)]);
          _boldRow(sheet, sheet.maxRows - 1, 1);
        case OcptShootingPlanElementsGridElementRow():
          sheet.appendRow([
            TextCellValue(row.label),
            for (final cell in row.cells) _textOrNull(cell),
          ]);
      }
    }
  }

  /// Writes the `Chronology` sheet into [sheet]: one header row, then one row per block of every
  /// live day of [dayIds], in the order given, each day's own blocks in shooting order
  /// (`ocptOrderedScheduleEntriesOfDay`) — see the class doc comment for why that walk is read
  /// rather than reimplemented, and for why a day with no live slot at all contributes no row.
  void _appendChronologySheet({
    required Sheet sheet,
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptShootingPlanXlsxLabels labels,
  }) {
    _appendHeaderRow(sheet, OcptShootingPlanXlsxColumn.values, labels.chronologyHeaderOf);

    for (final dayId in dayIds) {
      final day = plan.schedule.daysById[dayId];
      if (day == null) {
        continue;
      }
      for (final ordered in ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: dayId)) {
        sheet.appendRow([
          for (final column in OcptShootingPlanXlsxColumn.values)
            _chronologyCellOf(column: column, day: day, ordered: ordered, plan: plan, labels: labels),
        ]);
      }
    }
  }

  /// Appends [sheet]'s single header row, one cell per value of [columns], and emboldens it —
  /// mirrors `OcptBreakdownXlsxExportService._appendHeaderRow`.
  void _appendHeaderRow<T>(Sheet sheet, List<T> columns, String Function(T column) headerOf) {
    final headerRowIndex = sheet.maxRows;
    sheet.appendRow([for (final column in columns) TextCellValue(headerOf(column))]);
    _boldRow(sheet, headerRowIndex, columns.length);
  }

  /// The cell [column] holds for [ordered]'s own row of the `Chronology` sheet, scoped to [day].
  CellValue? _chronologyCellOf({
    required OcptShootingPlanXlsxColumn column,
    required OcptShootingDay day,
    required OcptOrderedScheduleEntry ordered,
    required OcptSchedulePlanSnapshot plan,
    required OcptShootingPlanXlsxLabels labels,
  }) {
    final block = ordered.block;
    return switch (column) {
      OcptShootingPlanXlsxColumn.dayTag => TextCellValue("${labels.dayTagPrefix}${day.dayNumber}"),
      OcptShootingPlanXlsxColumn.date => DateCellValue.fromDateTime(day.date),
      OcptShootingPlanXlsxColumn.slot => _textOrNull(ordered.slot.label),
      OcptShootingPlanXlsxColumn.start => TextCellValue(ocptFormatDayMinute(ordered.entry.startMinute)),
      OcptShootingPlanXlsxColumn.end => TextCellValue(ocptFormatDayMinute(ordered.entry.endMinute)),
      OcptShootingPlanXlsxColumn.kind => _textOrNull(labels.blockKindLabelOf(block.kind)),
      OcptShootingPlanXlsxColumn.shot => _textOrNull(_shotCodeOf(block, plan)),
      OcptShootingPlanXlsxColumn.sequence => _textOrNull(_sequenceHeadingOf(block, plan)),
      OcptShootingPlanXlsxColumn.set => _textOrNull(_setNameOf(ordered.slot, plan)),
      OcptShootingPlanXlsxColumn.roles => _textOrNull(_rolesOf(block, plan)),
      OcptShootingPlanXlsxColumn.durationMinutes => IntCellValue(ordered.entry.endMinute - ordered.entry.startMinute),
      OcptShootingPlanXlsxColumn.crewNote => _textOrNull(block.crewNote),
    };
  }

  /// [block]'s own shot's code, or null while [block] is not a [OcptShootingBlockKind.shot] one, or
  /// names a shot [plan] no longer holds.
  String? _shotCodeOf(OcptShootingDayBlock block, OcptSchedulePlanSnapshot plan) {
    if (block.kind != OcptShootingBlockKind.shot || block.shotId == null) {
      return null;
    }
    return plan.shotById(block.shotId!)?.code;
  }

  /// The heading of the sequence [block] concerns: a [OcptShootingBlockKind.shot] block's own
  /// shot's scene, a [OcptShootingBlockKind.hold] block's own [OcptShootingDayBlock.sceneId] — the
  /// column [ocptScheduleBlockCaptionOf] itself reads for a hold's own caption — or null for every
  /// other kind, which concerns no sequence at all.
  String? _sequenceHeadingOf(OcptShootingDayBlock block, OcptSchedulePlanSnapshot plan) {
    final sceneId = switch (block.kind) {
      OcptShootingBlockKind.shot => block.shotId == null ? null : plan.shotById(block.shotId!)?.sceneId,
      OcptShootingBlockKind.hold => block.sceneId,
      _ => null,
    };
    return sceneId == null ? null : plan.headingBySceneId[sceneId];
  }

  /// [slot]'s own set name, or null while it names none.
  String? _setNameOf(OcptShootingSlot slot, OcptSchedulePlanSnapshot plan) {
    final setId = slot.setId;
    return setId == null ? null : plan.setById[setId]?.name;
  }

  /// The role names of every one of [block]'s own shot's `characters` matched against
  /// [plan]'s own roles (through `normalizeCharacterName`, the same join
  /// `OcptShootingPlanPdfService._roleNamesOf` uses for the day agenda's own `Perso.` column), or
  /// null for a block that is not a [OcptShootingBlockKind.shot] one or matches no role at all.
  String? _rolesOf(OcptShootingDayBlock block, OcptSchedulePlanSnapshot plan) {
    if (block.kind != OcptShootingBlockKind.shot || block.shotId == null) {
      return null;
    }
    final shot = plan.shotById(block.shotId!);
    if (shot == null) {
      return null;
    }

    final byNormalizedName = {for (final role in plan.roles) normalizeCharacterName(role.name): role};
    final matched = <String>{};
    for (final name in shot.characters) {
      if (byNormalizedName[name] case final role?) {
        matched.add(role.name);
      }
    }
    if (matched.isEmpty) {
      return null;
    }
    final sorted = matched.toList()..sort();
    return sorted.join(", ");
  }

  /// A text cell holding [value], or null when it is null or holds nothing but whitespace.
  CellValue? _textOrNull(String? value) =>
      value == null || value.trim().isEmpty ? null : TextCellValue(value);
}
