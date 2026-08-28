// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of a page's own big title (a day's own heading, a grid's own title).
const double _titleFontSizePt = 16;

/// The font size, in points, of the title page's own document name.
const double _coverTitleFontSizePt = 24;

/// The font size, in points, of every body line: a section's own note, a table cell.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, a section title, a grid's
/// own column headers.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of a table or a grid.
const double _cellPaddingPt = 4;

/// The colour of the rules a table's and a grid's own borders are drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's header row and of a grid's own header band.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The colour of the ten-minute grid's own horizontal rule, one per row, lighter than [_ruleColor]
/// so it reads as a reading aid behind the tiles rather than as a border of its own.
const PdfColor _gridRowRuleColor = PdfColor.fromInt(0xFFDCDCDC);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// How many columns one page of a summary grid holds before the rest carries on, chunked, onto the
/// next one — a slot column for three of the four grids, a day column for the elements one — a grid
/// silently printing only its first few days is worse than one that runs on.
const int _maxGridColumnsPerPage = 6;

/// A shot table's `Hours / Plan / Valeur de plan / Move. / Cadre / Commentaire / Perso.` columns —
/// see [OcptShootingPlanLabels.framingHeader]'s own doc comment for why the reference document's
/// own `Description` column has no counterpart here, and [OcptShootingPlanLabels.hoursHeader]'s own
/// for why the reference document's `Hours` column, absent there, leads this one.
const Map<int, pw.TableColumnWidth> _shotColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(),
  2: pw.FlexColumnWidth(1.6),
  3: pw.FlexColumnWidth(1.4),
  4: pw.FlexColumnWidth(1.8),
  5: pw.FlexColumnWidth(2.4),
  6: pw.FlexColumnWidth(1.6),
};

/// A day agenda's own trailing guest table's `NOM / MOTIF / HORAIRES` columns — the same shape
/// `OcptCallSheetPdfService`'s own `_guestColumnWidths` already gives a day's guests, wider on the
/// reason column than the name and hours ones since a guest's own reason is prose.
const Map<int, pw.TableColumnWidth> _guestColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(2.4),
  2: pw.FlexColumnWidth(1.2),
};

/// Renders the whole shoot's own shooting plan: an optional title page, the four summary grids —
/// locations, sequences, crew and cast, each crossing every printed day's own slots, and the
/// elements grid crossing every printed **day** instead — and then one detailed agenda per day, hour
/// by hour.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings — `OcptCallSheetPdfService` chief
/// among them, whose own doc comment this one mirrors. It prints no screenplay, so it draws nothing
/// through [OcptScriptPagePainter]'s absolutely positioned page builders and flows its content in
/// [pw.MultiPage]s instead, exactly as `OcptCallSheetPdfService` and `OcptBreakdownSheetsPdfService`
/// do; it still takes one painter, for the page geometry every export of this app measures a sheet
/// with and the Courier Prime variants all of them print in.
///
/// **Every hour printed comes off [OcptSchedulePlanSnapshot.timelinesOfDay]'s resolved clocks** —
/// never off a stored anchor, never re-derived. A minute may exceed 1440 for a night shoot's small
/// hours, and every figure is printed through `ocptFormatDayMinute`, the one place that ever wraps
/// one back onto a clock face — the same rule `OcptCallSheetPdfService` follows, and the reason the
/// two share `ocpt_schedule_pdf_shared.dart` rather than each reading the schedule its own way. A
/// day agenda's own shot table leads with an **hours column**, the one column the reference
/// document's own table carries no equivalent of, reading the same resolved clock a shot's block was
/// placed on.
///
/// **The day's own events, guests and a block's own crew note** — schema v17's three additions —
/// are printed here too, following `OcptCallSheetPdfService`'s own reading of them rather than a
/// second one invented for this document: the events section sits beside the day's own hours
/// section (an event is a fact about the day, taking part in no chain), the guest table trails the
/// timetable exactly as it trails the call sheet's own cast-and-extras list, and a block's own
/// [OcptShootingDayBlock.crewNote] prints under its own row — inline on a milestone's already
/// full-width line, and as its own band under a shot run, since a `pw.Table` row cannot itself span
/// the page width the note deserves. All three are skipped entirely on a day that carries none,
/// rather than drawn over an em dash.
///
/// **The four summary grids are landscape** (page width and height swapped from the painter's own
/// geometry): a shoot is wide, and a grid silently cropped to whatever a portrait page holds would
/// be worse than one that runs the columns on. The locations, sequences and crew-and-cast grids'
/// own columns are **one per slot, grouped under its day** — a decision already taken
/// (`docs/architecture/schedule.md`): the reference document's own day-parts are exactly what a
/// slot is in this app. When more columns exist than [_maxGridColumnsPerPage] holds, a grid's own
/// rows repeat over as many chunked pages as it takes; the detailed day agendas that follow stay
/// portrait, so one document mixes both orientations.
///
/// **The elements grid's own columns are one per day instead**, never per slot: an element is
/// needed on a day or it is not, and which of that day's own units carries it is not something this
/// app's data says. Its rows are grouped under an `OcptElementCategory` band — the reference
/// `.xlsx`'s own `ANIMAUX`/`VÉHICULES`/`ÉQUIPEMENTS SPÉCIAUX` bands — in the enum's own declaration
/// order and **never by `OcptCrewDepartment`**: that type has six entries against the element
/// category's fourteen, and a mapping between the two would be this app's own opinion about how a
/// production organises itself, which no field of the schema states. A cell is
/// [OcptShootingPlanLabels.presenceMark] or blank, **never a quantity summed across that day's own
/// scenes**: `scene_elements.quantity` is carried per scene link, so the same coat appearing in
/// three scenes of one day is one coat on set, and a total would be a figure this app invented
/// rather than read off the schedule. [_chunkColumns] paginates it by the very same rule the other
/// three grids use, over its own day columns rather than slot ones, so [_maxGridColumnsPerPage]
/// never means two different things depending on which grid asks.
///
/// **Each day's own ten-minute grid** (`includeTenMinuteGrid` on [generate]) is an optional extra
/// page, added right after that day's detailed agenda rather than replacing it: rows every
/// [OcptShootingDayAgendaGrid.stepMinutes] from the day's earliest resolved start to its latest
/// resolved end, one column per slot, a block drawn as a tile and an event as a full-width marker.
/// It is drawn **portrait**, unlike the four summary grids — a whole shoot's own slots run wide
/// across many days, while a single day's own slots are few, exactly the trade this class's own
/// grids paragraphs already argue the other way. The geometry is entirely
/// [OcptShootingDayAgendaGrid.of]'s own; this service only draws it, and only the drawing choices
/// specific to `pdf`'s own `Table` widget belong here — see [_tenMinuteGridPage]'s own doc comment
/// for the one it has to work around (no cell can span more than one row of a `pw.Table`).
class OcptShootingPlanPdfService {
  /// Creates an [OcptShootingPlanPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptShootingPlanPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the shooting plan of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - shooting plan.pdf`); a blank one falls back to the project name alone, exactly as
  /// `OcptBreakdownSheetsPdfService.sheetsFileName` does.
  String shootingPlanFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the shooting plan of [dayIds] (in the order given), returning the PDF's bytes.
  ///
  /// A [dayIds] entry naming no live day of [plan] is silently skipped, exactly as
  /// `OcptCallSheetPdfService` reads a missing day: nothing this app writes can produce one, but a
  /// hand-edited file or a stale selection might. A [dayIds] list resolving to no live day at all
  /// still produces a readable, one-note document (plus its title page, when [includeTitlePage]
  /// asks for one) rather than an empty file nobody can open.
  ///
  /// [exportDate] is the moment the title page's own version line and every page's running head
  /// print (`Version 2026-08-08 14:32`, through [ocptScheduleGeneratedAtStamp], the stamp
  /// `OcptCallSheetPdfService` prints too); it defaults to the moment this method runs, and is
  /// exposed so a test can pin it rather than racing a midnight rollover. It is resolved **once**
  /// per document, so a plan whose rendering straddles a minute boundary still names one issue of
  /// itself on every one of its pages.
  Future<Uint8List> generate({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required bool includeLocationsGrid,
    required bool includeSequencesGrid,
    required bool includePeopleGrid,
    required bool includeTenMinuteGrid,
    required bool includeElementsGrid,
    DateTime? exportDate,
  }) async {
    final painter = await _painterFor(pageSetup);
    final pdfDocument = pw.Document();
    final versionLine = "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";

    final resolvedDayIds = [for (final id in dayIds) if (plan.schedule.daysById.containsKey(id)) id];

    if (includeTitlePage) {
      pdfDocument.addPage(
        _titlePage(painter: painter, labels: labels, projectName: projectName, versionLine: versionLine),
      );
    }

    if (resolvedDayIds.isEmpty) {
      pdfDocument.addPage(
        _notePage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          text: labels.emptyPlanNote,
        ),
      );
      return pdfDocument.save();
    }

    final headingBySceneId = ocptScheduleHeadingBySceneId(plan);
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
    final chunks = _chunkColumns(grids.slotColumns, _maxGridColumnsPerPage);

    if (includeLocationsGrid) {
      _addGridPages(
        pdfDocument: pdfDocument,
        painter: painter,
        labels: labels,
        projectName: projectName,
        versionLine: versionLine,
        title: labels.locationsGridTitle,
        rowHeaderLabel: labels.locationsGridRowHeader,
        chunks: chunks,
        rows: grids.locationsRows,
      );
    }
    if (includeSequencesGrid) {
      _addGridPages(
        pdfDocument: pdfDocument,
        painter: painter,
        labels: labels,
        projectName: projectName,
        versionLine: versionLine,
        title: labels.sequencesGridTitle,
        rowHeaderLabel: labels.sequencesGridRowHeader,
        chunks: chunks,
        rows: grids.sequencesRows,
      );
    }
    if (includePeopleGrid) {
      _addGridPages(
        pdfDocument: pdfDocument,
        painter: painter,
        labels: labels,
        projectName: projectName,
        versionLine: versionLine,
        title: labels.peopleGridTitle,
        rowHeaderLabel: labels.peopleGridRowHeader,
        chunks: chunks,
        rows: grids.peopleRows,
      );
    }
    if (includeElementsGrid) {
      _addElementsGridPages(
        pdfDocument: pdfDocument,
        painter: painter,
        labels: labels,
        projectName: projectName,
        versionLine: versionLine,
        chunks: _chunkColumns(grids.dayColumns, _maxGridColumnsPerPage),
        rows: grids.elementsRows,
      );
    }

    for (final dayId in resolvedDayIds) {
      pdfDocument.addPage(
        _dayAgendaPage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          plan: plan,
          dayId: dayId,
          headingBySceneId: headingBySceneId,
        ),
      );
      if (includeTenMinuteGrid) {
        pdfDocument.addPage(
          _tenMinuteGridPage(
            painter: painter,
            labels: labels,
            projectName: projectName,
            versionLine: versionLine,
            plan: plan,
            dayId: dayId,
            headingBySceneId: headingBySceneId,
          ),
        );
      }
    }

    return pdfDocument.save();
  }

  /// The [OcptScriptPagePainter] every page is drawn through, sharing this session's font cache.
  Future<OcptScriptPagePainter> _painterFor(OcptPageSetup pageSetup) async =>
      OcptScriptPagePainter(metrics: pageSetup.toMetrics(), fonts: await fontsLoader.load());

  // ---------------------------------------------------------------------------------------------
  // Title page and empty-document note
  // ---------------------------------------------------------------------------------------------

  /// The document's own title page: its name, the `"<title>" de <director>` line, and the date the
  /// export was run.
  pw.Page _titlePage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
  }) => pw.Page(
    pageFormat: _portraitPageFormat(painter),
    build: (context) => pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            labels.documentTitle,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: _coverTitleFontSizePt),
          ),
          if (labels.directorLine.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              labels.directorLine,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
            ),
          ],
          pw.SizedBox(height: 32),
          pw.Text(
            versionLine,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
      ),
    ),
  );

  /// A single-note portrait page: the running head, then [text] alone — what a range with no live
  /// day at all, or an empty grid, prints in place of its own content.
  pw.MultiPage _notePage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required String text,
  }) => pw.MultiPage(
    pageFormat: _portraitPageFormat(painter),
    header: (context) => _runningHead(
      painter: painter,
      projectName: projectName,
      documentTitle: labels.documentTitle,
      versionLine: versionLine,
    ),
    build: (context) => [
      pw.SizedBox(height: 6),
      _noteWidget(painter: painter, text: text),
    ],
  );

  // ---------------------------------------------------------------------------------------------
  // Summary grids
  // ---------------------------------------------------------------------------------------------

  /// Adds one landscape page per chunk of [chunks] to [pdfDocument], each carrying every one of
  /// [rows] over that chunk's own columns — or a single note page when [chunks] or [rows] is empty
  /// (no slot anywhere in the printed range, or nothing this grid's own kind has to say about it).
  void _addGridPages({
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
        _gridNotePage(
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
        _gridPage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          pageTitle: chunks.length > 1 ? "$title (${chunkIndex + 1}/${chunks.length})" : title,
          rowHeaderLabel: rowHeaderLabel,
          columns: chunk,
          chunkStartIndex: chunkIndex * _maxGridColumnsPerPage,
          rows: rows,
        ),
      );
    }
  }

  /// A landscape note page for a grid with nothing to show.
  pw.MultiPage _gridNotePage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required String title,
  }) => pw.MultiPage(
    pageFormat: _landscapePageFormat(painter),
    header: (context) => _runningHead(
      painter: painter,
      projectName: projectName,
      documentTitle: labels.documentTitle,
      versionLine: versionLine,
    ),
    build: (context) => [
      pw.SizedBox(height: 6),
      pw.Text(title, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt)),
      pw.SizedBox(height: 8),
      _noteWidget(painter: painter, text: labels.emptyPlanNote),
    ],
  );

  /// One landscape grid page: the running head, the grid's own title, then its table — a day band
  /// row (the day tag printed once above the first of its own slot columns), a slot-label row, then
  /// [rows].
  pw.MultiPage _gridPage({
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
      pageFormat: _landscapePageFormat(painter),
      header: (context) => _runningHead(
        painter: painter,
        projectName: projectName,
        documentTitle: labels.documentTitle,
        versionLine: versionLine,
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        pw.Text(pageTitle, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                _gridCornerCell(painter: painter),
                for (final (index, column) in columns.indexed)
                  _gridHeaderCell(
                    painter: painter,
                    text: (index == 0 || columns[index - 1].dayId != column.dayId)
                        ? "${labels.dayTagPrefix}${column.dayNumber}"
                        : "",
                  ),
              ],
            ),
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                _gridRowLabelCell(painter: painter, text: rowHeaderLabel, isBold: true),
                for (final column in columns)
                  _gridHeaderCell(
                    painter: painter,
                    text: column.slotLabel.trim().isEmpty ? ocptScheduleEmptyValue : column.slotLabel.trim(),
                  ),
              ],
            ),
            for (final row in rows)
              pw.TableRow(
                children: [
                  _gridRowLabelCell(
                    painter: painter,
                    text: row.label,
                    isBold: row.isBold,
                    isIndented: row.isIndented,
                  ),
                  for (final (index, _) in columns.indexed)
                    _gridDataCell(
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

  /// A grid's own blank cell — the top-left corner of a header row, or one of a category band row's
  /// own trailing cells, which carry no per-column value (the elements grid's own band rows).
  pw.Widget _gridCornerCell({required OcptScriptPagePainter painter}) =>
      pw.Padding(padding: const pw.EdgeInsets.all(_cellPaddingPt), child: pw.SizedBox());

  /// A grid's own header cell (a day tag, a slot's own label).
  pw.Widget _gridHeaderCell({required OcptScriptPagePainter painter, required String text}) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt),
    ),
  );

  /// A grid row's own leading label cell — indented and muted for a locations grid's own nested
  /// `Perso.` row.
  pw.Widget _gridRowLabelCell({
    required OcptScriptPagePainter painter,
    required String text,
    bool isBold = false,
    bool isIndented = false,
  }) => pw.Padding(
    padding: pw.EdgeInsets.only(
      left: isIndented ? _cellPaddingPt * 3 : _cellPaddingPt,
      top: _cellPaddingPt,
      right: _cellPaddingPt,
      bottom: _cellPaddingPt,
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: painter.fonts.variant(bold: isBold, italic: isIndented),
        fontSize: _bodyFontSizePt,
        color: isIndented ? _mutedColor : null,
      ),
    ),
  );

  /// One grid data cell. Deliberately **not** [_textCell]: a blank cell here means "not applicable
  /// to this column" (a location's row against a slot shot somewhere else, an element's row against
  /// a day it is not needed on), not a missing value, so it prints truly empty rather than
  /// substituting [ocptScheduleEmptyValue].
  pw.Widget _gridDataCell({required OcptScriptPagePainter painter, required String text, bool isMuted = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(_cellPaddingPt),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: painter.fonts.regular,
            fontSize: _smallFontSizePt,
            color: isMuted ? _mutedColor : null,
          ),
        ),
      );

  /// Adds one landscape page per chunk of [chunks] to [pdfDocument], each carrying every one of
  /// [rows] over that chunk's own day columns — or a single note page when [chunks] or [rows] is
  /// empty. Mirrors [_addGridPages] over [OcptShootingDay] columns rather than
  /// [OcptShootingPlanGridColumn] ones: the elements grid's own columns are days, not slots, so it
  /// is its own page-building method rather than a second call through [_gridPage], which draws a
  /// second, slot-label header row this grid has none of.
  void _addElementsGridPages({
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
        _gridNotePage(
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
        _elementsGridPage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          pageTitle: chunks.length > 1
              ? "${labels.elementsGridTitle} (${chunkIndex + 1}/${chunks.length})"
              : labels.elementsGridTitle,
          columns: chunk,
          chunkStartIndex: chunkIndex * _maxGridColumnsPerPage,
          rows: rows,
        ),
      );
    }
  }

  /// One landscape elements-grid page: the running head, the grid's own title, then its table — a
  /// single header row (the day tag over each column, unlike [_gridPage]'s own two: **the elements
  /// grid's own columns are days, not slots**, so there is no second, slot-label row to draw), then
  /// [rows] — an [OcptShootingPlanElementsGridCategoryBand] painted as its own full band row and an
  /// [OcptShootingPlanElementsGridElementRow] as an ordinary data row.
  ///
  /// **Only the day header repeats across a page break, not a category band.** `pw.TableRow.repeat`
  /// redraws *every* row it marks at the top of *every* page the table spans — right for a fixed
  /// header meant once, wrong for a band that recurs once per category: a table several categories
  /// deep would stack every category seen so far atop a continuation page rather than only the one a
  /// reader is actually looking at, which is a worse lie than the one being fixed. Making only the
  /// *current* band follow the break would need this table built row by row like
  /// [_dayTimetableWidgets] rather than handed whole to `pw.Table`, for a document that already names
  /// every row's own element (`<code> · <name>`, [OcptShootingPlanElementsGridElementRow.label])
  /// whether or not its category is still in view — a reader who has lost the band can still read
  /// the row, which is not true of a column with no header at all.
  pw.MultiPage _elementsGridPage({
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
      pageFormat: _landscapePageFormat(painter),
      header: (context) => _runningHead(
        painter: painter,
        projectName: projectName,
        documentTitle: labels.documentTitle,
        versionLine: versionLine,
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        pw.Text(pageTitle, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                _gridRowLabelCell(painter: painter, text: labels.elementsGridRowHeader, isBold: true),
                for (final day in columns)
                  _gridHeaderCell(painter: painter, text: "${labels.dayTagPrefix}${day.dayNumber}"),
              ],
            ),
            for (final row in rows)
              switch (row) {
                OcptShootingPlanElementsGridCategoryBand() => pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _bandColor),
                  children: [
                    _gridRowLabelCell(painter: painter, text: row.label, isBold: true),
                    for (final _ in columns) _gridCornerCell(painter: painter),
                  ],
                ),
                OcptShootingPlanElementsGridElementRow() => pw.TableRow(
                  children: [
                    _gridRowLabelCell(painter: painter, text: row.label),
                    for (final (index, _) in columns.indexed)
                      _gridDataCell(painter: painter, text: row.cells[chunkStartIndex + index]),
                  ],
                ),
              },
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Detailed day agenda
  // ---------------------------------------------------------------------------------------------

  /// One day's own detailed agenda: its title, its location(s), its per-slot hours, its own events
  /// next to them, the sets used, then the interleaved timetable — the milestones as prose and the
  /// shot runs as tables, a block's own [OcptShootingDayBlock.crewNote] printed under its row — and,
  /// trailing it, the day's own guest table.
  pw.MultiPage _dayAgendaPage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required Map<String, String> headingBySceneId,
  }) {
    final day = plan.schedule.daysById[dayId]!;
    final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    final timelines = plan.timelinesOfDay(dayId);
    final orderedEntries = ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: dayId);
    final locations = ocptScheduleLocationsOfSlots(plan, slots);
    final events = plan.schedule.eventsByDayId[dayId] ?? const <OcptShootingDayEvent>[];
    final guestRows = ocptScheduleGuestRowsOfDay(
      plan: plan,
      dayId: dayId,
      unnamedPersonLabel: labels.unnamedPersonLabel,
    );
    final title = labels.titleOfDay(dayId);

    return pw.MultiPage(
      pageFormat: _portraitPageFormat(painter),
      header: (context) => _runningHead(
        painter: painter,
        projectName: projectName,
        documentTitle: labels.documentTitle,
        versionLine: versionLine,
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        pw.Text(
          title.isEmpty ? "${labels.dayTagPrefix}${day.dayNumber}" : title,
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt),
        ),
        pw.SizedBox(height: 10),
        _daySectionTitle(painter: painter, text: labels.dayLocationLabel),
        pw.SizedBox(height: 2),
        ..._locationLines(painter: painter, locations: locations),
        pw.SizedBox(height: 10),
        _daySectionTitle(painter: painter, text: labels.dayHoursLabel),
        pw.SizedBox(height: 2),
        ..._hoursLines(painter: painter, labels: labels, slots: slots, timelines: timelines),
        if (events.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _eventsSection(painter: painter, labels: labels, events: events),
        ],
        pw.SizedBox(height: 10),
        _daySectionTitle(painter: painter, text: labels.daySetsLabel),
        pw.SizedBox(height: 2),
        ..._setsLines(painter: painter, plan: plan, slots: slots, locations: locations),
        pw.SizedBox(height: 10),
        _daySectionTitle(painter: painter, text: labels.dayTimetableLabel),
        pw.SizedBox(height: 4),
        ..._dayTimetableWidgets(
          painter: painter,
          labels: labels,
          orderedEntries: orderedEntries,
          plan: plan,
          headingBySceneId: headingBySceneId,
        ),
        if (guestRows.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _guestsSection(painter: painter, labels: labels, rows: guestRows),
        ],
      ],
    );
  }

  /// A section's own small, muted heading.
  pw.Widget _daySectionTitle({required OcptScriptPagePainter painter, required String text}) => pw.Text(
    text.toUpperCase(),
    style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt, color: _mutedColor),
  );

  /// [locations]' own name and address, one line each, or a single [ocptScheduleEmptyValue] line
  /// when there is none.
  List<pw.Widget> _locationLines({required OcptScriptPagePainter painter, required List<OcptLocation> locations}) {
    if (locations.isEmpty) {
      return [_noteWidget(painter: painter, text: ocptScheduleEmptyValue)];
    }
    return [
      for (final location in locations)
        _noteWidget(painter: painter, text: ocptScheduleLocationAddressLine(location)),
    ];
  }

  /// One line per live slot: its own label, the call time (its resolved start) and the estimated end
  /// (its resolved end, or [ocptScheduleEmptyValue] while it carries no block yet).
  List<pw.Widget> _hoursLines({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<OcptShootingSlot> slots,
    required OcptShootingDayTimelines? timelines,
  }) {
    if (timelines == null || slots.isEmpty) {
      return [_noteWidget(painter: painter, text: ocptScheduleEmptyValue)];
    }

    final lines = <String>[];
    for (final slot in slots) {
      final timeline = timelines.bySlotId[slot.id];
      if (timeline == null) {
        continue;
      }
      final label = slot.label.trim().isEmpty ? ocptScheduleEmptyValue : slot.label.trim();
      final start = ocptFormatDayMinute(timeline.startMinute);
      final end = timeline.endMinute == null ? ocptScheduleEmptyValue : ocptFormatDayMinute(timeline.endMinute!);
      lines.add("$label : ${labels.callTimeLabel} $start … ${labels.estimatedEndLabel} $end");
    }

    if (lines.isEmpty) {
      return [_noteWidget(painter: painter, text: ocptScheduleEmptyValue)];
    }
    return [for (final line in lines) _noteWidget(painter: painter, text: line)];
  }

  /// One line per [locations] entry: its own name, then the sets used there that day, comma-joined —
  /// or [ocptScheduleEmptyValue] when no slot at that location named one.
  List<pw.Widget> _setsLines({
    required OcptScriptPagePainter painter,
    required OcptSchedulePlanSnapshot plan,
    required List<OcptShootingSlot> slots,
    required List<OcptLocation> locations,
  }) {
    if (locations.isEmpty) {
      return [_noteWidget(painter: painter, text: ocptScheduleEmptyValue)];
    }

    final setNamesByLocationId = <String, Set<String>>{};
    for (final slot in slots) {
      final locationId = slot.locationId;
      final setId = slot.setId;
      if (locationId == null || setId == null) {
        continue;
      }
      final setName = plan.setById[setId]?.name.trim();
      if (setName == null || setName.isEmpty) {
        continue;
      }
      (setNamesByLocationId[locationId] ??= <String>{}).add(setName);
    }

    return [
      for (final location in locations)
        _noteWidget(
          painter: painter,
          text:
              "${location.name.trim().isEmpty ? ocptScheduleEmptyValue : location.name.trim()} : "
              "${_joinedOrEmpty(setNamesByLocationId[location.id])}",
        ),
    ];
  }

  /// [names], sorted and comma-joined, or [ocptScheduleEmptyValue] while it is null or empty.
  String _joinedOrEmpty(Set<String>? names) {
    if (names == null || names.isEmpty) {
      return ocptScheduleEmptyValue;
    }
    final sorted = names.toList()..sort();
    return sorted.join(", ");
  }

  /// The day's own events section: [OcptShootingPlanLabels.eventsSectionTitle] then one bold
  /// `HH:mm — <label>` line per event, its own free-form note beneath in a muted second line when it
  /// carries one.
  ///
  /// Mirrors `OcptCallSheetPdfService._eventsSection`, placed here beside the day's own hours
  /// section for the same reason it sits beside that document's own time bands: an event is a fact
  /// about the day rather than about any one slot's chain, so it takes part in no chain and is never
  /// interleaved into the timetable [_dayTimetableWidgets] builds. Never called on a day with no
  /// event at all — see [_dayAgendaPage]'s own composition for why an empty section is skipped
  /// entirely rather than drawn over an em dash.
  pw.Widget _eventsSection({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<OcptShootingDayEvent> events,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _daySectionTitle(painter: painter, text: labels.eventsSectionTitle),
      pw.SizedBox(height: 2),
      for (final event in events) ...[
        pw.Text(
          "${ocptFormatDayMinute(event.minute)} — "
              "${event.label.trim().isEmpty ? ocptScheduleEmptyValue : event.label.trim()}",
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
        ),
        if (event.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            event.notes.trim(),
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
        pw.SizedBox(height: 4),
      ],
    ],
  );

  /// The day's own trailing guest table (`NOM / MOTIF / HORAIRES`) — the shape
  /// `OcptCallSheetPdfService._guestsSection` already gives a day's guests, and for the same reason:
  /// a guest is owed an arrival and a departure and never a PAT band (ADR 0018), so there is no
  /// fourth column here to leave blank for one. Never called on a day with no guest at all — see
  /// [_dayAgendaPage]'s own composition.
  pw.Widget _guestsSection({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<OcptScheduleGuestRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _daySectionTitle(painter: painter, text: labels.guestsSectionTitle),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
        columnWidths: _guestColumnWidths,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _bandColor),
            children: [
              for (final header in [labels.nameHeader, labels.guestReasonHeader, labels.hoursLinePrefix])
                _textCell(painter: painter, text: header, isBold: true),
            ],
          ),
          for (final row in rows)
            pw.TableRow(
              children: [
                _textCell(painter: painter, text: row.name),
                _guestReasonCell(painter: painter, row: row),
                _textCell(painter: painter, text: row.hours),
              ],
            ),
        ],
      ),
    ],
  );

  /// One [_guestsSection] row's own `MOTIF` cell: the guest's own reason(s), then their own note(s)
  /// on a muted second line when they carry any — mirrors
  /// `OcptCallSheetPdfService._guestReasonCell`.
  pw.Widget _guestReasonCell({
    required OcptScriptPagePainter painter,
    required OcptScheduleGuestRow row,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          row.reason.isEmpty ? ocptScheduleEmptyValue : row.reason,
          style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
        ),
        if (row.notes.isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            row.notes,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
      ],
    ),
  );

  /// A full-width band naming a shot run's own crew note — printed the moment a run is interrupted
  /// by a block that carries one, since a `pw.Table` row cannot itself span the page width a note
  /// deserves. Mirrors `OcptCallSheetPdfService._crewNoteBandWidget`, minus its own list of several
  /// notes: here it is always exactly the one block's own, [_dayTimetableWidgets] calling this the
  /// instant it sees one rather than accumulating several across a run.
  pw.Widget _crewNoteBandWidget({required OcptScriptPagePainter painter, required String crewNote}) =>
      pw.Container(
        constraints: const pw.BoxConstraints(minWidth: double.infinity),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _ruleColor, width: 0.5)),
        padding: const pw.EdgeInsets.all(_cellPaddingPt),
        child: pw.Text(crewNote, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
      );

  /// The day's own interleaved timetable: a run of consecutive [OcptShootingBlockKind.shot] blocks
  /// becomes one shot table, every other block becomes its own prose milestone line — or
  /// [OcptShootingPlanLabels.emptyDayScheduleNote] when [orderedEntries] is empty (no slot, or no
  /// block on any of them).
  ///
  /// **A block's own [OcptShootingDayBlock.crewNote] prints under its own row**: `notes` is the
  /// private one that never prints, `crewNote` is the one that does. A shot run's own note closes
  /// the pending table chunk the moment it is seen — mirroring
  /// `OcptCallSheetPdfService._mainTableSection`'s own `flushShotRows` — since a `pw.Table` row
  /// cannot itself span the page width the note deserves; a milestone's own note has no such
  /// problem, [_milestoneProseLine] already being a full-width line that prints it inline.
  List<pw.Widget> _dayTimetableWidgets({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<OcptOrderedScheduleEntry> orderedEntries,
    required OcptSchedulePlanSnapshot plan,
    required Map<String, String> headingBySceneId,
  }) {
    final widgets = <pw.Widget>[];
    var pendingShots = <(OcptShot, OcptOrderedScheduleEntry)>[];

    void flush() {
      if (pendingShots.isEmpty) {
        return;
      }
      widgets.add(_shotTable(painter: painter, labels: labels, rows: pendingShots, plan: plan));
      pendingShots = <(OcptShot, OcptOrderedScheduleEntry)>[];
    }

    for (final ordered in orderedEntries) {
      final block = ordered.block;
      if (block.kind == OcptShootingBlockKind.shot) {
        final shot = block.shotId == null ? null : plan.shotById(block.shotId!);
        if (shot == null) {
          continue;
        }
        pendingShots.add((shot, ordered));
        final crewNote = block.crewNote.trim();
        if (crewNote.isNotEmpty) {
          flush();
          widgets.add(_crewNoteBandWidget(painter: painter, crewNote: crewNote));
        }
        continue;
      }

      flush();
      final caption = ocptScheduleBlockCaptionOf(
        block: block,
        headingBySceneId: headingBySceneId,
        roleById: plan.roleById,
        roleCandidateById: plan.roleCandidateById,
        blockKindLabelOf: labels.blockKindLabelOf,
      );
      widgets.add(
        _milestoneProseLine(
          painter: painter,
          labels: labels,
          caption: caption,
          rolesLine: ocptScheduleBlockRoleNumbersLine(
            roleNumbers: ocptScheduleBlockRoleNumbersOf(
              block: block,
              slot: ordered.slot,
              roleById: plan.roleById,
            ),
            rolesLabel: labels.rolesLabel,
          ),
          startMinute: ordered.entry.startMinute,
          endMinute: ordered.entry.endMinute,
          crewNote: block.crewNote.trim(),
        ),
      );
    }
    flush();

    if (widgets.isEmpty) {
      return [_noteWidget(painter: painter, text: labels.emptyDayScheduleNote)];
    }
    return [for (final (index, widget) in widgets.indexed) ...[if (index > 0) pw.SizedBox(height: 4), widget]];
  }

  /// A non-shot block's own prose line (`De 16h45 à 17h15 : …`), or `<from> <start> : <caption>`
  /// when [endMinute] is null — a milestone whose block resolves to zero duration, or a slot with
  /// nothing placed on it yet — then [rolesLine] beneath it when the band expects anybody
  /// ([ocptScheduleBlockRoleNumbersLine], null for every band that doesn't), then [crewNote] on its
  /// own line when the block carries one — printed inline, unlike a shot run's own
  /// ([_crewNoteBandWidget]): this line is already full-width, so it has nothing to close and
  /// reopen the way a `pw.Table` row does.
  pw.Widget _milestoneProseLine({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String caption,
    required String? rolesLine,
    required int startMinute,
    required int? endMinute,
    required String crewNote,
  }) {
    final start = ocptFormatDayMinute(startMinute);
    final text = endMinute == null
        ? "${labels.milestoneFromLabel} $start : $caption"
        : "${labels.milestoneFromLabel} $start ${labels.milestoneToLabel} ${ocptFormatDayMinute(endMinute)} : "
              "$caption";

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(text, style: pw.TextStyle(font: painter.fonts.italic, fontSize: _bodyFontSizePt)),
          if (rolesLine != null)
            pw.Text(rolesLine, style: pw.TextStyle(font: painter.fonts.italic, fontSize: _bodyFontSizePt)),
          if (crewNote.isNotEmpty)
            pw.Text(crewNote, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
        ],
      ),
    );
  }

  /// One run of consecutive shot blocks, as an `Hours / Plan / Valeur de plan / Move. / Cadre /
  /// Commentaire / Perso.` table — the hours column reading each row's own resolved start over its
  /// resolved end, off the very [OcptOrderedScheduleEntry] the row was placed from, never a stored
  /// anchor and never taken modulo anything (a night run crossing midnight prints past `23:59`
  /// through [ocptFormatDayMinute] exactly as every other hour in this document does).
  pw.Widget _shotTable({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<(OcptShot, OcptOrderedScheduleEntry)> rows,
    required OcptSchedulePlanSnapshot plan,
  }) => pw.Table(
    border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
    columnWidths: _shotColumnWidths,
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _bandColor),
        children: [
          for (final header in [
            labels.hoursHeader,
            labels.planHeader,
            labels.shotSizeHeader,
            labels.moveHeader,
            labels.framingHeader,
            labels.commentHeader,
            labels.persoLabel,
          ])
            _textCell(painter: painter, text: header, isBold: true),
        ],
      ),
      for (final (shot, ordered) in rows)
        pw.TableRow(
          children: [
            _textCell(
              painter: painter,
              text: "${ocptFormatDayMinute(ordered.entry.startMinute)} – "
                  "${ocptFormatDayMinute(ordered.entry.endMinute)}",
            ),
            _textCell(painter: painter, text: shot.code),
            _textCell(painter: painter, text: shot.shotSize),
            _textCell(painter: painter, text: shot.cameraMove),
            _textCell(painter: painter, text: shot.framing),
            _textCell(painter: painter, text: shot.notes),
            _textCell(painter: painter, text: _roleNamesOf(shot, plan.roles)),
          ],
        ),
    ],
  );

  /// The role names of every one of [shot]'s own [OcptShot.characters] matched against [roles]
  /// (through `normalizeCharacterName`, the same join every reader of a shot's characters uses), or
  /// [ocptScheduleEmptyValue] when none matched.
  String _roleNamesOf(OcptShot shot, List<OcptRole> roles) {
    final byNormalizedName = {for (final role in roles) normalizeCharacterName(role.name): role};
    final matched = <String>{};
    for (final name in shot.characters) {
      final role = byNormalizedName[name];
      if (role != null) {
        matched.add(role.name);
      }
    }
    if (matched.isEmpty) {
      return ocptScheduleEmptyValue;
    }
    final sorted = matched.toList()..sort();
    return sorted.join(", ");
  }

  // ---------------------------------------------------------------------------------------------
  // Ten-minute day grid
  // ---------------------------------------------------------------------------------------------

  /// [dayId]'s own [OcptShootingDayAgendaGrid], built from [plan]'s resolved timelines and events —
  /// the one place this service turns those into the grid's own pure input types.
  ///
  /// A shot block's own tile caption is its shot's own code (`shot.code`), never its full row of
  /// fields: the ten-minute grid's own columns are narrow, and the detailed agenda right before it
  /// already prints every other field of the very same shot. Every other block kind reads its
  /// caption the same way [_dayTimetableWidgets] does, through [ocptScheduleBlockCaptionOf].
  OcptShootingDayAgendaGrid _tenMinuteGridOf({
    required OcptShootingPlanLabels labels,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required Map<String, String> headingBySceneId,
  }) {
    final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    final timelines = plan.timelinesOfDay(dayId);
    if (timelines == null) {
      return const OcptShootingDayAgendaGrid.empty();
    }

    final blocksBySlotId = <String, List<OcptShootingDayBlock>>{};
    for (final block in plan.schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[]) {
      (blocksBySlotId[block.slotId] ??= <OcptShootingDayBlock>[]).add(block);
    }

    final columns = <OcptShootingDayAgendaColumnInput>[];
    for (final slot in slots) {
      final timeline = timelines.bySlotId[slot.id];
      if (timeline == null) {
        continue;
      }
      final captions = <String, String>{
        for (final block in blocksBySlotId[slot.id] ?? const <OcptShootingDayBlock>[])
          block.id: block.kind == OcptShootingBlockKind.shot
              ? (block.shotId == null ? null : plan.shotById(block.shotId!))?.code ?? ocptScheduleEmptyValue
              : ocptScheduleBlockCaptionOf(
                  block: block,
                  headingBySceneId: headingBySceneId,
                  roleById: plan.roleById,
                  roleCandidateById: plan.roleCandidateById,
                  blockKindLabelOf: labels.blockKindLabelOf,
                ),
      };
      columns.add(
        OcptShootingDayAgendaColumnInput(
          slotId: slot.id,
          label: slot.label,
          timeline: timeline,
          captionByBlockId: captions,
        ),
      );
    }

    final events = [
      for (final event in plan.schedule.eventsByDayId[dayId] ?? const <OcptShootingDayEvent>[])
        OcptShootingDayAgendaEventInput(id: event.id, minute: event.minute, label: event.label),
    ];

    return OcptShootingDayAgendaGrid.of(columns: columns, events: events);
  }

  /// One day's own ten-minute grid page: the running head, the day's own title with
  /// [OcptShootingPlanLabels.tenMinuteGridSectionTitle] appended, then the grid itself, or
  /// [OcptShootingPlanLabels.emptyDayScheduleNote] on a day with no live slot at all.
  ///
  /// **`pw.Table` cannot span a cell across rows**, so a tile whose own
  /// [OcptShootingDayAgendaTile.rowSpan] is more than 1 is drawn as one ordinary bordered cell per
  /// row, its own top and bottom border switched off on every row but its first and its last
  /// ([_tenMinuteGridTileCell]) — which reads as a single merged rectangle without the package ever
  /// being asked to merge one. An [OcptShootingDayAgendaEventPlacement.inGrid] event breaks the
  /// table at its own row into two chunks with its own full-width band between them
  /// ([_tenMinuteGridEventWidget]), mirroring [_dayTimetableWidgets]'s own milestone break:
  /// `pw.Table` cannot span a *column* any more than a row, so there is no other way to print one
  /// line the whole width of the page. A tile whose own band happens to cross that break is
  /// therefore drawn as two bordered rectangles rather than one — a visual seam this reading aid
  /// accepts rather than a claim the grid cannot make. A `.beforeGrid`/`.afterGrid` event is the
  /// same band, simply printed before the first table chunk or after the last one instead of
  /// breaking one open — the grid's own bounds no longer stretch to reach it (see
  /// `OcptShootingDayAgendaGrid`'s own doc comment for why a printed page decided that differently
  /// from the schedule mode's own on-screen week grid).
  ///
  /// Every row additionally opens on a **light grey rule the whole width of the page**, carried by
  /// the row's own decoration rather than by its cells: a reader following a time across three slot
  /// columns has nothing else to line their eye up on, the hour column and the tiles being drawn
  /// several centimetres apart. It is painted in [_gridRowRuleColor] over the tiles rather than
  /// under them — `pw.BoxDecoration` draws a border in its foreground phase — and that is why the
  /// colour is lighter than [_ruleColor]: it crosses a multi-row tile without ever reading as that
  /// tile having been cut into pieces.
  pw.MultiPage _tenMinuteGridPage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required Map<String, String> headingBySceneId,
  }) {
    final day = plan.schedule.daysById[dayId]!;
    final title = labels.titleOfDay(dayId);
    final grid = _tenMinuteGridOf(labels: labels, plan: plan, dayId: dayId, headingBySceneId: headingBySceneId);

    return pw.MultiPage(
      pageFormat: _portraitPageFormat(painter),
      header: (context) => _runningHead(
        painter: painter,
        projectName: projectName,
        documentTitle: labels.documentTitle,
        versionLine: versionLine,
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        pw.Text(
          "${title.isEmpty ? "${labels.dayTagPrefix}${day.dayNumber}" : title} — "
              "${labels.tenMinuteGridSectionTitle}",
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt),
        ),
        pw.SizedBox(height: 10),
        ..._tenMinuteGridWidgets(painter: painter, labels: labels, grid: grid),
      ],
    );
  }

  /// The grid's own body: an [OcptShootingDayAgendaEventPlacement.beforeGrid] event's own band
  /// first, then one [pw.Table] per run of rows uninterrupted by an `.inGrid` one — a header row
  /// (the slot labels) leading every one of them so a page reached after a break still says which
  /// column is which slot — then every `.afterGrid` event's own band last, or
  /// [OcptShootingPlanLabels.emptyDayScheduleNote] while [grid] is empty.
  List<pw.Widget> _tenMinuteGridWidgets({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required OcptShootingDayAgendaGrid grid,
  }) {
    if (grid.isEmpty) {
      return [_noteWidget(painter: painter, text: labels.emptyDayScheduleNote)];
    }

    final tileAtRowByColumn = <String, List<OcptShootingDayAgendaTile?>>{
      for (final column in grid.columns) column.slotId: List<OcptShootingDayAgendaTile?>.filled(grid.rowCount, null),
    };
    for (final tile in grid.tiles) {
      final rows = tileAtRowByColumn[tile.slotId];
      if (rows == null) {
        continue;
      }
      for (var row = tile.startRow; row < tile.startRow + tile.rowSpan && row < grid.rowCount; row++) {
        rows[row] = tile;
      }
    }

    final leadingMarkers = <OcptShootingDayAgendaEventMarker>[];
    final trailingMarkers = <OcptShootingDayAgendaEventMarker>[];
    final eventsByRow = <int, List<OcptShootingDayAgendaEventMarker>>{};
    for (final marker in grid.events) {
      switch (marker.placement) {
        case OcptShootingDayAgendaEventPlacement.beforeGrid:
          leadingMarkers.add(marker);
        case OcptShootingDayAgendaEventPlacement.afterGrid:
          trailingMarkers.add(marker);
        case OcptShootingDayAgendaEventPlacement.inGrid:
          (eventsByRow[marker.row!] ??= <OcptShootingDayAgendaEventMarker>[]).add(marker);
      }
    }

    final columnWidths = <int, pw.TableColumnWidth>{0: const pw.FlexColumnWidth(0.8)};
    for (var index = 0; index < grid.columns.length; index++) {
      columnWidths[index + 1] = const pw.FlexColumnWidth();
    }

    final widgets = <pw.Widget>[
      for (final marker in leadingMarkers) _tenMinuteGridEventWidget(painter: painter, marker: marker),
    ];
    var pendingRows = <pw.TableRow>[];

    void flush() {
      if (pendingRows.isEmpty) {
        return;
      }
      widgets.add(
        pw.Table(
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                _gridCornerCell(painter: painter),
                for (final column in grid.columns)
                  _gridHeaderCell(
                    painter: painter,
                    text: column.label.trim().isEmpty ? ocptScheduleEmptyValue : column.label.trim(),
                  ),
              ],
            ),
            ...pendingRows,
          ],
        ),
      );
      pendingRows = <pw.TableRow>[];
    }

    for (var row = 0; row < grid.rowCount; row++) {
      pendingRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _gridRowRuleColor, width: 0.3)),
          ),
          children: [
            _tenMinuteGridHourCell(painter: painter, minute: grid.startMinute + row * OcptShootingDayAgendaGrid.stepMinutes),
            for (final column in grid.columns)
              _tenMinuteGridTileCell(painter: painter, tile: tileAtRowByColumn[column.slotId]![row], row: row),
          ],
        ),
      );

      final events = eventsByRow[row];
      if (events == null) {
        continue;
      }
      flush();
      for (final marker in events) {
        widgets.add(_tenMinuteGridEventWidget(painter: painter, marker: marker));
      }
    }
    flush();

    for (final marker in trailingMarkers) {
      widgets.add(_tenMinuteGridEventWidget(painter: painter, marker: marker));
    }

    return widgets;
  }

  /// The grid's own leading column cell: [minute] formatted through `ocptFormatDayMinute`, printed
  /// on every row — the same figure the tile cells inside that row's own band read their exact
  /// clock from, but rounded to this row's own ten-minute mark rather than a block's own exact one.
  pw.Widget _tenMinuteGridHourCell({required OcptScriptPagePainter painter, required int minute}) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      ocptFormatDayMinute(minute),
      style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
    ),
  );

  /// One slot column's own cell for [row]: a blank, borderless space while [tile] is null (that
  /// slot has nothing placed on this row — a gap between two blocks, or a row before the slot's own
  /// call), otherwise a bordered rectangle carrying [tile]'s own caption and exact clock on its
  /// first row alone, its top and bottom border switched on only where [row] is that tile's own
  /// first or last row respectively — see [_tenMinuteGridPage]'s own doc comment for why.
  pw.Widget _tenMinuteGridTileCell({
    required OcptScriptPagePainter painter,
    required OcptShootingDayAgendaTile? tile,
    required int row,
  }) {
    if (tile == null) {
      return pw.Padding(padding: const pw.EdgeInsets.all(_cellPaddingPt), child: pw.SizedBox());
    }

    final isFirstRow = row == tile.startRow;
    final isLastRow = row == tile.startRow + tile.rowSpan - 1;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: const pw.BorderSide(color: _ruleColor, width: 0.5),
          right: const pw.BorderSide(color: _ruleColor, width: 0.5),
          top: isFirstRow ? const pw.BorderSide(color: _ruleColor, width: 0.5) : pw.BorderSide.none,
          bottom: isLastRow ? const pw.BorderSide(color: _ruleColor, width: 0.5) : pw.BorderSide.none,
        ),
      ),
      padding: const pw.EdgeInsets.all(_cellPaddingPt),
      child: isFirstRow
          ? pw.Text(
              "${tile.caption} · ${ocptFormatDayMinute(tile.startMinute)}–${ocptFormatDayMinute(tile.endMinute)}",
              style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt),
            )
          : pw.SizedBox(),
    );
  }

  /// The grid's own full-width event marker, breaking the table it interrupts into two — mirrors
  /// [_crewNoteBandWidget]'s own `minWidth: double.infinity` trick, `pw.Table` having no column a
  /// single widget could span instead.
  pw.Widget _tenMinuteGridEventWidget({
    required OcptScriptPagePainter painter,
    required OcptShootingDayAgendaEventMarker marker,
  }) => pw.Container(
    constraints: const pw.BoxConstraints(minWidth: double.infinity),
    margin: const pw.EdgeInsets.symmetric(vertical: 2),
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _ruleColor, width: 0.5), color: _bandColor),
    child: pw.Text(
      "${ocptFormatDayMinute(marker.minute)} — ${marker.label.trim().isEmpty ? ocptScheduleEmptyValue : marker.label.trim()}",
      style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
    ),
  );

  // ---------------------------------------------------------------------------------------------
  // Small shared drawing helpers
  // ---------------------------------------------------------------------------------------------

  /// The running head naming the project and the document on the left, [versionLine] on the right,
  /// over a thin rule — the same shape `OcptCallSheetPdfService._page` draws inline, factored out
  /// here since every page kind of this service (title, grid, day agenda, note) opens with it.
  ///
  /// The version line is repeated on **every** page rather than on the title page alone: a shooting
  /// plan is read page by page, a day agenda torn out of it or a landscape grid pinned on a wall,
  /// and a reader holding one sheet of it has nowhere else to find out which issue they are working
  /// from. Every call site hands this to its own `pw.MultiPage`'s **`header:`** callback rather than
  /// as the first entry of its `build:` list: `build:` only ever runs once, on the first physical
  /// page a flow lands on, while `header:` runs on every one it overflows onto — a busy day agenda
  /// or a wide grid chunked across several sheets would otherwise carry this on its first page alone
  /// and nothing on the rest, which is exactly the failure this doc comment's own promise rules out.
  pw.Widget _runningHead({
    required OcptScriptPagePainter painter,
    required String projectName,
    required String documentTitle,
    required String versionLine,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "$projectName — $documentTitle",
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
          pw.Text(
            versionLine,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
      ),
      pw.SizedBox(height: 2),
      pw.Divider(color: _ruleColor, thickness: 0.5, height: 6),
      pw.SizedBox(height: 6),
    ],
  );

  /// A block of free text.
  pw.Widget _noteWidget({required OcptScriptPagePainter painter, required String text}) =>
      pw.Text(text, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt));

  /// One table cell holding [text], substituting [ocptScheduleEmptyValue] when it is blank — unlike
  /// [_gridDataCell], a shot table cell always names a specific field of a specific shot, so a blank
  /// one *is* a missing value.
  pw.Widget _textCell({required OcptScriptPagePainter painter, required String text, bool isBold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(_cellPaddingPt),
        child: pw.Text(
          text.isEmpty ? ocptScheduleEmptyValue : text,
          style: pw.TextStyle(font: painter.fonts.variant(bold: isBold, italic: false), fontSize: _bodyFontSizePt),
        ),
      );

  /// The portrait `pdf` page format every title page, note page and day agenda is drawn on — the
  /// same margin convention `OcptCallSheetPdfService._page` uses (`marginRightPt` standing in for
  /// the bottom margin too, [OcptScriptPagePainter] having none of its own).
  PdfPageFormat _portraitPageFormat(OcptScriptPagePainter painter) => PdfPageFormat(
    painter.pageWidthPt,
    painter.pageHeightPt,
    marginLeft: painter.marginRightPt,
    marginTop: painter.marginTopPt,
    marginRight: painter.marginRightPt,
    marginBottom: painter.marginRightPt,
  );

  /// The landscape `pdf` page format every summary grid page is drawn on — [painter]'s own width and
  /// height swapped, its margins otherwise read the same way [_portraitPageFormat] does.
  PdfPageFormat _landscapePageFormat(OcptScriptPagePainter painter) => PdfPageFormat(
    painter.pageHeightPt,
    painter.pageWidthPt,
    marginLeft: painter.marginRightPt,
    marginTop: painter.marginTopPt,
    marginRight: painter.marginRightPt,
    marginBottom: painter.marginRightPt,
  );
}

// ===================================================================================================
// Pure pagination helper — the columns and rows themselves are `OcptShootingPlanGrids`' own
// (`lib/models/ocpt_shooting_plan_grids.dart`), shared with `OcptShootingPlanXlsxExportService`.
// ===================================================================================================

/// [columns] split into chunks of at most [chunkSize], in order — empty when [columns] itself is.
/// Generic over the column's own type so every summary grid paginates by the very same rule: a
/// slot column ([OcptShootingPlanGridColumn]) for the locations, sequences and crew-and-cast grids,
/// a day column ([OcptShootingDay]) for the elements one — [_maxGridColumnsPerPage] never meaning
/// two different things depending on which grid asks. A chunk's own start offset into [columns]
/// (`chunkIndex * chunkSize`, contiguous by construction) is what every caller reads a row's own
/// cells at, [OcptShootingPlanGridRow.cells]/[OcptShootingPlanElementsGridElementRow.cells] being
/// resolved against the **whole**, unchunked column list rather than against one page's own slice.
List<List<T>> _chunkColumns<T>(List<T> columns, int chunkSize) {
  if (columns.isEmpty) {
    return const [];
  }

  final chunks = <List<T>>[];
  for (var start = 0; start < columns.length; start += chunkSize) {
    final end = start + chunkSize < columns.length ? start + chunkSize : columns.length;
    chunks.add(columns.sublist(start, end));
  }
  return chunks;
}
