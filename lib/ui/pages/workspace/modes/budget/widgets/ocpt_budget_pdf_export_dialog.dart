// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The dialog the budget documents that take only the common options share: a page format
/// dropdown and the title page checkbox.
///
/// It builds the options the document runs with through [optionsOf] and pops them to whoever
/// showed the dialog. A document that asks for more (the quote, with its tax basis) has a dialog
/// of its own, so that no document silently ignores a field another one collected.
class OcptBudgetPdfExportDialog<T extends Object> extends StatefulWidget {
  /// The dialog's title.
  final String title;

  /// The page setup the budget mode's PDF exports are typeset with, used to pre-fill the format
  /// dropdown and to supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Build the options the document runs with from what the user picked.
  final T Function({
    required OcptPageFormat format,
    required FountainPageMargins margins,
    required bool includeTitlePage,
  })
  optionsOf;

  /// Class constructor
  const OcptBudgetPdfExportDialog({
    required this.title,
    required this.current,
    required this.optionsOf,
    super.key,
  });

  /// Create the [_OcptBudgetPdfExportDialogState] holding the state of the budget PDF export
  /// dialog.
  @override
  State<OcptBudgetPdfExportDialog<T>> createState() => _OcptBudgetPdfExportDialogState<T>();
}

/// The state of [OcptBudgetPdfExportDialog].
class _OcptBudgetPdfExportDialogState<T extends Object>
    extends State<OcptBudgetPdfExportDialog<T>> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// Whether the title page will be included in the exported document.
  bool _includeTitlePage = true;

  /// Seed the selection from the settings the dialog was opened with.
  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
  }

  /// Build the budget PDF export dialog as an [AlertDialog].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<OcptPageFormat>(
              initialValue: _selectedFormat,
              decoration: InputDecoration(labelText: tr.editorPageSetupPageSizeLabel),
              mouseCursor: ocpt_theme.ocptClickableCursor,
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

  /// Get the localized label of [format].
  String _formatLabel(Tr tr, OcptPageFormat format) => switch (format) {
    OcptPageFormat.usLetter => tr.editorPageSetupUsLetterOption,
    OcptPageFormat.a4 => tr.editorPageSetupA4Option,
  };

  /// Pop the dialog returning the options [OcptBudgetPdfExportDialog.optionsOf] builds.
  ///
  /// The dialog is dismissed through the router manager (navigation only via the router
  /// manager), whose pop delivers the new options back to the caller that showed the dialog.
  void _submit() {
    final options = widget.optionsOf(
      format: _selectedFormat,
      margins: widget.current.margins,
      includeTitlePage: _includeTitlePage,
    );
    globalGetIt().get<OcptRouterManager>().pop<T>(options);
  }
}
