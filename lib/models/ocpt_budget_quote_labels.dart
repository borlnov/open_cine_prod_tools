// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';

/// Every localized string the exported quote carries, resolved by the caller.
///
/// `OcptBudgetQuotePdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptDayOutOfDaysLabels` and its own siblings already exist
/// for every export before it.
///
/// [coverageReadOutTemplate] mirrors `tr.budgetCostTrackingCoverageReadOut` word for word, with
/// `{amount}`, `{coveredCount}` and `{totalCount}` placeholders standing in for the figures a
/// manager-layer service cannot ask `Tr` to interpolate itself — `ocptBudgetExportCoveredAmountText`
/// (`lib/managers/export/services/ocpt_budget_pdf_shared.dart`) is what fills them in.
class OcptBudgetQuoteLabels extends Equatable {
  /// The localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - quote.pdf`). A blank one falls back to the project name alone, exactly as its
  /// siblings do.
  final String fileNameSuffix;

  /// The document's own generic name, printed as the title page's own document name and in every
  /// page's own running head.
  final String documentTitle;

  /// The label the moment this export was produced is printed under (`Version`), mirroring
  /// `OcptDayOutOfDaysLabels.versionLabel`.
  final String versionLabel;

  /// The header of a quote line's own label column.
  final String lineLabelHeader;

  /// The header of a quote line's own quantity-and-unit column.
  final String quantityHeader;

  /// The header of a quote line's own unit-price column.
  final String unitPriceHeader;

  /// The header of a quote line's own total column.
  final String lineTotalHeader;

  /// The label printed beside a poste's own subtotal row.
  final String posteSubtotalLabel;

  /// The label printed beside the project's own grand total, at the very end of the document.
  final String projectTotalLabel;

  /// The caption stating every amount is printed including tax — `OcptBudgetTaxBasis.includingTax`.
  final String includingTaxCaption;

  /// The caption stating every amount is printed excluding tax — `OcptBudgetTaxBasis.excludingTax`.
  final String excludingTaxCaption;

  /// The note a poste holding no line at all prints in place of its own table.
  final String noLinesLabel;

  /// The note the whole document prints in place of every poste when the project holds none at
  /// all.
  final String emptyDocumentNote;

  /// The template a total's own coverage read-out is built from — see the class doc comment.
  final String coverageReadOutTemplate;

  /// Class constructor
  const OcptBudgetQuoteLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.versionLabel,
    required this.lineLabelHeader,
    required this.quantityHeader,
    required this.unitPriceHeader,
    required this.lineTotalHeader,
    required this.posteSubtotalLabel,
    required this.projectTotalLabel,
    required this.includingTaxCaption,
    required this.excludingTaxCaption,
    required this.noLinesLabel,
    required this.emptyDocumentNote,
    required this.coverageReadOutTemplate,
  });

  /// The caption stating which of the two bases [basis] itself is — [includingTaxCaption] or
  /// [excludingTaxCaption].
  String taxBasisCaptionOf(OcptBudgetTaxBasis basis) =>
      basis == OcptBudgetTaxBasis.includingTax ? includingTaxCaption : excludingTaxCaption;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptBudgetQuoteLabels(documentTitle: $documentTitle)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    versionLabel,
    lineLabelHeader,
    quantityHeader,
    unitPriceHeader,
    lineTotalHeader,
    posteSubtotalLabel,
    projectTotalLabel,
    includingTaxCaption,
    excludingTaxCaption,
    noLinesLabel,
    emptyDocumentNote,
    coverageReadOutTemplate,
  ];
}
