// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';

/// Every localized string the exported financing plan carries, resolved by the caller.
///
/// `OcptBudgetFinancingPlanPdfService` runs in the manager layer, where there is no `BuildContext`
/// and therefore no `Tr`: the same reason `OcptDayOutOfDaysLabels` and its own siblings already
/// exist for every export before it.
///
/// [balanceNoQuoteMessage], [balanceBalancedMessage] and [balanceShortfallMessageTemplate] mirror
/// `OcptBudgetDashboard`'s own three-way verdict over `ocptBudgetNeedsResourcesBalanceOf`
/// (`docs/architecture/budget.md`), and [coverageReadOutTemplate] mirrors
/// `tr.budgetCostTrackingCoverageReadOut` — both read through
/// `lib/managers/export/services/ocpt_budget_pdf_shared.dart`'s own helpers, which fill in the
/// `{amount}`/`{coveredCount}`/`{totalCount}` placeholders a manager-layer service cannot ask `Tr`
/// to interpolate itself.
///
/// Every map accessor returns an empty string for a key it holds nothing for, exactly as its
/// siblings' do.
class OcptBudgetFinancingPlanLabels extends Equatable {
  /// The localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - financing plan.pdf`). A blank one falls back to the project name alone, exactly
  /// as its siblings do.
  final String fileNameSuffix;

  /// The document's own generic name, printed as the title page's own document name and in every
  /// page's own running head.
  final String documentTitle;

  /// The label the moment this export was produced is printed under (`Version`).
  final String versionLabel;

  /// The section title of each `OcptBudgetResourceGroupKind`, printed once per group holding at
  /// least one live resource — a group holding none is not drawn at all, exactly as
  /// `OcptBudgetFinancing` draws none for it.
  final Map<OcptBudgetResourceGroupKind, String> groupTitles;

  /// The label of each `OcptBudgetResourceStatus`.
  final Map<OcptBudgetResourceStatus, String> statusLabels;

  /// The header of a resource's own label column.
  final String labelHeader;

  /// The header of a resource's own status column.
  final String statusHeader;

  /// The header of a resource's own amount column.
  final String amountHeader;

  /// The header of what has come in against a resource.
  final String receivedHeader;

  /// The header of what is still outstanding against a resource.
  final String outstandingHeader;

  /// The label printed beside a group's own subtotal row.
  final String groupSubtotalLabel;

  /// The label printed beside the plan's own grand total, at the very end of the document.
  final String projectTotalLabel;

  /// The note the whole document prints when the project holds no live resource at all.
  final String emptyDocumentNote;

  /// The needs/resources balance's own "needs" side label.
  final String balanceNeedsLabel;

  /// The needs/resources balance's own "resources" side label.
  final String balanceResourcesLabel;

  /// The verdict printed when the quote holds no line at all — see the class doc comment.
  final String balanceNoQuoteMessage;

  /// The verdict printed once the plan covers the quote.
  final String balanceBalancedMessage;

  /// The verdict printed while the plan still falls short, its own `{amount}` placeholder filled
  /// in with how far.
  final String balanceShortfallMessageTemplate;

  /// The template a total's own coverage read-out is built from — see the class doc comment.
  final String coverageReadOutTemplate;

  /// Class constructor
  const OcptBudgetFinancingPlanLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.versionLabel,
    required this.groupTitles,
    required this.statusLabels,
    required this.labelHeader,
    required this.statusHeader,
    required this.amountHeader,
    required this.receivedHeader,
    required this.outstandingHeader,
    required this.groupSubtotalLabel,
    required this.projectTotalLabel,
    required this.emptyDocumentNote,
    required this.balanceNeedsLabel,
    required this.balanceResourcesLabel,
    required this.balanceNoQuoteMessage,
    required this.balanceBalancedMessage,
    required this.balanceShortfallMessageTemplate,
    required this.coverageReadOutTemplate,
  });

  /// The section title of [kind], or an empty string if [groupTitles] holds none for it.
  String groupTitleOf(OcptBudgetResourceGroupKind kind) => groupTitles[kind] ?? "";

  /// The label of [status], or an empty string if [statusLabels] holds none for it.
  String statusLabelOf(OcptBudgetResourceStatus status) => statusLabels[status] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetFinancingPlanLabels(documentTitle: $documentTitle)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    versionLabel,
    groupTitles,
    statusLabels,
    labelHeader,
    statusHeader,
    amountHeader,
    receivedHeader,
    outstandingHeader,
    groupSubtotalLabel,
    projectTotalLabel,
    emptyDocumentNote,
    balanceNeedsLabel,
    balanceResourcesLabel,
    balanceNoQuoteMessage,
    balanceBalancedMessage,
    balanceShortfallMessageTemplate,
    coverageReadOutTemplate,
  ];
}
