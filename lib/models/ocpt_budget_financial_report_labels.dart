// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// Every localized string the exported financial report carries, resolved by the caller.
///
/// `OcptBudgetFinancialReportPdfService` runs in the manager layer, where there is no
/// `BuildContext` and therefore no `Tr`: the same reason `OcptDayOutOfDaysLabels` and its own
/// siblings already exist for every export before it.
///
/// This report prints the very same readings `lib/utils/ocpt_budget_totals.dart` already computes
/// for the cost-tracking table (`Quoted`/`Paid`/`Committed`/`Remaining`/`Variance`), then the
/// financing plan's own total and `ocptBudgetNeedsResourcesBalanceOf`'s own verdict — so
/// [balanceNoQuoteMessage], [balanceBalancedMessage] and [balanceShortfallMessageTemplate] mirror
/// `OcptBudgetDashboard`'s own three-way reading of it, and [coverageReadOutTemplate] mirrors
/// `tr.budgetCostTrackingCoverageReadOut`, both read through
/// `lib/managers/export/services/ocpt_budget_pdf_shared.dart`'s own helpers, which fill in the
/// `{amount}`/`{coveredCount}`/`{totalCount}` placeholders a manager-layer service cannot ask `Tr`
/// to interpolate itself.
class OcptBudgetFinancialReportLabels extends Equatable {
  /// The localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - financial report.pdf`). A blank one falls back to the project name alone, exactly
  /// as its siblings do.
  final String fileNameSuffix;

  /// The document's own generic name, printed as the title page's own document name and in every
  /// page's own running head.
  final String documentTitle;

  /// The label the moment this export was produced is printed under (`Version`).
  final String versionLabel;

  /// The header of the poste column.
  final String posteHeader;

  /// The header of a poste's own quoted total column.
  final String quotedHeader;

  /// The header of a poste's own paid total column.
  final String paidHeader;

  /// The header of a poste's own committed total column.
  final String committedHeader;

  /// The header of a poste's own remaining column.
  final String remainingHeader;

  /// The header of a poste's own variance column.
  final String varianceHeader;

  /// The label printed beside the project's own totals row, at the very end of the table.
  final String projectTotalsLabel;

  /// The label printed beside the financing plan's own grand total, under the table.
  final String financingPlanTotalLabel;

  /// The note the whole document prints when the project holds no poste at all.
  final String emptyDocumentNote;

  /// The template a total's own coverage read-out is built from — see the class doc comment.
  final String coverageReadOutTemplate;

  /// The needs/resources balance's own "needs" side label.
  final String balanceNeedsLabel;

  /// The needs/resources balance's own "resources" side label.
  final String balanceResourcesLabel;

  /// The verdict printed when the quote holds no line at all.
  final String balanceNoQuoteMessage;

  /// The verdict printed once the plan covers the quote.
  final String balanceBalancedMessage;

  /// The verdict printed while the plan still falls short, its own `{amount}` placeholder filled
  /// in with how far.
  final String balanceShortfallMessageTemplate;

  /// Class constructor
  const OcptBudgetFinancialReportLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.versionLabel,
    required this.posteHeader,
    required this.quotedHeader,
    required this.paidHeader,
    required this.committedHeader,
    required this.remainingHeader,
    required this.varianceHeader,
    required this.projectTotalsLabel,
    required this.financingPlanTotalLabel,
    required this.emptyDocumentNote,
    required this.coverageReadOutTemplate,
    required this.balanceNeedsLabel,
    required this.balanceResourcesLabel,
    required this.balanceNoQuoteMessage,
    required this.balanceBalancedMessage,
    required this.balanceShortfallMessageTemplate,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetFinancialReportLabels(documentTitle: $documentTitle)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    versionLabel,
    posteHeader,
    quotedHeader,
    paidHeader,
    committedHeader,
    remainingHeader,
    varianceHeader,
    projectTotalsLabel,
    financingPlanTotalLabel,
    emptyDocumentNote,
    coverageReadOutTemplate,
    balanceNeedsLabel,
    balanceResourcesLabel,
    balanceNoQuoteMessage,
    balanceBalancedMessage,
    balanceShortfallMessageTemplate,
  ];
}
