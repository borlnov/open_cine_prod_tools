// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The shots-per-page choices the dialog's own dropdown offers.
const List<int> _shotsPerPageChoices = [1, 2, 3, 4];

/// The default number of shots printed on one page, when the dialog is first opened.
const int _defaultShotsPerPage = 2;

/// A dialog letting the user pick the one-off options a storyboard export runs with.
///
/// Modelled on `OcptScenarioCoverageExportDialog`, line for line (`docs/plans/storyboard.md`, §5):
/// a page format dropdown (prefilled from [current], never persisted), a shots-per-page dropdown of
/// its own, and the `Include the floor plans after each sequence` toggle — the "printed alongside"
/// reading of the two documents (§8, decision 8). Use [show] to display it and get back the
/// resulting [OcptStoryboardExportOptions], or null if the user cancelled.
class OcptStoryboardExportDialog extends StatefulWidget {
  /// The page setup the screenplay is typeset with, used to pre-fill the format dropdown and to
  /// supply the margins carried through unchanged into the resulting options.
  final OcptPageSetup current;

  /// Class constructor
  const OcptStoryboardExportDialog({required this.current, super.key});

  /// Shows the dialog and returns the [OcptStoryboardExportOptions] the user applied, or null if
  /// they cancelled it.
  static Future<OcptStoryboardExportOptions?> show(
    BuildContext context, {
    required OcptPageSetup current,
  }) => showDialog<OcptStoryboardExportOptions>(
    context: context,
    builder: (context) => OcptStoryboardExportDialog(current: current),
  );

  @override
  State<OcptStoryboardExportDialog> createState() => _OcptStoryboardExportDialogState();
}

/// The state of [OcptStoryboardExportDialog].
class _OcptStoryboardExportDialogState extends State<OcptStoryboardExportDialog> {
  /// The page format currently selected in the dropdown.
  late OcptPageFormat _selectedFormat;

  /// How many shots print on one page before the document breaks onto a fresh one.
  int _shotsPerPage = _defaultShotsPerPage;

  /// Whether the floor plan sheets are appended after each sequence.
  bool _includeFloorPlansAfterEachSequence = false;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.current.format;
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return AlertDialog(
      title: Text(tr.shotListExportStoryboardDialogTitle),
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
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _shotsPerPage,
              decoration: InputDecoration(labelText: tr.shotListExportStoryboardShotsPerPageLabel),
              mouseCursor: ocptClickableCursor,
              items: [
                for (final choice in _shotsPerPageChoices)
                  DropdownMenuItem(value: choice, child: Text("$choice")),
              ],
              onChanged: (shotsPerPage) {
                if (shotsPerPage == null) {
                  return;
                }
                setState(() => _shotsPerPage = shotsPerPage);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeFloorPlansAfterEachSequence,
              title: Text(tr.shotListExportStoryboardIncludeFloorPlansLabel),
              onChanged: (value) =>
                  setState(() => _includeFloorPlansAfterEachSequence = value ?? false),
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

  /// Pops the dialog returning the resulting [OcptStoryboardExportOptions].
  ///
  /// The dialog is dismissed through the router manager (RFL31: navigation only via the router
  /// manager), whose pop delivers the new options back to the
  /// [OcptStoryboardExportDialog.show] caller.
  void _submit() {
    final options = OcptStoryboardExportOptions(
      format: _selectedFormat,
      margins: widget.current.margins,
      shotsPerPage: _shotsPerPage,
      includeFloorPlansAfterEachSequence: _includeFloorPlansAfterEachSequence,
    );
    globalGetIt().get<OcptRouterManager>().pop<OcptStoryboardExportOptions>(options);
  }
}
