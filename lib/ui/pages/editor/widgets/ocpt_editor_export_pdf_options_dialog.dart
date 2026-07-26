// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_pdf_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// A dialog letting the user pick the one-off options a PDF export runs with.
///
/// Shows a page format dropdown (prefilled from [current], but never persisted: it only changes
/// the PDF being exported now) and two checkboxes, "Include scene numbers" and "Include title
/// page" (both default on). The margins of [current] are always carried through unchanged: this
/// dialog never lets the user edit them. Use [show] to display it and get back the resulting
/// [OcptPdfExportOptions], or null if the user cancelled.
class OcptEditorExportPdfOptionsDialog extends StatefulWidget {
  /// The page setup currently applied to the editor, used to pre-fill the format dropdown and to
  /// supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Class constructor
  const OcptEditorExportPdfOptionsDialog({required this.current, super.key});

  /// Shows the dialog and returns the [OcptPdfExportOptions] the user applied, or null if they
  /// cancelled it.
  static Future<OcptPdfExportOptions?> show(BuildContext context, {required OcptPageSetup current}) =>
      showDialog<OcptPdfExportOptions>(
        context: context,
        builder: (context) => OcptEditorExportPdfOptionsDialog(current: current),
      );

  @override
  State<OcptEditorExportPdfOptionsDialog> createState() => _OcptEditorExportPdfOptionsDialogState();
}

/// The state of [OcptEditorExportPdfOptionsDialog].
class _OcptEditorExportPdfOptionsDialogState extends State<OcptEditorExportPdfOptionsDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// Whether scene numbers will be included in the exported PDF.
  bool _includeSceneNumbers = true;

  /// Whether a title page will be included in the exported PDF.
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
      title: Text(tr.editorExportPdfDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<OcptPageFormat>(
              initialValue: _selectedFormat,
              decoration: InputDecoration(labelText: tr.editorPageSetupPageSizeLabel),
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
              value: _includeSceneNumbers,
              title: Text(tr.editorExportPdfSceneNumbersLabel),
              onChanged: (value) => setState(() => _includeSceneNumbers = value ?? true),
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

  /// Pops the dialog returning the resulting [OcptPdfExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptEditorExportPdfOptionsDialog.show] caller.
  void _submit() {
    final options = OcptPdfExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      includeSceneNumbers: _includeSceneNumbers,
      includeTitlePage: _includeTitlePage,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptPdfExportOptions>(options);
  }
}
