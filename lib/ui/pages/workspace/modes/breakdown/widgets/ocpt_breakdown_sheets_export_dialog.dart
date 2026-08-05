// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_export_options.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// A dialog letting the user pick the one-off options a breakdown sheets export runs with.
///
/// Modelled on `OcptScenarioCoverageExportDialog`, whose strings it reuses for everything the two
/// dialogs ask the same question about (the page size, the two buttons): wording the very same
/// option differently in the two places would only invite the reader to look for a difference that
/// isn't there. The three checkboxes below are this export's own — which scenes are printed, and
/// the two sections a sheet may leave out.
///
/// Shows a page format dropdown (prefilled from [current], but never persisted: it only changes the
/// document being exported now) and those three checkboxes. The two content ones default on and
/// "only the scenes marked as done" defaults **off**: the sheets are what a department head reads
/// to prepare, and a scene half broken down is still a scene they have to prepare for. The margins
/// of [current] are always carried through unchanged: this dialog never lets the user edit them.
/// Use [show] to display it and get back the resulting [OcptBreakdownSheetsExportOptions], or null
/// if the user cancelled.
class OcptBreakdownSheetsExportDialog extends StatefulWidget {
  /// The page setup the script view is typeset with, used to pre-fill the format dropdown and to
  /// supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Class constructor
  const OcptBreakdownSheetsExportDialog({required this.current, super.key});

  /// Shows the dialog and returns the [OcptBreakdownSheetsExportOptions] the user applied, or null
  /// if they cancelled it.
  static Future<OcptBreakdownSheetsExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
  }) => showDialog<OcptBreakdownSheetsExportOptions>(
    context: context,
    builder: (context) => OcptBreakdownSheetsExportDialog(current: current),
  );

  @override
  State<OcptBreakdownSheetsExportDialog> createState() => _OcptBreakdownSheetsExportDialogState();
}

/// The state of [OcptBreakdownSheetsExportDialog].
class _OcptBreakdownSheetsExportDialogState extends State<OcptBreakdownSheetsExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// Whether only the scenes marked as done will be printed.
  bool _onlyDoneScenes = false;

  /// Whether each scene's own breakdown notes will be printed on its sheet.
  bool _includeNotes = true;

  /// Whether each sheet closes on the list of what the scene still has to find.
  bool _includeToFindList = true;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.breakdownExportSheetsDialogTitle),
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
              value: _onlyDoneScenes,
              title: Text(tr.breakdownExportSheetsOnlyDoneLabel),
              onChanged: (value) => setState(() => _onlyDoneScenes = value ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeNotes,
              title: Text(tr.breakdownExportSheetsNotesLabel),
              onChanged: (value) => setState(() => _includeNotes = value ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeToFindList,
              title: Text(tr.breakdownExportSheetsToFindLabel),
              onChanged: (value) => setState(() => _includeToFindList = value ?? true),
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

  /// Pops the dialog returning the resulting [OcptBreakdownSheetsExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptBreakdownSheetsExportDialog.show] caller.
  void _submit() {
    final options = OcptBreakdownSheetsExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      onlyDoneScenes: _onlyDoneScenes,
      includeNotes: _includeNotes,
      includeToFindList: _includeToFindList,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptBreakdownSheetsExportOptions>(options);
  }
}
