// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_day_out_of_days_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_out_of_days.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of the table's own title.
const double _titleFontSizePt = 16;

/// The font size, in points, of the title page's own document name.
const double _coverTitleFontSizePt = 24;

/// The font size, in points, of every body line: a row label, a legend entry, a note.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small lines: the running head, a column header, a cell's own
/// code.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of the table.
const double _cellPaddingPt = 4;

/// The colour of the rules the table's own borders are drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of the table's own header row.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// How many day columns one page holds before the rest carries on, chunked, onto the next one.
///
/// Deliberately its own figure rather than the shooting plan's `_maxGridColumnsPerPage`: a column
/// here carries a two- or three-letter code under a two-line header, where one of that document's
/// own columns carries a set name, a list of first names or a run of shot ranks — twice as many fit
/// before a page stops being readable, and tying the two together would mean one document's
/// legibility deciding the other's.
const int _maxDayColumnsPerPage = 12;

/// Renders the *Day Out of Days*: one row per role the printed range convokes, one column per day of
/// that range, a code in every cell of a role's own span, and a trailing count of the days it works
/// and the days it is held.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings — `OcptShootingPlanPdfService` chief
/// among them, whose own doc comment this one mirrors. It prints no screenplay, so it draws nothing
/// through [OcptScriptPagePainter]'s absolutely positioned page builders and flows its content in
/// [pw.MultiPage]s instead; it still takes one painter, for the page geometry every export of this
/// app measures a sheet with and the Courier Prime variants all of them print in.
///
/// **Every code comes off [ocptComputeDayOutOfDays]**, the pure function that owns every rule this
/// document has — which day is a start, which a finish, which a hold, and which days carry nothing
/// at all. This service decides two things only, both of them about paper: the **order** of the rows
/// (by role number, the order the cast is listed in everywhere else in this app) and how the table
/// is drawn. It prints the four codes that function derives, plus the one cell where a span's two
/// ends meet; it never prints a `T` or an `R`, no field of this app saying either — see
/// [OcptDayOutOfDaysCode]'s own doc comment for that argument.
///
/// **The table is landscape** (page width and height swapped from the painter's own geometry), the
/// same trade `OcptShootingPlanPdfService`'s own summary grids make: a shoot is wide, and a document
/// silently cropped to whatever a portrait page holds would be worse than one that runs the columns
/// on. When more days exist than [_maxDayColumnsPerPage] holds, the rows repeat over as many chunked
/// pages as it takes, each page's own trailing counts being **the whole range's**, never that
/// chunk's: an actor's contract is negotiated over the shoot, not over whichever days happened to
/// fall on one sheet.
class OcptDayOutOfDaysPdfService {
  /// Creates an [OcptDayOutOfDaysPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptDayOutOfDaysPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the *Day Out of Days* of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - day out of days.pdf`); a blank one falls back to the project name alone, exactly
  /// as `OcptShootingPlanPdfService.shootingPlanFileName` does.
  String dayOutOfDaysFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the *Day Out of Days* of [dayIds] (in the order given), returning the PDF's bytes.
  ///
  /// A [dayIds] entry naming no live day of [plan] is silently skipped, exactly as its two sibling
  /// services read a missing day: nothing this app writes can produce one, but a hand-edited file or
  /// a stale selection might. A range resolving to no live day at all, or to one no role is convoked
  /// anywhere in, still produces a readable, one-note document (plus its title page, when
  /// [includeTitlePage] asks for one) rather than an empty file nobody can open.
  ///
  /// **Shooting days only.** This document is about the shoot: a [dayIds] entry naming a day whose
  /// `OcptShootingDayKind` is not [OcptShootingDayKind.shoot] is skipped exactly as an entry naming
  /// no live day at all is. The scoping lives here rather than at the call site so every caller
  /// gets the same answer — the mode's own day picker offers the shooting days alone, and this is
  /// what makes that an agreement rather than a coincidence.
  ///
  /// [exportDate] is the moment the title page's own version line and every page's running head
  /// print (through [ocptScheduleGeneratedAtStamp], the stamp every schedule document of this app
  /// prints); it defaults to the moment this method runs, and is exposed so a test can pin it rather
  /// than racing a midnight rollover. It is resolved **once** per document, so a table whose
  /// rendering straddles a minute boundary still names one issue of itself on every one of its
  /// pages.
  Future<Uint8List> generate({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required OcptPageSetup pageSetup,
    required OcptDayOutOfDaysLabels labels,
    required String projectName,
    required bool includeTitlePage,
    DateTime? exportDate,
  }) async {
    final painter = await _painterFor(pageSetup);
    final pdfDocument = pw.Document();
    final versionLine = "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";

    final days = [
      for (final dayId in dayIds)
        if (plan.schedule.daysById[dayId] case final day?)
          if (day.kind == OcptShootingDayKind.shoot) day,
    ];

    if (includeTitlePage) {
      pdfDocument.addPage(_titlePage(painter: painter, labels: labels, versionLine: versionLine));
    }

    final orderedRoles = _orderedRolesOf(plan);
    final table = ocptComputeDayOutOfDays(
      days: [
        for (final day in days)
          OcptDayOutOfDaysDay(id: day.id, convokedRoleIds: plan.convokedRoleIdsOfDay(day.id)),
      ],
      roleIds: [for (final role in orderedRoles) role.id],
    );

    if (table.isEmpty) {
      pdfDocument.addPage(
        _notePage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          text: labels.emptyTableNote,
        ),
      );
      return pdfDocument.save();
    }

    final chunks = _chunkDays(days, _maxDayColumnsPerPage);
    for (final (chunkIndex, chunk) in chunks.indexed) {
      pdfDocument.addPage(
        _tablePage(
          painter: painter,
          labels: labels,
          roleLabelById: {
            for (final role in orderedRoles) role.id: _roleLabelOf(role, labels),
          },
          projectName: projectName,
          versionLine: versionLine,
          pageTitle: chunks.length > 1
              ? "${labels.documentTitle} (${chunkIndex + 1}/${chunks.length})"
              : labels.documentTitle,
          days: chunk,
          table: table,
          isLastChunk: chunkIndex == chunks.length - 1,
        ),
      );
    }

    return pdfDocument.save();
  }

  /// The [OcptScriptPagePainter] every page is drawn through, sharing this session's font cache.
  Future<OcptScriptPagePainter> _painterFor(OcptPageSetup pageSetup) async =>
      OcptScriptPagePainter(metrics: pageSetup.toMetrics(), fonts: await fontsLoader.load());

  /// [plan]'s own cast, in role-number order — the order the rows are drawn in, and the order the
  /// shot list, the call sheets and the shooting plan already list a cast in. Sorted on a copy: the
  /// snapshot's own list is shared with every other reader of it.
  List<OcptRole> _orderedRolesOf(OcptSchedulePlanSnapshot plan) =>
      [...plan.roles]..sort((a, b) => a.number.compareTo(b.number));

  /// [role]'s own printable label — `<number> · <name>`, the same shape
  /// `OcptShootingPlanPdfService`'s own crew-and-cast grid gives a role's row, falling back to
  /// [OcptDayOutOfDaysLabels.unnamedRoleLabel] while the part carries no name.
  String _roleLabelOf(OcptRole role, OcptDayOutOfDaysLabels labels) {
    final name = role.name.trim();
    return "${role.number} · ${name.isEmpty ? labels.unnamedRoleLabel : name}";
  }

  // ---------------------------------------------------------------------------------------------
  // Pages
  // ---------------------------------------------------------------------------------------------

  /// The document's own title page: its name, the `"<title>" de <director>` line, and the moment the
  /// export was run.
  pw.Page _titlePage({
    required OcptScriptPagePainter painter,
    required OcptDayOutOfDaysLabels labels,
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

  /// A single-note landscape page: the running head, the document's own title, then [text] alone —
  /// what a range with no live day, or one convoking nobody, prints in place of its table.
  pw.MultiPage _notePage({
    required OcptScriptPagePainter painter,
    required OcptDayOutOfDaysLabels labels,
    required String projectName,
    required String versionLine,
    required String text,
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
      pw.Text(labels.documentTitle, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt)),
      pw.SizedBox(height: 8),
      pw.Text(text, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
    ],
  );

  /// One landscape table page: the running head, the title, then the table itself — a two-line
  /// column header per day (its tag over its date), one row per role of [table], and the two
  /// trailing count columns.
  ///
  /// The legend is printed under the table on the **last** chunk alone ([isLastChunk]): it explains
  /// the whole document rather than one page of it, and repeating it under every chunk would push
  /// rows off pages a reader has to compare side by side.
  pw.MultiPage _tablePage({
    required OcptScriptPagePainter painter,
    required OcptDayOutOfDaysLabels labels,
    required Map<String, String> roleLabelById,
    required String projectName,
    required String versionLine,
    required String pageTitle,
    required List<OcptShootingDay> days,
    required OcptDayOutOfDaysTable table,
    required bool isLastChunk,
  }) {
    final columnWidths = <int, pw.TableColumnWidth>{0: const pw.FlexColumnWidth(3.2)};
    for (var index = 0; index < days.length; index++) {
      columnWidths[index + 1] = const pw.FlexColumnWidth();
    }
    columnWidths[days.length + 1] = const pw.FlexColumnWidth(1.4);
    columnWidths[days.length + 2] = const pw.FlexColumnWidth(1.4);

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
            // The header repeats across every page this table flows onto: a torn-out or pinned-up
            // sheet has nowhere else to say which day a column belongs to — the rule both other
            // schedule documents already follow.
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                _rowLabelCell(painter: painter, text: labels.roleHeader, isBold: true),
                for (final day in days)
                  _dayHeaderCell(painter: painter, labels: labels, day: day),
                _headerCell(painter: painter, text: labels.workedDaysHeader),
                _headerCell(painter: painter, text: labels.heldDaysHeader),
              ],
            ),
            for (final row in table.rows)
              pw.TableRow(
                children: [
                  // Every row of [table] was built from a [roleLabelById] entry's own role, so the
                  // fallback here is a formality rather than a case this document can reach.
                  _rowLabelCell(painter: painter, text: roleLabelById[row.roleId] ?? labels.unnamedRoleLabel),
                  for (final day in days)
                    _codeCell(painter: painter, labels: labels, code: row.codeOf(day.id)),
                  _countCell(painter: painter, value: row.workedDayCount),
                  _countCell(painter: painter, value: row.heldDayCount),
                ],
              ),
          ],
        ),
        if (isLastChunk) ...[
          pw.SizedBox(height: 12),
          _legend(painter: painter, labels: labels),
        ],
      ],
    );
  }

  /// The legend printed under the last chunk of the table: one line per code, its own letter then
  /// what it means — the document is read by people who never asked for its conventions, and a grid
  /// of two-letter codes with nothing to read them by is a grid of two-letter codes.
  pw.Widget _legend({required OcptScriptPagePainter painter, required OcptDayOutOfDaysLabels labels}) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        labels.legendSectionTitle.toUpperCase(),
        style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt, color: _mutedColor),
      ),
      pw.SizedBox(height: 2),
      for (final code in OcptDayOutOfDaysCode.values)
        pw.Text(
          "${labels.codeLabelOf(code)} — ${labels.codeDescriptionOf(code)}",
          style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
        ),
    ],
  );

  // ---------------------------------------------------------------------------------------------
  // Cells
  // ---------------------------------------------------------------------------------------------

  /// One day's own column header: its day tag over its short date, the date muted under it.
  pw.Widget _dayHeaderCell({
    required OcptScriptPagePainter painter,
    required OcptDayOutOfDaysLabels labels,
    required OcptShootingDay day,
  }) {
    final date = labels.dateOfDay(day.id);

    return pw.Padding(
      padding: const pw.EdgeInsets.all(_cellPaddingPt),
      child: pw.Column(
        children: [
          pw.Text(
            "${labels.dayTagPrefix}${day.dayNumber}",
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt),
          ),
          if (date.isNotEmpty)
            pw.Text(
              date,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
            ),
        ],
      ),
    );
  }

  /// One of the two trailing count columns' own header.
  pw.Widget _headerCell({required OcptScriptPagePainter painter, required String text}) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt),
    ),
  );

  /// A row's own leading label cell (a role, or the table's own corner header).
  pw.Widget _rowLabelCell({
    required OcptScriptPagePainter painter,
    required String text,
    bool isBold = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      text,
      style: pw.TextStyle(font: painter.fonts.variant(bold: isBold, italic: false), fontSize: _bodyFontSizePt),
    ),
  );

  /// One code cell: [code]'s own letter, or a **truly empty** cell outside the role's own span —
  /// never [ocptScheduleEmptyValue], which everywhere else in this app's schedule exports means "a
  /// value that has none". A day before a role joins the shoot is not a missing figure; it is a day
  /// this document deliberately says nothing about.
  pw.Widget _codeCell({
    required OcptScriptPagePainter painter,
    required OcptDayOutOfDaysLabels labels,
    required OcptDayOutOfDaysCode? code,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      code == null ? "" : labels.codeLabelOf(code),
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt),
    ),
  );

  /// One trailing count cell — a figure the whole printed range answers for, never the chunk's own
  /// (the class doc comment).
  pw.Widget _countCell({required OcptScriptPagePainter painter, required int value}) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      "$value",
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt),
    ),
  );

  // ---------------------------------------------------------------------------------------------
  // Small shared drawing helpers
  // ---------------------------------------------------------------------------------------------

  /// The running head naming the project and the document on the left, [versionLine] on the right,
  /// over a thin rule — handed to every page's own `header:` callback rather than to its `build:`
  /// list, for the reason `OcptShootingPlanPdfService._runningHead`'s own doc comment gives: a
  /// `build:` child is drawn once per flow, a `header:` one on every page that flow overflows onto.
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

  /// The portrait `pdf` page format the title page is drawn on — the same margin convention every
  /// other schedule export uses (`marginRightPt` standing in for the bottom margin too,
  /// [OcptScriptPagePainter] having none of its own).
  PdfPageFormat _portraitPageFormat(OcptScriptPagePainter painter) => PdfPageFormat(
    painter.pageWidthPt,
    painter.pageHeightPt,
    marginLeft: painter.marginRightPt,
    marginTop: painter.marginTopPt,
    marginRight: painter.marginRightPt,
    marginBottom: painter.marginRightPt,
  );

  /// The landscape `pdf` page format every table page is drawn on — [painter]'s own width and height
  /// swapped, its margins otherwise read the same way [_portraitPageFormat] does.
  PdfPageFormat _landscapePageFormat(OcptScriptPagePainter painter) => PdfPageFormat(
    painter.pageHeightPt,
    painter.pageWidthPt,
    marginLeft: painter.marginRightPt,
    marginTop: painter.marginTopPt,
    marginRight: painter.marginRightPt,
    marginBottom: painter.marginRightPt,
  );
}

/// [days] split into chunks of at most [chunkSize], in order — empty when [days] itself is. The same
/// rule `OcptShootingPlanPdfService` paginates its own summary grids by, over this document's own
/// day columns and its own [_maxDayColumnsPerPage].
List<List<OcptShootingDay>> _chunkDays(List<OcptShootingDay> days, int chunkSize) {
  if (days.isEmpty) {
    return const [];
  }

  final chunks = <List<OcptShootingDay>>[];
  for (var start = 0; start < days.length; start += chunkSize) {
    final end = start + chunkSize < days.length ? start + chunkSize : days.length;
    chunks.add(days.sublist(start, end));
  }
  return chunks;
}
