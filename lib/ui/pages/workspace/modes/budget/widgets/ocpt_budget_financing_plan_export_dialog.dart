// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_pdf_export_dialog.dart';

/// A dialog letting the user pick the one-off options a financing plan export runs with: the page
/// format and the title page.
///
/// Modelled on `OcptScheduleDayOutOfDaysExportDialog`, whose page-format dropdown and title-page
/// checkbox this reuses the same strings for. **No tax basis here**, unlike
/// `OcptBudgetQuoteExportDialog`: `OcptBudgetFinancingPlanExportOptions`'s own doc comment already
/// argues there is no second basis this document could offer a choice between, a financing resource
/// being money coming in, always read tax-inclusive. Its own class, with its own
/// options, for the very same reason `OcptBudgetQuoteExportDialog`'s own doc comment gives; only
/// the dialog's body is shared.
///
/// Use [show] to display it and get back the resulting [OcptBudgetFinancingPlanExportOptions], or
/// null if the user cancelled.
class OcptBudgetFinancingPlanExportDialog extends StatelessWidget {
  /// The page setup the budget mode's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Class constructor
  const OcptBudgetFinancingPlanExportDialog({required this.current, super.key});

  /// Build the dialog as an [OcptBudgetPdfExportDialog] building a
  /// [OcptBudgetFinancingPlanExportOptions].
  @override
  Widget build(BuildContext context) =>
      OcptBudgetPdfExportDialog<OcptBudgetFinancingPlanExportOptions>(
        title: Tr.of(context).budgetExportFinancingPlanDialogTitle,
        current: current,
        optionsOf: OcptBudgetFinancingPlanExportOptions.new,
      );

  /// Show the dialog and return the [OcptBudgetFinancingPlanExportOptions]
  /// the user applied, or null if they cancelled it.
  static Future<OcptBudgetFinancingPlanExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
  }) => showDialog<OcptBudgetFinancingPlanExportOptions>(
    context: context,
    builder: (context) => OcptBudgetFinancingPlanExportDialog(current: current),
  );
}
