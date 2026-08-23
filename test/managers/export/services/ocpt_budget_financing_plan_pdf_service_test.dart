// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_financing_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';

/// Every localized string of the document, filled with recognisable placeholders: nothing here
/// asserts on the printed text (Courier Prime is embedded as an Identity-H composite font, so a
/// content stream holds glyph indices rather than readable characters), only on what changes when
/// the financing plan does.
const _labels = OcptBudgetFinancingPlanLabels(
  fileNameSuffix: "financing plan",
  documentTitle: "Financing plan",
  versionLabel: "Version",
  groupTitles: {
    OcptBudgetResourceGroupKind.subsidy: "Subsidies",
    OcptBudgetResourceGroupKind.cash: "Cash contributions",
    OcptBudgetResourceGroupKind.inKind: "In-kind contributions",
  },
  statusLabels: {
    OcptBudgetResourceGroupKind.subsidy: {
      OcptBudgetResourceStatus.pending: "Applied",
      OcptBudgetResourceStatus.agreed: "Notified",
      OcptBudgetResourceStatus.confirmed: "Secured",
    },
    OcptBudgetResourceGroupKind.cash: {
      OcptBudgetResourceStatus.pending: "Requested",
      OcptBudgetResourceStatus.agreed: "Agreed",
      OcptBudgetResourceStatus.confirmed: "Contracted",
    },
    OcptBudgetResourceGroupKind.inKind: {
      OcptBudgetResourceStatus.pending: "Promised",
      OcptBudgetResourceStatus.agreed: "Valued",
      OcptBudgetResourceStatus.confirmed: "Signed",
    },
  },
  labelHeader: "Label",
  statusHeader: "Status",
  amountHeader: "Amount",
  receivedHeader: "Received",
  outstandingHeader: "Outstanding",
  groupSubtotalLabel: "Group total",
  projectTotalLabel: "Grand total",
  emptyDocumentNote: "Nothing to finance yet.",
  balanceNeedsLabel: "Needs",
  balanceResourcesLabel: "Resources",
  balanceNoQuoteMessage: "No quote yet.",
  balanceBalancedMessage: "The plan covers the quote.",
  balanceShortfallMessageTemplate: "Short by {amount}.",
  coverageReadOutTemplate: "{amount} · over {coveredCount} of {totalCount}",
);

/// Builds a resource, every field left at a neutral value unless the test overrides it.
OcptBudgetResource _buildResource({
  required String id,
  required OcptBudgetResourceGroupKind groupKind,
  String label = "Resource",
  int amountCents = 100000,
  OcptBudgetResourceStatus status = OcptBudgetResourceStatus.pending,
  bool isReimbursable = false,
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  personId: null,
  label: label,
  amountCents: amountCents,
  status: status,
  isReimbursable: isReimbursable,
  notes: "",
  sortKey: "a",
);

/// Builds an entry crediting [resourceId], everything else neutral.
OcptBudgetEntry _buildCreditEntry({required String id, required String resourceId, required int creditCents}) =>
    OcptBudgetEntry(
      id: id,
      date: DateTime(2026),
      label: "",
      posteId: null,
      debitCents: 0,
      creditCents: creditCents,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: "J-001",
      sortKey: "a",
      resourceId: resourceId,
      revenueId: null,
      shareId: null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = OcptBudgetFinancingPlanPdfService();
  const pageSetup = OcptPageSetup.standard();

  OcptBudgetSnapshot buildSnapshot({
    List<OcptBudgetPoste> postes = const [],
    List<OcptBudgetResource> resources = const [],
    List<OcptBudgetEntry> entries = const [],
  }) => OcptBudgetSnapshot.build(
    postes: postes,
    entries: entries,
    commitments: const [],
    resources: resources,
    defaultVatRateBasisPoints: null,
    currencyCode: "EUR",
  );

  group("generate", () {
    test("produces bytes starting with the %PDF magic string", () async {
      final bytes = await service.generate(
        snapshot: buildSnapshot(
          resources: [_buildResource(id: "res-1", groupKind: OcptBudgetResourceGroupKind.subsidy)],
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
        resources: [_buildResource(id: "res-1", groupKind: OcptBudgetResourceGroupKind.subsidy)],
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

    test("a project with no live resource at all prints the empty-document note", () async {
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

    test("an in-kind resource with an entry naming it prints differently from one with none", () async {
      final uncollected = buildSnapshot(
        resources: [_buildResource(id: "res-1", groupKind: OcptBudgetResourceGroupKind.inKind)],
      );
      final collected = buildSnapshot(
        resources: [_buildResource(id: "res-1", groupKind: OcptBudgetResourceGroupKind.inKind)],
        entries: [_buildCreditEntry(id: "entry-1", resourceId: "res-1", creditCents: 50000)],
      );

      Future<Uint8List> generateFor(OcptBudgetSnapshot snapshot) => service.generate(
        snapshot: snapshot,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
      );

      expect(_contentStreams(await generateFor(uncollected)), isNot(_contentStreams(await generateFor(collected))));
    });

    test("a quote with no line at all prints a different verdict from a covered one", () async {
      final noQuote = buildSnapshot(
        resources: [_buildResource(id: "res-1", groupKind: OcptBudgetResourceGroupKind.cash)],
      );
      final covered = buildSnapshot(
        postes: [
          const OcptBudgetPoste(
            id: "poste-1",
            code: "1",
            label: "Rights",
            simpleLabel: null,
            estimateToCompleteCents: null,
            sortKey: "a",
            lines: [
              OcptBudgetLine(
                id: "line-1",
                posteId: "poste-1",
                label: "Line",
                quantityMilli: 1000,
                unit: "day",
                unitPrice: OcptMoney(amountCents: 10000, isTaxInclusive: true, vatRateBasisPoints: null),
                elementId: null,
                provisionKey: null,
                provisionDigest: null,
                notes: "",
                sortKey: "a",
              ),
            ],
          ),
        ],
        resources: [_buildResource(id: "res-1", groupKind: OcptBudgetResourceGroupKind.cash)],
      );

      Future<Uint8List> generateFor(OcptBudgetSnapshot snapshot) => service.generate(
        snapshot: snapshot,
        pageSetup: pageSetup,
        labels: _labels,
        projectName: "My Movie",
        includeTitlePage: false,
      );

      expect(_contentStreams(await generateFor(noQuote)), isNot(_contentStreams(await generateFor(covered))));
    });
  });

  group("financingPlanFileName", () {
    test("joins the project name and the localized suffix", () {
      expect(
        service.financingPlanFileName(projectName: "My Movie", suffix: "financing plan"),
        "My Movie - financing plan.pdf",
      );
    });

    test("a blank suffix falls back to the project name alone", () {
      expect(service.financingPlanFileName(projectName: "My Movie", suffix: "   "), "My Movie.pdf");
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
