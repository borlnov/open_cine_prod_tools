// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_day_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_page_parts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_style.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_elements_grid_row.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grid_column.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grid_row.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:pdf/widgets.dart' as pw;

/// The shooting plan's day-by-column grid pages and the elements grid pages that follow them.
///
/// Stateless page builders over a page painter.
abstract final class OcptShootingPlanGridSections {
  // ---------------------------------------------------------------------------------------------
  // Summary grids
  // ---------------------------------------------------------------------------------------------

  /// Add one landscape page per chunk of [chunks] to [pdfDocument], each carrying every one of
  /// [rows] over that chunk's own columns — or a single note page when [chunks] or [rows] is empty
  /// (no slot anywhere in the printed range, or nothing this grid's own kind has to say about it).
  static void addGridPages({
    required pw.Document pdfDocument,
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required String title,
    required String rowHeaderLabel,
    required List<List<OcptShootingPlanGridColumn>> chunks,
    required List<OcptShootingPlanGridRow> rows,
  }) {
    if (chunks.isEmpty || rows.isEmpty) {
      pdfDocument.addPage(
        gridNotePage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          title: title,
        ),
      );
      return;
    }

    for (final (chunkIndex, chunk) in chunks.indexed) {
      pdfDocument.addPage(
        gridPage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          pageTitle: chunks.length > 1 ? "$title (${chunkIndex + 1}/${chunks.length})" : title,
          rowHeaderLabel: rowHeaderLabel,
          columns: chunk,
          chunkStartIndex: chunkIndex * ocptShootingPlanMaxGridColumnsPerPage,
          rows: rows,
        ),
      );
    }
  }

  /// Build a landscape note page for a grid with nothing to show.
  static pw.MultiPage gridNotePage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required String title,
  }) => pw.MultiPage(
    pageFormat: OcptShootingPlanPageParts.landscapePageFormat(painter),
    header: (context) => OcptShootingPlanPageParts.runningHead(
      painter: painter,
      projectName: projectName,
      documentTitle: labels.documentTitle,
      versionLine: versionLine,
    ),
    build: (context) => [
      pw.SizedBox(height: 6),
      pw.Text(
        title,
        style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptShootingPlanTitleFontSizePt),
      ),
      pw.SizedBox(height: 8),
      OcptShootingPlanPageParts.noteWidget(painter: painter, text: labels.emptyPlanNote),
    ],
  );

  /// Build one landscape grid page: the running head, the grid's own title, then its table — a day
  /// band
  /// row (the day tag printed once above the first of its own slot columns), a slot-label row, then
  /// [rows].
  static pw.MultiPage gridPage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required String pageTitle,
    required String rowHeaderLabel,
    required List<OcptShootingPlanGridColumn> columns,
    required int chunkStartIndex,
    required List<OcptShootingPlanGridRow> rows,
  }) {
    final columnWidths = <int, pw.TableColumnWidth>{0: const pw.FlexColumnWidth(2.4)};
    for (var index = 0; index < columns.length; index++) {
      columnWidths[index + 1] = const pw.FlexColumnWidth();
    }

    return pw.MultiPage(
      pageFormat: OcptShootingPlanPageParts.landscapePageFormat(painter),
      header: (context) => OcptShootingPlanPageParts.runningHead(
        painter: painter,
        projectName: projectName,
        documentTitle: labels.documentTitle,
        versionLine: versionLine,
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        pw.Text(
          pageTitle,
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptShootingPlanTitleFontSizePt),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: ocptShootingPlanRuleColor, width: 0.5),
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: ocptShootingPlanBandColor),
              children: [
                gridCornerCell(painter: painter),
                for (final (index, column) in columns.indexed)
                  gridHeaderCell(
                    painter: painter,
                    text: (index == 0 || columns[index - 1].dayId != column.dayId)
                        ? "${labels.dayTagPrefix}${column.dayNumber}"
                        : "",
                  ),
              ],
            ),
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: ocptShootingPlanBandColor),
              children: [
                gridRowLabelCell(painter: painter, text: rowHeaderLabel, isBold: true),
                for (final column in columns)
                  gridHeaderCell(
                    painter: painter,
                    text: column.slotLabel.trim().isEmpty
                        ? ocptScheduleEmptyValue
                        : column.slotLabel.trim(),
                  ),
              ],
            ),
            for (final row in rows)
              pw.TableRow(
                children: [
                  gridRowLabelCell(
                    painter: painter,
                    text: row.label,
                    isBold: row.isBold,
                    isIndented: row.isIndented,
                  ),
                  for (final (index, _) in columns.indexed)
                    gridDataCell(
                      painter: painter,
                      text: row.cells[chunkStartIndex + index],
                      isMuted: row.isMuted,
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// Build a grid's own blank cell — the top-left corner of a header row, or one of a category band
  /// row's
  /// own trailing cells, which carry no per-column value (the elements grid's own band rows).
  static pw.Widget gridCornerCell({required OcptScriptPagePainter painter}) => pw.Padding(
    padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
    child: pw.SizedBox(),
  );

  /// Build a grid's own header cell (a day tag, a slot's own label).
  static pw.Widget gridHeaderCell({required OcptScriptPagePainter painter, required String text}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptShootingPlanSmallFontSizePt),
        ),
      );

  /// Build a grid row's own leading label cell — indented and muted for a locations grid's own
  /// nested
  /// `Perso.` row.
  static pw.Widget gridRowLabelCell({
    required OcptScriptPagePainter painter,
    required String text,
    bool isBold = false,
    bool isIndented = false,
  }) => pw.Padding(
    padding: pw.EdgeInsets.only(
      left: isIndented ? ocptShootingPlanCellPaddingPt * 3 : ocptShootingPlanCellPaddingPt,
      top: ocptShootingPlanCellPaddingPt,
      right: ocptShootingPlanCellPaddingPt,
      bottom: ocptShootingPlanCellPaddingPt,
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: painter.fonts.variant(bold: isBold, italic: isIndented),
        fontSize: ocptShootingPlanBodyFontSizePt,
        color: isIndented ? ocptShootingPlanMutedColor : null,
      ),
    ),
  );

  /// Build one grid data cell. Deliberately **not** [OcptShootingPlanPageParts.textCell]: a blank
  /// cell
  /// here means "not applicable to this column" (a location's row against a slot shot somewhere
  /// else, an element's row against a day it is not needed on), not a missing value, so it prints
  /// truly empty rather than substituting [ocptScheduleEmptyValue].
  static pw.Widget gridDataCell({
    required OcptScriptPagePainter painter,
    required String text,
    bool isMuted = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        font: painter.fonts.regular,
        fontSize: ocptShootingPlanSmallFontSizePt,
        color: isMuted ? ocptShootingPlanMutedColor : null,
      ),
    ),
  );

  /// Add one landscape page per chunk of [chunks] to [pdfDocument], each carrying every one of
  /// [rows] over that chunk's own day columns — or a single note page when [chunks] or [rows] is
  /// empty. Mirrors [addGridPages] over [OcptShootingDay] columns rather than
  /// [OcptShootingPlanGridColumn] ones: the elements grid's own columns are days, not slots, so it
  /// is its own page-building method rather than a second call through [gridPage], which draws a
  /// second, slot-label header row this grid has none of.
  static void addElementsGridPages({
    required pw.Document pdfDocument,
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required List<List<OcptShootingDay>> chunks,
    required List<OcptShootingPlanElementsGridRow> rows,
  }) {
    if (chunks.isEmpty || rows.isEmpty) {
      pdfDocument.addPage(
        gridNotePage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          title: labels.elementsGridTitle,
        ),
      );
      return;
    }

    for (final (chunkIndex, chunk) in chunks.indexed) {
      pdfDocument.addPage(
        elementsGridPage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          pageTitle: chunks.length > 1
              ? "${labels.elementsGridTitle} (${chunkIndex + 1}/${chunks.length})"
              : labels.elementsGridTitle,
          columns: chunk,
          chunkStartIndex: chunkIndex * ocptShootingPlanMaxGridColumnsPerPage,
          rows: rows,
        ),
      );
    }
  }

  /// Build one landscape elements-grid page: the running head, the grid's own title, then its table
  /// — a
  /// single header row (the day tag over each column, unlike [gridPage]'s own two: **the elements
  /// grid's own columns are days, not slots**, so there is no second, slot-label row to draw), then
  /// [rows] — an [OcptShootingPlanElementsGridCategoryBand] painted as its own full band row and an
  /// [OcptShootingPlanElementsGridElementRow] as an ordinary data row.
  ///
  /// **Only the day header repeats across a page break, not a category band.** `pw.TableRow.repeat`
  /// redraws *every* row it marks at the top of *every* page the table spans — right for a fixed
  /// header meant once, wrong for a band that recurs once per category: a table several categories
  /// deep would stack every category seen so far atop a continuation page rather than only the one
  /// a reader is actually looking at, which is a worse lie than the one being fixed. Making only
  /// the *current* band follow the break would need this table built row by row like
  /// [OcptShootingPlanDaySections.dayTimetableWidgets] rather than handed whole to `pw.Table`, for
  /// a document that already names every row's own element (`<code> · <name>`,
  /// [OcptShootingPlanElementsGridElementRow.label]) whether or not its category is still in view —
  /// a reader who has lost the band can still read the row, which is not true of a column with no
  /// header at all.
  static pw.MultiPage elementsGridPage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required String pageTitle,
    required List<OcptShootingDay> columns,
    required int chunkStartIndex,
    required List<OcptShootingPlanElementsGridRow> rows,
  }) {
    final columnWidths = <int, pw.TableColumnWidth>{0: const pw.FlexColumnWidth(2.4)};
    for (var index = 0; index < columns.length; index++) {
      columnWidths[index + 1] = const pw.FlexColumnWidth();
    }

    return pw.MultiPage(
      pageFormat: OcptShootingPlanPageParts.landscapePageFormat(painter),
      header: (context) => OcptShootingPlanPageParts.runningHead(
        painter: painter,
        projectName: projectName,
        documentTitle: labels.documentTitle,
        versionLine: versionLine,
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        pw.Text(
          pageTitle,
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptShootingPlanTitleFontSizePt),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: ocptShootingPlanRuleColor, width: 0.5),
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: ocptShootingPlanBandColor),
              children: [
                gridRowLabelCell(
                  painter: painter,
                  text: labels.elementsGridRowHeader,
                  isBold: true,
                ),
                for (final day in columns)
                  gridHeaderCell(painter: painter, text: "${labels.dayTagPrefix}${day.dayNumber}"),
              ],
            ),
            for (final row in rows)
              switch (row) {
                OcptShootingPlanElementsGridCategoryBand() => pw.TableRow(
                  decoration: const pw.BoxDecoration(color: ocptShootingPlanBandColor),
                  children: [
                    gridRowLabelCell(painter: painter, text: row.label, isBold: true),
                    for (final _ in columns) gridCornerCell(painter: painter),
                  ],
                ),
                OcptShootingPlanElementsGridElementRow() => pw.TableRow(
                  children: [
                    gridRowLabelCell(painter: painter, text: row.label),
                    for (final (index, _) in columns.indexed)
                      gridDataCell(painter: painter, text: row.cells[chunkStartIndex + index]),
                  ],
                ),
              },
          ],
        ),
      ],
    );
  }
}
