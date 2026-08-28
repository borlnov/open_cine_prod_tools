// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// A dialog letting the user pick the one-off options a financing plan export runs with: the page
/// format and the title page.
///
/// Modelled on `OcptScheduleDayOutOfDaysExportDialog`, whose page-format dropdown and title-page
/// checkbox this reuses the same strings for. **No tax basis here**, unlike
/// `OcptBudgetQuoteExportDialog`: `OcptBudgetFinancingPlanExportOptions`'s own doc comment already
/// argues there is no second basis this document could offer a choice between, a financing resource
/// being money coming in, always read tax-inclusive. Deliberately its own class rather than sharing
/// one with its siblings, for the very same reason `OcptBudgetQuoteExportDialog`'s own doc comment
/// gives.
///
/// Use [show] to display it and get back the resulting [OcptBudgetFinancingPlanExportOptions], or
/// null if the user cancelled.
class OcptBudgetFinancingPlanExportDialog extends StatefulWidget {
  /// The page setup the budget mode's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Class constructor
  const OcptBudgetFinancingPlanExportDialog({required this.current, super.key});

  /// Shows the dialog and returns the [OcptBudgetFinancingPlanExportOptions] the user applied, or
  /// null if they cancelled it.
  static Future<OcptBudgetFinancingPlanExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
  }) => showDialog<OcptBudgetFinancingPlanExportOptions>(
    context: context,
    builder: (context) => OcptBudgetFinancingPlanExportDialog(current: current),
  );

  @override
  State<OcptBudgetFinancingPlanExportDialog> createState() =>
      _OcptBudgetFinancingPlanExportDialogState();
}

/// The state of [OcptBudgetFinancingPlanExportDialog].
class _OcptBudgetFinancingPlanExportDialogState extends State<OcptBudgetFinancingPlanExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// Whether the title page will be included in the exported document.
  bool _includeTitlePage = true;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.budgetExportFinancingPlanDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<OcptPageFormat>(
              initialValue: _selectedFormat,
              decoration: InputDecoration(labelText: tr.editorPageSetupPageSizeLabel),
              mouseCursor: ocptClickableCursor,
              items: [
                for (final format in OcptPageFormat.values)
                  DropdownMenuItem(value: format, child: Text(_formatLabel(tr, format))),
              ],
              onChanged: (format) {
                if (format == null) {
                  return;
                }
                setState(() => _selectedFormat = format);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeTitlePage,
              title: Text(tr.editorExportPdfTitlePageLabel),
              onChanged: (value) => setState(() => _includeTitlePage = value ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.editorPageSetupCancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(tr.editorExportPdfExportAction)),
      ],
    );
  }

  /// The localized label of [format].
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };

  /// Pops the dialog returning the resulting [OcptBudgetFinancingPlanExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptBudgetFinancingPlanExportDialog.show] caller.
  void _submit() {
    final options = OcptBudgetFinancingPlanExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      includeTitlePage: _includeTitlePage,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetFinancingPlanExportOptions>(options);
  }
}
