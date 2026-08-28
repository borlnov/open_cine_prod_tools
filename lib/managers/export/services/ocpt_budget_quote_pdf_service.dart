// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of the document's own big title, printed once on the title page.
const double _titleFontSizePt = 16;

/// The font size, in points, of the title page's own document name.
const double _coverTitleFontSizePt = 24;

/// The font size, in points, of every body line: a poste heading, a table cell.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, the tax-basis caption, an
/// element's own quiet second line under its label.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of a poste's own table.
const double _cellPaddingPt = 4;

/// The colour the tables' rules are drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's own header row.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The `Description / Qty / Unit price / Total` columns every poste's own table shares.
const Map<int, pw.TableColumnWidth> _columnWidths = {
  0: pw.FlexColumnWidth(3),
  1: pw.FlexColumnWidth(1.2),
  2: pw.FlexColumnWidth(1.2),
  3: pw.FlexColumnWidth(1.2),
};

/// Renders the quote: the full CNC nomenclature, poste by poste with its own lines, each poste's own
/// subtotal, then the project's own grand total.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings. It prints no screenplay, so it draws
/// nothing through [OcptScriptPagePainter]'s absolutely positioned page builders and flows its
/// content in a [pw.MultiPage] instead, exactly as `OcptContactListPdfService` and
/// `OcptDayOutOfDaysPdfService` already do; it still takes one painter, for the page geometry every
/// export of this app measures a sheet with and the Courier Prime variants all of them print in.
///
/// **Every amount is converted row by row, then summed** — never a summed total converted by one
/// rate — exactly the reading `lib/utils/ocpt_budget_totals.dart` already gives the cost-tracking
/// table, and for the same reason: a table mixing tax-inclusive and tax-exclusive lines, or lines at
/// different rates, would otherwise total wrong. Wherever a total is not
/// [OcptBudgetCoveredTotal.isComplete], this document prints the coverage read-out
/// `ocptBudgetExportCoveredAmountText` builds from [OcptBudgetQuoteLabels.coverageReadOutTemplate],
/// beside it, rather than a figure standing in for the rows it does not cover.
///
/// **A line minted from a breakdown element** (`OcptBudgetLine.elementId`) prints the element's own
/// name as a quiet second line under its own label, resolved through `elementNameById` — a plain
/// map the caller hands in, this service resolving nothing itself
/// (`docs/architecture/budget.md`'s own "A quote line can price a breakdown element").
class OcptBudgetQuotePdfService {
  /// Creates an [OcptBudgetQuotePdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptBudgetQuotePdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the quote of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - quote.pdf`); a blank one falls back to the project name alone, exactly as
  /// `OcptContactListPdfService.contactListFileName` does.
  String quoteFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the quote of [snapshot]'s own postes, in [taxBasis], returning the PDF's bytes.
  ///
  /// [elementNameById] names every breakdown element a quote line prices (`OcptBudgetLine
  /// .elementId`) — see the class doc comment. [exportDate] is the moment the title page's own
  /// version line and every page's running head print, resolved once per document; it defaults to
  /// [DateTime.now] so a caller that never reissues this document doesn't have to pass one. A
  /// project holding no poste at all prints one readable note page rather than an empty file.
  Future<Uint8List> generate({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> elementNameById,
    required OcptPageSetup pageSetup,
    required OcptBudgetTaxBasis taxBasis,
    required OcptBudgetQuoteLabels labels,
    required String projectName,
    required bool includeTitlePage,
    DateTime? exportDate,
  }) async {
    final painter = OcptScriptPagePainter(metrics: pageSetup.toMetrics(), fonts: await fontsLoader.load());
    final versionLine =
        "${labels.versionLabel} ${ocptBudgetExportGeneratedAtStamp(exportDate ?? DateTime.now())}";

    final pdfDocument = pw.Document();

    if (includeTitlePage) {
      pdfDocument.addPage(_titlePage(painter: painter, labels: labels, versionLine: versionLine));
    }

    pdfDocument.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat(painter),
        header: (context) => _runningHead(
          painter: painter,
          projectName: projectName,
          documentTitle: labels.documentTitle,
          versionLine: versionLine,
        ),
        build: (context) => snapshot.postes.isEmpty
            ? [_noteWidget(painter: painter, text: labels.emptyDocumentNote)]
            : _body(painter: painter, snapshot: snapshot, elementNameById: elementNameById, taxBasis: taxBasis, labels: labels),
      ),
    );

    return pdfDocument.save();
  }

  /// The document's own body: the tax-basis caption, one section per poste, then the project's own
  /// grand total.
  List<pw.Widget> _body({
    required OcptScriptPagePainter painter,
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> elementNameById,
    required OcptBudgetTaxBasis taxBasis,
    required OcptBudgetQuoteLabels labels,
  }) {
    final allLines = [for (final poste in snapshot.postes) ...poste.lines];
    final grandTotal = ocptBudgetTotalOf(
      allLines,
      basis: taxBasis,
      projectVatRateBasisPoints: snapshot.defaultVatRateBasisPoints,
    );

    return [
      pw.Text(
        labels.taxBasisCaptionOf(taxBasis),
        style: pw.TextStyle(font: painter.fonts.italic, fontSize: _smallFontSizePt, color: _mutedColor),
      ),
      pw.SizedBox(height: 10),
      for (final poste in snapshot.postes) ...[
        _posteSection(
          painter: painter,
          poste: poste,
          elementNameById: elementNameById,
          taxBasis: taxBasis,
          labels: labels,
          projectVatRateBasisPoints: snapshot.defaultVatRateBasisPoints,
          currencyCode: snapshot.currencyCode,
        ),
        pw.SizedBox(height: 14),
      ],
      pw.Divider(color: _ruleColor, thickness: 0.5),
      pw.SizedBox(height: 4),
      _totalRow(
        painter: painter,
        label: labels.projectTotalLabel,
        text: ocptBudgetExportCoveredAmountText(
          total: grandTotal,
          currencyCode: snapshot.currencyCode,
          coverageReadOutTemplate: labels.coverageReadOutTemplate,
        ),
        isBold: true,
      ),
    ];
  }

  /// One poste's own section: its heading, its own table of lines (or [OcptBudgetQuoteLabels
  /// .noLinesLabel] while it holds none), then its own subtotal.
  pw.Widget _posteSection({
    required OcptScriptPagePainter painter,
    required OcptBudgetPoste poste,
    required Map<String, String> elementNameById,
    required OcptBudgetTaxBasis taxBasis,
    required OcptBudgetQuoteLabels labels,
    required int? projectVatRateBasisPoints,
    required String currencyCode,
  }) {
    final subtotal = ocptBudgetTotalOf(
      poste.lines,
      basis: taxBasis,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "${poste.code} — ${poste.label}",
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt),
        ),
        pw.SizedBox(height: 6),
        if (poste.lines.isEmpty)
          pw.Text(
            labels.noLinesLabel,
            style: pw.TextStyle(font: painter.fonts.italic, fontSize: _bodyFontSizePt, color: _mutedColor),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
            columnWidths: _columnWidths,
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: _bandColor),
                children: [
                  _headerCell(painter: painter, text: labels.lineLabelHeader, align: pw.TextAlign.left),
                  _headerCell(painter: painter, text: labels.quantityHeader, align: pw.TextAlign.right),
                  _headerCell(painter: painter, text: labels.unitPriceHeader, align: pw.TextAlign.right),
                  _headerCell(painter: painter, text: labels.lineTotalHeader, align: pw.TextAlign.right),
                ],
              ),
              for (final line in poste.lines)
                _lineRow(
                  painter: painter,
                  line: line,
                  elementName: line.elementId == null ? null : elementNameById[line.elementId],
                  taxBasis: taxBasis,
                  projectVatRateBasisPoints: projectVatRateBasisPoints,
                  currencyCode: currencyCode,
                ),
            ],
          ),
        pw.SizedBox(height: 4),
        _totalRow(
          painter: painter,
          label: labels.posteSubtotalLabel,
          text: ocptBudgetExportCoveredAmountText(
            total: subtotal,
            currencyCode: currencyCode,
            coverageReadOutTemplate: labels.coverageReadOutTemplate,
          ),
          isBold: false,
        ),
      ],
    );
  }

  /// One quote line's own row: its label (with the element it prices under it, when it prices
  /// one), its quantity and unit, its unit price, and its own total in [taxBasis].
  pw.TableRow _lineRow({
    required OcptScriptPagePainter painter,
    required OcptBudgetLine line,
    required String? elementName,
    required OcptBudgetTaxBasis taxBasis,
    required int? projectVatRateBasisPoints,
    required String currencyCode,
  }) {
    final unitPriceCents = _amountInBasisCentsOf(
      line.unitPrice,
      taxBasis: taxBasis,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );
    final lineTotalCents = _lineAmountCentsInBasis(
      line,
      taxBasis: taxBasis,
      projectVatRateBasisPoints: projectVatRateBasisPoints,
    );

    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(_cellPaddingPt),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(line.label, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
              if (elementName != null && elementName.trim().isNotEmpty)
                pw.Text(
                  elementName,
                  style: pw.TextStyle(font: painter.fonts.italic, fontSize: _smallFontSizePt, color: _mutedColor),
                ),
            ],
          ),
        ),
        _amountCell(painter: painter, text: "${ocptBudgetExportQuantityLabel(line.quantityMilli)} ${line.unit}"),
        _amountCell(
          painter: painter,
          text: unitPriceCents == null
              ? ocptBudgetExportEmptyValue
              : ocptBudgetExportAmountLabel(unitPriceCents, currencyCode),
        ),
        _amountCell(
          painter: painter,
          text: lineTotalCents == null
              ? ocptBudgetExportEmptyValue
              : ocptBudgetExportAmountLabel(lineTotalCents, currencyCode),
        ),
      ],
    );
  }

  /// [line]'s own total, read in [taxBasis] — [ocptBudgetLineTotalCents] converted individually,
  /// never summed first, mirroring `ocptBudgetTotalOf`'s own inner reading for the including-tax
  /// case and `ocptBudgetLineExcludingTaxTotalCents` for the excluding-tax one.
  int? _lineAmountCentsInBasis(
    OcptBudgetLine line, {
    required OcptBudgetTaxBasis taxBasis,
    required int? projectVatRateBasisPoints,
  }) => _amountInBasisCentsOf(
    OcptMoney(
      amountCents: ocptBudgetLineTotalCents(line),
      isTaxInclusive: line.unitPrice.isTaxInclusive,
      vatRateBasisPoints: line.unitPrice.vatRateBasisPoints,
    ),
    taxBasis: taxBasis,
    projectVatRateBasisPoints: projectVatRateBasisPoints,
  );

  /// [money]'s own amount, read in [taxBasis] — the single place this service picks between
  /// [ocptExcludingTaxAmountCentsOf] and [ocptIncludingTaxAmountCentsOf], both of them
  /// `lib/utils/ocpt_budget_vat.dart`'s own "null, never zero" readings.
  int? _amountInBasisCentsOf(
    OcptMoney money, {
    required OcptBudgetTaxBasis taxBasis,
    required int? projectVatRateBasisPoints,
  }) => taxBasis == OcptBudgetTaxBasis.includingTax
      ? ocptIncludingTaxAmountCentsOf(money, projectVatRateBasisPoints: projectVatRateBasisPoints)
      : ocptExcludingTaxAmountCentsOf(money, projectVatRateBasisPoints: projectVatRateBasisPoints);

  /// One header cell of a poste's own table.
  pw.Widget _headerCell({
    required OcptScriptPagePainter painter,
    required String text,
    required pw.TextAlign align,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(text, textAlign: align, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt)),
  );

  /// One right-aligned amount cell.
  pw.Widget _amountCell({required OcptScriptPagePainter painter, required String text}) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
    ),
  );

  /// A right-aligned `<label>: <text>` line — a poste's own subtotal, or the project's own grand
  /// total.
  pw.Widget _totalRow({
    required OcptScriptPagePainter painter,
    required String label,
    required String text,
    required bool isBold,
  }) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      "$label: $text",
      style: pw.TextStyle(
        font: painter.fonts.variant(bold: isBold, italic: false),
        fontSize: isBold ? _titleFontSizePt : _bodyFontSizePt,
      ),
    ),
  );

  /// The document's own title page: its name and the moment the export was run.
  pw.Page _titlePage({
    required OcptScriptPagePainter painter,
    required OcptBudgetQuoteLabels labels,
    required String versionLine,
  }) => pw.Page(
    pageFormat: _pageFormat(painter),
    build: (context) => pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            labels.documentTitle,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: _coverTitleFontSizePt),
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            versionLine,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
      ),
    ),
  );

  /// A block of free text — the note standing in for the whole document on a project with no poste
  /// at all.
  pw.Widget _noteWidget({required OcptScriptPagePainter painter, required String text}) =>
      pw.Text(text, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt));

  /// The running head every page of the document carries: the project and the document's own name
  /// on the left, [versionLine] on the right, over a rule — mirroring
  /// `OcptContactListPdfService._runningHead` exactly.
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

  /// The portrait `pdf` page format every page is drawn on, mirroring `OcptContactListPdfService`'s
  /// own margin convention (`marginRightPt` standing in for the bottom margin too,
  /// [OcptScriptPagePainter] having none of its own).
  PdfPageFormat _pageFormat(OcptScriptPagePainter painter) => PdfPageFormat(
    painter.pageWidthPt,
    painter.pageHeightPt,
    marginLeft: painter.marginRightPt,
    marginTop: painter.marginTopPt,
    marginRight: painter.marginRightPt,
    marginBottom: painter.marginRightPt,
  );
}
