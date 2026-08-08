// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
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

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// How many slot columns one page of a summary grid holds before the rest carries on, chunked, onto
/// the next one — a grid silently printing only its first few days is worse than one that runs on.
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

/// Renders the whole shoot's own shooting plan: an optional title page, the three summary grids —
/// locations, sequences, crew and cast, each crossing every printed day's own slots — and then one
/// detailed agenda per day, hour by hour.
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
/// **The three summary grids are landscape** (page width and height swapped from the painter's own
/// geometry): a shoot is wide, and a grid silently cropped to whatever a portrait page holds would
/// be worse than one that runs the columns on. Their own columns are **one per slot, grouped under
/// its day** — a decision already taken (`docs/plans/schedule-mode.md` §4.2): the reference
/// document's own day-parts are exactly what a slot is in this app. When more columns exist than
/// [_maxGridColumnsPerPage] holds, a grid's own rows repeat over as many chunked pages as it takes;
/// the detailed day agendas that follow stay portrait, so one document mixes both orientations.
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
    final dayGroups = _dayColumnGroupsOf(plan, resolvedDayIds);
    final columns = _flattenColumns(dayGroups);
    final chunks = _chunkColumns(columns, _maxGridColumnsPerPage);

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
        rows: _locationsGridRows(plan: plan, columns: columns, labels: labels),
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
        rows: _sequencesGridRows(plan: plan, columns: columns, labels: labels),
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
        rows: _peopleGridRows(plan: plan, columns: columns, labels: labels),
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
    build: (context) => [
      _runningHead(
          painter: painter,
          projectName: projectName,
          documentTitle: labels.documentTitle,
          versionLine: versionLine,
        ),
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
    required List<List<_GridColumnRef>> chunks,
    required List<_GridRow> rows,
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
    build: (context) => [
      _runningHead(
          painter: painter,
          projectName: projectName,
          documentTitle: labels.documentTitle,
          versionLine: versionLine,
        ),
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
    required List<_GridColumnRef> columns,
    required List<_GridRow> rows,
  }) {
    final columnWidths = <int, pw.TableColumnWidth>{0: const pw.FlexColumnWidth(2.4)};
    for (var index = 0; index < columns.length; index++) {
      columnWidths[index + 1] = const pw.FlexColumnWidth();
    }

    return pw.MultiPage(
      pageFormat: _landscapePageFormat(painter),
      build: (context) => [
        _runningHead(
          painter: painter,
          projectName: projectName,
          documentTitle: labels.documentTitle,
          versionLine: versionLine,
        ),
        pw.SizedBox(height: 6),
        pw.Text(pageTitle, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                _gridCornerCell(painter: painter),
                for (final (index, column) in columns.indexed)
                  _gridHeaderCell(
                    painter: painter,
                    text: (index == 0 || columns[index - 1].day.id != column.day.id)
                        ? "${labels.dayTagPrefix}${column.day.dayNumber}"
                        : "",
                  ),
              ],
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                _gridRowLabelCell(painter: painter, text: rowHeaderLabel, isBold: true),
                for (final column in columns)
                  _gridHeaderCell(
                    painter: painter,
                    text: column.slot.label.trim().isEmpty ? ocptScheduleEmptyValue : column.slot.label.trim(),
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
                  for (final column in columns)
                    _gridDataCell(painter: painter, text: row.valueOf(column), isMuted: row.isMuted),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// A grid's own blank top-left corner cell.
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
  /// to this slot" (a location's row against a slot shot somewhere else), not a missing value, so it
  /// prints truly empty rather than substituting [ocptScheduleEmptyValue].
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

  /// The locations grid's own rows: two per location referenced anywhere in [columns] — its own
  /// name (marking, in each of its own slot columns, the set shot there or [OcptShootingPlanLabels
  /// .presenceMark] when none was chosen) and, nested under it, [OcptShootingPlanLabels.persoLabel]
  /// naming who is present.
  List<_GridRow> _locationsGridRows({
    required OcptSchedulePlanSnapshot plan,
    required List<_GridColumnRef> columns,
    required OcptShootingPlanLabels labels,
  }) {
    final seenLocationIds = <String>{};
    final locationIds = <String>[];
    for (final column in columns) {
      final locationId = column.slot.locationId;
      if (locationId == null || !seenLocationIds.add(locationId)) {
        continue;
      }
      locationIds.add(locationId);
    }

    final rows = <_GridRow>[];
    for (final locationId in locationIds) {
      final location = plan.locationById[locationId];
      final name = location == null || location.name.trim().isEmpty ? ocptScheduleEmptyValue : location.name.trim();

      rows.add(
        _GridRow(
          label: name,
          isBold: true,
          valueOf: (column) {
            if (column.slot.locationId != locationId) {
              return "";
            }
            final setId = column.slot.setId;
            final setName = setId == null ? null : plan.setById[setId]?.name.trim();
            return (setName != null && setName.isNotEmpty) ? setName : labels.presenceMark;
          },
        ),
      );
      rows.add(
        _GridRow(
          label: labels.persoLabel,
          isIndented: true,
          isMuted: true,
          valueOf: (column) {
            if (column.slot.locationId != locationId) {
              return "";
            }
            return _slotPersonFirstNames(plan, column.slot).join(", ");
          },
        ),
      );
    }
    return rows;
  }

  /// The sequences grid's own rows: one per sequence with at least one shot placed anywhere in
  /// [columns], in screenplay order, its cell listing the shot ranks covered in that slot.
  List<_GridRow> _sequencesGridRows({
    required OcptSchedulePlanSnapshot plan,
    required List<_GridColumnRef> columns,
    required OcptShootingPlanLabels labels,
  }) {
    final dayIds = <String>{for (final column in columns) column.day.id};
    final shotsBySceneIdBySlotId = <String, Map<String, List<OcptShot>>>{};

    for (final dayId in dayIds) {
      for (final ordered in ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: dayId)) {
        if (ordered.block.kind != OcptShootingBlockKind.shot || ordered.block.shotId == null) {
          continue;
        }
        final shot = plan.shotById(ordered.block.shotId!);
        if (shot == null || shot.sceneId == null) {
          continue;
        }
        ((shotsBySceneIdBySlotId[shot.sceneId!] ??= <String, List<OcptShot>>{})[ordered.slot.id] ??= <OcptShot>[])
            .add(shot);
      }
    }

    final sequencesBySceneId = {
      for (final sequence in plan.shotList?.sequences ?? const [])
        if (sequence is OcptSceneShotSequence) sequence.sceneId: sequence,
    };

    final rows = <_GridRow>[];
    for (final sequence in sequencesBySceneId.values) {
      final bySlotId = shotsBySceneIdBySlotId[sequence.sceneId];
      if (bySlotId == null || bySlotId.isEmpty) {
        continue;
      }
      rows.add(
        _GridRow(
          label: "${labels.sequenceRowPrefix} ${sequence.displaySceneNumber}",
          isBold: true,
          valueOf: (column) {
            final shots = bySlotId[column.slot.id];
            if (shots == null || shots.isEmpty) {
              return "";
            }
            final ranks = shots.map(ocptShotRankOf).toList()..sort();
            return ranks.join(",");
          },
        ),
      );
    }
    return rows;
  }

  /// The crew and cast grid's own rows: one per crew position actually held anywhere in [columns],
  /// in catalogue order, then one per role convoked anywhere in [columns], in role-number order —
  /// a position's cell names who holds it, a role's cell names its actor or, uncast,
  /// [OcptShootingPlanLabels.presenceMark].
  List<_GridRow> _peopleGridRows({
    required OcptSchedulePlanSnapshot plan,
    required List<_GridColumnRef> columns,
    required OcptShootingPlanLabels labels,
  }) {
    final heldPositionIds = <String>{};
    final castRoleIds = <String>{};
    for (final column in columns) {
      for (final member in column.slot.crew) {
        if (member.positionId.isNotEmpty) {
          heldPositionIds.add(member.positionId);
        }
      }
      for (final member in column.slot.cast) {
        castRoleIds.add(member.roleId);
      }
    }

    final rows = <_GridRow>[];
    for (final position in ocptCrewPositions) {
      if (!heldPositionIds.contains(position.id)) {
        continue;
      }
      rows.add(
        _GridRow(
          label: labels.crewPositionLabelOf(position.id),
          isBold: true,
          valueOf: (column) {
            final names = <String>{};
            for (final member in column.slot.crew) {
              if (member.positionId != position.id) {
                continue;
              }
              final first = plan.personById[member.personId]?.firstName.trim();
              if (first != null && first.isNotEmpty) {
                names.add(first);
              }
            }
            final sorted = names.toList()..sort();
            return sorted.join(", ");
          },
        ),
      );
    }

    final orderedRoles = [for (final role in plan.roles) if (castRoleIds.contains(role.id)) role]
      ..sort((a, b) => a.number.compareTo(b.number));
    for (final role in orderedRoles) {
      rows.add(
        _GridRow(
          label: "${role.number} · ${role.name}",
          valueOf: (column) {
            if (!column.slot.cast.any((member) => member.roleId == role.id)) {
              return "";
            }
            final actorFirstName = role.personId == null ? null : plan.personById[role.personId]?.firstName.trim();
            return (actorFirstName != null && actorFirstName.isNotEmpty) ? actorFirstName : labels.presenceMark;
          },
        ),
      );
    }
    return rows;
  }

  /// Every distinct first name of a person linked to [slot], crew and cast alike (a cast role's
  /// actor read through `roles.personId`), sorted.
  List<String> _slotPersonFirstNames(OcptSchedulePlanSnapshot plan, OcptShootingSlot slot) {
    final names = <String>{};
    for (final member in slot.crew) {
      final first = plan.personById[member.personId]?.firstName.trim();
      if (first != null && first.isNotEmpty) {
        names.add(first);
      }
    }
    for (final member in slot.cast) {
      final role = plan.roleById[member.roleId];
      final personId = role?.personId;
      final first = personId == null ? null : plan.personById[personId]?.firstName.trim();
      if (first != null && first.isNotEmpty) {
        names.add(first);
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
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
      build: (context) => [
        _runningHead(
          painter: painter,
          projectName: projectName,
          documentTitle: labels.documentTitle,
          versionLine: versionLine,
        ),
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
  // Small shared drawing helpers
  // ---------------------------------------------------------------------------------------------

  /// The running head naming the project and the document on the left, [versionLine] on the right,
  /// over a thin rule — the same shape `OcptCallSheetPdfService._page` draws inline, factored out
  /// here since every page kind of this service (title, grid, day agenda, note) opens with it.
  ///
  /// The version line is repeated on **every** page rather than on the title page alone: a shooting
  /// plan is read page by page, a day agenda torn out of it or a landscape grid pinned on a wall,
  /// and a reader holding one sheet of it has nowhere else to find out which issue they are working
  /// from.
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
// Pure data-preparation types and functions — no `pw.Widget` in sight, so a future test can exercise
// them directly if it ever needs to.
// ===================================================================================================

/// One live day contributing columns to the three summary grids: its own slots, in order — a day
/// with no live slot at all contributes none, [_dayColumnGroupsOf] never producing an empty group.
class _DayColumnGroup {
  const _DayColumnGroup({required this.day, required this.slots});

  /// The day these [slots] belong to.
  final OcptShootingDay day;

  /// This day's own live slots, in `sortKey` order.
  final List<OcptShootingSlot> slots;
}

/// One column of a summary grid: a slot, and the day it belongs to (so a grid page can print the
/// day tag once above the first column of its own group).
class _GridColumnRef {
  const _GridColumnRef({required this.day, required this.slot});

  /// The day [slot] belongs to.
  final OcptShootingDay day;

  /// The slot this column is about.
  final OcptShootingSlot slot;
}

/// One row of a summary grid: its own leading label and how to read its value out of one column.
class _GridRow {
  const _GridRow({
    required this.label,
    required this.valueOf,
    this.isBold = false,
    this.isMuted = false,
    this.isIndented = false,
  });

  /// This row's own leading label (a location's name, a sequence's own tag, a position's or a
  /// role's own label).
  final String label;

  /// This row's own value at [_GridColumnRef], or the empty string when nothing applies to that
  /// slot — never [ocptScheduleEmptyValue], see [OcptShootingPlanPdfService._gridDataCell]'s own doc
  /// comment for why.
  final String Function(_GridColumnRef column) valueOf;

  /// Whether [label] is printed bold — a location's or a sequence's own name, a crew position.
  final bool isBold;

  /// Whether this row's own cells are printed muted — the locations grid's own nested `Perso.` row.
  final bool isMuted;

  /// Whether [label] is printed indented — the locations grid's own nested `Perso.` row.
  final bool isIndented;
}

/// Every live day of [dayIds] that carries at least one live slot, in the order given — a day with
/// none contributes no column to a summary grid at all.
List<_DayColumnGroup> _dayColumnGroupsOf(OcptSchedulePlanSnapshot plan, List<String> dayIds) {
  final groups = <_DayColumnGroup>[];
  for (final dayId in dayIds) {
    final day = plan.schedule.daysById[dayId];
    if (day == null) {
      continue;
    }
    final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    if (slots.isEmpty) {
      continue;
    }
    groups.add(_DayColumnGroup(day: day, slots: slots));
  }
  return groups;
}

/// [groups] flattened into one column per slot, in order — the decision taken for this app: a
/// summary grid's own columns are one per slot, grouped under its day.
List<_GridColumnRef> _flattenColumns(List<_DayColumnGroup> groups) => [
  for (final group in groups)
    for (final slot in group.slots) _GridColumnRef(day: group.day, slot: slot),
];

/// [columns] split into chunks of at most [chunkSize], in order — empty when [columns] itself is.
List<List<_GridColumnRef>> _chunkColumns(List<_GridColumnRef> columns, int chunkSize) {
  if (columns.isEmpty) {
    return const [];
  }

  final chunks = <List<_GridColumnRef>>[];
  for (var start = 0; start < columns.length; start += chunkSize) {
    final end = start + chunkSize < columns.length ? start + chunkSize : columns.length;
    chunks.add(columns.sublist(start, end));
  }
  return chunks;
}
