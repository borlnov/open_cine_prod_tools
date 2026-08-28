// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_journal.dart';

/// Renders the cash journal into the bytes of an XLSX workbook.
///
/// This is pure in-memory workbook building with no I/O of its own (no dialog, no file system
/// access): it's owned by `OcptExportManager` and exposed as a public final field, reached through
/// the manager rather than through `globalGetIt()` (RFL18), exactly like `OcptShotListXlsxExportService`
/// and its own siblings. **A `const` service, like every other workbook service in this app**: a
/// workbook takes no page geometry and no font loader at all (`docs/architecture/exports.md`).
///
/// The sheet is one header row, then one row per live entry in **the journal's own chronological
/// order** — `ocptBudgetJournalRowsOf`'s own reading of `OcptBudgetSnapshot.entries`, never
/// reordered here — then a trailing totals row.
///
/// **The running balance keeps `ocptBudgetJournalRowsOf`'s own honesty intact**: a row whose
/// [OcptBudgetJournalRow.balanceAfterCents] is null writes an **empty cell**, never the balance
/// before it and never a guess (`docs/architecture/budget.md`'s own "Money that has moved is read
/// tax-inclusive, always").
///
/// **"What the entry settles" is a plain string column fed by `linkLabelByEntryId`**, a map the
/// caller hands in — this service resolves nothing itself, which is what keeps it independent of
/// `budget_revenues`/`budget_shares`: an entry naming a revenue or a share simply arrives with a
/// label in that map once the mode fills it in.
class OcptBudgetCashJournalXlsxExportService {
  /// The extension of an Excel workbook file, without its leading dot.
  static const xlsxFileExtension = "xlsx";

  /// The sheet name used when the caller's own [OcptBudgetCashJournalXlsxLabels.sheetName] is
  /// blank.
  ///
  /// A workbook whose only sheet has no name is not a valid one, so a missing (or whitespace-only)
  /// localized name falls back to this rather than producing a file no spreadsheet can open.
  static const fallbackSheetName = "Cash journal";

  /// Class constructor
  const OcptBudgetCashJournalXlsxExportService();

  /// The `.xlsx` file name to suggest when exporting the cash journal of the project named
  /// [projectName]. [episodeTag] is the selected episode's own tag, present only while the open
  /// project holds more than one episode — see `ocptExportFileNameOf`'s own doc comment. In
  /// practice the cash journal is never scoped to one episode (`docs/architecture/budget.md`'s own
  /// "one budget for the whole production"), so a caller never actually passes one; the parameter
  /// stays for the same reason every other file-name method here carries it.
  String xlsxFileName({required String projectName, String? episodeTag}) => ocptExportFileNameOf(
    projectName: projectName,
    episodeTag: episodeTag,
    extension: xlsxFileExtension,
  );

  /// Builds the workbook holding [snapshot]'s whole cash journal, titled and headed with [labels],
  /// and returns its bytes.
  ///
  /// [linkLabelByEntryId] is the "what this entry settles" column's own text, keyed by
  /// `OcptBudgetEntry.id` — see the class doc comment. Throws a [StateError] if the workbook cannot
  /// be encoded, which the caller reports as a failed export: `excel_community` returns null there
  /// rather than throwing anything of its own.
  Uint8List generate({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> linkLabelByEntryId,
    required OcptBudgetCashJournalXlsxLabels labels,
  }) {
    final excel = Excel.createExcel();
    final sheetName = _sheetNameOf(labels);
    _renameDefaultSheet(excel, sheetName);

    final sheet = excel[sheetName];
    _appendHeaderRow(sheet, labels);

    final posteLabelById = {for (final poste in snapshot.postes) poste.id: poste.label};
    final rows = ocptBudgetJournalRowsOf(
      snapshot.entries,
      projectVatRateBasisPoints: snapshot.defaultVatRateBasisPoints,
    );
    for (final row in rows) {
      sheet.appendRow(
        _rowCellsOf(row: row, posteLabelById: posteLabelById, linkLabelByEntryId: linkLabelByEntryId),
      );
    }

    _appendTotalsRow(sheet, snapshot.cashTotals, labels);

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError("The cash journal workbook could not be encoded");
    }

    return Uint8List.fromList(bytes);
  }

  /// The name to give the workbook's single sheet: [labels]'s own, or [fallbackSheetName] when it
  /// holds nothing but whitespace.
  String _sheetNameOf(OcptBudgetCashJournalXlsxLabels labels) =>
      labels.sheetName.trim().isEmpty ? fallbackSheetName : labels.sheetName;

  /// Renames the sheet [Excel.createExcel] starts from to [sheetName], mirroring
  /// `OcptShotListXlsxExportService._renameDefaultSheet` exactly.
  void _renameDefaultSheet(Excel excel, String sheetName) {
    final defaultSheetName = excel.getDefaultSheet();
    if (defaultSheetName == null || defaultSheetName == sheetName) {
      return;
    }

    excel.rename(defaultSheetName, sheetName);
  }

  /// Appends the sheet's single header row, one cell per column, and emboldens it.
  void _appendHeaderRow(Sheet sheet, OcptBudgetCashJournalXlsxLabels labels) {
    final headerRowIndex = sheet.maxRows;
    final headers = [
      labels.dateHeader,
      labels.voucherHeader,
      labels.labelHeader,
      labels.posteHeader,
      labels.settlesHeader,
      labels.debitHeader,
      labels.creditHeader,
      labels.balanceHeader,
    ];
    sheet.appendRow([for (final header in headers) TextCellValue(header)]);

    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: headerRowIndex))
          .cellStyle = CellStyle(bold: true);
    }
  }

  /// One journal row's own cells, in column order — see the class doc comment for the honesty each
  /// one keeps.
  List<CellValue?> _rowCellsOf({
    required OcptBudgetJournalRow row,
    required Map<String, String> posteLabelById,
    required Map<String, String> linkLabelByEntryId,
  }) {
    final entry = row.entry;

    return [
      TextCellValue(_isoDate(entry.date)),
      TextCellValue(entry.voucherNumber),
      _textOrNull(entry.label),
      _textOrNull(entry.posteId == null ? null : posteLabelById[entry.posteId]),
      _textOrNull(linkLabelByEntryId[entry.id]),
      switch (row.debitCents) {
        final cents? => DoubleCellValue(cents / 100),
        null => null,
      },
      switch (row.creditCents) {
        final cents? => DoubleCellValue(cents / 100),
        null => null,
      },
      switch (row.balanceAfterCents) {
        final cents? => DoubleCellValue(cents / 100),
        null => null,
      },
    ];
  }

  /// Appends the trailing totals row: [totals]' own debit, credit and balance, bolded, under
  /// [labels]'s own [OcptBudgetCashJournalXlsxLabels.totalsRowLabel].
  void _appendTotalsRow(Sheet sheet, OcptBudgetCashTotals totals, OcptBudgetCashJournalXlsxLabels labels) {
    final totalsRowIndex = sheet.maxRows;
    sheet.appendRow([
      TextCellValue(labels.totalsRowLabel),
      null,
      null,
      null,
      null,
      DoubleCellValue(totals.debitCents / 100),
      DoubleCellValue(totals.creditCents / 100),
      DoubleCellValue(totals.balanceCents / 100),
    ]);

    for (var columnIndex = 0; columnIndex < 8; columnIndex++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: totalsRowIndex))
          .cellStyle = CellStyle(bold: true);
    }
  }

  /// A text cell holding [value], or null when it is null or holds nothing but whitespace —
  /// mirroring `OcptShotListXlsxExportService._textOrNull`.
  CellValue? _textOrNull(String? value) => value == null || value.trim().isEmpty ? null : TextCellValue(value);

  /// [date] as `yyyy-MM-dd`, mirroring `OcptResourcesXlsxExportService._isoDate`.
  String _isoDate(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-"
      "${date.day.toString().padLeft(2, '0')}";
}
