// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_script_sides_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_sides_labels.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, every running-head and running-foot line is printed at.
const double _runningTextFontSizePt = 7;

/// The font size, in points, of the note page's own body text — the day plays no scene the
/// screenplay still holds, or a printed day the plan does not hold at all.
const double _noteFontSizePt = 12;

/// The distance, in points, from a page's top physical edge to its own running head.
///
/// Deliberately the same band [OcptScriptPagePainter] prints its own page number in
/// (`_pageNumberTopInches`, private to that file): a reader of a script page already looks there
/// for the page's identity, and a side sitting anywhere else would be read past on the first
/// glance.
const double _runningHeadTopInches = 0.5;

/// The distance, in points, from a page's bottom physical edge to its own running foot.
const double _runningFootBottomInches = 0.5;

/// The width, in inches, the running head keeps clear on its right for the page's own identity.
///
/// The head's two lines share one row, so the left-hand one is bounded to whatever this leaves
/// rather than to the whole printable width: a long day title would otherwise wrap straight under
/// `p. 123` and print two strings on top of one another. Wide enough for the longest thing either
/// presentation puts there (`12 / 34`, or a three-digit screenplay page) at
/// [_runningTextFontSizePt], plus air.
const double _pageIdentityWidthInches = 1.2;

/// The grey the running head and the running foot are printed in — the muted colour every
/// schedule PDF export prints its own small labels in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// Renders a day's own sides: the pages of the screenplay it plays, extracted from the composed
/// script and reprinted through the real screenplay layout — a side is only useful if it looks
/// like the script, so it is a slice of the very typeset the crew already knows, never a
/// re-typeset excerpt.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings. It draws nothing it decides itself:
/// [OcptScriptSidesLayout] says which rows land on which page, [OcptScriptPagePainter] draws the
/// screenplay itself (the same drawing `OcptPdfExportService` and `OcptScenarioCoveragePdfService`
/// produce, from the same composer call and the same metrics, so a side can never disagree with the
/// full script about how a page is laid out), and this service only wraps that drawing in the
/// running head and foot a torn-off booklet page needs to say who and what it is.
class OcptSidesPdfService {
  /// Creates an [OcptSidesPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptSidesPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The Fountain-to-page-layout engine, stateless so one instance is shared across every
  /// [generate] call.
  ///
  /// The very same composer `OcptPdfExportService` and `OcptScenarioCoveragePdfService` use: a
  /// side's own pagination must never drift from the full script's, or a page number printed on one
  /// would name a different page of the other.
  static const FountainScriptComposer _composer = FountainScriptComposer();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the sides of [dayId], within [plan].
  ///
  /// `"<project> - <suffix> - <dayTag>.pdf"`, e.g. `My Movie - sides - D3.pdf`; a blank [labels]'
  /// own [OcptSidesLabels.fileNameSuffix] drops that segment, exactly as its siblings' own suffix
  /// does, and [dayId] naming no live day of [plan] drops the day segment rather than printing a
  /// dangling one. **The day tag is part of the name on purpose, unlike every other schedule
  /// document's own file name**: a call sheet, a shooting plan, a *Day Out of Days* and a one-line
  /// schedule are each produced once for the whole shoot, while a booklet of sides is produced once
  /// **per day** — two of them saved into the same folder without a day tag of their own would
  /// silently overwrite one another.
  String sidesFileName({
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required String projectName,
    required OcptSidesLabels labels,
  }) {
    final suffix = labels.fileNameSuffix.trim();
    final day = plan.schedule.daysById[dayId];

    final parts = [
      projectName,
      if (suffix.isNotEmpty) suffix,
      if (day != null) "${labels.dayTagPrefix}${day.dayNumber}",
    ];

    return "${parts.join(" - ")}.pdf";
  }

  /// Renders [dayId]'s own sides booklet, returning the PDF's bytes.
  ///
  /// [document] is composed with [pageSetup] into the very screenplay layout
  /// [OcptSchedulePlanSnapshot.sceneSpanBySceneId]'s offsets address — a booklet built from any
  /// other text or any other page setup would slice the wrong rows. The day's own scenes come from
  /// [OcptSchedulePlanSnapshot.sceneIdsOfDay], each resolved through
  /// [OcptSchedulePlanSnapshot.sceneSpanBySceneId]; a scene id that map holds nothing for is
  /// skipped rather than crashing the export — nothing this app writes reaches that case (a shot's
  /// own scene is always one the shot list still indexes), but a hand-edited file might name one
  /// that no longer is. **The resulting spans are handed to [OcptScriptSidesLayout.of] exactly as
  /// [OcptSchedulePlanSnapshot.sceneIdsOfDay] yields them, unsorted**: that factory sorts them
  /// itself, and sorting twice would only risk disagreeing with its own reading of "screenplay
  /// order".
  ///
  /// [exportDate] is resolved **once** per document, into the running foot's own version line
  /// (through [ocptScheduleGeneratedAtStamp], the stamp every schedule document of this app
  /// prints); it defaults to the moment this method runs, and is exposed so a test can pin it
  /// rather than racing a midnight rollover — the rule every schedule document of this app already
  /// follows.
  ///
  /// A day whose scenes fold down to no page at all (nothing the screenplay still prints, or
  /// [dayId] naming no live day of [plan]) prints **one** portrait note page carrying the running
  /// head, the day band and [OcptSidesLabels.emptyDayNote] — a readable document a crew can still
  /// open, rather than an empty file nobody can.
  Future<Uint8List> generate({
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required OcptSidesLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required OcptSidesPresentation presentation,
    DateTime? exportDate,
  }) async {
    final metrics = pageSetup.toMetrics();
    final painter = OcptScriptPagePainter(metrics: metrics, fonts: await fontsLoader.load());
    final script = _composer.compose(document: document, metrics: metrics);

    final sceneSpans = [
      for (final sceneId in plan.sceneIdsOfDay(dayId))
        if (plan.sceneSpanBySceneId[sceneId] case final span?) span,
    ];

    final layout = OcptScriptSidesLayout.of(
      script: script,
      sceneSpans: sceneSpans,
      metrics: metrics,
      presentation: presentation,
    );

    final versionLine = "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";
    final pdfDocument = pw.Document();

    if (layout.pages.isEmpty) {
      pdfDocument.addPage(
        _notePage(painter: painter, labels: labels, plan: plan, dayId: dayId, projectName: projectName, versionLine: versionLine),
      );
      return pdfDocument.save();
    }

    for (final (index, sidesPage) in layout.pages.indexed) {
      pdfDocument.addPage(
        // `pageNumber: 0` deliberately silences `OcptScriptPagePainter`'s own page-number
        // annotation (only ever drawn from its 2nd script page onward): that number counts script
        // pages of the document *it* is building, which a booklet's own pages are not — a packed
        // page in particular reproduces no single one at all. This service prints the page's own
        // identity itself, in its own running head, so a reader of either presentation has exactly
        // one place to look for it rather than the painter's own count in one and a made-up one in
        // the other.
        painter.buildScriptPage(
          page: FountainScriptPage(lines: sidesPage.lines),
          pageNumber: 0,
          includeSceneNumbers: includeSceneNumbers,
          overlays: _overlaysFor(
            painter: painter,
            labels: labels,
            plan: plan,
            dayId: dayId,
            projectName: projectName,
            versionLine: versionLine,
            sidesPage: sidesPage,
            pageIndex: index,
            pageCount: layout.pages.length,
          ),
        ),
      );
    }

    return pdfDocument.save();
  }

  /// The running head and running foot drawn over one script page, in the page's own coordinate
  /// system (points from its top-left corner, which is what every geometry accessor of
  /// [OcptScriptPagePainter] returns) — the two lines every torn-off page of this booklet needs to
  /// say which day it belongs to and which issue of it this is.
  List<pw.Widget> _overlaysFor({
    required OcptScriptPagePainter painter,
    required OcptSidesLabels labels,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required String projectName,
    required String versionLine,
    required OcptScriptSidesPage sidesPage,
    required int pageIndex,
    required int pageCount,
  }) => [
    _leftAlignedRunningText(
      painter: painter,
      topPt: _runningHeadTopInches * ocptPdfPointsPerInch,
      text: _dayHeadingOf(labels: labels, plan: plan, dayId: dayId),
      reservedRightInches: _pageIdentityWidthInches,
    ),
    _rightAlignedRunningText(
      painter: painter,
      topPt: _runningHeadTopInches * ocptPdfPointsPerInch,
      text: _pageIdentityOf(labels: labels, sidesPage: sidesPage, pageIndex: pageIndex, pageCount: pageCount),
    ),
    _leftAlignedRunningText(
      painter: painter,
      topPt: painter.pageHeightPt - _runningFootBottomInches * ocptPdfPointsPerInch,
      text: "$projectName — $versionLine",
    ),
  ];

  /// A running-head/running-foot line starting at [painter]'s own left margin, bounded to the
  /// printable width less [reservedRightInches], so a long line wraps inside the page rather than
  /// spilling under whatever else its own row carries.
  ///
  /// The running foot has that row to itself and reserves nothing; the running head shares it with
  /// the page's own identity and reserves [_pageIdentityWidthInches] for it.
  pw.Widget _leftAlignedRunningText({
    required OcptScriptPagePainter painter,
    required double topPt,
    required String text,
    double reservedRightInches = 0,
  }) => pw.Positioned(
    left: painter.marginLeftPt,
    top: topPt,
    child: pw.SizedBox(
      width:
          painter.pageWidthPt -
          painter.marginLeftPt -
          painter.marginRightPt -
          reservedRightInches * ocptPdfPointsPerInch,
      child: pw.Text(text, style: _runningStyle(painter)),
    ),
  );

  /// A running-head line ending at [painter]'s own right margin — the same band the painter's own
  /// page-number annotation is right-aligned into.
  pw.Widget _rightAlignedRunningText({
    required OcptScriptPagePainter painter,
    required double topPt,
    required String text,
  }) => pw.Positioned(
    left: 0,
    top: topPt,
    child: pw.SizedBox(
      width: painter.pageWidthPt - painter.marginRightPt,
      child: pw.Text(text, textAlign: pw.TextAlign.right, style: _runningStyle(painter)),
    ),
  );

  /// The running head's own left-hand line: the document's own title, then the printed day's tag
  /// and — while [OcptSidesLabels.dayTitle] is non-empty — its own title, `" — "`-joined. A day
  /// [plan] does not hold (nothing this app writes reaches that, a stale selection might) prints
  /// the document title alone, never a dangling tag.
  String _dayHeadingOf({
    required OcptSidesLabels labels,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
  }) {
    final day = plan.schedule.daysById[dayId];
    if (day == null) {
      return labels.documentTitle;
    }

    final tag = "${labels.dayTagPrefix}${day.dayNumber}";
    final title = labels.dayTitle.trim();
    return title.isEmpty ? "${labels.documentTitle} · $tag" : "${labels.documentTitle} · $tag — $title";
  }

  /// The running head's own right-hand line: [sidesPage]'s identity. A
  /// [OcptSidesPresentation.scriptPages] page prints the **screenplay's own page number** — the
  /// whole point of a side, since a reader holding one can find the same page in the full script —
  /// and a [OcptSidesPresentation.packed] page, which reproduces no single script page, prints its
  /// own position among the booklet's pages instead, the only honest thing it can say once the
  /// screenplay's own pagination has been given up.
  String _pageIdentityOf({
    required OcptSidesLabels labels,
    required OcptScriptSidesPage sidesPage,
    required int pageIndex,
    required int pageCount,
  }) {
    final scriptPageIndex = sidesPage.scriptPageIndex;
    if (scriptPageIndex != null) {
      return "${labels.scriptPagePrefix} ${scriptPageIndex + 1}";
    }
    return "${pageIndex + 1} / $pageCount";
  }

  /// The shared text style every running-head and running-foot line is drawn with.
  pw.TextStyle _runningStyle(OcptScriptPagePainter painter) =>
      pw.TextStyle(font: painter.fonts.regular, fontSize: _runningTextFontSizePt, color: _mutedColor);

  /// A single portrait note page: the running head and foot exactly as every other page carries
  /// them, then [OcptSidesLabels.emptyDayNote] alone — what a day whose scenes fold down to no page
  /// at all prints in place of the whole booklet, so a readable document still comes out of the
  /// export rather than an empty file nobody can open.
  ///
  /// Drawn on [OcptScriptPagePainter.scriptPageFormat] — the same zero-margin physical sheet every
  /// script page is drawn on — rather than a page format carrying its own margins: every widget
  /// here is a [pw.Positioned] computed from [painter]'s own geometry, which is only ever correct
  /// against a page with no margin of its own to double the offset (the running head/foot helpers
  /// [_leftAlignedRunningText]/[_rightAlignedRunningText] make the very same assumption).
  pw.Page _notePage({
    required OcptScriptPagePainter painter,
    required OcptSidesLabels labels,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required String projectName,
    required String versionLine,
  }) => pw.Page(
    pageFormat: painter.scriptPageFormat,
    build: (context) => pw.Stack(
      children: [
        _leftAlignedRunningText(
          painter: painter,
          topPt: _runningHeadTopInches * ocptPdfPointsPerInch,
          text: _dayHeadingOf(labels: labels, plan: plan, dayId: dayId),
        ),
        _leftAlignedRunningText(
          painter: painter,
          topPt: painter.pageHeightPt - _runningFootBottomInches * ocptPdfPointsPerInch,
          text: "$projectName — $versionLine",
        ),
        pw.Positioned(
          left: painter.marginLeftPt,
          top: painter.marginTopPt,
          // `marginRightPt` stands in for the bottom margin too, the same convention every other
          // schedule export follows — see e.g. `OcptOneLineSchedulePdfService._portraitPageFormat`.
          child: pw.SizedBox(
            width: painter.pageWidthPt - painter.marginLeftPt - painter.marginRightPt,
            height: painter.pageHeightPt - painter.marginTopPt - painter.marginRightPt,
            child: pw.Center(
              child: pw.Text(
                labels.emptyDayNote,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: painter.fonts.regular, fontSize: _noteFontSizePt),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
