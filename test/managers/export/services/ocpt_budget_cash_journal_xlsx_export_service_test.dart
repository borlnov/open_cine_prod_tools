// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_cash_journal_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';

/// The sheet name every test here exports under.
const _sheetName = "Cash journal";

/// Builds the labels the tests export with: a header naming each column after its own role, so an
/// assertion can tell any two columns apart without depending on the app's own translations.
OcptBudgetCashJournalXlsxLabels _buildLabels({String sheetName = _sheetName}) => OcptBudgetCashJournalXlsxLabels(
  sheetName: sheetName,
  dateHeader: "Date",
  voucherHeader: "Voucher",
  labelHeader: "Label",
  posteHeader: "Poste",
  settlesHeader: "Settles",
  debitHeader: "Debit",
  creditHeader: "Credit",
  balanceHeader: "Balance",
  totalsRowLabel: "Total",
);

/// Builds an entry, every field left at a neutral value unless the test overrides it.
OcptBudgetEntry _buildEntry({
  required String id,
  required DateTime date,
  String label = "",
  String? posteId,
  int debitCents = 0,
  int creditCents = 0,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  String voucherNumber = "J-001",
  String? resourceId,
}) => OcptBudgetEntry(
  id: id,
  date: date,
  label: label,
  posteId: posteId,
  debitCents: debitCents,
  creditCents: creditCents,
  isTaxInclusive: isTaxInclusive,
  vatRateBasisPoints: vatRateBasisPoints,
  voucherNumber: voucherNumber,
  sortKey: "a",
  resourceId: resourceId,
  revenueId: null,
  shareId: null,
);

/// Builds a poste holding no line, only what this test reads: its own id and label.
OcptBudgetPoste _buildPoste({required String id, required String code, required String label}) =>
    OcptBudgetPoste(id: id, code: code, label: label, simpleLabel: null, estimateToCompleteCents: null, sortKey: "a", lines: const []);

/// Decodes [bytes] and returns the rows of its [_sheetName] sheet, as plain Dart values — mirroring
/// `ocpt_shot_list_xlsx_export_service_test.dart`'s own `_rowsOf`.
List<List<Object?>> _rowsOf(List<int> bytes, {String sheetName = _sheetName}) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables[sheetName];
  expect(sheet, isNotNull, reason: "the workbook has no sheet named $sheetName");

  return [
    for (final row in sheet!.rows) [for (final cell in row) _valueOf(cell)],
  ];
}

/// The plain Dart value [cell] holds, or null when it is empty.
///
/// A whole-number amount round-trips through the workbook as an [IntCellValue] rather than a
/// [DoubleCellValue] — `excel_community`'s own storage optimisation — so this reads it back as a
/// `double` too, mirroring `ocpt_shot_list_xlsx_export_service_test.dart`'s own `_valueOf`.
Object? _valueOf(Data? cell) => switch (cell?.value) {
  TextCellValue(:final value) => value.toString(),
  IntCellValue(:final value) => value.toDouble(),
  DoubleCellValue(:final value) => value,
  null => null,
  final other => other.toString(),
};

void main() {
  const service = OcptBudgetCashJournalXlsxExportService();

  group("xlsxFileName", () {
    test("appends the .xlsx extension to the project name", () {
      expect(service.xlsxFileName(projectName: "My Movie"), "My Movie.xlsx");
    });
  });

  group("generate", () {
    test("writes one row per entry, in the journal's own order, then a totals row", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: [_buildPoste(id: "poste-1", code: "1", label: "Rights")],
        entries: [
          _buildEntry(
            id: "entry-1",
            date: DateTime(2026, 1, 5),
            label: "Deposit",
            creditCents: 100000,
          ),
          _buildEntry(
            id: "entry-2",
            date: DateTime(2026, 1, 10),
            label: "Rights fee",
            posteId: "poste-1",
            debitCents: 25000,
            voucherNumber: "J-002",
          ),
        ],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );

      final rows = _rowsOf(
        service.generate(
          snapshot: snapshot,
          linkLabelByEntryId: const {},
          labels: _buildLabels(),
        ),
      );

      expect(rows, hasLength(4));
      expect(rows.first, ["Date", "Voucher", "Label", "Poste", "Settles", "Debit", "Credit", "Balance"]);

      // entry-1: a credit of 1,000.00 €, no debit at all — a real zero, printed as data rather
      // than left blank, since the movement is fully readable — balance after is 1,000.00 €.
      expect(rows[1], ["2026-01-05", "J-001", "Deposit", null, null, 0.0, 1000.0, 1000.0]);

      // entry-2: a debit of 250.00 € against poste-1, no credit at all, balance after is 750.00 €.
      expect(rows[2], ["2026-01-10", "J-002", "Rights fee", "Rights", null, 250.0, 0.0, 750.0]);

      // The totals row: the journal's own debit, credit and balance.
      expect(rows[3], ["Total", null, null, null, null, 250.0, 1000.0, 750.0]);
    });

    test("prints what an entry settles from the caller's own map, resolving nothing itself", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: const [],
        entries: [_buildEntry(id: "entry-1", date: DateTime(2026, 1, 5), creditCents: 5000)],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );

      final rows = _rowsOf(
        service.generate(
          snapshot: snapshot,
          linkLabelByEntryId: const {"entry-1": "Regional grant"},
          labels: _buildLabels(),
        ),
      );

      expect(rows[1][4], "Regional grant");
    });

    test(
      "a row this basis cannot read leaves its own balance an empty cell, never a repeat or a guess",
      () {
        final snapshot = OcptBudgetSnapshot.build(
          postes: const [],
          entries: [
            _buildEntry(id: "entry-1", date: DateTime(2026), creditCents: 10000),
            // Typed excluding tax, no rate anywhere to gross it back up with: unreadable.
            _buildEntry(
              id: "entry-2",
              date: DateTime(2026, 1, 2),
              debitCents: 5000,
              isTaxInclusive: false,
            ),
            _buildEntry(id: "entry-3", date: DateTime(2026, 1, 3), debitCents: 2000),
          ],
          commitments: const [],
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
        );

        final rows = _rowsOf(
          service.generate(snapshot: snapshot, linkLabelByEntryId: const {}, labels: _buildLabels()),
        );

        // entry-1: balance 100.00 €.
        expect(rows[1][7], 100.0);
        // entry-2: unreadable — debit, credit and balance are all empty cells.
        expect(rows[2][5], isNull);
        expect(rows[2][6], isNull);
        expect(rows[2][7], isNull);
        // entry-3 resumes counting from exactly where the journal stood before the hole: 80.00 €,
        // never poisoned by the gap above it.
        expect(rows[3][7], 80.0);
      },
    );

    test("names the single sheet after the labels, with no leftover default sheet", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: const [],
        entries: const [],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );

      final excel = Excel.decodeBytes(
        service.generate(
          snapshot: snapshot,
          linkLabelByEntryId: const {},
          labels: _buildLabels(sheetName: "Trésorerie"),
        ),
      );

      expect(excel.tables.keys, ["Trésorerie"]);
    });

    test("falls back to a valid sheet name when the labels carry a blank one", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: const [],
        entries: const [],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );

      final excel = Excel.decodeBytes(
        service.generate(snapshot: snapshot, linkLabelByEntryId: const {}, labels: _buildLabels(sheetName: "   ")),
      );

      expect(excel.tables.keys, [OcptBudgetCashJournalXlsxExportService.fallbackSheetName]);
    });
  });
}
