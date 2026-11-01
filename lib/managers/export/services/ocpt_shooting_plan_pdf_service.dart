// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts_loader.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_day_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_grid_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_page_parts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_style.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_time_grid_sections.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:pdf/widgets.dart' as pw;

/// Render the whole shoot's own shooting plan: an optional title page, the four summary grids —
/// locations, sequences, crew and cast, each crossing every printed day's own slots, and the
/// elements grid crossing every printed **day** instead — and then one detailed agenda per day,
/// hour by hour.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()`, exactly like its siblings — `OcptCallSheetPdfService` chief among them,
/// whose own doc comment this one mirrors. It prints no screenplay, so it draws nothing through
/// [OcptScriptPagePainter]'s absolutely positioned page builders and flows its content in
/// [pw.MultiPage]s instead, exactly as `OcptCallSheetPdfService` and
/// `OcptBreakdownSheetsPdfService` do; it still takes one painter, for the page geometry every
/// export of this app measures a sheet with and the Courier Prime variants all of them print in.
///
/// **Every hour printed comes off [OcptSchedulePlanSnapshot.timelinesOfDay]'s resolved clocks** —
/// never off a stored anchor, never re-derived. A minute may exceed 1440 for a night shoot's small
/// hours, and every figure is printed through `ocptFormatDayMinute`, the one place that ever wraps
/// one back onto a clock face — the same rule `OcptCallSheetPdfService` follows, and the reason the
/// two share `ocpt_schedule_pdf_shared.dart` rather than each reading the schedule its own way. A
/// day agenda's own shot table leads with an **hours column**, the one column the reference
/// document's own table carries no equivalent of, reading the same resolved clock a shot's block
/// was placed on.
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
/// slot is in this app. When more columns exist than [ocptShootingPlanMaxGridColumnsPerPage] holds,
/// a grid's own rows repeat over as many chunked pages as it takes; the detailed day agendas that
/// follow stay portrait, so one document mixes both orientations.
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
/// rather than read off the schedule. [ocptShootingPlanChunkColumns] paginates it by the very same
/// rule the other three grids use, over its own day columns rather than slot ones, so
/// [ocptShootingPlanMaxGridColumnsPerPage] never means two different things depending on which grid
/// asks.
///
/// **Each day's own ten-minute grid** (`includeTenMinuteGrid` on [generate]) is an optional extra
/// page, added right after that day's detailed agenda rather than replacing it: rows every
/// [OcptShootingDayAgendaGrid.stepMinutes] from the day's earliest resolved start to its latest
/// resolved end, one column per slot, a block drawn as a tile and an event as a full-width marker.
/// It is drawn **portrait**, unlike the four summary grids — a whole shoot's own slots run wide
/// across many days, while a single day's own slots are few, exactly the trade this class's own
/// grids paragraphs already argue the other way. The geometry is entirely
/// [OcptShootingDayAgendaGrid.of]'s own; this service only draws it, and only the drawing choices
/// specific to `pdf`'s own `Table` widget belong here — see
/// [OcptShootingPlanTimeGridSections.tenMinuteGridPage]'s own doc comment for the one it has to
/// work around (no cell can span more than one row of a `pw.Table`).
class OcptShootingPlanPdfService extends AbsOcptService {
  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// Create an [OcptShootingPlanPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptShootingPlanPdfService({required super.logger, OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// Get the `.pdf` file name to suggest when exporting the shooting plan of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - shooting plan.pdf`); a blank one falls back to the project name alone, exactly as
  /// `OcptBreakdownSheetsPdfService.sheetsFileName` does.
  String shootingPlanFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Render the shooting plan of [dayIds] (in the order given), returning the PDF's bytes.
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
    final versionLine =
        "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";

    final resolvedDayIds = [
      for (final id in dayIds)
        if (plan.schedule.daysById.containsKey(id)) id,
    ];

    if (includeTitlePage) {
      pdfDocument.addPage(
        _titlePage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
        ),
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
    final chunks = ocptShootingPlanChunkColumns(
      grids.slotColumns,
      ocptShootingPlanMaxGridColumnsPerPage,
    );

    if (includeLocationsGrid) {
      OcptShootingPlanGridSections.addGridPages(
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
      OcptShootingPlanGridSections.addGridPages(
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
      OcptShootingPlanGridSections.addGridPages(
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
      OcptShootingPlanGridSections.addElementsGridPages(
        pdfDocument: pdfDocument,
        painter: painter,
        labels: labels,
        projectName: projectName,
        versionLine: versionLine,
        chunks: ocptShootingPlanChunkColumns(
          grids.dayColumns,
          ocptShootingPlanMaxGridColumnsPerPage,
        ),
        rows: grids.elementsRows,
      );
    }

    for (final dayId in resolvedDayIds) {
      pdfDocument.addPage(
        OcptShootingPlanDaySections.dayAgendaPage(
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
          OcptShootingPlanTimeGridSections.tenMinuteGridPage(
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

  /// Get the [OcptScriptPagePainter] every page is drawn through, sharing this session's font
  /// cache.
  Future<OcptScriptPagePainter> _painterFor(OcptPageSetup pageSetup) async =>
      OcptScriptPagePainter(metrics: pageSetup.toMetrics(), fonts: await fontsLoader.load());

  // ---------------------------------------------------------------------------------------------
  // Title page and empty-document note
  // ---------------------------------------------------------------------------------------------

  /// Build the document's own title page: its name, the `"<title>" de <director>` line, and the
  /// date the
  /// export was run.
  pw.Page _titlePage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
  }) => pw.Page(
    pageFormat: OcptShootingPlanPageParts.portraitPageFormat(painter),
    build: (context) => pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            labels.documentTitle,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: painter.fonts.bold,
              fontSize: ocptShootingPlanCoverTitleFontSizePt,
            ),
          ),
          if (labels.directorLine.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              labels.directorLine,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: painter.fonts.regular,
                fontSize: ocptShootingPlanBodyFontSizePt,
              ),
            ),
          ],
          pw.SizedBox(height: 32),
          pw.Text(
            versionLine,
            style: pw.TextStyle(
              font: painter.fonts.regular,
              fontSize: ocptShootingPlanSmallFontSizePt,
              color: ocptShootingPlanMutedColor,
            ),
          ),
        ],
      ),
    ),
  );

  /// Build a single-note portrait page: the running head, then [text] alone — what a range with no
  /// live
  /// day at all, or an empty grid, prints in place of its own content.
  pw.MultiPage _notePage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required String text,
  }) => pw.MultiPage(
    pageFormat: OcptShootingPlanPageParts.portraitPageFormat(painter),
    header: (context) => OcptShootingPlanPageParts.runningHead(
      painter: painter,
      projectName: projectName,
      documentTitle: labels.documentTitle,
      versionLine: versionLine,
    ),
    build: (context) => [
      pw.SizedBox(height: 6),
      OcptShootingPlanPageParts.noteWidget(painter: painter, text: text),
    ],
  );
}
