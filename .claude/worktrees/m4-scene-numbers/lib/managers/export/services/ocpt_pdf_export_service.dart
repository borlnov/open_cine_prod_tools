// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Points per inch, the unit every `pdf` package measurement is given in
/// (unlike [FountainLayoutMetrics], whose measurements are all in inches).
const double _pointsPerInch = 72;

/// The 12-point Courier body text size, matching
/// [FountainLayoutMetrics.charsPerInch] (10 chars/inch at 12pt) and
/// [FountainLayoutMetrics.linesPerInch] (6 lines/inch at 12pt), so a rendered
/// page lines up exactly with the pagination [FountainScriptComposer]
/// already computed.
const double _bodyFontSizePt = 12;

/// The vertical distance between two consecutive [FountainScriptLine] rows,
/// in points: `72pt/in ÷ 6 lines/in`.
const double _lineHeightPt = _pointsPerInch / 6;

/// The distance from a script page's top physical edge to its page-number
/// annotation, in inches. Fixed regardless of the configured top margin
/// (unlike the body text, which starts at the margin), matching how
/// professional screenwriting software places the page number in the header
/// band rather than tying it to the body's own margin.
const double _pageNumberTopInches = 0.5;

/// The title page's title font size, in points.
const double _titleFontSizePt = 24;

/// The title page's credit/author/contact/draft-date font size, in points.
const double _titleMetaFontSizePt = _bodyFontSizePt;

/// The 4 Courier Prime `pw.Font` variants loaded from the asset bundle,
/// bundled together so [OcptPdfExportService] only has to cache and pass
/// around one object instead of 4 separate futures.
class _CourierPrimeFonts {
  /// Creates a [_CourierPrimeFonts].
  const _CourierPrimeFonts({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  /// The regular (upright, non-bold) variant.
  final pw.Font regular;

  /// The bold variant.
  final pw.Font bold;

  /// The italic variant.
  final pw.Font italic;

  /// The bold-italic variant.
  final pw.Font boldItalic;

  /// Reads the 4 Courier Prime TTFs from the asset bundle and decodes each
  /// into a `pw.Font`.
  ///
  /// The `flutter: fonts:` block in `pubspec.yaml` makes these usable as an
  /// on-screen `TextStyle` family, but does not put their raw bytes within
  /// reach of `rootBundle.load`; that requires the same paths to also be
  /// listed under `flutter: assets:`, which they are.
  static Future<_CourierPrimeFonts> load() async {
    Future<pw.Font> loadVariant(String fileName) async {
      final data = await rootBundle.load(
        'assets/fonts/courier_prime/$fileName',
      );
      return pw.Font.ttf(data);
    }

    final variants = await Future.wait([
      loadVariant('CourierPrime-Regular.ttf'),
      loadVariant('CourierPrime-Bold.ttf'),
      loadVariant('CourierPrime-Italic.ttf'),
      loadVariant('CourierPrime-BoldItalic.ttf'),
    ]);

    return _CourierPrimeFonts(
      regular: variants[0],
      bold: variants[1],
      italic: variants[2],
      boldItalic: variants[3],
    );
  }

  /// The font variant matching [bold]/[italic], mirroring how a
  /// [FountainStyledRun]'s own flags combine.
  pw.Font variant({required bool bold, required bool italic}) {
    if (bold && italic) {
      return boldItalic;
    }
    if (bold) {
      return this.bold;
    }
    if (italic) {
      return this.italic;
    }
    return regular;
  }
}

/// Renders a parsed [FountainDocument] into a paginated, Courier-Prime-
/// embedded screenplay PDF.
///
/// This is pure rendering logic with no dialog or file-system access of its
/// own: it's owned by `OcptExportManager` and exposed as a public final
/// field, reached through the manager rather than through `globalGetIt()`
/// (RFL18). It consumes [FountainScriptComposer] (from `fountain_kit`, which
/// must stay Flutter-free) for the body's line-level pagination and only
/// adds the `pdf`-package-specific concerns: font embedding, the title page,
/// and page/scene-number margin annotations.
class OcptPdfExportService {
  /// Creates an [OcptPdfExportService].
  ///
  /// Deliberately not `const` (unlike the sibling `OcptFountainIoService`):
  /// this service caches its loaded fonts in a mutable field once
  /// [generate] first runs, so repeated exports within the same app session
  /// don't re-read the asset bundle.
  OcptPdfExportService();

  /// The Fountain-to-page-layout engine, stateless so one instance is
  /// shared across every [generate] call.
  static const FountainScriptComposer _composer = FountainScriptComposer();

  /// The memoized font-loading future, populated on first use. A `Future`
  /// rather than the resolved fonts themselves, so two [generate] calls
  /// racing before the first load finishes both await the same load instead
  /// of triggering it twice.
  Future<_CourierPrimeFonts>? _fontsFuture;

  /// Loads (once) and returns the embedded Courier Prime font set.
  Future<_CourierPrimeFonts> _loadFonts() =>
      _fontsFuture ??= _CourierPrimeFonts.load();

  /// The `.pdf` file name to suggest when exporting the project named
  /// [projectName], mirroring `OcptFountainIoService.fountainFileName`.
  String pdfFileName(String projectName) => '$projectName.pdf';

  /// Renders [document] into a complete screenplay PDF, returning its bytes.
  ///
  /// [pageSetup] supplies both the physical page geometry (via
  /// [OcptPageSetup.toMetrics]) and, indirectly, the body's pagination
  /// (which depends on that same geometry). [includeTitlePage] toggles a
  /// leading title page built from [document]'s title page metadata (or a
  /// minimal [projectName] fallback when that metadata is absent or has no
  /// usable title). [includeSceneNumbers] toggles the both-margins scene
  /// number annotations opposite every explicitly numbered scene heading.
  Future<Uint8List> generate({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
  }) async {
    final fonts = await _loadFonts();
    final metrics = pageSetup.toMetrics();
    final pdfDocument = pw.Document();

    if (includeTitlePage) {
      pdfDocument.addPage(
        _buildTitlePage(
          titlePage: document.titlePage,
          projectName: projectName,
          metrics: metrics,
          fonts: fonts,
        ),
      );
    }

    final layout = _composer.compose(document: document, metrics: metrics);
    for (var index = 0; index < layout.pages.length; index++) {
      pdfDocument.addPage(
        _buildScriptPage(
          page: layout.pages[index],
          // Script pages are 1-based for the printed page number, and the
          // very first one is never numbered (professional convention).
          pageNumber: index + 1,
          metrics: metrics,
          fonts: fonts,
          includeSceneNumbers: includeSceneNumbers,
        ),
      );
    }

    return pdfDocument.save();
  }

  /// Builds the leading title [pw.Page] from [titlePage]'s metadata: title
  /// centered in the upper-to-middle area, credit and authors below it,
  /// contact at the bottom-left and draft date at the bottom-right. Falls
  /// back to a single centered [projectName] when [titlePage] is null or has
  /// no usable [FountainTitlePage.title] — the option to include a title
  /// page at all is handled by the caller; this method never itself decides
  /// to omit the page.
  pw.Page _buildTitlePage({
    required FountainTitlePage? titlePage,
    required String projectName,
    required FountainLayoutMetrics metrics,
    required _CourierPrimeFonts fonts,
  }) {
    final pageFormat = PdfPageFormat(
      metrics.pageWidthInches * _pointsPerInch,
      metrics.pageHeightInches * _pointsPerInch,
      marginLeft: metrics.marginLeftInches * _pointsPerInch,
      marginTop: metrics.marginTopInches * _pointsPerInch,
      marginRight: metrics.marginRightInches * _pointsPerInch,
      marginBottom: metrics.marginBottomInches * _pointsPerInch,
    );

    pw.TextStyle style(double size, {bool bold = false}) => pw.TextStyle(
      font: fonts.variant(bold: bold, italic: false),
      fontSize: size,
    );

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
                    pw.SizedBox(height: _lineHeightPt * 2),
                    pw.Text(
                      credit,
                      style: style(_titleMetaFontSizePt),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                  if (authors.isNotEmpty) ...[
                    pw.SizedBox(height: _lineHeightPt),
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

  /// Builds one script [pw.Page] from a paginated [page], absolutely
  /// positioning every line rather than flowing them, since that is what
  /// lets a page number and both-margin scene numbers land at their own
  /// row's exact Y coordinate alongside the line itself.
  ///
  /// [pageNumber] is this page's 1-based position among script pages (not
  /// counting the title page); it is only ever printed from the 2nd script
  /// page onward, matching the professional convention that the title page
  /// and the first script page stay unnumbered.
  pw.Page _buildScriptPage({
    required FountainScriptPage page,
    required int pageNumber,
    required FountainLayoutMetrics metrics,
    required _CourierPrimeFonts fonts,
    required bool includeSceneNumbers,
  }) {
    final widthPt = metrics.pageWidthInches * _pointsPerInch;
    final heightPt = metrics.pageHeightInches * _pointsPerInch;
    final marginTopPt = metrics.marginTopInches * _pointsPerInch;
    final marginLeftPt = metrics.marginLeftInches * _pointsPerInch;
    final marginRightPt = metrics.marginRightInches * _pointsPerInch;

    final children = <pw.Widget>[
      if (pageNumber >= 2)
        pw.Positioned(
          left: 0,
          top: _pageNumberTopInches * _pointsPerInch,
          child: pw.SizedBox(
            width: widthPt - marginRightPt,
            child: pw.Text(
              '$pageNumber.',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: fonts.regular, fontSize: _bodyFontSizePt),
            ),
          ),
        ),
    ];

    for (var row = 0; row < page.lines.length; row++) {
      final line = page.lines[row];
      final rowTopPt = marginTopPt + row * _lineHeightPt;

      if (line.runs.isNotEmpty) {
        final elementLayout = _elementLayoutFor(line.lineType, metrics);
        final blockStyle = FountainPrintStyle.of(line.lineType);
        children.add(
          pw.Positioned(
            left: line.leftIndentInches * _pointsPerInch,
            top: rowTopPt,
            child: pw.SizedBox(
              width: elementLayout.maxWidthInches * _pointsPerInch,
              child: pw.RichText(
                textAlign: _textAlignFor(line.alignment),
                text: pw.TextSpan(children: _spansFor(line.runs, blockStyle, fonts)),
              ),
            ),
          ),
        );
      }

      final sceneNumber = line.sceneNumber;
      if (includeSceneNumbers && line.isSceneHeading && sceneNumber != null) {
        children.add(
          pw.Positioned(
            left: 0,
            top: rowTopPt,
            child: pw.SizedBox(
              width: marginLeftPt,
              child: pw.Text(
                sceneNumber,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: fonts.regular, fontSize: _bodyFontSizePt),
              ),
            ),
          ),
        );
        children.add(
          pw.Positioned(
            left: widthPt - marginRightPt,
            top: rowTopPt,
            child: pw.SizedBox(
              width: marginRightPt,
              child: pw.Text(
                sceneNumber,
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(font: fonts.regular, fontSize: _bodyFontSizePt),
              ),
            ),
          ),
        );
      }
    }

    return pw.Page(
      pageFormat: PdfPageFormat(widthPt, heightPt),
      build: (context) => pw.Stack(children: children),
    );
  }

  /// Turns [runs] into the [pw.TextSpan]s of one [FountainScriptLine], each
  /// carrying the Courier Prime variant matching [blockStyle]'s bold/italic
  /// composed with the run's own bold/italic flags, and an underline
  /// decoration when [FountainStyledRun.isUnderline] is set.
  ///
  /// [blockStyle] and a run's flags compose with a boolean OR on each axis,
  /// never a replacement: a `**bold**` word inside an italic
  /// [FountainLineType.lyrics] line resolves to bold-italic, and an
  /// `*italic*` word inside a bold [FountainLineType.sceneHeading] likewise.
  ///
  /// A note run ([FountainStyledRun.isNote]) is dropped rather than
  /// rendered: `[[...]]` notes are an authoring aid meant for the editor,
  /// not screenplay content that belongs in a printed/exported page.
  List<pw.TextSpan> _spansFor(
    List<FountainStyledRun> runs,
    FountainPrintStyle blockStyle,
    _CourierPrimeFonts fonts,
  ) => [
    for (final run in runs)
      if (!run.isNote)
        pw.TextSpan(
          text: run.text,
          style: pw.TextStyle(
            font: fonts.variant(
              bold: blockStyle.isBold || run.isBold,
              italic: blockStyle.isItalic || run.isItalic,
            ),
            fontSize: _bodyFontSizePt,
            decoration: run.isUnderline
                ? pw.TextDecoration.underline
                : pw.TextDecoration.none,
          ),
        ),
  ];

  /// Maps a [FountainLayoutAlignment] to the matching `pdf`-package
  /// [pw.TextAlign].
  pw.TextAlign _textAlignFor(FountainLayoutAlignment alignment) =>
      switch (alignment) {
        FountainLayoutAlignment.left => pw.TextAlign.left,
        FountainLayoutAlignment.center => pw.TextAlign.center,
        FountainLayoutAlignment.right => pw.TextAlign.right,
      };

  /// The [FountainElementLayout] [metrics] uses for [lineType], so a line's
  /// box width for alignment purposes matches exactly the width
  /// [FountainScriptComposer] already wrapped it to.
  ///
  /// [FountainLineType.blank] (a spacer line) and the non-printing types
  /// that never reach this renderer (page break, section, synopsis) fall
  /// back to [FountainLayoutMetrics.action]: harmless, since a line reaching
  /// this branch never has any runs to align in the first place.
  FountainElementLayout _elementLayoutFor(
    FountainLineType lineType,
    FountainLayoutMetrics metrics,
  ) => switch (lineType) {
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
