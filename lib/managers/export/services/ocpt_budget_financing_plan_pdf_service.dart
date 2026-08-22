// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_financing.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of the document's own big title, printed once on the title page.
const double _titleFontSizePt = 16;

/// The font size, in points, of the title page's own document name.
const double _coverTitleFontSizePt = 24;

/// The font size, in points, of every body line: a section title, a table cell.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, a section title.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of a section's own table.
const double _cellPaddingPt = 4;

/// The colour the tables' rules are drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's own header row.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The `Label / Status / Amount / Received / Outstanding` columns every group's own table shares.
const Map<int, pw.TableColumnWidth> _columnWidths = {
  0: pw.FlexColumnWidth(2.6),
  1: pw.FlexColumnWidth(1.4),
  2: pw.FlexColumnWidth(1.2),
  3: pw.FlexColumnWidth(1.2),
  4: pw.FlexColumnWidth(1.2),
};

/// Renders the financing plan: every live resource, grouped by [OcptBudgetResourceGroupKind] so an
/// in-kind contribution stays visibly apart from a cash one, each group with its own subtotal, then
/// the plan's own grand total and the needs/resources balance.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings. It prints no screenplay, so — like
/// `OcptBudgetQuotePdfService` — it flows its content in a [pw.MultiPage] rather than drawing
/// through [OcptScriptPagePainter]'s absolutely positioned page builders; it still takes one
/// painter, for the page geometry and the Courier Prime variants every export of this app shares.
///
/// **A group holding no live resource is not drawn at all**, exactly as `OcptBudgetFinancing` draws
/// none for it on screen. **An `inKind` resource with no journal entry naming it prints
/// [ocptBudgetExportEmptyValue] for both received and outstanding**, rather than a zero — the same
/// silence the screen keeps, since a contribution in kind is valued, not collected
/// (`docs/architecture/budget.md`). The needs side of the closing balance is always read
/// tax-inclusive, whatever tax basis the quote itself is stored in — "Money that has moved is read
/// tax-inclusive, always" — and the verdict is the same three-way reading
/// `OcptBudgetDashboard` gives it: no quote yet, covered, or short by an amount.
class OcptBudgetFinancingPlanPdfService {
  /// Creates an [OcptBudgetFinancingPlanPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptBudgetFinancingPlanPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the financing plan of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - financing plan.pdf`); a blank one falls back to the project name alone, exactly
  /// as `OcptContactListPdfService.contactListFileName` does.
  String financingPlanFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the financing plan of [snapshot], returning the PDF's bytes.
  ///
  /// [exportDate] is the moment the title page's own version line and every page's running head
  /// print, resolved once per document; it defaults to [DateTime.now] so a caller that never
  /// reissues this document doesn't have to pass one. A project holding no live resource at all
  /// prints one readable note page rather than an empty file.
  Future<Uint8List> generate({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancingPlanLabels labels,
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
        build: (context) => snapshot.resources.isEmpty
            ? [_noteWidget(painter: painter, text: labels.emptyDocumentNote)]
            : _body(painter: painter, snapshot: snapshot, labels: labels),
      ),
    );

    return pdfDocument.save();
  }

  /// The document's own body: one section per non-empty group, the plan's own grand total, then the
  /// needs/resources balance.
  List<pw.Widget> _body({
    required OcptScriptPagePainter painter,
    required OcptBudgetSnapshot snapshot,
    required OcptBudgetFinancingPlanLabels labels,
  }) {
    final groupTotals = ocptBudgetResourcesTotalByGroupKind(snapshot.resources);
    final grandTotalCents = ocptBudgetResourcesTotalCents(snapshot.resources);

    final allLines = [for (final poste in snapshot.postes) ...poste.lines];
    final needs = ocptBudgetTotalOf(
      allLines,
      basis: OcptBudgetTaxBasis.includingTax,
      projectVatRateBasisPoints: snapshot.defaultVatRateBasisPoints,
    );
    final balance = ocptBudgetNeedsResourcesBalanceOf(needs: needs, resourcesCents: grandTotalCents);

    return [
      for (final kind in OcptBudgetResourceGroupKind.values)
        if (groupTotals[kind] != null) ...[
          _groupSection(painter: painter, kind: kind, snapshot: snapshot, labels: labels),
          pw.SizedBox(height: 14),
        ],
      pw.Divider(color: _ruleColor, thickness: 0.5),
      pw.SizedBox(height: 4),
      _totalRow(
        painter: painter,
        label: labels.projectTotalLabel,
        text: ocptBudgetExportAmountLabel(grandTotalCents, snapshot.currencyCode),
        isBold: true,
      ),
      pw.SizedBox(height: 16),
      _balanceSection(painter: painter, balance: balance, snapshot: snapshot, labels: labels),
    ];
  }

  /// One group's own section: its title, its table of resources, then its own subtotal.
  pw.Widget _groupSection({
    required OcptScriptPagePainter painter,
    required OcptBudgetResourceGroupKind kind,
    required OcptBudgetSnapshot snapshot,
    required OcptBudgetFinancingPlanLabels labels,
  }) {
    final resources = [for (final resource in snapshot.resources) if (resource.groupKind == kind) resource];
    final subtotalCents = ocptBudgetResourcesTotalByGroupKind(snapshot.resources)[kind] ?? 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          labels.groupTitleOf(kind),
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
          columnWidths: _columnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                _headerCell(painter: painter, text: labels.labelHeader, align: pw.TextAlign.left),
                _headerCell(painter: painter, text: labels.statusHeader, align: pw.TextAlign.left),
                _headerCell(painter: painter, text: labels.amountHeader, align: pw.TextAlign.right),
                _headerCell(painter: painter, text: labels.receivedHeader, align: pw.TextAlign.right),
                _headerCell(painter: painter, text: labels.outstandingHeader, align: pw.TextAlign.right),
              ],
            ),
            for (final resource in resources)
              _resourceRow(painter: painter, resource: resource, snapshot: snapshot, labels: labels),
          ],
        ),
        pw.SizedBox(height: 4),
        _totalRow(
          painter: painter,
          label: labels.groupSubtotalLabel,
          text: ocptBudgetExportAmountLabel(subtotalCents, snapshot.currencyCode),
          isBold: false,
        ),
      ],
    );
  }

  /// One resource's own row: its label, its status, its amount, and what has come in and is still
  /// outstanding against it — an `inKind` resource with no entry naming it prints
  /// [ocptBudgetExportEmptyValue] for the last two, see the class doc comment.
  pw.TableRow _resourceRow({
    required OcptScriptPagePainter painter,
    required OcptBudgetResource resource,
    required OcptBudgetSnapshot snapshot,
    required OcptBudgetFinancingPlanLabels labels,
  }) {
    final receivedTotal = snapshot.receivedByResourceId[resource.id];
    final isUncollectedInKind = resource.groupKind == OcptBudgetResourceGroupKind.inKind && receivedTotal == null;

    String receivedText;
    String outstandingText;
    if (isUncollectedInKind) {
      receivedText = ocptBudgetExportEmptyValue;
      outstandingText = ocptBudgetExportEmptyValue;
    } else {
      final received = receivedTotal ?? const OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0);
      final outstandingCents = ocptBudgetResourceOutstandingCents(
        amountCents: resource.amountCents,
        receivedCents: received.amountCents,
      );
      receivedText = ocptBudgetExportCoveredAmountText(
        total: received,
        currencyCode: snapshot.currencyCode,
        coverageReadOutTemplate: labels.coverageReadOutTemplate,
      );
      outstandingText = ocptBudgetExportCoveredAmountText(
        total: OcptBudgetCoveredTotal(
          amountCents: outstandingCents,
          coveredLineCount: received.coveredLineCount,
          lineCount: received.lineCount,
        ),
        currencyCode: snapshot.currencyCode,
        coverageReadOutTemplate: labels.coverageReadOutTemplate,
      );
    }

    return pw.TableRow(
      children: [
        _textCell(painter: painter, text: resource.label, align: pw.TextAlign.left),
        _textCell(painter: painter, text: labels.statusLabelOf(resource.status), align: pw.TextAlign.left),
        _textCell(
          painter: painter,
          text: ocptBudgetExportAmountLabel(resource.amountCents, snapshot.currencyCode),
          align: pw.TextAlign.right,
        ),
        _textCell(painter: painter, text: receivedText, align: pw.TextAlign.right),
        _textCell(painter: painter, text: outstandingText, align: pw.TextAlign.right),
      ],
    );
  }

  /// The needs/resources balance printed under the plan's own grand total: the quote's own needs
  /// (tax-inclusive, always) against [balance]'s own resources, then the three-way verdict.
  pw.Widget _balanceSection({
    required OcptScriptPagePainter painter,
    required OcptBudgetNeedsResourcesBalance balance,
    required OcptBudgetSnapshot snapshot,
    required OcptBudgetFinancingPlanLabels labels,
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

  /// One header cell of a group's own table.
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
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
    ),
  );

  /// A right-aligned `<label>: <text>` line — a group's own subtotal, or the plan's own grand total.
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
    required OcptBudgetFinancingPlanLabels labels,
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

  /// A block of free text — the note standing in for the whole document on a project with no live
  /// resource at all.
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
