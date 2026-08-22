// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of the document's own big title, printed once on the title page.
const double _titleFontSizePt = 16;

/// The font size, in points, of the title page's own document name.
const double _coverTitleFontSizePt = 24;

/// The font size, in points, of every body line: a poste row, a table cell.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, a section title.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of the table.
const double _cellPaddingPt = 4;

/// The colour the table's rules are drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of the table's own header row and of its own totals row.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The `Poste / Quoted / Paid / Committed / Remaining / Variance` columns of the table.
const Map<int, pw.TableColumnWidth> _columnWidths = {
  0: pw.FlexColumnWidth(2.4),
  1: pw.FlexColumnWidth(1.2),
  2: pw.FlexColumnWidth(1.2),
  3: pw.FlexColumnWidth(1.2),
  4: pw.FlexColumnWidth(1.2),
  5: pw.FlexColumnWidth(1.2),
};

/// Renders the financial report: the quote read against what has actually moved, poste by poste,
/// with the variance, then the financing plan's own total and the needs/resources balance.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings. It prints no screenplay, so — like
/// `OcptBudgetQuotePdfService` and `OcptBudgetFinancingPlanPdfService` — it flows its content in a
/// [pw.MultiPage] rather than drawing through [OcptScriptPagePainter]'s absolutely positioned page
/// builders; it still takes one painter, for the page geometry and the Courier Prime variants every
/// export of this app shares.
///
/// **Every reading is the very one `lib/utils/ocpt_budget_totals.dart` already computes for the
/// cost-tracking table** — `Quoted` (`ocptBudgetPosteQuotedTotalCents`), `Paid`
/// (`snapshot.paidCentsOf`), `Committed` (`snapshot.committedCentsOf`), `Remaining`
/// (`ocptBudgetRemainingCents`) and `Variance` (`ocptBudgetVarianceCents`) — printed rather than
/// recomputed a second way. `Paid` and `Committed` are always tax-inclusive, exactly as the journal
/// and the projection read them (`docs/architecture/budget.md`), so `Quoted` is read the same way
/// here too — this report measures one figure against the other, and comparing an excluding-tax
/// quote against a tax-inclusive actual would compare two different figures while looking like it
/// compared one.
class OcptBudgetFinancialReportPdfService {
  /// Creates an [OcptBudgetFinancialReportPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptBudgetFinancialReportPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the financial report of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - financial report.pdf`); a blank one falls back to the project name alone, exactly
  /// as `OcptContactListPdfService.contactListFileName` does.
  String financialReportFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the financial report of [snapshot], returning the PDF's bytes.
  ///
  /// [exportDate] is the moment the title page's own version line and every page's running head
  /// print, resolved once per document; it defaults to [DateTime.now] so a caller that never
  /// reissues this document doesn't have to pass one. A project holding no poste at all prints one
  /// readable note page rather than an empty file.
  Future<Uint8List> generate({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancialReportLabels labels,
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
            : _body(painter: painter, snapshot: snapshot, labels: labels),
      ),
    );

    return pdfDocument.save();
  }

  /// The document's own body: the poste-by-poste table with its own totals row, then the financing
  /// plan's own total and the needs/resources balance.
  List<pw.Widget> _body({
    required OcptScriptPagePainter painter,
    required OcptBudgetSnapshot snapshot,
    required OcptBudgetFinancialReportLabels labels,
  }) {
    final allLines = [for (final poste in snapshot.postes) ...poste.lines];
    final quotedTotal = ocptBudgetTotalOf(
      allLines,
      basis: OcptBudgetTaxBasis.includingTax,
      projectVatRateBasisPoints: snapshot.defaultVatRateBasisPoints,
    );
    final paidTotalCents = snapshot.postes.fold(0, (sum, poste) => sum + snapshot.paidCentsOf(poste.id));
    final committedTotalCents = snapshot.postes.fold(
      0,
      (sum, poste) => sum + snapshot.committedCentsOf(poste.id),
    );
    final remainingTotalCents = ocptBudgetRemainingCents(
      quotedAmountCents: quotedTotal.amountCents,
      paidCents: paidTotalCents,
      committedCents: committedTotalCents,
    );
    final varianceTotalCents = ocptBudgetVarianceCents(
      quotedAmountCents: quotedTotal.amountCents,
      paidCents: paidTotalCents,
      committedCents: committedTotalCents,
    );

    final financingPlanTotalCents = ocptBudgetResourcesTotalCents(snapshot.resources);
    final balance = ocptBudgetNeedsResourcesBalanceOf(needs: quotedTotal, resourcesCents: financingPlanTotalCents);

    return [
      pw.Table(
        border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
        columnWidths: _columnWidths,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _bandColor),
            children: [
              _headerCell(painter: painter, text: labels.posteHeader, align: pw.TextAlign.left),
              _headerCell(painter: painter, text: labels.quotedHeader, align: pw.TextAlign.right),
              _headerCell(painter: painter, text: labels.paidHeader, align: pw.TextAlign.right),
              _headerCell(painter: painter, text: labels.committedHeader, align: pw.TextAlign.right),
              _headerCell(painter: painter, text: labels.remainingHeader, align: pw.TextAlign.right),
              _headerCell(painter: painter, text: labels.varianceHeader, align: pw.TextAlign.right),
            ],
          ),
          for (final poste in snapshot.postes)
            _posteRow(painter: painter, poste: poste, snapshot: snapshot, labels: labels),
          _totalsRow(
            painter: painter,
            label: labels.projectTotalsLabel,
            quotedText: ocptBudgetExportCoveredAmountText(
              total: quotedTotal,
              currencyCode: snapshot.currencyCode,
              coverageReadOutTemplate: labels.coverageReadOutTemplate,
            ),
            paidCents: paidTotalCents,
            committedCents: committedTotalCents,
            remainingCents: remainingTotalCents,
            varianceCents: varianceTotalCents,
            currencyCode: snapshot.currencyCode,
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      _totalRow(
        painter: painter,
        label: labels.financingPlanTotalLabel,
        text: ocptBudgetExportAmountLabel(financingPlanTotalCents, snapshot.currencyCode),
      ),
      pw.SizedBox(height: 8),
      _balanceSection(painter: painter, balance: balance, snapshot: snapshot, labels: labels),
    ];
  }

  /// One poste's own row: its label, its quoted total (tax-inclusive), what has been paid and
  /// committed against it, and the remaining and variance readings — every one of them
  /// `lib/utils/ocpt_budget_totals.dart`'s own figure.
  pw.TableRow _posteRow({
    required OcptScriptPagePainter painter,
    required OcptBudgetPoste poste,
    required OcptBudgetSnapshot snapshot,
    required OcptBudgetFinancialReportLabels labels,
  }) {
    final quoted = ocptBudgetTotalOf(
      poste.lines,
      basis: OcptBudgetTaxBasis.includingTax,
      projectVatRateBasisPoints: snapshot.defaultVatRateBasisPoints,
    );
    final paidCents = snapshot.paidCentsOf(poste.id);
    final committedCents = snapshot.committedCentsOf(poste.id);
    final remainingCents = ocptBudgetRemainingCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );
    final varianceCents = ocptBudgetVarianceCents(
      quotedAmountCents: quoted.amountCents,
      paidCents: paidCents,
      committedCents: committedCents,
    );

    return pw.TableRow(
      children: [
        _textCell(painter: painter, text: "${poste.code} — ${poste.label}", align: pw.TextAlign.left),
        _textCell(
          painter: painter,
          text: ocptBudgetExportCoveredAmountText(
            total: quoted,
            currencyCode: snapshot.currencyCode,
            coverageReadOutTemplate: labels.coverageReadOutTemplate,
          ),
          align: pw.TextAlign.right,
        ),
        _textCell(
          painter: painter,
          text: ocptBudgetExportAmountLabel(paidCents, snapshot.currencyCode),
          align: pw.TextAlign.right,
        ),
        _textCell(
          painter: painter,
          text: ocptBudgetExportAmountLabel(committedCents, snapshot.currencyCode),
          align: pw.TextAlign.right,
        ),
        _textCell(
          painter: painter,
          text: ocptBudgetExportAmountLabel(remainingCents, snapshot.currencyCode),
          align: pw.TextAlign.right,
        ),
        _textCell(
          painter: painter,
          text: ocptBudgetExportAmountLabel(varianceCents, snapshot.currencyCode),
          align: pw.TextAlign.right,
        ),
      ],
    );
  }

  /// The project's own totals row, closing the table.
  pw.TableRow _totalsRow({
    required OcptScriptPagePainter painter,
    required String label,
    required String quotedText,
    required int paidCents,
    required int committedCents,
    required int remainingCents,
    required int varianceCents,
    required String currencyCode,
  }) => pw.TableRow(
    decoration: const pw.BoxDecoration(color: _bandColor),
    children: [
      _textCell(painter: painter, text: label, align: pw.TextAlign.left, isBold: true),
      _textCell(painter: painter, text: quotedText, align: pw.TextAlign.right, isBold: true),
      _textCell(
        painter: painter,
        text: ocptBudgetExportAmountLabel(paidCents, currencyCode),
        align: pw.TextAlign.right,
        isBold: true,
      ),
      _textCell(
        painter: painter,
        text: ocptBudgetExportAmountLabel(committedCents, currencyCode),
        align: pw.TextAlign.right,
        isBold: true,
      ),
      _textCell(
        painter: painter,
        text: ocptBudgetExportAmountLabel(remainingCents, currencyCode),
        align: pw.TextAlign.right,
        isBold: true,
      ),
      _textCell(
        painter: painter,
        text: ocptBudgetExportAmountLabel(varianceCents, currencyCode),
        align: pw.TextAlign.right,
        isBold: true,
      ),
    ],
  );

  /// The needs/resources balance printed under the financing plan's own total: the quote's own
  /// needs (tax-inclusive, always) against [balance]'s own resources, then the three-way verdict.
  pw.Widget _balanceSection({
    required OcptScriptPagePainter painter,
    required OcptBudgetNeedsResourcesBalance balance,
    required OcptBudgetSnapshot snapshot,
    required OcptBudgetFinancialReportLabels labels,
  }) {
    final needsText = ocptBudgetExportCoveredAmountText(
      total: balance.needs,
      currencyCode: snapshot.currencyCode,
      coverageReadOutTemplate: labels.coverageReadOutTemplate,
    );
    final resourcesText = ocptBudgetExportAmountLabel(balance.resourcesCents, snapshot.currencyCode);
    final verdict = ocptBudgetExportBalanceVerdict(
      balance: balance,
      noQuoteMessage: labels.balanceNoQuoteMessage,
      balancedMessage: labels.balanceBalancedMessage,
      shortfallMessageTemplate: labels.balanceShortfallMessageTemplate,
      currencyCode: snapshot.currencyCode,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "${labels.balanceNeedsLabel}: $needsText",
              style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
            ),
            pw.Text(
              "${labels.balanceResourcesLabel}: $resourcesText",
              style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(verdict, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
      ],
    );
  }

  /// One header cell of the table.
  pw.Widget _headerCell({
    required OcptScriptPagePainter painter,
    required String text,
    required pw.TextAlign align,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(text, textAlign: align, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt)),
  );

  /// One ordinary table cell.
  pw.Widget _textCell({
    required OcptScriptPagePainter painter,
    required String text,
    required pw.TextAlign align,
    bool isBold = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(font: painter.fonts.variant(bold: isBold, italic: false), fontSize: _bodyFontSizePt),
    ),
  );

  /// A right-aligned `<label>: <text>` line — the financing plan's own grand total, printed under
  /// the table.
  pw.Widget _totalRow({required OcptScriptPagePainter painter, required String label, required String text}) =>
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text("$label: $text", style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt)),
      );

  /// The document's own title page: its name and the moment the export was run.
  pw.Page _titlePage({
    required OcptScriptPagePainter painter,
    required OcptBudgetFinancialReportLabels labels,
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

  /// The running head every page of the document carries, mirroring
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
  /// own margin convention.
  PdfPageFormat _pageFormat(OcptScriptPagePainter painter) => PdfPageFormat(
    painter.pageWidthPt,
    painter.pageHeightPt,
    marginLeft: painter.marginRightPt,
    marginTop: painter.marginTopPt,
    marginRight: painter.marginRightPt,
    marginBottom: painter.marginRightPt,
  );
}
