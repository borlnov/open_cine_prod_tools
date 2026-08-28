// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// Every localized string the exported cash journal workbook carries, resolved by the caller.
///
/// `OcptBudgetCashJournalXlsxExportService` runs in the manager layer, where there is no
/// `BuildContext` and therefore no `Tr`: the same reason `OcptShotListXlsxLabels` and its own
/// siblings already exist for every export before it.
class OcptBudgetCashJournalXlsxLabels extends Equatable {
  /// The name given to the workbook's single sheet.
  final String sheetName;

  /// The header of the entry's own date column.
  final String dateHeader;

  /// The header of the entry's own voucher number column.
  final String voucherHeader;

  /// The header of the entry's own label column.
  final String labelHeader;

  /// The header of the entry's own poste column — an entry naming no poste (money coming in prices
  /// no poste) writes an empty cell there, never a placeholder word.
  final String posteHeader;

  /// The header of what the entry settles — a resource or a share, once the tables that name them
  /// exist; an entry naming neither writes an empty cell there too.
  final String settlesHeader;

  /// The header of the entry's own debit column.
  final String debitHeader;

  /// The header of the entry's own credit column.
  final String creditHeader;

  /// The header of the running balance column.
  final String balanceHeader;

  /// The label of the trailing totals row.
  final String totalsRowLabel;

  /// Class constructor
  const OcptBudgetCashJournalXlsxLabels({
    required this.sheetName,
    required this.dateHeader,
    required this.voucherHeader,
    required this.labelHeader,
    required this.posteHeader,
    required this.settlesHeader,
    required this.debitHeader,
    required this.creditHeader,
    required this.balanceHeader,
    required this.totalsRowLabel,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetCashJournalXlsxLabels(sheetName: $sheetName)";

  /// Object properties
  @override
  List<Object?> get props => [
    sheetName,
    dateHeader,
    voucherHeader,
    labelHeader,
    posteHeader,
    settlesHeader,
    debitHeader,
    creditHeader,
    balanceHeader,
    totalsRowLabel,
  ];
}
