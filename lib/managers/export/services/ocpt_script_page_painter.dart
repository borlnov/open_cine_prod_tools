// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_script_page_number.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Points per inch, the unit every `pdf` package measurement is given in (unlike
/// [FountainLayoutMetrics], whose measurements are all in inches).
const double ocptPdfPointsPerInch = 72;

/// The 12-point Courier body text size, matching [FountainLayoutMetrics.charsPerInch] (10
/// chars/inch at 12pt) and [FountainLayoutMetrics.linesPerInch] (6 lines/inch at 12pt), so a
/// rendered page lines up exactly with the pagination [FountainScriptComposer] already computed.
const double ocptScriptBodyFontSizePt = 12;

/// The vertical distance between two consecutive [FountainScriptLine] rows, in points:
/// `72pt/in ÷ 6 lines/in`.
const double ocptScriptLineHeightPt = ocptPdfPointsPerInch / 6;

/// The title page's title font size, in points.
const double _titleFontSizePt = 24;

/// The title page's credit/author/contact/draft-date font size, in points.
const double _titleMetaFontSizePt = ocptScriptBodyFontSizePt;

/// Draws the pages a screenplay document itself is made of — its title page and its composed
/// script pages — into `pdf` package pages.
///
/// Every PDF this app exports that contains a screenplay goes through this one painter, so the
/// screenplay body of the plain PDF export and of the scenario coverage export are the same
/// drawing, laid out from the same [FountainLayoutMetrics] and the same
/// [FountainScriptComposer] output. A renderer adding something *on top of* a screenplay (the
/// coverage bars, their labels, the uncovered washes) hands it in through [buildScriptPage]'s
/// underlay and overlay slots rather than drawing the screenplay itself again.
///
/// The geometry accessors ([rowTopPt], [columnLeftPt], [columnWidthPt]…) are the other half of
/// that contract: they are how such a renderer finds the exact point on the page a given row and
/// column of a given line was drawn at, without ever re-deriving the layout.
class OcptScriptPagePainter {
  /// The page geometry every measurement here is derived from.
  final FountainLayoutMetrics metrics;

  /// The Courier Prime variants the body text is drawn with.
  final OcptCourierPrimeFonts fonts;

  /// Class constructor
  const OcptScriptPagePainter({required this.metrics, required this.fonts});

  /// The page's full width, in points.
  double get pageWidthPt => metrics.pageWidthInches * ocptPdfPointsPerInch;

  /// The page's full height, in points.
  double get pageHeightPt => metrics.pageHeightInches * ocptPdfPointsPerInch;

  /// The distance, in points, from the page's top edge to the first printed row.
  double get marginTopPt => metrics.marginTopInches * ocptPdfPointsPerInch;

  /// The distance, in points, from the page's left edge to the printable area.
  double get marginLeftPt => metrics.marginLeftInches * ocptPdfPointsPerInch;

  /// The distance, in points, from the page's right edge to the printable area.
  double get marginRightPt => metrics.marginRightInches * ocptPdfPointsPerInch;

  /// The vertical distance, in points, between two consecutive printed rows.
  double get lineHeightPt => ocptScriptLineHeightPt;

  /// The width, in points, of one Courier column.
  ///
  /// The nominal pitch [FountainScriptComposer] wrapped every line to, not Courier Prime's own
  /// advance width (0.5996 em, a shade narrower): a column position derived from it therefore
  /// agrees with the wrap the pagination is built on, at the cost of drifting by less than a third
  /// of a point over a full 60-column line.
  double get columnWidthPt => ocptPdfPointsPerInch / metrics.charsPerInch;

  /// The `pdf` page format of a script page: the physical sheet with no margins of its own, since
  /// every line on it is absolutely positioned.
  PdfPageFormat get scriptPageFormat => PdfPageFormat(pageWidthPt, pageHeightPt);

  /// The distance, in points, from the page's top edge to the top of the printed row [row].
  double rowTopPt(int row) => marginTopPt + row * lineHeightPt;

  /// The distance, in points, from the page's left edge to the 0-based [column] of [line]'s own
  /// printed text.
  ///
  /// Resolves the line's alignment the same way the drawn [pw.RichText] does — a centered or
  /// right-aligned line does not start at its element's left indent — so a mark drawn inside the
  /// text (a coverage tick, a wash behind an uncovered run) lands on the character it names.
  double columnLeftPt({required FountainScriptLine line, required int column}) {
    final boxLeftPt = line.leftIndentInches * ocptPdfPointsPerInch;
    final freeWidthPt = lineBoxWidthPt(line.lineType) - line.plainText.length * columnWidthPt;
    final textLeftPt = switch (line.alignment) {
      FountainLayoutAlignment.left => boxLeftPt,
      FountainLayoutAlignment.center => boxLeftPt + freeWidthPt / 2,
      FountainLayoutAlignment.right => boxLeftPt + freeWidthPt,
    };

    return textLeftPt + column * columnWidthPt;
  }

  /// The width, in points, of the box one [FountainScriptLine] of [lineType] is drawn in.
  ///
  /// Derived from [FountainElementLayout.maxWidthColumns] rather than from
  /// [FountainElementLayout.maxWidthInches], so the box is measured in the very unit
  /// [FountainScriptComposer] wrapped the line to: a line can then never be one column wider than
  /// the box holding it, whatever the page format. That matters because every line is absolutely
  /// positioned at its own row, so a [pw.RichText] re-wrapping a line it considers too wide would
  /// not push the page down — it would draw the overflow on top of the next row. Courier Prime's
  /// real pitch being slightly narrower than the nominal [FountainLayoutMetrics.charsPerInch]
  /// leaves a little slack on top of that, and truncated column counts keep the box inside the
  /// page margins (which right-aligned transitions and centered text rely on).
  double lineBoxWidthPt(FountainLineType lineType) =>
      _elementLayoutFor(lineType).maxWidthColumns * columnWidthPt;

  /// Builds the leading title [pw.Page] from [titlePage]'s metadata: title centered in the
  /// upper-to-middle area, credit and authors below it, contact at the bottom-left and draft date
  /// at the bottom-right. Falls back to a single centered [projectName] when [titlePage] is null or
  /// has no usable [FountainTitlePage.title] — the option to include a title page at all is handled
  /// by the caller; this method never itself decides to omit the page.
  pw.Page buildTitlePage({required FountainTitlePage? titlePage, required String projectName}) {
    final pageFormat = PdfPageFormat(
      pageWidthPt,
      pageHeightPt,
      marginLeft: marginLeftPt,
      marginTop: marginTopPt,
      marginRight: marginRightPt,
      marginBottom: metrics.marginBottomInches * ocptPdfPointsPerInch,
    );

    pw.TextStyle style(double size, {bool bold = false}) =>
        pw.TextStyle(font: fonts.variant(bold: bold, italic: false), fontSize: size);

    final title = titlePage?.title?.trim();
    if (title == null || title.isEmpty) {
      return pw.Page(
        pageFormat: pageFormat,
        build: (context) => pw.Center(
          child: pw.Text(
            projectName,
            style: style(_titleFontSizePt, bold: true),
            textAlign: pw.TextAlign.center,
          ),
        ),
      );
    }

    final credit = titlePage?.credit?.trim();
    final authors = titlePage?.authors ?? const <String>[];
    final contact = titlePage?.contact ?? const <String>[];
    final draftDate = titlePage?.draftDate?.trim();

    return pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: pw.Center(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    title,
                    style: style(_titleFontSizePt, bold: true),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (credit != null && credit.isNotEmpty) ...[
                    pw.SizedBox(height: ocptScriptLineHeightPt * 2),
                    pw.Text(
                      credit,
                      style: style(_titleMetaFontSizePt),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                  if (authors.isNotEmpty) ...[
                    pw.SizedBox(height: ocptScriptLineHeightPt),
                    for (final author in authors)
                      pw.Text(
                        author,
                        style: style(_titleMetaFontSizePt),
                        textAlign: pw.TextAlign.center,
                      ),
                  ],
                ],
              ),
            ),
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  for (final line in contact)
                    pw.Text(line, style: style(_titleMetaFontSizePt)),
                ],
              ),
              if (draftDate != null && draftDate.isNotEmpty)
                pw.Text(draftDate, style: style(_titleMetaFontSizePt))
              else
                pw.SizedBox(),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds one script [pw.Page] from a paginated [page], absolutely positioning every line rather
  /// than flowing them, since that is what lets a page number and both-margin scene numbers land at
  /// their own row's exact Y coordinate alongside the line itself.
  ///
  /// [pageNumber] is this page's 1-based position among script pages (not counting the title page);
  /// whether it is printed at all, and how it reads, is [ocptScriptPageNumberLabelOf]'s to say — the
  /// styled editor's page-simulation sheets number the very same pages from that same rule.
  ///
  /// [underlays] are drawn beneath the text and [overlays] above it, both in the page's own
  /// coordinate system (points from its top-left corner, which is what every geometry accessor of
  /// this painter returns): that is where a renderer of its own annotations puts them, so the
  /// screenplay itself is never drawn twice.
  pw.Page buildScriptPage({
    required FountainScriptPage page,
    required int pageNumber,
    required bool includeSceneNumbers,
    List<pw.Widget> underlays = const [],
    List<pw.Widget> overlays = const [],
  }) {
    final pageNumberLabel = ocptScriptPageNumberLabelOf(pageNumber);
    final children = <pw.Widget>[
      ...underlays,
      if (pageNumberLabel != null)
        pw.Positioned(
          left: 0,
          top: ocptScriptPageNumberTopInches * ocptPdfPointsPerInch,
          child: pw.SizedBox(
            width: pageWidthPt - marginRightPt,
            child: pw.Text(
              pageNumberLabel,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: fonts.regular, fontSize: ocptScriptBodyFontSizePt),
            ),
          ),
        ),
    ];

    for (var row = 0; row < page.lines.length; row++) {
      children.addAll(
        _lineWidgets(line: page.lines[row], row: row, includeSceneNumbers: includeSceneNumbers),
      );
    }

    children.addAll(overlays);

    return pw.Page(
      pageFormat: scriptPageFormat,
      build: (context) => pw.Stack(children: children),
    );
  }

  /// The widgets one printed [line] at [row] draws: its text, and the scene numbers printed in
  /// both margins opposite it when [includeSceneNumbers] is on and it carries one.
  List<pw.Widget> _lineWidgets({
    required FountainScriptLine line,
    required int row,
    required bool includeSceneNumbers,
  }) {
    final rowTopPt = this.rowTopPt(row);
    final widgets = <pw.Widget>[];

    if (line.runs.isNotEmpty) {
      final blockStyle = FountainPrintStyle.of(line.lineType);
      widgets.add(
        pw.Positioned(
          left: line.leftIndentInches * ocptPdfPointsPerInch,
          top: rowTopPt,
          child: pw.SizedBox(
            width: lineBoxWidthPt(line.lineType),
            child: pw.RichText(
              textAlign: _textAlignFor(line.alignment),
              text: pw.TextSpan(children: _spansFor(line.runs, blockStyle)),
            ),
          ),
        ),
      );
    }

    final sceneNumber = line.sceneNumber;
    if (includeSceneNumbers && line.isSceneHeading && sceneNumber != null) {
      final style = pw.TextStyle(font: fonts.regular, fontSize: ocptScriptBodyFontSizePt);
      widgets
        ..add(
          pw.Positioned(
            left: 0,
            top: rowTopPt,
            child: pw.SizedBox(
              width: marginLeftPt,
              child: pw.Text(sceneNumber, textAlign: pw.TextAlign.right, style: style),
            ),
          ),
        )
        ..add(
          pw.Positioned(
            left: pageWidthPt - marginRightPt,
            top: rowTopPt,
            child: pw.SizedBox(
              width: marginRightPt,
              child: pw.Text(sceneNumber, textAlign: pw.TextAlign.left, style: style),
            ),
          ),
        );
    }

    return widgets;
  }

  /// Turns [runs] into the [pw.TextSpan]s of one [FountainScriptLine], each carrying the Courier
  /// Prime variant matching [blockStyle]'s bold/italic composed with the run's own bold/italic
  /// flags, and an underline decoration when [FountainStyledRun.isUnderline] is set.
  ///
  /// [blockStyle] and a run's flags compose with a boolean OR on each axis, never a replacement: a
  /// `**bold**` word inside an italic [FountainLineType.lyrics] line resolves to bold-italic, and
  /// an `*italic*` word inside a bold [FountainLineType.sceneHeading] likewise.
  ///
  /// A note run ([FountainStyledRun.isNote]) is dropped rather than rendered: `[[...]]` notes are
  /// an authoring aid meant for the editor, not screenplay content that belongs in a
  /// printed/exported page.
  List<pw.TextSpan> _spansFor(List<FountainStyledRun> runs, FountainPrintStyle blockStyle) => [
    for (final run in runs)
      if (!run.isNote)
        pw.TextSpan(
          text: run.text,
          style: pw.TextStyle(
            font: fonts.variant(
              bold: blockStyle.isBold || run.isBold,
              italic: blockStyle.isItalic || run.isItalic,
            ),
            fontSize: ocptScriptBodyFontSizePt,
            decoration: run.isUnderline ? pw.TextDecoration.underline : pw.TextDecoration.none,
          ),
        ),
  ];

  /// Maps a [FountainLayoutAlignment] to the matching `pdf`-package [pw.TextAlign].
  pw.TextAlign _textAlignFor(FountainLayoutAlignment alignment) => switch (alignment) {
    FountainLayoutAlignment.left => pw.TextAlign.left,
    FountainLayoutAlignment.center => pw.TextAlign.center,
    FountainLayoutAlignment.right => pw.TextAlign.right,
  };

  /// The [FountainElementLayout] [metrics] uses for [lineType], so a line's box width for alignment
  /// purposes matches exactly the width [FountainScriptComposer] already wrapped it to.
  ///
  /// [FountainLineType.blank] (a spacer line) and the non-printing types that never reach this
  /// renderer (page break, section, synopsis) fall back to [FountainLayoutMetrics.action]:
  /// harmless, since a line reaching this branch never has any runs to align in the first place.
  FountainElementLayout _elementLayoutFor(FountainLineType lineType) => switch (lineType) {
    FountainLineType.sceneHeading => metrics.sceneHeading,
    FountainLineType.action => metrics.action,
    FountainLineType.character => metrics.character,
    FountainLineType.parenthetical => metrics.parenthetical,
    FountainLineType.dialogue => metrics.dialogue,
    FountainLineType.transition => metrics.transition,
    FountainLineType.centeredText => metrics.centeredText,
    FountainLineType.lyrics => metrics.lyrics,
    FountainLineType.blank ||
    FountainLineType.pageBreak ||
    FountainLineType.section ||
    FountainLineType.synopsis => metrics.action,
  };
}
