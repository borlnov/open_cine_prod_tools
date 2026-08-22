// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// A dialog letting the user pick the one-off options a quote export runs with: the page format,
/// the title page, and the tax basis every line and total is printed in.
///
/// Modelled on `OcptScheduleDayOutOfDaysExportDialog`, whose page-format dropdown and title-page
/// checkbox this reuses the same strings for. **Deliberately its own class rather than one of its
/// siblings' (`OcptBudgetFinancingPlanExportDialog`, `OcptBudgetFinancialReportExportDialog`) with
/// a field added**: `OcptBudgetQuoteExportOptions`'s own doc comment already argues why each export
/// owns its options rather than sharing a class, and the same argument holds for the dialog filling
/// it in — a shared dialog would let one document silently ignore a field the other one collected.
///
/// [taxBasis] defaults to the header's own currently selected `OcptBudgetTaxBasis`, so the document
/// a person exports matches the one they were just reading, and it is changeable here.
///
/// Use [show] to display it and get back the resulting [OcptBudgetQuoteExportOptions], or null if
/// the user cancelled.
class OcptBudgetQuoteExportDialog extends StatefulWidget {
  /// The page setup the budget mode's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// The header's own currently selected tax basis, the dialog's own default.
  final OcptBudgetTaxBasis taxBasis;

  /// Class constructor
  const OcptBudgetQuoteExportDialog({required this.current, required this.taxBasis, super.key});

  /// Shows the dialog and returns the [OcptBudgetQuoteExportOptions] the user applied, or null if
  /// they cancelled it.
  static Future<OcptBudgetQuoteExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
    required OcptBudgetTaxBasis taxBasis,
  }) => showDialog<OcptBudgetQuoteExportOptions>(
    context: context,
    builder: (context) => OcptBudgetQuoteExportDialog(current: current, taxBasis: taxBasis),
  );

  @override
  State<OcptBudgetQuoteExportDialog> createState() => _OcptBudgetQuoteExportDialogState();
}

/// The state of [OcptBudgetQuoteExportDialog].
class _OcptBudgetQuoteExportDialogState extends State<OcptBudgetQuoteExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// The tax basis currently selected in the segmented control.
  late OcptBudgetTaxBasis _selectedTaxBasis;

  /// Whether the title page will be included in the exported document.
  bool _includeTitlePage = true;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
    _selectedTaxBasis = widget.taxBasis;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.budgetExportQuoteDialogTitle),
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
            const SizedBox(height: 8),
            SegmentedButton<OcptBudgetTaxBasis>(
              segments: [
                ButtonSegment(
                  value: OcptBudgetTaxBasis.excludingTax,
                  label: Text(tr.budgetHeaderExcludingTaxSegmentLabel),
                ),
                ButtonSegment(
                  value: OcptBudgetTaxBasis.includingTax,
                  label: Text(tr.budgetHeaderIncludingTaxSegmentLabel),
                ),
              ],
              selected: {_selectedTaxBasis},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedTaxBasis = selection.first),
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

  /// Pops the dialog returning the resulting [OcptBudgetQuoteExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the [OcptBudgetQuoteExportDialog.show]
  /// caller.
  void _submit() {
    final options = OcptBudgetQuoteExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      includeTitlePage: _includeTitlePage,
      taxBasis: _selectedTaxBasis,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptBudgetQuoteExportOptions>(options);
  }
}
