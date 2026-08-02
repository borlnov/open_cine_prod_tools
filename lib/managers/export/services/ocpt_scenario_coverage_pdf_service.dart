// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The width, in points, of a coverage bar's own stroke, and of the tick marking where inside a
/// line a covered passage starts or ends.
///
/// Capped by half its lane's pitch at the call site, so a page dense enough to have shrunk its
/// lanes keeps air between two neighbouring bars.
const double _barWidthPt = 2.5;

/// The width, in points, of the stroke a hollow (stale) bar is outlined with.
const double _staleBarStrokePt = 0.5;

/// The width, in points, of the tick drawn inside the text where a covered passage starts or ends
/// mid-line.
const double _tickWidthPt = 1.2;

/// The width, in points, of the cap closing a bar at either end — the horizontal stroke a script
/// supervisor's lining draws there.
///
/// Capped by its lane's pitch at the call site, so a cap never reaches into the neighbouring lane's
/// own bar on a page whose lanes have tightened.
const double _barCapWidthPt = 6;

/// The thickness, in points, of that cap.
const double _barCapThicknessPt = 1.2;

/// The font size, in points, a bar's label is printed at.
const double _labelFontSizePt = 7;

/// The height, in points, of one line of label text: what the label is vertically centred on its
/// bar by.
const double _labelLineHeightPt = _labelFontSizePt * 1.2;

/// The horizontal air, in points, between a bar and the label printed beside it.
const double _labelGapPt = 2;

/// The padding, in points, between a label's text and the edge of the opaque plate it is printed
/// on: what keeps the text legible when the plate lands over a neighbouring bar.
const double _labelPaddingPt = 1.5;

/// The colour of that plate — the paper's own white, so a label reads as printed on the page
/// rather than on whatever it happens to cover.
const PdfColor _labelBackgroundColor = PdfColors.white;

/// The grey an uncovered passage is washed with, behind the text.
///
/// Light enough that 12pt Courier stays perfectly readable through it, dark enough to survive a
/// black-and-white print — which is the whole reason the export marks a gap with a wash rather
/// than with a colour.
const PdfColor _gapWashColor = PdfColor.fromInt(0xFFE4E4E4);

/// The font size, in points, of the legend and summary pages' own heading.
const double _appendixTitleFontSizePt = 16;

/// The font size, in points, of the legend and summary pages' table text.
const double _appendixFontSizePt = 9;

/// The padding, in points, inside one cell of a legend or summary table.
const double _appendixCellPaddingPt = 4;

/// The side, in points, of the colour swatch the legend prints a shot's colour as.
const double _swatchSizePt = 8;

/// The colour of the rules a legend or summary table is drawn with.
const PdfColor _appendixRuleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's header row and of a sequence's separator band.
const PdfColor _appendixHeaderColor = PdfColor.fromInt(0xFFEDEDED);

/// The columns of the legend's tables: the colour swatch, then the shot's label and its three
/// free-text fields.
///
/// Shared by the header table and by every sequence's own table, which is what keeps their columns
/// lined up even though a sequence's separator band splits them into one table each.
const Map<int, pw.TableColumnWidth> _legendColumnWidths = {
  0: pw.FixedColumnWidth(_swatchSizePt + 2 * _appendixCellPaddingPt),
  1: pw.FlexColumnWidth(1.4),
  2: pw.FlexColumnWidth(2),
  3: pw.FlexColumnWidth(2),
  4: pw.FlexColumnWidth(2),
};

/// Renders the scenario coverage of a shot list: the screenplay printed as usual, with a coloured
/// bar in the margin alongside every passage a shot covers, a wash behind every passage no shot
/// covers, and two appendix pages naming the shots and measuring the coverage.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its three siblings.
///
/// It draws nothing it decides itself. [OcptScenarioCoverageLayout] says which bar goes in which
/// lane of which page and which text is uncovered, [OcptScriptPagePainter] draws the screenplay
/// underneath (the same drawing `OcptPdfExportService` produces, from the same composer call and
/// the same metrics), and this service only turns the one into `pdf` widgets on top of the other.
///
/// The document reads: title page, legend, summary, then the annotated screenplay. The two
/// appendices come *before* the body on purpose — the legend is the key to the colours the body is
/// covered in, and a key nobody has read yet is of no use at the back of the document.
class OcptScenarioCoveragePdfService {
  /// Creates an [OcptScenarioCoveragePdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptScenarioCoveragePdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The Fountain-to-page-layout engine, stateless so one instance is shared across every
  /// [generate] call.
  ///
  /// The very same composer `OcptPdfExportService` uses: the coverage bars are placed on the rows
  /// this composer wrapped the screenplay onto, so the two exports must never paginate differently.
  static const FountainScriptComposer _composer = FountainScriptComposer();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the scenario coverage of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the plain screenplay export
  /// (`My Movie - couverture.pdf`); a blank one falls back to the project name alone rather than
  /// producing a file name ending on a dangling separator.
  String coverageFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the scenario coverage of [snapshot] over [document], returning the PDF's bytes.
  ///
  /// [screenplayText] must be the very text [document] was parsed from and [snapshot]'s scenes were
  /// indexed against: a coverage range addresses it by character offset, so a text that has moved
  /// on since would place every bar somewhere else. [pageSetup] supplies the page geometry, and
  /// with it the pagination the bars are placed against.
  ///
  /// [includeSceneNumbers] and [includeTitlePage] behave exactly as they do in the plain screenplay
  /// export; [includeLegendPage] and [includeSummaryPage] toggle the two appendices.
  Future<Uint8List> generate({
    required FountainDocument document,
    required String screenplayText,
    required OcptShotListSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptScenarioCoverageLabels labels,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
    required bool includeLegendPage,
    required bool includeSummaryPage,
  }) async {
    final metrics = pageSetup.toMetrics();
    final painter = OcptScriptPagePainter(metrics: metrics, fonts: await fontsLoader.load());
    final script = _composer.compose(document: document, metrics: metrics);
    final coverage = OcptScenarioCoverageLayout.of(
      script: script,
      snapshot: snapshot,
      screenplayText: screenplayText,
      metrics: metrics,
    );

    final pdfDocument = pw.Document();

    if (includeTitlePage) {
      pdfDocument.addPage(
        painter.buildTitlePage(titlePage: document.titlePage, projectName: projectName),
      );
    }
    if (includeLegendPage) {
      pdfDocument.addPage(_buildLegendPage(coverage: coverage, labels: labels, painter: painter));
    }
    if (includeSummaryPage) {
      pdfDocument.addPage(_buildSummaryPage(coverage: coverage, labels: labels, painter: painter));
    }

    for (var index = 0; index < script.pages.length; index++) {
      final page = script.pages[index];
      final coveragePage = coverage.pages[index];
      pdfDocument.addPage(
        painter.buildScriptPage(
          page: page,
          // Script pages are 1-based for the printed page number, and the very first one is never
          // numbered (professional convention) — the appendices ahead of them are not script pages
          // and never shift that count.
          pageNumber: index + 1,
          includeSceneNumbers: includeSceneNumbers,
          underlays: _gapWidgets(page: page, coveragePage: coveragePage, painter: painter),
          overlays: _barWidgets(page: page, coveragePage: coveragePage, painter: painter),
        ),
      );
    }

    return pdfDocument.save();
  }

  /// The washes drawn behind [page]'s uncovered runs, in the page's own coordinates.
  ///
  /// One rectangle per [OcptCoverageGap], as tall as the row it sits on so two washed rows of the
  /// same paragraph read as one block rather than as a row of stripes.
  List<pw.Widget> _gapWidgets({
    required FountainScriptPage page,
    required OcptScenarioCoveragePage coveragePage,
    required OcptScriptPagePainter painter,
  }) => [
    for (final gap in coveragePage.gaps)
      if (gap.row < page.lines.length)
        pw.Positioned(
          left: painter.columnLeftPt(line: page.lines[gap.row], column: gap.startColumn),
          top: painter.rowTopPt(gap.row),
          child: pw.Container(
            width: (gap.endColumn - gap.startColumn) * painter.columnWidthPt,
            height: painter.lineHeightPt,
            color: _gapWashColor,
          ),
        ),
  ];

  /// The bars, their labels and their ticks, drawn on top of the script [page] [coveragePage]
  /// annotates.
  ///
  /// Every label comes after every bar rather than each one right after its own: a page dense
  /// enough for the lanes to have tightened lets a label reach over its neighbours' bars, and it is
  /// the label — the only thing on the page naming which shot a bar belongs to — that has to stay
  /// readable when the two meet.
  List<pw.Widget> _barWidgets({
    required FountainScriptPage page,
    required OcptScenarioCoveragePage coveragePage,
    required OcptScriptPagePainter painter,
  }) {
    final bars = <pw.Widget>[];
    final labels = <pw.Widget>[];

    for (final segment in coveragePage.segments) {
      final widgets = _segmentWidgets(
        segment: segment,
        page: page,
        coveragePage: coveragePage,
        painter: painter,
      );
      bars.addAll(widgets.bars);
      labels.add(widgets.label);
    }

    return [...bars, ...labels];
  }

  /// The widgets one bar draws, kept apart so the caller can stack them in its own order: the bar
  /// itself, the caps closing it where the covered passage really starts and ends, and the ticks
  /// marking where inside its first and last rows those boundaries fall, then the label printed
  /// beside it.
  ///
  /// A stale bar (its range no longer agrees with the screenplay's text) is outlined rather than
  /// filled, so it reads as "recorded, needs re-checking" instead of as solid coverage.
  ({List<pw.Widget> bars, pw.Widget label}) _segmentWidgets({
    required OcptCoverageBarSegment segment,
    required FountainScriptPage page,
    required OcptScenarioCoveragePage coveragePage,
    required OcptScriptPagePainter painter,
  }) {
    final color = PdfColor.fromInt(ocptCoverageColorAt(segment.colorIndex));
    final bandPt = coveragePage.lanePitchInches * ocptPdfPointsPerInch;
    final insetPt = coveragePage.laneInsetInches(segment) * ocptPdfPointsPerInch;
    final widthPt = math.min(_barWidthPt, bandPt / 2);
    final isLeft = segment.side == OcptCoverageBarSide.left;
    // The lane band runs outward from the printable area's edge; the bar takes its inner edge, the
    // label whatever room is left between it and the page's own edge.
    final leftPt = isLeft
        ? painter.marginLeftPt - insetPt - widthPt
        : painter.pageWidthPt - painter.marginRightPt + insetPt;
    final topPt = painter.rowTopPt(segment.firstRow);
    final heightPt = (segment.lastRow - segment.firstRow + 1) * painter.lineHeightPt;

    return (
      bars: [
        pw.Positioned(
          left: leftPt,
          top: topPt,
          child: pw.Container(
            width: widthPt,
            height: heightPt,
            decoration: segment.isStale
                ? pw.BoxDecoration(border: pw.Border.all(color: color, width: _staleBarStrokePt))
                : pw.BoxDecoration(color: color),
          ),
        ),
        if (segment.startsRange)
          _barCapWidget(
            color: color,
            bandPt: bandPt,
            barLeftPt: leftPt,
            barWidthPt: widthPt,
            topPt: topPt,
          ),
        if (segment.endsRange)
          _barCapWidget(
            color: color,
            bandPt: bandPt,
            barLeftPt: leftPt,
            barWidthPt: widthPt,
            topPt: topPt + heightPt - _barCapThicknessPt,
          ),
        for (final tick in [segment.startTick, segment.endTick])
          if (tick != null && tick.row < page.lines.length)
            _tickWidget(tick: tick, line: page.lines[tick.row], painter: painter, color: color),
      ],
      label: _labelWidget(
        segment: segment,
        painter: painter,
        color: color,
        barLeftPt: leftPt,
        barWidthPt: widthPt,
        barMiddlePt: topPt + heightPt / 2,
      ),
    );
  }

  /// The label printed beside one bar, at its vertical middle and in its own colour, on an opaque
  /// plate of its own.
  ///
  /// Grows away from the text — leftward for a bar in the left margin, rightward for one in the
  /// right margin — over whatever room the margin still has, exactly as the reference document
  /// prints it. It therefore crosses the lanes further out, and two bars whose middles land on the
  /// same row still overprint each other's label; the plate is what keeps the first of those two
  /// collisions legible, which is why the label hugs its text rather than filling the room it is
  /// aligned in — a plate as wide as the margin would blank out every bar beside it.
  pw.Widget _labelWidget({
    required OcptCoverageBarSegment segment,
    required OcptScriptPagePainter painter,
    required PdfColor color,
    required double barLeftPt,
    required double barWidthPt,
    required double barMiddlePt,
  }) {
    final isLeft = segment.side == OcptCoverageBarSide.left;
    final leftPt = isLeft ? 0.0 : barLeftPt + barWidthPt + _labelGapPt;
    final widthPt = isLeft
        ? math.max<double>(0, barLeftPt - _labelGapPt)
        : math.max<double>(0, painter.pageWidthPt - leftPt);

    return pw.Positioned(
      left: leftPt,
      // The plate's padding sits outside the line box the label is centred on, so the text itself
      // stays on the bar's middle row.
      top: barMiddlePt - _labelLineHeightPt / 2 - _labelPaddingPt,
      child: pw.SizedBox(
        width: widthPt,
        // A row rather than the plain text the alignment alone used to place: the plate has to be
        // as wide as the label, and pushed to the far side of that room by something other than
        // its own width.
        child: pw.Row(
          mainAxisAlignment: isLeft ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
          children: [
            pw.Container(
              color: _labelBackgroundColor,
              padding: const pw.EdgeInsets.all(_labelPaddingPt),
              child: pw.Text(
                segment.label,
                maxLines: 1,
                textAlign: isLeft ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(
                  font: painter.fonts.regular,
                  fontSize: _labelFontSizePt,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The horizontal stroke closing a bar at [topPt], centred on the bar it caps.
  ///
  /// Only ever drawn where the covered passage really begins or ends, never where a page break cut
  /// the bar in two: an uncapped end is precisely how a reader tells a bar continues overleaf.
  /// Always solid, stale bar or not — a cap is a boundary mark rather than a claim about how sure
  /// the coverage is, and hollowing a stroke this short would only make it disappear.
  pw.Widget _barCapWidget({
    required PdfColor color,
    required double bandPt,
    required double barLeftPt,
    required double barWidthPt,
    required double topPt,
  }) {
    // Wider than the bar so it reads as a cap rather than as a thicker end, but never wider than
    // its own lane band, whose neighbour would otherwise be crossed by it.
    final widthPt = math.max(barWidthPt, math.min(_barCapWidthPt, bandPt));

    return pw.Positioned(
      left: barLeftPt + barWidthPt / 2 - widthPt / 2,
      top: topPt,
      child: pw.Container(width: widthPt, height: _barCapThicknessPt, color: color),
    );
  }

  /// The short vertical stroke marking, inside the text itself, the exact character a covered
  /// passage starts or ends at when that boundary falls mid-line.
  pw.Widget _tickWidget({
    required OcptCoverageTick tick,
    required FountainScriptLine line,
    required OcptScriptPagePainter painter,
    required PdfColor color,
  }) => pw.Positioned(
    left: painter.columnLeftPt(line: line, column: tick.column),
    top: painter.rowTopPt(tick.row),
    child: pw.Container(width: _tickWidthPt, height: painter.lineHeightPt, color: color),
  );

  /// Builds the legend page: every shot of the shot list, grouped by sequence, with the colour its
  /// bars are drawn in.
  pw.Page _buildLegendPage({
    required OcptScenarioCoverageLayout coverage,
    required OcptScenarioCoverageLabels labels,
    required OcptScriptPagePainter painter,
  }) {
    /// The shots' rows of the sequence [sequenceId], in the order the legend holds them.
    pw.Widget tableOfSequence(String sequenceId) => pw.Table(
      border: pw.TableBorder.all(color: _appendixRuleColor, width: 0.5),
      columnWidths: _legendColumnWidths,
      children: [
        for (final entry in coverage.legend)
          if (entry.sequenceId == sequenceId)
            pw.TableRow(
              children: [
                _appendixCell(
                  child: pw.Container(
                    width: _swatchSizePt,
                    height: _swatchSizePt,
                    color: PdfColor.fromInt(ocptCoverageColorAt(entry.colorIndex)),
                  ),
                ),
                _appendixTextCell(painter: painter, text: entry.label),
                _appendixTextCell(painter: painter, text: entry.shotSize),
                _appendixTextCell(painter: painter, text: entry.framing),
                _appendixTextCell(painter: painter, text: entry.cameraMove),
              ],
            ),
      ],
    );

    // The legend's own order, deduplicated: one block per sequence, in the order the shots come.
    final sequenceIds = <String>[];
    for (final entry in coverage.legend) {
      if (sequenceIds.isEmpty || sequenceIds.last != entry.sequenceId) {
        sequenceIds.add(entry.sequenceId);
      }
    }

    return _appendixPage(
      painter: painter,
      title: labels.legendTitle,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _appendixRuleColor, width: 0.5),
          columnWidths: _legendColumnWidths,
          children: [
            _appendixHeaderRow(
              painter: painter,
              cells: [
                "",
                labels.legendShotHeader,
                labels.legendShotSizeHeader,
                labels.legendFramingHeader,
                labels.legendCameraMoveHeader,
              ],
            ),
          ],
        ),
        for (final sequenceId in sequenceIds) ...[
          _appendixBand(painter: painter, title: labels.titleOfSequence(sequenceId)),
          tableOfSequence(sequenceId),
        ],
      ],
    );
  }

  /// Builds the summary page: how much of each sequence its shots cover, and what they leave out.
  pw.Page _buildSummaryPage({
    required OcptScenarioCoverageLayout coverage,
    required OcptScenarioCoverageLabels labels,
    required OcptScriptPagePainter painter,
  }) {
    final rows = <pw.TableRow>[
      _appendixHeaderRow(painter: painter, cells: [
        labels.summarySequenceHeader,
        labels.summaryShotCountHeader,
        labels.summaryCoveredHeader,
        labels.summaryStaleHeader,
        labels.summaryUncoveredHeader,
      ]),
      for (final row in coverage.summary)
        pw.TableRow(
          children: [
            _appendixTextCell(painter: painter, text: labels.titleOfSequence(row.sequenceId)),
            _appendixTextCell(painter: painter, text: "${row.shotCount}"),
            _appendixTextCell(
              painter: painter,
              // The orphan group covers nothing that can be printed, so a share of it would read
              // as a scene nobody has covered rather than as a group that has no text at all.
              text: row.isOrphanGroup ? "" : "${(row.coveredWordShare * 100).round()}%",
            ),
            _appendixTextCell(painter: painter, text: "${row.staleRangeCount}"),
            _appendixTextCell(painter: painter, text: row.uncoveredExtracts.join("\n")),
          ],
        ),
    ];

    return _appendixPage(
      painter: painter,
      title: labels.summaryTitle,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _appendixRuleColor, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1.5),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(4),
          },
          children: rows,
        ),
        if (coverage.hasLaneOverflow) ...[
          pw.SizedBox(height: _appendixTitleFontSizePt),
          pw.Text(
            labels.laneOverflowNote,
            style: pw.TextStyle(
              font: painter.fonts.italic,
              fontSize: _appendixFontSizePt,
            ),
          ),
        ],
      ],
    );
  }

  /// One appendix [pw.MultiPage], titled [title] and flowing [children] under it.
  ///
  /// A flowing page rather than one of [OcptScriptPagePainter]'s absolutely positioned ones: an
  /// appendix has as many rows as the shot list has shots, so it must be free to run onto a second
  /// sheet. Its side margins are the screenplay's *right* margin on both sides — the wide left
  /// margin a screenplay needs is there to be punched and annotated, and a table has no such use
  /// for it.
  pw.Page _appendixPage({
    required OcptScriptPagePainter painter,
    required String title,
    required List<pw.Widget> children,
  }) => pw.MultiPage(
    pageFormat: PdfPageFormat(
      painter.pageWidthPt,
      painter.pageHeightPt,
      marginLeft: painter.marginRightPt,
      marginTop: painter.marginTopPt,
      marginRight: painter.marginRightPt,
      marginBottom: painter.marginRightPt,
    ),
    build: (context) => [
      pw.Text(
        title,
        style: pw.TextStyle(font: painter.fonts.bold, fontSize: _appendixTitleFontSizePt),
      ),
      pw.SizedBox(height: _appendixTitleFontSizePt),
      ...children,
    ],
  );

  /// The header row of an appendix table, one cell per entry of [cells].
  pw.TableRow _appendixHeaderRow({
    required OcptScriptPagePainter painter,
    required List<String> cells,
  }) => pw.TableRow(
    decoration: const pw.BoxDecoration(color: _appendixHeaderColor),
    children: [
      for (final cell in cells) _appendixTextCell(painter: painter, text: cell, isBold: true),
    ],
  );

  /// The full-width tinted band introducing one sequence's own table, carrying its [title].
  ///
  /// A band between two tables rather than a row inside one: a table row is bound to its column's
  /// width, and a sequence title (a scene number and a whole heading) has no business being folded
  /// into the width of a colour swatch.
  pw.Widget _appendixBand({required OcptScriptPagePainter painter, required String title}) =>
      pw.Container(
        constraints: const pw.BoxConstraints(minWidth: double.infinity),
        decoration: pw.BoxDecoration(
          color: _appendixHeaderColor,
          border: pw.Border.all(color: _appendixRuleColor, width: 0.5),
        ),
        padding: const pw.EdgeInsets.all(_appendixCellPaddingPt),
        child: pw.Text(
          title,
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _appendixFontSizePt),
        ),
      );

  /// One appendix table cell holding [text].
  pw.Widget _appendixTextCell({
    required OcptScriptPagePainter painter,
    required String text,
    bool isBold = false,
  }) => _appendixCell(
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: painter.fonts.variant(bold: isBold, italic: false),
        fontSize: _appendixFontSizePt,
      ),
    ),
  );

  /// One appendix table cell wrapping [child] in the tables' shared padding.
  pw.Widget _appendixCell({required pw.Widget child}) =>
      pw.Padding(padding: const pw.EdgeInsets.all(_appendixCellPaddingPt), child: child);
}
