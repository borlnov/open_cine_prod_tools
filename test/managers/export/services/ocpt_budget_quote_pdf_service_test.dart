// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_quote_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the quote does — the same convention `ocpt_day_out_of_days_pdf_service_test.dart` follows.
const _labels = OcptBudgetQuoteLabels(
  fileNameSuffix: "quote",
  documentTitle: "Quote",
  versionLabel: "Version",
  lineLabelHeader: "Description",
  quantityHeader: "Qty",
  unitPriceHeader: "Unit price",
  lineTotalHeader: "Total",
  posteSubtotalLabel: "Poste total",
  projectTotalLabel: "Grand total",
  includingTaxCaption: "Amounts include tax",
  excludingTaxCaption: "Amounts exclude tax",
  noLinesLabel: "No line yet",
  emptyDocumentNote: "Nothing to quote yet.",
  coverageReadOutTemplate: "{amount} · over {coveredCount} of {totalCount}",
);

/// Builds a quote line, every field left at a neutral value unless the test overrides it.
OcptBudgetLine _buildLine({
  required String id,
  required String posteId,
  String label = "Line",
  int quantityMilli = 1000,
  String unit = "day",
  int unitAmountCents = 10000,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  String? elementId,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: label,
  quantityMilli: quantityMilli,
  unit: unit,
  unitPrice: OcptMoney(
    amountCents: unitAmountCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  elementId: elementId,
  notes: "",
  sortKey: "a",
);

/// Builds a poste holding [lines].
OcptBudgetPoste _buildPoste({
  required String id,
  String code = "1",
  String label = "Rights",
  List<OcptBudgetLine> lines = const [],
}) => OcptBudgetPoste(id: id, code: code, label: label, simpleLabel: null, sortKey: "a", lines: lines);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = OcptBudgetQuotePdfService();
  const pageSetup = OcptPageSetup.standard();

  OcptBudgetSnapshot buildSnapshot({List<OcptBudgetPoste> postes = const [], int? defaultVatRateBasisPoints}) =>
      OcptBudgetSnapshot.build(
        postes: postes,
        entries: const [],
        commitments: const [],
        defaultVatRateBasisPoints: defaultVatRateBasisPoints,
        currencyCode: "EUR",
      );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final snapshot = buildSnapshot(
        postes: [
          _buildPoste(id: "poste-1", lines: [_buildLine(id: "line-1", posteId: "poste-1")]),
        ],
      );

      final bytes = await service.generate(
        snapshot: snapshot,
        elementNameById: const {},
        pageSetup: pageSetup,
        taxBasis: OcptBudgetTaxBasis.includingTax,
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
        elementNameById: const {},
        pageSetup: pageSetup,
        taxBasis: OcptBudgetTaxBasis.includingTax,
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
        elementNameById: const {},
        pageSetup: pageSetup,
        taxBasis: OcptBudgetTaxBasis.includingTax,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });

    test("reading the same quote in the two tax bases prints two different documents", () async {
      final snapshot = buildSnapshot(
        postes: [
          _buildPoste(
            id: "poste-1",
            lines: [
              _buildLine(id: "line-1", posteId: "poste-1", vatRateBasisPoints: 2000),
            ],
          ),
        ],
      );

      Future<Uint8List> generateFor(OcptBudgetTaxBasis basis) => service.generate(
        snapshot: snapshot,
        elementNameById: const {},
        pageSetup: pageSetup,
        taxBasis: basis,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
      );

      expect(
        _contentStreams(await generateFor(OcptBudgetTaxBasis.includingTax)),
        isNot(_contentStreams(await generateFor(OcptBudgetTaxBasis.excludingTax))),
      );
    });

    test(
      "a line minted from a breakdown element prints its own name differently from a plain line",
      () async {
        final withElement = buildSnapshot(
          postes: [
            _buildPoste(
              id: "poste-1",
              lines: [_buildLine(id: "line-1", posteId: "poste-1", elementId: "element-1")],
            ),
          ],
        );
        final withoutElement = buildSnapshot(
          postes: [
            _buildPoste(id: "poste-1", lines: [_buildLine(id: "line-1", posteId: "poste-1")]),
          ],
        );

        Future<Uint8List> generateFor(OcptBudgetSnapshot snapshot) => service.generate(
          snapshot: snapshot,
          elementNameById: const {"element-1": "Vintage car"},
          pageSetup: pageSetup,
          taxBasis: OcptBudgetTaxBasis.includingTax,
          labels: _labels,
          projectName: "My Movie",
          includeTitlePage: false,
        );

        expect(
          _contentStreams(await generateFor(withElement)),
          isNot(_contentStreams(await generateFor(withoutElement))),
        );
      },
    );

    test("a poste holding no line at all still prints, with its own subtotal of zero", () async {
      final bytes = await service.generate(
        snapshot: buildSnapshot(postes: [_buildPoste(id: "poste-1")]),
        elementNameById: const {},
        pageSetup: pageSetup,
        taxBasis: OcptBudgetTaxBasis.includingTax,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
      );

      expect(ascii.decode(bytes.sublist(0, 4)), "%PDF");
      expect(_pageCount(bytes), 1);
    });
  });

  group("quoteFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(service.quoteFileName(projectName: "My Movie", suffix: "quote"), "My Movie - quote.pdf");
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.quoteFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
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
