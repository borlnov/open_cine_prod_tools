// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_financial_report_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the report does.
const _labels = OcptBudgetFinancialReportLabels(
  fileNameSuffix: "financial report",
  documentTitle: "Financial report",
  versionLabel: "Version",
  posteHeader: "Poste",
  quotedHeader: "Quoted",
  paidHeader: "Paid",
  committedHeader: "Committed",
  remainingHeader: "Remaining",
  varianceHeader: "Variance",
  projectTotalsLabel: "Totals",
  financingPlanTotalLabel: "Financing plan total",
  emptyDocumentNote: "Nothing to report yet.",
  coverageReadOutTemplate: "{amount} · over {coveredCount} of {totalCount}",
  balanceNeedsLabel: "Needs",
  balanceResourcesLabel: "Resources",
  balanceNoQuoteMessage: "No quote yet.",
  balanceBalancedMessage: "The plan covers the quote.",
  balanceShortfallMessageTemplate: "Short by {amount}.",
);

/// Builds a poste holding [lines].
OcptBudgetPoste _buildPoste({required String id, String code = "1", String label = "Rights", List<OcptBudgetLine> lines = const []}) =>
    OcptBudgetPoste(id: id, code: code, label: label, simpleLabel: null, sortKey: "a", lines: lines);

/// Builds a quote line at a plain tax-inclusive price, everything else neutral.
OcptBudgetLine _buildLine({required String id, required String posteId, int unitAmountCents = 10000}) =>
    OcptBudgetLine(
      id: id,
      posteId: posteId,
      label: "Line",
      quantityMilli: 1000,
      unit: "day",
      unitPrice: OcptMoney(amountCents: unitAmountCents, isTaxInclusive: true, vatRateBasisPoints: null),
      elementId: null,
      notes: "",
      sortKey: "a",
    );

/// Builds a debit entry against [posteId], everything else neutral.
OcptBudgetEntry _buildDebitEntry({required String id, required String posteId, required int debitCents}) =>
    OcptBudgetEntry(
      id: id,
      date: DateTime(2026),
      label: "",
      posteId: posteId,
      debitCents: debitCents,
      creditCents: 0,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: "J-001",
      sortKey: "a",
      resourceId: null,
      revenueId: null,
      shareId: null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = OcptBudgetFinancialReportPdfService();
  const pageSetup = OcptPageSetup.standard();

  OcptBudgetSnapshot buildSnapshot({List<OcptBudgetPoste> postes = const [], List<OcptBudgetEntry> entries = const []}) =>
      OcptBudgetSnapshot.build(
        postes: postes,
        entries: entries,
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await service.generate(
        snapshot: buildSnapshot(
          postes: [
            _buildPoste(id: "poste-1", lines: [_buildLine(id: "line-1", posteId: "poste-1")]),
          ],
        ),
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: true,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
    });

    test("the title page is one page of its own, and toggling it off drops it", () async {
      final snapshot = buildSnapshot(
        postes: [
          _buildPoste(id: "poste-1", lines: [_buildLine(id: "line-1", posteId: "poste-1")]),
        ],
      );

      Future<Uint8List> generateFor({required bool includeTitlePage}) => service.generate(
        snapshot: snapshot,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: includeTitlePage,
      );

      expect(_pageCount(await generateFor(includeTitlePage: true)), 2);
      expect(_pageCount(await generateFor(includeTitlePage: false)), 1);
    });

    test("a project with no poste at all prints the empty-document note", () async {
      final bytes = await service.generate(
        snapshot: buildSnapshot(),
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("a poste paid against prints differently from one nothing has moved against", () async {
      final untouched = buildSnapshot(
        postes: [
          _buildPoste(id: "poste-1", lines: [_buildLine(id: "line-1", posteId: "poste-1")]),
        ],
      );
      final paid = buildSnapshot(
        postes: [
          _buildPoste(id: "poste-1", lines: [_buildLine(id: "line-1", posteId: "poste-1")]),
        ],
        entries: [_buildDebitEntry(id: "entry-1", posteId: "poste-1", debitCents: 5000)],
      );

      Future<Uint8List> generateFor(OcptBudgetSnapshot snapshot) => service.generate(
        snapshot: snapshot,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
      );

      expect(_contentStreams(await generateFor(untouched)), isNot(_contentStreams(await generateFor(paid))));
    });
  });

  group("financialReportFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.financialReportFileName(projectName: "My Movie", suffix: "financial report"),
        "My Movie - financial report.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.financialReportFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
    });
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers (excluding `/Type /Pages`, the
/// tree node) — mirroring `ocpt_day_out_of_days_pdf_service_test.dart`'s own `_pageCount`.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r"/Type\s*/Page[^s]").allMatches(text).length;
}

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in [bytes], in file order —
/// mirroring `ocpt_day_out_of_days_pdf_service_test.dart`'s own `_contentStreams`.
List<String> _contentStreams(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final pattern = RegExp(r"stream\r?\n(.*?)endstream", dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}
