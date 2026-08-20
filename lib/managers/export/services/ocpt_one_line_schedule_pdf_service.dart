// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_one_line_schedule_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_effect.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shot_code.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of the title page's own document name.
const double _coverTitleFontSizePt = 24;

/// The font size, in points, of every body line: a day band, a table cell, a note.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head and a day band's own
/// location.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of a day's table and inside a day band.
const double _cellPaddingPt = 4;

/// The colour of the rules every table is drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a day band and of a table's own header row.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The one-line table's `SEQ / EFFET / DÉCOR / RÔLES / DURÉE` columns.
///
/// One shared `const` map for the whole document, unlike a per-day one: every day's own table is a
/// fresh [pw.Table] (a day band restarts it), and a shared map is what keeps a column falling at
/// the same place under whichever day band a reader's eye last passed, down the whole document.
const Map<int, pw.TableColumnWidth> _lineColumnWidths = {
  0: pw.FlexColumnWidth(),
  1: pw.FlexColumnWidth(1.4),
  2: pw.FlexColumnWidth(2.2),
  3: pw.FlexColumnWidth(2.4),
  4: pw.FlexColumnWidth(1.2),
};

/// Renders the one-line schedule: the compact strip schedule a production plans on, one printed
/// line per sequence, in shooting order, over the whole shoot.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings — `OcptDayOutOfDaysPdfService` chief
/// among them, whose own doc comment this one mirrors.
///
/// **Every line comes off the same [ocptOrderedScheduleEntriesOfDay] walk both existing schedule PDF
/// exports already read**, so this document cannot disagree with a call sheet or the shooting plan
/// about what order a shoot's sequences run in. A line is a run of consecutive
/// [OcptShootingBlockKind.shot] blocks on the same slot and the same scene, collapsed exactly as
/// `OcptCallSheetPdfService`'s own `_DayRow.shotRun` folds one, or a single
/// [OcptShootingBlockKind.hold] block, which never folds with anything — see
/// [_buildOneLineRows]'s own doc comment for why every other block kind gives no line at all.
///
/// **The table is landscape** (page width and height swapped from the painter's own geometry) and
/// **one continuous flow across the whole document**, unlike the *Day Out of Days*' own chunked
/// pages: a day band interrupts the flow between two days, but the running head and the column
/// widths carry on unbroken, a shoot being read start to finish rather than compared day against
/// day. **No hours column**: a one-line schedule is read as an order, and the resolved clock a line
/// happens at is the shooting plan's own day agenda — printing it twice would be the two documents
/// disagreeing about which one says when.
class OcptOneLineSchedulePdfService {
  /// Creates an [OcptOneLineSchedulePdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptOneLineSchedulePdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the one-line schedule of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - one-line schedule.pdf`); a blank one falls back to the project name alone, exactly
  /// as `OcptDayOutOfDaysPdfService.dayOutOfDaysFileName` does.
  String oneLineScheduleFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the one-line schedule of [dayIds] (in the order given), returning the PDF's bytes.
  ///
  /// A [dayIds] entry naming no live day of [plan] is silently skipped, exactly as its two sibling
  /// services read a missing day: nothing this app writes can produce one, but a hand-edited file or
  /// a stale selection might. [dayIds] naming no live day at all still produces a readable, one-note
  /// document (plus its title page, when [includeTitlePage] asks for one) rather than an empty file
  /// nobody can open; a live day whose own lines fold down to none prints its own band and
  /// [OcptOneLineScheduleLabels.emptyDayNote] in place of its table, never a bare band.
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
    required OcptOneLineScheduleLabels labels,
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

    if (days.isEmpty) {
      pdfDocument.addPage(
        _notePage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          text: labels.emptyDocumentNote,
        ),
      );
      return pdfDocument.save();
    }

    pdfDocument.addPage(
      _documentPage(
        painter: painter,
        labels: labels,
        projectName: projectName,
        versionLine: versionLine,
        plan: plan,
        days: days,
      ),
    );

    return pdfDocument.save();
  }

  /// The [OcptScriptPagePainter] every page is drawn through, sharing this session's font cache.
  Future<OcptScriptPagePainter> _painterFor(OcptPageSetup pageSetup) async =>
      OcptScriptPagePainter(metrics: pageSetup.toMetrics(), fonts: await fontsLoader.load());

  // ---------------------------------------------------------------------------------------------
  // Pages
  // ---------------------------------------------------------------------------------------------

  /// The document's own title page: its name, the `"<title>" de <director>` line, and the moment the
  /// export was run.
  pw.Page _titlePage({
    required OcptScriptPagePainter painter,
    required OcptOneLineScheduleLabels labels,
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
  /// what a day range naming no live day at all prints in place of the whole document.
  pw.MultiPage _notePage({
    required OcptScriptPagePainter painter,
    required OcptOneLineScheduleLabels labels,
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
      pw.Text(labels.documentTitle, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt)),
      pw.SizedBox(height: 8),
      pw.Text(text, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
    ],
  );

  /// The document's own single continuous flow: every one of [days], in order, as its own band
  /// followed by its own table (or [OcptOneLineScheduleLabels.emptyDayNote] while it holds no line)
  /// — one [pw.MultiPage] rather than one page per day, so the running head and the shared
  /// [_lineColumnWidths] carry on unbroken from the last line of one day to the first of the next.
  pw.MultiPage _documentPage({
    required OcptScriptPagePainter painter,
    required OcptOneLineScheduleLabels labels,
    required String projectName,
    required String versionLine,
    required OcptSchedulePlanSnapshot plan,
    required List<OcptShootingDay> days,
  }) {
    final children = <pw.Widget>[];

    for (final (index, day) in days.indexed) {
      if (index > 0) {
        children.add(pw.SizedBox(height: 10));
      }

      children.add(_dayBand(painter: painter, labels: labels, plan: plan, day: day));
      children.add(pw.SizedBox(height: 4));

      final rows = _buildOneLineRows(
        plan: plan,
        orderedEntries: ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: day.id),
      );

      children.add(
        rows.isEmpty
            ? _noteWidget(painter: painter, text: labels.emptyDayNote)
            : _dayTable(painter: painter, labels: labels, plan: plan, rows: rows),
      );
    }

    return pw.MultiPage(
      pageFormat: _landscapePageFormat(painter),
      header: (context) => _runningHead(
        painter: painter,
        projectName: projectName,
        documentTitle: labels.documentTitle,
        versionLine: versionLine,
      ),
      build: (context) => children,
    );
  }

  /// One day's own full-width band: its tag over its number, its own title, then its first live
  /// slot's own location (or [OcptOneLineScheduleLabels.noLocationLabel] while it has none).
  pw.Widget _dayBand({
    required OcptScriptPagePainter painter,
    required OcptOneLineScheduleLabels labels,
    required OcptSchedulePlanSnapshot plan,
    required OcptShootingDay day,
  }) {
    final location = plan.firstLocationOfDay(day.id);

    return pw.Container(
      constraints: const pw.BoxConstraints(minWidth: double.infinity),
      decoration: const pw.BoxDecoration(color: _bandColor),
      padding: const pw.EdgeInsets.all(_cellPaddingPt),
      child: pw.Row(
        children: [
          pw.Text(
            "${labels.dayTagPrefix}${day.dayNumber}",
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(
              labels.titleOfDay(day.id),
              style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
            ),
          ),
          pw.Text(
            location?.name ?? labels.noLocationLabel,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
      ),
    );
  }

  /// One day's own table: a `SEQ / EFFET / DÉCOR / RÔLES / DURÉE` header, then one row per
  /// [_OneLineRow] of [rows].
  ///
  /// **The header repeats on every one of this table's own pages, and it is drawn once per day
  /// rather than once for the whole document**: a day band restarts the flow into a fresh
  /// [pw.Table], and a torn-out page from the middle of a long shoot has nowhere else to say which
  /// column is which — the same rule every other schedule export follows for its own tables.
  pw.Widget _dayTable({
    required OcptScriptPagePainter painter,
    required OcptOneLineScheduleLabels labels,
    required OcptSchedulePlanSnapshot plan,
    required List<_OneLineRow> rows,
  }) => pw.Table(
    border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
    columnWidths: _lineColumnWidths,
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _bandColor),
        children: [
          for (final header in [
            labels.seqHeader,
            labels.effectHeader,
            labels.decorHeader,
            labels.rolesHeader,
            labels.durationHeader,
          ])
            _textCell(painter: painter, text: header, isBold: true),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          children: [
            _textCell(painter: painter, text: _sceneNumberOf(plan, row)),
            _textCell(painter: painter, text: _effectOf(plan, row)),
            _textCell(painter: painter, text: row.decor ?? ocptScheduleEmptyValue),
            _textCell(painter: painter, text: _rolesLabelOf(row, plan.roles)),
            _textCell(painter: painter, text: _durationLabelOf(row)),
          ],
        ),
    ],
  );

  // ---------------------------------------------------------------------------------------------
  // Small shared drawing helpers
  // ---------------------------------------------------------------------------------------------

  /// A line of plain text, printed in place of a day's own table while it holds none.
  pw.Widget _noteWidget({required OcptScriptPagePainter painter, required String text}) =>
      pw.Text(text, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt));

  /// One table cell holding [text].
  pw.Widget _textCell({required OcptScriptPagePainter painter, required String text, bool isBold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(_cellPaddingPt),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: painter.fonts.variant(bold: isBold, italic: false), fontSize: _bodyFontSizePt),
        ),
      );

  /// The running head naming the project and the document on the left, [versionLine] on the right,
  /// over a thin rule — handed to every page's own `header:` callback rather than to its `build:`
  /// list, so a day flowing past a page break still names the document and the moment it was
  /// produced, exactly as every other schedule export's own running head does.
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

// ===================================================================================================
// Pure data-preparation types and functions — no `pw.Widget` in sight, so a future test can exercise
// them directly if it ever needs to.
// ===================================================================================================

/// One printed line: a run of one or more consecutive [OcptShootingBlockKind.shot] blocks on the
/// same slot and the same scene, collapsed exactly as `OcptCallSheetPdfService`'s own
/// `_DayRow.shotRun` folds one ([shots] non-empty), or a single [OcptShootingBlockKind.hold] block,
/// which never folds with anything ([shots] always empty for one). See [_buildOneLineRows]'s own
/// doc comment for why every other block kind gives no line at all.
class _OneLineRow {
  _OneLineRow._({
    required this.slotId,
    required this.sceneId,
    required this.decor,
    required this.shots,
    required this.startMinute,
    required this.endMinute,
  });

  /// Builds a row starting a new run of shot blocks.
  factory _OneLineRow.shotRun({
    required String slotId,
    required String? sceneId,
    required String? decor,
    required OcptShot shot,
    required int startMinute,
    required int endMinute,
  }) => _OneLineRow._(
    slotId: slotId,
    sceneId: sceneId,
    decor: decor,
    shots: [shot],
    startMinute: startMinute,
    endMinute: endMinute,
  );

  /// Builds a row for a single hold block, reserving [sceneId] (or naming no sequence at all).
  factory _OneLineRow.hold({
    required String slotId,
    required String? sceneId,
    required String? decor,
    required int startMinute,
    required int endMinute,
  }) => _OneLineRow._(
    slotId: slotId,
    sceneId: sceneId,
    decor: decor,
    shots: const [],
    startMinute: startMinute,
    endMinute: endMinute,
  );

  /// The slot this row's blocks were placed on.
  final String slotId;

  /// The scene this row's shots belong to, or the hold's own reserved scene — null for an orphaned
  /// shot or a hold naming no sequence yet.
  final String? sceneId;

  /// The name of the set this row's slot is shot at, or null.
  final String? decor;

  /// The shots collapsed into this row — always exactly one until a following shot of the same
  /// scene, on the same slot, is appended to it; always empty for a hold.
  final List<OcptShot> shots;

  /// Where this row starts, resolved.
  final int startMinute;

  /// Where this row ends, resolved — mutable so a following collapsed shot can extend it.
  int endMinute;

  /// Whether this is a hold row rather than a run of shot blocks.
  bool get isHold => shots.isEmpty;
}

/// Turns [orderedEntries] into the printed lines of [plan]'s own day: a run of consecutive
/// [OcptShootingBlockKind.shot] blocks on the same slot and the same scene collapses into one
/// [_OneLineRow], a [OcptShootingBlockKind.hold] block prints its own row and never folds with
/// anything, and **every other block kind gives no line at all**.
///
/// A one-line schedule is a schedule of sequences, and a [OcptShootingBlockKind.preparation],
/// [OcptShootingBlockKind.hairMakeUp], [OcptShootingBlockKind.meal], [OcptShootingBlockKind.pause],
/// [OcptShootingBlockKind.travel] or [OcptShootingBlockKind.wrap] block is not one — a meal break is
/// not a sequence, and the mode's own strip agenda, which this document prints, shows shot chips
/// alone. Mirrors `OcptCallSheetPdfService`'s own `_buildDayRows`, so the two documents cannot
/// disagree about what one printed line is.
List<_OneLineRow> _buildOneLineRows({
  required OcptSchedulePlanSnapshot plan,
  required List<OcptOrderedScheduleEntry> orderedEntries,
}) {
  final rows = <_OneLineRow>[];

  for (final ordered in orderedEntries) {
    final block = ordered.block;
    final entry = ordered.entry;
    final slot = ordered.slot;
    final decor = slot.setId == null ? null : plan.setById[slot.setId]?.name;

    if (block.kind == OcptShootingBlockKind.shot) {
      final shot = block.shotId == null ? null : plan.shotById(block.shotId!);
      if (shot == null) {
        continue;
      }

      final last = rows.isNotEmpty ? rows.last : null;
      if (last != null &&
          !last.isHold &&
          last.slotId == slot.id &&
          shot.sceneId != null &&
          last.sceneId == shot.sceneId) {
        last.shots.add(shot);
        last.endMinute = entry.endMinute;
        continue;
      }

      rows.add(
        _OneLineRow.shotRun(
          slotId: slot.id,
          sceneId: shot.sceneId,
          decor: decor,
          shot: shot,
          startMinute: entry.startMinute,
          endMinute: entry.endMinute,
        ),
      );
      continue;
    }

    if (block.kind == OcptShootingBlockKind.hold) {
      rows.add(
        _OneLineRow.hold(
          slotId: slot.id,
          sceneId: block.sceneId,
          decor: decor,
          startMinute: entry.startMinute,
          endMinute: entry.endMinute,
        ),
      );
    }
  }

  return rows;
}

/// [row]'s own `SEQ` cell: [OcptSchedulePlanSnapshot.sceneNumberBySceneId]'s reading of its scene,
/// falling back to [ocptShotSceneNumberOf] for an orphaned shot (a null scene id but a non-empty
/// [_OneLineRow.shots]), and to [ocptScheduleEmptyValue] for a hold naming no sequence, or one whose
/// sequence this snapshot cannot name (nothing this app writes reaches that case; a hand-edited file
/// might).
String _sceneNumberOf(OcptSchedulePlanSnapshot plan, _OneLineRow row) {
  final sceneId = row.sceneId;
  if (sceneId != null) {
    return plan.sceneNumberBySceneId[sceneId] ?? ocptScheduleEmptyValue;
  }
  return row.isHold ? ocptScheduleEmptyValue : ocptShotSceneNumberOf(row.shots.first);
}

/// [row]'s own `DURÉE` cell: the **span its resolved blocks occupy**, from the start of its first to
/// the end of its last, written through [ocptFormatMinuteDuration].
///
/// It is the time the plan **reserves** for that sequence, never a shot's own
/// `OcptShot.estimatedDurationMs`, which estimates how long the shot runs on screen rather than how
/// long it takes to get. And it is the run's span rather than the sum of its blocks' own durations:
/// the two differ only when a pinned anchor leaves a gap in the middle of a folded run, and a
/// sequence a day holds its slot busy with from 09:00 to 11:00 has cost that unit two hours whatever
/// happened in the gap — which is the figure a production reads this column for.
String _durationLabelOf(_OneLineRow row) => ocptFormatMinuteDuration(row.endMinute - row.startMinute);

/// [row]'s own `EFFET` cell: [ocptSceneEffectOf]'s reading of its scene's heading, read off
/// [OcptSchedulePlanSnapshot.headingBySceneId] exactly as `OcptCallSheetPdfService`'s own `EFFET`
/// column reads it — the two documents must not read a heading differently.
String _effectOf(OcptSchedulePlanSnapshot plan, _OneLineRow row) {
  final sceneId = row.sceneId;
  final heading = sceneId == null ? null : plan.headingBySceneId[sceneId];
  return ocptSceneEffectOf(heading).printedEffect ?? ocptScheduleEmptyValue;
}

/// [row]'s own `RÔLES` cell: the role numbers of every role whose character is in one of [row]'s
/// own [_OneLineRow.shots], among [roles] — matched through `normalizeCharacterName`, the exact join
/// `OcptCallSheetPdfService`'s own `_rolesLabelOf` makes.
///
/// **A hold row always answers [ocptScheduleEmptyValue]**: nothing in the manager layer says which
/// roles a sequence not yet shot-listed calls for — the day view's own reading of that comes from
/// the breakdown, which is not among this document's reads — and guessing would put a part on a
/// page nobody entered.
String _rolesLabelOf(_OneLineRow row, List<OcptRole> roles) {
  if (row.isHold) {
    return ocptScheduleEmptyValue;
  }

  final characterNames = <String>{for (final shot in row.shots) ...shot.characters};
  if (characterNames.isEmpty) {
    return ocptScheduleEmptyValue;
  }

  final byNormalizedName = {for (final role in roles) normalizeCharacterName(role.name): role};
  final matched = <OcptRole>{};
  for (final name in characterNames) {
    final role = byNormalizedName[name];
    if (role != null) {
      matched.add(role);
    }
  }

  if (matched.isEmpty) {
    return ocptScheduleEmptyValue;
  }

  final sorted = matched.toList()..sort((a, b) => a.number.compareTo(b.number));
  return sorted.map((role) => "${role.number}").join(", ");
}
