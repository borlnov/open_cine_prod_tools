// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_pdf_export_dialog.dart';

/// A dialog letting the user pick the one-off options a financial report export runs with: the
/// page format and the title page.
///
/// Modelled on `OcptScheduleDayOutOfDaysExportDialog`, whose page-format dropdown and title-page
/// checkbox this reuses the same strings for. **No tax basis here**, unlike
/// `OcptBudgetQuoteExportDialog`: `OcptBudgetFinancialReportExportOptions`'s own doc comment
/// already argues this report reads the quote against figures that are always read tax-inclusive,
/// so a basis toggle here would let the quoted column disagree with what it is measured against.
/// Its own class, with its own options, for the very same reason
/// `OcptBudgetQuoteExportDialog`'s own doc comment gives; only the dialog's body is shared.
///
/// Use [show] to display it and get back the resulting [OcptBudgetFinancialReportExportOptions], or
/// null if the user cancelled.
class OcptBudgetFinancialReportExportDialog extends StatelessWidget {
  /// The page setup the budget mode's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Class constructor
  const OcptBudgetFinancialReportExportDialog({required this.current, super.key});

  /// Build the dialog as an [OcptBudgetPdfExportDialog] building a
  /// [OcptBudgetFinancialReportExportOptions].
  @override
  Widget build(BuildContext context) =>
      OcptBudgetPdfExportDialog<OcptBudgetFinancialReportExportOptions>(
        title: Tr.of(context).budgetExportFinancialReportDialogTitle,
        current: current,
        optionsOf: OcptBudgetFinancialReportExportOptions.new,
      );

  /// Show the dialog and return the [OcptBudgetFinancialReportExportOptions] the user applied, or null if
  /// they cancelled it.
  static Future<OcptBudgetFinancialReportExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
  }) => showDialog<OcptBudgetFinancialReportExportOptions>(
    context: context,
    builder: (context) => OcptBudgetFinancialReportExportDialog(current: current),
  );
}
