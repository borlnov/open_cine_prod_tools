// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:ui';

import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_cash_journal_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_financial_report_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_financing_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_budget_quote_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_write_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_export_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';

/// The export of the budget mode's four documents: each one renders its document and hands the
/// bytes to the write funnel.
abstract final class OcptBudgetExportOps {
  /// Render the quote of [snapshot] via [budgetQuotePdfService] and show the native save dialog
  /// to write it out.
  ///
  /// [elementNameById] names every breakdown element a quote line prices
  /// (`OcptBudgetLine.elementId`), resolved by the caller — this manager has no `Tr` of its own.
  /// [labels] carries every localized string the document itself holds and [fileTypeLabel] the one
  /// the native dialog needs. Returns the write funnel's own outcome, or null if the user cancelled
  /// or the save failed (failures are logged; the OS dialog already reported a cancellation to the
  /// user).
  static Future<OcptExportOutcome?> exportBudgetQuote({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> elementNameById,
    required OcptPageSetup pageSetup,
    required OcptBudgetTaxBasis taxBasis,
    required OcptBudgetQuoteLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptBudgetQuotePdfService budgetQuotePdfService,
  }) async {
    final bytes = await budgetQuotePdfService.generate(
      snapshot: snapshot,
      elementNameById: elementNameById,
      pageSetup: pageSetup,
      taxBasis: taxBasis,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: budgetQuotePdfService.quoteFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Render the financing plan of [snapshot] via [budgetFinancingPlanPdfService] and show the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds and [fileTypeLabel] the one
  /// the native dialog needs. Returns the write funnel's own outcome, or null if the user cancelled
  /// or the save failed (failures are logged; the OS dialog already reported a cancellation to the
  /// user).
  static Future<OcptExportOutcome?> exportBudgetFinancingPlan({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancingPlanLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptBudgetFinancingPlanPdfService budgetFinancingPlanPdfService,
  }) async {
    final bytes = await budgetFinancingPlanPdfService.generate(
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: budgetFinancingPlanPdfService.financingPlanFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }

  /// Build the cash journal's own XLSX workbook of [snapshot] via
  /// [budgetCashJournalXlsxExportService] and show the native save dialog to write it out.
  ///
  /// [linkLabelByEntryId] is the "what this entry settles" column's own text, keyed by
  /// `OcptBudgetEntry.id` and resolved by the caller — this manager has no `Tr` of its own, and
  /// this service resolves nothing itself either (`OcptBudgetCashJournalXlsxExportService`'s own
  /// doc comment). [labels] carries every localized string the sheet itself holds and
  /// [fileTypeLabel] the one the native dialog needs. Returns the write funnel's own outcome, or
  /// null if the user cancelled or the save failed (failures are logged; the OS dialog already
  /// reported a cancellation to the user).
  static Future<OcptExportOutcome?> exportBudgetCashJournalXlsx({
    required OcptBudgetSnapshot snapshot,
    required Map<String, String> linkLabelByEntryId,
    required OcptBudgetCashJournalXlsxLabels labels,
    required String projectName,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptBudgetCashJournalXlsxExportService budgetCashJournalXlsxExportService,
  }) => writer.writeWorkbookToPickedLocation(
    suggestedFileName: budgetCashJournalXlsxExportService.xlsxFileName(projectName: projectName),
    fileTypeLabel: fileTypeLabel,
    extensions: const [OcptShotListXlsxExportService.xlsxFileExtension],
    workbook: budgetCashJournalXlsxExportService.generate(
      snapshot: snapshot,
      linkLabelByEntryId: linkLabelByEntryId,
      labels: labels,
    ),
    shareAnchor: shareAnchor,
  );

  /// Render the financial report of [snapshot] via [budgetFinancialReportPdfService] and show the
  /// native save dialog to write it out.
  ///
  /// [labels] carries every localized string the document itself holds and [fileTypeLabel] the one
  /// the native dialog needs. Returns the write funnel's own outcome, or null if the user cancelled
  /// or the save failed (failures are logged; the OS dialog already reported a cancellation to the
  /// user).
  static Future<OcptExportOutcome?> exportBudgetFinancialReport({
    required OcptBudgetSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBudgetFinancialReportLabels labels,
    required String projectName,
    required bool includeTitlePage,
    required String fileTypeLabel,
    Rect? shareAnchor,
    required OcptExportWriteService writer,
    required OcptBudgetFinancialReportPdfService budgetFinancialReportPdfService,
  }) async {
    final bytes = await budgetFinancialReportPdfService.generate(
      snapshot: snapshot,
      pageSetup: pageSetup,
      labels: labels,
      projectName: projectName,
      includeTitlePage: includeTitlePage,
    );

    return writer.writeToPickedLocation(
      suggestedFileName: budgetFinancialReportPdfService.financialReportFileName(
        projectName: projectName,
        suffix: labels.fileNameSuffix,
      ),
      fileTypeLabel: fileTypeLabel,
      extensions: const ["pdf"],
      bytes: bytes,
      shareAnchor: shareAnchor,
    );
  }
}
